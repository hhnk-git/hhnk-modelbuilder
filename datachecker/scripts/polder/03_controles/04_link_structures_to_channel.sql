/* Add the channel_id to the structure in order to link them together */
UPDATE
    checks.pumpstation as a
SET channel_code = b.id
  , wgtype_id    = b.channel_type_id
FROM
    checks.channel_linemerge as b
WHERE
    ST_Intersects(b.bufgeom,a.geom)
    AND a.on_channel
    AND NOT a.multiple_channels
;

--voor stuwen
UPDATE
    checks.weirs as a
SET channel_code = b.id
FROM
    checks.channel_linemerge as b
WHERE
    ST_Intersects(b.bufgeom,a.geom)
    AND a.on_channel
    AND NOT a.multiple_channels
;

--voor bruggen
UPDATE
    checks.bridge as a
SET channel_code = b.id
FROM
    checks.channel_linemerge as b
WHERE
    ST_Intersects(b.bufgeom,a.geom)
    AND a.on_channel
    AND NOT a.multiple_channels
;

--voor duikers
UPDATE
    checks.culvert as a
SET channel_code = b.id
FROM
    checks.channel_linemerge as b
WHERE
    ST_Contains(b.bufgeom,a.geom)
    AND a.on_channel
    AND NOT weir_attached
    AND NOT pump_attached
;

--voor vaste dammen
UPDATE
    checks.fixed_dam as a
SET channel_code = b.id
FROM
    checks.channel_linemerge as b
WHERE
    ST_Intersects(b.bufgeom,a.geom)
    AND a.on_channel
    AND NOT a.multiple_channels
;