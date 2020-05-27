#!/bin/bash
rm ./tmp_data -r
mkdir ./tmp_data
mkdir ./tmp_data/rasters
mkdir ./tmp_data/rasters/tmp
echo INFO maak shapefile van deelgebied.polder
ogr2ogr -overwrite -sql "SELECT polder_id, name, polder_type, ST_SetSRID(geom,28992) as geom FROM deelgebied.polder" -f "ESRI Shapefile" ./tmp_data/rasters/tmp/polder.shp PG:"host=localhost user=postgres dbname=work_modelbuilder password=v00rd3ur port=5432"
echo INFO maak shapefile van deelgebied.channelsurface
ogr2ogr -overwrite -sql "SELECT ST_SetSRID(ST_CollectionExtract(geom,3),28992) as geom, height FROM deelgebied.channelsurface" -f "ESRI Shapefile" ./tmp_data/rasters/tmp/channelsurface.shp PG:"host=localhost user=postgres dbname=work_modelbuilder password=v00rd3ur port=5432"
echo INFO rasterize shapefile deelgebied.channelsurface, gebruik 'height' attribuut
gdal_rasterize -a_nodata -9999 -a_srs EPSG:28992 -co "COMPRESS=DEFLATE" -tr 0.5 0.5  -a height -l channelsurface ./tmp_data/rasters/tmp/channelsurface.shp ./tmp_data/rasters/tmp/channelsurface.tif
PS=$(python ./python_scripts/999_pixelsize.py "./tmp_data/rasters/tmp/channelsurface.tif")
echo $PS