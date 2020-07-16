/*
Tabellen aangemaakt:
checks.polderclusters
-nxt.poldercluster
tmp.fixeddrainagelevelarea_poldercode
-tmp.fixedleveldrainagearea_union
-checks.polderclusters
-hardcoded peilvakcodes
tmp.fdla_collect
-tmp.fixeddrainagelevelarea_poldercode
tmp.polder_interior
-tmp.fdla_collect
checks.polder
-tmp.fdla_collect
-tmp.polder_interior
tmp.afvoergebieden
-nxt.polder
tmp.fixeddrainagelevelarea_afvoergebiedcode
-tmp.fixedleveldrainagearea_union
-tmp.afvoergebieden
-hardcoded peilvakcodes
checks.afvoergebieden
-tmp.fixeddrainagelevelarea_afvoergebiedcode
*/
DROP TABLE IF EXISTS checks.polderclusters
;

CREATE TABLE checks.polderclusters AS
    (
        SELECT
            id
          , polder_id
          , name
          , ''::text as polder_type
          , geom
        FROM
            nxt.polderclusters
    )
;

-- Aanmaken 1 shape van alle peilgebieden binnen polderclusters
DROP TABLE IF EXISTS tmp.fixeddrainagelevelarea_poldercode
;

CREATE TABLE tmp.fixeddrainagelevelarea_poldercode AS
SELECT
    a.code
  , a.geom
  , b.polder_id::numeric as polder_id
  , b.polder_type
  , b.name
FROM
    tmp.fixedleveldrainagearea_union as a
  , checks.polderclusters            as b
WHERE
    ST_Contains(b.geom, a.pointgeom)
    AND b.polder_id IS NOT NULL
    AND
    (
        a.code   <> '1000-01'
        AND code <> '1700-01'
        AND code <> '1800-01'
        AND code <> '03010-01'
        AND code <> '6753-01'
    )
;

CREATE INDEX sm_checks_fixeddrainagelevelarea
ON
    tmp.fixeddrainagelevelarea_poldercode
USING gist
    (
        geom
    )
;

-- maak polderclusters obv peilgebieden
DROP TABLE IF EXISTS tmp.fdla_collect
;

CREATE TABLE tmp.fdla_collect AS
    (
        SELECT
            ST_Collect(geom) as geom
          , polder_id
          , polder_type
          , name
        FROM
            (
                SELECT
                    polder_id::numeric
                  , (ST_Dump(ST_Union(geom))).geom as geom
                  , polder_type
                  , name
                FROM
                    tmp.fixeddrainagelevelarea_poldercode
                GROUP BY
                    polder_id
                  , polder_type
                  , name
            )
            s
        GROUP BY
            polder_id
          , polder_type
          , name
    )
;

DROP TABLE IF EXISTS tmp.polder_interior
;

CREATE TABLE tmp.polder_interior AS
    (
        WITH rings AS
            (
                SELECT
                    polder_id
                  , ST_DumpRings((ST_Dump(geom)).geom) as ring
                FROM
                    tmp.fdla_collect
            )
        SELECT
            polder_id
          , ST_Union((ring).geom) as intrings
        FROM
            rings
        WHERE
            (
                ring
            )
            .path[1]                 > 0
            AND ST_Area((ring).geom) < 250
        GROUP BY
            polder_id
    )
;

DROP TABLE IF EXISTS checks.polder
;

CREATE TABLE checks.polder AS
    (
        SELECT
            ST_Union(a.geom,b.intrings) as geom
          , a.polder_id
          , a.polder_type
          , a.name
        FROM
            tmp.fdla_collect a
            LEFT JOIN
                tmp.polder_interior b
                ON
                    a.polder_id = b.polder_id
        WHERE
            b.intrings IS NOT NULL
        UNION ALL
        SELECT
            a.geom
          , a.polder_id
          , a.polder_type
          , a.name
        FROM
            tmp.fdla_collect a
            LEFT JOIN
                tmp.polder_interior b
                ON
                    a.polder_id = b.polder_id
        WHERE
            b.intrings IS NULL
    )
;

CREATE INDEX checks_polder
ON
    checks.polder
USING gist
    (
        geom
    )
;

DROP TABLE IF EXISTS tmp.afvoergebieden
;

CREATE TABLE tmp.afvoergebieden AS
SELECT
    id
  , code
  , name
  , ST_force2D(ST_Transform(geometry,28992)) as geom
FROM
    nxt.polder
;

CREATE INDEX tmp_afvoergebieden_geom
ON
    tmp.afvoergebieden
USING gist
    (
        geom
    )
;

-- Aanmaken 1 shape van alle peilgebieden binnen polderclusters
DROP TABLE IF EXISTS tmp.fixeddrainagelevelarea_afvoergebiedcode
;

CREATE TABLE tmp.fixeddrainagelevelarea_afvoergebiedcode AS
SELECT
    b.code
  , a.geom
  , b.id::numeric as afvoer_id
  , b.name
FROM
    tmp.fixedleveldrainagearea_union as a
  , tmp.afvoergebieden               as b
WHERE
    ST_Contains(b.geom, a.pointgeom)
    AND b.id IS NOT NULL
    AND
    (
        a.code     <> '1000-01'
        AND a.code <> '1700-01'
        AND a.code <> '1800-01'
        AND a.code <> '03010-01'
        AND a.code <> '6753-01'
    )
;

CREATE INDEX tmp_fixeddrainagelevelarea_afvoergebiedcode
ON
    tmp.fixeddrainagelevelarea_afvoergebiedcode
USING gist
    (
        geom
    )
;

-- maak polderclusters obv peilgebieden
DROP TABLE IF EXISTS checks.afvoergebieden
;

CREATE TABLE checks.afvoergebieden AS
SELECT
    ST_Collect(ST_MakePolygon(geom)) as geom
  , afvoer_id
  , code
  , name
FROM
    (
        SELECT
            afvoer_id::numeric
          , ST_ExteriorRing((ST_Dump(ST_Union(geom))).geom) as geom
          , code
          , name
        FROM
            tmp.fixeddrainagelevelarea_afvoergebiedcode
        GROUP BY
            afvoer_id
          , code
          , name
    )
    s
GROUP BY
    afvoer_id
  , code
  , name
;

--opschonen
DROP TABLE IF EXISTS tmp.fdla_collect
;

DROP TABLE IF EXISTS tmp.polder_interior
;

DROP TABLE IF EXISTS tmp.afvoergebieden
;