#!/bin/bash -x
set -eu -o pipefail

export COMPOSE_HTTP_TIMEOUT=500
export DOCKER_CLIENT_TIMEOUT=500

INSTALLATION_DIRECTORY="/opt"
OPENVIDU_DIRECTORY="${INSTALLATION_DIRECTORY}/openvidu"
CUSTOM_LOCATIONS_DIRECTORY_FOLDER_NAME="custom-nginx-locations"
CUSTOM_LOCATIONS_DIRECTORY="${OPENVIDU_DIRECTORY}/${CUSTOM_LOCATIONS_DIRECTORY_FOLDER_NAME}"
# If true, openvidu-call will not be updated on update
NIGHTLY="${1}"
KEEP_OV_CALL="${2}"
OV_VERSION="${3}"

if [[ "${NIGHTLY}" == "true" ]]; then
    OPENVIDU_SERVER_PRO_TAG="${3}"
    OPENVIDU_REDIS_TAG="${4}"
    OPENVIDU_NGINX_PROXY_TAG="${5}"
    OPENVIDU_COTURN_TAG="${6}"
    OPENVIDU_CALL_VERSION="${7}"
    MEDIASOUP_CONTROLLER_TAG="${8}"
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
    if [[ -d "${OPENVIDU_DIRECTORY}"/certificates ]]; then
        mv "${OPENVIDU_DIRECTORY}"/certificates "${INSTALLATION_DIRECTORY}"/old-certificates
    fi

    # TODO: Comment if you want to keep docker-compose.override.yml
    if [[ "${KEEP_OV_CALL}" == 'true' ]]; then
        if [[ -f "${OPENVIDU_DIRECTORY}"/docker-compose.override.yml ]]; then
            mv "${OPENVIDU_DIRECTORY}"/docker-compose.override.yml "${INSTALLATION_DIRECTORY}"/old-docker-compose.override.yml
        fi
    fi
    # Remove previous installation
    rm -rf "${OPENVIDU_DIRECTORY}"
fi

cd "${INSTALLATION_DIRECTORY}"
# Download and install media node
if [[ "${NIGHTLY}" == "true" ]] || [[ "${OV_VERSION}" == "master" ]]; then
    curl https://raw.githubusercontent.com/OpenVidu/openvidu/master/openvidu-server/deployments/pro/docker-compose/openvidu-server-pro/install_openvidu_pro.sh | bash
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

if [[ -d "${INSTALLATION_DIRECTORY}"/old-certificates ]]; then
    # Remove empty certificates folder
    if [[ -d "${OPENVIDU_DIRECTORY}"/certificates ]]; then
        rm -rf "${OPENVIDU_DIRECTORY}"/certificates
    fi

    # Rename and move
    mv "${INSTALLATION_DIRECTORY}"/old-certificates "${INSTALLATION_DIRECTORY}"/certificates
    mv "${INSTALLATION_DIRECTORY}"/certificates "${OPENVIDU_DIRECTORY}"/certificates
fi

if [[ -f "${INSTALLATION_DIRECTORY}"/old-docker-compose.override.yml ]]; then
    rm "${OPENVIDU_DIRECTORY}"/docker-compose.override.yml
    mv "${INSTALLATION_DIRECTORY}"/old-docker-compose.override.yml "${OPENVIDU_DIRECTORY}"/docker-compose.override.yml
fi

# Create custom location to show versions file
cat >"${CUSTOM_LOCATIONS_DIRECTORY}"/versions.conf <<EOF
location ~ ^/versions$ {
    add_header Content-Type text/plain;
    add_header X-Content-Type-Options nosniff;
    alias /${CUSTOM_LOCATIONS_DIRECTORY_FOLDER_NAME}/versions.txt;
}
EOF

# Insert cron to generate versions if it was not installed
if ! crontab -l | grep 'next_call_generate_versions_file.sh' 1>/dev/null 2>&1; then
    crontab -l >/tmp/crontab.tmp
    echo "*/5 * * * * ${OPENVIDU_DIRECTORY}/next_call_generate_versions_file.sh" >>/tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
fi

cd "${OPENVIDU_DIRECTORY}"

# Replace variables with nightly tags if specified
if [[ "${NIGHTLY}" == "true" ]]; then
    # Replace variables in docker-compose.yml file
    sed -i "s|image: openvidu/openvidu-server-pro:.*|image: openvidu/openvidu-server-pro:${OPENVIDU_SERVER_PRO_TAG}|" docker-compose.yml
    sed -i "s|image: openvidu/openvidu-redis:.*|image: openvidu/openvidu-redis:${OPENVIDU_REDIS_TAG}|" docker-compose.yml
    sed -i "s|image: openvidu/openvidu-coturn:.*|image: openvidu/openvidu-coturn:${OPENVIDU_COTURN_TAG}|" docker-compose.yml
    sed -i "s|image: openvidu/openvidu-proxy:.*|image: openvidu/openvidu-proxy:${OPENVIDU_NGINX_PROXY_TAG}|" docker-compose.yml
    if [[ "${KEEP_OV_CALL}" == 'false' ]]; then
        sed -i "s|image: openvidu/openvidu-call:.*|image: openvidu/openvidu-call:${OPENVIDU_CALL_VERSION}|" docker-compose.override.yml
    fi

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
    docker pull openvidu/openvidu-proxy:"${OPENVIDU_NGINX_PROXY_TAG}"
    docker pull openvidu/openvidu-call:"${OPENVIDU_CALL_VERSION}"
fi


# Start openvidu
systemctl restart docker
export FOLLOW_OPENVIDU_LOGS=false
/bin/bash openvidu stop
/bin/bash openvidu start
