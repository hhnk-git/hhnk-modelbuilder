-- DIT SCRIPT BESTAAT UIT TWEE DELEN
-- DEEL I = uniforme rekenroosters maken over het hele studiegebied voor alle refinement_levels (kmax en gridspace opgeven!) --> duurt lang!!
-- DEEL II = grid refinement maken en daarna quadtree maken -- duurt kort!!
-- ADVIES = draai DEEL 1 slecht eenmaal, en daarna kun je DEEL II steeds opnieuw aanzetten (met steeds andere voorkeuren voor grid_refiment)


--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- DEEL II = grid_refiment en quadtree maken
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/* Methode selectie connected/isolated/embedded en grid refinement voor landelijk vlak volgens:
0. LEVEE's overal minimaal 80m rekencellen
1. Verfijn de rekencellen tot 40m als er alleen een levee in de rekencel ligt
2. Verfijn de rekencellen maximaal zolang er een watergang en een levee in liggen

3. alle watergangen worden embedded tenzij:
A. Alle primaire afvoerwatergangen maken we connected
B. Alle watergangen in een rekencel waar ook een levee door loopt worden connected, de levee's zijn gebaseerd op de vereenvoudigde peilgebieden
C. Alle watergangen in een opgeheven peilgebied worden isolated
D. watergangen deels buiten model worden isolated
E. Watergangen met randvoorwaarden worden isolated
*/

-- kmax grid_space
-- 1    20x20
-- 2    40x40
-- 3    80x80
-- 4    160x160

-- 0. LEVEE's overal minimaal k3 rekencellen
--ALTER TABLE deelgebied.levee DROP COLUMN refinement_level;
ALTER TABLE deelgebied.levee DROP COLUMN IF EXISTS refinement_level;
ALTER TABLE deelgebied.levee ADD COLUMN refinement_level integer;
UPDATE deelgebied.levee SET refinement_level = 3;

-- 1. RK: Verfijn de rekencellen tot k2 als er alleen een levee in de k1 rekencel ligt
UPDATE deelgebied.levee as a
SET refinement_level = 2
FROM tmp.k1_count as b
WHERE ST_Intersects(a.geom,b.geom) AND b.count = 0 AND b.max_peil IS NOT NULL
;
-- 2. Verfijn de rekencellen tot k2 zolang er een watergang en een levee in de k3 rekencel ligt
UPDATE deelgebied.levee as a
SET refinement_level = 2 
FROM tmp.k3_count as b 
WHERE ST_Intersects(a.geom,b.geom) AND b.count > 0 AND b.max_peil IS NOT NULL
;
-- 3. Verfijn de rekencellen tot k1 zolang er een watergang en een levee in de k2 rekencel ligt
UPDATE deelgebied.levee as a
SET refinement_level = 1 
FROM tmp.k2_count as b
WHERE ST_Intersects(a.geom,b.geom) AND b.count > 0 AND b.max_peil IS NOT NULL
;
-- 4. Verfijn de rekencellen tot k1 zolang er een watergang en een levee in de k1 rekencel ligt
UPDATE deelgebied.levee as a
SET refinement_level = 1
FROM tmp.k1_count as b 
WHERE ST_Intersects(a.geom,b.geom) AND b.count > 0 AND b.max_peil IS NOT NULL
;

-- 5. vereenvoudig grid refinement
DROP SEQUENCE IF EXISTS newid;
CREATE SEQUENCE newid;
DROP TABLE IF EXISTS deelgebied.grid_refinement;
CREATE TABLE deelgebied.grid_refinement AS
WITH merge AS (
	SELECT levee_ring_id, min(levee_id) as levee_id, refinement_level, ST_Linemerge(ST_UNION(geom)) as geom
	FROM deelgebied.levee
	WHERE refinement_level < 4
	GROUP BY levee_ring_id, refinement_level
	)
SELECT ST_MakeValid((ST_Dump(geom)).geom) as geom, levee_ring_id, refinement_level, nextval('newid') as id
FROM merge
;


