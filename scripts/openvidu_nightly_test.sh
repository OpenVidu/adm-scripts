#!/bin/bash -x
set -eu -o pipefail

# Openvidu Nightly Test

DATESTAMP=$(date +%Y%m%d)

# Launch Firefox container
docker run \
  --rm \
  -d \
  --name firefox-${DATESTAMP} \
  -p 4445:4444 \
  -p 5901:5900 \
  --shm-size=1g \
  elastest/eus-browser-firefox:3.7.1

# Get Firefox Docker IP
FIREFOX_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' firefox-${DATESTAMP})

# Launch Chrome container
docker run \
  --rm \
  -d \
  --name chrome-${DATESTAMP} \
  -p 4444:4444 \
  -p 5900:5900 \
  --shm-size=1g \
  selenium/standalone-chrome-debug:latest

# Get Chrome Docker IP
CHROME_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' chrome-${DATESTAMP})

# Deploy TestApp
docker run \
  --rm \
  -d \
  --name testapp-${DATESTAMP} \
  -p 5000:443 \
  openvidu/testapp:nightly-${DATESTAMP}

# Get Testapp Docker IP
TESTAPP_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' testapp-${DATESTAMP})

# Launch kms
docker run \
  --rm \
  -d \
  --name kms-${DATESTAMP} \
  -p 8888:8888 \
  kurento/kurento-media-server:6.11.0

# Get KMS Docker IP
KMS_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kms-${DATESTAMP})

# Launch OpenViduServer
docker run \
  --rm \
  -d \
  --name openvidu-${DATESTAMP} \
  -p 4443:4443 \
  -e kms.uris=[\"ws://$KMS_IP:8888/kurento\"] \
  -e openvidu.publicurl=docker \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/openvidu/recordings/:/opt/openvidu/recordings/ \
  -e openvidu.recording=true \
  -e MY_UID=$(id -u $USER) \
  -e openvidu.recording.path=/opt/openvidu/recordings/ \
  -e openvidu.recording.public-access=true \
  openvidu/openvidu-server:nightly-${DATESTAMP}

# Get OpenVidu Docker IP
OPENVIDU_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' openvidu-${DATESTAMP})

# Wait for OpenViduServer
TIMEOUT=60
i=0
until $(curl --insecure --output /dev/null --silent --head --fail --user OPENVIDUAPP:MY_SECRET https://${OPENVIDU_IP}:4443/)
do 
	echo "Waiting for openvidu-server...";
	sleep 5;
  let i=i+5
  [ $i == $TIMEOUT ] && { echo "Timeout!"; break; }
done

# Testing
cat >run.sh<<EOF
#!/bin/bash -x
MAVEN_OPTIONS='--batch-mode -DskipTests=true'

pushd openvidu-java-client
mvn \$MAVEN_OPTIONS versions:set -DnewVersion=1.0.0-TEST || exit 1
popd

# OpenVidu Parent
mvn \$MAVEN_OPTIONS versions:set-property -Dproperty=version.openvidu.java.client -DnewVersion=1.0.0-TEST || exit 1
mvn \$MAVEN_OPTIONS clean || exit 1
mvn \$MAVEN_OPTIONS install || exit 1

# OpenVidu Browser
pushd openvidu-browser 
npm install --unsafe-perm || exit 1
npm run build || exit 1
npm link || exit 1
popd 

# OpenVidu Node Client
pushd openvidu-node-client
npm install --unsafe-perm || exit 1
npm run build || exit 1
npm link || exit 1
popd

# OpenVidu Server Dashboard
pushd openvidu-server/src/dashboard 
npm install --unsafe-perm || exit 1
npm link openvidu-browser || exit 1
./node_modules/\@angular/cli/bin/ng build --prod --output-path ../main/resources/static || exit 1
popd

# OpenVidu Server
pushd openvidu-server
mvn \$MAVEN_OPTIONS clean compile package || exit 1
popd

pushd openvidu-test-e2e
mvn --batch-mode -DAPP_URL=https://${TESTAPP_IP}:443/ -DOPENVIDU_URL=https://${OPENVIDU_IP}:4443/ -DREMOTE_URL_CHROME=http://${CHROME_IP}:4444/wd/hub/ -DREMOTE_URL_FIREFOX=http://${FIREFOX_IP}:4444/wd/hub/ test
echo \$? > res.out
popd
EOF
chmod +x run.sh
docker run \
  -t \
  --rm \
  --name maven-${DATESTAMP} \
  -v "$(pwd)":/workdir \
  -w /workdir \
  maven:3.3.9-jdk-8 ./run.sh

# Cleaning the house
CONTAINERS=(firefox chrome testapp kms openvidu)
for CONTAINER in "${CONTAINERS[@]}"
do
	docker rm -f $CONTAINER-${DATESTAMP}
done
rm run.sh

# Catch the exit
exit $(cat res.out)
