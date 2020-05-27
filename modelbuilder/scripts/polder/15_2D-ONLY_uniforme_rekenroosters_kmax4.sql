-- DIT SCRIPT BESTAAT UIT TWEE DELEN
-- DEEL I = uniforme rekenroosters maken over het hele studiegebied voor alle refinement_levels (kmax en gridspace opgeven!) --> duurt lang!!
-- DEEL II = grid refinement maken en daarna quadtree maken -- duurt kort!!
-- ADVIES = draai DEEL 1 slecht eenmaal, en daarna kun je DEEL II steeds opnieuw aanzetten (met steeds andere voorkeuren voor grid_refiment)

--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- DEEL I (uniforme rekenroosters maken)
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- FUNCTION TO CREATE FISHNET
CREATE OR REPLACE FUNCTION ST_CreateFishnet(
        nrow integer, ncol integer,
        xsize float8, ysize float8,
        x0 float8 DEFAULT 0, y0 float8 DEFAULT 0,
        OUT "row" integer, OUT col integer,
        OUT geom geometry)
    RETURNS SETOF record AS
$$
SELECT i + 1 AS row, j + 1 AS col, ST_Translate(cell, j * $3 + $5, i * $4 + $6) AS geom
FROM generate_series(0, $1 - 1) AS i,
     generate_series(0, $2 - 1) AS j,
(
SELECT ('POLYGON((0 0, 0 '||$4||', '||$3||' '||$4||', '||$3||' 0,0 0))')::geometry AS cell
) AS foo;
$$ LANGUAGE sql IMMUTABLE STRICT;

-- kmax, gridspace tabel maken
DROP SEQUENCE IF EXISTS k;
CREATE SEQUENCE k MINVALUE 1 INCREMENT BY 1;
drop table if exists tmp.gridspace_kmax;
create table tmp.gridspace_kmax as select nextval('k')::integer as k, NULL::integer as grid_size from generate_series(1,10) i;
-- INVULLEN GRID_SPACE en K_MAX in regel hieronder!!
with parameters as (select 20 as grid_space, 4 as kmax) --> standaard bwn = 20x20, 40x40, 80x80, 160x160m cellen.
update tmp.gridspace_kmax a set grid_size = b.grid_space from parameters b where a.k <= b.kmax;
delete from tmp.gridspace_kmax where grid_size is null;
update tmp.gridspace_kmax set grid_size = grid_size*2^(k-1);
select * from tmp.gridspace_kmax order by k;

/*
where nrow and ncol are the number of rows and columns, xsize and ysize are the lengths of the cell size, and optional x0 and y0 are coordinates for the bottom-left corner.
The result is row and col numbers, starting from 1 at the bottom-left corner, and geom rectangular polygons for each cell. 

So for example:
*/

-- een kmax+1 rekenrooster maken 
drop table if exists tmp.box;
create table tmp.box as 
SELECT  split_part(split_part(ST_Extent(geom)::varchar, '(', 2),' ',1)::numeric as x0, 
        split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',1)::numeric as y0,
		split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',2)::numeric as xm, 
        substring(split_part(split_part(ST_Extent(geom)::varchar, ',', 2),' ',2) FROM '[0-9]+.[0-9]+')::numeric as ym, 
		geom
FROM (SELECT polder_id, ST_Union(geom) as geom FROM deelgebied.polder GROUP BY polder_id) as foo -- REPLACE WITH YOUR EXTENT SHAPEFILE
--FROM (SELECT polder_id, ST_Buffer(ST_Union(geom),10) as geom FROM deelgebied.polder GROUP BY polder_id) as foo -- REPLACE WITH YOUR EXTENT SHAPEFILE
GROUP BY polder_id, geom;
drop table if exists tmp.net;
create table tmp.net as 
with grid_size as (select grid_size*2 as size from tmp.gridspace_kmax where k=4) -- kmax+1 <-- als wij kmax=4 dan hebben een tmp.k5 rekenrooster nodig voor het querien
SELECT 	ST_SetSRID((ST_Dump(ST_Collect(cells.geom))).geom,28992) as geom FROM ST_CreateFishnet(
		(SELECT ceil((ym-y0)/size)::integer FROM grid_size, tmp.box),
		(SELECT ceil((xm-x0)/size)::integer FROM grid_size, tmp.box),
		(SELECT size FROM grid_size),
		(SELECT size FROM grid_size),
		(SELECT x0 FROM tmp.box),
		(SELECT y0 FROM tmp.box)
		) AS cells;
