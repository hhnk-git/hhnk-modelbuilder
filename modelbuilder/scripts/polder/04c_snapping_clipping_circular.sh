#!/bin/bash
pwd
/srv/nens-s-bwn-modelbuilder.nens.local/bin/python /srv/nens-s-bwn-modelbuilder.nens.local/manage.py 02_fix_channels ./config/config_modelbuilder.ini
/srv/nens-s-bwn-modelbuilder.nens.local/bin/python /srv/nens-s-bwn-modelbuilder.nens.local/manage.py 03_clip_channel_by_culvert --search-radius 0.1 ./config/config_modelbuilder.ini
/srv/nens-s-bwn-modelbuilder.nens.local/bin/python /srv/nens-s-bwn-modelbuilder.nens.local/manage.py 04_cut_circular ./config/config_modelbuilder.ini