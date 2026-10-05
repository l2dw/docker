# Elasticsearch

[Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/8.17/docker.html) **8.17** HTTP API on **TCP 9200**. Default mode is **single-node** (`discovery.type=single-node`), **xpack.security disabled** — same idea as the Cockroach stack’s lab single-node profile. The same compose also supports a **3-node cluster** via three Dokploy apps on a shared overlay (see below).

Traefik is the Swarm ingress (`docker-compose.yml`); `compose.yml` **publishes 9200** (`ELASTICSEARCH_HTTP_PUBLISHED_PORT`).

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

## Single-node (default)

Works out of the box — one Dokploy/Compose stack, one volume, one DNS alias:

```env
ELASTICSEARCH_DISCOVERY_TYPE=single-node
ELASTICSEARCH_CLUSTER_NAME=elasticsearch
ELASTICSEARCH_NODE_NAME=elasticsearch
ELASTICSEARCH_HEALTHCHECK_WAIT_FOR_STATUS=yellow
```

Do **not** set `discovery.seed_hosts` / `cluster.initial_master_nodes` (empty values crash ES: `null-valued setting`, exit 70). Do **not** raise `ELASTICSEARCH_DEPLOY_REPLICAS` — replicas share one volume and do not form a cluster.

## Multi-node cluster (3 Dokploy stacks)

Use **three** Dokploy applications from the same compose, on **`dokploy-network`**, each with its own volume and DNS name. Compose substitution uses `${ELASTICSEARCH_DISCOVERY_TYPE-single-node}` (no `:`): an **empty** `ELASTICSEARCH_DISCOVERY_TYPE=` disables single-node mode.

`discovery.seed_hosts` and `cluster.initial_master_nodes` are **not** in `environment:` (empty strings are rejected). Add them only when forming a cluster, as **literal** ES setting names in `.env` / Dokploy env (loaded via `env_file`).

| Dokploy app | `APP_NAME` / hostname / node / alias | Volume name |
|-------------|--------------------------------------|-------------|
| Node 1 | `elasticsearch-01` | `elasticsearch_data_01` |
| Node 2 | `elasticsearch-02` | `elasticsearch_data_02` |
| Node 3 | `elasticsearch-03` | `elasticsearch_data_03` |

**Shared on all three:**

```env
DEFAULT_NETWORK_NAME=dokploy-network
DEFAULT_NETWORK_EXTERNAL=true
ELASTICSEARCH_CLUSTER_NAME=elasticsearch
ELASTICSEARCH_DISCOVERY_TYPE=
ELASTICSEARCH_HEALTHCHECK_WAIT_FOR_STATUS=green
# Literal ES settings (non-empty only) — via env_file / Dokploy env:
discovery.seed_hosts=elasticsearch-01,elasticsearch-02,elasticsearch-03
cluster.initial_master_nodes=elasticsearch-01,elasticsearch-02,elasticsearch-03
```

**Per node (example node 1):**

```env
APP_NAME=elasticsearch-01
ELASTICSEARCH_HOSTNAME=elasticsearch-01
ELASTICSEARCH_NODE_NAME=elasticsearch-01
ELASTICSEARCH_NETWORK_ALIAS=elasticsearch-01
ELASTICSEARCH_DATA_VOLUME_NAME=elasticsearch_data_01
ELASTICSEARCH_PLACEMENT_CONSTRAINTS=node.hostname==worker-1
ELASTICSEARCH_MIDDLEWARES=elasticsearch-01-strip
```

Mirror for `-02` / `-03` (unique volume, alias, placement). Prefer **one ES container per Swarm host**.

Clients (e.g. Huly): `http://elasticsearch-01:9200` (or Traefik on one node / Host LB). Verify:

```sh
curl -s http://elasticsearch-01:9200/_cat/nodes?v
```

## Base path

Elasticsearch has **no native HTTP base path**. Public routing is Traefik only.


| `ELASTICSEARCH_BASE_PATH`  | Traefik               | `ELASTICSEARCH_MIDDLEWARES`                                             |
| -------------------------- | --------------------- | ----------------------------------------------------------------------- |
| `/elasticsearch` (default) | `Host` + `PathPrefix` | `elasticsearch-strip` (required — ES must not see `/elasticsearch/...`) |
| `/` or empty               | Host-only             | **empty** — do **not** strip `/`                                        |


`make elasticsearch-setup` turns an empty `ELASTICSEARCH_BASE_PATH` into `/` and clears middlewares. Align `ELASTICSEARCH_APP_URL` with the public URL. If Dokploy sets `APP_NAME`, set `ELASTICSEARCH_MIDDLEWARES` to `${APP_NAME}-strip`.

## Health (`yellow` by default)

Healthcheck: `/_cluster/health?wait_for_status=${ELASTICSEARCH_HEALTHCHECK_WAIT_FOR_STATUS:-yellow}`. Default is **yellow** because a single-node cluster often stays yellow when indices expect replicas. With a 3-node cluster, set `ELASTICSEARCH_HEALTHCHECK_WAIT_FOR_STATUS=green`. Do **not** pass `index.number_of_shards` / `index.number_of_replicas` as process env — Elasticsearch rejects them as unknown node settings. Replica count is an **index** setting (templates / index create), not a node env var.

## Traefik / Homepage

Labels: Traefik only in `docker-compose.yml`. Homepage on both compose files. `APP_NAME` scopes Traefik router/service/middleware names. Long-form `ports:` for **9200** on `compose.yml` only.

## env_file

`ELASTICSEARCH_ENV_FILE` (default `.env.example`). Production → `.env`. `environment:` overrides. Swarm: Make-exported root `.env`.

## Networks


| Goal                  | `DEFAULT_NETWORK_NAME`  | `EXTERNAL` |
| --------------------- | ----------------------- | ---------- |
| Stack-local (default) | `elasticsearch-network` | `false`    |
| Shared Traefik / apps / multi-node | `dokploy-network`       | `true`     |


`make elasticsearch-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

```sh
docker network create elasticsearch-network --driver overlay   # Swarm
docker network create elasticsearch-network --driver bridge    # Compose
```



## Volumes


| Compose key | Container path                  | Default name         |
| ----------- | ------------------------------- | -------------------- |
| `data`      | `/usr/share/elasticsearch/data` | `elasticsearch_data` |


Swarm treats interpolated bind-style mounts as **named volumes**. Keep `ELASTICSEARCH_DATA_VOLUME_NAME` a short name (not a host path). Multi-node: **one volume name per Dokploy app**.


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
- `ELASTICSEARCH_NETWORK_ALIAS` (default `dokploy-elasticsearch`)
- Multi-node: empty `ELASTICSEARCH_DISCOVERY_TYPE`, plus non-empty literal `discovery.seed_hosts` and `cluster.initial_master_nodes` in `.env` / Dokploy (not in compose `environment:`)
