-- nxt.fixeddrainagelevelarea mergen met datamining peil obv peilgebied code (bijv 'GPG-Q-142172')
drop table if exists tmp.fixeddrainagelevelarea_datamining
;

create table tmp.fixeddrainagelevelarea_datamining as
select *
from
    nxt.fixeddrainagelevelarea
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS point_on_surface
;

alter table tmp.fixeddrainagelevelarea_datamining add column point_on_surface geometry
;

update
    tmp.fixeddrainagelevelarea_datamining
set point_on_surface = ST_Transform(ST_PointOnSurface(geometry),28992)
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_ahn3_mediaan_geom
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_mediaan_code
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_mediaan_geom
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_wss_code
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS datamining_wss_geom
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS hdb_winter
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS hdb_zomer
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS streefpeil_bwn2
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS streefpeil_bwn2_source
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_ahn3_mediaan_geom float
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_mediaan_code float
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_mediaan_geom float
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_wss_code float
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN datamining_wss_geom float
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN hdb_winter float
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN hdb_zomer float
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN streefpeil_bwn2 float
;

ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN streefpeil_bwn2_source varchar(250)
;

drop table if exists tmp.link_table_datamining_fixeddrainagelevelarea
;

create table tmp.link_table_datamining_fixeddrainagelevelarea as
select
    a.id                                                                as fixeddrainagelevelarea_datamining_id
  , st_pointonsurface(st_cleangeometry(st_transform(a.geometry,28992))) as geometry
  , NULL::integer                                                       as peilgebieden_datamining_q0156_id
from
    tmp.fixeddrainagelevelarea_datamining a
;

drop index if exists tmp.link_table_datamining_fixeddrainagelevelarea_index;
create index link_table_datamining_fixeddrainagelevelarea_index
on
    tmp.link_table_datamining_fixeddrainagelevelarea
using gist
    (
        geometry
    )
;

cluster tmp.link_table_datamining_fixeddrainagelevelarea using link_table_datamining_fixeddrainagelevelarea_index;
-- updaten AHN3 datamining op basis van peilgebied code
UPDATE
    tmp.fixeddrainagelevelarea_datamining a
SET datamining_ahn3_mediaan_geom = median
FROM
    fixed_data.datamining_ahn3 b
WHERE
    a.code LIKE b.fdla_code
;

UPDATE
    tmp.fixeddrainagelevelarea_datamining a
SET hdb_winter = b.winterpeil
  , hdb_zomer  = b.zomerpeil
FROM
    hdb.hydro_deelgebieden b
WHERE
    ST_Intersects(a.point_on_surface,b.wkb_geometry)
;

update
    tmp.fixeddrainagelevelarea_datamining a
set streefpeil_bwn2 =
    (
        select
            case
                when hdb_winter BETWEEN -9.99 AND 10
                    then hdb_winter
                when hdb_zomer BETWEEN -9.99 AND 10
                    then hdb_zomer
                when water_level_fixed BETWEEN -9.99 AND 10
                    then water_level_fixed
                when water_level_winter BETWEEN -9.99 AND 10
                    then water_level_winter
                when water_level_summer BETWEEN -9.99 AND 10
                    then water_level_summer
                when water_level_flexible BETWEEN -9.99 AND 10
                    then water_level_flexible
                WHEN datamining_ahn3_mediaan_geom BETWEEN -9.99 AND 10
                    THEN datamining_ahn3_mediaan_geom
                when datamining_mediaan_code BETWEEN -9.99 AND 10
                    then datamining_mediaan_code
                when datamining_wss_code BETWEEN -9.99 AND 10
                    then datamining_wss_code
                when datamining_mediaan_geom BETWEEN -9.99 AND 10
                    then datamining_mediaan_geom
                when datamining_wss_geom BETWEEN -9.99 AND 10
                    then datamining_wss_geom
                    ELSE -10
            end
    )
;

update
    tmp.fixeddrainagelevelarea_datamining a
set streefpeil_bwn2_source =
    (
        select
            case
                when hdb_winter BETWEEN -9.99 AND 10
                    then 'hdb_winter'
                when hdb_zomer BETWEEN -9.99 AND 10
                    then 'hdb_zomer'
                when water_level_fixed BETWEEN -9.99 AND 10
                    then 'water_level_fixed'
                when water_level_winter BETWEEN -9.99 AND 10
                    then 'water_level_winter'
                when water_level_summer BETWEEN -9.99 AND 10
                    then 'water_level_summer'
                when water_level_flexible BETWEEN -9.99 AND 10
                    then 'water_level_flexible'
                when datamining_ahn3_mediaan_geom BETWEEN -9.99 AND 10
                    THEN 'datamining_ahn3_mediaan_geom'
                when datamining_mediaan_code BETWEEN -9.99 AND 10
                    then 'datamining_mediaan_code'
                when datamining_wss_code BETWEEN -9.99 AND 10
                    then 'datamining_wss_code'
                when datamining_mediaan_geom BETWEEN -9.99 AND 10
                    then 'datamining_mediaan_geom'
                when datamining_wss_geom BETWEEN -9.99 AND 10
                    then 'datamining_wss_geom'
                    ELSE '9999'
            end
    )
;

-- copy fixeddrainagelevelarea to checks schema
DROP TABLE IF EXISTS checks.fixeddrainagelevelarea
;

CREATE TABLE checks.fixeddrainagelevelarea AS
SELECT
    id
  , peil_id
  , organisation_id
  , created
  , code
  , name
  , type
  , water_level_summer
  , water_level_winter
  , water_level_fixed
  , water_level_flexible
  , streefpeil_bwn2
  , streefpeil_bwn2_source
  , image_url
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , "end"
  , start
  , polder_id::numeric
  , NULL::varchar(200) as opmerking
  , NULL::integer      as wgtype_id
FROM
    tmp.fixeddrainagelevelarea_datamining
;

CREATE INDEX checks_fixeddrainagelevelarea_geom
ON
    checks.fixeddrainagelevelarea
USING gist
    (
        geom
    )
;