FROM ubuntu:18.04

LABEL maintainer=carlos.ruizbal@gmail.com

RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl openjdk-11-jdk python curl maven

RUN echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /root/.bashrc

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*


