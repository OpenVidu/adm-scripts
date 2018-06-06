#!/bin/bash -x
set -eu -o pipefail

echo "##################### EXECUTE: openvidu_http_publish #####################"
# BUILDS_HOST url
#   URL where files will be uploaded
#
# FILES string
#   List of files to be uploaded. It consist of a of tuplas
#   SRC_FILE:DST_FILE:UNCOMPRESS separated by white space.
#
# HTTP_KEY path
#   Path to key file used to authenticate
#
# HTTP_CERT path
#   Path to the certificate file if authentication is requried.
#

# Params management
[ -z "$BUILDS_HOST" ] && BUILDS_HOST=builds.openvidu.io
[ -z "$FILES" ] && exit 1
if [ -n "$HTTP_KEY$HTTP_CERT" ]; then
  export CURL="curl --insecure --key $HTTP_KEY --cert $HTTP_CERT"
else
  CURL="curl"
fi

# Copy deployed files
for FILE in $FILES
do
	SRC_FILE=$(echo $FILE|cut -d":" -f 1)
	DST_FILE=$(echo $FILE|cut -d":" -f 2)
    UNCOMPRESS=0 # needed for backward compativility
    [ -f $SRC_FILE ] && $CURL -X POST https://$BUILDS_HOST/$DST_FILE --data-binary @$SRC_FILE
done
