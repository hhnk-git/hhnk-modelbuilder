/* 
Voer uit nadat connection_nodes zijn aangemaakt. Dit script draait alleen de pomprichting om indien de pomprichting (gegeven de aangeleverde data) in tegengestelde richting (van/naar peilgebied) is.
Is er onduidelijkheid over de te koppelen peilgebieden, of de aangeleverde data heeft een ongeldig/meerdere peilgebieden per veld, dan worden deze genegeerd.
*/




DROP TABLE IF EXISTS tmp.pump_conn_node_level;
CREATE TABLE tmp.pump_conn_node_level AS(
    SELECT
        a.id as pumpstation_id,
        a.connection_node_start_id,
        a.connection_node_end_id,
        b.initial_waterlevel as ini_wl_start,
        c.initial_waterlevel as ini_wl_end,
        b.initial_waterlevel > c.initial_waterlevel OR (b.initial_waterlevel IS NULL AND c.initial_waterlevel IS NOT NULL) as reverse_dir
    FROM v2_pumpstation a
    LEFT JOIN v2_connection_nodes b ON a.connection_node_start_id = b.id
    LEFT JOIN v2_connection_nodes c ON a.connection_node_end_id = c.id
);

UPDATE tmp.pump_conn_node_level SET reverse_dir = FALSE WHERE reverse_dir IS NULL;

UPDATE v2_pumpstation 
SET connection_node_start_id = connection_node_end_id,
connection_node_end_id = connection_node_start_id
WHERE id IN (SELECT pumpstation_id FROM tmp.pump_conn_node_level WHERE reverse_dir);

UPDATE v2_pumpstation a
SET start_level = least(b.ini_wl_start,b.ini_wl_end)+0.02,
lower_stop_level = least(b.ini_wl_start,b.ini_wl_end)-0.03
FROM (SELECT * FROM tmp.pump_conn_node_level) b
WHERE a.id = b.pumpstation_id;

DROP TABLE IF EXISTS tmp.connection_node_fdla;
CREATE TABLE tmp.connection_node_fdla AS(
	SELECT 
		a.id as connection_node_id, 
		b.code as fdla_code, 
		b.streefpeil_bwn2
	FROM 
		v2_connection_nodes a
	LEFT JOIN
		deelgebied.fixeddrainagelevelarea b
	ON 
		(		
				a.id IN (SELECT connection_node_start_id 	FROM v2_pumpstation)
			OR 	a.id IN (SELECT connection_node_end_id 		FROM v2_pumpstation)
		)
		AND ST_Intersects(a.the_geom,b.geom)
);

DROP TABLE IF EXISTS tmp.pumpstation_peil;
CREATE TABLE tmp.pumpstation_peil AS(
	SELECT 
	a.*,
	b.fdla_code as schema_from_fixeddrainagelevelarea_code,
	c.fdla_code as schema_to_fixeddrainagelevelarea_code,
	b.streefpeil_bwn2 as schema_from_peil,
	c.streefpeil_bwn2 as schema_to_peil,
	d.from_fixeddrainagelevelarea_code::text as data_from_fixeddrainagelevelarea_code,
	d.to_fixeddrainagelevelarea_code::text as data_to_fixeddrainagelevelarea_code

	FROM
		v2_pumpstation a

	LEFT JOIN tmp.connection_node_fdla b
	ON a.connection_node_start_id = b.connection_node_id

	LEFT JOIN tmp.connection_node_fdla c
	ON a.connection_node_end_id = c.connection_node_id

	LEFT JOIN deelgebied.pumpstation d
	ON a.code = d.code
);

