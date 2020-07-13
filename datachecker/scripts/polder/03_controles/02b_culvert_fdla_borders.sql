-- 1) Duikers en sifons:
-- We voegen de twee fixeddrainagelevelarea id's toe aan checks.culvert (van eind en startpunt). Dit doen we om later te voorkomen dat we de duikers die beginnen en eindigen in hetzelfde peilgebied EN een peilgrens intersecten bestempelen als 'kruispunt zonder kunstwerk'

-- 1.1) We gaan eerst de duikers/sifon's selecteren waarvan begin en eind punt in zelfde peilgebied liggen
--Check of een begin/eindpunt op meerdere peilgebieden ligt (exact op peilgrens)	
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS fixeddrainagelevelarea_array_1;
ALTER TABLE checks.culvert ADD COLUMN fixeddrainagelevelarea_array_1 integer[];
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS fixeddrainagelevelarea_array_2;
ALTER TABLE checks.culvert ADD COLUMN fixeddrainagelevelarea_array_2 integer[];

/*
This takes SUPER long, optimized query below
DROP TABLE IF EXISTS tmp.culvert_start_fdla_id;
CREATE TABLE tmp.culvert_start_fdla_id AS(
SELECT a.code, array_agg(b.id) as fdla_array
FROM checks.culvert a, checks.fixeddrainagelevelarea b
WHERE ST_intersects(st_startpoint(a.geom),ST_Buffer(b.geom,0.01))
GROUP BY a.code);
*/

DROP TABLE IF EXISTS tmp.culvert_start_fdla_id;
CREATE TABLE tmp.culvert_start_fdla_id AS(
SELECT a.code, array_agg(b.id) as fdla_array
FROM checks.culvert a, checks.fixeddrainagelevelarea b
--WHERE ST_intersects(st_startpoint(a.geom),ST_Buffer(b.geom,0.01))
WHERE ST_dwithin(st_startpoint(a.geom),b.geom,0.01)
GROUP BY a.code
);

DROP TABLE IF EXISTS tmp.culvert_end_fdla_id;
CREATE TABLE tmp.culvert_end_fdla_id AS(
SELECT a.code, array_agg(b.id) as fdla_array
FROM checks.culvert a, checks.fixeddrainagelevelarea b
WHERE ST_dwithin(st_endpoint(a.geom),b.geom,0.01)
GROUP BY a.code);

UPDATE checks.culvert a SET fixeddrainagelevelarea_array_1 = fdla_array
    FROM tmp.culvert_start_fdla_id b
    WHERE a.code = b.code;
UPDATE checks.culvert a SET fixeddrainagelevelarea_array_2 = fdla_array
    FROM tmp.culvert_end_fdla_id b
    WHERE a.code = b.code;	

--Bepaal id's uit arrays
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS fixeddrainagelevelarea_id_1;
ALTER TABLE checks.culvert ADD COLUMN fixeddrainagelevelarea_id_1 integer;
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS fixeddrainagelevelarea_id_2;
ALTER TABLE checks.culvert ADD COLUMN fixeddrainagelevelarea_id_2 integer;

--Verwijder de ene set van de andere set
UPDATE checks.culvert a SET 
	fixeddrainagelevelarea_id_1 = 
	CASE 
		WHEN array_length(fixeddrainagelevelarea_array_1,1) = 1 THEN fixeddrainagelevelarea_array_1[1]
		WHEN array_length(fixeddrainagelevelarea_array_1,1) = 2 THEN (array_remove(fixeddrainagelevelarea_array_1,fixeddrainagelevelarea_array_2[1]))[1]
		WHEN array_length(fixeddrainagelevelarea_array_1,1) > 2 THEN (array_remove(fixeddrainagelevelarea_array_1,fixeddrainagelevelarea_array_2[1]))[1]
	END,
	fixeddrainagelevelarea_id_2 = 
	CASE 
		WHEN array_length(fixeddrainagelevelarea_array_2,1) = 1 THEN fixeddrainagelevelarea_array_2[1]
		WHEN array_length(fixeddrainagelevelarea_array_2,1) = 2 THEN (array_remove(fixeddrainagelevelarea_array_2,fixeddrainagelevelarea_array_1[1]))[1]
		WHEN array_length(fixeddrainagelevelarea_array_2,1) > 2 THEN (array_remove(fixeddrainagelevelarea_array_2,fixeddrainagelevelarea_array_1[1]))[1]
	END;

