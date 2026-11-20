# elastic-agent

Elastic Agent enrolled in Fleet to collect **node metrics** (System + Docker integrations) and ship them to Elasticsearch (read them in Kibana).

## Usage
```sh
make elastic-agent-setup           # create elastic-agent/.env, sync network
make elastic-agent-stack-up        # Swarm   (docker stack deploy does not read env_file: use Make export + environment:)
make elastic-agent-compose-up      # Compose
make elastic-agent-debug           # services / tasks
```
Required: `ELASTIC_AGENT_FLEET_URL` (Fleet Server URL seen from the node), `ELASTIC_AGENT_HOSTNAME` (node name) and the secret `FLEET_ENROLLMENT_TOKEN` in the file referenced by `ELASTIC_AGENT_ENV_FILE` (0600, outside Git). `environment:` overrides `env_file`.

## Notes
- No Traefik, no HTTP port, no base path (the agent only makes outbound connections). Homepage labels are kept on both compose files (`compose.yml` and `docker-compose.yml` are identical).
- The host root is mounted read-only on `/hostfs`; set `system.hostfs: /hostfs` in the Fleet System integration. `pid: host` exposes host processes (rootless Podman: only the user's own).
- Docker integration: mount the runtime socket (`ELASTIC_AGENT_DOCKER_SOCK`; rootless Podman: `/run/user/<uid>/podman/podman.sock`).

## Networks
Default: stack-local `elastic-agent-network` (`DEFAULT_NETWORK_EXTERNAL=false`, created by `make elastic-agent-setup`). To join the shared overlay set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true` (`docker network create -d overlay dokploy-network` if absent).

## Volumes
Compose key `data` → `/usr/share/elastic-agent/state` (agent identity). Recipes via `ELASTIC_AGENT_DATA_VOLUME_*`: local named (default), bind (`TYPE=none OPTS=bind PATH=/srv/...`), NFS (`TYPE=nfs OPTS=addr=<host>,rw PATH=:/export/...`), external (`EXTERNAL=true`, `docker volume create elastic_agent_data`). On rootless Podman create the volume beforehand without options.
