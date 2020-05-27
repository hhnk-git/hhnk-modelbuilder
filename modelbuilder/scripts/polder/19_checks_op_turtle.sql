-- CHECKS en OPLOSSINGEN

-- ============================ Channels ====================================
--CHECK alle locaties hebben een definitie
DROP TABLE IF EXISTS feedback.xs_locations_without_definition;
CREATE TABLE feedback.xs_locations_without_definition AS(
	SELECT a.*, 'v2_cross_section_location does not have a v2_cross_section_definition'::text as remark
	FROM v2_cross_section_location as a
	LEFT JOIN v2_cross_section_definition as b
	ON a.definition_id = b.id
	WHERE b.id IS NULL
);

-- ===========================Cross sections=================================
--CHECK alle channels hebben een cross section location
DROP TABLE IF EXISTS feedback.channel_without_xs_location;
CREATE TABLE feedback.channel_without_xs_location AS(
	SELECT a.*, 'Channel does not have a cross-section location'::text as remark
	FROM v2_channel a
	LEFT JOIN v2_cross_section_location c 
	ON a.id = c.channel_id
	WHERE c.id IS NULL
	ORDER BY a.id
)
;

-- check vertices op profiel
--TODO
DROP TABLE IF EXISTS feedback.xs_location_vertex_REVIEW;
CREATE TABLE feedback.xs_location_vertex_REVIEW AS(
WITH vertix AS (
	SELECT (ST_DumpPoints(the_geom)).geom, id
	FROM v2_channel
	)
, good as (
	SELECT a.*, c.id as cid
	FROM vertix a
	LEFT JOIN v2_cross_section_location c 
	ON ST_DWithin(a.geom,c.the_geom,0.01)
	WHERE c.id IS NOT NULL
	ORDER BY a.id
	)
SELECT * FROM v2_channel WHERE id NOT IN (SELECT id FROM good))
;

-- CHECK friction filled
DROP TABLE IF EXISTS feedback.missing_friction;
CREATE TABLE feedback.missing_friction AS(
SELECT *, 'Cross section location does not have a friction'::text as remark FROM v2_cross_section_location WHERE friction_value IS NULL OR friction_type IS NULL);

-- CHECK reference/bank level
DROP TABLE IF EXISTS feedback.xs_location_lowered_reference_level;
CREATE TABLE feedback.xs_location_lowered_reference_level AS(
	SELECT *, 'reference_level >= banklevel: reference level lowered to 1 meter below bank level'::text as remark
	FROM v2_cross_section_location
	WHERE reference_level >= bank_level
);
UPDATE v2_cross_section_location SET reference_level = bank_level - 1
WHERE reference_level >= bank_level
;

-- 48 records (03-04-2017)
-- 3 (02-05-2017)
-- Drieban (17-5-2017): 0
-- Koegras (22-5-2017): 0
-- Koegras (30-11-2017):5

-- CHECK bank level is minimaal initial level aan beide zijde + 10cm
DROP TABLE IF EXISTS feedback.xs_location_increased_bank_level;
CREATE TABLE feedback.xs_location_increased_bank_level AS(
WITH level_check AS(
SELECT 
	a.id as check_id, 
	a.channel_id, 
	a.bank_level, GREATEST(c.initial_waterlevel, c.initial_waterlevel) as max_wl 
FROM 
	v2_cross_section_location a, 
	v2_channel b, 
	v2_connection_nodes c, 
	v2_connection_nodes d
WHERE 
	a.channel_id = b.id 
	AND b.connection_node_start_id = c.id 
	AND b.connection_node_end_id = d.id
	AND GREATEST(c.initial_waterlevel, c.initial_waterlevel)+0.1 > a.bank_level
)
SELECT a.*, 'bank level increased to initial waterlevel + 0.10m'::text as remark FROM v2_cross_section_location a, level_check b WHERE a.id = b.check_id);

WITH level_check AS(
SELECT 
	a.id as check_id, 
	a.channel_id, 
	a.bank_level, GREATEST(c.initial_waterlevel, c.initial_waterlevel) as max_wl 
FROM 
	v2_cross_section_location a, 
	v2_channel b, 
	v2_connection_nodes c, 
	v2_connection_nodes d
WHERE 
	a.channel_id = b.id 
	AND b.connection_node_start_id = c.id 
	AND b.connection_node_end_id = d.id
	AND GREATEST(c.initial_waterlevel, c.initial_waterlevel)+0.1 > a.bank_level
)
UPDATE v2_cross_section_location SET bank_level = max_wl + 0.1
FROM level_check 
WHERE id = check_id
; 

-- ==========================Culverts========================================
-- CHECK alle duikers hebben een cross section definition
DROP TABLE IF EXISTS feedback.culvert_without_xs;
CREATE TABLE feedback.culvert_without_xs AS(
SELECT a.*, 'culvert does not have a cross-section'::text as remark
FROM v2_culvert as a
LEFT JOIN v2_cross_section_definition as b
ON a.cross_section_definition_id = b.id
WHERE b.id IS NULL)
;

-- CHECK Culvert invert level below connection node reference level, reference level is updated
-- FEEDBACK TODO