-- hieronder wordt daadwerkelijk quadtree shp gemaakt (duurt ongeveer 7 sec voor heel friesland)
--------------------------------
-- loop1 = refinement_level = 1 
---------------------------------
-- eerst alle k1 cellen aanzetten waar deelgebied.grid_refinement met level 1 inzit
update tmp.k1 a set on_off_loop1 = 1 from deelgebied.grid_refinement b where st_intersects(a.geom,b.geom) and b.refinement_level=1;
-- nu zorgen dat alle k1 cellen binnen een k2 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k1 set on_off_loop1 = 1 where k2 in (select k2 from tmp.k1 where on_off_loop1 = 1);

-- nu alle k2 cellen aanzetten die st_touchen met actieve k1 cellen
update tmp.k2 a set on_off_loop1 = 1 from tmp.k1 b where b.on_off_loop1 = 1 and st_touches(a.geom,b.geom);
-- st_touch zet ook diagonale k2_cellen aan. De k2 cellen die als enige actief zijn in een k3 cel, zetten we uit;
update tmp.k2 set on_off_loop1 = 0 where k3 in (select distinct k3 from tmp.k2 where on_off_loop1 = 1 group by k3 having count(*)<2);
-- nu zorgen dat alle k2 cellen binnen een k3 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k2 set on_off_loop1 = 1 where k3 in (select k3 from tmp.k2 where on_off_loop1 = 1);

-- nu alle k3 cellen aanzetten die st_touchen met actieve k2 cellen
update tmp.k3 a set on_off_loop1 = 1 from tmp.k2 b where b.on_off_loop1 = 1 and st_touches(a.geom,b.geom);
-- st_touch artefact oplossen
update tmp.k3 set on_off_loop1 = 0 where k4 in (select distinct k4 from tmp.k3 where on_off_loop1 = 1 group by k4 having count(*)<2);
-- nu zorgen dat alle k2 cellen binnen een k3 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k3 set on_off_loop1 = 1 where k4 in (select k4 from tmp.k3 where on_off_loop1 = 1);

-- nu alle k4 cellen aanzetten die st_touchen met actieve k3 cellen
update tmp.k4 a set on_off_loop1 = 1 from tmp.k3 b where b.on_off_loop1 = 1 and st_touches(a.geom,b.geom);
-- st_touch artefact oplossen
update tmp.k4 set on_off_loop1 = 0 where k5 in (select distinct k5 from tmp.k4 where on_off_loop1 = 1 group by k5 having count(*)<2);
-- nu zorgen dat alle k2 cellen binnen een k3 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k4 set on_off_loop1 = 1 where k5 in (select k5 from tmp.k4 where on_off_loop1 = 1);




--------------------------------
-- loop2 = refinement_level = 2 
---------------------------------
-- eerst alle k2 cellen aanzetten waar deelgebied.grid_refinement met level 2 inzit
update tmp.k2 a set on_off_loop2 = 1 from deelgebied.grid_refinement b where st_intersects(a.geom,b.geom) and b.refinement_level=2;
-- nu zorgen dat alle k2 cellen binnen een k3 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k2 set on_off_loop2 = 1 where k3 in (select k3 from tmp.k2 where on_off_loop2 = 1);

-- nu alle k3 cellen aanzetten die st_touchen met actieve k2 cellen
update tmp.k3 a set on_off_loop2 = 1 from tmp.k2 b where b.on_off_loop2 = 1 and st_touches(a.geom,b.geom);
-- st_touch zet ook diagonale k3 cellen aan. De k3 cellen die als enige actief zijn in een k4 cel, zetten we uit;
update tmp.k3 set on_off_loop2 = 0 where k4 in (select distinct k4 from tmp.k3 where on_off_loop2 = 1 group by k4 having count(*)<2);
-- nu zorgen dat alle k2 cellen binnen een k3 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k3 set on_off_loop2 = 1 where k4 in (select k4 from tmp.k3 where on_off_loop2 = 1);

-- nu alle k4 cellen aanzetten die st_touchen met actieve k3 cellen
update tmp.k4 a set on_off_loop2 = 1 from tmp.k3 b where b.on_off_loop2 = 1 and st_touches(a.geom,b.geom);
-- st_touch artefact oplossen
update tmp.k4 set on_off_loop2 = 0 where k5 in (select distinct k5 from tmp.k4 where on_off_loop2 = 1 group by k5 having count(*)<2);
-- nu zorgen dat alle k2 cellen binnen een k3 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k4 set on_off_loop2 = 1 where k5 in (select k5 from tmp.k4 where on_off_loop2 = 1);


