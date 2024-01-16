rem bestanden voor modelbulder feedback worden nu weggeschreven
rmdir /s /q \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\
mkdir \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data
mkdir \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\modelbuilder_output
mkdir \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\peilgebieden
ogr2ogr -overwrite -sql "SELECT * FROM deelgebied.feedback" -nln feedback -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\modelbuilder_output\model_feedback.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt Point -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM feedback.misfits WHERE ST_GeometryType(geom) LIKE 'ST_Point'" -nln misfit_points -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\modelbuilder_output\misfit_points.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt Point -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM feedback.misfits WHERE ST_GeometryType(geom) LIKE 'ST_LineString'" -nln misfit_lines -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\modelbuilder_output\misfit_lines.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt LineString -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM tmp.v2_culvert_to_orifice" -nln culvert_to_orifice -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\modelbuilder_output\culvert_to_orifice.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt LineString -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM feedback.channel_surface_from_profiles" -nln channel_surface_from_profiles -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\modelbuilder_output\channel_surface_from_profiles.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt Polygon -a_srs EPSG:28992
rem ogr2ogr -overwrite -sql "SELECT * FROM deelgebied.voronoi_output" -nln voronoi_output -f "ESRI Shapefile" \code\data\output\models\feedback\voronoi_output.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt MultiPolygon -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM deelgebied.impervious_surface_simple" -nln impervious_surface_simple -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\modelbuilder_output\impervious_surface_simple.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt MultiPoint -a_srs EPSG:28992

rem Export and copy files for source data
ogr2ogr -overwrite -sql "SELECT * FROM deelgebied.polder" -nln polder_polygon -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\polder_polygon.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -a_srs EPSG:28992

ogr2ogr -clipsrc -f gpkg \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\polder_polygon.shp \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\datachecker_output.gpkg \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\datachecker_output.gpkg -nlt PROMOTE_TO_MULTI

ogr2ogr -clipsrc \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\polder_polygon.shp -overwrite -sql "SELECT * FROM deelgebied.fixeddrainagelevelarea" -nln peilgebieden -f "ESRI Shapefile" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\peilgebieden\peilgebieden.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -a_srs EPSG:28992
copy \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\input\DAMO.gpkg \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\DAMO.gpkg
copy \\corp.hhnk.nl\data\Hydrologen_data\01.basisgegevens\00.HDB\Hydro_database.gpkg \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\01_source_data\HDB.gpkg

rem rm -r ./logging/modelbuilder_logfiles/
rem mkdir ./logging/modelbuilder_logfiles/
rem cp ./logging/modelbuilder_logging.txt ./logging/modelbuilder_logfiles/modelbuilder_general.log
rem cp ./logging/logging_02_copy_data.sh.txt ./logging/modelbuilder_logfiles/01_copy_database.log
rem cp ./logging/logging_04a_snap_geometries.sh.txt ./logging/modelbuilder_logfiles/02_snap_geometries.log
rem cp ./logging/logging_04c_fix_channels.sh.txt ./logging/modelbuilder_logfiles/03_clip_and_linify.log
rem cp ./logging/logging_04e_clip_and_linify.sh.txt ./logging/modelbuilder_logfiles/04_clip_and_linify.log
rem cp ./logging/logging_22_voorbereiden_rasters_threedi_turtle.sh.txt ./logging/modelbuilder_logfiles/05_prepare_rasters.log
rem cp ./logging/logging_23_create_raster.sh.txt ./logging/modelbuilder_logfiles/06_create_rasters.log
rem cp ./logging/logging_24_export_and_run_model.sh.txt ./logging/modelbuilder_logfiles/07_create_and_run_model.log
rem rm ./models/bwn_${2}_1d2d_test/preprocessed/grid_data*
rem cp -r ./models/bwn_${2}_1d2d_test/preprocessed/ ./models/feedback/



rem The -spat parameter in ogr2ogr https://gdal.org/programs/ogr2ogr.html#ogr2ogr affects all available layers. This selects data withing the given rectangle from all layers if you write only the name of the datasource into the command but not the layername. So just "...input.gpkg" instead of "...input.gpkg selected_layer".

rem ogr2ogr -f gpkg -spat 100000 6000000 101000 6001000 subset.gpkg input.gpkg
rem Various clip options should work as well for all the layers. The -sql option would require writing names of all the tables explicitly into the SQL statement (FROM and also into WHERE) and that would not be nice.
