#!/bin/bash
trap 'err_report $LINENO' ERR

err_report() {
    rm "${FILE_NAME_DIRECTORY}"
    echo "Error generating versions file" > "${FILE_NAME_DIRECTORY}"
}

parse_image_info() {
    IMAGE="${1}"
    PROJECT="Unknown"
    NIGHTLY="false"
    COMMIT="Unknown"
    DATE="Unknown"
    if [[ "${IMAGE}" =~ "openvidu-redis" ]] || [[ "${IMAGE}" =~ "openvidu-coturn" ]] || [[ "${IMAGE}" =~ "openvidu-proxy" ]]; then
        PROJECT="openvidu/openvidu-server"
    else
        PROJECT=$(echo "${IMAGE}" | cut -d":" -f1 || echo "Unknown")
    fi
    if [[ "${IMAGE}" =~ "nightly" ]]; then
        NIGHTLY="true"
        COMMIT=$(echo "${IMAGE}" | cut -d ":" -f2 | cut -d "-" -f3 || echo "Unkown")
        DATE_UNPARSED=$(echo "${IMAGE}" | cut -d ":" -f2 | cut -d "-" -f4 || echo "Unkown")
        if  [[ "${DATE_UNPARSED}" != "Unknown" ]]; then
            YEAR="$(echo "$DATE_UNPARSED" | cut -c 1-4)"
            MONTH="$(echo "$DATE_UNPARSED" | cut -c 5-6)"
            DAY="$(echo "$DATE_UNPARSED" | cut -c 7-8)"
            DATE="${DAY}-${MONTH}-${YEAR}"
        fi
    fi
    echo -e "Project: ${PROJECT} \t | Nightly: ${NIGHTLY} \t | Commit: ${COMMIT} \t | Date: ${DATE} \t | Docker Image: ${IMAGE}"
}


OPENVIDU_DIRECTORY="/opt/openvidu"
CUSTOM_LOCATIONS_DIRECTORY_FOLDER_NAME="custom-nginx-locations"
CUSTOM_LOCATIONS_DIRECTORY="${OPENVIDU_DIRECTORY}/${CUSTOM_LOCATIONS_DIRECTORY_FOLDER_NAME}"
FILE_NAME_DIRECTORY="${CUSTOM_LOCATIONS_DIRECTORY}/versions.txt"

# Templated variables
MEDIA_NODE_PORT={{MEDIA_NODE_PORT}}
MEDIA_NODE_CONTAINERS_PATH={{MEDIA_NODE_CONTAINERS_PATH}}

# Get OpenVidu secret
OV_SECRET="$(cat ${OPENVIDU_DIRECTORY}/.env | grep "OPENVIDU_SECRET=" | cut -d'=' -f2 || echo '')"
OPENVIDU_IMAGES=$(docker ps | grep 'openvidu/' | tr -s ' ' | cut -d' ' -f2 || echo '')
MEDIA_NODES_IPS=$(curl -s -u OPENVIDUAPP:"${OV_SECRET}" http://localhost:5443/openvidu/api/config | grep -oP 'KMS_URIS(.*?)]' | grep -oP '[0-9]{1,3}(\.[0-9]{1,3}){3}')

{
    echo "Call Next versions: Format <version>-<commit>-<mmddyy>"
    echo "Info updated at: $(date)"
    echo "==================="
    echo "Master Node"
    echo "==================="
    echo ""
    for IMAGE in ${OPENVIDU_IMAGES}; do
       parse_image_info "${IMAGE}"
    done
    echo
    for MEDIA_NODE_IP in ${MEDIA_NODES_IPS}; do
        echo "==================="
        echo "Media Node: ${MEDIA_NODE_IP}"
        echo "==================="
        MEDIASOUP_IMAGE=$(curl -s http://"${MEDIA_NODE_IP}":"${MEDIA_NODE_PORT}"/"${MEDIA_NODE_CONTAINERS_PATH}" | grep -oP '"openvidu/mediasoup-controller:(.*?)"' | head -n 1 | tr -d '"' || echo '')
        KMS_IMAGE=$(curl -s http://"${MEDIA_NODE_IP}":"${MEDIA_NODE_PORT}"/"${MEDIA_NODE_CONTAINERS_PATH}" | grep -oP '"kurento/kurento-media-server:(.*?)"' | head -n 1 | tr -d '"' || echo '')
        [[ -n "${MEDIASOUP_IMAGE}" ]] && parse_image_info "${MEDIASOUP_IMAGE}"
        [[ -n "${KMS_IMAGE}" ]] && parse_image_info "${KMS_IMAGE}"
        echo
    done
} &> "${FILE_NAME_DIRECTORY}"
