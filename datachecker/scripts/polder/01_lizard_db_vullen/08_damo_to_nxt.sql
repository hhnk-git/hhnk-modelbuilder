/*
hydra_core_polder
code NOT NULL + UNIQUE
type toevoegen
damo_ruw.afvoergebiedaanvoergebied
objectid serial NOT NULL,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
oppervlakte double precision,
shape_length double precision,
shape_area double precision,
wkb_geometry geometry(MultiPolygon,28992)
nxt.hydra_core_polder
id serial NOT NULL,
created timestamp with time zone NOT NULL,
image_url character varying(2048),
code character varying(50),
name character varying(255) NOT NULL,
organisation_id integer,
geometry geometry(MultiPolygonZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
CONSTRAINT hydra_core_polder_pkey PRIMARY KEY (id)
*/
-- hydra_core_polder
DROP SEQUENCE IF EXISTS serial;
CREATE SEQUENCE serial START 1;
ALTER TABLE nxt.polder ADD COLUMN polder_type VARCHAR
;

INSERT INTO nxt.polder
    (id
      , created
      , code
      , name
      , polder_type
      , geometry
    )
SELECT
    NEXTVAL('serial')
  , NOW()
  , code
  , case
        when (
                naam = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE naam
    END
  , 'NULL' AS polder_type
  , ST_CollectionExtract(ST_MakeValid(st_force3d(st_transform(wkb_geometry,4326))),3)::geometry(MultiPolygonZ)
FROM
    tmp.afvoergebiedaanvoergebied
;

/*
(gebieden) hydra_core_fixeddrainagelevelarea
code NOT NULL
polder_id toevoegen
tmp.peilgebiedpraktijk
objectid serial NOT NULL,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
ws_peilbesluitplichtig character varying(3),
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
shape_length double precision,
shape_area double precision,
peilgebiedpraktijk_id integer,
wkb_geometry geometry(MultiPolygon,28992)
tmp.peilafwijkinggebied
objectid serial NOT NULL,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
shape_length double precision,
shape_area double precision,
peilafwijking_id integer,
wkb_geometry geometry(MultiPolygon,28992),
tmp.fixedleveldrainagearea_union <-- is peilgebiekPraktijk en Peilafwijkinggebied door elkaar heen gedrukt met script peilgebieden_arcgis_union.sql (dus geen overlappingen meer)
objectid integer,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
shape_length double precision,
shape_area double precision,
id integer,
geom geometry, <-- volgens Wouter is dit in 28992
nxt.hydra_core_fixeddrainagelevelarea
id serial NOT NULL,
organisation_id integer,
created timestamp with time zone NOT NULL,
code character varying(50),
name character varying(64) NOT NULL,
type integer NOT NULL,
water_level_summer double precision,
water_level_winter double precision,
water_level_fixed double precision,
image_url character varying(2048),
geometry geometry(MultiPolygonZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
CONSTRAINT hydra_core_fixeddrainagelevelarea_pkey PRIMARY KEY (id)
*/
-- peilgebieden (peilvakken) = hydra_core_fixeddrainagelevelarea
delete
from
    nxt.fixeddrainagelevelarea
;

ALTER TABLE nxt.fixeddrainagelevelarea ADD COLUMN polder_id integer
;

ALTER TABLE nxt.fixeddrainagelevelarea ADD COLUMN peil_id integer
;

--ALTER TABLE nxt.fixeddrainagelevelarea ALTER COLUMN peil_id integer;
-- ALTER TABLE nxt.fixeddrainagelevelarea ADD COLUMN water_level_flexible float; <-- in 03_kopie_hydra_core_naar_nxt_schema__________01sec heb ik al een water_level_flexible toegevoegd gelijk na water_level_fixed, zodat ik hier niet de volgorde van de kolommen hoef aan te passen (zodat in lizard alle 4 kolommen met peilen achterelkaar staan)
DROP SEQUENCE IF EXISTS serial;
CREATE SEQUENCE serial START 1;
INSERT INTO nxt.fixeddrainagelevelarea
    (id
      , created
      , code
      , name
      , type
      , peil_id
      , water_level_fixed
      , geometry
    )
SELECT
    nextval('serial')
  , -- door slechte geometry van peilgebieden (peilgebieden en afwijking liggen niet altijd netjes op elkaar..) gebruiken we hier een serial
    NOW()
  , -- created NOT NULL (dus timestamp opgeven)
    code
  , case
        when (
                naam = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE naam
    END
  , -- als veld damo.naam leeg is dan vullen we in 'LEEG' in nxt.name want nxt.name NOT NULL
    case
        when type like 'peilgebied'
            then 1 -- type (1 = peilvak, 2 = peilafwijking)
        when type like 'peilafwijking'
            then 2
    end
  , id
  , -- peil_id
    wsa_level
  ,
     -- polder_id weten we nog niet
    --st_force3d(st_transform(geom,4326))::geometry(MultiPolygonZ) -- want nxt.geometry is 3D (met z-coordinaat)
    ST_CollectionExtract( ST_MakeValid( st_force3d( ST_Multi( st_transform(geom,4326) ) )),3)::geometry(MultiPolygonZ)
    --) -- want nxt.geometry is 3D (met z-coordinaat)
FROM
    tmp.fixedleveldrainagearea_union
;

-- door slechte geometry van peilgebieden (peilgebieden en afwijking liggen niet altijd netjes op elkaar..) gebruiken we hier een serial
-- select id, count(*) from tmp.fixedleveldrainagearea_union group by id having count(*)>1
-- bijvoorbeeld id 7678 komt 3x voor!!
--select * from tmp.fixedleveldrainagearea_union;
-- 3861
-- select distinct on (objectid) * from tmp.fixedleveldrainagearea_union;
-- 2015
-- select distinct on (id) * from tmp.fixedleveldrainagearea_union;
-- 3657... en dat is 204 minder dan zonder distinct on (id)... das niet handig... welke zijn het dan bijv?
-- select id, count(*) from tmp.fixedleveldrainagearea_union group by id having count(*)>1
-- bijvoorbeeld id 7678 komt 3x voor!!
/*
damo_ruw.streefpeil;
objectid serial NOT NULL,
soortstreefpeil smallint,
eenheid smallint DEFAULT 1,
waterhoogte double precision,
beginperiode character varying(50),
eindperiode character varying(50),
peilgebiedpraktijkid integer,
peilafwijkinggebiedid integer,
peilgebiedvigerendid integer,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
*/
/*
-- streefpeil_SOORTSTREEFPEIL
Code Name
901 Vast peilbeheer; streefpeil jaarrond
902 Seizoensgebonden peilbeheer; streefpeil winter
903 Seizoensgebonden peilbeheer; streefpeil zomer
904 Dynamisch peilbeheer; streefpeil jaarrond
905 Dynamisch peilbeheer; ondergrenspeil jaarrond
906 Dynamisch peilbeheer; bovengrenspeil jaarrond
907 Dynamisch seizoensgebonden peilbeheer; streefpeil winter
908 Dynamisch seizoensgebonden peilbeheer; streefpeil zomer
909 Dynamisch seizoensgebonden peilbeheer; ondergrenspeil winter
910 Dynamisch seizoensgebonden peilbeheer; bovengrenspeil winter
911 Dynamisch seizoensgebonden peilbeheer; ondergrenspeil zomer
912 Dynamisch seizoensgebonden peilbeheer; bovengrenspeil zomer
913 Flexibel peilbeheer; ondergrenspeil jaarrond
914 Flexibel peilbeheer; bovengrenspeil jaarrond
915 Vrij afwaterend op buitenwater; ondergrenspeil jaarrond
916 Vrij afwaterend op boezemwater; ondergrenspeil jaarrond
917 Wateraanvoer Wieringermeer; streefpeil zomer
918 Onderbemaling; ondergrenspeil
919 Opmaling; bovengrenspeil
920 Opstuwing; bovengrenspeil
921 Op- en onderbemaling; ondergrenspeil
922 Op- en onderbemaling; bovengrenspeil
-- 919 en 921 zijn er niet in DAMO export (damo_ruw)
*/
/*
-- vast streefpeil peilgebieden
UPDATE nxt.fixeddrainagelevelarea a SET water_level_fixed = waterhoogte FROM damo_ruw.streefpeil b
WHERE a.peil_id = b.peilgebiedpraktijkid
AND b.soortstreefpeil = CASE
WHEN b.soortstreefpeil = 901 THEN 901
WHEN b.soortstreefpeil = 904 THEN 904
WHEN b.soortstreefpeil = 915 THEN 915
END;
-- zomer streefpeil peilgebieden
UPDATE nxt.fixeddrainagelevelarea a SET water_level_summer = waterhoogte FROM damo_ruw.streefpeil b
WHERE a.peil_id = b.peilgebiedpraktijkid
AND b.soortstreefpeil = CASE
WHEN b.soortstreefpeil = 903 THEN 903
WHEN b.soortstreefpeil = 908 THEN 908
WHEN b.soortstreefpeil = 917 THEN 917
END;
UPDATE nxt.fixeddrainagelevelarea a SET water_level_winter = waterhoogte FROM damo_ruw.streefpeil b
WHERE a.peil_id = b.peilgebiedpraktijkid
AND b.soortstreefpeil = CASE
WHEN b.soortstreefpeil = 902 THEN 902
WHEN b.soortstreefpeil = 907 THEN 907
END;
-- flexibel streefpeil peilgebieden
WITH gemiddelde AS (
SELECT a.peilgebiedpraktijkid, round(((a.waterhoogte+b.waterhoogte)/2)::numeric,2) as gemiddelde
FROM damo_ruw.streefpeil as a
LEFT JOIN damo_ruw.streefpeil as b
ON a.peilgebiedpraktijkid = b.peilgebiedpraktijkid
WHERE a.soortstreefpeil = 913 AND b.soortstreefpeil = 914
)
UPDATE nxt.fixeddrainagelevelarea as c SET water_level_flexible = d.gemiddelde
FROM gemiddelde as d
WHERE c.peil_id = d.peilgebiedpraktijkid
;
-- vast streefpeil peilafwijkingen
UPDATE nxt.fixeddrainagelevelarea a SET water_level_fixed = waterhoogte FROM damo_ruw.streefpeil b
WHERE a.peil_id = b.peilafwijkinggebiedid
AND b.soortstreefpeil = CASE
WHEN b.soortstreefpeil = 918 THEN 918
WHEN b.soortstreefpeil = 919 THEN 919
WHEN b.soortstreefpeil = 920 THEN 920
WHEN b.soortstreefpeil = 921 THEN 921
--WHEN b.soortstreefpeil = 922 THEN 922 --ALLEEN ONDERGRENS GEBRUIKEN: 921
END;
*/
-- peilen uit hydrologische database koppelen
UPDATE
    nxt.fixeddrainagelevelarea a
SET water_level_summer = b.zomerpeil
FROM
    hdb.hydro_deelgebieden b
WHERE
    a.code = 'HDB:'
        || b.code
;

UPDATE
    nxt.fixeddrainagelevelarea a
SET water_level_winter = b.winterpeil
FROM
    hdb.hydro_deelgebieden b
WHERE
    a.code = 'HDB:'
        || b.code
;

/*
hhnk kent 4 soorten peilbeheer:
1.     Vast
2.     Seizoen
3.     Dynamisch (seizoen)
4.     Flexibel
We moeten hierbij onderscheid maken naar peilgebied en peilafwijking.
PeilgebiedPraktijk Vast:
901    Vast peilbeheer; streefpeil jaarrond
904    Dynamisch peilbeheer; streefpeil jaarrond
PeilgebiedPraktijk Zomer:
903    Seizoensgebonden peilbeheer; streefpeil zomer
908    Dynamisch seizoensgebonden peilbeheer; streefpeil zomer
917    Wateraanvoer Wieringermeer; streefpeil zomer
PeilgebiedPraktijk Winter:
902    Seizoensgebonden peilbeheer; streefpeil winter
907    Dynamisch seizoensgebonden peilbeheer; streefpeil winter
PeilgebiedPraktijk Flexibel:
Gemiddelde van
913    Flexibel peilbeheer; ondergrenspeil jaarrond en
914    Flexibel peilbeheer; bovengrenspeil jaarrond
PeilafwijkingGebied Onderbemaling:
918    Onderbemaling; ondergrenspeil
PeilafwijkingGebied Opmaling of opstuwing:
919    Opmaling; bovengrenspeil
920    Opstuwing; bovengrenspeil
PeilafwijkingGebied Op- en onderbemaling
921    Op- en onderbemaling; ondergrenspeil (0 st)
922    Op- en onderbemaling; bovengrenspeil (179 st)
*/
/*
hydra_core_channel
- code NOT NULL + UNIQUE
- type_id veld toevoegen
- bed_level_upstream toevoegen <-- niet gedaan want hebben ze niet
- bed_level_downstream toevoegen <-- niet gedaan want hebben ze niet
- bed_width toevoegen
- width_at_waterlevel toevoegen <-- wel gedaan, maar is niet goed meegekomen in damo export volgens Jeroen H??
- talud_left_dry toevoegen <-- niet gedaan want hebben ze niet
- talud_right_dry toevoegen <-- niet gedaan want hebben ze niet
*/
/*
damo_ruw.hydroobject
objectid serial NOT NULL,
code character varying(50),
opmerking character varying(250),
soortoppwaterkwantiteit smallint,
categorieoppwaterlichaam smallint,
breedte double precision,
lengte double precision,
ws_bodemhoogte real,
ws_bodembreedte real,
ws_talud_links real,
ws_talud_rechts real,
ws_bodembreedte_brede_kijk real,
ws_bodemhoogte_brede_kijk real,
ws_in_peilgebied character varying(25),
ws_droge_bedding smallint,
ws_ohplicht smallint,
ws_soort_vak smallint,
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
shape_length double precision,
wkb_geometry geometry(MultiLineString,28992),
nxt.channel
id serial NOT NULL,
organisation_id integer,
created timestamp with time zone NOT NULL,
code character varying(50),
type character varying(50) NOT NULL,
bed_level double precision,
comment text,
name character varying(255) NOT NULL,
talud_left double precision,
talud_right double precision,
image_url character varying(2048),
geometry geometry(LineStringZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
damo_ruw.categorieoppwaterlichaam
1 primair
2 secundair
3 tertiair
99 overig
damo_ruw.soortoppwaterkwantiteit
6 Boezemwater
10 Hoofdwaterloop
22 Schouwsloot
37 Wegsloot
901 Boezemvaarweg
902 Poldervaarweg
903 Dijksloot HHNK
904 Dijksloot derden
905 Spoorsloot
906 Rijkswegsloot
907 Wegsloot derden
908 Wegsloot HHNK
909 Stedelijk HHNK
910 Stedelijk derden
911 Natuurwater
912 Schouwsloot breed
913 Schouwsloot HHNK
914 Waterberging HHNK
915 Overig
*/
/*
DROP TABLE IF EXISTS nxt.channel;
CREATE TABLE nxt.channel
(
id serial NOT NULL,
organisation_id integer,
created timestamp with time zone NOT NULL,
code character varying(50),
type character varying(50) NOT NULL,
bed_level double precision,
comment text,
name character varying(255) NOT NULL,
talud_left double precision,
talud_right double precision,
image_url character varying(2048),
geometry geometry(LineStringZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
CONSTRAINT hydra_core_channel_pkey PRIMARY KEY (id)
)
WITH (
OIDS=FALSE
);
drop sequence if exists serial;
create sequence serial start 1;
drop table if exists tmp.hydroobject_sp;
create table tmp.hydroobject_sp as
select nextval('serial') as serial,
objectid,
ws_in_peilgebied,
soortoppwaterkwantiteit,
categorieoppwaterlichaam,
ws_bodemhoogte,
ws_talud_links,
ws_talud_rechts,
ws_bodembreedte,
case
when (objectid, code) is null then null
else concat(objectid, '-', code)
end,
(st_dump(st_collect(st_transform(wkb_geometry, 4326)))).geom AS geom
from damo_ruw.hydroobject group by objectid;
alter table nxt.channel add column channel_type_id integer;
alter table nxt.channel add column bed_width double precision;
alter table nxt.channel add column width_at_waterlevel double precision;
delete from nxt.channel;
insert into nxt.channel(id, created, code, channel_type_id, type, name, bed_level, talud_left, talud_right, bed_width, width_at_waterlevel, geometry)
select serial,
now(),
case when (ws_in_peilgebied = ' ') IS NOT FALSE then 'LEEG' ELSE ws_in_peilgebied END, -- code::varchar
case when categorieoppwaterlichaam is null then 9999 else categorieoppwaterlichaam end, -- channel_type_id::integer --> 1= primair, 2=secudair, 3=tertair. Of het boezem is staat in kolom hiernaast (name='Boezemwater' of 'Boezemvaarweg' ??)
case -- type::varchar
when soortoppwaterkwantiteit is null then 'LEEG'
when soortoppwaterkwantiteit = 6 then 'Boezemwater'
when soortoppwaterkwantiteit = 10 then 'Hoofdwaterloop'
when soortoppwaterkwantiteit = 22 then 'Schouwsloot'
when soortoppwaterkwantiteit = 37 then 'Wegsloot'
when soortoppwaterkwantiteit = 901 then 'Boezemvaarweg'
when soortoppwaterkwantiteit = 902 then 'Poldervaarweg'
when soortoppwaterkwantiteit = 903 then 'Dijksloot HHNK'
when soortoppwaterkwantiteit = 904 then 'Dijksloot derden'
when soortoppwaterkwantiteit = 905 then 'Spoorsloot'
when soortoppwaterkwantiteit = 906 then 'Rijkswegsloot'
when soortoppwaterkwantiteit = 907 then 'Wegsloot derden'
when soortoppwaterkwantiteit = 908 then 'Wegsloot HHNK'
when soortoppwaterkwantiteit = 909 then 'Stedelijk HHNK'
when soortoppwaterkwantiteit = 910 then 'Stedelijk derden'
when soortoppwaterkwantiteit = 911 then 'Natuurwater'
when soortoppwaterkwantiteit = 912 then 'Schouwsloot breed'
when soortoppwaterkwantiteit = 913 then 'Schouwsloot HHNK'
when soortoppwaterkwantiteit = 914 then 'Waterberging HHNK'
when soortoppwaterkwantiteit = 915 then 'Overige'
else 'LEEG'
end,
concat, -- name::varchar --> objectid-code (van damo.hydroobject) wordt name (van nxt.channel) voor koppelen van tabellen
ws_bodemhoogte,
ws_talud_links,
ws_talud_rechts,
ws_bodembreedte,
'9999' as width_at_waterlevel,
st_force3d(geom) from tmp.hydroobject_sp;
*/
-- hydra_core_channelsurface
-- code NOT NULL + UNIQUE
/*
nxt.channelsurface
id serial NOT NULL,
organisation_id integer,
created timestamp with time zone NOT NULL,
code character varying(50),
image_url character varying(2048),
geometry geometry(MultiPolygonZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
tmp.waterdeel
objectid serial NOT NULL,
bgtstatus smallint,
bgttype smallint,
bronhouder character varying(250),
code character varying(50),
detailniveaugeometrie double precision,
eindregistratie timestamp with time zone,
inonderzoek character varying(1),
lokaalid character varying(50) NOT NULL,
lvpublicatiedatum timestamp with time zone,
naamspace character varying(50),
objectbegintijd timestamp with time zone,
objecteindtijd timestamp with time zone,
plustype smallint,
relatievehoogteligging smallint,
hydroobjectid integer,
metadataid integer,
tijdstipregistratie timestamp with time zone,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
shape_length double precision,
shape_area double precision,
wkb_geometry geometry(MultiPolygon,28992),
*/
insert into nxt.channelsurface
    (id
      , created
      , code
      , geometry
    )
select
    objectid
  , now()
  , code
  , ST_Force3d(ST_CollectionExtract(ST_MakeValid(st_transform(wkb_geometry,4326)),3))::geometry(MultiPolygonZ) -- want nxt.geometry is 3D (met z-coordinaat)
from
    tmp.waterdeel
;

/*
hydra_core_pumpstation
- code UNIQUE
- name wel NULL
- from_fixeddrainagelevelarea_code toevoegen
- to_fixeddrainagelevelarea_code toevoegen
- channel_code toevoegen
*/
/*
nxt.pumpstation
id serial NOT NULL,
organisation_id integer,
created timestamp with time zone NOT NULL,
code character varying(50),
type character varying(50) NOT NULL,
start_point_id integer,
end_point_id integer,
connection_serial integer,
capacity double precision,
start_level double precision,
stop_level double precision,
name character varying(255) NOT NULL,
allowed_flow_direction integer,
start_level_delivery_side double precision,
stop_level_delivery_side double precision,
image_url character varying(2048),
geometry geometry(PointZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
num_timeseries integer NOT NULL,
damo_ruw.gemaal
objectid serial NOT NULL,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
indicatiewaterkerend smallint,
richting real,
functiegemaal smallint,
maximalecapaciteit double precision,
CAST(ws_categorie AS INT) smallint,
ws_op_afstand_beheerd character varying(3),
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
ws_inlaatfunctie character varying(3),
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
wkb_geometry geometry(Point,28992),
in lizard wordt onderscheidt gemaakt in:
HOUSEHOLD = 'Drukgemaal'
SEWER = 'Rioolgemaal'
TRANSPORT = 'Transportgemaal'
UNDER = 'Onderbemaling'
POLDER = 'Poldergemaal'
BOSOM = 'Boezemgemaal'
OTHER = 'Gemaal'
Wij maken voor BWN2 nu eigen types aan (zo veel mogelijk zelfde als damo_ruw types)
damo_ruw.functiegemaal (smallint)
1 Aanvoergemaal
2 Afvoergemaal
3 Opmaling
4 Onderbemaling
5 Af- en Aanvoergemaal
6 Noodpomp
99 Onbekend
damo_ruw.ws_functie_gemaal (smallint)
1 aanvoergemaal
2 afvoergemaal
3 opmaling
4 onderbemaling
5 af- en aanvoergemaal
6 noodpomp
901 onderbemalingspomp; aanwezig, maar niet meer in gebruik
902 trekkerpomp, niet standaard aanwezig
99 onbekend
903 op- en onderbemaling
nxt.pump
1   Aanvoergemaal
2   Afvoergemaal
3   Opmaling
4   Onderbemaling
5   Af- en aanvoergemaal
6   Noodpomp
7   Boezemgemaal
8   onderbemalingspomp; aanwezig, maar niet meer in gebruik
9   trekkerpomp, niet standaard aanwezig
10  op- en onderbemaling
*/
-- Toegevoegd: 98 doorspoelgemaal
-- Toegevoegd: 99 overig
alter table nxt.pumpstation add column channel_type_id integer
;

alter table nxt.pumpstation add column from_fixeddrainagelevelarea_code varchar
;

alter table nxt.pumpstation add column to_fixeddrainagelevelarea_code varchar
;

alter table nxt.pumpstation add column channel_code integer
;

DROP SEQUENCE IF EXISTS serial;
CREATE SEQUENCE serial START 1;
delete
from
    nxt.pumpstation
;

insert into nxt.pumpstation
    (id
      , code
      , created
      , channel_type_id
      , type
      , name
      , num_timeseries
      , capacity
      , geometry
    )
select
    objectid
  , case
        when (
                code = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE code
    END
  , now()
  , case
        when CAST(ws_categorie AS INT)is null
            then 9999
        when CAST(ws_categorie AS INT) > 4
            then 9999
            else CAST(ws_categorie AS INT) -- channel_type_id = 1 primair, 2 secundair, 3 tertiair
    end
  , case
        when functiegemaal is null
            then 9999 -- nxt.pump heeft ook nog type 7 (boezemgemaal, maar die is niet in damo getypeerd)
        when functiegemaal = 1
            then 1 -- aanvoergemaal wordt aanvoergemaal
        when functiegemaal = 2
            then 2 -- afvoergemaal wordt afvoergemaal
        when functiegemaal = 3
            then 3 -- opmaling wordt opmaling
        when functiegemaal = 4
            then 4 -- onderbemaling wordt onderbemaling
        when functiegemaal = 5
            then 5 -- af- en aanvoergemaal wordt af- en aanvoergemaal
        when functiegemaal = 6
            then 6 -- noodpomp wordt noodpomp
        when functiegemaal = 901
            then 99 -- onderbemalingspomp-aanwezig-maar niet meer in gebruik wordt overig
        when functiegemaal = 902
            then 99 -- trekkerpomp-niet standaard aanwezig wordt overig
        when functiegemaal = 903
            then 99 -- op- en onderbemaling wordt overig
        when functiegemaal = 904
            then 98   -- doorvoergemaal
            else 9999 -- de rest (dus ook 99 onbekend) wordt 9999
    end
  , case
        when (
                naam = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE naam
    END
  , '9999' as num_timeseries
  , maximalecapaciteit
  ,                                                               -- m3/uur naar m3/min
    st_force3d(st_transform(wkb_geometry,4326))::geometry(PointZ) -- van Point naar PointZ ??
from
    damo_ruw.gemaal
;

-- hydra_core_pump
-- direction double precision toevoegen
/*
nxt.pump
id serial NOT NULL,
pump_station_id integer NOT NULL,
code character varying(50) NOT NULL,
serial integer,
capacity double precision,
start_level double precision,
stop_level double precision,
name character varying(255) NOT NULL,
type character varying(50) NOT NULL,
reduction_factor_no_levels double precision,
reduction_factor double precision,
characteristics character varying(255),
allowed_flow_direction integer,
start_level_delivery_side double precision,
stop_level_delivery_side double precision,
created timestamp with time zone NOT NULL,
damo_ruw.gemaal
objectid serial NOT NULL,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
indicatiewaterkerend smallint,
richting real,
functiegemaal smallint,
maximalecapaciteit double precision,
CAST(ws_categorie AS INT) smallint,
ws_op_afstand_beheerd character varying(3),
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
ws_inlaatfunctie character varying(3),
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
wkb_geometry geometry(Point,28992),
*/
-- nxt.pumps (tabel zonder geom) doen we niet mee
/*
alter table nxt.pump add column channel_type_id integer;
alter table nxt.pump add column direction integer;
insert into nxt.pump(id, pump_station_id, code, capacity, name, channel_type_id, type, created)
select objectid,
objectid,
case when (code = ' ') IS NOT FALSE then 'LEEG' ELSE code END,
maximalecapaciteit,
case when (naam = ' ') IS NOT FALSE then 'LEEG' ELSE naam END,
case
when CAST(ws_categorie AS INT) is null then 9999
when CAST(ws_categorie AS INT) > 4 then 9999 else CAST(ws_categorie AS INT) -- channel_type_id = 1 primair, 2 secundair, 3 tertiair
end,
case
when functiegemaal is null then 9999 -- nxt.pump heeft ook nog type 7 (boezemgemaal, maar die is niet in damo getypeerd)
when functiegemaal = 1 then 1 -- aanvoergemaal wordt aanvoergemaal
when functiegemaal = 2 then 5 -- afvoergemaal wordt afvoergemaal
when functiegemaal = 3 then 3 -- opmaling wordt opmaling
when functiegemaal = 4 then 4 -- onderbemaling wordt onderbemaling
when functiegemaal = 5 then 2 -- af- en aanvoergemaal wordt af- en aanvoergemaal
when functiegemaal = 6 then 5 -- noodpomp wordt noodpomp
else 9999 -- 901 (onderbemalingspomp; aanwezig, maar niet meer in gebruik), 902 (trekkerpomp, niet standaard aanwezig), 99 (onbekend), 903 (op- en onderbemaling) wordt 9999
end,
now() from damo_ruw.gemaal;
*/
/*
hydra_core_weir
- code NOT NULL + UNIQUE
- name wel NULL
- crest_level wordt maximum_crest_level
- type waarvoor nu gebruikt? kan voor vispassage
- shape integer toevoegen
- controlled_fixeddrainagelevelarea_code toevoegen
- channel_code toevoegen
nxt.weir
id serial NOT NULL,
organisation_id integer,
created timestamp with time zone NOT NULL,
code character varying(50),
type character varying(50) NOT NULL,
crest_width double precision,
crest_level double precision,
name character varying(255) NOT NULL,
lat_dis_coeff double precision,
angle double precision,
allowed_flow_direction integer,
controlled integer,
comment text,
discharge_coeff double precision,
image_url character varying(2048),
geometry geometry(PointZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
num_timeseries integer NOT NULL,
damo_ruw.stuw
objectid serial NOT NULL,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
indicatiewaterkerend smallint,
soortstuw smallint,
doorstroombreedte double precision,
kruinbreedte double precision,
laagstedoorstroomhoogte double precision,
hoogstedoorstroomhoogte double precision,
soortregelbaarheid smallint,
richting real,
CAST(ws_categorie AS INT) smallint,
ws_kruinvorm smallint,
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
ws_functiestuw smallint,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
wkb_geometry geometry(Point,28992)
damo_ruw.stuw.ws_kruinvorm
1 rechthoek
2 driehoek
3 trapezium
4 parabool
5 cirkel
6 kruin met speciale vorm
99 onbekend
nxt.weir.shape
1 rectangle
2 Circle
3 Egg
4 Tabulated rectangle
5 Tabulated trapezium
6 Onbekend
damo_ruw.damo.soortregelbaarheid
1 niet regelbaar (vast)
2 regelbaar, niet automatisch
3 regelbaar, automatisch
4 handmatig
5   niet regelbaar (vispassage) <-- bedacht door renier
99 overig
nxt.weir.type               --> deze zou ik eigenlijk nxt.weir.type_control willen noemen...
1   Niet regelbaar, vast stuw
2   Sturing: vasthouden     --> renier veranderd in regelbaar, niet automatisch
3   Sturing: afvoeren       --> renier veranderd in regelbaar, automatisch
4   handmatig               --> nieuw / toegevoegd door renier
damo_ruw.stuw.ws_functiestuw
1 aanvoerstuw (inlaat)
2 afvoerstuw
3 aan- en afvoerstuw
4 terugloopvoorziening
nxt.weir.type_function      --> zelf toegevoegde kolom door renier
1 aanvoerstuw (inlaat)
2 afvoerstuw
3 aan- en afvoerstuw
4 terugloopvoorziening
*/
alter table nxt.weir add column shape integer
;

-- alter table nxt.weir alter column code not null
alter table nxt.weir add column controlled_ficeddrainagelevelarea_code integer
;

alter table nxt.weir add column channel_code integer
;

alter table nxt.weir add column type_function integer
;

alter table nxt.weir add column channel_type_id integer
;

delete
from
    nxt.weir
;

insert into nxt.weir
    (id
      , created
      , code
      , type
      , type_function
      , channel_type_id
      , crest_width
      , crest_level
      , name
      , geometry
      , num_timeseries
      , shape
    )
select
    objectid
  , now()
  , case
        when (
                code = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE code
    END
  , -- code
    case
        when soortregelbaarheid is null
            then 9999
            else soortregelbaarheid
    end
  , -- type
    case
        when ws_functiestuw is null
            then 9999
            else ws_functiestuw
    end
  , -- type_function
    case
        when CAST(ws_categorie AS INT) is null
            then 9999
        when CAST(ws_categorie AS INT) > 4
            then 9999
            else CAST(ws_categorie AS INT) -- channel_type_id = 1 primair, 2 secundair, 3 tertiair
    end
  , case
        when kruinbreedte         is not null
            and doorstroombreedte is not null
            and kruinbreedte                > doorstroombreedte
            then doorstroombreedte
        when kruinbreedte         is not null
            and doorstroombreedte is not null
            and kruinbreedte                < doorstroombreedte
            then kruinbreedte
        when doorstroombreedte is not null
            then doorstroombreedte
        when kruinbreedte is not null
            then kruinbreedte
    end
  , laagstedoorstroomhoogte
  , case
        when (
                naam = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE naam
    END
  , st_force3d(st_transform(wkb_geometry,4326))::geometry(PointZ)
  , -- van Point naar PointZ ??
    '9999' as num_timeseries
  , case
        when ws_kruinvorm = 1
            then 1 -- rechthoek wordt rectangle
        when ws_kruinvorm = 2
            then 5 -- driehoek wordt tabulated trapezium
        when ws_kruinvorm = 3
            then 5 -- trapezium wordt tabulated trapezium
        when ws_kruinvorm = 4
            then 3 -- parabool wordt egg
        when ws_kruinvorm = 5
            then 2 -- cirkel wordt cirkel
        when ws_kruinvorm = 6
            then 4 -- kruin met speciale vorm wordt tabulated rectangle
        when ws_kruinvorm = 99
            then 9999 -- onbekend wordt leeg veld
        when ws_kruinvorm is null
            then 9999 -- leeg veld wordt leeg veld
            else 9999
    end
from
    damo_ruw.stuw
;

-- laagstedoorstroomhoogte en hoogstedoorstroomhoogte is niet handig om als crest_level voor stuwen. Want dat is bandbreedte.
--> op basis van streefpeil crest_level instellen
/*
-- de vispassage (als punt aangeleverd) vullen we in in nxt.weir
damo_ruw.vispassage
objectid serial NOT NULL,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
soortvispassage smallint,
richting real,
CAST(ws_categorie AS INT) smallint,
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
wkb_geometry geometry(Point,28992),
nxt.weir
id serial NOT NULL,
shape,
controlled_ficeddrainagelevelarea_code,
type_function integer,
channel_type_id,
channel_code integer ,
code character varying(50),
organisation_id integer,
created timestamp with time zone NOT NULL,
type character varying(50) NOT NULL,
crest_width double precision,
crest_level double precision,
name character varying(255) NOT NULL,
lat_dis_coeff double precision,
angle double precision,
allowed_flow_direction integer,
controlled integer,
comment text,
discharge_coeff double precision,
image_url character varying(2048),
geometry geometry(PointZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
num_timeseries integer NOT NULL,
*/
drop sequence if exists serial;
create sequence serial;
select
    setval('serial', max(id))
from
    nxt.weir
;

insert into nxt.weir
    (id
      , created
      , code
      , type
      , type_function
      , channel_type_id
      , name
      , geometry
      , num_timeseries
    )
select
    nextval('serial')
  , now()
  , case
        when (
                code = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE code
    END
  , -- code
    5
  , -- type
    9999
  , -- type_fuctnion =9999 want niet aan-, af- of terugloopvoorziening
    case
        when CAST(ws_categorie AS INT) is null
            then 9999
        when CAST(ws_categorie AS INT) > 4
            then 9999
            else CAST(ws_categorie AS INT) -- channel_type_id = 1 primair, 2 secundair, 3 tertiair
    end
  , case
        when (
                naam = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE naam
    END
  , -- name
    st_force3d(st_transform(wkb_geometry,4326))::geometry(PointZ)
  , -- van Point naar PointZ ??
    '9999' as num_timeseries
from
    damo_ruw.vispassage
;

/*
hydra_core_culvert
- code NOT NULL + UNIQUE
- type wordt integer
- channel_code toevoegen
damo_ruw.duikersifonhevel
objectid serial NOT NULL,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
indicatiewaterkerend smallint,
lengte double precision,
hoogteopening double precision,
breedteopening double precision,
hoogtebinnenonderkantbene double precision,
hoogtebinnenonderkantbov double precision,
vormkoker smallint,
soortmateriaal smallint,
typekruising smallint,
CAST(ws_categorie AS INT) smallint,
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
ws_inlaatfunctie character varying(3),
ws_afsluitwijze1 smallint,
ws_afsluitwijze2 smallint,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
shape_length double precision,
wkb_geometry geometry(MultiLineString,28992),
nxt.culvert
id serial NOT NULL,
organisation_id integer,
created timestamp with time zone NOT NULL,
code character varying(50),
type character varying(50) NOT NULL,
bed_level_upstream double precision,
bed_level_downstream double precision,
width double precision,
length double precision,
allowed_flow_direction integer,
height double precision,
material integer,
shape integer,
description text,
image_url character varying(2048),
geometry geometry(LineStringZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
num_timeseries integer NOT NULL,
damo_ruw.stuw.ws_afsluitwijze1 en damo_ruw.stuw.ws_afsluitwijze2
1 deur
2 schotbalk sponning
3 zandzakken
4 schuif
5 terugslagklep
6 tolklep
97 niet afsluitbaar
98 overig
99 onbekend
901 vlinderklep
902 stuw
903 spindel
damo_ruw.stuw.vormkoker
1 Rond
2 Driehoekig
3 Rechthoekig
4 Eivormig
5 Ellipsvormig
6 Paraboolvormig --> vlak aan de onderkant
7 Trapeziumvormig
8 Heulprofiel
9 Muilprofiel
10 Langwerpig
11 Scherp
99 Onbekend
--> SOBEK handleiding erbij pakken. Daar staat waarschijnlijk wel vorm beschrijving in.
nxt.culvert.shape
1 rectangle
2 Circle
3 Egg
4 Muil
5 Ellips
6 Heul
7 Onbekend
nxt.culvert.material
1 Beton
2 Pvc
3 Gres
4 Gietijzer
5 Metselwerk
6 HPE
7 LDPE
8 Plaatijzer
9 Staal
damo_ruw.duikersifonhevel.soortmateriaal
1 aluminium
2 asbestcement
3 beton
4 gegolfd plaatstaal
5 gewapend beton
6 gietijzer
7 glad staal
8 glas
9 grasbetontegels
10 hout
11 ijser
12 koper
13 kunststof
14 kuststoffolie
15 kurk
16 lood
17 metselwerk
18 plaatstaal
19 puinsteen
20 PVC
21 staal
22 steen
23 voorgespannen beton
..
98 onbekend
99 overig
*/
drop sequence if exists serial;
create sequence serial start 1;
drop table if exists tmp.duikersifonhevel_sp
;

create table tmp.duikersifonhevel_sp as
select
    nextval('serial') as serial
  , objectid
  , code
  , case
        when (
                objectid, code
            )
            is null
            then null
            else concat(objectid, '-', code)
    end
  , naam
  , opmerking
  , indicatiewaterkerend
  , indpeilregulpeilscheidend
  , lengte
  , hoogteopening
  , breedteopening
  , hoogtebinnenonderkantbene
  , hoogtebinnenonderkantbov
  , vormkoker
  , soortmateriaal
  , typekruising
  , CAST(ws_categorie AS INT)
  , ws_bron
  , ws_inwinningswijze
  , ws_inwinningsdatum
  , ws_inlaatfunctie
  , ws_afsluitwijze1
  , ws_afsluitwijze2
  , (st_dump(st_collect(st_transform(wkb_geometry, 4326)))).geom AS geom
from
    damo_ruw.duikersifonhevel
group by
    objectid
;

delete
from
    nxt.culvert
;

alter table nxt.culvert add column channel_code integer
;

alter table nxt.culvert add column channel_type_id integer
;

alter table nxt.culvert add column type_art integer
;

alter table nxt.culvert alter column type type integer
using type::integer
;

alter table nxt.culvert add column level_seperator_indicator boolean
;

insert into nxt.culvert
    (id
      , created
      , code
      , channel_type_id
      , type_art
      , type
      , level_seperator_indicator
      , bed_level_upstream
      , bed_level_downstream
      , width
      , height
      , length
      , material
      , shape
      , num_timeseries
      , geometry
    )
select
    objectid
  , now()
  , code
  ,      -- code
    case -- channel_type_id = 1 primair, 2 secundair, 3 tertiair
        when CAST(ws_categorie AS INT) is null
            then 9999
        when CAST(ws_categorie AS INT) > 4
            then 9999
            else CAST(ws_categorie AS INT)
    end
  , case -- type_art = duiker (omdat typekruising = 1 Aquaduct, 2 Brug, 3 Duiker, 4 Sifon, 5 Hevel, 6 Bypass)
        when typekruising = 3
            then 1 -- damo_ruw.duikersifonhevel.typekruising=duiker wordt nxt.culvert.type_art=duiker (type_art =1)
        when typekruising = 4
            then 2 -- damo_ruw.duikersifonhevel.typekruising=sifon wordt nxt.culvert.type_art=sifon (type_art =2)
    end
  , case -- type
        when typekruising        = 3
            and ws_inlaatfunctie = 'j'
            and (
                ws_afsluitwijze1 = 97
                and (
                    ws_afsluitwijze2          = 97
                    or ws_afsluitwijze2 is null
                )
            )
            then 1 -- 113 niet afsluitbare inlaat duikers
        when typekruising        = 3
            and ws_inlaatfunctie = 'n'
            and (
                ws_afsluitwijze1 = 97
                and (
                    ws_afsluitwijze2          = 97
                    or ws_afsluitwijze2 is null
                )
            )
            then 2 -- 13170 niet afsluitbare duikers (anders dan inlaat duiker)
            --when typekruising = 3 and ws_inlaatfunctie = 'j' and ((ws_afsluitwijze1 is not null and ws_afsluitwijze1 != 99) or (ws_afsluitwijze2 is not null and ws_afsluitwijze2 != 99)) then 3 -- 1479 afsluitbare inlaat duikers
            --when  typekruising = 3 and ws_inlaatfunctie = 'n' and ((ws_afsluitwijze1 is not null and ws_afsluitwijze1 != 99) or (ws_afsluitwijze2 is not null and ws_afsluitwijze2 != 99)) then 4 -- 14590 afsluitbare duikers (anders dan inlaat duiker)
        when typekruising        = 3
            and ws_inlaatfunctie = 'j'
            and (
                ws_afsluitwijze1    is not null
                or ws_afsluitwijze2 is not null
            )
            then 3 -- 1479 afsluitbare inlaat duikers
        when typekruising        = 3
            and ws_inlaatfunctie = 'n'
            and (
                ws_afsluitwijze1    is not null
                or ws_afsluitwijze2 is not null
            )
            then 4 -- 14590 afsluitbare duikers (anders dan inlaat duiker)
        when typekruising        = 4
            and ws_inlaatfunctie = 'j'
            and (
                ws_afsluitwijze1 = 97
                and (
                    ws_afsluitwijze2          = 97
                    or ws_afsluitwijze2 is null
                )
            )
            then 5 -- 0 niet afsluitbare inlaat sifons = logisch
        when typekruising        = 4
            and ws_inlaatfunctie = 'n'
            and (
                ws_afsluitwijze1 = 97
                and (
                    ws_afsluitwijze2          = 97
                    or ws_afsluitwijze2 is null
                )
            )
            then 6 -- 0 niet afsluitbare sifons (anders dan inlaat sifon) = logisch
        when typekruising        = 4
            and ws_inlaatfunctie = 'j'
            and (
                (
                    ws_afsluitwijze1 is not null
                    and ws_afsluitwijze1      != 99
                )
                or (
                    ws_afsluitwijze2 is not null
                    and ws_afsluitwijze2      != 99
                )
            )
            then 7 -- 4 afsluitbare inlaat sifons = ??? zijn er inlaat sifons?
        when typekruising        = 4
            and ws_inlaatfunctie = 'n'
            and (
                (
                    ws_afsluitwijze1 is not null
                    and ws_afsluitwijze1      != 99
                )
                or (
                    ws_afsluitwijze2 is not null
                    and ws_afsluitwijze2      != 99
                )
            )
            then 8 -- 189 afsluitbare sifons (anders dan inlaat sifon)
            else 9999
    end
  , CASE indpeilregulpeilscheidend
        WHEN 'j'
            THEN TRUE
        WHEN 'n'
            THEN FALSE
        WHEN 'o'
            THEN NULL
            ELSE NULL
    END
  , hoogtebinnenonderkantbov
  , hoogtebinnenonderkantbene
  , breedteopening
  , hoogteopening
  , lengte
  , case
        when soortmateriaal is null
            then 9999 -- leeg veld wordt leeg veld
        when soortmateriaal = 1
            then 9 -- 1 aluminium wordt 9 Staal
        when soortmateriaal = 2
            then 5 -- 2 asbestcement wordt 5 Metselwerk
        when soortmateriaal = 3
            then 1 -- 3 beton wordt 1 Beton
        when soortmateriaal = 4
            then 9 -- 4 gegolfd plaatstaal wordt 9 Staal
        when soortmateriaal = 5
            then 5 -- 5 gewapend beton wordt 5 Metselwerk
        when soortmateriaal = 6
            then 4 -- 6 gietijzer wordt 4 Gietijzer
        when soortmateriaal = 7
            then 9 -- 7 glad staal wordt 9 Staal
        when soortmateriaal = 8
            then 6 -- 8 glas wordt 6 HPE
        when soortmateriaal = 9
            then 5 -- 9 grasbetontegels wordt 5 Metselwerk
        when soortmateriaal = 10
            then 7 -- 10 hout wordt 7 LDPE
        when soortmateriaal = 11
            then 8 -- 11 ijser wordt 8 Plaatijzer
        when soortmateriaal = 12
            then 4 -- 12 koper wordt 4 Gietijzer
        when soortmateriaal = 13
            then 2 -- 13 kunststof wordt 2 Pvc
        when soortmateriaal = 14
            then 2 -- 14 kuststoffolie wordt 2 Pvc
        when soortmateriaal = 15
            then 5 -- 15 kurk 5 wordt Metselwerk
        when soortmateriaal = 16
            then 4 -- 16 lood 4 wordt Gietijzer
        when soortmateriaal = 17
            then 5 -- 17 metselwerk wordt 5 Metselwerk
        when soortmateriaal = 18
            then 9 -- 18 plaatstaal wordt 9 Staal
        when soortmateriaal = 19
            then 5 -- 19 puinsteen wordt 5 Metselwerk
        when soortmateriaal = 20
            then 2 -- 20 PVC wordt 2 Pvc
        when soortmateriaal = 21
            then 9 -- 21 staal wordt 9 Staal
        when soortmateriaal = 22
            then 1 -- 22 steen wordt 1 Beton
        when soortmateriaal = 23
            then 1 -- 23 voorgespannen beton wordt 1 Beton
        when soortmateriaal = 98
            then 9999 -- onbekend wordt leeg veld
        when soortmateriaal = 99
            then 9999 -- overig wordt leeg veld
            else 9999
    end
  , case
        when vormkoker is null
            then 9999 -- leeg wordt leeg
        when vormkoker = 1
            then 2 -- rond wordt circle
        when vormkoker = 2
            then 1 -- driehoekig wordt rectangle
        when vormkoker = 3
            then 1 -- rechthoekig wordt rectangle
        when vormkoker = 4
            then 3 -- eivormig wordt egg
        when vormkoker = 5
            then 5 -- ellipsvormig wordt ellips
        when vormkoker = 6
            then 4 -- paraboolvormig wordt muil
        when vormkoker = 7
            then 6 -- trapeziumvormig wort heul
        when vormkoker = 8
            then 6 -- heulprofiel wordt heul
        when vormkoker = 9
            then 4 -- muilprofiel wordt muil
        when vormkoker = 10
            then 1 -- langwerpig wordt rectangle
        when vormkoker = 11
            then 1 -- scherp wordt rectangle
        when vormkoker = 99
            then 9 -- onbekend wordt onbekend
            else 9999
    end
  , '9999' as num_timeseries
  , st_force3d(st_transform(geom,4326))::geometry(LineStringZ) -- van (wkb_geometry, 4326) naar geometry geometry(LineStringZ,4326),
 from
    tmp.duikersifonhevel_sp
where
    (
        typekruising    = 3
        or typekruising = 4
    )
    AND code NOT IN ('KDU-P-36517'
                   ,'KDU-M-4872')
; -- damo_ruw.duikersifonhevel.typekruising = 1 Aquaduct, 2 Brug, 3 Duiker, 4 Sifon, 5 Hevel, 6 Bypass
-- 1, 2 en 6 hebben 0 rijen
--select * from tmp.duikersifonhevel_sp where typekruising = 4
--277 sifons (wel in lizard, niet in 3di, want aanvoer en daar doen we niets mee)
--select * from tmp.duikersifonhevel_sp where typekruising = 5
--116 hevels (wel in lizard, ook in 3di nodig)
DROP SEQUENCE IF EXISTS seq_nxt_culvert;
CREATE SEQUENCE seq_nxt_culvert START 1;
SELECT
    setval('seq_nxt_culvert', (
        SELECT
            max(id)
        FROM
            nxt.culvert
    )
    )
;

INSERT INTO nxt.culvert
    (id
      , created
      , code
      , channel_type_id
      , type_art
      , type
      , bed_level_upstream
      , bed_level_downstream
      , width
      , height
      , length
      , material
      , shape
      , num_timeseries
      , geometry
    )
SELECT
    nextval('seq_nxt_culvert')
  , now()
  , code
  , CASE -- channel_type_id = 1 primair, 2 secundair, 3 tertiair
        WHEN CAST(ws_categorie AS INT) IS NULL
            THEN 9999
        WHEN CAST(ws_categorie AS INT) > 4
            THEN 9999
            ELSE CAST(ws_categorie AS INT)
    END
  , 2
  , --Aquaduct als syfon nxt.culvert.type = 2
    6
  , --niet afsluitbare syfon (geen inlaat)
    bodemhoogtebovenstrooms
  , bodemhoogtebenedenstrooms
  , CASE
        WHEN breedte IS NULL
            THEN ws_bovenbreedte
            ELSE breedte
    END
  , 10
  , shape_length
  , case
        when soortmateriaal is null
            then 9999 -- leeg veld wordt leeg veld
        when soortmateriaal = 1
            then 9 -- 1 aluminium wordt 9 Staal
        when soortmateriaal = 2
            then 5 -- 2 asbestcement wordt 5 Metselwerk
        when soortmateriaal = 3
            then 1 -- 3 beton wordt 1 Beton
        when soortmateriaal = 4
            then 9 -- 4 gegolfd plaatstaal wordt 9 Staal
        when soortmateriaal = 5
            then 5 -- 5 gewapend beton wordt 5 Metselwerk
        when soortmateriaal = 6
            then 4 -- 6 gietijzer wordt 4 Gietijzer
        when soortmateriaal = 7
            then 9 -- 7 glad staal wordt 9 Staal
        when soortmateriaal = 8
            then 6 -- 8 glas wordt 6 HPE
        when soortmateriaal = 9
            then 5 -- 9 grasbetontegels wordt 5 Metselwerk
        when soortmateriaal = 10
            then 7 -- 10 hout wordt 7 LDPE
        when soortmateriaal = 11
            then 8 -- 11 ijser wordt 8 Plaatijzer
        when soortmateriaal = 12
            then 4 -- 12 koper wordt 4 Gietijzer
        when soortmateriaal = 13
            then 2 -- 13 kunststof wordt 2 Pvc
        when soortmateriaal = 14
            then 2 -- 14 kuststoffolie wordt 2 Pvc
        when soortmateriaal = 15
            then 5 -- 15 kurk 5 wordt Metselwerk
        when soortmateriaal = 16
            then 4 -- 16 lood 4 wordt Gietijzer
        when soortmateriaal = 17
            then 5 -- 17 metselwerk wordt 5 Metselwerk
        when soortmateriaal = 18
            then 9 -- 18 plaatstaal wordt 9 Staal
        when soortmateriaal = 19
            then 5 -- 19 puinsteen wordt 5 Metselwerk
        when soortmateriaal = 20
            then 2 -- 20 PVC wordt 2 Pvc
        when soortmateriaal = 21
            then 9 -- 21 staal wordt 9 Staal
        when soortmateriaal = 22
            then 1 -- 22 steen wordt 1 Beton
        when soortmateriaal = 23
            then 1 -- 23 voorgespannen beton wordt 1 Beton
        when soortmateriaal = 98
            then 9999 -- onbekend wordt leeg veld
        when soortmateriaal = 99
            then 9999 -- overig wordt leeg veld
            else 9999
    end
  , 1
  , --vorm
    '9999' as num_timeseries
  , st_force3d(st_transform((ST_Dump(wkb_geometry)).geom,4326))::geometry(LineStringZ) -- van (wkb_geometry, 4326) naar geometry geometry(LineStringZ,4326),
 from
    damo_ruw.aquaductlijn
;

/*
hydra_core_bridge
- code UNIQUE
- shape toevoegen
damo_ruw.brug
objectid serial NOT NULL,
code character varying(50),
opmerking character varying(250),
hoogteonderzijde double precision,
doorvaartbreedte double precision,
richting real,
CAST(ws_categorie AS INT) smallint,
ws_kbrbeweg character varying(3),
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
brug_id integer,
wkb_geometry geometry(Point,28992),
nxt.bridge
id serial NOT NULL,
organisation_id integer,
created timestamp with time zone NOT NULL,
code character varying(50),
name character varying(255) NOT NULL,
type character varying(50) NOT NULL,
width double precision,
length double precision,
height double precision,
image_url character varying(2048),
geometry geometry(PointZ,4326),
"end" timestamp with time zone,
start timestamp with time zone
*/
-- alter table nxt.bridge add column shape integer <-- shape van een brug is niet bekend
alter table nxt.bridge add column number_openings integer
;

-- alter table nxt.bridge add column total_flow_width double precision;
alter table nxt.bridge add column channel_type_id integer
;

alter table nxt.bridge add column bottom_level float
;

delete
from
    nxt.bridge
;

insert into nxt.bridge
    (id
      , created
      , code
      , name
      , type
      , width
      , bottom_level
      , channel_type_id
      , geometry
    )
select distinct
on
    (
        brug_id
    )
    brug_id
  , -- distinct want er komt eenmaal een dubbele in voor (brugid 213333)
    now()
  , code
  , -- code wordt code
    code
  , -- code wordt name want name NOT NULL
    'null'
  , -- type
    null
  , --> widht vullen we met sum(doorstroombreedte) --> dat gebeurt hieronder
    hoogteonderzijde
  , --bottom_level (mNAP)
    case
        when CAST(ws_categorie AS INT) is null
            then 9999
        when CAST(ws_categorie AS INT) > 4
            then 9999
            else CAST(ws_categorie AS INT) -- channel_type_id = 1 primair, 2 secundair, 3 tertiair
    end
  , st_force3d(st_transform(wkb_geometry,4326))::geometry(PointZ) -- van Point naar PointZ ??
from
    damo_ruw.brug
;

-- update nxt.bridge a set a.number_openings = (select max(b.ws_opening_nr) from damo_ruw.doorstroomopening b where a.brugid = b.brugid);
-- select * from nxt.bridge where number_openings is not null order by number_openings desc
-- dit geeft 19 openingen?? voor damo_ruw.brug.brug_id = 6348 (hoogste ws_operning_nr is ook 19!) terwijl er maar 13 rijen (dus 13 openingen) zijn
-- dus aantal doorstroomopeningen zelf tellen met count(*)
drop table if exists tmp.bridge
;

create table tmp.bridge as
select distinct
on
    (
        brug_id
    )
    *
from
    damo_ruw.brug
;

alter table tmp.bridge add column number_openings integer
;

alter table tmp.bridge add column total_flow_width double precision
;

with conversie as
    (
        select
            brugid
          , count(*)
        from
            damo_ruw.doorstroomopening
        group by
            brugid
    )
update
    tmp.bridge a
set number_openings = count
from
    conversie b
where
    a.brug_id = b.brugid
;

update
    tmp.bridge a
set total_flow_width =
    (
        select
            sum(b.breedteopening)
        from
            damo_ruw.doorstroomopening b
        where
            a.brug_id = b.brugid
    )
;

update
    nxt.bridge a
set number_openings = b.number_openings
from
    tmp.bridge b
where
    a.id = b.brug_id
;

update
    nxt.bridge a
set width = b.total_flow_width
from
    tmp.bridge b
where
    a.id = b.brug_id
;

/*
hydra_core_fixed_dam toevoegen
- code characte varying(50) NOT NULL + UNIQUE
- geometry  geometry(POint,28992)
- crest_level double precision
- type integer
- channel_code
damo_ruw.vastedam
objectid serial NOT NULL,
code character varying(50),
opmerking character varying(250),
richting real,
CAST(ws_categorie AS INT) smallint,
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
wkb_geometry geometry(Point,28992),
*/
-- !!!!!!!!!!! alter table (deze hele tabel is new) !!!!!!!!!!!!!!!!!!!
drop table if exists nxt.fixed_dam
;

create table nxt.fixed_dam as
select
    objectid::integer as id
  , code::varchar
  , case -- channel_type_id = 1 primair, 2 secundair, 3 tertiair
        when CAST(ws_categorie AS INT) is null
            then 9999
        when CAST(ws_categorie AS INT) > 4
            then 9999
            else CAST(ws_categorie AS INT)::integer
    end                                                           as channel_type_id
  , st_force3d(st_transform(wkb_geometry,4326))::geometry(PointZ) as geometry -- van Point naar PointZ ??
from
    damo_ruw.vastedam
;

/*
hydra_core_crosssection
- code characte varying(50) NOT NULL + UNIQUE
damo_ruw.gw_pro
pro_id serial NOT NULL,
proident character varying(24),
ovk_ovk_id integer,
prosoort smallint,
oprdatop timestamp with time zone,
osmomsch character varying(60),
geometrie_length double precision,
wkb_geometry geometry(MultiLineStringZ,28992),
damo_ruw.profielpunten
objectid serial NOT NULL,
pbpsoort smallint,
iws_tekencode smallint,
iws_volgnr integer,
iws_hoogte double precision,
iws_afstand double precision,
pro_pro_id integer,
osmomsch_1 character varying(60),
wkb_geometry geometry(PointZ,28992),
pro_pro_id van profielpunten = pro_id van gw_pro
gw_pro is een dwarslijn op een hydrovak. Koppelen op basis van geometry?
tmp.tabulated_table (gemaakt in locolhost)
ogc_fid serial NOT NULL,
defname character varying,
prw_id integer,
width character varying,
height character varying,
max_height double precision,
max_width double precision,
min double precision,
max double precision,
nr_input_points integer,
channel_id integer,
pro_id integer,
numgeometries integer,
opmerking character varying,
ovk_id integer,
wkb_geometry geometry(Point,28992),
nxt.crosssection
id serial NOT NULL,
cross_profile_id integer NOT NULL,
channel_id integer,
friction_type integer,
friction_value integer,
distance_on_channel numeric(8,2),
bed_level double precision,
bed_width double precision,
width double precision,
slope_left double precision,
slope_right double precision,
reclamation double precision,
created timestamp with time zone NOT NULL,
geometry geometry(GeometryZ,4326),
nxt.profile
id serial NOT NULL,
type integer NOT NULL,
tables character varying(50),
created timestamp with time zone NOT NULL,
CONSTRAINT hydra_core_crossprofile_pkey PRIMARY KEY (id)
*/
alter table nxt.crosssection add column bank_level float
;

alter table nxt.crosssection add column code varchar
;

alter table nxt.crosssection add column prw_id integer
;

delete
from
    nxt.crosssection
;

drop sequence if exists serial;
create sequence serial start 1;
insert into nxt.crosssection
    (id
      , created
      , cross_profile_id
      , channel_id
      , prw_id
      , bed_level
      , bank_level
      , width
      , geometry
    )
select
    nextval('serial')
  , now()
  , pro_id
  , channel_id
  , prw_id
  , min
  , max
  , max_width
  , st_force3d(st_transform(geom,4326))::geometry(PointZ)
from
    tmp.tabulated_table
;

alter table nxt.crossprofile add column width varchar
;

alter table nxt.crossprofile add column height varchar
;

alter table nxt.crossprofile add column y varchar
;

alter table nxt.crossprofile add column z varchar
;

alter table nxt.crossprofile add column diameter float
;

alter table nxt.crossprofile add column prw_id integer
;

delete
from
    nxt.crossprofile
;

insert into nxt.crossprofile
    (id
      , prw_id
      , created
      , type
      , width
      , height
    )
select
    pro_id
  , prw_id
  , now()
  , 5
  , -- type 1: rectangle = 1, circle = 2, egg = 3, tabulated_rectangle = 5, tabulated_trapezium = 6 (overgenomen van 3di versie2)
    width
  , height
from
    tmp.tabulated_table
;

/*
hydra_core_sluice
- code characte varying(50) NOT NULL + UNIQUE
- channel_code
damo_ruw.sluis
objectid serial NOT NULL,
code character varying(50),
naam character varying(100),
opmerking character varying(250),
doorvaartbreedte double precision,
indicatiewaterkerend smallint,
breedte double precision,
kerendehoogte double precision,
soortsluis smallint,
hoogtebinnenonderkantben double precision,
hoogtebinnenonderkantbov double precision,
richting real,
drempelhoogte double precision,
CAST(ws_categorie AS INT) smallint,
ws_doorvaarlengte real,
ws_doorvaardiepte real,
ws_bron character varying(255),
ws_inwinningswijze smallint,
ws_inwinningsdatum timestamp with time zone,
ws_inlaatfunctie character varying(3),
ws_afsluitwijze1 smallint,
ws_afsluitwijze2 smallint,
created_user character varying(255),
created_date timestamp with time zone,
last_edited_user character varying(255),
last_edited_date timestamp with time zone,
wkb_geometry geometry(Point,28992),
nxt.sluice
id serial NOT NULL,
organisation_id integer,
created timestamp with time zone NOT NULL,
code character varying(50),
name character varying(64) NOT NULL,
image_url character varying(2048),
geometry geometry(PointZ,4326),
"end" timestamp with time zone,
start timestamp with time zone,
*/
alter table nxt.sluice add column channel_type_id integer
;

alter table nxt.sluice add column type integer
;

alter table nxt.sluice add column width float
;

alter table nxt.sluice add column length float
;

alter table nxt.sluice add column bottom_level float
;

insert into nxt.sluice
    (id
      , created
      , name
      , code
      , channel_type_id
      , type
      , width
      , length
      , bottom_level
      , geometry
    )
select
    objectid
  , now()
  , case
        when (
                naam = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE naam
    END
  , -- name
    case
        when (
                code = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE code
    END
  ,      -- code
    case -- channel_type_id = 1 primair, 2 secundair, 3 tertiair
        when CAST(ws_categorie AS INT) is null
            then 9999
        when CAST(ws_categorie AS INT) > 4
            then 9999
            else CAST(ws_categorie AS INT)::integer
    end
  , case -- type
        when ws_inlaatfunctie = 'j'
            and (
                ws_afsluitwijze1 = 97
                and (
                    ws_afsluitwijze2          = 97
                    or ws_afsluitwijze2 is null
                )
            )
            then 1 -- niet afsluitbare inlaat sluis
        when ws_inlaatfunctie = 'n'
            and (
                ws_afsluitwijze1 = 97
                and (
                    ws_afsluitwijze2          = 97
                    or ws_afsluitwijze2 is null
                )
            )
            then 2 -- niet afsluitbare sluis (anders dan inlaat sluis)
        when ws_inlaatfunctie = 'j'
            and (
                (
                    ws_afsluitwijze1 is not null
                    and ws_afsluitwijze1      != 99
                )
                or (
                    ws_afsluitwijze2 is not null
                    and ws_afsluitwijze2      != 99
                )
            )
            then 3 -- afsluitbare inlaat sluis
        when ws_inlaatfunctie = 'n'
            and (
                (
                    ws_afsluitwijze1 is not null
                    and ws_afsluitwijze1      != 99
                )
                or (
                    ws_afsluitwijze2 is not null
                    and ws_afsluitwijze2      != 99
                )
            )
            then 4 -- afsluitbare sluis(anders dan inlaat sluis)
            else 9999
    end
  , case
        when breedte             is not null
            and doorvaartbreedte is not null
            then least(breedte, doorvaartbreedte)
        when breedte         is not null
            and doorvaartbreedte is null
            then breedte
        when breedte                 is null
            and doorvaartbreedte is not null
            then doorvaartbreedte
    end
  , ws_doorvaarlengte
  , case
        when hoogtebinnenonderkantben    is not null
            and hoogtebinnenonderkantbov is not null
            and drempelhoogte            is not null
            then greatest(hoogtebinnenonderkantben, hoogtebinnenonderkantbov, drempelhoogte)
        when hoogtebinnenonderkantben is not null
            and drempelhoogte         is not null
            then greatest(hoogtebinnenonderkantben, drempelhoogte)
        when hoogtebinnenonderkantbov is not null
            and drempelhoogte         is not null
            then greatest(hoogtebinnenonderkantbov, drempelhoogte)
        when drempelhoogte is not null
            then drempelhoogte
        when hoogtebinnenonderkantben is not null
            and hoogtebinnenonderkantbov  is null
            then hoogtebinnenonderkantben
        when hoogtebinnenonderkantben        is null
            and hoogtebinnenonderkantbov is not null
            then hoogtebinnenonderkantbov
    end
  , st_force3d(st_transform(wkb_geometry,4326))::geometry(PointZ) -- van Point naar PointZ ??
from
    damo_ruw.sluis
;

--Breng HDB.polderclusters naar nxt
DROP TABLE IF EXISTS nxt.polderclusters
;

CREATE TABLE nxt.polderclusters AS
    (
        SELECT
            objectid as id
          , polder_id
          , naam         as name
          , wkb_geometry as geom
        FROM
            hdb.polderclusters
    )
;

/*
hydra_core_waterstoragearea toevoegen
- code characte varying(50) NOT NULL + UNIQUE
- geometry  geometry(Multipolygon,28992)
- bed_level_average double precision
*/
/*
hydra_core_pumpeddrainagearea
- code NOT NULL + UNIQUE
- sewerage_type toevoegen
*/