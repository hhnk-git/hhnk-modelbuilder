#!/bin/bash
rm ./output/* -r
zip -r ./output/modelbuilder_output_$3.zip ./models/bwn_$2.sqlite ./models/rasters/ ./models/feedback/ ./logging/modelbuilder_logfiles/