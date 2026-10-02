# Jenkins

Jenkins LTS (`docker.io/jenkins/jenkins:lts`) with Traefik PathPrefix `/jenkins` via `JENKINS_OPTS=--prefix=/jenkins`.

```sh
make jenkins-setup JENKINS_DOMAIN=jenkins.example.com
make jenkins-stack-up
```

| File | Labels |
|------|--------|
| [`compose.yml`](compose.yml) | Homepage only |
| [`docker-compose.yml`](docker-compose.yml) | Traefik + Homepage |

`JENKINS_HOMEPAGE_URL=` empty by default. Mounts Docker socket for agents/out-of-container builds.
