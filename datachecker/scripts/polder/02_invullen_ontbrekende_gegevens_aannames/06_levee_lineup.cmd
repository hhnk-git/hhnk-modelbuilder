set "DATA_ROOT=%~1"

rmdir /s /q "%DATA_ROOT%\line-up"
mkdir "%DATA_ROOT%\line-up"
echo "Exporting levees for line-up tool"
ogr2ogr -overwrite -sql "SELECT * FROM tmp.levee_split" -f "ESRI Shapefile" "%DATA_ROOT%\line-up\levee_split.shp" PG:"host=localhost user=postgres dbname=datachecker password=postgres port=5433" -skipfailures
echo "Executing line-up tool"
%CONDA_PREFIX%\python.exe D:\modelbuilder\code\raster-tools\line_up.py "\\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\rasters\DEM\DEM_AHN4_int.vrt" "%DATA_ROOT%\line-up\levee_split.shp" "%DATA_ROOT%\line-up\levee_height.shp" -o -d 6 -w 2 -a 75 -l line -f lineupid -e height
echo "Importing line-up tool result"
ogr2ogr -f "PostgreSQL" PG:"host=localhost user=postgres dbname=datachecker password=postgres port=5433" -lco "SCHEMA=tmp" -lco "FID=objectid" -nlt LINESTRING -a_srs EPSG:28992 -progress -lco "OVERWRITE=YES" "%DATA_ROOT%\line-up\levee_height.shp" 
