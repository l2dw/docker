#!/bin/sh
# Render config/teleport.yaml from the example (Dokploy pre-deploy / CI).
# Reads TELEPORT_CLUSTER_NAME, TELEPORT_PUBLIC_ADDR, TELEPORT_DOMAIN from the environment.
set -eu

cd "$(dirname "$0")"

cluster="${TELEPORT_CLUSTER_NAME:-}"
paddr="${TELEPORT_PUBLIC_ADDR:-}"
domain="${TELEPORT_DOMAIN:-teleport.example.com}"

[ -n "$cluster" ] || cluster="$domain"
[ -n "$paddr" ] || paddr="${domain}:443"

src="config/teleport.yaml.example"
dst="config/teleport.yaml"

if [ ! -f "$src" ]; then
	echo "Error: missing $src" >&2
	exit 1
fi

if command -v python3 >/dev/null 2>&1 && [ -f render-config.py ]; then
	python3 render-config.py "$src" "$dst" "$cluster" "$paddr"
else
	sed -e "s/^\([[:space:]]*cluster_name:\).*/\1 ${cluster}/" \
		-e "s/^\([[:space:]]*public_addr:\).*/\1 ${paddr}/" \
		"$src" > "$dst"
fi

echo "Wrote ${dst} (cluster_name=${cluster} public_addr=${paddr})"
