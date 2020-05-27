#!/bin/bash
mkdir /code/data/lineup
rm ./tmp_data/levee_height.dbf
rm ./tmp_data/levee_height.prj
rm ./tmp_data/levee_height.shp
rm ./tmp_data/levee_height.shx
echo "Exporting levees for line-up tool"
ogr2ogr -overwrite -sql "SELECT * FROM tmp.levee_split" -f "ESRI Shapefile" ./tmp_data/levee_split.shp PG:"host=db user=postgres dbname=datachecker password=postgres port=5432"
#echo "Executing line-up tool"
#/opt/raster-tools/bin/line-up ./fixed_data/ahn3_raster/hhnk_ahn3_2x2.tif ./tmp_data/levee_split.shp ./tmp_data/levee_height.shp -d 6 -w 2 -a 75 -l line -f lineupid -e height
#echo "Importing line-up tool result"
#ogr2ogr -f "PostgreSQL" PG:"host=db user=postgres dbname=datachecker password=postgres port=5432" -lco "SCHEMA=tmp" -lco "FID=objectid" -nlt LINESTRING -lco "OVERWRITE=YES" -a_srs EPSG:28992 -progress -overwrite ./tmp_data/levee_height.shp
#rm -r /code/data/lineup