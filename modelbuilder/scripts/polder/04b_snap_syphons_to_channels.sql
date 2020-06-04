--Create Syphons table from culvert
DROP TABLE IF EXISTS deelgebied.syphon;
CREATE TABLE deelgebied.syphon AS(
SELECT * FROM deelgebied.culvert
WHERE type_art = 2
);

--Removes syphons from culvert table
DELETE FROM deelgebied.culvert WHERE type_art = 2;


--Create union of channels with syphon on top
DROP TABLE IF EXISTS deelgebied.syphon_channel_union;
CREATE TABLE deelgebied.syphon_channel_union AS(
SELECT ST_Union(geom) as geom FROM deelgebied.channel
WHERE comment LIKE '%sifon%');

--Snap syphons to this union
UPDATE deelgebied.syphon a
SET geom = ST_RemoveRepeatedPoints(ST_Snap(a.geom,b.geom,0.1),0.0000001)
FROM deelgebied.syphon_channel_union b;


--Make a table with channels where the syphon was cut out
DROP TABLE IF EXISTS deelgebied.channel_snapped_syphon_clip;
CREATE TABLE deelgebied.channel_snapped_syphon_clip AS(
SELECT (ST_Dump(ST_Difference(a.geom,b.geom))).geom as dumpgeom, a.* FROM deelgebied.channel a, deelgebied.syphon b WHERE ST_Contains(a.geom, b.geom));

DROP TABLE IF EXISTS tmp.exact_overlapping_channel_syphon;
CREATE TABLE tmp.exact_overlapping_channel_syphon AS (
SELECT a.* 
FROM deelgebied.channel a, deelgebied.syphon b 
WHERE ST_Equals(a.geom, b.geom)
);

DROP SEQUENCE IF EXISTS seq_channel_id;
CREATE SEQUENCE seq_channel_id START 1;
SELECT setval('seq_channel_id', max(id)) FROM deelgebied.channel;

--Remove parts from channel_snapped
DELETE FROM deelgebied.channel WHERE id IN (SELECT id FROM deelgebied.channel_snapped_syphon_clip);
DELETE FROM deelgebied.channel WHERE id IN (SELECT id FROM tmp.exact_overlapping_channel_syphon);

UPDATE deelgebied.channel_snapped_syphon_clip SET id = nextval('seq_channel_id'), geom = dumpgeom;
ALTER TABLE deelgebied.channel_snapped_syphon_clip DROP COLUMN IF EXISTS dumpgeom;

--Insert parts
INSERT INTO deelgebied.channel SELECT * FROM deelgebied.channel_snapped_syphon_clip WHERE NOT ST_IsEmpty(geom);
