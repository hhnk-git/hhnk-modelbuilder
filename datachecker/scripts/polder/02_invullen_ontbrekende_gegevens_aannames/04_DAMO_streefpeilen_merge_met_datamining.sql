-- nxt.fixeddrainagelevelarea mergen met datamining peil obv peilgebied code (bijv 'GPG-Q-142172') 
drop table if exists tmp.fixeddrainagelevelarea_datamining;
create table tmp.fixeddrainagelevelarea_datamining as select * from nxt.fixeddrainagelevelarea;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS point_on_surface;
alter table tmp.fixeddrainagelevelarea_datamining add column point_on_surface geometry;
update tmp.fixeddrainagelevelarea_datamining set point_on_surface = ST_Transform(ST_PointOnSurface(geometry),28992);

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_ahn3_mediaan_geom;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_mediaan_code;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_mediaan_geom;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_wss_code;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_wss_geom;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS hdb_winter;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS hdb_zomer;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS streefpeil_bwn2;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS streefpeil_bwn2_source;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_ahn3_mediaan_geom float;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_mediaan_code float;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_mediaan_geom float;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_wss_code float;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_wss_geom float;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN hdb_winter float;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN hdb_zomer float;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN streefpeil_bwn2 float;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN streefpeil_bwn2_source varchar(250);
/*
update tmp.fixeddrainagelevelarea_datamining a set streefpeil_bwn2 = (select case 
	when water_level_fixed is not null then water_level_fixed
	when water_level_winter is not null then water_level_winter
    when water_level_summer is not null then water_level_summer
	when water_level_flexible is not null then water_level_flexible
	when datamining_mediaan_code is not null then datamining_mediaan_code
	when datamining_wss_code is not null then datamining_wss_code
	else -10
    end);


update tmp.fixeddrainagelevelarea_datamining a set streefpeil_bwn2_source = 
      (select case 
	when water_level_fixed is not null then 'water_level_fixed'
	when water_level_winter is not null then 'water_level_winter'
	when water_level_summer is not null then 'water_level_summer'
    when water_level_flexible is not null then 'water_level_flexible'
	when datamining_mediaan_code is not null then 'datamining_mediaan_code'
	when datamining_wss_code is not null then 'datamining_wss_code'
	else '9999'
    end);

*/

-- select * from tmp.fixeddrainagelevelarea_datamining where streefpeil_bwn2 is null geeft 284 gebieden waar de mediaan van datamining is null EN voorstel_wss van datamining null.
-- In 365-284=81 gebieden is mediaan van datamining null, maar voorstel_wss van datamining wel ingevuld
-- Dit komt doordat in bovenstaande query de datamining gebieden zijn gekoppeld aan damo peilgebieden obv peilgebied code. 
-- We gaan daarom de lege gebieden koppelen obv geometry (middels st_pointonsurface)

drop table if exists tmp.link_table_datamining_fixeddrainagelevelarea;
create table tmp.link_table_datamining_fixeddrainagelevelarea as select 
a.id as fixeddrainagelevelarea_datamining_id,
st_pointonsurface(st_cleangeometry(st_transform(a.geometry,28992))) as geometry, -- omdat tmp.fixeddrainagelevelarea_datamining heeft geometry geometry(MultiPolygonZ,4326),
NULL::integer as peilgebieden_datamining_q0156_id
from tmp.fixeddrainagelevelarea_datamining a; 

drop index if exists tmp.link_table_datamining_fixeddrainagelevelarea_index;
create index link_table_datamining_fixeddrainagelevelarea_index on tmp.link_table_datamining_fixeddrainagelevelarea using gist(geometry);
cluster tmp.link_table_datamining_fixeddrainagelevelarea using link_table_datamining_fixeddrainagelevelarea_index;
-- deze apart runnen -- vacuum tmp.link_table_datamining_fixeddrainagelevelarea;
/* 
drop index if exists fixed_data.datamining_q0156_index;
create index datamining_q0156_index on fixed_data.datamining_q0156 using gist(wkb_geometry);
cluster fixed_data.datamining_q0156 using datamining_q0156_index;
-- deze apart runnen -- vacuum tmp.fixeddrainagelevelarea_datamining;
 */
-- updaten AHN3 datamining op basis van peilgebied code
UPDATE tmp.fixeddrainagelevelarea_datamining a
SET datamining_ahn3_mediaan_geom = median
FROM fixed_data.datamining_ahn3 b
WHERE a.code LIKE b.fdla_code;

UPDATE tmp.fixeddrainagelevelarea_datamining a
SET hdb_winter = b.winterpeil, hdb_zomer = b.zomerpeil
FROM hdb.hydro_deelgebieden b
WHERE ST_Intersects(a.point_on_surface,b.wkb_geometry);

/* -- updaten obv van peilgebied code
update tmp.fixeddrainagelevelarea_datamining a 
set datamining_mediaan_code = b.dm_mediaan, 
datamining_wss_code = b.voorstel_w
from fixed_data.datamining_q0156 b where a.code like b.gpgident;

-- updaten obv van geom stap 1: link maken tussen punten en vlakken
UPDATE tmp.link_table_datamining_fixeddrainagelevelarea a 
SET peilgebieden_datamining_q0156_id = b.id
from fixed_data.datamining_q0156 b
where st_intersects(b.wkb_geometry, a.geometry);
 */
