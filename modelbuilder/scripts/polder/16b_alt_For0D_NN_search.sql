DROP FUNCTION IF EXISTS make_ordered_point_grid(geometry,integer);
CREATE OR REPLACE FUNCTION make_ordered_point_grid(geometry, integer)
RETURNS geometry AS
'SELECT ST_Collect(ST_SetSRID(ST_POINT(x, y), ST_SRID($1))) FROM
generate_series(floor(ST_XMIN($1))::int, ceiling(ST_XMAX($1))::int, $2) AS x,
generate_series(floor(ST_YMIN($1))::int, ceiling(ST_YMAX($1))::int, $2) AS y
WHERE st_intersects($1, ST_SetSRID(ST_POINT(x,y), ST_SRID($1)))'
LANGUAGE sql
;

DROP SEQUENCE
IF EXISTS serial;
    CREATE SEQUENCE serial START 1;
	
-- maken punten 10x10 m afstand van elkaar per peilgebied
DROP TABLE IF EXISTS tmp.fdla_ordered_points;
CREATE TABLE tmp.fdla_ordered_points as
SELECT (ST_DUMP(make_ordered_point_grid(a.geom, 10))).geom, 
       a.id, a.code, nextval('serial') as pnt_id 
FROM deelgebied.fixeddrainagelevelarea as a
;

CREATE INDEX tmp_fdla_orderd_points_geom 
	ON tmp.fdla_ordered_points
	USING gist(geom)
    ;

CREATE INDEX tmp_fdla_orderd_points_id
ON tmp.fdla_ordered_points
USING btree(id)
;


-- verwijder punten buiten polder
DELETE FROM tmp.fdla_ordered_points 
WHERE pnt_id NOT IN (
       SELECT pnt_id 
       FROM tmp.fdla_ordered_points as a,
              deelgebied.polder as b 
       WHERE st_intersects(a.geom,b.geom)
       )
;

-- koppel connection nodes aan fdla
DROP TABLE IF EXISTS tmp.v2_connection_nodes_fdla;
CREATE TABLE tmp.v2_connection_nodes_fdla as
SELECT DISTINCT ON (a.id) a.id as con_id, b.code as fdla_code, 
       b.id as fdla_id, a.the_geom, 0.0 as norm
FROM v2_connection_nodes as a, 	
       deelgebied.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.the_geom,b.geom)
;
--afvoernorm instellen
UPDATE tmp.v2_connection_nodes_fdla 
set norm = historische_afvoernorm_mm_d
FROM hdb.polders_v4
WHERE ST_Intersects(the_geom,wkb_geometry)
;

CREATE INDEX tmp_v2_connection_nodes_flda_geom 
ON tmp.v2_connection_nodes_fdla
USING gist(the_geom)
;

CREATE INDEX tmp_v2_connection_nodes_fdla_id
ON tmp.v2_connection_nodes_fdla
USING btree(con_id)
;

        DELETE
        FROM
               tmp.v2_connection_nodes_fdla
        WHERE
               con_id IN
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
               tmp.v2_connection_nodes_fdla
        WHERE
               con_id IN
               (
                      SELECT
                             connection_node_id
                      FROM
                             v2_1d_boundary_conditions
               )
        ;
		
		
		/*
-- join punten aan nodes en bereken afstand, sorteer op dichtsbijzijnde
DROP TABLE IF EXISTS tmp.node_fdlap_link;
CREATE TABLE tmp.node_fdlap_link as 
SELECT n.con_id, n.fdla_code, n.the_geom, ST_Distance(p.geom,n.the_geom) as dist
FROM tmp.v2_connection_nodes_fdla as n,
	tmp.fdla_ordered_points as p 
WHERE p.id = n.fdla_id
	AND ST_DWithin(p.geom,n.the_geom,2000)
ORDER BY ST_Distance(p.geom,n.the_geom) ASC
;
*/

-- dichtsbijzijnde punt zoeken (https://gis.stackexchange.com/questions/401425/postgis-closest-point-to-another-point)
DROP TABLE IF EXISTS tmp.node_fdlap_link;
CREATE TABLE tmp.node_fdlap_link as 
SELECT a.pnt_id, a.id, a.code as fdla_code, 
       b.con_id, b.norm,
       a.geom
FROM   tmp.fdla_ordered_points AS a
CROSS JOIN LATERAL (
  SELECT con_id, norm
  FROM   tmp.v2_connection_nodes_fdla
  WHERE fdla_id = a.id
  ORDER BY
         the_geom <-> a.geom
  LIMIT  1
) AS b
;


CREATE INDEX tmp_node_fdlap_link_geom 
ON tmp.node_fdlap_link
USING gist(geom)
;

DROP TABLE IF EXISTS deelgebied.area_per_node_nn_search
            ;
CREATE TABLE deelgebied.area_per_node_nn_search AS 
SELECT count(pnt_id) * 100 as area, con_id, fdla_code
FROM tmp.node_fdlap_link 
GROUP BY con_id, fdla_code
;


DROP TABLE IF EXISTS deelgebied.impervious_surface_simple;
CREATE TABLE deelgebied.impervious_surface_simple as
SELECT ST_Collect(geom) as geom, fdla_code, con_id, norm
FROM tmp.node_fdlap_link
GROUP BY fdla_code, con_id, norm;

CREATE INDEX deelgebied_impervious_surface_simple_geom 
ON deelgebied.impervious_surface_simple
USING gist(geom)
;

DROP TABLE IF EXISTS deelgebied.impervious_surface_concave;
CREATE TABLE deelgebied.impervious_surface_concave as
SELECT ST_Buffer(ST_ConcaveHull(a.geom,0.1,TRUE),4.5) as geom,
        a.fdla_code, a.con_id, a.norm,
       b.area as node_area,
       ST_Area(ST_Buffer(ST_ConcaveHull(a.geom,0.1,TRUE),4.5))
FROM deelgebied.impervious_surface_simple as a 
LEFT JOIN deelgebied.area_per_node_nn_search as b
ON a.con_id = b.con_id
;


/* ************************
-- vullen impervious surfaces voor 0D1D model
************************/
DELETE
FROM
       v2_impervious_surface
;

INSERT INTO v2_impervious_surface
       ( 	id
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
       con_id
     , fdla_code
     , coalesce(fdla_code, ' on ', con_id::text, ' norm ', norm::text)
     , 'gesloten verharding'
     , NULL
     , 'uitgestrekt'
     , 1
     , 0
     , 0
     , node_area
     , geom
FROM
       deelgebied.impervious_surface_concave
WHERE node_area > 0
;

DELETE
FROM
       v2_impervious_surface_map
;

INSERT INTO v2_impervious_surface_map
       ( 		id
            , impervious_surface_id
            , connection_node_id
            , percentage
       )
SELECT
       con_id
     , con_id
     , con_id
     , norm
FROM
       deelgebied.impervious_surface_concave
;