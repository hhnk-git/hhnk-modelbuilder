-- copy channels to checks schema
DROP TABLE IF EXISTS checks.channel
;

CREATE TABLE checks.channel AS
SELECT
    id
  , organisation_id
  , created
  , code
  , type
  , bed_level
  , comment
  , name
  , talud_left
  , talud_right
  , image_url
  , ST_force2D(ST_Transform(geometry,28992))               as geom
  , ST_lineInterpolatePoint(ST_force2D(ST_Transform(geometry,28992)),0.5)                 as pointgeom
  , ST_Buffer(ST_Buffer(ST_force2D(ST_Transform(geometry,28992)),0.1,'endcap=flat'),0.01) as bufgeom
  , "end"
  , start
  , channel_type_id
  , bed_width
  , tabulated_width
  , tabulated_height
  , derived_bed_level
FROM
    nxt.channel
;

CREATE INDEX checks_channel_geom
ON
    checks.channel
USING gist
    (
        geom
    )
;

CREATE INDEX checks_channel_bufgeom
ON
    checks.channel
USING gist
    (
        bufgeom
    )
;

CREATE INDEX checks_channel_pointgeom
ON
    checks.channel
USING gist
    (
        pointgeom
    )
;

-- welke kanalen zijn een sifon?
UPDATE
    checks.channel as a
SET comment = 'sifon'
FROM
    checks.culvert as b
WHERE
    b.type_art = 2
    AND ST_Contains(a.bufgeom,b.geom)
;

-- 0.1) hoeveel sifons intersecten wel maar containen niet?
DROP TABLE IF EXISTS tmp.channel_sifon_snap
;

CREATE TABLE tmp.channel_sifon_snap as
    (
        SELECT distinct
        on
            (
                a.id
            )
            a.*
          , b.id as culvert_id
        FROM
            checks.channel    a
          , checks.culvert as b
        WHERE
            a.comment IS NULL
            AND b.type_art  = 2
            AND ST_Intersects(a.bufgeom,b.geom)
    )
; -- 934 sifons die niet containen... en die we dus moeten snappen ALS(!!) dat kan
CREATE INDEX tmp_channel_sinfon_geom
ON
    tmp.channel_sifon_snap
USING gist
    (
        geom
    )
;

CREATE INDEX tmp_channel_sifon_bufgeom
ON
    tmp.channel_sifon_snap
USING gist
    (
        bufgeom
    )
;

CREATE INDEX tmp_channel_sifon_pointgeom
ON
    tmp.channel_sifon_snap
USING gist
    (
        pointgeom
    )
;

ALTER TABLE tmp.channel_sifon_snap DROP COLUMN IF EXISTS sifon_share
;

AlTER TABLE tmp.channel_sifon_snap ADD COLUMN sifon_share float
;

-- 1) Eerst aandeel bepalen hoeveel sifon en channel.bufgeom overlappen
-- 1.1) ff buffer van sifonnen maken (1cm buffer) (er is namelijk polygon nodig voor opp bepaling; kan niet met linestring)
-- 1cm is arbitrair, maakt voor aandeel bepaling niet uit zolang bufgeom van sifon maar binnen bufgeom van channel valt.
-- Maw: de bufferafstand van tmp.culvert mag maximaal 0.1+0.1m zijn.
DROP TABLE IF EXISTS tmp.sifon
;

CREATE TABLE tmp.sifon AS
SELECT *
FROM
    checks.culvert
WHERE
    type_art=2
;

-- 1.2) sifon bufferen
ALTER TABLE tmp.sifon ADD COLUMN bufgeom geometry(Polygon,28992)
;

UPDATE
    tmp.sifon
SET bufgeom = st_buffer(geom,0.1)
;

-- 1.3) overlapping (percentage) bepalen
UPDATE
    tmp.channel_sifon_snap a
SET sifon_share = round( (ST_area(ST_intersection(a.bufgeom, b.bufgeom))/(ST_area(b.bufgeom))*100)::numeric,2)
FROM
    tmp.sifon b
WHERE
    ST_Intersects(a.bufgeom,b.geom)
;

