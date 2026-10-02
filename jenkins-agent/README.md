# Jenkins Agent

Inbound Jenkins agent (`jenkins/inbound-agent:lts`) with optional local Dockerfile build. No Traefik (worker). Homepage labels present for inventory.

```sh
make jenkins-agent-setup
make jenkins-agent-stack-up
```

Set `JENKINS_SERVER_URL`, `JENKINS_AGENT_NODE_NAME`, and `JENKINS_AGENT_NODE_SECRET` from the Jenkins controller.
