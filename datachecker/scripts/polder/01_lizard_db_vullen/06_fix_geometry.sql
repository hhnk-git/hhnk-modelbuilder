/* 
Zet invalid geometrie om naar valid geometrie
 */
 
DROP TABLE IF EXISTS tmp.peilgebiedpraktijk;
CREATE TABLE tmp.peilgebiedpraktijk AS(
	SELECT 
		objectid,
		code,
		naam,
		opmerking,
		ws_bron,
		ws_inwinningswijze,
		ws_inwinningsdatum,
		ws_peilbesluitplichtig,
		created_user,
		created_date,
		last_edited_user,
		last_edited_date,
		ws_oppervlakte,
		shape_length,
		shape_area,
		peilgebiedpraktijk_id,
		peil_wsa,
		keuze_wsa,
		ST_CollectionExtract(ST_MakeValid(wkb_geometry),3) AS wkb_geometry
		FROM damo_ruw.peilgebiedpraktijk
);
		
		
DROP TABLE IF EXISTS tmp.peilafwijkinggebied;
CREATE TABLE tmp.peilafwijkinggebied AS(
	SELECT 
		objectid,
		code,
		naam,
		opmerking,
		ws_bron,
		ws_inwinningswijze,
		ws_inwinningsdatum,
		created_user,
		created_date,
		last_edited_user,
		last_edited_date,
		ws_oppervlakte,
		shape_length,
		shape_area,
		peilafwijkinggebied_id, -- peilafwijking_id as peilafwijkinggebied_id,  --deze is veranderd tov feb levering
		peil_wsa,
		keuze_wsa,
		ST_CollectionExtract(ST_MakeValid(wkb_geometry),3) AS wkb_geometry
		FROM damo_ruw.peilafwijkinggebied
);


DROP TABLE IF EXISTS tmp.afvoergebiedaanvoergebied;
CREATE TABLE tmp.afvoergebiedaanvoergebied AS(
	SELECT
		objectid,
		code,
		naam,
		opmerking,
		soortafvoeraanvoergebied, --deze is nieuw tov feb levering
		oppervlakte,
		shape_length,
		shape_area,
		ST_CollectionExtract(ST_MakeValid(wkb_geometry),3) AS wkb_geometry
		FROM damo_ruw.afvoergebiedaanvoergebied
);

/*
DROP TABLE IF EXISTS tmp.bergingsgebied;
CREATE TABLE tmp.bergingsgebied AS(
	SELECT
		objectid,
		naam,
		opp,
		onderhouds,
		registrati,
		bij_peil,
		bergend_ve,
		code,
		soor_wsw,
		shape_length,
		shape_area,
		ST_CollectionExtract(ST_MakeValid(wkb_geometry),3) AS wkb_geometry
		FROM damo_ruw.bergingsgebied
);
*/


DROP TABLE IF EXISTS tmp.ref_beheergebiedgrens_hhnk;
CREATE TABLE tmp.ref_beheergebiedgrens_hhnk AS(
	SELECT
		objectid,
		shape_length, --shape_length as geometrie_length,   --deze is veranderd tov feb levering
		shape_area, -- shape_area as geometrie_area,        --deze is veranderd tov feb levering
		ST_CollectionExtract(ST_MakeValid(wkb_geometry),3) AS wkb_geometry
		FROM damo_ruw.ref_beheergebiedgrens_hhnk
);



DROP TABLE IF EXISTS tmp.waterdeel;
CREATE TABLE tmp.waterdeel AS(
	SELECT
		objectid,
		--bgtstatus,
		--bgttype,
		--bronhouder,
		identificatie as code,
		--detailniveaugeometrie,
		--eindregistratie,
		--inonderzoek,
		--lokaalid,
		--lvpublicatiedatum,
		--naamspace,
		--objectbegintijd,
		--objecteindtijd,
		--plustype,
		--relatievehoogteligging,
		--hydroobjectid,
		--metadataid,
		--tijdstipregistratie,
		--created_user,
		--created_date,
		--last_edited_user,
		--last_edited_date,
		--shape_length,
		--shape_area,
		ST_CollectionExtract(ST_MakeValid(wkb_geometry),3) AS wkb_geometry
	FROM damo_ruw.waterdeel
);
