/*
Dit script leest gebruikt de volgende tabellen:
-hdb.sturing_3di
-nxt.weir

Aan de nxt.weir tabel wordt het volgende toegevoegd:
-is_controlled (boolean)
-measurement_variable
-control_variable

*/

/*
ALTER TABLE nxt.weir DROP COLUMN IF EXISTS is_controlled;
ALTER TABLE nxt.weir DROP COLUMN IF EXISTS ctrl_measure_variable;
ALTER TABLE nxt.weir DROP COLUMN IF EXISTS ctrl_action_type;
ALTER TABLE nxt.weir DROP COLUMN IF EXISTS ctrl_measure_operator;
ALTER TABLE nxt.weir DROP COLUMN IF EXISTS ctrl_measure_values;
ALTER TABLE nxt.weir DROP COLUMN IF EXISTS ctrl_control_values;
ALTER TABLE nxt.weir DROP COLUMN IF EXISTS ctrl_measurement_location;

ALTER TABLE nxt.weir ADD COLUMN is_controlled boolean;
ALTER TABLE nxt.weir ADD COLUMN ctrl_measure_variable varchar(20);
ALTER TABLE nxt.weir ADD COLUMN ctrl_action_type varchar(20);
ALTER TABLE nxt.weir ADD COLUMN ctrl_measure_operator varchar(1);
ALTER TABLE nxt.weir ADD COLUMN ctrl_measure_values double precision[];
ALTER TABLE nxt.weir ADD COLUMN ctrl_control_values double precision[];
ALTER TABLE nxt.weir ADD COLUMN ctrl_measurement_location geometry(PointZ,4326);
*/

DROP TABLE IF EXISTS nxt.control_table;
CREATE TABLE nxt.control_table
(
  id serial NOT NULL,
  structure_code varchar(50),
  structure_type varchar(50),
  measure_variable varchar(50),
  action_type varchar(50),
  measure_operator varchar(1),
  measure_values double precision[],
  control_values double precision[],
  action_table text,
  measurement_location geometry(PointZ,4326),
  CONSTRAINT hydra_core_control_table_pkey PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);


INSERT INTO nxt.control_table (structure_code, structure_type, measure_variable, action_type, measure_operator, measure_values, control_values, action_table, measurement_location)
SELECT 
	code,
    CASE type_kunstwerk
        WHEN 'duiker' THEN 'culvert'
        WHEN 'stuw' THEN 'weir'
        ELSE NULL
    END,
	CASE meetvariabele
		WHEN 'Waterstand' THEN 'waterlevel'
		ELSE NULL
	END,
	CASE actievariabele
		WHEN 'Kruinhoogte' THEN 'set_crest_level'
        WHEN 'afvoer_coefficient' THEN 'set_discharge_coefficients'
		ELSE NULL
	END,
	drempel,
	string_to_array(replace(meetwaarden,' ',''),',')::double precision[],
	string_to_array(replace(actiewaarden,' ',''),',')::double precision[],
    action_table,
	ST_Force3d(ST_Transform(wkb_geometry,4326))::geometry(PointZ)
FROM hdb.sturing_3di
;
