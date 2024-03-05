-- copy crossprofile to checks schema
DROP TABLE IF EXISTS checks.crossprofile
;

CREATE TABLE checks.crossprofile AS
SELECT *
FROM
    nxt.crossprofile
;

ALTER TABLE checks.crossprofile DROP COLUMN IF EXISTS max_height
;

ALTER TABLE checks.crossprofile DROP COLUMN IF EXISTS max_width
;

ALTER TABLE checks.crossprofile DROP COLUMN IF EXISTS min
;

ALTER TABLE checks.crossprofile DROP COLUMN IF EXISTS max
;

ALTER TABLE checks.crossprofile DROP COLUMN IF EXISTS nr_input_points
;

ALTER TABLE checks.crossprofile DROP COLUMN IF EXISTS opmerking
;

ALTER TABLE checks.crossprofile ADD COLUMN max_height float
;

ALTER TABLE checks.crossprofile ADD COLUMN max_width float
;

ALTER TABLE checks.crossprofile ADD COLUMN min float
;

ALTER TABLE checks.crossprofile ADD COLUMN max float
;

ALTER TABLE checks.crossprofile ADD COLUMN nr_input_points integer
;

ALTER TABLE checks.crossprofile ADD COLUMN opmerking varchar(250)
;

UPDATE
    checks.crossprofile a
SET max_height      = b.max_height
  , max_width       = b.max_width
  , min             = b.min
  , max             = b.max
  , nr_input_points = b.nr_input_points
FROM
    tmp.tabulated_table b
WHERE
    a.id = b.pro_id
;

-- add opmerking
UPDATE
    checks.crossprofile
SET opmerking = 'profielhoogte<0.3m'
WHERE
    max_height < 0.3
;

UPDATE
    checks.crossprofile
SET opmerking = concat_ws(',',opmerking,'profielbreedte<2m')
WHERE
    max_width <2
;

UPDATE
    checks.crossprofile
SET opmerking = concat_ws(',',opmerking,'lage bodem?[mnap]?')
WHERE
    min <-9
;

UPDATE
    checks.crossprofile
SET opmerking = concat_ws(',',opmerking,'hoge bodem[mnap]?')
WHERE
    min >3
;

UPDATE
    checks.crossprofile
SET opmerking = concat_ws(',',opmerking,'lage bovenkant[mnap]?')
WHERE
    max <-6
;

UPDATE
    checks.crossprofile
SET opmerking = concat_ws(',',opmerking,'hoge bovenkant[mnap]?')
WHERE
    max >6
;

UPDATE
    checks.crossprofile
SET opmerking = concat_ws(',',opmerking,'aantal profielpunten<5')
WHERE
    nr_input_points <5
;

-- copy crosssection to checks schema
DROP TABLE IF EXISTS checks.crosssection
;

CREATE TABLE checks.crosssection AS
SELECT
    id
  , cross_profile_id
  , cross_profile_id::varchar as code
  , channel_id
  , prw_id
  , friction_type
  , friction_value
  , distance_on_channel
  , bank_level
  , bed_level
  , bed_width
  , width
  , slope_left
  , slope_right
  , reclamation
  , created
  , ST_force2D(ST_Transform(geometry,28992)) as geom
FROM
    nxt.crosssection
;

CREATE INDEX checks_crosssection_geom
ON
    checks.crosssection
USING gist
    (
        geom
    )
;

ALTER TABLE checks.crosssection DROP COLUMN IF EXISTS numgeometries
;

ALTER TABLE checks.crosssection DROP COLUMN IF EXISTS opmerking
;

ALTER TABLE checks.crosssection ADD COLUMN numgeometries integer
;

ALTER TABLE checks.crosssection ADD COLUMN opmerking varchar(250)
;

UPDATE
    checks.crosssection a
SET opmerking     = b.opmerking
  , numgeometries = b.numgeometries
FROM
    tmp.tabulated_table b
