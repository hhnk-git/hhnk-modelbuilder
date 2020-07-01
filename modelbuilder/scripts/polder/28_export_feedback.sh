#!/bin/bash
# De feedbacktabel uit stap 25 wordt geëxporteerd naar een shapefile.  
# De misfits uit stap 5 worden geëxporteerd naar een shapefile 
# Logfiles worden weggeschreven 

rm -rf /code/data/output/models/feedback/
mkdir /code/data/output/models/feedback/
ogr2ogr -overwrite -sql "SELECT * FROM deelgebied.feedback" -nln feedback -f "ESRI Shapefile" /code/data/output/models/feedback/model_feedback.shp PG:"host=db user=postgres dbname=datachecker port=5432 password=postgres" -nlt Point -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM feedback.misfits WHERE ST_GeometryType(geom) LIKE 'ST_Point'" -nln misfit_points -f "ESRI Shapefile" /code/data/output/models/feedback/misfit_points.shp PG:"host=db user=postgres dbname=datachecker port=5432 password=postgres" -nlt Point -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM feedback.misfits WHERE ST_GeometryType(geom) LIKE 'ST_LineString'" -nln misfit_lines -f "ESRI Shapefile" /code/data/output/models/feedback/misfit_lines.shp PG:"host=db user=postgres dbname=datachecker port=5432 password=postgres" -nlt LineString -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM feedback.channel_surface_from_profiles" -nln channel_surface_from_profiles -f "ESRI Shapefile" /code/data/output/models/feedback/channel_surface_from_profiles.shp PG:"host=db user=postgres dbname=datachecker port=5432 password=postgres" -nlt Polygon -a_srs EPSG:28992
#rm -r ./logging/modelbuilder_logfiles/
#mkdir ./logging/modelbuilder_logfiles/
#cp ./logging/modelbuilder_logging.txt ./logging/modelbuilder_logfiles/modelbuilder_general.log
#cp ./logging/logging_02_copy_data.sh.txt ./logging/modelbuilder_logfiles/01_copy_database.log
#cp ./logging/logging_04a_snap_geometries.sh.txt ./logging/modelbuilder_logfiles/02_snap_geometries.log
#cp ./logging/logging_04c_fix_channels.sh.txt ./logging/modelbuilder_logfiles/03_clip_and_linify.log
#cp ./logging/logging_04e_clip_and_linify.sh.txt ./logging/modelbuilder_logfiles/04_clip_and_linify.log
#cp ./logging/logging_22_voorbereiden_rasters_threedi_turtle.sh.txt ./logging/modelbuilder_logfiles/05_prepare_rasters.log
#cp ./logging/logging_23_create_raster.sh.txt ./logging/modelbuilder_logfiles/06_create_rasters.log
#cp ./logging/logging_24_export_and_run_model.sh.txt ./logging/modelbuilder_logfiles/07_create_and_run_model.log
#rm ./models/bwn_${2}_1d2d_test/preprocessed/grid_data*
#cp -r ./models/bwn_${2}_1d2d_test/preprocessed/ ./models/feedback/