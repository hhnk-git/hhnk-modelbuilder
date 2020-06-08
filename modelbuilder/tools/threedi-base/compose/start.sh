#!/bin/sh

cp ./compose/default_config.ini /srv/default_config.ini

python manage.py runserver 0.0.0.0:8000