DROP SEQUENCE IF EXISTS id;
CREATE SEQUENCE id RESTART WITH 1; 
DROP TABLE IF EXISTS tmp.k5; -- CHANGE tmp.k to K YOU WANT
CREATE TABLE tmp.k5 AS SELECT b.geom, nextval('id') as pk -- CHANGE tmp.k to K YOU WANT
FROM tmp.box as a, tmp.net as b
WHERE ST_Intersects(a.geom,b.geom)
; -- 4sec

-- now create polygon of outerring of largest cells (exterior ring of tmp.k5 )
drop table if exists tmp.outerring;
create table tmp.outerring as select 1::integer as id, 
st_setsrid(ST_MakePolygon(ST_ExteriorRing((ST_Dump(ST_Union(ST_Force2D(ST_Transform(geom,28992))))).geom)),28992)::geometry(Polygon,28992) as geom 
from tmp.k5;

-- k4 rekenrooster maken
drop table if exists tmp.box;
create table tmp.box as 
SELECT  	split_part(split_part(ST_Extent(geom)::varchar, '(', 2),' ',1)::numeric as x0, split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',1)::numeric as y0,
		split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',2)::numeric as xm, substring(split_part(split_part(ST_Extent(geom)::varchar, ',', 2),' ',2) FROM '[0-9]+.[0-9]+')::numeric as ym, 
		geom
FROM tmp.outerring -- REPLACE WITH YOUR EXTENT SHAPEFILE
GROUP BY id, geom;
drop table if exists tmp.net;
create table tmp.net as 
with grid_size as (select grid_size as size from tmp.gridspace_kmax where k=4) -- CHANGE TO K YOU WANT
SELECT 	ST_SetSRID((ST_Dump(ST_Collect(cells.geom))).geom,28992) as geom FROM ST_CreateFishnet(
		(SELECT ceil((ym-y0)/size)::integer FROM grid_size, tmp.box),
		(SELECT ceil((xm-x0)/size)::integer FROM grid_size, tmp.box),
		(SELECT size FROM grid_size),
		(SELECT size FROM grid_size),
		(SELECT x0 FROM tmp.box),
		(SELECT y0 FROM tmp.box)
		) AS cells;
DROP SEQUENCE IF EXISTS id;
CREATE SEQUENCE id RESTART WITH 1; 
DROP TABLE IF EXISTS tmp.k4; -- CHANGE tmp.k to K YOU WANT
CREATE TABLE tmp.k4 AS SELECT b.geom, nextval('id') as pk -- CHANGE tmp.k to K YOU WANT 
FROM tmp.box as a, tmp.net as b
WHERE ST_Intersects(a.geom,b.geom)
; -- 7sec

-- k3 rekenrooster maken
drop table if exists tmp.box;
create table tmp.box as 
SELECT  	split_part(split_part(ST_Extent(geom)::varchar, '(', 2),' ',1)::numeric as x0, split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',1)::numeric as y0,
		split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',2)::numeric as xm, substring(split_part(split_part(ST_Extent(geom)::varchar, ',', 2),' ',2) FROM '[0-9]+.[0-9]+')::numeric as ym, 
		geom
