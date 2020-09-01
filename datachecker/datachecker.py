# -*- coding: utf-8 -*-
"""
Python script reading sql and bash files in order to automatically execute datachecks on uploaded data
--Emiel Verstegen
"""

#import libraries
import os
import sys
import subprocess
import argparse

import sqlparse
import psycopg2
from psycopg2 import sql
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

import logging
import configparser

#setup logging to write debug log to file
logging.basicConfig(filename='/code/datachecker/datachecker.log',filemode='w',format='%(asctime)s - %(levelname)s - %(message)s',level=logging.DEBUG)

#Read configuration file
config = configparser.ConfigParser()
config.read('/code/datachecker/datachecker_config.ini')

walk_dir = '/code/datachecker/scripts/polder'


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
        db_conn = psycopg2.connect(host=config['db']['hostname'], dbname=config['db']['database'], user=config['db']['username'], password=config['db']['password'])
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
            try:
                db_cur.execute(str(query))
                db_conn.commit()
            except psycopg2.Error as e:
                logging.error("SQL error: {}".format(e))
                logging.debug("Query: {}".format(query))
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
    subprocess.call(['bash',file_path])
    

def create_database(db_name):
    logging.info("Creating database {}".format(db_name))
    con = psycopg2.connect(dbname='postgres', host=config['db']['hostname'], user=config['db']['username'], password=config['db']['password'])
    con.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    cur = con.cursor()
    
    cur.execute(sql.SQL("DROP DATABASE IF EXISTS {}").format(
        sql.Identifier(db_name))
    )
    
    cur.execute(sql.SQL("CREATE DATABASE {}").format(
        sql.Identifier(db_name))
    )
    
    #Fill with 3di template
    result = execute_sql_file_multiple_transactions('/code/datachecker/tools/threedi-template/work_empty_schema_2020-01-15.sql')

def datachecker(**kwargs):

    if(kwargs.get('file') is None):
        logging.info("Starting datachecker")
        create_database(config['db']['database'])
        
        script = 0
        try:
            for root, subdirs, files in sorted(os.walk(walk_dir)):
                for f in sorted(files):
                    script += 1
                    file_path = root+'/'+f
                    logging.debug('Opening file: {}'.format(file_path))
                    result = ""
                    if file_path.endswith('.sql'):
                        #execute .sql file
                        logging.debug('Executing .sql file')
                        result = execute_sql_file_multiple_transactions(file_path)
                    elif file_path.endswith('.sh'):
                        logging.debug('Executing .sh file')
                        result = execute_bash_file(file_path)
                    
                    else:
                        logging.debug("File is no .sql or .sh file, don't know what to do with it, skipping")
        except psycopg2.Error as e:
            logging.error(e)
        logging.info("Stopping datachecker")
    
    else:
        result = execute_sql_file_multiple_transactions(kwargs.get('file'))


def main():
    try:
        return datachecker(**vars(get_parser().parse_args()))
    except SystemExit:
        raise  # argparse does this

if __name__ == "__main__":
    main()
