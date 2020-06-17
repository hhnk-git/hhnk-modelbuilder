/* 
Check if syphons in NXT schema were EXACTLY contained by a hydroobject 
This is done in the NXT schema because in the checks schema coordinates might have been rounded already
*/
DROP TABLE IF EXISTS tmp.incorrect_syphons;
CREATE TABLE tmp.incorrect_syphons AS(
	WITH correct_syphons as(
		SELECT a.id as syphon_id, a.geometry as syphon_geom, a.code as syphon_code 
		FROM nxt.culvert a, nxt.channel b
		WHERE a.type IN (6,7,8) --alle syfons
		AND ST_Contains(b.geometry, a.geometry)
	)
SELECT code FROM nxt.culvert
WHERE type IN (6,7,8) AND code NOT IN (SELECT syphon_code FROM correct_syphons))
;

UPDATE checks.culvert as a
SET opmerking = concat_ws(',',a.opmerking,'sifon in brondata niet exact op watergang')
WHERE code in (SELECT code FROM tmp.incorrect_syphons);