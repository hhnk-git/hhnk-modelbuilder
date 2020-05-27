-- DEEL I:      onderbemaling en onderbemalingen (peilafwijkingen) detecteren ahv streefpeil_bwn2 + peilgebieden die het hoogste of laagste zijn tov omliggende vakken
-- DEEL II:     1m buffer zoekactie: de selectie uit DEEL I gaan checken of ze kunnen afvoeren (hoogste peilen moeten een stuw of duiker op grens hebben, laagste peilen moeten een gemaal hebben)
-- DEEL III:    niet doen: 10m buffer zoekactie: de selectie uit DEEL I gaan checken of ze kunnen afvoeren (hoogste peilen moeten een stuw of duiker op grens hebben, laagste peilen moeten een gemaal hebben)



-- DEEL I
--explode fixceddrainagelevelares multipolygons to single parts want deelgebied.fixeddrainagelevelarea is facked_up;
DROP SEQUENCE serial;
CREATE SEQUENCE serial START 1;
DROP TABLE IF EXISTS tmp.fdla_EXPLODE;
CREATE TABLE tmp.fdla_EXPLODE AS
SELECT 
    nextval('serial') as id, 
    name,
    peil_id,
    code,
    type,
    water_level_summer,
    water_level_winter,
    water_level_fixed,
    water_level_flexible,
    streefpeil_bwn2,
    streefpeil_bwn2_source,
    ST_Buffer((ST_Dump(geom)).geom,0) as geom
FROM checks.fixeddrainagelevelarea;

DROP INDEX IF EXISTS tmp.fdla_EXPLODE_geom;
CREATE INDEX fdla_EXPLODE_geom on tmp.fdla_EXPLODE using gist(geom);

DROP TABLE IF EXISTS tmp.min_max_neighbours;
CREATE TABLE tmp.min_max_neighbours as 
SELECT 	a.id as a_id, 
	b.id as b_id,
	NULL::varchar(50) as a_code,
    NULL::varchar(50) as b_code,
    NULL::float as a_wlevel,
	NULL::float as b_wlevel,
    NULL::float as max_b_wlevel,
    NULL::float as min_b_wlevel
FROM tmp.fdla_EXPLODE AS a
JOIN tmp.fdla_EXPLODE b
ON ST_Touches(a.geom, b.geom) 
WHERE a.id != b.id
; -- 133 sec

UPDATE tmp.min_max_neighbours a SET 
    a_code = c.code,
    a_wlevel = c.streefpeil_bwn2
FROM tmp.fdla_EXPLODE c 
WHERE a.a_id = c.id;

UPDATE tmp.min_max_neighbours a SET 
    b_code = c.code,
    b_wlevel = c.streefpeil_bwn2
FROM tmp.fdla_EXPLODE c 
WHERE a.b_id = c.id;

UPDATE tmp.min_max_neighbours a SET max_b_wlevel = 
    (
    SELECT max(b_wlevel) 
    FROM tmp.min_max_neighbours c 
    WHERE a.a_id = c.a_id
    )
; -- 70 sec    

UPDATE tmp.min_max_neighbours a SET min_b_wlevel = 
    (
    SELECT min(b_wlevel) 
    FROM tmp.min_max_neighbours c 
    WHERE a.a_id = c.a_id
    )
; -- 70 sec
-- tot hier 490 sec

DROP TABLE IF EXISTS tmp.tmp_peilgebieden_neighbours;
CREATE TABLE tmp.tmp_peilgebieden_neighbours AS
SELECT  
    a.*, -- hierin zit dus ook type (1=peilgebied, 2=peilafwijking), en name in (waardoor we kunnen filteren op %boezem%)
	b.max_b_wlevel as max_neighbor,
	b.min_b_wlevel as min_neighbor,
	FALSE::boolean as onderbemaling,
	FALSE::boolean as opmaling,
    FALSE::boolean as peilgebied_hoogst,
    FALSE::boolean as peilgebied_laagst,
	FALSE::boolean as gemaal_op_grens,
	FALSE::boolean as stuw_op_grens,
	FALSE::boolean as duiker_op_grens,
	FALSE::boolean as isusable
FROM tmp.fdla_EXPLODE as a
JOIN tmp.min_max_neighbours as b
ON a.id = b.a_id
; -- 10 sec





-- DEEL II: 1meter buffer zoekactie: de selectie uit DEEL I gaan checken of ze kunnen afvoeren (hoogste peilen moeten een stuw of duiker op grens hebben, laagste peilen moeten een gemaal hebben)

