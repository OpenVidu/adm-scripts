#!/bin/bash -x
set -eu -o pipefail

# Build nightly version of OpenVidu Server
# and upload the jar to builds.openvidu.io

echo "##################### EXECUTE: openvidu_build_nightly #####################"
DATESTAMP=$(date +%Y%m%d)
MAVEN_OPTIONS='--batch-mode --settings /opt/openvidu-settings.xml -DskipTests=true'

mvn $MAVEN_OPTIONS compile || exit 1
mvn $MAVEN_OPTIONS install || exit 1
cd openvidu-server
mvn $MAVEN_OPTIONS package || exit 1

OV_VERSION=$(get_version_from_pom-xml.py )

FILES="target/openvidu-server-${OV_VERSION}.jar:upload/openvidu/nightly/${DATESTAMP}/openvidu-server-${OV_VERSION}.jar"
FILES=$FILES openvidu_http_publish.sh

