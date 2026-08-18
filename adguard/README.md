# AdGuard Home

[AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) (`adguard/adguardhome`) — network-wide DNS filtering. Joins `dokploy-network`; does not run Traefik/WAF.

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
| [`compose.yml`](compose.yml) | None (no Traefik / Homepage) |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage — used by `make` |

## Base path

**Subpath deploy is not supported.** AdGuard redirects to absolute paths (`/login.html`) and has no vendor base-path setting. Use a **dedicated subdomain** (`ADGUARD_DOMAIN` + Host-only Traefik rule). Keep `ADGUARD_BASE_PATH=/`.

## DNS ports

DNS (53/tcp+udp) and the first-run wizard (3053/tcp) publish in **host** mode by default — required for LAN DNS. Pin on a Swarm **manager** (`ADGUARD_PLACEMENT_CONSTRAINTS=node.role==manager`). After setup, the web UI listens on **80** inside the container (Traefik routes it; do not publish 80 on the host unless needed).

First boot: open `http://<host>:${ADGUARD_PORT_SETUP:-3053}` for the wizard. Then use Traefik at `ADGUARD_APP_URL`.

## Makefile

```sh
make adguard-setup
make adguard-pull-images
make adguard-stack-up
make adguard-stack-upgrade
make adguard-stack-down
make adguard-stack-logs
make adguard-debug
make adguard-debug-logs
make adguard-compose-up
make adguard-compose-down
make adguard-compose-restart
```

## Required env

| Variable | Notes |
|----------|--------|
| `ADGUARD_APP_URL` | Public URL (default `http://adguard.example.com`) |
| `ADGUARD_DOMAIN` | Traefik `Host()` |
| `ADGUARD_BASE_PATH` | Keep `/` (subpath unsupported) |
| `ADGUARD_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `ADGUARD_PORT_DNS_TCP` / `UDP` | Host DNS ports (default `53`) |
| `ADGUARD_PORT_SETUP` | First-run wizard (default `3053`) |

## Volumes

| Mount | Default | Role |
|-------|---------|------|
| `/opt/adguardhome/conf` | `adguard-conf` | `AdGuardHome.yaml`, TLS certs |
| `/opt/adguardhome/work` | `adguard-work` | Query log, stats, filter data |
