# -*- coding: utf-8 -*-
"""
Created on Wed Jun 17 14:51:04 2020

@author: chris.kerklaan
"""

import argparse
import csv
import logging
import os
import sys

from threedi_modelchecker.exporters import export_to_file, format_check_results
from threedi_modelchecker.model_checks import ThreediModelChecker
from threedi_modelchecker.threedi_database import ThreediDatabase


def get_parser():
    """Return argument parser."""

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "sqlite_path", default="name.sqlite", help="sqlite_path (sqlite with path)"
    )
    return parser


def run_modelchecker(**kwargs):
    print("Starting modelchecker")
    sqlite_path = kwargs.get("sqlite_path")
    log_path = sqlite_path.split(".")[0] + "_modelchecker.csv"
    if os.path.exists(log_path):
        os.remove(log_path)

    database = ThreediDatabase(
        connection_settings={"db_path": sqlite_path}, db_type="spatialite"
    )
    model_checker = ThreediModelChecker(database)
    session = model_checker.db.get_session()
    with open(log_path, "w", newline="") as output_file:
        writer = csv.writer(output_file)
        writer.writerow(
            ["id", "table", "column", "value", "description", "type of check"]
        )
        for i, check in enumerate(model_checker.checks()):
            model_errors = check.get_invalid(session)
            for error_row in model_errors:
                writer.writerow(
                    [
                        error_row.id,
                        check.table.name,
                        check.column.name,
                        getattr(error_row, check.column.name),
                        check.description(),
                        check,
                    ]
                )
    # export_to_file(model_checker.errors(), log_path)

    # for check, error in model_checker.errors():
    #   logging.info(format_check_results(check, error))


def main():
    try:
        return run_modelchecker(**vars(get_parser().parse_args()))
    except SystemExit:
        raise  # argparse does this


if __name__ == "__main__":
    main()
