FROM ubuntu:16.04

MAINTAINER Fede Diaz nordri@gmail.com

RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl maven openjdk-8-jdk python

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*


