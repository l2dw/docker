#!/bin/sh
set -eu
: "${KEYCLOAK_DB_PASSWORD:?KEYCLOAK_DB_PASSWORD is required}"
# The generated password is alphanumeric; refuse unexpected input before
# emitting the psql variable to stdin, never through a process argument.
case "$KEYCLOAK_DB_PASSWORD" in *[!a-zA-Z0-9]*|'') exit 1;; esac
{
  printf "\\set kc_password '%s'\n" "$KEYCLOAK_DB_PASSWORD"
  printf "%s\n" "CREATE ROLE keycloak LOGIN PASSWORD :'kc_password';" "CREATE DATABASE keycloak OWNER keycloak;"
} | psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1
