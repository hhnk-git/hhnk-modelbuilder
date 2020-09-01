/*
Dit script zet de structuur van de database op in de vorm van schema's. Er worden nog geen tabellen aangemaakt.
De bestaande schema's inclusief alle  tabellen die daar in zitten worden verwijderd.
*/

DROP SCHEMA
    IF EXISTS deelgebied CASCADE;
    
DROP SCHEMA
    IF EXISTS tmp CASCADE;
        
DROP SCHEMA
   IF EXISTS feedback CASCADE;

CREATE SCHEMA deelgebied;
CREATE SCHEMA tmp;
CREATE SCHEMA feedback;

DELETE FROM v2_culvert;
DELETE FROM v2_manhole;
DELETE FROM v2_orifice;
DELETE FROM v2_1d_lateral;
DELETE FROM v2_cross_section_location; 
DELETE FROM v2_weir;
DELETE FROM v2_pumpstation;
DELETE FROM v2_channel;
DELETE FROM v2_impervious_surface_map;
DELETE FROM v2_connection_nodes; 
DELETE FROM v2_cross_section_definition;
DELETE FROM v2_1d_boundary_conditions;
DELETE FROM v2_connection_nodes;
DELETE FROM v2_global_settings;
DELETE FROM v2_numerical_settings;
DELETE FROM v2_levee;
DELETE FROM v2_grid_refinement;