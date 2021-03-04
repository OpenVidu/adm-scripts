# VERSION 0.1 September 11, 2017

FROM ubuntu:18.04
LABEL maintainer=carlos.ruizbal@gmail.com

RUN apt-get update && \
    apt-get install -y git curl build-essential openjdk-11-jdk maven python-lxml

# Installing nodejs
RUN curl -sL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    apt-get install -y nodejs && \
    rm nodesource_setup.sh

RUN echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /root/.bashrc

# Installing angular-cli
RUN npm install -g @angular/cli


