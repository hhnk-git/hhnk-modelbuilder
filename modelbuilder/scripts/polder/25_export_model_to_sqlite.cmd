mkdir \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\models
%CONDA_PREFIX%\python.exe \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\code\modelbuilder\tools\threedi-export\export_threedi.py \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\models\bwn_%2.sqlite
rmdir /s /q \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\02_schematisation\00_basis
mkdir \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\02_schematisation\00_basis
xcopy /E /I /Y \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\models \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\02_schematisation\00_basis
rmdir /s /q \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp