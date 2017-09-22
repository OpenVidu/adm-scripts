#!/bin/bash -x

echo "##################### EXECUTE: openvidu_ci_container_job_setup #####################"

[ -z "$OPENVIDU_GIT_REPOSITORY" ] && OPENVIDU_GIT_REPOSITORY=$GIT_URL
[ -z "$BUILD_COMMAND" ] && exit 1
[ -z "$CONTAINER_IMAGE" ] && exit 1

export WORKSPACE=/opt
MAVEN_OPTIONS+="-DskipTests=false"
CONTAINER_ADM_SCRIPTS=/opt/adm-scripts
CONTAINER_PRIVATE_RSA_KEY=/opt/git_id_rsa

docker run \
  --name $BUILD_TAG-JOB_SETUP-$(date +"%s") \
  --rm \
  -e "MAVEN_OPTIONS=$MAVEN_OPTIONS" \
  -e OPENVIDU_GIT_REPOSITORY=$OPENVIDU_GIT_REPOSITORY \
  -v $OPENVIDU_ADM_SCRIPTS_HOME:$CONTAINER_ADM_SCRIPTS \
  $([ -f "$GITHUB_PRIVATE_RSA_KEY" ] && echo "-v $GITHUB_PRIVATE_RSA_KEY:$CONTAINER_PRIVATE_RSA_KEY" ) \
  $([ "${OPENVIDU_GITHUB_TOKEN}x" != "x" ] && echo "-e GITHUB_KEY=$OPENVIDU_GITHUB_TOKEN" ) \
  -e "GITHUB_PRIVATE_RSA_KEY=$CONTAINER_PRIVATE_RSA_KEY" \
  -e "OPENVIDU_PROJECT=$OPENVIDU_PROJECT" \
  -e "GITHUB_TOKEN=$OPENVIDU_GITHUB_TOKEN" \
  -e "ADM_SCRIPTS=$CONTAINER_ADM_SCRIPTS" \
  -w $WORKSPACE \
  $CONTAINER_IMAGE \
  /opt/adm-scripts/openvidu_ci_container_entrypoint.sh $BUILD_COMMAND
status=$?

# Change worspace ownership to avoid permission errors caused by docker usage of root
[ -n "$WORKSPACE" ] && sudo chown -R $(whoami) $WORKSPACE

exit $status
  
