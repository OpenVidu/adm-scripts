#!/bin/bash -x
set -eu -o pipefail

# This script is intended to remove old tags
# in Docker Hub. Right now, older than 7 days
#
# Basically, get the token from Docker Hub using
# your credentials, then lock up for nightly tag
# and remove those ones older than seven days. 
#
# It knows the date because we tag our nightly repo
# in this way:
#
# openvidu/openvidu-server:nightly-20180101

DOCKER_HUB_USERNAME=${DH_UNAME}
DOCKER_HUB_PASSWORD=${DH_UPASS}
DOCKER_HUB_ORGANIZATION=${DH_ORG}
DOCKER_HUB_REPOSITORY=${DH_REPO}

SEVENDAYSAGO=$(date +%m%d%Y -d "7 days ago")

# Get Docker Hub Token
TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKER_HUB_USERNAME}'", "password": "'${DOCKER_HUB_PASSWORD}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)

# Get Tags
TAGS=$(curl -s -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/${DOCKER_HUB_ORGANIZATION}/${DOCKER_HUB_REPOSITORY}/tags/?page_size=300 | jq -r '.results|.[]|.name' | grep nightly)

for TAG in $TAGS
do
  DATE=$(echo $TAG | cut -d"-" -f3)
  if [ ! "$DATE" -gt "$SEVENDAYSAGO" ]; then
  	curl -X DELETE -s -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/${DOCKER_HUB_ORGANIZATION}/${DOCKER_HUB_REPOSITORY}/tags/${TAG}/
  fi
done
