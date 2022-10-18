import configparser
import psycopg2
#Read configuration file
config = configparser.ConfigParser()
config.read('/code/datachecker/datachecker_config.ini')
print(config)
db_conn = psycopg2.connect(host=config['db']['hostname'], dbname=config['db']['database'], user=config['db']['username'], password=config['db']['password'])
db_cur = db_conn.cursor()
print(db_cur.execute("select nspname from pg_catalog.pg_namespace"))
