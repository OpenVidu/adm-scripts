#!/bin/bash 
set -eu -o pipefail

if [ "${ACTION}" == "CREATE" ]; then
	sudo htpasswd -b ${HTPASSWDFILE} ${USERNAME} ${PASSWORD}
else
	sudo htpasswd -D ${HTPASSWDFILE} ${USERNAME}
fi