DROP TABLE IF EXISTS feedback.lowered_reference_level_culvert;
CREATE TABLE feedback.lowered_reference_level_culvert AS(
WITH start_node_reference_levels as -- select profile nearest to channel start for every channel
	( 
	SELECT DISTINCT ON (channel_id) c.reference_level as ref, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Startpoint(d.the_geom),c.the_geom)
	)
  , end_node_reference_levels as -- select profile nearest to channel end for every channel
	(
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Endpoint(d.the_geom),c.the_geom)
	)
 , all_nodes AS ( -- make one list of it
	SELECT *
	FROM start_node_reference_levels
	UNION ALL
	SELECT *
	FROM end_node_reference_levels
	)
, ref_list AS ( -- list all reference id with there current level and the culvert invert level
	SELECT a.id, a.display_name, a.invert_level_end_point as invert_level, 
		b.ref, b.ref_id 
	FROM v2_culvert as a
	LEFT JOIN all_nodes as b
	ON a.connection_node_end_id = b.connection_node
	WHERE a.invert_level_end_point <= b.ref
	
	UNION ALL

	SELECT a.id, a.display_name, a.invert_level_start_point as invert_level,
		c.ref, c.ref_id 
	FROM v2_culvert as a
	LEFT JOIN all_nodes as c 
	ON a.connection_node_start_id = c.connection_node
	WHERE a.invert_level_start_point <= c.ref
	)
  SELECT *, 'Reference level lowered due to culvert'::text as remark FROM v2_cross_section_location WHERE id IN (SELECT ref_id FROM ref_list)
);


UPDATE v2_cross_section_location as o 
SET reference_level = new_ref_level - 0.01
FROM (
WITH start_node_reference_levels as -- select profile nearest to channel start for every channel
	( 
	SELECT DISTINCT ON (channel_id) c.reference_level as ref, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Startpoint(d.the_geom),c.the_geom)
	)
  , end_node_reference_levels as -- select profile nearest to channel end for every channel
	(
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Endpoint(d.the_geom),c.the_geom)
	)
 , all_nodes AS ( -- make one list of it
	SELECT *
	FROM start_node_reference_levels
	UNION ALL
	SELECT *
	FROM end_node_reference_levels
	)
, ref_list AS ( -- list all reference id with there current level and the culvert invert level
	SELECT a.id, a.display_name, a.invert_level_end_point as invert_level, 
		b.ref, b.ref_id 
	FROM v2_culvert as a
	LEFT JOIN all_nodes as b
	ON a.connection_node_end_id = b.connection_node
	WHERE a.invert_level_end_point <= b.ref
	
	UNION ALL

	SELECT a.id, a.display_name, a.invert_level_start_point as invert_level,
		c.ref, c.ref_id 
	FROM v2_culvert as a
	LEFT JOIN all_nodes as c 
	ON a.connection_node_start_id = c.connection_node
	WHERE a.invert_level_start_point <= c.ref
	)
  SELECT min(invert_level) as new_ref_level, ref_id
  FROM ref_list
  GROUP BY ref_id
	) as b 
	WHERE o.id = b.ref_id
;


	

-- CHECK alle velden ingevuld
DROP TABLE IF EXISTS feedback.culvert_without_invert_level;
CREATE TABLE feedback.culvert_without_invert_level AS(
SELECT *, 'Culvert is missing invert level'::text as remark FROM v2_culvert WHERE invert_level_start_point IS NULL OR invert_level_end_point IS NULL);

-- CHECK uiteinden van culverts (connection nodes) zonder channel verbonden
DROP TABLE IF EXISTS feedback.culvert_connection_node_without_channel;
CREATE TABLE feedback.culvert_connection_node_without_channel AS(
WITH channel_conection_nodes AS
	(
	SELECT connection_node_start_id as nodes
	FROM v2_channel
	UNION
	SELECT connection_node_end_id as nodes
	FROM v2_channel
	), loose_nodes as (
	SELECT connection_node_start_id
	FROM v2_culvert
	WHERE connection_node_start_id NOT IN (SELECT * FROM channel_conection_nodes)
	UNION
	SELECT connection_node_end_id
	FROM v2_culvert	
	WHERE connection_node_end_id NOT IN (SELECT * FROM channel_conection_nodes)
	)
SELECT *, 'culvert ending connection node receives 10m2 storage'::text as remark FROM v2_connection_nodes
WHERE id IN (SELECT connection_node_start_id FROM loose_nodes))
;

WITH channel_conection_nodes AS
	(
	SELECT connection_node_start_id as nodes
	FROM v2_channel
	UNION
	SELECT connection_node_end_id as nodes
	FROM v2_channel
	), loose_nodes as (
	SELECT connection_node_start_id AS id
	FROM v2_culvert
	WHERE connection_node_start_id NOT IN (SELECT nodes FROM channel_conection_nodes)
	UNION
	SELECT connection_node_end_id AS id
	FROM v2_culvert	
	WHERE connection_node_end_id NOT IN (SELECT nodes FROM channel_conection_nodes)
	)
