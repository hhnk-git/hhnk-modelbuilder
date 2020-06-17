/*
Voorbereiding van de profielen van de watergangen. Koppelt de ingemeten profiel-puntgeometrie aan een watergang. Watergangen die geen profiel hebben gekregen maar wel hun reach_id delen met een andere watergang krijgen het dichtstbijzijnde profiel (binnen 250 m) van de andere watergang. 

Watergangen zonder profiel krijgen een profielen die zijn aangeleverd als getabelleerd of een leggerprofiel. De locatie van deze profielen is op het midden van het kanaal voor kanalen <= 40 meter en op 10% en 90% van de lengte voor kanalen van > 40m. 

Locaties worden naar vertices van kanalen gesnapped of extra vertices worden aangemaakt om naar toe te snappen.
*/

-- profielen aanmaken voor het kanalen netwerk
-- maak nieuwe serials voor id's
DROP SEQUENCE IF EXISTS channelserial;
CREATE SEQUENCE channelserial;
DROP SEQUENCE IF EXISTS crsserial;
CREATE SEQUENCE crsserial;
DROP SEQUENCE IF EXISTS crsdefserial;
CREATE SEQUENCE crsdefserial;

-- definieer een lege tmp_crossprofile_location tabel ter voorbereiding op turtle
DROP TABLE IF EXISTS deelgebied.tmp_v2_cross_section_location;
CREATE TABLE deelgebied.tmp_v2_cross_section_location
(
  id serial,
  channel_id integer,
  definition_id integer,
  reference_level double precision,
  friction_type integer,
  friction_value double precision,
  bank_level double precision,
  the_geom geometry(Point,28992),
  code character varying(100),
  shape integer,
  width character varying(255),
  height character varying(255),
  channel_type_reach_id integer,
  depth_under_fdl double precision
);

-- definieer een lege crs_profile tabel ter voorbereiding op turtle
DROP TABLE IF EXISTS deelgebied.tmp_v2_cross_section_definition;
CREATE TABLE deelgebied.tmp_v2_cross_section_definition
(
  id serial NOT NULL,
  shape integer,
  width character varying(255),
  height character varying(255),
  code character varying(100)
);

-- linemerge kanalen met dezelfde typering
DROP TABLE IF EXISTS deelgebied.channel_typeunion; 
CREATE TABLE deelgebied.channel_typeunion AS
SELECT (ST_dump(ST_Linemerge(ST_UNION(geom)))).geom, ST_Buffer((ST_dump(ST_Linemerge(ST_UNION(geom)))).geom , 0.5) as bufgeom, 
	channel_type_id, nextval('channelserial') as channel_type_reach_id
FROM deelgebied.channel
GROUP BY channel_type_id;

CREATE INDEX deelgebied_channel_typeunion_bufgeom ON deelgebied.channel_typeunion USING gist(bufgeom);
CREATE INDEX deelgebied_channel_typeunion_geom ON deelgebied.channel_typeunion USING gist(geom);

-- maak singleparts van channel_branches en voeg middelpunt toe
ALTER TABLE deelgebied.tmp_sel_branches_without_structures DROP COLUMN IF EXISTS channel_type_reach_id;
ALTER TABLE deelgebied.tmp_sel_branches_without_structures DROP COLUMN IF EXISTS pointgeom;
ALTER TABLE deelgebied.tmp_sel_branches_without_structures DROP COLUMN IF EXISTS bufgeom;
ALTER TABLE deelgebied.tmp_sel_branches_without_structures ADD COLUMN channel_type_reach_id integer;
ALTER TABLE deelgebied.tmp_sel_branches_without_structures ADD COLUMN pointgeom geometry(Point,28992);
ALTER TABLE deelgebied.tmp_sel_branches_without_structures ADD COLUMN bufgeom geometry(Polygon,28992);
UPDATE deelgebied.tmp_sel_branches_without_structures
SET pointgeom = ST_LineInterpolatePoint(geom,0.5),
	bufgeom = ST_Buffer(geom,0.5)
;

CREATE INDEX deelgebied_tmp_sel_branches_without_structures_pointgeom ON deelgebied.tmp_sel_branches_without_structures USING gist(pointgeom);
CREATE INDEX deelgebied_tmp_sel_branches_without_structures_bufgeom ON deelgebied.tmp_sel_branches_without_structures USING gist(bufgeom);

--Add vertex at centerpoint when line is only 2 vertices
UPDATE deelgebied.tmp_sel_branches_without_structures SET geom = ST_LineMerge(ST_Union(ST_MakeLine(ST_StartPoint(geom),ST_LineInterpolatePoint(geom,0.5)),ST_MakeLine(ST_LineInterpolatePoint(geom,0.5),ST_EndPoint(geom))))
WHERE ST_NPoints(geom) = 2;


