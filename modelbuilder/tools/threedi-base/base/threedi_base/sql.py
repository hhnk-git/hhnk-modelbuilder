# -*- coding: utf-8 -*-

snap_start_end = """
-- maak nieuwe kruispunten
DROP TABLE IF EXISTS {schema}.tmp_snappoints;
CREATE TABLE {schema}.tmp_snappoints AS WITH nodes AS
(
  SELECT
    ST_Startpoint({geom_column}) as geom
  FROM
    {schema}.{input_table}
  UNION
  SELECT
    ST_Endpoint({geom_column}) as geom
  FROM
    {schema}.{input_table}
)
SELECT
  ST_Centroid((ST_Dump(ST_Union(ST_Buffer(geom, {snap_distance})))).geom) as geom
FROM
  nodes ;
CREATE INDEX idx_tmp_snappoints
ON {schema}.tmp_snappoints USING gist(geom);

-- maak multipoint
DROP TABLE IF EXISTS {schema}.tmp_snappoints_union;
CREATE TABLE {schema}.tmp_snappoints_union AS
SELECT
  ST_SnapToGrid(
    ST_Union(
      {geom_column}
    )
    , 0,0,0.1,0.1) AS geom
FROM
  {schema}.tmp_snappoints ;
CREATE INDEX idx_tmp_snappoints_union
ON {schema}.tmp_snappoints_union USING gist(geom);

--snappen naar nieuwe kruispunten
DROP TABLE IF EXISTS {schema}.{output_table};
CREATE TABLE {schema}.{output_table} AS
SELECT DISTINCT
  ON (a.id) ST_Snap(
              a.{geom_column}
              , b.{geom_column}
              , {snap_distance}
            ) AS geom,
     a.id
FROM
  {schema}.{input_table} as a,
  {schema}.tmp_snappoints as b
WHERE
  ST_DWithin(a.{geom_column}, b.{geom_column}, {snap_distance})
ORDER BY
  id,
  ST_Distance(a.{geom_column}, b.{geom_column}) DESC ;
CREATE INDEX idx_{output_table}
ON {schema}.{output_table} USING gist(geom);
"""


simplify_lines = """
DROP SEQUENCE IF EXISTS simple_seq_id;
CREATE SEQUENCE simple_seq_id;

DROP TABLE IF EXISTS {schema}.{output_table};
CREATE TABLE {schema}.{output_table} AS
SELECT
  (ST_Dump(
    ST_LineMerge(
      ST_Union(
        ST_SnapToGrid(
          a.{geom_column}, 0, 0, 0.05, 0.05
        )
      )
    )
  )).geom AS geom,
  nextval('simple_seq_id') AS id
FROM
  {schema}.{input_table} as a;
"""

remove_short_lines = """
-- Verwijder ook lijnen korter dan de snap distance in tool 02_snap_start_end
DELETE FROM
  {schema}.{table_name}
WHERE
  ST_Length({geom_column}) < {minimum_line_len}
;
"""


# 5) Opknippen circulaire lijnsegmenten
# Watergangen mogen niet hetzelfde begin als eindpunt hebben. We knippen ze
# in twee stukken

cut_circular = """
DROP SEQUENCE IF EXISTS id;
CREATE SEQUENCE id;

DROP TABLE IF EXISTS {schema}.{output_table};
CREATE TABLE {schema}.{output_table} as
SELECT
  ST_SnapToGrid(
    ST_LineSubstring({geom_column}, 0, 0.5), 0, 0, 0.05, 0.05) as geom,
  nextval('id') as id
FROM
  {schema}.{input_table}
WHERE
  ST_IsClosed({geom_column}) --OR count > 1
UNION ALL
SELECT
  ST_SnapToGrid(
    ST_LineSubstring({geom_column}, 0.5, 1), 0, 0, 0.05, 0.05) as geom,
  nextval('id') as id
FROM
  {schema}.{input_table}
WHERE
  ST_IsClosed({geom_column}) --OR count > 1
UNION ALL
SELECT
  ST_SnapToGrid({geom_column}, 0, 0, 0.05, 0.05) as geom,
  nextval('id') as id
FROM
  {schema}.{input_table}
WHERE
  ST_IsClosed({geom_column}) IS FALSE -- AND count = 1
;

-- worden er minder door verwijderen lege geometrien
CREATE INDEX idx_{output_table}
ON {schema}.{output_table} USING gist(geom);
"""


# ​6) Toevoegen duikers en sifons
# W: de verwijderde duikers en sifons weer toevoegen aan de rest van het netwerk
# I: vereenvoudigd netwerk 2
# M: voeg duiker en sifon lijnen toe, snap begin en eindpunten met tolerantie van xx
# O: vereenvoudigd netwerk 300


