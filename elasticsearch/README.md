# Elasticsearch

[Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/8.17/docker.html) **8.17** HTTP API on **TCP 9200**. Single-node (`discovery.type=single-node`), **xpack.security disabled**. Traefik is the Swarm ingress (`docker-compose.yml`); `compose.yml` **publishes 9200** (`ELASTICSEARCH_HTTP_PUBLISHED_PORT`).

Other stacks on the overlay reach it as `dokploy-elasticsearch:9200` (`ELASTICSEARCH_NETWORK_ALIAS`) or `elasticsearch:9200` (Compose service name).

Heap via `ELASTICSEARCH_JAVA_OPTS` (default `-Xms512m -Xmx512m`); container memory limit **1G**. Host: `vm.max_map_count=262144`.

## Quick start

```sh
make elasticsearch-setup
# Edit elasticsearch/.env — ELASTICSEARCH_DOMAIN / ELASTICSEARCH_APP_URL
make elasticsearch-stack-up      # Swarm
# or
make elasticsearch-compose-up    # Compose
```

Debug: `make elasticsearch-debug` / `make elasticsearch-debug-logs`.

`docker stack deploy` does **not** load Compose `env_file` reliably — use Make (exports root `.env`) + `environment:` interpolation.

## Base path

Elasticsearch has **no native HTTP base path**. Public routing is Traefik only.


| `ELASTICSEARCH_BASE_PATH`  | Traefik               | `ELASTICSEARCH_MIDDLEWARES`                                             |
| -------------------------- | --------------------- | ----------------------------------------------------------------------- |
| `/elasticsearch` (default) | `Host` + `PathPrefix` | `elasticsearch-strip` (required — ES must not see `/elasticsearch/...`) |
| `/` or empty               | Host-only             | **empty** — do **not** strip `/`                                        |


`make elasticsearch-setup` turns an empty `ELASTICSEARCH_BASE_PATH` into `/` and clears middlewares. Align `ELASTICSEARCH_APP_URL` with the public URL. If Dokploy sets `APP_NAME`, set `ELASTICSEARCH_MIDDLEWARES` to `${APP_NAME}-strip`.

## Health (`green`)

Healthcheck: `/_cluster/health?wait_for_status=green`. An empty single-node cluster is green. Do **not** pass `index.number_of_shards` / `index.number_of_replicas` as process env — Elasticsearch rejects them as unknown node settings. Replica count is an **index** setting (templates / index create), not a node env var.

## Traefik / Homepage

Labels: Traefik only in `docker-compose.yml`. Homepage on both compose files. `APP_NAME` scopes Traefik router/service/middleware names. Long-form `ports:` for **9200** on `compose.yml` only.

## env_file

`ELASTICSEARCH_ENV_FILE` (default `.env.example`). Production → `.env`. `environment:` overrides. Swarm: Make-exported root `.env`.

## Networks


| Goal                  | `DEFAULT_NETWORK_NAME`  | `EXTERNAL` |
| --------------------- | ----------------------- | ---------- |
| Stack-local (default) | `elasticsearch-network` | `false`    |
| Shared Traefik / apps | `dokploy-network`       | `true`     |


`make elasticsearch-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

```sh
docker network create elasticsearch-network --driver overlay   # Swarm
docker network create elasticsearch-network --driver bridge    # Compose
```



## Volumes


| Compose key | Container path                  | Default name         |
| ----------- | ------------------------------- | -------------------- |
| `data`      | `/usr/share/elasticsearch/data` | `elasticsearch_data` |


Swarm treats interpolated bind-style mounts as **named volumes**. Keep `ELASTICSEARCH_DATA_VOLUME_NAME` a short name (not a host path).


| Mode                  | `EXTERNAL` | `TYPE` | `OPTS`                   | `PATH`                    |
| --------------------- | ---------- | ------ | ------------------------ | ------------------------- |
| Local named (default) | `false`    | empty  | empty                    | empty                     |
| Bind                  | `false`    | `none` | `bind`                   | `/appdata/elasticsearch`  |
| NFS                   | `false`    | `nfs`  | `addr=host,rw,nfsvers=4` | `:/exports/elasticsearch` |
| External              | `true`     | —      | —                        | —                         |


```env
# Local named
ELASTICSEARCH_DATA_VOLUME_TYPE=
ELASTICSEARCH_DATA_VOLUME_OPTS=
ELASTICSEARCH_DATA_VOLUME_PATH=

# Bind
ELASTICSEARCH_DATA_VOLUME_TYPE=none
ELASTICSEARCH_DATA_VOLUME_OPTS=bind
ELASTICSEARCH_DATA_VOLUME_PATH=/appdata/elasticsearch
```

```sh
docker volume create elasticsearch_data
```



## Required env

- `ELASTICSEARCH_DOMAIN`, `ELASTICSEARCH_APP_URL`
- `ELASTICSEARCH_BASE_PATH` / `ELASTICSEARCH_MIDDLEWARES` (subpath vs Host-only)
- `ELASTICSEARCH_NETWORK_ALIAS` (default `elasticsearch`)

