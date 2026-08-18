# smtp-relay

[namshi/smtp](https://github.com/namshi/docker-smtp) — Exim SMTP relay on **TCP 25**. Joins `dokploy-network`. **Not an HTTP app**: no Traefik/Homepage labels (`compose.yml` is a symlink of `docker-compose.yml`).

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${SMTP_RELAY_ENV_FILE:-.env.example}`; production: `SMTP_RELAY_ENV_FILE=.env`. `environment:` wins on key conflicts.

```sh
make smtp-relay-setup \
  SMTP_RELAY_MAILNAME=smtp.example.com
make smtp-relay-stack-up
# or
make smtp-relay-compose-up
```

On the `smtp-relay` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `smtp-relay/`.

## Base path

**Not applicable.** This is SMTP, not HTTP. `SMTP_RELAY_BASE_PATH=/` is unused. Do not put Traefik `PathPrefix` or `stripPrefix` on this service.

## Smarthost vs Gmail

namshi **Gmail mode** (`GMAIL_USER` / `GMAIL_PASSWORD`) wins if both are set. Otherwise use **generic smarthost** (`SMARTHOST_*`).

### Gmail / App Password

```env
SMTP_RELAY_GMAIL_USER=you@gmail.com
SMTP_RELAY_GMAIL_PASSWORD=your-app-password
```

### Generic smarthost (Google Workspace, SES SMTP, custom)

```env
SMTP_RELAY_HOST=smtp.gmail.com
SMTP_RELAY_PORT=587
SMTP_RELAY_USER=you@yourdomain.com
SMTP_RELAY_PASS=your-app-password
SMTP_RELAY_ALIASES=*.gmail.com
```

`SMTP_RELAY_NETWORKS` **must start with `:`**. Clients outside those CIDRs are rejected. Empty `SMTP_RELAY_HOST` (and empty Gmail) = direct MX delivery.

Port **25** publishes in **host** mode by default — pin on a Swarm manager. If the host already binds 25: `SMTP_RELAY_PORT_PUBLISHED=2525`.

## Makefile

```sh
make smtp-relay-setup
make smtp-relay-pull-images
make smtp-relay-stack-up
make smtp-relay-stack-upgrade
make smtp-relay-stack-down
make smtp-relay-debug
make smtp-relay-debug-logs
make smtp-relay-compose-up
make smtp-relay-compose-down
make smtp-relay-compose-logs
make smtp-relay-test-send SMTP_RELAY_TEST_TO=you@example.com
```

Older aliases still work: `smtp-relay-deploy`, `smtp-relay-up`, `send-test-email`.

`smtp-relay-test-send` talks to **`SMTP_RELAY_TEST_HOST`:`SMTP_RELAY_PORT_PUBLISHED`** (local relay), not the upstream `SMTP_RELAY_HOST`.

## Handshake

```sh
{ sleep 0.2; printf 'HELO test.local\r\n'; sleep 0.2; printf 'QUIT\r\n'; } | nc -w 5 127.0.0.1 25
```

Expect `220` then `250`. **554 synchronization error** means you typed before the banner.

## Required env

| Variable | Notes |
|----------|--------|
| `SMTP_RELAY_MAILNAME` | HELO / mailname (warns if `example.com`) |
| `SMTP_RELAY_NETWORKS` | Must start with `:` |
| `SMTP_RELAY_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `SMTP_RELAY_PORT_PUBLISHED` | Host SMTP port (default `25`) |
| `SMTP_RELAY_HOST` / `PORT` / `USER` / `PASS` / `ALIASES` | Vendor `SMARTHOST_*` |
| `SMTP_RELAY_GMAIL_USER` / `GMAIL_PASSWORD` | Vendor `GMAIL_*` (takes precedence) |

## Common failures

- **Client rejected** — widen `SMTP_RELAY_NETWORKS` (Docker Desktop Mac often `192.168.65.1`).
- **Gmail `530 Authentication Required`** — set `SMTP_RELAY_ALIASES=*.gmail.com` plus user/pass; recreate.
- **Port 25 in use** — `SMTP_RELAY_PORT_PUBLISHED=2525`.
- **linux/amd64 on Apple Silicon** — image may emulate; check logs.
