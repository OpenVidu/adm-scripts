#!/bin/bash -xe
set -eu -o pipefail

export PATH=$PATH:$ADM_SCRIPTS

echo "##################### EXECUTE: openvidu_ci_container_build #####################"

[ -n "${OV_VERSION}" ] || exit 1
[ -n "${OPENVIDU_BRANCH}" ] || OPENVIDU_BRANCH='master'

# Clone OpenVidu Repository to build openvidu-browser and openvidu-node-client
git clone https://github.com/OpenVidu/openvidu.git
pushd openvidu
if [[ "${OPENVIDU_BRANCH}" != 'master' ]]; then
    git checkout "${OPENVIDU_BRANCH}"
fi
BUILD_COMMIT_OV=$(git rev-parse HEAD | cut -c 1-8)
popd
# Get commits from OpenVidu Call and OpenVidu repository
BUILD_COMMIT_CALL=$(git rev-parse HEAD | cut -c 1-8)

OV_BROWSER_VERSION="${OV_VERSION}-nightly-${BUILD_COMMIT_OV}-$(date +%Y%m%d)"
OV_VERSION="${OV_VERSION}-nightly-${BUILD_COMMIT_CALL}-$(date +%Y%m%d)"

CURRENT_USERNAME=$(whoami)
CURRENT_UID=$(id -u "${CURRENT_USERNAME}")
CURRENT_GID=$(id -g "${CURRENT_USERNAME}")

# This script updates all dependencies for openvidu call nightly build
cat >update_dependencies.sh <<EOF
#!/bin/bash -x

chown -R root:root /workspace

# Build openvidu-browser
pushd openvidu/openvidu-browser
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OV_BROWSER_VERSION}\"/" package.json
npm install || { echo "openvidu-browser -> install"; exit 1; }
npm run build || { echo "openvidu-browser -> build"; exit 1; }
npm pack || { echo "openvidu-browser -> build"; exit 1; }
cp openvidu-browser-"${OV_BROWSER_VERSION}".tgz ../../
popd

# update package.json at speech-to-text service
sed -i "/\"openvidu-browser\":/ s/\"openvidu-browser\":[^,]*/\"openvidu-browser\": \"file:openvidu-browser-${OV_BROWSER_VERSION}.tgz\"/" package.json
npm i --package-lock-only

cat package.json

chown -R "${CURRENT_UID}":"${CURRENT_GID}" /workspace

rm -rf openvidu
EOF

chmod +x update_dependencies.sh

# Login to dockerhub
docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"

# Execute update dependencies script
docker run --rm -v ${PWD}:/workspace -w /workspace "${OPENVIDU_DEVELOPMENT_DOCKER_IMAGE}" /bin/bash -c "./update_dependencies.sh" || exit 1

# Build openvidu call
# Build speech to text service forcing ipv4, because ipv6 is not supported by our ci
docker build --pull --no-cache --rm=true --build-arg NODE_OPTIONS='--dns-result-order=ipv4first' -f docker/Dockerfile.bin -t openvidu/speech-to-text-service:"${OV_VERSION}" . || exit 1
docker push openvidu/speech-to-text-service:"${OV_VERSION}"
docker tag openvidu/speech-to-text-service:"${OV_VERSION}" openvidu/speech-to-text-service:master
docker push openvidu/speech-to-text-service:master

docker logout

# Remove dangling images
if [ $(docker images -f "dangling=true" -q | wc -l) -ne 0 ]; then
    docker rmi $(docker images -f "dangling=true" -q) || exit 0
fi
