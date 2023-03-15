#!/bin/bash -x
set -eu -o pipefail

echo "##################### EXECUTE: openvidu_download_release #####################"

wget http://builds.openvidu.io/openvidu/builds/openvidu-server-$1.jar