-- SELECT * FROM tmp.channel_sifon_snap WHERE sifon_share >51 ORDER BY sifon_share DESC;
-- 70 vd 934 sifons (die niet containen) liggen voor meer dan 51% van hun lengte (lees: gebufferde opp) in een channel.bugeom
-- 2) Wat als er meerdere sifons in 1 channel.bufgeom liggen??
-- 2.1) We gaan het aantal sifons tellen dat een channel.bufgeom intersect
AlTER TABLE tmp.channel_sifon_snap ADD COLUMN number_of_sifons integer
;

WITH list as
    (
        SELECT
            count(b.*)
          , a.id as channel_id
        FROM
            tmp.channel_sifon_snap a
          , tmp.sifon              b
        WHERE
            ST_Intersects(a.bufgeom, b.geom)
        GROUP BY
            a.id
    )
UPDATE
    tmp.channel_sifon_snap c
SET number_of_sifons = d.count
from
    list d
where
    c.id = d.channel_id
;

-- SELECT * from tmp.channel_sifon_snap where number_of_sifons >1;
-- er zijn 14 checks.channel die meer dan 1 sifon intersecten: lastig om op te lossen!
-- Er zijn 53 sifons die voor meer dan 51% (van hun lengte (of opp.) in een checks.channel liggen (relatief eenvoudig op te lossen voor hhnk)
UPDATE
    checks.culvert a
SET opmerking = concat_ws(',',opmerking,'>51% in 1 hydroobject')
where
    a.id in
    (
        select
            culvert_id
        from
            tmp.channel_sifon_snap
        where
            sifon_share         > 51
            and number_of_sifons<2
    )
;

-- tabellen weggooien
DROP TABLE IF EXISTS tmp.sifon
;

DROP TABLE IF EXISTS tmp.sifon_do_not_snap
;

DROP TABLE IF EXISTS tmp.channel_sifon_snap
;

-- maak een envoudige variant van channel voor netwerkanalyse
-- 1) wat gebeurt er?
-- 1.1) st_union maakt van ALLE kanalen grote MultiLinestring
-- 1.2) st_linemerge icm st_union maakt van die grote MultiLinestring meerdere Linestrings (dus meerdere features: features lopen niet van kruispunt tot kruispunt). De originele checks.channel indeling komt hier naar voren
-- 1.3) st_dump icm st_linemerge en st_union dumpt de Linestrings: maw: er wordt een single part geometrie gemaakt. Ook hier weer geldt dat features niet lopen van kruispunt tot kruispunt). De originele checks.channel indeling komt hier naar voren
DROP TABLE IF EXISTS checks.channel_linemerge
;

CREATE TABLE checks.channel_linemerge AS
SELECT
    ( ST_dump(ST_Linemerge(ST_UNION(geom)))).geom                                             as geom
  , ST_Buffer(ST_Buffer((ST_dump(ST_Linemerge(ST_UNION(geom)))).geom,0.1,'endcap=flat'),0.01) as bufgeom
FROM
    checks.channel
WHERE
    comment IS NULL
; --5.5 minuten
INSERT INTO checks.channel_linemerge
SELECT
    NULL
  ,                                                              -- lijngeometrie niet meegenomen zodat stuwen op uiteinde van sifon niet als 2 watergangen gemarkeerd worden
    ST_Buffer(ST_Buffer(geom,0.1,'endcap=flat'),0.01) as bufgeom -- buffer geometrie wel meegenomen zodat loose channel een verbinding krijgt bij sifon
FROM
    checks.channel
WHERE
    comment = 'sifon'
;

CREATE INDEX checks_channel_linemerge_geom
ON
    checks.channel_linemerge
USING gist
    (
        geom
    )
;

CREATE INDEX checks_channel_linemerge_bufgeom
ON
    checks.channel_linemerge
USING gist
    (
        bufgeom
    )
;

-- voeg id toe
ALTER TABLE checks.channel_linemerge ADD COLUMN id integer
;

DROP SEQUENCE IF EXISTS serial;
CREATE SEQUENCE serial;
UPDATE
    checks.channel_linemerge
SET id = nextval('serial')
;

ALTER TABLE checks.channel_linemerge ADD PRIMARY KEY (id)
;

-- voeg typering toe
ALTER TABLE checks.channel_linemerge ADD COLUMN channel_type_id integer
;

UPDATE
    checks.channel_linemerge a
SET channel_type_id = b.channel_type_id
FROM
    checks.channel as b
WHERE
    ST_Contains(a.bufgeom,b.pointgeom)
;