WHERE
    a.cross_profile_id = b.pro_id
;

UPDATE
    checks.crosssection
SET opmerking = 'gw_pro dubbel ingetekend'
WHERE
    opmerking = 'duplicate,koppel obv geom'
;

UPDATE
    checks.crosssection
SET opmerking = concat_ws(',',opmerking,'gw_pro zigzag ingetekend')
WHERE
    numgeometries>1
;

-- 5) Zijn de dwarsprofielen bruikbaar? Zowel de geometrie (crossection) als de profielvorm (profile) moet in orde zijn voor 3di.
-- isusable = 1      --> te gebruiken in 3Di
-- isusable = 0      --> niet te gebruiken in 3Di
-- isusable = NULL   --> niet te gebruiken in 3Di
ALTER TABLE checks.crosssection DROP COLUMN IF EXISTS isusable
;

ALTER TABLE checks.crosssection ADD COLUMN isusable integer
;

ALTER TABLE checks.crossprofile DROP COLUMN IF EXISTS isusable
;

ALTER TABLE checks.crossprofile ADD COLUMN isusable INTEGER
;

-- 5.1) Geometrie is bruikbaar als koppeling tussen dwarsprofiellijn en hydroopject mogelijk is
UPDATE
    checks.crosssection
SET isusable =
    CASE
        WHEN opmerking LIKE '%koppel niet mogelijk obv geom of code%'
            OR geom IS NULL
            THEN 0
            ELSE 1
    END
;

-- 5.2) Geometrie is niet bruikbaar als op die plek een invalid crossprofile is (profile met opmerking)
UPDATE
    checks.crosssection
SET isusable = 0
WHERE
    cross_profile_id IN
    (
        SELECT
            id
        FROM
            checks.crossprofile
        WHERE
            opmerking    LIKE 'profielbreedte<2m'
            OR opmerking LIKE 'profielhoogte<0.3m'
            OR opmerking LIKE 'aantal profielpunten<5'
    )
;

-- 5.3 isusable moet 0 of 1 zijn (en niet NULL)
UPDATE
    checks.crosssection
SET isusable = 0
WHERE
    isusable IS NULL
;

-- 5.4) Profielvorm is bruikbaar als doorstroomhoogte minimaal 30cm is, profielbreedte minimaal 2m is, en bij minimaal 5 damo profielpunten
UPDATE
    checks.crossprofile
SET isusable = 1
WHERE
    id NOT IN
    (
        SELECT
            id
        FROM
            checks.crossprofile
        WHERE
            opmerking    LIKE 'profielbreedte<2m'
            OR opmerking LIKE 'profielhoogte<0.3m'
            OR opmerking LIKE 'aantal profielpunten<5'
    )
;

-- 5.5) Profielvorm is niet bruikbaar als de geometrie ervan (cross section) niet bruikbaar is
UPDATE
    checks.crossprofile
SET isusable = 0
WHERE
    id IN
    (
        SELECT
            cross_profile_id
        FROM
            checks.crosssection
        WHERE
            isusable = 0
    )
;

-- 5.6) isusable moet 0 of 1 zijn (en niet NULL)
UPDATE
    checks.crossprofile
SET isusable = 0
WHERE
    isusable IS NULL
;

SELECT
    COUNT(*)
FROM
    checks.crosssection
;

SELECT
    COUNT(*)
FROM
    checks.crosssection
WHERE
    isusable = 1
;

-- 10527 vd 19295 zijn bruikbaar
SELECT
    COUNT(*)
FROM
    checks.crossprofile
;

SELECT
    COUNT(*)
FROM
    checks.crossprofile
WHERE
    isusable = 1
;

-- 10527 vd 19295 zijn bruikbaar
-- zijn crossprofiles en crosssection wel consistent met elkaar (mbt isusable)?
SELECT *
FROM
    checks.crossprofile
WHERE
    isusable <> 1
    AND id NOT IN
    (
        SELECT
            cross_profile_id
        FROM
            checks.crosssection
        WHERE
            isusable <> 1
    )
