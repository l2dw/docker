# Bugsink

Self-hosted error tracking ([bugsink/bugsink](https://github.com/bugsink/bugsink)) on `dokploy-network`.

## Setup

```sh
cp .env.example .env   # or merge into root .env
# set BUGSINK_SECRET_KEY (openssl rand -base64 50)
# set BUGSINK_CREATE_SUPERUSER=you@example.com:strong-password
# production: set BUGSINK_DATABASE_URL and uncomment DATABASE_URL in docker-compose.yml
```

## Makefile

```sh
make bugsink-pull-images
make bugsink-stack-up
make bugsink-stack-down
make bugsink-stack-recreate
make bugsink-stack-logs
make bugsink-stack-watch-logs
make bugsink-debug
make bugsink-debug-logs
# compose (non-swarm)
make bugsink-compose-upgrade
make bugsink-compose-up
make bugsink-compose-down
make bugsink-compose-recreate
make bugsink-compose-logs
make bugsink-compose-watch-logs
```


## Notes

- `BUGSINK_SECRET_KEY` is required (≥50 characters).
- Leave `BUGSINK_DATA` empty to use the `bugsink_data` named volume mounted at `/data`.
- Placement defaults to any Linux node; set `BUGSINK_PLACEMENT_CONSTRAINTS` to pin.
- Behind TLS Traefik: set `BUGSINK_BEHIND_HTTPS_PROXY=true`, `BUGSINK_USE_X_FORWARDED_HOST=true`, and `BUGSINK_BASE_URL=https://…`.
