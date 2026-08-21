# Memcached

Official [Memcached](https://hub.docker.com/_/memcached) (`memcached:1.6.45-alpine`) on **TCP 11211**. **Not an HTTP app**: no Traefik/Homepage labels (`compose.yml` → symlink of `docker-compose.yml`).

Port **11211 is not published on the host**. Other stacks on the same overlay reach it as `memcached:11211` (Compose service name). Example: Xibo `XIBO_MEMCACHED_HOST=memcached`.

`.env` is **not** read by `docker stack deploy` alone — use Make. Compose `env_file` loads `${MEMCACHED_ENV_FILE:-.env.example}`; production: `MEMCACHED_ENV_FILE=.env`. `environment:` wins on key conflicts.

```sh
make memcached-setup
make memcached-compose-up   # or: make memcached-stack-up
```

## Base path

**Not applicable** (TCP). `MEMCACHED_BASE_PATH=/` is unused. Subpath deploy does not apply.

## Process vs container memory

| Key | Role |
|-----|------|
| `MEMCACHED_CACHE_MEMORY` | `memcached --memory-limit` (MB inside the process, default 64) |
| `MEMCACHED_MEMORY_LIMIT` | Swarm/Compose container limit (default 1G) |

Also: `MEMCACHED_CONN_LIMIT`, `MEMCACHED_THREADS`.

## Network

Default `DEFAULT_NETWORK_NAME=memcached-network` (`EXTERNAL=false`). For shared Dokploy overlay: `DEFAULT_NETWORK_NAME=dokploy-network` and `DEFAULT_NETWORK_EXTERNAL=true`.

## Ops

| Target | Role |
|--------|------|
| `memcached-setup` | Env + network pairing |
| `memcached-stack-up` / `memcached-compose-up` | Deploy |
| `memcached-debug` / `memcached-debug-logs` | Swarm inspect |
| `memcached-pull-images` | Pull images |
