#!/bin/bash -x
set -eu -o pipefail

INSTALLATION_DIRECTORY="/opt"
OPENVIDU_DIRECTORY="${INSTALLATION_DIRECTORY}/openvidu"
MEDIA_NODE_DIRECTORY="${INSTALLATION_DIRECTORY}/kms"
NIGHTLY="${1}"
OV_VERSION="${2}"

if [[ "${NIGHTLY}" == "true" ]]; then
    DATESTAMP=$(date +%m%d%Y)
    MEDIASOUP_CONTROLLER_TAG="${OV_VERSION}-nightly-${DATESTAMP}"
    MEDIA_NODE_CONTROLLER_TAG="${OV_VERSION}-nightly-${DATESTAMP}"
fi

# Stop and clean all docker images
set +e
if [[ -n "$(docker ps -a -q)" ]]; then
    docker ps -a -q | xargs docker rm -f || true
fi

# Prune docker
docker system prune --all --volumes --force || true
set -e

# Remove old installation
if [[ -d "${MEDIA_NODE_DIRECTORY}" ]]; then
    rm -rf "${MEDIA_NODE_DIRECTORY}"
fi
if [[ -d "${OPENVIDU_DIRECTORY}" ]]; then
    rm -rf "${OPENVIDU_DIRECTORY}"
fi

cd "${INSTALLATION_DIRECTORY}"
# Download and install media node
if [[ "${OV_VERSION}" == "master" ]]; then
    curl https://raw.githubusercontent.com/OpenVidu/openvidu/"${OV_VERSION}"/openvidu-server/deployments/pro/docker-compose/media-node/install_media_node.sh | bash
else
    curl curl https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/install_media_node_"${OV_VERSION}".sh | bash
fi

# Replace variables with nightly tags if specified
cd "${MEDIA_NODE_DIRECTORY}"
if [[ "${NIGHTLY}" == "true" ]] || [[ "${OV_VERSION}" == "master" ]]; then
    # Replace variables in docker-compose.yml file
    sed -i "s|image: openvidu/media-node-controller:.*|image: openvidu/media-node-controller:${MEDIA_NODE_CONTROLLER_TAG}|" docker-compose.yml
    sed -i "s|MEDIASOUP_IMAGE=openvidu/mediasoup-controller:.*|MEDIASOUP_IMAGE=openvidu/mediasoup-controller:${MEDIASOUP_CONTROLLER_TAG}|" docker-compose.yml
    docker pull openvidu/media-node-controller:"${MEDIA_NODE_CONTROLLER_TAG}"
    docker pull openvidu/mediasoup-controller:"${MEDIASOUP_CONTROLLER_TAG}"
fi

# TODO: Add option FOLLOW_MEDIA_NODE_LOGS to not follow logs
docker-compose up -d
