/*
Om de instroomoppervlak in het 0D1D model zo goed mogelijk te bepalen worden per peilgebied alle daarbinnen liggende connection_nodes gebruikt om een voronoi-diagram te maken. Dit diagram wordt vervolgens uitgeknipt op de geometrie van het betreffende peilgebied. Hierdoor wordt het aantal vierkante meters instroomoppervlak per connection_node bepaald.
Wordt uitgevoerd in schema: tmp
De invoer is als volgt:
-Tabel met punten
-Tabel met peilgebieden, bevat per peilgebied een unieke identifier
Deels ontworpen adhv de volgende stackexchange thread: http://gis.stackexchange.com/questions/114764/how-to-use-st-delaunaytriangles-to-construct-a-voronoi-diagram
Kopieer relevante data van peilgebied tabel. Moet minimaal bevatten:
-id
-geom
Indicatie van duur van deze stap: 5 - 15 minuten
*/
--Cleanup geometries
UPDATE
       deelgebied.fixeddrainagelevelarea
SET    geom = ST_CollectionExtract(ST_MakeValid(geom),3)
;

DROP SEQUENCE
IF EXISTS serial;
    CREATE SEQUENCE serial START 1;
    DROP TABLE IF EXISTS tmp.voronoi_peilgebieden
    ;
    
    CREATE TABLE tmp.voronoi_peilgebieden AS
                 (
                        SELECT
                               id                                                                                       as area_id
                             , (ST_Dump(ST_MakeValid(ST_Intersection(ST_MakeValid(a.geom),ST_MakeValid(b.geom))))).geom as area_geom
                        FROM
                               deelgebied.fixeddrainagelevelarea a
                             , deelgebied.polder                 b
                        WHERE
                               ST_Intersects(b.geom,a.geom)
                 )
    ;
    
    DROP INDEX
    IF EXISTS tmp.vrn_peilgebied;
        CREATE INDEX vrn_peilgebied
        ON
                     tmp.voronoi_peilgebieden
        USING        gist
                     (
                                  area_geom
                     )
        ;
        
        /*
        Voeg imaginaire punten toe op verre afstand om convexe shapes te voorkomen
        Maak een bounding box van peilgebieden, buffer hier 50 kilometer omheen, opnieuw bounding box en gebruik nu de hoekpunten
        */
        DROP TABLE IF EXISTS tmp.voronoi_imaginaire_punten
        ;
        
        CREATE TABLE tmp.voronoi_imaginaire_punten AS
                     (
                          WITH envelope AS
                               (
                                      SELECT
                                             ST_Envelope(ST_UNION(ST_MakeValid(area_geom))) as env_geom
                                           , --bounding box om deelgebied
                                             ST_Scale(ST_Envelope(ST_UNION(ST_MakeValid(area_geom))),5,5) as env_geom_scale
                                           , --schaal bounding box 5x
                                             ST_Centroid(ST_Envelope(ST_UNION(ST_MakeValid(area_geom)))) as env_geom_centroid
                                           ,                                                                                                      --middelpunt bounding box (voor translate operatie)
                                             ST_Centroid(ST_Scale(ST_Envelope(ST_UNION(ST_MakeValid(area_geom))),5,5)) as env_geom_scale_centroid -- middelpunt geschaalede boundingbox (voor translate operatie)
                                      FROM
                                             tmp.voronoi_peilgebieden
                               )
                          SELECT DISTINCT
                                 ((ST_DumpPoints(ST_Translate(env_geom_scale,ST_X(env_geom_centroid)-ST_X(env_geom_scale_centroid),ST_Y(env_geom_centroid)-ST_Y(env_geom_scale_centroid)))).geom) as img_point
                          FROM
                                 envelope
                     )
        ;
        
        /*
        Kopieer relevante data van puntdata tabel, moet minimaal bevatten:
        -id
        -geom
        */
        DROP TABLE IF EXISTS tmp.voronoi_puntdata
        ;
        
        CREATE TABLE tmp.voronoi_puntdata AS
                     (
                               SELECT
                                         a.id       as point_id
                                       , b.area_id  as area_id
                                       , a.the_geom as point_geom
                               FROM
                                         public.v2_connection_nodes a --inputtabel
                                         LEFT JOIN
                                                   tmp.voronoi_peilgebieden b
                                                   ON
                                                             ST_Contains(b.area_geom,a.the_geom)
                     )
        ;
        
        /*
        Er mag geen voronoi op nodes die alleen aan een pomp zitten
        */
        DELETE
        FROM
               tmp.voronoi_puntdata
        WHERE
               point_id IN
               (
                      SELECT
                             id
                      FROM
                             v2_connection_nodes
                      WHERE
                             (
                                    id NOT IN
                                    (
                                           select
                                                  connection_node_end_id
                                           from
                                                  v2_culvert
                                           WHERE
                                                  connection_node_end_id is not NULL
                                    )
                                    AND id NOT IN
                                    (
                                           select
                                                  connection_node_start_id
                                           from
                                                  v2_culvert
                                           WHERE
                                                  connection_node_start_id is not NULL
                                    )
                                    AND id NOT IN
                                    (
                                           select
                                                  connection_node_end_id
                                           from
                                                  v2_channel
                                           WHERE
                                                  connection_node_end_id is not NULL
                                    )
                                    AND id NOT IN
                                    (
                                           select
                                                  connection_node_start_id
                                           from
                                                  v2_channel
                                           WHERE
                                                  connection_node_start_id is not NULL
                                    )
                                    AND id NOT IN
                                    (
                                           select
                                                  connection_node_start_id
                                           from
                                                  v2_pipe
                                           WHERE
                                                  connection_node_start_id is not NULL
                                    )
                                    AND id NOT IN
                                    (
                                           select
                                                  connection_node_end_id
                                           from
                                                  v2_pipe
                                           WHERE
                                                  connection_node_end_id is not NULL
                                    )
                                    AND id NOT IN
                                    (
                                           select
                                                  connection_node_start_id
                                           from
                                                  v2_weir
                                           WHERE
                                                  connection_node_start_id is not NULL
                                    )
                                    AND id NOT IN
                                    (
                                           select
                                                  connection_node_end_id
                                           from
                                                  v2_weir
                                           WHERE
                                                  connection_node_end_id is not NULL
                                    )
                                    AND id NOT IN
                                    (
                                           select
                                                  connection_node_start_id
                                           from
                                                  v2_orifice
                                           WHERE
                                                  connection_node_start_id is not NULL
                                    )
                                    AND id NOT IN
                                    (
                                           select
                                                  connection_node_end_id
                                           from
                                                  v2_orifice
                                           WHERE
                                                  connection_node_end_id is not NULL
                                    )
                             )
               )
        ;
        
        /*
        Er mag geen voronoi op nodes die een randvoorwaarde vormen
        */
        DELETE
        FROM
               tmp.voronoi_puntdata
        WHERE
               point_id IN
               (
                      SELECT
                             connection_node_id
                      FROM
                             v2_1d_boundary_conditions
               )
        ;
        
        /*
        Groepeer punten per peilgebied in een MultiPoint
        */
        DROP TABLE IF EXISTS tmp.voronoi_input
        ;
        
        CREATE TABLE tmp.voronoi_input AS
                     (
                              SELECT
                                       area_id
                                     , ST_COLLECTIONEXTRACT(ST_COLLECT( ST_UNION(point_geom), (
                                              SELECT
                                                     ST_UNION(img_point)
                                              FROM
                                                     tmp.voronoi_imaginaire_punten
                                       )
                                       ),1) point_geom
                              FROM
                                       (
                                              SELECT
                                                     a.point_geom
                                                   , b.*
                                              FROM
                                                     tmp.voronoi_puntdata     as a
                                                   , tmp.voronoi_peilgebieden as b
                                              WHERE
                                                     ST_Contains(b.area_geom,a.point_geom)
                                       )
                                       a
                              GROUP BY
                                       area_id
                     )
        ;
        
        /*
        Gebruik DelaunayTriangles om edges en centerpoints tussen punten aan te maken
        */
        DROP TABLE IF EXISTS tmp.voronoi_edges
        ;
        
        CREATE TABLE tmp.voronoi_edges AS
                     (
                            SELECT
                                   area_id
                                 , id
                                 , UNNEST(ARRAY['e1','e2','e3'])                                                                                                      EdgeName
                                 , UNNEST(ARRAY[ ST_SETSRID(ST_MakeLine(p1,p2),28992) , ST_SETSRID(ST_MakeLine(p2,p3),28992) , ST_SETSRID(ST_MakeLine(p3,p1),28992)]) Edge
                                 , ST_SETSRID(ST_Centroid(ST_ConvexHull(ST_Union(                                                                      -- Done this way due to issues I had with LineToCurve
                                   ST_CurveToLine(REPLACE(ST_AsText(ST_LineMerge(ST_Union(ST_MakeLine(p1,p2),ST_MakeLine(p2,p3)))),'LINE','CIRCULAR')),--,15),
                                   ST_CurveToLine(REPLACE(ST_AsText(ST_LineMerge(ST_Union(ST_MakeLine(p2,p3),ST_MakeLine(p3,p1)))),'LINE','CIRCULAR')) --,15)
                                   ))),28992) ct
                            FROM
                                   (
                                          -- Decompose to points
                                          SELECT
                                                 area_id
                                               , id
                                               , ST_SETSRID(ST_PointN(g,1),28992) p1
                                               , ST_SETSRID(ST_PointN(g,2),28992) p2
                                               , ST_SETSRID(ST_PointN(g,3),28992) p3
                                          FROM
                                                 (
                                                        SELECT
                                                               area_id
                                                             , (gd).Path                  id
                                                             , ST_ExteriorRing((gd).Geom) g -- ID andmake triangle a linestring
                                                        FROM
                                                               (
                                                                      SELECT
                                                                             area_id
                                                                           , (ST_Dump(ST_DelaunayTriangles(point_geom))) gd
                                                                      FROM
                                                                             tmp.voronoi_input
                                                               )
                                                               a
                                                 )
                                                 b
                                   )
                                   c
                     )
        ;
        
        DROP INDEX
        IF EXISTS tmp.vrn_edges;
            CREATE INDEX vrn_edges
            ON
                         tmp.voronoi_edges
            USING        gist
                         (
                                      edge
                         )
            ;
            
            /*
            Per peilgebied, maak convex hulls om de punten
            */
            DROP TABLE IF EXISTS tmp.voronoi_convex
            ;
            
            CREATE TABLE tmp.voronoi_convex AS
                         (
                                  SELECT
                                           area_id
                                         , ST_ConvexHull(ST_Collect(point_geom)) as hull
                                  FROM
                                           tmp.voronoi_input
                                  GROUP BY
                                           area_id
                         )
            ;
            
            /*
            Maak voronoi lijnen adhv centerpoints, edges en convex hull. Deze operatie duurt lang
            */
            DROP TABLE IF EXISTS tmp.voronoi_inner_lines
            ;
            
            CREATE TABLE tmp.voronoi_inner_lines AS
                         (
                                         SELECT -- Create voronoi edges and reduce to a multilinestring
                                                         x.area_id
                                                       , ST_LineMerge(ST_Union(ST_MakeLine( x.ct, CASE
                                                                         WHEN ST_IsEmpty(y.ct)
                                                                                         THEN
                                                                                         CASE
                                                                                                         WHEN ST_Within( x.ct, (
                                                                                                                                SELECT
                                                                                                                                       hull
                                                                                                                                FROM
                                                                                                                                       tmp.voronoi_convex
                                                                                                                                WHERE
                                                                                                                                       area_id=x.area_id
                                                                                                                         )
                                                                                                                         )
                                                                                                                         THEN -- Don't draw lines back towards the original set
                                                                                                                         -- Project line out twice the distance from convex hull
                                                                                                                         ST_MakePoint(ST_X(x.ct) + ((ST_X(ST_Centroid(x.edge)) - ST_X(x.ct)) * 2),ST_Y(x.ct) + ((ST_Y(ST_Centroid(x.edge)) - ST_Y(x.ct)) * 2))
                                                                                         END
                                                                                         ELSE y.ct --ST_SETSRID(y.ct,28992)
                                                         END ))) v
                                         FROM
                                                         tmp.voronoi_edges x
                                                         LEFT OUTER JOIN -- Self Join based on edges
                                                                         tmp.voronoi_edges y
                                                                         ON
                                                                                         x.id <> y.id
                                                                                         AND ST_Equals(x.edge,y.edge)
                                         GROUP BY
                                                         x.area_id
                         )
            ;
            
            /*
            Zet voronoi lijnen om in outlines
            */
            DROP TABLE IF EXISTS tmp.voronoi_lines
            ;
            
            CREATE TABLE tmp.voronoi_lines AS
                         (
                                SELECT
                                       area_id
                                     , ST_Node(ST_LineMerge(ST_Union(v, ST_ExteriorRing(ST_ConvexHull(ST_SETSRID(v,28992)))))) as voronoi_outline
                                FROM
                                       tmp.voronoi_inner_lines
                                WHERE
                                       ST_GeometryType(ST_ConvexHull(v)) = 'ST_Polygon'
                         )
            ;
            
            /*
            Zet voronoi outline om in polygonen
            */
            DROP TABLE IF EXISTS tmp.voronoi_polygon
            ;
            
            CREATE TABLE tmp.voronoi_polygon AS
                         (
                                  SELECT
                                           area_id
                                         , (ST_DUMP(st_collectionextract(ST_Polygonize(voronoi_outline),3))).geom as voronoi_unclipped
                                  FROM
                                           tmp.voronoi_lines
                                  GROUP BY
                                           area_id
                         )
            ;
            
            /*
            Voeg point_id toe aan de hand van ST_Contains
            */
            DROP SEQUENCE serial;
            CREATE SEQUENCE serial START 1;
            DROP TABLE IF EXISTS tmp.voronoi_unclipped
            ;
            
            CREATE TABLE tmp.voronoi_unclipped AS
                         (
                                   SELECT
                                             nextval('serial') as vrn_id
                                           , b.point_id
                                           , a.area_id
                                           , a.voronoi_unclipped
                                   FROM
                                             tmp.voronoi_polygon a
                                             LEFT JOIN
                                                       tmp.voronoi_puntdata b
                                                       ON
                                                                 a.area_id = b.area_id
                                                                 AND ST_Contains(a.voronoi_unclipped,b.point_geom)
                         )
            ;
            
            /*
            Clip voronoi polygonen op bijbehorend peilgebied, Buffer met 0.0 om geometrie op te schonen
            */
            DROP TABLE IF EXISTS tmp.voronoi_clip
            ;
            
            CREATE TABLE tmp.voronoi_clip AS
                         (
                                   SELECT
                                             vrn_id
                                           , point_id
                                           , a.area_id
                                           , ST_Buffer(ST_Intersection(a.voronoi_unclipped,ST_MakeValid(b.area_geom)),0.0) as vrn_geom
                                   FROM
                                             tmp.voronoi_unclipped a
                                             LEFT JOIN
                                                       tmp.voronoi_peilgebieden b
                                                       ON
                                                                 a.area_id = b.area_id
                                                                 AND ST_IsValid(ST_MakeValid(b.area_geom))
                         )
            ;
            
            /*
            Groupeer per punt
            */
            DROP TABLE IF EXISTS deelgebied.voronoi_output
            ;
            
            CREATE TABLE deelgebied.voronoi_output AS
                         (
                                  SELECT
                                           MIN(vrn_id) as vrn_id
                                         , point_id
                                         , MIN(area_id)                                                                  as area_id
                                         , ST_Union(ST_Buffer(ST_SnapToGrid(vrn_geom,0,0,0.000001,0.000001),0))          as vrn_geom
                                         , ST_AREA(ST_Union(ST_Buffer(ST_SnapToGrid(vrn_geom,0,0,0.000001,0.000001),0)))    vrn_area
                                  FROM
                                           tmp.voronoi_clip
                                  WHERE
                                           NOT ST_IsEmpty(vrn_geom)
                                  GROUP BY
                                           point_id
                         )
            ;
            
            /*
            ============================================
            Volgende queries zijn voor kwaliteits checks
            ============================================
            */
            /*
            Identificeer gebieden waarbij een convex hull geen polygon is (punten spannen geen polygon omdat ze op 1 lijn liggen of het aantal punten <3
            */
            DROP TABLE IF EXISTS tmp.voronoi_invalid_polygon
            ;
            
            CREATE TABLE tmp.voronoi_invalid_polygon AS
                         (
                                SELECT *
                                FROM
                                       tmp.voronoi_inner_lines
                                WHERE
                                       ST_GeometryType(ST_ConvexHull(v)) != 'ST_Polygon'
                         )
            ;
            
            /*
            Peilgebied is geen valid geometry
            */
            DROP TABLE IF EXISTS tmp.voronoi_invalid_peilgebied
            ;
            
            CREATE TABLE tmp.voronoi_invalid_peilgebied AS
                         (
                                SELECT *
                                FROM
                                       tmp.voronoi_peilgebieden
                                WHERE
                                       NOT ST_IsValid(area_geom)
                                       OR area_id IN
                                       (
                                              SELECT DISTINCT
                                                     (area_id)
                                              FROM
                                                     tmp.voronoi_invalid_polygon
                                       )
                         )
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_cover
            ;
            
            CREATE TABLE tmp.voronoi_cover AS
                         (
                              WITH opsomming AS
                                   (
                                            SELECT
                                                     area_id
                                                   , sum(vrn_area) as vrn_sum
                                            FROM
                                                     deelgebied.voronoi_output
                                            GROUP BY
                                                     area_id
                                   )
                              SELECT
                                        a.id
                                      , a.geom
                                      , b.area_id
                                      , ST_AREA(geom) as org_area
                                      , b.vrn_sum     as vrn_sum
                              FROM
                                        deelgebied.fixeddrainagelevelarea a
                                        LEFT JOIN
                                                  opsomming b
                                                  ON
                                                            a.id = b.area_id
                         )
            ;
            
            ALTER TABLE tmp.voronoi_cover ADD COLUMN prec double precision DEFAULT 0
            ;
            
            UPDATE
                   tmp.voronoi_cover
            SET    prec = vrn_sum/org_area
            WHERE
                   org_area              != 0
                   AND vrn_sum  IS NOT NULL
                   AND org_area IS NOT NULL
            ;
            
            /*
            Verwijder hulptabellen
            */
            DROP TABLE IF EXISTS tmp.voronoi_box
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_clip
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_convex
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_cover
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_edges
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_imaginaire_punten
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_inner_lines
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_input
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_invalid_peilgebied
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_invalid_polygon
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_lines
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_peilgebied_zonder_connection_node
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_peilgebieden
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_polygon
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_puntdata
            ;
            
            DROP TABLE IF EXISTS tmp.voronoi_unclipped
            ;
            
            /* ************************
            -- vullen impervious surfaces voor 0D1D model
            ************************/
            DELETE
            FROM
                   v2_impervious_surface
            ;
            
            WITH lijst AS
                 (
                        SELECT
                               point_id as nodeid
                             , area_id  as vlakid
                             , vrn_area as opppernode
                        FROM
                               deelgebied.voronoi_output
                 )
            INSERT INTO v2_impervious_surface
                   ( id
                        , display_name
                        , code
                        , surface_class
                        , surface_sub_class
                        , surface_inclination
                        , zoom_category
                        , nr_of_inhabitants
                        , dry_weather_flow
                        , area
                        , the_geom
                   )
            SELECT DISTINCT
                   nodeid
                 , nodeid
                 , nodeid
                 , 'gesloten verharding'
                 , NULL
                 , 'uitgestrekt'
                 , -1
                 , 0
                 , 0
                 , opppernode
                 , NULL
            FROM
                   lijst
            WHERE
                   nodeid IS NOT NULL
            ;
            
            DELETE
            FROM
                   v2_impervious_surface_map
            ;
            
            INSERT INTO v2_impervious_surface_map
                   ( id
                        , impervious_surface_id
                        , connection_node_id
                        , percentage
                   )
            SELECT
                   id
                 , id
                 , id
                 , 100
            FROM
                   v2_impervious_surface
            ;