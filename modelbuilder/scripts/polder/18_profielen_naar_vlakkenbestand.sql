--Determine per channel arrays of the cross sections, fractions at which they are located, withds at waterlevel and length of the channel
DROP TABLE IF EXISTS tmp.interpolation_width;
CREATE TABLE tmp.interpolation_width AS(
SELECT 
	id, 
	array_agg(cs_id ORDER BY order_id) as cs_ids, 
	array_agg(fraction ORDER BY order_id) fractions, 
	array_agg(width_at_waterlevel ORDER BY order_id) as widths,  
	avg(length) as length 
FROM tmp.channel_cs_join
GROUP BY id);

--Get channels with only one profile
DROP TABLE IF EXISTS tmp.channel_one_profile;
CREATE TABLE tmp.channel_one_profile AS(
SELECT id, generate_subscripts(fractions, 1) as nr, array_upper(fractions,1) as cnt, unnest(fractions) as fraction, unnest(widths) as width FROM tmp.interpolation_width WHERE array_upper(fractions,1) = 1);


DROP TABLE IF EXISTS tmp.fractioned;
CREATE TABLE tmp.fractioned AS(
WITH explode AS
( SELECT id, generate_subscripts(fractions, 1) as nr, array_upper(fractions,1) as cnt, unnest(fractions) as fraction, unnest(widths) as width FROM tmp.interpolation_width)
, parts AS(SELECT a.id, a.nr as from_nr, b.nr as to_nr, a.cnt as cnt, a.fraction as from_frac, b.fraction as to_frac, a.width as from_width, b.width as to_width
FROM explode a, explode b
WHERE a.id = b.id
AND a.nr+1 = b.nr)
SELECT
	id, from_nr as nr, cnt, from_frac, to_frac, from_width, to_width, (from_frac+to_frac)/2 as betweenfrac

	--from frac
	/*CASE 	WHEN from_nr = 1	THEN 0
		WHEN to_nr = cnt	THEN (from_frac+to_frac)/2
		ELSE (from_frac+to_frac)/2
	END as from_frac2,
	
	

	--to frac
	CASE 	WHEN from_nr = 1	THEN (from_frac+to_frac)/2
		WHEN to_nr = cnt	THEN 1
		ELSE (from_frac+to_frac)/2
	END as to_frac2*/
FROM parts);


DROP TABLE IF EXISTS checks.profiel_watervlak;
CREATE TABLE checks.profiel_watervlak(
  id integer,
  channel_id integer,
  nr integer,
  cnt integer,
  width double precision,
  bufgeom geometry(Polygon,28992)
);

DROP SEQUENCE IF EXISTS seq_profiel_watervlak_id;
CREATE SEQUENCE seq_profiel_watervlak_id START 1;

--Start watergangen invoeren. (extrapolatie)
INSERT INTO checks.profiel_watervlak
WITH raw AS(
SELECT
nextval('seq_profiel_watervlak_id'),
a.id,
a.nr,
a.cnt,
a.from_width,
(ST_Dump(ST_Buffer(ST_LineSubstring(b.the_geom,0,from_frac),from_width/2,'endcap=flat'))).geom
FROM tmp.fractioned a, v2_channel b
WHERE a.id = b.id
AND a.nr = 1
ORDER BY a.id
)
SELECT DISTINCT ON (id) nextval, id, nr, cnt, from_width, geom
FROM raw
ORDER BY id, ST_Area(geom) DESC;

--Eind watergangen invoeren. (extrapolatie)
INSERT INTO checks.profiel_watervlak
WITH raw AS(
SELECT
nextval('seq_profiel_watervlak_id'),
a.id,
a.nr,
a.cnt,
to_frac,
a.from_width,
(ST_Dump(ST_Buffer(ST_LineSubstring(b.the_geom,to_frac,1),to_width/2,'endcap=flat'))).geom
FROM tmp.fractioned a, v2_channel b
WHERE a.id = b.id
AND a.nr+1 = a.cnt
ORDER BY a.id
)
SELECT DISTINCT ON (id) nextval, id, nr, cnt, from_width, geom
FROM raw
ORDER BY id, ST_Area(geom) DESC;


--Interpolatiesegmenten meenemen.
INSERT INTO checks.profiel_watervlak
SELECT
nextval('seq_profiel_watervlak_id'),
a.id,
a.nr,
a.cnt,
a.from_width,
ST_Buffer(ST_LineSubstring(b.the_geom,from_frac,to_frac),((from_width+to_width)/2)/2,'endcap=flat')
FROM tmp.fractioned a, v2_channel b
WHERE a.id = b.id
AND ST_GeometryType(ST_Buffer(ST_LineSubstring(b.the_geom,from_frac,to_frac),((from_width+to_width)/2)/2,'endcap=flat')) NOT LIKE 'ST_MultiPolygon'
;

--Watergangen met maar 1 profiel
INSERT INTO checks.profiel_watervlak
SELECT
nextval('seq_profiel_watervlak_id'),
a.id,
a.nr,
a.cnt,
a.width,
ST_Buffer(the_geom,width/2,'endcap=flat')
FROM tmp.channel_one_profile a, v2_channel b
WHERE a.id = b.id
AND ST_GeometryType(ST_Buffer(the_geom,width/2,'endcap=flat')) NOT LIKE 'ST_MultiPolygon';

--Dump de union om overlappende polygonen weg te poetsen
DROP TABLE IF EXISTS checks.profiel_watervlak_union;
CREATE TABLE checks.profiel_watervlak_union AS(
WITH geomdump AS(
	SELECT ST_Dump(ST_Union(bufgeom)) as dumpoutput
	FROM checks.profiel_watervlak)
SELECT (dumpoutput).path[1] as id, (dumpoutput).geom as geom
FROM geomdump
);

DROP TABLE IF EXISTS feedback.channel_surface_from_profiles;
CREATE TABLE feedback.channel_surface_from_profiles AS(
	SELECT * FROM checks.profiel_watervlak
);