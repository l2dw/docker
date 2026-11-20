# Kibana

[Kibana](https://www.elastic.co/kibana) 8.17 (image `docker.io/library/kibana`) — UI for Elasticsearch / Fleet. Does not run Traefik/WAF or Elasticsearch (join the same network; use the Dokploy overlay when needed).

```sh
make kibana-setup \
  KIBANA_DOMAIN=kibana.example.com \
  KIBANA_APP_URL=http://kibana.example.com/kibana
make kibana-stack-up      # Swarm
# or
make kibana-compose-up    # Compose
```

`docker stack deploy` does not read `.env` alone — use Make (root `.env` is exported). Compose loads `env_file` (`KIBANA_ENV_FILE`, default `.env.example`; production: `KIBANA_ENV_FILE=.env`); `environment:` wins over the file. Swarm relies on Make-exported root `.env` + `environment:` interpolation (`env_file` is not equivalent under `docker stack deploy`). Router/service Traefik names use `APP_NAME` (`APP_NAME=kibana` in `.env.example`; Dokploy may override).

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | Homepage only |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage — used by `make` |

## Base path

Supported by Kibana (`SERVER_BASEPATH` + `SERVER_REWRITEBASEPATH=true`). Default `KIBANA_BASE_PATH=/kibana` (Traefik) and `KIBANA_SERVER_BASE_PATH=/kibana` (Kibana) — keep them aligned; `KIBANA_SERVER_REWRITE_BASE_PATH=true`. Host-only: set both to empty or `/` for Traefik, `KIBANA_SERVER_BASE_PATH=` and `KIBANA_SERVER_REWRITE_BASE_PATH=false` for Kibana. No Traefik strip prefix.

## Configuration

Required secrets (names only; placeholders in `.env.example`): `KIBANA_ELASTICSEARCH_PASSWORD` (password of the `kibana_system` user — set it on Elasticsearch first), `KIBANA_XPACK_SECURITY_ENCRYPTION_KEY`, `KIBANA_XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTION_KEY`, `KIBANA_XPACK_REPORTING_ENCRYPTION_KEY` (≥ 32 characters; `make kibana-setup` generates them when still `ChangeMe…`). Elasticsearch target: `KIBANA_ELASTICSEARCH_HOSTS` (default `http://elasticsearch:9200`, alias provided by the elasticsearch stack on the shared network). Extra Kibana settings can be added as environment variables in the file named by `KIBANA_ENV_FILE` (e.g. Fleet air-gapped mode and registry proxy).

## Networks

Default: stack-local network `kibana-network` (`DEFAULT_NETWORK_EXTERNAL=false`); `make kibana-setup` creates it (overlay for Swarm, bridge for Compose). To join the shared Dokploy overlay (Traefik, other stacks):

```sh
DEFAULT_NETWORK_NAME=dokploy-network   # setup then sets DEFAULT_NETWORK_EXTERNAL=true
```

Pairing rule: only `dokploy-network` ⇒ `EXTERNAL=true`; any other name ⇒ `false`. Manual create: `docker network create --driver overlay kibana-network` (Swarm) or `--driver bridge` (Compose).

## Volumes

Compose volume key `data` → `/usr/share/kibana/data`. Choose with `KIBANA_DATA_VOLUME_*`:

| Recipe | Variables |
|--------|-----------|
| Local named (default) | `EXTERNAL=false`, `TYPE=`, `OPTS=`, `PATH=` |
| Bind | `TYPE=none`, `OPTS=bind`, `PATH=/appdata/kibana` (directory must exist on the node) |
| NFS | `TYPE=nfs`, `OPTS=addr=nfs-host,rw,nfsvers=4`, `PATH=:/exports/kibana` |
| External | `EXTERNAL=true` after `docker volume create kibana_data` |

## Make targets

`kibana-setup`, `kibana-stack-up|down|recreate|upgrade|logs`, `kibana-compose-up|down|restart|recreate|logs`, `kibana-debug`, `kibana-debug-logs`, `kibana-pull-images`.
