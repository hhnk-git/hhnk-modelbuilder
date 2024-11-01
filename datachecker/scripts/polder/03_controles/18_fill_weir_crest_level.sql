--Voor stuwen: bepaal het hoogste peil in een straal van 2 meter rondom de stuw.
DROP TABLE IF EXISTS tmp.weir_level_radius
;

CREATE TABLE tmp.weir_level_radius AS
    (
        WITH radius_search AS
            (
                SELECT
                    a.code as weir_code
                  ,
                     --a.geom as weir_geom,
                     --b.code as fdla_code,
                     streefpeil_bwn2 as streefpeil
                FROM
                    checks.weirs                  a
                  , checks.fixeddrainagelevelarea b
                WHERE
                    ST_DWithin(a.geom,b.geom,2)
            )
        SELECT
            weir_code
          ,
             --ST_Union(weir_geom) as geom,
             max(streefpeil) as max_streefpeil
        FROM
            radius_search
        GROUP BY
            weir_code
        HAVING
            COUNT(*) > 1 --Mits er meerdere streefpeilen gevonden zijn
    )
;

ALTER TABLE checks.weirs DROP COLUMN IF EXISTS aanname
;

ALTER TABLE checks.weirs ADD COLUMN aanname varchar(200)
;

-- gedataminede stuwhoogte invullen
ALTER TABLE checks.weirs DROP COLUMN IF EXISTS crest_height_datamining
;

ALTER TABLE checks.weirs ADD COLUMN crest_height_datamining float
;

UPDATE
    checks.weirs a
SET crest_height_datamining = round(b.kruinhoogte_hdb::numeric,2)
FROM
    hdb.stuwen b
WHERE
    a.code LIKE b.code
;

--Update crest level obv hoogste peil in straal van 2 meter (mits er meerdere streefpeilen gevonden zijn)
UPDATE
    checks.weirs AS a
SET crest_level = b.max_streefpeil
  , aanname     = 'max peil in radius'
FROM
    tmp.weir_level_radius AS b
WHERE
    a.code LIKE b.weir_code
    AND
    (
        crest_level   IS NULL
        OR b.max_streefpeil > crest_level
    )
    AND type_function != 1
;

--Update crest level van inlaatstuwen
UPDATE
    checks.weirs AS a
SET crest_level = b.max_streefpeil + 0.5
  , aanname     = 'max peil+0.5 in radius'
FROM
    tmp.weir_level_radius AS b
WHERE
    a.code             LIKE b.weir_code
    AND crest_level IS NULL
    AND type_function     = 1
;

-- datamining hoogte invullen
UPDATE
    checks.weirs a
SET crest_level = crest_height_datamining
  , aanname     = 'datamining crest_height' -- niet concat want het is OF 'max peil in radius' OF 'datamining ..'
WHERE
    crest_level                     IS NULL
    AND crest_height_datamining IS NOT NULL
;

-- als er maar een streefpeil bestaat, dit invullen (ivm stuwen in hdb)
UPDATE
    checks.weirs as a
SET crest_level = b.streefpeil_bwn2
FROM
    checks.fixeddrainagelevelarea as b
WHERE
    a.crest_level IS NULL
    AND ST_DWithin(a.geom,b.geom,2)
;

-- opruimen
DROP TABLE IF EXISTS tmp.peilgebiedgrenzen
;

DROP TABLE IF EXISTS tmp.channel_kunstwerk
;

DROP TABLE IF EXISTS tmp.channel_kunstwerk_peil
;

DROP TABLE IF EXISTS tmp.weir_level_radius
;