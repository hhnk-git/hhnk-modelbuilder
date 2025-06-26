# (c) Nelen & Schuurmans.  GPL licensed, see LICENSE.rst.
# -*- coding: utf-8 -*-

import logging
import sys

BASIC_FORMAT = "(%(name)s) %(asctime)s: [%(levelname)s] %(message)s"


class Logger(object):
    _logger = None

    def __init__(self, name, loglevel=logging.DEBUG, format=BASIC_FORMAT):
        if loglevel is None:
            loglevel = logging.DEBUG

        logger = logging.getLogger(name)
        logger.setLevel(loglevel)
        logger.propagate = False
        formatter = logging.Formatter(format)
        if not logger.handlers:
            handler = logging.StreamHandler(stream=sys.stdout)
            handler.setFormatter(formatter)
            handler.setLevel(loglevel)
            logger.addHandler(handler)

        self._logger = logger

    @classmethod
    def get(cls, name, loglevel=None, format=BASIC_FORMAT):
        return cls(name, loglevel, format)._logger
