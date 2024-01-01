rem Dit script roept drie losse python scripts aan.
rem fix channels repareert mogelijke fouten in de geometrie van watergangen
rem clip channel by culvert knipt de duikers uit de watergangen
rem clip circular knipt watergangen met het start en eindpunt op elkaar in tweeen (mag niet in 3Di)
%CONDA_PREFIX%\python.exe \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\code\modelbuilder\tools\threedi-base\manage.py 02_fix_channels \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\code\modelbuilder\tools\threedi-base\config.ini
%CONDA_PREFIX%\python.exe \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\code\modelbuilder\tools\threedi-base\manage.py 03_clip_channel_by_culvert --search-radius 0.1 \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\code\modelbuilder\tools\threedi-base\config.ini
%CONDA_PREFIX%\python.exe \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\code\modelbuilder\tools\threedi-base\manage.py 04_cut_circular \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\code\modelbuilder\tools\threedi-base\config.ini