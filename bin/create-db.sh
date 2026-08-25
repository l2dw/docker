#!/usr/bin/env bash
# Create PostgreSQL role and database in a Swarm Postgres service.
# Requires: DB_USER, DB_PASS, DB_NAME
# Optional: PG_SERVICE (default: try dokploy_postgresql, then infrastructure_postgresql)

set -euo pipefail

source "$(dirname "$0")/utils.sh"

: "${DB_USER:?Missing DB_USER}"
: "${DB_PASS:?Missing DB_PASS}"
: "${DB_NAME:?Missing DB_NAME}"

resolve_pg_cid() {
	local svc cid
	if [ -n "${PG_SERVICE:-}" ]; then
		cid="$(docker_cmd ps -q --filter "label=com.docker.swarm.service.name=${PG_SERVICE}" | head -n 1)"
		if [ -n "${cid}" ]; then
			echo "${cid}"
			return 0
		fi
		echo "Error: no running container found for Swarm service ${PG_SERVICE}." >&2
		echo "Hint: run: docker service ps ${PG_SERVICE}" >&2
		return 1
	fi
	for svc in dokploy_postgresql infrastructure_postgresql; do
		cid="$(docker_cmd ps -q --filter "label=com.docker.swarm.service.name=${svc}" | head -n 1)"
		if [ -n "${cid}" ]; then
			echo "Auto-detected Postgres service: ${svc}" >&2
			echo "${cid}"
			return 0
		fi
	done
	cid="$(docker_cmd ps -q --filter "name=postgresql" | head -n 1)"
	if [ -n "${cid}" ]; then
		echo "Auto-detected Postgres container by name: ${cid}" >&2
		echo "${cid}"
		return 0
	fi
	echo "Error: no running PostgreSQL container found (tried dokploy_postgresql, infrastructure_postgresql)." >&2
	echo "Hint: set PG_SERVICE=<swarm-service-name> or start Postgres." >&2
	return 1
}

cid="$(resolve_pg_cid)"

echo "Using postgresql task container: ${cid}"

# psql -c does not perform :variable substitution (server parses the string as-is).
# Pipe SQL on stdin so :'name' (string) and :"name" (identifier) work as documented.
psql_run() {
	docker_cmd exec -i "${cid}" psql -U postgres -d postgres "$@"
}

psql_db() {
	docker_cmd exec -i "${cid}" psql -U postgres -d "${DB_NAME}" "$@"
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
	echo "Role ${DB_USER} already exists — syncing password."
	psql_run -v ON_ERROR_STOP=1 -v db_user="${DB_USER}" -v db_pass="${DB_PASS}" <<'EOSQL'
ALTER USER :"db_user" WITH PASSWORD :'db_pass';
EOSQL
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
	echo "Database ${DB_NAME} already exists — ensuring OWNER=${DB_USER}."
	psql_run -v ON_ERROR_STOP=1 -v db_name="${DB_NAME}" -v db_user="${DB_USER}" <<'EOSQL'
ALTER DATABASE :"db_name" OWNER TO :"db_user";
EOSQL
fi

# Ensure app role can use public schema (PG15+ defaults tightened).
psql_db -v ON_ERROR_STOP=1 -v db_user="${DB_USER}" <<'EOSQL'
GRANT ALL ON SCHEMA public TO :"db_user";
ALTER SCHEMA public OWNER TO :"db_user";
EOSQL

echo "Postgres role/DB ready: ${DB_USER} @ ${DB_NAME}"
