# Huly

Self-hosted [Huly](https://huly.io) (all-in-one PM / chat / CRM), based on [huly-selfhost](https://github.com/hcengineering/huly-selfhost) **v0.7.x**.

Platform source: [hcengineering/platform](https://github.com/hcengineering/platform#self-hosting). Prefer production tags (`v*`, e.g. `v0.7.426`).

This stack deploys **Huly application services only**. CockroachDB, Kafka/Redpanda, object storage, and Elasticsearch run **outside** the stack (separate compose stacks or managed services on the same overlay).

**Requirements:** ~8 GB RAM minimum (16 GB recommended) for the app tier; plan additional resources for external data stores.

## Quick start

```sh
make huly-setup
# Edit huly/.env: external URLs + HULY_DOMAIN / schemes / TLS
make huly-stack-up          # Swarm
# or: make huly-compose-up  # Compose
```

`docker stack deploy` does **not** load Compose `env_file` the same way — use Make (exports root `.env` + `environment:` interpolation).

## Services (this stack)

| Compose service | Role | Public path (Traefik) |
|-----------------|------|------------------------|
| `front` | Web UI | `Host(domain)` |
| `account` | Accounts API | `/_accounts` (strip) |
| `transactor` | WS / sync | `/_transactor` (strip), `/eyJ…` |
| `collaborator` | Collaboration WS | `/_collaborator` (strip) |
| `stats` | Stats | `/_stats` (strip) |
| `rekoni` | Recognition | `/_rekoni` (strip) |
| `stream` | Screen recording (TUS) | `/_stream` (strip), `/recording` |
| `datalake` | Blob API for media | `/_datalake` (strip) |
| `media` | Transcode worker | internal |
| `mail` | SMTP / OTP emails | internal (`MAIL_URL`) |
| `workspace` / `fulltext` / `kvs` | Workers | internal |

Per-service files: `front-compose.yml`, `account-compose.yml`, `stream-compose.yml`, … (same definitions + labels where applicable).

Nginx from upstream is **not** included — Traefik path routers replace `.huly.nginx`.

### Uploads vs screen recording

| Feature | Front env | Backend | Notes |
|---------|-----------|---------|--------|
| Attachments | `UPLOAD_URL=/files` | S3/MinIO via `HULY_STORAGE_CONFIG` | Normal file upload |
| Screen recording | `STREAM_URL=…/recording` | `stream` → `datalake://` | TUS; not MinIO `/files` |
| Blob playback | `FILES_URL` / `DATALAKE_URL` | `datalake` | Prefer `datalake://` for stream endpoint |
| Huly Love | `LOVE_ENDPOINT=…/_love` | Love service | Video calls — not screen capture |

`STREAM_URL` must end with `/recording` (TUS returns relative `/recording/<id>`). Use `HULY_STREAM_ENDPOINT_URL=datalake://datalake:4030` — `s3://` alone often does not persist blobs for playback. Datalake `BUCKETS` location must be one of: `eu`, `weur`, `eeur`, `wnam`, `enam`, `apac`.

## External dependencies

Provision these **before** first deploy. Hostnames must resolve from the Huly stack network (e.g. join `dokploy-network` or use stack DNS aliases).

| Dependency | Env var(s) | Notes |
|------------|------------|--------|
| **CockroachDB** (Postgres wire) | `HULY_CR_DB_URL` | e.g. `postgres://huly:pass@postgresql:26257/huly` |
| **Kafka / Redpanda** | `HULY_QUEUE_CONFIG` | `host:9092` (no URI scheme) |
| **S3 / MinIO** | `HULY_STORAGE_CONFIG`, `HULY_DATALAKE_BUCKETS` | Use `minio\|` (not `s3\|`); include `rootBucket=huly` |
| **Elasticsearch 7.x** | `HULY_ELASTIC_URL`, `HULY_FULLTEXT_DB_URL` | Ingest-attachment plugin for fulltext |

Example `.env` fragment:

```env
HULY_CR_DB_URL=postgres://huly:ChangeMe@postgresql:26257/huly
HULY_QUEUE_CONFIG=kafka:9092
HULY_STORAGE_CONFIG=minio|minio:9000?accessKey=ChangeMe&secretKey=ChangeMe&rootBucket=huly
HULY_STREAM_URL=https://huly.example.com/recording
HULY_STREAM_ENDPOINT_URL=datalake://datalake:4030
HULY_DATALAKE_BUCKETS=huly,eu|http://minio:9000?accessKey=ChangeMe&secretKey=ChangeMe
HULY_ELASTIC_URL=http://elasticsearch:9200
HULY_FULLTEXT_DB_URL=http://elasticsearch:9200
```

### Create Huly database on CockroachDB

Cockroach is **external** to this stack. Create the SQL user + database once, then point `HULY_CR_DB_URL` at it.

Replace the container name filter with your Swarm/Compose service (Dokploy often looks like `*_cockroach`):

```sh
# Interactive SQL shell (TLS certs volume)
docker exec -it "$(docker ps -q -f name=cockroach)" \
  /cockroach/cockroach sql --certs-dir=/cockroach/certs --host=cockroach:26257 -u root

# One-shot: user + database + grants
docker exec "$(docker ps -q -f name=cockroach)" \
  /cockroach/cockroach sql --certs-dir=/cockroach/certs --host=cockroach:26257 -u root -e "
CREATE USER IF NOT EXISTS huly WITH PASSWORD 'ChangeMe';
CREATE DATABASE IF NOT EXISTS huly;
GRANT ALL ON DATABASE huly TO huly;
"
```

If the stack runs **insecure** / `--accept-sql-without-tls`, drop `--certs-dir=…` and use `--insecure` instead.

Then set:

```env
HULY_CR_DB_URL=postgres://huly:ChangeMe@cockroach:26257/huly
```

Host `cockroach` must resolve on the shared overlay (`DEFAULT_NETWORK_NAME=dokploy-network`). Adjust hostname if your Cockroach service/alias differs.

## SMTP / mail (`MAIL_URL`)

The stack includes **`mail`** (`hardcoreeng/mail`). `account` and `transactor` set `MAIL_URL=${HULY_MAIL_URL:-http://mail:8097}`.

Configure SMTP in `.env`:

```env
HULY_MAIL_SOURCE=noreply@huly.example.com
HULY_SMTP_HOST=smtp.example.com
HULY_SMTP_PORT=587
HULY_SMTP_USERNAME=ChangeMe
HULY_SMTP_PASSWORD=ChangeMe
HULY_MAIL_URL=http://mail:8097
```

Prefer port **587** (STARTTLS). Do **not** enable SMTP and Amazon SES at the same time (SES keys are commented in `.env.example`). UI: **Settings → Notifications** (per user). Not the same as `GMAIL_URL` (Gmail inbox integration).

Debug: [smtp-troubleshooting.md](https://github.com/hcengineering/huly-selfhost/blob/main/guides/smtp-troubleshooting.md).

## SSO (OpenID Connect)

Env vars on **`account`** (empty `CLIENT_ID` / `SECRET` / `ISSUER` = OIDC disabled):

```env
HULY_OPENID_CLIENT_ID=...
HULY_OPENID_CLIENT_SECRET=...
HULY_OPENID_ISSUER=https://idp.example.com/application/o/huly/
HULY_OPENID_DISPLAY_NAME=SSO
```

`HULY_OPENID_DISPLAY_NAME` is optional (login button label). Scope is hardcoded upstream to `openid profile email`.

### SSO-only UI (hide password login)

On **`front`** only:

```env
HULY_HIDE_LOCAL_LOGIN=true
```

Hides the email/password form so users see the OIDC button. This does **not** fully disable the password login API.

### Lock down public sign-up

By default anyone can register. With SSO, set on **both** `account` and `front`:

```env
HULY_DISABLE_SIGNUP=true
```

Then only workspace **invite links** can add users. Create the first admin **before** enabling this (or while it is still `false`). Redeploy / recreate those two services after changing the env.

**Caveat:** `DISABLE_SIGNUP=true` on `account` can block auto-provisioning of new OIDC users. If first SSO login fails to create an account, leave `HULY_DISABLE_SIGNUP=false` on account (or both) and rely on `HIDE_LOCAL_LOGIN=true` + IdP access control.

IdP redirect / callback URI:

```text
https://huly.example.com/_accounts/auth/openid/callback
```

(`front` already has public `ACCOUNTS_URL=…/_accounts`. Traefik strips `/_accounts`.)

Notes: IdP JWT must be **unencrypted** (Authentik: disable token encryption). Upstream: [OIDC](https://github.com/hcengineering/huly-selfhost#configure-openid-connect-oidc).

## Base path

**Subpath is not supported.** Keep `HULY_BASE_PATH=/` and a dedicated subdomain (`HULY_DOMAIN`). Upstream paths (`/_accounts`, `/_transactor`, …) are absolute.

## Env / secrets

| Key | Notes |
|-----|--------|
| `HULY_SECRET` | Shared app secret (`make huly-setup` generates if `ChangeMe`) |
| `HULY_CR_DB_URL` | External Cockroach/Postgres URL |
| `HULY_QUEUE_CONFIG` | External Kafka broker |
| `HULY_STORAGE_CONFIG` | External object storage (`minio\|…&rootBucket=huly`) |
| `HULY_STREAM_URL` | Public TUS base (`…/recording`) for screen capture |
| `HULY_STREAM_ENDPOINT_URL` | Prefer `datalake://datalake:4030` |
| `HULY_DATALAKE_URL` / `HULY_FILES_URL` | Public datalake + blob URL template |
| `HULY_MAIL_*` / `HULY_SMTP_*` | Mail service + SMTP (`MAIL_URL` → account/transactor) |
| `HULY_OPENID_CLIENT_ID` / `_SECRET` / `_ISSUER` / `_DISPLAY_NAME` | OIDC SSO on account (empty = off) |
| `HULY_DISABLE_SIGNUP` | `true` = invite-only (account + front); may block OIDC auto-provision |
| `HULY_HIDE_LOCAL_LOGIN` | `true` on front = hide password form (SSO button only) |
| `HULY_ELASTIC_URL` / `HULY_FULLTEXT_DB_URL` | External Elasticsearch |
| `HULY_HTTP_SCHEME` / `HULY_WS_SCHEME` | `https` / `wss` (or `http` / `ws`) |
| `HULY_INIT_REPO_DIR` | Set `/no-init-scripts` to skip default workspace content |

Each service has `env_file` (`HULY_<ROLE>_ENV_FILE`, default `.env.example`) **and** `environment:` (wins on conflict). Production: set `*_ENV_FILE=.env`.

`APP_NAME` scopes Traefik router/service names (Dokploy may override).

## Traefik / Homepage

Labels only in `docker-compose.yml` (and matching role files). `compose.yml` is unlabeled. Homepage on `front` only.

## Networks

| Goal | `DEFAULT_NETWORK_NAME` | `DEFAULT_NETWORK_EXTERNAL` |
|------|------------------------|----------------------------|
| Stack-local (default) | `huly-network` | `false` |
| Dokploy / shared Traefik + deps | `dokploy-network` | `true` |

`make huly-setup` upserts `EXTERNAL` (`true` only for `dokploy-network`) and creates the stack-local network when needed.

```sh
docker network create huly-network --driver overlay   # Swarm
```

## Volumes

This stack has **no persistent volumes** — state lives in external Cockroach, Kafka, S3, and Elasticsearch.

## Make targets

| Target | Role |
|--------|------|
| `huly-setup` | `.env`, secrets, network pairing |
| `huly-stack-up\|down\|recreate\|upgrade\|logs` | Swarm |
| `huly-compose-up\|down\|restart\|logs` | Compose |
| `huly-debug` / `huly-debug-logs` | Ops |
| `huly-pull-images` | Pull |

## Updates

Follow upstream [MIGRATION.md](https://github.com/hcengineering/huly-selfhost/blob/main/MIGRATION.md) before bumping `HULY_VERSION` / image tags. Then `make huly-stack-upgrade`.
