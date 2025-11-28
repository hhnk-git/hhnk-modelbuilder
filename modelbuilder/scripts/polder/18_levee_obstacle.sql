
-- insert levees into public table. Only use those that have ring geometry
        
        DELETE
        FROM
               v2_levee
        ;
        
        INSERT INTO v2_levee
               ( id
                    , crest_level
                    , the_geom
                    , code
               )
        SELECT
               levee_id
             , height
             , geom
             , levee_ring_id
                      || '-'
                      || levee_id
        FROM
               deelgebied.levee
        WHERE
               ST_GeometryType(geom) = 'ST_LineString'
        ;