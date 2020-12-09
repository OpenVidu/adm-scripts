FROM ubuntu:18.04

LABEL maintainer=carlos.ruizbal@gmail.com

ENV DEBIAN_FRONTEND=noninteractive

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
    openjdk-11-jdk \
    python-lxml \
    openssh-client \
    ffmpeg

# Installing nodejs
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y nodejs

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*