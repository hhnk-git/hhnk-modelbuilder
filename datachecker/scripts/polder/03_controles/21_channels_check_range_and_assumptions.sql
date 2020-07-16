/*
Assumptions channels
channe_type = 1 primaire watergangen
1. if the left embankment or  right embankment of a channel is larger than 0.30 or smaller than 0.1 or not filled at all, than the embankment will be filled as 2 for primary channels and 1.5 for not primary channels.
2. If the difference between the bed level of channel and the waterlevel of the fixeddrainagelevelarea is not between 0.2 and 20, the channel is inclined and it is a primary channel, bed level is set to waterlevel - 1.
3. If the channel is not primary then the bed level is set to waterlevel -0.5. If channel and fixeddrainagelevelarea intersect then, bed level is the waterlevel - 10.5.
4. If the bed level of a channel is smaller than -100 then it is set to -10.
5. If bed with is not between 02 or 400 and it is a primary channel then it is set to 3. If the channel is not a primary channel then it is set to 1.
*/
/*
Talud links (-) 0,1 - 30
Talud rechts (-) 0,1 - 30
Bodemhoogte Lager dan peil*
Bodembreedt (m) 0,2 -100
Watergangprofiel
Talud Bodemdiepte Drooglegging Bodembreedte Bodemweerstand (Strickler waarde)
[-] [m] [m] [m] [m1/3/s]
primair 1:2 1 0 3 30
overig 1:1.5 0.5 0 1 20
*/
-- talud
ALTER TABLE checks.channel DROP COLUMN IF EXISTS aanname
;

ALTER TABLE checks.channel ADD COLUMN aanname varchar(200)
;

UPDATE
    checks.channel
SET talud_left = 2
  , aanname    = concat_ws(',',aanname,'talud_left')
WHERE
    channel_type_id = 1
    AND
    (
        talud_left IS NULL
        OR talud_left    <0.1
        OR talud_left    > 30
    )
;

UPDATE
    checks.channel
SET talud_right = 2
  , aanname     = concat_ws(',',aanname,'talud_right')
WHERE
    channel_type_id = 1
    AND
    (
        talud_right IS NULL
        OR talud_right    <0.1
        OR talud_right    > 30
    )
;

UPDATE
    checks.channel
SET talud_left = 1.5
  , aanname    = concat_ws(',',aanname,'talud_left')
WHERE
    channel_type_id <> 1
    AND
    (
        talud_left IS NULL
        OR talud_left    <0.1
        OR talud_left    > 30
    )
;

UPDATE
    checks.channel
SET talud_right = 1.5
  , aanname     = concat_ws(',',aanname,'talud_right')
WHERE
    channel_type_id <> 1
    AND
    (
        talud_right IS NULL
        OR talud_right    <0.1
        OR talud_right    > 30
    )
;

UPDATE
    checks.channel as a
SET bed_level = b.streefpeil_bwn2 - 1
  , aanname   = concat_ws(',',aanname,'bed_level')
FROM
    checks.fixeddrainagelevelarea as b
WHERE
    ST_Intersects(a.geom,b.geom)
    AND channel_type_id = 1
    AND
    (
        (
            b.streefpeil_bwn2 - a.bed_level
        )
        NOT BETWEEN 0.2 AND 20
        OR a.bed_level IS NULL
    )
    AND typering <> 'Hellend'
; --147 sec
UPDATE
    checks.channel as a
SET bed_level = b.streefpeil_bwn2 - 1
  , aanname   = concat_ws(',',aanname,'bed_level')
FROM
    checks.fixeddrainagelevelarea as b
WHERE
    ST_Intersects(a.geom,b.geom)
    AND channel_type_id   = 1
    AND a.bed_level IS NULL
    AND typering          = 'Hellend'
;

UPDATE
    checks.channel as a
SET bed_level = b.streefpeil_bwn2 - 0.5
  , aanname   = concat_ws(',',aanname,'bed_level')
FROM
    checks.fixeddrainagelevelarea as b
WHERE
    ST_Intersects(a.geom,b.geom)
    AND channel_type_id <> 1
    AND
    (
        (
            b.streefpeil_bwn2 - a.bed_level
        )
        NOT BETWEEN 0.2 AND 20
        OR a.bed_level IS NULL
    )
    AND typering <> 'Hellend'
; --147 sec
UPDATE
    checks.channel as a
SET bed_level = b.streefpeil_bwn2 - 10.5
  , aanname   = concat_ws(',',aanname,'bed_level')
FROM
    checks.fixeddrainagelevelarea as b
WHERE
    ST_Intersects(a.geom,b.geom)
    AND channel_type_id  <> 1
    AND a.bed_level IS NULL
    AND typering          = 'Hellend'
;

UPDATE
    checks.channel as a
SET bed_level = -10
  , aanname   = concat_ws(',',aanname,'bed_level')
WHERE
    bed_level IS NULL
    OR bed_level    < -100
;

-- bodembreedte
UPDATE
    checks.channel
SET bed_width = 3.0
  , aanname   = concat_ws(',',aanname,'bed_width')
WHERE
    channel_type_id = 1
    AND
    (
        bed_width IS NULL
        OR bed_width    <0.2
        OR bed_width    > 400
    )
;

UPDATE
    checks.channel
SET bed_width = 1.0
  , aanname   = concat_ws(',',aanname,'bed_width')
WHERE
    channel_type_id<> 1
    AND
    (
        bed_width IS NULL
        OR bed_width    <0.2
        OR bed_width    > 400
    )
;