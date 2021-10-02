#!/bin/bash -xe
set -eu -o pipefail

echo "##################### EXECUTE: openvidu_ci_container_build #####################"

[ -n "${OVC_VERSION}" ] || exit 1
[ -n "${RELEASE}" ] || RELEASE='false'
[ -n "${OPENVIDU_CALL_BRANCH}" ] || OPENVIDU_CALL_BRANCH='master'
[ -n "${OPENVIDU_BROWSER_BRANCH}" ] || OPENVIDU_BROWSER_BRANCH='master'
# Check if nightly
[ -n "$NIGHTLY" ] || NIGHTLY="false"
if [[ "${NIGHTLY}" == "true"  ]]; then
  BUILD_COMMIT=$(git rev-parse HEAD | cut -c 1-8)
  OVC_VERSION="${OVC_VERSION}-nightly-${BUILD_COMMIT}-$(date +%Y%m%d)"
fi


CURRENT_USERNAME=$(whoami)
CURRENT_UID=$(id -u "${CURRENT_USERNAME}")
CURRENT_GID=$(id -g "${CURRENT_USERNAME}")
# This script updates all dependencies for openvidu call, but only for non release builds
cat >update_depencies.sh <<EOF
#!/bin/bash -x

# Clone OpenVidu Repository to build openvidu-browser and openvidu-node-client
git clone https://github.com/OpenVidu/openvidu.git
pushd openvidu
if [[ "${OPENVIDU_BROWSER_BRANCH}" != 'master' ]]; then
  git checkout "${OPENVIDU_BROWSER_BRANCH}"
fi
popd

pushd openvidu/openvidu-node-client
# Build node client
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OVC_VERSION}\"/" package.json
cat package.json
npm install || { echo "openvidu-browser -> install"; exit 1; }
npm run build || { echo "openvidu-browser -> build"; exit 1; }
npm pack || { echo "openvidu-browser -> pack"; exit 1; }
mv openvidu-node-client-"${OVC_VERSION}".tgz ../../openvidu-call-back

# update package.json openvidu-call-back
pushd ../../openvidu-call-back
chown "${CURRENT_UID}":"${CURRENT_GID}" openvidu-node-client-"${OVC_VERSION}".tgz
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OVC_VERSION}\"/" package.json
sed -i "/\"openvidu-node-client\":/ s/\"openvidu-node-client\":[^,]*/\"openvidu-node-client\": \"file:openvidu-node-client-${OVC_VERSION}.tgz\"/" package.json
cat package.json
popd
popd

pushd openvidu/openvidu-browser
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OVC_VERSION}\"/" package.json
npm install || { echo "openvidu-browser -> install"; exit 1; }
npm run build || { echo "openvidu-browser -> build"; exit 1; }
npm pack || { echo "openvidu-browser -> build"; exit 1; }
mv openvidu-browser-"${OVC_VERSION}".tgz ../../openvidu-call-front

# update package.json openvidu-call-front
pushd ../../openvidu-call-front
chown "${CURRENT_UID}":"${CURRENT_GID}" openvidu-browser-"${OVC_VERSION}".tgz
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OVC_VERSION}\"/" package.json
sed -i "/\"openvidu-browser\":/ s/\"openvidu-browser\":[^,]*/\"openvidu-browser\": \"file:openvidu-browser-${OVC_VERSION}.tgz\"/" package.json
cat package.json
popd
popd

rm -rf openvidu
EOF
chmod +x update_depencies.sh


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
    # Execute update dependencies script
    docker run --rm -v ${PWD}:/workspace -w /workspace "${OPENVIDU_DEVELOPMENT_DOCKER_IMAGE}" /bin/bash -c "./update_depencies.sh" || exit 1
    # Build openvidu call
    docker build -f docker/custom.dockerfile -t openvidu/openvidu-call:"${OVC_VERSION}" --build-arg OPENVIDU_BROWSER="${OPENVIDU_BROWSER_BRANCH}" . || exit 1
    docker push openvidu/openvidu-call:"${OVC_VERSION}"
fi

docker logout

# Remove dangling images
if [ $(docker images -f "dangling=true" -q | wc -l) -ne 0 ]; then
  docker rmi $(docker images -f "dangling=true" -q) || exit 0
fi
