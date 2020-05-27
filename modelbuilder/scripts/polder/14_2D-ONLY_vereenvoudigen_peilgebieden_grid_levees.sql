-- vereenvoudigen peilgebieden
/*
Voorafgaand aan de koppeling tussen het watersysteem en het maaiveld worden de peilgebieden (en peilafwijkingen) enigszins vereenvoudigd: hoogwatervoorzieningen die voldoen aan bepaalde voorwaarden worden samengevoegd met aangrenzende peilgebieden.
De hoogwatervoorzieningen rondom lintbebouwing of dijksloten zijn vaak langgerekte, smalle peilgebieden met een grote omtrek en een klein oppervlak. Door de grote omtrek is veel verfijning (en dus veel verlies rekensnelheid) nodig om de peilgrens (als levee) juist te modelleren, terwijl het effect op de afvoer naar verwachting klein is. 
De peilgebieden die voldoen aan beide volgende voorwaarden worden samengevoegd met een aangrenzend peilgebied: 
›	De verhouding tussen oppervlak en omtrek is kleiner dan factor 50;
›	Het peilgebied bevat geen primaire afvoerwatergangen;
›	Het oppervlak van het omliggende peilgebied is minstens zo groot als die van de hoogwatervoorziening.
De hoogwatervoorzieningen die hiervoor in aanmerking komen worden samengevoegd met een aangrenzend peilgebied met een lager peil. Bij meerdere peilgebieden kiezen we het peilgebied waarbij het peilverschil het kleinst is. 
De watergangen in de hoogwatervoorzieningen worden getypeerd als ‘isolated’ inclusief de oorspronkelijke peilen en kunstwerken. Ze kunnen de watergangen water bergen als de waterstand in lagere peilvakken stijgt. 
Als het peilgebied geen lager peil in de buurt heeft, wordt het bestempeld als een onderbemaling zonder gemaal. Hier zijn de gegevens onbetrouwbaar. We gaan uit van een 2D grens zonder watergangen en kunstwerken. De gemaakte fout blijft hierdoor zoveel mogelijk geïsoleerd.

*/

-- selecteer primaire afvoerwatergangen
DROP TABLE IF EXISTS tmp.channel_type_linemerge; 
CREATE TABLE tmp.channel_type_linemerge AS
SELECT (ST_dump(
	ST_Buffer(
	ST_UNION(
	a.geom
	)
	,0.1)
	)).geom as bufgeom,
	b.polder_id
FROM deelgebied.channel as a, deelgebied.polder as b
WHERE channel_type_id = 1 AND ST_Intersects(a.geom,b.geom)
GROUP BY b.polder_id
;
CREATE INDEX tmp_channel_type_linemerge_bufgeom ON tmp.channel_type_linemerge USING gist(bufgeom);

DROP TABLE IF EXISTS tmp.channel_afvoer;
CREATE TABLE tmp.channel_afvoer AS
SELECT DISTINCT a.polder_id, ST_Simplify(a.bufgeom,0.1) as bufgeom
FROM tmp.channel_type_linemerge as a, deelgebied.afvoerkunstwerken as b
WHERE ST_Intersects(a.bufgeom,b.geom)
;
CREATE INDEX tmp_channel_afvoer_bufgeom ON tmp.channel_afvoer USING gist(bufgeom);

-- selecteer peilgebieden om op te lossen in de andere
DROP SEQUENCE IF EXISTS newid;
CREATE SEQUENCE newid;
DROP TABLE IF EXISTS tmp.fdla;
CREATE TABLE tmp.fdla AS
SELECT nextval('newid') as id, code, Min(streefpeil_bwn2) as streefpeil_bwn2, (ST_Dump(ST_Union(ST_MakeValid(geom)))).geom as geom
FROM deelgebied.fixeddrainagelevelarea
WHERE (code <> '1000-01' AND code <> '1700-01' AND code <> '1800-01')-- AND code <> '03010-01' AND code <> '6753-01') 
GROUP BY code
;


DROP TABLE IF EXISTS tmp.fdlad;
CREATE TABLE tmp.fdlad AS
SELECT a.id, a.code, a.streefpeil_bwn2, a.geom, ST_Length(ST_ExteriorRing(geom)) as length, 
	ST_Area(a.geom) as area, ST_Area(a.geom) / ST_Length(ST_ExteriorRing(geom)) as verh
FROM tmp.fdla as a
WHERE ST_GeometryType(geom) = 'ST_Polygon'
;
CREATE INDEX tmp_fdlad_geom ON tmp.fdlad USING gist(geom);


