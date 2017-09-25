#!/bin/bash -x

echo "##################### EXECUTE: openvidu_ci_container_do_release #####################"

# Verify mandatory parameters
[ -z "$OPENVIDU_SERVER_VERSION" ] && exit 1
[ -z "$OPENVIDU_BROWSER_VERSION" ] && exit 1
[ -z "$GITHUB_TOKEN" ] && exit 1

export PATH=$PATH:$ADM_SCRIPTS

OPENVIDU_REPO=$(echo $OPENVIDU_GIT_REPOSITORY | cut -d"/" -f2 | cut -d"." -f 1)

git clone $OPENVIDU_GIT_REPOSITORY

# Openvidu Server
cd $OPENVIDU_REPO/openvidu-server/src/angular/frontend

npm install
ng build --output-path ../../main/resources/static

cd /opt/openvidu
pom-vbump.py -i -v $OPENVIDU_SERVER_VERSION openvidu-server/pom.xml || exit 1
mvn clean compile package

DESC=$(git log -1 --pretty=%B)
TAG=$OPENVIDU_SERVER_VERSION
openvidu_github_release.go release --user openvidu --repo $OPENVIDU_REPO --tag "$TAG" --description "$DESC"
openvidu_github_release.go upload  --user openvidu --repo $OPENVIDU_REPO --tag "$TAG" --name openvidu-server-${TAG}.jar -f openvidu-server/target/openvidu-server-${TAG}.jar

# Openvidu Browser
cd /opt/$OPENVIDU_REPO
pom-vbump.py -i -v $OPENVIDU_BROWSER_VERSION openvidu-browser/pom.xml || exit 1
PROJECT_VERSION=$(grep version openvidu-browser/src/main/resources/package.json | cut -d ":" -f 2 | cut -d "\"" -f 2)
sed -i "s/\"version\": \"$PROJECT_VERSION\",/\"version\": \"$OPENVIDU_BROWSER_VERSION\",/" openvidu-browser/src/main/resources/package.json

cd /opt/$OPENVIDU_REPO/openvidu-browser
npm run updatetsc && VERSION=$OPENVIU_BROWSER_VERSION npm run browserify && VERSION=$OPENVIDU_BROWSER_VERSION npm run browserify-prod

TAG=OPENVIU_BROWSER_VERSION
openvidu_github_release.go upload  --user openvidu --repo $OPENVIDU_REPO --tag "$TAG" --name openvidu-server-${TAG}.jar -f openvidu-server/target/openvidu-server-${TAG}.jar

