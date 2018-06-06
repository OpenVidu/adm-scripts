FROM ubuntu:16.04
MAINTAINER Fede Diaz nordri@gmail.com

RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl build-essential zip python

# Installing nodejs
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get install -y nodejs

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*