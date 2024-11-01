# %%
# -*- coding: utf-8 -*-
"""
Python script reading sql and bash files in order to automatically execute datachecks on uploaded data
--Emiel Verstegen
"""

#import libraries
import os
import re
import sys
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
logging.basicConfig(filename=work_dir.joinpath('code/modelbuilder/modelbuilder_visual_studio.log'),filemode='w',format='%(asctime)s - %(levelname)s - %(message)s',level=log_level)

#Read configuration file
config = configparser.ConfigParser()
config.read(work_dir.joinpath('code/modelbuilder/modelbuilder_config.ini'))

walk_dir = work_dir.joinpath('code/modelbuilder/scripts/polder')

run_file = work_dir.joinpath("code/modelbuilder/modelbuilder_running.txt")

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
        db_conn = psycopg2.connect(dbname=config['db']['database'], host=config['db']['hostname'], user=config['db']['username'], password=config['db']['password'], port=config['db']['port'])
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
            if debug:
                logging.debug("Query: {}".format(query))
            try:
                db_cur.execute(str(query))
                db_conn.commit()
            except psycopg2.Error as e:
                logging.error("SQL error: {}".format(e))
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
def execute_bash_file(file_path, polder_id, polder_name):
    logging.info('START execute bash file')
    file_name = file_path.split('/')[-1]
    f = open("/code/modelbuilder/logging_" + file_name + ".log", "w")
    subprocess.call(['bash',file_path,polder_id,polder_name], stdout=f)
 
#Define function for executing cmd files        
def execute_cmd_file(file_path, polder_id, polder_name):
    logging.info("START execute cmd file: {}".format(file_path))
    file_path = Path(file_path)
    cmd = file_path.as_posix()
    log_file = work_dir.joinpath(f"code/modelbuilder/logging_{file_path.stem}.log")
    p = subprocess.Popen([cmd, polder_id, polder_name], stdout=subprocess.PIPE).stdout.read()
    log_file.write_bytes(p)   
 
def execute_file(file_path, polder_id, polder_name):    
    if file_path.endswith('.sql'):
        #execute .sql file
        logging.debug('Executing .sql file')
        #result = execute_sql_file_multiple_transactions(file_path)
        result = execute_sql_file_multiple_transactions(file_path, polder_id, polder_name)
    elif file_path.endswith('.sh') and not windows:
        logging.debug('Executing .sh file')

        result = execute_bash_file(file_path)
    elif file_path.endswith('.cmd') and windows:
        logging.debug('Executing .cmd file')
        result = execute_cmd_file(file_path, polder_id, polder_name)
    
    else:
        logging.debug("File is no .sql or .sh file, don't know what to do with it, skipping")

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

def check_polder_contains_data(polder_id):
    try:
        db_conn = psycopg2.connect(host=config['db']['hostname'], dbname=config['db']['database'], user=config['db']['username'], password=config['db']['password'], port=config['db']['port'])
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
    polder_name = polder_name.lower()
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
                if run_file.is_file():
                    run_file.unlink()
        else:
            logging.info("No channels found in polder, stopping the modelbuilder")
        logging.info("Stopping modelbuilder")
        if run_file.is_file():
            run_file.unlink()
    
    else:
        result = execute_file(file_path, polder_id, polder_name)


def main():
    try:
        return modelbuilder(**vars(get_parser().parse_args()))
    except SystemExit:
        raise  # argparse does this

