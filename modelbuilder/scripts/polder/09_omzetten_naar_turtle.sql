--inladen naar turtle

-- leeg turtle
DELETE FROM v2_culvert;
DELETE FROM v2_manhole;
DELETE FROM v2_orifice;
DELETE FROM v2_1d_lateral;
DELETE FROM v2_cross_section_location; 
DELETE FROM v2_weir;
DELETE FROM v2_pumpstation;
DELETE FROM v2_channel;
DELETE FROM v2_impervious_surface_map;
DELETE FROM v2_connection_nodes; 
DELETE FROM v2_cross_section_definition;
DELETE FROM v2_1d_boundary_conditions;
DELETE FROM v2_connection_nodes;
DELETE FROM v2_global_settings;
DELETE FROM v2_numerical_settings;
DELETE FROM v2_levee;
DELETE FROM v2_grid_refinement;

-- CONNECTION NODES
INSERT INTO v2_connection_nodes(id, storage_area,initial_waterlevel, the_geom, code)
SELECT id, NULL, NULL, the_geom as the_geom, id
FROM deelgebied.tmp_connection_nodes_structures
WHERE the_geom IS NOT NULL
;

-- CHANNEL
INSERT INTO v2_channel(id, display_name, code, calculation_type, dist_calc_points, zoom_category, 
       the_geom, connection_node_start_id, connection_node_end_id)
SELECT reach_id as id, reach_code, reach_code, 101
	, 40, 2, geom, connection_node_start_id, connection_node_end_id
FROM deelgebied.tmp_sel_branches_without_structures
;

--Check if middle of channel is in primary or secundary linemerge.
DROP TABLE IF EXISTS tmp.v2_channel_type;
CREATE TABLE tmp.v2_channel_type AS(
SELECT a.id as v2_channel_id, b.channel_type_id, ST_LineInterpolatePoint(a.the_geom, 0.5) as centerpoint, b.bufgeom
FROM v2_channel a, deelgebied.channel b
WHERE ST_Within(ST_LineInterpolatePoint(a.the_geom, 0.5),b.bufgeom));

UPDATE v2_channel SET zoom_category = 4 WHERE id IN (SELECT v2_channel_id FROM tmp.v2_channel_type WHERE channel_type_id = 1);
UPDATE v2_channel SET zoom_category = 3 WHERE id IN (SELECT v2_channel_id FROM tmp.v2_channel_type WHERE channel_type_id = 2);
UPDATE v2_channel SET zoom_category = 2 WHERE id IN (SELECT v2_channel_id FROM tmp.v2_channel_type WHERE channel_type_id = 3);

-- CROSS SECTION DEFINITIONS
--SELECT * FROM deelgebied.tmp_v2_cross_section_definition WHERE width IS NULL
--SELECT * FROM deelgebied.tmp_v2_cross_section_definition WHERE height IS NULL ORDER BY shape

INSERT INTO v2_cross_section_definition(id,shape,width,height,code)
SELECT id,shape,width,height, (code || '-' || id) as code 
FROM deelgebied.tmp_v2_cross_section_definition
;
--SELECT * FROM v2_cross_section_definition WHERE id = 3271
--SELECT * FROM deelgebied.tmp_v2_cross_section_definition WHERE id = 3271
--SELECT * FROM deelgebied.tmp_v2_cross_section_location WHERE definition_id = 3271


-- CROSS SECTION LOCATIONS
-- sommige crs liggen op het einde van een kanaal en dat mag eigenlijk niet
UPDATE deelgebied.tmp_v2_cross_section_location as a
SET the_geom = ST_LineInterpolatePoint(c.the_geom,0.5)
FROM v2_channel as c, v2_connection_nodes as b
WHERE c.id = a.channel_id AND ST_DWithin(a.the_geom,b.the_geom,0.05)
;

