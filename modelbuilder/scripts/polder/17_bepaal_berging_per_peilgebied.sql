--Stappenplan
--Stap 1. bepaal bergend oppervlak per peilgebied volgens BGT watervlakkenkaart


--STAP 1
--maak channelsurface/fixeddrainagelevelarea valid

UPDATE deelgebied.channelsurface SET geom = ST_MakeValid(geom) WHERE NOT ST_IsValid(geom);
UPDATE deelgebied.fixeddrainagelevelarea SET geom = ST_MakeValid(geom) WHERE NOT ST_IsValid(geom);
UPDATE deelgebied.fixeddrainagelevelarea SET geom = ST_CollectionExtract(geom,3);

DROP TABLE IF EXISTS tmp.channelsurface_union;
CREATE TABLE tmp.channelsurface_union AS(
	SELECT ST_CollectionExtract(ST_Union(geom),3) as geom FROM deelgebied.channelsurface
);

--Bepaal surface per peilgebied
DROP TABLE IF EXISTS tmp.fdla_channel_surface;
CREATE TABLE tmp.fdla_channel_surface AS(
	SELECT a.id, a.code, a.streefpeil_bwn2, ST_CollectionExtract(a.geom,3) as fdla_geom, ST_Intersection(ST_CollectionExtract(a.geom,3),b.geom) as surface_geom
	FROM deelgebied.fixeddrainagelevelarea a, tmp.channelsurface_union b
	WHERE ST_Intersects(a.geom,b.geom)
);

ALTER TABLE tmp.fdla_channel_surface DROP COLUMN IF EXISTS storage_area;
ALTER TABLE tmp.fdla_channel_surface ADD COLUMN storage_area double precision;
UPDATE tmp.fdla_channel_surface SET storage_area = ST_Area(surface_geom);

--Bepaal streefpeil per kanaal
DROP TABLE IF EXISTS tmp.channel_streefpeil;
CREATE TABLE tmp.channel_streefpeil AS(
SELECT a.id, b.initial_waterlevel as start_level, c.initial_waterlevel as end_level, (b.initial_waterlevel+c.initial_waterlevel)/2 as avg_level, a.the_geom as geom
FROM v2_channel a, v2_connection_nodes b, v2_connection_nodes c
WHERE a.connection_node_start_id = b.id AND a.connection_node_end_id = c.id
);


--Koppel streefpeil aan cross_section location/definition
DROP TABLE IF EXISTS tmp.cross_sections;
CREATE TABLE tmp.cross_sections AS(
SELECT a.id, a.channel_id, a.definition_id, a.reference_level, a.bank_level, b.shape, b.width, b.height, c. avg_level, a.the_geom as geom 
FROM v2_cross_section_location a, v2_cross_section_definition b, tmp.channel_streefpeil c
WHERE a.definition_id = b.id
AND a.channel_id = c.id);

--Bepaal waterdiepte (waterstand-bodemhoogte)
ALTER TABLE tmp.cross_sections DROP COLUMN IF EXISTS waterdepth;
ALTER TABLE tmp.cross_sections ADD COLUMN waterdepth double precision;
UPDATE tmp.cross_sections SET waterdepth = GREATEST(avg_level-reference_level,0);

--Maak arrays met waterlevel > of <= element in hoogtearray om de indexen te vinden waartussen te interpoleren.
DROP TABLE IF EXISTS tmp.level_comp_unnest;
CREATE TABLE tmp.level_comp_unnest AS(
SELECT id, waterdepth, arr[nr] AS height, nr, arr[nr]::double precision < waterdepth as st, arr[nr]::double precision >= waterdepth as gt
FROM  (
   SELECT *, generate_subscripts(arr, 1) AS nr
   FROM  (SELECT id, waterdepth, string_to_array(height, ' ') AS arr  FROM tmp.cross_sections) t
   ) sub
  );



--Bepaal indexen in hoogte/breedte array van element net onder/boven waterhoogte
DROP TABLE IF EXISTS tmp.level_comp_indices;
CREATE TABLE tmp.level_comp_indices AS(
WITH ilow AS(
SELECT id, st, max(nr) as index_low FROM tmp.level_comp_unnest WHERE st GROUP BY id, st
), ihigh as(
SELECT id, gt, min(nr) as index_high FROM tmp.level_comp_unnest WHERE gt GROUP BY id, gt)
SELECT a.id, index_low, index_high
FROM ilow a, ihigh b
WHERE a.id = b.id
);



