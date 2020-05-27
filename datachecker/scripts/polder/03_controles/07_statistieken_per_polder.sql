-- bepaal het aantal afvoer kunstwerken per polder
ALTER TABLE checks.polder DROP COLUMN IF EXISTS cnt_afvrkw;
ALTER TABLE checks.polder ADD cnt_afvrkw integer;
UPDATE checks.polder as a
SET cnt_afvrkw = count(b.*)
FROM (	SELECT count(b.*), a.polder_id
	FROM checks.polder as a
	LEFT JOIN checks.afvoerkunstwerken as b
	ON ST_Intersects(a.geom,b.linegeom)
	GROUP BY a.polder_id::numeric
	) as b
WHERE a.polder_id = b.polder_id
;
--polders zonder afvoerkunstwerken kloppen sowieso niet... Deze met hoge prio uit laten zoeken door hhnk...
ALTER TABLE checks.afvoergebieden DROP COLUMN IF EXISTS cnt_afvrkw;
ALTER TABLE checks.afvoergebieden ADD cnt_afvrkw integer;
UPDATE checks.afvoergebieden as a
SET cnt_afvrkw = count(b.*)
FROM (	SELECT count(b.*), a.afvoer_id
	FROM checks.afvoergebieden as a
	LEFT JOIN checks.afvoerkunstwerken as b
	ON ST_Intersects(a.geom,b.linegeom)
	GROUP BY a.afvoer_id::numeric
	) as b
WHERE a.afvoer_id = b.afvoer_id
;
--polders zonder afvoerkunstwerken klopppen sowieso niet... Deze met hoge prio uit laten zoeken door hhnk...

-- aantal kunstwerken per polder tellen met onderscheid maken in primaire en non primaire kunstwerken
ALTER TABLE checks.polder DROP COLUMN IF EXISTS name;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS type;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS cnt_pump_error_primair;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS cnt_pump_error_non_primair;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS cnt_culvert_error_primair;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS cnt_culvert_error_non_primair;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS cnt_weirs_error_primair;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS cnt_weirs_error_non_primair;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS cnt_kruising_error_primair;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS cnt_kruising_error_non_primair;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_loose_channel;
ALTER TABLE checks.polder DROP COLUMN IF EXISTS prct_nowayout_channel;
ALTER TABLE checks.polder ADD COLUMN name varchar(50);
ALTER TABLE checks.polder ADD COLUMN type varchar(50);
ALTER TABLE checks.polder ADD COLUMN cnt_pump_error_primair integer;
ALTER TABLE checks.polder ADD COLUMN cnt_pump_error_non_primair integer;
ALTER TABLE checks.polder ADD COLUMN cnt_culvert_error_primair integer;
ALTER TABLE checks.polder ADD COLUMN cnt_culvert_error_non_primair integer;
ALTER TABLE checks.polder ADD COLUMN cnt_weirs_error_primair integer;
ALTER TABLE checks.polder ADD COLUMN cnt_weirs_error_non_primair integer;
ALTER TABLE checks.polder ADD COLUMN cnt_kruising_error_primair integer;
ALTER TABLE checks.polder ADD COLUMN cnt_kruising_error_non_primair integer;
ALTER TABLE checks.polder ADD COLUMN prct_loose_channel integer;
ALTER TABLE checks.polder ADD COLUMN prct_nowayout_channel integer;


/* kunstwerken opmerkingen veld
SELECT DISTINCT ON (opmerking) opmerking FROM checks.pumpstation
"afvoergemaal op poldergrens"
"geen watergang"
"niet op peilgrens"
"meerdere watergangen:"
*/
-- koppel een naam van een van de aan/afvoergebieden
UPDATE checks.polder as a
SET name = b.name, type = b.polder_type
FROM checks.polderclusters as b
WHERE a.polder_id = b.polder_id
;



update checks.polder a set cnt_pump_error_primair = count
FROM (
	select a.polder_id, count(b.*) 
	from checks.polder a, checks.pumpstation b 
	where channel_type_id = 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.polder_id
	) as b
WHERE a.polder_id = b.polder_id
;

update checks.polder a set cnt_pump_error_non_primair = count
FROM (
	select a.polder_id, count(b.*) 
	from checks.polder a, checks.pumpstation b 
	where channel_type_id != 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.polder_id
	) as b
