DROP FUNCTION IF EXISTS yz_to_tabulated(steps integer, y float[], z float[]);
DROP TYPE IF EXISTS tabulated_type CASCADE;
CREATE TYPE tabulated_type as (height float[], width float[], max_height float, max_width float, min float, max float, length integer);
drop sequence if exists serial;
create sequence serial start 1;

-- vereenvoudig geometrie profiel lijnen
drop table if exists tmp.gw_pro_sp
;
create table tmp.gw_pro_sp as
select
    nextval('serial') as serial
  , pro_id
  , unnest(array_agg(osmomsch))                                                                           as osmomsch
  , unnest(array_agg(proident))                                                                           as proident
  , min(ovk_ovk_id)                                                                                       as ovk_ovk_id
  , min(prw_prw_id)                                                                                       as prw_prw_id
  , (st_dump(st_collect(st_transform(st_force2d(wkb_geometry), 28992)))).geom::geometry(Linestring,28992) AS geom
from
    damo_ruw.gw_pro
group by
    pro_id
;

-- selecteer profielmetingen in baggerlaag Z2 en natte delen
drop table if exists tmp.profielpunten_selectie
;
create table tmp.profielpunten_selectie as
select *
from
    damo_ruw.gw_pbp
where
    prw_prw_id in
    (
        select
            prw_id
        from
            damo_ruw.gw_prw -- gw_prw bevat beschrijving Z1 of Z2
        where
            osmomsch = 'Z2'
    )
    AND pbpsoort = ANY (ARRAY[5,6,7,22])
;

-- ordenen en hernoemen profielhoogtemetingen en afstand naar resp. z en y
drop table if exists tmp.yz_table
;
create table tmp.yz_table as
select
    prw_prw_id::varchar as name
  , prw_prw_id::integer
  , round(iws_hoogte::numeric,3)  as z
  , round(iws_afstand::numeric,3) as y
from
    tmp.profielpunten_selectie
order by
    prw_prw_id
  , iws_afstand
;

/* functie die profielmetingen om zet naar vereenvoudigd getalleerd profiel
    steps: het aan tabelregels in het getabuleerde profiel
    y: de afstand van de meting vanaf het eerste meetpunt
    z: de NAP hoogte van de meting
*/
CREATE OR REPLACE FUNCTION yz_to_tabulated(steps integer, y float[], z float[])
RETURNS setof tabulated_type AS $$
DECLARE
step            integer;
min             float;
max             float;
length          integer;
indicis_min     integer[];
index_first_min integer;
index_last_min  integer;
max_left        float;
max_right       float;
index_left_max  integer;
index_right_max integer;
i               integer;
n               float;
z_sel           float[];
z_pos           integer[];
y_sel           float[];
level           float;
width           float[];
height          float[];
max_height      float;
max_width       float;
BEGIN
min = min(unnest) from (
    select
        unnest(z)
)
b;
max = max(unnest) from (
    select
        unnest(z)
)
b;
length          = array_length(z, 1);
indicis_min     = array_positions(z, min);
index_first_min = min(unnest) from (
    select
        unnest(indicis_min)
)
foo;
index_last_min = max(unnest) from (
    select
        unnest(indicis_min)
)
foo;
max_left = max(unnest) from (
    select
        unnest(z[1:index_first_min])
)
b;
max_right = max(unnest) from (
    select
        unnest(z[index_last_min:length])
)
b;
index_left_max = max(unnest) from (
    select
        unnest(array_positions(z[1:index_first_min], max_left))
)
foo;
index_right_max = index_last_min-1 + min(unnest) from (
    select
        unnest(array_positions(z[index_last_min:length], max_right))
)
foo;
IF array_length(indicis_min,1) = 1 THEN
width[1]                       = 0;
ELSE
width[1] = round(abs(y[index_last_min] - y[index_first_min])::numeric,3);
END IF;
height[1] = 0;
steps     = least(steps, (length/2));
FOR step in 1..steps
LOOP
level = round(((max - min) * step / steps)::numeric,3);
y_sel = '{NULL, NULL}';
z_sel = '{9999,9999}';
z_pos = '{NULL, NULL}';
i     = 1;
FOREACH n in array z[index_left_max:index_first_min]
LOOP
IF abs(n - min - level) < abs(z_sel[i] - min - level) THEN
z_sel[i]                = n;
z_pos[i]                = index_left_max-1 + array_position(z[index_left_max:index_first_min], n);
END IF;
END LOOP;
y_sel[i] = y[z_pos[i]];
i        =2;
FOREACH n in array z[index_last_min:index_right_max]
LOOP
IF abs(n - min - level) < abs(z_sel[i] - min - level) THEN
z_sel[i]                = n;
z_pos[i]                = index_last_min-1 + array_position(z[index_last_min:index_right_max], n);
END IF;
END LOOP;
y_sel[i]                 = y[z_pos[i]];
IF (y_sel[2] - y_sel[1]) > 0 THEN
width[step+1]            = round(greatest(width[step], y_sel[2] - y_sel[1])::numeric,3);
height[step+1]           = level;
END IF;
END LOOP;
max_height = max(unnest) from (
    select
        unnest(height)
)
foo;
max_width = max(unnest) from (
    select
        unnest(width)
)
foo;
return query
select
    height
  , width
  , max_height
  , max_width
  , min
  , max
  , length
