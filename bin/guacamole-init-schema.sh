#!/usr/bin/env bash
# Load Guacamole JDBC schema into an existing Postgres DB (idempotent).
# Requires: DB_USER, DB_PASS, DB_NAME
# Optional: PG_SERVICE, GUACAMOLE_IMAGE (default guacamole/guacamole:1.6.0)

set -euo pipefail

source "$(dirname "$0")/utils.sh"

: "${DB_USER:?Missing DB_USER}"
: "${DB_PASS:?Missing DB_PASS}"
: "${DB_NAME:?Missing DB_NAME}"

GUACAMOLE_IMAGE="${GUACAMOLE_IMAGE:-docker.io/guacamole/guacamole:1.6.0}"

resolve_pg_cid() {
	local svc cid
	if [ -n "${PG_SERVICE:-}" ]; then
		cid="$(docker_cmd ps -q --filter "label=com.docker.swarm.service.name=${PG_SERVICE}" | head -n 1)"
		[ -n "${cid}" ] && { echo "${cid}"; return 0; }
		echo "Error: no running container for PG_SERVICE=${PG_SERVICE}." >&2
		return 1
	fi
	for svc in dokploy_postgresql infrastructure_postgresql; do
		cid="$(docker_cmd ps -q --filter "label=com.docker.swarm.service.name=${svc}" | head -n 1)"
		[ -n "${cid}" ] && { echo "${cid}"; return 0; }
	done
	cid="$(docker_cmd ps -q --filter "name=postgresql" | head -n 1)"
	[ -n "${cid}" ] && { echo "${cid}"; return 0; }
	echo "Error: no running PostgreSQL container found." >&2
	return 1
}

cid="$(resolve_pg_cid)"
echo "Using postgresql task container: ${cid}"

# Prefer app role; fall back to postgres superuser if auth fails (then reassign).
psql_as() {
	local user="$1"
	shift
	PGPASSWORD="${DB_PASS}" docker_cmd exec -e PGPASSWORD -i "${cid}" \
		psql -U "${user}" -d "${DB_NAME}" "$@"
}

has_schema="$(psql_as postgres -tA <<'EOSQL' 2>/dev/null || true
SELECT 1 FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'guacamole_entity';
EOSQL
)"

if [ "${has_schema}" = "1" ]; then
	echo "Guacamole schema already present in ${DB_NAME} — skipping initdb."
	exit 0
fi

echo "Loading Guacamole schema into ${DB_NAME} (image ${GUACAMOLE_IMAGE}) ..."
tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT
docker_cmd run --rm "${GUACAMOLE_IMAGE}" /opt/guacamole/bin/initdb.sh --postgresql >"${tmp}"

if ! PGPASSWORD="${DB_PASS}" docker_cmd exec -e PGPASSWORD -i "${cid}" \
	psql -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 -f - <"${tmp}"; then
	echo "Load as ${DB_USER} failed — retrying as postgres then fixing ownership." >&2
	docker_cmd exec -i "${cid}" psql -U postgres -d "${DB_NAME}" -v ON_ERROR_STOP=1 -f - <"${tmp}"
	docker_cmd exec -i "${cid}" psql -U postgres -d "${DB_NAME}" -v ON_ERROR_STOP=1 \
		-v db_user="${DB_USER}" -v db_name="${DB_NAME}" <<'EOSQL'
ALTER DATABASE :"db_name" OWNER TO :"db_user";
REASSIGN OWNED BY CURRENT_USER TO :"db_user";
GRANT ALL ON SCHEMA public TO :"db_user";
EOSQL
fi

echo "Guacamole schema loaded (default login guacadmin / guacadmin — change immediately)."
