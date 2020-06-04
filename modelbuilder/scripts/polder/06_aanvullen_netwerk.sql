SELECT * FROM deelgebied.tmp_sel_culvert WHERE connection_node_end_id IS NULL OR connection_node_start_id IS NULL;
-- 12-04-2017: 0 hits voor de purmer (dus damo is nice en/of script Lars werkt goed!)
ALTER TABLE deelgebied.tmp_sel_culvert ADD COLUMN code varchar(50);
UPDATE deelgebied.tmp_sel_culvert as a
SET code = b.code
FROM deelgebied.culvert as b
WHERE a.culvert_id = b.id
;
-- kan eigenlijk niet gebeuren voor stuwen en gemalen
SELECT * FROM deelgebied.tmp_sel_weirs WHERE connection_node_end_id IS NULL OR connection_node_start_id IS NULL;
SELECT * FROM deelgebied.tmp_sel_pumpstation WHERE connection_node_end_id IS NULL OR connection_node_start_id IS NULL;
-- TO DO: renier: "als ik het goed begrijp gooien we nu een multipart duiker helemaal weg. Wellicht singleparts van maken en dan 1 overhouden??"
-- duikers multipart of duikers met dubbele id's
DELETE FROM deelgebied.tmp_sel_culvert
WHERE culvert_id IN (
WITH tel AS (
	SELECT count(*), culvert_id, code
	FROM deelgebied.tmp_sel_culvert
	GROUP BY culvert_id, code
	)
SELECT culvert_id FROM tel WHERE count > 1
);