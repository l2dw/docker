# Bugsink

Self-hosted error tracking ([bugsink/bugsink](https://github.com/bugsink/bugsink)). Default network `bugsink-network` (Dokploy overlay optional).

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${BUGSINK_ENV_FILE:-.env.example}`; production: `BUGSINK_ENV_FILE=.env`.

```sh
make bugsink-setup \
  BUGSINK_DOMAIN=bugsink.example.com \
  BUGSINK_BASE_URL=https://bugsink.example.com/bugsink
make bugsink-stack-up
# or
make bugsink-compose-up
```

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | Homepage only |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage |

## Base path

Default `BUGSINK_BASE_PATH=/bugsink` with Traefik strip middleware `bugsink-strip`. Host-only: `BUGSINK_BASE_PATH=/` and clear `BUGSINK_MIDDLEWARES`. Align `BUGSINK_BASE_URL`. Homepage: `BUGSINK_HOMEPAGE_URL=` empty by default.

## Networks

Default `bugsink-network` / `EXTERNAL=false`. Dokploy: `DEFAULT_NETWORK_NAME=dokploy-network`.

## Volumes

Compose key `data` → `/data`. Local / bind / NFS / external via `BUGSINK_DATA_VOLUME_*`.
