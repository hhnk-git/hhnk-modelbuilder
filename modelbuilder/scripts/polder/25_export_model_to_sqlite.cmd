mkdir \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\models
python .\code\modelbuilder\tools\threedi-export\export_threedi.py \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\models\bwn_%2.sqlite
rem python .\code\modelbuilder\tools\modelchecker.py .\code\tmp\models\bwn_%2.sqlite
rmdir /s /q \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\models
mkdir \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\models
xcopy /E /I /Y \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp\models \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\output\models
rem rmdir /s /q \\corp.hhnk.nl\data\Hydrologen_data\Data\modelbuilder\data\tmp