UPDATE v2_connection_nodes SET storage_area = 10
WHERE id IN (SELECT id FROM loose_nodes)
;
-- 18 (03-04-2017)
-- 3 (02-05-2017)
-- Drieban (17-05-2017): 19
-- hoorn (19-5-2017): 113
-- Koegras (22-05-2017): 28
-- hhw (21 juni 2016): 17

-- ===================================WEIRS================================================
-- CHECK alle weirs hebben een cross section definition

DROP TABLE IF EXISTS feedback.weir_without_xs_definition;
CREATE TABLE feedback.weir_without_xs_definition AS(
WITH weirs as(
SELECT a.*, 'weir without cross section definition'::text as remark
FROM v2_weir as a
LEFT JOIN v2_cross_section_definition as b
ON a.cross_section_definition_id = b.id
WHERE b.id IS NULL)
SELECT a.*, ST_Centroid(ST_Union(b.the_geom,c.the_geom)) as the_geom
FROM weirs a, v2_connection_nodes b, v2_connection_nodes c
WHERE a.connection_node_start_id = b.id AND a.connection_node_end_id = c.id
);



-- CHECK uiteinden van weir (connection nodes) zonder channel verbonden
DROP TABLE IF EXISTS feedback.weir_connection_node_without_channel;
CREATE TABLE feedback.weir_connection_node_without_channel AS(
WITH channel_conection_nodes AS
	(
	SELECT connection_node_start_id as nodes
	FROM v2_channel
	UNION
	SELECT connection_node_end_id as nodes
	FROM v2_channel
	), loose_nodes as (
	SELECT connection_node_start_id
	FROM v2_weir
	WHERE connection_node_start_id NOT IN (SELECT * FROM channel_conection_nodes)
	UNION
	SELECT connection_node_end_id
	FROM v2_weir	
	WHERE connection_node_end_id NOT IN (SELECT * FROM channel_conection_nodes)
	)
SELECT *, 'weir ending connection node receives 10m2 storage'::text as remark FROM v2_connection_nodes WHERE id IN (SELECT * FROM loose_nodes));

WITH channel_conection_nodes AS
	(
	SELECT connection_node_start_id as nodes
	FROM v2_channel
	UNION
	SELECT connection_node_end_id as nodes
	FROM v2_channel
	), loose_nodes as (
	SELECT connection_node_start_id
	FROM v2_weir
	WHERE connection_node_start_id NOT IN (SELECT * FROM channel_conection_nodes)
	UNION
	SELECT connection_node_end_id
	FROM v2_weir	
	WHERE connection_node_end_id NOT IN (SELECT * FROM channel_conection_nodes)
	)
UPDATE v2_connection_nodes SET storage_area = 10
WHERE id IN (SELECT connection_node_start_id FROM loose_nodes)
;
-- 27 (03-04-2017)
-- 15 (02-05-2017)
-- Drieban (17-05-2017): 13
-- hoorn (19-5-2017): 45
-- Koegras (22-05-2017): 31
-- hhw (21 juni 2016): 5

-- Helps with finding the lowest crest level of weirs with a variable crest level
DROP TABLE IF EXISTS tmp.min_ctrl_crest_level_weirs;
create table tmp.min_ctrl_crest_level_weirs AS
(
	WITH tmp_ctrl_crest_level_weirs AS
	(
		select target_id as weir_id, unnest(string_to_array(action_table, '#')) as a
		from v2_control_table
		where target_type = 'v2_weir'
	)
	select weir_id, min(split_part(a, ';', 2)::double precision) as min_ctrl_crest_level
	FROM tmp_ctrl_crest_level_weirs
	GROUP BY weir_id
);

-- CHECK Weir crest level below connection node reference level, reference level is updated
DROP TABLE IF EXISTS feedback.lowered_reference_level_weir;
CREATE TABLE feedback.lowered_reference_level_weir AS(
WITH start_node_reference_levels as -- select profile nearest to channel start for every channel
	( 
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Startpoint(d.the_geom),c.the_geom)
	)
  , end_node_reference_levels as -- select profile nearest to channel end for every channel
	(
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Endpoint(d.the_geom),c.the_geom)
	)
 , all_nodes AS ( -- make one list of it
	SELECT *
	FROM start_node_reference_levels
	UNION ALL
	SELECT *
	FROM end_node_reference_levels
	)
, ref_list AS ( -- list all reference id with there current level and the weir invert level
	SELECT a.id, a.display_name, least(a.crest_level,d.min_ctrl_crest_level) as crest_level,
		b.ref, b.ref_id 
	FROM v2_weir as a
	LEFT JOIN all_nodes as b
	ON a.connection_node_end_id = b.connection_node
	LEFT JOIN tmp.min_ctrl_crest_level_weirs as d
	ON a.id = d.weir_id
	WHERE a.crest_level <= b.ref OR d.min_ctrl_crest_level <= b.ref
	
	UNION ALL

	SELECT a.id, a.display_name, least(a.crest_level,d.min_ctrl_crest_level) as crest_level, 
		c.ref, c.ref_id 
	FROM v2_weir as a
	LEFT JOIN all_nodes as c 
	ON a.connection_node_start_id = c.connection_node
	LEFT JOIN tmp.min_ctrl_crest_level_weirs as d
	ON a.id = d.weir_id
	WHERE a.crest_level <= c.ref OR d.min_ctrl_crest_level <= c.ref
	)
