#!/bin/bash -xe

echo "##################### EXECUTE: openvidu_download_release #####################"

[ -z "$RELEASE" ] && exit 1
[ -z "$RELEASE_URL" ] && exit 1

DOWNLOAD_URL=$(curl -s $RELEASE_URL | grep browser_download_url | cut -d '"' -f 4 | grep $RELEASE)

curl -L -o $OUTPUT $DOWNLOAD_URL


