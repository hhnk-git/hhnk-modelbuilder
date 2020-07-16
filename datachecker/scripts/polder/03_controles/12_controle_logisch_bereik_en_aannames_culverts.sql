/*
Assumptions culverts
    1. If a culvert has a width which is not between 0.1 and 25, then it is set to 1.
    2  If a culvert has a width but not a height, the height is set to the width.
    3. If a culvert has no bed level upstream and intersects with a channel. The bed level upstream is set to the bed level of that channel. A similar assumption is made for the downstream bed level.
    4. If a culvert has a upstream bed level which is higher than the waterlevel or the upsteam bed level is not between -20 and 20 it is set to the waterlevel - culvert width.A similar assumption is made for the downstream bed level.
    5. IF a culvert has no upstream or down stream bed level, it is set to the waterlevel - 1.

*/

/*
Duikers
	Diameter (m)	0,1 - 25
	Hoogte (m)	0,1 - 25
	Breedte (m)	0,1 - 25
	B.O.B. (m NAP)	lager dan streefpeil
			groter dan legger-bodemhoogte 

 	Duiker
 	Breedte / diameter	B.O.K.
 	[mm]	[m]
primair	800	bodemhoogte watergang
overig	500	bodemhoogte watergang
*/
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS aanname;
ALTER TABLE checks.culvert ADD COLUMN aanname varchar(250);
UPDATE checks.culvert
SET width = 0.8,
	aanname = concat_ws(',',aanname,'width')
WHERE channel_type_id = 1 
	AND(width NOT BETWEEN 0.1 AND 25 OR width IS NULL)
;
UPDATE checks.culvert
SET width = 0.5,
	aanname = concat_ws(',',aanname,'width')
WHERE channel_type_id <> 1 
	AND(width NOT BETWEEN 0.1 AND 25 OR width IS NULL)
;
UPDATE checks.culvert
SET height = width,
	aanname = concat_ws(',',aanname,'width')
WHERE (height NOT BETWEEN 0.1 AND 25 OR height IS NULL)
;

UPDATE checks.culvert as a
SET bed_level_upstream = b.bed_level, 
	aanname = concat_ws(',',a.aanname,'bed_level_up from channel')
FROM checks.channel as b
WHERE ST_Intersects(b.bufgeom,a.geom) 
	AND a.bed_level_upstream IS NULL
	AND (a.opmerking NOT LIKE ALL (ARRAY['%niet afsluitbaar op peilgrens%','%afsluitbare inlaat op peilgrens%','%afsluitbare afvoer op peilgrens%']) OR a.opmerking IS NULL)
;
 -- LET OP bob naar beneden getrokken! Afweging is dat meestal zal de bed level verkeerd zijn ingevuld
UPDATE checks.culvert as a
SET bed_level_upstream = b.streefpeil_bwn2 - a.width, 
	aanname = concat_ws(',',a.aanname,'bed_level_up level-width')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom)  
	AND (a.bed_level_upstream > b.streefpeil_bwn2 OR a.bed_level_upstream NOT BETWEEN -20 AND 20)
	AND (a.opmerking NOT LIKE ALL (ARRAY['%niet afsluitbaar op peilgrens%','%afsluitbare inlaat op peilgrens%','%afsluitbare afvoer op peilgrens%','%(hdb:open)%'])
	OR a.opmerking IS NULL)
	AND (NOT level_seperator_indicator OR level_seperator_indicator IS NULL);

UPDATE checks.culvert as a
SET bed_level_downstream = b.bed_level, 
	aanname = concat_ws(',',a.aanname,'bed_level_down from channel')
FROM checks.channel as b
WHERE ST_Intersects(b.bufgeom, a.geom) 
	AND a.bed_level_downstream IS NULL
;
 -- LET OP bob naar beneden getrokken!  Afweging is dat meestal zal de bed level verkeerd zijn ingevuld
UPDATE checks.culvert as a
SET bed_level_downstream = b.streefpeil_bwn2 - a.width, 
	aanname = concat_ws(',',a.aanname,'bed_level_down level-width')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom)  
	AND (a.bed_level_downstream > b.streefpeil_bwn2 OR a.bed_level_downstream NOT BETWEEN -20 AND 20)
	AND (NOT level_seperator_indicator OR level_seperator_indicator IS NULL)
	AND (a.opmerking NOT LIKE '%(hdb:open)%' OR a.opmerking IS NULL)
;

UPDATE checks.culvert as a
SET bed_level_upstream = b.streefpeil_bwn2 - 1, 
	aanname = concat_ws(',',a.aanname,'bed_level_up level-1m')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom)  
	AND a.bed_level_upstream IS NULL
;
UPDATE checks.culvert as a
SET bed_level_downstream = b.streefpeil_bwn2 - 1, 
	aanname = concat_ws(',',a.aanname,'bed_level_down level-1m')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom)  
	AND a.bed_level_downstream IS NULL
;

UPDATE checks.culvert
SET shape = 1,
	aanname = concat_ws(',',aanname,'shape')
WHERE shape > 6
;

