#!/bin/bash -xe

[ -z "$OPENVIDU_GIT_REPOSITORY" ] && OPENVIDU_GIT_REPOSITORY=$GIT_URL
[ -z "$BUILD_COMMAND" ] && exit 1
[ -z "$CONTAINER_IMAGE" ] && exit 1

export WORKSPACE=/opt
export MAVEN_OPTIONS+="-DskipTests=true"
export CONTAINER_ADM_SCRIPTS=/opt/adm-scripts

docker run \
  --name openvidu-build \
  --rm \
  -e MAVEN_OPTIONS=$MAVEN_OPTIONS \
  -e OPENVIDU_GIT_REPOSITORY=$OPENVIDU_GIT_REPOSITORY \
  -v $OPENVIDU_ADM_SCRIPTS_HOME:$CONTAINER_ADM_SCRIPTS \
  -v ${PWD}:$WORKSPACE \
  -w /opt \
  $CONTAINER_IMAGE \
  /opt/adm-scripts/openvidu_ci_container_entrypoint.sh $BUILD_COMMAND
status=$?

# Change worspace ownership to avoid permission errors caused by docker usage of root
[ -n "$WORKSPACE" ] && sudo chown -R $(whoami) $WORKSPACE

exit $status
  
