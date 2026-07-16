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

role_exists="$(docker_cmd exec "${cid}" psql -U postgres -d postgres -tAc \
	"SELECT 1 FROM pg_roles WHERE rolname = :'db_user';" \
	-v db_user="${DB_USER}")"

if [ "${role_exists}" != "1" ]; then
	echo "Creating role ${DB_USER} ..."
	docker_cmd exec "${cid}" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
		-v db_user="${DB_USER}" -v db_pass="${DB_PASS}" \
		-c "CREATE USER :\"db_user\" WITH PASSWORD :'db_pass';"
else
	echo "Role ${DB_USER} already exists."
fi

db_exists="$(docker_cmd exec "${cid}" psql -U postgres -d postgres -tAc \
	"SELECT 1 FROM pg_database WHERE datname = :'db_name';" \
	-v db_name="${DB_NAME}")"

if [ "${db_exists}" != "1" ]; then
	echo "Creating database ${DB_NAME} ..."
	docker_cmd exec "${cid}" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
		-v db_name="${DB_NAME}" -v db_user="${DB_USER}" \
		-c "CREATE DATABASE :\"db_name\" OWNER :\"db_user\";"
else
	echo "Database ${DB_NAME} already exists."
fi