--Determine the depth = fdla - reference_level
ALTER TABLE deelgebied.crosssection DROP COLUMN IF EXISTS depth_under_fdl;
ALTER TABLE deelgebied.crosssection ADD COLUMN depth_under_fdl double precision;
UPDATE deelgebied.crosssection a SET depth_under_fdl = b.streefpeil_bwn2 - a.bed_level
FROM deelgebied.fixeddrainagelevelarea b WHERE ST_Contains(b.geom,a.geom);

-- koppel de profielen aan een gelinemerge reach obv type (prim, sec, ter)
ALTER TABLE deelgebied.crosssection DROP COLUMN IF EXISTS channel_type_reach_id;
ALTER TABLE deelgebied.crosssection ADD COLUMN channel_type_reach_id integer;
UPDATE deelgebied.crosssection as a
SET channel_type_reach_id = b.channel_type_reach_id
FROM deelgebied.channel_typeunion as b
WHERE ST_Intersects(b.bufgeom,a.geom); 


-- koppel de channel_type_reach_id aan het kanalen netwerk tmp_sel_branches_without_structures
UPDATE deelgebied.tmp_sel_branches_without_structures as a
SET channel_type_reach_id = b.channel_type_reach_id 
FROM deelgebied.channel_typeunion as b
WHERE ST_Intersects(b.bufgeom,a.pointgeom);

-- koppel de profielen aan het kanalen netwerk tmp_branches_without_scructures
ALTER TABLE deelgebied.crosssection DROP COLUMN IF EXISTS branch_reach_id;
ALTER TABLE deelgebied.crosssection ADD COLUMN branch_reach_id integer;
UPDATE deelgebied.crosssection as a
SET branch_reach_id = b.reach_id
FROM deelgebied.tmp_sel_branches_without_structures as b
WHERE ST_Intersects(b.bufgeom,a.geom); 

-- vul de profielen in tmp_crossprofile voor branches uit tmp_branches_without_scructures waar ze al op elkaar liggen
DELETE FROM deelgebied.tmp_v2_cross_section_location;
INSERT INTO deelgebied.tmp_v2_cross_section_location
SELECT id, branch_reach_id as channel_id, cross_profile_id as definition_id, bed_level as reference_level, 2 as friction_type, 
       (1.0/30) as friction_value, bank_level, geom as the_geom, code, NULL as shape, NULL as width, NULL as height, 
       channel_type_reach_id, depth_under_fdl
FROM deelgebied.crosssection
WHERE branch_reach_id IS NOT NULL
;



-- vul de tmp_crsprofile tabel
INSERT INTO deelgebied.tmp_v2_cross_section_definition
SELECT id, 6 as shape, width, height, ('PRO:' || id::varchar) as  code
FROM deelgebied.crossprofile
    WHERE id IN (
	SELECT definition_id
	FROM deelgebied.tmp_v2_cross_section_location
    )
;

-- maak profielen aan voor de branches zonder profiel maar met een profiel met hetzelfde channel_type_reach_id
-- leg de nieuwe profielen op het midden van de branch
-- neem het dichtsbijzijnde profiel


SELECT setval('crsserial', (select max(id) from deelgebied.tmp_v2_cross_section_location));
INSERT INTO deelgebied.tmp_v2_cross_section_location
SELECT DISTINCT ON (a.reach_id) nextval('crsserial') as id, a.reach_id as channel_id, b.cross_profile_id as definition_id, null as reference_level, 2 as friction_type, 
	(1.0/30) as friction_value, NULL as bank_level, ST_LineInterpolatePoint(a.geom,0.5) as the_geom, (b.code || '-' || a.reach_id) as code,  	--MAKE CODE HERE IDENTIFIABLE
	NULL::integer as shape, '' as width, '' as height, 
	a.channel_type_reach_id, b.depth_under_fdl
FROM deelgebied.tmp_sel_branches_without_structures as a
LEFT JOIN deelgebied.crosssection as b
ON a.channel_type_reach_id = b.channel_type_reach_id
WHERE b.cross_profile_id IS NOT NULL 
	AND a.reach_id NOT IN ( 																										--REMOVE THIS CHECK
		SELECT channel_id 																											--
		FROM deelgebied.tmp_v2_cross_section_location																				--
		) AND 																														--TO HERE. Now there will be double profiles (measured + tabultated)
		b.cross_profile_id IN (SELECT definition_id FROM deelgebied.tmp_v2_cross_section_location) 
    AND ST_Distance(a.geom,b.geom) < 250																						--Only take profile if the closest point of channel is within 250 meter