;

END; $$
LANGUAGE PLPGSQL;

/* DEBUG remark:
set correct cross_section_definition_id for iteration
select setval('v2_cross_section_definition_id_seq', (select max(id) from v2_cross_section_definition));
*/

-- YZ to TABULATED in one query!!!
-- hier functie gebruikt met 5 regels in de tabel voor breedte en hoogte
-- vervolgens nog enkele algemente eigenschappen afgeleid tbv checks later
drop table if exists tmp.tabulated_table
;
create table tmp.tabulated_table as
select
    name                                                                                                              as defname
  , prw_prw_id                                                                                                        as prw_id
  , array_to_string((yz_to_tabulated(5, array_agg(y::float order by y), array_agg(z::float order by y))).width, ' ')  as width
  , array_to_string((yz_to_tabulated(5, array_agg(y::float order by y), array_agg(z::float order by y))).height, ' ') as height
  , (yz_to_tabulated(5, array_agg(y::float order by y), array_agg(z::float order by y))).max_height                   as max_height
  , (yz_to_tabulated(5, array_agg(y::float order by y), array_agg(z::float order by y))).max_width                    as max_width
  , (yz_to_tabulated(5, array_agg(y::float order by y), array_agg(z::float order by y))).min                          as min
  , (yz_to_tabulated(5, array_agg(y::float order by y), array_agg(z::float order by y))).max                          as max
  , (yz_to_tabulated(5, array_agg(y::float order by y), array_agg(z::float order by y))).length                       as nr_input_points
FROM
    (
        SELECT *
        FROM
            tmp.yz_table
    )
    foo
group by
    name
  , prw_prw_id
;

-- koppelen yz array (width, height) aan een profiel id (de dwarslijnen op de hydroobjecten).
alter table tmp.tabulated_table add column channel_id integer
;
alter table tmp.tabulated_table add column pro_id integer
;
update
    tmp.tabulated_table a
set pro_id = b.pro_pro_id
from
    damo_ruw.gw_prw b
where
    a.prw_id = b.prw_id
;

-- verwijder onmogelijke profielen (slechts twee metingen)
DELETE FROM tmp.tabulated_table 
WHERE nr_input_points <3
;

-- nxt.channel maken en vullen vanuit damo
-- TODO: waarom hier en niet in 08?
drop table if exists nxt.channel
;

CREATE TABLE nxt.channel
    (
        id serial NOT NULL
      , organisation_id integer
      , created         timestamp with time zone NOT NULL
      , code            character varying(50)
      , type            character varying(50) NOT NULL
      , bed_level double precision
      , comment text
      , name    character varying(255) NOT NULL
      , talud_left double precision
      , talud_right double precision
      , image_url character varying(2048)
      , geometry geometry(LineStringZ,4326)
      , "end" timestamp with time zone
      , start timestamp with time zone
      , CONSTRAINT hydra_core_channel_pkey PRIMARY KEY (id)
    )
    WITH
    (
        OIDS=FALSE
    )
