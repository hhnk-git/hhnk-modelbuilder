#!/bin/bash
echo "Loading datamining AHN3 data"
ogr2ogr -f "PostgreSQL" PG:"host=db user=postgres dbname=datachecker password=postgres port=5432" -lco "GEOMETRY_NAME=wkb_geometry" -lco "SCHEMA=fixed_data" -lco "FID=objectid" -nlt MULTIPOLYGON -lco "OVERWRITE=YES" -progress /code/data/fixed_data/datamining_ahn3/datamining_ahn3.shp
echo "Loading connection CODE/HydrObject"
ogr2ogr -f "PostgreSQL" PG:"host=db user=postgres dbname=datachecker password=postgres port=5432" -lco "GEOMETRY_NAME=wkb_geometry" -lco "SCHEMA=fixed_data" -lco "OVERWRITE=YES" -progress /code/data/fixed_data/hydroobjectid/CODE_HydroObject_OBJECTID.dbf
echo "Loading DAMO data"
ogr2ogr -f "PostgreSQL" PG:"host=db user=postgres dbname=datachecker password=postgres port=5432" -nlt CONVERT_TO_LINEAR -lco "GEOMETRY_NAME=wkb_geometry" -lco "SCHEMA=damo_ruw" -lco "FID=objectid" -lco "OVERWRITE=YES" -progress /code/data/input/DAMO.gdb --config PG_USE_COPY YES -skipfailures -gt 1000
echo "Loading HDB data"
ogr2ogr -f "PostgreSQL" PG:"host=db user=postgres dbname=datachecker password=postgres port=5432" -nlt CONVERT_TO_LINEAR -lco "GEOMETRY_NAME=wkb_geometry" -lco "SCHEMA=hdb" -lco "FID=objectid" -lco "OVERWRITE=YES" -progress /code/data/input/HDB.gdb