-- verwijder alle niet lint bebouwing
DELETE FROM tmp.fdlad
WHERE verh > 50
;
-- verwijder peilgebieden met primaire afvoerwatergangen TODO verbeter afvoerkunstwerken
DELETE FROM tmp.fdlad as a
USING tmp.channel_afvoer as b
WHERE ST_Intersects(a.geom,b.bufgeom) -- sifon gaat ook mee, deel uitgummen? kost veel tijd TODO
;

DELETE FROM tmp.fdlad as a
USING deelgebied.pumpstation as b
WHERE ST_Intersects(a.geom,b.geom) AND (b.opmerking IS NULL OR b.opmerking = '')
;

-- verwijder peilafwijkinggebieden
DELETE FROM tmp.fdlad as a
WHERE code IN ( SELECT code FROM deelgebied.fixeddrainagelevelarea WHERE type = 2)
;

-- maak tabel van overige peilvakken
DROP TABLE IF EXISTS tmp.fdlab;
CREATE TABLE tmp.fdlab AS
SELECT id, code, streefpeil_bwn2, geom
FROM tmp.fdla
WHERE id NOT IN (SELECT id FROM tmp.fdlad) AND ST_GeometryType(geom) = 'ST_Polygon'
;
CREATE INDEX tmp_fdlab_geom ON tmp.fdlab USING gist(geom);



-- bereken de lengte van de gedeelde zijden per peilgebied in de twee verschillende tabellen
DROP TABLE IF EXISTS tmp.touchlist;
CREATE TABLE tmp.touchlist AS
SELECT a.id AS id_a, b.id AS id_b,
  ST_Length(ST_CollectionExtract(ST_Intersection(a.geom, b.geom), 2))
FROM tmp.fdlad a, tmp.fdlab b
WHERE ST_Touches(a.geom, b.geom)
;

-- join het id van het peilgebied met de langste grens aan de peilgebieden die dissolved worden en voeg samen met de overige peilgebieden
DROP TABLE IF EXISTS tmp.fdladb;
CREATE TABLE tmp.fdladb AS
SELECT DISTINCT ON (a.id) a.id, a.code, a.streefpeil_bwn2, a.geom, b.id_b as newid, ST_PointOnSurface(a.geom) as pointgeom
FROM tmp.fdlad as a
LEFT JOIN tmp.touchlist as b
ON a.id = b.id_a
ORDER BY a.id, b.st_length DESC
;
INSERT INTO tmp.fdladb
SELECT *, id as newid, ST_PointOnSurface(geom) as pointgeom
FROM tmp.fdlab
;
CREATE INDEX tmp_fdladb_pointgeom ON tmp.fdladb USING gist(pointgeom);
CREATE INDEX tmp_fdladb_geom ON tmp.fdladb USING gist(geom);

-- nog een iteratie om ingesloten hoogwatervoorzieningen ook op te lossen samen met andere oogwatervoorzieningen.
WITH touchlist AS (
	SELECT DISTINCT ON (a.id) a.id AS id_a, b.newid AS newid,
		ST_Length(ST_CollectionExtract(ST_Intersection(a.geom, b.geom), 2))
	FROM tmp.fdladb a, tmp.fdladb b
	WHERE ST_Touches(a.geom, b.geom) AND a.newid IS NULL AND b.newid IS NOT NULL
	ORDER BY a.id, ST_Length(ST_CollectionExtract(ST_Intersection(a.geom, b.geom), 2)) DESC
	)
UPDATE tmp.fdladb as a
SET newid = b.newid
FROM touchlist as b
WHERE a.id = b.id_a
;

-- overgebleven liggen buiten de polders of hebben geen goeie geometrie
DELETE FROM tmp.fdladb WHERE newid IS NULL;

-- merge de peilgebieden op basis van het nieuwe id
DROP TABLE IF EXISTS deelgebied.fixeddrainagelevelarea_simple;
CREATE TABLE deelgebied.fixeddrainagelevelarea_simple AS
SELECT newid as id, ST_MakeValid(ST_Union(geom)) as geom
FROM tmp.fdladb
GROUP BY newid
;
CREATE INDEX deelgebied_fdla_simple_geom ON deelgebied.fixeddrainagelevelarea_simple USING gist(geom);
CREATE INDEX deelgebied_fdla_simple_id ON deelgebied.fixeddrainagelevelarea_simple USING btree(id);


-- selecteer levees die helemaal in de vereenvoudigde peilgebieden vallen (deze hoeven we niet mee te nemen)
DROP TABLE IF EXISTS tmp.levee_removers;
CREATE TABLE tmp.levee_removers AS
SELECT a.*
FROM deelgebied.levee as a, deelgebied.fixeddrainagelevelarea_simple as b
WHERE ST_Contains(b.geom,a.midgeom)
;

--DELETE FROM deelgebied.levee WHERE levee_id IN (SELECT levee_id FROM tmp.levee_removers);
