-- peilgebieden opvullen


-- watergangen
/*
Talud links (-)	0,1 - 30
Talud rechts (-)	0,1 - 30
Bodemhoogte	Lager dan peil*
Bodembreedt (m)	0,2 -100

	Watergangprofiel
	Talud	Bodemdiepte	Drooglegging	Bodembreedte	Bodemweerstand (Strickler waarde)
 	[-]	[m]	[m]	[m]	[m1/3/s]
primair	1:2	1	0	3	30
overig	1:1.5	0.5	0	1	20

*/
-- talud
ALTER TABLE checks.channel DROP COLUMN IF EXISTS aanname;
ALTER TABLE checks.channel ADD COLUMN aanname varchar(200);
UPDATE checks.channel
SET talud_left = 2, 
	aanname = concat_ws(',',aanname,'talud_left')
WHERE channel_type_id = 1 
	AND (talud_left IS NULL OR talud_left <0.1 OR talud_left > 30)
;
UPDATE checks.channel
SET talud_right = 2, 
	aanname = concat_ws(',',aanname,'talud_right')
WHERE channel_type_id = 1 
	AND (talud_right IS NULL OR talud_right <0.1 OR talud_right > 30)
;
UPDATE checks.channel
SET talud_left = 1.5, 
	aanname = concat_ws(',',aanname,'talud_left')
WHERE channel_type_id <> 1 
	AND (talud_left IS NULL OR talud_left <0.1 OR talud_left > 30)
;
UPDATE checks.channel
SET talud_right = 1.5, 
	aanname = concat_ws(',',aanname,'talud_right')
WHERE channel_type_id <> 1 
	AND (talud_right IS NULL OR talud_right <0.1 OR talud_right > 30)
;



--bodemhoogte
UPDATE checks.channel as a
SET bed_level = b.streefpeil_bwn2 - 1, 
	aanname = concat_ws(',',aanname,'bed_level')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom) 
	AND channel_type_id = 1 
	AND ((b.streefpeil_bwn2 - a.bed_level) NOT BETWEEN 0.2 AND 20 OR a.bed_level IS NULL)
	AND typering <> 'Hellend'
; --147 sec
UPDATE checks.channel as a
SET bed_level = b.streefpeil_bwn2 - 1, 
	aanname = concat_ws(',',aanname,'bed_level')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom) 
	AND channel_type_id = 1 
	AND a.bed_level IS NULL
	AND typering = 'Hellend'
; 
UPDATE checks.channel as a
SET bed_level = b.streefpeil_bwn2 - 0.5, 
	aanname = concat_ws(',',aanname,'bed_level')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom) 
	AND channel_type_id <> 1 
	AND ((b.streefpeil_bwn2 - a.bed_level) NOT BETWEEN 0.2 AND 20 OR a.bed_level IS NULL)
	AND typering <> 'Hellend'
; --147 sec
UPDATE checks.channel as a
SET bed_level = b.streefpeil_bwn2 - 10.5, 
	aanname = concat_ws(',',aanname,'bed_level')
FROM checks.fixeddrainagelevelarea as b
WHERE ST_Intersects(a.geom,b.geom) 
	AND channel_type_id <> 1 
	AND a.bed_level IS NULL
	AND typering = 'Hellend'
; 

UPDATE checks.channel as a
SET bed_level = -10,
	aanname = concat_ws(',',aanname,'bed_level')
WHERE bed_level IS NULL OR bed_level < -100
;

-- bodembreedte
UPDATE checks.channel
SET bed_width = 3.0, 
	aanname = concat_ws(',',aanname,'bed_width')
WHERE channel_type_id = 1 
	AND (bed_width IS NULL OR bed_width <0.2 OR bed_width > 400)
;
UPDATE checks.channel
SET bed_width = 1.0, 
	aanname = concat_ws(',',aanname,'bed_width')
WHERE channel_type_id<> 1 
	AND (bed_width IS NULL OR bed_width <0.2 OR bed_width > 400)
;


/*
Gemalen	Capaciteit (m3/min) 0.001 - 1000 
	Primair: 25 m3/min als er niet is ingevuld
    Primair: niet updaten (enkel een opmerking) als er wel wat is ingevuld 
    Overige: 1 m3/min
*/

ALTER TABLE checks.pumpstation DROP COLUMN IF EXISTS aanname;
ALTER TABLE checks.pumpstation ADD COLUMN aanname varchar(200);


UPDATE checks.pumpstation
SET opmerking = concat_ws(',',opmerking,'weird_capacity') 
WHERE channel_type_id = 1 
AND capacity IS NULL
;

UPDATE checks.pumpstation
SET capacity = 25, 
	aanname = concat_ws(',',aanname,'capacity25m3_min') 
WHERE channel_type_id = 1 
AND capacity IS NULL
;

UPDATE checks.pumpstation
SET capacity = 1, 
	aanname = concat_ws(',',aanname,'capacity1m3_min') 
WHERE channel_type_id <> 1
AND capacity IS NULL
AND type NOT LIKE '98'
;

--zet doorspoelgemalen uit
UPDATE checks.pumpstation
SET capacity = 0, 
	aanname = concat_ws(',',aanname,'capacity0m3_min') 
WHERE type LIKE '98'
;

/*
Stuwen	1) Kruinhoogte (mNAP) moet minimaal gelijk of groter dan peil
        2) Kruinhoogte (mNAP) moet groter zijn dan dan bodemhoogte
        3) Kruinhoogte moet tussen minimaal (-10mNAP) en maximaal (+10mNAP) liggen
*/


