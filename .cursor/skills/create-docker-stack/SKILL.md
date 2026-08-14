---
name: create-docker-stack
description: Scaffolds a new application Docker stack in this docker-templates repo (dedicated git branch, project directory, Makefile, compose.yml without labels plus docker-compose.yml with Traefik/Homepage labels, base_path check, root symlinks for README/compose). Use when creating a new app stack, docker-compose.yml, Swarm stack, wrapping an image, or when the user asks to dockeriser une application, créer un stack, copier le template tpl, or follow the template/dictfp/dokploy structure.
---

# Create Docker stack

Scaffold a new **application** stack in this repo. Do **not** recreate Traefik/WAF (apps join the existing overlay). Do **not** commit `.env`, overrides, or secrets. Do **not** push unless asked.

Read [conventions.md](conventions.md) before writing compose, env, Makefile, or Traefik/Homepage labels.

## Sources of truth (read before generating)

Copy patterns from the **local ignored scaffold** `_trash/template/` (see `.gitignore`: `_trash/`). **Create the new branch from `master`.** Do not commit `_trash/`. Do not check out git branch `template` to copy files.

| Source | What to copy |
|--------|----------------|
| Branch `master` | Base for `git checkout -b <projet>` |
| `_trash/template/` | Scaffold (`tpl` / `TPL` / `Tpl` rename). Gitignored — not in the repo |
| `dokploy/` / `arcane/` if present | Apply current conventions on top of the scaffold (two compose files, no `x-*`, unquoted booleans) |

```sh
ls _trash/template/
# compose.yml docker-compose.yml .env.example Makefile README.md
```

If `_trash/template/` is missing: **STOP** and tell the user the ignored scaffold is absent. Prefer [conventions.md](conventions.md) over older `x-*` / quoted `privileged` / literal `external: true` in the trash copy.

## Workflow

Copy this checklist and complete in order:

