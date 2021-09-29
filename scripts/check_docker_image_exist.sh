#!/bin/bash
[ -n "${OPENVIDU_DOCKERHUB_USER}" ] || exit 1
[ -n "${OPENVIDU_DOCKERHUB_PASSWD}" ] || exit 1
[ -n "${DOCKER_IMAGE}" ] || exit 1


# If version exist in DockerHub, stop execution. Nightly builds must have the current version in development
docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD" &> /dev/null

docker manifest inspect "${DOCKER_IMAGE}" > /dev/null ;
EXIST=$?
if [[ "${EXIST}" -eq 0 ]]; then
    echo "true"
    exit 0
fi
echo "false"
