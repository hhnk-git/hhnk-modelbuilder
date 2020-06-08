THREEDI-BASE
============

Introduction
------------

Customers like "waterschappen" organize their geographic data in different ways.
Structures for example sometimes are represented as point geometries, sometimes
as line geometries. To be able to build and run 3Di models in a reliable way
the customer data needs to be transformed and normalized.
``threedi-base`` is (or will be) the starting point for these transformations.
The result will be a base schema that then can be manipulated into 3Di models.


Getting started
---------------

Create a virutal environment (see https://virtualenv.pypa.io/en/stable/userguide/)
using python3, activate it and install the requirements by running::

     $ pip install -r requirements.txt

The project knows three possible environment names: "PRODUCTION", "DEVELOPMENT" and
"TESTING". Add one of those as a environment variable named "environment" so use
the apps settings as specified in ``threedi-base/apps.py``, e.g.::

    $ export environment="DEVELOPMENT"

To import and use the settings from within a script::

    from base.threedi_base.apps import ThreediBaseConfig as conf

``threedi_base`` is a django app. So see all available commands run::

    $ python manage.py --help

If you want to use the djano-admin utility you also have to add ``DJANGO_SETTINGS_MODULE`` to your
environment variables (see https://docs.djangoproject.com/en/1.10/topics/settings/)::

    $ export DJANGO_SETTINGS_MODULE="base.settings"


Local development with docker-compose
-------------------------------------

You can also use docker-compose for local development. Make sure you have a copy of ``docker-compose.yml.example``::

    $ cp docker-compose.yml.example docker-compose.yml

Replace the TODO's in the ``docker-compose.yml`` file by the correct values.

Then run docker-compose up::

    $ docker-compose up

This will fetch and/or build the required docker images.

Optional: load an sql file with example data into the ``gis`` (default) database::

    $ docker-compose exec postgres bash
    (root)# su postgres
    (postgres)# psql -d gis -a -f /dumps/<name_of_your_sql_file>


Commands: snap_to_grid
----------------------

Geometries come from different organisations, different databases etc.
That is, sources differ and so is their precision. This scripts ensures
that all data lies on a regular grid. All successive steps rely on this
operation.

    $ python manage.py snap_to_grid


Deployment
----------

staging
=======

To deploy to staging make sure to put the correct ``repo_version`` in the
``host_vars/threedi-base-staging.3di.lizard.net`` file. Then run::

    $ ansible-playbook -i staging -l threedi-base-staging.3di.lizard.net deploy.yml -Kk

production
==========

To deploy to production make sure to put the correct ``repo_version`` in the
``host_vars/threedi-base-production.3di.lizard.net`` file. Then run::

    $ ansible-playbook -i production -l threedi-base-production.3di.lizard.net deploy.yml -Kk


To deploy to the deltares production server make sure to put the correct ``repo_version`` in the
``host_vars/threedi-base-production-deltares.3di.lizard.net`` file. Then run::

    $ ansible-playbook -i production -l threedi-base-production-deltares.3di.lizard.net deploy.yml -Kk


After the deployment make sure to commit the changed ``host_vars`` file together with a
line in ``CHANGES.rst`` that states what is deployed where.

To use the management commands on staging or production, edit the ``default_config.ini`` file
with the correct database settings and run the management command like this (example for staging)::

    $ ssh nens-3di-task-03.nens.local
    $ sudo su buildout
    $ cd /srv/threedi-base-staging.3di.lizard.net
    $ bin/python manage.py snap_to_grid