-- gemaal op grens? (1m bufgeom peilgrens)
DROP TABLE IF EXISTS tmp.peilgebieden_neighbours_1m;
CREATE TABLE tmp.peilgebieden_neighbours_1m AS SELECT DISTINCT ON (id) * FROM tmp.tmp_peilgebieden_neighbours;

DROP INDEX IF EXISTS tmp.peilgebieden_neighbours_1m_geom;
CREATE INDEX peilgebieden_neighbours_1m_geom on tmp.peilgebieden_neighbours_1m using gist(geom);

UPDATE tmp.peilgebieden_neighbours_1m 
SET opmaling = TRUE 
WHERE streefpeil_bwn2 > max_neighbor 
AND type = 2
; --1sec

UPDATE tmp.peilgebieden_neighbours_1m 
SET onderbemaling = TRUE 
WHERE streefpeil_bwn2 < min_neighbor 
AND type = 2
; --1sec

UPDATE tmp.peilgebieden_neighbours_1m 
SET peilgebied_hoogst = TRUE 
WHERE streefpeil_bwn2 > max_neighbor 
AND type = 1
AND lower(name) NOT LIKE '%boezem%';
--1sec

UPDATE tmp.peilgebieden_neighbours_1m 
SET peilgebied_laagst = TRUE 
WHERE streefpeil_bwn2 < min_neighbor 
AND type = 1
AND lower(name) NOT LIKE '%boezem%';
--1sec

ALTER TABLE tmp.peilgebieden_neighbours_1m DROP COLUMN IF EXISTS bufgeom;
ALTER TABLE tmp.peilgebieden_neighbours_1m ADD COLUMN bufgeom geometry;

UPDATE tmp.peilgebieden_neighbours_1m 
SET bufgeom = ST_Buffer(ST_ExteriorRing(ST_GeometryN(geom,1)),1)
WHERE (opmaling OR onderbemaling OR peilgebied_hoogst OR peilgebied_laagst);
-- 4 sec

DROP INDEX IF EXISTS tmp.peilgebieden_neighbours_1m_bufgeom;
CREATE INDEX peilgebieden_neighbours_1m_bufgeom on tmp.peilgebieden_neighbours_1m using gist(bufgeom);

UPDATE tmp.peilgebieden_neighbours_1m a 
SET gemaal_op_grens = TRUE 
FROM checks.pumpstation b
WHERE (opmaling OR onderbemaling OR peilgebied_hoogst OR peilgebied_laagst) 
AND st_intersects(a.bufgeom, b.geom)
; -- 1sec

-- stuw op grens? (1m bufgeom peilgrens)
UPDATE tmp.peilgebieden_neighbours_1m a 
SET stuw_op_grens = TRUE 
FROM checks.weirs b
WHERE (opmaling OR onderbemaling OR peilgebied_hoogst OR peilgebied_laagst)
AND st_intersects(a.bufgeom, b.geom)
;-- 1sec

-- duiker (geen sifon) op grens? (1m bufgeom peilgrens)
UPDATE tmp.peilgebieden_neighbours_1m a 
SET duiker_op_grens = TRUE 
FROM checks.culvert b
WHERE (opmaling OR onderbemaling OR peilgebied_hoogst OR peilgebied_laagst) 
AND b.type_art= 1
AND st_intersects(a.bufgeom, b.geom)
;-- 1sec

ALTER TABLE tmp.peilgebieden_neighbours_1m DROP COLUMN IF EXISTS opmerking_peil;
ALTER TABLE tmp.peilgebieden_neighbours_1m ADD COLUMN opmerking_peil varchar(200);

UPDATE tmp.peilgebieden_neighbours_1m 
SET opmerking_peil = 'onderbemaling zonder gemaal', isusable = FALSE
WHERE type = 2 
AND onderbemaling 
AND gemaal_op_grens = FALSE;

UPDATE tmp.peilgebieden_neighbours_1m 
SET opmerking_peil = 'opmaling zonder stuw of duiker', isusable = FALSE 
WHERE type = 2 
AND opmaling 
AND stuw_op_grens = FALSE 
AND duiker_op_grens = FALSE;

UPDATE tmp.peilgebieden_neighbours_1m 
SET opmerking_peil = 'laagste peilgebied zonder gemaal', isusable = FALSE
WHERE type = 1 
AND peilgebied_laagst 
AND gemaal_op_grens = FALSE;