ORDER BY a.reach_id ASC, ST_Distance(a.pointgeom,b.geom) ASC
;

-- stel de banklevel van gemeten profielen ook op de aanname in en de reference level op de depth_under_fdl
UPDATE deelgebied.tmp_v2_cross_section_location as a SET bank_level = b.streefpeil_bwn2 +0.1, reference_level = b.streefpeil_bwn2 - depth_under_fdl
FROM deelgebied.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.the_geom,b.geom)
;

--ALTER TABLE deelgebied.tmp_v2_cross_section_location DROP COLUMN IF EXISTS depth_under_fdl;

-- maak voor de originele channels langer dan 40 m twee profielen op basis van de legger op 0.1 en 0.9 van de lijn, bewaar het brach_id
-- maak voor de originele channels korter dan 40 m een profiel op het midden van de channel, bewaar het brach_id
SELECT setval('crsserial', (select max(id) from deelgebied.tmp_v2_cross_section_location));
SELECT setval('crsdefserial', (select max(id) from deelgebied.tmp_v2_cross_section_definition));

DROP TABLE IF EXISTS deelgebied.tmp_channel_crs;
CREATE TABLE deelgebied.tmp_channel_crs AS
SELECT nextval('crsserial') as id, 
	0 as channel_id, 
	nextval('crsdefserial') as definition_id, 
	CASE profile_type
		WHEN 'legger'
			THEN a.bed_level
		WHEN 'getabuleerde breedte en bodemhoogte'
			THEN derived_bed_level
	END as reference_level, 
	2 as friction_type,
	CASE WHEN channel_type_id = 1 THEN (1.0/30) ELSE (1.0/20) END as friction_value, --> aanname
	b.streefpeil_bwn2 + 0.1 as bank_level, --> aanname!
	ST_LineInterpolatePoint(a.geom,0.1) as the_geom, 
	('HO1:' || a.name) as code, 
	6 as shape,
	CASE profile_type 
		WHEN 'legger' 
			THEN a.bed_width || ' ' || greatest(a.bed_width + (b.streefpeil_bwn2 - a.bed_level)*((talud_right+talud_left)),a.bed_width)
		WHEN 'getabuleerde breedte en bodemhoogte' 
			THEN tabulated_width
	END as width, 	-- <- hier wordt legger gebruikt
	CASE profile_type
		WHEN 'legger'
			THEN '0 ' || greatest((b.streefpeil_bwn2 - a.bed_level),0.5) 
		WHEN 'getabuleerde breedte en bodemhoogte'
			THEN tabulated_height
	END as height 																		-- <- hier wordt legger gebruikt
FROM deelgebied.channel as a, deelgebied.fixeddrainagelevelarea as b
WHERE ST_Intersects(ST_LineInterpolatePoint(a.geom,0.1), b.geom) 
	AND ST_Length(a.geom) > 40
UNION
SELECT nextval('crsserial') as id, 
	0 as channel_id, 
	nextval('crsdefserial') as definition_id, 
	CASE profile_type
		WHEN 'legger'
			THEN a.bed_level
		WHEN 'getabuleerde breedte en bodemhoogte'
			THEN derived_bed_level
	END as reference_level, 
	2 as friction_type,
	CASE WHEN channel_type_id = 1 THEN (1.0/30) ELSE (1.0/20) END as friction_value, --> aanname
	b.streefpeil_bwn2 + 0.1 as bank_level, --> aanname!
	ST_LineInterpolatePoint(a.geom,0.9) as the_geom, 
	('HO2:' || a.name) as code, 
	6 as shape, 
	CASE profile_type 
		WHEN 'legger' 
			THEN a.bed_width || ' ' || greatest(a.bed_width + (b.streefpeil_bwn2 - a.bed_level)*((talud_right+talud_left)),a.bed_width)
		WHEN 'getabuleerde breedte en bodemhoogte'
			THEN tabulated_width
	END as width, 	-- <- hier wordt legger gebruikt
	CASE profile_type
		WHEN 'legger'
			THEN '0 ' || greatest((b.streefpeil_bwn2 - a.bed_level),0.5) 
		WHEN 'getabuleerde breedte en bodemhoogte'
			THEN tabulated_height
	END as height 																															-- <- hier wordt legger gebruikt
FROM deelgebied.channel as a, deelgebied.fixeddrainagelevelarea as b
WHERE ST_Intersects(ST_LineInterpolatePoint(a.geom,0.9), b.geom) 
	AND ST_Length(a.geom) > 40
