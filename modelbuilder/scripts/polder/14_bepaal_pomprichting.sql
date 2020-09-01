/*
Voer uit nadat connection_nodes zijn aangemaakt. Dit script draait alleen de pomprichting om indien de pomprichting (gegeven de aangeleverde data) in tegengestelde richting (van/naar peilgebied) is.
Is er onduidelijkheid over de te koppelen peilgebieden, of de aangeleverde data heeft een ongeldig/meerdere peilgebieden per veld, dan worden deze genegeerd.
*/
DROP TABLE IF EXISTS tmp.pump_conn_node_level
;

CREATE TABLE tmp.pump_conn_node_level AS
             (
                       SELECT
                                 a.id as pumpstation_id
                               , a.connection_node_start_id
                               , a.connection_node_end_id
                               , b.initial_waterlevel as ini_wl_start
                               , c.initial_waterlevel as ini_wl_end
                               , b.initial_waterlevel > c.initial_waterlevel
                                 OR
                                 (
                                           b.initial_waterlevel         IS NULL
                                           AND c.initial_waterlevel IS NOT NULL
                                 )
                                 as reverse_dir
                       FROM
                                 v2_pumpstation a
                                 LEFT JOIN
                                           v2_connection_nodes b
                                           ON
                                                     a.connection_node_start_id = b.id
                                 LEFT JOIN
                                           v2_connection_nodes c
                                           ON
                                                     a.connection_node_end_id = c.id
             )
;

UPDATE
       tmp.pump_conn_node_level
SET    reverse_dir = FALSE
WHERE
       reverse_dir IS NULL
;

UPDATE
       v2_pumpstation
SET    connection_node_start_id = connection_node_end_id
     , connection_node_end_id   = connection_node_start_id
WHERE
       id IN
       (
              SELECT
                     pumpstation_id
              FROM
                     tmp.pump_conn_node_level
              WHERE
                     reverse_dir
       )
;

UPDATE
       v2_pumpstation a
SET    start_level      = least(b.ini_wl_start,b.ini_wl_end)+0.02
     , lower_stop_level = least(b.ini_wl_start,b.ini_wl_end)-0.03
FROM
       (
              SELECT *
              FROM
                     tmp.pump_conn_node_level
       )
       b
WHERE
       a.id = b.pumpstation_id
;