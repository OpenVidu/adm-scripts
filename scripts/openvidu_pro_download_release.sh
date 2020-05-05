#!/bin/bash -x
set -eu -o pipefail

echo "##################### EXECUTE: openvidu_pro_download_release #####################"

wget -O openvidu-server.jar --http-user=${OPENVIDU_PRO_USERNAME} --http-password=${OPENVIDU_PRO_PASSWORD} https://pro-stripe.openvidu.io/openvidu-server-pro-$1.jar --tries=0 --read-timeout=20