if __name__ == "__main__":
    POLDERDICT = {
        1: ("Heerhugowaard", ("03150","03350")),
        2: ("Drieban", ("6090")),
        3: ("Purmer", ("5801","5802","5803")),
        4: ("Grootlimmerpolder", ("04230","04290","04300")),
        5: ("Koegras", ("2060","2040","2010","20601")),
        6: ("Marken", ("5160")),
        7: ("HUB", ("04310","04320","04541","04542")),
        8: ("Beemster", ("5400","5401")),
        9: ("VNK", ("6750")),
        10: ("t Hoekje", ("2020","2040")),
        11: ("Assendelft", ("04751","04752","04380")),
        12: ("Grootslag", ("6700","6770","6780","6080")),
        13: ("Heiloo", ("04170","04650","04160","04200")),
        14: ("Purmerend", ("5741","5742","5721","5722","5841","5842","5320")),
        15: ("Starnmeer", ("04460")),
        16: ("Eijerland", ("8040","8071")),
        17: ("Mijzen", ("04520")),
        18: ("Oudorp", ("03765")),
        20: ("Wijdewormer", ("5310")),
        21: ("Noorderkaag", ("03703")),
        23: ("Edam Volendam Katwoude", ("5360","5781","5761","5762","5782")),
        24: ("VRNK-Oost", ("2100","2110","03190","03200","03210","6753")),
        25: ("Wieringermeer", ("7701","7702","7703","7704")),
        26: ("Binnenduinrand Egmond", ("04100","04150","04902","04220","04902-00")),
        27: ("Geestmerambacht", ("03764","03751","03240","03801","03802","03763","03300","03752")),
        28: ("Waterland", ("5170","5470","5821","5480","5230","5240","5560","5220","5180","5410","5250","5440","5500","5150","5510","5260","5520","5822","5200","5490","5210","5530","5540","5550","5570","5460","5600","5610","5620","5580","5390","5171")),
        29: ("Schermer", ("04851","04852","04853")),
        30: ("Zijpe-West", ("2751","2752","2775","2754","2780","2779","2050","2756")),
        31: ("Oosterpolder Hoorn", ("6110","6100")),
        32: ("Westzaan", ("04400","04390")),
        33: ("Bergermeer", ("04070","04080","04090","04952","04953","04640")),
        34: ("Wieringerwaard", ("2080")),
        35: ("Schagerkogge", ("03010","03020","03030","03040","03050","03060","03701","03702")),
        36: ("Zeevang", ("5701","5702","5703","5704","5705")),
        37: ("Westerkogge", ("6130")),
        38: ("Alkmaardermeerpolders", ("04250","04280","04260","04420","04270", "04240")),
        39: ("Wieringen", ("2851","2852","2854","2855","2856")),
        40: ("Zijpe-Zuid", ("2757","2758","2759","2781","2763","2764","2765","2766")),
        41: ("Egmondermeer", ("04130","04110","04951")),
        42: ("Oostzaan", ("5330","5340")),
        43: ("HOUW (Wohoobur)", ("6180","6190","6200","6210")),
        44: ("Zijpe-Noord", ("2767","2768","2772","2769","2773","2774","2120")),
        45: ("Callantsoog", ("2030","2040")),
        46: ("Bergen-Noord", ("04010","04020","04030","04040","04050","04060")),
        47: ("Berkmeer e.o.", ("6230","6240","03130","03140")),
        48: ("Valkkoog en Schagerwaard", ("03080","03090")),
        49: ("Waar Woud Spek eet", ("03100","03110","03120","03340")),
        50: ("Wormer", ("5270","5280","5290","5300")),
        51: ("Eilandspolder", ("04801","04802","04803","04804","04470")),
        53: ("VRNK-West", ("03160","03170","03180","03070")),
        54: ("Anna Paulowna", ("2803","2804","2805")),
        55: ("NZK-polders", ("04340","04580","04590","04610","04410")),
        56: ("Beetskoog", ("5010","5020","5030","5040","5050","5080")),
        57: ("Texel-Zuid", ("8010","8020","8030","8071")),
    }
    
    polder_id = 54
#%%    
polder_name_laundered = re.sub('[^a-zA-Z0-9]', "_", POLDERDICT[polder_id][0]).lower()
print(f"Modelbuilder begint met polder '{polder_name_laundered}' (ID {polder_id})")
modelbuilder(polder_id=str(polder_id), polder_name=polder_name_laundered)  # main()
print(f"Modelbuilder klaar met polder '{polder_name_laundered}' (ID {polder_id})")

# modelbuilder(polder_id="45", polder_name="callantsoog")
# %%
