/*
Maakt het nxt schema aan inclusief tabellen in schema
*/
drop schema if exists nxt cascade;
create schema nxt;
-- Table: hydra_core_bridge
-- DROP TABLE nxt.bridge;
CREATE TABLE nxt.bridge
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , name            character varying(255) NOT NULL
      , type            character varying(50) NOT NULL
      , width double precision
      , length double precision
      , height double precision
      , image_url character varying(2048)
      , geometry geometry(PointZ,4326)
      , "end" timestamp with time zone
      , start timestamp with time zone
      , CONSTRAINT hydra_core_bridge_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_channel
-- DROP TABLE nxt.channel;
CREATE TABLE nxt.channel
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , type            character varying(50) NOT NULL
      , bed_level double precision
      , comment text
      , name    character varying(255) NOT NULL
      , talud_left double precision
      , talud_right double precision
      , image_url character varying(2048)
      , geometry geometry(LineStringZ,4326)
      , "end" timestamp with time zone
      , start timestamp with time zone
      , CONSTRAINT hydra_core_channel_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_channelsurface
-- DROP TABLE nxt.channelsurface;
CREATE TABLE nxt.channelsurface
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , image_url       character varying(2048)
      , geometry geometry(MultiPolygonZ,4326)
      , "end" timestamp with time zone
      , start timestamp with time zone
      , CONSTRAINT hydra_core_channelsurface_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_crossprofile
