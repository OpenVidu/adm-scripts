# VERSION 0.1 September 11, 2017

FROM ubuntu:16.04
MAINTAINER Fede Diaz nordri@gmail.com

RUN apt-get update && \
    apt-get install -y git curl build-essential maven openjdk-8-jdk python-lxml

# Installing nodejs
RUN curl -sL https://deb.nodesource.com/setup_8.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    apt-get install -y nodejs && \
    rm nodesource_setup.sh

# Installing angular-cli
RUN npm install -g @angular/cli


