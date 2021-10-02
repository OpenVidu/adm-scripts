#!/bin/bash
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
# openvidu/openvidu-server:<version>-nightly-<commit>-<date>

date_to_timestamp() {
  DATE="${1}"
  if [[ -z "${DATE}" ]]; then
    return 1
  fi
  YEAR="$(echo "$DATE" | cut -c 1-4)"
  MONTH="$(echo "$DATE" | cut -c 5-6)"
  DAY="$(echo "$DATE" | cut -c 7-8)"
  # Convert date using ISO 8601 (Thanks ISO 8601...)
  date -d "${YEAR}-${MONTH}-${DAY}T00:00:00" "+%s"
}

DOCKER_HUB_USERNAME=${DH_UNAME}
DOCKER_HUB_PASSWORD=${DH_UPASS}
DOCKER_HUB_ORGANIZATION=${DH_ORG}
DOCKER_HUB_REPOSITORY=${DH_REPO}

SEVENDAYSAGO=$(date +%s -d "15 days ago")

# Get Docker Hub Token
TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKER_HUB_USERNAME}'", "password": "'${DOCKER_HUB_PASSWORD}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)

# Get Tags
set +e
TAGS=$(curl -s -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/${DOCKER_HUB_ORGANIZATION}/${DOCKER_HUB_REPOSITORY}/tags/?page_size=300 | jq -r '.results|.[]|.name' | grep nightly)

if [[ -n "${TAGS}" ]]; then
set -e
  for TAG in $TAGS
  do
    DATE_FORMATTED=$(echo $TAG | cut -d"-" -f4)
    if [[ -n "${DATE_FORMATTED}" ]]; then

      DATE=$(date_to_timestamp "${DATE_FORMATTED}")
      if [[ -n "${DATE}" ]] && [[ "$SEVENDAYSAGO" -gt "$DATE" ]]; then
        echo "The image ${DOCKER_HUB_ORGANIZATION}/${DOCKER_HUB_REPOSITORY}:${TAG} is old. Deleting"
        curl -X DELETE -s -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/${DOCKER_HUB_ORGANIZATION}/${DOCKER_HUB_REPOSITORY}/tags/${TAG}/
      else
        echo "The image ${DOCKER_HUB_ORGANIZATION}/${DOCKER_HUB_REPOSITORY}:${TAG} is not 15 days old. Keeping"
      fi

    fi
  done
fi