--Defining characteristics of culverts
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS op_peilgrens;
ALTER TABLE checks.culvert ADD COLUMN op_peilgrens BOOLEAN;

ALTER TABLE checks.culvert DROP COLUMN IF EXISTS hdb_open;
ALTER TABLE checks.culvert ADD COLUMN hdb_open BOOLEAN;

ALTER TABLE checks.culvert DROP COLUMN IF EXISTS closeable;
ALTER TABLE checks.culvert ADD COLUMN closeable BOOLEAN;

ALTER TABLE checks.culvert DROP COLUMN IF EXISTS inlet;
ALTER TABLE checks.culvert ADD COLUMN inlet BOOLEAN;

ALTER TABLE checks.culvert DROP COLUMN IF EXISTS attached;
ALTER TABLE checks.culvert ADD COLUMN attached BOOLEAN;

UPDATE checks.culvert 
SET attached = opmerking LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']);
UPDATE checks.culvert SET attached = False where attached is NULL;


--Duikers/sifon's kruisen de bufgeom van een peilgrens EN beginnen en eindigen niet in hetzelfde peilgebied. Deze krijgen op_peilgrens.
UPDATE checks.culvert a 
    SET op_peilgrens = True 
    FROM tmp.peilgrenzen as b 
	WHERE a.fixeddrainagelevelarea_array_1 <> a.fixeddrainagelevelarea_array_2
    AND ST_Intersects(a.geom,b.geom);
    
UPDATE checks.culvert a 
    SET op_peilgrens = FALSE
    FROM checks.weirs as b
    WHERE op_peilgrens is NULL or ST_DWithin(a.geom,b.geom,0.1);
    
-- Closable geeft aan of de duikers afsluitbaar zijn, dit is afhankelijk van 'type'
UPDATE checks.culvert SET 
    closeable = 
    CASE 
        WHEN type IN (3,4,7,8) THEN True
        WHEN type IN (1,2,5,6, 9999) THEN False
        ELSE NULL
    END;

-- hdb_open geeft aan of de duikers open zijn, volgens de HDB
UPDATE checks.culvert a
	SET hdb_open = True 
    FROM hdb.duikers_op_peilgrens as b
	WHERE a.code = b.code
	AND a.code IN (
		SELECT code 
		FROM hdb.duikers_op_peilgrens
		WHERE modelleren_als LIKE '%open%');
UPDATE checks.culvert SET hdb_open = False where hdb_open is NULL;

-- inlet geeft aan of de duiker een inlaat is of niet.
UPDATE checks.culvert SET 
    inlet = 
    CASE 
        WHEN type in (1,3,5,7) THEN TRUE
        WHEN type in (2,4,6,8) THEN FALSE
        ELSE NULL
    END;
    
-- pomp binnen 10 cm van duiker --> checks.culvert.attached
-- indpeilregulpeilscheidend --> level_separator_indicator

-- 1.2) Welke duikers/sifon's kruisen de bufgeom van een peilgrens EN beginnen en eindigen niet in hetzelfde peilgebied. Deze krijgen op_peilgrens.
/*
UPDATE checks.culvert a 
    SET op_peilgrens =
    FROM tmp.peilgrenzen as b 
	WHERE a.fixeddrainagelevelarea_array_1 <> a.fixeddrainagelevelarea_array_2
    AND ST_Intersects(a.geom,b.geom);
*/    
-- sifon's gaan bijna altijd van zelfde peilgebied naar andere peilgebied. Als ze dat niet doen, dan komen ze hier terug met 'op_peilgrens=1'