;

-- vereenvoudigen geometrie hydroobjecten en ophalen gegevens
drop sequence if exists serial;
create sequence serial start 1;
drop table if exists tmp.hydroobject_sp
;
create table tmp.hydroobject_sp as
select
    nextval('serial') as serial
  , id
  , hydroobject_id
  , code
  , case
        when (
                hydroobject_id, code
            )
            is null
            then null
            else concat(hydroobject_id, '-', code)
    end as name
  , peilgebied_code
  , soortoppwaterkwantiteit
  , categorieoppwaterlichaam
  , ws_bodemhoogte
  , ws_talud_links
  , ws_talud_rechts
  , ws_bodembreedte
  , NULL::varchar(100) as tabulated_width 
  , NULL::varchar(100) as tabulated_height
  , bodemhoogtenap::numeric as derived_bed_level
  , breedte::numeric as width_at_waterlevel
  , round(diepte::numeric,2) as depth
  , taludvoorkeur::numeric
  , round(breedte::numeric - (diepte::numeric * taludvoorkeur::numeric),2)
            as bed_width 
  , geschikt_pro_id::int
  , st_transform(wkb_geometry, 4326) AS geom
from
    damo_ruw.hydroobject
;

-- invullen getabuleerde profiel wanneer gemeten profiel beschikbaar
UPDATE tmp.hydroobject_sp as ho
SET tabulated_width = tab.width,
    tabulated_height = tab.height
FROM tmp.tabulated_table as tab
WHERE ho.geschikt_pro_id = tab.pro_id
;

-- aanmaken getabuleerde profielen op basis van gegevens legger/FME
UPDATE tmp.hydroobject_sp
SET tabulated_width = array_to_string(ARRAY[bed_width,width_at_waterlevel],' ')
WHERE tabulated_width IS NULL
    AND bed_width IS NOT NULL
    AND width_at_waterlevel IS NOT NULL
;
UPDATE tmp.hydroobject_sp
SET tabulated_height = array_to_string(ARRAY[0,depth],' ')
WHERE tabulated_height IS NULL
    AND depth IS NOT NULL
;    


-- gebruik hydroobject_id als de originele object_id van de hydroobjecten --> deze tmp.hydroobject_sp zetten we om in nxt.channel format
alter table nxt.channel add column channel_type_id integer
;

alter table nxt.channel add column bed_width double precision 
;

alter table nxt.channel add column tabulated_width text
;

alter table nxt.channel add column tabulated_height text
;

alter table nxt.channel add column derived_bed_level double precision
;

alter table nxt.channel add column hydroobject_id integer
;

delete
from
    nxt.channel
;

insert into nxt.channel
    (id
      , CAST(hydroobject_id AS int)
      , created
      , code
      , channel_type_id
      , type
      , name
      , bed_level
      , talud_left
      , talud_right
      , bed_width
      , tabulated_width
      , tabulated_height
      , derived_bed_level
      , geometry
    )
