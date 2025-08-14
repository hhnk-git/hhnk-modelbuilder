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
  , ST_Multi(ST_CollectionExtract(ST_MakeValid(st_force3d(st_transform(wkb_geometry,4326))),3))::geometry(MultiPolygonZ)
FROM
    tmp.afvoergebiedaanvoergebied
;


insert into nxt.channelsurface
    (id
      , created
      , code
      , geometry
    )
select
    id
  , now()
  , code
  , ST_Multi(ST_Force3d(ST_CollectionExtract(ST_MakeValid(st_transform(wkb_geometry,4326)),3)))::geometry(MultiPolygonZ) -- want nxt.geometry is 3D (met z-coordinaat)
from
    tmp.waterdeel
;

-- pumpstation
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
    id
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
    st_force3d(st_transform((ST_Dump(wkb_geometry)).geom ,4326))::geometry(PointZ) -- van Point naar PointZ ??
from
    damo_ruw.gemaal
;

-- hydra_core_pump
-- direction double precision toevoegen


-- weir
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
    id
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
    END, -- code
    500, -- type
    9999, -- type_function =9999 want niet aan-, af- of terugloopvoorziening
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

*/
drop sequence if exists serial;
create sequence serial start 1;
drop table if exists tmp.duikersifonhevel_sp
;

create table tmp.duikersifonhevel_sp as
select
    nextval('serial') as serial
  , id
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
    id
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
    id
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
  , NULL as shape --vorm
  ,  '9999' as num_timeseries
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
    id
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
    id
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
            id
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