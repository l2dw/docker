# immich

[Immich](https://docs.immich.app/) **v3.1.0** photo/video library. Services: `immich-server` (HTTP **2283**) and `immich-machine-learning`. Default overlay **`immich-network`** (`DEFAULT_NETWORK_EXTERNAL=false`). Set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true` to join the shared Dokploy overlay. Traefik is the ingress for the server; port 2283 is **not** published on the host.

**Postgres and Redis are external.** Default hosts: `dokploy-postgresql:5432`, `dokploy-redis:6379`. Create the `immich` database first. Immich v3 needs **VectorChord** on Postgres — do **not** use the separate `pgvecto` (pgvecto.rs) stack.

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `IMMICH_SERVER_ENV_FILE` / `IMMICH_ML_ENV_FILE` (default `.env.example`); production: set those to `.env`. `environment:` wins on key conflicts.

```sh
make immich-setup
make immich-stack-up
# or
make immich-compose-up
```

## Base path

Immich **does not support** a URL subpath (official reverse-proxy docs). Traefik uses **Host-only** routing. Keep `IMMICH_BASE_PATH=/` and a dedicated subdomain (`IMMICH_DOMAIN`).

## Volumes

| Var | Container path |
|-----|----------------|
| `IMMICH_UPLOAD_BIND` | `/data` (library) |
| `IMMICH_MODEL_CACHE_BIND` | `/cache` (ML models) |

Swarm treats `${IMMICH_*_BIND}:…` as **named volumes** after interpolation — do not put `/appdata/...` in those vars. Host bind: gitignored Compose override `type: bind`.

Memory limit defaults to **1G** for server and ML.

## Makefile

```sh
make immich-setup
make immich-pull-images
make immich-stack-up
make immich-stack-upgrade
make immich-stack-down
make immich-debug
make immich-debug-logs
make immich-compose-up
make immich-compose-down
make immich-compose-logs
```

Setup forces `IMMICH_BASE_PATH=/`, warns on `example.com` / empty DB password / Redis `ChangeMe`, and syncs `DEFAULT_NETWORK_EXTERNAL`.

## Required env

| Variable | Notes |
|----------|--------|
| `IMMICH_DOMAIN` | Public host (warns on `example.com`) |
| `IMMICH_DB_HOSTNAME` / `IMMICH_DB_PASSWORD` | External Postgres (VectorChord) |
| `IMMICH_REDIS_PASSWORD` | From the redis stack |
| `IMMICH_SERVER_ENV_FILE` / `IMMICH_ML_ENV_FILE` | Compose dotenv paths |
| `DEFAULT_NETWORK_NAME` / `DEFAULT_NETWORK_EXTERNAL` | Default `immich-network` / `false`; use `dokploy-network` / `true` to join shared overlay |

Do not commit `immich/.env`.
