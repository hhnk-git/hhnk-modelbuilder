## 
# Dit script roept drie losse python scripts aan.
# fix channels repareert mogelijke fouten in de geometrie van watergangen
# clip channel by culvert knipt de duikers uit de watergangen
# clip circular knipt watergangen met het start en eindpunt op elkaar in tweeen (mag niet in 3Di)
##
#!/bin/bash
python3 /code/modelbuilder/tools/threedi-base/manage.py 02_fix_channels /code/modelbuilder/tools/threedi-base/config.ini
python3 /code/modelbuilder/tools/threedi-base/manage.py 03_clip_channel_by_culvert --search-radius 0.1 /code/modelbuilder/tools/threedi-base/config.ini
python3 /code/modelbuilder/tools/threedi-base/manage.py 04_cut_circular /code/modelbuilder/tools/threedi-base/config.ini