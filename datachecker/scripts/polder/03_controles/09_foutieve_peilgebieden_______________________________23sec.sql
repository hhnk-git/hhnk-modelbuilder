-- Zijn er hele kleine peilgebieden (<1000m2) die niet kunnen kloppen? 
UPDATE checks.fixeddrainagelevelarea
SET opmerking = concat_ws(',',opmerking,'kleiner dan 1000m2')
WHERE ST_Area(geom) < 1000
;

DROP INDEX IF EXISTS checks.checks_fixeddrainagelevelarea_id;
DROP INDEX IF EXISTS checks.checks_fixeddrainagelevelarea_geom;
DROP INDEX IF EXISTS checks.checks_channel_geom;
CREATE INDEX checks_fixeddrainagelevelarea_id ON checks.fixeddrainagelevelarea USING btree(id);
CREATE INDEX checks_fixeddrainagelevelarea_geom on checks.fixeddrainagelevelarea USING gist(geom);
CREATE INDEX checks_channel_geom ON checks.channel USING gist(geom);

-- 1) welke peilgebieden hebben geen watergangen? 
DROP TABLE IF EXISTS tmp.fixeddrainagelevelarea_with_channel;
CREATE TABLE tmp.fixeddrainagelevelarea_with_channel AS 
	SELECT distinct on (a.id) a.id 
	FROM checks.fixeddrainagelevelarea as a, checks.channel as b
	WHERE ST_Intersects(a.geom,b.geom);
--In geval van GEOSIntersects: TopologyException: side location conflict at a.geom bufferen met 0.
-- WHERE ST_Intersects(ST_Buffer(a.geom,0),b.geom)
    
-- 2) vervolg: welke peilgebieden hebben geen watergangen? 
UPDATE checks.fixeddrainagelevelarea SET opmerking = concat_ws(',',opmerking,'geen watergang')
WHERE id NOT IN (SELECT id FROM tmp.fixeddrainagelevelarea_with_channel);

DROP INDEX IF EXISTS checks_fixeddrainagelevelarea_with_channel_id;
CREATE INDEX checks_fixeddrainagelevelarea_with_channel_id ON tmp.fixeddrainagelevelarea_with_channel USING btree(id);

-- vergelijking maken tussen hhnk peilen en datamining peilen obv 1) peilgebiedscode en 2) geometrie (omdat obv peilcode soms niet lukt door verschillende code door spatie/raar teken/helemaal andere code
-- De uitkomst hiervan gebruiken we later om opmerking toe te voegen aan checks.fixeddrainagelevelarea (20 regels hieronder) 
ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS bwn_vs_datamining_code;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN bwn_vs_datamining_code float;
update tmp.fixeddrainagelevelarea_datamining set bwn_vs_datamining_code = streefpeil_bwn2 - 
(select case
	when datamining_mediaan_code > -9999 and datamining_wss_code > -9999 then (datamining_mediaan_code + datamining_wss_code)/2
	when datamining_mediaan_code > -9999 and datamining_wss_code is null then datamining_mediaan_code
	when datamining_mediaan_code is null and datamining_wss_code > -9999 then datamining_wss_code
end);

ALTER TABLE tmp.fixeddrainagelevelarea_datamining DROP COLUMN IF EXISTS bwn_vs_datamining_geom;
ALTER TABLE tmp.fixeddrainagelevelarea_datamining ADD COLUMN bwn_vs_datamining_geom float;
update tmp.fixeddrainagelevelarea_datamining set bwn_vs_datamining_geom = streefpeil_bwn2 - 
(select case
	when datamining_mediaan_geom > -9999 and datamining_wss_geom > -9999 then (datamining_mediaan_geom + datamining_wss_geom)/2
	when datamining_mediaan_geom > -9999 and datamining_wss_geom is null then datamining_mediaan_geom
	when datamining_mediaan_geom is null and datamining_wss_geom > -9999 then datamining_wss_geom
end);

-- peilgebieden die geen peil hebben in damo_ruw
update checks.fixeddrainagelevelarea
set opmerking = concat_ws(',',opmerking,'geen damo peil')
where (streefpeil_bwn2_source = ' ') is not false
or streefpeil_bwn2_source = 'datamining_mediaan_geom'
or streefpeil_bwn2_source = 'datamining_mediaan_code'
or streefpeil_bwn2_source = 'datamining_wss_geom'
or streefpeil_bwn2_source = 'datamining_wss_code'
;

-- peilgebieden die geen peil hebben in damo_ruw en geen datamining peil
update checks.fixeddrainagelevelarea
set opmerking = concat_ws(',',opmerking,'geen damopeil en geen dataminingpeil')
where streefpeil_bwn2 is null or streefpeil_bwn2 NOT BETWEEN -9.99 AND 10;

/*   
-- peilgebieden met 2m peilverschil tov dataminingpeil dat is gekoppeld obv van peilgebiedscode)
update checks.fixeddrainagelevelarea
set opmerking = concat_ws(',',opmerking,'>2m peilverschil damopeil vs dataminingpeil_code')
where id in (
	select id 
    from tmp.fixeddrainagelevelarea_datamining 
    where bwn_vs_datamining_code is not null 
    and abs(bwn_vs_datamining_code)>2 
    );
    
-- peilgebieden met 2m peilverschil tov dataminingpeil dat is gekoppeld obv van geometrie
UPDATE checks.fixeddrainagelevelarea
SET opmerking = concat_ws(',',opmerking,'>2m peilverschil damopeil vs dataminingpeil_geom')
WHERE id in (
	select id 
    from tmp.fixeddrainagelevelarea_datamining 
    where bwn_vs_datamining_geom is not null 
    and abs(bwn_vs_datamining_geom)>2
    );
*/

-- tabellen weggooien    
DROP TABLE IF EXISTS tmp.fixeddrainagelevelarea_with_channel;	