SELECT *, 'Reference level lowered due to weir'::text as remark FROM v2_cross_section_location WHERE id IN (SELECT ref_id FROM ref_list));

UPDATE v2_cross_section_location as o 
SET reference_level = new_ref_level - 0.01
FROM (
WITH start_node_reference_levels as -- select profile nearest to channel start for every channel
	( 
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Startpoint(d.the_geom),c.the_geom)
	)
  , end_node_reference_levels as -- select profile nearest to channel end for every channel
	(
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Endpoint(d.the_geom),c.the_geom)
	)
 , all_nodes AS ( -- make one list of it
	SELECT *
	FROM start_node_reference_levels
	UNION ALL
	SELECT *
	FROM end_node_reference_levels
	)
, ref_list AS ( -- list all reference id with there current level and the weir invert level
		SELECT a.id, a.display_name, least(a.crest_level,d.min_ctrl_crest_level) as crest_level,
		b.ref, b.ref_id 
	FROM v2_weir as a
	LEFT JOIN all_nodes as b
	ON a.connection_node_end_id = b.connection_node
	LEFT JOIN tmp.min_ctrl_crest_level_weirs as d
	ON a.id = d.weir_id
	WHERE a.crest_level <= b.ref OR d.min_ctrl_crest_level <= b.ref
	
	UNION ALL

	SELECT a.id, a.display_name, least(a.crest_level,d.min_ctrl_crest_level) as crest_level, 
		c.ref, c.ref_id 
	FROM v2_weir as a
	LEFT JOIN all_nodes as c 
	ON a.connection_node_start_id = c.connection_node
	LEFT JOIN tmp.min_ctrl_crest_level_weirs as d
	ON a.id = d.weir_id
	WHERE a.crest_level <= c.ref OR d.min_ctrl_crest_level <= c.ref
	)
  SELECT min(crest_level) as new_ref_level, ref_id
  FROM ref_list
  GROUP BY ref_id
	) as b 
	WHERE o.id = b.ref_id
;
-- 4 (03-04-2017)
-- 0 (02-05-2017)
-- Drieban (17-05-2017): 0
-- hoorn (19-5-2017): 4
-- Koegras (22-05-2017): 1
-- hhw (21 juni 2016): 0

-- CHECK alle velden ingevuld
DROP TABLE IF EXISTS feedback.weir_without_crest_level;
CREATE TABLE feedback.weir_without_crest_level AS(
WITH weirs as(
	SELECT *, 'Weir does not have a crest level'::text as remark FROM v2_weir WHERE crest_level IS NULL
)
SELECT a.*, ST_Centroid(ST_Union(b.the_geom,c.the_geom)) as the_geom
FROM weirs a, v2_connection_nodes b, v2_connection_nodes c
WHERE a.connection_node_start_id = b.id AND a.connection_node_end_id = c.id
);

-- ===================================ORIFICES================================================
-- CHECK alle weirs hebben een cross section definition
DROP TABLE IF EXISTS feedback.orifice_without_xs_definition;
CREATE TABLE feedback.orifice_without_xs_definition AS(
WITH orifices AS(
SELECT a.*, 'orifice without cross section definition'::text as remark
FROM v2_orifice as a
LEFT JOIN v2_cross_section_definition as b
ON a.cross_section_definition_id = b.id
WHERE b.id IS NULL)
SELECT a.*, ST_Centroid(ST_Union(b.the_geom,c.the_geom)) as the_geom
FROM orifices a, v2_connection_nodes b, v2_connection_nodes c
WHERE a.connection_node_start_id = b.id AND a.connection_node_end_id = c.id
);

-- CHECK uiteinden van orifices (connection nodes) zonder channel verbonden
DROP TABLE IF EXISTS feedback.orifice_connection_node_without_channel;
CREATE TABLE feedback.orifice_connection_node_without_channel AS(
WITH channel_conection_nodes AS
	(
	SELECT connection_node_start_id as nodes
	FROM v2_channel
	UNION
	SELECT connection_node_end_id as nodes
	FROM v2_channel
	), loose_nodes as (
	SELECT connection_node_start_id AS id
	FROM v2_orifice
	WHERE connection_node_start_id NOT IN (SELECT nodes FROM channel_conection_nodes)
	UNION
	SELECT connection_node_end_id AS id
	FROM v2_orifice	
	WHERE connection_node_end_id NOT IN (SELECT nodes FROM channel_conection_nodes)
	)
SELECT *, 'weir ending connection node receives 10m2 storage'::text as remark FROM v2_connection_nodes WHERE id IN (SELECT id FROM loose_nodes));

WITH channel_conection_nodes AS
	(
	SELECT connection_node_start_id as nodes
	FROM v2_channel
	UNION
	SELECT connection_node_end_id as nodes
	FROM v2_channel
	), loose_nodes as (
	SELECT connection_node_start_id AS id
	FROM v2_orifice
	WHERE connection_node_start_id NOT IN (SELECT nodes FROM channel_conection_nodes)
	UNION
	SELECT connection_node_end_id AS id
	FROM v2_orifice	
	WHERE connection_node_end_id NOT IN (SELECT nodes FROM channel_conection_nodes)
	)
