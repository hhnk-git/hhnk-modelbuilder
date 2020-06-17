-- zijn er peilregelende kunstwerken niet op peilgrens liggen?

-- buffer van de buitenste ringen, dit is de zoekradius waarbinnen de kunstwerken moeten liggen
-- we bufferen de peilgrenzen met 10cm en later kijken we of kunstwerken intersecten met deze buffer. Waarom bufferen en niet gewoon de lijn-lijn intersect? Omdat we van RD naar WGS naar RD gaan EN omdat ruwe data kunstwerken precies stoppen (of beginnen) op een peilgrens. De buffer werkt dus als soort zekerheid (van fix voor verschuivingen).
DROP TABLE IF EXISTS tmp.peilgrenzen;
CREATE TABLE tmp.peilgrenzen AS
SELECT ST_Buffer(ST_ExteriorRing((ST_Dump(ST_Force2D(ST_Transform(geom,28992)))).geom),0.1) as geom
FROM checks.fixeddrainagelevelarea
;
CREATE INDEX tmp_peilgrenzen_geom ON tmp.peilgrenzen USING gist(geom);

/*
-- maak een tabel met de afstand to peilgrens voor figuur
DROP TABLE IF EXISTS tmp.pumpstation_peilgrens_afstand;
CREATE TABLE tmp.pumpstation_peilgrens_afstand AS
SELECT DISTINCT ON (a.code) a.*, ST_Distance(a.geom,b.geom)
FROM checks.pumpstation as a, tmp.peilgrenzen as b
ORDER BY a.code, ST_Distance(a.geom,b.geom)
;
*/

-- selecteer alle gemalen die niet binnen de zoekradius van een peilgrens liggen
UPDATE checks.pumpstation
SET opmerking = concat_ws(',',opmerking,'niet op peilgrens')
WHERE code NOT IN (
	SELECT a.code
	FROM checks.pumpstation as a, 
	tmp.peilgrenzen as b 
	WHERE ST_Intersects(b.geom,a.geom)
	
	UNION
	
	SELECT code 
	FROM hdb.gemalen_op_peilgrens
	WHERE moet_op_peilgrens LIKE '%hoeft niet op peilgrens%'
	)
AND type NOT LIKE '98' --doorspoelgemalen krijgen deze opmerking niet
;
-- SELECT count(*) FROM checks.pumpstation
-- 669/2090 (1e levering), 518/2102 (2e levering)
-- 1552/2118 niet op peilgrens (27-03-2017)

-- selecteer alle stuwen die niet binnen de zoekradius van een peilgrens liggen
UPDATE checks.weirs
SET opmerking = concat_ws(',',opmerking,'niet op peilgrens')
WHERE code NOT IN (
	SELECT a.code 
	FROM checks.weirs as a, 
	tmp.peilgrenzen as b 
	WHERE ST_Intersects(b.geom,a.geom)
	UNION
	SELECT code 
	FROM hdb.stuwen_op_peilgrens
	WHERE moet_op_peilgrens LIKE '%hoeft niet op peilgrens%'
	)
; 
-- SELECT count(*) FROM checks.weirs
-- 2208 (1e levering), 2111/4947 (2e levering)
-- 2300/4951

-- selecteer alle vaste dammen die niet binnen de zoekradius van een peilgrens liggen (in principe zouden alle vaste dammen op een peilgrens moeten liggen)
UPDATE checks.fixed_dam
SET opmerking = concat_ws(',',opmerking,'niet op peilgrens')
WHERE code NOT IN (
	SELECT a.code 
	FROM checks.fixed_dam as a, 
	tmp.peilgrenzen as b 
	WHERE ST_Intersects(b.geom,a.geom)
	)
; 



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

    
-- 1.2) Welke duikers/sifon's kruisen de bufgeom van een peilgrens EN beginnen en eindigen niet in hetzelfde peilgebied. Deze krijgen op_peilgrens = 1.
ALTER TABLE checks.culvert DROP COLUMN IF EXISTS op_peilgrens;
ALTER TABLE checks.culvert ADD COLUMN op_peilgrens integer;
UPDATE checks.culvert a 
    SET op_peilgrens = 1 
    FROM tmp.peilgrenzen as b 
	WHERE a.fixeddrainagelevelarea_array_1 <> a.fixeddrainagelevelarea_array_2
    AND ST_Intersects(a.geom,b.geom);
