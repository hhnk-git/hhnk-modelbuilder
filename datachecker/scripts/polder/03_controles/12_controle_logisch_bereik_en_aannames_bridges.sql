/*
Assumptions bridges
    1. If the bottom level of a bridge is lower than the waterlevel at that spatial point, a bottom level of 10.01 mNAP is assigned. 
    2. If the width of a bridge is not between 0.5 m and 50 m it gets a value of 20.02 if the bridge is above a primairy channel
    3. If the width of a bridge is not between 0.5 and 50 it gets a value of 10.02 if the bridge is above something else than a prima
    4. Where the bridge intersects a channel, the bed level of the bridge is set as the bed level of the channel.
*/
/*
Bruggen
	Hoogte onderzijde (mNAP)	Hoger dan legger-bodemhoogte
	Breedte (m)	0,5 - 50

Brug
Breedte / diameter
[mm]
800
500
*/


ALTER TABLE checks.bridge DROP COLUMN IF EXISTS aanname;
ALTER TABLE checks.bridge ADD COLUMN aanname varchar(250);
UPDATE checks.bridge as a
SET bottom_level = b.streefpeil_bwn2 + 10.01, 
	aanname = concat_ws(',',a.aanname,'bottom_level')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom) 
	AND channel_type_id = 1  
	AND (a.bottom_level < b.streefpeil_bwn2 OR a.bottom_level IS NULL)
;
UPDATE checks.bridge as a
SET bottom_level = b.streefpeil_bwn2 + 10.01, 
	aanname = concat_ws(',',a.aanname,'bottom_level')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom)
	AND channel_type_id <> 1 
	AND (a.bottom_level < b.streefpeil_bwn2 OR a.bottom_level IS NULL)
;
UPDATE checks.bridge
SET width = 20.02,
	aanname = concat_ws(',',aanname,'width')
WHERE channel_type_id = 1 
	AND(width NOT BETWEEN 0.5 AND 50 OR width IS NULL)
;
UPDATE checks.bridge
SET width = 10.01,
	aanname = concat_ws(',',aanname,'width')
WHERE channel_type_id <> 1 
	AND(width NOT BETWEEN 0.5 AND 50 OR width IS NULL)
;


--Set bed_level from channel, first derived bed level and otherwise bed_level (legger)
ALTER TABLE checks.bridge DROP COLUMN IF EXISTS bed_level;
ALTER TABLE checks.bridge ADD COLUMN bed_level double precision;

UPDATE checks.bridge as a
SET bed_level = b.derived_bed_level
FROM checks.channel as b
WHERE ST_Intersects(a.geom,b.bufgeom) 
;

UPDATE checks.bridge as a
SET bed_level = b.bed_level
FROM checks.channel as b
WHERE a.bed_level IS NULL AND 
ST_Intersects(a.geom,b.bufgeom) 
;


