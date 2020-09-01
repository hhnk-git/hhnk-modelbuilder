-- zijn er peilregelende kunstwerken niet op een datamining peilgrens liggen?
-- buffer van de buitenste ringen, dit is de zoekradius waarbinnen de kunstwerken moeten liggen
DROP TABLE IF EXISTS tmp.peilgrenzen_datamining
;

CREATE TABLE tmp.peilgrenzen_datamining AS
SELECT
    ST_Buffer(ST_ExteriorRing((ST_Dump(wkb_geometry)).geom),0.1) as geom
FROM
    fixed_data.datamining_ahn3
;

DROP INDEX IF EXISTS tmp.tmp_peilgrenzen_geom;
CREATE INDEX tmp_peilgrenzen_geom
ON
    tmp.peilgrenzen_datamining
USING gist
    (
        geom
    )
;

-- selecteer alle gemalen die niet binnen de zoekradius van een datamining peilgrens liggen
ALTER TABLE checks.pumpstation DROP COLUMN IF EXISTS opmerk_datamining
;

ALTER TABLE checks.weirs DROP COLUMN IF EXISTS opmerk_datamining
;

ALTER TABLE checks.culvert DROP COLUMN IF EXISTS opmerk_datamining
;

ALTER TABLE checks.pumpstation ADD COLUMN opmerk_datamining varchar(100)
;

ALTER TABLE checks.weirs ADD COLUMN opmerk_datamining varchar(100)
;

ALTER TABLE checks.culvert ADD COLUMN opmerk_datamining varchar(100)
;

DROP INDEX IF EXISTS checks.checks_pumpstation_idx;
CREATE INDEX checks_pumpstation_idx
ON
    checks.pumpstation
USING gist
    (
        geom
    )
;

DROP INDEX IF EXISTS checks.checks_weirs_idx;
CREATE INDEX checks_weirs_idx
ON
    checks.weirs
USING gist
    (
        geom
    )
;

DROP INDEX IF EXISTS checks.checks_culvert_idx;
CREATE INDEX checks_culvert_idx
ON
    checks.culvert
USING gist
    (
        geom
    )
;

DROP TABLE IF EXISTS tmp.shortlist
;

CREATE TABLE tmp.shortlist AS
    (
        SELECT
            a.code
        FROM
            checks.pumpstation         as a
          , tmp.peilgrenzen_datamining as b
        WHERE
            ST_Intersects(b.geom,a.geom)
    )
;

UPDATE
    checks.pumpstation
SET opmerk_datamining = 'wel op datamining peilgrens'
WHERE
    opmerking like '%niet op peilgrens%'
    and code IN
    (
        SELECT *
        FROM
            tmp.shortlist
    )
; -- 669/2090
-- selecteer alle stuwen die niet binnen de zoekradius van een datamining peilgrens liggen
DROP TABLE IF EXISTS tmp.shortlist
;

CREATE TABLE tmp.shortlist AS
    (
        SELECT
            a.code
        FROM
            checks.weirs               as a
          , tmp.peilgrenzen_datamining as b
        WHERE
            ST_Intersects(b.geom,a.geom)
    )
;

UPDATE
    checks.weirs
SET opmerk_datamining = 'wel op datamining peilgrens'
WHERE
    opmerking like '%niet op peilgrens%'
    and code IN
    (
        SELECT *
        FROM
            tmp.shortlist
    )
; --2208
-- selecteer alle afsluitbare duikers/sifons die niet kruisen met de zoekradius van een datamining peilgrens
DROP TABLE IF EXISTS tmp.shortlist
;

CREATE TABLE tmp.shortlist AS
    (
        SELECT
            a.id
        FROM
            checks.culvert             as a
          , tmp.peilgrenzen_datamining as b
        WHERE
            ST_Intersects(b.geom,a.geom)
    )
;

DROP INDEX IF EXISTS checks.checks_culvert_id;
CREATE INDEX checks_culvert_id
ON
    checks.culvert
USING btree
    (
        id
    )
;

UPDATE
    checks.culvert
SET opmerk_datamining = 'wel op datamining peilgrens'
WHERE
    id IN
    (
        SELECT *
        FROM
            tmp.shortlist
    )
    AND on_fdla_border IS NULL
; -- 9 sec
DROP TABLE IF EXISTS tmp.shortlist
;

DROP TABLE IF EXISTS tmp.peilgrenzen_datamining
;