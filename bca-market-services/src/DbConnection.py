from os import getenv, environ
import psycopg2

def db_connection():
    try:
        dbhost: string = getenv('PGHOST','localhost')
        dbport: string = int(getenv('PGPORT','5432'))
        dbname: string = environ['PGDATABASE']
        dbuser: string = environ['PGUSER']
        dbpassword: string = environ['PGPASSWORD']
        with psycopg2.connect(host=dbhost, port=dbport, dbname=dbname, user=dbuser, password=dbpassword) as conn:
            print('Connected to the PostgreSQL server.')
            return conn
    except (psycopg2.DatabaseError, Exception) as error:
        print(f"failed to connect to database: {error}")
