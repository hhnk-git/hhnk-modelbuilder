/*
Assumptions weirs
1. The crest level of a weir is set to a the waterlevel if the crest level falls below the waterlevel.
2. The crest level of a weir is set to the bed level + 0.5 mNAP of channel when the crest level falls below the bed level of that channel.
3. If a crest level is smaller than -10 mNAP it is set to -10 mNAP, if it is larger than 10 mNAP it is set to 10 mNAP.
4. If a crest wdith is smaller than 0.15 m or larger than 25 m it is set to 2 m for primary channels.
5. If a crest wdith is smaller than 0.15 m or larger than 25 m it is set to 1 m for not primary channels.
6. If the shape of a crest is not possible is is set to a rectangle.
*/
/*
Stuwen 1) Kruinhoogte (mNAP) moet minimaal gelijk of groter dan peil
2) Kruinhoogte (mNAP) moet groter zijn dan dan bodemhoogte
3) Kruinhoogte moet tussen minimaal (-10mNAP) en maximaal (+10mNAP) liggen
*/
DROP TABLE IF EXISTS tmp.weir_level_radius
;

CREATE TABLE tmp.weir_level_radius AS
    (
        WITH radius_search AS
            (
                SELECT
                    a.code          as weir_code
                  , streefpeil_bwn2 as streefpeil
                FROM
                    checks.weirs                  a
                  , checks.fixeddrainagelevelarea b
                WHERE
                    ST_DWithin(a.geom,b.geom,2)
            )
        SELECT
            weir_code
          , max(streefpeil) as max_streefpeil
        FROM
            radius_search
        GROUP BY
            weir_code
        HAVING
            COUNT(*) > 1 --Mits er meerdere streefpeilen gevonden zijn
    )
;

UPDATE
    checks.weirs a
SET crest_level = b.max_streefpeil
  , aanname     = concat_ws(',',aanname,'crest_heigth')
FROM
    tmp.weir_level_radius b
WHERE
    a.channel_type_id = 1
    AND a.code        = b.weir_code
    AND a.crest_level < b.max_streefpeil
;

UPDATE
    checks.weirs a
SET crest_level = b.max_streefpeil
  , aanname     = concat_ws(',',aanname,'crest_heigth')
FROM
    tmp.weir_level_radius b
WHERE
    a.channel_type_id <> 1
    AND a.code         = b.weir_code
    AND a.crest_level  < b.max_streefpeil
;

DROP TABLE IF EXISTS tmp.max_bottom_weir_radius
;

CREATE TABLE tmp.max_bottom_weir_radius AS
    (
        WITH radius_search AS
            (
                SELECT
                    a.code      as weir_code
                  , b.code      as fdla_code
                  , b.bed_level as channel_bedlevel
                FROM
                    checks.weirs   a
                  , checks.channel b
                WHERE
                    ST_DWithin(a.geom,b.geom,2)
            )
        SELECT
            weir_code
          ,
             -- ST_Union(weir_geom) as geom,
             max(channel_bedlevel) as max_channelbedlevel
        FROM
            radius_search
        GROUP BY
            weir_code
        HAVING
            COUNT(*) > 1 --Mits er meerdere channels verbonden zijn
    )
;

UPDATE
    checks.weirs a
SET crest_level = b.max_channelbedlevel + 0.5
  , aanname     = concat_ws(',',aanname,'crest_heigth')
FROM
    tmp.max_bottom_weir_radius b
WHERE
    a.channel_type_id = 1
    AND a.code        = b.weir_code
    AND a.crest_level < b.max_channelbedlevel
;

UPDATE
    checks.weirs a
SET crest_level = b.max_channelbedlevel + 0.5
  , aanname     = concat_ws(',',aanname,'crest_heigth')
FROM
    tmp.max_bottom_weir_radius b
WHERE
    a.channel_type_id <> 1
    AND a.code         = b.weir_code
    AND a.crest_level  < b.max_channelbedlevel
;

UPDATE
    checks.weirs a
SET crest_level = -10
  , aanname     = concat_ws(',',aanname,'crest_heigth')
WHERE
    crest_level < -10
;

UPDATE
    checks.weirs a
SET crest_level = 10
  , aanname     = concat_ws(',',aanname,'crest_heigth')
WHERE
    crest_level > 10
;

UPDATE
    checks.weirs
SET crest_width = 2
  , aanname     = concat_ws(',',aanname,'crest_width')
WHERE
    channel_type_id = 1
    AND
    (
        crest_width NOT BETWEEN 0.15 AND 25
        OR crest_width IS NULL
    )
;

UPDATE
    checks.weirs
SET crest_width = 1
  , aanname     = concat_ws(',',aanname,'crest_width')
WHERE
    channel_type_id <> 1
    AND
    (
        crest_width NOT BETWEEN 0.15 AND 25
        OR crest_width IS NULL
    )
;

UPDATE
    checks.weirs
SET shape   = 1
  , aanname = concat_ws(',',aanname,'shape')
WHERE
    shape > 2
;