#!/bin/bash -x

echo "##################### EXECUTE: openvidu_ci_container_do_release #####################"

# Verify mandatory parameters
[ -z "$OPENVIDU_VERSION" ] && exit 1
[ -z "$BASE_NAME" ] && BASE_NAME=$OPENVIDU_PROJECT
[ -z "$GITHUB_TOKEN" ] && exit 1

export PATH=$PATH:$ADM_SCRIPTS

OPENVIDU_REPO=$(echo $OPENVIDU_GIT_REPOSITORY | cut -d"/" -f2 | cut -d"." -f 1)

git clone $OPENVIDU_GIT_REPOSITORY
case $OPENVIDU_PROJECT in

  openvidu-server)
    cd openvidu/openvidu-server/src/angular/frontend

    npm install
    ng build --output-path ../../main/resources/static

    cd /opt/openvidu
    pom-vbump.py -i -v $OPENVIDU_VERSION openvidu-server/pom.xml || exit 1
    mvn clean compile package

    DESC=$(git log -1 --pretty=%B)
    TAG=$OPENVIDU_VERSION
    openvidu_github_release.go release --user openvidu --repo openvidu --tag "$TAG" --description "$DESC"
    openvidu_github_release.go upload  --user openvidu --repo openvidu --tag "$TAG" --name openvidu-server-${TAG}.jar -f ${PWD}/openvidu-server/target/openvidu-server-${TAG}.jar
    echo $PWD
    ls -lh openvidu-server/target
    ;;

  *)
    echo "something went wrong"
    env
esac
    
    

    

    
