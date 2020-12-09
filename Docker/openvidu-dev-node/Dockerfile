FROM ubuntu:18.04
LABEL mantainer=carlos.ruizbalgmail.com

RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl build-essential zip python python-lxml

# Installing nodejs
RUN curl -sLk https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y nodejs

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*