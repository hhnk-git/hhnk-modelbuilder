# (c) Nelen & Schuurmans.  GPL licensed, see LICENSE.rst.
# -*- coding: utf-8 -*-
from base.threedi_base.apps import ThreediBaseConfig as conf
from base.threedi_base.logger import Logger

try:
    # py 3
    import configparser
except ImportError:
    # py 2
    import ConfigParser as configparser

logger = Logger.get(__name__, conf.LOG_LEVEL)


class IniReader:
    """
    Read and parse an ini-file
    """

    def __init__(self, ini_file_name):
        """
        :param project_root:  path to the project_root directory
        :param ini_file_name: name of the ini file
        """

        self.ini_file_name = ini_file_name
        # make sure the source exists and actually is a file
        self._parser = configparser.ConfigParser()
        self._parser.read(self.ini_file_name)
        # all attributes are accessible via the ``options-``dict
        self.options = dict(self.get_all_options())

    def get_all_options(self):
        for section in self._parser.sections():
            for option in self._parser.options(section):
                clean_value = self.clean(self._parser.get(section, option))
                yield (option, clean_value)

    def clean(self, value):
        """Remove everything after first #"""
        return value.split("#")[0].strip()

    def get(self, option):
        # parser.options() has all options in lower case, so whatever
        # is passed here, we make it lower case too.
        return self.options.get(option.lower())
