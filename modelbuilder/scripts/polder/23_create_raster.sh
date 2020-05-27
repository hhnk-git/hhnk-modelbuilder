#!/bin/bash
PS=$(python ./python_scripts/999_pixelsize.py "./tmp_data/rasters/tmp/channelsurface.tif")
echo $PS
gdalwarp -cutline ./tmp_data/rasters/tmp/polder.shp -tr $PS $PS -tap -crop_to_cutline -srcnodata -9999 -dstnodata -9999 -co "COMPRESS=DEFLATE" ./fixed_data/DEM/dem.vrt ./tmp_data/rasters/tmp/raw_dem_clipped.tif
echo INFO smeer watergangen dicht
gdalwarp -ot Float32 -dstnodata -9999 -tr $PS $PS -tap ./tmp_data/rasters/tmp/raw_dem_clipped.tif ./tmp_data/rasters/tmp/channelsurface.tif ./tmp_data/rasters/tmp/temp.tif
echo INFO pas compressie toe op DEM
gdal_translate -ot Float32 -co "COMPRESS=DEFLATE" ./tmp_data/rasters/tmp/temp.tif ./tmp_data/rasters/dem_$2.tif
echo INFO Knip bodemberging, frictie en infiltratie uit gebiedsbrede rasters
echo -----------------------------------
echo INFO maak raster met enen voor extent
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/dem_$2.tif --outfile ./tmp_data/rasters/tmp/enenraster_ongec.tif --calc="1"
echo INFO maak rasters om te vullen
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/dem_$2.tif --outfile ./tmp_data/rasters/tmp/vulraster_ghg_ongec.tif --calc="0"
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/dem_$2.tif --outfile ./tmp_data/rasters/tmp/vulraster_glg_ongec.tif --calc="0"
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/dem_$2.tif --outfile ./tmp_data/rasters/tmp/vulraster_ggg_ongec.tif --calc="0"
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/dem_$2.tif --outfile ./tmp_data/rasters/tmp/vulraster_friction.tif --calc="0.2"
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/dem_$2.tif --outfile ./tmp_data/rasters/tmp/vulraster_infiltration.tif --calc="0"
echo INFO plak de waarden voor bodemberging hier in
gdalwarp ./fixed_data/bodemberging_verhard_hhnk.tif ./fixed_data/bodemberging_hhnk_ghg_m.tif ./tmp_data/rasters/tmp/vulraster_ghg_ongec.tif
gdalwarp ./fixed_data/bodemberging_verhard_hhnk.tif ./fixed_data/bodemberging_hhnk_ggg_m.tif ./tmp_data/rasters/tmp/vulraster_ggg_ongec.tif
gdalwarp ./fixed_data/bodemberging_verhard_hhnk.tif ./fixed_data/bodemberging_hhnk_glg_m.tif ./tmp_data/rasters/tmp/vulraster_glg_ongec.tif
gdalwarp ./fixed_data/friction_hhnk.tif ./tmp_data/rasters/tmp/vulraster_friction.tif
gdalwarp ./fixed_data/infiltratie_hhnk.tif ./tmp_data/rasters/tmp/vulraster_infiltration.tif
echo INFO pas extent toe op gevulde rasters
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/tmp/enenraster_ongec.tif -B ./tmp_data/rasters/tmp/vulraster_ghg_ongec.tif --outfile ./tmp_data/rasters/tmp/vulraster_ghg_ongec_ext.tif --calc="A*B"  
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/tmp/enenraster_ongec.tif -B ./tmp_data/rasters/tmp/vulraster_ggg_ongec.tif --outfile ./tmp_data/rasters/tmp/vulraster_ggg_ongec_ext.tif --calc="A*B"  
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/tmp/enenraster_ongec.tif -B ./tmp_data/rasters/tmp/vulraster_glg_ongec.tif --outfile ./tmp_data/rasters/tmp/vulraster_glg_ongec_ext.tif --calc="A*B"  
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/tmp/enenraster_ongec.tif -B ./tmp_data/rasters/tmp/vulraster_friction.tif --outfile ./tmp_data/rasters/tmp/vulraster_friction_ext.tif --calc="A*B"  
gdal_calc.py --co="COMPRESS=DEFLATE" --NoDataValue -9999 -A ./tmp_data/rasters/tmp/enenraster_ongec.tif -B ./tmp_data/rasters/tmp/vulraster_infiltration.tif --outfile ./tmp_data/rasters/tmp/vulraster_infiltration_ext.tif --calc="A*B"  
echo INFO comprimeer eindresultaat
gdal_translate -co "COMPRESS=DEFLATE" ./tmp_data/rasters/tmp/vulraster_ghg_ongec_ext.tif ./tmp_data/rasters/storage_ghg_$2.tif
gdal_translate -co "COMPRESS=DEFLATE" ./tmp_data/rasters/tmp/vulraster_ggg_ongec_ext.tif ./tmp_data/rasters/storage_ggg_$2.tif
gdal_translate -co "COMPRESS=DEFLATE" ./tmp_data/rasters/tmp/vulraster_glg_ongec_ext.tif ./tmp_data/rasters/storage_glg_$2.tif
gdal_translate -co "COMPRESS=DEFLATE" ./tmp_data/rasters/tmp/vulraster_friction_ext.tif ./tmp_data/rasters/friction_$2.tif
gdal_translate -co "COMPRESS=DEFLATE" ./tmp_data/rasters/tmp/vulraster_infiltration_ext.tif ./tmp_data/rasters/infiltration_$2.tif
echo INFO verwijder tijdelijke bestanden
rm ./tmp_data/rasters/tmp -r
cp -r ./tmp_data/rasters/ ./models/
echo Klaar tmp_data