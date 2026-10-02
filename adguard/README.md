# AdGuard Home

[AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) (`adguard/adguardhome`) — network-wide DNS filtering. Does not run Traefik/WAF (joins the stack network; use Dokploy overlay when needed).

Docs: [Docker wiki](https://github.com/AdguardTeam/AdGuardHome/wiki/Docker), [reverse proxy FAQ](https://adguard-dns.io/kb/adguard-home/faq/#reverseproxy).

`.env` is **not** read by `docker stack deploy` alone — use Make (root `.env` is exported). Compose `env_file` loads `${ADGUARD_ENV_FILE:-.env.example}`; production: `ADGUARD_ENV_FILE=.env`.

```sh
make adguard-setup \
  ADGUARD_DOMAIN=adguard.example.com \
  ADGUARD_APP_URL=https://adguard.example.com
make adguard-stack-up
# or
make adguard-compose-up
```

On the `adguard` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `adguard/`.

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | Homepage only |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage — used by `make` |

## Base path

**Subpath deploy is not supported.** AdGuard redirects to absolute paths (`/login.html`) and has no vendor base-path setting. Use a **dedicated subdomain** (`ADGUARD_DOMAIN` + Host-only Traefik rule). Keep `ADGUARD_BASE_PATH=/`. Homepage link: set `ADGUARD_HOMEPAGE_URL` (empty by default).

## Networks

Default: `adguard-network` / `DEFAULT_NETWORK_EXTERNAL=false` (created by `make adguard-setup`). To join Dokploy + Traefik: set `DEFAULT_NETWORK_NAME=dokploy-network` (setup sets `EXTERNAL=true`).

## Volumes

Compose keys `conf` and `work` → `/opt/adguardhome/conf` and `/opt/adguardhome/work`.

| Mode | `*_VOLUME_EXTERNAL` | `DRIVER` | `TYPE` | `OPTS` | `PATH` |
|------|---------------------|----------|--------|--------|--------|
| Local named (default) | `false` | `local` | empty | empty | empty |
| Bind | `false` | `local` | `none` | `bind` | e.g. `/appdata/adguard/conf` |
| NFS | `false` | `local` | `nfs` | `addr=host,rw,nfsvers=4` | e.g. `:/exports/adguard/conf` |
| External | `true` | — | — | — | — |

## DNS ports

DNS (53/tcp+udp) and the first-run wizard (3053/tcp) publish in **host** mode by default — required for LAN DNS. Pin on a Swarm **manager** (`ADGUARD_PLACEMENT_CONSTRAINTS=node.role==manager`). After setup, the web UI listens on **80** inside the container (Traefik routes it; do not publish 80 on the host unless needed).

First boot: open `http://<host>:${ADGUARD_PORT_SETUP:-3053}` for the wizard. Then use Traefik at `ADGUARD_APP_URL`.

## Makefile

```sh
make adguard-setup
make adguard-pull-images
make adguard-stack-up
make adguard-compose-up
make adguard-debug
make adguard-debug-logs
```

`APP_NAME` scopes Traefik router/service names (`APP_NAME=adguard` in `.env.example`; Dokploy may override).
