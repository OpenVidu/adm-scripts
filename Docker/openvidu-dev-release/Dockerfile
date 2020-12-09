# VERSION 0.1 September 11, 2017

FROM ubuntu:18.04
LABEL maintainer=carlos.ruizbal@gmail.com

RUN apt-get update && \
    apt-get install -y git curl build-essential maven openjdk-11-jdk python-lxml

# Installing nodejs
RUN curl -sL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    apt-get install -y nodejs && \
    rm nodesource_setup.sh

# Installing angular-cli
RUN npm install -g @angular/cli


