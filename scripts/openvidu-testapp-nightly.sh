#!/bin/bash -x
set -eu -o pipefail

# Build nightly version of OpenVidu TestApp
# and upload the zip to builds.openvidu.io

echo "##################### EXECUTE: openvidu_build_nightly #####################"

DATESTAMP=$(date +%Y%m%d)
TESTAPP_VERSION=$(cd openvidu-testapp; npm-get-version.py )

# OpenVidu Browser build
pushd openvidu-browser
npm install --unsafe-perm || exit 1
npm run build || exit 1
npm link || exit 1
popd

# OpenVidu Node Client build
pushd openvidu-node-client
npm install --unsafe-perm || exit 1
npm run build || exit 1
npm link || exit 1
popd

# OpenVidu TestApp
pushd openvidu-testapp
npm install --unsafe-perm || exit 1
npm link openvidu-browser || exit 1
npm link openvidu-node-client || exit 1
./node_modules/\@angular/cli/bin/ng version || exit 1
./node_modules/\@angular/cli/bin/ng build --prod || exit 1

# Generate the zip file
cd dist 
zip openvidu-testapp-${TESTAPP_VERSION}.zip *
cp openvidu-testapp-${TESTAPP_VERSION}.zip openvidu-testapp-latest.zip

popd

FILES="openvidu-testapp/dist/openvidu-testapp-${TESTAPP_VERSION}.zip:upload/openvidu/nightly/${DATESTAMP}/openvidu-testapp-${TESTAPP_VERSION}.zip"
FILES="$FILES openvidu-testapp/dist/openvidu-testapp-latest.zip:upload/openvidu/nightly/latest/openvidu-testapp-latest.zip"
FILES=$FILES openvidu_http_publish.sh


