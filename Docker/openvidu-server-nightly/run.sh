#!/bin/bash

/usr/bin/java -jar -Dspring.profiles.active=docker $MAVEN_OPTS /openvidu-server.jar