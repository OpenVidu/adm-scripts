FROM ubuntu:16.04
MAINTAINER nordri@gmail.com

RUN apt-get update \
    && apt-get install --no-install-recommends -y git curl jq python python-pip pwgen lsb-release maven 

# Install AWS Cli
RUN pip install awscli --upgrade --user

# Installing nodejs
RUN curl -sLk https://deb.nodesource.com/setup_8.x | bash - && \
    apt-get install -y nodejs
