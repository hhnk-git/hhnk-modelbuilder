/*
Gemalen op de poldergrens krijgen geen connection end node zodat ze als randvoorwaarde fungeren.
*/


-- koppeling tussen gemalen en peil
DROP TABLE IF EXISTS tmp.pumpstation_peil;
CREATE TABLE tmp.pumpstation_peil AS(
	SELECT 
	a.*,
	b.fdla_code as schema_from_fixeddrainagelevelarea_code,
	c.fdla_code as schema_to_fixeddrainagelevelarea_code,
	b.streefpeil_bwn2 as schema_from_peil,
	c.streefpeil_bwn2 as schema_to_peil,
	d.from_fixeddrainagelevelarea_code::text as data_from_fixeddrainagelevelarea_code,
	d.to_fixeddrainagelevelarea_code::text as data_to_fixeddrainagelevelarea_code

	FROM
		v2_pumpstation a

	LEFT JOIN tmp.connection_node_fdla b
	ON a.connection_node_start_id = b.connection_node_id

	LEFT JOIN tmp.connection_node_fdla c
	ON a.connection_node_end_id = c.connection_node_id

	LEFT JOIN deelgebied.pumpstation d
	ON a.code = d.code
);

-- onderstaande gemalen zijn aanvoergemalen volgens de van/naar peilgebied gegevens
DELETE FROM deelgebied.afvoerkunstwerken WHERE code IN (
	SELECT code 
	FROM tmp.pumpstation_peil 
	WHERE schema_from_fixeddrainagelevelarea_code LIKE '%1000-01%' 
		AND (data_to_fixeddrainagelevelarea_code NOT LIKE '%1000-01%' OR data_to_fixeddrainagelevelarea_code IS NULL)
);



-- select channel profile(s) behind an edge-pump and remove them
WITH end_node AS (
	SELECT connection_node_end_id as id
	FROM v2_pumpstation
	WHERE code IN (SELECT code FROM deelgebied.afvoerkunstwerken)
	)
, end_channel AS (
	SELECT a.id, a.code 
	FROM v2_channel as a, end_node as b
	WHERE b.id = a.connection_node_end_id OR b.id = a.connection_node_start_id
	)
DELETE FROM v2_cross_section_location WHERE channel_id IN (SELECT id FROM end_channel)
;

-- select channels behind an edge-pump and remove them
WITH end_node AS (
	SELECT connection_node_end_id as id
	FROM v2_pumpstation
	WHERE code IN (SELECT code FROM deelgebied.afvoerkunstwerken)
	)
, end_channel AS (
	SELECT a.id, a.code 
	FROM v2_channel as a, end_node as b
	WHERE b.id = a.connection_node_end_id OR b.id = a.connection_node_start_id
	)
DELETE FROM v2_channel WHERE id IN (SELECT id FROM end_channel)
;

-- set connection node end id of edge-pumps to NULL so it becomes an edge (if this fails, another structure might be connected to the pump)
WITH no_channel_nodes AS (
   SELECT id FROM v2_connection_nodes WHERE
	(
	--id NOT IN (select connection_node_start_id from v2_pumpstation WHERE connection_node_start_id is not NULL)
	--id NOT IN (select connection_node_end_id from v2_pumpstation WHERE connection_node_end_id is not NULL)
	--AND 
	id NOT IN (select connection_node_end_id from v2_culvert WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_culvert WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_channel WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_channel WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_pipe WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_pipe WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_weir WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_weir WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_orifice WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_orifice WHERE connection_node_end_id is not NULL)
	)
   )

, end_node AS (
	SELECT connection_node_end_id
	FROM v2_pumpstation
	WHERE code IN (SELECT code FROM deelgebied.afvoerkunstwerken)
		AND connection_node_end_id IN (SELECT id FROM no_channel_nodes)
	)
