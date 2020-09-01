------------------------- profielen voor kunstwerken -------------------------------------
/*
Profielen worden voorbereid voor de kunstwerken. Indien een duiker een ei-vormige vorm heeft wordt de hoogte aangenomen als 1.5x de breedte.
*/
-- stuwen
SELECT
       setval('crsdefserial', (
              select
                     max(id)
              from
                     deelgebied.tmp_v2_cross_section_definition
       )
       )
;

INSERT INTO deelgebied.tmp_v2_cross_section_definition
       (id
            , shape
            , width
            , code
       )
SELECT
       nextval('crsdefserial') as id
     , 1                       as shape
     , crest_width             as width
     , code
FROM
       deelgebied.weirs
;

-- stuwen op duikers
SELECT
       setval('crsdefserial', (
              select
                     max(id)
              from
                     deelgebied.tmp_v2_cross_section_definition
       )
       )
;

INSERT INTO deelgebied.tmp_v2_cross_section_definition
       (id
            , shape
            , width
            , code
       )
SELECT
       nextval('crsdefserial') as id
     , shape                   as shape
     , crest_width             as width
     , code
FROM
       deelgebied.culvert_to_weir
;

-- rechthoekige duikers
INSERT INTO deelgebied.tmp_v2_cross_section_definition
       (id
            , shape
            , width
            , height
            , code
       )
SELECT DISTINCT
       nextval('crsdefserial') as id
     , 5
     , (width::varchar
              || ' '
              || width::varchar
              || ' '
              || 0)
     , (0
              || ' '
              || height::varchar
              || ' '
              || height::varchar)
     , code
FROM
       deelgebied.culvert
WHERE
       shape = 1
;

-- ronde duikers
INSERT INTO deelgebied.tmp_v2_cross_section_definition
       (id
            , shape
            , width
            , height
            , code
       )
SELECT DISTINCT
       nextval('crsdefserial') as id
     , 2
     , width
     , height
     , code
FROM
       deelgebied.culvert
WHERE
       shape = 2
;

-- allelei ei-vormige varianten (egg, mail, ellipse, Heul)
INSERT INTO deelgebied.tmp_v2_cross_section_definition
       (id
            , shape
            , width
            , height
            , code
       )
SELECT DISTINCT
       nextval('crsdefserial') as id
     , 2
     , width
     , width * 1.5
     , code
FROM
       deelgebied.culvert
WHERE
       shape > 2
;

-- bruggen
INSERT INTO deelgebied.tmp_v2_cross_section_definition
       (id
            , shape
            , width
            , height
            , code
       )
SELECT DISTINCT
       nextval('crsdefserial') as id
     , 5
     , (width::varchar
              || ' '
              || width::varchar
              || ' '
              || 0)
     , (0
              || ' '
              || (bottom_level - bed_level)::varchar
              || ' '
              || (bottom_level - bed_level)::varchar)
     , code
FROM
       deelgebied.bridge
;

-- TODO: uizoeken waar dit voor geburuikt wordt
DROP TABLE IF EXISTS tmp.measured_bed_level_on_connection_node
;

CREATE TABLE tmp.measured_bed_level_on_connection_node AS
             (
                  WITH measured_locations AS
                       (
                              SELECT *
                              FROM
                                     deelgebied.tmp_v2_cross_section_location
                              WHERE
                                     definition_id IN
                                     (
                                            SELECT
                                                   id
                                            FROM
                                                   deelgebied.tmp_v2_cross_section_definition
                                            WHERE
                                                   code LIKE 'PRO:%'
                                     )
                       )
                     , measured_channels AS
                       (
                              SELECT
                                     a.reach_id
                                   , a.connection_node_start_id
                                   , a.connection_node_end_id
                                   , b.reference_level
                                   , ST_LineLocatePoint(a.geom, b.the_geom) as fraction
                              FROM
                                     deelgebied.tmp_sel_branches_without_structures a
                                   , measured_locations                             b
                              WHERE
                                     a.reach_id = b.channel_id
                       )
                     , ref_level_on_channel_asc AS
                       (
                                SELECT    DISTINCT
                                ON
                                         (
                                                  reach_id
                                         )
                                         reach_id
                                       , connection_node_start_id as connection_node_id
                                       , reference_level
                                FROM
                                         measured_channels
                                ORDER BY
                                         reach_id
                                       , fraction ASC
                       )
                     , ref_level_on_channel_DESC AS
                       (
                                SELECT    DISTINCT
                                ON
                                         (
                                                  reach_id
                                         )
                                         reach_id
                                       , connection_node_end_id as connection_node_id
                                       , reference_level
                                FROM
                                         measured_channels
                                ORDER BY
                                         reach_id
                                       , fraction DESC
                       )
                  SELECT   *
                  FROM
                         ref_level_on_channel_asc
                  UNION
                  SELECT   *
                  FROM
                         ref_level_on_channel_desc
             )
;

--Get bed_level on bridge from minimum reference level