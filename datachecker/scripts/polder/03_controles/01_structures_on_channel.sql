/*
Script to check if a hydraulic structure is positioned an a channel
- Weirs (intersect with buffered channel)
- Fixed dam (intersect with buffered channel)
- Bridge (intersect with buffered channel)
- Pumpstation (intersect with buffered channel)
- Culvert (contained by buffered channel)
*/
--Weirs
ALTER TABLE checks.weirs DROP COLUMN IF EXISTS on_channel
;

ALTER TABLE checks.weirs ADD COLUMN on_channel boolean DEFAULT False
;

UPDATE
    checks.weirs as a
SET on_channel = True
WHERE
    a.code IN
    (
        SELECT
            a.code
        FROM
            checks.weirs             as a
          , checks.channel_linemerge as b
        WHERE
            ST_Intersects(b.bufgeom,a.geom)
    )
;

--Fixed dam
ALTER TABLE checks.fixed_dam DROP COLUMN IF EXISTS on_channel
;

ALTER TABLE checks.fixed_dam ADD COLUMN on_channel boolean DEFAULT False
;

UPDATE
    checks.fixed_dam as a
SET on_channel = True
WHERE
    a.code IN
    (
        SELECT
            a.code
        FROM
            checks.fixed_dam         as a
          , checks.channel_linemerge as b
        WHERE
            ST_Intersects(b.bufgeom,a.geom)
    )
;

--Bridge
ALTER TABLE checks.bridge DROP COLUMN IF EXISTS on_channel
;

ALTER TABLE checks.bridge ADD COLUMN on_channel boolean DEFAULT False
;

UPDATE
    checks.bridge as a
SET on_channel = True
WHERE
    a.code IN
    (
        SELECT
            a.code
        FROM
            checks.bridge            as a
          , checks.channel_linemerge as b
        WHERE
            ST_Intersects(b.bufgeom,a.geom)
    )
;

--Pumpstation
ALTER TABLE checks.pumpstation DROP COLUMN IF EXISTS on_channel
;

ALTER TABLE checks.pumpstation ADD COLUMN on_channel boolean DEFAULT False
;

UPDATE
    checks.pumpstation as a
SET on_channel = True
WHERE
    a.code IN
    (
        SELECT
            a.code
        FROM
            checks.pumpstation       as a
          , checks.channel_linemerge as b
        WHERE
            ST_Intersects(b.bufgeom,a.geom)
    )
;

-- Culvert (needs to be completely contained by channel)
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS on_channel
;

ALTER TABLE checks.culvert ADD COLUMN on_channel boolean DEFAULT False
;

UPDATE
    checks.culvert as a
SET on_channel = True
WHERE
    a.code IN
    (
        SELECT
            a.code
        FROM
            checks.culvert           as a
          , checks.channel_linemerge as b
        WHERE
            ST_Contains(b.bufgeom,a.geom)
    )
;

/*
A structure should be on maximum 2 channels, check if this is the case
*/
-- Pumpstation
ALTER TABLE checks.pumpstation DROP COLUMN IF EXISTS multiple_channels
;

ALTER TABLE checks.pumpstation ADD COLUMN multiple_channels boolean DEFAULT False
;

WITH koppels AS
    (
        SELECT
            a.code
          , a.geom
          , count(b.*)
          , min(b.channel_type_id) as channel_type_id
        FROM
            checks.pumpstation       as a
          , checks.channel_linemerge as b
        WHERE
            ST_Intersects(b.bufgeom,a.geom)
        GROUP BY
            a.code
          , a.geom
    )
UPDATE
    checks.pumpstation as a
SET multiple_channels = True
  , opmerking         = concat_ws(',',a.opmerking,('meerdere watergangen:'
        ||count))
FROM
    koppels as b
WHERE
    a.code    = b.code
    AND count > 2
;

-- Bridge
ALTER TABLE checks.bridge DROP COLUMN IF EXISTS multiple_channels
;

ALTER TABLE checks.bridge ADD COLUMN multiple_channels boolean DEFAULT False
;

WITH koppels AS
    (
        SELECT
            a.code
          , a.geom
          , count(b.*)
          , min(b.channel_type_id) as channel_type_id
        FROM
            checks.bridge            as a
          , checks.channel_linemerge as b
        WHERE
            ST_Intersects(b.bufgeom,a.geom)
        GROUP BY
            a.code
          , a.geom
    )
UPDATE
    checks.bridge as a
SET multiple_channels = True
  , opmerking         = concat_ws(',',a.opmerking,('meerdere watergangen:'
        ||count))
FROM
    koppels as b
WHERE
    a.code    = b.code
    AND count > 2
;

-- Weirs
ALTER TABLE checks.weirs DROP COLUMN IF EXISTS multiple_channels
;

ALTER TABLE checks.weirs ADD COLUMN multiple_channels boolean DEFAULT False
;

WITH koppels AS
    (
        SELECT
            a.code
          , a.geom
          , count(b.*)
          , min(b.channel_type_id) as channel_type_id
        FROM
            checks.weirs             as a
          , checks.channel_linemerge as b
        WHERE
            ST_Intersects(b.bufgeom,a.geom)
        GROUP BY
            a.code
          , a.geom
    )
UPDATE
    checks.weirs as a
SET multiple_channels = True
  , opmerking         = concat_ws(',',a.opmerking,('meerdere watergangen:'
        ||count))
FROM
    koppels as b
WHERE
    a.code    = b.code
    AND count > 2
;

-- Fixed dam
ALTER TABLE checks.fixed_dam DROP COLUMN IF EXISTS multiple_channels
;

ALTER TABLE checks.fixed_dam ADD COLUMN multiple_channels boolean DEFAULT False
;

WITH koppels AS
    (
        SELECT
            a.code
          , a.geom
          , count(b.*)
          , min(b.channel_type_id) as channel_type_id
        FROM
            checks.fixed_dam         as a
          , checks.channel_linemerge as b
        WHERE
            ST_Intersects(b.bufgeom,a.geom)
        GROUP BY
            a.code
          , a.geom
    )
UPDATE
    checks.fixed_dam as a
SET multiple_channels = True
  , opmerking         = concat_ws(',',a.opmerking,('meerdere watergangen:'
        ||count))
FROM
    koppels as b
WHERE
    a.code    = b.code
    AND count > 2
;