UPDATE v2_connection_nodes SET storage_area = 10
WHERE id IN (SELECT id FROM loose_nodes)
;
-- 27 (03-04-2017)
-- 15 (02-05-2017)
-- Drieban (17-05-2017): 13
-- hoorn (19-5-2017): 45
-- Koegras (22-05-2017): 31
-- hhw (21 juni 2016): 5


-- CHECK Orifice crest level below connection node reference level, reference level is updated

DROP TABLE IF EXISTS feedback.lowered_reference_level_orifice;
CREATE TABLE feedback.lowered_reference_level_orifice AS(
WITH start_node_reference_levels as -- select profile nearest to channel start for every channel
	( 
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Startpoint(d.the_geom),c.the_geom)
	)
  , end_node_reference_levels as -- select profile nearest to channel end for every channel
	(
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Endpoint(d.the_geom),c.the_geom)
	)
 , all_nodes AS ( -- make one list of it
	SELECT *
	FROM start_node_reference_levels
	UNION ALL
	SELECT *
	FROM end_node_reference_levels
	)
, ref_list AS ( -- list all reference id with there current level and the culvert invert level
	SELECT a.id, a.display_name, a.crest_level as crest_level, 
		b.ref, b.ref_id 
	FROM v2_orifice as a
	LEFT JOIN all_nodes as b
	ON a.connection_node_end_id = b.connection_node
	WHERE a.crest_level <= b.ref
	
	UNION ALL

	SELECT a.id, a.display_name, a.crest_level as crest_level,
		c.ref, c.ref_id 
	FROM v2_orifice as a
	LEFT JOIN all_nodes as c 
	ON a.connection_node_start_id = c.connection_node
	WHERE a.crest_level <= c.ref
	)
SELECT *, 'Reference level lowered due to orifice'::text as remark FROM v2_cross_section_location WHERE id IN (SELECT ref_id FROM ref_list));


UPDATE v2_cross_section_location as o 
SET reference_level = new_ref_level - 0.01
FROM (
WITH start_node_reference_levels as -- select profile nearest to channel start for every channel
	( 
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Startpoint(d.the_geom),c.the_geom)
	)
  , end_node_reference_levels as -- select profile nearest to channel end for every channel
	(
	SELECT DISTINCT ON (c.channel_id) c.reference_level as ref, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom as csgeom, d.the_geom, c.id as ref_id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	ORDER BY c.channel_id, ST_Distance(ST_Endpoint(d.the_geom),c.the_geom)
	)
 , all_nodes AS ( -- make one list of it
	SELECT *
	FROM start_node_reference_levels
	UNION ALL
	SELECT *
	FROM end_node_reference_levels
	)
, ref_list AS ( -- list all reference id with there current level and the culvert invert level
	SELECT a.id, a.display_name, a.crest_level as crest_level, 
		b.ref, b.ref_id 
	FROM v2_orifice as a
	LEFT JOIN all_nodes as b
	ON a.connection_node_end_id = b.connection_node
	WHERE a.crest_level <= b.ref
	
	UNION ALL

	SELECT a.id, a.display_name, a.crest_level as crest_level,
		c.ref, c.ref_id 
	FROM v2_orifice as a
	LEFT JOIN all_nodes as c 
	ON a.connection_node_start_id = c.connection_node
	WHERE a.crest_level <= c.ref
	)
  SELECT min(crest_level) as new_ref_level, ref_id
  FROM ref_list
  GROUP BY ref_id
	) as b 
	WHERE o.id = b.ref_id
;
-- 4 (03-04-2017)
-- 0 (02-05-2017)
-- Drieban (17-05-2017): 0
-- hoorn (19-5-2017): 4
-- Koegras (22-05-2017): 1
-- hhw (21 juni 2016): 0

-- CHECK alle velden ingevuld
DROP TABLE IF EXISTS feedback.orifice_without_crest_level;
CREATE TABLE feedback.orifice_without_crest_level AS(
WITH orifices AS(
SELECT *,'Orifice does not have a crest level'::text as remark FROM v2_orifice WHERE crest_level IS NULL)
SELECT a.*, ST_Centroid(ST_Union(b.the_geom,c.the_geom)) as the_geom
FROM orifices a, v2_connection_nodes b, v2_connection_nodes c
WHERE a.connection_node_start_id = b.id AND a.connection_node_end_id = c.id
);

