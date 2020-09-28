/*
Dit script selecteerd uit de gecontroleerde gegevens alles dat binnen een deelgebied ligt. Het deelgebied is een poldercluster. Telkens wordt ook een selectie gedaan op 'isuable' of objecten in de nowayout vlakken, dus alleen objecten die correct zijn worden in het schema deelgebied meegenomen.
Er wordt daarnaast feedback verzameld van slivers in de polder laag.
*/
--Bepaal deelgebied polygon
DROP TABLE IF EXISTS deelgebied.polder
;

CREATE TABLE deelgebied.polder AS
WITH polder_dump               AS
     (
            SELECT
                   polder_id
                 , name
                 , polder_type
                 , ST_Buffer((ST_Dump(geom)).geom,0.1)                  as geom
                 , ST_Buffer(ST_ExteriorRing((ST_Dump(geom)).geom),0.1) as outergeom
                 , (ST_Dump(geom)).geom                                 as dumpgeom
                 , geom                                                 as origgeom
                 , ST_Buffer((ST_Dump(geom)).geom,-2)                   as innergeom
            FROM
                   checks.polder
            WHERE
                   polder_id = <<polder_id>>
     )
SELECT
         polder_id
       , name
       , polder_type
       , ST_Union(geom)      as geom
       , ST_Union(outergeom) as outergeom
       , ST_Union(dumpgeom)  as dumpgeom
       , ST_Union(origgeom)  as origgeom
       , ST_Union(innergeom) as innergeom
FROM
         polder_dump
WHERE
         ST_Area(dumpgeom) > 1000 --Eliminating slivers < 1000 m2
GROUP BY
         polder_id
       , name
       , polder_type
;

CREATE INDEX deelgebied_polder_geom
ON
             deelgebied.polder
USING        gist
             (
                          geom
             )
;

CREATE INDEX deelgebied_polder_outergeom
ON
             deelgebied.polder
USING        gist
             (
                          outergeom
             )
;

CREATE INDEX deelgebied_polder_innergeom
ON
             deelgebied.polder
USING        gist
             (
                          innergeom
             )
;

CREATE TABLE feedback.polder_slivers AS
             (
                  WITH polder_dump AS
                       (
                              SELECT
                                     polder_id
                                   , name
                                   , polder_type
                                   , ST_Buffer((ST_Dump(geom)).geom,0.1)                  as geom
                                   , ST_Buffer(ST_ExteriorRing((ST_Dump(geom)).geom),0.1) as outergeom
                                   , (ST_Dump(geom)).geom                                 as dumpgeom
                                   , geom                                                 as origgeom
                                   , ST_Buffer((ST_Dump(geom)).geom,-2)                   as innergeom
                              FROM
                                     checks.polder
                              WHERE
                                     polder_id = <<polder_id>>
                       )
                  SELECT *
                  FROM
                         polder_dump
                  WHERE
                         ST_Area(dumpgeom) <= 1000
             )
;

--Knip bruggen uit
DROP TABLE IF EXISTS deelgebied.bridge
;

CREATE TABLE deelgebied.bridge AS
SELECT
       a.*
FROM
       checks.bridge     as a
     , deelgebied.polder as b
WHERE
       ST_Intersects(b.geom,a.geom)
       AND
       (
              a.opmerking IS NULL
              OR a.opmerking    =''
       )
       AND a.isusable = 1
;

DELETE
FROM
       deelgebied.bridge a
USING  checks.channel_nowayout b
WHERE
       ST_Intersects(a.geom,b.geom)
;

--Knip gemalen uit
DROP TABLE IF EXISTS deelgebied.pumpstation
;

CREATE TABLE deelgebied.pumpstation AS
SELECT
       a.*
FROM
       checks.pumpstation as a
     , deelgebied.polder  as b
WHERE
       ST_Intersects(b.geom,a.geom)
       AND a.isusable = 1
;

DELETE
FROM
       deelgebied.pumpstation a
USING  checks.channel_nowayout b
WHERE
       ST_Intersects(a.geom,b.geom)
;

