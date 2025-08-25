-- copy peilen to checks schema
DROP TABLE IF EXISTS checks.fixeddrainagelevelarea
;

CREATE TABLE checks.fixeddrainagelevelarea AS
SELECT
    id
  , id as peil_id
  , NULL organisation_id
  , NULL created
  , code
  , naam::varchar(50) as name
  , CASE WHEN type LIKE '%Peilgebied%' THEN 1::integer ELSE 2::integer END as type 
  , zomerpeil::numeric as water_level_summer
  , winterpeil::numeric as water_level_winter
  , NULL as water_level_fixed
  , NULL as water_level_flexible
  , peil_wsa::numeric as streefpeil_bwn2
  , keuze_wsa as streefpeil_bwn2_source
  , type as image_url
  , ST_CollectionExtract(ST_MakeValid(ST_force2D(wkb_geometry)),3) as geom
  , --ST_force2D(ST_Transform(geometry,28992)) as geom,
    NULL as "end"
  , NULL as start
  , NULL::numeric as polder_id
  , NULL::varchar(250) as opmerking
  , NULL::integer      as wgtype_id
FROM
    damo_ruw.peilen
;

CREATE INDEX checks_fixeddrainagelevelarea_geom
ON
    checks.fixeddrainagelevelarea
USING gist
    (
        geom
    )
;

--Op een of andere manier is ie nog steeds niet altijd valid, dus hier nog een keertje een ST_MakeValid:
UPDATE
    checks.fixeddrainagelevelarea
SET geom = ST_MakeValid(geom)
;

-- copy weirs to checks schema
DROP TABLE IF EXISTS checks.weirs
;

CREATE TABLE checks.weirs AS
SELECT
    id
  , organisation_id
  , created
  , code
  , type
  , crest_width
  , crest_level
  , name
  , lat_dis_coeff
  , angle
  , allowed_flow_direction
  , controlled
  , comment
  , discharge_coeff
  , image_url
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , "end"
  , start
  , num_timeseries
  , shape
  , controlled_ficeddrainagelevelarea_code
  , channel_code
  , type_function
  , NULL::varchar(250) as opmerking
  , NULL::integer      as wgtype_id
  , channel_type_id
FROM
    nxt.weir
;

CREATE INDEX checks_weirs_geom
ON
    checks.weirs
USING gist
    (
        geom
    )
;

-- copy fixed dam to check schema
DROP TABLE IF EXISTS checks.fixed_dam
;

CREATE TABLE checks.fixed_dam AS
SELECT
    id
  , code
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , NULL::varchar(50)                        as channel_code
  , NULL::varchar(250)                       as opmerking
  , NULL::integer                            as wgtype_id
  , channel_type_id
FROM
    nxt.fixed_dam
;

CREATE INDEX checks_fixed_dam_geom
ON
    checks.fixed_dam
USING gist
    (
        geom
    )
;

-- copy culverts to checks schema
DROP TABLE IF EXISTS checks.culvert
;

CREATE TABLE checks.culvert AS
SELECT
    id
  , organisation_id
  , created
  , code
  , type
  , level_seperator_indicator
  , bed_level_upstream
  , bed_level_downstream
  , width
  , length
  , allowed_flow_direction
  , 0.8::double precision as discharge_coefficient_positive
  , 0.8::double precision as discharge_coefficient_negative
  , height
  , material
  , shape
  , description
  , image_url
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , "end"
  , start
  , num_timeseries
  , channel_code
  , channel_type_id
  , type_art
  , NULL::varchar(250) as opmerking
  , NULL::integer      as wgtype_id
  , NULL::integer      as fixeddrainagelevelarea_id_1
  , NULL::integer      as fixeddrainagelevelarea_id_2
FROM
    nxt.culvert
;

CREATE INDEX checks_culvert_geom
ON
    checks.culvert
USING gist
    (
        geom
    )
;

-- copy pumpstations to checks schema
DROP TABLE IF EXISTS checks.pumpstation
;

CREATE TABLE checks.pumpstation AS
SELECT
    id
  , organisation_id
  , created
  , code
  , type
  , start_point_id
  , end_point_id
  , connection_serial
  , capacity
  , start_level
  , stop_level
  , name
  , allowed_flow_direction
  , start_level_delivery_side
  , stop_level_delivery_side
  , image_url
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , "end"
  , start
  , num_timeseries
  , from_fixeddrainagelevelarea_code
  , to_fixeddrainagelevelarea_code
  , NULL::varchar(50)  as channel_code
  , NULL::varchar(50)  as code_polder
  , NULL::varchar(250) as opmerking
  , NULL::integer      as wgtype_id
  , channel_type_id
