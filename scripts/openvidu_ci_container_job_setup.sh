#!/bin/bash -xe

[ -z "$OPENVIDU_GIT_REPOSITORY" ] && OPENVIDU_GIT_REPOSITORY=$GIT_URL
[ -z "$BUILD_COMMAND" ] && exit 1
[ -z "$CONTAINER_IMAGE" ] && exit 1

export WORKSPACE=/opt
MAVEN_OPTIONS+="-DskipTests=true"

docker run \
  --name openvidu-build \
  -d \
  --rm \
  -e MAVEN_OPTIONS=$MAVEN_OPTIONS \
  -e OPENVIDU_GIT_REPOSITORY=$OPENVIDU_GIT_REPOSITORY \
  -v ${PWD}:$WORKSPACE \
  -w /opt \
  $CONTAINER_IMAGE \
  /opt/openvidu_ci_container_entrypoint.sh $BUILD_COMMAND
status=$?

# Change worspace ownership to avoid permission errors caused by docker usage of root
[ -n "$WORKSPACE" ] && sudo chown -R $(whoami) $WORKSPACE

exit $status
  
