FROM ubuntu:16.04
MAINTAINER nordri@gmail.com

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    git \
    curl \
    jq \
    zip \
    python \
    python-pip \
    pwgen \
    lsb-release \
    maven \
    awscli \
    openjdk-8-jdk \
    python-lxml \
    openssh-client

# Installing nodejs
RUN curl -sLk https://deb.nodesource.com/setup_8.x | bash - && \
    apt-get install -y nodejs

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*