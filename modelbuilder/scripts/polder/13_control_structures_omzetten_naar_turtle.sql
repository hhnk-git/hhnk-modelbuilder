/*
Alle v2_control_* tabellen worden eerst leeggegooid. Het aangeleverde meetpunt zoekt de dichtstbijzijnde watergang en vervolgens het dichtstbijzijnde uiteinde. Dit zal het effectieve meetpunt voor de aangeleverde sturingsregel worden. Tevens worden de ids van de te sturen kunstwerken gekoppeld aan de hand van de kunstwerk code.
Vervolgens worden de tabellen gevuld.
*/
UPDATE
       v2_global_settings
SET    control_group_id = NULL
;

DELETE
FROM
       v2_control
;

DELETE
FROM
       v2_control_delta
;

DELETE
FROM
       v2_control_group
;

DELETE
FROM
       v2_control_measure_map
;

DELETE
FROM
       v2_control_measure_group
;

DELETE
FROM
       v2_control_memory
;

DELETE
FROM
       v2_control_pid
;

DELETE
FROM
       v2_control_table
;

DELETE
FROM
       v2_control_timed
;

--Find connection_nodes within 1 meter
DROP TABLE IF EXISTS tmp.closest_connection_nodes
;

CREATE TABLE tmp.closest_connection_nodes AS
             (
                      SELECT
                               a.id
                             , b.id as channel_id
                             , a.measurement_location
                             , b.id as connection_node_id
                      FROM
                               deelgebied.control_table a
                             , v2_connection_nodes      b
                      WHERE
                               ST_DWithin(a.measurement_location, b.the_geom,1)
                      ORDER BY
                               a.id
                             , ST_Distance(a.measurement_location, b.the_geom) LIMIT 1 --why only one? TODO
             )
;

--Add connection_node_id to deelgebied.control_table
INSERT INTO tmp.closest_connection_nodes
       (id
            , channel_id
            , measurement_location
            , connection_node_id
       )
       (
            WITH structures AS
                 (
                        SELECT
                               a.code
                             , ST_MakeLine(b.the_geom,c.the_geom) as the_geom
                        FROM
                               v2_weir             a
                             , v2_connection_nodes b
                             , v2_connection_nodes c
                        WHERE
                               a.connection_node_start_id   = b.id
                               AND a.connection_node_end_id = c.id
                        UNION
                        SELECT
                               a.code
                             , ST_MakeLine(b.the_geom,c.the_geom) as the_geom
                        FROM
                               v2_culvert          a
                             , v2_connection_nodes b
                             , v2_connection_nodes c
                        WHERE
                               a.connection_node_start_id   = b.id
                               AND a.connection_node_end_id = c.id
                        UNION
                        SELECT
                               a.code
                             , ST_MakeLine(b.the_geom,c.the_geom) as the_geom
                        FROM
                               v2_orifice          a
                             , v2_connection_nodes b
                             , v2_connection_nodes c
                        WHERE
                               a.connection_node_start_id   = b.id
                               AND a.connection_node_end_id = c.id
                 )
            SELECT  DISTINCT
            ON
                     (
                              a.id
                     )
                     a.id
                   , b.id as channel_id
                   , a.measurement_location
                   , CASE
                              WHEN ST_Distance(c.the_geom,ST_StartPoint(b.the_geom))       < ST_Distance(c.the_geom,ST_EndPoint(b.the_geom))
                                       AND ST_Distance(c.the_geom,ST_EndPoint(b.the_geom)) < 1000
                                       THEN b.connection_node_end_id
                                       ELSE b.connection_node_start_id
                     END as connection_node_id
            FROM
                     deelgebied.control_table a
                   , v2_channel               b
                   , structures               c
            WHERE
                     ST_DWithin(a.measurement_location, b.the_geom,50) --search radius 50m
                     AND a.structure_code = c.code
                     AND a.id NOT IN
                     (
                            SELECT
                                   id
                            FROM
                                   tmp.closest_connection_nodes
                     )
            ORDER BY
                     a.id
                   , ST_Distance(a.measurement_location, b.the_geom)
       )
;

ALTER TABLE deelgebied.control_table DROP COLUMN IF EXISTS connection_node_id
;

ALTER TABLE deelgebied.control_table ADD COLUMN connection_node_id integer
;

UPDATE
       deelgebied.control_table a
SET    connection_node_id = b.connection_node_id
FROM
       tmp.closest_connection_nodes b
WHERE
       a.id = b.id
;

UPDATE
       deelgebied.control_table a
SET    is_usable = FALSE
WHERE
       connection_node_id IS NULL
;

DROP TABLE IF EXISTS tmp.closest_connection_nodes
;