-- 1)Kruinhoogte (mNAP) moet minimaal gelijk of groter dan peil
-- Voor stuwen: bepaal het hoogste peil in een straal van 2 meter rondom de stuw.
DROP TABLE IF EXISTS tmp.weir_level_radius;
CREATE TABLE tmp.weir_level_radius AS(
	WITH radius_search AS(
		SELECT a.code as weir_code, 
		streefpeil_bwn2 as streefpeil
		FROM checks.weirs a, checks.fixeddrainagelevelarea b
		WHERE ST_DWithin(a.geom,b.geom,2) 
	)
	SELECT 
		weir_code, 
		max(streefpeil) as max_streefpeil
	FROM radius_search
	GROUP BY weir_code
	HAVING COUNT(*) > 1 --Mits er meerdere streefpeilen gevonden zijn
);

UPDATE checks.weirs a
SET crest_level =  b.max_streefpeil,
	aanname = concat_ws(',',aanname,'crest_heigth') 
FROM tmp.weir_level_radius b
    WHERE a.channel_type_id = 1
    AND a.code = b.weir_code
    AND a.crest_level < b.max_streefpeil;

UPDATE checks.weirs a
SET crest_level = b.max_streefpeil,
	aanname = concat_ws(',',aanname,'crest_heigth') 
FROM tmp.weir_level_radius b
    WHERE a.channel_type_id <> 1
    AND a.code = b.weir_code
    AND a.crest_level < b.max_streefpeil;   
    
    
    
-- 2) Kruinhoogte (mNAP) moet groter zijn dan dan bodemhoogte   
-- Voor stuwen: bepaal het hoogste bodemniveau van channels 2 meter rondom de stuw.
DROP TABLE IF EXISTS tmp.max_bottom_weir_radius;
CREATE TABLE tmp.max_bottom_weir_radius AS(
	WITH radius_search AS(
		SELECT a.code as weir_code, 
		b.code as fdla_code, 
		b.bed_level as channel_bedlevel
		FROM checks.weirs a, checks.channel b
		WHERE ST_DWithin(a.geom,b.geom,2)
    )
	SELECT 
		weir_code, 
		-- ST_Union(weir_geom) as geom, 
		max(channel_bedlevel) as max_channelbedlevel
    FROM radius_search 
	GROUP BY weir_code
	HAVING COUNT(*) > 1 --Mits er meerdere channels verbonden zijn
);         
        
UPDATE checks.weirs a
SET crest_level =  b.max_channelbedlevel + 0.5,
	aanname = concat_ws(',',aanname,'crest_heigth') 
FROM tmp.max_bottom_weir_radius b
    WHERE a.channel_type_id = 1
    AND a.code = b.weir_code
    AND a.crest_level < b.max_channelbedlevel;

UPDATE checks.weirs a
SET crest_level = b.max_channelbedlevel + 0.5,
	aanname = concat_ws(',',aanname,'crest_heigth') 
FROM tmp.max_bottom_weir_radius b
    WHERE a.channel_type_id <> 1
    AND a.code = b.weir_code
    AND a.crest_level < b.max_channelbedlevel;        
 
  
  
-- 3) Kruinhoogte moet tussen minimaal (-10mNAP) en maximaal (+10mNAP) liggen 
UPDATE checks.weirs a
SET crest_level = -10,
	aanname = concat_ws(',',aanname,'crest_heigth') 
WHERE crest_level < -10;

UPDATE checks.weirs a
SET crest_level = 10,
	aanname = concat_ws(',',aanname,'crest_heigth') 
WHERE crest_level > 10; 








/*
Stuwen	Kruinbreedte (m)	0,15 - 25

Breedte
[m]
2
1
*/

UPDATE checks.weirs
SET crest_width = 2, 
	aanname = concat_ws(',',aanname,'crest_width') 
WHERE channel_type_id = 1
	AND(crest_width NOT BETWEEN 0.15 AND 25 OR crest_width IS NULL)
;
UPDATE checks.weirs
SET crest_width = 1, 
	aanname = concat_ws(',',aanname,'crest_width') 
WHERE channel_type_id <> 1
	AND(crest_width NOT BETWEEN 0.15 AND 25 OR crest_width IS NULL)
;

UPDATE checks.weirs
SET shape = 1,
	aanname = concat_ws(',',aanname,'shape')
WHERE shape > 2
;


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
-- hoogte duiker
UPDATE checks.culvert
SET height = width,
	aanname = concat_ws(',',aanname,'width')
WHERE (height NOT BETWEEN 0.1 AND 25 OR height IS NULL)
;

--bob
UPDATE checks.culvert as a
SET bed_level_upstream = b.bed_level, 
	aanname = concat_ws(',',a.aanname,'bed_level_up from channel')
FROM checks.channel as b
WHERE ST_Intersects(a.geom,b.bufgeom) 
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
WHERE ST_Intersects(a.geom,b.bufgeom) 
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

/* Verwijderd ivm scripts mbt inlaat/afvoer afsluitbaar bepaling (zie bovenstaand)
-- afsluitbare duikers en inlaten en sifons
UPDATE checks.culvert as a
SET bed_level_upstream = (b.streefpeil_bwn2 + 10),
	aanname = concat_ws(',',a.aanname,'afsluiter')
FROM checks.fixeddrainagelevelarea as b
WHERE  ST_Intersects(ST_Startpoint(a.geom),b.geom) 
	AND (a.type = 1 OR a.type = 3 OR a.type = 5 OR a.type = 7 OR a.type = 8)
;
*/


-- vorm
UPDATE checks.culvert
SET shape = 1,
	aanname = concat_ws(',',aanname,'shape')
WHERE shape > 6
;

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


