# Dit script roept het python script aan waarin kunstwerken die als punt in de database staan worden omgezet naar lijnsegmenten
#!/bin/bash
pwd
python3 /code/modelbuilder/tools/threedi-base/manage.py 05_linify_structures /code/modelbuilder/tools/threedi-base/config.ini