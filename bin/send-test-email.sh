#!/usr/bin/env sh
# Send a test message to an SMTP server (local relay or other).
# Configure via environment variables; CLI flags override env.
set -eu

usage() {
  cat <<'EOF'
Usage: send-test-email.sh [options]

Options (override environment):
  --from ADDR   envelope sender (SMTP_FROM)
  --to ADDR     recipient (SMTP_TO)
  --host HOST   SMTP server host (SMTP_HOST)
  --port PORT   SMTP server port (SMTP_PORT)

  -h, --help    show this help

Environment (export before running, or pass via make):
  SMTP_HOST     server host (default: 127.0.0.1)
  SMTP_PORT     server port (default: 25)
  SMTP_TO       recipient (required if --to omitted)
  SMTP_FROM     sender (default: `hostname`)
  SMTP_SUBJECT  message subject (default: smtp test)
  SMTP_BODY     message body
EOF
}

arg_from=
arg_to=
arg_host=
arg_port=

while [ $# -gt 0 ]; do
  case "$1" in
    --from)
      [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
      arg_from=$2
      shift 2
      ;;
    --to)
      [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
      arg_to=$2
      shift 2
      ;;
    --host)
      [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
      arg_host=$2
      shift 2
      ;;
    --port)
      [ $# -ge 2 ] || { echo "Error: $1 requires a value" >&2; exit 1; }
      arg_port=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      echo "Error: unexpected argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

host=${arg_host:-${SMTP_HOST:-127.0.0.1}}
port=${arg_port:-${SMTP_PORT:-25}}
to=${arg_to:-${SMTP_TO:-}}
from=${arg_from:-${SMTP_FROM:-$HOSTNAME}}

if [ -z "$to" ]; then
  echo "Error: recipient required (set SMTP_TO or use --to)" >&2
  exit 1
fi

if [ -z "$from" ]; then
  if [ -n "${SMTP_SMARTHOST_USER:-}" ]; then
    from=$SMTP_SMARTHOST_USER
  else
    mailname=${SMTP_MAILNAME:-smtp.local}
    from="noreply@${mailname}"
  fi
fi

subject=${SMTP_SUBJECT:-smtp test}
body=${SMTP_BODY:-Test message from send-test-email.sh at $(date -u '+%Y-%m-%d %H:%M:%S UTC').}

echo "Sending test mail"
echo "  server:  ${host}:${port}"
echo "  from:    ${from}"
echo "  to:      ${to}"
echo "  subject: ${subject}"

if command -v swaks >/dev/null 2>&1; then
  exec swaks \
    --server "${host}:${port}" \
    --from "$from" \
    --to "$to" \
    --header "Subject: ${subject}" \
    --body "$body"
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 - "$host" "$port" "$from" "$to" "$subject" "$body" <<'PY'
import smtplib
import sys
from email.message import EmailMessage

host, port_s, from_addr, to_addr, subject, body = sys.argv[1:7]
port = int(port_s)

msg = EmailMessage()
msg["From"] = from_addr
msg["To"] = to_addr
msg["Subject"] = subject
msg.set_content(body)

with smtplib.SMTP(host, port, timeout=30) as smtp:
    smtp.send_message(msg)

print("250 Message accepted for delivery (local relay)")
PY
fi

echo "Error: install swaks (brew install swaks) or ensure python3 is available." >&2
exit 1