CREATE INDEX deelgebied_pumpstation_geom
ON
             deelgebied.pumpstation
USING        gist
             (
                          geom
             )
;

--Zet capaciteit van gemalen anders dan 'afvoergemaal' of 'aan/afvoergemaal' op 0 ipv verwijderen
UPDATE
       deelgebied.pumpstation
SET    capacity = 0.0
WHERE
       type IN ('1'
              ,'3'
              ,'6'
              ,'8'
              ,'9')
       AND opmerking NOT LIKE '%afvoergemaal op poldergrens%'
;

DROP TABLE IF EXISTS tmp.culvert_to_pumpstation
;

CREATE TABLE tmp.culvert_to_pumpstation AS
             (
                    SELECT
                           a.code as culvert_code
                         , a.geom as culvert_geom
                         , b.*
                    FROM
                           checks.culvert     a
                         , checks.pumpstation b
                    WHERE
                           a.opmerking LIKE '%pomp op duiker%'
                           AND
                           (
                                  b.opmerking   NOT LIKE '%niet op peilgrens%'
                                  OR b.opmerking IS NULL
                           )
                           AND ST_Intersects(a.geom,b.geom)
                           AND a.isusable = 1
                           AND b.isusable = 1
             )
;

DELETE
FROM
       deelgebied.pumpstation
WHERE
       code IN
       (
              SELECT
                     code
              FROM
                     tmp.culvert_to_pumpstation
       )
;

--Knip sluizen uit
DROP TABLE IF EXISTS deelgebied.sluice
;

CREATE TABLE deelgebied.sluice AS
SELECT
       a.*
FROM
       checks.sluice     as a
     , deelgebied.polder as b
WHERE
       ST_Intersects(b.geom,a.geom)
;

DELETE
FROM
       deelgebied.sluice a
USING  checks.channel_nowayout b
WHERE
       ST_Intersects(a.geom,b.geom)
;

--Knip stuwen uit
DROP TABLE IF EXISTS deelgebied.weirs
;

CREATE TABLE deelgebied.weirs AS
SELECT
       a.*
FROM
       checks.weirs      as a
     , deelgebied.polder as b
WHERE
       ST_Intersects(b.geom,a.geom)
       AND a.isusable = 1
;

DELETE
FROM
       deelgebied.weirs a
USING  checks.channel_nowayout b
WHERE
       ST_Intersects(a.geom,b.geom)
;

DELETE
FROM
       deelgebied.weirs
WHERE
       type LIKE '5'
;

DROP TABLE IF EXISTS tmp.culvert_to_weir
;

CREATE TABLE tmp.culvert_to_weir AS
             (
                    SELECT
                           a.code as culvert_code
                         , a.geom as culvert_geom
                         , b.*
                    FROM
                           checks.culvert a
                         , checks.weirs   b
                    WHERE
                           a.opmerking LIKE '%stuw op duiker%'
                           AND
                           (
                                  b.opmerking   NOT LIKE '%niet op peilgrens%'
                                  OR b.opmerking IS NULL
                           )
                           AND ST_Intersects(a.geom,b.geom)
                           AND a.isusable = 1
                           AND b.isusable = 1
             )
;

--Verwijder stuwen die aansluiten op een duiker. De duiker zal eerst verlijnd worden en vervolgens omgezet worden in een stuw
DELETE
FROM
       deelgebied.weirs
WHERE
       code IN
       (
              SELECT
                     code
              FROM
                     tmp.culvert_to_weir
       )
;

