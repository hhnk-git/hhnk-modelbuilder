mkdir D:\modelbuilder\data\tmp\models
%CONDA_PREFIX%\python.exe D:\modelbuilder\code\modelbuilder\tools\threedi-export\export_threedi.py D:\modelbuilder\data\tmp\models\bwn_%2.sqlite
rmdir /s /q D:\modelbuilder\data\output\02_schematisation\00_basis
mkdir D:\modelbuilder\data\output\02_schematisation\00_basis
xcopy /E /I /Y D:\modelbuilder\data\tmp\models D:\modelbuilder\data\output\02_schematisation\00_basis
rmdir /s /q D:\modelbuilder\data\tmp