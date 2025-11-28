set "DATA_ROOT=%~1"

echo "Loading DAMO data @ %DATA_ROOT%\input\DAMO.gpkg
ogr2ogr -f "PostgreSQL" PG:"host=localhost user=postgres dbname=datachecker password=postgres port=5433" -nlt CONVERT_TO_LINEAR -lco "GEOMETRY_NAME=wkb_geometry" -lco "SCHEMA=damo_ruw" -lco "FID=id" -lco "OVERWRITE=YES" "%DATA_ROOT%\input\DAMO.gpkg" --config PG_USE_COPY YES -gt 1000
echo "Loading HDB data @ \\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\00.HDB\Hydro_database.gpkg
ogr2ogr -f "PostgreSQL" PG:"host=localhost user=postgres dbname=datachecker password=postgres port=5433" -nlt CONVERT_TO_LINEAR -lco "GEOMETRY_NAME=wkb_geometry" -lco "SCHEMA=hdb" -lco "FID=id" -lco "OVERWRITE=YES" "\\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\00.HDB\Hydro_database.gpkg"
