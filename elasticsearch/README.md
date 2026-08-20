# elasticsearch

[Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/8.17/docker.html) 8.17 HTTP API on **TCP 9200**. Joins `dokploy-network`. Traefik is the ingress; port 9200 is **not** published on the host.

Other stacks on the overlay reach Elasticsearch as **`dokploy-elasticsearch:9200`** (network alias) or `elasticsearch:9200` (Compose service name). Override with `ELASTICSEARCH_NETWORK_ALIAS`.

Single-node (`discovery.type=single-node`), **xpack.security disabled** (HTTP on the overlay + Traefik). Heap via `ELASTICSEARCH_JAVA_OPTS` (default `-Xms512m -Xmx512m`); container memory limit **1G**.

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${ELASTICSEARCH_ENV_FILE:-.env.example}`; production: `ELASTICSEARCH_ENV_FILE=.env`. `environment:` wins on key conflicts.

```sh
make elasticsearch-setup
make elasticsearch-stack-up
# or
make elasticsearch-compose-up
```

## Base path

Elasticsearch has **no native HTTP base path**. Public routing is Traefik only.

| `ELASTICSEARCH_BASE_PATH` | Traefik | `ELASTICSEARCH_MIDDLEWARES` |
|---------------------------|---------|-----------------------------|
| `/elasticsearch` (default) | `Host` + `PathPrefix(/elasticsearch)` | `elasticsearch-stripprefix` (required — ES would otherwise see `/elasticsearch/_cluster/health`) |
| `/` or empty (Compose default `/elasticsearch` if unset) | Host-only: set `ELASTICSEARCH_BASE_PATH=/` | **empty** — do **not** strip `/` |

Align `ELASTICSEARCH_HOMEPAGE_HREF` with the public URL.

## Health (`green`)

The healthcheck calls `/_cluster/health?wait_for_status=green`. Defaults `index.number_of_replicas=0` and `index.number_of_shards=1` keep a **single-node** cluster green after indexing (replica=1 would stay yellow).

Host: `vm.max_map_count=262144` (Elastic requirement). Without it the node may fail to start.

## Makefile

```sh
make elasticsearch-setup
make elasticsearch-pull-images
make elasticsearch-stack-up
make elasticsearch-stack-upgrade
make elasticsearch-stack-down
make elasticsearch-debug
make elasticsearch-debug-logs
make elasticsearch-compose-up
make elasticsearch-compose-down
make elasticsearch-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `ELASTICSEARCH_DOMAIN` | Public host (warns on `example.com`) |
| `ELASTICSEARCH_BASE_PATH` | Default `/elasticsearch`; `/` + empty middlewares for a dedicated subdomain |
| `ELASTICSEARCH_MEMORY_LIMIT` | Default `1G` |
| `ELASTICSEARCH_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `ELASTICSEARCH_NETWORK_ALIAS` | Overlay DNS alias (default `dokploy-elasticsearch`) |
| `DEFAULT_NETWORK_NAME` / `DEFAULT_NETWORK_EXTERNAL` | Join `dokploy-network` with `external=true` |

Do not commit `elasticsearch/.env`.
