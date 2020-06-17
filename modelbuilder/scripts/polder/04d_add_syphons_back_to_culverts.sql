/*
In dit sript worden de sifons weer toegevoegd aan de tabel met duikers. Ook worden watergangen waar nodig opgeknipt. Dit is nodig omdat de watergangen zijn samengevoegd tijdens voorgaande stappen, maar er soms opnieuw een verbinding met de sifons moet worden gemaakt.
*/

--Insert into deelgebied.culvert the syphons with all data
INSERT INTO deelgebied.culvert SELECT * FROM deelgebied.syphon;

--Insert into deelgebied.culvert_snapped with culvert_id
DROP SEQUENCE IF EXISTS seq_culvert_snapped_id;
CREATE SEQUENCE seq_culvert_snapped_id START 1;
SELECT setval('seq_culvert_snapped_id', max(id)) FROM deelgebied.culvert_snapped;

INSERT INTO deelgebied.culvert_snapped
SELECT
	nextval('seq_culvert_snapped_id'),
	id,
	geom
FROM deelgebied.syphon;

--DO SOMETHING WITH CULVERTS ENDING ON SIDE OF CHANNEL_CUT_CIRCULAR

CREATE OR REPLACE FUNCTION ST_LineSubstrings(
	inputlijn geometry,
    knipfracties double precision[]
)
RETURNS
    SETOF geometry_dump

AS
$$
DECLARE
	i geometry_dump % rowtype;
BEGIN
	FOR i IN 
		-- Voeg 0 en 1 toe als knipfractie om altijd aan het begin van de lijn te beginnen en aan het eind te eindigen
		WITH knipfracties AS (
			SELECT  inputlijn AS geom,
					0 AS kf
			UNION
			SELECT	inputlijn AS geom,
					unnest(knipfracties) AS kf
			UNION
			SELECT	inputlijn AS geom,
					1 AS kf
		),
		knipfracties_uniek_gesorteerd AS (
			SELECT DISTINCT ON (kf) * FROM knipfracties ORDER BY kf
		),
		fracties_van_tot AS	(
			SELECT  geom,
					kf AS fractie_van,
					lead(kf) over() AS fractie_tot
			FROM	knipfracties_uniek_gesorteerd
			),
		fracties_van_tot_opgeschoond AS	(
			SELECT	*
			FROM	fracties_van_tot
			WHERE	fractie_van IS NOT NULL
					AND
					fractie_tot IS NOT NULL
		)
		SELECT	ARRAY[row_number() over()] AS path, 
				ST_LineSubString(geom, fractie_van, fractie_tot) AS geom
		FROM	fracties_van_tot_opgeschoond
	LOOP
		RETURN NEXT i;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ST_LineSubstrings(
	inputlijn geometry,
    max_length double precision
)
RETURNS
    SETOF geometry_dump
AS
$$
DECLARE
	step numeric;
	cut_fractions double precision[];
	i geometry_dump % rowtype;
BEGIN
	-- calculate step (fraction corresponding to max length)
	step := max_length / ST_Length(inputlijn);

	-- generate array of cut_fractions
	WITH ser AS (select generate_series(0::integer, ceil(1/step)::integer, step) AS ies) SELECT array_agg(ser.ies) FROM ser WHERE ser.ies BETWEEN 0 AND 1 INTO cut_fractions;

	-- call the other version of ST_LineSubstrings with the calculated parameters
	FOR i IN 
		SELECT (ST_LineSubstrings(inputlijn, cut_fractions)).*
	LOOP
		RETURN NEXT i;
	END LOOP;
END;
$$ LANGUAGE plpgsql;


--Determine channels that have to be splitted
DROP TABLE IF EXISTS tmp.split_channels;
CREATE TABLE tmp.split_channels AS(
WITH syphon_ends AS(
SELECT ST_StartPoint(geom) as geom
FROM deelgebied.syphon

UNION

SELECT ST_EndPoint(geom) as geom
FROM deelgebied.syphon
)
SELECT a.id as channel_cut_circular_id, array_agg(ST_LineLocatePoint(a.geom, b.geom)) as fraction_arr FROM deelgebied.channel_cut_circular a, syphon_ends b
WHERE ST_LineLocatePoint(a.geom,b.geom) > 0 AND  ST_LineLocatePoint(a.geom,b.geom) < 1 AND ST_Intersects(a.geom, b.geom)
GROUP BY a.id);

DROP TABLE IF EXISTS tmp.splitted_channels;
CREATE TABLE tmp.splitted_channels AS(
SELECT (ST_Linesubstrings(a.geom, b.fraction_arr)).geom as geom
FROM deelgebied.channel_cut_circular a, tmp.split_channels b
WHERE a.id = b.channel_cut_circular_id);


--Delete these channels
DELETE FROM deelgebied.channel_cut_circular WHERE id IN (SELECT channel_cut_circular_id FROM tmp.split_channels);

--INSERT split_dump in channels
DROP SEQUENCE IF EXISTS seq_channel_cut_circular_id;
CREATE SEQUENCE seq_channel_cut_circular_id START 1;
SELECT setval('seq_culvert_snapped_id', max(id)) FROM deelgebied.channel_cut_circular;
INSERT INTO deelgebied.channel_cut_circular (id, geom) SELECT nextval('seq_culvert_snapped_id'), geom FROM tmp.splitted_channels;