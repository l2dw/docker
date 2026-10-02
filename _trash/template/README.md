# Tpl

Scaffold a new stack by copying this folder and renaming `tpl` → your app name (case preserved).

## Scaffold

```sh
# From devops/docker-templates
APP=myapp   # lowercase slug
SRC=_trash/template

cp -R "$SRC" "$APP"

# Replace in all files (order: UPPER → Title → lower)
find "$APP" -type f -print0 | xargs -0 perl -pi -e '
  s/TPL/\U'"$APP"'\E/g;
  s/Tpl/\u'"$APP"'\E/g;
  s/tpl/'"$APP"'/g;
'
```

| from | to (`APP=myapp`) |
|------|------------------|
| `tpl` | `myapp` |
| `Tpl` | `Myapp` |
| `TPL` | `MYAPP` |

Then copy `.env.example` → `.env` and fill in values.

## Makefile

Targets below become `$APP-*` after scaffold (e.g. `make myapp-stack-up`).

```sh
# Run from devops/docker-templates (parent of the app folder)
make tpl-pull-images
make tpl-stack-up
make tpl-stack-down
make tpl-stack-recreate
make tpl-stack-logs
make tpl-stack-watch-logs
make tpl-debug
make tpl-debug-logs
# compose
make tpl-compose-upgrade
make tpl-compose-up
make tpl-compose-down
make tpl-compose-recreate
make tpl-compose-logs
make tpl-compose-watch-logs
```
