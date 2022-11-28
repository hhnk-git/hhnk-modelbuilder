-- peilgrenzen omzetten naar levees
-- maak de buitenste ringen
DROP TABLE IF EXISTS tmp.peilgrenzen3
;

CREATE TABLE tmp.peilgrenzen3 AS
SELECT
    ST_ExteriorRing((ST_Dump(ST_Force2D(ST_Transform(geom,28992)))).geom) as geom
FROM
    checks.fixeddrainagelevelarea
;

CREATE INDEX tmp_peilgrenzen3_geom
ON
    tmp.peilgrenzen3
USING gist
    (
        geom
    )
;

-- peilgrenzen vereenvoudigen
DROP TABLE IF EXISTS tmp.peilgrenzen2
;

CREATE TABLE tmp.peilgrenzen2 AS
SELECT
    ST_SimplifyPreserveTopology((ST_Dump(ST_LineMerge(ST_Union(geom)))).geom,0.2) as geom
FROM
    tmp.peilgrenzen3
;

-- Opknippen circulaire peilgrenzen
DROP SEQUENCE IF EXISTS waterid;
CREATE SEQUENCE waterid;
DROP TABLE IF EXISTS tmp.peilgrenzen
;

CREATE TABLE tmp.peilgrenzen as
SELECT
    ST_LineSubstring(geom, 0, 0.5)                                           as geom
  , nextval('waterid')                                                       as id
  , ST_Buffer(ST_LineInterpolatePoint(ST_LineSubstring(geom, 0, 0.5),0.5),2) as midgeom
FROM
    tmp.peilgrenzen2
WHERE
    ST_IsClosed(geom)
UNION ALL --UNION ALL is faster than UNION, no risk on duplicate entries here
SELECT
    ST_LineSubstring(geom, 0.5, 1)                                           as geom
  , nextval('waterid')                                                       as id
  , ST_Buffer(ST_LineInterpolatePoint(ST_LineSubstring(geom, 0.5, 1),0.5),2) as midgeom
FROM
    tmp.peilgrenzen2
WHERE
    ST_IsClosed(geom)
UNION ALL --UNION ALL is faster than UNION, no risk on duplicate entries here
SELECT
    geom
  , nextval('waterid')                             as id
  , ST_Buffer(ST_LineInterpolatePoint(geom,0.5),2) as midgeom
FROM
    tmp.peilgrenzen2
WHERE
    NOT ST_IsClosed(geom)
;

CREATE INDEX tmp_peilgrenzen
ON
    tmp.peilgrenzen
USING gist
    (
        geom
    )
;

CREATE INDEX tmp_peilgrenzen_midgeom
ON
    tmp.peilgrenzen
USING gist
    (
        midgeom
    )
;

-- eerst MakeValid om self-intersect te voorkomen. Enkele polygonen hebben te weinig punten om een ruimte te spannen, dus pas ST_CollectionExtract toe
DROP TABLE IF EXISTS tmp.fdla_valid
;

CREATE TABLE tmp.fdla_valid AS
SELECT *
  , ST_CollectionExtract(ST_MakeValid(geom),3) as valid_geom
FROM
    checks.fixeddrainagelevelarea
    --LIMIT 1
;

CREATE INDEX tmp_fdla_valid
ON
    tmp.fdla_valid
USING gist
    (
        valid_geom
    )
;

-- koppel hoogste peil aan elke peilgrens ()
DROP TABLE IF EXISTS tmp.levee
;

CREATE TABLE tmp.levee AS
SELECT
    a.geom
  , a.id                 as levee_ring_id
  , max(streefpeil_bwn2) as maximum_water_level
FROM
    tmp.peilgrenzen as a
  , tmp.fdla_valid  as b
WHERE
    ST_Intersects(a.midgeom,valid_geom)
GROUP BY
    a.geom
  , a.id
;

CREATE INDEX tmp_levee_geom
ON
    tmp.levee
USING gist
    (
        geom
    )
;

-- negatieve buffer van polderclusters
DROP TABLE IF EXISTS tmp.polder_inside
;

CREATE TABLE tmp.polder_inside AS
SELECT
    ST_Buffer(b.geom,-2) as geom
FROM
    checks.polder as b
;

CREATE INDEX tmp_poldercluster_inside
ON
    tmp.polder_inside
USING gist
    (
        geom
    )
;

DROP SEQUENCE IF EXISTS waterid;
CREATE SEQUENCE waterid;
-- verwijderen buitenste ring, hier geen levee of verfijning
DROP TABLE IF EXISTS checks.peilgrens_met_waterpeil
;

CREATE TABLE checks.peilgrens_met_waterpeil AS
SELECT
    (ST_Dump(ST_Intersection(a.geom,b.geom))).geom as geom
  , levee_ring_id
  , maximum_water_level
  , nextval('waterid') as levee_id
FROM
    tmp.levee         as a
  , tmp.polder_inside as b
WHERE
    ST_Intersects(a.geom,b.geom)
;

CREATE INDEX checks_peilgrens_met_waterpeil
ON
    checks.peilgrens_met_waterpeil
USING gist
    (
        geom
    )
;

--Split levees to vertex_to_vertex lines because the line-up tool needs straight lines
DROP SEQUENCE IF EXISTS waterid;
CREATE SEQUENCE waterid;
DROP TABLE IF EXISTS tmp.levee_split
;

CREATE TABLE tmp.levee_split AS
    (
        WITH dump_points AS
            (
                SELECT
                    (ST_DumpPoints(geom)).path[1]
                  , (ST_DumpPoints(geom)).geom
                  , levee_ring_id
                  , maximum_water_level
                  , levee_id
                FROM
                    checks.peilgrens_met_waterpeil
            )
        SELECT
            nextval('waterid')         as id
          , a.levee_ring_id            as ring_id
          , a.maximum_water_level      as max_wl
          , a.levee_id                 as code
          , ST_MakeLine(a.geom,b.geom) as geom
        FROM
            dump_points a
          , dump_points b
        WHERE
            a.path              = b.path+1
            AND a.levee_ring_id = b.levee_ring_id
            AND a.levee_id      = b.levee_id
    )
;

-- Opknippen levee-segmenten
DELETE
FROM
    tmp.levee_split
WHERE
    ST_Length(geom) < 2
;

DELETE
FROM
    tmp.levee_split
WHERE
    geom IS NULL
;