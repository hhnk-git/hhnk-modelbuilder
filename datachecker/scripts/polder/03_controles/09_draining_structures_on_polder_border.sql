-- Welke afvoerende kunstwerken liggen op de poldergrenzen?
-- zet de polders om in lijnen als poldergrenzen
DROP TABLE IF EXISTS tmp.poldergrenzen
;

CREATE TABLE tmp.poldergrenzen AS
SELECT
    polder_id::numeric
  , ST_ExteriorRing((ST_Dump(geom)).geom) as geom
FROM
    checks.polder
;

CREATE INDEX tmp_poldergrenzen_geom
ON
    tmp.poldergrenzen
USING gist
    (
        geom
    )
;

-- selecteer kanaalsegmenten die de poldergrenzen kruisen
DROP TABLE IF EXISTS tmp.channel_poldergrens
;

CREATE TABLE tmp.channel_poldergrens AS
SELECT DISTINCT
ON
    (
        a.geom
    )
    a.*
  , ST_Startpoint(a.geom) as startpunt
  , ST_Endpoint(a.geom)   as eindpunt
FROM
    checks.channel_linemerge as a
  , tmp.poldergrenzen        as b
WHERE
    ST_Intersects(a.bufgeom,b.geom)
; --1373
CREATE INDEX tmp_channel_poldergrens_geom
ON
    tmp.channel_poldergrens
USING gist
    (
        geom
    )
;

CREATE INDEX tmp_channel_poldergrens_start
ON
    tmp.channel_poldergrens
USING gist
    (
        startpunt
    )
;

CREATE INDEX tmp_channel_poldergrens_eind
ON
    tmp.channel_poldergrens
USING gist
    (
        eindpunt
    )
;

-- bepaal het peil op het begin en eindpunt
DROP TABLE IF EXISTS tmp.channel_poldergrens_peil
;

CREATE TABLE tmp.channel_poldergrens_peil AS
SELECT DISTINCT
ON
    (
        a.geom
    )
    a.*
  , b.streefpeil_bwn2 as startpeil
  , c.streefpeil_bwn2 as eindpeil
  , NULL::varchar(50) as polderkant
FROM
    tmp.channel_poldergrens as a
    LEFT JOIN
        checks.fixeddrainagelevelarea as b
        ON
            ST_Intersects(a.startpunt,b.geom)
    LEFT JOIN
        checks.fixeddrainagelevelarea as c
        ON
            st_Intersects(a.eindpunt,c.geom)
; --1373
CREATE INDEX tmp_channel_poldergrens_peil_start
ON
    tmp.channel_poldergrens_peil
USING gist
    (
        startpunt
    )
;

CREATE INDEX tmp_channel_poldergrens_peil_eind
ON
    tmp.channel_poldergrens_peil
USING gist
    (
        eindpunt
    )
;

CREATE INDEX tmp_channel_poldergrens_bufgeom
ON
    tmp.channel_poldergrens
USING gist
    (
        bufgeom
    )
;

-- bepaal of het startpunt in een polder ligt
UPDATE
    tmp.channel_poldergrens_peil
SET polderkant = 'startpunt'
WHERE
    geom IN
    (
        SELECT DISTINCT
        ON
            (
                a.geom
            )
            a.geom
        FROM
            tmp.channel_poldergrens_peil as a
          , checks.polder                as b
        WHERE
            ST_Intersects(a.startpunt,b.geom)
    )
;--886
UPDATE
    tmp.channel_poldergrens_peil
SET polderkant = 'eindpunt'
WHERE
    geom IN
    (
        SELECT DISTINCT
        ON
            (
                a.geom
            )
            a.geom
        FROM
            tmp.channel_poldergrens_peil as a
          , checks.polder                as b
        WHERE
            ST_Intersects(a.eindpunt,b.geom)
    )
;--799
UPDATE
    tmp.channel_poldergrens_peil
SET polderkant = 'beide'
WHERE
    geom IN
    (
        SELECT DISTINCT
        ON
            (
                a.geom
            )
            a.geom
        FROM
            tmp.channel_poldergrens_peil as a
          , checks.polder                as b
        WHERE
            ST_Intersects(a.eindpunt,b.geom)
            AND ST_Intersects(a.startpunt,b.geom)
    )
;--128
UPDATE
    tmp.channel_poldergrens_peil
SET polderkant = 'geen'
WHERE
    polderkant IS NULL
; --21
--CHECK: alle watergangen die beide of geen hebben worden niet meegenomen? Soms zijn het sifons
-- selecteer de gemalen en stuwen die op de grenzen liggen (mbv kanalen overgebleven)
DROP TABLE IF EXISTS tmp.kunstwerk_poldergrens
;

CREATE TABLE tmp.kunstwerk_poldergrens AS
SELECT DISTINCT
ON
    (
        a.code
    )
    a.code
  , a.geom
  , 'gemaal op poldergrens'::varchar(200) as omschrijving
  , b.startpeil
  , b.eindpeil
  , b.polderkant
  , b.geom as linegeom
FROM
    checks.pumpstation           as a
  , tmp.channel_poldergrens_peil as b
WHERE
    ST_Intersects(b.bufgeom,a.geom)