-- sifon's gaan bijna altijd van zelfde peilgebied naar andere peilgebied. Als ze dat niet doen, dan komen ze hier terug met 'op_peilgrens=1'

-- 1.3) Als er een stuw op die duiker ligt, kunnen we het peil handhaven met de stuw. De duiker ligt dus eigenlijk niet op de peilgrens. Als we verderop de channel_nowayout gaan bepallen wordt (met onderstaande code) deze culvert niet als blokerend segment gezien en weggegooid
UPDATE checks.culvert a 
    SET op_peilgrens = NULL
    FROM checks.weirs as b
    WHERE op_peilgrens = 1 AND b.opmerking IS NULL AND ST_DWithin(a.geom,b.geom,0.1);
        
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
    WHERE op_peilgrens = 1
		AND (NOT level_seperator_indicator OR level_seperator_indicator IS NULL)
		AND (opmerking NOT LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']) OR opmerking IS NULL)
		AND type IN (1,2,5,6,9999)	--Niet afsluitbaar
		AND code NOT IN (
			SELECT code 
			FROM hdb.duikers_op_peilgrens
			WHERE modelleren_als LIKE '%open%'
			);
		--616 (01-05-2017)
		--1699 (27-06-2017) meer omdat ook type 9999 is toegevoegd

-- Duiker/sifon kruist peilgrens, is niet afsluitbaar en heeft geen stuw of gemaal aangesloten. Volgens HDB toch open modelleren: zet BOB op max streefpeil
UPDATE checks.culvert
    SET opmerking = concat_ws(',',opmerking,'niet afsluitbaar (hdb:open) op peilgrens') 
	WHERE op_peilgrens = 1
		AND (NOT level_seperator_indicator OR level_seperator_indicator IS NULL)
		AND (opmerking NOT LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']) OR opmerking IS NULL)
		AND type IN (1,2,5,6,9999)	--Niet afsluitbaar
		AND code IN (
			SELECT code 
			FROM hdb.duikers_op_peilgrens
			WHERE modelleren_als LIKE '%open%'
			);	
			
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
	AND op_peilgrens = 1
	AND (opmerking NOT LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']) OR opmerking IS NULL)
	AND a.code IN (
		SELECT code 
		FROM hdb.duikers_op_peilgrens
		WHERE modelleren_als LIKE '%open%');
		

-- Duiker/sifon kruist peilgrens, is niet afsluitbaar maar ligt op hoogte: zet BOB op max(streefpeil_beneden,streefpeil_boven,bob)		
UPDATE checks.culvert
    SET opmerking = concat_ws(',',opmerking,'duiker op overstort') 
	WHERE op_peilgrens = 1
		AND level_seperator_indicator
		AND (opmerking NOT LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']) OR opmerking IS NULL)
		AND type IN (1,2,5,6,9999)	--Niet afsluitbaar
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
	WHERE op_peilgrens = 1
	AND (opmerking NOT LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']) OR opmerking IS NULL)
    AND type IN (3,7); -- afsluitbare inlaat duikers en afsluitbare inlaat sifons (type 3 = duiker, type 7 = syphon)
	--1118 (01-05-2017)
	
-- 1.7c) Duiker/sifon kruist peilgrens (zonder aangesloten stuw of gemaal), is afsluitbaar en heeft een afvoerfunctie (dwz afvoerfunctie in DAMO (type 4 of 8)): zet dicht door discharge_coefficient op 0 te zetten
UPDATE checks.culvert
    SET opmerking = concat_ws(',',opmerking,'afsluitbare afvoer op peilgrens'),
	discharge_coefficient_positive = 0.0,
	discharge_coefficient_negative = 0.0
	WHERE op_peilgrens = 1
	AND (opmerking NOT LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']) OR opmerking IS NULL)
    AND type IN (4,8)
	AND code NOT IN (SELECT code FROM hdb.duikers_op_peilgrens WHERE modelleren_als LIKE '%open%')
	; -- afsluitbare duikers (anders dan inlaat duiker), en afsluitbare sifons (anders dan inlaat sifon)
	--625 (01-05-2017)

/*	
UPDATE checks.culvert
    SET opmerking = concat_ws(',',opmerking,'afsluitbare afvoer (hdb:open) op peilgrens'),
	--Toegevoegd: EV 20180412
	bed_level_upstream = greatest(bed_level_upstream)
	WHERE op_peilgrens = 1
	AND (opmerking NOT LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']) OR opmerking IS NULL)
    AND type IN (4,8)
	AND code IN (SELECT code FROM hdb.duikers_op_peilgrens WHERE modelleren_als LIKE '%open%')
	;
*/	

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
			WHERE b.op_peilgrens = 1
			AND (b.opmerking NOT LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']) OR b.opmerking IS NULL)
			AND b.type IN (4,8)
			AND b.code IN (SELECT code FROM hdb.duikers_op_peilgrens WHERE modelleren_als LIKE '%open%')
		) e
	WHERE a.id = e.id;
	
-- Zet bovenstroomse BOB dicht (+10mNAP) voor afsluitbare duiker op peilgrens (niet in hdb opgenomen als modelleren_als 'open')

--Weggehaald: EV 20180412
/*
UPDATE checks.culvert
	SET bed_level_upstream = 10
	WHERE op_peilgrens = 1
			AND (opmerking NOT LIKE ALL(ARRAY['%pomp op duiker%','%stuw op duiker%']) OR opmerking IS NULL)
			AND type IN (4,8)
			AND code IN (SELECT code FROM hdb.duikers_op_peilgrens WHERE modelleren_als LIKE '%open%');
*/
			
-- 2.0) We selecteren kruisingen van watergang en peilgrens zonder kunstwerk
DROP TABLE IF EXISTS checks.kruising_zonder_kunstwerk;
CREATE TABLE checks.kruising_zonder_kunstwerk AS(
	WITH correct_crossings AS(
		SELECT channel_code::integer, geom::geometry(Point,28992) as pointgeom, NULL::geometry(Linestring,28992) as linegeom
		FROM checks.pumpstation
		WHERE channel_code IS NOT NULL 
		AND (opmerking NOT LIKE '%niet op peilgrens%' OR opmerking IS NULL)
            UNION ALL
		SELECT channel_code::integer, geom::geometry(Point,28992), NULL::geometry(Linestring,28992) as linegeom
		FROM checks.weirs
		WHERE channel_code IS NOT NULL  
		AND (opmerking NOT LIKE '%niet op peilgrens%' OR opmerking IS NULL)        
            UNION ALL
		SELECT channel_code::integer, NULL, geom::geometry(Linestring,28992) as linegeom
		FROM checks.culvert
		WHERE channel_code IS NOT NULL 
		AND op_peilgrens = 1
		AND on_channel
            UNION ALL
		SELECT channel_code::integer, geom::geometry(Point,28992), NULL::geometry(Linestring,28992) as linegeom
		FROM checks.fixed_dam
		WHERE channel_code IS NOT NULL  
		AND (opmerking NOT LIKE '%niet op peilgrens%' OR opmerking IS NULL)        	
		),
	all_intersections AS(
		SELECT DISTINCT ON (ST_Intersection(a.geom,b.geom)) ST_Intersection(a.geom,b.geom) as pointgeom, a.geom as channelgeom, b.geom as leveegeom, a.id as channel_id, b.levee_ring_id, channel_type_id
		FROM checks.channel_linemerge as a, checks.peilgrens_met_waterpeil as b
		WHERE ST_Intersects(a.geom,b.geom)
		),
	correct_crossing_at_intersection AS(
	SELECT a.channel_code, a.pointgeom --Hier een geom toevoegen van de correct_crossing 
		FROM correct_crossings a, all_intersections b 
		WHERE (ST_DWithin(a.pointgeom, b.pointgeom, 5))
		OR (ST_DWithin(a.linegeom, b.pointgeom, 5))
	)
	SELECT * FROM all_intersections a, (SELECT ST_Union(pointgeom) as geom FROM correct_crossing_at_intersection) b
	WHERE channel_id NOT IN (
		SELECT channel_code --Hier een geom toevoegen van de correct_crossing 
		FROM correct_crossing_at_intersection
		)
	AND NOT ST_DWithin(a.pointgeom, b.geom,5)
	-- AND NOT ST_DWithin(all_intersection.geom, correct.geom, 5) aanleiding: KGM-JH-113 geen KZK maar wel unusable pompje
	);
CREATE INDEX checks_kruising_zonder_kunstwerk_pointgeom ON checks.kruising_zonder_kunstwerk USING gist(pointgeom);

/*
na eindeloos zoeken: Als opmerking is null (dus een stuw die wel goed ligt) dan slaat "opmerking not like '%niet%'" de rij onterecht over. Voorbeeld stuw 'KST-OH-322' die wel goed ligt -->
	- verkeerd, want geen resultaat terug	= SELECT * FROM checks.weirs WHERE code like 'KST-OH-322' AND opmerking NOT LIKE '%niet%';
	- goed, want wel resultaat terug	= SELECT * FROM checks.weirs WHERE code like 'KST-OH-322' AND (opmerking NOT LIKE '%niet%' OR opmerking IS NULL); 

-- renier@wouter(3mrt): waarom bij culvert ook niet where clause met (opmerking NOT LIKE '%niet%' OR opmerking IS NULL) ??


renier denkt dat renier heeft op 3 maart 2017 toegevoegd aan checks.culvert "AND (opmerking NOT LIKE '%niet%' OR opmerking IS NULL)" tijdens de CREATE checks.kruising_zonder_kunstwerk. Zie hieronder de 3 alternatieven. Wouter had gemaakt (1) gemaakt. Het is nu (3).

(1) SELECT count(*)
	FROM checks.culvert
	WHERE channel_code IS NOT NULL 
		AND (type = 3 OR type = 4 OR type = 7 OR type = 8)  -- 2530 hits
		
(2) SELECT count(*)
	FROM checks.culvert
	WHERE channel_code IS NOT NULL 
		AND (type = 3 OR type = 4 OR type = 7 OR type = 8) 
		AND (opmerking NOT LIKE '%niet%') -- 0 hits

(3) SELECT count(*)
	FROM checks.culvert
	WHERE channel_code IS NOT NULL 
		AND (type = 3 OR type = 4 OR type = 7 OR type = 8)  
		AND (opmerking NOT LIKE '%niet%' OR opmerking IS NULL) -- 1729
*/

	
-- vaste dammen uit deze serie halen
--DELETE FROM checks.kruising_zonder_kunstwerk as a
--USING checks.fixed_dam as b
--WHERE ST_DWithin(a.pointgeom,b.geom,5)
--Dit verwijderen of volgende zin toevoegen
--AND BRUIKBARE fixed_dam :(opmerking NOT LIKE '%niet op peilgrens%' OR opmerking IS NULL) ;


-- sifons uit deze serie halen
DELETE FROM checks.kruising_zonder_kunstwerk as a
USING checks.culvert as b
WHERE b.type_art = 2 AND ST_DWithin(a.pointgeom,b.geom,5)
;


-- We gaan eerst de duikers (type_art =1) selecteren waarvan begin en eind punt in zelfde peilgebied liggen
-- deze duikers uit de 'kruising zonder kunsterk' halen 
DELETE FROM checks.kruising_zonder_kunstwerk as a
    USING checks.culvert as b 
    WHERE b.fixeddrainagelevelarea_id_1 = b.fixeddrainagelevelarea_id_2
    AND b.opmerking IS NOT NULL
    AND ST_DWithin(a.pointgeom,b.geom,5);
-- er zijn 7.916 (vd 48.450) duikers die beginnen en eindigen in hetzelfde peilgebied en wel een opmerking hebben

DROP TABLE IF EXISTS tmp.culvert_fdla_id;
DROP TABLE IF EXISTS tmp.pumpstation_peilgrens_afstand;
DROP TABLE IF EXISTS tmp.peilgrenzen;
DROP TABLE IF EXISTS tmp.poldergrenzen;