--------------------------------
-- loop3 = refinement_level = 3 
---------------------------------
-- eerst alle k3 cellen aanzetten waar deelgebied.grid_refinement met level 3 inzit
update tmp.k3 a set on_off_loop3 = 1 from deelgebied.grid_refinement b where st_intersects(a.geom,b.geom) and b.refinement_level=3;
-- nu zorgen dat alle k3 cellen binnen een k4 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k3 set on_off_loop3 = 1 where k4 in (select k4 from tmp.k3 where on_off_loop3 = 1);

-- nu alle k4 cellen aanzetten die st_touchen met actieve k3 cellen
update tmp.k4 a set on_off_loop3 = 1 from tmp.k3 b where b.on_off_loop3 = 1 and st_touches(a.geom,b.geom);
-- st_touch artefact oplossen
update tmp.k4 set on_off_loop3 = 0 where k5 in (select distinct k5 from tmp.k4 where on_off_loop3 = 1 group by k5 having count(*)<2);
-- nu zorgen dat alle k2 cellen binnen een k3 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k4 set on_off_loop3 = 1 where k5 in (select k5 from tmp.k4 where on_off_loop3 = 1);



--------------------------------
-- loop4 = refinement_level = 4 
---------------------------------
-- eerst alle k4 cellen aanzetten waar deelgebied.grid_refinement met level 4 inzit
update tmp.k4 a set on_off_loop4 = 1 from deelgebied.grid_refinement b where st_intersects(a.geom,b.geom) and b.refinement_level=4;
-- nu zorgen dat alle k4 cellen binnen een k5 cel actief worden als zojuist minimaal één actief is geworden
update tmp.k4 set on_off_loop4 = 1 where k5 in (select k5 from tmp.k4 where on_off_loop4 = 1);


--------------------------------
-- quadtree maken
---------------------------------
DROP SEQUENCE IF EXISTS id;
CREATE SEQUENCE id;

alter table tmp.k1 add column use integer;
update tmp.k1 set use = 1 where on_off_loop1=1 or on_off_loop2=1 ; --or on_off_loop3=1 or on_off_loop4=1 or on_off_loop4=1;
alter table tmp.k2 add column use integer;
update tmp.k2 set use = 1 where on_off_loop1=1 or on_off_loop2=1 ; --or on_off_loop3=1 or on_off_loop4=1 or on_off_loop4=1;
alter table tmp.k3 add column use integer;
update tmp.k3 set use = 1 where on_off_loop1=1 or on_off_loop2=1 ; --or on_off_loop3=1 or on_off_loop4=1 or on_off_loop4=1;

alter table tmp.k1 add column count integer;
alter table tmp.k1 add column max_peil float;
update tmp.k1 a set count = b.count, max_peil = b.max_peil from tmp.k1_count b where a.pk = b.pk;

alter table tmp.k2 add column count integer;
alter table tmp.k2 add column max_peil float;
update tmp.k2 a set count = b.count, max_peil = b.max_peil from tmp.k2_count b where a.pk = b.pk;

alter table tmp.k3 add column count integer;
alter table tmp.k3 add column max_peil float;
update tmp.k3 a set count = b.count, max_peil = b.max_peil  from tmp.k3_count b where a.pk = b.pk;

alter table tmp.k4 add column count integer;
alter table tmp.k4 add column max_peil float;
update tmp.k4 a set count = b.count, max_peil = b.max_peil  from tmp.k4_count b where a.pk = b.pk;

drop table if exists deelgebied.grid;
create table deelgebied.grid as
select nextval('id') as id, 1::numeric as refinement_level, geom, max_peil, count from tmp.k1 where use=1
union
select nextval('id') as id, 2::numeric as refinement_level, geom, max_peil, count from tmp.k2 where use=1 and pk not in (select k2 from tmp.k1 where use=1)
union
select nextval('id') as id, 3::numeric as refinement_level, geom, max_peil, count from tmp.k3 where use=1 and pk not in (select k3 from tmp.k2 where use=1)
union
select nextval('id') as id, 4::numeric as refinement_level, geom, max_peil, count from tmp.k4 where pk in (select k4 from tmp.k3 where use is null);

delete from deelgebied.grid where id not in (select a.id from deelgebied.grid a, tmp.outerring b where st_contains(b.geom, a.geom));