-- 1.3) Als er een stuw op die duiker ligt, kunnen we het peil handhaven met de stuw. De duiker ligt dus eigenlijk niet op de peilgrens. Als we verderop de channel_nowayout gaan bepallen wordt (met onderstaande code) deze culvert niet als blokerend segment gezien en weggegooid
UPDATE checks.culvert a 
    SET op_peilgrens = NULL
    FROM checks.weirs as b
    WHERE op_peilgrens AND b.opmerking IS NULL AND ST_DWithin(a.geom,b.geom,0.1);
        
-- 1.4) zet de polders om in lijnen als poldergrenzen
DROP TABLE IF EXISTS tmp.poldergrenzen;
CREATE TABLE tmp.poldergrenzen AS
SELECT polder_id::numeric, ST_ExteriorRing((ST_Dump(geom)).geom) as geom
FROM checks.polder
;
CREATE INDEX tmp_poldergrenzen_geom ON tmp.poldergrenzen USING gist(geom);

-- 1.5) Welke duikers/sifon's kruisen poldergrens? Deze krijgen op_poldergrens = 1.
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS op_poldergrens;
ALTER TABLE checks.culvert ADD COLUMN op_poldergrens integer;
UPDATE checks.culvert a 
    SET op_poldergrens = 1 
    FROM tmp.poldergrenzen as b
	WHERE ST_DWithin(a.geom,b.geom,0.1); -- moet dit niet zijn?  AND ST_Intersects(st_buffer(a.geom,0.1),b.geom);

-- 1.6) Als er een stuw op die duiker ligt, kunnen we het peil handhaven met de stuw. De duiker ligt dus eigenlijk niet op de poldergrens. 
UPDATE checks.culvert a 
    SET op_poldergrens = NULL
    FROM checks.weirs as b
    WHERE op_poldergrens = 1 AND b.opmerking IS NULL AND ST_DWithin(a.geom,b.geom,0.1);
        
       
-- 1.7a) Duiker/sifon kruist peilgrens, is niet afsluitbaar en heeft geen stuw of gemaal aangesloten en in HDB niet meegenomen. Actie: Afsluiten door discharge naar 0 te zetten
UPDATE checks.culvert
    SET     opmerking = concat_ws(',',opmerking,'niet afsluitbaar op peilgrens'),
			discharge_coefficient_positive = 0.0,
			discharge_coefficient_negative = 0.0
    WHERE op_peilgrens
		AND (NOT level_seperator_indicator OR level_seperator_indicator IS NULL)
		AND NOT attached
		AND NOT closeable	--Niet afsluitbaar
		AND NOT  hdb_open;
		--616 (01-05-2017)
		--1699 (27-06-2017) meer omdat ook type 9999 is toegevoegd

-- Duiker/sifon kruist peilgrens, is niet afsluitbaar en heeft geen stuw of gemaal aangesloten. Volgens HDB toch open modelleren: zet BOB op max streefpeil
UPDATE checks.culvert
    SET opmerking = concat_ws(',',opmerking,'niet afsluitbaar (hdb:open) op peilgrens') 
	WHERE op_peilgrens
		AND (NOT level_seperator_indicator OR level_seperator_indicator IS NULL)
		AND NOT attached
		AND NOT closeable	--Niet afsluitbaar
		AND hdb_open;
			
-- Zet bovenstroomse BOB op maximale streefpeil
UPDATE checks.culvert a
	SET bed_level_upstream = GREATEST(a.bed_level_upstream,maxpeil) FROM (
		SELECT b.id, GREATEST(c.streefpeil_bwn2,d.streefpeil_bwn2) as maxpeil
		FROM checks.culvert b 
		LEFT JOIN checks.fixeddrainagelevelarea c
		ON b.fixeddrainagelevelarea_id_1 = c.id
		LEFT JOIN checks.fixeddrainagelevelarea d
		ON b.fixeddrainagelevelarea_id_2 = d.id
		) e
	WHERE a.id = e.id
	AND op_peilgrens
	AND NOT attached
	AND hdb_open;
		

