--Controles op kunstwerk sturing

--Zijn meetreeksen oplopend/aflopend
--Bestaat het kunstwerk

ALTER TABLE checks.control_table DROP COLUMN IF EXISTS opmerking;
ALTER TABLE checks.control_table ADD COLUMN opmerking text;


--Controleer of er geen dubbelingen in structure_code zijn
ALTER TABLE checks.control_table DROP COLUMN IF EXISTS has_code;
ALTER TABLE checks.control_table ADD COLUMN has_code boolean;

UPDATE checks.control_table SET has_code = TRUE;
UPDATE checks.control_table SET has_code = FALSE WHERE structure_code IS NULL;

ALTER TABLE checks.control_table DROP COLUMN IF EXISTS unique_code;
ALTER TABLE checks.control_table ADD COLUMN unique_code boolean;

UPDATE checks.control_table SET unique_code = structure_code NOT IN(
SELECT structure_code
FROM checks.control_table
GROUP BY structure_code
HAVING count(*)>1);

--Check if controlled structure exists
ALTER TABLE checks.control_table DROP COLUMN IF EXISTS structure_exists;
ALTER TABLE checks.control_table ADD COLUMN structure_exists boolean;

UPDATE checks.control_table SET structure_exists = structure_code IN(
SELECT code FROM checks.weirs
UNION
SELECT code FROM checks.pumpstation
UNION
SELECT code FROM checks.culvert
);


--Check if measurement series in continues incrementing/decreasing
DROP TABLE IF EXISTS tmp.control_measurement_increment;
CREATE TABLE tmp.control_measurement_increment AS(
WITH unnested AS(
	SELECT structure_code, measure_values[elem_nr] as m_value, elem_nr
	FROM 
		(
		SELECT *, generate_subscripts(measure_values,1) AS elem_nr 
		FROM checks.control_table
		) t
),
ordered_increment AS(
	SELECT structure_code, elem_nr, m_value, lag(m_value) 
	OVER (PARTITION BY structure_code ORDER BY elem_nr) 
	FROM unnested
),
grouped_increment AS(
	SELECT 
		structure_code, 
		max(m_value-lag) as max_increment, 
		min(m_value-lag) as min_increment 
	FROM ordered_increment 
	GROUP BY structure_code
)
SELECT 
	structure_code, 
	(max_increment<0 AND min_increment<0) OR (max_increment>0 AND max_increment>0) as correct_measurement_series
FROM grouped_increment
)
;


ALTER TABLE checks.control_table DROP COLUMN IF EXISTS correct_measurement_series;
ALTER TABLE checks.control_table ADD COLUMN correct_measurement_series boolean;

UPDATE checks.control_table SET correct_measurement_series = structure_code IN (SELECT structure_code FROM tmp.control_measurement_increment WHERE correct_measurement_series);

DROP TABLE IF EXISTS tmp.control_measurement_increment;


--Convert arrays to table control string
ALTER TABLE checks.control_table DROP COLUMN IF EXISTS table_control_string;
ALTER TABLE checks.control_table ADD COLUMN table_control_string text;

DROP TABLE IF EXISTS tmp.table_control;
CREATE TABLE tmp.table_control AS(
WITH unnested AS(
    SELECT 
        structure_code, 
        unnest(measure_values) as measurement_value, 
        unnest(control_values) as control_value, 
        measure_values, 
        control_values,
        action_type
    FROM checks.control_table)
    ,unnested_concat AS(
        SELECT 
            structure_code,
            CASE action_type
                WHEN 'set_crest_level' THEN concat(measurement_value::text,';', control_value)
                WHEN 'set_discharge_coefficients' THEN concat(measurement_value::text,';', control_value, ' ' ,control_value)
                ELSE NULL
            END as step_control
    FROM unnested)

SELECT structure_code, string_agg(step_control,'#') as table_control FROM unnested_concat GROUP BY structure_code);

UPDATE checks.control_table a SET table_control_string = b.table_control
FROM tmp.table_control b WHERE a.structure_code = b.structure_code;

--Check if control is usable
ALTER TABLE checks.control_table DROP COLUMN IF EXISTS is_usable;
ALTER TABLE checks.control_table ADD COLUMN is_usable boolean;

UPDATE checks.control_table SET is_usable = (unique_code AND structure_exists AND correct_measurement_series AND has_code);

--Create action_table