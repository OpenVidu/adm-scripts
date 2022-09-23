#!/bin/bash -xe
set -eu -o pipefail

export PATH=$PATH:$ADM_SCRIPTS

echo "##################### EXECUTE: openvidu_ci_container_build #####################"

[ -n "${OVC_VERSION}" ] || exit 1
[ -n "${RELEASE}" ] || RELEASE='false'
[ -n "${OPENVIDU_BRANCH}" ] || OPENVIDU_BRANCH='master'
[ -n "$NIGHTLY" ] || NIGHTLY="false"

if [[ "${RELEASE}" == "false"  ]]; then
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

  if [[ "${NIGHTLY}" == "true" ]]; then
    OV_NODE_CLIENT_VERSION="${OVC_VERSION}-nightly-${BUILD_COMMIT_OV}-$(date +%Y%m%d)"
    OV_BROWSER_VERSION="${OVC_VERSION}-nightly-${BUILD_COMMIT_OV}-$(date +%Y%m%d)"
    OV_COMP_ANGULAR="${OVC_VERSION}-nightly-${BUILD_COMMIT_OV}-$(date +%Y%m%d)"
    OVC_VERSION="${OVC_VERSION}-nightly-${BUILD_COMMIT_CALL}-$(date +%Y%m%d)"
  else
    OV_NODE_CLIENT_VERSION="${OVC_VERSION}"
    OV_BROWSER_VERSION="${OVC_VERSION}"
    OV_COMP_ANGULAR="${OVC_VERSION}"
  fi


  CURRENT_USERNAME=$(whoami)
  CURRENT_UID=$(id -u "${CURRENT_USERNAME}")
  CURRENT_GID=$(id -g "${CURRENT_USERNAME}")

# This script updates all dependencies for openvidu call nightly build
cat >update_dependencies.sh <<EOF
#!/bin/bash -x

chown -R root:root /workspace

# Build node client
pushd openvidu/openvidu-node-client
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OV_NODE_CLIENT_VERSION}\"/" package.json
cat package.json
npm install || { echo "openvidu-node-client -> install"; exit 1; }
npm run build || { echo "openvidu-node-client -> build"; exit 1; }
npm pack || { echo "openvidu-node-client -> pack"; exit 1; }
mv openvidu-node-client-"${OV_NODE_CLIENT_VERSION}".tgz ../../openvidu-call/openvidu-call-back
popd

# update package.json openvidu-call-back
pushd openvidu-call/openvidu-call-back
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OVC_VERSION}\"/" package.json
sed -i "/\"openvidu-node-client\":/ s/\"openvidu-node-client\":[^,]*/\"openvidu-node-client\": \"file:openvidu-node-client-${OV_NODE_CLIENT_VERSION}.tgz\"/" package.json
cat package.json
popd

# Build openvidu-browser
pushd openvidu/openvidu-browser
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OV_BROWSER_VERSION}\"/" package.json
npm install || { echo "openvidu-browser -> install"; exit 1; }
npm run build || { echo "openvidu-browser -> build"; exit 1; }
npm pack || { echo "openvidu-browser -> build"; exit 1; }
cp openvidu-browser-"${OV_BROWSER_VERSION}".tgz ../../openvidu/openvidu-components-angular
cp openvidu-browser-"${OV_BROWSER_VERSION}".tgz ../../openvidu-call/openvidu-call-front
popd

# Build openvidu angular
pushd openvidu/openvidu-components-angular
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OV_COMP_ANGULAR}\"/" package.json
sed -i "/\"openvidu-browser\":/ s/\"openvidu-browser\":[^,]*/\"openvidu-browser\": \"file:openvidu-browser-${OV_BROWSER_VERSION}.tgz\"/" package.json
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OV_COMP_ANGULAR}\"/" projects/openvidu-angular/package.json
sed -i "/\"openvidu-browser\":/ s/\"openvidu-browser\":[^,]*/\"openvidu-browser\": \"file:openvidu-browser-${OV_BROWSER_VERSION}.tgz\"/" projects/openvidu-angular/package.json
cat package.json
cat projects/openvidu-angular/package.json
npm install || { echo "Failed to 'npm install'"; exit 1; }
npm run lib:build || { echo "Failed to 'npm run lib:build'"; exit 1; }
pushd dist/openvidu-angular
mv openvidu-angular-"${OV_COMP_ANGULAR}".tgz ../../../../openvidu-call/openvidu-call-front
popd
popd

# update package.json openvidu-call-front
pushd openvidu-call/openvidu-call-front
sed -i "/\"version\":/ s/\"version\":[^,]*/\"version\": \"${OVC_VERSION}\"/" package.json
sed -i "s/\"dependencies\": {/\"dependencies\": { \"openvidu-browser\": \"file:openvidu-browser-${OV_BROWSER_VERSION}.tgz\",/" package.json
sed -i "/\"openvidu-angular\":/ s/\"openvidu-angular\":[^,]*/\"openvidu-angular\": \"file:openvidu-angular-${OV_COMP_ANGULAR}.tgz\"/" package.json
cat package.json
popd

chown -R "${CURRENT_UID}":"${CURRENT_GID}" /workspace

rm -rf openvidu
EOF
chmod +x update_dependencies.sh

fi

# Login to dockerhub
docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"

if [[ "${RELEASE}" == 'true' ]]; then
    openvidu_call_build.sh "${OVC_VERSION}"
    popd
else
    # Execute update dependencies script
    docker run --rm -v ${PWD}:/workspace -w /workspace "${OPENVIDU_DEVELOPMENT_DOCKER_IMAGE}" /bin/bash -c "./update_dependencies.sh" || exit 1
    # Build openvidu call
    pushd openvidu-call
    docker build -f docker/Dockerfile.node -t openvidu/openvidu-call:"${OVC_VERSION}" . || exit 1
    docker push openvidu/openvidu-call:"${OVC_VERSION}"
    if [[ "${NIGHTLY}" == "true" ]]; then
      docker tag openvidu/openvidu-call:"${OVC_VERSION}" openvidu/openvidu-call:master
      docker push openvidu/openvidu-call:master
    fi
    popd
fi

docker logout

# Remove dangling images
if [ $(docker images -f "dangling=true" -q | wc -l) -ne 0 ]; then
  docker rmi $(docker images -f "dangling=true" -q) || exit 0
fi
