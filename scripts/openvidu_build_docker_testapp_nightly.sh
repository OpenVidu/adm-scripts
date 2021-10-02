#!/bin/bash -x
set -eu -o pipefail

# Create a nightly docker container for OpenVidu TestApp

DATESTAMP=$(date +%Y%m%d)

mkdir -p nginx
openssl req -subj '/CN=localhost' -x509 -newkey rsa:4096 -nodes -keyout nginx/key.pem -out nginx/cert.pem -days 365

cat >nginx/default.conf<<EOF
server {
    listen       443 ssl;
    server_name  localhost;

    ssl_certificate /etc/nginx/conf.d/cert.pem;
    ssl_certificate_key /etc/nginx/conf.d/key.pem;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}
EOF

mkdir -p web
curl -O http://builds.openvidu.io/openvidu/nightly/latest/openvidu-testapp-latest.zip
unzip openvidu-testapp-latest.zip -d web

# Build docker image
docker build --pull --no-cache --rm=true -t openvidu/testapp:nightly-${DATESTAMP} .
docker tag openvidu/testapp:nightly-${DATESTAMP} openvidu/testapp:nightly-latest

# Upload the image
docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"
docker push openvidu/testapp:nightly-${DATESTAMP}
docker push openvidu/testapp:nightly-latest
docker logout
