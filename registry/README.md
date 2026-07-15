# Registry

Private Docker Registry v2 with **htpasswd** auth. Credentials are injected via a Compose/Swarm **secret** (not a bind mount).

## Secret — create `docker-registry-htpasswd`

The registry reads htpasswd at **`REGISTRY_AUTH_HTPASSWD_PATH`** (default inside the container: `/run/secrets/docker-registry-htpasswd`).

### 1. Generate the htpasswd file

```sh
export REGISTRY_USER=cenadmin
export REGISTRY_PASS='your-strong-password'

# Option A — htpasswd on the host (apache2-utils / httpd-tools)
htpasswd -Bbn "${DOCKER_REGISTRY_USER}" "${DOCKER_REGISTRY_PASS}" > .docker-registry-htpasswd

# Option B — no local htpasswd binary
docker run --rm --entrypoint htpasswd httpd:2 -Bbn "${REGISTRY_USER}" "${REGISTRY_PASS}" \
  > .docker-registry-htpasswd

chmod 600 .docker-registry-htpasswd
```

The file must contain **one line per user**, bcrypt format, e.g.:

```text
user:$2y$05$...
```

Do not commit this file — add `registry-htpasswd` to `.gitignore`.

### 2. Optional — HTTP secret (recommended for Swarm)

Used to sign upload sessions (separate from htpasswd):

```sh
openssl rand -base64 32
# → set REGISTRY_HTTP_SECRET=... in .env
```

---

## Inject into `docker-compose.yml`

Compose declares the secret at the top of `docker-compose.yml`:

```yaml
secrets:
  docker-registry-htpasswd:
    name: ${REGISTRY_PASSWORD_SECRET_NAME:-docker-registry-htpasswd}
    file: ${REGISTRY_PASSWORD_FILE_PATH:-./.docker-registry-htpasswd}
    external: ${REGISTRY_PASSWORD_SECRET_EXTERNAL:-false}
```

The **registry** service mounts it and points auth at it:

```yaml
environment:
  REGISTRY_AUTH_HTPASSWD_PATH=${REGISTRY_AUTH_HTPASSWD_PATH:-/run/secrets/docker-registry-htpasswd}
secrets:
  - docker-registry-htpasswd
```

### Mode A — Docker Compose (`make registry-compose-up`)

Uses the **file** on disk; Compose creates the secret automatically.

In `registry/.env`:

```env
REGISTRY_PASSWORD_FILE_PATH=./docker-registry-htpasswd
REGISTRY_PASSWORD_SECRET_EXTERNAL=false
REGISTRY_AUTH_HTPASSWD_PATH=/run/secrets/docker-registry-htpasswd
```

```sh
cp .env.example .env
# create registry-htpasswd (step 1 above)
make registry-compose-up
```

### Mode B — Docker Swarm (`make registry-stack-up`)

Create the Swarm secret **once** on the manager from the same file:

```sh
docker secret create docker-registry-htpasswd .docker-registry-htpasswd
# or if the secret already exists: docker secret rm registry_htpasswd && docker secret create ...
```

In `registry/.env`:

```env
REGISTRY_PASSWORD_SECRET_NAME=docker-registry-htpasswd
REGISTRY_PASSWORD_SECRET_EXTERNAL=true
REGISTRY_AUTH_HTPASSWD_PATH=/run/secrets/docker-registry-htpasswd
```

```sh
make registry-stack-up
```

Swarm mounts the secret at `/run/secrets/docker-registry-htpasswd` (Compose secret key name).

---

## Verify login

```sh
docker login ${DOCKER_REGISTRY_HOST} -u "${DOCKER_REGISTRY_USER}" -p "${DOCKER_REGISTRY_PASS}"
```

---

## Makefile

```sh
# Run from devops/docker-templates (parent of the registry/ folder)

## 1. copy and adjust .env from .env.example

## 2. command
make registry-pull-images
make registry-deploy
make registry-remove
make registry-redeploy
make registry-stack-logs
make registry-stack-watch
make registry-stack-debug
# compose
make registry-compose-upgrade
make registry-compose-up
make registry-compose-down
make registry-compose-recreate
make registry-compose-logs
make registry-compose-watch
```
