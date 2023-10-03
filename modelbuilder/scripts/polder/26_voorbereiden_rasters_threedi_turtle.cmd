rmdir /s /q \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters
mkdir \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp
echo INFO maak shapefile van deelgebied.polder
ogr2ogr -overwrite -sql "SELECT polder_id, name, polder_type, ST_SetSRID(ST_Buffer(geom,0),28992) as geom FROM deelgebied.polder" -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\polder.shp PG:"host=localhost user=postgres dbname=datachecker password=postgres port=5433"
echo INFO maak shapefile van deelgebied.channelsurfacedem
ogr2ogr -overwrite -sql "SELECT ST_SetSRID(ST_CollectionExtract(geom,3),28992) as geom, id FROM deelgebied.channelsurfacedem" -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\channelsurface.shp PG:"host=localhost user=postgres dbname=datachecker password=postgres port=5433"