--$$$$$$$$$$$$$$$$$$$$$$$$$$$$
-- KANAAL TYPES
-- $$$$$$$$$$$$$$$$$$$$$$$$$$$

-- channel type             zoom_category
-- embedded (100)           2
-- isolated (101)           3
-- connected (102)          3
-- primaire afvoer kanalen  5


-- Alle watergangen worden embedded en zoom_category =2, tenzij:
-- UPDATE v2_channel
-- SET calculation_type = 100, doen we niet meer;
-- Alle watergangen worden connected , tenzij:
UPDATE v2_channel
SET calculation_type = 102--, zoom_category = 3
;  -- HIER EVENTUEEL EMBEDDED ZETTEN

-- A. Alle (primaire) afvoerwatergangen maken we connected
UPDATE v2_channel as a
SET calculation_type = 102--,
--zoom_category = 5
FROM tmp.channel_afvoer as b
WHERE ST_Contains(b.bufgeom,a.the_geom)
;

-- B. Alle watergangen in een rekencel waar ook een levee door loopt worden connected, de levee's zijn gebaseerd op de vereenvoudigde peilgebieden
UPDATE v2_channel as a
SET calculation_type = 102
FROM deelgebied.grid as b
WHERE ST_Intersects(a.the_geom,b.geom) AND b.max_peil IS NOT NULL AND b.count > 0
;

-- C. Alle watergangen in een opgeheven peilgebied worden isolated
--UPDATE v2_channel as a
--SET calculation_type = 101
--FROM tmp.fdla as b
--WHERE ST_Intersects(a.the_geom,b.geom) AND b.id NOT IN (SELECT id FROM deelgebied.fixeddrainagelevelarea_simple)
--;

-- D. watergangen aan de rand van het model worden isolated
UPDATE v2_channel as a
SET calculation_type = 101
FROM deelgebied.polder as b
WHERE NOT ST_Contains(b.innergeom,a.the_geom)
AND NOT ST_IsEmpty(innergeom)
;


-- E. Watergangen met randvoorwaarden worden isolated
UPDATE v2_channel as a
SET calculation_type = 101
WHERE connection_node_start_id IN (SELECT connection_node_id as id FROM v2_1d_boundary_conditions)
	OR connection_node_end_id IN (SELECT connection_node_id as id FROM v2_1d_boundary_conditions)
;

-- F. update bank levels bij levees
WITH grid_heigth AS (
	SELECT a.id, a.geom, a.max_peil, a.count, MAX(b.height) as height --> levee hoogte in eerder stadium aan grid toevoegen zoadat het sneller wordt
	FROM deelgebied.grid as a
	LEFT JOIN deelgebied.levee as b
	ON ST_Intersects(a.geom,b.geom)
	GROUP BY a.id, a.geom, a.max_peil, a.count
	)
 , channels AS (
	SELECT a.id, b.height
	FROM v2_channel as a, grid_heigth as b
	WHERE ST_Intersects(a.the_geom,b.geom) AND b.max_peil IS NOT NULL AND b.count > 0
	)
UPDATE v2_cross_section_location as c
SET bank_level = d.height
FROM channels as d
WHERE c.channel_id = d.id
    AND d.height IS NOT NULL
;

-- set the calculation distance to maximum calculation cell size
WITH link AS (
	SELECT a.id, max(b.refinement_level) as max_level
	FROM v2_channel as a, deelgebied.grid as b
	WHERE ST_Intersects(a.the_geom,b.geom)
	GROUP BY a.id
)
UPDATE v2_channel as a
SET dist_calc_points = least(20 * b.max_level, 80)
FROM link as b
WHERE a.id = b.id
;


-- INSERT INTO public TABLES

DELETE FROM v2_grid_refinement;
INSERT INTO v2_grid_refinement(
            id, display_name, refinement_level, the_geom, code)
SELECT id, levee_ring_id, refinement_level, geom, (levee_ring_id || '-' || id)
FROM deelgebied.grid_refinement;

DELETE FROM v2_levee;
INSERT INTO v2_levee(
            id, crest_level, the_geom, code)
SELECT levee_id, height, geom, levee_ring_id  || '-' || levee_id
FROM deelgebied.levee
WHERE ST_GeometryType(geom) = 'ST_LineString';