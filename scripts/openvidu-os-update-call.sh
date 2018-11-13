#!/bin/bash -x
set -eu -o pipefail

KMS_VERSION=$1

# Stopping services
systemctl stop kurento-media-server
systemctl stop nginx
supervisorctl stop openvidu-server

# Get the tarball
aws s3 cp s3://openvidu-pro/openvidu-server-pro-latest.jar /opt/openvidu/openvidu-server.jar

# Check if KMS is up to date
if ! grep -q ${KMS_VERSION} /etc/apt/sources.list.d/kurento.list; then
	echo "deb [arch=amd64] http://ubuntu.openvidu.io/${KMS_VERSION} xenial kms6" > /etc/apt/sources.list.d/kurento.list
	apt-get update
	apt-get install --only-upgrade -y kurento-media-server
fi

# Removing old version OpenVidu Call
rm -rf /var/www/html/*

# Deploying
tar zxf /home/ubuntu/openvidu-call.tar.gz -C /var/www/html
chown -R www-data.www-data /var/www/html
rm /home/ubuntu/openvidu-call.tar.gz

# Starting services
systemctl start kurento-media-server
systemctl start nginx
supervisorctl start openvidu-server
