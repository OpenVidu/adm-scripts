FROM ubuntu:22.04

LABEL maintainer=carlos.ruizbal@gmail.com

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    git \
    curl \
    jq \
    zip \
    openjdk-11-jdk \
    python3 \
    python3-pip \
    pwgen \
    lsb-release \
    maven \
    awscli \
    python3-lxml \
    openssh-client \
    ffmpeg \
    build-essential \
    gnupg

# Installing docker
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Installing nodejs
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

RUN echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /root/.bashrc

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*