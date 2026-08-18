# poste.io

[poste.io](https://poste.io/) (`analogic/poste.io`) — full mail server in **one** container: SMTP/IMAP/POP, Rspamd, ClamAV, **SRS**, DKIM wizard, aliases/forwards, Roundcube + WebAdmin. Joins `dokploy-network`. Does **not** run Traefik/WAF.

Docs: [installation](https://poste.io/doc), [DNS](https://poste.io/doc/configuring-dns), [license](https://poste.io/doc/license) (free Hub vs **PRO** image `poste.io/mailserver`).

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${POSTEIO_ENV_FILE:-.env.example}`; production: `POSTEIO_ENV_FILE=.env`. `environment:` wins on key conflicts.

```sh
make posteio-setup \
  POSTEIO_HOSTNAME=mail.example.com \
  POSTEIO_DOMAIN=mail.example.com \
  POSTEIO_APP_URL=https://mail.example.com
make posteio-stack-up
# or
make posteio-compose-up
```

On the `posteio` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `posteio/`.

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | None |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage (admin/webmail HTTP) — used by `make` |

First boot: open `POSTEIO_APP_URL` and complete the **admin wizard**. Then Virtual domains → DKIM + **DNS diagnostics**. Do not publish **80/443** on the host (`POSTEIO_HTTPS=OFF`; Traefik terminates TLS).

## Base path

**Subpath is not supported** (admin + Roundcube). Dedicated hostname: `POSTEIO_DOMAIN` / `POSTEIO_HOSTNAME` = `mail.example.com`, `POSTEIO_BASE_PATH=/`. Host-only Traefik rule.

## Mail ports

Host mode (pin Swarm **manager**): **25** (MX), **465**, **587** (submission), **993** (IMAPS), **995** (POP3S), **4190** (Sieve). Analogic recommends `--net=host` for PTR/IP; this stack uses overlay + host-published ports instead (Swarm-compatible). The public IP of that node must match the **PTR**.

## DNS (required)

| Record | Example |
|--------|---------|
| `A`/`AAAA` | `mail.example.com` → public IP of the MX node |
| **PTR** | that IP → `mail.example.com` |
| `MX` | `example.com` → `mail.example.com` |
| `SPF` TXT | `v=spf1 mx -all` (copy from admin diagnostics) |
| `DKIM` TXT | selector from Virtual domains → DKIM (create key in UI) |
| `DMARC` TXT | `_dmarc.example.com` `v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com` |

**SRS** is built-in (Haraka). Forwards/aliases to Gmail (`info@example.com` → `jane.doe@gmail.com`) rewrite the envelope so SPF of **your** domain is what Gmail checks. Create redirects in the admin UI.

## Makefile

```sh
make posteio-setup
make posteio-pull-images
make posteio-stack-up
make posteio-stack-upgrade
make posteio-stack-down
make posteio-debug
make posteio-debug-logs
make posteio-compose-up
make posteio-compose-down
make posteio-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `POSTEIO_HOSTNAME` | Container / MX FQDN |
| `POSTEIO_DOMAIN` | Traefik `Host()` |
| `POSTEIO_APP_URL` | Public admin/webmail URL |
| `POSTEIO_BASE_PATH` | Keep `/` |
| `POSTEIO_HTTPS` | Keep `OFF` behind Traefik |
| `POSTEIO_ENV_FILE` | Compose dotenv (default `.env.example`) |
| `POSTEIO_DISABLE_CLAMAV` / `DISABLE_RSPAMD` | Set `TRUE` to disable (saves RAM) |

## Volumes

| Mount | Default | Role |
|-------|---------|------|
| `/data` | `posteio-data` | Mailboxes, config, DKIM keys |

## Licence

Free Hub image for own use. PRO adds DMARC reports, extra logs, domain-admin roles. Do not redistribute the image as a hosted service.