--Voeg hoogte/breedte array toe
ALTER TABLE tmp.cross_sections DROP COLUMN IF EXISTS width_array, DROP COLUMN IF EXISTS height_array;
ALTER TABLE tmp.cross_sections ADD COLUMN width_array double precision[], ADD COLUMN height_array double precision[];

ALTER TABLE tmp.cross_sections DROP COLUMN IF EXISTS height_low, DROP COLUMN IF EXISTS height_high, DROP COLUMN IF EXISTS width_low, DROP COLUMN IF EXISTS width_high;
ALTER TABLE tmp.cross_sections ADD COLUMN height_low double precision, ADD COLUMN height_high double precision, ADD COLUMN width_low double precision, ADD COLUMN width_high double precision;

UPDATE tmp.cross_sections SET width_array = string_to_array(width, ' ')::double precision[], height_array = string_to_array(height, ' ')::double precision[];

UPDATE tmp.cross_sections a SET height_low = height_array[index_low], height_high = height_array[index_high], width_low = width_array[index_low], width_high = width_array[index_high]
FROM tmp.level_comp_indices b
WHERE a.id = b.id;

--Indien waterdiepte > dan hoogste element dan hoogste hoogte/breedte nemen
UPDATE tmp.cross_sections SET height_low = height_array[array_upper(height_array,1)-1], height_high = height_array[array_upper(height_array,1)], width_low = width_array[array_upper(width_array,1)-1], width_high = width_array[array_upper(width_array,1)] WHERE waterdepth > height_array[array_upper(height_array,1)];

--Indien waterdiepte = 0
UPDATE tmp.cross_sections SET height_low = height_array[1], height_high = height_array[2], width_low = width_array[1], width_high = width_array[2] WHERE waterdepth = 0;



--Bepaal breedte
ALTER TABLE tmp.cross_sections DROP COLUMN IF EXISTS width_at_waterlevel;
ALTER TABLE tmp.cross_sections ADD COLUMN width_at_waterlevel double precision;

UPDATE tmp.cross_sections SET width_at_waterlevel =
	CASE WHEN (height_high-height_low) = 0
		THEN width_low
		ELSE width_low + 
			LEAST(1,
				GREATEST(0,
				(waterdepth-height_low)/(height_high-height_low)))*(width_high-width_low)
	END
;


DROP SEQUENCE IF EXISTS seq_channel_cs_join;
CREATE SEQUENCE seq_channel_cs_join START 1;
--Per kanaal nu interpoleren/extrapoleren, voeg een id toe op de georderde lijst om later de arrays te sorteren
DROP TABLE IF EXISTS tmp.channel_cs_join;
CREATE TABLE tmp.channel_cs_join AS(
WITH ordered AS(
SELECT a.id, b.id as cs_id, a.the_geom, b.the_geom as cs_geom, ST_LineLocatePoint(a.the_geom,b.the_geom) as fraction, c.width_at_waterlevel, ST_Length(a.the_geom) as length 
FROM v2_channel a, v2_cross_section_location b, tmp.cross_sections c
WHERE a.id = b.channel_id
AND b.id = c.id
ORDER BY b.channel_id, fraction)
SELECT nextval('seq_channel_cs_join') as order_id, *
FROM ordered);

--Voeg begin/eindpunt toe voor extrapolatie
DROP TABLE IF EXISTS tmp.interpolation;
CREATE TABLE tmp.interpolation AS(
SELECT 
	id, 
	array_agg(cs_id) as cs_ids, 
	array_append(array_prepend(0::double precision,array_agg(fraction)),1::double precision) as fractions, 
	array_append(array_prepend((array_agg(width_at_waterlevel))[1],array_agg(width_at_waterlevel)),(array_agg(width_at_waterlevel))[array_upper(array_agg(width_at_waterlevel),1)]) as widths,  avg(length) as length FROM tmp.channel_cs_join
GROUP BY id);

--Bereken surface area per kanaal
DROP TABLE IF EXISTS tmp.channel_surface_area;
CREATE TABLE tmp.channel_surface_area AS(
WITH explode AS(
SELECT id, unnest(fractions) as frac, unnest(widths) as width, length, generate_subscripts(fractions, 1) AS index FROM tmp.interpolation)
, explode_join AS(
SELECT a.id, a.frac as from_frac, b.frac as to_frac, a.width as from_width, b.width as to_width, a.length FROM explode a, explode b
WHERE a.id = b.id AND a.index+1 = b.index
ORDER BY id
), fraction_surface AS(
SELECT 
	*,
	(to_frac-from_frac)*length as length,
	(from_width + to_width)/2 as avg_width,
	((to_frac-from_frac)*length)*((from_width + to_width)/2) as surface
FROM explode_join)
SELECT
	id,
	sum(surface) as surface_area
FROM fraction_surface
GROUP BY id);

