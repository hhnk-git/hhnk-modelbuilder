--Selecteer meerdere kunstwerken van hetzelfde type op exact dezelfde locatie

DROP TABLE IF EXISTS tmp.dubbele_kunstwerken;
CREATE TABLE tmp.dubbele_kunstwerken AS(
			WITH kunstwerken_puntgeometrie AS(
			SELECT 'damo_ruw.brug' as tabel, a.code, a.wkb_geometry FROM damo_ruw.brug a
			UNION ALL
			SELECT 'damo_ruw.gemaal' as tabel, b.code, b.wkb_geometry FROM damo_ruw.gemaal b
			UNION ALL
			SELECT 'damo_ruw.stuw' as tabel, c.code, c.wkb_geometry FROM damo_ruw.stuw c
			UNION ALL
			SELECT 'damo_ruw.vastedam' as tabel, d.code, d.wkb_geometry FROM damo_ruw.vastedam d
			UNION ALL
			SELECT 'damo_ruw.sluis' as tabel, e.code, e.wkb_geometry FROM damo_ruw.sluis e
			UNION ALL
			SELECT 'damo_ruw.vispassage' as tabel, f.code, f.wkb_geometry FROM damo_ruw.vispassage f
		),
	
	dubbele_kunstwerken_geometrie AS(

		SELECT wkb_geometry
		FROM kunstwerken_puntgeometrie
		GROUP BY wkb_geometry
		HAVING COUNT(*)>1
	)
	SELECT a.*
	FROM kunstwerken_puntgeometrie a, dubbele_kunstwerken_geometrie b
	WHERE ST_Intersects(a.wkb_geometry,b.wkb_geometry)
);




DROP TABLE IF EXISTS tmp.dubbele_kunstwerk_code;
CREATE TABLE tmp.dubbele_kunstwerk_code AS(
	SELECT 'damo_ruw.stuw' as tabel, a.code, a.wkb_geometry
	FROM 
		damo_ruw.stuw a
	RIGHT JOIN
		(
		SELECT code
		FROM damo_ruw.stuw
		GROUP BY code
		HAVING count(*)>1
		) b
	ON a.code = b.code

UNION

	SELECT 'damo_ruw.gemaal' as tabel, c.code, c.wkb_geometry
	FROM 
		damo_ruw.gemaal c
	RIGHT JOIN
		(
		SELECT code
		FROM damo_ruw.gemaal
		GROUP BY code
		HAVING count(*)>1
		) d
	ON c.code = d.code

UNION

	SELECT 'damo_ruw.brug' as tabel, e.code, e.wkb_geometry
	FROM 
		damo_ruw.brug e
	RIGHT JOIN
		(
		SELECT code
		FROM damo_ruw.brug
		GROUP BY code
		HAVING count(*)>1
		) f
	ON e.code = f.code)
	
UNION

	SELECT 'damo_ruw.vastedam' as tabel, f.code, f.wkb_geometry
	FROM 
		damo_ruw.vastedam f
	RIGHT JOIN
		(
		SELECT code
		FROM damo_ruw.vastedam
		GROUP BY code
		HAVING count(*)>1
		) g
	ON f.code = g.code	
	
UNION

	SELECT 'damo_ruw.sluis' as tabel, h.code, h.wkb_geometry
	FROM 
		damo_ruw.sluis h
	RIGHT JOIN
		(
		SELECT code
		FROM damo_ruw.sluis
		GROUP BY code
		HAVING count(*)>1
		) i
	ON h.code = i.code	

UNION

	SELECT 'damo_ruw.vispassage' as tabel, j.code, j.wkb_geometry
	FROM 
		damo_ruw.vispassage j
	RIGHT JOIN
		(
		SELECT code
		FROM damo_ruw.vispassage
		GROUP BY code
		HAVING count(*)>1
		) k
	ON j.code = k.code	
	
	
UNION

	SELECT 'damo_ruw.duikersifonhevel' as tabel, l.code, l.wkb_geometry
	FROM 
		damo_ruw.duikersifonhevel l
	RIGHT JOIN
		(
		SELECT code
		FROM damo_ruw.duikersifonhevel
		GROUP BY code
		HAVING count(*)>1
		) m
	ON l.code = m.code	
	;
	
	
-- Verwijder bruggen wanneer deze samen vallen met stuwen
UPDATE checks.bridge SET isusable = 0
WHERE code IN(
	SELECT a.code
	FROM tmp.dubbele_kunstwerken a
	LEFT JOIN tmp.dubbele_kunstwerken b
	ON a.wkb_geometry=b.wkb_geometry
	AND a.code NOT LIKE b.code
	WHERE a.tabel LIKE 'damo_ruw.brug' AND b.tabel LIKE 'damo_ruw.stuw'
	)
;

-- Verwijder gemalen wanneer deze niet afvoerend zijn (!type 2) en samen vallen met een stuw
UPDATE checks.pumpstation SET isusable = 0
WHERE code IN(
	SELECT a.code
	FROM tmp.dubbele_kunstwerken a
	LEFT JOIN tmp.dubbele_kunstwerken b
	ON a.wkb_geometry=b.wkb_geometry
	AND a.code NOT LIKE b.code
	WHERE a.tabel LIKE 'damo_ruw.gemaal' AND b.tabel LIKE 'damo_ruw.stuw'
	)
AND type NOT LIKE '2'
;

-- Verwijder stuw wanneer deze samenvallen met een afvoerend gemaal (type 2)
UPDATE checks.weirs SET isusable = 0
WHERE code IN(
	SELECT a.code
	FROM tmp.dubbele_kunstwerken a
	LEFT JOIN tmp.dubbele_kunstwerken b
	ON a.wkb_geometry=b.wkb_geometry
	AND a.code NOT LIKE b.code
	LEFT JOIN checks.pumpstation c
	ON b.code = c.code
	WHERE a.tabel LIKE 'damo_ruw.stuw' AND b.tabel LIKE 'damo_ruw.gemaal' AND c.type LIKE '2'
	)
;

-- Verwijder stuw wanneer deze samenvalt met een vastedam
UPDATE checks.weirs SET isusable = 0
WHERE code IN(
	SELECT a.code
	FROM tmp.dubbele_kunstwerken a
	LEFT JOIN tmp.dubbele_kunstwerken b
	ON a.wkb_geometry=b.wkb_geometry
	AND a.code NOT LIKE b.code
	WHERE a.tabel LIKE 'damo_ruw.stuw' AND b.tabel LIKE 'damo_ruw.vastedam'
	)
;


-- 1 check tabel maken met zowel dubbele kunstwerken (geom) als dubbele kunstwerken (code)
DROP TABLE IF EXISTS checks.dubbele_kunstwerken;
CREATE TABLE checks.dubbele_kunstwerken AS SELECT
    tabel,
    code,
    'dubbele geom'::varchar(100) as opmerking,
    st_collectionExtract(wkb_geometry, 1)  as geom_point,
    st_collectionExtract(wkb_geometry, 2)  as geom_line
FROM tmp.dubbele_kunstwerken
;

INSERT INTO checks.dubbele_kunstwerken(tabel, code, opmerking, geom_point, geom_line) 
SELECT 
    tabel, 
    code,
    'dubbele code',
    st_collectionExtract(wkb_geometry, 1)  as geom_point,
    st_collectionExtract(wkb_geometry, 2)  as geom_line
FROM tmp.dubbele_kunstwerk_code
;

-- drop tmp tabellen
DROP TABLE IF EXISTS tmp.dubbele_kunstwerken;
DROP TABLE IF EXISTS tmp.dubbele_kunstwerk_code;