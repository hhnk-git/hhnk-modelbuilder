--ALTER TABLE damo_ruw.peilafwijkinggebied RENAME COLUMN peilafwijkinggebied_id TO peilafwijking_id;

--Onderstaande sequence alleen gebruiken als peilafwijkingid mist
DROP SEQUENCE IF EXISTS serial;
CREATE SEQUENCE serial START 10000000;
SELECT setval('serial', (SELECT max(peilafwijkinggebied_id) FROM tmp.peilafwijkinggebied));   
    
-- tijdelijke tabel met peilgebieden
DROP TABLE IF EXISTS tmp.SSC;
CREATE TABLE tmp.SSC AS
SELECT objectid, code as ssc_name, naam, opmerking, ws_bron, ws_inwinningswijze, 
       ws_inwinningsdatum, created_user, created_date, 
       last_edited_user, last_edited_date, shape_length, shape_area, 
      peilgebiedpraktijk_id as SSC_CODE, peil_wsa as ssc_level, keuze_wsa as ssc_level_type, 
	   --nextval('serial') as SSC_CODE, --igv missend peilafwijkingid
	   wkb_geometry as geom
  FROM tmp.peilgebiedpraktijk
  --LIMIT 100
  ;


-- tijdelijke tabel met peilafwijkingen
DROP TABLE IF EXISTS tmp.POA;
CREATE TABLE tmp.POA AS
SELECT objectid, code as poa_name, naam, opmerking, ws_bron, ws_inwinningswijze, 
       ws_inwinningsdatum, created_user, created_date, last_edited_user, 
       last_edited_date, shape_length, shape_area, 
	   peilafwijkinggebied_id as POA_CODE, peil_wsa as poa_level, keuze_wsa as poa_level_type,
	   --nextval('serial') as POA_CODE, --igv missend peilafwijkingid
       wkb_geometry as geom
  FROM tmp.peilafwijkinggebied
UNION
SELECT objectid, 'HDB:' || code as poa_name, naam, opmerking, ws_bron, NULL as ws_inwinningswijze,
	peil_datum as ws_inwinningsdatum, NULL as created_user, NULL as created_date, NULL as last_edited_user,
	NULL as last_edited_date, shape_length, shape_area,
	nextval('serial') as POA_CODE, NULL as poa_level, NULL as poa_level_type,
	wkb_geometry as geom
FROM hdb.hydro_deelgebieden
;


--explode multipolygons to single parts
DROP TABLE IF EXISTS tmp.POA_EXPLODE;
CREATE TABLE tmp.POA_EXPLODE AS
SELECT
	poa_code,
	poa_name,
	poa_level,
	poa_level_type,
	(ST_Dump(geom) ).geom
FROM
	tmp.POA;

DROP TABLE IF EXISTS tmp.SSC_EXPLODE;
CREATE TABLE tmp.SSC_EXPLODE AS
SELECT
	ssc_code,
	ssc_name,
	ssc_level,
	ssc_level_type,
	(ST_Dump(geom) ).geom
FROM
	tmp.SSC;

--combine geometries into a single table
DROP TABLE IF EXISTS tmp.POA_SSC_COMBO;
CREATE TABLE tmp.POA_SSC_COMBO AS
SELECT ssc_code AS ssc_code, ssc_name as ssc_name, ssc_level as ssc_level, ssc_level_type as ssc_level_type, null AS poa_code, null as poa_name, null as poa_level, null as poa_level_type, geom as geom FROM tmp.SSC_EXPLODE
UNION ALL
SELECT null AS ssc_code, null as ssc_name, null as ssc_level, null as ssc_level_type, poa_code AS poa_code, poa_name as poa_name, poa_level as poa_level, poa_level_type as poa_level_type, geom as geom FROM tmp.POA_EXPLODE;

--creates a single table of non-overalapping polygons
--warning takes a long time to execute..
DROP TABLE IF EXISTS tmp.POA_SSC_OVERLAY;
CREATE TABLE tmp.POA_SSC_OVERLAY AS SELECT
	geom
FROM
	ST_Dump (
		(
			SELECT
				ST_Polygonize (the_geom) AS the_geom
			FROM
				(
					SELECT
						ST_Union (ST_SnapToGrid(the_geom,0,0,0.001,0.001)) AS the_geom
					FROM
						(
							SELECT
								ST_ExteriorRing (geom) AS the_geom
							FROM
								tmp.POA_SSC_COMBO
						) AS lines
				) AS noded_lines
		)
	);

