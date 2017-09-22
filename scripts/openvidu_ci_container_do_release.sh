#!/bin/bash -x

echo "##################### EXECUTE: openvidu_ci_container_do_release #####################"

# Verify mandatory parameters
[ -z "$OV_VERSION" ] || exit 1
[ -z "$BASE_NAME" ] && BASE_NAME=$OPENVIDU_PROJECT
[ -z "$GITHUB_TOKEN" ] && exit 1

export PATH=$PATH:$CONTAINER_ADM_SCRIPTS

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
    TAG=$OV_VERSION
    openvidu-github-release.go release --user $OPENVIDU_PROJECT --repo $BASE_NAME --tag $TAG --description $DESC
    openvidu-github-release.go upload  --user $OPENVIDU_PROJECT --repo $BASE_NAME --tag $TAG --name openvidu-server-${OV_VERSION}.jar -f openvidu-server/target/openvidu-server-${OV_VERSION}.jar
    ;;

  *)
    echo "something went wrong"
    env
esac
    
    

    

    
