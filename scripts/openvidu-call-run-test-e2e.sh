#!/bin/bash -x
set -eu -o pipefail

DATESTAMP=$(date +%Y%m%d)

# Run the browser
docker run \
  -d \
  --rm \
  --name chrome-${DATESTAMP} \
  -p 4444:4444 \
  -p 5900:5900 \
  --shm-size=1g \
  elastestbrowsers/firefox:latest-2.0.0

SELENIUM_URL=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' chrome-${DATESTAMP})

# Run KMS + OV + OVC
docker run \
  -d \
  --rm \
  --name kms-ov-ovc-${DATESTAMP} \
  -p 4200:4200 \
  -p 4443:4443 \
  -e OV_PROFILE=docker \
  -e OV_PUBLIC_URL=docker \
  openvidu/openvidu-call

APP_URL=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kms-ov-ovc-${DATESTAMP})

# Wait for OpenViduServer
until $(curl --insecure --output /dev/null --silent --head --fail --user OPENVIDUAPP:MY_SECRET https://${APP_URL}:4443/)
do
        echo "Waiting for openvidu-server...";
        sleep 5;
done

# Run the test
cat >run.sh<<EOF
#!/bin/bash -x
cd front/openvidu-call/
npm install
./node_modules/protractor/bin/protractor ./e2e/protractor.conf.js --baseUrl=\${APP_URL}
echo \$? > /workdir/res.out
EOF
chmod +x run.sh

docker run \
  -t \
  --rm \
  --name openvidu-call-test-${DATESTAMP} \
  -e APP_URL=https://${APP_URL}:4443 \
  -e SELENIUM_URL=http://${SELENIUM_URL}:4444/wd/hub/ \
  -v ${WORKSPACE}:/workdir \
  -w /workdir \
  openvidu/openvidu-dev-node:10.x ./run.sh

# Cleaning the house
CONTAINERS=(chrome kms-ov-ovc)
for CONTAINER in "${CONTAINERS[@]}"
do
        docker rm -f $CONTAINER-${DATESTAMP}
done
rm run.sh

# Catch the exit
exit $(cat res.out)
