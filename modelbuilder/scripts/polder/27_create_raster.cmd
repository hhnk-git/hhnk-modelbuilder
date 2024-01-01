rem De DEM wordt uitgeknipt uit de gebiedsdekkende DEM, de verrasterde watervlakken worden gebruikt om de DEM 
rem dicht te smeren. 
rem Een masker wordt gemaakt van de DEM om data/nodata pixels te onderscheiden. Gebiedsdekkende bodemberging 
rem (ghg, glg, ggg), frictie en infiltratie raster worden op dit masker geprojecteerd en gecomprimeerd. 
rem Rasters staat nu vast op 0.5 meter resolutie. 

rem PS=$(python3 /code/modelbuilder/pixelsize.py "/code/tmp/rasters/tmp/channelsurface.tif")
rem echo $PS
rem PS=0.5

echo INFO knip dem uit ahn met resolutie 0.5 m
gdalwarp -cutline \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\polder.shp -tr 0.5 0.5 -tap -crop_to_cutline -srcnodata -9999 -dstnodata -9999 -co "COMPRESS=DEFLATE" "\\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\rasters\DEM\DEM_AHN4_int.vrt" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\raw_dem_clipped.tif

echo INFO rasterize shapefile deelgebied.channelsurfacedem
gdal_rasterize -a_nodata -9999 -a_srs EPSG:28992 -co "COMPRESS=DEFLATE" -tr 0.5 0.5  -burn 10.0 -l channelsurface \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\channelsurface.shp \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\channelsurface.tif

echo INFO smeer watergangen dicht en comprimeer
gdalwarp -ot Float32 -dstnodata -9999 -tr 0.5 0.5 -tap \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\raw_dem_clipped.tif \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\channelsurface.tif -ot Float32 -co "COMPRESS=DEFLATE" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\dem_%2.tif

echo INFO Knip bodemberging, frictie en infiltratie uit gebiedsbrede rasters
echo -----------------------------------
echo INFO maak raster met enen voor extent
%CONDA_PREFIX%\python.exe %CONDA_PREFIX%\Scripts\gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\dem_%2.tif --outfile \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\enenraster_ongec.tif --calc="1" --quiet

echo INFO maak rasters om te vullen
%CONDA_PREFIX%\python.exe %CONDA_PREFIX%\Scripts\gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\dem_%2.tif --outfile \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulrasternul.tif --calc="0" --quiet

copy \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulrasternul.tif \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_infiltration.tif 
copy \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulrasternul.tif \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_berging.tif 

echo INFO plak eenmalig bodemberging verhard in het vulraster
gdalwarp "\\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\rasters\bodemberging\bodemberging_verhard_hhnk.tif" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_berging.tif 

echo INFO maak drie vulrasters voor de berging
copy \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_berging.tif \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_ghg_ongec.tif 
copy \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_berging.tif \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_glg_ongec.tif 
copy \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_berging.tif \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_ggg_ongec.tif 
%CONDA_PREFIX%\python.exe %CONDA_PREFIX%\Scripts\gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\dem_%2.tif --outfile \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_friction.tif --calc="0.2" --quiet

echo INFO plak de waarden voor bodemberging in de vulrasters
gdalwarp "\\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\rasters\bodemberging\bodemberging_hhnk_ghg_m.tif" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_ghg_ongec.tif
gdalwarp "\\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\rasters\bodemberging\bodemberging_hhnk_ggg_m.tif" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_ggg_ongec.tif
gdalwarp "\\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\rasters\bodemberging\bodemberging_hhnk_glg_m.tif" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_glg_ongec.tif

echo INFO vul rasters voor infiltratie en frictie
gdalwarp "\\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\rasters\weerstand\friction_hhnk_2021.tif" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_friction.tif
gdalwarp "\\corp.hhnk.nl\data\Hydrologen_data\Data\01.basisgegevens\rasters\infiltratie\infiltratie_hhnk.tif" \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_infiltration.tif

echo INFO pas extent toe op gevulde rasters
%CONDA_PREFIX%\python.exe %CONDA_PREFIX%\Scripts\gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\enenraster_ongec.tif -B \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_ghg_ongec.tif --outfile \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\storage_ghg_%2.tif --calc="A*B" --quiet
%CONDA_PREFIX%\python.exe %CONDA_PREFIX%\Scripts\gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\enenraster_ongec.tif -B \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_ggg_ongec.tif --outfile \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\storage_ggg_%2.tif --calc="A*B" --quiet
%CONDA_PREFIX%\python.exe %CONDA_PREFIX%\Scripts\gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\enenraster_ongec.tif -B \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_glg_ongec.tif --outfile \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\storage_glg_%2.tif --calc="A*B" --quiet
%CONDA_PREFIX%\python.exe %CONDA_PREFIX%\Scripts\gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\enenraster_ongec.tif -B \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_friction.tif --outfile \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\friction_%2.tif --calc="A*B" --quiet
%CONDA_PREFIX%\python.exe %CONDA_PREFIX%\Scripts\gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\enenraster_ongec.tif -B \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\tmp\vulraster_infiltration.tif --outfile \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters\infiltration_%2.tif --calc="A*B" --quiet

rem echo INFO comprimeer eindresultaat
rem gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_ghg_ongec_ext.tif /code/tmp/rasters/storage_ghg_%2.tif
rem gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_ggg_ongec_ext.tif /code/tmp/rasters/storage_ggg_%2.tif
rem gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_glg_ongec_ext.tif /code/tmp/rasters/storage_glg_%2.tif
rem gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_friction_ext.tif /code/tmp/rasters/friction_%2.tif
rem gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_infiltration_ext.tif /code/tmp/rasters/infiltration_%2.tif

echo INFO verwijder tijdelijke bestanden
rmdir /s /q .\code\tmp\rasters\tmp
xcopy /E /I /Y \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\rasters \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\models\rasters
rmdir /s /q .\code\tmp
echo Klaar tmp_data