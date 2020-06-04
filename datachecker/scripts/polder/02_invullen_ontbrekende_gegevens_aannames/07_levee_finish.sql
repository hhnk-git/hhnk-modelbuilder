-- inladen en samenvoegen
DROP TABLE IF EXISTS checks.levee;
CREATE TABLE checks.levee AS
SELECT wkb_geometry as geom, ring_id as levee_ring_id, max_wl as maximum_water_level, objectid as levee_id, height, 
	ST_Buffer(ST_LineInterpolatePoint(ST_LineSubstring(wkb_geometry, 0, 0.5),0.5),2) as midgeom,
	NULL::varchar(250) as opmerking
FROM tmp.levee_height
WHERE ST_Length(wkb_geometry) > 2
;
CREATE INDEX checks_levee_geom ON checks.levee USING gist(geom);
CREATE INDEX checks_levee_mifdeom ON checks.levee USING gist(midgeom);

-- check of hoogte valide is
UPDATE checks.levee SET opmerking = 'Levee below waterlevel +30cm', height = maximum_water_level + 0.3
WHERE (maximum_water_level +0.3) > height
;




-- opruimen
DROP TABLE IF EXISTS tmp.peilgrenzen;
DROP TABLE IF EXISTS tmp.peilgrenzen2;
DROP TABLE IF EXISTS tmp.levee;
DROP TABLE IF EXISTS tmp.polder_inside;
