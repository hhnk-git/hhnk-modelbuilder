/*
Simple way to add grid refinement to model. This used to be based on very ellaborate considorations
using the grid, but since an updated version from 3Di, 1d2d links respect levees, making this largely obsolete.
The method below assumes 40 m grid on all leveesand 20 m when a channel is whitin 20 m.
kmax grid_space
1    10x10
2    20x20
3    40x40
4    80x80
*/
-- Reset refeinment_level column
ALTER TABLE deelgebied.levee DROP COLUMN IF EXISTS refinement_level
;
ALTER TABLE deelgebied.levee ADD COLUMN refinement_level integer
;

-- Set default refinement level to 40 m
UPDATE
       deelgebied.levee
SET    refinement_level = 3
;

-- Set refinement level to 20 m when channel within 20 m
UPDATE
       deelgebied.levee as l
SET    refinement_level = 2
FROM deelgebied.channel as c 
WHERE ST_DWithin(l.geom,c.geom,20);


-- INSERT INTO public TABLES
DELETE
FROM
       v2_grid_refinement
;

INSERT INTO v2_grid_refinement
       ( id
       , display_name
       , refinement_level
       , the_geom
       , code
       )
SELECT
       levee_id
       , levee_ring_id
       , refinement_level
       , geom
       , (levee_ring_id
              || '-'
              || levee_id)
FROM
       deelgebied.levee
;
  