FROM tmp.outerring -- REPLACE WITH YOUR EXTENT SHAPEFILE
GROUP BY id, geom;
drop table if exists tmp.net;
create table tmp.net as 
with grid_size as (select grid_size as size from tmp.gridspace_kmax where k=3) -- CHANGE TO K YOU WANT
SELECT 	ST_SetSRID((ST_Dump(ST_Collect(cells.geom))).geom,28992) as geom FROM ST_CreateFishnet(
		(SELECT ceil((ym-y0)/size)::integer FROM grid_size, tmp.box),
		(SELECT ceil((xm-x0)/size)::integer FROM grid_size, tmp.box),
		(SELECT size FROM grid_size),
		(SELECT size FROM grid_size),
		(SELECT x0 FROM tmp.box),
		(SELECT y0 FROM tmp.box)
		) AS cells;
DROP SEQUENCE IF EXISTS id;
CREATE SEQUENCE id RESTART WITH 1; 
DROP TABLE IF EXISTS tmp.k3; -- CHANGE tmp.k to K YOU WANT
CREATE TABLE tmp.k3 AS SELECT b.geom, nextval('id') as pk -- CHANGE tmp.k to K YOU WANT 
FROM tmp.box as a, tmp.net as b
WHERE ST_Intersects(a.geom,b.geom)
; -- 7sec

-- k2 rekenrooster maken
drop table if exists tmp.box;
create table tmp.box as 
SELECT  	split_part(split_part(ST_Extent(geom)::varchar, '(', 2),' ',1)::numeric as x0, split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',1)::numeric as y0,
		split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',2)::numeric as xm, substring(split_part(split_part(ST_Extent(geom)::varchar, ',', 2),' ',2) FROM '[0-9]+.[0-9]+')::numeric as ym, 
		geom
FROM tmp.outerring -- REPLACE WITH YOUR EXTENT SHAPEFILE
GROUP BY id, geom;
drop table if exists tmp.net;
create table tmp.net as 
with grid_size as (select grid_size as size from tmp.gridspace_kmax where k=2) -- CHANGE TO K YOU WANT
SELECT 	ST_SetSRID((ST_Dump(ST_Collect(cells.geom))).geom,28992) as geom FROM ST_CreateFishnet(
		(SELECT ceil((ym-y0)/size)::integer FROM grid_size, tmp.box),
		(SELECT ceil((xm-x0)/size)::integer FROM grid_size, tmp.box),
		(SELECT size FROM grid_size),
		(SELECT size FROM grid_size),
		(SELECT x0 FROM tmp.box),
		(SELECT y0 FROM tmp.box)
		) AS cells;
DROP SEQUENCE IF EXISTS id;
CREATE SEQUENCE id RESTART WITH 1; 
DROP TABLE IF EXISTS tmp.k2; -- CHANGE tmp.k to K YOU WANT
CREATE TABLE tmp.k2 AS SELECT b.geom, nextval('id') as pk -- CHANGE tmp.k to K YOU WANT 
FROM tmp.box as a, tmp.net as b
WHERE ST_Intersects(a.geom,b.geom)
; -- 7sec

-- k1 rekenrooster maken
drop table if exists tmp.box;
create table tmp.box as 
SELECT  	split_part(split_part(ST_Extent(geom)::varchar, '(', 2),' ',1)::numeric as x0, split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',1)::numeric as y0,
		split_part(split_part(ST_Extent(geom)::varchar, ' ', 2),',',2)::numeric as xm, substring(split_part(split_part(ST_Extent(geom)::varchar, ',', 2),' ',2) FROM '[0-9]+.[0-9]+')::numeric as ym, 
		geom
FROM tmp.outerring -- REPLACE WITH YOUR EXTENT SHAPEFILE
GROUP BY id, geom;
drop table if exists tmp.net;
create table tmp.net as 
with grid_size as (select grid_size as size from tmp.gridspace_kmax where k=1) -- CHANGE TO K YOU WANT
SELECT 	ST_SetSRID((ST_Dump(ST_Collect(cells.geom))).geom,28992) as geom FROM ST_CreateFishnet(
		(SELECT ceil((ym-y0)/size)::integer FROM grid_size, tmp.box),
		(SELECT ceil((xm-x0)/size)::integer FROM grid_size, tmp.box),
		(SELECT size FROM grid_size),
		(SELECT size FROM grid_size),
		(SELECT x0 FROM tmp.box),
		(SELECT y0 FROM tmp.box)
		) AS cells;
