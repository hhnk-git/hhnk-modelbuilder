#!/bin/bash
# Bereidt de mappenstructuur voor het aanmaken van de rasters voor. Exporteer de polder en de uitgeknipte 
# watervlakken als shapefiles en veraster de watervlakken om deze later dicht te smeren. 
# Bepaalt de pixelgrootte afhankelijk van de omvang van de rasters
rm /code/tmp/rasters -rf
mkdir /code/tmp/rasters/tmp -p
echo INFO maak shapefile van deelgebied.polder
ogr2ogr -overwrite -sql "SELECT polder_id, name, polder_type, ST_SetSRID(ST_Buffer(geom,0),28992) as geom FROM deelgebied.polder" -f "ESRI Shapefile" /code/tmp/rasters/tmp/polder.shp PG:"host=db user=postgres dbname=datachecker password=postgres port=5433"
echo INFO maak shapefile van deelgebied.channelsurfacedem
ogr2ogr -overwrite -sql "SELECT ST_SetSRID(ST_CollectionExtract(geom,3),28992) as geom, id FROM deelgebied.channelsurfacedem" -f "ESRI Shapefile" /code/tmp/rasters/tmp/channelsurface.shp PG:"host=db user=postgres dbname=datachecker password=postgres port=5433"
