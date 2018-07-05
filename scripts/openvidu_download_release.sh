#!/bin/bash -x
set -eu -o pipefail

echo "##################### EXECUTE: openvidu_download_release #####################"

wget -O openvidu-server.jar https://github.com/OpenVidu/openvidu/releases/download/v$1/openvidu-server-$1.jar



