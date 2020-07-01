#!/bin/bash -x

### Variables ###
OPENVIDU_RECORDING_UBUNTU_VERSION=$OPENVIDU_RECORDING_UBUNTU_VERSION
OPENVIDU_RECORDING_CHROME_VERSION=$OPENVIDU_RECORDING_CHROME_VERSION
OPENVIDU_RECORDING_DOCKER_TAG=$OPENVIDU_RECORDING_DOCKER_TAG

# Change directory to openvidu-recording
pushd openvidu-server/docker/openvidu-recording

# Docker login
docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"

# Build image with parameters
docker build --no-cache --rm=true --build-arg CHROME_VERSION="$OPENVIDU_RECORDING_CHROME_VERSION" \
    -f $OPENVIDU_RECORDING_UBUNTU_VERSION.Dockerfile \
    -t openvidu/openvidu-recording:$OPENVIDU_RECORDING_DOCKER_TAG . \
    && docker push openvidu/openvidu-recording:$OPENVIDU_RECORDING_DOCKER_TAG

docker logout