-- points on surface
DROP TABLE IF EXISTS tmp.POA_SSC_OVERLAY_PTS;
CREATE TABLE tmp.POA_SSC_OVERLAY_PTS AS SELECT
	ST_PointOnSurface (geom) AS geom
FROM
	tmp.POA_SSC_OVERLAY;

-- group by geom and aggregate original ids by point overlap
-- Replicates an ArcGIS-style Union
DROP TABLE IF EXISTS tmp.POA_SSC_UNION;
CREATE TABLE tmp.POA_SSC_UNION AS (
	SELECT
		NEW .geom AS geom,
		MAX (orig.SSC_CODE) AS SSC_CODE,
		MIN (orig.POA_CODE) AS POA_CODE
	FROM
		tmp.POA_SSC_COMBO AS orig,
		tmp.POA_SSC_OVERLAY_PTS AS pt,
		tmp.POA_SSC_OVERLAY AS NEW
	WHERE
		orig.geom && pt.geom
	AND NEW.geom && pt.geom
	AND ST_Intersects (orig.geom, pt.geom)
	AND ST_Intersects (NEW .geom, pt.geom)
	GROUP BY
		NEW .geom
);

-- Join with the original tables to pull in attributes
-- This is still single part geometry

DROP TABLE IF EXISTS tmp.POA_SSC_UNIONJOIN;
CREATE TABLE tmp.POA_SSC_UNIONJOIN AS SELECT
	G.geom AS geom,
	S.SSC_CODE,
	S.SSC_NAME,
	S.SSC_LEVEL,
	S.SSC_LEVEL_TYPE,
	P.POA_CODE,
	P.POA_NAME,
	P.POA_LEVEL,
	P.POA_LEVEL_TYPE
FROM
	tmp.POA_SSC_UNION AS G
LEFT JOIN tmp.SSC S ON S.SSC_CODE = G.SSC_CODE
LEFT JOIN tmp.POA P ON P.POA_CODE = G.POA_CODE;

-- Maak weer multies van
DROP TABLE IF EXISTS tmp.POA_SSC_FINALUNION;
CREATE TABLE tmp.POA_SSC_FINALUNION AS  SELECT
	U.SSC_CODE,
	MIN (U.SSC_NAME) AS SSC_NAME,
	SSC_LEVEL,
	SSC_LEVEL_TYPE,
	U.POA_CODE,
	MIN (U.POA_NAME) AS POA_NAME,
	POA_LEVEL,
	POA_LEVEL_TYPE,
	ST_Multi (ST_Union(U.geom)) AS GEOM
FROM
	tmp.POA_SSC_UNIONJOIN AS U
GROUP BY
	SSC_CODE,SSC_LEVEL,SSC_LEVEL_TYPE,
	POA_CODE,POA_LEVEL,POA_LEVEL_TYPE;


-- nieuwe tabel maken met alle eigenschappen
DROP TABLE IF EXISTS tmp.union;
CREATE TABLE tmp.union AS
SELECT b.objectid, b.ssc_name as code, naam, opmerking, ws_bron, ws_inwinningswijze, 
       ws_inwinningsdatum, created_user, created_date, last_edited_user, 
       last_edited_date, shape_length, shape_area, a.ssc_code as id, a.ssc_level as wsa_level, a.ssc_level_type as wsa_level_type, a.geom, 'peilgebied'::varchar(50) as type
FROM tmp.POA_SSC_FINALUNION as a
LEFT JOIN tmp.SSC as b
ON a.ssc_name = b.ssc_name
WHERE a.poa_code IS NULL
UNION
SELECT b.objectid, b.poa_name as code, naam, opmerking, ws_bron, ws_inwinningswijze, 
       ws_inwinningsdatum, created_user, created_date, last_edited_user, 
       last_edited_date, shape_length, shape_area, a.poa_code as id, a.poa_level as wsa_level, a.poa_level_type as wsa_level_type, a.geom, 'peilafwijking'::varchar(50) as type
FROM tmp.POA_SSC_FINALUNION as a
LEFT JOIN tmp.POA as b
ON a.poa_name = b.poa_name
WHERE a.poa_code IS NOT NULL
;