UNION
SELECT nextval('crsserial') as id, 
	0 as channel_id, 
	nextval('crsdefserial') as definition_id, 
	CASE profile_type
		WHEN 'legger'
			THEN a.bed_level
		WHEN 'getabuleerde breedte en bodemhoogte'
			THEN derived_bed_level
	END as reference_level, 
	2 as friction_type,
	CASE WHEN channel_type_id = 1 THEN (1.0/30) ELSE (1.0/20) END as friction_value, --> aanname
	b.streefpeil_bwn2 + 0.1 as bank_level, --> aanname!
	ST_LineInterpolatePoint(a.geom,0.5) as the_geom, 
	('HO:' || a.name) as code, 
	6 as shape, 
	CASE profile_type 
		WHEN 'legger' 
			THEN a.bed_width || ' ' || greatest(a.bed_width + (b.streefpeil_bwn2 - a.bed_level)*((talud_right+talud_left)),a.bed_width)
		WHEN 'getabuleerde breedte en bodemhoogte'
			THEN tabulated_width
	END as width, 	-- <- hier wordt legger gebruikt
	CASE profile_type
		WHEN 'legger'
			THEN '0 ' || greatest((b.streefpeil_bwn2 - a.bed_level),0.5) 
		WHEN 'getabuleerde breedte en bodemhoogte'
			THEN tabulated_height
	END as height 													 																		-- <- hier wordt legger gebruikt
FROM deelgebied.channel as a, deelgebied.fixeddrainagelevelarea as b
WHERE ST_Intersects(ST_LineInterpolatePoint(a.geom,0.5), b.geom) 
	AND ST_Length(a.geom) <= 40
;
CREATE INDEX deelgebied_tmp_channel_crs_geom ON deelgebied.tmp_channel_crs USING gist(the_geom);

-- koppel de channel-profielen aan de overgebleven branches en voeg de profielen toe aan tmp_crossprofile
INSERT INTO deelgebied.tmp_v2_cross_section_location
SELECT distinct on(a.id) a.id, b.reach_id as channel_id, a.definition_id, a.reference_level, a.friction_type, 
       a.friction_value, a.bank_level, a.the_geom, a.code, a.shape, a.width, a.height, b.channel_type_reach_id, null
  FROM deelgebied.tmp_channel_crs as a, deelgebied.tmp_sel_branches_without_structures as b
  WHERE ST_Intersects(b.bufgeom,a.the_geom) 
	AND b.reach_id NOT IN (SELECT channel_id FROM deelgebied.tmp_v2_cross_section_location)
  ;


-- zoek branches die niet gekoppeld zijn aan een profiel en pak er een uit dezelfde channel_type_reach
ALTER TABLE deelgebied.tmp_channel_crs DROP COLUMN IF EXISTS channel_type_reach_id;
ALTER TABLE deelgebied.tmp_channel_crs ADD COLUMN channel_type_reach_id integer;
UPDATE deelgebied.tmp_channel_crs as a
SET channel_type_reach_id = b.channel_type_reach_id
FROM deelgebied.channel_typeunion as b
WHERE ST_Intersects(b.bufgeom,a.the_geom)
;


INSERT INTO deelgebied.tmp_v2_cross_section_location(
            id, channel_id, definition_id, reference_level, friction_type, 
            friction_value, bank_level, the_geom, code, shape, width, height, 
            channel_type_reach_id)
SELECT DISTINCT ON (a.reach_id) nextval('crsserial') as id,
	a.reach_id as channel_id, 
	b.definition_id, b.reference_level, b.friction_type, b.friction_value, b.bank_level, ST_LineInterpolatePoint(a.geom,0.5) as the_geom, b.code, b.shape, b.width, b.height,
	a.channel_type_reach_id
FROM deelgebied.tmp_sel_branches_without_structures as a
LEFT JOIN deelgebied.tmp_channel_crs as b 
ON a.channel_type_reach_id = b.channel_type_reach_id
WHERE b.channel_type_reach_id IS NOT NULL
	AND reach_id NOT IN (SELECT channel_id FROM deelgebied.tmp_v2_cross_section_location)
ORDER BY a.reach_id ASC, ST_Distance(a.pointgeom,b.the_geom) ASC
;


-- zoek branches die niet gekoppeld zijn aan een profiel en pas hier het dichtsbijzijnde profiel toe
INSERT INTO deelgebied.tmp_v2_cross_section_location(
            id, channel_id, definition_id, reference_level, friction_type, 
            friction_value, bank_level, the_geom, code, shape, width, height, 
            channel_type_reach_id)