FROM
    nxt.pumpstation
;

CREATE INDEX checks_pumpstation_geom
ON
    checks.pumpstation
USING gist
    (
        geom
    )
;

-- copy bridge to checks schema
DROP TABLE IF EXISTS checks.bridge
;

CREATE TABLE checks.bridge AS
SELECT
    id
  , organisation_id
  , created
  , code
  , name
  , type
  , width
  , length
  , bottom_level
  , image_url
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , "end"
  , start
  , number_openings
  , channel_type_id
  , NULL::varchar(250) as opmerking
  , NULL::integer      as channel_code
FROM
    nxt.bridge
;

CREATE INDEX checks_bridge_geom
ON
    checks.bridge
USING gist
    (
        geom
    )
;

-- copy channelsurface to checks schema
DROP TABLE IF EXISTS checks.channelsurface
;

CREATE TABLE checks.channelsurface AS
SELECT
    id
  , organisation_id
  , created
  , code
  , image_url
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , "end"
  , start
FROM
    nxt.channelsurface
;

CREATE INDEX checks_channelsurface_geom
ON
    checks.channelsurface
USING gist
    (
        geom
    )
;

-- copy crossprofile to checks schema
DROP TABLE IF EXISTS checks.crossprofile
;

CREATE TABLE checks.crossprofile AS
SELECT *
FROM
    nxt.crossprofile
;

-- copy crosssection to checks schema
DROP TABLE IF EXISTS checks.crosssection
;

CREATE TABLE checks.crosssection AS
SELECT
    id
  , cross_profile_id
  , channel_id
  , friction_type
  , friction_value
  , distance_on_channel
  , bed_level
  , bed_width
  , width
  , slope_left
  , slope_right
  , reclamation
  , created
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , bank_level
  , code
FROM
    nxt.crosssection
;

CREATE INDEX checks_crosssection_geom
ON
    checks.crosssection
USING gist
    (
        geom
    )
;

-- copy manhole to checks schema
DROP TABLE IF EXISTS checks.manhole
;

CREATE TABLE checks.manhole AS
SELECT
    id
  , organisation_id
  , created
  , code
  , surface_level
  , drainage_area
  , material
  , width
  , length
  , shape
  , bottom_level
  , image_url
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , "end"
  , start
  , num_timeseries
FROM
    nxt.manhole
;

CREATE INDEX checks_manhole_geom
ON
    checks.manhole
USING gist
    (
        geom
    )
;

-- copy orifice to checks schema
DROP TABLE IF EXISTS checks.orifice
;

CREATE TABLE checks.orifice AS
SELECT
    id
  , organisation_id
  , created
  , start_point_id
  , end_point_id
  , connection_serial
  , crest_width
  , crest_level
  , shape
  , initial_opening_height
  , code
  , name
  , flow_type
  , angle
  , contraction_coeff
  , lat_contr_coeff
  , negative_flow_limit
  , positive_flow_limit
  , allowed_flow_direction
  , image_url
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , "end"
  , start
FROM
    nxt.orifice
;

CREATE INDEX checks_orifice_geom
ON
    checks.orifice
USING gist
    (
        geom
    )
;

-- copy manhole to checks schema
DROP TABLE IF EXISTS checks.sluice
;

CREATE TABLE checks.sluice AS
SELECT
    id
  , organisation_id
  , created
  , code
  , name
  , image_url
  , ST_force2D(ST_Transform(geometry,28992)) as geom
  , "end"
  , start
  , channel_type_id
  , type
  , width
  , length
  , bottom_level
FROM
    nxt.sluice
;

CREATE INDEX checks_sluice_geom
ON
    checks.sluice
USING gist
    (
        geom
    )
;

--Copy control table to checks schema
DROP TABLE IF EXISTS checks.control_table
;

CREATE TABLE checks.control_table AS
SELECT
    id
  , structure_code
  , structure_type
  , measure_variable
  , action_type
  , measure_operator
  , measure_values
  , control_values
  , ST_force2D(ST_Transform(measurement_location,28992)) as measurement_location
FROM
    nxt.control_table
;

CREATE INDEX checks_control_measurement_location
ON
    checks.control_table
USING gist
    (
        measurement_location
    )
;