-- ==================================PUMPSTATION=================================
-- CHECK pump activation or turn off level is below bottom of node
DROP TABLE IF EXISTS feedback.lowered_reference_level_pumpstation;
CREATE TABLE feedback.lowered_reference_level_pumpstation AS(
WITH node_reference_levels as
	(
	SELECT DISTINCT c.reference_level, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom, c.id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	UNION 
	SELECT DISTINCT c.reference_level, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom,c.id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d	
	ON d.id = c.channel_id)
  ,pump_start as (
	SELECT g.*, h.the_geom
	FROM v2_pumpstation as g
	LEFT JOIN v2_connection_nodes as h
	ON g.connection_node_start_id = h.id)
 , shortlist as (
        SELECT DISTINCT ON (a.id) a.id as pumpid, a.display_name, a.start_level, a.lower_stop_level, b.reference_level, a.connection_node_start_id, ST_Distance(a.the_geom,b.the_geom), b.id as csid
        FROM pump_start as a
        LEFT JOIN node_reference_levels as b
        ON a.connection_node_start_id = b.connection_node
        WHERE least(a.lower_stop_level, a.lower_stop_level) <= b.reference_level
        ORDER BY a.id, ST_Distance(a.the_geom,b.the_geom)
        )
SELECT *,'Reference level lowered due to pumpstation'::text as remark FROM v2_cross_section_location WHERE id IN (SELECT csid FROM shortlist));


WITH node_reference_levels as
	(
	SELECT DISTINCT c.reference_level, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom, c.id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	UNION 
	SELECT DISTINCT c.reference_level, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom,c.id
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d	
	ON d.id = c.channel_id)
  ,pump_start as (
	SELECT g.*, h.the_geom
	FROM v2_pumpstation as g
	LEFT JOIN v2_connection_nodes as h
	ON g.connection_node_start_id = h.id)
 , shortlist as (
        SELECT DISTINCT ON (a.id) a.id as pumpid, a.display_name, a.start_level, a.lower_stop_level, b.reference_level, a.connection_node_start_id, ST_Distance(a.the_geom,b.the_geom), b.id as csid
        FROM pump_start as a
        LEFT JOIN node_reference_levels as b
        ON a.connection_node_start_id = b.connection_node
        WHERE least(a.lower_stop_level, a.lower_stop_level) <= b.reference_level
        ORDER BY a.id, ST_Distance(a.the_geom,b.the_geom)
        )
UPDATE v2_cross_section_location SET reference_level = lower_stop_level - 1
FROM shortlist 
WHERE id = csid;
-- 13 (03-04-2017)
-- 0 (02-05-2017)
-- Drieban (17-05-2017): 0
-- hoorn (19-5-2017): 1
-- Koegras (22-05-2017): 0
-- hhw (21 juni 2016): 0

-- CHECK pump has no channel at start
WITH node_reference_levels as
	(
	SELECT DISTINCT c.reference_level, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	UNION 
	SELECT DISTINCT c.reference_level, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d	
	ON d.id = c.channel_id)
  ,pump_start as (
	SELECT g.*, h.the_geom
	FROM v2_pumpstation as g
	LEFT JOIN v2_connection_nodes as h
	ON g.connection_node_start_id = h.id)
 , shortlist as (
        SELECT DISTINCT ON (a.id) a.id, a.display_name, a.start_level, a.lower_stop_level, b.reference_level, a.connection_node_start_id, ST_Distance(a.the_geom,b.the_geom)
        FROM pump_start as a
        LEFT JOIN node_reference_levels as b
        ON a.connection_node_start_id = b.connection_node
        WHERE b.reference_level IS NULL
        ORDER BY a.id, ST_Distance(a.the_geom,b.the_geom)
        )
INSERT INTO v2_manhole -- Maak een put bij elk van deze pompen
SELECT      DISTINCT ON (connection_node_start_id) connection_node_start_id, display_name || '_put', display_name, connection_node_start_id, '00', 5, 5,
			--connection_node_start_id, display_name || '_put', display_name, connection_node_start_id, '00', 5, 5, 
            0, 1, start_level - 2, start_level + 2, 
            start_level + 2, NULL, 0
FROM shortlist
;
-- 0 (03-04-2017)
-- 0 (02-05-2017)
-- Drieban (17-05-2017): 0
-- hoorn (19-5-20178): 5
-- Koegras (22-05-2017): 9
-- hhw (21 juni 2016): 0


-- CHECK pump has no channel at end
WITH node_reference_levels as
	(
	SELECT DISTINCT c.reference_level, c.channel_id, d.connection_node_start_id as connection_node, c.the_geom
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d
	ON d.id = c.channel_id
	UNION 
	SELECT DISTINCT c.reference_level, c.channel_id, d.connection_node_end_id as connection_node, c.the_geom
	FROM v2_cross_section_location as c
	LEFT JOIN v2_channel as d	
	ON d.id = c.channel_id)
  ,pump_start as (
	SELECT g.*, h.the_geom
	FROM v2_pumpstation as g
	LEFT JOIN v2_connection_nodes as h
	ON g.connection_node_end_id = h.id)
 , shortlist AS (
        SELECT DISTINCT ON (a.id) a.id, a.display_name, a.start_level, a.lower_stop_level, b.reference_level, a.connection_node_end_id, ST_Distance(a.the_geom,b.the_geom)
        FROM pump_start as a
        LEFT JOIN node_reference_levels as b
        ON a.connection_node_end_id = b.connection_node
        WHERE b.reference_level IS NULL
        ORDER BY a.id, ST_Distance(a.the_geom,b.the_geom)
        )
INSERT INTO v2_manhole -- Maak een put bij elk van deze pompen
SELECT      DISTINCT ON (connection_node_end_id) connection_node_end_id, display_name || '_put', display_name, connection_node_end_id, '00', 5, 5, 
            0, 1, start_level - 2, start_level + 2, 
            start_level + 2, NULL, 0
