/*
1.  Dit script bepaalt de bruikbaarheid (isusable = 0 of 1) van kunstwerken,
gebaseerd op de opmerkingen per kunstwerken.
2.  Indien er een aanname is gedaan bij een kunstwerk wordt de flag hasassumption op 1 gezet.
3.  Per polder wordt een kwaliteitsindicator berekend (getal 0-100) adhv #errors/m^2 en genormaliseerd op de maximale waarde. De styling in Lizard wordt gebasseerd op de kwaliteitsindicator. Lizard styling obv van varchar(250), met daarin meerdere opmerkingen is niet te doen in Lizard, vandaar deze 0-100 keuze.
*/
/*
1.  Bruikbaarheid
*/
--bridge
ALTER TABLE checks.bridge DROP COLUMN IF EXISTS isusable
;

ALTER TABLE checks.bridge ADD COLUMN isusable integer DEFAULT 1
;

UPDATE
    checks.bridge
SET isusable = 0
WHERE
    opmerking IS NOT NULL
    AND opmerking      != ''
;

--crossprofile
ALTER TABLE checks.crossprofile DROP COLUMN IF EXISTS isusable
;

ALTER TABLE checks.crossprofile ADD COLUMN isusable integer DEFAULT 1
;

UPDATE
    checks.crossprofile
SET isusable = 0
WHERE
    opmerking LIKE ANY(ARRAY['%profielhoogte<0.1m%','%profielbreedte<2m%'])
;

--crosssection
ALTER TABLE checks.crosssection DROP COLUMN IF EXISTS isusable
;

ALTER TABLE checks.crosssection ADD COLUMN isusable integer DEFAULT 1
;

UPDATE
    checks.crosssection
SET isusable = 0
WHERE
    opmerking LIKE ANY(ARRAY['%gw_pro dubbel ingetekend%','%koppel niet mogelijk obv geom of code%','%gw_pro zigzag ingetekend%'])
;

--culvert
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS isusable
;

ALTER TABLE checks.culvert ADD COLUMN isusable integer DEFAULT 1
;

UPDATE
    checks.culvert
SET isusable = 0
WHERE
    opmerking LIKE ANY(ARRAY['%geen watergang%','%culvert on channel_nowayout%','%culvert on channel_loose%'])
    OR NOT on_channel
; -- '%niet afsluitbaar op peilgrens%','%pomp op duiker%','%stuw op duiker%']);
--fixed_dam
ALTER TABLE checks.fixed_dam DROP COLUMN IF EXISTS isusable
;

ALTER TABLE checks.fixed_dam ADD COLUMN isusable integer DEFAULT 1
;

UPDATE
    checks.fixed_dam
SET isusable = 0
WHERE
    NOT on_channel
    OR multiple_channels
    OR NOT on_fdla_border
;

--pumpstation
ALTER TABLE checks.pumpstation DROP COLUMN IF EXISTS isusable
;

ALTER TABLE checks.pumpstation ADD COLUMN isusable integer DEFAULT 1
;

UPDATE
    checks.pumpstation
SET isusable = 0
WHERE
    (
        opmerking LIKE ANY(ARRAY['%meerdere watergangen:%','%niet op peilgrens%','%geen watergang%'])
        OR NOT on_channel
    )
    AND opmerking NOT LIKE '%afvoer%'
;

UPDATE
    checks.pumpstation
SET isusable = 0
WHERE
    start_level IS NULL
;

--weirs
ALTER TABLE checks.weirs DROP COLUMN IF EXISTS isusable
;

ALTER TABLE checks.weirs ADD COLUMN isusable integer DEFAULT 1
;

UPDATE
    checks.weirs
SET isusable = 0
WHERE
    opmerking LIKE ANY(ARRAY['%meerdere watergangen:%','%niet op peilgrens%','%geen watergang%'])
    OR NOT on_channel
; -- '%crest/startlevel onbetrouwbaar%' verwijderd
UPDATE
    checks.weirs
SET isusable = 0
WHERE
    crest_level IS NULL
;

/*
2.  Aannames
*/
--bridge
ALTER TABLE checks.bridge DROP COLUMN IF EXISTS hasassumption
;

ALTER TABLE checks.bridge ADD COLUMN hasassumption integer DEFAULT 0
;

UPDATE
    checks.bridge
SET hasassumption = 1
WHERE
    aanname IS NOT NULL
;

--channel
ALTER TABLE checks.channel DROP COLUMN IF EXISTS hasassumption
;

ALTER TABLE checks.channel ADD COLUMN hasassumption integer DEFAULT 0
;

UPDATE
    checks.channel
SET hasassumption = 1
WHERE
    aanname IS NOT NULL
;

--culvert
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS hasassumption
;

ALTER TABLE checks.culvert ADD COLUMN hasassumption integer DEFAULT 0
;

UPDATE
    checks.culvert
SET hasassumption = 1
WHERE
    aanname IS NOT NULL
