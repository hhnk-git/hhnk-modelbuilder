-- 1) channel_loose: Welke watergangen zijn niet verbonden met afvoerkunstwerken omdat ze los liggen (lees: niet verbonden (ook niet middels kunstwerken) met omliggende watersysteem)??
-- 1.1) We groeperen de lossen kanalen per poldercluster. Groeperen betekent alle watergangen verbinden die aan elkaar liggen (buffer 10 cm flat+ 1cm) per polder
-- channel_loose = hier ALLE(!!) channel_linemerge.bufgeom (die intersecten met poldercluster polygon)
-- channel_linemerge.bufgeom = zijn alle checks.channels (hydroobjecten die ook onder kunstwerken zijn doorgetekend!!) gebufferd met 0.1 en 0.01
-- checks.channel is nxt.channel met kolom 'comment' waar is ingevuld 'sifon' daar waar de channel.bufgeom (0.1 en 0.01) st_contains een checks.culvert
DROP SEQUENCE IF EXISTS serial;
CREATE SEQUENCE serial START 1;
DROP TABLE IF EXISTS checks.channel_loose
;

CREATE TABLE checks.channel_loose AS
SELECT
    nextval('serial') as id
  , (ST_dump(ST_Union(bufgeom))).geom
  , b.polder_id::numeric
FROM
    checks.channel_linemerge as a
  , checks.polder            as b
WHERE
    ST_Intersects(a.bufgeom,b.geom)
GROUP BY
    b.polder_id
;

CREATE INDEX checks_channel_loose_geom
ON
    checks.channel_loose
USING gist
    (
        geom
    )
;
-- 1.2) We bepalen de lengte van losliggende kanalen door eerst te de linemerge lijnen die volledig binnen channel_loose liggen te joinen in een tabel en vervolgens de lengte hiervan op te tellen.
DROP TABLE IF EXISTS tmp.channel_loose_length
;

CREATE TABLE tmp.channel_loose_length AS
    (
        WITH join_linemerge_loose AS
            (
                SELECT
                    a.id
                  , a.polder_id
                  , b.geom as linegeom
                FROM
                    checks.channel_loose a
                    LEFT JOIN
                        checks.channel_linemerge b
                        ON
                            ST_Contains(a.geom,b.geom)
            )
        SELECT
            id
          , SUM(ST_Length(linegeom)) as lengte
          , ST_Union(linegeom)
        FROM
            join_linemerge_loose
        GROUP BY
            id
    )
;

ALTER TABLE checks.channel_loose ADD COLUMN lengte numeric
;

ALTER TABLE checks.channel_loose ADD COLUMN pointgeom geometry(point,28992)
;

UPDATE
    checks.channel_loose a
SET lengte = ST_Area(geom)/0.2
;
UPDATE
    checks.channel_loose
SET pointgeom = ST_PointOnSurface(geom)
;

CREATE INDEX checks_channel_loose_pointgeom
ON
    checks.channel_loose
USING gist
    (
        pointgeom
    )
;

-- 1.3) We verwijderen delen die wel verbonden zijn met afvoerkunstwerken
-- channel_loose = channel_linemerge.bufgeom minus de segmenten die intersecten met de korte lijntjes van ong 200m waarop een afvoerkunstwerk ligt
DELETE
FROM
    checks.channel_loose       as a
USING checks.afvoerkunstwerken as b
WHERE
    ST_Intersects(a.geom,b.geom)
;
DROP TABLE IF EXISTS checks.channel_loose_type
;

CREATE TABLE checks.channel_loose_type AS
SELECT
    a.*
FROM
    checks.channel       as a
  , checks.channel_loose    b
WHERE
    ST_contains(b.geom,a.geom)
;

-- channel nowayout op basis van losse channels
--DROP TABLE IF EXISTS tmp.wrong_channels
--;

CREATE TABLE tmp.wrong_channels AS
SELECT
    a.geom
  , a.bufgeom
  , a.id
  , a.type                                    as channel_type_id
  , 'kruising_zonder_kunstwerk'::varchar(250) as opmerking
