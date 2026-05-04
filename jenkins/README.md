# Jenkins

## Makefile

```sh
# Run from devops/docker-templates (parent of the dokploy/ folder)

## 1. copy and adjust .env from .env.example
#stack
make jenkins-deploy
make jenkins-remove
make jenkins-redeploy
make jenkins-stack-logs
make jenkins-stack-watch
make jenkins-stack-debug
# compose
make jenkins-up
make jenkins-down
make jenkins-recreate
make jenkins-compose-logs
make jenkins-compose-watch
```