-- INSERT
INSERT INTO v2_cross_section_location(id, channel_id, definition_id,reference_level,friction_type,friction_value,bank_level,the_geom,code)
SELECT id, channel_id, definition_id, reference_level, friction_type, friction_value, bank_level, the_geom, code 
FROM deelgebied.tmp_v2_cross_section_location 
;

-- WEIRS
INSERT INTO v2_weir(
            id, display_name, code, crest_level, crest_type, cross_section_definition_id, 
            connection_node_start_id,connection_node_end_id,
            sewerage, discharge_coefficient_positive, discharge_coefficient_negative,friction_type , friction_value)
SELECT DISTINCT ON (a.id) a.id, b.name as display_name, a.code, b.crest_level, 4 as crest_type, c.id as cross_section_definition_id, 
            a.connection_node_start_id, a.connection_node_end_id, FALSE as sewerage, 0.8, 0.8, 2 , 0.003
FROM deelgebied.tmp_sel_weirs as a
LEFT JOIN deelgebied.weirs as b
ON a.code = b.code
LEFT JOIN deelgebied.tmp_v2_cross_section_definition as c
ON a.code = c.code
;
UPDATE v2_weir
SET discharge_coefficient_positive = 0.8,
	discharge_coefficient_negative = 0.8,
	external = FALSE,
	zoom_category = 4,
	friction_value = 0.03,
	friction_type = 2
;

-- PUMPSTATION

INSERT INTO v2_pumpstation(
            id, display_name, code, sewerage, start_level, 
            lower_stop_level, capacity, zoom_category, 
            connection_node_start_id, connection_node_end_id, type)
SELECT DISTINCT ON (a.id) a.id, b.name, b.code, FALSE, b.start_level, 
	b.start_level - 0.05 as stop_level, b.capacity*1000/60, 4, 
	a.connection_node_start_id, a.connection_node_end_id, 1
FROM deelgebied.tmp_sel_pumpstation as a
LEFT JOIN deelgebied.pumpstation as b 
ON a.code = b.code
; 

--Voeg culvert/pumpstation combinaties toe als pumpstation
INSERT INTO v2_pumpstation(
            id, display_name, code, sewerage, start_level, 
            lower_stop_level, capacity, zoom_category, 
            connection_node_start_id, connection_node_end_id, type)
SELECT DISTINCT ON (a.id) a.id+10000, b.name, b.code, FALSE, b.start_level, 
	b.start_level - 0.05 as stop_level, b.capacity*1000/60, 4, 
	a.connection_node_start_id, a.connection_node_end_id,1
FROM deelgebied.tmp_sel_culvert a
INNER JOIN deelgebied.culvert_to_pumpstation b
ON a.code LIKE b.culvert_code
; 

/*
--  tijdelijke oplossing voor misfit duiker purmer noord
INSERT INTO v2_pumpstation(
            display_name, code, sewerage, start_level, 
            lower_stop_level, capacity, zoom_category, 
            connection_node_start_id, connection_node_end_id)
SELECT  b.name, b.code, FALSE, b.start_level,
	b.start_level - 0.05 as stop_level, b.capacity*1000/60,4,
	4324 as start_id, NULL as connection_node_end_id
FROM deelgebied.culvert_to_pumpstation as b
WHERE b.code = 'KGM-Q-20376'
; 

*/

--DELETE culverts with invalid geometry and save it as a new feedback table.
DROP TABLE IF EXISTS feedback.culvert_with_invalid_geometry;
CREATE TABLE feedback.culvert_with_invalid_geometry AS(
	SELECT id, code, ST_MakeValid(geom) as the_geom, concat('invalid geometry of culvert ',code) as remark FROM deelgebied.tmp_sel_culvert WHERE NOT ST_IsValid(geom)
);

DELETE FROM deelgebied.tmp_sel_culvert WHERE NOT ST_IsValid(geom);

