echo bestanden voor modelbulder feedback worden nu weggeschreven
mkdir %3\data\output\01_source_data\modelbuilder_output
mkdir %3\data\output\01_source_data\peilgebieden
ogr2ogr -overwrite -sql "SELECT * FROM deelgebied.feedback" -nln feedback -f "ESRI Shapefile" %3\data\output\01_source_data\modelbuilder_output\model_feedback.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt Point -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM feedback.misfits WHERE ST_GeometryType(geom) LIKE 'ST_Point'" -nln misfit_points -f "ESRI Shapefile" %3\data\output\01_source_data\modelbuilder_output\misfit_points.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt Point -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM feedback.misfits WHERE ST_GeometryType(geom) LIKE 'ST_LineString'" -nln misfit_lines -f "ESRI Shapefile" %3\data\output\01_source_data\modelbuilder_output\misfit_lines.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt LineString -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM tmp.v2_culvert_to_orifice" -nln culvert_to_orifice -f "ESRI Shapefile" %3\data\output\01_source_data\modelbuilder_output\culvert_to_orifice.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt LineString -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM feedback.channel_surface_from_profiles" -nln channel_surface_from_profiles -f "ESRI Shapefile" %3\data\output\01_source_data\modelbuilder_output\channel_surface_from_profiles.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt Polygon -a_srs EPSG:28992
rem ogr2ogr -overwrite -sql "SELECT * FROM deelgebied.voronoi_output" -nln voronoi_output -f "ESRI Shapefile" \code\data\output\models\feedback\voronoi_output.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt MultiPolygon -a_srs EPSG:28992
ogr2ogr -overwrite -sql "SELECT * FROM deelgebied.impervious_surface_simple" -nln impervious_surface_simple -f "ESRI Shapefile" %3\data\output\01_source_data\modelbuilder_output\impervious_surface_simple.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -nlt MultiPoint -a_srs EPSG:28992

echo Export and copy files for source data
ogr2ogr -overwrite -sql "SELECT * FROM deelgebied.polder" -nln polder_polygon -f "ESRI Shapefile" %3\data\output\01_source_data\polder_polygon.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -a_srs EPSG:28992

ogr2ogr -clipsrc -f gpkg %3\data\output\01_source_data\polder_polygon.shp %3\data\output\datachecker_output.gpkg %3\data\output\01_source_data\datachecker_output.gpkg -nlt PROMOTE_TO_MULTI

ogr2ogr -clipsrc %3\data\output\01_source_data\polder_polygon.shp -overwrite -sql "SELECT * FROM deelgebied.fixeddrainagelevelarea" -nln peilgebieden -f "ESRI Shapefile" %3\data\output\01_source_data\peilgebieden\peilgebieden.shp PG:"host=localhost user=postgres dbname=datachecker port=5433 password=postgres" -a_srs EPSG:28992
