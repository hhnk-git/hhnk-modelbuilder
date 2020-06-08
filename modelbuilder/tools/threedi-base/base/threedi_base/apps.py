# (c) Nelen & Schuurmans.  GPL licensed, see LICENSE.rst.
# -*- coding: utf-8 -*-
import os

from django.apps import AppConfig


class ThreediBaseDefaultConfig(AppConfig):
    name = 'threedi_base'
    PROJECT_DIR = os.path.realpath(os.path.dirname(__file__))
    DEBUG = False
    TESTING = False


class ProductionConfig(ThreediBaseDefaultConfig):
    DEBUG = False
    LOG_LEVEL = "INFO"
    DEFAULT_FETCH = 'default'


class DevelopmentConfig(ThreediBaseDefaultConfig):

    # the same settigns for now.
    DEBUG = True
    LOG_LEVEL = "INFO"
    DEFAULT_FETCH = 'default'


class TestingConfig(ThreediBaseDefaultConfig):
    TESTING = True

#
config_class = {
    "PRODUCTION": ProductionConfig,
    "STAGING": "",
    "DEVELOPMENT": DevelopmentConfig,
    "TESTING": TestingConfig,
}

environment = os.environ.get("environment", "DEVELOPMENT")

_to_import = config_class.get(environment.upper())


class ThreediBaseConfig(_to_import):
    pass
