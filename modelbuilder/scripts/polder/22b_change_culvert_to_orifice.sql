/*
SCRIPTJE VOOR HET WEGNEMEN INSTABILITEIT EN HET AANPASSEN DUIKERS EN ORIFICES

We willen het volgende:
1.	Lange overlaat (orifice) met discharge coëfficiënten op 1.0, mits:
	a.	Duiker breedte of diameter is factor 3 kleiner dan breedte watergang op streefpeil en,
	b.	Duiker is korter dan 25m (zo veel mogelijk culverts voor eerste test, als er toch nog instabiele lange duikers ontstaan dan misschien langere afstand kiezen) en,
	c.	Het verschil in bob is kleiner dan 10 cm
2.	Duikers korter dan 10 m die reeds als orifice zijn gemodelleerd worden lange overlaten met discharge coëfficiënt op 1.0
3.	Alle andere duikers (lang, breed of schuin) blijven culvert maar toevoegen 1m2 storage op begin en eind node daar waar dat nog niet tenminste het geval is
4.	Alle bruggen krijgen discharge coëfficiënt op 1.0 (nu vaak 0.8)

*/

-- Originele lagen bewaren;
DROP TABLE IF EXISTS v2_culvert_org;
DROP TABLE IF EXISTS v2_orifice_org;
DROP TABLE IF EXISTS tmp.v2_culvert_to_orifice;

CREATE TABLE v2_culvert_org AS SELECT * FROM v2_culvert;
CREATE TABLE v2_orifice_org AS SELECT * FROM v2_orifice;

--SELECT RecoverGeometryColumn( 'v2_culvert_org' , 'the_geom' , 4326 , 'LINESTRING'); -- sqlite only