FROM shortlist
WHERE connection_node_end_id NOT IN (SELECT id FROM v2_manhole) --Geen manhole toevoegen indien al aanwezig
	AND connection_node_end_id IS NOT NULL
;
-- 0 (03-04-2017)
-- 0 (02-05-2017)
-- Drieban (17-05-2017): 1
-- hoorn (19-5-2017): 0
-- Koegras (22-05-2017): 5
-- hhw (21 juni 2016): 0

-- CHECK losliggende connection nodes
DROP TABLE IF EXISTS feedback.loose_connection_nodes;
CREATE TABLE feedback.loose_connection_nodes AS(
SELECT *, 'connection node was removed because it was not connected'::text as remark FROM v2_connection_nodes WHERE
	(id NOT IN (select connection_node_start_id from v2_pumpstation WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_pumpstation WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_culvert WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_culvert WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_channel WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_channel WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_pipe WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_pipe WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_weir WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_weir WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_orifice WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_orifice WHERE connection_node_end_id is not NULL))
);

DELETE FROM v2_connection_nodes WHERE id IN (
SELECT id FROM v2_connection_nodes WHERE
	(id NOT IN (select connection_node_start_id from v2_pumpstation WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_pumpstation WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_culvert WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_culvert WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_channel WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_channel WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_pipe WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_pipe WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_weir WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_weir WHERE connection_node_end_id is not NULL)
	AND id NOT IN (select connection_node_start_id from v2_orifice WHERE connection_node_start_id is not NULL)
	AND id NOT IN (select connection_node_end_id from v2_orifice WHERE connection_node_end_id is not NULL))
);
-- 0 (03-04-2017)
-- 0 (02-05-2017)
-- Drieban (17-05-2017): 0
-- hoorn (19-5-2017): 0
-- Koegras (22-05-2017): 0
-- hhw (21 juni 2016): 0

-- helpt bij checken losse v2_connection_nodes
DROP TABLE IF EXISTS tmp.pumpstation_view;
CREATE TABLE tmp.pumpstation_view AS SELECT *, NULL::geometry(Linestring,28992) AS geom FROM v2_pumpstation;
UPDATE tmp.pumpstation_view a SET geom = ST_Makeline(b.the_geom, c.the_geom)
FROM v2_connection_nodes b, v2_connection_nodes c
WHERE a.connection_node_start_id = b.id
AND a.connection_node_end_id = c.id;

-- CHECK nodes die alleen met een pomp zijn verbonden
DROP TABLE IF EXISTS feedback.connection_node_only_connected_to_pump;
CREATE TABLE feedback.connection_node_only_connected_to_pump AS(
SELECT *, 'Connection node is only connected to v2_pumpstation'::text as remark FROM v2_connection_nodes WHERE
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
	))
; --> Hier goed naar kijken, waarom liggen ze op het einde en wat kunnen we er aan doen
--> als de pomp aan het startpunt geen kanaal heeft pompt hij water uit het niets... 
--> Dit is mogelijke oorzaak van de crash van Koegras.

/* 

in castricum bevindt zich een gemaal dat uit een onderbemaling zonder watergangen pompt. Kan eigenlijk helemaalweg:
DELETE FROM v2_pumpstation WHERE code LIKE 'KGM-Q-30545';
DELETE FROM v2_manhole WHERE connection_node_id = 107;
Hierna losse connection nodes nog weg gooien (staart hierboven nog eens draaien)

*/

-- CHECK alle connection nodes hebben initiele waterstand
DROP TABLE IF EXISTS feedback.connection_node_without_initial_waterlevel;
CREATE TABLE feedback.connection_node_without_initial_waterlevel AS(
SELECT *, 'Connection node does not have an initial water level'::text as remark FROM v2_connection_nodes WHERE initial_waterlevel IS NULL);


-- CHECK randvoorwarden connection nodes hebben maar 1 verbinding (alles mag, behalve pumpstations)
DROP TABLE IF EXISTS feedback.boundaries_with_multiple_connections;
CREATE TABLE feedback.boundaries_with_multiple_connections AS(
WITH all_node_refs AS (
	SELECT 'channel' as link, connection_node_start_id as connection_node FROM v2_channel UNION
	SELECT 'channel' as link, connection_node_end_id as connection_node FROM v2_channel UNION
	SELECT 'weir' as link, connection_node_start_id as connection_node FROM v2_weir UNION
	SELECT 'weir' as link, connection_node_end_id as connection_node FROM v2_weir UNION
	SELECT 'pumpstation' as link, connection_node_start_id as connection_node FROM v2_pumpstation UNION -- deze mag niet voorkomen!
	SELECT 'pumpstation' as link, connection_node_end_id as connection_node FROM v2_pumpstation UNION -- deze mag eniet voorkomen!
	SELECT 'culvert' as link, connection_node_start_id as connection_node FROM v2_culvert UNION
	SELECT 'culvert' as link, connection_node_end_id as connection_node FROM v2_culvert UNION
	SELECT 'orifice' as link, connection_node_start_id as connection_node FROM v2_orifice UNION
	SELECT 'orifice' as link, connection_node_end_id as connection_node FROM v2_orifice 
	),
list as (
	SELECT *
	FROM v2_1d_boundary_conditions as a
	LEFT JOIN all_node_refs as b
	ON a.connection_node_id = b.connection_node
	),
test as (
	SELECT id, connection_node_id as cn_id, concat(link,'_',connection_node_id::varchar) as boundary_connection_node, boundary_type, count(connection_node)
	FROM list
	GROUP BY connection_node_id, link, boundary_type, id
	ORDER BY boundary_connection_node),
boundaries AS(
SELECT id, cn_id, boundary_connection_node, boundary_type, count, 
	CASE 
		WHEN boundary_connection_node LIKE '%pumpstation%' OR count > 1 THEN 'wrong'
		ELSE 'okay'
	END as check,
	'Boundary condition is connected through multiple connections'::text as remark
FROM test)
SELECT a.*, b.the_geom
FROM boundaries a, v2_connection_nodes b
WHERE a.cn_id = b.id
)
;



