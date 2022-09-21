#!/bin/bash -x
set -eu -o pipefail

echo "##################### EXECUTE: openvidu_ci_container_do_release #####################"

# Verify mandatory parameters
[ -z "$GITHUB_TOKEN" ] && exit 1

export PATH=$PATH:$ADM_SCRIPTS

OPENVIDU_REPO=$(echo "$OPENVIDU_GIT_REPOSITORY" | cut -d"/" -f2 | cut -d"." -f 1)

# *sigh*, NPM Infers the user which is running the command by looking at the files it is using...
# As this scrupts run as root, we need to change the ownership of the files to the current user
# This is a workaround to avoid the following error:
# npm ERR! code EACCES
chown -R root:root "${PWD}"

case $OPENVIDU_PROJECT in

  openvidu)

    # Openvidu Browser
    [ -z "$OPENVIDU_VERSION" ] && { echo "OPENVIDU_VERSION is empty"; exit 1; }
    echo "## Building OpenVidu Browser"
    npm-update-dep.py || { echo "Faile to update dependencies"; exit 1; }
    pushd openvidu-browser || exit 1
    npm-vbump.py --envvar OPENVIDU_VERSION || { echo "Failed to bump package.json version"; exit 1; }

    npm install
    npm run build || exit 1
    VERSION=$OPENVIDU_VERSION npm run browserify || exit 1
    VERSION=$OPENVIDU_VERSION npm run browserify-prod || exit 1

    npm link || { echo "Failed to link npm"; exit 1; }
    # npm publish || { echo "Failed to publish to npm"; exit 1; }

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

    npm install || { echo "Failed 'npm install'"; exit 1; }
    npm link openvidu-browser || { echo "Failed 'npm link openvidu-browser'"; exit 1; }
    npm run build-prod || { echo "Failed to compile frontend"; exit 1; }
    popd

    pom-vbump.py -i -v "$OPENVIDU_VERSION" openvidu-server/pom.xml || { echo "Failed to bump openvidu-server version"; exit 1; }
    mvn --batch-mode --settings /opt/openvidu-settings.xml -DskipTests=true clean compile package

    # openvidu-angular
    pushd openvidu-components-angular
    npm install || { echo "Failed to 'npm install'"; exit 1; }
    npm link openvidu-browser

    export OPENVIDU_CALL_VERSION="${OPENVIDU_VERSION}"
    npm-update-dep-ov-components-angular.py || { echo "Faile to update dependencies/bump version"; exit 1; }

    chown -R 1001:1001 "/root/.npm"
    npm run lib:build || { echo "Failed to 'npm run lib:build'"; exit 1; }
    pushd dist/openvidu-angular
    npm publish || { echo "Failed to publish openvidu-angular to npm"; exit 1; }
    popd
    popd

    # openvidu-webcomponent
    npm run webcomponent:build || { echo "Failed to 'npm run webcomponent:build'"; exit 1; }
    zip -r --junk-paths dist/openvidu-webcomponent/openvidu-webcomponent-${OPENVIDU_VERSION}.zip dist/openvidu-webcomponent

    # Github release: commit and push
    git commit -a -m "Update to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || { echo "Failed to push to Github"; exit 1; }

    DESC="Release v$OPENVIDU_VERSION"
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || { echo "Failed to make the release"; exit 1; }
    sleep 10
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-server-${OPENVIDU_VERSION}.jar --file openvidu-server/target/openvidu-server-${OPENVIDU_VERSION}.jar || { echo "Failed to upload the artifact to Github"; exit 1; }
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_VERSION}.js --file openvidu-browser/static/js/openvidu-browser-${OPENVIDU_VERSION}.js || { echo "Failed to upload the artifact to Github"; exit 1; }
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-browser-${OPENVIDU_VERSION}.min.js --file openvidu-browser/static/js/openvidu-browser-${OPENVIDU_VERSION}.min.js || { echo "Failed to upload the artifact to Github"; exit 1; }
    openvidu_github_release.go upload --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name openvidu-webcomponent-${OPENVIDU_VERSION}.zip --file openvidu-components-angular/dist/openvidu-webcomponent/openvidu-webcomponent-${OPENVIDU_VERSION}.zip || { echo "Failed to upload openvidu-webcomponent artifact to Github"; exit 1; }

    # Pushing file to builds server
    pushd openvidu-server/target
    FILES="openvidu-server-${OPENVIDU_VERSION}.jar:upload/openvidu/builds/openvidu-server-${OPENVIDU_VERSION}.jar"
    FILES=$FILES openvidu_http_publish.sh
    popd

    ;;

  openvidu-nightly)

    [ -z "$OPENVIDU_VERSION" ] && { echo "OPENVIDU_VERSION is empty"; exit 1; }
    # Check if nightly
    [ -n "$NIGHTLY" ] || NIGHTLY="false"
    if [[ "${NIGHTLY}" == "true"  ]]; then
      BUILD_COMMIT=$(git rev-parse HEAD | cut -c 1-8)
      OPENVIDU_VERSION="${OPENVIDU_VERSION}-nightly-${BUILD_COMMIT}-$(date +%Y%m%d)"
    fi

    # Openvidu Browser
    echo "## Building OpenVidu Browser"
    pushd openvidu-browser
    npm-vbump.py --envvar OPENVIDU_VERSION || { echo "Failed to bump package.json version"; exit 1; }
    npm install || { echo "openvidu-browser -> install"; exit 1; }
    npm run build || { echo "openvidu-browser -> build"; exit 1; }
    npm pack || { echo "openvidu-browser -> pack"; exit 1; }
    mv openvidu-browser-"${OPENVIDU_VERSION}".tgz ../openvidu-server/src/dashboard
    popd

    # Openvidu Server
    echo "## Building OpenVidu Server"
    pushd openvidu-server/src/dashboard
    npm install openvidu-browser-"${OPENVIDU_VERSION}".tgz
    npm install || { echo "dashboard -> install "; exit 1; }
    npm run build-prod || { echo "dashboard -> build for prod"; exit 1; }
    rm openvidu-browser-"${OPENVIDU_VERSION}".tgz
    popd

    pom-vbump.py -i -v "$OPENVIDU_VERSION" openvidu-server/pom.xml || { echo "Failed to bump openvidu-server version"; exit 1; }

    if ${KURENTO_JAVA_SNAPSHOT} ; then
      git clone https://github.com/Kurento/kurento-java.git
      cd kurento-java && MVN_VERSION="$(grep -oPm1 "(?<=<version>)[^<]+" "pom.xml")"
      cd .. && mvn --batch-mode --settings /opt/kurento-snapshot-settings.xml -Dmaven.artifact.threads=1 versions:set-property -Dproperty=version.kurento -DnewVersion="$MVN_VERSION"
    fi

    mvn --batch-mode --settings /opt/kurento-snapshot-settings.xml -Dmaven.artifact.threads=1 -DskipTests=true clean compile package

    if [[ "${OVERWRITE_VERSION}" == 'false' ]]; then
      HTTP_REQUEST=$(curl --write-out "%{http_code}" --silent --output /dev/null "http://builds.openvidu.io/openvidu/builds/openvidu-server-${OPENVIDU_VERSION}.jar")
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
    [ -z "$OPENVIDU_VERSION" ] && { echo "OPENVIDU_VERSION is empty"; exit 1; }

    mvn $MAVEN_OPTIONS versions:set-property -Dproperty=version.openvidu.java.client -DnewVersion=${OPENVIDU_VERSION} || { echo "Failed to update version"; exit 1; }

    pushd "$OPENVIDU_PROJECT"

    mvn $MAVEN_OPTIONS versions:set -DnewVersion=${OPENVIDU_VERSION} || { echo "Failed to bump version"; exit 1; }
    mvn $MAVEN_OPTIONS -DperformRelease=true clean compile package || { echo "Failed to compile"; exit 1; }
    mvn $MAVEN_OPTIONS -DperformRelease=true clean deploy || { echo "Failed to deploy"; exit 1; }

    # Github release: commit and push
    git add pom.xml
    git commit -a -m "Update openvidu-java-client to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || { echo "Failed to push to Github"; exit 1; }

    popd

    ;;

  openvidu-test-browsers)

    echo "## Building openvidu-test-browsers"
    [ -z "$OPENVIDU_VERSION" ] && { echo "OPENVIDU_VERSION is empty"; exit 1; }
    pushd "$OPENVIDU_PROJECT"

    mvn $MAVEN_OPTIONS versions:set -DnewVersion=${OPENVIDU_VERSION} || { echo "Failed to bump version"; exit 1; }
    mvn $MAVEN_OPTIONS -DperformRelease=true clean compile package || { echo "Failed to compile"; exit 1; }
    mvn $MAVEN_OPTIONS -DperformRelease=true clean deploy || { echo "Failed to deploy"; exit 1; }

    # Github release: commit and push
    git add pom.xml
    git commit -a -m "Update openvidu-test-browsers to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || { echo "Failed to push to Github"; exit 1; }

    popd

    ;;

  openvidu-node-client)

    echo "## Building $OPENVIDU_PROJECT"
    [ -z "$OPENVIDU_VERSION" ] && { echo "OPENVIDU_VERSION is empty"; exit 1; }
    pushd "$OPENVIDU_PROJECT"
    npm-vbump.py --envvar OPENVIDU_VERSION || { echo "Faile to bump package.json version"; exit 1; }
    npm install
    npm run build|| { echo "Failed to build"; exit 1; }
    npm publish || { echo "Failed to publish to npm"; exit 1; }

    # Github release: commit and push
    git add package.json
    git commit -a -m "Update openvidu-node-client to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || { echo "Failed to push to Github"; exit 1; }

    popd

    ;;

  # OpenVidu Tutorials
  tutorials)

    echo "## Building openvidu-roles-java"
    [ -z "$OPENVIDU_VERSION" ] && { echo "OPENVIDU_VERSION is empty"; exit 1; }
    pushd openvidu-roles-java
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || { echo "Failed to bump version"; exit 1; }
    mvn $MAVEN_OPTIONS clean compile package || { echo "Failed to compile openvidu-roles-java"; exit 1; }
    DESC=$(git log -1 --pretty=%B)
    openvidu_github_release.go release --user openvidu --repo $OPENVIDU_REPO --tag v"$OPENVIDU_VERSION" --description "$DESC" || { echo "Failed to make the release"; exit 1; }
    sleep 10
    openvidu_github_release.go upload --user openvidu --repo $OPENVIDU_REPO --tag "v$OPENVIDU_VERSION" --name openvidu-roles-java-${OPENVIDU_VERSION}.jar --file target/openvidu-roles-java-${OPENVIDU_VERSION}.jar || { echo "Failed to upload the artifact"; exit 1; }
    popd

    ;;

  classroom-front)

    echo "## Building classroom-front"
    [ -z "$OPENVIDU_VERSION" ] && { echo "OPENVIDU_VERSION is empty"; exit 1; }
    cd src/angular/frontend
    npm-vbump.py --envvar OPENVIDU_VERSION || { echo "Failed to bump version"; exit 1; }
    npm install || { echo "Failed to install dependencies"; exit 1; }
    rm /opt/src/main/resources/static/* || { echo "Cleaning"; exit 1; }
    ./node_modules/\@angular/cli/bin/ng.js build --output-path /opt/src/main/resources/static || { echo "Failed compiling"; exit 1; }

    ;;

  classroom-back)

    echo "## Building classroom-back"
    [ -z "$OPENVIDU_VERSION" ] && { echo "OPENVIDU_VERSION is empty"; exit 1; }
    pom-vbump.py -i -v $OPENVIDU_VERSION pom.xml || { echo "Failed to bump version"; exit 1; }
    mvn clean compile package -DskipTest=true || { echo "Failed compiling"; exit 1; }

    # Github release: commit and push
    git add /opt/src/main/resources/static/*
    git commit -a -m "Update to version v$OPENVIDU_VERSION"
    git push origin HEAD:master || { echo "Failed to push to Github"; exit 1; }

    DESC="Release v$OPENVIDU_VERSION"
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || { echo "Failed to make the release"; exit 1; }
    sleep 10
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name classroom-demo-${OPENVIDU_VERSION}.war --file /opt/target/classroom-demo-${OPENVIDU_VERSION}.war || { echo "Failed to upload the artifact to Github"; exit 1; }

    ;;

  openvidu-react)

    # Own root directory to avoid EACCES error 
    chown -R root:root library/ openvidu-call-react/

    #### git clone https://github.com/OpenVidu/openvidu-call-react.git
    echo "## Building openvidu-react"
    [ -z "$OPENVIDU_REACT_VERSION" ] && exit 1

    # Update npm dependencies
    npm-update-dep-call-react.py || { echo "Failed to update dependencies/bump version"; exit 1; }

    # Install npm dependencies
    cd openvidu-call-react || { echo "Failed to change folder"; exit 1; }
    npm install || { echo "Failed to install dependencies in openvidu-call-react"; exit 1; }
    cd ../library
    npm install || { echo "Failed to install dependencies in openvidu-react library"; exit 1; }

    # Build openvidu-react library
    cd ../openvidu-call-react
    npm run build:openvidu-react || { echo "Failed to build openvidu-react library"; exit 1; }

    # Publish openvidu-react library
    cd ../library
    npm publish || { echo "Failed to publish openvidu-react library"; exit 1; }

    # Github commit and push
    cd ..
    git commit -a -m "Update to version v$OPENVIDU_REACT_VERSION"
    git push origin HEAD:master || { echo "Failed to push to Github"; exit 1; }

    ;;

  openvidu-pro)

    export AWS_DEFAULT_REGION=us-east-1

    [ -n "$OVERWRITE_VERSION" ] || OVERWRITE_VERSION='false'
    [ -z "$OPENVIDU_PRO_VERSION" ] && exit 1

    # Commit or branch to build
    [ -n "$OPENVIDU_CE_COMMIT" ] || OPENVIDU_CE_COMMIT='master'
    [ -n "$OPENVIDU_PRO_COMMIT" ] || OPENVIDU_PRO_COMMIT='master'

    git clone https://github.com/OpenVidu/openvidu.git
    pushd openvidu
    if [[ "${OPENVIDU_CE_COMMIT}" != 'master' ]]; then
      git checkout "${OPENVIDU_CE_COMMIT}"
    fi
    popd

    # Check if nightly and setup variables
    [ -n "$NIGHTLY" ] || NIGHTLY="false"
    ORIG_VERSION="${OPENVIDU_PRO_VERSION}"
    if [[ "${NIGHTLY}" == "true"  ]]; then
      # Create OpenVidu Pro version based in commit
      BUILD_COMMIT_PRO=$(git rev-parse HEAD | cut -c 1-8)
      export OPENVIDU_PRO_VERSION="${ORIG_VERSION}-nightly-${BUILD_COMMIT_PRO}-$(date +%Y%m%d)"

      # Create OpenVidu CE version based in commit
      pushd openvidu
      BUILD_COMMIT_CE=$(git rev-parse HEAD | cut -c 1-8)
      export OPENVIDU_CE_VERSION="${ORIG_VERSION}-nightly-${BUILD_COMMIT_CE}-$(date +%Y%m%d)"
      popd
    else

      # If not nightly, use version originally configured
      export OPENVIDU_PRO_VERSION="${ORIG_VERSION}"
      export OPENVIDU_CE_VERSION="${ORIG_VERSION}"
    fi

    pushd openvidu
    # Update java-client from parent pom.xml
    mvn versions:set-property -Dproperty=version.openvidu.java.client -DnewVersion=${OPENVIDU_CE_VERSION} -DskipTests=true || { echo "Failed to update version"; exit 1; }
    popd

    pushd openvidu/openvidu-java-client
    # Update java-client version
    mvn versions:set -DnewVersion=${OPENVIDU_CE_VERSION} -DskipTests=true  || { echo "Failed to bump version"; exit 1; }
    popd

    # Update openvidu-server
    pushd openvidu/openvidu-server
    mvn versions:set -DnewVersion=${OPENVIDU_CE_VERSION} -DskipTests=true || { echo "Failed to bump version"; exit 1; }
    popd

    if ${KURENTO_JAVA_SNAPSHOT} ; then
      git clone https://github.com/Kurento/kurento-java.git
      cd kurento-java && MVN_VERSION="$(grep -oPm1 "(?<=<version>)[^<]+" "pom.xml")"
      cd ../openvidu && mvn --settings /opt/kurento-snapshot-settings.xml -Dmaven.artifact.threads=1 --batch-mode versions:set-property -Dproperty=version.kurento -DnewVersion="$MVN_VERSION"
      cd ..
    fi

    pushd openvidu
    mvn --settings /opt/kurento-snapshot-settings.xml -Dmaven.artifact.threads=1 -DskipTests=true compile || { echo "openvidu-ce -> compile"; exit 1; }
    mvn --settings /opt/kurento-snapshot-settings.xml -Dmaven.artifact.threads=1 -DskipTests=true install || { echo "openvidu-ce -> install"; exit 1; }
    popd

    if [ "${BUILD_OPENVIDU_INSPECTOR}" == true ]; then
      pushd openvidu/openvidu-node-client
      npm-vbump.py --envvar OPENVIDU_CE_VERSION || { echo "Failed to bump package.json version"; exit 1; }
      npm install || { echo "openvidu-browser -> install"; exit 1; }
      npm run build || { echo "openvidu-browser -> build"; exit 1; }
      npm pack || { echo "openvidu-browser -> pack"; exit 1; }
      mv openvidu-node-client-"${OPENVIDU_CE_VERSION}".tgz ../../dashboard
      popd

      pushd openvidu/openvidu-browser
      npm-vbump.py --envvar OPENVIDU_CE_VERSION || { echo "Failed to bump package.json version"; exit 1; }
      npm install || { echo "openvidu-browser -> install"; exit 1; }
      npm run build || { echo "openvidu-browser -> build"; exit 1; }
      npm pack || { echo "openvidu-browser -> build"; exit 1; }
      mv openvidu-browser-"${OPENVIDU_CE_VERSION}".tgz ../../dashboard
      popd

      pushd dashboard
      npm-vbump.py --envvar OPENVIDU_PRO_VERSION || { echo "Failed to bump package.json version"; exit 1; }
      npm install openvidu-node-client-"${OPENVIDU_CE_VERSION}".tgz || { echo "dashboard -> install "; exit 1; }
      npm install openvidu-browser-"${OPENVIDU_CE_VERSION}".tgz || { echo "dashboard -> install "; exit 1; }
      npm install
      npm run build-server-prod  || { echo "dashboard -> build for prod"; exit 1; }
      rm openvidu-node-client-"${OPENVIDU_CE_VERSION}".tgz
      rm openvidu-browser-"${OPENVIDU_CE_VERSION}".tgz
      popd
    fi

    pushd openvidu/openvidu-server
    mvn --settings /opt/kurento-snapshot-settings.xml -Dmaven.artifact.threads=1 -Pdependency install || { echo "openvidu-server-ce -> install dependency"; exit 1; }
    popd

    pushd openvidu-server-pro
    mvn versions:set-property -Dproperty=version.openvidu.server -DnewVersion=${OPENVIDU_CE_VERSION} -DskipTests=true
    mvn versions:set -DnewVersion=$OPENVIDU_PRO_VERSION -DskipTests=true
    mvn --settings /opt/kurento-snapshot-settings.xml -Dmaven.artifact.threads=1 -DskipTests=true clean package || { echo "openvidu-server-pro -> clean package"; exit 1; }
    popd

    pushd openvidu-server-pro/target
    chmod 0400 /opt/id_rsa.key

    if [[ "${OVERWRITE_VERSION}" == 'false' ]]; then
      FILE_EXIST=0
      ssh -o StrictHostKeyChecking=no -i /opt/id_rsa.key ubuntu@pro.openvidu.io \
        [[ -f /var/www/pro.openvidu.io/openvidu-server-pro-"${OPENVIDU_PRO_VERSION}".jar ]] || FILE_EXIST=$?
      if [[ "${FILE_EXIST}" -eq 0 ]]; then
        echo "Build openvidu-server-pro-${OPENVIDU_PRO_VERSION} actually exists and OVERWRITE_VERSION=false"
        exit 1
      fi
    fi

    # Upload to pro.openvidu.io
    scp -o StrictHostKeyChecking=no \
    -i /opt/id_rsa.key \
    openvidu-server-pro-${OPENVIDU_PRO_VERSION}.jar \
    ubuntu@pro.openvidu.io:/var/www/pro.openvidu.io/

    ;;

  replication-manager)

    echo "## Release replication-manager v${OPENVIDU_VERSION}"
    DESC="Release replication-manager v${OPENVIDU_VERSION}"

    # Update pom version
    mvn versions:set -DnewVersion=${OPENVIDU_VERSION} || { echo "Failed to bump openvidu-pro version"; exit 1; }

    # Build
    mvn --batch-mode -DskipTests=true clean compile package || { echo "Failed to build replication-manager version"; exit 1; }

    # Release
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || { echo "Failed to make the release"; exit 1; }
    sleep 10
    openvidu_github_release.go upload  --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --name replication-manager-"${OPENVIDU_VERSION}".jar --file target/replication-manager-"${OPENVIDU_VERSION}".jar || { echo "Failed to upload the artifact to Github"; exit 1; }

    ;;

  mediasoup-controller)
    echo "## Release mediasoup-controller v${OPENVIDU_VERSION}"
    DESC="Release mediasoup-controller v${OPENVIDU_VERSION}"

    # Update version in package.json file
    perl -i -pe "s/\"version\":\s*\"\K\S*(?=\")/$OPENVIDU_VERSION/" package.json || (echo "Failed to bump package.json version"; exit 1)
    git add package.json
    git commit -a -m "Update mediasoup-controller to version v$OPENVIDU_VERSION"

    # Push to github
    git push origin HEAD:master || { echo "Failed to push to Github"; exit 1; }
    openvidu_github_release.go release --user openvidu --repo "$OPENVIDU_REPO" --tag "v$OPENVIDU_VERSION" --description "$DESC" || { echo "Failed to make the release"; exit 1; }

    ;;

  *)
    echo "No project specified"
    exit 1
esac