--  CULVERTS
INSERT INTO v2_culvert(
            id, display_name, code, calculation_type, friction_value, friction_type, 
            dist_calc_points, zoom_category, cross_section_definition_id, 
            discharge_coefficient_positive, discharge_coefficient_negative, 
            invert_level_start_point, invert_level_end_point, the_geom, connection_node_start_id, 
            connection_node_end_id)
SELECT DISTINCT ON (a.id) a.id, a.code, b.code, 101, 0.003, 2,
	1000, 3, c.id,
	discharge_coefficient_positive, discharge_coefficient_negative,
	b.bed_level_upstream, b.bed_level_downstream, a.geom, a.connection_node_start_id,
	a.connection_node_end_id
FROM deelgebied.tmp_sel_culvert as a
LEFT JOIN deelgebied.culvert as b
ON a.code = b.code
LEFT JOIN deelgebied.tmp_v2_cross_section_definition as c
ON a.code = c.code
WHERE a.code NOT IN 
	(
	SELECT culvert_code 
	FROM deelgebied.culvert_to_weir 
	
	UNION ALL 
	
	SELECT culvert_code 
	FROM deelgebied.culvert_to_pumpstation
	) --Betreffende culverts worden als weir/pumpstation toegevoegd
--WHERE b.bed_level_upstream IS NULL
;

--Voeg culvert/weir combinaties toe als weir
INSERT INTO v2_weir(
            id, display_name, code, crest_level, crest_type, cross_section_definition_id, 
            connection_node_start_id,connection_node_end_id,
            sewerage, discharge_coefficient_positive, discharge_coefficient_negative,friction_type , friction_value)
SELECT DISTINCT a.id+10000, b.code, b.code, b.crest_level, 4 as crest_type, c.id as cross_section_definition_id, a.connection_node_start_id, a.connection_node_end_id, FALSE as sewerage, 0.8, 0.8, 2, 0.003
FROM deelgebied.tmp_sel_culvert a
INNER JOIN deelgebied.culvert_to_weir b
ON a.code LIKE b.culvert_code
LEFT JOIN deelgebied.tmp_v2_cross_section_definition as c
ON b.code = c.code;

-- LEVEE
--DELETE FROM v2_levee;
INSERT INTO v2_levee(
            id, crest_level, the_geom, code)
SELECT levee_id, height, geom, levee_ring_id  || '-' || levee_id
FROM deelgebied.levee
WHERE ST_GeometryType(geom) = 'ST_LineString'
;


--NUMERICAL SETTINGS
INSERT INTO v2_numerical_settings(
id,
integration_method,
max_nonlin_iterations,
convergence_eps,
max_degree,
use_of_cg,
precon_cg,
use_of_nested_newton,
preissmann_slot,
cfl_strictness_factor_1d,
cfl_strictness_factor_2d,
pump_implicit_ratio,
frict_shallow_water_correction,
limiter_slope_crossectional_area_2d,
limiter_slope_friction_2d,
limiter_grad_2d,
limiter_grad_1d,
flow_direction_threshold,
minimum_friction_velocity,
convergence_cg,
general_numerical_threshold,
minimum_surface_area
)VALUES(
1,				--id
0,				--integration_method
20,				--max_nonlin_iterations
1e-05,			--convergence_eps
7,				--max_degree
20,				--use_of_cg
1,				--precon_cg
1,				--use_of_nested_newton
0,				--preissmann_slot
NULL,			--cfl_strictness_factor_1d
NULL,			--cfl_strictness_factor_2d
1,			--pump_implicit_ratio
0,				--frict_shallow_water_correction
0,				--limiter_slope_crossectional_area_2d
0,				--limiter_slope_friction_2d
1,				--limiter_grad_2d
1			,	--limiter_grad_1d
0.000001,		--flow_direction_threshold
0.05,			--minimum_friction_velocity
0.000000001,	--convergence_cg
0.00000001,		--general_numerical_threshold
0.00000001		--minimum_surface_area
);