/* OUD SCRIPT


--Maak een tabel met connection_node_id's van pompen en bijbehorende fixeddrainagelevelarea (fdla)
DROP TABLE IF EXISTS tmp.connection_node_fdla;
CREATE TABLE tmp.connection_node_fdla AS(
	SELECT 
		a.id as connection_node_id, 
		b.code as fdla_code, 
		b.streefpeil_bwn2
	FROM 
		v2_connection_nodes a
	LEFT JOIN
		deelgebied.fixeddrainagelevelarea b
	ON 
		(		
				a.id IN (SELECT connection_node_start_id 	FROM v2_pumpstation)
			OR 	a.id IN (SELECT connection_node_end_id 		FROM v2_pumpstation)
		)
		AND ST_Intersects(a.the_geom,b.geom)
);

--Maak een tabel met v2_pumpstations met bijbehorend fdla en peil
DROP TABLE IF EXISTS tmp.pumpstation_peil;
CREATE TABLE tmp.pumpstation_peil AS(
	SELECT 
	a.*,
	b.fdla_code as schema_from_fixeddrainagelevelarea_code,
	c.fdla_code as schema_to_fixeddrainagelevelarea_code,
	b.streefpeil_bwn2 as schema_from_peil,
	c.streefpeil_bwn2 as schema_to_peil,
	d.from_fixeddrainagelevelarea_code::text as data_from_fixeddrainagelevelarea_code,
	d.to_fixeddrainagelevelarea_code::text as data_to_fixeddrainagelevelarea_code

	FROM
		v2_pumpstation a

	LEFT JOIN tmp.connection_node_fdla b
	ON a.connection_node_start_id = b.connection_node_id

	LEFT JOIN tmp.connection_node_fdla c
	ON a.connection_node_end_id = c.connection_node_id

	LEFT JOIN deelgebied.pumpstation d
	ON a.code = d.code
);

-- DONE filter alleen de con_nodes die als start en eind in pumpstation voorkomen
-- DONE op basis van startpeil moet lager zijn dan eindpeil, anders omdraaien
-- DONE als één van de nodes niet in een peilgebied ligt, laat de pomp dan in die richting pompen (uitgaand gemaal)
-- VRAAG wat als het peil niet is ingevuld bij een peilgebied?


ALTER TABLE tmp.pumpstation_peil DROP COLUMN IF EXISTS reverse_dir_peil;
ALTER TABLE tmp.pumpstation_peil DROP COLUMN IF EXISTS reverse_dir_data;
ALTER TABLE tmp.pumpstation_peil ADD COLUMN reverse_dir_peil text;
ALTER TABLE tmp.pumpstation_peil ADD COLUMN reverse_dir_data text;



--Indien aangeleverde richting omgekeerde volgorde aangeeft reverse_dir_data = 'y'
UPDATE tmp.pumpstation_peil SET reverse_dir_data = 'y'
WHERE schema_from_fixeddrainagelevelarea_code = data_to_fixeddrainagelevelarea_code::text
AND schema_to_fixeddrainagelevelarea_code = data_from_fixeddrainagelevelarea_code::text;

--Indien aangeleverde richting overkeenkomt met geschematiseerde richting: reverse_dir_data = 'n', OOK NIET OMKEREN IVM PEILAANNAMES
UPDATE tmp.pumpstation_peil SET reverse_dir_data = 'n'
WHERE schema_from_fixeddrainagelevelarea_code = data_from_fixeddrainagelevelarea_code::text
AND schema_to_fixeddrainagelevelarea_code = data_to_fixeddrainagelevelarea_code::text;

--Indien huidige richting van hoog naar laag pompt, of van NULL (buiten peilgebied) naar NOT NULL (binnen peilgebied): reverse_dir_peil = 'y' --TODO (nog iets met aanvoer/afvoer?)
UPDATE tmp.pumpstation_peil SET reverse_dir_peil = 'y'
WHERE 
		(schema_from_peil > schema_to_peil AND schema_from_peil != 9999 AND schema_to_peil != 9999)
	OR 	(schema_from_fixeddrainagelevelarea_code IS NULL AND schema_to_fixeddrainagelevelarea_code IS NOT NULL);
	--eventueel 9999 als NULL bestempelen, dus altij in richting van 9999 pompen. Dit gaat echter momenteel niet op ivm onbekende (9999) peilen in gebiedsafwijkingen
	
--Draai start/end nodes indien dit uit de aangeleverde richting blijkt. Als deze geen uitsluitsel geeft dan peilen gebruiken.
-- Pas op, onderstaande query altijd uitvoeren icm bovenstaand script, anders draai je de pomprichting weer terug
UPDATE v2_pumpstation 
SET connection_node_start_id = connection_node_end_id,
connection_node_end_id = connection_node_start_id
WHERE code IN 
	(
	SELECT code 
	FROM tmp.pumpstation_peil
	WHERE
		(reverse_dir_data NOT LIKE 'n'
		OR reverse_dir_data IS NULL)
		AND
		(
			reverse_dir_data LIKE 'y'
			OR reverse_dir_peil LIKE 'y'
		)
	);
	
--Verwijderen tijdelijke tabellen	
DROP TABLE IF EXISTS tmp.connection_node_fdla;
--DROP TABLE IF EXISTS tmp.pumpstation_peil;

--SELECT * FROM tmp.pumpstation_peil WHERE schema_from_fixeddrainagelevelarea_code LIKE '%1000-01%' AND data_to_fixeddrainagelevelarea_code NOT LIKE '%1000-01%'
--SELECT * FROM tmp.pumpstation_peil WHERE code LIKE '%25197%'

*/