--Oplossen niet unieke codes
DROP TABLE IF EXISTS checks.fixeddrainagelevelarea_double_code;
CREATE TABLE checks.fixeddrainagelevelarea_double_code AS
WITH dist AS (SELECT DISTINCT ON (code) code FROM tmp.union),
  grouped AS (SELECT objectid, code, naam, opmerking, ws_bron, ws_inwinningswijze, 
       ws_inwinningsdatum, created_user, created_date, last_edited_user, 
       last_edited_date, shape_length, shape_area, id, ST_UNION(geom) as geom, type
  FROM tmp.union
  GROUP BY objectid, code, naam, opmerking, ws_bron, ws_inwinningswijze, 
       ws_inwinningsdatum, created_user, created_date, last_edited_user, 
       last_edited_date, shape_length, shape_area, id, type),
  counted AS (
	SELECT a.code, count(b.code) 
	FROM dist as a, grouped as b
	WHERE a.code = b.code
	GROUP BY a.code
	)
SELECT a.count, b.* FROM counted as a, grouped as b WHERE a.count > 1 AND a.code = b.code ORDER BY a.code
;

DROP SEQUENCE IF EXISTS serial;
CREATE SEQUENCE serial START 1;

UPDATE tmp.union as a
SET code = b.code || '--' || b.objectid
FROM checks.fixeddrainagelevelarea_double_code as b
WHERE a.objectid = b.objectid AND a.code = b.code
;


DROP TABLE IF EXISTS tmp.fixedleveldrainagearea_union;
CREATE TABLE tmp.fixedleveldrainagearea_union AS
SELECT DISTINCT ON (geom) objectid, code, naam, opmerking, ws_bron, ws_inwinningswijze, 
       ws_inwinningsdatum, created_user, created_date, last_edited_user, 
       last_edited_date, shape_length, shape_area, id, wsa_level, wsa_level_type, 
		ST_CollectionExtract(
			ST_MakeValid(ST_UNION(geom))
		,3) as geom, type
  FROM tmp.union
  GROUP BY objectid, code, naam, opmerking, ws_bron, ws_inwinningswijze, 
       ws_inwinningsdatum, created_user, created_date, last_edited_user, 
       last_edited_date, shape_length, shape_area, id, wsa_level, wsa_level_type, type
;
CREATE INDEX tmp_fixedleveldrainagearea_union_geom ON tmp.fixedleveldrainagearea_union USING gist(geom);

-- tmp.peilgebiedpraktijk.code wordt tmp.SCC.ssc_name wordt tmp.fixedleveldrainagearea_union.code
-- tmp.peilafwijkinggebied.code wordt tmp.POA.poa_name wordt tmp.fixedleveldrainagearea_union.code
-- tmp.peilgebiedpraktijk.peilgebiedpraktijk_id wordt tmp.SCC.SSC_CODE wordt tmp.fixedleveldrainagearea_union.id
-- tmp.peilafwijkinggebied.peilafwijking_id wordt tmp.POA.POA_CODE wordt tmp.fixedleveldrainagearea_union.id
-- tmp.peilgebiedPraktijk.objectid en damo_ruw.peilafwijkinggebied.objectid worden tmp.fixedleveldrainagearea_union.objectid


ALTER TABLE tmp.fixedleveldrainagearea_union ADD COLUMN pointgeom geometry;
UPDATE tmp.fixedleveldrainagearea_union
SET pointgeom = ST_PointOnSurface(geom)
;
CREATE INDEX tmp_fixedleveldrainagearea_union_pointgeom ON tmp.fixedleveldrainagearea_union USING gist(pointgeom);

-- opruimen
DROP TABLE IF EXISTS tmp.SSC;
DROP TABLE IF EXISTS tmp.POA;
DROP TABLE IF EXISTS tmp.POA_EXPLODE;
DROP TABLE IF EXISTS tmp.SSC_EXPLODE;
DROP TABLE IF EXISTS tmp.POA_SSC_COMBO;
DROP TABLE IF EXISTS tmp.POA_SSC_OVERLAY;
DROP TABLE IF EXISTS tmp.POA_SSC_OVERLAY_PTS;
DROP TABLE IF EXISTS tmp.POA_SSC_UNION;
DROP TABLE IF EXISTS tmp.POA_SSC_UNIONJOIN;
DROP TABLE IF EXISTS tmp.POA_SSC_FINALUNION;