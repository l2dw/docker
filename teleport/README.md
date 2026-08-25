# Teleport

[Teleport Community Edition](https://goteleport.com/docs/installation/docker/) (`public.ecr.aws/gravitational/teleport-distroless:18.10.0`) — Auth + Proxy in one container. Web UI **HTTPS 3080** (Traefik terminates TLS in front; backend uses Teleport’s own TLS). Auth listen **3025**.

## Quick start

```sh
make teleport-setup
# edit teleport/.env (TELEPORT_DOMAIN) then re-run setup to render config
make teleport-compose-up   # or: make teleport-stack-up
```

First admin (distroless: no shell — call `tctl` as the container command):

```sh
docker compose -f teleport/docker-compose.yml exec teleport \
  tctl users add admin --roles=editor,access
```

Image entrypoint already runs `teleport start -c /etc/teleport/teleport.yaml` — do **not** set a Compose `command:` with another `start` (that yields `unexpected start`).

Use Make for Swarm: `docker stack deploy` does not load `.env` alone.

## Config

`teleport-setup` writes `teleport/config/teleport.yaml` from `config/teleport.yaml.example` (cluster_name / public_addr from `TELEPORT_DOMAIN`). That file is gitignored. Compose `configs:` mounts it at `/etc/teleport/teleport.yaml`. Scaffold/docs default: `TELEPORT_CONFIG_FILE=./config/teleport.yaml.example`. After setup: `./config/teleport.yaml`.

`TELEPORT_DOMAIN` drives Traefik `Host()` (must match the browser hostname). `teleport-setup` syncs DOMAIN from `TELEPORT_APP_URL` when DOMAIN still uses `example.com`, and warns if they diverge. `public_addr` defaults to `<domain>:443` (clients + Traefik). `trust_x_forwarded_for: true`.

## Base path

**Unsupported.** Default `TELEPORT_BASE_PATH=/` (Host-only subdomain). Do not use a URL prefix or Traefik stripPrefix.

## Env / env_file

- `TELEPORT_ENV_FILE` (default `.env.example`; prod → `.env`).
- Compose merges `env_file` + `environment:`; **`environment:` wins**.
- Swarm relies on Make-exported root `.env` + compose interpolation (not Compose `env_file`).
- Traefik talks **HTTPS** to port 3080 (rely on Traefik’s global `serversTransport.insecureSkipVerify`; do not set a custom `serversTransport` label — Docker provider does not create it and the router fails with 404).
- Traefik middleware `${APP_NAME}-br` forces `Accept-Encoding: br` upstream. Teleport only serves `/web/app/app.js` as precompressed Brotli — without `br` the UI is a blank/black page ([teleport#66500](https://github.com/gravitational/teleport/issues/66500)).
- UI is on **HTTPS** (`websecure` + TLS). HTTP router redirects via Dokploy `redirect-to-https`. CSRF cookies are `__Host-…; Secure`.
- `TELEPORT_TLS_CERTRESOLVER` empty → Traefik default cert (fine for `*.local`). Set `letsencrypt` only for public hostnames.
- `APP_NAME` (Dokploy) scopes Traefik router/service names; not listed in `.env.example`.

## Network / Traefik

Default `DEFAULT_NETWORK_NAME=teleport-network` (`EXTERNAL=false`). Shared overlay + Traefik: set `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true` **explicitly** in `teleport/.env`, then `make teleport-setup` (syncs NAME + EXTERNAL into root `.env` — Make exports the root file and it must not stay on a stale `dokploy-network` with `EXTERNAL=false`). No network aliases by default.

Agents join via the public HTTPS address (`TELEPORT_PUBLIC_ADDR`), not a published host port.

## Ops

| Target | Role |
|--------|------|
| `teleport-setup` | Env, render `teleport.yaml`, network pairing |
| `teleport-stack-up` / `teleport-compose-up` | Deploy |
| `teleport-debug` / `teleport-debug-logs` | Swarm inspect |
| `teleport-pull-images` | Pull images |
