UPDATE
    v2_cross_section_location
SET reference_level = round(reference_level,2)
  , bank_level      = round(bank_level,2)
;

UPDATE
    v2_culvert
SET invert_level_start_point = round(invert_level_start_point, 2)
  , invert_level_end_point   = round(invert_level_end_point,2)
;

UPDATE
    v2_impervious_surface
SET area = round(area,2)
;

UPDATE
    v2_levee
SET crest_level = round(crest_level,2)
;

UPDATE
    v2_manhole
SET bottom_level  = round(bottom_level,2)
  , surface_level = round(surface_level,2)
  , drain_level   = round(drain_level,2)
;

UPDATE
    v2_orifice
SET crest_level = round(crest_level,2)
;

UPDATE
    v2_pumpstation
SET start_level = round(start_level,2)
  , end_level   = round(end_level,2)
  , capacity    = round(capacity,2)
;

UPDATE
    v2_weir
SET crest_level = round(crest_level)
;