-- statistieken voor de corretheid van aangeleverde gegevens per peilgebied

--Fix geometrie checks.fixeddrainageleverarea alvorens ST_Intersects te gebruiken
UPDATE checks.fixeddrainagelevelarea SET geom = ST_CollectionExtract(ST_MakeValid(geom),3) WHERE NOT ST_IsValid(geom);

-- aantal kunstwerken per polder tellen met onderscheid maken in primaire en non primaire kunstwerken
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS cnt_pump_error_primair;
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS cnt_pump_error_non_primair;
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS cnt_culvert_error_primair;
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS cnt_culvert_error_non_primair;
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS cnt_weirs_error_primair;
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS cnt_weirs_error_non_primair;
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS cnt_kruising_error_primair;
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS cnt_kruising_error_non_primair;
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS prct_loose_channel;
ALTER TABLE checks.fixeddrainagelevelarea DROP COLUMN IF EXISTS prct_nowayout_channel;

ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN cnt_pump_error_primair integer;
ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN cnt_pump_error_non_primair integer;
ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN cnt_culvert_error_primair integer;
ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN cnt_culvert_error_non_primair integer;
ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN cnt_weirs_error_primair integer;
ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN cnt_weirs_error_non_primair integer;
ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN cnt_kruising_error_primair integer;
ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN cnt_kruising_error_non_primair integer;
ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN prct_loose_channel integer;
ALTER TABLE checks.fixeddrainagelevelarea ADD COLUMN prct_nowayout_channel integer;


/* kunstwerken opmerkingen veld
SELECT DISTINCT ON (opmerking) opmerking FROM checks.pumpstation
"afvoergemaal op poldergrens"
"geen watergang"
"niet op peilgrens"
"meerdere watergangen:"
*/


update checks.fixeddrainagelevelarea a set cnt_pump_error_primair = count
FROM (
	select a.code, count(b.*) 
	from checks.fixeddrainagelevelarea a, checks.pumpstation b 
	where channel_type_id = 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.code
	) as b
WHERE a.code = b.code
;

update checks.fixeddrainagelevelarea a set cnt_pump_error_non_primair = count
FROM (
	select a.code, count(b.*) 
	from checks.fixeddrainagelevelarea a, checks.pumpstation b 
	where channel_type_id != 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.code
	) as b
WHERE a.code = b.code
;

update checks.fixeddrainagelevelarea a set cnt_culvert_error_primair = count
FROM (
	select a.code, count(b.*) 
	from checks.fixeddrainagelevelarea a, checks.culvert b 
	where channel_type_id = 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.code
	) as b
WHERE a.code = b.code
;

update checks.fixeddrainagelevelarea a 
set cnt_culvert_error_non_primair = count
FROM (
	select a.code, count(b.*) 
	from checks.fixeddrainagelevelarea a, checks.culvert b 
	where channel_type_id != 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.code
	) as b
WHERE a.code = b.code
;

update checks.fixeddrainagelevelarea a set cnt_weirs_error_primair = count
FROM (
	select a.code, count(b.*) 
	from checks.fixeddrainagelevelarea a, checks.weirs b 
	where channel_type_id = 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.code
	) as b
WHERE a.code = b.code
;

update checks.fixeddrainagelevelarea a set cnt_weirs_error_non_primair  = count
FROM (
	select a.code, count(b.*) 
	from checks.fixeddrainagelevelarea a, checks.weirs b 
	where channel_type_id != 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.code
	) as b
WHERE a.code = b.code
;


-- hoeveel kruisingen tussen watergangen en peilgrenzen zijn er per peilgebied?
update checks.fixeddrainagelevelarea a set cnt_kruising_error_primair  = count
FROM (
	select a.code, count(b.*) 
	from checks.fixeddrainagelevelarea a, checks.kruising_zonder_kunstwerk b 
	where channel_type_id = 1 and
		ST_Intersects(a.geom,b.pointgeom)
	GROUP BY a.code
	) as b
WHERE a.code = b.code
;

update checks.fixeddrainagelevelarea a set cnt_kruising_error_non_primair  = count
FROM (
	select a.code, count(b.*) 
	from checks.fixeddrainagelevelarea a, checks.kruising_zonder_kunstwerk b 
	where channel_type_id != 1 and
		ST_Intersects(a.geom,b.pointgeom)
	GROUP BY a.code
	) as b
WHERE a.code = b.code
;





/*
-- bereken lengte van watergangen per peilgebied. Duurt lang omdat de channel loose en no way out nog niet bestaan per peilgebied.
WITH alle AS (
	SELECT b.code, sum(ST_Length(a.geom)) as alle_lengte
	FROM checks.channel as a, checks.fixeddrainagelevelarea as b
	WHERE ST_Intersects(a.geom,b.geom)    --       AND b.code = 'GPG-C-4372'
	GROUP BY b.code
	)
, loose AS (
	SELECT b.code, sum(ST_Area(ST_Intersection(a.geom,b.geom)))/0.22 as loose_lengte -- let op, afhankelijk van buffer lengte!
	FROM checks.channel_loose as a, checks.fixeddrainagelevelarea as b
	WHERE ST_Intersects(a.geom,b.geom)    --       AND b.code = 'GPG-C-4372'
	GROUP BY b.code
	)
, nowayout AS (
	SELECT b.code, sum(ST_Area(ST_Intersection(a.geom,b.geom)))/0.22 as nowayout_lengte -- let op, afhankelijk van buffer lengte!
	FROM checks.channel_nowayout as a, checks.fixeddrainagelevelarea as b
	WHERE ST_Intersects(a.geom,b.geom)    --       AND b.code = 'GPG-C-4372'
	GROUP BY b.code
	)
, prcnt AS (
	SELECT a.code, 
	  CASE WHEN b.loose_lengte IS NULL THEN 0 ELSE least(round(((b.loose_lengte/a.alle_lengte)*100)::numeric,2),100) END as looseprcnt, 
	  CASE WHEN c.nowayout_lengte IS NULL THEN 0 ELSE least(round(((c.nowayout_lengte/a.alle_lengte)*100)::numeric,2),100) END as nowayoutprcnt
	FROM alle as a
	LEFT JOIN loose as b
	ON a.code = b.code
	LEFT JOIN nowayout as c
	ON a.code = c.code
	)
UPDATE checks.fixeddrainagelevelarea as f
SET prct_loose_channel = looseprcnt,
	prct_nowayout_channel = nowayoutprcnt
FROM prcnt as g
WHERE f.code = g.code
;

*/