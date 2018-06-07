#!/bin/bash -x
set -eu -o pipefail

# Create a nightly docker container for OpenVidu TestApp

DATESTAMP=$(date +%Y%m%d)

pushd openvidu-testapp/docker

# Download nightly version of OpenVidu Server
curl -o openvidu-server.jar http://builds.openvidu.io/openvidu/nightly/latest/openvidu-server-latest.jar

# Download nightly version of TestApp
mkdir -p web
curl -O http://builds.openvidu.io/openvidu/nightly/latest/openvidu-testapp-latest.zip
unzip openvidu-testapp-latest.zip -d web

# Generate SSL
cd web
openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -subj '/CN=www.mydom.com/O=My Company LTD./C=US' -keyout key.pem -out cert.pem
openssl pkcs12 -export -in cert.pem -inkey key.pem -out keystore.p12 -password pass:CERT_PASS -name CERT_ALIAS -CAfile cert.pem
keytool -importkeystore -srckeystore keystore.p12 -srcstoretype PKCS12 -deststorepass CERT_PASS -srcstorepass CERT_PASS -destkeystore NEW.jks -deststoretype JKS
cd ..

# Build docker image
docker build --no-cache --rm=true -t openvidu/testapp:nightly-${DATESTAMP} .

# Upload the image
docker login -u "$OPENVIDU_DOCKERHUB_USER" -p "$OPENVIDU_DOCKERHUB_PASSWD"
docker push openvidu/testapp:nightly-${DATESTAMP} 
docker logout