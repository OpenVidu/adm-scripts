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
    pushd openvidu-server/src/angular/frontend || exit 1

    npm install
    ng build --output-path ../../main/resources/static || (echo "Failed to compile frontend"; exit 1)
    popd

    pom-vbump.py -i -v $OPENVIDU_SERVER_VERSION openvidu-server/pom.xml || (echo "Failed to bump openvidu-server version"; exit 1)
    PROJECT_VERSION=$(grep version openvidu-browser/package.json | cut -d ":" -f 2 | cut -d "\"" -f 2) || (echo "Failed to bump openvidu-browser version"; exit 1)
    sed -i "s/\"version\": \"$PROJECT_VERSION\",/\"version\": \"$OPENVIDU_VERSION\",/" openvidu-browser/package.json || (echo "Failed to bump openvidu-browser version"; exit 1)
    git commit -a -m "Update to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || echo "Failed to push to Github"; exit 1
    mvn $MAVEN_OPTIONS clean compile package

    DESC="Release v$OPENVIDU_VERSION"
    openvidu_github_release.go release --user openvidu --repo $OPENVIDU_REPO --tag "v$OPENVIDU_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo $OPENVIDU_REPO --tag "v$OPENVIDU_VERSION" --name openvidu-server-${OPENVIDU_SERVER_VERSION}.jar --file openvidu-server/target/openvidu-server-${OPENVIDU_SERVER_VERSION}.jar || (echo "Failed to upload the archifact to Github"; exit 1)

    # Openvidu Browser
    pushd openvidu-browser || exit 1

    npm install
    npm run updatetsc || exit 1
    VERSION=$OPENVIDU_BROWSER_VERSION npm run browserify || exit 1
    VERSION=$OPENVIDU_BROWSER_VERSION npm run browserify-prod || exit 1

    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_BROWSER_VERSION}.js --file static/js/openvidu-browser-${OPENVIDU_BROWSER_VERSION}.js || (echo "Failed to upload the archifact to Github"; exit 1)
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_BROWSER_VERSION}.min.js --file static/js/openvidu-browser-${OPENVIDU_BROWSER_VERSION}.min.js || (echo "Failed to upload the archifact to Github"; exit 1)
    npm publish
    popd
    ;;

  openvidu-java-client)

    echo "Building openvidu-java-client"
    pushd $OPENVIDU_PROJECT
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || (echo "Failed to bump version"; exit 1)
    
    mvn $MAVEN_OPTIONS -DperformRelease=true clean compile package && \
    mvn $MAVEN_OPTIONS -DperformRelease=true clean deploy && \
    mvn $MAVEN_OPTIONS release:clean && \
    mvn $MAVEN_OPTIONS release:prepare && \
    mvn $MAVEN_OPTIONS release:perform
    popd
    ;;

  openvidu-node-client)

    echo "Building $OPENVIDU_PROJECT"
    pushd $OPENVIDU_PROJECT
    PROJECT_VERSION=$(grep version package.json | cut -d ":" -f 2 | cut -d "\"" -f 2)
    sed -i "s/\"version\": \"$PROJECT_VERSION\",/\"version\": \"$OPENVIDU_VERSION\",/" package.json
    npm install
    npm run build || exit 1
    npm publish
    popd
    ;;

  openvidu-js-java|openvidu-mvc-java)

    echo "Building openvidu-js-java"
    pushd openvidu-js-java
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || (echo "Failed to bump version"; exit 1)
    mvn $MAVEN_OPTIONS clean compile package || (echo "Failed to compile openvidu-js-java"; exit 1)
    DESC=$(git log -1 --pretty=%B)
    openvidu_github_release.go release --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --name openvidu-js-java-${OPENVIDU_VERSION}.jar --file target/openvidu-js-java-${OPENVIDU_VERSION}.jar || (echo "Failed to upload the archifact"; exit 1)
    popd

    echo "Building openvidu-mvc-java"
    pushd openvidu-mvc-java
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || (echo "Failed to bump version"; exit 1)
    mvn $MAVEN_OPTIONS clean compile package || (echo "Failed to compile openvidu-mvc-java"; exit 1)
    DESC=$(git log -1 --pretty=%B)
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "$OPENVIDU_VERSION" --name openvidu-mvc-java-${OPENVIDU_VERSION}.jar --file target/openvidu-mvc-java-${OPENVIDU_VERSION}.jar
    popd
    ;;

  *)
    echo "No project specified"
    exit 1
esac