-- CHECK KORTSTE LIJNSEGMENT
DROP TABLE IF EXISTS feedback.short_lines;
CREATE TABLE feedback.short_lines AS(
SELECT *, 'Channel segment too short (<5m)'::text as remark FROM v2_channel WHERE ST_Length(the_geom) < 5);
-- 12 segmenten korter dan 1 meter (23 feb 2017)
-- 20 segmenten korter dan 1 meter (3 maart 2017)
-- 19 segmenten korter dan 1 meter (03-04-2017)
-- 17 segmenten korter dan 1 meter (02-05-2017)
-- Drieban (17-05-2017): 10 segmenten korter dan 1 meter
-- hoorn (19-5-2017): 75 segmenten korter dan 1 meter
-- Koegras (22-05-2017): 15 segmenten korter dan 1 meters
-- hhw (21 juni 2016): 14 segmenten kortdan dan 1 meters

--SELECT ST_Length(geom), inp_id FROM v1.channel ORDER BY ST_Length(geom)
/*
-- CHECK alle v2 levees moeten binenn de dem liggen. Strenger dan v1
DELETE FROM v2_levee
WHERE id NOT IN (SELECT a.id FROM v2_levee as a, deelgebied.polder as b WHERE ST_Contains(b.geom,a.the_geom));
*/


-- korte kanalsegmenten extra berging geven om het model sneller te maken
WITH plenty_storage_channels AS (
	SELECT connection_node_start_id as id
	FROM v2_channel
	WHERE ST_Length(the_geom) > 20
	UNION 
	SELECT connection_node_end_id as id
	FROM v2_channel
	WHERE ST_Length(the_geom) > 20
	)
, low_storage_nodes AS (
	SELECT connection_node_start_id as id
	FROM v2_channel
	WHERE ST_Length(the_geom) <= 20 AND connection_node_start_id NOT IN (SELECT id FROM plenty_storage_channels)
	UNION 
	SELECT connection_node_end_id
	FROM v2_channel
	WHERE ST_Length(the_geom) <= 20 AND connection_node_end_id NOT IN (SELECT id FROM plenty_storage_channels)
	)
--SELECT DISTINCT *
--FROM v2_connection_nodes
UPDATE v2_connection_nodes
SET storage_area = 2
WHERE id IN (SELECT id FROM low_storage_nodes) AND storage_area IS NULL
;

-- bovenstaande mag niet voor knopen waar een gemaal met alleen een start node op zit
UPDATE v2_connection_nodes SET storage_area = NULL
WHERE id IN (SELECT connection_node_start_id FROM v2_pumpstation WHERE connection_node_end_id IS NULL)
;


-- duikers omzetten naar orifice voor snelheid
INSERT INTO v2_orifice(
            id, display_name, code, max_capacity, crest_level, sewerage, 
            cross_section_definition_id, friction_value, friction_type, discharge_coefficient_positive, 
            discharge_coefficient_negative, zoom_category, crest_type, connection_node_start_id, 
            connection_node_end_id)
SELECT id+100000, display_name, code, NULL, greatest(invert_level_start_point,invert_level_end_point), FALSE,
      cross_section_definition_id, friction_value, friction_type, discharge_coefficient_positive, 
      discharge_coefficient_negative, zoom_category,4, connection_node_start_id, 
      connection_node_end_id
FROM v2_culvert
WHERE ST_Length(the_geom) < 10
;
DROP TABLE IF EXISTS deelgebied.tmp_culvert_to_orifice;
CREATE TABLE deelgebied.tmp_culvert_to_orifice AS SELECT * FROM v2_culvert WHERE ST_Length(the_geom) < 10;

--UPDATE control structures (change v2_culvert to v2_orifice and add +100000 to the id)
UPDATE v2_control_table SET target_type = 'v2_orifice', target_id = target_id+100000 WHERE target_id IN (SELECT id FROM deelgebied.tmp_culvert_to_orifice) AND target_type = 'v2_culvert';

DELETE FROM v2_culvert
WHERE ST_Length(the_geom) < 10
;



-- tabllen weggooien
DROP TABLE IF EXISTS tmp.pumpstation_view;