UPDATE tmp.peilgebieden_neighbours_1m 
SET opmerking_peil = 'hoogste peilgebied zonder stuw of duiker', isusable = FALSE 
WHERE type = 1 
AND peilgebied_hoogst 
AND stuw_op_grens = FALSE 
AND duiker_op_grens = FALSE;

-- SELECT count(*) FROM tmp.peilgebieden_neighbours_1m WHERE TYPE = 1 AND isusable is FALSE; -- 1612 vd 2953
-- SELECT count(*) FROM tmp.peilgebieden_neighbours_1m WHERE TYPE = 2 AND isusable is FALSE; -- 88 vd 2488

ALTER TABLE tmp.peilgebieden_neighbours_1m DROP COLUMN IF EXISTS midpoint;
ALTER TABLE tmp.peilgebieden_neighbours_1m ADD COLUMN midpoint geometry;











/*
-- DEEL III: 10meter buffer zoekactie: de selectie uit DEEL I gaan checken of ze kunnen afvoeren (hoogste peilen moeten een stuw of duiker op grens hebben, laagste peilen moeten een gemaal hebben)

-- gemaal op grens? (10m bufgeom peilgrens)
DROP TABLE IF EXISTS tmp.peilgebieden_neighbours_10m;
CREATE TABLE tmp.peilgebieden_neighbours_10m AS SELECT DISTINCT ON (id) * FROM tmp.tmp_peilgebieden_neighbours;

DROP INDEX IF EXISTS tmp.peilgebieden_neighbours_10m_geom;
CREATE INDEX peilgebieden_neighbours_10m_geom on tmp.peilgebieden_neighbours_10m using gist(geom);

UPDATE tmp.peilgebieden_neighbours_10m 
SET opmaling = TRUE 
WHERE streefpeil_bwn2 > max_neighbor 
AND type = 2
; --1sec

UPDATE tmp.peilgebieden_neighbours_10m 
SET onderbemaling = TRUE 
WHERE streefpeil_bwn2 < min_neighbor 
AND type = 2
; --1sec

UPDATE tmp.peilgebieden_neighbours_10m 
SET peilgebied_hoogst = TRUE 
WHERE streefpeil_bwn2 > max_neighbor 
AND type = 1
AND lower(name) NOT LIKE '%boezem%';
; --1sec

UPDATE tmp.peilgebieden_neighbours_10m 
SET peilgebied_laagst = TRUE 
WHERE streefpeil_bwn2 < min_neighbor 
AND type = 1
AND lower(name) NOT LIKE '%boezem%';
; --1sec

ALTER TABLE tmp.peilgebieden_neighbours_10m DROP COLUMN IF EXISTS bufgeom;
ALTER TABLE tmp.peilgebieden_neighbours_10m ADD COLUMN bufgeom geometry;

UPDATE tmp.peilgebieden_neighbours_10m 
SET bufgeom = ST_Buffer(ST_ExteriorRing(ST_GeometryN(geom,1)),10)
WHERE (opmaling OR onderbemaling OR peilgebied_hoogst OR peilgebied_laagst);
; -- 4 sec

DROP INDEX IF EXISTS tmp.peilgebieden_neighbours_10m_bufgeom;
CREATE INDEX peilgebieden_neighbours_10m_bufgeom on tmp.peilgebieden_neighbours_10m using gist(bufgeom);

UPDATE tmp.peilgebieden_neighbours_10m a 
SET gemaal_op_grens = TRUE 
FROM checks.pumpstation b
WHERE (opmaling OR onderbemaling OR peilgebied_hoogst OR peilgebied_laagst) 
AND st_intersects(a.bufgeom, b.geom)
; -- 1sec

-- stuw op grens? (1m bufgeom peilgrens)
UPDATE tmp.peilgebieden_neighbours_10m a 
SET stuw_op_grens = TRUE 
FROM checks.weirs b
WHERE (opmaling OR onderbemaling OR peilgebied_hoogst OR peilgebied_laagst)
AND st_intersects(a.bufgeom, b.geom)
;-- 1sec

-- duiker (geen sifon) op grens? (1m bufgeom peilgrens)
UPDATE tmp.peilgebieden_neighbours_10m a 
SET duiker_op_grens = TRUE 
FROM checks.culvert b
WHERE (opmaling OR onderbemaling OR peilgebied_hoogst OR peilgebied_laagst) 
AND b.type_art= 1
AND st_intersects(a.bufgeom, b.geom)
;-- 1sec

ALTER TABLE tmp.peilgebieden_neighbours_10m DROP COLUMN IF EXISTS opmerking_peil;
ALTER TABLE tmp.peilgebieden_neighbours_10m ADD COLUMN opmerking_peil varchar(200);

UPDATE tmp.peilgebieden_neighbours_10m 
SET opmerking_peil = 'peilafwijking (onderbemaling) bruikbaar', isusable = TRUE
WHERE type = 2 
AND onderbemaling 
AND gemaal_op_grens = TRUE;

UPDATE tmp.peilgebieden_neighbours_10m 
SET opmerking_peil = 'peilafwijking (onderbemaling) niet bruikbaar', isusable = FALSE
WHERE type = 2 
AND onderbemaling 
AND gemaal_op_grens = FALSE;

UPDATE tmp.peilgebieden_neighbours_10m 
SET opmerking_peil = 'peilafwijking (opmaling) bruikbaar', isusable = TRUE
WHERE type = 2 
AND opmaling 
AND (stuw_op_grens = TRUE OR duiker_op_grens = TRUE);

UPDATE tmp.peilgebieden_neighbours_10m 
SET opmerking_peil = 'peilafwijking (opmaling) niet bruikbaar', isusable = FALSE 
WHERE type = 2 
AND opmaling 
AND stuw_op_grens = FALSE 
AND duiker_op_grens = FALSE;

UPDATE tmp.peilgebieden_neighbours_10m 
SET opmerking_peil = 'peilgebied (laagste) bruikbaar', isusable = TRUE  
WHERE type = 1 
AND peilgebied_laagst
AND gemaal_op_grens = TRUE;

UPDATE tmp.peilgebieden_neighbours_10m 
SET opmerking_peil = 'peilgebied (laagste) niet bruikbaar', isusable = FALSE
WHERE type = 1 
AND peilgebied_laagst 
AND gemaal_op_grens = FALSE;

UPDATE tmp.peilgebieden_neighbours_10m 
SET opmerking_peil = 'peilgebied (hoogste) bruikbaar', isusable = TRUE
WHERE type = 1 
AND peilgebied_hoogst 
AND (stuw_op_grens = TRUE OR duiker_op_grens = TRUE);

UPDATE tmp.peilgebieden_neighbours_10m 
SET opmerking_peil = 'peilgebied (hoogste) niet bruikbaar', isusable = FALSE 
WHERE type = 1 
AND peilgebied_hoogst 
AND stuw_op_grens = FALSE 
AND duiker_op_grens = FALSE;

DROP TABLE IF EXISTS tmp.boezem;
CREATE TABLE tmp.boezem AS
SELECT * FROM tmp.peilgebieden_neighbours_10m 
WHERE lower(name) LIKE '%boezem%'; 
*/

