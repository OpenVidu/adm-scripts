#!/bin/bash -xe

echo "##################### EXECUTE: openvidu_ci_container_build #####################"

[ -n $PUSH_IMAGES ] || PUSH_IMAGES='no'

[ -n "$IMAGE_NAME" ] || exit 1
[ -n "$TAG" ] || exit 1

docker build --no-cache --rm=true -t $IMAGE_NAME:$TAG -f dockerfile . || exit 1
docker tag $IMAGE_NAME:$TAG $IMAGE_NAME:latest

if [ "$PUSH_IMAGES" == "yes" ]; then
  docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"

  docker push $IMAGE_NAME:$TAG
  docker push $IMAGE_NAME:latest

  docker logout
fi

# Remove dangling images
if [ $(docker images -f "dangling=true" -q | wc -l) -ne 0 ]; then
  docker rmi $(docker images -f "dangling=true" -q) || exit 0
fi
