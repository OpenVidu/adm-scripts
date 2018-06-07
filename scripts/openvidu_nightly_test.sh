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
  -p 4200:5000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/openvidu/recordings:/opt/openvidu/recordings \
  -e openvidu.recording=true \
  -e MY_UID=$(id -u $USER) \
  -e openvidu.recording.path=/opt/openvidu/recordings \
  -e openvidu.recording.public-access=true \
  openvidu/testapp:nightly-${DATESTAMP}

# Get Testapp Docker IP
TESTAPP_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' testapp-${DATESTAMP})

# Launch kms
docker run \
  --rm \
  -d \
  --name kms-${DATESTAMP} \
  -p 8888:8888 \
  kurento/kurento-media-server:6.7.2-xenial

# Get KMS Docker IP
KMS_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kms-${DATESTAMP})

# Launch OpenViduServer
docker run \
  --rm \
  -d \
  --name openvidu-${DATESTAMP} \
  -p 4443:4443 \
  -e kms.uris=[\"ws://$KMS_IP:8888/kurento\"] \
  openvidu/openvidu-server:nightly-${DATESTAMP}

# Get OpenVidu Docker IP
OPENVIDU_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' openvidu-${DATESTAMP})

# Wait for OpenViduServer
until $(curl --insecure --output /dev/null --silent --head --fail --user OPENVIDUAPP:MY_SECRET https://${OPENVIDU_IP}:4443/)
do 
	echo "Waiting for openvidu-server...";
	sleep 5;
done

# Testing
cd openvidu-test-e2e
docker run \
  -it \
  --rm \
  --name maven-${DATESTAMP} \
  -v "$(pwd)":/workdir \
  -w /workdir \
  maven:3.3-jdk-8 mvn -DAPP_URL=https://${TESTAPP_IP}:5000/ -DOPENVIDU_URL=https://${OPENVIDU_IP}:4443/ -DREMOTE_URL_CHROME=http://${CHROME_IP}:4444/wd/hub/ -DREMOTE_URL_FIREFOX=http://${FIREFOX_IP}:4444/wd/hub/ test

# Cleaning the house
CONTAINERS=(firefox chrome testapp kms openvidu maven)
for CONTAINER in "${CONTAINERS[@]}"
do
	docker rm -f $CONTAINER-${DATESTAMP}
done

