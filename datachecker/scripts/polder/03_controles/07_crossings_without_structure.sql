-- 2.0) We selecteren kruisingen van watergang en peilgrens zonder kunstwerk
DROP TABLE IF EXISTS checks.kruising_zonder_kunstwerk
;

CREATE TABLE checks.kruising_zonder_kunstwerk AS
    (
        WITH correct_crossings AS
            (
                SELECT
                    channel_code::integer
                  , geom::geometry(Point,28992)      as pointgeom
                  , NULL::geometry(Linestring,28992) as linegeom
                FROM
                    checks.pumpstation
                WHERE
                    channel_code IS NOT NULL
                    AND on_fdla_border
                UNION ALL
                SELECT
                    channel_code::integer
                  , geom::geometry(Point,28992)
                  , NULL::geometry(Linestring,28992) as linegeom
                FROM
                    checks.weirs
                WHERE
                    channel_code IS NOT NULL
                    AND on_fdla_border
                UNION ALL
                SELECT
                    channel_code::integer
                  , NULL
                  , geom::geometry(Linestring,28992) as linegeom
                FROM
                    checks.culvert
                WHERE
                    channel_code IS NOT NULL
                    AND on_fdla_border
                    AND on_channel
                UNION ALL
                SELECT
                    channel_code::integer
                  , geom::geometry(Point,28992)
                  , NULL::geometry(Linestring,28992) as linegeom
                FROM
                    checks.fixed_dam
                WHERE
                    channel_code IS NOT NULL
                    AND on_fdla_border
            )
          , all_intersections AS
            (
                SELECT DISTINCT
                ON
                    (
                        ST_Intersection(a.geom,b.geom)
                    )
                    ST_Intersection(a.geom,b.geom) as pointgeom
                  , a.geom                         as channelgeom
                  , b.geom                         as peilgrensgeom
                  , a.id                           as channel_id
                  --, b.levee_ring_id
                  , channel_type_id
                FROM
                    checks.channel_linemerge       as a
                  , tmp.peilgrenzen3 as b 
                WHERE
                    ST_Intersects(a.geom,b.geom)
            )
          , correct_crossing_at_intersection AS
            (
                SELECT
                    a.channel_code
                  , a.pointgeom --Hier een geom toevoegen van de correct_crossing
                FROM
                    correct_crossings a
                  , all_intersections b
                WHERE
                    (
                        ST_DWithin(a.pointgeom, b.pointgeom, 5)
                    )
                    OR
                    (
                        ST_DWithin(a.linegeom, b.pointgeom, 5)
                    )
            )
        SELECT *
        FROM
            all_intersections a
          , (
                SELECT
                    ST_Union(pointgeom) as geom
                FROM
                    correct_crossing_at_intersection
            )
            b
        WHERE
            channel_id NOT IN
            (
                SELECT
                    channel_code --Hier een geom toevoegen van de correct_crossing
                FROM
                    correct_crossing_at_intersection
            )
            AND NOT ST_DWithin(a.pointgeom, b.geom,5)
            -- AND NOT ST_DWithin(all_intersection.geom, correct.geom, 5) aanleiding: KGM-JH-113 geen KZK maar wel unusable pompje
    )
;

CREATE INDEX checks_kruising_zonder_kunstwerk_pointgeom
ON
    checks.kruising_zonder_kunstwerk
USING gist
    (
        pointgeom
    )
;

-- sifons uit deze serie halen
DELETE
FROM
    checks.kruising_zonder_kunstwerk as a
USING checks.culvert                 as b
WHERE
    b.type_art = 2
    AND ST_DWithin(a.pointgeom,b.geom,5)
;

-- We gaan eerst de duikers (type_art =1) selecteren waarvan begin en eind punt in zelfde peilgebied liggen
-- deze duikers uit de 'kruising zonder kunsterk' halen
DELETE
FROM
    checks.kruising_zonder_kunstwerk as a
USING checks.culvert                 as b
WHERE
    b.fixeddrainagelevelarea_id_1 = b.fixeddrainagelevelarea_id_2
    AND b.opmerking     IS NOT NULL
    AND ST_DWithin(a.pointgeom,b.geom,5)
;

-- er zijn 7.916 (vd 48.450) duikers die beginnen en eindigen in hetzelfde peilgebied en wel een opmerking hebben
DROP TABLE IF EXISTS tmp.culvert_fdla_id
;

DROP TABLE IF EXISTS tmp.pumpstation_peilgrens_afstand
;

DROP TABLE IF EXISTS tmp.peilgrenzen
;

DROP TABLE IF EXISTS tmp.poldergrenzen
;