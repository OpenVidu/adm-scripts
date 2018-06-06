FROM ubuntu:16.04
MAINTAINER Fede Diaz nordri@gmail.com

RUN apt-get update && \
    apt-get install -y git curl build-essential

# Installing nodejs
RUN curl -sL https://deb.nodesource.com/setup_10.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    apt-get install -y nodejs && \
    rm nodesource_setup.sh
