#!/usr/bin/env bash
# Verify the dokploy podman/docker-compose stack is healthy.
# Exit 0 only when required containers are running and probes succeed.
#
# Env (optional, usually from .env via make):
#   DOCKER, DOKPLOY_STACK_NAME, DOKPLOY_DOMAIN
#   DOKPLOY_TRAEFIK_PORT80_PUBLISHED, DOKPLOY_POSTGRES_USER
#   DOKPLOY_HEALTHCHECK_SKIP_WAF=1  — ignore WAF (optional sidecar)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/utils.sh"

PROJECT="${DOKPLOY_STACK_NAME:-dokploy}"
DOMAIN="${DOKPLOY_DOMAIN:-dokploy.home}"
HTTP_PORT="${DOKPLOY_TRAEFIK_PORT80_PUBLISHED:-80}"
PG_USER="${DOKPLOY_POSTGRES_USER:-dokploy}"
SKIP_WAF="${DOKPLOY_HEALTHCHECK_SKIP_WAF:-0}"

# Prefer explicit DOCKER from make/.env (e.g. podman); fall back to utils discovery.
if [ -n "${DOCKER:-}" ]; then
	runtime() { "${DOCKER}" "$@"; }
else
	runtime() { docker_cmd "$@"; }
fi

pass=0
fail=0
warn=0

ok() {
	pass=$((pass + 1))
	printf '  OK   %s\n' "$*"
}

bad() {
	fail=$((fail + 1))
	printf '  FAIL %s\n' "$*" >&2
}

note() {
	warn=$((warn + 1))
	printf '  WARN %s\n' "$*" >&2
}

container_name() {
	# podman-compose / docker-compose classic: <project>_<service>_1
	printf '%s_%s_1' "${PROJECT}" "$1"
}

container_state() {
	local name="$1"
	runtime inspect -f '{{.State.Status}}' "${name}" 2>/dev/null || printf 'missing'
}

container_health() {
	local name="$1"
	runtime inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${name}" 2>/dev/null || printf 'missing'
}

require_running() {
	local service="$1"
	local name
	name="$(container_name "${service}")"
	local state
	state="$(container_state "${name}")"
	if [ "${state}" = "running" ]; then
		ok "${name} is running"
		return 0
	fi
	bad "${name} state=${state} (expected running)"
	return 1
}

http_code() {
	# usage: http_code URL [extra curl args...]
	# Always print a 3-digit code (curl already writes 000 on connect failure; do not append again).
	local url="$1"
	shift
	local code
	code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "$@" "${url}" 2>/dev/null || true)"
	printf '%s' "${code:-000}"
}

# Same as http_code, but via `runtime exec` inside a container.
container_http_code() {
	local name="$1"
	local url="$2"
	local code
	code="$(runtime exec "${name}" curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 "${url}" 2>/dev/null || true)"
	printf '%s' "${code:-000}"
}

echo "Dokploy compose healthcheck (project=${PROJECT})"
echo

echo "Containers"
SERVICES=(postgresql redis dokploy traefik certs-dumper)
for svc in "${SERVICES[@]}"; do
	require_running "${svc}" || true
done

waf_name="$(container_name waf)"
waf_state="$(container_state "${waf_name}")"
if [ "${SKIP_WAF}" = "1" ]; then
	note "${waf_name} skipped (DOKPLOY_HEALTHCHECK_SKIP_WAF=1), state=${waf_state}"
elif [ "${waf_state}" = "running" ]; then
	ok "${waf_name} is running"
else
	bad "${waf_name} state=${waf_state} (expected running; fix log dir ownership or set DOKPLOY_HEALTHCHECK_SKIP_WAF=1)"
fi
echo

echo "Probes"
pg_name="$(container_name postgresql)"
if [ "$(container_state "${pg_name}")" = "running" ]; then
	if runtime exec "${pg_name}" pg_isready -U "${PG_USER}" >/dev/null 2>&1; then
		ok "postgresql pg_isready (-U ${PG_USER})"
	else
		bad "postgresql pg_isready failed"
	fi
else
	bad "postgresql probe skipped (not running)"
fi

redis_name="$(container_name redis)"
if [ "$(container_state "${redis_name}")" = "running" ]; then
	health="$(container_health "${redis_name}")"
	case "${health}" in
		healthy|none)
			if [ "${health}" = "healthy" ]; then
				ok "redis health=${health}"
			fi
			;;
		*)
			bad "redis health=${health}"
			;;
	esac
	pong="$(runtime exec "${redis_name}" redis-cli ping 2>/dev/null || true)"
	if [ "${pong}" = "PONG" ]; then
		ok "redis PING -> PONG"
	else
		bad "redis PING failed (got: ${pong:-empty})"
	fi
else
	bad "redis probe skipped (not running)"
fi

dokploy_name="$(container_name dokploy)"
if [ "$(container_state "${dokploy_name}")" = "running" ]; then
	code="$(container_http_code "${dokploy_name}" "http://127.0.0.1:3000/")"
	case "${code}" in
		200|301|302|303|307|308)
			ok "dokploy :3000 -> HTTP ${code}"
			;;
		*)
			bad "dokploy :3000 -> HTTP ${code} (expected 2xx/3xx)"
			;;
	esac
else
	bad "dokploy probe skipped (not running)"
fi

traefik_name="$(container_name traefik)"
if [ "$(container_state "${traefik_name}")" = "running" ]; then
	code="$(http_code "http://127.0.0.1:${HTTP_PORT}/" -H "Host: ${DOMAIN}")"
	case "${code}" in
		200|301|302|303|307|308)
			ok "traefik :${HTTP_PORT} Host=${DOMAIN} / -> HTTP ${code}"
			;;
		404)
			bad "traefik :${HTTP_PORT} Host=${DOMAIN} / -> HTTP 404 (router/middleware misconfigured?)"
			;;
		*)
			bad "traefik :${HTTP_PORT} Host=${DOMAIN} / -> HTTP ${code}"
			;;
	esac
else
	bad "traefik probe skipped (not running)"
fi

# CRS apache image listens on 8080/8443 (not 80). 503 is normal with no upstream backend.
if [ "${SKIP_WAF}" != "1" ] && [ "${waf_state}" = "running" ]; then
	code="$(container_http_code "${waf_name}" "http://127.0.0.1:8080/")"
	case "${code}" in
		200|301|302|303|307|308|403|404|503)
			ok "waf :8080 -> HTTP ${code}"
			;;
		*)
			bad "waf :8080 -> HTTP ${code}"
			;;
	esac
fi
echo

echo "Summary: ${pass} ok, ${fail} failed, ${warn} warnings"
if [ "${fail}" -gt 0 ]; then
	exit 1
fi
exit 0
