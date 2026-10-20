# dsh

[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web UI — image `ghcr.io/xidong-ai/deepseek-harness-web-docker`.

Directory / branch / stack: **`dsh`**. Env prefix: **`DSH_`**.

HTTP via Traefik on `docker-compose.yml` (labels gated by `DSH_TRAEFIK_LABELS_*`). Homepage labels on **both** compose files. Host port published **3080→3080** (long-form). Network alias **`deepseek-harness`** (override with `DSH_NETWORK_ALIAS`) for Traefik file routes / stable DNS. `APP_NAME` scopes Traefik router/service names (`APP_NAME=dsh`; Dokploy may override).

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${DSH_ENV_FILE:-.env.example}`; production: `DSH_ENV_FILE=.env`. `environment:` wins on key conflicts.

```sh
make dsh-setup
make dsh-stack-up      # Swarm
# or
make dsh-compose-up    # Compose
```

On this branch, root `compose.yml` / `docker-compose.yml` symlink into `dsh/`. Root `README.md` stays the repo socle doc when it is a regular file.

## Base path

Vendor Web UI does **not** support a real subpath (`BASE_PATH`): assets and `/api` are root-absolute ([discussion #1444](https://github.com/deepseek-ai/deepseek-harness/discussions/1444)). Keep `DSH_BASE_PATH=/` and prefer a **dedicated Host / subdomain**. Do not rely on Traefik `stripPrefix` alone. `DSH_PUBLIC_URL` is advertisement only (`--public-url`); set `DSH_TRUSTED_HOSTS` to the browser-visible authority.

## env_file

`DSH_ENV_FILE` (default `.env.example`). Production → `.env`. Swarm: Make-exported root `.env` + `environment:` interpolation.

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `EXTERNAL` |
|------|------------------------|------------|
| Stack-local (default) | `dsh-network` | `false` |
| Shared Dokploy / Traefik overlay | `dokploy-network` | `true` |

`make dsh-setup` upserts `DEFAULT_NETWORK_EXTERNAL` (`true` only for `dokploy-network`) and creates the network when external is false.

```sh
docker network create dsh-network --driver overlay   # Swarm
docker network create dsh-network --driver bridge    # Compose
```

## Ports

| Key | Default |
|-----|---------|
| `DSH_PORT` (target) | `3080` |
| `DSH_PUBLISHED_PORT` | `3080` |
| `DSH_PORT_MODE` | `ingress` |
| `DSH_PORT_PROTOCOL` | `tcp` |

Direct: `http://localhost:3080/`

## Network alias

Service DNS name remains `dsh`. Alias default: `deepseek-harness` (`DSH_NETWORK_ALIAS`) — matches the local Traefik file provider target.

## Volumes

| Compose key | Container path | Default |
|-------------|----------------|---------|
| `data` | `/home/node` | local named `dsh_data` |

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|------------|--------|--------|--------|
| Local named (default) | `false` | empty | empty | empty |
| Bind | `false` | `none` | `bind` | `/appdata/dsh` |
| NFS | `false` | `nfs` | `addr=host,rw,nfsvers=4` | `:/exports/dsh` |
| External | `true` | — | — | — |

```sh
docker volume create dsh_data
```

## First login

After start, read the one-time launch URL from logs or:

```sh
docker exec <container> cat /home/node/.dsh/web-launch-url.txt
```

Rewrite host to your Traefik domain / public URL. Set a real `DSH_DEEPSEEK_API_KEY` then recreate.

## Makefile

```sh
make dsh-setup
make dsh-pull-images
make dsh-stack-up
make dsh-stack-upgrade
make dsh-stack-down
make dsh-debug
make dsh-debug-logs
make dsh-compose-up
make dsh-compose-down
make dsh-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `DSH_DEEPSEEK_API_KEY` | Mapped to container `DEEPSEEK_API_KEY` |
| `DSH_TRUSTED_HOSTS` | Browser-visible Host allowlist |
| `DSH_PUBLIC_URL` | Advertised public URL (trailing `/`) |
| `DSH_DOMAIN` | Traefik `Host()` rule |
| `DSH_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `APP_NAME` | Traefik router/service prefix (`dsh`) |

Do not commit `dsh/.env` or real secrets.