select
    serial
  , hydroobject_id
  , now()
  , case
        when (
                peilgebied_code = ' '
            )
            IS NOT FALSE
            then 'LEEG'
            ELSE peilgebied_code
    END
  , -- code::varchar
    case
        when categorieoppwaterlichaam is null
            then 9999
            else categorieoppwaterlichaam
    end
  ,      -- channel_type_id::integer --> 1= primair, 2=secudair, 3=tertair
    case -- type::varchar
        when soortoppwaterkwantiteit is null
            then 'LEEG'
        when soortoppwaterkwantiteit = 6
            then 'Boezemwater'
        when soortoppwaterkwantiteit = 10
            then 'Hoofdwaterloop'
        when soortoppwaterkwantiteit = 22
            then 'Schouwsloot'
        when soortoppwaterkwantiteit = 37
            then 'Wegsloot'
        when soortoppwaterkwantiteit = 901
            then 'Boezemvaarweg'
        when soortoppwaterkwantiteit = 902
            then 'Poldervaarweg'
        when soortoppwaterkwantiteit = 903
            then 'Dijksloot HHNK'
        when soortoppwaterkwantiteit = 904
            then 'Dijksloot derden'
        when soortoppwaterkwantiteit = 905
            then 'Spoorsloot'
        when soortoppwaterkwantiteit = 906
            then 'Rijkswegsloot'
        when soortoppwaterkwantiteit = 907
            then 'Wegsloot derden'
        when soortoppwaterkwantiteit = 908
            then 'Wegsloot HHNK'
        when soortoppwaterkwantiteit = 909
            then 'Stedelijk HHNK'
        when soortoppwaterkwantiteit = 910
            then 'Stedelijk derden'
        when soortoppwaterkwantiteit = 911
            then 'Natuurwater'
        when soortoppwaterkwantiteit = 912
            then 'Schouwsloot breed'
        when soortoppwaterkwantiteit = 913
            then 'Schouwsloot HHNK'
        when soortoppwaterkwantiteit = 914
            then 'Waterberging HHNK'
        when soortoppwaterkwantiteit = 915
            then 'Overige'
            else 'LEEG'
    end
  , name
  , -- name::varchar --> objectid-code (van damo.hydroobject) wordt name (van nxt.channel) voor koppelen van tabellen
    ws_bodemhoogte
  , ws_talud_links
  , ws_talud_rechts
  , bed_width
  , tabulated_width
  , tabulated_height
  , derived_bed_level
  , st_force3d(geom)
from
    tmp.hydroobject_sp
;

-- van nxt.channel maken we tmp.channel_28992_sp
drop sequence if exists serial;
create sequence serial start 1;
drop table if exists tmp.channel_28992_sp
;

create table tmp.channel_28992_sp as
select
    nextval('serial') as serial
  , hydroobject_id::integer
  , id                                                                                                as nxt_channel_id
  , (st_dump(st_collect(st_transform(st_force2d(geometry), 28992)))).geom::geometry(Linestring,28992) AS geom
from
    nxt.channel
group by
    id
;

drop index if exists tmp.gw_pro_sp_index;
create index gw_pro_sp_index
on
    tmp.gw_pro_sp
using gist
    (
        geom
    )
;

cluster tmp.gw_pro_sp using gw_pro_sp_index;
drop index if exists tmp.channel_28992_sp_index;
create index channel_28992_sp_index
on
    tmp.channel_28992_sp
using gist
    (
        geom
    )
;

cluster tmp.channel_28992_sp using channel_28992_sp_index;
update
    tmp.tabulated_table a
set channel_id = b.nxt_channel_id
from
    tmp.channel_28992_sp b
  , tmp.gw_pro_sp        c
where
    a.pro_id = c.pro_id
    and st_crosses(b.geom, c.geom)
;

-- nu nog tmp.tabulated_table nog een point geometry geven (= kruising van hydroobject linestring en profiel linestring)
alter table tmp.tabulated_table add column geom geometry(Point,28992)
;

alter table tmp.tabulated_table add column numGeometries integer
;

alter table tmp.tabulated_table add column opmerking varchar
;

-- we willen de kruisen als point en niet als multipoint (daarom pakken we de 1-based nth geometrie in case of multpoint)
update
    tmp.tabulated_table a
set numGeometries = st_numgeometries(ST_Intersection(c.geom, b.geom))
  , geom          = st_geometryN(ST_Intersection(c.geom, b.geom),1)
  , opmerking     = 'koppel obv geom'
from
    tmp.channel_28992_sp b
  , tmp.gw_pro_sp        c
where
    a.channel_id is not null
    and a.channel_id       = b.nxt_channel_id
    and a.pro_id           = c.pro_id
; -- 21 sec
alter table tmp.tabulated_table add column ovk_id integer
;

update
    tmp.tabulated_table a
set ovk_id = b.ovk_ovk_id
from
    tmp.gw_pro_sp b
