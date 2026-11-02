#!/usr/bin/env bash
# Create PostgreSQL role and database in the infrastructure_postgresql Swarm service.
# Requires: DB_USER, DB_PASS, DB_NAME

set -euo pipefail

source "$(dirname "$0")/utils.sh"

: "${DB_USER:?Missing DB_USER}"
: "${DB_PASS:?Missing DB_PASS}"
: "${DB_NAME:?Missing DB_NAME}"

PG_SERVICE="${PG_SERVICE:-infrastructure_postgresql}"

cid="$(docker_cmd ps -q --filter "label=com.docker.swarm.service.name=${PG_SERVICE}" | head -n 1)"
if [ -z "${cid}" ]; then
	echo "Error: no running container found for Swarm service ${PG_SERVICE}." >&2
	echo "Hint: run: docker service ps ${PG_SERVICE}" >&2
	exit 1
fi

echo "Using postgresql task container: ${cid}"

# psql -c does not perform :variable substitution (server parses the string as-is).
# Pipe SQL on stdin so :'name' (string) and :"name" (identifier) work as documented.
psql_run() {
	docker_cmd exec -i "${cid}" psql -U postgres -d postgres "$@"
}

role_exists="$(psql_run -tA -v db_user="${DB_USER}" <<'EOSQL'
SELECT 1 FROM pg_roles WHERE rolname = :'db_user';
EOSQL
)"

if [ "${role_exists}" != "1" ]; then
	echo "Creating role ${DB_USER} ..."
	psql_run -v ON_ERROR_STOP=1 -v db_user="${DB_USER}" -v db_pass="${DB_PASS}" <<'EOSQL'
CREATE USER :"db_user" WITH PASSWORD :'db_pass';
EOSQL
else
	echo "Role ${DB_USER} already exists."
fi

db_exists="$(psql_run -tA -v db_name="${DB_NAME}" <<'EOSQL'
SELECT 1 FROM pg_database WHERE datname = :'db_name';
EOSQL
)"

if [ "${db_exists}" != "1" ]; then
	echo "Creating database ${DB_NAME} ..."
	psql_run -v ON_ERROR_STOP=1 -v db_name="${DB_NAME}" -v db_user="${DB_USER}" <<'EOSQL'
CREATE DATABASE :"db_name" OWNER :"db_user";
EOSQL
else
	echo "Database ${DB_NAME} already exists."
fi