-- Duiker/sifon kruist peilgrens, is niet afsluitbaar maar ligt op hoogte: zet BOB op max(streefpeil_beneden,streefpeil_boven,bob)		
UPDATE checks.culvert
    SET opmerking = concat_ws(',',opmerking,'duiker op overstort') 
	WHERE op_peilgrens
		AND level_seperator_indicator
		AND NOT attached
		AND NOT closeable	--Niet afsluitbaar
;					
		
UPDATE checks.culvert a	
	SET bed_level_upstream = greatest(bed_level_upstream, bed_level_downstream, maxpeil) FROM (
		SELECT b.id, GREATEST(c.streefpeil_bwn2,d.streefpeil_bwn2) as maxpeil
		FROM checks.culvert b 
		LEFT JOIN checks.fixeddrainagelevelarea c
		ON b.fixeddrainagelevelarea_id_1 = c.id
		LEFT JOIN checks.fixeddrainagelevelarea d
		ON b.fixeddrainagelevelarea_id_2 = d.id
		) e
	WHERE a.id = e.id
	--Toegevoegd: EV 20180412
	AND opmerking LIKE '%duiker op overstort%'
;
		
-- 1.7b) Duiker/sifon kruist peilgrens (zonder aangesloten stuw of gemaal), is afsluitbaar en heeft een inlaatfunctie: zet dicht door discharge_coefficient op 0 te zetten		
UPDATE checks.culvert
    SET 
	opmerking = concat_ws(',',opmerking,'afsluitbare inlaat op peilgrens'),
	discharge_coefficient_positive = 0.0,
	discharge_coefficient_negative = 0.0
	WHERE op_peilgrens
	AND NOT attached
    AND type IN (3,7); -- afsluitbare inlaat duikers en afsluitbare inlaat sifons (type 3 = duiker, type 7 = syphon)
	--1118 (01-05-2017)
	
-- 1.7c) Duiker/sifon kruist peilgrens (zonder aangesloten stuw of gemaal), is afsluitbaar en heeft een afvoerfunctie (dwz afvoerfunctie in DAMO (type 4 of 8)): zet dicht door discharge_coefficient op 0 te zetten
UPDATE checks.culvert
    SET opmerking = concat_ws(',',opmerking,'afsluitbare afvoer op peilgrens'),
	discharge_coefficient_positive = 0.0,
	discharge_coefficient_negative = 0.0
	WHERE op_peilgrens
	AND NOT attached
    AND type IN (4,8)
	AND NOT hdb_open;-- afsluitbare duikers (anders dan inlaat duiker), en afsluitbare sifons (anders dan inlaat sifon)

-- Zet bovenstroomse BOB op maximale streefpeil (indien hdb zegt modelleren_als 'open'
UPDATE checks.culvert a
	SET bed_level_upstream = GREATEST(a.bed_level_upstream,maxpeil),
	opmerking = concat_ws(',',opmerking,'afsluitbare afvoer (hdb:open) op peilgrens')
	FROM (
		SELECT b.id, GREATEST(c.streefpeil_bwn2,d.streefpeil_bwn2) as maxpeil
		FROM checks.culvert b 
		LEFT JOIN checks.fixeddrainagelevelarea c
		ON b.fixeddrainagelevelarea_id_1 = c.id
		LEFT JOIN checks.fixeddrainagelevelarea d
		ON b.fixeddrainagelevelarea_id_2 = d.id
			WHERE b.op_peilgrens
			AND NOT b.attached
			AND b.type IN (4,8)
			AND hdb_open
		) e
	WHERE a.id = e.id;