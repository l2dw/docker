# OpenBao

[OpenBao](https://openbao.org/) — open-source secrets management (Vault fork). Image `openbao/openbao:2.7.1`, HTTP API/UI on **8200**. Traefik on `docker-compose.yml`; Homepage on both compose files.

This stack runs **`bao server`** with **file storage** (`/openbao/file`) and **TLS disabled** on the listener (terminate TLS at Traefik). Not `-dev` — data persists, but you must **initialize and unseal** after first boot (and after every restart until auto-unseal is configured).

## Quick start

```sh
make openbao-setup
# Edit openbao/.env — OPENBAO_DOMAIN / OPENBAO_APP_URL / OPENBAO_API_ADDR
make openbao-stack-up      # Swarm
# or
make openbao-compose-up    # Compose
```

Debug: `make openbao-debug` / `make openbao-debug-logs`.

`docker stack deploy` does **not** load Compose `env_file` reliably — use Make (exports root `.env`) + `environment:` interpolation.

## Init / unseal (first boot)

```sh
# From a client with the bao CLI (or docker exec into the task):
export BAO_ADDR=http://openbao.example.com   # or http://127.0.0.1:8200 via publish
bao operator init
bao operator unseal   # repeat with each unseal key (default threshold)
```

Store the root token and unseal keys offline. Losing them loses access to the sealed store.

## Base path

UI/API subpath is **not** supported for this scaffold. Keep `OPENBAO_BASE_PATH=/` and a dedicated subdomain. UI lives at `/ui`.

## Traefik / Homepage

Labels: Traefik only in `docker-compose.yml`. Homepage on both compose files. `APP_NAME` scopes Traefik router/service names. Align `OPENBAO_API_ADDR` with the public URL (no trailing slash).

## env_file

`OPENBAO_ENV_FILE` (default `.env.example`). Production → `.env`. `environment:` overrides. Swarm: Make-exported root `.env`.

Server config is inline JSON via `OPENBAO_LOCAL_CONFIG` → `BAO_LOCAL_CONFIG` (override for raft, TLS, etc.).

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `EXTERNAL` |
|------|------------------------|------------|
| Stack-local (default) | `openbao-network` | `false` |
| Shared Traefik / apps | `dokploy-network` | `true` |

`make openbao-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

```sh
docker network create openbao-network --driver overlay   # Swarm
docker network create openbao-network --driver bridge    # Compose
```

## Volumes

| Compose key | Container path | Default name |
|-------------|----------------|--------------|
| `data` | `/openbao/file` | `openbao_data` |

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|------------|--------|--------|--------|
| Local named (default) | `false` | empty | empty | empty |
| Bind | `false` | `none` | `bind` | `/appdata/openbao` |
| NFS | `false` | `nfs` | `addr=host,rw,nfsvers=4` | `:/exports/openbao` |
| External | `true` | — | — | — |

```env
# Local named
OPENBAO_DATA_VOLUME_TYPE=
OPENBAO_DATA_VOLUME_OPTS=
OPENBAO_DATA_VOLUME_PATH=

# Bind
OPENBAO_DATA_VOLUME_TYPE=none
OPENBAO_DATA_VOLUME_OPTS=bind
OPENBAO_DATA_VOLUME_PATH=/appdata/openbao
```

```sh
docker volume create openbao_data
```

## Required env

- `OPENBAO_DOMAIN`, `OPENBAO_APP_URL`, `OPENBAO_API_ADDR`