-- vaste dammen als hoge stuwen inladen (crestlevel 15mNAP)
drop sequence
if exists serial;
    create sequence serial;
    select
           setval('serial', (
                  select
                         max(id)
                  from
                         deelgebied.weirs
           )
           )
    ;
    
    insert into deelgebied.weirs
           (id
                , code
                , name
                , crest_level
                , crest_width
                , channel_code
                , wgtype_id
                , channel_type_id
                , geom
                , opmerking
           )
    select
           nextval('serial')
         , a.code
         , concat('fixed_dam_id',a.id)
         , -- deelgebied.weirs.name wordt 'fixed_dam_id_123' voor terug zoeken
           15
         , -- crest_level van vaste dammen zetten we op 15mNAP
           2
         , --crest_width van vaste dammen zetten we op 2m
           a.channel_code::integer
         , a.wgtype_id
         , a.channel_type_id
         , a.geom
         , a.opmerking
    from
           checks.fixed_dam     a
         , deelgebied.polder as b
    where
           ST_Intersects(a.geom,b.geom)
           and a.isusable = 1
    ;
    
    CREATE INDEX deelgebied_weirs_geom
    ON
                 deelgebied.weirs
    USING        gist
                 (
                              geom
                 )
    ;
    
    --Knip watergangen uit
    DROP TABLE IF EXISTS deelgebied.channel
    ;
    
    CREATE TABLE deelgebied.channel AS
    SELECT DISTINCT
           a.*
    FROM
           checks.channel    as a
         , deelgebied.polder as b
    WHERE
           ST_Intersects(b.geom,a.geom)
    ;
    
    CREATE INDEX deelgebied_channel_geom
    ON
                 deelgebied.channel
    USING        gist
                 (
                              geom
                 )
    ;
    
    --Fix broken buffer geometries
    UPDATE
           deelgebied.channel
    SET    bufgeom = ST_MakeValid(bufgeom)
    WHERE
           NOT ST_IsValid(bufgeom)
    ;
    
    --kanalen op kruisingen zonder kunstwerk niet mee nemen
    DELETE
    FROM
           deelgebied.channel               as a
    USING  checks.kruising_zonder_kunstwerk as b
    WHERE
           ST_Intersects(a.bufgeom,b.pointgeom)
    ;
    
    -- verwijder kanalen op de rand van polder waar geen gemaal of stuw op ligt
    DELETE
    FROM
           deelgebied.channel
    WHERE
           id IN
           (
                  SELECT
                         a.id
                  FROM
                         deelgebied.channel as a
                       , deelgebied.polder  as b
                  WHERE
                         ST_Intersects(a.geom,b.outergeom)
                         AND id NOT IN
                         (
                                SELECT
                                       a.id
                                FROM
                                       deelgebied.channel     as a
                                     , deelgebied.pumpstation as b
                                WHERE
                                       ST_DWithin(a.geom,b.geom,5)
                                UNION
                                SELECT
                                       a.id
                                FROM
                                       deelgebied.channel as a
                                     , deelgebied.weirs   as b
                                WHERE
                                       ST_DWithin(a.geom,b.geom,5)
                                UNION
                                SELECT
                                       a.id
                                FROM
                                       deelgebied.channel as a
                                     , deelgebied.sluice  as b
                                WHERE
                                       ST_DWithin(a.geom,b.geom,5)
                                UNION
                                SELECT
                                       a.id
                                FROM
                                       deelgebied.channel as a
                                     , deelgebied.polder  as b
                                WHERE
                                       ST_Intersects(ST_Startpoint(a.geom),b.geom)
                                       AND a.id IN
                                       (
                                              SELECT
                                                     a.id
                                              FROM
                                                     deelgebied.channel as a
                                                   , deelgebied.polder  as b
                                              WHERE
                                                     ST_Intersects(ST_Endpoint(a.geom),b.geom)
                                       )
                         )
           )
    ;
    
    --verwijder kanalen die niet kunnen afvoeren door foutieve segmenten
    DELETE
    FROM
           deelgebied.channel      as a
    USING  checks.channel_nowayout as b
    WHERE
           ST_Intersects(b.geom,a.pointgeom)
    ;
    
    --verwijder losliggende kanalen
    DELETE
    FROM
           deelgebied.channel   as a
    USING  checks.channel_loose as b
    WHERE
           ST_Intersects(b.geom,a.pointgeom)
    ;
    
    --Knip wateroppervlak uit
    DROP TABLE IF EXISTS deelgebied.channelsurface
    ;
    
    CREATE TABLE deelgebied.channelsurface AS
    SELECT
           ST_Intersection(a.geom,b.innergeom) as geom
         , 10.0                                as height
    FROM
           checks.channelsurface as a
         , deelgebied.polder     as b
    WHERE
           ST_Intersects(a.geom,b.innergeom)
    ;
    
    --Knip crosssections uit
    DROP TABLE IF EXISTS deelgebied.crosssection
    ;
    
    CREATE TABLE deelgebied.crosssection AS
    SELECT
           a.*
    FROM
           checks.crosssection as a
         , deelgebied.polder   as b
    WHERE
           ST_Intersects(b.geom,a.geom)
           and a.isusable = 1
           --LIMIT 0 -- gebruiken we niet maar moet wel in de DB staan
    ;
    
    --Knip crossprofiles uit
    DROP TABLE IF EXISTS deelgebied.crossprofile
    ;
    
    CREATE TABLE deelgebied.crossprofile AS
    SELECT
           a.*
    FROM
           checks.crossprofile as a
    WHERE
           isusable = 1
           AND id IN
           (
                  SELECT
                         cross_profile_id
                  FROM
                         deelgebied.crosssection as b
           )
    ;
    
    -- tijdelijke oplossing vanwege isusable bug
    DELETE
    FROM
           deelgebied.crosssection
    WHERE
           cross_profile_id IN
           (
                  SELECT
                         id
                  FROM
                         checks.crossprofile
                  WHERE
                         isusable = 0
           )
    ;
    
    /*
    SELECT * FROM checks.crosssection WHERE cross_profile_id = 42324
    SELECT * FROM checks.crossprofile WHERE id = 42324
    */
    --Knip duikers/syphonnen uit
    DROP TABLE IF EXISTS deelgebied.culvert
    ;
    
    CREATE TABLE deelgebied.culvert AS
    SELECT
           a.*
    FROM
           checks.culvert    as a
         , deelgebied.polder as b
    WHERE
           ST_Intersects(b.geom,a.geom)
           AND isusable = 1
    ;
    
    DELETE
    FROM
           deelgebied.culvert a
    USING  checks.channel_nowayout b
    WHERE
           ST_Contains(b.geom,a.geom)
           AND a.id IN
           (
                  SELECT
                         id
                  FROM
                         deelgebied.culvert
                  WHERE
                         opmerking NOT LIKE '%afsluitbare inlaat op peilgrens%'
           )
    ;
    
    -- we nemen alle culverts mee. De tool van Lars doet z'n best om alles te koppelen.
    -- Als data van HHNK veel beter is kunnen we wel hier een selectie maken.
    --Knip peilgebieden uit (behalve boezemgebieden)
    DROP TABLE IF EXISTS deelgebied.fixeddrainagelevelarea
    ;
    
    CREATE TABLE deelgebied.fixeddrainagelevelarea AS
    SELECT DISTINCT
           a.*
    FROM
           checks.fixeddrainagelevelarea as a--, deelgebied.polder as b
           --WHERE ST_Intersects(b.geom,a.geom) AND lower(name) NOT LIKE '%boezem%'
    ;
    
    --Fix broken geometries
    UPDATE
           deelgebied.fixeddrainagelevelarea
    SET    geom = ST_MakeValid(geom)
    WHERE
           NOT ST_IsValid(geom)
    ;
    
    --Knip levees uit
    DROP TABLE IF EXISTS deelgebied.levee
    ;
    
    CREATE TABLE deelgebied.levee AS
    SELECT
           a.*
    FROM
           checks.levee      as a
         , deelgebied.polder as b
    WHERE
           ST_Contains(b.geom,a.geom)
    ;
    
    CREATE INDEX deelgebied_levee_geom
    ON
                 deelgebied.levee
    USING        gist
                 (
                              geom
                 )
    ;
    
    CREATE INDEX deelgebied_levee_miggeom
    ON
                 deelgebied.levee
    USING        gist
                 (
                              midgeom
                 )
    ;
    
    --Knip manholes uit
    DROP TABLE IF EXISTS deelgebied.manhole
    ;
    
    CREATE TABLE deelgebied.manhole AS
    SELECT
           a.*
    FROM
           checks.manhole    as a
         , deelgebied.polder as b
    WHERE
           ST_Intersects(b.geom,a.geom)
    ;
    
    --Knip orifices uit
    DROP TABLE IF EXISTS deelgebied.orifice
    ;
    
    CREATE TABLE deelgebied.orifice AS
    SELECT
           a.*
    FROM
           checks.orifice    as a
         , deelgebied.polder as b
    WHERE
           ST_Intersects(b.geom,a.geom)
    ;
    
    --Knip peilgrenzen met waterpeil uit
    DROP TABLE IF EXISTS deelgebied.peilgrens_met_waterpeil
    ;
    
    CREATE TABLE deelgebied.peilgrens_met_waterpeil AS
    SELECT
           a.*
    FROM
           checks.levee      as a
         , deelgebied.polder as b
    WHERE
           ST_Intersects(b.geom,a.geom)
    ;
    
    --Knip afvoerkunstwerken uit
    DROP TABLE IF EXISTS deelgebied.afvoerkunstwerken
    ;
    
    CREATE TABLE deelgebied.afvoerkunstwerken AS
                 (
                        SELECT
                               a.*
                        FROM
                               checks.afvoerkunstwerken AS a
                             , deelgebied.polder        AS b
                        WHERE
                               ST_Intersects(b.geom, a.geom)
                 )
    ;
    
    -- indexen voor alle tabellen
    CREATE INDEX deelgebied_sluice_geom
    ON
                 deelgebied.sluice
    USING        gist
                 (
                              geom
                 )
    ;
    
    CREATE INDEX deelgebied_orifice_geom
    ON
                 deelgebied.orifice
    USING        gist
                 (
                              geom
                 )
    ;
    
    CREATE INDEX deelgebied_manhole_geom
    ON
                 deelgebied.manhole
    USING        gist
                 (
                              geom
                 )
    ;
    
    CREATE INDEX deelgebied_fixeddrainagelevelarea_geom
    ON
                 deelgebied.fixeddrainagelevelarea
    USING        gist
                 (
                              geom
                 )
    ;
    
    CREATE INDEX deelgebied_culvert_geom
    ON
                 deelgebied.culvert
    USING        gist
                 (
                              geom
                 )
    ;
    
    CREATE INDEX deelgebied_crosssection_geom
    ON
                 deelgebied.crosssection
    USING        gist
                 (
                              geom
                 )
    ;
    
    CREATE INDEX deelgebied_bridge_geom
    ON
                 deelgebied.bridge
    USING        gist
                 (
                              geom
                 )
    ;
    
    CREATE INDEX deelgebied_peilgrens_met_waterpeil_geom
    ON
                 deelgebied.peilgrens_met_waterpeil
    USING        gist
                 (
                              geom
                 )
    ;
    
    DROP TABLE IF EXISTS deelgebied.culvert_to_pumpstation
    ;
    
    CREATE TABLE deelgebied.culvert_to_pumpstation AS
                 (
                        SELECT
                               a.*
                        FROM
                               tmp.culvert_to_pumpstation a
                             , deelgebied.polder          b
                        WHERE
                               ST_Intersects(ST_Buffer(b.geom,5),a.culvert_geom)
                 )
    ;
    
    DROP TABLE IF EXISTS deelgebied.culvert_to_weir
    ;
    
    CREATE TABLE deelgebied.culvert_to_weir AS
                 (
                        SELECT
                               a.*
                        FROM
                               tmp.culvert_to_weir a
                             , deelgebied.polder   b
                        WHERE
                               ST_Intersects(ST_Buffer(b.geom,5),a.culvert_geom)
                 )
    ;
    
    DROP TABLE IF EXISTS deelgebied.control_table
    ;
    
    CREATE TABLE deelgebied.control_table AS
                 (
                        SELECT
                               a.*
                        FROM
                               checks.control_table a
                             , deelgebied.polder    b
                        WHERE
                               ST_Intersects(b.geom,a.measurement_location)
                               AND is_usable
                 )
    ;