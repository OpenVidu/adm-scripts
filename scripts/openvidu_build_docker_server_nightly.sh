#!/bin/bash -x
set -eu -o pipefail

DATESTAMP=$(date +%Y%m%d)

# Create a nightly docker container for OpenVidu Server
pushd openvidu-server/docker/openvidu-server

# Download nightly version of OpenVidu Server
curl -o ../../target/openvidu-server-latest.jar http://builds.openvidu.io/openvidu/nightly/latest/openvidu-server-latest.jar

# Build docker image
./create_image.sh nightly-"${DATESTAMP}"

# Upload the image
docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"
docker push openvidu/openvidu-server:nightly-"${DATESTAMP}"

docker logout