CREATE TABLE tmp.v2_culvert_to_orifice AS
	
	WITH duikerbreedte AS (
	SELECT the_geom, ST_Length(ST_Transform(the_geom,28992)) as duikerlengte, 
	cul_id, cul_code, cul_discharge_coefficient_positive, cul_discharge_coefficient_negative, cul_invert_level_start_point, cul_invert_level_end_point, cul_connection_node_start_id, cul_connection_node_end_id,
		CASE 	WHEN def_shape = 1 OR def_shape = 2 THEN def_width 
				WHEN def_shape = 5 THEN substr(def_width,0,strpos(def_width,' ')) 
				END as duikerbreedte
	FROM v2_culvert_view
	WHERE abs(cul_invert_level_start_point - cul_invert_level_end_point) < 0.1 AND ST_Length(ST_Transform(the_geom,28992)) < 25 
	),
	waterbreedte AS (
	SELECT l_channel_id as channel_id, v2_cross_section_view.l_id, v2_cross_section_view.l_code, v2_cross_section_view.l_reference_level, v2_cross_section_view.l_definition_id, v2_cross_section_view.def_shape, v2_cross_section_view.def_width, the_geom,
	CASE WHEN def_shape = 1 OR def_shape = 2 THEN def_width 
		 WHEN def_shape = 5 THEN substr(def_width,0,strpos(def_width,' ')) 	
		 WHEN def_shape = 6 THEN 
		 CASE WHEN substr(def_width,length(def_width) - 1 ,1) = ' ' THEN substr(def_width,length(def_width) - 0 ,99) 
		 WHEN substr(def_width,length(def_width) - 2 ,1) = ' ' THEN substr(def_width,length(def_width) - 1 ,99)
			WHEN substr(def_width,length(def_width) - 3 ,1) = ' ' THEN substr(def_width,length(def_width) - 2 ,99)
			WHEN substr(def_width,length(def_width) - 4 ,1) = ' ' THEN substr(def_width,length(def_width) - 3 ,99)
			WHEN substr(def_width,length(def_width) - 5 ,1) = ' ' THEN substr(def_width,length(def_width) - 4 ,99)
			WHEN substr(def_width,length(def_width) - 6 ,1) = ' ' THEN substr(def_width,length(def_width) - 5 ,99)
			WHEN substr(def_width,length(def_width) - 7 ,1) = ' ' THEN substr(def_width,length(def_width) - 6 ,99)
			WHEN substr(def_width,length(def_width) - 8 ,1) = ' ' THEN substr(def_width,length(def_width) - 7 ,99)
			WHEN substr(def_width,length(def_width) - 9 ,1) = ' ' THEN substr(def_width,length(def_width) - 8 ,99)
			WHEN substr(def_width,length(def_width) - 10 ,1) = ' ' THEN substr(def_width,length(def_width) - 9 ,99)
			WHEN substr(def_width,length(def_width) - 11 ,1) = ' ' THEN substr(def_width,length(def_width) - 10 ,99)
			WHEN substr(def_width,length(def_width) - 12 ,1) = ' ' THEN substr(def_width,length(def_width) - 11 ,99)
			WHEN substr(def_width,length(def_width) - 13 ,1) = ' ' THEN substr(def_width,length(def_width) - 12 ,99)
			WHEN substr(def_width,length(def_width) - 14 ,1) = ' ' THEN substr(def_width,length(def_width) - 13 ,99)
			WHEN substr(def_width,length(def_width) - 15 ,1) = ' ' THEN substr(def_width,length(def_width) - 14 ,99)
			WHEN substr(def_width,length(def_width) - 16 ,1) = ' ' THEN substr(def_width,length(def_width) - 15 ,99)
			WHEN substr(def_width,length(def_width) - 17 ,1) = ' ' THEN substr(def_width,length(def_width) - 16 ,99)
			WHEN substr(def_width,length(def_width) - 18 ,1) = ' ' THEN substr(def_width,length(def_width) - 17 ,99)
			WHEN substr(def_width,length(def_width) - 19 ,1) = ' ' THEN substr(def_width,length(def_width) - 18 ,99)
			WHEN substr(def_width,length(def_width) - 20 ,1) = ' ' THEN substr(def_width,length(def_width) - 19 ,99)
			WHEN substr(def_width,length(def_width) - 21 ,1) = ' ' THEN substr(def_width,length(def_width) - 20 ,99)
			WHEN substr(def_width,length(def_width) - 22 ,1) = ' ' THEN substr(def_width,length(def_width) - 21 ,99)
			WHEN substr(def_width,length(def_width) - 23 ,1) = ' ' THEN substr(def_width,length(def_width) - 22 ,99)
			WHEN substr(def_width,length(def_width) - 24 ,1) = ' ' THEN substr(def_width,length(def_width) - 23 ,99)
			WHEN substr(def_width,length(def_width) - 25 ,1) = ' ' THEN substr(def_width,length(def_width) - 24 ,99)
			WHEN substr(def_width,length(def_width) - 26 ,1) = ' ' THEN substr(def_width,length(def_width) - 25 ,99)
			WHEN substr(def_width,length(def_width) - 27 ,1) = ' ' THEN substr(def_width,length(def_width) - 26 ,99)
			WHEN substr(def_width,length(def_width) - 28 ,1) = ' ' THEN substr(def_width,length(def_width) - 27 ,99)
			WHEN substr(def_width,length(def_width) - 29 ,1) = ' ' THEN substr(def_width,length(def_width) - 28 ,99)
			WHEN substr(def_width,length(def_width) - 30 ,1) = ' ' THEN substr(def_width,length(def_width) - 29 ,99)
			WHEN substr(def_width,length(def_width) - 31 ,1) = ' ' THEN substr(def_width,length(def_width) - 30 ,99)
			WHEN substr(def_width,length(def_width) - 32 ,1) = ' ' THEN substr(def_width,length(def_width) - 31 ,99)
			WHEN substr(def_width,length(def_width) - 33 ,1) = ' ' THEN substr(def_width,length(def_width) - 32 ,99)
			WHEN substr(def_width,length(def_width) - 34 ,1) = ' ' THEN substr(def_width,length(def_width) - 33 ,99)
			WHEN substr(def_width,length(def_width) - 35 ,1) = ' ' THEN substr(def_width,length(def_width) - 34 ,99)
			WHEN substr(def_width,length(def_width) - 36 ,1) = ' ' THEN substr(def_width,length(def_width) - 35 ,99)
			WHEN substr(def_width,length(def_width) - 37 ,1) = ' ' THEN substr(def_width,length(def_width) - 36 ,99)
			WHEN substr(def_width,length(def_width) - 38 ,1) = ' ' THEN substr(def_width,length(def_width) - 37 ,99)
			WHEN substr(def_width,length(def_width) - 39 ,1) = ' ' THEN substr(def_width,length(def_width) - 38 ,99)
			WHEN substr(def_width,length(def_width) - 40 ,1) = ' ' THEN substr(def_width,length(def_width) - 39 ,99)
			WHEN substr(def_width,length(def_width) - 41 ,1) = ' ' THEN substr(def_width,length(def_width) - 40 ,99)
	ELSE '0.0'
	END
	END	as waterbreedte
	FROM v2_cross_section_view 
	ORDER BY length(def_width) 
	), list_start AS (
		SELECT waterbreedte.*,  v2_channel.connection_node_start_id, v2_channel.connection_node_end_id, ST_LineLocatePoint(v2_channel.the_geom,waterbreedte.the_geom) as location -- Let op: LineLocatePoint is afhankelijk van postgis versie met _ Line_Locate_point
		FROM waterbreedte
		LEFT JOIN v2_channel
		ON waterbreedte.channel_id = v2_channel.id
		ORDER BY ST_LineLocatePoint(v2_channel.the_geom,waterbreedte.the_geom) ASC)
	, list_end AS (
		SELECT waterbreedte.*,  v2_channel.connection_node_start_id, v2_channel.connection_node_end_id, ST_LineLocatePoint(v2_channel.the_geom,waterbreedte.the_geom) as location
		FROM waterbreedte
		LEFT JOIN v2_channel
		ON waterbreedte.channel_id = v2_channel.id
		ORDER BY ST_LineLocatePoint(v2_channel.the_geom,waterbreedte.the_geom) DESC)
	, width_channel_at_node AS (
		SELECT DISTINCT ON (channel_id) channel_id, l_id, l_code, l_reference_level, l_definition_id, def_shape, def_width, the_geom, waterbreedte, connection_node_start_id as nearest_node, location
		FROM list_start 
		--GROUP BY channel_id
		UNION ALL
		SELECT  DISTINCT ON (channel_id) channel_id, l_id, l_code, l_reference_level, l_definition_id, def_shape, def_width, the_geom, waterbreedte, connection_node_end_id as nearest_node, location
		FROM list_end 
		--GROUP BY channel_id
		)
	, joined_list as (
		SELECT  duikerbreedte.*, width_channel_at_node.waterbreedte as waterbreedte, 
		width_channel_at_node.waterbreedte::numeric / duikerbreedte.duikerbreedte::numeric as factor
		FROM duikerbreedte
		JOIN width_channel_at_node
		ON width_channel_at_node.nearest_node = duikerbreedte.cul_connection_node_start_id OR width_channel_at_node.nearest_node = duikerbreedte.cul_connection_node_end_id )