-- DROP TABLE nxt.crossprofile;
CREATE TABLE nxt.crossprofile
    (
        id serial NOT NULL
      , type    integer NOT NULL
      , tables  character varying(50)
      , created timestamp with time zone NOT NULL
      , CONSTRAINT hydra_core_crossprofile_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_crosssection
-- DROP TABLE nxt.crosssection;
CREATE TABLE nxt.crosssection
    (
        id serial NOT NULL
      , cross_profile_id    integer NOT NULL
      , channel_id          integer
      , friction_type       integer
      , friction_value      integer
      , distance_on_channel numeric(8,2)
      , bed_level double precision
      , bed_width double precision
      , width double precision
      , slope_left double precision
      , slope_right double precision
      , reclamation double precision
      , created timestamp with time zone NOT NULL
      , geometry geometry(GeometryZ,4326)
      , CONSTRAINT hydra_core_crosssection_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_culvert
-- DROP TABLE nxt.culvert;
CREATE TABLE nxt.culvert
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , type            character varying(50) NOT NULL
      , bed_level_upstream double precision
      , bed_level_downstream double precision
      , width double precision
      , length double precision
      , allowed_flow_direction integer
      , height double precision
      , material    integer
      , shape       integer
      , description text
      , image_url   character varying(2048)
      , geometry geometry(LineStringZ,4326)
      , "end"          timestamp with time zone
      , start          timestamp with time zone
      , num_timeseries integer NOT NULL
      , CONSTRAINT hydra_core_culvert_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_fixeddrainagelevelarea
-- DROP TABLE nxt.fixeddrainagelevelarea;
CREATE TABLE nxt.fixeddrainagelevelarea
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , name            character varying(64) NOT NULL
      , type            integer NOT NULL
      , water_level_summer double precision
      , water_level_winter double precision
      , water_level_fixed double precision
      , water_level_flexible double precision
      , image_url character varying(2048)
      , geometry geometry(MultiPolygonZ,4326)
      , "end" timestamp with time zone
      , start timestamp with time zone
      , CONSTRAINT hydra_core_fixeddrainagelevelarea_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_levee
-- DROP TABLE nxt.levee;
CREATE TABLE nxt.levee
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , recurrence_time integer
      , material        character varying(32)
      , coating         character varying(32)
      , crest_height double precision
      , image_url     character varying(2048)
      , name          character varying(256)
      , category      integer
      , levee_ring_id integer
      , levee_type    integer
      , geometry geometry(LineStringZ,4326)
      , "end"          timestamp with time zone
      , start          timestamp with time zone
      , num_timeseries integer NOT NULL
      , CONSTRAINT hydra_core_levee_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_manhole
-- DROP TABLE nxt.manhole;
CREATE TABLE nxt.manhole
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , surface_level double precision
      , drainage_area integer
      , material      character varying(4) NOT NULL
      , width double precision
      , length double precision
      , shape character varying(4) NOT NULL
      , bottom_level double precision
      , image_url character varying(2048)
      , geometry geometry(PointZ,4326)
      , "end"          timestamp with time zone
      , start          timestamp with time zone
      , num_timeseries integer NOT NULL
      , CONSTRAINT hydra_core_manhole_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_orifice
-- DROP TABLE nxt.orifice;
CREATE TABLE nxt.orifice
    (
        id serial NOT NULL
      , organisation_id   integer
      , created           timestamp with time zone NOT NULL
      , start_point_id    integer
      , end_point_id      integer
      , connection_serial integer
      , crest_width double precision
      , crest_level double precision
      , shape character varying(4) NOT NULL
      , initial_opening_height double precision
      , code      character varying(50)
      , name      character varying(255) NOT NULL
      , flow_type integer NOT NULL
      , angle double precision
      , contraction_coeff double precision
      , lat_contr_coeff double precision
      , negative_flow_limit double precision
      , positive_flow_limit double precision
      , allowed_flow_direction integer
      , image_url              character varying(2048)
      , geometry geometry(LineStringZ,4326)
      , "end" timestamp with time zone
      , start timestamp with time zone
      , CONSTRAINT hydra_core_orifice_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_polder
-- DROP TABLE nxt.polder;
CREATE TABLE nxt.polder
    (
        id serial NOT NULL
      , created         timestamp with time zone NOT NULL
      , image_url       character varying(2048)
      , code            character varying(50)
      , name            character varying(255) NOT NULL
      , organisation_id integer
      , geometry geometry(MultiPolygonZ,4326)
      , "end" timestamp with time zone
      , start timestamp with time zone
      , CONSTRAINT hydra_core_polder_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_pump
-- DROP TABLE nxt.pump;
CREATE TABLE nxt.pump
    (
        id serial NOT NULL
      , pump_station_id integer NOT NULL
      , code            character varying(50) NOT NULL
      , serial          integer
      , capacity double precision
      , start_level double precision
      , stop_level double precision
      , name character varying(255) NOT NULL
      , type character varying(50) NOT NULL
      , reduction_factor_no_levels double precision
      , reduction_factor double precision
      , characteristics        character varying(255)
      , allowed_flow_direction integer
      , start_level_delivery_side double precision
      , stop_level_delivery_side double precision
      , created timestamp with time zone NOT NULL
      , CONSTRAINT hydra_core_pump_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_pumpstation
-- DROP TABLE nxt.pumpstation;
CREATE TABLE nxt.pumpstation
    (
        id serial NOT NULL
      , organisation_id   integer
      , created           timestamp with time zone NOT NULL
      , code              character varying(50)
      , type              character varying(50) NOT NULL
      , start_point_id    integer
      , end_point_id      integer
      , connection_serial integer
      , capacity double precision
      , start_level double precision
      , stop_level double precision
      , name                   character varying(255) NOT NULL
      , allowed_flow_direction integer
      , start_level_delivery_side double precision
      , stop_level_delivery_side double precision
      , image_url character varying(2048)
      , geometry geometry(PointZ,4326)
      , "end"          timestamp with time zone
      , start          timestamp with time zone
      , num_timeseries integer NOT NULL
      , CONSTRAINT hydra_core_pumpstation_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_sluice
-- DROP TABLE nxt.sluice;
CREATE TABLE nxt.sluice
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , name            character varying(64) NOT NULL
      , image_url       character varying(2048)
      , geometry geometry(PointZ,4326)
      , "end" timestamp with time zone
      , start timestamp with time zone
      , CONSTRAINT hydra_core_sluice_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- Table: hydra_core_weir
-- DROP TABLE nxt.weir;
CREATE TABLE nxt.weir
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , type            character varying(50) NOT NULL
      , crest_width double precision
      , crest_level double precision
      , name character varying(255) NOT NULL
      , lat_dis_coeff double precision
      , angle double precision
      , allowed_flow_direction integer
      , controlled             integer
      , comment                text
      , discharge_coeff double precision
      , image_url character varying(2048)
      , geometry geometry(PointZ,4326)
      , "end"          timestamp with time zone
      , start          timestamp with time zone
      , num_timeseries integer NOT NULL
      , CONSTRAINT hydra_core_weir_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;