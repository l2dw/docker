# keycloak

Official [Keycloak](https://www.keycloak.org/server/containers) (`quay.io/keycloak/keycloak:26.7.3`) on **HTTP 8080**. Defaults to a stack-local overlay `keycloak-network`. Traefik/Homepage labels live only in `docker-compose.yml`.

Postgres is **external** — this stack has no `keycloak-db` service. Point `KEYCLOAK_DB_URL` at a PostgreSQL VM/native DB that already exists (default placeholder `jdbc:postgresql://<DB_HOST>:5432/keycloak`). Create the `keycloak` role/database before the first start.

`keycloak-network` is **stack-local** (`DEFAULT_NETWORK_EXTERNAL=false`). To join a shared external overlay at runtime, set `DEFAULT_NETWORK_NAME=<shared-overlay-name>` and `DEFAULT_NETWORK_EXTERNAL=true` in `.env`. `make keycloak-setup` keeps those two keys consistent (`false` for `keycloak-network`).

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${KEYCLOAK_ENV_FILE:-.env.example}`; production: `KEYCLOAK_ENV_FILE=.env`. `environment:` wins on key conflicts.

```sh
make keycloak-setup \
  KEYCLOAK_DOMAIN=example.com \
  KEYCLOAK_APP_URL=http://example.com/auth
make keycloak-stack-up
# or
make keycloak-compose-up
```

On the `keycloak` branch, root `README.md` / `compose.yml` / `docker-compose.yml` are symlinks into `keycloak/`.

## Base path

**Supported.** Vendor env is `KC_HTTP_RELATIVE_PATH` (`KEYCLOAK_BASE_PATH`, default `/auth`). Public URL is `KC_HOSTNAME` (`KEYCLOAK_APP_URL`, include the path). Traefik uses `PathPrefix` — **do not** add `stripPrefix`. Override `KEYCLOAK_BASE_PATH=/` and drop the path from `KEYCLOAK_APP_URL` for a dedicated subdomain.

## Reverse proxy

Traefik terminates TLS. Keycloak listens on HTTP (`KC_HTTP_ENABLED=true`) and trusts `X-Forwarded-*` (`KC_PROXY_HEADERS=xforwarded`). First admin user: `KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME` / `KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD` (`make keycloak-setup` generates the password).

Single replica uses `KC_CACHE=local`. HTTP 8080 is not published on the host. Memory limit default is **1G**. Traefik router/service names are scoped by `${APP_NAME:-keycloak}` (Dokploy injects `APP_NAME`; not listed in `.env.example`).

Named volumes persist `/opt/keycloak/data`, `themes`, `providers`, `conf`, and `logs`. Empty `KEYCLOAK_*_DIR` uses the named volume; set a host path to bind-mount instead.

## Base de données (PostgreSQL externe)

Ce stack n'embarque **pas** de service `keycloak-db` : Keycloak se connecte à une **PostgreSQL existante** sur l'overlay. Créez le rôle et la base **avant le premier démarrage**, sinon Keycloak ne peut pas initialiser son schéma.

### 1. Générer un mot de passe fort (`DB_PWD`)

`make keycloak-setup` génère automatiquement `KEYCLOAK_DB_PASSWORD` s'il est vide (`openssl rand -hex 32`). Pour le générer à la main sans le stocker nulle part :

```sh
openssl rand -hex 24
# ex. 5c4f2b9a3e8d1c7f6b0a9e4d2c8f1a6b3e5d7c8a
DB_PASS=$(openssl rand -hex 24)
```

### 2. Créer le rôle (`DB_USER`) et la base (`DB_NAME`) via `psql`

La base est **hors de ce swarm** (autre VM / installation native). Connectez-vous avec le client `psql` classique en tant que super-utilisateur. Exportez d'abord l'adresse du serveur :

```sh
DB_HOST=<adresse IP ou nom DNS de la VM Postgres>
# Exemple: DB_HOST=192.168.10.20
```

Puis ouvrez une session interactive en super-utilisateur `postgres` :

```sh
psql -h "$DB_HOST" -U postgres -d postgres
```

Une fois dans le prompt `psql`, créez le rôle et la base (remplacez `<le mot de passe>` par `$DB_PASS`) :

```sql
CREATE USER keycloak WITH PASSWORD '<le mot de passe>';
CREATE DATABASE keycloak OWNER keycloak;
```

En une commande sans entrée interactive (si vous préférez `-c`). Attention : `psql -c` **n'effectue pas** la substitution de variables `:` — passez les mots de passe en littéral :

```sh
psql -h "$DB_HOST" -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE USER keycloak WITH PASSWORD '<le mot de passe>'"
psql -h "$DB_HOST" -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE keycloak OWNER keycloak"
```

`<le mot de passe>` n'a **pas** de quote imbriquée : une valeur contenant un simple guillemet ne peut pas être passée ainsi.

> **Pré-requis accès distant** : la VM Postgres doit accepter les connexions TCP (client + réseau autorisé dans `pg_hba.conf` et un `listen_addresses` non-bouclé). Le port par défaut est `5432` — ajoutez `-p <port>` si différent.

### 3. Renseigner le Stack

Dans `keycloak/.env` (ou via `make keycloak-setup KEYCLOAK_DB_PASSWORD='<mdp>'`), mettez à jour :

```env
KEYCLOAK_DB_USERNAME=keycloak
KEYCLOAK_DB_PASSWORD=<le mot de passe généré>
KEYCLOAK_DB_URL=jdbc:postgresql://<DB_HOST>:5432/keycloak
```

Remplacez `<DB_HOST>` par l'adresse IP / nom DNS de la VM Postgres (même valeur que `DB_HOST` utilisé en section 2), et ajustez le port si elle n'est pas sur `5432`. `make keycloak-setup` avertit si `KEYCLOAK_DB_URL` pointe toujours vers un ancien service `keycloak-db`.

## Makefile

```sh
make keycloak-setup
make keycloak-pull-images
make keycloak-stack-up
make keycloak-stack-upgrade
make keycloak-stack-down
make keycloak-debug
make keycloak-debug-logs
make keycloak-compose-up
make keycloak-compose-down
make keycloak-compose-logs
```

## Required env

| Variable | Notes |
|----------|--------|
| `KEYCLOAK_APP_URL` | Public URL including base path (warns if `example.com`) |
| `KEYCLOAK_DOMAIN` | Traefik `Host()` |
| `KEYCLOAK_BASE_PATH` | Default `/auth` → `KC_HTTP_RELATIVE_PATH` |
| `KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD` | Generated by setup if empty |
| `KEYCLOAK_DB_URL` | JDBC URL of existing Postgres VM/native DB (default `jdbc:postgresql://<DB_HOST>:5432/keycloak`; replace `<DB_HOST>`) |
| `KEYCLOAK_DB_USERNAME` / `KEYCLOAK_DB_PASSWORD` | Must match that role; password generated by setup if empty |
| `KEYCLOAK_ENV_FILE` | Compose dotenv (default `.env.example`) |

Do not commit `keycloak/.env` or real passwords.