WHERE a.polder_id = b.polder_id
;

update checks.polder a set cnt_culvert_error_primair = count
FROM (
	select a.polder_id, count(b.*) 
	from checks.polder a, checks.culvert b 
	where channel_type_id = 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%' OR b.opmerking LIKE '%sifon in brondata niet exact op watergang%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.polder_id
	) as b
WHERE a.polder_id = b.polder_id
;

update checks.polder a 
set cnt_culvert_error_non_primair = count
FROM (
	select a.polder_id, count(b.*) 
	from checks.polder a, checks.culvert b 
	where channel_type_id != 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%' OR b.opmerking LIKE '%sifon in brondata niet exact op watergang%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.polder_id
	) as b
WHERE a.polder_id = b.polder_id
;

update checks.polder a set cnt_weirs_error_primair = count
FROM (
	select a.polder_id, count(b.*) 
	from checks.polder a, checks.weirs b 
	where channel_type_id = 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.polder_id
	) as b
WHERE a.polder_id = b.polder_id
;

update checks.polder a set cnt_weirs_error_non_primair  = count
FROM (
	select a.polder_id, count(b.*) 
	from checks.polder a, checks.weirs b 
	where channel_type_id != 1 and
		(b.opmerking like '%geen watergang%' OR b.opmerking LIKE '%meerdere%' OR b.opmerking LIKE '%niet op peilgrens%') and 
		ST_Intersects(a.geom,b.geom)
	GROUP BY a.polder_id
	) as b
WHERE a.polder_id = b.polder_id
;


-- hoeveel kruisingen tussen watergangen en peilgrenzen zijn er per polder?
update checks.polder a set cnt_kruising_error_primair  = count
FROM (
	select a.polder_id, count(b.*) 
	from checks.polder a, checks.kruising_zonder_kunstwerk b 
	where channel_type_id = 1 and
		ST_Intersects(a.geom,b.pointgeom)
	GROUP BY a.polder_id
	) as b
WHERE a.polder_id = b.polder_id
;

update checks.polder a set cnt_kruising_error_non_primair  = count
FROM (
	select a.polder_id, count(b.*) 
	from checks.polder a, checks.kruising_zonder_kunstwerk b 
	where channel_type_id != 1 and
		ST_Intersects(a.geom,b.pointgeom)
	GROUP BY a.polder_id
	) as b
WHERE a.polder_id = b.polder_id
;

-- bereken lengte van watergangen per polder
WITH alle AS (
	SELECT b.polder_id, sum(ST_Length(a.geom)) as alle_lengte
	FROM checks.channel as a, checks.polder as b
	WHERE ST_Intersects(a.pointgeom,b.geom)
	GROUP BY b.polder_id
	)
, loose AS (
	SELECT b.polder_id, sum(lengte) as loose_lengte
	FROM checks.channel_loose as a, checks.polder as b
	WHERE ST_Intersects(a.pointgeom,b.geom)
	GROUP BY b.polder_id
	)
, nowayout AS (
	SELECT b.polder_id, sum(lengte) as nowayout_lengte
	FROM checks.channel_nowayout as a, checks.polder as b
	WHERE ST_Intersects(a.pointgeom,b.geom)
	GROUP BY b.polder_id
	)
, prcnt AS (
	SELECT a.polder_id, 
	  CASE WHEN b.loose_lengte IS NULL THEN 0 ELSE least(round(((b.loose_lengte/a.alle_lengte)*100)::numeric,2),100) END as looseprcnt, 
	  CASE WHEN c.nowayout_lengte IS NULL THEN 0 ELSE least(round(((c.nowayout_lengte/a.alle_lengte)*100)::numeric,2),100) END as nowayoutprcnt
	FROM alle as a
	LEFT JOIN loose as b
	ON a.polder_id = b.polder_id
	LEFT JOIN nowayout as c
	ON a.polder_id = c.polder_id
	)
UPDATE checks.polder as f
SET prct_loose_channel = looseprcnt,
	prct_nowayout_channel = nowayoutprcnt
FROM prcnt as g
WHERE f.polder_id = g.polder_id
;

-- select * from checks.polder where cnt_afvrkw <1
-- 11 polders zonder afvoerend kunstwerk