-- BRIDGE
INSERT INTO v2_orifice(
            id, display_name, code, max_capacity, crest_level, sewerage, 
            cross_section_definition_id, friction_value, friction_type, discharge_coefficient_positive, 
            discharge_coefficient_negative, zoom_category, crest_type, connection_node_start_id, 
            connection_node_end_id)
SELECT DISTINCT ON (a.id) a.id, a.code, a.code, NULL, b.bed_level, FALSE, 
	c.id, 0.003, 2, 1,
	1, 4, 4, a.connection_node_start_id,
	a.connection_node_end_id
FROM deelgebied.tmp_sel_bridge as a
LEFT JOIN deelgebied.bridge as b
ON a.code = b.code
LEFT JOIN deelgebied.tmp_v2_cross_section_definition as c
ON a.code = c.code
;


DROP TABLE IF EXISTS tmp.connection_node_min_reference_level;
CREATE TABLE tmp.connection_node_min_reference_level AS(
WITH channel_xsloc_join AS(
	SELECT a.id as channel_id, connection_node_start_id, connection_node_end_id, b.id as xs_loc_id, b.reference_level, ST_LineLocatePoint(a.the_geom, b.the_geom) as position_on_channel FROM v2_channel a, v2_cross_section_location b
	WHERE a.id = b.channel_id)
, ascending_position AS(
	SELECT channel_id, xs_loc_id, connection_node_start_id as connection_node_id, reference_level FROM channel_xsloc_join
	ORDER BY channel_id, position_on_channel ASC)
, descending_position AS(
	SELECT channel_id, xs_loc_id, connection_node_end_id as connection_node_id, reference_level FROM channel_xsloc_join
	ORDER BY channel_id, position_on_channel DESC)
, connection_nodes_channel_reference_level AS(
	SELECT DISTINCT ON(channel_id) channel_id, connection_node_id, xs_loc_id, reference_level
	FROM ascending_position
	UNION 
	SELECT DISTINCT ON(channel_id) channel_id, connection_node_id, xs_loc_id, reference_level
	FROM descending_position)
	SELECT connection_node_id, min(reference_level) as min_reference_level FROM connection_nodes_channel_reference_level GROUP BY connection_node_id ORDER BY connection_node_id
);

DROP TABLE IF EXISTS tmp.bridge_crest_level;
CREATE TABLE tmp.bridge_crest_level AS(
SELECT a.*, LEAST(b.min_reference_level, c.min_reference_level) as lowest_bed_level FROM v2_orifice a, tmp.connection_node_min_reference_level b, tmp.connection_node_min_reference_level c 
WHERE a.code LIKE 'KBR%'
AND a.connection_node_start_id = b.connection_node_id
AND a.connection_node_end_id = c.connection_node_id
);

UPDATE v2_orifice a SET crest_level = b.lowest_bed_level+0.01 FROM tmp.bridge_crest_level b
WHERE a.code = b.code;

--Determine new height of bridge opening
DROP TABLE IF EXISTS tmp.updated_bridge_xs_definition;
CREATE TABLE tmp.updated_bridge_xs_definition AS(
SELECT a.id, a.crest_level, a.code, a.cross_section_definition_id, b.bottom_level, c.height, greatest(1,b.bottom_level-a.crest_level) as new_height FROM v2_orifice a, deelgebied.bridge b, v2_cross_section_definition c
WHERE a.code LIKE b.code
AND a.cross_section_definition_id = c.id);

UPDATE v2_cross_section_definition a SET height = (0 || ' ' || b.new_height::varchar || ' ' || b.new_height::varchar)
FROM tmp.updated_bridge_xs_definition b
WHERE a.id = b.cross_section_definition_id;

-- INITIAL WATERLEVEL
UPDATE v2_connection_nodes a SET initial_waterlevel = streefpeil_bwn2
FROM deelgebied.fixeddrainagelevelarea b 
WHERE ST_Intersects(b.geom,a.the_geom)
;

