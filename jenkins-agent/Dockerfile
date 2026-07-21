FROM docker.io/jenkins/inbound-agent:latest

USER root

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG USER_UID=1000
ARG USER_GID=1000
ARG USER_NAME=jenkins
ARG DOCKER_VERSION=27.3.1
ARG JENKINS_AGENT_WORKDIR=/var/jenkins-agent

ENV http_proxy=${HTTP_PROXY}
ENV https_proxy=${HTTPS_PROXY}
ENV no_proxy=${NO_PROXY}
ENV JENKINS_AGENT_WORKDIR=${JENKINS_AGENT_WORKDIR}

RUN apt-get update && apt-get install -y \
    make \
    curl \
    sudo \
    ca-certificates \
    openssh-client \
    postgresql-client \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI (use host socket via -v /var/run/docker.sock:/var/run/docker.sock)
ENV DOCKER_VERSION=27.3.1
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
    | tar xz -C /tmp && mv /tmp/docker/docker /usr/local/bin/docker && chmod +x /usr/local/bin/docker && rm -rf /tmp/docker

# MinIO client
RUN curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc \
    -o /usr/local/bin/mc && chmod +x /usr/local/bin/mc

# Create group if it doesn't exist
RUN groupadd -g ${USER_GID} ${USER_NAME} || true

# Create user if it doesn't exist
RUN useradd -m -u ${USER_UID} -g ${USER_GID} ${USER_NAME} || true

# Add user to docker group
RUN usermod -u ${USER_UID} ${USER_NAME} || true
RUN groupmod -g ${USER_GID} ${USER_NAME} || true

# Add user to root group
RUN usermod -aG root ${USER_NAME} || true
RUN usermod -aG docker ${USER_NAME} || true
RUN echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# # Add user to root group
# RUN usermod -aG root jenkins || true
# RUN usermod -aG docker jenkins || true
# RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN mkdir -p /home/${USER_NAME} ${JENKINS_AGENT_WORKDIR} && chown -R ${USER_UID}:${USER_GID} /home/${USER_NAME} ${JENKINS_AGENT_WORKDIR}

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}