DROP SEQUENCE IF EXISTS id;
CREATE SEQUENCE id RESTART WITH 1; 
DROP TABLE IF EXISTS tmp.k1; -- CHANGE tmp.k to K YOU WANT
CREATE TABLE tmp.k1 AS SELECT b.geom, nextval('id') as pk -- CHANGE tmp.k to K YOU WANT 
FROM tmp.box as a, tmp.net as b
WHERE ST_Intersects(a.geom,b.geom)
; -- 7sec

DROP INDEX IF EXISTS tmp.k3_index_geom;
CREATE INDEX k3_index_geom ON tmp.k3 USING gist(geom);
DROP INDEX IF EXISTS tmp.k2_index_geom;
CREATE INDEX k2_index_geom ON tmp.k2 USING gist(geom);
DROP INDEX IF EXISTS tmp.k1_index_geom;
CREATE INDEX k1_index_geom ON tmp.k1 USING gist(geom); -- 12sec

--explode fixceddrainagelevelares multipolygons to single parts want deelgebied.fixeddrainagelevelarea is facked_up;
DROP SEQUENCE serial;
CREATE SEQUENCE serial START 1;
DROP TABLE IF EXISTS tmp.fdla_EXPLODE;
CREATE TABLE tmp.fdla_EXPLODE AS
SELECT nextval('serial') as id, code, streefpeil_bwn2, (ST_Dump(geom)).geom 
FROM deelgebied.fixeddrainagelevelarea;

-- koppel peilgebied aan watergangen
UPDATE tmp.fdla_EXPLODE SET geom = ST_Buffer(geom,0); --Fix fdla_explode polygonen
DROP TABLE IF EXISTS deelgebied.channel_peil;
CREATE TABLE deelgebied.channel_peil AS
SELECT DISTINCT ON (a.id) a.*, b.code as pgbcode, b.streefpeil_bwn2
FROM deelgebied.channel as a, tmp.fdla_EXPLODE as b
WHERE ST_Intersects(b.geom,a.geom) --GEBRUIK "WHERE ST_Intersects(ST_Buffer(b.geom,0),a.geom)" indien hij hierop crasht, duurt wel langer
ORDER BY a.id ASC, b.code DESC
;
CREATE INDEX deelgebied_channel_peil_geom ON deelgebied.channel_peil USING gist(geom);

-- voeg watergangen in hetzelfde peil samen
DROP TABLE IF EXISTS deelgebied.channel_peil_union;
CREATE TABLE deelgebied.channel_peil_union AS
SELECT ST_Union(geom) as geom, pgbcode, 1 as teller
FROM deelgebied.channel_peil
GROUP BY pgbcode
;
CREATE INDEX deelgebied_channel_peil_union_geom ON deelgebied.channel_peil_union USING gist(geom);