;

-- Andersom: zijn crosssection en crossprofiles wel consistent met elkaar (mbt isusable)?
SELECT *
FROM
    checks.crosssection
WHERE
    isusable <> 1
    AND cross_profile_id NOT IN
    (
        SELECT
            id
        FROM
            checks.crossprofile
        WHERE
            isusable <> 1
    )
;

/* DIT SCRIPT IS OM RELATIE TE LEGGEN TUSSEN aantal_profielpunten per dwarsprofiellijn (puur ter info)
drop table if exists tmp.aantal_yz_waarden;
create table tmp.aantal_yz_waarden as select distinct on (aantal_yz_waarden) null::integer as cnt_profielen,
aantal_yz_waarden from checks.profielen order by aantal_yz_waarden;
update tmp.aantal_yz_waarden a
set cnt_profielen = b.cnt_profiles
from (
select aantal_yz_waarden, count(aantal_yz_waarden) as cnt_profiles
from checks.profielen
group by 1
) as b
where a.aantal_yz_waarden = b.aantal_yz_waarden;
select * from tmp.aantal_yz_waarden;
*/
--Add check
-- REGEX to check decimals seperated by spaces:  ^\d+(\.\d+)?(\s\d+(\.\d+)?)*\s\d+(\.\d+)?$
-- Count spaces in both DATALENGTH(Name)-LEN(REPLACE(Name,' ', '')) AS Count_Of_Spaces
-- Check for increasing height
DROP TABLE IF EXISTS tmp.badly_ordered_tabulated_profiles
;

CREATE TABLE tmp.badly_ordered_tabulated_profiles AS
    (
        WITH unnested AS
            (
                SELECT
                    id
                  , unnest(string_to_array(tabulated_height, ' '))                 as height
                  , generate_subscripts(string_to_array(tabulated_height, ' '), 1) AS idx
                FROM
                    checks.channel
                WHERE
                    tabulated_height IS NOT NULL
            )
        SELECT
            a.id
          , a.idx    as aidx
          , b.idx    as bidx
          , a.height as aheight
          , b.height as bheight
        FROM
            unnested a
          , unnested b
        WHERE
            a.id        = b.id
            AND a.idx+1 = b.idx
            AND a.height ~ '\d+(\.\d+)?'
            AND b.height ~ '\d+(\.\d+)?'
            AND a.height::double precision > b.height::double precision
    )
;

ALTER TABLE checks.channel DROP COLUMN IF EXISTS profile_valid
;

ALTER TABLE checks.channel ADD COLUMN profile_valid boolean
;
-- TODO, gaat dit goed met gemeten profielen?
UPDATE
    checks.channel
SET profile_valid = ( tabulated_width ~ '^\d+(\.\d+)?(\s\d+(\.\d+)?)*\s\d+(\.\d+)?$'
    AND tabulated_height ~ '^\d+(\.\d+)?(\s\d+(\.\d+)?)*\s\d+(\.\d+)?$'
    AND derived_bed_level IS NOT NULL
    AND tabulated_width   IS NOT NULL
    AND tabulated_height  IS NOT NULL
    AND
    (
        LENGTH(tabulated_width)-LENGTH(REPLACE(tabulated_width,' ', ''))
    )
    =(LENGTH(tabulated_height)-LENGTH(REPLACE(tabulated_height,' ', '')))
    AND id NOT IN
    (
        SELECT
            id
        FROM
            tmp.badly_ordered_tabulated_profiles
    )
    )
;

ALTER TABLE checks.channel DROP COLUMN IF EXISTS profile_type
;

ALTER TABLE checks.channel ADD COLUMN profile_type character varying(50)
;

UPDATE
    checks.channel
SET profile_type =
    CASE
        WHEN profile_valid
            THEN 'getabuleerde breedte en bodemhoogte'
            ELSE 'legger'
    END
;