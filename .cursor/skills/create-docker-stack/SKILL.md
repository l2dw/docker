---
name: create-docker-stack
description: Scaffolds a new application Docker stack in this docker-templates repo (dedicated git branch, project directory, Makefile, compose.yml without labels plus docker-compose.yml with Traefik/Homepage labels). Use when creating a new app stack, docker-compose.yml, Swarm stack, wrapping an image, or when the user asks to dockeriser une application, créer un stack, copier le template tpl, or follow the template/dictfp/dokploy structure.
---

# Create Docker stack

Scaffold a new **application** stack in this repo. Do **not** recreate Traefik/WAF (apps join the existing overlay). Do **not** commit `.env`, overrides, or secrets. Do **not** push unless asked.

Read [conventions.md](conventions.md) before writing compose, env, Makefile, or Traefik/Homepage labels.

## Sources of truth (read before generating)

Copy patterns from git — the working tree may only contain the current stack. **Create the new branch from `master`.** Use other branches only via `git show` (do not check them out to copy files):

| Source | What to copy |
|--------|----------------|
| Branch `master` | Base for `git checkout -b <projet>` |
| Branch `template` | File patterns (`tpl` / `TPL` rename) via `git show` |
| Branch `dictfp` | `<projet>/Makefile` + root `-include <projet>/Makefile` via `git show` |
| `dokploy/` / `arcane/` if present | Unified compose: two files, dual Traefik labels, single-level `${VAR:-default}` |

```sh
git show template:template/docker-compose.yml
git show template:template/.env.example
git show dictfp:dictfp/Makefile
git show dictfp:Makefile | tail -n 20
```

Prefer current conventions over older `x-*` / quoted `privileged` / literal `external: true` in those sources.

## Workflow

Copy this checklist and complete in order:

```
- [ ] 0. Working tree propre (sinon STOP)
- [ ] 1. Collecter le brief
- [ ] 2. Nommer projet et préfixe
- [ ] 3. Branche dédiée depuis master
- [ ] 4. Copier template tpl
- [ ] 5. Écrire compose.yml + docker-compose.yml
- [ ] 6. Écrire .env.example
- [ ] 7. Cibles Makefile
- [ ] 8. README projet
- [ ] 9. Valider compose
```

### 0. Working tree propre — STOP si non commit

**Before any checkout or file write**, run:

```sh
git status --porcelain
```

If the output is **not empty** (staged, unstaged, or untracked files):

1. **STOP.** Do not `git checkout`, stash, commit, or generate the stack.
2. Tell the user the tree is dirty and list `git status --short`.
3. Ask them to commit or discard, then retry.

Ignored files (`.env`, overrides) do not appear in `--porcelain` and are fine.

### 1. Collecter le brief

If missing, ask (do not invent production domains or secrets):

- Stack name, image(s) + tags, HTTP port
- Volumes (data/logs), extra services (db, redis)
- Traefik: domain, `PathPrefix`, TLS, middlewares
- Swarm vs Compose (both targets unless user says otherwise)

### 2. Nommer projet et préfixe

| Thing | Rule | Example |
|-------|------|---------|
| Directory / branch / stack | kebab-case, `[a-z0-9-]+` | `myapp` |
| Env prefix | `SCREAMING_SNAKE` + `_` | `MYAPP_` |
| Compose services | `<projet>` or `<projet>-<role>` | `myapp`, `myapp-db` |
| Router/service Traefik | same as compose service | `myapp` |

Do not reuse `tpl` / `TPL` in generated files.

### 3. Branche dédiée depuis `master`

**Une branche ≈ un stack.** Do not add a second project onto `dokploy`, `arcane`, or another app branch.

Create the branch **from `master`** (not `template`, not `main` unless `master` is missing):

```sh
git checkout master
git checkout -b <projet>
```

Equivalent: `git checkout -b <projet> master`.

If already **on** `<projet>` and it was created from `master` **and** step 0 passed, keep it. Never mix unrelated stacks in one working tree commit.

### 4. Copier template tpl

```sh
git show template:template/docker-compose.yml
# copy patterns from template (git show) → <projet>/ — do not checkout template
# replace tpl → <projet>, TPL → <PREFIX>, Tpl → Title
```

Delete `stack-compose.yml` unless the user explicitly wants that name. Always write **two** compose files (see step 5). Make / `bin/resolve-project-compose.sh` prefer `stack-compose.yml` if present, else `docker-compose.yml` (labeled). `compose.yml` is unlabeled and not the Make default.

### 5. Écrire compose.yml + docker-compose.yml

Two files, same services / volumes / `deploy:` (mode, replicas, placement, `restart_policy`):

| File | Labels |
|------|--------|
| `<projet>/compose.yml` | **None** — no `labels:` / `deploy.labels`, no Traefik, no Homepage |
| `<projet>/docker-compose.yml` | Traefik + Homepage on `deploy.labels` (Swarm) **and** service `labels` (Compose). Gate with `<PREFIX>_TRAEFIK_LABELS_SWARM_ENABLE` and `<PREFIX>_TRAEFIK_LABELS_DOCKER_ENABLE` |

Keep `compose.yml` and `docker-compose.yml` in sync except for labels. Make targets use `docker-compose.yml`. Use `compose.yml` when Traefik/Homepage must not see the service.

Network: `name: ${DEFAULT_NETWORK_NAME:-dokploy-network}` and `external: ${DEFAULT_NETWORK_EXTERNAL:-false}` (unquoted). No `x-*` keys. No quotes around `${…}` booleans (`privileged`, `external`). Do not nest interpolation. Details in [conventions.md](conventions.md).

### 6. Écrire .env.example

- `<projet>/.env.example` — all `<PREFIX>_*` keys
- Root `.env.example` — same project keys (Make exports root `.env` for `stack deploy`)
- Include `DEFAULT_NETWORK_NAME`, `DEFAULT_NETWORK_EXTERNAL=false`, `<PREFIX>_TRAEFIK_LABELS_SWARM_ENABLE`, `<PREFIX>_TRAEFIK_LABELS_DOCKER_ENABLE`
- Placeholders only (`ChangeMe`, empty secrets). Never copy real passwords.

### 7. Cibles Makefile

Create `<projet>/Makefile` from `dictfp/Makefile` (rename `dictfp` / `DICTFP`). At end of root `Makefile`:

```make
-include <projet>/Makefile
```

Required targets: `<projet>-stack-up|down|recreate|upgrade|logs`, `<projet>-compose-up|down|restart|logs`, `<projet>-debug`, `<projet>-debug-logs`, `<projet>-pull-images`.

Stack up must call `stack-deploy STACK_NAME=<projet>` (directory name = stack name). On older branches, make `stack-deploy` fall back to `docker-compose.yml` if `stack-compose.yml` is absent.

### 8. README projet

Short `<projet>/README.md`: what the stack is, `make <projet>-stack-up` / `make <projet>-compose-up`, required env, debug targets. Note that `docker stack deploy` does not read `.env` alone — use Make.

### 9. Valider compose

```sh
docker compose -f <projet>/compose.yml --env-file <projet>/.env.example config
docker compose -f <projet>/docker-compose.yml --env-file <projet>/.env.example config
docker stack config -c <projet>/docker-compose.yml   # if CLI supports it
```

Confirm `compose.yml` has **no** `traefik.` / `homepage.` labels. Fix errors before finishing. Do not create `.env` or `*.override.yml` unless asked.

## Out of scope

- Traefik, WAF, certs-dumper as part of the app stack
- Committing `.env`, `*.override.*`, or secrets
- Push / `make commit-changes` unless the user asks
