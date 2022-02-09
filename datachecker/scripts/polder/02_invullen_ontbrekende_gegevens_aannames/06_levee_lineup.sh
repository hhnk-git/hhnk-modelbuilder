#!/bin/bash
rm -rf /code/data/line-up
mkdir /code/data/line-up
echo "Exporting levees for line-up tool"
ogr2ogr -overwrite -sql "SELECT * FROM tmp.levee_split" -f "ESRI Shapefile" /code/data/line-up/levee_split.shp PG:"host=db user=postgres dbname=datachecker password=postgres port=5432"
echo "Executing line-up tool"
line-up /code/data/fixed_data/DEM/DEM_AHN4_int.vrt /code/data/line-up/levee_split.shp /code/data/line-up/levee_height.shp -d 6 -w 2 -a 75 -l line -f lineupid -e height
echo "Importing line-up tool result"
ogr2ogr -f "PostgreSQL" PG:"host=db user=postgres dbname=datachecker password=postgres port=5432" -lco "SCHEMA=tmp" -lco "FID=objectid" -nlt LINESTRING -lco "OVERWRITE=YES" -a_srs EPSG:28992 -progress -overwrite /code/data/line-up/levee_height.shp