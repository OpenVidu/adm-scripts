#!/bin/bash -x

echo "##################### EXECUTE: openvidu_ci_container_job_setup #####################"

[ -z "$OPENVIDU_GIT_REPOSITORY" ] && OPENVIDU_GIT_REPOSITORY=$GIT_URL
[ -z "$BUILD_COMMAND" ] && exit 1
[ -z "$CONTAINER_IMAGE" ] && exit 1

WORKSPACE=/opt
MAVEN_OPTIONS="--batch-mode --settings /opt/openvidu-settings.xml -DskipTests=false"
CONTAINER_MAVEN_SETTINGS=/opt/openvidu-settings.xml
CONTAINER_ADM_SCRIPTS=/opt/adm-scripts
CONTAINER_PRIVATE_RSA_KEY=/opt/git_id_rsa
CONTAINER_NPM_CONFIG=/root/.npmrc
CONTAINER_GPG_PRIVATE_BLOCK=/root/.gpgpriv

docker run \
  --name $BUILD_TAG-JOB_SETUP-$(date +"%s") \
  --rm \
  -e "MAVEN_OPTIONS=$MAVEN_OPTIONS" \
  -e OPENVIDU_GIT_REPOSITORY=$OPENVIDU_GIT_REPOSITORY \
  -v $OPENVIDU_ADM_SCRIPTS_HOME:$CONTAINER_ADM_SCRIPTS \
  $([ -f "$GITHUB_PRIVATE_RSA_KEY" ] && echo "-v $GITHUB_PRIVATE_RSA_KEY:$CONTAINER_PRIVATE_RSA_KEY" ) \
  $([ "${OPENVIDU_GITHUB_TOKEN}x" != "x" ] && echo "-e GITHUB_KEY=$OPENVIDU_GITHUB_TOKEN" ) \
  $([ -f "$MAVEN_SETTINGS" ] && echo "-v $MAVEN_SETTINGS:$CONTAINER_MAVEN_SETTINGS") \
  $([ -f "$NPM_CONFIG" ] && echo "-v $NPM_CONFIG:$CONTAINER_NPM_CONFIG") \
  $([ -f "$GPG_PRIVATE_BLOCK" ] && echo "-v $GPG_PRIVATE_BLOCK:$CONTAINER_GPG_PRIVATE_BLOCK") \
  -e "GITHUB_PRIVATE_RSA_KEY=$CONTAINER_PRIVATE_RSA_KEY" \
  -e "OPENVIDU_PROJECT=$OV_PROJECT" \
  -e "GITHUB_TOKEN=$OPENVIDU_GITHUB_TOKEN" \
  -e "ADM_SCRIPTS=$CONTAINER_ADM_SCRIPTS" \
  -e "OPENVIDU_VERSION=$OV_VERSION" \
  -e "OPENVIDU_SERVER_VERSION=$OV_SERVER_VERSION" \
  -e "OPENVIDU_BROWSER_VERSION=$OV_BROWSER_VERSION" \
  -e "MAVEN_SETTINGS=$CONTAINER_MAVEN_SETTINGS" \
  -e "GPG_PRIVATE_BLOCK=$CONTAINER_GPG_PRIVATE_BLOCK" \
  -e "GNUPG_KEY_ID=$OPENVIDU_GPG_KEY" \
  -e "GPG_PASSKEY=$OPENVIDU_GPG_PASSKEY" \
  -v "${PWD}:$WORKSPACE" \
  -w $WORKSPACE \
  $CONTAINER_IMAGE \
  /opt/adm-scripts/openvidu_ci_container_entrypoint.sh $BUILD_COMMAND
status=$?

# Change worspace ownership to avoid permission errors caused by docker usage of root
[ -n "$WORKSPACE" ] && sudo chown -R $(whoami) $WORKSPACE

exit $status
  
