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
        'filename', default='name',
        help='filename (without path)')
    return parser

def run_modelchecker(**kwargs):
    print('Starting modelchecker')
    name = kwargs.get('filename')
    logging.basicConfig(filename=f'/code/data/output/{name}_modelchecker.txt',level=logging.DEBUG)


    sqlite_file = f"/code/data/output/{name}.sqlite"
    database = ThreediDatabase(
        connection_settings={"db_path": sqlite_file}, db_type="spatialite"
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