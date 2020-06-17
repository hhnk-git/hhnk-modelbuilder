# -*- coding: utf-8 -*-
"""
Created on Wed Jun 17 14:51:04 2020

@author: chris.kerklaan
"""

import sys
import logging
import argparse


from threedi_modelchecker.exporters import format_check_results
from threedi_modelchecker.model_checks import ThreediModelChecker
from threedi_modelchecker.threedi_database import ThreediDatabase

def get_parser():
    """ Return argument parser. """

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        'sqlite_path', default='name.sqlite',
        help='sqlite_path (sqlite with path)')
    return parser

def run_modelchecker(**kwargs):
    print('Starting modelchecker')
    sqlite_path = kwargs.get('sqlite_path')
    log_path = sqlite_path.split(".")[0] + "_modelchecker.txt"
    logging.basicConfig(filename=log_path,level=logging.DEBUG)


    database = ThreediDatabase(
        connection_settings={"db_path": sqlite_path}, db_type="spatialite"
    )
    model_checker = ThreediModelChecker(database)
    for check, error in model_checker.errors():
        logging.info(format_check_results(check, error))

def main():
    try:
        return run_modelchecker(**vars(get_parser().parse_args()))
    except SystemExit:
        raise  # argparse does this
        
if __name__ == "__main__":
    main()