-- bekijk in welke cellen watergangen van hetzelfde peil zitten
DROP TABLE IF EXISTS tmp.k4_count;
CREATE TABLE tmp.k4_count AS
SELECT a.*, count(b.teller), max(maximum_water_level) as max_peil -- HIER STARKS LEVEE HEIGHT
FROM tmp.k4 as a 
LEFT JOIN deelgebied.channel_peil_union as b
ON ST_Intersects(a.geom,b.geom)
LEFT JOIN deelgebied.peilgrens_met_waterpeil as c
ON ST_Intersects(a.geom,c.geom)
GROUP BY a.pk, a.geom
;
DROP TABLE IF EXISTS tmp.k3_count;
CREATE TABLE tmp.k3_count AS
SELECT a.*, count(b.teller), max(maximum_water_level) as max_peil -- HIER STARKS LEVEE HEIGHT
FROM tmp.k3 as a 
LEFT JOIN deelgebied.channel_peil_union as b
ON ST_Intersects(a.geom,b.geom)
LEFT JOIN deelgebied.peilgrens_met_waterpeil as c
ON ST_Intersects(a.geom,c.geom)
GROUP BY a.pk, a.geom
;
DROP TABLE IF EXISTS tmp.k2_count;
CREATE TABLE tmp.k2_count AS
SELECT a.*, count(b.teller), max(maximum_water_level) as max_peil -- HIER STARKS LEVEE HEIGHT
FROM tmp.k2 as a 
LEFT JOIN deelgebied.channel_peil_union as b
ON ST_Intersects(a.geom,b.geom)
LEFT JOIN deelgebied.peilgrens_met_waterpeil as c
ON ST_Intersects(a.geom,c.geom)
GROUP BY a.pk, a.geom
; -- 35 sec
DROP TABLE IF EXISTS tmp.k1_count;
CREATE TABLE tmp.k1_count AS
SELECT a.*, count(b.teller), max(maximum_water_level) as max_peil -- HIER STARKS LEVEE HEIGHT
FROM tmp.k1 as a 
LEFT JOIN deelgebied.channel_peil_union as b
ON ST_Intersects(a.geom,b.geom)
LEFT JOIN deelgebied.peilgrens_met_waterpeil as c
ON ST_Intersects(a.geom,c.geom)
GROUP BY a.pk, a.geom
; --138sec

DROP INDEX IF EXISTS tmp.k5_index_pk;
CREATE INDEX k5_index_pk ON tmp.k5 USING btree(pk);
DROP INDEX IF EXISTS tmp.k4_index_pk;
CREATE INDEX k4_index_pk ON tmp.k4 USING btree(pk);
DROP INDEX IF EXISTS tmp.k3_index_pk;
CREATE INDEX k3_index_pk ON tmp.k3 USING btree(pk);
DROP INDEX IF EXISTS tmp.k2_index_pk;
CREATE INDEX k2_index_pk ON tmp.k2 USING btree(pk);
DROP INDEX IF EXISTS tmp.k1_index_pk;
CREATE INDEX k1_index_pk ON tmp.k1 USING btree(pk)
;

alter table tmp.k4 add column on_off_loop1 integer;
alter table tmp.k4 add column on_off_loop2 integer;
alter table tmp.k4 add column on_off_loop3 integer;
alter table tmp.k4 add column on_off_loop4 integer;

alter table tmp.k3 add column on_off_loop1 integer;
alter table tmp.k3 add column on_off_loop2 integer;
alter table tmp.k3 add column on_off_loop3 integer;
alter table tmp.k3 add column on_off_loop4 integer;

alter table tmp.k2 add column on_off_loop1 integer;
alter table tmp.k2 add column on_off_loop2 integer;
alter table tmp.k2 add column on_off_loop3 integer;
alter table tmp.k2 add column on_off_loop4 integer;

alter table tmp.k1 add column on_off_loop1 integer;
alter table tmp.k1 add column on_off_loop2 integer;
alter table tmp.k1 add column on_off_loop3 integer;
alter table tmp.k1 add column on_off_loop4 integer;

-- relatie leggen tussen bijv een k3 cell en haar 4 k2 cellen;
alter table tmp.k5 add column k4_1 integer;
alter table tmp.k5 add column k4_2 integer;
alter table tmp.k5 add column k4_3 integer;
alter table tmp.k5 add column k4_4 integer;

alter table tmp.k4 add column k3_1 integer;
alter table tmp.k4 add column k3_2 integer;
alter table tmp.k4 add column k3_3 integer;
alter table tmp.k4 add column k3_4 integer;

alter table tmp.k3 add column k2_1 integer;
alter table tmp.k3 add column k2_2 integer;
alter table tmp.k3 add column k2_3 integer;
alter table tmp.k3 add column k2_4 integer;

