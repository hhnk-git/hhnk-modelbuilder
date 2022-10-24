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
logging.basicConfig(filename='/code/modelbuilder/modelbuilder.log',filemode='w',format='%(asctime)s - %(levelname)s - %(message)s',level=logging.DEBUG)

#Read configuration file
config = configparser.ConfigParser()
config.read('/code/modelbuilder/modelbuilder_config.ini')

walk_dir = '/code/modelbuilder/scripts/polder'


def get_parser():
    """ Return argument parser. """

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        'polder_id',
        help='id of polder to model, based on ids from datachecker')
    parser.add_argument(
        'polder_name',default='unnamed',
        help='name of polder to model')
    parser.add_argument(
        '-f', '--file',
        help='script to execute')
    return parser
    

def execute_sql_file_multiple_transactions(file_path,polder_id, polder_name):
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
    sqlfile_content = sqlfile.read().replace("<<polder_id>>",polder_id).replace("<<polder_name>>",polder_name);
    sqlfile.close() 
    
    #parse content naar queries
    formatted_content = sqlparse.format(sqlfile_content,strip_comments=True, strip_whitespace=True,encoding='utf-8')
    splitted_content = sqlparse.split(formatted_content)
    parsed_content = sqlparse.parse(formatted_content)
    #splitted_content = sqlparse.parse(sqlparse.split(sqlparse.format(sqlfile_content,strip_comments=True,encoding='utf-8'))
    
    try:
        #voer queries 1-voor-1 uit en commit
        for query in parsed_content:
            # print(str(query))
            #print query.tokens
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
def execute_bash_file(file_path, polder_id, polder_name):
    logging.info('START execute bash file')
    file_name = file_path.split('/')[-1]
    f = open("/code/modelbuilder/logging_" + file_name + ".log", "w")
    subprocess.call(['bash',file_path,polder_id,polder_name], stdout=f)
    
def execute_file(file_path, polder_id, polder_name):    
    if file_path.endswith('.sql'):
        #execute .sql file
        logging.debug('Executing .sql file')
        #result = execute_sql_file_multiple_transactions(file_path)
        result = execute_sql_file_multiple_transactions(file_path, polder_id, polder_name)
    elif file_path.endswith('.sh'):
        logging.debug('Executing .sh file')
        result = execute_bash_file(file_path, polder_id, polder_name)
    
    else:
        logging.debug("File is no .sql or .sh file, don't know what to do with it, skipping")

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

def check_polder_contains_data(polder_id):
    try:
        db_conn = psycopg2.connect(host=config['db']['hostname'], dbname=config['db']['database'], user=config['db']['username'], password=config['db']['password'])
        db_cur = db_conn.cursor()
    except psycopg2.OperationalError as e:
        logging.error("Could not connect to database with error: {}".format(e))
        raise
    
    db_cur.execute("SELECT COUNT(*) FROM checks.channel a, checks.polder b WHERE ST_Contains(b.geom,a.geom) AND b.polder_id = {}".format(polder_id))
    channel_count = int(db_cur.fetchone()[0])
    logging.info("Amount of channels contained in selected polder: {}".format(channel_count))
    
    return channel_count > 0

def modelbuilder(**kwargs):
    polder_id = kwargs.get('polder_id')
    polder_name = kwargs.get('polder_name')
    file_path = kwargs.get('file')
    
    if(kwargs.get('file') is None):
        logging.info("Starting modelbuilder")
        
        #check if there are any channels in the polder. If not, the filled in polder_id is most probably wrong
        if check_polder_contains_data(polder_id):
            script = 0
            try:
                for root, subdirs, files in sorted(os.walk(walk_dir)):
                    for f in sorted(files):
                        script += 1
                        file_path = root+'/'+f
                        logging.debug('Opening file: {}'.format(file_path))
                        result = ""
                        print(file_path)
                        execute_file(file_path, polder_id, polder_name)
            except psycopg2.Error as e:
                logging.error(e)
                os.remove("/code/modelbuilder/modelbuilder_running.txt")
        else:
            logging.info("No channels found in polder, stopping the modelbuilder")
        logging.info("Stopping modelbuilder")
        os.remove("/code/modelbuilder/modelbuilder_running.txt")
    
    else:
        result = execute_file(file_path, polder_id, polder_name)


def main():
    try:
        return modelbuilder(**vars(get_parser().parse_args()))
    except SystemExit:
        raise  # argparse does this

if __name__ == "__main__":
    main()
