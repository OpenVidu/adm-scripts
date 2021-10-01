#!/bin/bash -xe

echo "##################### EXECUTE: openvidu_ci_container_build #####################"

# Check other env variables
[ -n "$NIGHTLY" ] || NIGHTLY="false"
[ -n $PUSH_IMAGES ] || PUSH_IMAGES='no'
[ -n $DOCKERHUB_REPO ] || exit 1
[ -n "$LATEST_TAG" ] || LATEST_TAG='yes'
[ -n "$IMAGE_NAME" ] || exit 1
[ -n "$TAGS" ] || exit 1
DOCKER_FILE_DIR="${DOCKER_FILE_DIR:-Dockerfile}"

if [[ "$LATEST_TAG" == "yes" ]]; then
  TAGS="$TAGS latest"
else
  TAGS="$TAGS"
fi

# If nighly
if [[ "${NIGHTLY}" == "true" ]]; then

  if [[ -z "${BUILD_COMMIT}" ]]; then
    echo "You need to specify the specific commit of the nightly build"
    exit 1
  fi

  # If nightly, check that version is no released
  export DOCKER_TAG="${TAGS}"
  export DOCKER_IMAGE="${DOCKERHUB_REPO}/${IMAGE_NAME}"
  EXIST_RELEASE=$(check_docker_image_exist.sh)
  if [[ ${EXIST_RELEASE} == "true" ]]; then
    echo "Release specified exist. To create nightly builds you need to specify the current version in development for this image"
    exit 1
  fi

  # Check that num of tags is only one on nightly
  NUM_TAGS=$(echo "$TAGS" | wc -w)
  if [[ "${NUM_TAGS}" == "1" ]]; then
    TAGS="${TAGS}-nightly-${BUILD_COMMIT}-$(date +%m%d%Y) master"
  else
    echo "Nightly build can only have one TAG specified"
    exit 1
  fi
fi

docker build --pull --no-cache --rm=true -t $DOCKERHUB_REPO/$IMAGE_NAME -f ${DOCKER_FILE_DIR} . || exit 1

for TAG in $(echo $TAGS)
do
  docker tag $DOCKERHUB_REPO/$IMAGE_NAME $DOCKERHUB_REPO/$IMAGE_NAME:$TAG
done

if [ "$PUSH_IMAGES" == "yes" ]; then
  docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"

  for TAG in $(echo $TAGS)
  do
    docker push $DOCKERHUB_REPO/$IMAGE_NAME:$TAG
  done

  docker logout
fi

# Remove dangling images
if [ $(docker images -f "dangling=true" -q | wc -l) -ne 0 ]; then
  docker rmi $(docker images -f "dangling=true" -q) || exit 0
fi
