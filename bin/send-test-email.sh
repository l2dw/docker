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
  TZ            timezone for Date header and default body stamp (e.g. America/Montreal)
EOF
}

# Local time in TZ (exported by make from .env); avoids UTC-only body timestamps.
now_local() {
  TZ=${TZ:-UTC} date '+%Y-%m-%d %H:%M:%S %Z'
}

mail_date_header() {
  TZ=${TZ:-UTC} date '+%a, %d %b %Y %H:%M:%S %z'
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
    mailname=${SMTP_MAILNAME:-smtp.local}
    from="noreply@${mailname}"
fi

subject=${SMTP_SUBJECT:-smtp test}
date_hdr=$(mail_date_header)
body=${SMTP_BODY:-Test message from send-test-email.sh at $(now_local).}

echo "Sending test mail"
echo "  server:  ${host}:${port}"
echo "  from:    ${from}"
echo "  to:      ${to}"
echo "  subject: ${subject}"
echo "  date:    ${date_hdr}"

if command -v swaks >/dev/null 2>&1; then
  exec swaks \
    --server "${host}:${port}" \
    --from "$from" \
    --to "$to" \
    --header "Date: ${date_hdr}" \
    --header "Subject: ${subject}" \
    --body "$body"
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 - "$host" "$port" "$from" "$to" "$subject" "$body" "$date_hdr" <<'PY'
import smtplib
import sys
from email.message import EmailMessage

host, port_s, from_addr, to_addr, subject, body, date_hdr = sys.argv[1:8]
port = int(port_s)

msg = EmailMessage()
msg["From"] = from_addr
msg["To"] = to_addr
msg["Subject"] = subject
msg["Date"] = date_hdr
msg.set_content(body)

with smtplib.SMTP(host, port, timeout=30) as smtp:
    smtp.send_message(msg)

print("250 Message accepted for delivery (local relay)")
PY
fi

echo "Error: install swaks (brew install swaks) or ensure python3 is available." >&2
exit 1