-- vul initial_waterlevel in als leeg als met de waterstand in het kanaal aan andere kant
WITH startlink AS (
	SELECT a.id as startid, b.connection_node_end_id as endid 
	FROM v2_connection_nodes as a, v2_channel as b
	WHERE a.id = b.connection_node_start_id AND a.initial_waterlevel IS NULL)
, wl AS (
	SELECT startid, endid, initial_waterlevel
	FROM startlink as a, v2_connection_nodes as b 
	WHERE a.endid = b.id
	)
UPDATE v2_connection_nodes as a
SET initial_waterlevel = b.initial_waterlevel
FROM wl as b
WHERE a.id = b.startid
;

WITH endlink AS (
	SELECT a.id as endid, b.connection_node_start_id as startid 
	FROM v2_connection_nodes as a, v2_channel as b
	WHERE a.id = b.connection_node_end_id AND a.initial_waterlevel IS NULL)
, wl AS (
	SELECT endid, startid, initial_waterlevel
	FROM endlink as a, v2_connection_nodes as b 
	WHERE a.startid = b.id
	)
UPDATE v2_connection_nodes as a
SET initial_waterlevel = b.initial_waterlevel
FROM wl as b
WHERE a.id = b.endid
;


-- CHECK voor watergangen met verschillend peil aan start en begin
WITH list AS (
	SELECT a.id, a.code, p.streefpeil_bwn2, b.id as start_id, b.initial_waterlevel as startlevel, c.id as end_id, c.initial_waterlevel as endlevel,
		CASE WHEN b.initial_waterlevel = p.streefpeil_bwn2 THEN c.id
			WHEN c.initial_waterlevel = p.streefpeil_bwn2 THEN b.id
		END as changeid
	FROM v2_channel as a
	LEFT JOIN v2_connection_nodes as b
	ON a.connection_node_start_id = b.id
	LEFT JOIN v2_connection_nodes as c
	ON a.connection_node_end_id = c.id
	LEFT JOIN checks.fixeddrainagelevelarea as p
	ON ST_Intersects(ST_LineInterpolatePoint(a.the_geom, 0.5),p.geom)
	WHERE b.initial_waterlevel <> c.initial_waterlevel
	)
UPDATE v2_connection_nodes as a
SET initial_waterlevel = b.streefpeil_bwn2
FROM list as b
WHERE a.id = b.changeid
;


/*
Script om op basis van een vlakkenkaart de impervious_surface en impervious_surface_map te vullen
Wordt overschreven indien 11 Voronoi script wordt gedraaid
*/
/*
DELETE FROM v2_impervious_surface;
WITH lijst AS (
 SELECT a.id as nodeid, b.id as vlakid, ST_Area(b.geom) as opp
 FROM v2_connection_nodes as a, deelgebied.fixeddrainagelevelarea as b
 WHERE ST_Contains(b.geom,a.the_geom)
 ORDER BY b.id
 ), groep AS (
 SELECT vlakid, opp / count(*) as opppernode
 FROM lijst
 GROUP BY vlakid, opp
 )
INSERT INTO v2_impervious_surface(
            id, display_name, code, surface_class, surface_sub_class, surface_inclination, 
            zoom_category, nr_of_inhabitants, dry_weather_flow, function, 
            area, the_geom)
SELECT DISTINCT nodeid, nodeid, nodeid, 'gesloten verharding', NULL, 'uitgestrekt', -1, 0, 0, NULL, opppernode, NULL
FROM lijst as c
LEFT JOIN groep as d
ON c.vlakid = d.vlakid
;

DELETE FROM v2_impervious_surface_map;
INSERT INTO v2_impervious_surface_map(
            id, impervious_surface_id, connection_node_id, percentage)
SELECT id, id, id, 100
FROM v2_impervious_surface
;
*/
