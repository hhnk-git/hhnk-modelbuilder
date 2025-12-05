/* Alle waterlopen connected
*/
UPDATE
       v2_channel
SET    calculation_type = 102
;                           

-- watergangen aan de rand van het model worden isolated
UPDATE
       v2_channel as a
SET    calculation_type = 101
FROM
       deelgebied.polder as b
WHERE
       NOT ST_Contains(b.innergeom,a.the_geom)
       AND NOT ST_IsEmpty(innergeom)
;

-- Watergangen met randvoorwaarden worden isolated
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

-- Overal dezelfde rekenpuntafstand
UPDATE
       v2_channel as a
SET    dist_calc_points = 40;