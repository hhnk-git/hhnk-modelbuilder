-- zijn er peilregelende kunstwerken niet op peilgrens liggen?

-- buffer van de buitenste ringen, dit is de zoekradius waarbinnen de kunstwerken moeten liggen
-- we bufferen de peilgrenzen met 10cm en later kijken we of kunstwerken intersecten met deze buffer. Waarom bufferen en niet gewoon de lijn-lijn intersect? Omdat we van RD naar WGS naar RD gaan EN omdat ruwe data kunstwerken precies stoppen (of beginnen) op een peilgrens. De buffer werkt dus als soort zekerheid (van fix voor verschuivingen).
DROP TABLE IF EXISTS tmp.peilgrenzen;
CREATE TABLE tmp.peilgrenzen AS
SELECT ST_Buffer(ST_ExteriorRing((ST_Dump(ST_Force2D(ST_Transform(geom,28992)))).geom),0.1) as geom
FROM checks.fixeddrainagelevelarea
;
CREATE INDEX tmp_peilgrenzen_geom ON tmp.peilgrenzen USING gist(geom);

ALTER TABLE checks.pumpstation DROP COLUMN IF EXISTS on_fdla_border;
ALTER TABLE checks.pumpstation ADD COLUMN on_fdla_border boolean DEFAULT false;

UPDATE checks.pumpstation
SET on_fdla_border = true
WHERE code IN(
    SELECT a.code
	FROM checks.pumpstation as a, 
	tmp.peilgrenzen as b 
	WHERE ST_Intersects(b.geom,a.geom)
);


--Make remark (maybe move to quality part if not used)
UPDATE checks.pumpstation
SET opmerking = concat_ws(',',opmerking,'niet op peilgrens')
WHERE 
    NOT on_fdla_border 
    AND code NOT IN (
        SELECT code 
        FROM hdb.gemalen_op_peilgrens
        WHERE moet_op_peilgrens LIKE '%hoeft niet op peilgrens%'
	)
    AND type NOT LIKE '98' --doorspoelgemalen krijgen deze opmerking niet
;


-- selecteer alle stuwen die niet binnen de zoekradius van een peilgrens liggen
ALTER TABLE checks.weir DROP COLUMN IF EXISTS on_fdla_border;
ALTER TABLE checks.weir ADD COLUMN on_fdla_border boolean DEFAULT false;

UPDATE checks.weir
SET on_fdla_border = true
WHERE code IN(
    SELECT a.code
	FROM checks.weir as a, 
	tmp.peilgrenzen as b 
	WHERE ST_Intersects(b.geom,a.geom)
);

UPDATE checks.weirs
SET opmerking = concat_ws(',',opmerking,'niet op peilgrens')
WHERE
    NOT on_fdla_border
    AND code NOT IN (
        SELECT code 
        FROM hdb.stuwen_op_peilgrens
        WHERE moet_op_peilgrens LIKE '%hoeft niet op peilgrens%'
	)
; 

-- selecteer alle vaste dammen die niet binnen de zoekradius van een peilgrens liggen (in principe zouden alle vaste dammen op een peilgrens moeten liggen)
ALTER TABLE checks.fixed_dam DROP COLUMN IF EXISTS on_fdla_border;
ALTER TABLE checks.fixed_dam ADD COLUMN on_fdla_border boolean DEFAULT false;

UPDATE checks.fixed_dam
SET on_fdla_border = true
WHERE code IN(
    SELECT a.code
	FROM checks.fixed_dam as a, 
	tmp.peilgrenzen as b 
	WHERE ST_Intersects(b.geom,a.geom)
);

UPDATE checks.fixed_dam
SET opmerking = concat_ws(',',opmerking,'niet op peilgrens')
WHERE NOT on_fdla_border
;