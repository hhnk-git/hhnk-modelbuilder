#!/bin/bash
mkdir /code/tmp/models -p
python3 /code/modelbuilder/tools/threedi-export/export_threedi.py /code/tmp/models/bwn_$2.sqlite
python3 /code/modelbuilder/tools/modelchecker.py /code/tmp/models/bwn_$2.sqlite
rm /code/data/output/models/* -rf
mkdir /code/data/output/models -p
cp -a /code/tmp/models/. /code/data/output/models/
rm /code/tmp -rf