SELECT DISTINCT ON (cul_id) * FROM joined_list
WHERE factor > 3.0 
--GROUP BY cul_id
;

	INSERT INTO v2_orifice
		   ( id
				, display_name
				, code
				, crest_level
				, sewerage
				, cross_section_definition_id
				, friction_value
				, friction_type
				, discharge_coefficient_positive
				, discharge_coefficient_negative
				, zoom_category
				, crest_type
				, connection_node_start_id
				, connection_node_end_id
		   )
	SELECT
		   id+10000000
		 , display_name
		 , code
		 , greatest(invert_level_start_point,invert_level_end_point)
		 , FALSE
		 , cross_section_definition_id
		 , friction_value
		 , friction_type
		 , discharge_coefficient_positive
		 , discharge_coefficient_negative
		 , zoom_category, 4
		 , connection_node_start_id
		 , connection_node_end_id
	FROM
		   v2_culvert
	WHERE id IN (SELECT cul_id FROM tmp.v2_culvert_to_orifice)
	;


	UPDATE
		   v2_control_table
	SET    target_type = 'v2_orifice'
		 , target_id   = target_id+10000000
	WHERE
		   target_id IN
		   (SELECT cul_id FROM tmp.v2_culvert_to_orifice)
		   AND target_type = 'v2_culvert'
	;
	DELETE FROM v2_culvert
	WHERE id IN (SELECT cul_id FROM tmp.v2_culvert_to_orifice)
	;

UPDATE v2_orifice
SET crest_type = 3
WHERE substr(code,1,3) = 'KDU'
;

UPDATE v2_orifice
SET discharge_coefficient_negative = 1.0
WHERE discharge_coefficient_negative > 0
;
UPDATE v2_orifice
SET discharge_coefficient_positive = 1.0
WHERE discharge_coefficient_positive > 0
;
UPDATE v2_culvert
SET discharge_coefficient_negative = 1.0
WHERE discharge_coefficient_negative > 0
;
UPDATE v2_culvert
SET discharge_coefficient_positive = 1.0
WHERE discharge_coefficient_positive > 0
;

UPDATE v2_connection_nodes
SET storage_area = 1.0
WHERE id IN (
		SELECT connection_node_start_id FROM v2_culvert
		UNION ALL
		SELECT connection_node_end_id FROM v2_culvert ) 
	AND (storage_area IS NULL OR storage_area < 1.0)
;




--UPDATE control structures (change v2_culvert to v2_orifice and add +100000 to the id)
UPDATE
       v2_control_table
SET    target_type = 'v2_orifice'
     , target_id   = target_id+10000000
WHERE
       target_id IN
       (
              SELECT
                     id
              FROM
                     tmp.culvert_to_orifice
       )
       AND target_type = 'v2_culvert'
;
