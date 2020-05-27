-- Welke kunstwerken liggen te ver van een watergang af?
-- Welke kunstwerken zijn niet duidelijk aan een watergang te koppelen?
-- Welke kunstwerken zijn eenduidig te koppelen?

-- Welke kunstwerken liggen te ver van een watergang af?
UPDATE checks.weirs as a
SET opmerking = concat_ws(',',a.opmerking,'geen watergang')
  WHERE a.code NOT IN (
	SELECT a.code
	FROM checks.weirs as a, checks.channel_linemerge as b
	WHERE ST_Intersects(b.bufgeom,a.geom)
	)
; --107/4650
-- 37/ 4951 (27-03-2017)
-- 24 / 4959 (01-05-2017)

UPDATE checks.fixed_dam as a
SET opmerking = concat_ws(',',a.opmerking,'geen watergang')
  WHERE a.code NOT IN (
	SELECT a.code
	FROM checks.fixed_dam as a, checks.channel_linemerge as b
	WHERE ST_Intersects(b.bufgeom,a.geom)
	)
; -- 3491/6939
--  3723/7137 (27-03-2017)
-- 3887/7287 (01-05-2017)

UPDATE checks.bridge as a
SET opmerking = concat_ws(',',a.opmerking,'geen watergang')
  WHERE a.code NOT IN (
	SELECT a.code
	FROM checks.bridge as a, checks.channel_linemerge as b
	WHERE ST_Intersects(b.bufgeom,a.geom)
	)
; --198
--   200/11649 (27-03-2017)
-- 191/11649 (01-05-2017)

UPDATE checks.pumpstation as a
SET opmerking = concat_ws(',',a.opmerking,'geen watergang')
  WHERE a.code NOT IN (
	SELECT a.code
	FROM checks.pumpstation as a, checks.channel_linemerge as b
	WHERE ST_Intersects(b.bufgeom,a.geom)
	)
  ;-- 105/2090
  --   116/2118 (27-03-2017)
  -- 74/2119 (01-05-2017)

-- duikers als lijn
-- voor duikers moet helemaal op dezelfde watergang liggen (vandaar contains ipv intersects) --ONZEKER IVM GEBRUIKTE LINEMERGE
UPDATE checks.culvert as a
SET opmerking = concat_ws(',',a.opmerking,'geen watergang')
--SELECT a.code, a.geom, 'duiker komt niet overeen met watergang'::varchar(200) as omschrijving
--FROM checks.culvert as a
  WHERE a.code NOT IN (
	SELECT a.code
	FROM checks.culvert as a, checks.channel_linemerge as b
	WHERE ST_Contains(b.bufgeom,a.geom)
	)
  ; --9973/48652 van alle duikers bij 10cm 
	--3376/48806	27-03-2017
	--2675/48939 (01-05-2017)
  
  
/* Check if syphons in NXT schema were EXACTLY contained by a hydroobject */
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
  
-- Voeg opmerking toe aan duiker als een gemaal binnen zijn buffer valt

UPDATE checks.culvert as a
SET opmerking = concat_ws(',',a.opmerking,'pomp op duiker')
	WHERE a.code IN(
		SELECT a.code
		FROM checks.culvert as a, checks.pumpstation as b
		WHERE ST_Intersects(b.geom,a.geom)
	
	); -- 142
	--138 (01-05-2017)
	
	
-- Voeg opmerking toe aan duiker als een stuw binnen zijn buffer valt
UPDATE checks.culvert as a
SET opmerking = concat_ws(',',a.opmerking,'stuw op duiker')
	WHERE a.code IN(
		SELECT a.code
		FROM checks.culvert as a, checks.weirs as b
		WHERE ST_Intersects(b.geom,a.geom)
	
	); --1353
	--1359 (01-05-2017)
  
-- Welke kunstwerken zijn niet duidelijk aan een watergang te koppelen? -- HIERVOOR DE VEREENVOUDIGDE WATERGANGEN GEBRUIKEN
--DROP TABLE IF EXISTS checks.return_kunstwerk_meerdere_watergangen;
--CREATE TABLE checks.return_kunstwerk_meerdere_watergangen AS
WITH koppels AS (
	SELECT a.code, a.geom, count(b.*), min(b.channel_type_id) as channel_type_id
	FROM checks.pumpstation as a, checks.channel_linemerge as b
	WHERE ST_Intersects(b.bufgeom,a.geom)
	GROUP BY a.code, a.geom
	)
