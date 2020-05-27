--Check damo_ruw op invalid geometry

DROP TABLE IF EXISTS checks.invalid_geometry;
CREATE TABLE checks.invalid_geometry AS(

	SELECT 
		'damo_ruw.afvoergebiedaanvoergebied'::text as tabel,
		code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.afvoergebiedaanvoergebied
	WHERE NOT ST_IsValid(wkb_geometry)

/* 	UNION

	SELECT 
		'damo_ruw.bergingsgebied'::text as tabel,
		code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.bergingsgebied
	WHERE NOT ST_IsValid(wkb_geometry)
 */
	UNION

	SELECT 
		'damo_ruw.duikersifonhevel'::text as tabel,
		code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.duikersifonhevel
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.gemaal'::text as tabel,
		code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.gemaal
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.gw_pro'::text as tabel,
		pro_id::text as code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.gw_pro
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.hydroobject'::text as tabel,
		code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.hydroobject
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.iws_geo_beschr_profielpunten'::text as tabel,
		objectid::text as code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.iws_geo_beschr_profielpunten
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.peilafwijkinggebied'::text as tabel,
		code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.peilafwijkinggebied
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.peilgebiedpraktijk'::text as tabel,
		code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.peilgebiedpraktijk
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.ref_beheergebiedgrens_hhnk'::text as tabel,
		objectid::text as code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.ref_beheergebiedgrens_hhnk
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.sluis'::text as tabel,
		objectid::text as code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.sluis
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.stuw'::text as tabel,
		objectid::text as code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.stuw
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.vastedam'::text as tabel,
		objectid::text as code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.vastedam
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.vispassage'::text as tabel,
		objectid::text as code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.vispassage
	WHERE NOT ST_IsValid(wkb_geometry)

	UNION

	SELECT 
		'damo_ruw.waterdeel'::text as tabel,
		objectid::text as code,
		wkb_geometry,
		ST_IsValidReason(wkb_geometry) as invalid_reason
	FROM damo_ruw.waterdeel
	WHERE NOT ST_IsValid(wkb_geometry)
);




--Zoek gaten in de peilenkaart
DROP TABLE IF EXISTS checks.geen_peil;
CREATE TABLE checks.geen_peil AS(
	WITH ringdump AS
	(
		SELECT 
			ST_DumpRings((ST_Dump(ST_Union(ST_MakeValid(wkb_geometry)))).geom) as rings
		FROM 
			damo_ruw.peilgebiedpraktijk
	)
	SELECT 
		(rings).geom 
	FROM 
		ringdump
	WHERE 
		(rings).path[1] != 0
);


--Zoek overlappende peilgebieden 
--iedere overlap komt er minimaal 2 x in. A overlapt met B, en B overlapt met A.
DROP TABLE IF EXISTS checks.overlappende_geometrie;
CREATE TABLE checks.overlappende_geometrie AS(
	WITH intersections AS(
		SELECT
			'damo_ruw.peilgebiedpraktijk'::text as tabel,
			a.code as code1,
			--a.wkb_geometry as geom1,
			b.code as code2,
			--b.wkb_geometry as geom2,
			ST_Intersection(a.wkb_geometry,b.wkb_geometry) as overlap
		FROM 
			tmp.peilgebiedpraktijk a, tmp.peilgebiedpraktijk b
		WHERE 
			ST_Intersects(a.wkb_geometry,b.wkb_geometry) AND a.code != b.code
			
		UNION
		
		SELECT
			'damo_ruw.peilafwijkinggebied'::text as tabel,
			a.code as code1,
			--a.wkb_geometry as geom1,
			b.code as code2,
			--b.wkb_geometry as geom2,
			ST_Intersection(a.wkb_geometry,b.wkb_geometry) as overlap
		FROM 
			tmp.peilafwijkinggebied a, tmp.peilafwijkinggebied b
		WHERE 
			ST_Intersects(a.wkb_geometry,b.wkb_geometry) AND a.code != b.code
	)
	SELECT tabel, code1, code2, overlap
	FROM intersections
	WHERE ST_GeometryType(overlap) LIKE 'ST_Polygon'
	
	UNION
	
	SELECT tabel, code1, code2, ST_CollectionExtract(overlap,3) as overlap
	FROM intersections
	WHERE NOT ST_IsEmpty(ST_CollectionExtract(overlap,3))
);