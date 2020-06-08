#!/bin/bash
rm /code/data/rasters -rf
mkdir /code/data/rasters
mkdir /code/data/rasters/tmp
echo INFO maak shapefile van deelgebied.polder
ogr2ogr -overwrite -sql "SELECT polder_id, name, polder_type, ST_SetSRID(geom,28992) as geom FROM deelgebied.polder" -f "ESRI Shapefile" /code/data/rasters/tmp/polder.shp PG:"host=db user=postgres dbname=datachecker password=postgres port=5432"
echo INFO maak shapefile van deelgebied.channelsurface
ogr2ogr -overwrite -sql "SELECT ST_SetSRID(ST_CollectionExtract(geom,3),28992) as geom, height FROM deelgebied.channelsurface" -f "ESRI Shapefile" /code/data/rasters/tmp/channelsurface.shp PG:"host=db user=postgres dbname=datachecker password=postgres port=5432"
echo INFO rasterize shapefile deelgebied.channelsurface, gebruik 'height' attribuut
gdal_rasterize -a_nodata -9999 -a_srs EPSG:28992 -co "COMPRESS=DEFLATE" -tr 0.5 0.5  -a height -l channelsurface /code/data/rasters/tmp/channelsurface.shp /code/data/rasters/tmp/channelsurface.tif
PS=$(python /code/modelbuilder/pixelsize.py "/code/data/rasters/tmp/channelsurface.tif")
echo $PS