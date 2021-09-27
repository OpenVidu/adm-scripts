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
    echo "## Building OpenVidu Browser"
    npm-update-dep.py || (echo "Faile to update dependencies"; exit 1)
    pushd openvidu-browser || exit 1
    npm-vbump.py --envvar OPENVIDU_VERSION || (echo "Failed to bump package.json version"; exit 1)

    npm install
    npm run build || exit 1
    VERSION=$OPENVIDU_VERSION npm run browserify || exit 1
    VERSION=$OPENVIDU_VERSION npm run browserify-prod || exit 1

    npm link || (echo "Failed to link npm"; exit 1)
    npm publish || (echo "Failed to publish to npm"; exit 1)

    # Active waiting for openvidu-browser NPM library
    CHECK_VERSION_AVAILABILTY="npm show openvidu-browser@$OPENVIDU_VERSION version"
    VERSION=$(eval "$CHECK_VERSION_AVAILABILTY")
    until [[ "$VERSION" == "$OPENVIDU_VERSION" ]]
    do
      echo "Waiting for openvidu-browser@$OPENVIDU_VERSION to be available in NPM...";
      sleep 2;
      VERSION=$(eval "$CHECK_VERSION_AVAILABILTY")
    done
    echo "openvidu-browser@$OPENVIDU_VERSION already available in NPM"

    popd

    # Openvidu Server
    echo "## Building OpenVidu Server"
    pushd openvidu-server/src/dashboard || exit 1

    npm install
    npm link openvidu-browser
    npm run build-prod || (echo "Failed to compile frontend"; exit 1)
    popd

    pom-vbump.py -i -v "$OPENVIDU_VERSION" openvidu-server/pom.xml || (echo "Failed to bump openvidu-server version"; exit 1)
    mvn --batch-mode --settings /opt/openvidu-settings.xml -DskipTests=true clean compile package

    # Github release: commit and push
    git commit -a -m "Update to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)

    DESC="Release v$OPENVIDU_VERSION"
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-server-${OPENVIDU_VERSION}.jar --file openvidu-server/target/openvidu-server-${OPENVIDU_VERSION}.jar || (echo "Failed to upload the artifact to Github"; exit 1)
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_VERSION}.js --file openvidu-browser/static/js/openvidu-browser-${OPENVIDU_VERSION}.js || (echo "Failed to upload the artifact to Github"; exit 1)
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_VERSION}.min.js --file openvidu-browser/static/js/openvidu-browser-${OPENVIDU_VERSION}.min.js || (echo "Failed to upload the artifact to Github"; exit 1)

    # Pushing file to builds server
    pushd openvidu-server/target
    FILES="openvidu-server-${OPENVIDU_VERSION}.jar:upload/openvidu/builds/openvidu-server-${OPENVIDU_VERSION}.jar"
    FILES=$FILES openvidu_http_publish.sh
    popd

    ;;

  openvidu-nightly)

    # Openvidu Browser
    [ -z "$OPENVIDU_VERSION" ] && (echo "OPENVIDU_VERSION is empty"; exit 1)
    echo "## Building OpenVidu Browser"
    npm-update-dep.py || (echo "Faile to update dependencies"; exit 1)
    pushd openvidu-browser || exit 1
    npm-vbump.py --envvar OPENVIDU_VERSION || (echo "Failed to bump package.json version"; exit 1)

    npm install
    npm run build || exit 1
    npm pack || (echo "Failed to pack openvidu-browser"; exit 1)
    mv openvidu-browser-"${OPENVIDU_VERSION}".tgz ../openvidu-server/src/dashboard
    popd

    # Openvidu Server
    echo "## Building OpenVidu Server"
    pushd openvidu-server/src/dashboard || exit 1

    npm install openvidu-browser-"${OPENVIDU_VERSION}".tgz
    npm install
    npm run build-prod || (echo "Failed to compile frontend"; exit 1)
    popd

    pom-vbump.py -i -v "$OPENVIDU_VERSION" openvidu-server/pom.xml || (echo "Failed to bump openvidu-server version"; exit 1)
    mvn --batch-mode --settings /opt/openvidu-settings.xml -DskipTests=true clean compile package

    if [[ "${OVERWRITE_VERSION}" == 'false' ]]; then
      HTTP_REQUEST=$(curl -s -o /dev/null -I -w "%{http_code}" "http://builds.openvidu.io/openvidu/builds/openvidu-server-${OPENVIDU_VERSION}.jar")
      if [[ "${HTTP_REQUEST}" == "200" ]]; then
        echo "Build openvidu-server-pro-${OPENVIDU_VERSION} actually exists and OVERWRITE_VERSION=false"
        exit 1
      fi
    fi

    # Pushing file to builds server
    pushd openvidu-server/target
    FILES="openvidu-server-${OPENVIDU_VERSION}.jar:upload/openvidu/builds/openvidu-server-${OPENVIDU_VERSION}.jar"
    FILES=$FILES openvidu_http_publish.sh
    popd

    ;;
  openvidu-java-client)

    echo "## Building openvidu-java-client"
    [ -z "$OPENVIDU_VERSION" ] && (echo "OPENVIDU_VERSION is empty"; exit 1)

    mvn $MAVEN_OPTIONS versions:set-property -Dproperty=version.openvidu.java.client -DnewVersion=${OPENVIDU_VERSION} || (echo "Failed to update version"; exit 1)

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

  openvidu-test-browsers)

    echo "## Building openvidu-test-browsers"
    [ -z "$OPENVIDU_VERSION" ] && (echo "OPENVIDU_VERSION is empty"; exit 1)
    pushd "$OPENVIDU_PROJECT"

    mvn $MAVEN_OPTIONS versions:set -DnewVersion=${OPENVIDU_VERSION} || (echo "Failed to bump version"; exit 1)
    mvn $MAVEN_OPTIONS -DperformRelease=true clean compile package || (echo "Failed to compile"; exit 1)
    mvn $MAVEN_OPTIONS -DperformRelease=true clean deploy || (echo "Failed to deploy"; exit 1)

    # Github release: commit and push
    git add pom.xml
    git commit -a -m "Update openvidu-test-browsers to version v$OPENVIDU_VERSION"
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
    # TODO Enable "--prod" after upgrade to greater angular 7 because of this issue: https://github.com/uuidjs/uuid/issues/500
    # ./node_modules/\@angular/cli/bin/ng build --prod --output-path /opt/src/main/resources/static || (echo "Failed compiling"; exit 1)
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
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name classroom-demo-${OPENVIDU_VERSION}.war --file /opt/target/classroom-demo-${OPENVIDU_VERSION}.war || (echo "Failed to upload the artifact to Github"; exit 1)

    ;;

  openvidu-call)

    echo "## Building openvidu-call"
    [ -z "$OPENVIDU_CALL_VERSION" ] && exit 1

    ## FRONT
    # Update npm dependencies
    npm-update-dep-call.py || (echo "Faile to update dependencies/bump version"; exit 1)
    cd openvidu-call-front || (echo "Failed to change folder"; exit 1)

    # Install npm dependencies
    npm install || exit 1

    # openvidu-call production build
    ./node_modules/\@angular/cli/bin/ng version || exit 1
    npm run build-prod || exit 1

    ## BACK
    cd ../openvidu-call-back || (echo "Failed to change folder"; exit 1)
    npm install || (echo "Failed to NPM install"; exit 1)
    npm run build || (echo "Failed to NPM run build"; exit 1)

    # openvidu-call package
    cd dist
    tar czf /opt/openvidu-call-${OPENVIDU_CALL_VERSION}.tar.gz *
    rm -rf dist/*

    # openvidu-call-demos build and package
    cd ../../openvidu-call-front
    rm -rf dist/openvidu-call
    npm run build-prod /openvidu-call/ || exit 1
    cd ../openvidu-call-back || (echo "Failed to change folder"; exit 1)
    npm run build || (echo "Failed to NPM run build"; exit 1)
    cd dist
    tar czf /opt/openvidu-call-demos-${OPENVIDU_CALL_VERSION}.tar.gz *

    # OpenVidu Web Component build and package
    cd ../../openvidu-call-front || (echo "Failed to change folder"; exit 1)
    echo "## Building openvidu WebComponent"
    npm run build:openvidu-webcomponent
    zip -r --junk-paths /opt/openvidu-webcomponent-${OPENVIDU_CALL_VERSION}.zip openvidu-webcomponent
    rm -rf ./openvidu-webcomponent # Delete webcomponent compilation folder

    # openvidu-angular build
    echo "## Building openvidu-angular"
    npm run build:openvidu-angular

    # npm release openvidu-angular
    cd dist/openvidu-angular
    npm publish || (echo "Failed to publish openvidu-angular to npm"; exit 1)

    # Github release: commit and push
    cd ../../..
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

    export AWS_DEFAULT_REGION=us-east-1
    # Check if nightly
    [ -n "$NIGHTLY" ] || NIGHTLY="false"
    if [[ "${NIGHTLY}" == "true"  ]]; then
      OPENVIDU_PRO_VERSION="nightly-$(date +%m%d%Y)"
    fi

    [ -n "$OVERWRITE_VERSION" ] || OVERWRITE_VERSION='false'
    [ -z "$OPENVIDU_PRO_VERSION" ] && exit 1

    # Commit or branch to build
    [ -n "$OPENVIDU_CE_COMMIT" ] || OPENVIDU_CE_COMMIT='master'
    [ -n "$OPENVIDU_PRO_COMMIT" ] || OPENVIDU_PRO_COMMIT='master'

    git clone https://github.com/OpenVidu/openvidu.git

    if ${KURENTO_JAVA_SNAPSHOT} ; then
      git clone https://github.com/Kurento/kurento-java.git
      cd kurento-java && MVN_VERSION=$(mvn --batch-mode -q -Dexec.executable=echo -Dexec.args='${project.version}' --non-recursive exec:exec)
      cd ../openvidu && mvn --batch-mode versions:set-property -Dproperty=version.kurento -DnewVersion=$MVN_VERSION
      mvn dependency:get -DrepoUrl=https://maven.openvidu.io/repository/snapshots/ -Dartifact=org.kurento:kurento-client:$MVN_VERSION
      mvn dependency:get -DrepoUrl=https://maven.openvidu.io/repository/snapshots/ -Dartifact=org.kurento:kurento-jsonrpc-client-jetty:$MVN_VERSION
      mvn dependency:get -DrepoUrl=https://maven.openvidu.io/repository/snapshots/ -Dartifact=org.kurento:kurento-jsonrpc-server:$MVN_VERSION
      mvn dependency:get -DrepoUrl=https://maven.openvidu.io/repository/snapshots/ -Dartifact=org.kurento:kurento-test:$MVN_VERSION
      cd ..
    fi

    pushd openvidu
    if [[ "${OPENVIDU_CE_COMMIT}" != 'master' ]]; then
      git checkout "${OPENVIDU_CE_COMMIT}"
    fi
    mvn -DskipTests=true compile || { echo "openvidu -> compile"; exit 1; }
    mvn -DskipTests=true install || { echo "openvidu -> install"; exit 1; }
    popd

    if [ "${BUILD_OPENVIDU_INSPECTOR}" == true ]; then
      pushd openvidu/openvidu-node-client
      npm install || { echo "openvidu-node-client -> install"; exit 1; }
      npm run build || { echo "openvidu-node-client -> build"; exit 1; }
      npm link || { echo "openvidu-node-client -> link"; exit 1; }
      popd

      pushd openvidu/openvidu-browser
      npm install || { echo "openvidu-browser -> install"; exit 1; }
      npm run build || { echo "openvidu-browser -> build"; exit 1; }
      npm link || { echo "openvidu-browser -> link"; exit 1; }
      popd

      pushd dashboard
      npm install || { echo "dashboard -> install "; exit 1; }
      npm link openvidu-node-client || { echo "dashboard -> link"; exit 1; }
      npm link openvidu-browser || { echo "dashboard -> link"; exit 1; }
      npm run build-server-prod  || { echo "dashboard -> build for prod"; exit 1; }
      popd
    fi

    pushd openvidu/openvidu-server
    mvn -Pdependency install || { echo "openvidu-server -> install dependency"; exit 1; }
    popd

    pushd openvidu-server-pro
    if [ "${OPENVIDU_PRO_IS_SNAPSHOT}" == true ]; then
        OVP_VERSION=${OPENVIDU_PRO_VERSION}-SNAPSHOT
    else
        OVP_VERSION=${OPENVIDU_PRO_VERSION}
    fi

    mvn versions:set -DnewVersion=${OVP_VERSION} || { echo "Failed to bump openvidu-pro version"; exit 1; }
    mvn -DskipTests=true clean package || { echo "openvidu-server-pro -> clean package"; exit 1; }
    popd

    pushd openvidu-server-pro/target
    chmod 0400 /opt/id_rsa.key

    if [[ "${OVERWRITE_VERSION}" == 'false' ]]; then
      FILE_EXIST=0
      ssh -o StrictHostKeyChecking=no -i /opt/id_rsa.key ubuntu@pro.openvidu.io \
        [[ -f /var/www/pro.openvidu.io/openvidu-server-pro-"${OVP_VERSION}".jar ]] || FILE_EXIST=$?
      if [[ "${FILE_EXIST}" -eq 0 ]]; then
        echo "Build openvidu-server-pro-${OVP_VERSION} actually exists and OVERWRITE_VERSION=false"
        exit 1
      fi
    fi

    # Upload to pro.openvidu.io
    scp -o StrictHostKeyChecking=no \
    -i /opt/id_rsa.key \
    openvidu-server-pro-${OVP_VERSION}.jar \
    ubuntu@pro.openvidu.io:/var/www/pro.openvidu.io/

    ;;

  replication-manager)

    echo "## Release replication-manager v${OPENVIDU_VERSION}"
    DESC="Release replication-manager v${OPENVIDU_VERSION}"

    # Update pom version
    mvn versions:set -DnewVersion=${OPENVIDU_VERSION} || { echo "Failed to bump openvidu-pro version"; exit 1; }

    # Build
    mvn --batch-mode -DskipTests=true clean compile package || (echo "Failed to build replication-manager version"; exit 1)
    mv target/replication-manager-*.jar target/replication-manager-"${OPENVIDU_VERSION}".jar || exit 1

    # Release
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name replication-manager-"${OPENVIDU_VERSION}".jar --file target/replication-manager-"${OPENVIDU_VERSION}".jar || (echo "Failed to upload the artifact to Github"; exit 1)

    ;;

  mediasoup-controller)
    echo "## Release mediasoup-controller v${OPENVIDU_VERSION}"
    DESC="Release mediasoup-controller v${OPENVIDU_VERSION}"

    # Update version in package.json file
    npm-vbump.py --envvar OPENVIDU_VERSION || (echo "Failed to bump package.json version"; exit 1)
    git add package.json
    git commit -a -m "Update mediasoup-controller to version v$OPENVIDU_VERSION"

    # Push to github
    git push origin HEAD:master || (echo "Failed to push to Github"; exit 1)
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || (echo "Failed to make the release"; exit 1)

    ;;

  *)
    echo "No project specified"
    exit 1
esac