# 7)
# W: stuwen en gemalen moeten ook lijnen worden, stukjes van kanalennetwerk gebruiken. Niet de duikers en sifons gebruiken.
# I: Netwerk van watergangen, punten gemalen en stuwen, standaard waarde voor lengte nieuwe lijnsegmenten (5m), waarde voor minimale afstand tot eindpunt in netwerk om korte segmenten te voorkomen (bijvoorbeeld 10m)
# ---
# Required context variables for rendering linify_structures_template:
# - schema: e.g. 'deelgebied'
# - structure_tables: e.g. ['pumpstation', 'weirs', 'bridge']
# - channel_table: e.g. 'clipped_channel'
linify_structures_template = """
{% for structure_table in structure_tables %}
-- copy structure tables to new tables with postfix '_linified'
DROP TABLE IF EXISTS {{ schema }}.{{ structure_table }}_linified;
CREATE TABLE {{ schema }}.{{ structure_table }}_linified AS SELECT * FROM {{ schema }}.{{ structure_table }};

DO $$
    BEGIN
        BEGIN
            ALTER TABLE {{ schema }}.{{ structure_table }}_linified ADD COLUMN channel_code INTEGER;
        EXCEPTION
            WHEN duplicate_column THEN RAISE NOTICE 'column channel_code already exists in {{ schema }}.{{ structure_table }}_linified.';
        END;
    END;
$$
;

DROP TABLE IF EXISTS {{ schema }}.tmp_sel_{{ structure_table }};
CREATE TABLE {{ schema }}.tmp_sel_{{ structure_table }}
(
  id serial NOT NULL,
  code character varying(100) NOT NULL,
  sewerage boolean NOT NULL,
  connection_node_start_id integer,
  connection_node_end_id integer
)
WITH (
  OIDS=FALSE
);

-- connect the structures to the nearest channels
UPDATE {{ schema }}.{{ structure_table }}_linified SET channel_code = NULL;
UPDATE {{ schema }}.{{ structure_table }}_linified AS a
SET channel_code = b.id
FROM {{ schema }}.{{ channel_table }} AS b
WHERE ST_DWithin(a.geom, b.geom, 0.1) -- TODO: verbeteren manier van koppelen en zoekafstand kiezen
;
DROP TABLE IF EXISTS {{ schema }}.{{ structure_table }}_misfits;
CREATE TABLE {{ schema }}.{{ structure_table }}_misfits AS
SELECT * FROM {{ schema }}.{{ structure_table }}_linified WHERE channel_code IS NULL
;
DELETE FROM {{ schema }}.{{ structure_table }}_linified
WHERE channel_code IS NULL
;

-- create indices
CREATE INDEX {{ schema }}_{{ structure_table }}_linified_geom ON {{ schema }}.{{ structure_table }}_linified USING GIST(geom);
CREATE INDEX {{ schema }}_{{ structure_table }}_linified_channel_code ON {{ schema }}.{{ structure_table }}_linified USING BTREE(channel_code);
{% endfor %}

DROP TABLE IF EXISTS {{ schema }}.tmp_connection_nodes_structures;
CREATE TABLE {{ schema }}.tmp_connection_nodes_structures AS SELECT * FROM {{ schema }}.v2_connection_nodes LIMIT 0;

DROP SEQUENCE IF EXISTS nodeserial;
CREATE SEQUENCE nodeserial;
DROP SEQUENCE IF EXISTS structureserial;
CREATE SEQUENCE structureserial;

-- start verlijnen script
DELETE FROM {{ schema }}.tmp_connection_nodes_structures;
SELECT setval('nodeserial', 1);
WITH reversed_channels AS (
    SELECT id, geom
    FROM {{ schema }}.{{ channel_table }}
)
{% for structure_table in structure_tables %}
, select_{{ structure_table }}_start_end AS (
    -- verlijnen van de structures rekening houdend met een minimale kanaallengte van 5 meter
	SELECT DISTINCT ON (a.id) nextval('structureserial') AS structure_id, '{{ structure_table }}'::text AS structure_type,
	    a.code, 5 AS length,
		CASE WHEN (ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom)-5.0/2<5) THEN 0
		     WHEN (ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom)-5.0/2>=5) AND (ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom)+5.0/2>ST_Length(b.geom)-5) THEN ST_Length(b.geom)-5
		     ELSE ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom)-5.0/2
		END AS start_point,
		ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom) AS centre_point,
		CASE WHEN (ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom)-5.0/2<5) AND (5>ST_Length(b.geom)-5) THEN ST_Length(b.geom)
		     WHEN (ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom)-5.0/2<5) AND (5<ST_Length(b.geom)-5) THEN 5
		     WHEN (ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom)-5.0/2>=5) AND (ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom)+5.0/2>ST_Length(b.geom)-5) THEN ST_Length(b.geom)
		     ELSE ST_LineLocatePoint(b.geom, a.geom)*ST_Length(b.geom)+5.0/2
		END AS end_point,
	ST_Length(b.geom) AS channel_length, b.id AS branch_code, b.geom AS branch_geom
	FROM {{ schema }}.{{ structure_table }}_linified AS a
	JOIN reversed_channels b ON a.channel_code::text = b.id::text
	ORDER BY a.id
	)
{% endfor %}
, select_union_structures AS (
    {% for structure_table in structure_tables %}
    SELECT * FROM select_{{ structure_table }}_start_end
    {% if not forloop.last %}UNION{% endif %}
	{% endfor %}
)
, select_overlapping_structures_temp AS (
	-- update van overlappende structures rekening houdend met een minimale kanaallengte van 5 meter
	SELECT DISTINCT b.structure_id, b.centre_point AS centre_structure_b, b.structure_type, b.length,
		CASE WHEN b.centre_point < a.centre_point THEN 'upstream'
			ELSE 'downstream'
		END AS loc,
		     --	   SELECT upstream			DETERMINE IF NEW START_POINT < TOLERANCE
		CASE WHEN (b.centre_point < a.centre_point) AND (((b.centre_point + (a.centre_point - b.centre_point)/2) - b.length) < 5) THEN 0
		     --	   SELECT upstream			DETERMINE IF NEW OTHER_END_POINT > TOLERANCE
		     WHEN (b.centre_point < a.centre_point) AND (((a.centre_point - (a.centre_point - b.centre_point)/2) + a.length) > b.channel_length - 5) THEN greatest(b.channel_length-a.length-b.length,0)
		     --	   SELECT upstream			DETERMINE IF NEW START_POINT > TOLERANCE
		     WHEN (b.centre_point < a.centre_point) AND (((b.centre_point + (a.centre_point - b.centre_point)/2) - b.length) > 5) THEN (b.centre_point + (a.centre_point - b.centre_point)/2) - b.length
		     --	   SELECT downstream			DETERMINE IF NEW OTHER_START_POINT < TOLERANCE
		     WHEN (b.centre_point > a.centre_point) AND (((a.centre_point + (b.centre_point - a.centre_point)/2) - a.length) < 5) THEN least(a.length,greatest(b.channel_length-b.length,5))
		     --	   SELECT downstream			DETERMINE IF NEW END_POINT > TOLERANCE
		     WHEN (b.centre_point > a.centre_point) AND (((b.centre_point - (b.centre_point - a.centre_point)/2) + b.length) > b.channel_length - 5) THEN greatest(b.channel_length-b.length, a.length)
		     --	   SELECT downstream			DETERMINE IF NEW END_POINT < TOLERANCE
		     ELSE (a.centre_point - (a.centre_point - b.centre_point)/2)
		END AS new_structure_start_point,
		CASE WHEN (b.centre_point < a.centre_point) AND (((b.centre_point + (a.centre_point - b.centre_point)/2) - b.length) < 5) THEN least(b.length,greatest(b.channel_length-a.length,5))
		     WHEN (b.centre_point < a.centre_point) AND (((a.centre_point - (a.centre_point - b.centre_point)/2) + a.length) > b.channel_length - 5) THEN greatest(b.channel_length-a.length, b.length)
		     WHEN (b.centre_point < a.centre_point) AND (((b.centre_point + (a.centre_point - b.centre_point)/2) - b.length) > 5) THEN (b.centre_point + (a.centre_point - b.centre_point)/2)
		     WHEN (b.centre_point > a.centre_point) AND (((a.centre_point + (b.centre_point - a.centre_point)/2) - a.length) < 5) THEN least(b.length+a.length, b.channel_length)
		     WHEN (b.centre_point > a.centre_point) AND (((b.centre_point - (b.centre_point - a.centre_point)/2) + b.length) > b.channel_length - 5) THEN b.channel_length
			ELSE (a.centre_point - (a.centre_point - b.centre_point)/2)+5
		END AS new_structure_end_point,
		 b.channel_length, a.structure_id AS structure_id_a, a.centre_point AS centre_structure_a, b.branch_geom, b.branch_code
	FROM select_union_structures a, select_union_structures b
	WHERE a.branch_code = b.branch_code AND a.structure_id != b.structure_id AND b.start_point < a.end_point+5 AND b.end_point+5 > a.start_point
	)
	,select_overlapping_structures AS (
		SELECT *
		FROM select_overlapping_structures_temp
		WHERE structure_id NOT IN (SELECT structure_id FROM select_overlapping_structures_temp GROUP BY structure_id HAVING count(*) > 1)
		)
, connection_nodes AS (
	-- aanmaken van connection_nodes
	INSERT INTO {{ schema }}.tmp_connection_nodes_structures(id, storage_area, the_geom)
	SELECT DISTINCT ON (geom) * FROM (
		SELECT nextval('nodeserial') AS id, NULL::float AS storage_area, ST_LineInterpolatePoint(branch_geom, a.start_point/channel_length) AS geom
		FROM select_union_structures a
		WHERE structure_id NOT IN (SELECT structure_id FROM select_overlapping_structures UNION SELECT structure_id FROM select_overlapping_structures_temp GROUP BY structure_id HAVING count(*) > 1)
		UNION
		SELECT nextval('nodeserial') AS id, NULL AS storage_area, ST_LineInterpolatePoint(branch_geom, a.end_point/channel_length) AS geom
		FROM select_union_structures a
		WHERE structure_id NOT IN (SELECT structure_id FROM select_overlapping_structures UNION SELECT structure_id FROM select_overlapping_structures_temp GROUP BY structure_id HAVING count(*) > 1)
		UNION
		SELECT nextval('nodeserial') AS id, NULL AS storage_area, ST_LineInterpolatePoint(branch_geom, a.new_structure_start_point/channel_length) AS geom
		FROM select_overlapping_structures a
		UNION
		SELECT nextval('nodeserial') AS id, NULL AS storage_area, ST_LineInterpolatePoint(branch_geom, a.new_structure_end_point/channel_length) AS geom
		FROM select_overlapping_structures a
		UNION
		SELECT nextval('nodeserial') AS id, NULL AS storage_area, ST_LineInterpolatePoint(geom, 0) AS geom
		FROM {{ schema }}.{{ channel_table }}
		UNION
		SELECT nextval('nodeserial') AS id, NULL AS storage_area, ST_LineInterpolatePoint(geom, 1) AS geom
		FROM {{ schema }}.{{ channel_table }}
		) AS foo
        RETURNING *
)
{% for structure_table in structure_tables %}
, insert_{{ structure_table }} AS (
     INSERT INTO {{ schema }}.tmp_sel_{{ structure_table }}(
            id, code, sewerage,
            connection_node_start_id, connection_node_end_id)
     SELECT a.structure_id AS id,
        a.code AS code,
        FALSE AS sewerage,
        s.id AS connection_node_start_id,
        e.id AS connection_node_end_id
    FROM connection_nodes AS s, connection_nodes AS e, select_union_structures a
    LEFT JOIN select_overlapping_structures c ON a.structure_id=c.structure_id AND a.structure_type = c.structure_type
    WHERE a.structure_type = '{{ structure_table }}'
    AND ST_DWithin(ST_LineInterpolatePoint(a.branch_geom, CASE WHEN c.new_structure_start_point >= 0 THEN c.new_structure_start_point ELSE a.start_point END/a.channel_length), s.the_geom,0.01)
    AND ST_DWithin(ST_LineInterpolatePoint(a.branch_geom, CASE WHEN c.new_structure_end_point >= 0 THEN c.new_structure_end_point ELSE a.end_point END/a.channel_length), e.the_geom,0.01)
    RETURNING *
)
{% endfor %}

-- clip branches onto structures
SELECT setval('nodeserial', 1);
DROP TABLE IF EXISTS {{ schema }}.tmp_sel_branches_without_structures;
CREATE TABLE {{ schema }}.tmp_sel_branches_without_structures AS
WITH select_reaches AS (
    SELECT  b.id, a.id AS start_id, lead(a.id) OVER (PARTITION BY b.id ORDER BY ST_LineLocatePoint(b.geom, a.the_geom)) AS end_id,
	rank() OVER (PARTITION BY b.id ORDER BY ST_LineLocatePoint(b.geom, a.the_geom)) AS rank,
	b.geom, ST_LineLocatePoint(b.geom, a.the_geom) AS start_fraction,
	ST_LineLocatePoint(b.geom, lead(a.the_geom) OVER (PARTITION BY b.id ORDER BY ST_LineLocatePoint(b.geom, a.the_geom))) AS end_fraction
    FROM {{ schema }}.tmp_connection_nodes_structures a
    JOIN {{ schema }}.{{ channel_table }} b
    ON ST_DWithin(a.the_geom, b.geom, 0.01)
)
SELECT nextval('nodeserial') AS reach_id, id, id || '_' || rank AS reach_code, start_id AS connection_node_start_id, end_id AS connection_node_end_id,
	ST_LineSubstring(a.geom, start_fraction, end_fraction) AS geom
FROM select_reaches a
WHERE a.end_id IS NOT NULL
    {% for structure_table in structure_tables %}
    AND CONCAT(start_id, ' ', end_id) NOT IN (SELECT CONCAT(connection_node_start_id, ' ', connection_node_end_id) FROM {{ schema }}.tmp_sel_{{ structure_table }})
    {% endfor %}
;

-- clean out some odd geometries
DELETE FROM {{ schema }}.tmp_sel_branches_without_structures
WHERE ST_GeometryType(geom) NOT LIKE 'ST_LineString' OR geom IS NULL
;
	
-- snap connection nodes geometries	
UPDATE {{ schema }}.tmp_connection_nodes_structures
SET the_geom = ST_SnapToGrid(the_geom,0,0,0.05,0.05)
;

-- connect lines to nodes
CREATE INDEX {{ schema }}_tmp_connection_nodes_structures_geom ON {{ schema }}.tmp_connection_nodes_structures USING gist(the_geom);
CREATE INDEX {{ schema }}_tmp_sel_branches_without_structures_geom ON {{ schema }}.tmp_sel_branches_without_structures USING gist(geom);

UPDATE {{ schema }}.tmp_sel_branches_without_structures AS a
SET geom = ST_SetPoint(a.geom,0,b.the_geom)
FROM {{ schema }}.tmp_connection_nodes_structures AS b
WHERE a.connection_node_start_id = b.id
;
UPDATE {{ schema }}.tmp_sel_branches_without_structures AS a
SET geom = ST_SetPoint(a.geom, ST_NumPoints(geom) - 1,b.the_geom)
FROM {{ schema }}.tmp_connection_nodes_structures AS b
WHERE a.connection_node_end_id = b.id
;
"""