FROM
    checks.channel                   as a
  , checks.kruising_zonder_kunstwerk as b
WHERE
    ST_Intersects(b.pointgeom,a.bufgeom)
; -- kruisingen zonder kunstwerk
--Watergangen weggooien als
--1) culvert heeft een opmerking 'geen watergang' en ligt op een peilgrens (zowel duikers als syfonnen)
--2) culvert heeft een opmerking, ligt niet op een peilgrens maar is een syfon
--3) culvert heeft GEEN sturingsregeling meegekregen
DROP TABLE IF EXISTS tmp.unusable_culvert_endpoints
;

CREATE TABLE tmp.unusable_culvert_endpoints AS
    (
        SELECT
            ST_LineInterpolatePoint(geom,0.1) as geom
          , opmerking
        FROM
            checks.culvert
        WHERE
            NOT on_channel
            AND
            (
                on_fdla_border
                OR type_art = 2
            )
            AND code NOT IN
            (
                SELECT
                    structure_code
                FROM
                    checks.control_table
            )
        UNION ALL
        SELECT
            ST_LineInterpolatePoint(geom,0.9) as geom
          , opmerking
        FROM
            checks.culvert
        WHERE
            NOT on_channel
            AND
            (
                on_fdla_border
                OR type_art = 2
            )
            AND code NOT IN
            (
                SELECT
                    structure_code
                FROM
                    checks.control_table
            )
    )
;

--Voeg kanalen toe aan tmp.wrong_channels die intersecten met bovenstaande punten
INSERT INTO tmp.wrong_channels
SELECT DISTINCT
ON
    (
        a.id
    )
    a.geom
  , a.bufgeom
  , a.id
  , a.channel_type_id
  , concat('duiker/sifon op watergang wordt weggegooid, reden: ', opmerking) as opmerking
FROM
    checks.channel                 a
  , tmp.unusable_culvert_endpoints b
WHERE
    ST_Intersects(a.bufgeom,b.geom)
;

--Voeg kanalen toe aan tmp.wrong_channels die intersecten met vispassages (weir type = 5)
INSERT INTO tmp.wrong_channels
SELECT DISTINCT
ON
    (
        a.id
    )
    a.geom
  , a.bufgeom
  , a.id
  , a.channel_type_id
  , 'vispassage' as opmerking
FROM
    checks.channel a
  , checks.weirs   b
WHERE
    ST_Intersects(a.bufgeom,b.geom)
    AND b.type LIKE '5'
;

-- voeg kanalen toe in foute peilafwijkingen
INSERT INTO tmp.wrong_channels
SELECT DISTINCT
ON
    (
        a.id
    )
    a.geom
  , a.bufgeom
  , a.id
  , a.channel_type_id
  , 'onderbemaling zonder gemaal' as opmerking
FROM
    checks.channel             a
  , checks.fdla_sp_nowayout as b
WHERE
    b.opmerking_peil LIKE '%onderbemaling zonder gemaal%'
    AND ST_Intersects(a.geom,b.geom)
;

INSERT INTO tmp.wrong_channels
SELECT DISTINCT
ON
    (
        a.id
    )
    a.geom
  , a.bufgeom
  , a.id
  , a.channel_type_id
  , 'opmaling zonder stuw of duiker' as opmerking
FROM
    checks.channel             a
  , checks.fdla_sp_nowayout as b
WHERE
    b.opmerking_peil LIKE '%opmaling zonder stuw of duiker%'
    AND ST_Intersects(a.geom,b.geom)
;

-- voeg kanalen toe in foute peilgebieden
INSERT INTO tmp.wrong_channels
SELECT DISTINCT
ON
    (
        a.id
    )
    a.geom
  , a.bufgeom
  , a.id
  , a.channel_type_id
  , 'laagste peilgebied zonder gemaal' as opmerking
FROM
    checks.channel             a
  , checks.fdla_sp_nowayout as b
