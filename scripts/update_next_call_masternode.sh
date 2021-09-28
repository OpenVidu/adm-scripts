#!/bin/bash -x
set -eu -o pipefail

INSTALLATION_DIRECTORY="/opt"
OPENVIDU_DIRECTORY="${INSTALLATION_DIRECTORY}/openvidu"
NIGHTLY="${1}"
OV_VERSION="${2:-master}"
if [[ "${NIGHTLY}" == "true" ]]; then
    DATESTAMP=$(date +%m%d%Y)
    OV_VERSION="master"
    OPENVIDU_SERVER_PRO_TAG="nightly-${DATESTAMP}"
    OPENVIDU_REDIS_TAG="nightly-${DATESTAMP}"
    OPENVIDU_COTURN_TAG="nightly-${DATESTAMP}"
    OPENVIDU_PROXY_TAG="nightly-${DATESTAMP}"
    MEDIASOUP_CONTROLLER_TAG="nightly-${DATESTAMP}"
fi

# Stop and clean all docker images
set +e
if [[ -n "$(docker ps -a -q)" ]]; then
    docker ps -a -q | xargs docker rm -f || true
fi


# Prune docker
docker system prune --all --volumes --force || true
set -e

# Move necessary files from previous version if exist
if [[ -d "${OPENVIDU_DIRECTORY}" ]]; then
    if [[ -f "${OPENVIDU_DIRECTORY}"/.env ]]; then
        mv "${OPENVIDU_DIRECTORY}"/.env "${INSTALLATION_DIRECTORY}"/.old-env
    fi
    if [[ -d "${OPENVIDU_DIRECTORY}"/elasticsearch ]]; then
        mv "${OPENVIDU_DIRECTORY}"/elasticsearch "${INSTALLATION_DIRECTORY}"/old-elasticsearch
    fi
    # Remove previous installation
    rm -rf "${OPENVIDU_DIRECTORY}"
fi

cd "${INSTALLATION_DIRECTORY}"
# Download and install media node
if [[ "${OV_VERSION}" == "master" ]]; then
    curl https://raw.githubusercontent.com/OpenVidu/openvidu/"${OV_VERSION}"/openvidu-server/deployments/pro/docker-compose/openvidu-server-pro/install_openvidu_pro.sh | bash
else
    curl https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/install_openvidu_pro_"${OV_VERSION}".sh | bash
fi

if [[ -f "${INSTALLATION_DIRECTORY}"/.old-env ]]; then
    # Rename old environment variables
    mv "${INSTALLATION_DIRECTORY}"/.old-env "${OPENVIDU_DIRECTORY}"/.old-env
    mv "${OPENVIDU_DIRECTORY}"/.env "${OPENVIDU_DIRECTORY}"/.orig-env
    mv "${OPENVIDU_DIRECTORY}"/.old-env "${OPENVIDU_DIRECTORY}"/.env
fi

if [[ -d "${INSTALLATION_DIRECTORY}"/old-elasticsearch ]]; then
    # Remove empty elasticsearch folder
    rm -rf "${OPENVIDU_DIRECTORY}"/elasticsearch

    # Rename and move
    mv "${INSTALLATION_DIRECTORY}"/old-elasticsearch "${INSTALLATION_DIRECTORY}"/elasticsearch
    mv "${INSTALLATION_DIRECTORY}"/elasticsearch "${OPENVIDU_DIRECTORY}"/elasticsearch
fi

cd "${OPENVIDU_DIRECTORY}"

# Replace variables with nightly tags if specified
if [[ "${NIGHTLY}" == "true" ]]; then
    # Replace variables in docker-compose.yml file
    sed -i "s|image: openvidu/openvidu-server-pro:.*|image: openvidu/openvidu-server-pro:${OPENVIDU_SERVER_PRO_TAG}|" docker-compose.yml
    sed -i "s|image: openvidu/openvidu-redis:.*|image: openvidu/openvidu-redis:${OPENVIDU_REDIS_TAG}|" docker-compose.yml
    sed -i "s|image: openvidu/openvidu-coturn:.*|image: openvidu/openvidu-coturn:${OPENVIDU_COTURN_TAG}|" docker-compose.yml
    sed -i "s|image: openvidu/openvidu-proxy:.*|image: openvidu/openvidu-proxy:${OPENVIDU_PROXY_TAG}|" docker-compose.yml

    # Replace MEDIASOUP IMAGE
    if grep -q "^MEDIASOUP_IMAGE=*" < .env; then
        # If variable exists and it is not commented
        sed -i "s|MEDIASOUP_IMAGE=.*|MEDIASOUP_IMAGE=openvidu/mediasoup-controller:${MEDIASOUP_CONTROLLER_TAG}|" .env
    else
        # If not exist or is commented, add it to the end
        echo "MEDIASOUP_IMAGE=openvidu/mediasoup-controller:${MEDIASOUP_CONTROLLER_TAG}" >> .env
    fi
    docker pull openvidu/openvidu-server-pro:"${OPENVIDU_SERVER_PRO_TAG}"
    docker pull openvidu/openvidu-redis:"${OPENVIDU_REDIS_TAG}"
    docker pull openvidu/openvidu-coturn:"${OPENVIDU_COTURN_TAG}"
    docker pull openvidu/openvidu-proxy:"${OPENVIDU_PROXY_TAG}"
fi

export FOLLOW_OPENVIDU_LOGS=false
/bin/bash openvidu start
