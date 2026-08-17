# Sonatype Nexus Repository

[Nexus Repository 3](https://github.com/sonatype/docker-nexus3) (`sonatype/nexus3`) — artifact registry. Joins the existing overlay (`dokploy-network`); does not run Traefik/WAF.

Docs: [docker-nexus3](https://github.com/sonatype/docker-nexus3), [context path](https://help.sonatype.com/en/configuring-the-runtime-environment.html), [reverse proxy](https://help.sonatype.com/en/run-behind-a-reverse-proxy.html).

`.env` is **not** read by `docker stack deploy` alone — use Make (root `.env` is exported). Compose `env_file` loads `${SONATYPE_ENV_FILE:-.env.example}`; `environment:` wins on conflicts. Production: `SONATYPE_ENV_FILE=.env`.

```sh
make sonatype-setup \
  SONATYPE_DOMAIN=example.com \
  SONATYPE_APP_URL=https://example.com/sonatype
make sonatype-stack-up
# or
make sonatype-compose-up
```

On the `sonatype` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `sonatype/`.

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | None (no Traefik / Homepage) |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage — used by `make` |

## Base path

Supported via vendor **`NEXUS_CONTEXT`** ([image README](https://github.com/sonatype/docker-nexus3): no leading slash; the image sets `nexus-context-path=/${NEXUS_CONTEXT}`). Defaults include the project path:

- Default: `SONATYPE_BASE_PATH=/sonatype`, `SONATYPE_NEXUS_CONTEXT=sonatype`, `SONATYPE_APP_URL=http://example.com/sonatype`
- Root on a dedicated subdomain: `SONATYPE_BASE_PATH=/`, `SONATYPE_NEXUS_CONTEXT=` (empty), `SONATYPE_APP_URL=https://nexus.example.com`

Keep Traefik `PathPrefix` aligned with the Nexus context. Do **not** add `stripPrefix` — Nexus serves under that path.

First boot can take 2–3 minutes (`start_period` 180s). Allow ~120s on stop (`SONATYPE_STOP_GRACE_PERIOD`).

## Makefile

```sh
make sonatype-setup
make sonatype-pull-images
make sonatype-stack-up
make sonatype-stack-upgrade
make sonatype-stack-down
make sonatype-stack-logs
make sonatype-debug
make sonatype-debug-logs
make sonatype-compose-up
make sonatype-compose-down
make sonatype-compose-restart
```

Pin to a worker with `SONATYPE_PLACEMENT_CONSTRAINTS=node.role==worker` when needed.

## Required env

| Variable | Notes |
|----------|--------|
| `SONATYPE_APP_URL` | Public URL including base path (default `http://example.com/sonatype`) |
| `SONATYPE_DOMAIN` | Traefik `Host()` |
| `SONATYPE_BASE_PATH` | Traefik `PathPrefix` (default `/sonatype`) |
| `SONATYPE_NEXUS_CONTEXT` | Vendor context, **no** leading slash (default `sonatype`) |
| `SONATYPE_MEMORY_LIMIT` | Must be ≥ JVM heap + `MaxDirectMemorySize` (default `2G`) |
| `SONATYPE_ENV_FILE` | Compose dotenv (default `.env.example`; use `.env` in production) |

Default admin is `admin`. First-boot password:

```sh
docker exec <nexus-container> cat /nexus-data/admin.password
```

Change it immediately. Process runs as **UID 200** — bind-mounts must be `chown 200`.

HTTP **8081** is not published; Traefik routes it. Optional Docker registry connector (host **5000**) is configured in Nexus, not in this compose file.

## Volumes

| Mount | Default | Role |
|-------|---------|------|
| `/nexus-data` | named `sonatype_data` or `SONATYPE_DATA_DIR` | Config, logs, blobs, `admin.password` |