# 8) Oplossen korte segmenten
# W: Er kunnen nog korte segmenten in het netwerk zitten, die willen we niet voor snellere modellen
# I: channel, culvert, pumpstation en weir
# M: zoeken naar kleine stukken en deze samenvoegen met die in de buurt liggen. Of dit vanuit start of eindpunt gebeurt is willekeurig.Alleen channel en culvert worden aangepast
# O: turtle met minder korte kanalen en duikers

# 8.1) Create 'remove' table

fix_short_segments_create_remove_table = """
-- dingen die zullen worden verwijderd
DROP TABLE IF EXISTS {schema}.{remove_table};
CREATE TABLE {schema}.{remove_table} (
  modid INT,
  newgeom geometry(MultiLineString, 28992),
  removeid INT,
  replaceid INT,
  remove_reach INT
  );
"""

# 8.2) Channels

fix_short_segments_channel = """
-- knoop het eindpunt van een channel aan het eindpunt van een kort kanaal
WITH shortlist
AS (
  SELECT reach_id,
    connection_node_start_id AS removeid,
    connection_node_end_id AS replaceid,
    {geom_column} AS addgeom
  FROM {schema}.{channel_table}
  WHERE ST_Length({geom_column}) < {min_distance}
  ),
mod
AS (
  INSERT INTO {schema}.{remove_table}
  SELECT a.reach_id AS modid,
    ST_Multi(ST_Linemerge(ST_Union(a.{geom_column}, b.addgeom))) AS newgeom,
    b.removeid,
    b.replaceid,
    b.reach_id AS remove_reach -- volgorde union aanpassen bij start/eind?
  FROM {schema}.{channel_table} AS a -- PAS HIER BRANCHE TYPE AAN
  LEFT JOIN shortlist AS b ON a.connection_node_end_id = b.removeid
  -- PAS HIER START OF EIND AAN
  WHERE b.removeid IS NOT NULL
    AND a.reach_id NOT IN (
      SELECT reach_id
      FROM shortlist
      ) RETURNING *
  )
UPDATE {schema}.{channel_table} AS a
SET connection_node_end_id = b.replaceid,
  {geom_column} = b.newgeom -- PAS HIER START OF EIND AAN
FROM mod AS b
WHERE a.reach_id = b.modid
;

-- knoop het startpunt van een channel aan het eindpunt van een kort kanaal
WITH shortlist
AS (
  SELECT reach_id,
    connection_node_start_id AS removeid,
    connection_node_end_id AS replaceid,
    {geom_column} AS addgeom
  FROM {schema}.{channel_table}
  WHERE ST_Length({geom_column}) < {min_distance}
  ),
mod
AS (
  INSERT INTO {schema}.{remove_table}
  SELECT a.reach_id AS modid,
    ST_Multi(ST_Linemerge(ST_Union(a.{geom_column}, b.addgeom))) AS newgeom,
    b.removeid,
    b.replaceid,
    b.reach_id AS remove_reach -- volgorde union aanpassen bij start/eind?
  FROM {schema}.{channel_table} AS a -- PAS HIER BRANCHE TYPE AAN
  LEFT JOIN shortlist AS b ON a.connection_node_start_id = b.removeid
  -- PAS HIER START OF EIND AAN
  WHERE b.removeid IS NOT NULL
    AND a.reach_id NOT IN (
      SELECT reach_id
      FROM shortlist
      ) RETURNING *
  )
UPDATE {schema}.{channel_table} AS a
SET connection_node_start_id = b.replaceid,
  {geom_column} = b.newgeom -- PAS HIER START OF EIND AAN
FROM mod AS b
WHERE a.reach_id = b.modid ;
"""

