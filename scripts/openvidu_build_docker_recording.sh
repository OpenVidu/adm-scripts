#!/bin/bash -x

# Change directory to openvidu-recording
pushd openvidu-server/docker/openvidu-recording

# Docker login
docker login -u $OPENVIDU_DOCKERHUB_USER -p $OPENVIDU_DOCKERHUB_PASSWD

# Build image with parameters
./create_image.sh $OPENVIDU_RECORDING_CHROME_VERSION $OPENVIDU_RECORDING_DOCKER_TAG

# Push image
docker push openvidu/openvidu-recording:$OPENVIDU_RECORDING_DOCKER_TAG

docker logout
