--Voeg tabellen toe indien deze niet bestaan (zodat de datachecker niet crasht)
CREATE TABLE IF NOT EXISTS damo_ruw.sluis
(
  objectid serial NOT NULL,
  code character varying(200),
  naam character varying(100),
  doorvaartbreedte double precision,
  breedte double precision,
  hoogtebinnenonderkantben double precision,
  hoogtebinnenonderkantbov double precision,
  drempelhoogte double precision,
  ws_categorie smallint,
  ws_doorvaarlengte real,
  ws_inlaatfunctie character varying(200),
  ws_afsluitwijze1 smallint,
  ws_afsluitwijze2 smallint,
  wkb_geometry geometry(Point,28992)
);





-- damo_ruw inhoud (tabellen en kolommen) van levering 12 feb 2017
/*
drop table if exists tmp.damo_ruw_feb_20177;
create table tmp.damo_ruw_feb_20177 (
    table_name character varying,
    column_name character varying,
    is_nullable character varying, 
    data_type character varying,
    opmerking character varying);

INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('afvoergebiedaanvoergebied', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('afvoergebiedaanvoergebied', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('afvoergebiedaanvoergebied', 'naam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('afvoergebiedaanvoergebied', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('afvoergebiedaanvoergebied', 'oppervlakte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('afvoergebiedaanvoergebied', 'shape_length', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('afvoergebiedaanvoergebied', 'shape_area', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('afvoergebiedaanvoergebied', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'naam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'opp', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'onderhouds', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'registrati', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'bij_peil', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'bergend_ve', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'soor_wsw', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'shape_length', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'shape_area', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('bergingsgebied', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('ref_beheergebiedgrens_hhnk', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('ref_beheergebiedgrens_hhnk', 'shape_length', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('ref_beheergebiedgrens_hhnk', 'shape_area', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('ref_beheergebiedgrens_hhnk', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'bgtstatus', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'bgttype', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'bronhouder', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'detailniveaugeometrie', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'eindregistratie', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'inonderzoek', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'lokaalid', 'NO', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'lvpublicatiedatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'naamspace', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'objectbegintijd', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'objecteindtijd', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'plustype', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'relatievehoogteligging', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'hydroobjectid', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'metadataid', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'tijdstipregistratie', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'shape_length', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'shape_area', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('waterdeel', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'hoogteonderzijde', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'doorvaartbreedte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'richting', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'ws_categorie', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'ws_kbrbeweg', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'brug_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('brug', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'naam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'indicatiewaterkerend', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'lengte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'hoogteopening', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'breedteopening', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'hoogtebinnenonderkantbene', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'hoogtebinnenonderkantbov', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'vormkoker', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'soortmateriaal', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'typekruising', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'ws_categorie', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'ws_inlaatfunctie', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'ws_afsluitwijze1', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'ws_afsluitwijze2', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'ws_op_afstand_beheerd', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'shape_length', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('duikersifonhevel', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'naam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'indicatiewaterkerend', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'richting', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'functiegemaal', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'maximalecapaciteit', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'ws_categorie', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'ws_op_afstand_beheerd', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'ws_inlaatfunctie', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gemaal', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('code_hydroobject_objectid', 'id', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('code_hydroobject_objectid', 'hydroobj_2', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('code_hydroobject_objectid', 'objectid', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'pbp_id', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'prw_prw_id', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'loc_loc_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'pbpident', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'pbpsoort', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'pbpbeso', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'quaprec', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'quaideal', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'xxxbetrw', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'gegbron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'gegdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'osmomsch', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'iws_legrt', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'iws_prfverdedig', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'iws_tekencode', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'iws_volgnr', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'iws_hoogte', 'NO', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'iws_afstand', 'NO', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'ws_user_created', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'ws_date_created', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'ws_user_modified', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pbp', 'ws_date_modified', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'soortoppwaterkwantiteit', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'categorieoppwaterlichaam', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'breedte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'lengte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_bodemhoogte', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_bodembreedte', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_talud_links', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_talud_rechts', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_bodembreedte_brede_kijk', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_bodemhoogte_brede_kijk', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_in_peilgebied', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_droge_bedding', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_ohplicht', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_soort_vak', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'shape_length', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('hydroobject', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'pro_id', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'pro_type', 'NO', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'mpn_mpn_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'iprks_iprks_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'proident', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ovk_ovk_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'dwk_dwk_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'owa_owa_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'pro_pro_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'prw_prw_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpkruin', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'dgpnumme', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'oprricht', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'lbistatg', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddphwmat', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'prosoort', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddphwgem', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'oprdatop', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpzmrpl', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'gegbron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpwntpl', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'osmomsch', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpopgpl', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'iws_legrt', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpzett', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'tbtvwind', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ktcsoort', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddprrglf', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpparap', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpitogt', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpitoto', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddptoord', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpiteen', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ddpiabkl', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'iws_x_offset', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'iws_y_offset', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'iws_voor_len', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'iws_na_len', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'iws_hyperlink', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'richting', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'iws_gepeild_door', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'iws_datum_gepeild', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_geonauwkeurigheid', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_geonauwkeurigheid_z', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_betrouwbaarheid', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_adminnauwkeurigheid', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_idealisatie', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_user_created', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_date_created', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_user_modified', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'ws_date_modified', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'se_anno_cad_data', 'YES', 'bytea', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'geometrie_length', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_pro', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'prw_id', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'prw_type', 'NO', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'prwident', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'mpn_mpn_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pro_pro_id', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pflaant', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pfwnaam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwkrhoo', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pfwtype', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwkrbre', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'prwsoort', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwhlbul', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'prwdatum', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'osmomsch', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pwghobub', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwhlbub', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_legrt', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwbrbub', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwhlbil', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwhgbib', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwhlbib', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pwghovrl', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_brbiberm', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_beschzonebu', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_beschzonebi', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_kernzonebi', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_kernzonebu', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwbrvo', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_bukruin', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_bikruin', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_refpeil', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_bodho', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_brplasbr', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_bodbr', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_brplasbl', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_watdiepte', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_taludl', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_taludr', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_insthgter', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_watpeil', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_plasbh_dl', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_plasbh_dr', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_insthgtel', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_plasbtall', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_plasbtalr', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'iws_w_watbrrefp', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'pgwhoogw', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'ddphwgem', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'oafnatom', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'oafnatop', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'oafhydst', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'oafdroob', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'oafdrooe', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'ws_user_created', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'ws_date_created', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'ws_user_modified', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('gw_prw', 'ws_date_modified', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'pbp_pbp_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'richting', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'temp_id', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'ws_user_created', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'ws_date_created', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'ws_user_modified', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'ws_date_modified', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'se_anno_cad_data', 'YES', 'bytea', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_geo_beschr_profielpunten', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'naam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'ws_oppervlakte', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'shape_length', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'shape_area', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'peilafwijking_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilafwijkinggebied', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'naam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'ws_peilbesluitplichtig', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'ws_oppervlakte', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'shape_length', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'shape_area', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'peilgebiedpraktijk_id', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('peilgebiedpraktijk', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'naam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'doorvaartbreedte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'indicatiewaterkerend', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'breedte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'soortsluis', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'hoogtebinnenonderkantben', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'hoogtebinnenonderkantbov', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'richting', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'drempelhoogte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'ws_categorie', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'ws_doorvaarlengte', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'ws_doorvaardiepte', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'ws_inlaatfunctie', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'ws_afsluitwijze1', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'ws_afsluitwijze2', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('sluis', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_profiel_reeksen', 'iprks_id', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_profiel_reeksen', 'iprksident', 'NO', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_profiel_reeksen', 'osmomsch', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_profiel_reeksen', 'ws_metfile', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_profiel_reeksen', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_profiel_reeksen', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_profiel_reeksen', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('iws_profiel_reeksen', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'naam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'indicatiewaterkerend', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'soortstuw', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'doorstroombreedte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'kruinbreedte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'laagstedoorstroomhoogte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'hoogstedoorstroomhoogte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'soortregelbaarheid', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'richting', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'ws_categorie', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'ws_kruinvorm', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'ws_functiestuw', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('stuw', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'richting', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'ws_categorie', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vastedam', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'code', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'naam', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'opmerking', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'soortvispassage', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'richting', 'YES', 'real', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'ws_categorie', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'ws_bron', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'ws_inwinningswijze', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'ws_inwinningsdatum', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'ws_indicatiewaterkerend', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'ws_afsluitwijze1', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'ws_afsluitwijze2', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'ws_op_afstand_beheerd', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('vispassage', 'wkb_geometry', 'YES', 'USER-DEFINED', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'code', 'NO', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'breedteopening', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'indicatiedoorvaarbaarheid', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'brugid', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'ws_opening_nr', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('doorstroomopening', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'objectid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'soortstreefpeil', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'eenheid', 'YES', 'smallint', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'waterhoogte', 'YES', 'double precision', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'peilgebiedpraktijkid', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'peilafwijkinggebiedid', 'YES', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'created_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'created_date', 'YES', 'timestamp with time zone', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'last_edited_user', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('streefpeil', 'last_edited_date', 'YES', 'timestamp with time zone', NULL);
*/

