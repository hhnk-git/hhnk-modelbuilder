#!/bin/bash
rm /code/data/output/models/* -rf
mkdir /code/data/output/models
python3 /code/modelbuilder/tools/threedi-export/export_threedi.py /code/data/output/models/bwn_$2.sqlite
python3 /code/modelbuilder/tools/modelchecker.py /code/data/output/models/bwn_$2.sqlite