# 8.3) Culverts

fix_short_segments_culvert = """
-- knoop het eindpunt van een culvert aan het eindpunt van een kort kanaal
WITH shortlist
AS (
  SELECT reach_id,
    connection_node_start_id AS removeid,
    connection_node_end_id AS replaceid,
    {geom_column} AS addgeom
  FROM {schema}.{channel_table} -- DIT BLIJFT ALTIJD CHANNEL
  WHERE ST_Length({geom_column}) < {min_distance}
  ),
mod
AS (
  INSERT INTO {schema}.{remove_table}
  SELECT a.id AS modid,
    ST_Multi(ST_Linemerge(ST_Union(a.{culvert_geom_column}, b.addgeom))) AS newgeom,
    b.removeid,
    b.replaceid,
    b.reach_id AS remove_reach -- volgorde union aanpassen bij start/eind?
  FROM {schema}.tmp_sel_{culvert_table} AS a
  LEFT JOIN shortlist AS b ON a.connection_node_end_id = b.removeid
  -- PAS HIER START OF EIND AAN
  -- PAS HIER START OF EIND AAN
  WHERE b.removeid IS NOT NULL RETURNING *
  )
UPDATE {schema}.tmp_sel_{culvert_table} AS a -- PAS HIER BRANCHE TYPE AAN
SET connection_node_end_id = b.replaceid,
  {culvert_geom_column} = b.newgeom -- PAS HIER START OF EIND AAN
FROM mod AS b
WHERE a.id = b.modid ;

-- knoop het startpunt van een culvert aan het eindpunt van een kort kanaal
WITH shortlist AS (
SELECT reach_id,
  connection_node_start_id AS removeid,
  connection_node_end_id AS replaceid,
  {geom_column} AS addgeom
FROM {schema}.{channel_table}
WHERE ST_Length({geom_column}) < {min_distance}
),
mod AS (
INSERT INTO {schema}.{remove_table}
SELECT a.id AS modid,
  ST_Multi(ST_Linemerge(ST_Union(a.{culvert_geom_column}, b.addgeom))) AS newgeom,
  b.removeid,
  b.replaceid,
  b.reach_id AS remove_reach -- volgorde union aanpassen bij start/eind?
FROM {schema}.tmp_sel_{culvert_table} AS a -- PAS HIER BRANCHE TYPE AAN
LEFT JOIN shortlist AS b ON a.connection_node_start_id = b.removeid
-- PAS HIER START OF EIND AAN
WHERE
  b.removeid IS NOT NULL RETURNING *
)

UPDATE {schema}.tmp_sel_{culvert_table} AS a
SET connection_node_start_id = b.replaceid,
  {culvert_geom_column} = b.newgeom -- PAS HIER START OF EIND AAN
FROM mod AS b
WHERE a.id = b.modid;
"""

