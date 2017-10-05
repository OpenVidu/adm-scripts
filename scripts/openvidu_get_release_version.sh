#!/bin/bash -x

RELEASE_URL="https://api.github.com/repos/openvidu/openvidu-cloud-devops/releases/latest"
echo $(curl "$RELEASE_URL" | jq --raw-output '.tag_name')

