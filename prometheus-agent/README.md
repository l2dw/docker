# prometheus-agent

Prometheus in **agent mode** + node-exporter on one node; pushes node metrics (`remote_write`, basic auth) to a central Prometheus (`--web.enable-remote-write-receiver`).

## Usage
```sh
make prometheus-agent-setup        # create prometheus-agent/.env, sync network
make prometheus-agent-stack-up     # Swarm (docker stack deploy does not read env_file: use Make export + environment:)
make prometheus-agent-compose-up   # Compose
make prometheus-agent-debug
```
Required: `PROMETHEUS_AGENT_CLUSTER` (node label), `PROMETHEUS_AGENT_REMOTE_WRITE_URL`, `PROMETHEUS_AGENT_REMOTE_WRITE_USERNAME` and the secret `PROMETHEUS_AGENT_REMOTE_WRITE_PASSWORD` in the file referenced by `PROMETHEUS_AGENT_ENV_FILE` (0600, outside Git). `environment:` overrides `env_file`.

## Notes
- The scrape/remote_write config is rendered at container start from environment variables (no config file or Docker secret to mount: works on hosts where bind-mounted files of the Git checkout are not reachable by the daemon). The password is written to `/tmp` inside the container.
- No Traefik, no published port, no base path. `compose.yml` and `docker-compose.yml` are identical (Homepage labels on both).
- cAdvisor and blackbox are not included (see the `prometheus` stack for the central ones).

## Networks
Default: stack-local `prometheus-agent-network` (`DEFAULT_NETWORK_EXTERNAL=false`, created by `make prometheus-agent-setup`); `dokploy-network` ⇒ `EXTERNAL=true`.

## Volumes
Compose key `data` → `/prometheus` (agent WAL). Recipes via `PROMETHEUS_AGENT_DATA_VOLUME_*`: local named (default), bind (`TYPE=none OPTS=bind PATH=/srv/...`), NFS (`TYPE=nfs OPTS=addr=<host>,rw PATH=:/export/...`), external (`EXTERNAL=true`, `docker volume create prometheus_agent_data`). On rootless Podman create the volume beforehand without options.
