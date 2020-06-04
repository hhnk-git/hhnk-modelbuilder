/* This script aggregates the feedback of the different scripts in one table

-------------------------------------------------------------
|  fid   |   level   |   geometry   |    feedback message   |
-------------------------------------------------------------
   int      info		(multi)point		text
			warning		(multi)line
			error		(multi)polygon
*/


--DELETE old table and create new table		
DROP TABLE IF EXISTS deelgebied.feedback;
CREATE TABLE deelgebied.feedback
(
  id bigint,
  level character varying(7),
  feature_id bigint,
  table_name character varying(50),
  geom geometry,
  message text,
  CONSTRAINT feedback_pkey PRIMARY KEY (id)
);

DROP SEQUENCE IF EXISTS seq_feedback_id;
CREATE SEQUENCE seq_feedback_id START 1;


--Cross section locations without definition
INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_cross_section_location', the_geom, remark
FROM feedback.xs_locations_without_definition;




--Channels without xs-locations
INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_channel', ST_LineInterpolatePoint(the_geom, 0.5), remark
FROM feedback.channel_without_xs_location;


INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_cross_section_location', the_geom, remark
FROM feedback.missing_friction;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_cross_section_location', the_geom, remark
FROM feedback.xs_location_lowered_reference_level;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_cross_section_location', the_geom, remark
FROM feedback.xs_location_increased_bank_level;

--Culverts

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_culvert', the_geom, remark
FROM feedback.culvert_without_xs;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_cross_section_location', the_geom, remark
FROM feedback.lowered_reference_level_culvert;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_culvert', the_geom, remark
FROM feedback.culvert_without_invert_level;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'INFO', id, 'v2_connection_nodes', the_geom, remark
FROM feedback.culvert_connection_node_without_channel;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_culvert', the_geom, remark
FROM feedback.culvert_with_invalid_geometry;

--Weirs (TODO make midpoints of start/end nodes

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_weir', the_geom, remark
FROM feedback.weir_without_xs_definition;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'INFO', id, 'v2_connection_nodes', the_geom, remark
FROM feedback.weir_connection_node_without_channel;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_cross_section_location', the_geom, remark
FROM feedback.lowered_reference_level_weir;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_weir', the_geom, remark
FROM feedback.weir_without_crest_level;

--Orifice
INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_orifice', the_geom, remark
FROM feedback.orifice_without_xs_definition;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'INFO', id, 'v2_connection_nodes', the_geom, remark
FROM feedback.orifice_connection_node_without_channel;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_cross_section_location', the_geom, remark
FROM feedback.lowered_reference_level_orifice;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_orifice', the_geom, remark
FROM feedback.orifice_without_crest_level;


--Pumpstation
INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_cross_section_location', the_geom, remark
FROM feedback.lowered_reference_level_pumpstation;

--Connection nodes
INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_connection_nodes', the_geom, remark
FROM feedback.loose_connection_nodes;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_connection_nodes', the_geom, remark
FROM feedback.connection_node_only_connected_to_pump;

INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_connection_nodes', the_geom, remark
FROM feedback.connection_node_without_initial_waterlevel;

--Boundary condition
INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'ERROR', id, 'v2_1d_boundary_condition', the_geom, remark
FROM feedback.boundaries_with_multiple_connections;

--channels
INSERT INTO deelgebied.feedback(id, level, feature_id, table_name, geom, message)
SELECT nextval('seq_feedback_id'), 'WARNING', id, 'v2_channel', ST_LineInterpolatePoint(the_geom, 0.5), remark
FROM feedback.short_lines;