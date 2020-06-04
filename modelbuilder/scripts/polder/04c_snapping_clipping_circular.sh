#!/bin/bash
pwd
python3 /code/modelbuilder/tools/threedi-base/manage.py 02_fix_channels /code/modelbuilder/tools/threedi-base/config.ini
python3 /code/modelbuilder/tools/threedi-base/manage.py 03_clip_channel_by_culvert --search-radius 0.1 /code/modelbuilder/tools/threedi-base/config.ini
python3 /code/modelbuilder/tools/threedi-base/manage.py 04_cut_circular /code/modelbuilder/tools/threedi-base/config.ini