ALTER TABLE checks.channel DROP COLUMN IF EXISTS typering;
ALTER TABLE checks.channel ADD COLUMN typering varchar(50);
UPDATE checks.channel as a
SET typering = b.polder_type
FROM checks.polder as b
WHERE ST_Intersects(a.geom,b.geom)
;
ALTER TABLE checks.pumpstation DROP COLUMN IF EXISTS typering;
ALTER TABLE checks.pumpstation ADD COLUMN typering varchar(50);
UPDATE checks.pumpstation as a
SET typering = b.polder_type
FROM checks.polder as b
WHERE ST_Intersects(a.geom,b.geom)
;
ALTER TABLE checks.crosssection DROP COLUMN IF EXISTS typering;
ALTER TABLE checks.crosssection ADD COLUMN typering varchar(50);
UPDATE checks.crosssection as a
SET typering = b.polder_type
FROM checks.polder as b
WHERE ST_Intersects(a.geom,b.geom)
;

