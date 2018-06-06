#!/bin/bash -x
set -eu -o pipefail

# Build nightly version of OpenVidu Server
# and upload the jar to builds.openvidu.io

MAVEN_OPTIONS='--batch-mode --settings /opt/openvidu-settings.xml -DskipTests=true'

mvn $MAVEN_OPTIONS compile || exit 1
mvn $MAVEN_OPTIONS install || exit 1
cd openvidu-server
mvn $MAVEN_OPTIONS package || exit 1

OV_VERSION=$(get_version_from_pom-xml.py )

ls -lh target/penvidu-server-${OV_VERISON}.jar
