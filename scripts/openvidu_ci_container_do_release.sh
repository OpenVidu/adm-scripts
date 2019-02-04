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
    npm publish || (echo "Failed to publish to npm"; exit 1)
    popd

    # Openvidu Server
    echo "## Building openvidu Server"
    pushd openvidu-server/src/angular/frontend || exit 1

    npm install
    npm link openvidu-browser 
    ./node_modules/\@angular/cli/bin/ng build --prod --output-path ../../main/resources/static || (echo "Failed to compile frontend"; exit 1)
    popd

    pom-vbump.py -i -v "$OPENVIDU_VERSION" openvidu-server/pom.xml || (echo "Failed to bump openvidu-server version"; exit 1)
    mvn --batch-mode --settings /opt/openvidu-settings.xml -DskipTests=true clean compile package

    # Github release: commit and push
    git add openvidu-server/src/main/resources/static/*
    git add openvidu-browser/static/js/*
    git commit -a -m "Update to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)

    DESC="Release v$OPENVIDU_VERSION"
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-server-${OPENVIDU_VERSION}.jar --file openvidu-server/target/openvidu-server-${OPENVIDU_VERSION}.jar || (echo "Failed to upload the artifact to Github"; exit 1)
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_VERSION}.js --file openvidu-browser/static/js/openvidu-browser-${OPENVIDU_VERSION}.js || (echo "Failed to upload the artifact to Github"; exit 1)
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_VERSION}.min.js --file openvidu-browser/static/js/openvidu-browser-${OPENVIDU_VERSION}.min.js || (echo "Failed to upload the artifact to Github"; exit 1)
    
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
    npm run build|| (echo "Failed to build"; exit 1)
    npm publish || (echo "Failed to publish to npm"; exit 1)
    
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
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "v$OPENVIDU_VERSION" --name openvidu-js-java-${OPENVIDU_VERSION}.jar --file target/openvidu-js-java-${OPENVIDU_VERSION}.jar || (echo "Failed to upload the artifact"; exit 1)
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
    npm-vbump.py --envvar OPENVIDU_VERSION || (echo "Failed to bump version"; exit 1)
    npm install || (echo "Failed to install dependencies"; exit 1)
    rm /opt/src/main/resources/static/* || (echo "Cleaning"; exit 1)
    ./node_modules/\@angular/cli/bin/ng build --prod --output-path /opt/src/main/resources/static || (echo "Failed compiling"; exit 1)
    
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
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name classroom-demo-${OPENVIDU_VERSION}.war --file /opt/target/classroom-demo-${OPENVIDU_VERSION}.war || (echo "Failed to upload the artifact to Github"; exit 1)
    
    ;;

  openvidu-call)

    echo "## Building openvidu-call"
    [ -z "$OPENVIDU_CALL_VERSION" ] && exit 1

    # Update npm dependencies
    npm-update-dep-call.py || (echo "Faile to update dependencies/bump version"; exit 1)
    pushd front/openvidu-call || (echo "Failed to change folder"; exit 1)

    # Install npm dependencies
    npm install || exit 1

    # openvidu-call production build
    ./node_modules/\@angular/cli/bin/ng version || exit 1
    ./node_modules/\@angular/cli/bin/ng build --prod || exit 1

    # OpenVidu Web Component build and package
    echo "## Building openvidu WebComponent"
    npm run build:openvidu-webcomponent -- $OPENVIDU_CALL_VERSION
    zip -r --junk-paths /opt/openvidu-webcomponent-${OPENVIDU_CALL_VERSION}.zip openvidu-webcomponent

    # openvidu-angular build
    echo "## Building openvidu-angular"
    npm run build:openvidu-angular

    # openvidu-call package
    cd dist/openvidu-call
    tar czf /opt/openvidu-call-${OPENVIDU_CALL_VERSION}.tar.gz *
    
    # openvidu-call-demos build and package	
    cd ../..	
    rm -rf dist/openvidu-call	
    ./node_modules/\@angular/cli/bin/ng build --prod --base-href=/openvidu-call/ || exit 1	
    cd dist/openvidu-call	
    tar czf /opt/openvidu-call-demos-${OPENVIDU_CALL_VERSION}.tar.gz *	

    # npm release openvidu-angular
    cd ../openvidu-angular
    npm publish || (echo "Failed to publish openvidu-angular to npm"; exit 1)

    # Github release: commit and push
    cd ../..
    git commit -a -m "Update to version v$OPENVIDU_CALL_VERSION"
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)

    # OpenVidu/openvidu-call repo
    DESC="Release v$OPENVIDU_CALL_VERSION"
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_CALL_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_CALL_VERSION" --name openvidu-call-${OPENVIDU_CALL_VERSION}.tar.gz --file /opt/openvidu-call-${OPENVIDU_CALL_VERSION}.tar.gz || (echo "Failed to upload openvidu-call artifact to Github"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_CALL_VERSION" --name openvidu-call-demos-${OPENVIDU_CALL_VERSION}.tar.gz --file /opt/openvidu-call-demos-${OPENVIDU_CALL_VERSION}.tar.gz || (echo "Failed to upload openvidu-call-demos artifact to Github"; exit 1)
    
    # OpenVidu/openvidu repo (OpenVidu Web Component)
    openvidu_github_release.go upload  --user openvidu --repo "openvidu" --tag "v$OPENVIDU_CALL_VERSION" --name openvidu-webcomponent-${OPENVIDU_CALL_VERSION}.zip --file /opt/openvidu-webcomponent-${OPENVIDU_CALL_VERSION}.zip || (echo "Failed to upload openvidu-webcomponent artifact to Github"; exit 1)

    ;;

  openvidu-react)

    #### git clone https://github.com/OpenVidu/openvidu-call-react.git
    echo "## Building openvidu-react"
    [ -z "$OPENVIDU_REACT_VERSION" ] && exit 1

    # Update npm dependencies
    npm-update-dep-call-react.py || (echo "Failed to update dependencies/bump version"; exit 1)

    # Install npm dependencies
    cd openvidu-call-react || (echo "Failed to change folder"; exit 1)
    npm install || (echo "Failed to install dependencies in openvidu-call-react"; exit 1)
    cd ../library
    npm install || (echo "Failed to install dependencies in openvidu-react library"; exit 1)

    # Build openvidu-react library
    cd ../openvidu-call-react
    npm run build:openvidu-react || (echo "Failed to build openvidu-react library"; exit 1)

    # Publish openvidu-react library
    cd ../library
    npm publish || (echo "Failed to publish openvidu-react library"; exit 1)

    # Github commit and push
    cd ..
    git commit -a -m "Update to version v$OPENVIDU_REACT_VERSION"
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)

    ;;

  openvidu-pro)

    export AWS_ACCESS_KEY_ID=${NAEVA_AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${NAEVA_AWS_SECRET_ACCESS_KEY}
    export AWS_DEFAULT_REGION=us-east-1
    
    [ -z "$OPENVIDU_PRO_VERSION" ] && exit 1

    git clone https://github.com/OpenVidu/openvidu.git

    pushd openvidu
    mvn -DskipTests=true compile || { echo "openvidu -> compile"; exit 1; }
    mvn -DskipTests=true install || { echo "openvidu -> install"; exit 1; }
    popd

    pushd openvidu/openvidu-node-client
    npm install || { echo "openvidu-node-client -> install"; exit 1; }
    npm run build || { echo "openvidu-node-client -> build"; exit 1; }
    npm link || { echo "openvidu-node-client -> link"; exit 1; }
    popd
     
    pushd openvidu/openvidu-server
    mvn -Pdependency install || { echo "openvidu-server -> install dependency"; exit 1; }
    popd

    pushd dashboard
    npm install || { echo "dashboard -> install "; exit 1; }
    npm link openvidu-node-client || { echo "dashboard -> link"; exit 1; }
    ./node_modules/\@angular/cli/bin/ng build --prod --output-path ../openvidu-server-pro/src/main/resources/static || { echo "dashboard -> build for prod"; exit 1; }
    popd

    pushd openvidu-server-pro
    mvn versions:set -DnewVersion="$OPENVIDU_PRO_VERSION" || { echo "Failed to bump openvidu-pro version"; exit 1; }
    mvn clean  || { echo "openvidu-server-pro -> clean"; exit 1; }
    mvn compile || { echo "openvidu-server-pro -> compile"; exit 1; }
    mvn package || { echo "openvidu-server-pro -> package"; exit 1; }
    popd

    pushd openvidu-server-pro/target
    aws s3 cp openvidu-server-pro-$OPENVIDU_PRO_VERSION.jar s3://naeva-openvidu-pro/openvidu-server-pro-latest.jar
    aws s3 cp openvidu-server-pro-$OPENVIDU_PRO_VERSION.jar s3://naeva-openvidu-pro/
    popd

    ;;

  *)
    echo "No project specified"
    exit 1
esac
