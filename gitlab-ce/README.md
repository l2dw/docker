# GitLab CE

GitLab Community Edition (Omnibus image [`gitlab/gitlab-ce`](https://hub.docker.com/r/gitlab/gitlab-ce)) with **external PostgreSQL and Redis**: the bundled `postgresql` and `redis` services are disabled (`postgresql['enable']=false`, `redis['enable']=false`) and GitLab connects to yours. Default network `gitlab-ce-network`.

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${GITLAB_ENV_FILE:-.env.example}`; production: `GITLAB_ENV_FILE=.env`. `environment:` overrides the file. Swarm relies on the Make-exported root `.env` + `environment:` interpolation (not `env_file`).

```sh
make gitlab-ce-setup \
  GITLAB_DOMAIN=gitlab.example.com \
  GITLAB_EXTERNAL_URL=https://gitlab.example.com \
  GITLAB_DB_HOST=postgres GITLAB_DB_PASSWORD=<à renseigner> \
  GITLAB_REDIS_HOST=redis
make gitlab-ce-stack-up
# or
make gitlab-ce-compose-up
```

`gitlab-ce-setup` creates `gitlab-ce/.env`, generates `GITLAB_ROOT_PASSWORD` if empty, checks the required keys (domain, external URL, DB host/password, Redis host), warns on `example.com`, syncs `DEFAULT_NETWORK_EXTERNAL` and creates the stack-local network.

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | Homepage only |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage |

Database/Redis settings reach GitLab through `GITLAB_OMNIBUS_CONFIG`; the passwords are passed as environment variables read with `ENV[...]`, never written in the config string.

## External PostgreSQL

Create the role, database and extensions beforehand (PostgreSQL 16 or later recommended; check the version matrix of your GitLab release):

```sql
CREATE ROLE gitlab WITH LOGIN PASSWORD '<à renseigner>';
CREATE DATABASE gitlabhq_production OWNER gitlab ENCODING 'UTF8';
\c gitlabhq_production
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS plpgsql;
```

The extensions require a superuser (or a role allowed to create trusted extensions). Keys: `GITLAB_DB_HOST`, `_PORT`, `_NAME`, `_USER`, `_PASSWORD`. The database host must be reachable from the stack network (see Networks).

## External Redis

A single Redis instance (`GITLAB_REDIS_HOST`, `_PORT`, `_PASSWORD`; empty password = no AUTH). Use a dedicated instance or a dedicated Redis for GitLab: it stores sessions, cache and Sidekiq queues.

## Ports

HTTP goes through Traefik (no published HTTP port). Git over SSH is TCP and published: host `GITLAB_SSH_PUBLISHED_PORT` (default `2222`) → container `GITLAB_SSH_PORT` (`22`); `gitlab_shell_ssh_port` is set to the published port so clone URLs are right.

## Base path

Host-only by default (`GITLAB_BASE_PATH=/`). GitLab Omnibus supports a relative URL, but it is fragile (registry, Pages, runners): prefer a dedicated subdomain. For a subpath set both `GITLAB_BASE_PATH=/gitlab` and `GITLAB_EXTERNAL_URL=https://host/gitlab`. `GITLAB_HOMEPAGE_URL=` stays empty; fill the public URL later. `APP_NAME=gitlab-ce` scopes the Traefik router/service names (Dokploy may override it).

## First login

User `root`, password `GITLAB_ROOT_PASSWORD` (first start only; later changes are made in GitLab). Reading it: `grep GITLAB_ROOT_PASSWORD gitlab-ce/.env`.

## Resources

`GITLAB_MEMORY_LIMIT=4G` (GitLab's minimum); raise it for many users. Swarm ignores `shm_size`; if Compose shows `/dev/shm` errors, add `shm_size: 256m` in a local override.

## Networks

Default `gitlab-ce-network` / `DEFAULT_NETWORK_EXTERNAL=false`, created by `make gitlab-ce-setup` (or Swarm/Compose). To reach a shared PostgreSQL/Redis and Traefik on Dokploy: `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true` (joined, never created). Manual: `docker network create gitlab-ce-network --driver overlay`.

## Volumes

| Key | Container path | Content |
|-----|----------------|---------|
| `config` | `/etc/gitlab` | `gitlab.rb`, `gitlab-secrets.json` — **back it up**: losing it makes encrypted DB values unreadable |
| `logs` | `/var/log/gitlab` | logs |
| `data` | `/var/opt/gitlab` | repositories, uploads, artifacts, LFS |

Each volume has `GITLAB_<KEY>_VOLUME_{NAME,EXTERNAL,DRIVER,TYPE,OPTS,PATH,DIR}`. Recipes (shown for `DATA`):

| Mode | `EXTERNAL` | `TYPE` | `OPTS` | `PATH` |
|------|-----------|--------|--------|--------|
| Local named (default) | `false` | empty | empty | empty |
| Bind | `false` | `none` | `bind` | `/appdata/gitlab-ce/data` |
| NFS | `false` | `nfs` | `addr=nfs-host,rw,nfsvers=4` | `:/exports/gitlab-ce/data` |
| External | `true` | — | — | — (`NAME` = existing volume) |

```sh
docker volume create gitlab_data
docker volume create --driver local --opt type=nfs \
  --opt o=addr=nfs.example.com,rw,nfsvers=4 --opt device=:/exports/gitlab-ce/data gitlab_data
```

Back up with `gitlab-backup create` plus the `config` volume; the external PostgreSQL has its own backups.

## Debug

`make gitlab-ce-debug`, `make gitlab-ce-debug-logs`, `make gitlab-ce-pull-images`. First start takes several minutes (migrations).
