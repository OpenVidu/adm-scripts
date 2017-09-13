#!/bin/bash -xe

echo "##################### EXECUTE: openvidu_download_release #####################"

OV_RELEASE=openvidu-server
OV_RELEASE_URL=$(curl -s https://api.github.com/repos/openvidu/openvidu/releases/latest | grep browser_download_url | cut -d '"' -f 4 | grep $OV_RELEASE)

wget -O openvidu-server.jar $OV_RELEASE_URL


