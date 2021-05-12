#!/bin/bash -x
set -eu -o pipefail

DATESTAMP=$(date +%Y%m%d)

# Create a nightly docker container for OpenVidu Server
pushd openvidu-server/docker/openvidu-server

# Download nightly version of OpenVidu Server
curl -o openvidu-server.jar http://builds.openvidu.io/openvidu/nightly/latest/openvidu-server-latest.jar

# Build docker image
if [[ -z "${OV_VERSION}" ]]; then
    ./create_image.sh nightly-"${DATESTAMP}"
else 
    ./create_image.sh "${OV_VERSION}"
fi

# Upload the image
docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"
if [[ -z "${OV_VERSION}" ]]; then
    docker push openvidu/openvidu-server:nightly-"${DATESTAMP}"
else 
    docker push openvidu/openvidu-server:"${OV_VERSION}"
fi

docker logout
