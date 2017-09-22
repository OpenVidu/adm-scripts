#!/bin/bash -x

echo "##################### EXECUTE: openvidu_ci_container_do_release #####################"

# Verify mandatory parameters
[ -z "$OPENVIDU_VERSION" ] && exit 1
[ -z "$BASE_NAME" ] && BASE_NAME=$OPENVIDU_PROJECT
[ -z "$GITHUB_TOKEN" ] && exit 1

export PATH=$PATH:$ADM_SCRIPTS

git clone $OPENVIDU_GIT_REPOSITORY
case $OPENVIDU_PROJECT in

  openvidu-server)
    cd openvidu/openvidu-server/src/angular/frontend

    npm install
    ng build --output-path ../../main/resources/static

    cd /opt/openvidu
    pom-vbump.py -i -v $OV_VERSION openvidu-server/pom.xml || exit 1
    mvn clean compile package

    DESC=$(git log -1 --pretty=%B)
    TAG=$OPENVIDU_VERSION
    openvidu_github_release.go release --user $OPENVIDU_PROJECT --repo $BASE_NAME --tag $TAG --description "$DESC"
    openvidu_github_release.go upload  --user $OPENVIDU_PROJECT --repo $BASE_NAME --tag $TAG --name openvidu-server-${TAG}.jar -f openvidu-server/target/openvidu-server-${TAG}.jar
    ;;

  *)
    echo "something went wrong"
    env
esac
    
    

    

    