```
- [ ] 0. Working tree propre (sinon STOP)
- [ ] 1. Collecter le brief
- [ ] 1b. Vérifier base_path (docs app)
- [ ] 2. Nommer projet et préfixe
- [ ] 3. Branche dédiée depuis master
- [ ] 4. Copier template tpl
- [ ] 5. Écrire compose.yml + docker-compose.yml
- [ ] 6. Écrire .env.example
- [ ] 7. Cibles Makefile
- [ ] 8. README projet
- [ ] 8b. Symlinks racine (README + compose)
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

Ignored files (`.env`, overrides, `_trash/`) do not appear in `--porcelain` and are fine.

### 1. Collecter le brief

If missing, ask (do not invent production domains or secrets):

- Stack name, image(s) + tags, HTTP port
- Volumes (data/logs), extra services (db, redis)
- Traefik: domain, desired `base_path` / subpath (if any), TLS, middlewares
- Swarm vs Compose (both targets unless user says otherwise)

### 1b. Vérifier `base_path` (docs de l’app)

**Before writing compose**, check the app’s official docs / image env reference for subpath / reverse-proxy support.

Look for names such as: `base path`, `basePath`, `BASE_PATH`, `ROOT_PATH`, `CONTEXT_PATH`, `SUBPATH`, `serve under a path`, `URL prefix`, `ASSET_PREFIX`, `APP_BASE`, or equivalent.

| Result | What to do |
|--------|------------|
| **Supported** | Set `<PREFIX>_BASE_PATH` to the chosen path (e.g. `/myapp`, never a trailing slash unless the app requires it). Wire the **app** env var documented by the vendor into `environment:` (both compose files). Keep Traefik `PathPrefix(\`${<PREFIX>_BASE_PATH:-/}\`)` and `homepage.href` with that path. Document the vendor env name + example in the project README. |
| **Not supported / unclear** | Default `<PREFIX>_BASE_PATH=/`. Prefer **Host-only** routing (subdomain). Do **not** invent a fake app base-path env. Do **not** rely on Traefik `stripPrefix` alone unless the user explicitly asks — many SPAs break. State in the README that subpath deploy is unsupported. |

If the user asked for a subpath but the app cannot do it: warn and keep `/` (or Host-only), do not silently configure a broken PathPrefix.

Details and label examples: [conventions.md](conventions.md) (§ Base path).

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

### 4. Copier template tpl depuis `_trash/`

Scaffold is **gitignored**: `_trash/template/`. Never `git add` `_trash/`.

```sh
test -d _trash/template || { echo "missing ignored scaffold _trash/template/"; exit 1; }
cp -R _trash/template <projet>
# replace in <projet>/ : TPL → PREFIX, Tpl → Title, tpl → projet
```

Then rewrite files to match [conventions.md](conventions.md) (step 5–7): `compose.yml` unlabeled + `docker-compose.yml` labeled; drop `x-*`; unquoted booleans. Delete `stack-compose.yml` unless the user wants that name. Make uses `docker-compose.yml`.

### 5. Écrire compose.yml + docker-compose.yml

Two files, same services / volumes / `deploy:` (mode, replicas, placement, `restart_policy`):

| File | Labels |
|------|--------|
| `<projet>/compose.yml` | **None** — no `labels:` / `deploy.labels`, no Traefik, no Homepage |
| `<projet>/docker-compose.yml` | Traefik + Homepage on `deploy.labels` (Swarm) **and** service `labels` (Compose). Gate with `<PREFIX>_TRAEFIK_LABELS_SWARM_ENABLE` and `<PREFIX>_TRAEFIK_LABELS_DOCKER_ENABLE` |

Keep `compose.yml` and `docker-compose.yml` in sync except for labels. Make targets use `docker-compose.yml`. Use `compose.yml` when Traefik/Homepage must not see the service.

Network: `name: ${DEFAULT_NETWORK_NAME:-dokploy-network}` and `external: ${DEFAULT_NETWORK_EXTERNAL:-false}` (unquoted). No `x-*` keys. No quotes around `${…}` booleans (`privileged`, `external`). Do not nest interpolation. Do **not** add network `aliases` unless the user asks or a Dokploy-style stable hostname is required. Details in [conventions.md](conventions.md).

If step **1b** found a supported base path: include the vendor env in `environment:` and use `<PREFIX>_BASE_PATH` in Traefik/Homepage labels (labeled file only).

### 6. Écrire .env.example

- `<projet>/.env.example` — all `<PREFIX>_*` keys
- Root `.env.example` — same project keys (Make exports root `.env` for `stack deploy`)
- Include `DEFAULT_NETWORK_NAME`, `DEFAULT_NETWORK_EXTERNAL=false`, `<PREFIX>_BASE_PATH`, `<PREFIX>_TRAEFIK_LABELS_SWARM_ENABLE`, `<PREFIX>_TRAEFIK_LABELS_DOCKER_ENABLE`
- Placeholders only (`ChangeMe`, empty secrets). Never copy real passwords.

### 7. Cibles Makefile

Create `<projet>/Makefile` from `_trash/template/Makefile` (rename `tpl` / `TPL`). At end of root `Makefile`:

```make
-include <projet>/Makefile
```

Required targets: `<projet>-stack-up|down|recreate|upgrade|logs`, `<projet>-compose-up|down|restart|logs`, `<projet>-debug`, `<projet>-debug-logs`, `<projet>-pull-images`.

Stack up must call `stack-deploy STACK_NAME=<projet>` (directory name = stack name). On older branches, make `stack-deploy` fall back to `docker-compose.yml` if `stack-compose.yml` is absent.

### 8. README projet

Short `<projet>/README.md`: what the stack is, `make <projet>-stack-up` / `make <projet>-compose-up`, required env, debug targets. Note that `docker stack deploy` does not read `.env` alone — use Make.

Include a short **Base path** note: supported or not, vendor env name if any, default `<PREFIX>_BASE_PATH=/`.

### 8b. Symlinks racine (README + compose)

After the project files exist, create **relative** symlinks at the **repo root** pointing into `<projet>/`:

```sh
ln -sfn <projet>/README.md README.md
ln -sfn <projet>/compose.yml compose.yml
ln -sfn <projet>/docker-compose.yml docker-compose.yml
```

Rules:

- Targets: `README.md`, `compose.yml`, `docker-compose.yml` only (not `.env.example`, not `Makefile`).
- Relative links (`<projet>/…`), never absolute paths.
- If a **regular file** already exists at the root with that name: **do not overwrite**. Ask the user, or leave it and report it. If it is already a symlink to this project (or broken to the same path), refresh with `ln -sfn`.
- Commit the symlinks with the stack (they are part of the branch-per-stack layout).
- Verify: `ls -l README.md compose.yml docker-compose.yml` → each is a symlink into `<projet>/`.

### 9. Valider compose

```sh
docker compose -f <projet>/compose.yml --env-file <projet>/.env.example config
docker compose -f <projet>/docker-compose.yml --env-file <projet>/.env.example config
docker stack config -c <projet>/docker-compose.yml   # if CLI supports it
```

Also confirm root symlinks resolve:

```sh
test -f README.md && test -f compose.yml && test -f docker-compose.yml
```

Confirm `compose.yml` (project file) has **no** `traefik.` / `homepage.` labels. Fix errors before finishing. Do not create `.env` or `*.override.yml` unless asked.

## Out of scope

- Traefik, WAF, certs-dumper as part of the app stack
- Committing `.env`, `*.override.*`, `_trash/`, or secrets
- Push / `make commit-changes` unless the user asks