;

--pumpstation
ALTER TABLE checks.pumpstation DROP COLUMN IF EXISTS hasassumption
;

ALTER TABLE checks.pumpstation ADD COLUMN hasassumption integer DEFAULT 0
;

UPDATE
    checks.pumpstation
SET hasassumption = 1
WHERE
    aanname IS NOT NULL
;

--weirs
ALTER TABLE checks.weirs DROP COLUMN IF EXISTS hasassumption
;

ALTER TABLE checks.weirs ADD COLUMN hasassumption integer DEFAULT 0
;

UPDATE
    checks.weirs
SET hasassumption = 1
WHERE
    aanname IS NOT NULL
;

/*
3.  Kwaliteitsindicator
*/
--bereken per polder % niet bruikbare kunstwerken (per kunstwerktype)
--pumpstation_primair
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_pump_error_primair
;

ALTER TABLE checks.polder ADD COLUMN prct_pump_error_primair double precision
;

UPDATE
    checks.polder a
SET prct_pump_error_primair = round(100*CAST(cnt_pump_error_primair AS FLOAT)/count)
FROM
    (
        select
            a.polder_id
          , count(b.*)
        from
            checks.polder      a
          , checks.pumpstation b
        where
            channel_type_id = 1
            and ST_Intersects(a.geom,b.geom)
        GROUP BY
            a.polder_id
    )
    as b
WHERE
    a.polder_id = b.polder_id
;

UPDATE
    checks.polder
SET prct_pump_error_primair = 0
WHERE
    prct_pump_error_primair IS NULL
;

--pumpstation_non_primair
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_pump_error_non_primair
;

ALTER TABLE checks.polder ADD COLUMN prct_pump_error_non_primair double precision
;

UPDATE
    checks.polder a
SET prct_pump_error_non_primair = round(100*CAST(cnt_pump_error_non_primair AS FLOAT)/count)
FROM
    (
        select
            a.polder_id
          , count(b.*)
        from
            checks.polder      a
          , checks.pumpstation b
        where
            channel_type_id != 1
            and ST_Intersects(a.geom,b.geom)
        GROUP BY
            a.polder_id
    )
    as b
WHERE
    a.polder_id = b.polder_id
;

UPDATE
    checks.polder
SET prct_pump_error_non_primair = 0
WHERE
    prct_pump_error_non_primair IS NULL
;

--culvert_primair
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_culvert_error_primair
;

ALTER TABLE checks.polder ADD COLUMN prct_culvert_error_primair double precision
;

UPDATE
    checks.polder a
SET prct_culvert_error_primair = round(100*CAST(cnt_culvert_error_primair AS FLOAT)/count)
FROM
    (
        select
            a.polder_id
          , count(b.*)
        from
            checks.polder  a
          , checks.culvert b
        where
            channel_type_id = 1
            and ST_Intersects(a.geom,b.geom)
        GROUP BY
            a.polder_id
    )
    as b
WHERE
    a.polder_id = b.polder_id
;

UPDATE
    checks.polder
SET prct_culvert_error_primair = 0
WHERE
    prct_culvert_error_primair IS NULL
;

--culvert_non_primair
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_culvert_error_non_primair
;

ALTER TABLE checks.polder ADD COLUMN prct_culvert_error_non_primair double precision
;

UPDATE
    checks.polder a
SET prct_culvert_error_non_primair = round(100*CAST(cnt_culvert_error_non_primair AS FLOAT)/count)
FROM
    (
        select
            a.polder_id
          , count(b.*)
        from
            checks.polder  a
          , checks.culvert b
        where
            channel_type_id != 1
            and ST_Intersects(a.geom,b.geom)
        GROUP BY
            a.polder_id
    )
    as b
WHERE
    a.polder_id = b.polder_id
;

UPDATE
    checks.polder
SET prct_culvert_error_non_primair = 0
WHERE
    prct_culvert_error_non_primair IS NULL
;

--weirs_primair
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_weirs_error_primair
;

ALTER TABLE checks.polder ADD COLUMN prct_weirs_error_primair double precision
;

UPDATE
    checks.polder a
SET prct_weirs_error_primair = round(100*CAST(cnt_weirs_error_primair AS FLOAT)/count)
FROM
    (
        select
            a.polder_id
          , count(b.*)
        from
            checks.polder a
          , checks.weirs  b
        where
            channel_type_id = 1
            and ST_Intersects(a.geom,b.geom)
        GROUP BY
            a.polder_id
    )
    as b
WHERE
    a.polder_id = b.polder_id
;

UPDATE
    checks.polder
SET prct_weirs_error_primair = 0
WHERE
    prct_weirs_error_primair IS NULL
;

--weirs_non_primair
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_weirs_error_non_primair
;

ALTER TABLE checks.polder ADD COLUMN prct_weirs_error_non_primair double precision
;

UPDATE
    checks.polder a
