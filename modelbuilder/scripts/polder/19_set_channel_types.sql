--$$$$$$$$$$$$$$$$$$$$$$$$$$$$
-- KANAAL TYPES
-- In dit script worden het rekentype en rekenafstand van watergangen ingevuld. Tevens wordt de zoom category ingevuld.
-- $$$$$$$$$$$$$$$$$$$$$$$$$$$
/* Methode selectie connected/isolated/embedded en grid refinement voor landelijk vlak volgens:
0. LEVEE's overal minimaal 80m rekencellen
1. Verfijn de rekencellen tot 40m als er alleen een levee in de rekencel ligt
2. Verfijn de rekencellen maximaal zolang er een watergang en een levee in liggen
3. alle watergangen worden embedded tenzij:
A. Alle primaire afvoerwatergangen maken we connected
B. Alle watergangen in een rekencel waar ook een levee door loopt worden connected, de levee's zijn gebaseerd op de vereenvoudigde peilgebieden
C. Alle watergangen in een opgeheven peilgebied worden isolated
D. watergangen deels buiten model worden isolated
E. Watergangen met randvoorwaarden worden isolated
*/
-- selecteer primaire afvoerwatergangen
DROP TABLE IF EXISTS tmp.channel_type_linemerge
;

CREATE TABLE tmp.channel_type_linemerge AS
SELECT
         (ST_dump( ST_Buffer( ST_UNION( a.geom ) ,0.1) )).geom as bufgeom
       , b.polder_id
FROM
         deelgebied.channel as a
       , deelgebied.polder  as b
WHERE
         channel_type_id = 1
         AND ST_Intersects(a.geom,b.geom)
GROUP BY
         b.polder_id
;

CREATE INDEX tmp_channel_type_linemerge_bufgeom
ON
             tmp.channel_type_linemerge
USING        gist
             (
                          bufgeom
             )
;

DROP TABLE IF EXISTS tmp.channel_afvoer
;

CREATE TABLE tmp.channel_afvoer AS
SELECT DISTINCT
                                     a.polder_id
     , ST_Simplify(a.bufgeom,0.1) as bufgeom
FROM
       tmp.channel_type_linemerge   as a
     , deelgebied.afvoerkunstwerken as b
WHERE
       ST_Intersects(a.bufgeom,b.geom)
;

CREATE INDEX tmp_channel_afvoer_bufgeom
ON
             tmp.channel_afvoer
USING        gist
             (
                          bufgeom
             )
;

-- channel type             zoom_category
-- embedded (100)           2
-- isolated (101)           3
-- connected (102)          3
-- primaire afvoer kanalen  5
-- Alle watergangen worden embedded en zoom_category =2, tenzij:
-- UPDATE v2_channel
-- SET calculation_type = 100, doen we niet meer;
-- Alle watergangen worden connected , tenzij:
UPDATE
       v2_channel
SET    calculation_type = 102--, zoom_category = 3
;                            -- HIER EVENTUEEL EMBEDDED ZETTEN
-- A. Alle (primaire) afvoerwatergangen maken we connected
UPDATE
       v2_channel as a
SET    calculation_type = 102--,
        --zoom_category = 5
FROM
       tmp.channel_afvoer as b
WHERE
       ST_Contains(b.bufgeom,a.the_geom)
;

-- B. Alle watergangen in een rekencel waar ook een levee door loopt worden connected, de levee's zijn gebaseerd op de vereenvoudigde peilgebieden
UPDATE
       v2_channel as a
SET    calculation_type = 102
FROM
       deelgebied.grid as b
WHERE
       ST_Intersects(a.the_geom,b.geom)
       AND b.max_peil IS NOT NULL
       AND b.count              > 0
;

-- C. Alle watergangen in een opgeheven peilgebied worden isolated
--UPDATE v2_channel as a
--SET calculation_type = 101
--FROM tmp.fdla as b
--WHERE ST_Intersects(a.the_geom,b.geom) AND b.id NOT IN (SELECT id FROM deelgebied.fixeddrainagelevelarea_simple)
--;
-- D. watergangen aan de rand van het model worden isolated
UPDATE
       v2_channel as a
SET    calculation_type = 101
FROM
       deelgebied.polder as b
WHERE
       NOT ST_Contains(b.innergeom,a.the_geom)
       AND NOT ST_IsEmpty(innergeom)
;

-- E. Watergangen met randvoorwaarden worden isolated
UPDATE
       v2_channel as a
SET    calculation_type = 101
WHERE
       connection_node_start_id IN
       (
              SELECT
                     connection_node_id as id
              FROM
                     v2_1d_boundary_conditions
       )
       OR connection_node_end_id IN
       (
              SELECT
                     connection_node_id as id
              FROM
                     v2_1d_boundary_conditions
       )
;

-- F. update bank levels bij levees
WITH grid_heigth AS
     (
               SELECT
                         a.id
                       , a.geom
                       , a.max_peil
                       , a.count
                       , MAX(b.height) as height --> levee hoogte in eerder stadium aan grid toevoegen zoadat het sneller wordt
               FROM
                         deelgebied.grid as a
                         LEFT JOIN
                                   deelgebied.levee as b
                                   ON
                                             ST_Intersects(a.geom,b.geom)
               GROUP BY
                         a.id
                       , a.geom
                       , a.max_peil
                       , a.count
     )
   , channels AS
     (
            SELECT
                   a.id
                 , b.height
            FROM
                   v2_channel  as a
                 , grid_heigth as b
            WHERE
                   ST_Intersects(a.the_geom,b.geom)
                   AND b.max_peil IS NOT NULL
                   AND b.count              > 0
     )
UPDATE
       v2_cross_section_location as c
SET    bank_level = d.height
FROM
       channels as d
WHERE
       c.channel_id           = d.id
       AND d.height IS NOT NULL
;

-- set the calculation distance to maximum calculation cell size
WITH link AS
     (
              SELECT
                       a.id
                     , max(b.refinement_level) as max_level
              FROM
                       v2_channel      as a
                     , deelgebied.grid as b
              WHERE
                       ST_Intersects(a.the_geom,b.geom)
              GROUP BY
                       a.id
     )
UPDATE
       v2_channel as a
SET    dist_calc_points = least(20 * b.max_level, 80)
FROM
       link as b
WHERE
       a.id = b.id
;