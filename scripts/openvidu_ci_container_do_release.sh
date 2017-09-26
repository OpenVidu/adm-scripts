#!/bin/bash -x

echo "##################### EXECUTE: openvidu_ci_container_do_release #####################"

# Verify mandatory parameters
[ -z "$OPENVIDU_VERSION" ] && exit 1
[ -z "$OPENVIDU_SERVER_VERSION" ] && OPENVIDU_SERVER_VERSION=$OPENVIDU_VERSION
[ -z "$OPENVIDU_BROWSER_VERSION" ] && OPENVIDU_BROWSER_VERSION=$OPENVIDU_VERSION
[ -z "$GITHUB_TOKEN" ] && exit 1

export PATH=$PATH:$ADM_SCRIPTS

OPENVIDU_REPO=$(echo $OPENVIDU_GIT_REPOSITORY | cut -d"/" -f2 | cut -d"." -f 1)

case $OPENVIDU_PROJECT in

  openvidu)
    
    # Openvidu Server
    echo $PWD
    pushd openvidu-server/src/angular/frontend || exit 1

    npm install
    ng build --output-path ../../main/resources/static
    popd

    pom-vbump.py -i -v $OPENVIDU_SERVER_VERSION openvidu-server/pom.xml || exit 1
    mvn $MAVEN_OPTIONS clean compile package

    DESC=$(git log -1 --pretty=%B)
    openvidu_github_release.go release --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --description "$DESC"
    openvidu_github_release.go upload  --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --name openvidu-server-${OPENVIDU_SERVER_VERSION}.jar --file openvidu-server/target/openvidu-server-${OPENVIDU_SERVER_VERSION}.jar

    # Openvidu Browser
    ls -l
    pom-vbump.py -i -v $OPENVIDU_BROWSER_VERSION openvidu-browser/pom.xml || exit 1

    pushd /opt/$OPENVIDU_REPO/openvidu-browser/src/main/resources
    PROJECT_VERSION=$(grep version package.json | cut -d ":" -f 2 | cut -d "\"" -f 2)
    sed -i "s/\"version\": \"$PROJECT_VERSION\",/\"version\": \"$OPENVIDU_BROWSER_VERSION\",/" package.json
    npm install
    npm run updatetsc && VERSION=$OPENVIDU_BROWSER_VERSION npm run browserify && VERSION=$OPENVIDU_BROWSER_VERSION npm run browserify-prod

    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_BROWSER_VERSION}.js --file static/js/openvidu-browser-${OPENVIDU_BROWSER_VERSION}.js
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_BROWSER_VERSION}.min.js --file static/js/openvidu-browser-${OPENVIDU_BROWSER_VERSION}.min.js
    popd
    ;;

  openvidu-java-client)

    echo "Building openvidu-java-client"
    cd /opt/$OPENVIDU_REPO
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || exit 1
    
    mvn $MAVEN_OPTIONS clean compile package && \
    mvn -DperformRelease=true clean compile package && \
    mvn -DperformRelease=true clean deploy && \
    mvn --settings $MAVEN_SETTINGS release:clean && \
    mvn --settings $MAVEN_SETTINGS release:prepare && \
    mvn --settings $MAVEN_SETTINGS release:perform
    ;;

  openvidu-node-client)

    echo "Building $OPENVIDU_PROJECT"
    cd $OPENVIDU_PROJECT
    PROJECT_VERSION=$(grep version package.json | cut -d ":" -f 2 | cut -d "\"" -f 2)
    sed -i "s/\"version\": \"$PROJECT_VERSION\",/\"version\": \"$OPENVIDU_VERSION\",/" package.json
    npm run build || exit 1
    npm publish
    ;;

  openvidu-js-java)

    echo "Building openvidu-js-java"
    cd /opt/$OPENVIDU_REPO
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || exit 1
    mvn $MAVEN_OPTIONS clean compile package
    DESC=$(git log -1 --pretty=%B)
    openvidu_github_release.go release --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --description "$DESC"
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --name openvidu-js-java-${OPENVIDU_VERSION}.jar --file target/openvidu-js-java-${OPENVIDU_VERSION}.jar
    ;;

  openvidu-mvc-java)

    echo "Building openvidu-mvc-java"
    cd /opt/$OPENVIDU_REPO
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || exit 1
    mvn $MAVEN_OPTIONS clean compile package
    DESC=$(git log -1 --pretty=%B)
    openvidu_github_release.go release --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --description "$DESC"
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --name openvidu-mvc-java-${OPENVIDU_VERSION}.jar --file target/openvidu-mvc-java-${OPENVIDU_VERSION}.jar
    ;;

  *)
    echo "No project specified"
    exit 1
esac