SET prct_weirs_error_non_primair = round(100*CAST(cnt_weirs_error_non_primair AS FLOAT)/count)
FROM
    (
        select
            a.polder_id
          , count(b.*)
        from
            checks.polder a
          , checks.weirs  b
        where
            channel_type_id != 1
            and ST_Intersects(a.geom,b.geom)
        GROUP BY
            a.polder_id
    )
    as b
WHERE
    a.polder_id = b.polder_id
;

UPDATE
    checks.polder
SET prct_weirs_error_non_primair = 0
WHERE
    prct_weirs_error_non_primair IS NULL
;

/*
Kruisingen moeten eerst (opnieuw) bepaald worden en gejoined met
polder_id en channel_type_id (primair/non_primair)
*/
--Join polder_id en channel_type_id naar checks.kruising
DROP TABLE IF EXISTS checks.kruising
;

CREATE TABLE checks.kruising AS
    (
        SELECT
            a.*
          , b.polder_id
          , CASE
                WHEN a.channel_type_id = 1
                    THEN 1
                    ELSE 0
            END AS primair
        FROM
            (
                SELECT DISTINCT
                ON
                    (
                        ST_INTERSECTION(x.geom,y.geom)
                    )
                    x.id as channel_id
                  , x.channel_type_id
                  , ST_INTERSECTION(x.geom,y.geom) as geom_kruising
                FROM
                    checks.channel_linemerge       as x
                  , checks.peilgrens_met_waterpeil as y
                WHERE
                    ST_Intersects(x.geom,y.geom)
            )
            AS a
            LEFT JOIN
                checks.polder AS b
                ON
                    ST_INTERSECTS(a.geom_kruising,b.geom)
    )
;

--kruising_primair
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_kruising_error_primair
;

ALTER TABLE checks.polder ADD COLUMN prct_kruising_error_primair double precision
;

UPDATE
    checks.polder a
SET prct_kruising_error_primair = round(100*CAST(cnt_kruising_error_primair AS FLOAT)/count)
FROM
    (
        select
            a.polder_id
          , count(b.*)
        from
            checks.polder   a
          , checks.kruising b
        where
            channel_type_id = 1
            and ST_Intersects(a.geom,b.geom_kruising)
        GROUP BY
            a.polder_id
    )
    as b
WHERE
    a.polder_id = b.polder_id
;

UPDATE
    checks.polder
SET prct_pump_error_primair = 0
WHERE
    prct_pump_error_primair IS NULL
;

--kruising_non_primair
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_kruising_error_non_primair
;

ALTER TABLE checks.polder ADD COLUMN prct_kruising_error_non_primair double precision
;

UPDATE
    checks.polder a
SET prct_kruising_error_non_primair = round(100*CAST(cnt_kruising_error_non_primair AS FLOAT)/count)
FROM
    (
        select
            a.polder_id
          , count(b.*)
        from
            checks.polder   a
          , checks.kruising b
        where
            channel_type_id != 1
            and ST_Intersects(a.geom,b.geom_kruising)
        GROUP BY
            a.polder_id
    )
    as b
WHERE
    a.polder_id = b.polder_id
;

UPDATE
    checks.polder
SET prct_pump_error_non_primair = 0
WHERE
    prct_pump_error_non_primair IS NULL
;

--Determine usability of control rules
ALTER TABLE checks.control_table DROP COLUMN IF EXISTS structure_isusable
;

ALTER TABLE checks.control_table ADD COLUMN structure_isusable boolean
;

UPDATE
    checks.control_table
SET structure_isusable = structure_code IN
    (
        SELECT
            code
        FROM
            checks.weirs
        WHERE
            isusable=1
        UNION
        SELECT
            code
        FROM
            checks.pumpstation
        WHERE
            isusable=1
        UNION
        SELECT
            code
        FROM
            checks.culvert
        WHERE
            isusable=1
    )
;

UPDATE
    checks.control_table
SET is_usable = (unique_code
    AND structure_exists
    AND correct_measurement_series
    AND structure_isusable)
;

UPDATE
    checks.control_table
SET opmerking = concat_ws(',',opmerking,'geen unieke kunstwerk code')
WHERE
    NOT unique_code
;

UPDATE
    checks.control_table
SET opmerking = concat_ws(',',opmerking,'kunstwerk niet gevonden')
WHERE
    NOT structure_exists
;

UPDATE
    checks.control_table
SET opmerking = concat_ws(',',opmerking,'meetwaardes niet volledig op/aflopend')
WHERE
    NOT correct_measurement_series
;

UPDATE
    checks.control_table
SET opmerking = concat_ws(',',opmerking,'kunstwerk is niet bruikbaar')
WHERE
    NOT structure_isusable
;

UPDATE
    checks.control_table
SET opmerking = concat_ws(',',opmerking,'geen kunstwerkcode ingevuld')
WHERE
    NOT has_code
;