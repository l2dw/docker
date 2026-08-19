# nginx

HTTP nginx serving **static files** on the existing overlay (`dokploy-network`). Traefik is the ingress; port 80 is not published on the host.

Default image: `nginx:alpine`. There is **no Redis**. Vanilla nginx has **no native S3 filesystem**.

## SPA (`try_files`) and Swarm `configs`

`nginx/default.conf` is injected with Compose/Swarm **`configs:`** (not a host bind) onto `/etc/nginx/conf.d/default.conf`. It uses:

```
try_files $uri $uri/ /index.html;
```

Existing files (JS/CSS under `/assets/…`) are served as-is. Unknown paths (React/Vue/Angular history routes) fall back to `index.html` so a refresh does not 404.

`docker stack deploy` reads `file: ./default.conf` from the compose directory and creates a cluster config object named `NGINX_DEFAULT_CONF_NAME` (default `nginx_default_conf`). Docker configs are **immutable**: after you edit `default.conf`, bump `NGINX_DEFAULT_CONF_NAME` (e.g. `nginx_default_conf_v2`) then `make nginx-stack-up`. Compose recreates the config on the next up.

Do **not** attach this config when `NGINX_IMAGE` is nginx-s3-gateway (it would overwrite the gateway’s nginx). Comment out the `configs:` blocks in that case.

## npm `/dist`

Build on the host or in CI, then bind the output directory (HTML only — conf stays a Swarm config):

```sh
npm ci && npm run build
# in nginx/.env (absolute path on the Docker host):
NGINX_HTML_DIR=/path/to/your-app/dist
make nginx-setup
make nginx-compose-up
```

Vite / webpack / Next `output: export` work as long as `dist/` contains `index.html` (and hashed assets). This stack does **not** run `npm` inside the container.

Redeploy after a new build: the HTML bind is live on Compose; Swarm may need the replica on the node that has the path (`NGINX_PLACEMENT_CONSTRAINTS`).

## Sources (folder, git, S3)

| Source | How |
|--------|-----|
| **Folder / dist** | Set `NGINX_HTML_DIR` to an **absolute host path** (bind → `/usr/share/nginx/html`). Pin the task with `NGINX_PLACEMENT_CONSTRAINTS` if the path exists on one Swarm node only. |
| **Git** | Clone (or `git pull`) **on the host**, then bind that tree (or its `dist/` after build). This stack does not run `git` inside the container. |
| **S3 / RustFS / MinIO** | nginx **cannot** mount a bucket as a folder. Switch `NGINX_IMAGE` to [nginx-s3-gateway](https://github.com/nginxinc/nginx-s3-gateway) and fill `NGINX_S3_*`. That image **proxies** HTTP to S3 with SigV4. A prefix in the bucket is an **object key prefix**, not a POSIX directory. FUSE (`s3fs`) is not used here. |

Empty `NGINX_HTML_DIR` uses the named volume `nginx_html`.

## Base path

Official nginx does not implement an app `BASE_PATH`. Default `NGINX_BASE_PATH=/` (Host + `PathPrefix(/)`). Serving under `/files` without rewriting HTML/asset URLs usually breaks; prefer a dedicated subdomain. For Vite, set `base: '/'` (or match Traefik) at **build** time.

## Traefik / `APP_NAME`

Dokploy may inject `APP_NAME` so Traefik router/service names do not collide. It is **not** in `.env.example`. Compose YAML service key stays `nginx`.

## Env file vs Swarm

- Compose: `NGINX_ENV_FILE` (default `.env.example`; production `.env`). `environment:` overrides the file.
- `docker stack deploy` does **not** reliably apply `env_file`. Use Make (`make nginx-stack-up`) so root `.env` is exported and `environment:` interpolates.

## Make

```sh
make nginx-setup
make nginx-stack-up      # Swarm
make nginx-compose-up    # Compose
make nginx-debug
make nginx-debug-logs
```

`nginx-setup` copies `.env.example` → `nginx/.env`, warns on `example.com` / S3 `ChangeMe` when the image is the gateway, and sets `DEFAULT_NETWORK_EXTERNAL` (`true` iff `DEFAULT_NETWORK_NAME` is `dokploy-network` or empty).
