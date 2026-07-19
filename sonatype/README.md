# Sonatype Nexus Repository Manager 3

Swarm/compose template for `sonatype/nexus3` on `dokploy-network`.

## Setup

```sh
# From devops/docker-templates
cp sonatype/.env.example sonatype/.env   # or merge into root .env
# keep MEMORY_LIMIT ≥ JVM heap + MaxDirectMemorySize
```

UI listens on **8081** (overlay / publish as needed). Optional host port **5000** is for a Docker registry connector you enable in Nexus.

Initial admin password (first boot):

```sh
docker exec <nexus-task> cat /nexus-data/admin.password
```

## Makefile

```sh
make sonatype-pull-images
make sonatype-stack-up
make sonatype-stack-down
make sonatype-stack-recreate
make sonatype-stack-logs
make sonatype-stack-watch-logs
make sonatype-debug
make sonatype-debug-logs
# compose (non-swarm)
make sonatype-compose-up
make sonatype-compose-down
make sonatype-compose-recreate
make sonatype-compose-logs
make sonatype-compose-watch-logs
```

## Notes

- Data (and logs) live under `/nexus-data` only.
- Default memory limit is **4G**; do not set `SONATYPE_MEMORY_LIMIT=512M` with a 1g+ heap.
- Default placement is `node.role == worker`; use `node.role==manager` on single-node swarms.