--Add structure_id to deelgebied.control_table
DROP TABLE IF EXISTS tmp.control_structure_ids
;

CREATE TABLE tmp.control_structure_ids AS
             (
                    SELECT
                           a.id
                         , b.id      as structure_id
                         , 'v2_weir' as structure_type
                    FROM
                           deelgebied.control_table a
                         , v2_weir                  b
                    WHERE
                           a.structure_code = b.code
                    UNION
                    SELECT
                           a.id
                         , b.id             as structure_id
                         , 'v2_pumpstation' as structure_type
                    FROM
                           deelgebied.control_table a
                         , v2_pumpstation           b
                    WHERE
                           a.structure_code = b.code
                    UNION
                    SELECT
                           a.id
                         , b.id         as structure_id
                         , 'v2_orifice' as structure_type
                    FROM
                           deelgebied.control_table a
                         , v2_orifice               b
                    WHERE
                           a.structure_code = b.code
                    UNION
                    SELECT
                           a.id
                         , b.id         as structure_id
                         , 'v2_culvert' as structure_type
                    FROM
                           deelgebied.control_table a
                         , v2_culvert               b
                    WHERE
                           a.structure_code = b.code
             )
;

ALTER TABLE deelgebied.control_table DROP COLUMN IF EXISTS structure_id
;

ALTER TABLE deelgebied.control_table ADD COLUMN structure_id integer
;

UPDATE
       deelgebied.control_table a
SET    structure_id = b.structure_id
FROM
       tmp.control_structure_ids b
WHERE
       a.id = b.id
;

ALTER TABLE deelgebied.control_table DROP COLUMN IF EXISTS structure_type
;

ALTER TABLE deelgebied.control_table ADD COLUMN structure_type text
;

UPDATE
       deelgebied.control_table a
SET    structure_type = b.structure_type
FROM
       tmp.control_structure_ids b
WHERE
       a.id = b.id
;

UPDATE
       deelgebied.control_table
SET    is_usable = (is_usable
       AND connection_node_id IS NOT NULL
       AND structure_id       IS NOT NULL)
;

DROP SEQUENCE
IF EXISTS seq_measure_group_id;
    CREATE SEQUENCE seq_measure_group_id START 1;
    ALTER TABLE deelgebied.control_table DROP COLUMN IF EXISTS measure_group_id
    ;
    
    ALTER TABLE deelgebied.control_table ADD COLUMN measure_group_id integer
    ;
    
    UPDATE
           deelgebied.control_table
    SET    measure_group_id = nextval('seq_measure_group_id')
    WHERE
           is_usable
    ;
    
    --Add measure groups
    INSERT INTO v2_control_measure_group
    SELECT
           measure_group_id
    FROM
           deelgebied.control_table
    WHERE
           is_usable
    ;
    
    --Add measure group mapping
    INSERT INTO v2_control_measure_map
           (id
                , measure_group_id
                , object_type
                , object_id
                , weight
           )
    SELECT
           id
         , measure_group_id
         , 'v2_connection_nodes'
         , connection_node_id
         , 1
    FROM
           deelgebied.control_table
    WHERE
           is_usable
    ;
    
    --Fill general control group (referenced from v2_control and v2_global_settings)
    INSERT INTO v2_control_group
    SELECT
           1
         , 'BWN sturing'
         , 'Sturingsregels zoals opgegeven in de HydrologenDataBase (HDB)'
    WHERE
           (
                  SELECT
                         COUNT(*)>0
                  FROM
                         v2_control_measure_group
           )
    ;
    
    UPDATE
           v2_global_settings
    SET    control_group_id = 1
    WHERE
           (
                  SELECT
                         COUNT(*)>0
                  FROM
                         v2_control_measure_group
           )
    ;
    
    --Insert all controls
    INSERT INTO v2_control
           (id
                , control_id
                , measure_group_id
                , control_group_id
                , control_type
                , start
                , "end"
                , measure_frequency
           )
    SELECT
           id
         , --id
           id
         , --control_id
           measure_group_id
         , --measure_group_id
           1
         , --control_group_id
           'table'
         , --control_type
           NULL
         , --start
           NULL
         ,      --end
           NULL --measure_frequency
    FROM
           deelgebied.control_table
    WHERE
           is_usable
    ;
    
    --Add control tables for weirs
    INSERT INTO v2_control_table
           (id
                , action_table
                , action_type
                , measure_variable
                , measure_operator
                , target_type
                , target_id
           )
    SELECT
           id
         , table_control_string
         , action_type
         , measure_variable
         , measure_operator
         , structure_type
         , structure_id
    FROM
           deelgebied.control_table
    WHERE
           is_usable
    ;