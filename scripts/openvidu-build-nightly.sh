#!/bin/bash -x
set -eu -o pipefail

[ -n "$OVERWRITE_VERSION" ] || OVERWRITE_VERSION='false'

# Build nightly version of OpenVidu Server
# and upload the jar to builds.openvidu.io

echo "##################### EXECUTE: openvidu_build_nightly #####################"
DATESTAMP=$(date +%Y%m%d)
MAVEN_OPTIONS='--batch-mode --settings /opt/openvidu-settings.xml -DskipTests=true'
IS_OV_VERSION_DEFINED='false'
if [[ -n "${OPENVIDU_VERSION}" ]]; then
    IS_OV_VERSION_DEFINED='true'
fi

if ${KURENTO_JAVA_SNAPSHOT} ; then
  git clone https://github.com/Kurento/kurento-java.git
  cd kurento-java && MVN_VERSION=$(mvn --batch-mode -q -Dexec.executable=echo -Dexec.args='${project.version}' --non-recursive exec:exec)
  cd .. && mvn --batch-mode versions:set-property -Dproperty=version.kurento -DnewVersion=$MVN_VERSION
  mvn dependency:get -DrepoUrl=https://maven.openvidu.io/repository/snapshots/ -Dartifact=org.kurento:kurento-client:$MVN_VERSION
  mvn dependency:get -DrepoUrl=https://maven.openvidu.io/repository/snapshots/ -Dartifact=org.kurento:kurento-jsonrpc-client-jetty:$MVN_VERSION
  mvn dependency:get -DrepoUrl=https://maven.openvidu.io/repository/snapshots/ -Dartifact=org.kurento:kurento-jsonrpc-server:$MVN_VERSION
  mvn dependency:get -DrepoUrl=https://maven.openvidu.io/repository/snapshots/ -Dartifact=org.kurento:kurento-test:$MVN_VERSION
fi

# OpenVidu Java Client
pushd openvidu-java-client
mvn $MAVEN_OPTIONS versions:set -DnewVersion="${OPENVIDU_VERSION}" || exit 1
popd

# OpenVidu Parent
mvn $MAVEN_OPTIONS versions:set-property -Dproperty=version.openvidu.java.client -DnewVersion="${OPENVIDU_VERSION}" || exit 1
mvn $MAVEN_OPTIONS clean || exit 1
mvn $MAVEN_OPTIONS install || exit 1

# OpenVidu Browser
pushd openvidu-browser
npm install --unsafe-perm || exit 1
npm run build || exit 1
npm link || exit 1
popd

# OpenVidu Node Client
pushd openvidu-node-client
npm install --unsafe-perm || exit 1
npm run build || exit 1
npm link || exit 1
popd

# OpenVidu Server Dashboard
pushd openvidu-server/src/dashboard
npm install --unsafe-perm || exit 1
npm link openvidu-browser || exit 1
npm run build-prod
popd

# OpenVidu Server
pushd openvidu-server
mvn $MAVEN_OPTIONS clean compile package || exit 1
if [[ "${IS_OV_VERSION_DEFINED}" == 'false' ]]; then
    OPENVIDU_VERSION=$(get_version_from_pom-xml.py)
fi
cp target/openvidu-server-*.jar target/openvidu-server.jar
popd

# Pushing file to server
pushd openvidu-server/target
if [[ "${IS_OV_VERSION_DEFINED}" == 'false' ]]; then
    FILES="openvidu-server.jar:upload/openvidu/nightly/${DATESTAMP}/openvidu-server-${OPENVIDU_VERSION}.jar"
    FILES="$FILES openvidu-server.jar:upload/openvidu/nightly/latest/openvidu-server-latest.jar"
else
    if [[ "${OVERWRITE_VERSION}" == 'false' ]]; then
      FILE_EXIST=0
      curl --head --silent http://builds.openvidu.io/openvidu/builds/openvidu-server-"${OPENVIDU_VERSION}".jar | head -n 1 | grep -q 200 || FILE_EXIST=$?
      if [[ "${FILE_EXIST}" -eq 0 ]]; then
        echo "Build openvidu-server-${OPENVIDU_VERSION} actually exists and OVERWRITE_VERSION=false"
        exit 1
      fi
    fi
    FILES="openvidu-server.jar:upload/openvidu/builds/openvidu-server-${OPENVIDU_VERSION}.jar"
fi
FILES=$FILES openvidu_http_publish.sh
popd

# Tell me the versions we've used
mvn --version
pushd openvidu-server/src/dashboard
./node_modules/\@angular/cli/bin/ng version
