#!/bin/bash

set -e
set -u

function create_user_and_database() {
    local database=$(echo $1 | tr ',' ' ' | awk  '{print $1}')
    local owner=$(echo $1 | tr ',' ' ' | awk  '{print $2}')
    echo "  Creating user and database '$database'"
    mysql -v ON_ERROR_STOP=1 --username "$MARIADB_USER" <<-EOSQL
        CREATE USER $owner WITH PASSWORD '$owner';
        CREATE DATABASE $database;
        GRANT ALL PRIVILEGES ON DATABASE $database TO $owner;
EOSQL
}

if [ -n "$MARIADB_MULTIPLE_DATABASES" ]; then
    echo "Multiple database creation requested: $MARIADB_MULTIPLE_DATABASES"
    for db in $(echo $MARIADB_MULTIPLE_DATABASES | tr ':' ' '); do
        create_user_and_database $db
    done
    echo "Multiple databases created"
fi
