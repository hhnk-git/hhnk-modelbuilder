#!/bin/bash
/srv/modelbuilder/prd/threedi-turtle/bin/django generate_threedi_files /srv/bwn_modelbuilder/models/
/srv/modelbuilder/prd/threedi-turtle/bin/pyflow /srv/bwn_modelbuilder/models/bwn_${2}_0d1d_test.ini -m -s -g
/srv/modelbuilder/prd/threedi-turtle/bin/pyflow /srv/bwn_modelbuilder/models/bwn_${2}_0d1d_test.ini -t 100
/srv/modelbuilder/prd/threedi-turtle/bin/pyflow /srv/bwn_modelbuilder/models/bwn_${2}_1d2d_test.ini -m -s -g
/srv/modelbuilder/prd/threedi-turtle/bin/pyflow /srv/bwn_modelbuilder/models/bwn_${2}_1d2d_test.ini -t 100