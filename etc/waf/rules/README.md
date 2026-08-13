# WAF custom rules (ModSecurity CRS)

Versioned custom configs for the Dokploy `waf` service (`owasp/modsecurity-crs`).

| File | When it runs |
|------|----------------|
| `REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` | Before CRS request rules |
| `RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf` | After CRS response rules |

Delivered via **Docker Swarm configs** (see `dokploy/docker-compose.yml`) onto:

`/etc/modsecurity.d/owasp-crs/rules/<filename>`

Do **not** replace the whole rules directory — that would hide the upstream CRS.

After editing these files: bump `DOKPLOY_WAF_*_CRS_CONFIG_NAME` in `.env`, then `stack deploy` (Swarm configs are immutable).