WHERE
    b.opmerking_peil LIKE '%laagste peilgebied zonder gemaal%'
    AND ST_Intersects(a.geom,b.geom)
;

INSERT INTO tmp.wrong_channels
SELECT DISTINCT
ON
    (
        a.id
    )
    a.geom
  , a.bufgeom
  , a.id
  , a.channel_type_id
  , 'hoogste peilgebied zonder stuw of duiker' as opmerking
FROM
    checks.channel             a
  , checks.fdla_sp_nowayout as b
WHERE
    b.opmerking_peil LIKE '%hoogste peilgebied zonder stuw of duiker%'
    AND ST_Intersects(a.geom,b.geom)
;

-- 2.2) maak een vlakkenbestand van alle watergangen en halen daaruit de foutieve segmenten
DROP TABLE IF EXISTS tmp.channel_nowayout
;

CREATE TABLE tmp.channel_nowayout AS
SELECT *
FROM
    checks.channel
WHERE
    id NOT IN
    (
        SELECT
            id
        FROM
            tmp.wrong_channels
    )
; --119sec
CREATE INDEX tmpchannel_nowayout_bufgeom
ON
    tmp.channel_nowayout
USING gist
    (
        bufgeom
    )
;

-- 2.3) Netwerkanalyse: we gaan checks.channel_nowayout maken. Dat wil zeggen: welke segmenten liggen los en zijn niet verbonden met een afvoerkunstwerk?
-- We groeperen de channel_nowayout kanalen per poldercluster
DROP SEQUENCE IF EXISTS serial;
CREATE SEQUENCE serial START 1;
DROP TABLE IF EXISTS checks.channel_nowayout
;

CREATE TABLE checks.channel_nowayout AS
SELECT
    nextval('serial') as id
  , (ST_dump(ST_Union(bufgeom))).geom 
  , b.polder_id::numeric
  , 'niet verbonden met afvoerkunstwerk' as opmerking
FROM
    tmp.channel_nowayout as a
  , checks.polder        as b
WHERE
    ST_Intersects(a.bufgeom,b.geom)
GROUP BY
    b.polder_id
; --119sec
CREATE INDEX checks_channel_nowayout_geom
ON
    checks.channel_nowayout
USING gist
    (
        geom
    )
;

-- 2.4) Verwijder delen die wel verbonden zijn met afvoerkunstwerken
DELETE
FROM
    checks.channel_nowayout    as a
USING checks.afvoerkunstwerken as b
WHERE
    ST_Intersects(a.geom,b.geom)
;

-- 2.5) Voeg de foutieve segmenten toe aan channel_nowayout;
INSERT INTO checks.channel_nowayout
    (geom, opmerking
    )
SELECT
    bufgeom
    , opmerking
    
from
    tmp.wrong_channels
;

-- 2.6) (lengte en) pointgeom toevoegen voor stap 3.
DROP TABLE IF EXISTS tmp.channel_nowayout_length
;

CREATE TABLE tmp.channel_nowayout_length AS
    (
        WITH join_linemerge_nowayout AS
            (
                SELECT
                    a.id
                  , a.polder_id
                  , b.geom as linegeom
                FROM
                    checks.channel_nowayout a
                    LEFT JOIN
                        checks.channel_linemerge b
                        ON
                            ST_Contains(a.geom,b.geom)
            )
        SELECT
            id
          , SUM(ST_Length(linegeom)) as lengte
          , ST_Union(linegeom)
        FROM
            join_linemerge_nowayout
        GROUP BY
            id
    )
;

ALTER TABLE checks.channel_nowayout ADD COLUMN lengte numeric
;

ALTER TABLE checks.channel_nowayout ADD COLUMN pointgeom geometry(point,28992)
;

UPDATE
    checks.channel_nowayout a
SET lengte = ST_Area(geom)/0.2
;
UPDATE
    checks.channel_nowayout
SET pointgeom = ST_PointOnSurface(geom)
;

CREATE INDEX checks_channel_nowayout_pointgeom
ON
    checks.channel_nowayout
