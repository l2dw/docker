# Smtp

## Makefile

```sh
# Run from devops/docker-templates (parent of the smtp/ folder)

## 1. copy and adjust .env from .env.example
make smtp-deploy
make smtp-remove
make smtp-redeploy
make smtp-stack-logs
make smtp-stack-watch
make smtp-stack-debug
# compose
make smtp-up
make smtp-down
make smtp-recreate
make smtp-compose-logs
make smtp-compose-watch
make smtp-test-send
```

## Configuration

Copy `smtp/.env.example` into the parent `devops/docker-templates/.env` (Makefile exports those keys for `make smtp-up` / `make smtp-deploy`). Adjust `SMTP_RELAY_NETWORKS` so it starts with `:` and lists the subnets allowed to submit mail on port 25.

The image is [namshi/smtp](https://github.com/namshi/docker-smtp). Compose maps `SMTP_RELAY_*` to `GMAIL_*` (Gmail) or `SMARTHOST_*` (other upstream hosts). Do not set both modes unless you intend Gmail to take precedence.

### Google

1. Turn on 2-Step Verification for the account.
2. Create an [App Password](https://myaccount.google.com/apppasswords) (Mail / Other).
3. In `.env`:

#### Google Workspace (authenticated smarthost)

Use `smtp.gmail.com` with the same App Password as above, or a service account / delegated mailbox if your admin allows it.

```env
SMTP_RELAY_HOST=smtp.gmail.com
SMTP_RELAY_PORT=587
SMTP_RELAY_USER=you@yourdomain.com
SMTP_RELAY_PASS=your-app-password
SMTP_RELAY_SMARTHOST_ALIASES=*.gmail.com
```


#### Google Workspace SMTP relay (`smtp.gmail.com`)

For server IP–based relay without per-message credentials, configure [SMTP relay service](https://support.google.com/a/answer/2956491) in the Admin console (allowed senders / IP). Then point the container at the relay host:

```env
SMTP_RELAY_HOST=smtp.gmail.com
SMTP_RELAY_PORT=587
SMTP_RELAY_SMARTHOST_ALIASES=*.google.com
```

`SMTP_RELAY_USER` / `SMTP_RELAY_PASS` are only required if your Workspace policy uses SMTP authentication on that route.

## Testing

Run these from `devops/docker-templates` after `make smtp-up` (or `make smtp-deploy` on Swarm).

### 1. Container and port

```sh
docker ps --filter name=smtp
make smtp-compose-logs
# or: docker logs -f smtp-smtp-1
```

Expect the container **Up** and port **25** published (e.g. `0.0.0.0:25->25/tcp`). Change the host port with `SMTP_RELAY_NODE_PORT` in `.env` if 25 is already in use.

### 2. SMTP handshake (no mail sent)

```sh
{ sleep 0.2
  printf 'HELO test.local\r\n'
  sleep 0.2
  printf 'QUIT\r\n'
} | nc -w 5 127.0.0.1 25
```

Expected:

- `220 smtp.example.com ESMTP ...`
- `250 ... Hello test.local [...]`
- `221 ... closing connection`

If you see **554 synchronization error**, wait for the `220` line before sending commands (or use `swaks` below).

Clients must be allowed by `SMTP_RELAY_NETWORKS` (must start with `:`). On Docker Desktop for Mac, connections often appear as `192.168.65.1`; a value like `:192.168.31.0/16` covers all of `192.168.0.0/16`.

### 3. Send a test message

**Script** (`bin/send-test-email.sh` — does not read `.env`; use exported vars or flags):

```sh
export SMTP_HOST=127.0.0.1 SMTP_PORT=25 SMTP_TO=you@example.com SMTP_FROM=you@gmail.com
make smtp-test-send

./bin/send-test-email.sh --from you@gmail.com --to someone@example.com --host 127.0.0.1 --port 25
make smtp-test-send ARGS='--to someone@example.com'
```

CLI flags `--from`, `--to`, `--host`, `--port` override `SMTP_FROM`, `SMTP_TO`, `SMTP_HOST`, `SMTP_PORT`. Optional: `SMTP_SUBJECT`, `SMTP_BODY`. Default sender is `$HOSTNAME@$DOMAIN` (system hostname + `SMTP_MAILNAME` or `local`). Uses `swaks` if installed, otherwise `python3`.

**swaks** (manual):

```sh
brew install swaks   # if needed

swaks \
  --server 127.0.0.1:25 \
  --from 'you@yourdomain.com' \
  --to 'your-inbox@gmail.com' \
  --header 'Subject: smtp test' \
  --body 'If you receive this, the relay works.'
```

Use `127.0.0.1:2525` if you mapped `SMTP_RELAY_NODE_PORT=2525`.

**telnet** (manual):

```sh
telnet 127.0.0.1 25
```

```text
HELO test.local
MAIL FROM:<you@yourdomain.com>
RCPT TO:<your-inbox@gmail.com>
DATA
Subject: smtp test

Test body.
.
QUIT
```

Success at the relay: `250` after the message body (`.` on its own line). Failures show as `550` / `554` or the connection closes — note the exact response.

### 4. Logs and upstream delivery

While sending, watch logs:

```sh
make smtp-compose-watch
```

Look for:

- **Accepted locally** — `250` for `RCPT` / `DATA`
- **Handoff to upstream** — no immediate `rejected` after the message is queued
- **Smarthost / auth errors** — `authentication failed`, `all hosts for 'smtp.gmail.com' have been abandoned`, etc.

For Gmail / Google Workspace via `SMTP_RELAY_HOST=smtp.gmail.com`, set `SMTP_RELAY_SMARTHOST_ALIASES=*.gmail.com` in `.env` and recreate the stack.

Confirm delivery in the recipient inbox (check spam). Delivery can take a minute.

### 5. Test from an application

Point the app at `host:25` (or the server hostname when remote). TLS is between the relay and the upstream provider, not required on the local hop to this container. Send one message and compare application logs with `make smtp-compose-logs`.

### Checklist

| Step | Good sign |
|------|-----------|
| `docker ps` | Container **Up**, port 25 (or `SMTP_RELAY_NODE_PORT`) mapped |
| `nc` / `HELO` | `220` then `250` |
| `swaks` / telnet | `250` after message body |
| Logs | No auth / reject errors after send |
| Inbox | Test mail arrives |

### Common failures

- **Relay rejects the client** — widen `SMTP_RELAY_NETWORKS` to include your Docker bridge or LAN subnet.
- **Gmail `530 Authentication Required`** — relay accepted mail locally but Gmail rejected AUTH. For `smtp.gmail.com`, set `SMTP_RELAY_SMARTHOST_ALIASES=*.gmail.com` (namshi matches `passwd.client` by host name), plus user/pass; recreate the stack. Check `docker exec smtp-smtp-1 cat /etc/exim4/passwd.client` shows `*.gmail.com:...`. If the file exists and AUTH still fails, regenerate the [App Password](https://myaccount.google.com/apppasswords) (16 characters, no spaces in `.env`).
- **Port 25 in use on the host** — set `SMTP_RELAY_NODE_PORT=2525` and test against that port.
- **linux/amd64 on Apple Silicon** — image may run under emulation; check logs for crashes or timeouts.
