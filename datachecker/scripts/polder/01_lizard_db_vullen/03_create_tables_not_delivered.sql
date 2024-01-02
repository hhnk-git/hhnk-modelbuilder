/*
Controleert of inputdata bestaat, als dit niet zo is, maakt hij tabellen aan zonder data
*/
CREATE TABLE IF NOT EXISTS damo_ruw.afvoergebiedaanvoergebied
    (
        id serial NOT NULL
      , code                     character varying(200)
      , naam                     character varying(100)
      , opmerking                character varying(200)
      , soortafvoeraanvoergebied character varying(200)
      , oppervlakte              character varying(200)
      , shape_length double precision
      , shape_area double precision
      , wkb_geometry geometry(MultiPolygon,28992)
      , CONSTRAINT afvoergebiedaanvoergebied_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.aquaductlijn
    (
        id serial NOT NULL
      , aquaductid integer
      , code       character varying(50)
      , naam       character varying(100)
      , opmerking  character varying(250)
      , bodemhoogtebenedenstrooms double precision
      , bodemhoogtebovenstrooms double precision
      , hoogteconstructie double precision
      , breedte double precision
      , soortmateriaal  smallint
      , typekruising    smallint
      , ws_bodembreedte real
      , ws_bovenbreedte real
      , ws_categorie    smallint
      , shape_length double precision
      , wkb_geometry geometry(MultiLineString,28992)
      , CONSTRAINT aquaductlijn_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.brug
    (
        id serial NOT NULL
      , code character varying(200)
      , hoogteonderzijde double precision
      , ws_categorie smallint
      , brug_id      integer
      , wkb_geometry geometry(Point,28992)
      , CONSTRAINT brug_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.doorstroomopening
    (
        id serial NOT NULL
      , breedteopening double precision
      , brugid integer
      , CONSTRAINT doorstroomopening_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.duikersifonhevel
    (
        id serial NOT NULL
      , code                 character varying(200)
      , ws_inlaatfunctie     character varying(3)
      , naam                 character varying(100)
      , opmerking            character varying(200)
      , indicatiewaterkerend smallint
      , lengte double precision
      , hoogteopening double precision
      , breedteopening double precision
      , hoogtebinnenonderkantbene double precision
      , hoogtebinnenonderkantbov double precision
      , vormkoker          smallint
      , soortmateriaal     smallint
      , typekruising       smallint
      , ws_categorie       smallint
      , ws_bron            character varying(200)
      , ws_inwinningswijze smallint
      , ws_inwinningsdatum timestamp with time zone
      , ws_afsluitwijze1   smallint
      , ws_afsluitwijze2   smallint
      , shape_length double precision
      , wkb_geometry geometry(MultiLineString,28992)
      , CONSTRAINT duikersifonhevel_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.gemaal
    (
        id serial NOT NULL
      , code          character varying(200)
      , naam          character varying(100)
      , functiegemaal smallint
      , maximalecapaciteit double precision
      , ws_categorie smallint
      , wkb_geometry geometry(Point,28992)
      , CONSTRAINT gemaal_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.gw_pbp
    (
        id serial NOT NULL
      , prw_prw_id integer
      , iws_hoogte double precision
      , iws_afstand double precision
	  , pbpsoort integer
      , CONSTRAINT gw_pbp_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.gw_pro
    (
        id serial NOT NULL
      , pro_id     integer
      , proident   character varying(200)
      , ovk_ovk_id integer
      , prw_prw_id integer
      , osmomsch   character varying(200)
      , shape_length double precision
      , wkb_geometry geometry(MultiLineStringZ,28992)
      , CONSTRAINT gw_pro_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.gw_prw
    (
        id serial NOT NULL
      , prw_id     integer
      , pro_pro_id integer
      , osmomsch   character varying(60)
      , CONSTRAINT gw_prw_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.hydroobject
    (
        id serial NOT NULL
      , code                     character varying(200)
      , soortoppwaterkwantiteit  smallint
      , categorieoppwaterlichaam smallint
      , ws_bodemhoogte           real
      , ws_bodembreedte          real
      , ws_talud_links           real
      , ws_talud_rechts          real
      , ws_in_peilgebied         character varying(200)
      , shape_length double precision
      , wkb_geometry geometry(MultiLineString,28992)
      , CONSTRAINT hydroobject_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.iws_geo_beschr_profielpunten
    (
        id serial NOT NULL
      , wkb_geometry geometry(PointZ,28992)
      , CONSTRAINT iws_geo_beschr_profielpunten_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.iws_profiel_reeksen
    (
        id serial NOT NULL
      , CONSTRAINT iws_profiel_reeksen_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.peilafwijkinggebied
    (
        id serial NOT NULL
      , code                   character varying(200)
      , naam                   character varying(100)
      , opmerking              character varying(200)
      , ws_bron                character varying(20)
      , ws_inwinningswijze     smallint
      , ws_inwinningsdatum     timestamp with time zone
      , created_user           character varying(200)
      , created_date           timestamp with time zone
      , last_edited_user       character varying(200)
      , last_edited_date       timestamp with time zone
      , ws_oppervlakte         integer
      , peilafwijkinggebied_id integer
      , shape_length double precision
      , shape_area double precision
      , wkb_geometry geometry(MultiPolygon,28992)
      , CONSTRAINT peilafwijkinggebied_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.peilgebiedpraktijk
    (
        id serial NOT NULL
      , code                   character varying(200)
      , naam                   character varying(100)
      , opmerking              character varying(200)
      , ws_bron                character varying(200)
      , ws_inwinningswijze     smallint
      , ws_inwinningsdatum     timestamp with time zone
      , ws_peilbesluitplichtig character varying(200)
      , created_user           character varying(200)
      , created_date           timestamp with time zone
      , last_edited_user       character varying(200)
      , last_edited_date       timestamp with time zone
      , ws_oppervlakte         integer
      , peilgebiedpraktijk_id  integer
      , shape_length double precision
      , shape_area double precision
      , wkb_geometry geometry(MultiPolygon,28992)
      , CONSTRAINT peilgebiedpraktijk_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.ref_beheergebiedgrens_hhnk
    (
        id serial NOT NULL
      , shape_length double precision
      , shape_area double precision
      , wkb_geometry geometry(MultiPolygon,28992)
      , CONSTRAINT ref_beheergebiedgrens_hhnk_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.sluis
    (
        id serial NOT NULL
      , code character varying(200)
      , naam character varying(100)
      , doorvaartbreedte double precision
      , breedte double precision
      , hoogtebinnenonderkantben double precision
      , hoogtebinnenonderkantbov double precision
      , drempelhoogte double precision
      , ws_categorie      smallint
      , ws_doorvaarlengte real
      , ws_inlaatfunctie  character varying(200)
      , ws_afsluitwijze1  smallint
      , ws_afsluitwijze2  smallint
      , wkb_geometry geometry(Point,28992)
      , CONSTRAINT sluis_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.streefpeil
    (
        id serial NOT NULL
      , soortstreefpeil smallint
      , waterhoogte double precision
      , peilgebiedpraktijkid  integer
      , peilafwijkinggebiedid integer
      , CONSTRAINT streefpeil_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.stuw
    (
        id serial NOT NULL
      , code character varying(200)
      , naam character varying(100)
      , doorstroombreedte double precision
      , kruinbreedte double precision
      , laagstedoorstroomhoogte double precision
      , soortregelbaarheid smallint
      , ws_categorie       smallint
      , ws_kruinvorm       smallint
      , ws_functiestuw     smallint
      , wkb_geometry geometry(Point,28992)
      , CONSTRAINT stuw_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.vastedam
    (
        id serial NOT NULL
      , code         character varying(200)
      , ws_categorie smallint
      , wkb_geometry geometry(Point,28992)
      , CONSTRAINT vastedam_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.vispassage
    (
        id serial NOT NULL
      , code         character varying(200)
      , naam         character varying(100)
      , ws_categorie smallint
      , wkb_geometry geometry(Point,28992)
      , CONSTRAINT vispassage_pkey PRIMARY KEY (id)
    )
;

CREATE TABLE IF NOT EXISTS damo_ruw.waterdeel
    (
        id serial NOT NULL
      , bgtstatus double precision
      , bgttype double precision
      , bronhouder double precision
      , code double precision
      , detailniveaugeometrie double precision
      , eindregistratie double precision
      , inonderzoek double precision
      , lokaalid double precision
      , lvpublicatiedatum double precision
      , naamspace double precision
      , objectbegintijd double precision
      , objecteindtijd double precision
      , plustype double precision
      , relatievehoogteligging double precision
      , hydroobjectid double precision
      , metadataid double precision
      , tijdstipregistratie double precision
      , created_user double precision
      , created_date double precision
      , last_edited_user double precision
      , last_edited_date double precision
      , shape_length double precision
      , shape_area double precision
      , wkb_geometry geometry(MultiPolygon,28992)
      , CONSTRAINT waterdeel_pkey PRIMARY KEY (id)
    )
;