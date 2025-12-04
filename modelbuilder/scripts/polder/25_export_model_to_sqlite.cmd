mkdir %3\data\tmp\models
%CONDA_PREFIX%\python.exe %3\code\modelbuilder\tools\threedi-export\export_threedi.py %3\data\tmp\models\bwn_%2.sqlite
rmdir /s /q %3\data\output\02_schematisation\00_basis
mkdir %3\data\output\02_schematisation\00_basis
xcopy /E /I /Y %3\data\tmp\models %3\data\output\02_schematisation\00_basis
rmdir /s /q %3\data\tmp