/*
Assumptions pumpstations
    1. If a pumpstation has no capacity and it is on a primary channel the capacity is set to 25m3 per minute.
    2. If a pumpstation has no capacity and it is not on a primary channel, the capacity is set to 1m3 per minute.
    3. If a pumpstation has a type of '98', the capacity is set to 0m3 per minute.
*/
/*
Gemalen	Capaciteit (m3/min) 0.001 - 1000 
	Primair: 25 m3/min als er niet is ingevuld
    Primair: niet updaten (enkel een opmerking) als er wel wat is ingevuld 
    Overige: 1 m3/min
*/

ALTER TABLE checks.pumpstation DROP COLUMN IF EXISTS aanname;
ALTER TABLE checks.pumpstation ADD COLUMN aanname varchar(200);


UPDATE checks.pumpstation
SET opmerking = concat_ws(',',opmerking,'weird_capacity') 
WHERE channel_type_id = 1 
AND capacity IS NULL
;

UPDATE checks.pumpstation
SET capacity = 25, 
	aanname = concat_ws(',',aanname,'capacity25m3_min') 
WHERE channel_type_id = 1 
AND capacity IS NULL
;

UPDATE checks.pumpstation
SET capacity = 1, 
	aanname = concat_ws(',',aanname,'capacity1m3_min') 
WHERE channel_type_id <> 1
AND capacity IS NULL
AND type NOT LIKE '98'
;

--zet doorspoelgemalen uit
UPDATE checks.pumpstation
SET capacity = 0, 
	aanname = concat_ws(',',aanname,'capacity0m3_min') 
WHERE type LIKE '98'
;