SELECT DISTINCT ON (a.reach_id) nextval('crsserial') as id,
	a.reach_id as channel_id, 
	b.definition_id, b.reference_level, b.friction_type, b.friction_value, b.bank_level, ST_LineINterpolatePoint(a.geom,0.5) as the_geom, b.code, b.shape, b.width, b.height,
	a.channel_type_reach_id
FROM deelgebied.tmp_sel_branches_without_structures as a
LEFT JOIN deelgebied.tmp_channel_crs as b 
ON ST_DWithin(a.geom,b.the_geom,20)
WHERE b.definition_id IS NOT NULL
	AND reach_id NOT IN (SELECT channel_id FROM deelgebied.tmp_v2_cross_section_location)
ORDER BY a.reach_id ASC, ST_Distance(a.pointgeom,b.the_geom) ASC
;



-- maak profiel definitions voor de channel-profielen
--DELETE FROM deelgebied.tmp_v2_cross_section_definition
INSERT INTO deelgebied.tmp_v2_cross_section_definition(
            id, shape, width, height, code)
SELECT DISTINCT ON (definition_id) definition_id, shape, width, height, code
FROM deelgebied.tmp_v2_cross_section_location
WHERE code LIKE 'HO%'
;




-- fix als location niet op lijn ligt
UPDATE deelgebied.tmp_v2_cross_section_location as a
SET the_geom = ST_LineInterpolatePoint(b.geom,0.5)
FROM deelgebied.tmp_sel_branches_without_structures as b
WHERE a.channel_id = b.reach_id AND ST_Linelocatepoint(b.geom,a.the_geom) NOT BETWEEN 0.01 AND 0.99
;


--SET PRIORITY
--1 REMOVE LEGGER IF THERE IS ANY OTHER PROFILE WITH THE SAME channel_id
--2 REMOVE MEASURED PROFILE IF THER IS A TABULATED PROFILE WITH THE SAME channel_id


-- Sommige crs liggen niet op een v2_channel vertex -- TABEL v2_channel MOET EERST ZIJN GEVULD!
CREATE OR REPLACE FUNCTION intersects_channel(
    x_sec_geom geometry, 
    x_sec_channel_id integer)
  RETURNS integer AS
$$
DECLARE
  result integer;
BEGIN
    SELECT COUNT(*)::integer FROM deelgebied.tmp_sel_branches_without_structures AS c
    WHERE ($2 = c.reach_id)
    -- AND (ST_Intersects(c.the_geom, $1))
    INTO result;
    IF result > 0 THEN
       UPDATE
          deelgebied.tmp_sel_branches_without_structures
       SET
          geom = ST_LineMerge(
           ST_SnapToGrid(
             ST_Union(
                ST_LineSubstring(tmp_sel_branches_without_structures.geom, 0, ST_LineLocatePoint(tmp_sel_branches_without_structures.geom, $1)),
                ST_LineSubstring(tmp_sel_branches_without_structures.geom, ST_LineLocatePoint(tmp_sel_branches_without_structures.geom, $1), 1)
             ),0,0,0.05,0.05))
        WHERE ($2 = tmp_sel_branches_without_structures.reach_id);
    END IF;
    return result;
END
$$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
  ALTER FUNCTION intersects_channel(geometry, integer)
  OWNER TO postgres;

-- VOEG VERTICES TOE AAN v2_channel
SELECT intersects_channel(the_geom,channel_id::integer) FROM deelgebied.tmp_v2_cross_section_location; --Duurt 8 minuten voor heel hhnk

-- simplify in case of vertices close to each other
UPDATE deelgebied.tmp_sel_branches_without_structures SET geom = ST_RemoveRepeatedPoints(geom);

-- ook snap to grid voor deelgebied.tmp_v2_cross_section_location en deelgebied.tmp_connection_nodes_structures!
UPDATE deelgebied.tmp_v2_cross_section_location set the_geom = ST_SnapToGrid(the_geom,0,0,0.05,0.05);
UPDATE deelgebied.tmp_connection_nodes_structures set the_geom = ST_SnapToGrid(the_geom,0,0,0.05,0.05);




-- CHECK:
--SELECT * FROM deelgebied.tmp_v2_cross_section_location WHERE definition_id NOT IN (SELECT id FROM deelgebied.tmp_v2_cross_section_definition);
--SELECT * FROM deelgebied.tmp_sel_branches_without_structures WHERE reach_id NOT IN (SELECT channel_id FROM deelgebied.tmp_v2_cross_section_location);