UPDATE checks.pumpstation as a
SET opmerking = concat_ws(',',a.opmerking,('meerdere watergangen:'||count))--, wgtype_id = b.channel_type_id
FROM koppels as b
WHERE a.code = b.code AND count > 2
; --65/2090
-- 9/2118 (27-03-2017)
-- 3/2119 (01-05-2017)



WITH koppels AS (
	SELECT a.code, a.geom, count(b.*), min(b.channel_type_id) as channel_type_id
	FROM checks.bridge as a, checks.channel_linemerge as b
	WHERE ST_Intersects(b.bufgeom,a.geom)
	GROUP BY a.code, a.geom
	)
UPDATE checks.bridge as a
SET opmerking = concat_ws(',',a.opmerking,('meerdere watergangen:'||count))
FROM koppels as b
WHERE a.code = b.code AND count > 2
; --22
--22/11649 (01-05-2017)


WITH koppels AS (
	SELECT a.code, a.geom, count(b.*), min(b.channel_type_id) as channel_type_id
	FROM checks.weirs as a, checks.channel_linemerge as b
	WHERE ST_Intersects(b.bufgeom,a.geom)
	GROUP BY a.code, a.geom
	)
UPDATE checks.weirs as a
SET opmerking = concat_ws(',',a.opmerking,('meerdere watergangen:'||count))--, wgtype_id = channel_type_id
FROM koppels as b
WHERE a.code = b.code AND count > 2
; --102/4650
--  446/4951 (27-03-2017)
-- 354/4959 (01-05-2017)

WITH koppels AS (
	SELECT a.code, a.geom, count(b.*), min(b.channel_type_id) as channel_type_id
	FROM checks.fixed_dam as a, checks.channel_linemerge as b
	WHERE ST_Intersects(b.bufgeom,a.geom)
	GROUP BY a.code, a.geom
	)
UPDATE checks.fixed_dam as a
SET opmerking = concat_ws(',',a.opmerking,('meerdere watergangen:'||count))--, wgtype_id = channel_type_id
FROM koppels as b
WHERE a.code = b.code AND count > 2
; --9/6939
--9/7137 (27-03-2017)
--7/7287 (01-05-2017)


-- duikers niet nodig omdat ze dan niet containen. In 

-- Welke kunstwerken zijn eenduidig te koppelen?
-- alles wat over blijft voor gemalen en koppelen channel_id
UPDATE checks.pumpstation as a
SET channel_code = b.id, wgtype_id = b.channel_type_id
FROM checks.channel_linemerge as b
WHERE ST_Intersects(b.bufgeom,a.geom) AND a.opmerking IS NULL 
; --1919
--1993 (27-03-2017)
--2039 (01-05-2017)


--voor stuwen
UPDATE checks.weirs as a
SET channel_code = b.id --, wgtype_id = b.channel_type_id
FROM checks.channel_linemerge as b
WHERE ST_Intersects(b.bufgeom,a.geom) AND a.opmerking IS NULL 
;
--4468 (27-03-2017)
--4581 (01-05-2017)


--voor bruggen
UPDATE checks.bridge as a
SET channel_code = b.id
FROM checks.channel_linemerge as b
WHERE ST_Intersects(b.bufgeom,a.geom) AND a.opmerking IS NULL 
;
-- 11427 (27-03-2017)
-- 11436 (01-05-2017)

--voor duikers
UPDATE checks.culvert as a
SET channel_code = b.id --, wgtype_id = b.channel_type_id
FROM checks.channel_linemerge as b
WHERE ST_Contains(b.bufgeom,a.geom) AND a.opmerking IS NULL
;
-- 40814 (27-03-2017)
-- 44832 (01-05-2017)

--voor vaste dammen
UPDATE checks.fixed_dam as a
SET channel_code = b.id --, wgtype_id = b.channel_type_id
FROM checks.channel_linemerge as b
WHERE ST_Intersects(b.bufgeom,a.geom) AND a.opmerking IS NULL 
;
--3402 (27-03-2017)
--3389 (01-05-2017)