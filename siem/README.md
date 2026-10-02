# SIEM (Elasticsearch + Kibana)

Stack branch: `siem`. Compose: Traefik + Homepage in `docker-compose.yml`; Homepage only in `compose.yml`.

## Quick start

```sh
make siem-setup
make siem-compose-up
# or Swarm:
make siem-stack-up
```

Generate transport TLS once (`cert-utils`), then ensure `kibana_system` password matches Elasticsearch.

Host requirement: `vm.max_map_count >= 262144`.