/* -- updaten obv van geom stap 2: met de link table de tmp.fixeddrainagelevelarea_datamining tabel updaten
update tmp.fixeddrainagelevelarea_datamining a 
set datamining_mediaan_geom = b.dm_mediaan, 
datamining_wss_geom = b.voorstel_w
from fixed_data.datamining_q0156 b, tmp.link_table_datamining_fixeddrainagelevelarea c
where c.peilgebieden_datamining_q0156_id = b.id
and c.fixeddrainagelevelarea_datamining_id = a.id; */

update tmp.fixeddrainagelevelarea_datamining a set streefpeil_bwn2 = (select case 
	when hdb_winter BETWEEN -9.99 AND 10 then hdb_winter
	when hdb_zomer BETWEEN -9.99 AND 10 then hdb_zomer
	when water_level_fixed BETWEEN -9.99 AND 10 then water_level_fixed
	when water_level_winter BETWEEN -9.99 AND 10 then water_level_winter
	when water_level_summer BETWEEN -9.99 AND 10 then water_level_summer
	when water_level_flexible BETWEEN -9.99 AND 10 then water_level_flexible
	WHEN datamining_ahn3_mediaan_geom BETWEEN -9.99 AND 10 THEN datamining_ahn3_mediaan_geom
	when datamining_mediaan_code BETWEEN -9.99 AND 10 then datamining_mediaan_code
	when datamining_wss_code BETWEEN -9.99 AND 10 then datamining_wss_code
	when datamining_mediaan_geom BETWEEN -9.99 AND 10 then datamining_mediaan_geom
	when datamining_wss_geom BETWEEN -9.99 AND 10 then datamining_wss_geom
	ELSE -10
	end)
;

update tmp.fixeddrainagelevelarea_datamining a set streefpeil_bwn2_source = (select case 
	when hdb_winter BETWEEN -9.99 AND 10 then 'hdb_winter'
	when hdb_zomer BETWEEN -9.99 AND 10 then 'hdb_zomer'
	when water_level_fixed BETWEEN -9.99 AND 10 then 'water_level_fixed'
	when water_level_winter BETWEEN -9.99 AND 10 then 'water_level_winter'
	when water_level_summer BETWEEN -9.99 AND 10 then 'water_level_summer'
	when water_level_flexible BETWEEN -9.99 AND 10 then 'water_level_flexible'
	when datamining_ahn3_mediaan_geom BETWEEN -9.99 AND 10 THEN 'datamining_ahn3_mediaan_geom'
	when datamining_mediaan_code BETWEEN -9.99 AND 10 then 'datamining_mediaan_code'
	when datamining_wss_code BETWEEN -9.99 AND 10 then 'datamining_wss_code'
	when datamining_mediaan_geom BETWEEN -9.99 AND 10 then 'datamining_mediaan_geom'
	when datamining_wss_geom BETWEEN -9.99 AND 10 then 'datamining_wss_geom'
	ELSE '9999'
	end)
    -- 2017 03 31
    --SELECT count(*) FROM tmp.fixeddrainagelevelarea_datamining WHERE streefpeil_bwn2_source = 'water_level_fixed' -- 1774
    --SELECT count(*) FROM tmp.fixeddrainagelevelarea_datamining WHERE streefpeil_bwn2_source = 'water_level_winter' -- 523
    --SELECT count(*) FROM tmp.fixeddrainagelevelarea_datamining WHERE streefpeil_bwn2_source = 'water_level_summer' -- 39
    --SELECT count(*) FROM tmp.fixeddrainagelevelarea_datamining WHERE streefpeil_bwn2_source = 'water_level_flexible' -- 34
    --SELECT count(*) FROM tmp.fixeddrainagelevelarea_datamining WHERE streefpeil_bwn2_source = 'datamining_mediaan_code'-- 1099
    --SELECT count(*) FROM tmp.fixeddrainagelevelarea_datamining WHERE streefpeil_bwn2_source = 'datamining_wss_code' -- 73
    --SELECT count(*) FROM tmp.fixeddrainagelevelarea_datamining WHERE streefpeil_bwn2_source = 'datamining_mediaan_geom' -- 886
    --SELECT count(*) FROM tmp.fixeddrainagelevelarea_datamining WHERE streefpeil_bwn2_source = 'datamining_wss_geom' -- 2
    --SELECT count(*) FROM tmp.fixeddrainagelevelarea_datamining WHERE streefpeil_bwn2_source = '9999' -- 35
;


-- copy fixeddrainagelevelarea to checks schema
DROP TABLE IF EXISTS checks.fixeddrainagelevelarea;
CREATE TABLE checks.fixeddrainagelevelarea AS
SELECT id, peil_id, organisation_id, created, code, name, type, water_level_summer, 
       water_level_winter, water_level_fixed, water_level_flexible, streefpeil_bwn2, streefpeil_bwn2_source, image_url, ST_force2D(ST_Transform(geometry,28992)) as geom, 
       "end", start, polder_id::numeric, NULL::varchar(200) as opmerking, NULL::integer as wgtype_id
FROM tmp.fixeddrainagelevelarea_datamining;
CREATE INDEX checks_fixeddrainagelevelarea_geom ON checks.fixeddrainagelevelarea USING gist(geom);