--Voeg midpoints van de v2_channel toe
DROP TABLE IF EXISTS tmp.channel_surface_area_midpoints;
CREATE TABLE tmp.channel_surface_area_midpoints AS(
SELECT a.id, a.surface_area, ST_Line_Interpolate_Point(b.the_geom, 0.5) as midpoint FROM tmp.channel_surface_area a, v2_channel b
WHERE a.id = b.id
);

--Bepaal in welk peilgebied ze liggen
ALTER TABLE tmp.channel_surface_area_midpoints DROP COLUMN IF EXISTS fdla_id;
ALTER TABLE tmp.channel_surface_area_midpoints ADD COLUMN fdla_id integer;
UPDATE tmp.channel_surface_area_midpoints a SET fdla_id = b.id
FROM deelgebied.fixeddrainagelevelarea b
WHERE ST_Contains(b.geom,a.midpoint);

--Maak tabel met vergelijking bgt/model
DROP TABLE IF EXISTS checks.modelled_surface;
CREATE TABLE checks.modelled_surface AS(
	WITH modelled_surface AS(
	SELECT fdla_id, sum(surface_area) as modelled_surface
	FROM tmp.channel_surface_area_midpoints
	GROUP BY fdla_id)
	SELECT a.id, a.code, a.streefpeil_bwn2, a.fdla_geom, a.storage_area as bgt_surface, b.modelled_surface, (100*(b.modelled_surface-a.storage_area))/a.storage_area as diff_percent,
	(a.storage_area-b.modelled_surface) as added_surface
	FROM tmp.fdla_channel_surface a, modelled_surface b
	WHERE a.id = b.fdla_id
);

--Bepaal v2_connection_nodes in secundaire systeem
DROP TABLE IF EXISTS tmp.secundary_channel_connection_nodes;
CREATE TABLE tmp.secundary_channel_connection_nodes AS(
WITH primary_channels AS(
	SELECT ST_Union(bufgeom) as geom
	FROM checks.channel_linemerge
	WHERE channel_type_id = 1
)
SELECT a.* FROM v2_connection_nodes a, primary_channels b WHERE NOT ST_Intersects(a.the_geom, b.geom)
);


--Groepeer per peilgebied en voeg extra berging toe
DROP TABLE IF EXISTS tmp.sec_con_node_per_fdla;
CREATE TABLE tmp.sec_con_node_per_fdla AS(
	SELECT a.id, count(*), array_agg(b.id) as ids_array, min(added_surface) as added_surface
	FROM checks.modelled_surface a, tmp.secundary_channel_connection_nodes b
	WHERE ST_Intersects(a.fdla_geom, b.the_geom)
	GROUP BY a.id
);

ALTER TABLE tmp.sec_con_node_per_fdla DROP COLUMN IF EXISTS add_storage_per_node;
ALTER TABLE tmp.sec_con_node_per_fdla ADD COLUMN add_storage_per_node double precision;
UPDATE tmp.sec_con_node_per_fdla SET add_storage_per_node = added_surface / array_upper(ids_array,1);


--EVENTUEEL v2_connection_nodes backuppen
/*
DROP TABLE IF EXISTS tmp.v2_connection_nodes_backup;
CREATE TABLE tmp.v2_connection_nodes_backup AS(
	SELECT *
	FROM v2_connection_nodes
);
*/


--UPDATE v2_connection_nodes, maar 1x uitvoeren anders blijven we storage toevoegen.
--Alleen toevoegen indien het meer dan 2m2 is
UPDATE v2_connection_nodes a
SET storage_area = 
	CASE 
		WHEN storage_area IS NULL AND b.add_storage_per_node > 2 THEN b.add_storage_per_node
		WHEN storage_area IS NOT NULL AND b.add_storage_per_node > 2 THEN storage_area+b.add_storage_per_node
		ELSE storage_area
	END
FROM tmp.sec_con_node_per_fdla b
WHERE a.id = ANY(b.ids_array);


--Nog een watervlakkenkaart maken
