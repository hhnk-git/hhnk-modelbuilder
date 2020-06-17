/* 
    Check if a culvert is combined with a pumpstation or weir_attached
*/

ALTER TABLE checks.culvert DROP COLUMN IF EXISTS pump_attached;
ALTER TABLE checks.culvert ADD COLUMN pump_attached boolean DEFAULT False;

UPDATE checks.culvert as a
SET pump_attached = True,
    opmerking = concat_ws(',',a.opmerking,'pomp op duiker')
	WHERE a.code IN(
		SELECT a.code
		FROM checks.culvert as a, checks.pumpstation as b
		WHERE ST_Intersects(b.geom,a.geom)
	
	);
	
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS weir_attached;
ALTER TABLE checks.culvert ADD COLUMN weir_attached boolean DEFAULT False;

UPDATE checks.culvert as a
SET weir_attached = True,
    opmerking = concat_ws(',',a.opmerking,'stuw op duiker')
	WHERE a.code IN(
		SELECT a.code
		FROM checks.culvert as a, checks.weirs as b
		WHERE ST_Intersects(b.geom,a.geom)
	
	);