FROM ubuntu:16.04
MAINTAINER openvidu@gmail.com

# Install Java
RUN apt-get update && \
    apt-get install -y openjdk-8-jdk

# Cleaning the house
RUN apt-get clean && \
    apt-get autoclean && \
    rm -Rf /tmp/* && \
    rm -Rf /var/lib/apt/lists/*

# Copy OpenVidu Server
COPY openvidu-server.jar /

EXPOSE 4443
EXPOSE 8888

# Exec supervisord
CMD [ "/bin/bash", "-c", "java", "-jar", "-Dspring.profiles.active=docker", "/openvidu-server.jar" ]
