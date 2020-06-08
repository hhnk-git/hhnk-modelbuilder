# (c) Nelen & Schuurmans.  GPL licensed, see LICENSE.rst.
# -*- coding: utf-8 -*-

import os
import sys
import time

from base.threedi_base.config_reader import IniReader
from django.core.management.base import BaseCommand
from base.threedi_base.apps import ThreediBaseConfig as conf
from base.threedi_base.DB import ThreediDatabase
from base.threedi_base.logger import Logger

logger = Logger.get(__name__, conf.LOG_LEVEL)


class ThreediBaseCommand(BaseCommand):
    """
    Base class for threedi-base commands. Reads the database
    credentials from the given ini-file and creates an ``ThreediDatabase``
    instance.
    """

    def add_arguments(self, parser):
        """
        add an ini file as an optional positional argument
        """
        parser.add_argument('ini', nargs='?', type=str)

    def setup_db(self, *args, **options):
        """
        call this method to make sure the ini_file will be
        resolved correctly and a database connection
        will be established.
        """
        ini_file = self.resolve_ini(**options)
        credentials = get_db_cretentials_from_ini(ini_file)
        self.db = ThreediDatabase(**credentials)

    def resolve_ini(self, **options):
        """
        decide which ini file to use
        """
        default_ini = os.path.abspath(
            os.path.join(conf.PROJECT_DIR, '..', '..', 'default_config.ini')
        )
        custom_ini_file = options.get('ini')
        if custom_ini_file is None:
            logger.info('[*] Using default ini file {}'.format(
                os.path.basename(default_ini))
            )
            return default_ini
        if all((os.path.exists(custom_ini_file),
               os.path.isfile(custom_ini_file))):
            logger.info('[*] Using custom ini file {}'.format(
                os.path.basename(custom_ini_file))
            )
            return custom_ini_file
        else:
            self.stdout.write(
                self.style.ERROR(
                    'Error: Could not find the ini file {}'.format(
                        custom_ini_file)
                )
            )
            sys.exit(1)

    def set_start_time(self):
        self.start_time = time.time()

    def get_exec_time(self):
        """
        calculate the execution time of the script
        """
        duration = time.time() - self.start_time
        _m, s = divmod(duration, 60)
        h, m = divmod(_m, 60)
        if all([h < 1, m < 1, s < 1]):
            return 'less than a second'
        return "%d:%02d:%02d" % (h, m, s)

    def deliver_message(self, msg, status):
        """
        print the message to stdout
        """
        if status == 'error':
            self.stdout.write(self.style.ERROR(msg))
        elif status == 'success':
            self.stdout.write(self.style.SUCCESS(msg))


def get_db_cretentials_from_ini(ini):
    ini_reader = IniReader(ini)
    return {
        "dbname": ini_reader.get('database_name'),
        "host": ini_reader.get('database_host'),
        "user": ini_reader.get('database_user'),
        "password": ini_reader.get('database_password'),
        "schema": ini_reader.get('schema'),
    }