UNION ALL
SELECT DISTINCT
ON
    (
        a.code
    )
    a.code
  , a.geom
  , 'stuw op poldergrens'::varchar(200) as omschrijving
  , b.startpeil
  , b.eindpeil
  , b.polderkant
  , b.geom as linegeom
FROM
    checks.weirs                 as a
  , tmp.channel_poldergrens_peil as b
WHERE
    ST_Intersects(b.bufgeom,a.geom)
UNION ALL
SELECT DISTINCT
ON
    (
        a.code
    )
    a.code
  , a.geom
  , 'duiker/sifon op poldergrens'::varchar(200) as omschrijving
  , b.startpeil
  , b.eindpeil
  , b.polderkant
  , b.geom as linegeom
FROM
    checks.culvert               as a
  , tmp.channel_poldergrens_peil as b
WHERE
    ST_Intersects(b.bufgeom,a.geom)
    AND a.opmerking LIKE '%afsluitbare afvoer op peilgrens%'
;

-- alleen afvoerkunstwerken die binnen 20m van peilgrens liggen gebruiken Het zijn anders vaak kunstwerken op een peilvak met maar 1 watergang naar de rand
DROP TABLE IF EXISTS tmp.polder_inside
;

CREATE TABLE tmp.polder_inside AS
SELECT
    ST_Buffer(geom,-20) as geom
  , polder_id
  , polder_type
  , name
FROM
    checks.polder
;

--TODO uitzondering maken voor duikers?
DELETE
FROM
    tmp.kunstwerk_poldergrens
WHERE
    code IN
    (
        SELECT
            a.code
        FROM
            tmp.kunstwerk_poldergrens as a
          , tmp.polder_inside         as b
        WHERE
            ST_Intersects(a.geom,b.geom)
    )
;

-- selecteer de afvoerkunstwerken
UPDATE
    checks.pumpstation
SET opmerking = concat_ws(',',opmerking,'afvoergemaal op poldergrens')
WHERE
    code IN
    (
        SELECT
            code
        FROM
            tmp.kunstwerk_poldergrens
        WHERE
            (
                polderkant       = 'startpunt'
                AND omschrijving = 'gemaal op poldergrens'
                AND startpeil    < eindpeil
            )
            OR
            (
                polderkant         = 'startpunt'
                AND omschrijving   = 'gemaal op poldergrens'
                AND eindpeil IS NULL
            )
            OR
            (
                polderkant       = 'eindpunt'
                AND omschrijving = 'gemaal op poldergrens'
                AND startpeil    > eindpeil
            )
            OR
            (
                polderkant          = 'eindpunt'
                AND omschrijving    = 'gemaal op poldergrens'
                AND startpeil IS NULL
            )
            OR
            (
                omschrijving = 'gemaal op poldergrens'
                AND code IN
                (
                    SELECT
                        code
                    FROM
                        checks.pumpstation
                    WHERE
                        type IN ('2'
                               ,'5')
                )
            )
    )
;

UPDATE
    checks.weirs
SET opmerking = concat_ws(',',opmerking,'afvoerstuw op poldergrens')
WHERE
    code IN
    (
        SELECT
            code
        FROM
            tmp.kunstwerk_poldergrens
        WHERE
            (
                polderkant       = 'startpunt'
                AND omschrijving = 'stuw op poldergrens'
                AND startpeil    > eindpeil
            )
            OR
            (
                polderkant       = 'eindpunt'
                AND omschrijving = 'stuw op poldergrens'
                AND startpeil    < eindpeil
            )
    )
;

-- Bepaal het aantal afvoerkunstwerken per polder
-- TODO: voeg bovenstaande en onderstaande query samen dat aanpassingen maar 1x hoeven te gebeuren
DROP TABLE IF EXISTS checks.afvoerkunstwerken
;

CREATE TABLE checks.afvoerkunstwerken AS
    (
        SELECT *
        FROM
            tmp.kunstwerk_poldergrens
        WHERE
            (
                polderkant       = 'startpunt'
                AND omschrijving = 'gemaal op poldergrens'
                AND startpeil    < eindpeil
            )
            OR
            (
                polderkant         = 'startpunt'
                AND omschrijving   = 'gemaal op poldergrens'
                AND eindpeil IS NULL
            )
            OR
            (
                polderkant       = 'eindpunt'
                AND omschrijving = 'gemaal op poldergrens'
                AND startpeil    > eindpeil
            )
            OR
            (
                polderkant          = 'eindpunt'
                AND omschrijving    = 'gemaal op poldergrens'
                AND startpeil IS NULL
            )
            OR
            (
                omschrijving = 'gemaal op poldergrens'
                AND code IN
                (
                    SELECT
                        code
                    FROM
                        checks.pumpstation
                    WHERE
                        type IN ('2'
                               ,'5')
                )
            )
            OR
            (
                polderkant       = 'eindpunt'
                AND omschrijving = 'stuw op poldergrens'
                AND startpeil    < eindpeil
            )
            OR omschrijving = 'duiker/sifon op poldergrens'
    )
;

-- opruimen
DROP TABLE IF EXISTS tmp.poldergrenzen
;

DROP TABLE IF EXISTS tmp.channel_poldergrens
;

DROP TABLE IF EXISTS tmp.channel_poldergrens_peil
;