alter table tmp.k2 add column k1_1 integer;
alter table tmp.k2 add column k1_2 integer;
alter table tmp.k2 add column k1_3 integer;
alter table tmp.k2 add column k1_4 integer;

-- elke cel heeft vier kleine cellen. Bijv: k5 heeft k4_1, k4_2, k4_3 en k4_4.
-- een k4 cel heeft op zijn beurt ook weer 4 k3 cellen.. etc..
update tmp.k5 a set k4_1 = b.pk from tmp.k4 b where st_contains(a.geom, b.geom);
update tmp.k5 a set k4_2 = b.pk from tmp.k4 b where st_contains(a.geom, b.geom) and b.pk <> a.k4_1;
update tmp.k5 a set k4_3 = b.pk from tmp.k4 b where st_contains(a.geom, b.geom) and b.pk <> a.k4_1 and b.pk <> a.k4_2;
update tmp.k5 a set k4_4 = b.pk from tmp.k4 b where st_contains(a.geom, b.geom) and b.pk <> a.k4_1 and b.pk <> a.k4_2 and b.pk <> a.k4_3;

update tmp.k4 a set k3_1 = b.pk from tmp.k3 b where st_contains(a.geom, b.geom);
update tmp.k4 a set k3_2 = b.pk from tmp.k3 b where st_contains(a.geom, b.geom) and b.pk <> a.k3_1;
update tmp.k4 a set k3_3 = b.pk from tmp.k3 b where st_contains(a.geom, b.geom) and b.pk <> a.k3_1 and b.pk <> a.k3_2;
update tmp.k4 a set k3_4 = b.pk from tmp.k3 b where st_contains(a.geom, b.geom) and b.pk <> a.k3_1 and b.pk <> a.k3_2 and b.pk <> a.k3_3;

update tmp.k3 a set k2_1 = b.pk from tmp.k2 b where st_contains(a.geom, b.geom);
update tmp.k3 a set k2_2 = b.pk from tmp.k2 b where st_contains(a.geom, b.geom) and b.pk <> a.k2_1;
update tmp.k3 a set k2_3 = b.pk from tmp.k2 b where st_contains(a.geom, b.geom) and b.pk <> a.k2_1 and b.pk <> a.k2_2;
update tmp.k3 a set k2_4 = b.pk from tmp.k2 b where st_contains(a.geom, b.geom) and b.pk <> a.k2_1 and b.pk <> a.k2_2 and b.pk <> a.k2_3;

update tmp.k2 a set k1_1 = b.pk from tmp.k1 b where st_contains(a.geom, b.geom);
update tmp.k2 a set k1_2 = b.pk from tmp.k1 b where st_contains(a.geom, b.geom) and b.pk <> a.k1_1;
update tmp.k2 a set k1_3 = b.pk from tmp.k1 b where st_contains(a.geom, b.geom) and b.pk <> a.k1_1 and b.pk <> a.k1_2;
update tmp.k2 a set k1_4 = b.pk from tmp.k1 b where st_contains(a.geom, b.geom) and b.pk <> a.k1_1 and b.pk <> a.k1_2 and b.pk <> a.k1_3; -- tot hier 13 sec
-- 21sec

-- we doen bovenstaande ook omgekeerd: een k3 cel behoort tot 1 k4 cel.
alter table tmp.k1 add column k2 integer;
alter table tmp.k2 add column k3 integer;
alter table tmp.k3 add column k4 integer;
alter table tmp.k4 add column k5 integer;

update tmp.k1 a set k2 = b.pk from tmp.k2 b where st_contains(b.geom, a.geom);
update tmp.k2 a set k3 = b.pk from tmp.k3 b where st_contains(b.geom, a.geom);
update tmp.k3 a set k4 = b.pk from tmp.k4 b where st_contains(b.geom, a.geom);
update tmp.k4 a set k5 = b.pk from tmp.k5 b where st_contains(b.geom, a.geom);
-- 10 sec

-- tabllen weggooien
DROP TABLE IF EXISTS tmp.fdla_EXPLODE;
