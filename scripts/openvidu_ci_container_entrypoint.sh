#!/bin/bash -xe

echo "##################### EXECUTE: openvidu_ci_container_entrypoint #####################"

[ -n "$1" ] || { echo "No script to run specified. Need one to run after preparing the environment"; exit 1; }

echo mvn $MAVEN_OPTIONS
for CMD in $BUILD_COMMAND; do
  echo "Running command: $CMD"
  $CMD || exit 1
done
