# Jaeger

[Jaeger](https://www.jaegertracing.io/) all-in-one 1.76 (image `docker.io/jaegertracing/all-in-one`) with Elasticsearch storage; OTLP/HTTP collector on :4318. Does not run Elasticsearch/Traefik/WAF.

```sh
make jaeger-setup \
  JAEGER_DOMAIN=jaeger.example.com \
  JAEGER_APP_URL=http://jaeger.example.com/jaeger
make jaeger-stack-up      # Swarm
# or
make jaeger-compose-up    # Compose
```

`docker stack deploy` does not read `.env` alone — use Make (root `.env` is exported). Compose loads `env_file` (`JAEGER_ENV_FILE`, default `.env.example`; production: `JAEGER_ENV_FILE=.env`); `environment:` wins over the file. Swarm relies on Make-exported root `.env` + `environment:` interpolation (`env_file` is not equivalent under `docker stack deploy`). Router/service Traefik names use `APP_NAME` (`APP_NAME=jaeger` in `.env.example`; Dokploy may override).

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | Homepage only |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage — used by `make` |

## Base path

Supported (`QUERY_BASE_PATH`). Default `JAEGER_BASE_PATH=/jaeger` (Traefik) and `JAEGER_QUERY_BASE_PATH=/jaeger` (Jaeger) — keep aligned. OTLP/HTTP is exposed on `JAEGER_OTLP_PATH=/otlp` with a Traefik `stripPrefix` middleware named `${APP_NAME}-otlp-strip`. Host-only: set both UI paths to `/` and `JAEGER_QUERY_BASE_PATH=` (empty).

## Configuration

Required secret (name only): `JAEGER_ES_PASSWORD` — password of the Elasticsearch user `JAEGER_ES_USERNAME`. Credentials are separate from `JAEGER_ES_SERVER_URLS` (default `http://elasticsearch:9200`). The `data` volume is unused with Elasticsearch storage (kept for the stack convention / optional local storage).

## Networks

Default: stack-local network `jaeger-network` (`DEFAULT_NETWORK_EXTERNAL=false`); `make jaeger-setup` creates it (overlay for Swarm, bridge for Compose). To join the shared Dokploy overlay (Traefik, other stacks):

```sh
DEFAULT_NETWORK_NAME=dokploy-network   # setup then sets DEFAULT_NETWORK_EXTERNAL=true
```

Pairing rule: only `dokploy-network` ⇒ `EXTERNAL=true`; any other name ⇒ `false`. Manual create: `docker network create --driver overlay jaeger-network` (Swarm) or `--driver bridge` (Compose).

## Volumes

Compose volume key `data` → `/data`. Choose with `JAEGER_DATA_VOLUME_*`:

| Recipe | Variables |
|--------|-----------|
| Local named (default) | `EXTERNAL=false`, `TYPE=`, `OPTS=`, `PATH=` |
| Bind | `TYPE=none`, `OPTS=bind`, `PATH=/appdata/jaeger` (directory must exist on the node) |
| NFS | `TYPE=nfs`, `OPTS=addr=nfs-host,rw,nfsvers=4`, `PATH=:/exports/jaeger` |
| External | `EXTERNAL=true` after `docker volume create jaeger_data` |

## Make targets

`jaeger-setup`, `jaeger-stack-up|down|recreate|upgrade|logs`, `jaeger-compose-up|down|restart|recreate|logs`, `jaeger-debug`, `jaeger-debug-logs`, `jaeger-pull-images`.
