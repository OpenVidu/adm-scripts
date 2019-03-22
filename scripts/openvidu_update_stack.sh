#!/bin/bash -x
set -eu -o pipefail

DISTRO=$(lsb_release -c | awk '{ print $2 }')

# Find kurento source file
pushd /etc/apt/sources.list.d

KURENTO_APT_FILE=$(find | grep openvidu)
KURENTO_CURRENT_VERSION=$(cat $KURENTO_APT_FILE | cut -d"/" -f4 | awk '{ print $1 }' )

if [ "${KURENTO_CURRENT_VERSION}" != "${KURENTO_NEW_VERSION}" ]; then

	# File treatment
	if [ "${KURENTO_APT_FILE}" == "./kurento.list" ]; then
		echo deb [arch=amd64] http://ubuntu.openvidu.io/${KURENTO_NEW_VERSION} ${DISTRO} kms6 > ${KURENTO_APT_FILE}
	else
		mv ${KURENTO_APT_FILE} ./ubuntu_openvidu_io_${KURENTO_NEW_VERSION}.list
		sed -i "s/${KURENTO_CURRENT_VERSION}/${KURENTO_NEW_VERSION}/" ./ubuntu_openvidu_io_${KURENTO_NEW_VERSION}.list
	fi

	apt update

	echo "Purging KMS ${KURENTO_CURRENT_VERSION}..."
	apt-get remove --purge --yes kurento-media-server

	echo "Installing KMS ${KURENTO_NEW_VERSION}..."
	apt-get install --yes kurento-media-server

	systemctl enable kurento-media-server
	systemctl start kurento-media-server
fi

# Updating openvidu
supervisorctl stop openvidu-server
wget -O /opt/openvidu/openvidu-server.jar https://github.com/OpenVidu/openvidu/releases/download/v${OV_NEW_VERSION}/openvidu-server-${OV_NEW_VERSION}.jar
supervisorctl start openvidu-server

# Cases
case $OV_NEW_VERSION in

	"2.8.0")
		chown -R kurento /opt/openvidu/recordings
		;;
esac