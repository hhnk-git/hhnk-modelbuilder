# %%
# -*- coding: utf-8 -*-
"""
Python script reading sql and bash files in order to automatically execute datachecks on uploaded data
--Emiel Verstegen
"""

#import libraries
import os
import subprocess
import argparse

from pathlib import Path

import sqlparse
import psycopg2
from psycopg2 import sql
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

import logging
import configparser

# set the work-dir so code-dir can be found
if not Path("code").absolute().resolve().exists():
    os.chdir(Path(__file__).absolute().resolve().parents[2])

windows = True
debug = False
if debug:
    log_level = logging.DEBUG
else:
    log_level = logging.INFO
work_dir = Path.cwd()         
#setup logging to write debug log to file
logging.basicConfig(filename=work_dir.joinpath('code/datachecker/datachecker.log'),filemode='w',format='%(asctime)s - %(levelname)s - %(message)s',level=log_level)

#Read configuration file
config = configparser.ConfigParser()
config.read(work_dir.joinpath('code/datachecker/datachecker_config.ini'))

walk_dir = work_dir.joinpath('code/datachecker/scripts/polder')

run_file = work_dir.joinpath("code/datachecker/datachecker_running.txt")


def get_parser():
    """ Return argument parser. """

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        '-f', '--file',
        help='script to execute')
    return parser
    

def execute_sql_file_multiple_transactions(file_path):
    """Execute .sql file with one query per transaction (speeds up the queries)"""

    try:
        db_conn = psycopg2.connect(dbname=config['db']['database'], host=config['db']['hostname'], user=config['db']['username'], password=config['db']['password'], port=config['db']['port'])
        db_cur = db_conn.cursor()
    except psycopg2.OperationalError as e:
        logging.error("Could not connect to database with error: {}".format(e))
        raise
        
    #Read file
    logging.info("Executing SQL script: {}".format(file_path))
    sqlfile = open(file_path)
    sqlfile_content = sqlfile.read()
    sqlfile.close() 
    
    #parse content naar queries
    formatted_content = sqlparse.format(sqlfile_content,strip_comments=True, strip_whitespace=True,encoding='utf-8')
    splitted_content = sqlparse.split(formatted_content)
    parsed_content = sqlparse.parse(formatted_content)
    
    try:
        #voer queries 1-voor-1 uit en commit
        for query in parsed_content:
            if debug:
                logging.debug("Query: {}".format(query))
            try:
                db_cur.execute(str(query))
                db_conn.commit()
            except psycopg2.Error as e:
                logging.error(f"SQL error: {e}")
                if debug:
                    raise e
        return 1
    
    except psycopg2.Error as e:
        logging.error("SQL error: {}".format(e))
        db_cur.close()
        db_conn.close()
        raise
        
    db_cur.close()
    db_conn.close()
        
#Define function for executing bash files        
def execute_bash_file(file_path):
    logging.info("START execute bash file: {}".format(file_path))
    file_name = file_path.split('/')[-1]
    f = open("/code/datachecker/logging_" + file_name + ".log", "w")
    subprocess.call(['bash',file_path])

#Define function for executing cmd files        
def execute_cmd_file(file_path):
    logging.info("START execute cmd file: {}".format(file_path))
    file_path = Path(file_path)
    cmd = file_path.as_posix()
    log_file = work_dir.joinpath(f"code/datachecker/logging_{file_path.stem}.log")
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE).stdout.read()
    log_file.write_bytes(p)

def create_database(db_name):
    logging.info("Creating database {}".format(db_name))
    con = psycopg2.connect(dbname='postgres', host=config['db']['hostname'], user=config['db']['username'], password=config['db']['password'], port=config['db']['port'])
    con.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    cur = con.cursor()
    
    cur.execute(sql.SQL("DROP DATABASE IF EXISTS {}").format(
        sql.Identifier(db_name))
    )
    
    cur.execute(sql.SQL("CREATE DATABASE {}").format(
        sql.Identifier(db_name))
    )
    
    #Fill with 3di template
    result = execute_sql_file_multiple_transactions(
        work_dir.joinpath(
            'code/datachecker/tools/threedi-template/work_empty_schema_2020-01-15.sql'
            )
        )

def datachecker(**kwargs):

    if(kwargs.get('file') is None):
        logging.info("Starting datachecker")
        run_file.write_text("")
        create_database(config['db']['database'])
        
        script = 0
        try:
            for root, subdirs, files in sorted(os.walk(walk_dir)):
                for f in sorted(files):
                    script += 1
                    file_path = root+'/'+f
                    logging.debug('Opening file: {}'.format(file_path))
                    result = ""
                    print(file_path)
                    if file_path.endswith('.sql'):
                        #execute .sql file
                        logging.debug('Executing .sql file')

                        result = execute_sql_file_multiple_transactions(file_path)
                    elif file_path.endswith('.sh') and not windows:
                        logging.debug('Executing .sh file')

                        result = execute_bash_file(file_path)
                    elif file_path.endswith('.cmd') and windows:
                        logging.debug('Executing .cmd file')
                        result = execute_cmd_file(file_path)
                    else:
                        logging.debug("File is no .sql or .sh file, don't know what to do with it, skipping")
        except psycopg2.Error as e:
            logging.error(e)
            logging.info("Stopping datachecker")
        logging.info("Stopping datachecker")
        if run_file.is_file():
            run_file.unlink()
        
    else:
        result = execute_sql_file_multiple_transactions(kwargs.get('file'))


def main():
    try:
        return datachecker(**vars(get_parser().parse_args()))
    except SystemExit:
        raise  # argparse does this

if __name__ == "__main__":
    datachecker() # main()
