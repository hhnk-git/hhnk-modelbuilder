# -*- coding: utf-8 -*-
"""
Python script reading sql and bash files in order to automatically execute datachecks on uploaded data
--Emiel Verstegen
"""

#import libraries
import os
import sqlparse
import psycopg2
import logging
import configparser

#setup logging to write debug log to file
logging.basicConfig(filename='datachecker.log',filemode='w',format='%(asctime)s - %(levelname)s - %(message)s',level=logging.DEBUG)

#Read configuration file
config = configparser.ConfigParser()
config.read('datachecker_config.ini')

#Execute .sql file with one query per transaction (speeds up the queries)
def execute_sql_file_multiple_transactions(file_path):
    try:
        db_conn = psycopg2.connect(host=config['db']['hostname'], dbname=config['db']['database'], user=config['db']['username'], password=config['db']['password'])
        db_cur = db_conn.cursor()
    except psycopg2.OperationalError as e:
        logging.error("Could not connect to database with error: {}".format(e))
        raise
        
    #Read file
    sqlfile = open(file_path)
    sqlfile_content = sqlfile.read()
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
            #try:
            db_cur.execute(str(query))
            db_conn.commit()
            #except:
            #print("Broken query: " + str(query))
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
    

logging.info("Starting datachecker")
execute_sql_file_multiple_transactions('./scripts/boezem/01_lizard_db_vullen/01_work_db_opzetten.sql')
logging.info("Finishing datachecker")