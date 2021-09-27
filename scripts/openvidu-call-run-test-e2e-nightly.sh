#!/bin/bash -x
set -eu -o pipefail

DATESTAMP=$(date +%m%d%Y)

# Run the browser
docker run \
  -d \
  --rm \
  --name chrome-${DATESTAMP} \
  -p 4444:4444 \
  -p 5900:5900 \
  --shm-size=1g \
  selenium/standalone-chrome-debug:latest

SELENIUM_URL=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' chrome-${DATESTAMP})

# Run KMS + OV
docker run \
  -d \
  --rm \
  --name kms-ov-${DATESTAMP} \
  -p 4443:4443 \
  -e OPENVIDU_SECRET=MY_SECRET \
  -e OPENVIDU_PUBLICURL=docker \
  openvidu/openvidu-server-kms

OV_URL=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kms-ov-${DATESTAMP})

# Wait for OpenViduServer
until $(curl --insecure --output /dev/null --silent --head --fail --user OPENVIDUAPP:MY_SECRET https://${OV_URL}:4443/)
do
  echo "Waiting for openvidu-server...";
  sleep 5;
done

# Configure the environment
cat >front/openvidu-call/src/environments/environment.ci.ts<<EOF
export const environment = {
  production: true,
  openvidu_url: 'https://${OV_URL}:4443',
  openvidu_secret: 'MY_SECRET'
};
EOF

# Compile the code
cat >run.sh<<EOF
#!/bin/bash -x
cd front/openvidu-call
npm install
./node_modules/\@angular/cli/bin/ng build -c=ci --output-path=/workdir/web
EOF
chmod +x run.sh

docker run \
  -t \
  --rm \
  --name node-${DATESTAMP} \
  -v ${PWD}:/workdir \
  -w /workdir \
  openvidu/openvidu-dev-node:10.x ./run.sh

# Put the app inside the nginx container
mkdir -p nginx
openssl req -subj '/CN=localhost' -x509 -newkey rsa:4096 -nodes -keyout nginx/key.pem -out nginx/cert.pem -days 365

cat >nginx/default.conf<<EOF
server {
    listen       443;
    server_name  localhost;

    ssl on;
    ssl_certificate /etc/nginx/conf.d/cert.pem;
    ssl_certificate_key /etc/nginx/conf.d/key.pem;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}
EOF

docker run \
  -d \
  --rm \
  --name nginx-${DATESTAMP} \
  -p 443:443 \
  -v ${WORKSPACE}/web:/usr/share/nginx/html \
  -v ${WORKSPACE}/nginx:/etc/nginx/conf.d \
  nginx

APP_URL=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nginx-${DATESTAMP})

until $(curl --insecure --output /dev/null --silent --head --fail https://${APP_URL}/)
do
  echo "Waiting for nginx...";
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
  -e APP_URL=https://${APP_URL} \
  -e SELENIUM_URL=http://${SELENIUM_URL}:4444/wd/hub/ \
  -v ${WORKSPACE}:/workdir \
  -w /workdir \
  openvidu/openvidu-dev-node:10.x ./run.sh

# Cleaning the house
CONTAINERS=(chrome kms-ov nginx)
for CONTAINER in "${CONTAINERS[@]}"
do
        docker rm -f $CONTAINER-${DATESTAMP}
done
rm run.sh

# Catch the exit
exit $(cat res.out)
