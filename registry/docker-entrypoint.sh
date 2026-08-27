#!/bin/sh
# Generate htpasswd from REGISTRY_USER_NAME / REGISTRY_USER_PASS, then start registry.
# No host-side make/htpasswd required (Dokploy / plain stack deploy).
set -eu

AUTH_PATH="${REGISTRY_AUTH_HTPASSWD_PATH:-/auth/htpasswd}"
USER_NAME="${REGISTRY_USER_NAME:-dockeradm}"
USER_PASS="${REGISTRY_USER_PASS:-ChangeMe}"

# Docker secrets mounts are read-only — always write under /auth when using env credentials.
case "$AUTH_PATH" in
  /run/secrets/* | "")
    AUTH_PATH=/auth/htpasswd
    ;;
esac

mkdir -p "$(dirname "$AUTH_PATH")"

if [ -n "$USER_NAME" ] && [ -n "$USER_PASS" ]; then
  if ! command -v htpasswd >/dev/null 2>&1; then
    apk add --no-cache apache2-utils >/dev/null
  fi
  htpasswd -Bbn "$USER_NAME" "$USER_PASS" > "$AUTH_PATH"
  chmod 600 "$AUTH_PATH" || true
  if [ "$USER_PASS" = "ChangeMe" ]; then
    echo "registry: warning: REGISTRY_USER_PASS is still ChangeMe — rotate it in .env" >&2
  fi
elif [ ! -s "$AUTH_PATH" ]; then
  echo "registry: set REGISTRY_USER_NAME and REGISTRY_USER_PASS (or provide a non-empty htpasswd at $AUTH_PATH)" >&2
  exit 1
fi

export REGISTRY_AUTH="${REGISTRY_AUTH:-htpasswd}"
export REGISTRY_AUTH_HTPASSWD_PATH="$AUTH_PATH"
export REGISTRY_AUTH_HTPASSWD_REALM="${REGISTRY_AUTH_HTPASSWD_REALM:-Registry Realm}"

exec /entrypoint.sh /etc/docker/registry/config.yml