-- SELECT count(*) FROM tmp.peilgebieden_neighbours_1m WHERE TYPE = 1 AND isusable is FALSE; -- 1612 vd 2953
-- SELECT count(*) FROM tmp.peilgebieden_neighbours_1m WHERE TYPE = 2 AND isusable is FALSE; -- 88 vd 2488

/* -- opmerking checks updaten 
UPDATE checks.fixeddrainagelevelarea a 
SET opmerking = concat_ws(',',a.opmerking,b.opmerking_peil)
FROM tmp.peilgebieden_neighbours_1m b
WHERE a.code LIKE b.code
AND b.opmerking_peil IS NOT NULL;
*/

DROP TABLE IF EXISTS checks.fdla_sp_nowayout;
CREATE TABLE checks.fdla_sp_nowayout AS(
	SELECT * FROM tmp.peilgebieden_neighbours_1m
);
CREATE INDEX checks_fdla_sp_nowayout ON checks.fdla_sp_nowayout USING gist(geom);

-- tabellen weggooien
DROP TABLE IF EXISTS tmp.min_max_neighbours;
DROP TABLE IF EXISTS tmp.tmp_min_max_neighbours;
DROP TABLE IF EXISTS tmp.peilafwijking_conflict;
DROP TABLE IF EXISTS tmp.tmp_peilgebieden_neighbours_1m;
DROP TABLE IF EXISTS tmp.peilgebieden_neighbours_1m; 
DROP TABLE IF EXISTS tmp.peilgebieden_neighbours_10m; 
DROP TABLE IF EXISTS tmp.boezem;


