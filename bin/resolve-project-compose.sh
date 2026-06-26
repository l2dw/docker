#!/usr/bin/env sh
# Resolve compose paths for a project directory.
# Optional env: COMPOSE_FILE, COMPOSE_OVERRIDE (explicit paths; skip auto-discovery when set).
set -eu

prj="${1:?project directory name required}"
compose="${COMPOSE_FILE:-}"
override="${COMPOSE_OVERRIDE:-}"

if [ -z "$compose" ]; then
	if [ -f "$prj/stack-compose.yml" ]; then
		compose="$prj/stack-compose.yml"
	elif [ -f "$prj/docker-compose.yml" ] || [ -L "$prj/docker-compose.yml" ]; then
		compose="$prj/docker-compose.yml"
	fi
fi

if [ -z "$override" ]; then
	if [ -f "$prj/stack-compose.override.yml" ] || [ -L "$prj/stack-compose.override.yml" ]; then
		override="$prj/stack-compose.override.yml"
	elif [ -f "$prj/docker-compose.override.yml" ] || [ -L "$prj/docker-compose.override.yml" ]; then
		override="$prj/docker-compose.override.yml"
	fi
fi

env_file=""
if [ -f "$prj/.env" ]; then
	env_file="$prj/.env"
fi

printf 'compose=%q\noverride=%q\nenv_file=%q\n' "$compose" "$override" "$env_file"
