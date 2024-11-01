-- Zijn er hele kleine peilgebieden (<1000m2) die niet kunnen kloppen?
UPDATE
    checks.fixeddrainagelevelarea
SET opmerking = concat_ws(',',opmerking,'kleiner dan 1000m2')
WHERE
    ST_Area(geom) < 1000
;

DROP INDEX IF EXISTS checks.checks_fixeddrainagelevelarea_id;
DROP INDEX IF EXISTS checks.checks_fixeddrainagelevelarea_geom;
DROP INDEX IF EXISTS checks.checks_channel_geom;
CREATE INDEX checks_fixeddrainagelevelarea_id
ON
    checks.fixeddrainagelevelarea
USING btree
    (
        id
    )
;

CREATE INDEX checks_fixeddrainagelevelarea_geom
on
    checks.fixeddrainagelevelarea
USING gist
    (
        geom
    )
;

CREATE INDEX checks_channel_geom
ON
    checks.channel
USING gist
    (
        geom
    )
;

-- 1) welke peilgebieden hebben geen watergangen?
DROP TABLE IF EXISTS tmp.fixeddrainagelevelarea_with_channel
;

CREATE TABLE tmp.fixeddrainagelevelarea_with_channel AS
SELECT distinct
on
    (
        a.id
    )
    a.id
FROM
    checks.fixeddrainagelevelarea as a
  , checks.channel                as b
WHERE
    ST_Intersects(a.geom,b.geom)
;

--In geval van GEOSIntersects: TopologyException: side location conflict at a.geom bufferen met 0.
-- WHERE ST_Intersects(ST_Buffer(a.geom,0),b.geom)
-- 2) vervolg: welke peilgebieden hebben geen watergangen?
UPDATE
    checks.fixeddrainagelevelarea
SET opmerking = concat_ws(',',opmerking,'geen watergang')
WHERE
    id NOT IN
    (
        SELECT
            id
        FROM
            tmp.fixeddrainagelevelarea_with_channel
    )
;

DROP INDEX IF EXISTS checks_fixeddrainagelevelarea_with_channel_id;
CREATE INDEX checks_fixeddrainagelevelarea_with_channel_id
ON
    tmp.fixeddrainagelevelarea_with_channel
USING btree
    (
        id
    )
;


-- peilgebieden die geen peil hebben in damo_ruw 
update
    checks.fixeddrainagelevelarea
set opmerking = concat_ws(',',opmerking,'geen damopeil')
where
    streefpeil_bwn2 is null
    or streefpeil_bwn2 NOT BETWEEN -9.99 AND 10
;

-- tabellen weggooien
DROP TABLE IF EXISTS tmp.fixeddrainagelevelarea_with_channel
;