# 8.4) Structures (pumpstations, weirs, etc.)

# NOTE: 'tmp_sel_' wordt gebruikt als prefix voor de kunstwerknaam

fix_short_segments_structure = """
-- knoop het eindpunt van een kunstwerk aan het eindpunt van een kort kanaal
WITH shortlist
AS (
  SELECT reach_id,
    connection_node_start_id AS removeid,
    connection_node_end_id AS replaceid,
    {geom_column} AS addgeom
  FROM {schema}.{channel_table} -- DIT BLIJFT ALTIJD CHANNEL
  WHERE ST_Length({geom_column}) < {min_distance}
  ),
mod
AS (
  INSERT INTO {schema}.{remove_table}
  SELECT a.id AS modid,
    NULL AS newgeom,
    b.removeid,
    b.replaceid,
    b.reach_id AS remove_reach -- volgorde union aanpassen bij start/eind?
  FROM {schema}.tmp_sel_{structure_name} AS a
  LEFT JOIN shortlist AS b ON a.connection_node_end_id = b.removeid
  -- PAS HIER START OF EIND AAN
  WHERE b.removeid IS NOT NULL RETURNING *
  )
UPDATE {schema}.tmp_sel_{structure_name} AS a -- PAS HIER BRANCHE TYPE AAN
SET connection_node_end_id = b.replaceid -- PAS HIER START OF EIND AAN
FROM mod AS b
WHERE a.id = b.modid;

-- knoop het startpunt van een kunstwerk aan het eindpunt van een kort kanaal
WITH shortlist
AS (
  SELECT reach_id,
    connection_node_start_id AS removeid,
    connection_node_end_id AS replaceid,
    {geom_column} AS addgeom
  FROM {schema}.{channel_table}
  WHERE ST_Length({geom_column}) < {min_distance}
  ),
mod
AS (
  INSERT INTO {schema}.{remove_table}
  SELECT a.id AS modid,
    NULL AS newgeom,
    b.removeid,
    b.replaceid,
    b.reach_id AS remove_reach -- volgorde union aanpassen bij start/eind?
  FROM {schema}.tmp_sel_{structure_name} AS a -- PAS HIER BRANCHE TYPE AAN
  LEFT JOIN shortlist AS b ON a.connection_node_start_id = b.removeid
  -- PAS HIER START OF EIND AAN
  WHERE b.removeid IS NOT NULL RETURNING *
  )
UPDATE {schema}.tmp_sel_{structure_name} AS a -- PAS HIER BRANCHE TYPE AAN
SET connection_node_start_id = b.replaceid -- PAS HIER START OF EIND AAN
FROM mod AS b
WHERE a.id = b.modid;
"""

