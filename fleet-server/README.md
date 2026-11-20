# Fleet Server

[Elastic Fleet Server](https://www.elastic.co/guide/en/fleet/8.17/fleet-server.html) 8.17 (image `docker.elastic.co/beats/elastic-agent`). Does not run Elasticsearch/Kibana/Traefik/WAF. The former `docker-fleet-server` APM listener (:8200, `/apm`) is not part of this stack.

```sh
make fleet-server-setup \
  FLEET_SERVER_DOMAIN=fleet-server.example.com \
  FLEET_SERVER_APP_URL=http://fleet-server.example.com/fleet
make fleet-server-stack-up      # Swarm
# or
make fleet-server-compose-up    # Compose
```

`docker stack deploy` does not read `.env` alone — use Make (root `.env` is exported). Compose loads `env_file` (`FLEET_SERVER_ENV_FILE`, default `.env.example`; production: `FLEET_SERVER_ENV_FILE=.env`); `environment:` wins over the file. Swarm relies on Make-exported root `.env` + `environment:` interpolation (`env_file` is not equivalent under `docker stack deploy`). Router/service Traefik names use `APP_NAME` (`APP_NAME=fleet-server` in `.env.example`; Dokploy may override).

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | Homepage only |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage — used by `make` |

## Base path

Fleet Server has no native base path. Default `FLEET_SERVER_BASE_PATH=/fleet` with a Traefik `stripPrefix` middleware named `${APP_NAME}-strip`. Host-only: set `FLEET_SERVER_BASE_PATH=/` (the strip is then a no-op).

## Configuration

Required secret (name only): `FLEET_SERVER_SERVICE_TOKEN` — create the Fleet Server policy and service token in Kibana (Fleet → Settings), then set it in the env file or Dokploy. `FLEET_SERVER_POLICY` is the policy id, `FLEET_SERVER_ELASTICSEARCH_HOST` defaults to `http://elasticsearch:9200`. `FLEET_SERVER_INSECURE_HTTP=true` makes Fleet Server listen in plain HTTP (needed behind the Traefik HTTP route); default `false` keeps the agent default (HTTPS).

## Networks

Default: stack-local network `fleet-server-network` (`DEFAULT_NETWORK_EXTERNAL=false`); `make fleet-server-setup` creates it (overlay for Swarm, bridge for Compose). To join the shared Dokploy overlay (Traefik, other stacks):

```sh
DEFAULT_NETWORK_NAME=dokploy-network   # setup then sets DEFAULT_NETWORK_EXTERNAL=true
```

Pairing rule: only `dokploy-network` ⇒ `EXTERNAL=true`; any other name ⇒ `false`. Manual create: `docker network create --driver overlay fleet-server-network` (Swarm) or `--driver bridge` (Compose).

## Volumes

Compose volume key `data` → `/usr/share/elastic-agent/state`. Choose with `FLEET_SERVER_DATA_VOLUME_*`:

| Recipe | Variables |
|--------|-----------|
| Local named (default) | `EXTERNAL=false`, `TYPE=`, `OPTS=`, `PATH=` |
| Bind | `TYPE=none`, `OPTS=bind`, `PATH=/appdata/fleet-server` (directory must exist on the node) |
| NFS | `TYPE=nfs`, `OPTS=addr=nfs-host,rw,nfsvers=4`, `PATH=:/exports/fleet-server` |
| External | `EXTERNAL=true` after `docker volume create fleet_server_data` |

## Make targets

`fleet-server-setup`, `fleet-server-stack-up|down|recreate|upgrade|logs`, `fleet-server-compose-up|down|restart|recreate|logs`, `fleet-server-debug`, `fleet-server-debug-logs`, `fleet-server-pull-images`.
