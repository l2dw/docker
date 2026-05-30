# Postfix relay

[boky/postfix](https://github.com/bokysan/docker-postfix) relay with optional Gmail upstream.

## Makefile

Run from `devops/docker-templates` (parent `.env` is loaded by `make`).

```sh
# Swarm
make postfix-relay-stack-deploy
make postfix-relay-stack-test-send   # test via overlay DNS (recommended on Docker Desktop)
make postfix-relay-stack-remove

# Compose (local host port 2525)
make postfix-relay-up
make send-test-email                 # SMTP_HOST=localhost SMTP_PORT=2525
make postfix-relay-down
```

## Docker Desktop (Mac) + Swarm

`make postfix-relay-stack-deploy` publishes `${POSTFIX_NODEPORT:-2525}` on the host, but on **Docker Desktop** that port often accepts TCP without reaching Postfix (no SMTP banner). The service is still reachable on the overlay network as **`postfix-relay:25`**.

Use:

```sh
make postfix-relay-stack-test-send
```

For sends from the Mac host, use **Compose** instead (`make postfix-relay-up`), or remove the stack first so port 2525 is free for compose.

## Configuration

Copy `postfix-relay/.env.example` into the parent `.env`. Required for boky/postfix:

- `POSTFIX_ALLOWED_SENDER_DOMAINS` — envelope sender domains (e.g. `gmail.com` or `example.com`)
- `POSTFIX_RELAYHOST` / `POSTFIX_RELAYHOST_USERNAME` / `POSTFIX_RELAYHOST_PASSWORD` for upstream relay

Test sender must match `POSTFIX_ALLOWED_SENDER_DOMAINS` (e.g. `SMTP_FROM=kantor@example.com` when the domain is `example.com`).
