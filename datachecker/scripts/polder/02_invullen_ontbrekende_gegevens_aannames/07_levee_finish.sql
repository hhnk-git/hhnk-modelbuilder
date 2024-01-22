-- inladen en samenvoegen
DROP TABLE IF EXISTS checks.levee
;

CREATE TABLE checks.levee AS
SELECT
    wkb_geometry as geom
  , ring_id      as levee_ring_id
  , max_wl       as maximum_water_level
  , objectid     as levee_id
  , height
  , NULL::varchar(250)                                                               as opmerking
FROM
    tmp.levee_height
WHERE
    ST_Length(wkb_geometry) > 2
;

CREATE INDEX checks_levee_geom
ON
    checks.levee
USING gist
    (
        geom
    )
;


-- check of hoogte valide is
UPDATE
    checks.levee
SET opmerking = 'Levee below waterlevel +30cm'
  , height    = maximum_water_level + 0.3
WHERE
    (
        maximum_water_level + 0.3
    )
    > height
;

drop sequence if exists serial;
create sequence serial;
select
    setval('serial', max(levee_id))
from
    checks.levee
;
--toevoegen keringen en wegen
INSERT INTO checks.levee
SELECT DISTINCT
    (ST_Dump(wkb_geometry)).geom as geom
  , id      as levee_ring_id
  , -9999       as maximum_water_level
  , nextval('serial')     as levee_id
  , height
  , CASE WHEN a.type LIKE 'weg' THEN concat(weg_typeweg,';',weg_fysiekvoorkomen,';',weg_naam)
		 WHEN a.type LIKE 'kering%' THEN concat(waterkering_code,';',waterkering_naam)
		 WHEN a.type LIKE 'spoor' THEN concat(a.type,';',spoor_geocode_naam)
	END as opmerking
FROM hdb.keringen_hoge_lijnelementen a, checks.polder
WHERE ST_INTERSECTS(wkb_geometry,geom) 
	AND id NOT IN (
		SELECT id 
		FROM hdb.keringen_hoge_lijnelementen
		WHERE weg_fysiekvoorkomen LIKE '%brug%'
			OR weg_fysiekvoorkomen LIKE '%tunnel%'
			OR weg_fysiekvoorkomen LIKE '%overkluisd%'
			)
;

-- opruimen
DROP TABLE IF EXISTS tmp.peilgrenzen
;

DROP TABLE IF EXISTS tmp.peilgrenzen2
;

DROP TABLE IF EXISTS tmp.levee
;

DROP TABLE IF EXISTS tmp.polder_inside
;