USING gist
    (
        pointgeom
    )
;

-- 2.7) extra info (oa channel_type_id) voor qgis styling (daarom in een tmp tabel)
DROP TABLE IF EXISTS checks.channel_nowayout_type
;

CREATE TABLE checks.channel_nowayout_type AS
SELECT
    a.*
FROM
    checks.channel          as a
  , checks.channel_nowayout    b
WHERE
    ST_contains(b.geom,a.geom)
;

-- tabellen weggooien
DROP TABLE IF EXISTS tmp.channel_peilgrens_afsluitbare_duikersifon
;

DROP TABLE IF EXISTS tmp.channel_peilgrens_inlaat
;

DROP TABLE IF EXISTS tmp.channel_nietinlaat_peilgrens
;

DROP TABLE IF EXISTS tmp.channel_vastedam
;

DROP TABLE IF EXISTS tmp.channel_nowayout_color_qgis
;

DROP TABLE IF EXISTS tmp.polderclusterborder
;

DROP TABLE IF EXISTS tmp.weirs_at_polderclusterborder
;

DROP TABLE IF EXISTS tmp.weirs_at_boezemwatervlak2006_sp
;

DROP TABLE IF EXISTS tmp.weirs_at_boezemwatervlak2006
;

DROP TABLE IF EXISTS tmp.channel_loose_length
;

DROP TABLE IF EXISTS tmp.channel_nowayout_length
;

DROP TABLE IF EXISTS tmp.unusable_culvert_endpoints
;

-- schaduwtabel maken
DROP TABLE IF EXISTS tmp.checks_channel
;

CREATE TABLE tmp.checks_channel AS
SELECT
    id
  , geom                as geom
  , ST_StartPoint(geom) as startpunt
  , ST_EndPoint(geom)   as eindpunt
FROM
    checks.channel
;

-- index aanmaken
DROP INDEX IF EXISTS tmp.checks_channel_geom_index;
CREATE INDEX checks_channel_geom_index
ON
    tmp.checks_channel
USING gist
    (
        geom
    )
;

DROP INDEX IF EXISTS tmp.checks_channel_end_index;
CREATE INDEX checks_channel_end_index
ON
    tmp.checks_channel
USING gist
    (
        startpunt
    )
;

DROP INDEX IF EXISTS tmp.checks_channel_start_index;
CREATE INDEX checks_channel_start_index
ON
    tmp.checks_channel
USING gist
    (
        eindpunt
    )
;

--Vul tabel met start- en eindpunten
DROP TABLE IF EXISTS tmp.channel_endpoints
;

CREATE TABLE tmp.channel_endpoints AS
    (
        SELECT
            id        as channel_id
          , startpunt as geom
        FROM
            tmp.checks_channel
        UNION ALL
        SELECT
            id       as channel_id
          , eindpunt as geom
        FROM
            tmp.checks_channel
    )
;

--Vul tabel met vertices (geen begin/eindpunt)
DROP TABLE IF EXISTS tmp.vertex_midpoints
;

CREATE TABLE tmp.vertex_midpoints AS
    (
        WITH vertex_dump AS
            (
                SELECT
                    id                  as channel_id
                  , ST_NPoints(geom)    as numpoints
                  , ST_DumpPoints(geom) as vertex
                FROM
                    tmp.checks_channel
            )
        SELECT
            channel_id
          , (vertex).geom as geom
        FROM
            vertex_dump
        WHERE
            (
                vertex
            )
            .path[1] > 1
            AND
            (
                vertex
            )
            .path[1] < numpoints
    )
;

--Deelt een eindpunt zijn locatie met geen enkel ander eindpunt dan betreft het een doodlopend kanaal
DROP SEQUENCE IF EXISTS seq_dead_end;
CREATE SEQUENCE seq_dead_end START 1;
DROP TABLE IF EXISTS tmp.dead_ends
;

