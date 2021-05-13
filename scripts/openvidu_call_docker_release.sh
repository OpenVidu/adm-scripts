#!/bin/bash -xe
set -eu -o pipefail

echo "##################### EXECUTE: openvidu_ci_container_build #####################"

[ -n "${OVC_VERSION}" ] || exit 1
[ -n "${RELEASE}" ] || RELEASE='false'
[ -n "${OPENVIDU_CALL_BRANCH}" ] || OPENVIDU_CALL_BRANCH='master'
[ -n "${OPENVIDU_BROWSER_BRANCH}" ] || OPENVIDU_BROWSER_BRANCH='master' 

if [ "${OPENVIDU_CALL_BRANCH}" != 'master' ]; then
    git checkout "${OPENVIDU_CALL_BRANCH}"
fi

# Login to dockerhub
docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"

if [[ "${RELEASE}" == 'true' ]]; then
    pushd docker
    chmod u+x run.sh
    ./run.sh "${OVC_VERSION}" "${OPENVIDU_CALL_BRANCH}"
    popd
else
    docker build -f docker/custom.dockerfile -t openvidu/openvidu-call:"${OVC_VERSION}" --build-arg OPENVIDU_BROWSER="${OPENVIDU_BROWSER_BRANCH}" . || exit 1
    docker push openvidu/openvidu-call:"${OVC_VERSION}"
fi

docker logout

# Remove dangling images
if [ $(docker images -f "dangling=true" -q | wc -l) -ne 0 ]; then
  docker rmi $(docker images -f "dangling=true" -q) || exit 0
fi