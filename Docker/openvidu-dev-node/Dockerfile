FROM ubuntu:16.04
MAINTAINER Fede Diaz nordri@gmail.com

RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl build-essential zip

# Installing nodejs
RUN curl -sL https://deb.nodesource.com/setup_10.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    apt-get install -y nodejs && \
    rm nodesource_setup.sh

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*