# 8.5) Clean up short reaches

fix_short_segments_cleanup_reaches = """
-- opruimen korte reaches
DELETE
FROM {schema}.{channel_table}
WHERE reach_id IN (
    SELECT remove_reach
    FROM {schema}.{remove_table}
    );
"""

# 9) Profiel toekennen aan watergangen
# W: elk kanaal moet een profiel krijgen
# I: kanalen netwerk en originele watergangen en evt. extra ingemeten
# profielen
# M: Van elk origineel kanaal een punt maken en die koppelen aan het nieuwe
# netwerk. Extra ingemeten profielen hebben een eigen locatie en overrulen de
# profielen van de originele watergangen.
# In de methode hieronder gebruik gemaakt van bestaande profiel locaties. Als
# die er niet zijn middelpunt van originele watergangen (hydra core). Not
# een uitzondering: in hellend gebied soms een profiel aan het begin en eind
# van elke watergang (daarvoor zijn aparte velden) Voor BWN is dit niet het
# geval.
# O: profielen met locatie en tabel


assign_cross_section = """
DROP SEQUENCE IF EXISTS {schema}.v2_cross_section_definition_id_seq;
CREATE SEQUENCE {schema}.v2_cross_section_definition_id_seq;

DROP TABLE IF EXISTS {schema}.tmp_sel_branches_without_structures_buf;
CREATE TABLE {schema}.tmp_sel_branches_without_structures_buf AS
SELECT *,
  ST_Buffer({geom_column}, 2, 'endcap=square') AS bufgeom
FROM {schema}.{input_table};

CREATE INDEX tmp_sel_branches_without_structures_buf_geom
ON {schema}.tmp_sel_branches_without_structures_buf USING gist ({geom_column});

CREATE INDEX tmp_sel_branches_without_structures_buf_bufgeom
ON {schema}.tmp_sel_branches_without_structures_buf USING gist (bufgeom);

-- maak een cross section tabel
-- input cross_section moet ook leggerprofielen bevatten!
DROP TABLE IF EXISTS {schema}.{output_table};
CREATE TABLE {schema}.{output_table} AS
SELECT DISTINCT ON (a.id) a.id,
  b.reach_id AS channel_id,
  cross_profile_id,
  bed_level AS reference_level,
  a.friction_type,
  a.friction_value,
  bank_level,
  ST_SnapToGrid(ST_LineInterpolatePoint(b.{geom_column}, ST_LineLocatePoint(
    b.{geom_column}, a.geom)), 0, 0, 0.05, 0.05) AS the_geom
FROM {schema}.tmp_sel_branches_without_structures_buf AS b
LEFT JOIN {schema}.{cross_section_table} AS a
ON a.channel_id = b.id
WHERE ST_Contains(b.bufgeom, a.geom)
  AND ST_LineLocatePoint(b.{geom_column}, a.geom) BETWEEN 0.01
    AND 0.99;

-- maak extra cross secties aan waar nog geen kanaal op ligt
SELECT setval('{schema}.v2_cross_section_definition_id_seq', (
  SELECT max(id)
  FROM {schema}.{output_table}
  ));-- deze gebruiken in Turtle

DROP TABLE IF EXISTS {schema}.tmp_extra_crs;
CREATE TABLE {schema}.tmp_extra_crs AS
SELECT nextval('{schema}.v2_cross_section_definition_id_seq') AS id,
  reach_id AS channel_id,
  ST_SnapToGrid(ST_LineInterpolatePoint(a.{geom_column}, 0.5), 0, 0, 0.05, 0.05) AS geom
  -- ,id TODO: what is this???
FROM {schema}.tmp_sel_branches_without_structures_buf AS a
WHERE reach_id NOT IN (
  SELECT DISTINCT channel_id
  FROM {schema}.{output_table}
  ORDER BY channel_id
  );

-- pak voor ontbrekende kanalen de cross sectie locatie die origineel op
-- hetzelfde kanaal lag en voeg deze op het middelpunt toe
INSERT INTO {schema}.{output_table}
SELECT DISTINCT ON (a.id) a.id,
  a.channel_id,
  b.cross_profile_id,
  b.bed_level AS reference_level,
  b.friction_type,
  b.friction_value,
  0.1 AS bank_level,
  ST_SnapToGrid(a.geom, 0, 0, 0.05, 0.05) AS geom
FROM {schema}.tmp_extra_crs AS a
LEFT JOIN {schema}.{cross_section_table} AS b
ON a.id = b.channel_id
--WHERE ST_DWithin(a.geom,b.geom,50)
ORDER BY a.id,
  ST_Distance(a.geom, b.geom);

-- CHECK OF ER NOG KANALEN ZIJN ZONDER CROSS SECTIE
DROP TABLE IF EXISTS {schema}.tmp_channel_without_profile;
CREATE TABLE {schema}.tmp_channel_without_profile AS
SELECT reach_id
FROM {schema}.tmp_sel_branches_without_structures_buf AS a
WHERE reach_id NOT IN (
  SELECT reach_id
  FROM {schema}.tmp_sel_branches_without_structures_buf AS a,
    {schema}.{output_table} AS b
  WHERE ST_Contains(a.bufgeom, b.the_geom)
  );
"""