where
    a.pro_id = b.pro_id
;

update
    tmp.tabulated_table a
set channel_id = b.nxt_channel_id
  , opmerking  = 'koppel obv ovk_id en hydrobjectid_ori'
from
    tmp.channel_28992_sp b
where
    a.ovk_id               = b.hydroobject_id
    and a.channel_id is null
    and a.ovk_id is not null --TODO
;

update
    tmp.tabulated_table a
set numGeometries = 1
  , geom          = ST_LineInterpolatePoint(b.geom, 0.5)
  , opmerking     = '>1 pro_ids per hydroobject obv code wordt 1 profielpunt'
from
    tmp.channel_28992_sp b
where
    a.ovk_id = b.hydroobject_id
    and a.pro_id in
    (
        select distinct
        on
            (
                channel_id
            )
            pro_id
        from
            tmp.tabulated_table
        where
            opmerking like 'koppel obv ovk_id en hydrobjectid_ori'
    )
;

update
    tmp.tabulated_table
set opmerking = 'dit hydroobject heeft al een profiel obv code'
where
    geom       is null
    and opmerking like 'koppel obv ovk_id en hydrobjectid_ori'
;

update
    tmp.tabulated_table
set opmerking = 'koppel niet mogelijk obv geom of code'
where
    opmerking is null
;

drop table if exists tmp.tabulated_table_backup
;

create table tmp.tabulated_table_backup as
select *
from
    tmp.tabulated_table
;

drop table if exists tmp.tabulated_table_backup_not_duplicate
;

create table tmp.tabulated_table_backup_not_duplicate as
select distinct
on
    (
        geom
    )
    *
from
    tmp.tabulated_table_backup
;

-- de overgebleven selecteren als duplicate
drop table if exists tmp.tabulated_table_backup_duplicate
;

create table tmp.tabulated_table_backup_duplicate as
select *
from
    tmp.tabulated_table_backup
where
    pro_id not in
    (
        select
            pro_id
        from
            tmp.tabulated_table_backup_not_duplicate
    )
;

drop table if exists tmp.tabulated_table_backup
;

create table tmp.tabulated_table_backup as
select *
from
    tmp.tabulated_table_backup_not_duplicate
;

update
    tmp.tabulated_table_backup
set opmerking = concat_ws(',','not_duplicate',opmerking)
;

insert into tmp.tabulated_table_backup
    (defname
      , prw_id
      , width
      , height
      , max_height
      , max_width
      , min
      , max
      , nr_input_points
      , channel_id
      , pro_id
      , geom
      , numgeometries
      , opmerking
      , ovk_id
    )
select
    defname
  , prw_id
  , width
  , height
  , max_height
  , max_width
  , min
  , max
  , nr_input_points
  , channel_id
  , pro_id
  , geom
  , numgeometries
  , concat_ws(',','duplicate',opmerking)
  , ovk_id
from
    tmp.tabulated_table_backup_duplicate
;

update
    tmp.tabulated_table_backup
set opmerking = 'dit hydroobject heeft al een profiel obv code'
where
    opmerking = 'duplicate,dit hydroobject heeft al een profiel obv code'
;

update
    tmp.tabulated_table_backup
set opmerking = 'koppel niet mogelijk obv geom of code'
where
    opmerking = 'duplicate,koppel niet mogelijk obv geom of code'
;

update
    tmp.tabulated_table_backup
set opmerking = 'dit hydroobject heeft al een profiel obv code'
where
    opmerking = 'not_duplicate,dit hydroobject heeft al een profiel obv code'
;

drop table if exists tmp.tabulated_table
;

create table tmp.tabulated_table as
select *
from
    tmp.tabulated_table_backup
;

drop table if exists tmp.tabulated_table_backup
;

drop table if exists tmp.tabulated_table_backup_not_duplicate
;

drop table if exists tmp.tabulated_table_backup_duplicate
;

drop table if exists tmp.tabulated_table_not_duplicate
;

drop table if exists tmp.tabulated_table_duplicate
;