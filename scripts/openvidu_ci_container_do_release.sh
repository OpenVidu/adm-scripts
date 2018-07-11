#!/bin/bash -x
set -eu -o pipefail

echo "##################### EXECUTE: openvidu_ci_container_do_release #####################"

# Verify mandatory parameters
[ -z "$GITHUB_TOKEN" ] && exit 1

export PATH=$PATH:$ADM_SCRIPTS

OPENVIDU_REPO=$(echo "$OPENVIDU_GIT_REPOSITORY" | cut -d"/" -f2 | cut -d"." -f 1)

case $OPENVIDU_PROJECT in

  openvidu)
    
    # Openvidu Browser
    [ -z "$OPENVIDU_VERSION" ] && (echo "OPENVIDU_VERSION is empty"; exit 1)
    echo "## Building openvidu-browser"
    npm-update-dep.py || (echo "Faile to update dependencies"; exit 1)
    pushd openvidu-browser || exit 1
    npm-vbump.py --envvar OPENVIDU_VERSION || (echo "Faile to bump package.json version"; exit 1)

    rm static/js/*

    npm install
    npm run build || exit 1
    VERSION=$OPENVIDU_VERSION npm run browserify || exit 1
    VERSION=$OPENVIDU_VERSION npm run browserify-prod || exit 1

    npm link || (echo "Failed to link npm"; exit 1)
    npm publish
    popd

    # Openvidu Server
    echo "## Building openvidu Server"
    pushd openvidu-server/src/angular/frontend || exit 1

    npm install
    npm link openvidu-browser 
    ng build --prod --output-path ../../main/resources/static || (echo "Failed to compile frontend"; exit 1)
    popd

    pom-vbump.py -i -v "$OPENVIDU_VERSION" openvidu-server/pom.xml || (echo "Failed to bump openvidu-server version"; exit 1)
    mvn --batch-mode --settings /opt/openvidu-settings.xml -DskipTests=true clean compile package

    # Github release: commit and push
    git add openvidu-browser/static/js/*
    git commit -a -m "Update to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)

    DESC="Release v$OPENVIDU_VERSION"
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-server-${OPENVIDU_VERSION}.jar --file openvidu-server/target/openvidu-server-${OPENVIDU_VERSION}.jar || (echo "Failed to upload the archifact to Github"; exit 1)
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_VERSION}.js --file openvidu-browser/static/js/openvidu-browser-${OPENVIDU_VERSION}.js || (echo "Failed to upload the archifact to Github"; exit 1)
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_VERSION}.min.js --file openvidu-browser/static/js/openvidu-browser-${OPENVIDU_VERSION}.min.js || (echo "Failed to upload the archifact to Github"; exit 1)
    ;;

  openvidu-java-client)

    echo "## Building openvidu-java-client"
    [ -z "$OPENVIDU_VERSION" ] && (echo "OPENVIDU_VERSION is empty"; exit 1)
    pushd "$OPENVIDU_PROJECT"
    
    mvn $MAVEN_OPTIONS versions:set -DnewVersion=${OPENVIDU_VERSION} || (echo "Failed to bump version"; exit 1)
    mvn $MAVEN_OPTIONS -DperformRelease=true clean compile package || (echo "Failed to compile"; exit 1)
    mvn $MAVEN_OPTIONS -DperformRelease=true clean deploy || (echo "Failed to deploy"; exit 1)
    
    # Github release: commit and push
    git add pom.xml
    git commit -a -m "Update openvidu-java-client to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)
    
    popd
    ;;

  openvidu-node-client)

    echo "## Building $OPENVIDU_PROJECT"
    [ -z "$OPENVIDU_VERSION" ] && (echo "OPENVIDU_VERSION is empty"; exit 1)
    pushd "$OPENVIDU_PROJECT"
    npm-vbump.py --envvar OPENVIDU_VERSION || (echo "Faile to bump package.json version"; exit 1)
    npm install
    npm run build || exit 1
    npm publish
    
    # Github release: commit and push
    git add package.json
    git commit -a -m "Update openvidu-node-client to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)
    
    popd
    ;;

  # OpenVidu Tutorials
  tutorials)

    echo "## Building openvidu-js-java"
    [ -z "$OPENVIDU_VERSION" ] && (echo "OPENVIDU_VERSION is empty"; exit 1)
    pushd openvidu-js-java
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || (echo "Failed to bump version"; exit 1)
    mvn $MAVEN_OPTIONS clean compile package || (echo "Failed to compile openvidu-js-java"; exit 1)
    DESC=$(git log -1 --pretty=%B)
    openvidu_github_release.go release --user openvidu --repo $OPENVIDU_REPO --tag v"$OPENVIDU_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "v$OPENVIDU_VERSION" --name openvidu-js-java-${OPENVIDU_VERSION}.jar --file target/openvidu-js-java-${OPENVIDU_VERSION}.jar || (echo "Failed to upload the archifact"; exit 1)
    popd

    echo "## Building openvidu-mvc-java"
    pushd openvidu-mvc-java
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || (echo "Failed to bump version"; exit 1)
    mvn $MAVEN_OPTIONS clean compile package || (echo "Failed to compile openvidu-mvc-java"; exit 1)
    DESC=$(git log -1 --pretty=%B)
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag v"$OPENVIDU_VERSION" --name openvidu-mvc-java-${OPENVIDU_VERSION}.jar --file target/openvidu-mvc-java-${OPENVIDU_VERSION}.jar
    popd
    ;;

  classroom-front)

    echo "## Building classroom-front"
    [ -z "$OPENVIDU_VERSION" ] && (echo "OPENVIDU_VERSION is empty"; exit 1)
    cd src/angular/frontend
    npm-vbump.py --envvar OV_VERSION || (echo "Failed to bump version"; exit 1)
    npm install || (echo "Failed to install dependencies"; exit 1)
    rm /opt/src/main/resources/static/* || (echo "Cleaning"; exit 1)
    ./node_modules/\@angular/cli/bin/ng build --output-path /opt/src/main/resources/static || (echo "Failed compiling"; exit 1)
    
    ;;

  classroom-back)

    echo "## Building classroom-back"
    [ -z "$OPENVIDU_VERSION" ] && (echo "OPENVIDU_VERSION is empty"; exit 1)
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || (echo "Failed to bump version"; exit 1)
    mvn clean compile package -DskipTest=true || (echo "Failed compiling"; exit 1)
    
    # Github release: commit and push
    git add /opt/src/main/resources/static/*
    git commit -a -m "Update to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)

    DESC="Release v$OPENVIDU_VERSION"
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name classroom-demo-${OPENVIDU_VERSION}.war --file /opt/target/classroom-demo-${OPENVIDU_VERSION}.war || (echo "Failed to upload the archifact to Github"; exit 1)
    ;;

  openvidu-call)

    echo "## Building openvidu-call"
    [ -z "$OPENVIDU_CALL_VERSION" ] && exit 1
    pushd front/openvidu-call || (echo "Failed to change folder"; exit 1)
    npm-vbump.py --envvar OPENVIDU_CALL_VERSION || (echo "Failed to bump version"; exit 1)
    npm install || exit 1
    ./node_modules/\@angular/cli/bin/ng -v || exit 1
    ./node_modules/\@angular/cli/bin/ng build --base-href=/ || exit 1

    cd dist/openvidu-call
    tar czf /opt/openvidu-call-${OPENVIDU_CALL_VERSION}.tar.gz *

    cd ../..
    rm -rf dist/openvidu-call
    ./node_modules/\@angular/cli/bin/ng build --base-href=/openvidu-call/ || exit 1
    cd dist/openvidu-call
    tar czf /opt/openvidu-call-demos-${OPENVIDU_CALL_VERSION}.tar.gz *

    cd ../..
    # Github release: commit and push
    git commit -m "Update to version v$OPENVIDU_CALL_VERSION" package.json
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)

    DESC="Release v$OPENVIDU_CALL_VERSION"
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_CALL_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_CALL_VERSION" --name openvidu-call-${OPENVIDU_CALL_VERSION}.tar.gz --file /opt/openvidu-call-${OPENVIDU_CALL_VERSION}.tar.gz || (echo "Failed to upload the archifact to Github"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_CALL_VERSION" --name openvidu-call-demos-${OPENVIDU_CALL_VERSION}.tar.gz --file /opt/openvidu-call-demos-${OPENVIDU_CALL_VERSION}.tar.gz || (echo "Failed to upload the archifact to Github"; exit 1)
    
    ;;

  *)
    echo "No project specified"
    exit 1
esac
