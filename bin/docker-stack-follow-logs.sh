#!/bin/sh
# Follow logs for each Swarm service (`docker stack logs` unavailable; one `docker service logs` per SERVICE).
set -eu
DOCKER="${DOCKER:-docker}"
STACK_NAME="${1:?stack name}"
TAIL_LINES="${STACK_LOG_TAIL:-100}"
EXTRA=${STACK_LOG_ARGS:-}

svc_list="$($DOCKER service ls \
	--filter "label=com.docker.stack.namespace=$STACK_NAME" \
	--format '{{.Name}}' 2>/dev/null)"
if [ -z "$svc_list" ]; then
	svc_list="$($DOCKER stack services "$STACK_NAME" --format '{{.Name}}' 2>/dev/null)" || svc_list=""
fi

svc_list=$(printf '%s' "$svc_list" | tr -d '\015')

if [ -z "$svc_list" ]; then
	echo >&2 "No services for stack $STACK_NAME (deploy the stack or check DOCKER_* / swarm)."
	exit 1
fi

while IFS= read -r svc || [ -n "$svc" ]; do
	[ -z "$svc" ] && continue
	$DOCKER service logs "$svc" --follow --tail "$TAIL_LINES" $EXTRA &
done <<EOF
$svc_list
EOF

wait