-- losse csv met pomp capa willen we niet meenemen in vergelijking, want dat is niet damo van hhnk (heeft renier wel ff daar ingeladen want handig alle broninfo bijelkaar anders te veel workdb schema's)
/*
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_thomas_berends_spoq', 'ogc_fid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_thomas_berends_spoq', 'id', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_thomas_berends_spoq', 'freq', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_thomas_berends_spoq', 'debiet', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_thomas_berends_spoq', 'nominaaldebiet', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_thomas_berends_spoq', 'ltdebiet', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_thomas_berends_spoq', 'htdebiet', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_jeroen_hermans_purmerend_beverwijk', 'ogc_fid', 'NO', 'integer', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_jeroen_hermans_purmerend_beverwijk', 'id', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_jeroen_hermans_purmerend_beverwijk', 'freq', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_jeroen_hermans_purmerend_beverwijk', 'debiet', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_jeroen_hermans_purmerend_beverwijk', 'nominaaldebiet', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_jeroen_hermans_purmerend_beverwijk', 'ltdebiet', 'YES', 'character varying', NULL);
INSERT INTO tmp.damo_ruw_feb_20177 VALUES ('csv_pomp_capa_jeroen_hermans_purmerend_beverwijk', 'htdebiet', 'YES', 'character varying', NULL);
*/

/*
-- maak een tabel met daarin alle tabelnamen en kolomnamen van current damo_ruw
drop table if exists tmp.damo_ruw_current;
create table tmp.damo_ruw_current as select table_name, column_name, is_nullable, data_type, now()::timestamp as date FROM information_schema.columns WHERE table_schema = 'damo_ruw';

-- opnieuw ook hier: losse csv met pomp capa willen we niet meenemen in vergelijking, want dat is niet damo van hhnk (heeft renier wel ff daar ingeladen want handig alle broninfo bijelkaar anders te veel workdb schema's)
delete from tmp.damo_ruw_current where table_name like 'csv_pomp_capa_thomas_berends_spoq';
delete from tmp.damo_ruw_current where table_name like 'csv_pomp_capa_jeroen_hermans_purmerend_beverwijk';
*/

/*
-- testje maken waarin we wat toevoegen en weggooien en datatype veranderen aan current 
insert into tmp.damo_ruw_current(table_name, column_name, is_nullable, data_type)
values ('po', 'j', 'YES', 'jfd');
delete from tmp.damo_ruw_current where table_name like 'brug'; 
update tmp.damo_ruw_current set data_type = 'ander datatypeA' where table_name like 'bergingsgebied' and column_name like 'code'; 
*/

/*
-- minder tabellen, kolommen tov vorige levering
drop table if exists checks.damo_ruw_completeness;
create table checks.damo_ruw_completeness as SELECT table_name as tabel, column_name as kolom, is_nullable as verplicht_invullen, 'minder tov vorige levering' as opmerking
FROM tmp.damo_ruw_current a 
FULL OUTER JOIN tmp.damo_ruw_feb_20177 b
USING (table_name, column_name, is_nullable, data_type)
WHERE a.table_name IS NULL;

-- extra tabellen, kolommen tov vorige levering
insert into checks.damo_ruw_completeness(tabel, kolom, verplicht_invullen, opmerking)
select table_name as tabel, column_name as kolom, is_nullable as verplicht_invullen, 'minder tov vorige levering' as opmerking
FROM tmp.damo_ruw_current a 
FULL OUTER JOIN tmp.damo_ruw_feb_20177 b
USING (table_name, column_name, is_nullable, data_type)
WHERE b.table_name IS NULL;

-- tabellen weggooien        
drop table if exists tmp.damo_ruw_current;
drop table if exists tmp.damo_ruw_feb_20177;
*/

/* 
select * from checks.damo_ruw_completeness;
"code_hydroobject_objectid";"hydroobj_2";"YES";"minder tov vorige levering"
"code_hydroobject_objectid";"id";"NO";"minder tov vorige levering"
"code_hydroobject_objectid";"objectid";"YES";"minder tov vorige levering"
"peilafwijkinggebied";"peilafwijking_id";"YES";"minder tov vorige levering"
"hydroobject";"hydroobject_id";"YES";"minder tov vorige levering"
"peilafwijkinggebied";"peilafwijkinggebied_id";"YES";"minder tov vorige levering"

 */