UPDATE v2_pumpstation
SET connection_node_end_id = NULL, zoom_category = 5
WHERE connection_node_end_id IN (SELECT * FROM end_node) 
;

-- unused connection nodes are deleted later

-- which edge-structures must still be adresses

--	SELECT * FROM v2_pumpstation WHERE connection_node_end_id IS NULL



-- SELECT * FROM v2_1d_boundary_conditions
/*
-- For weirs

DELETE FROM v2_1d_boundary_conditions;

-- id serial
DROP sequence if exists boundary;
CREATE SEQUENCE boundary;


-- more dificult because we do not know whether its direction is correct
WITH node_list AS ( -- list of all nodes used in the channels and structures
	SELECT connection_node_start_id as nodes
	FROM v2_channel
	UNION
	SELECT connection_node_end_id
	FROM v2_channel
	UNION
	SELECT connection_node_start_id
	FROM v2_culvert 
	UNION
	SELECT connection_node_end_id
	FROM v2_culvert
	UNION 
	SELECT connection_node_start_id
	FROM v2_weir
	UNION 
	SELECT connection_node_end_id
	FROM v2_weir
	UNION 
	SELECT connection_node_start_id
	FROM v2_pumpstation
	UNION
	SELECT connection_node_end_id
	FROM v2_pumpstation
	UNION 
	SELECT connection_node_start_id
	FROM v2_orifice
	UNION 
	SELECT connection_node_end_id
	FROM v2_orifice
	)
  , node_count AS ( -- count the number of times the node is used, it will tell us whether a node is an endpoint and can be used as a boundary
    SELECT nodes, count(nodes)
	FROM node_list
	GROUP BY nodes
	)
  , end_node AS ( -- find the endnodes of any weir that is a afvoerkunstwerk 
	SELECT connection_node_end_id
	FROM v2_weir
	WHERE code IN (SELECT code FROM deelgebied.afvoerkunstwerken)
	)
  , boundary_end_nodes AS ( -- find the opposite connection node of the channel that is connected to the afvoerkunstwerk
	SELECT connection_node_start_id as node
	FROM v2_channel
	WHERE connection_node_end_id IN (SELECT * FROM end_node)
	UNION
	SELECT connection_node_end_id
	FROM v2_channel
	WHERE connection_node_start_id IN (SELECT * FROM end_node) 
	)
  ,start_node AS ( -- find the endnodes of any weir that is a afvoerkunstwerk 
	SELECT connection_node_start_id
	FROM v2_weir
	WHERE code IN (SELECT code FROM deelgebied.afvoerkunstwerken)
	)
  , boundary_start_nodes AS ( -- find the opposite connection node of the channel that is connected to the afvoerkunstwerk 
	SELECT connection_node_start_id as node
	FROM v2_channel
	WHERE connection_node_end_id IN (SELECT * FROM end_node)
	UNION
	SELECT connection_node_end_id
	FROM v2_channel
	WHERE connection_node_start_id IN (SELECT * FROM end_node) 
	)
  , boundary_nodes AS (-- select nodes from available boundary nodes that are used only once
	SELECT nodes
	FROM node_count
	WHERE count = 1 AND nodes IN (
		SELECT node FROM boundary_end_nodes
		UNION
		SELECT node FROM boundary_start_nodes
		)
	)
--INSERT INTO v2_1d_boundary_conditions (id, connection_node_id, boundary_type, timeseries)
SELECT nextval('boundary'), nodes, 1, '0,-0.5' || E'\n999,-0.5'
FROM boundary_nodes
;

-- For culverts
-- more dificult because we do not know whether its direction is correct
WITH node_list AS ( -- list of all nodes used in the channels and structures
	SELECT connection_node_start_id as nodes
	FROM v2_channel
	UNION
	SELECT connection_node_end_id
	FROM v2_channel
	UNION
	SELECT connection_node_start_id
	FROM v2_culvert 
	UNION
	SELECT connection_node_end_id
	FROM v2_culvert
	UNION 
	SELECT connection_node_start_id
	FROM v2_weir
	UNION 
	SELECT connection_node_end_id
	FROM v2_weir
	UNION 
	SELECT connection_node_start_id
	FROM v2_pumpstation
	UNION
	SELECT connection_node_end_id
	FROM v2_pumpstation
	UNION 
	SELECT connection_node_start_id
	FROM v2_orifice
	UNION 
	SELECT connection_node_end_id
	FROM v2_orifice
	)
  , node_count AS ( -- count the number of times the node is used, it will tell us whether a node is an endpoint and can be used as a boundary
    SELECT nodes, count(nodes)
	FROM node_list
	GROUP BY nodes
	)
  , end_node AS ( -- find the endnodes of any weir that is a afvoerkunstwerk 
	SELECT connection_node_end_id
	FROM v2_culvert
	WHERE code IN (SELECT code FROM deelgebied.afvoerkunstwerken)
	)
  , boundary_end_nodes AS ( -- find the opposite connection node of the channel that is connected to the afvoerkunstwerk
	SELECT connection_node_start_id as node
	FROM v2_channel
	WHERE connection_node_end_id IN (SELECT * FROM end_node)
	UNION
	SELECT connection_node_end_id
	FROM v2_channel
	WHERE connection_node_start_id IN (SELECT * FROM end_node) 
	)
  , start_node AS ( -- find the endnodes of any weir that is a afvoerkunstwerk 
	SELECT connection_node_start_id
	FROM v2_culvert
	WHERE code IN (SELECT code FROM deelgebied.afvoerkunstwerken)
	)
  , boundary_start_nodes AS ( -- find the opposite connection node of the channel that is connected to the afvoerkunstwerk 
	SELECT connection_node_start_id as node
	FROM v2_channel
	WHERE connection_node_end_id IN (SELECT * FROM end_node)
	UNION
	SELECT connection_node_end_id
	FROM v2_channel
	WHERE connection_node_start_id IN (SELECT * FROM end_node) 
	)
  , boundary_nodes AS (-- select nodes from available boundary nodes that are used only once
	SELECT nodes
	FROM node_count
	WHERE count = 1 AND nodes IN (
		SELECT node FROM boundary_end_nodes
		UNION
		SELECT node FROM boundary_start_nodes
		)
	)
--INSERT INTO v2_1d_boundary_conditions (id, connection_node_id, boundary_type, timeseries)
SELECT nextval('boundary'), nodes, 1, '0,-0.5' || E'\n999,-0.5'
FROM boundary_nodes
;
-- CHECK:
-- which afvoerkunstwerken have no boundary
WITH channel_nodes AS (
	SELECT connection_node_end_id as node
	FROM v2_channel
	WHERE connection_node_start_id IN (SELECT connection_node_id FROM v2_1d_boundary_conditions)
	UNION
	SELECT connection_node_start_id
	FROM v2_channel
	WHERE connection_node_end_id IN (SELECT connection_node_id FROM v2_1d_boundary_conditions)
	)
  ,	structures AS (
	SELECT code
	FROM v2_weir
	WHERE connection_node_start_id IN (SELECT node FROM channel_nodes) OR
		connection_node_end_id IN (SELECT node FROM channel_nodes)
	UNION
	SELECT code
	FROM v2_pumpstation
	WHERE connection_node_start_id IN (SELECT node FROM channel_nodes) OR
		connection_node_end_id IN (SELECT node FROM channel_nodes)
	UNION
	SELECT code 
	FROM v2_pumpstation
	WHERE connection_node_start_id IN (SELECT node FROM channel_nodes) OR
		connection_node_end_id IN (SELECT node FROM channel_nodes)
	)
 SELECT code, geom
 FROM deelgebied.afvoerkunstwerken
 WHERE code IN (SELECT code FROM structures)
 ;
*/

