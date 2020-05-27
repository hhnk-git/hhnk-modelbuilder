#!/bin/bash
rm ./models/* -r
/srv/modelbuilder/prd/threedi-turtle/bin/django export_work_to_spatialite work_modelbuilder /srv/bwn_modelbuilder/models/bwn_$2.sqlite