CREATE TABLE tmp.dead_ends AS
    (
        SELECT
            nextval('seq_dead_end') as id
          , NULL::integer           as channel_id
          , geom
        FROM
            tmp.channel_endpoints
        GROUP BY
            geom
        HAVING
            COUNT(*)=1
    )
;

-- index aanmaken
DROP INDEX IF EXISTS tmp.tmp_dead_ends_geom;
CREATE INDEX tmp_dead_ends_geom
ON
    tmp.dead_ends
USING gist
    (
        geom
    )
;

--Verwijder doodlopende punten die wel op een midpoint (vertex) liggen
DELETE
FROM
    tmp.dead_ends a
USING tmp.vertex_midpoints b
WHERE
    ST_Intersects(a.geom,b.geom)
;

-- dead_end koppelen aan een checks.channel
UPDATE
    tmp.dead_ends a
SET channel_id = b.id
FROM
    tmp.checks_channel b
WHERE
    ST_Intersects(a.geom,b.geom)
;

--Bepaal welke doodlopende punten dicht bij een andere channel's vertex ligt
DROP TABLE IF EXISTS tmp.wrong_dead_ends
;

CREATE TABLE tmp.wrong_dead_ends AS
    (
        SELECT
            a.id
          , a.geom
          , a.channel_id
        FROM
            tmp.dead_ends         a
          , tmp.channel_endpoints b
        WHERE
            ST_DWithin(a.geom, b.geom, 1)
            AND a.channel_id <> b.channel_id
    )
;

-- een doodlopend checks.channel met lengte <1m kan in tmp.wrong_dead_ends komen. Deze moet eruit..
DELETE
FROM
    tmp.wrong_dead_ends a
USING tmp.checks_channel b
WHERE
    a.channel_id          = b.id
    AND ST_Length(b.geom) < 1
;

-- opmerking toevoegen
ALTER TABLE checks.channel DROP COLUMN IF EXISTS opmerking
;

ALTER TABLE checks.channel ADD COLUMN opmerking varchar(100)
;

UPDATE
    checks.channel
SET opmerking = concat_ws(',',opmerking,'<1m gap?')
WHERE
    id IN
    (
        SELECT
            channel_id
        FROM
            tmp.wrong_dead_ends
    )
;

-- tabellen weggooien
DROP TABLE IF EXISTS tmp.dead_ends
;

DROP TABLE IF EXISTS tmp.wrong_dead_ends
;

DROP TABLE IF EXISTS tmp.vertex_midpoints
;

DROP TABLE IF EXISTS tmp.wrong_dead_ends
;

DROP TABLE IF EXISTS tmp.checks_channel
;

-- index opruimen
DROP INDEX IF EXISTS tmp.checks_channel_geom_index;
DROP INDEX IF EXISTS tmp.checks_channel_end_index;
DROP INDEX IF EXISTS tmp.checks_channel_start_index;
DROP TABLE IF EXISTS tmp.culvert_on_channel_nowayout
;

CREATE TABLE tmp.culvert_on_channel_nowayout AS
    (
        SELECT
            a.*
        FROM
            checks.culvert          a
          , checks.channel_nowayout b
        WHERE
            ST_Contains(b.geom, a.geom)
    )
;

DROP TABLE IF EXISTS tmp.culvert_on_channel_loose
;

CREATE TABLE tmp.culvert_on_channel_loose AS
    (
        SELECT
            a.*
        FROM
            checks.culvert       a
          , checks.channel_loose b
        WHERE
            ST_Contains(b.geom, a.geom)
    )
;

UPDATE
    checks.culvert as a
SET opmerking = concat_ws(',',a.opmerking,'culvert on channel_nowayout')
WHERE
    id IN
    (
        SELECT
            id
        FROM
            tmp.culvert_on_channel_nowayout
    )
;

UPDATE
    checks.culvert as a
SET opmerking = concat_ws(',',a.opmerking,'culvert on channel_loose')
WHERE
    id IN
    (
        SELECT
            id
        FROM
            tmp.culvert_on_channel_loose
    )
;