/*
Kunstwerken die niet verlijnd kunnen worden worden naar een misfits tabel geexporteerd. Kanaalelementen < 0.1 m worden verwijderd (kleiner dan het snap-grid).
*/

-- TODO: moeten deze checks naar een tabel?
SELECT  * FROM deelgebied.channel_snapped WHERE ST_GeometryType(geom) = 'ST_MultiLineString';
SELECT  * FROM deelgebied.tmp_sel_branches_without_structures WHERE ST_GeometryType(geom) = 'ST_MultiLineString';

--Kopieer alle misfits naar checks schema
DROP TABLE IF EXISTS feedback.misfits;
CREATE TABLE feedback.misfits AS(
	SELECT 'bridge_misfits' as tabel, code, geom
	FROM deelgebied.bridge_misfits
	
	UNION ALL
	
	SELECT 'culvert_misfits' as tabel, code, a.geom
	FROM deelgebied.culvert_misfits a
	LEFT JOIN deelgebied.culvert b
	ON a.id=b.id
	
	UNION ALL
	
	SELECT 'pumpstation_misfits' as tabel, code, geom
	FROM deelgebied.pumpstation_misfits
	
	UNION ALL
	
	SELECT 'weirs_misfits' as tabel, code, geom
	FROM deelgebied.weirs_misfits
);

DROP TABLE IF EXISTS feedback.too_short_channels;
CREATE TABLE feedback.too_short_channels AS(
	SELECT *, 'channel is deleted before schematisation' as remark
	FROM deelgebied.tmp_sel_branches_without_structures
	WHERE ST_Length(geom) < 0.1
);

DELETE FROM deelgebied.tmp_sel_branches_without_structures WHERE ST_Length(geom) < 0.1;
