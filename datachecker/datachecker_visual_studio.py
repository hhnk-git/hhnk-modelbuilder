# %%
# -*- coding: utf-8 -*-
"""
Python script reading sql and bash files in order to automatically execute datachecks on uploaded data
--Emiel Verstegen
"""

# import libraries
import argparse
import configparser
import logging
import os
import subprocess
from pathlib import Path

import psycopg2
import sqlparse
from hhnk_research_tools import logging as logging_hrt
from psycopg2 import sql
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

# set the work-dir so code-dir can be found
if not Path("code").absolute().resolve().exists():
    os.chdir(Path(__file__).absolute().resolve().parents[2])

windows = True
debug = False
if debug:
    log_level = "DEBUG"
else:
    log_level = "INFO" 
work_dir = Path.cwd()

logger = logging_hrt.get_logger(
    name=__name__,
    filepath=work_dir.joinpath("code/datachecker/datachecker.log"),
    level=log_level,
    filemode="w",
)


# Read configuration file
config = configparser.ConfigParser()
config.read(work_dir.joinpath("code/datachecker/datachecker_config.ini"))

walk_dir = work_dir.joinpath("code/datachecker/scripts/polder")

run_file = work_dir.joinpath("code/datachecker/datachecker_running.txt")


def get_parser():
    """Return argument parser."""

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("-f", "--file", help="script to execute")
    return parser


def execute_sql_file_multiple_transactions(file_path):
    """Execute .sql file with one query per transaction (speeds up the queries)"""

    try:
        db_conn = psycopg2.connect(
            dbname=config["db"]["database"],
            host=config["db"]["hostname"],
            user=config["db"]["username"],
            password=config["db"]["password"],
            port=config["db"]["port"],
        )
        db_cur = db_conn.cursor()
    except psycopg2.OperationalError as e:
        logger.error("Could not connect to database with error: {}".format(e))
        raise

    # Read file
    logger.info("Executing SQL script: {}".format(file_path))
    sqlfile = open(file_path)
    sqlfile_content = sqlfile.read()
    sqlfile.close()

    # parse content naar queries
    formatted_content = sqlparse.format(
        sqlfile_content, strip_comments=True, strip_whitespace=True, encoding="utf-8"
    )
    splitted_content = sqlparse.split(formatted_content)
    parsed_content = sqlparse.parse(formatted_content)

    try:
        # voer queries 1-voor-1 uit en commit
        for query in parsed_content:
            if debug:
                logger.debug("Query: {}".format(query))
            try:
                db_cur.execute(str(query))
                db_conn.commit()
            except psycopg2.Error as e:
                logger.error(f"SQL error: {e}")
                if debug:
                    raise e
        return 1

    except psycopg2.Error as e:
        logger.error("SQL error: {}".format(e))
        db_cur.close()
        db_conn.close()
        raise

    db_cur.close()
    db_conn.close()


# Define function for executing bash files
def execute_bash_file(file_path):
    logger.info("START execute bash file: {}".format(file_path))
    file_name = file_path.split("/")[-1]
    f = open("/code/datachecker/logging_" + file_name + ".log", "w")
    subprocess.call(["bash", file_path])


# Define function for executing cmd files
def execute_cmd_file(file_path):
    logger.info("START execute cmd file: {}".format(file_path))
    file_path = Path(file_path)
    cmd = file_path.as_posix()
    log_file = work_dir.joinpath(f"code/datachecker/logging_{file_path.stem}.log")
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE).stdout.read()
    log_file.write_bytes(p)


def create_database(db_name):
    logger.info("Creating database {}".format(db_name))
    con = psycopg2.connect(
        dbname="postgres",
        host=config["db"]["hostname"],
        user=config["db"]["username"],
        password=config["db"]["password"],
        port=config["db"]["port"],
    )
    con.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    cur = con.cursor()

    cur.execute(sql.SQL("DROP DATABASE IF EXISTS {}").format(sql.Identifier(db_name)))

    cur.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(db_name)))

    # Fill with 3di template
    result = execute_sql_file_multiple_transactions(
        work_dir.joinpath(
            "code/datachecker/tools/threedi-template/work_empty_schema_2020-01-15.sql"
        )
    )


def datachecker(**kwargs):
    if kwargs.get("file") is None:
        logger.info("Starting datachecker")
        run_file.write_text("")

        damo_path = Path(r"E:\modelbuilder\data\input\DAMO.gpkg")
        hdb_path = Path(r"E:\modelbuilder\data\input\HDB.gpkg")
        if not damo_path.exists():
            raise FileExistsError(damo_path)
        if not hdb_path.exists():
            raise FileExistsError(hdb_path)

        create_database(config["db"]["database"])

        script = 0
        try:
            for root, subdirs, files in sorted(os.walk(walk_dir)):
                for f in sorted(files):
                    print(f)
                    script += 1
                    file_path = root + "/" + f

                    logger.debug("Opening file: {}".format(file_path))
                    result = ""
                    print(file_path)
                    if file_path.endswith(".sql"):
                        # execute .sql file
                        logger.debug("Executing .sql file")

                        result = execute_sql_file_multiple_transactions(file_path)
                    elif file_path.endswith(".sh") and not windows:
                        logger.debug("Executing .sh file")

                        result = execute_bash_file(file_path)
                    elif file_path.endswith(".cmd") and windows:
                        logger.debug("Executing .cmd file")
                        result = execute_cmd_file(file_path)
                    else:
                        logger.debug(
                            "File is no .sql or .sh file, don't know what to do with it, skipping"
                        )

        except psycopg2.Error as e:
            logger.error(e)
            logger.info("Stopping datachecker")
        logger.info("Stopping datachecker")
        if run_file.is_file():
            run_file.unlink()

    else:
        result = execute_sql_file_multiple_transactions(kwargs.get("file"))


def main():
    try:
        return datachecker(**vars(get_parser().parse_args()))
    except SystemExit:
        raise  # argparse does this


if __name__ == "__main__":
    datachecker()  # main()

print("datachecker klaar")
# %%
