#!/bin/bash
# De DEM wordt uitgeknipt uit de gebiedsdekkende DEM, de verrasterde watervlakken worden gebruikt om de DEM 
# dicht te smeren. 
# Een masker wordt gemaakt van de DEM om data/nodata pixels te onderscheiden. Gebiedsdekkende bodemberging 
# (ghg, glg, ggg), frictie en infiltratie raster worden op dit masker geprojecteerd en gecomprimeerd. 
# Rasters staat nu vast op 0.5 meter resolutie. 

#PS=$(python3 /code/modelbuilder/pixelsize.py "/code/tmp/rasters/tmp/channelsurface.tif")
#echo $PS
#PS=0.5

echo INFO knip dem uit ahn met resolutie 0.5 m
gdalwarp -cutline /code/tmp/rasters/tmp/polder.shp -tr 0.5 0.5 -tap -crop_to_cutline -srcnodata -9999 -dstnodata -9999 -co "COMPRESS=DEFLATE" /code/data/fixed_data/DEM/DEM_AHN4_int.vrt /code/tmp/rasters/tmp/raw_dem_clipped.tif

echo INFO rasterize shapefile deelgebied.channelsurfacedem
gdal_rasterize -a_nodata -9999 -a_srs EPSG:28992 -co "COMPRESS=DEFLATE" -tr 0.5 0.5  -burn 10.0 -l channelsurface /code/tmp/rasters/tmp/channelsurface.shp /code/tmp/rasters/tmp/channelsurface.tif

echo INFO smeer watergangen dicht en comprimeer
gdalwarp -ot Float32 -dstnodata -9999 -tr 0.5 0.5 -tap /code/tmp/rasters/tmp/raw_dem_clipped.tif /code/tmp/rasters/tmp/channelsurface.tif -ot Float32 -co "COMPRESS=DEFLATE" /code/tmp/rasters/dem_$2.tif

echo INFO Knip bodemberging, frictie en infiltratie uit gebiedsbrede rasters
echo -----------------------------------
echo INFO maak raster met enen voor extent
gdal_calc.py  --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A /code/tmp/rasters/dem_$2.tif --outfile /code/tmp/rasters/tmp/enenraster_ongec.tif --calc="1" --quiet

echo INFO maak rasters om te vullen
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A /code/tmp/rasters/dem_$2.tif --outfile /code/tmp/rasters/tmp/vulrasternul.tif --calc="0" --quiet
cp /code/tmp/rasters/tmp/vulrasternul.tif /code/tmp/rasters/tmp/vulraster_infiltration.tif 
cp /code/tmp/rasters/tmp/vulrasternul.tif /code/tmp/rasters/tmp/vulraster_berging.tif 

echo INFO plak eenmalig bodemberging verhard in het vulraster
gdalwarp /code/data/fixed_data/other/bodemberging_verhard_hhnk.tif /code/tmp/rasters/tmp/vulraster_berging.tif 

echo INFO maak drie vulrasters voor de berging
cp /code/tmp/rasters/tmp/vulraster_berging.tif /code/tmp/rasters/tmp/vulraster_ghg_ongec.tif 
cp /code/tmp/rasters/tmp/vulraster_berging.tif /code/tmp/rasters/tmp/vulraster_glg_ongec.tif 
cp /code/tmp/rasters/tmp/vulraster_berging.tif /code/tmp/rasters/tmp/vulraster_ggg_ongec.tif 
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A /code/tmp/rasters/dem_$2.tif --outfile /code/tmp/rasters/tmp/vulraster_friction.tif --calc="0.2" --quiet

echo INFO plak de waarden voor bodemberging in de vulrasters
gdalwarp /code/data/fixed_data/other/bodemberging_hhnk_ghg_m.tif /code/tmp/rasters/tmp/vulraster_ghg_ongec.tif
gdalwarp /code/data/fixed_data/other/bodemberging_hhnk_ggg_m.tif /code/tmp/rasters/tmp/vulraster_ggg_ongec.tif
gdalwarp /code/data/fixed_data/other/bodemberging_hhnk_glg_m.tif /code/tmp/rasters/tmp/vulraster_glg_ongec.tif

echo INFO vul rasters voor infiltratie en frictie
gdalwarp /code/data/fixed_data/other/friction_hhnk_2021.tif /code/tmp/rasters/tmp/vulraster_friction.tif
gdalwarp /code/data/fixed_data/other/infiltratie_hhnk.tif /code/tmp/rasters/tmp/vulraster_infiltration.tif

echo INFO pas extent toe op gevulde rasters
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A /code/tmp/rasters/tmp/enenraster_ongec.tif -B /code/tmp/rasters/tmp/vulraster_ghg_ongec.tif --outfile /code/tmp/rasters/storage_ghg_$2.tif --calc="A*B" --quiet
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A /code/tmp/rasters/tmp/enenraster_ongec.tif -B /code/tmp/rasters/tmp/vulraster_ggg_ongec.tif --outfile /code/tmp/rasters/storage_ggg_$2.tif --calc="A*B" --quiet
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A /code/tmp/rasters/tmp/enenraster_ongec.tif -B /code/tmp/rasters/tmp/vulraster_glg_ongec.tif --outfile /code/tmp/rasters/storage_glg_$2.tif --calc="A*B" --quiet
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A /code/tmp/rasters/tmp/enenraster_ongec.tif -B /code/tmp/rasters/tmp/vulraster_friction.tif --outfile /code/tmp/rasters/friction_$2.tif --calc="A*B" --quiet
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A /code/tmp/rasters/tmp/enenraster_ongec.tif -B /code/tmp/rasters/tmp/vulraster_infiltration.tif --outfile /code/tmp/rasters/infiltration_$2.tif --calc="A*B" --quiet

# echo INFO comprimeer eindresultaat
# gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_ghg_ongec_ext.tif /code/tmp/rasters/storage_ghg_$2.tif
# gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_ggg_ongec_ext.tif /code/tmp/rasters/storage_ggg_$2.tif
# gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_glg_ongec_ext.tif /code/tmp/rasters/storage_glg_$2.tif
# gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_friction_ext.tif /code/tmp/rasters/friction_$2.tif
# gdal_translate -co "COMPRESS=DEFLATE" /code/tmp/rasters/tmp/vulraster_infiltration_ext.tif /code/tmp/rasters/infiltration_$2.tif

# echo INFO verwijder tijdelijke bestanden
rm /code/tmp/rasters/tmp -rf
cp -r /code/tmp/rasters/ /code/data/output/models/rasters
rm /code/tmp -rf
echo Klaar tmp_data