create_connection_nodes_statement = """

CREATE TABLE {schema}.v2_connection_nodes
(
  id serial NOT NULL,
  storage_area double precision,
  initial_waterlevel double precision,
  the_geom geometry(Point,28992) NOT NULL,
  the_geom_linestring geometry(LineString,28992),
  code character varying(100) NOT NULL,
  CONSTRAINT v2_connection_nodes_pkey PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
-- Index: v2_connection_nodes_the_geom_id

-- DROP INDEX v2_connection_nodes_the_geom_id;

CREATE INDEX v2_connection_nodes_the_geom_id
  ON {schema}.v2_connection_nodes
  USING gist
  (the_geom);
"""

add_missing_connection_nodes_for_culverts = """
-- solve culvert that have the same start as end point
WITH nodes AS ( 
SELECT DISTINCT ON (id) *, (ST_DumpPoints(geom)).geom as vertex , ST_Distance((ST_DumpPoints(geom)).geom,ST_StartPoint(geom))
FROM {schema}.{culvert_table} 
WHERE ST_IsClosed(geom)
ORDER BY  id, ST_Distance((ST_DumpPoints(geom)).geom,ST_StartPoint(geom)) DESC
)
UPDATE {schema}.{culvert_table} as a
SET geom = ST_MakeLine(ST_StartPoint(b.geom),b.vertex)
FROM nodes as b
WHERE a.id = b.id AND ST_IsClosed(a.geom)
;

DROP SEQUENCE IF EXISTS nodeserial;
CREATE SEQUENCE nodeserial;

SELECT setval('nodeserial', (select max(id) from {schema}.{connection_node_table}));
INSERT INTO {schema}.{connection_node_table}(id, {geom_column_cn})
WITH list AS (
SELECT ST_SnapToGrid( ST_Startpoint({geom_column_culvert}) ,0,0,0.05,0.05) as geom, culvert_id
FROM {schema}.{culvert_table}
WHERE connection_node_start_id IS NULL
UNION
SELECT ST_SnapToGrid( ST_Endpoint({geom_column_culvert}) ,0,0,0.05,0.05) as geom, culvert_id
FROM {schema}.{culvert_table}
WHERE connection_node_end_id IS NULL
)
SELECT DISTINCT ON (geom) nextval('nodeserial'), geom
FROM list
;
UPDATE {schema}.{culvert_table} AS a
SET connection_node_start_id=b.id
FROM {schema}.{connection_node_table} AS b
WHERE ST_DWithin(ST_Startpoint(a.{geom_column_culvert}),b.{geom_column_cn},0.06)
;

UPDATE {schema}.{culvert_table} AS a
SET connection_node_end_id=b.id
FROM {schema}.{connection_node_table} AS b
WHERE ST_DWithin(ST_Endpoint(a.{geom_column_culvert}),b.{geom_column_cn},0.06)
;
UPDATE {schema}.{culvert_table} AS a
SET geom = ST_SetPoint(a.geom,0,b.the_geom)
FROM {schema}.{connection_node_table} AS b
WHERE a.connection_node_start_id = b.id
;

UPDATE {schema}.{culvert_table} AS a
SET geom = ST_SetPoint(a.geom, ST_NumPoints(geom) - 1,b.the_geom)
FROM {schema}.{connection_node_table} AS b
WHERE a.connection_node_end_id = b.id
;
"""
