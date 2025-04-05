#!/bin/bash
# https://github.com/MartinKaburu/docker-postgresql-multiple-databases/blob/master/create-multiple-postgresql-databases.sh
# Create databases and users for PostgreSQL
# This script is intended to be run inside a PostgreSQL Docker container
# It creates databases and users based on the environment variable POSTGRES_MULTIPLE_DATABASES
# The variable should be set in the format: "db1,owner1:db2,owner2:db3,owner3"
# Each database and owner pair should be separated by a colon (:)
# The database name and owner name should be separated by a comma (,)
# Example: "db1,owner1:db2,owner2:db3,owner3"
# This script is executed as part of the PostgreSQL Docker container startup process
# It is executed after the PostgreSQL server has been initialized
# and is ready to accept connections
# The script uses the psql command-line utility to execute SQL commands
# It connects to the PostgreSQL server using the default user (postgres)
# and creates the specified databases and users
# The script also grants all privileges on the created databases to the corresponding owners
# The script is designed to be idempotent, meaning it can be run multiple times
# without causing any issues
# It checks if the POSTGRES_MULTIPLE_DATABASES variable is set
# and only executes the database creation commands if it is set
# The script also uses the set -e and set -u options to ensure that
# it exits immediately if any command fails (set -e)
# and treats unset variables as an error (set -u)
# The script is intended to be run as the root user
# inside the PostgreSQL Docker container
set -e
set -u

function create_user_and_database() {
    local database=$(echo $1 | tr ',' ' ' | awk  '{print $1}')
    local owner=$(echo $1 | tr ',' ' ' | awk  '{print $2}')
    echo "  Creating user and database '$database'"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE USER $owner WITH PASSWORD '$owner';
        CREATE DATABASE $database;
        GRANT ALL PRIVILEGES ON DATABASE $database TO $owner;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ':' ' '); do
        create_user_and_database $db
    done
    echo "Multiple databases created"
fi
