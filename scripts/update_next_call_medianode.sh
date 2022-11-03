#!/bin/bash -x
set -eu -o pipefail

export COMPOSE_HTTP_TIMEOUT=500
export DOCKER_CLIENT_TIMEOUT=500

INSTALLATION_DIRECTORY="/opt"
OPENVIDU_DIRECTORY="${INSTALLATION_DIRECTORY}/openvidu"
MEDIA_NODE_DIRECTORY="${INSTALLATION_DIRECTORY}/kms"
NIGHTLY="${1}"
OV_VERSION="${2}"

if [[ "${NIGHTLY}" == "true" ]]; then
    MEDIASOUP_CONTROLLER_TAG="${3}"
    MEDIA_NODE_CONTROLLER_TAG="${4}"
    COTURN_TAG="${5}"
    OPENVIDU_PRO_SPEECH_TO_TEXT_TAG="${6}"
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
if [[ "${NIGHTLY}" == "true" ]] || [[ "${OV_VERSION}" == "master" ]]; then
    curl https://raw.githubusercontent.com/OpenVidu/openvidu/master/openvidu-server/deployments/pro/docker-compose/media-node/install_media_node.sh | bash
else
    curl curl https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/install_media_node_"${OV_VERSION}".sh | bash
fi

# Replace variables with nightly tags if specified
cd "${MEDIA_NODE_DIRECTORY}"
if [[ "${NIGHTLY}" == "true" ]]; then
    # Replace variables in docker-compose.yml file
    sed -i "s|image: openvidu/media-node-controller:.*|image: openvidu/media-node-controller:${MEDIA_NODE_CONTROLLER_TAG}|" docker-compose.yml
    sed -i "s|MEDIASOUP_IMAGE=openvidu/mediasoup-controller:.*|MEDIASOUP_IMAGE=openvidu/mediasoup-controller:${MEDIASOUP_CONTROLLER_TAG}|" docker-compose.yml
    sed -i "s|COTURN_IMAGE=openvidu/openvidu-coturn:.*|COTURN_IMAGE=openvidu/openvidu-coturn:${COTURN_TAG}|" docker-compose.yml
    sed -i "s|SPEECH_TO_TEXT_IMAGE=openvidu/speech-to-text-service:.*|SPEECH_TO_TEXT_IMAGE=openvidu/speech-to-text-service:${OPENVIDU_PRO_SPEECH_TO_TEXT_TAG}|" docker-compose.yml
    docker pull openvidu/media-node-controller:"${MEDIA_NODE_CONTROLLER_TAG}"
    docker pull openvidu/mediasoup-controller:"${MEDIASOUP_CONTROLLER_TAG}"
    docker pull openvidu/openvidu-coturn:"${COTURN_TAG}"
    docker pull openvidu/speech-to-text-service:"${OPENVIDU_PRO_SPEECH_TO_TEXT_TAG}"
fi

# TODO: Add option FOLLOW_MEDIA_NODE_LOGS to not follow logs
systemctl restart docker
docker-compose down
docker-compose up -d
