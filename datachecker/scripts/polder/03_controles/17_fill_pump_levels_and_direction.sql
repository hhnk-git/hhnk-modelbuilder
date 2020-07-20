-- zet de peilgebieden om in lijnen als peilgebiedgrenzen
DROP TABLE IF EXISTS tmp.peilgebiedgrenzen
;

CREATE TABLE tmp.peilgebiedgrenzen AS
SELECT
    code
  , ST_ExteriorRing((ST_Dump(geom)).geom) as geom
FROM
    checks.fixeddrainagelevelarea
;

CREATE INDEX tmp_peilgebiedgrenzen_geom
ON
    tmp.peilgebiedgrenzen
USING gist
    (
        geom
    )
;

-- selecteer kanaalsegmenten die bij kunstwerken horen
DROP TABLE IF EXISTS tmp.channel_kunstwerk
;

CREATE TABLE tmp.channel_kunstwerk AS
SELECT DISTINCT
ON
    (
        a.id
    )
    a.*
  , ST_Startpoint(a.geom) as startpunt
  , ST_Endpoint(a.geom)   as eindpunt
FROM
    checks.channel_linemerge as a
WHERE
    a.id IN
    (
        SELECT
            channel_code::integer
        FROM
            checks.pumpstation
    )
;

CREATE INDEX tmp_channel_kunstwerk_geom
ON
    tmp.channel_kunstwerk
USING gist
    (
        geom
    )
;

CREATE INDEX tmp_channel_kunstwerk_start
ON
    tmp.channel_kunstwerk
USING gist
    (
        startpunt
    )
;

CREATE INDEX tmp_channel_kunstwerk_eind
ON
    tmp.channel_kunstwerk
USING gist
    (
        eindpunt
    )
;

-- bepaal het peil op het begin en eindpunt
DROP TABLE IF EXISTS tmp.channel_kunstwerk_peil
;

CREATE TABLE tmp.channel_kunstwerk_peil AS
SELECT DISTINCT
ON
    (
        a.id
    )
    a.*
  , b.streefpeil_bwn2 as startpeil
  , b.id              as startid
  , c.streefpeil_bwn2 as eindpeil
  , c.id              as eindid
  , CASE
        WHEN b.streefpeil_bwn2 = c.streefpeil_bwn2
            THEN 'crest/startlevel onbetrouwbaar'
        WHEN b.streefpeil_bwn2   IS NULL
            OR c.streefpeil_bwn2 IS NULL
            THEN 'crest/startlevel onbetrouwbaar'
    END as opmerking
  , CASE
        WHEN b.streefpeil_bwn2 < c.streefpeil_bwn2
            THEN 'start'
        WHEN b.streefpeil_bwn2 > c.streefpeil_bwn2
            THEN 'eind'
    END as lage_peil
FROM
    tmp.channel_kunstwerk as a
    LEFT JOIN
        checks.fixeddrainagelevelarea as b
        ON
            ST_Intersects(a.startpunt,b.geom)
    LEFT JOIN
        checks.fixeddrainagelevelarea as c
        ON
            st_Intersects(a.eindpunt,c.geom)
;

-- Vul het peil in
UPDATE
    checks.pumpstation as a
SET start_level =
    CASE
        WHEN b.lage_peil = 'start'
            THEN b.startpeil+0.02
        WHEN b.lage_peil = 'eind'
            THEN b.eindpeil                   +0.02
            ELSE least(b.startpeil,b.eindpeil)+0.02
    END
  , start_point_id = b.startid
  , end_point_id   = b.eindid
  , opmerking      = concat_ws(',',a.opmerking,b.opmerking)
FROM
    tmp.channel_kunstwerk_peil as b
WHERE
    a.channel_code::integer = b.id
;

-- gebruik allowed flow direction voor richting
UPDATE
    checks.pumpstation as a
SET allowed_flow_direction =
    CASE
        WHEN b.lage_peil = 'start'
            THEN degrees(ST_Azimuth(a.geom,ST_LineInterpolatePoint(b.geom,least(ST_LineLocatePoint(b.geom,a.geom)+0.1,1))))
        WHEN b.lage_peil = 'eind'
            THEN degrees(ST_Azimuth(a.geom,ST_LineInterpolatePoint(b.geom,greatest(ST_LineLocatePoint(b.geom,a.geom)-0.1,0))))
    END
FROM
    tmp.channel_kunstwerk_peil as b
WHERE
    a.channel_code::integer = b.id
;

-- gemalen waar bovenstaande niet lukt:
UPDATE
    checks.pumpstation as a
SET start_level            = b.streefpeil_bwn2 +0.02
  , stop_level             = b.streefpeil_bwn2 - 0.03
  , allowed_flow_direction = 1
  , opmerking              = concat_ws(',',a.opmerking,'start_level en richting onbetrouwbaar')
FROM
    checks.fixeddrainagelevelarea as b
WHERE
    a.start_level IS NULL
    AND ST_DWithin(a.geom,b.geom,2)
;