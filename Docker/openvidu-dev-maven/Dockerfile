FROM ubuntu:18.04

LABEL maintainer=carlos.ruizbal@gmail.com

RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl maven openjdk-11-jdk python curl

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*


