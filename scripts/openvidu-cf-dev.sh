#!/bin/bash -x
set -eu -o pipefail

DATESTAMP=$(date +%s)
TEMPJSON=$(mktemp -t cloudformation-XXX --suffix .json)

cat > $TEMPJSON<<EOF
  [
    {"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"},
    {"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"Nil"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"Nil"},
    {"ParameterKey":"MyDomainName","ParameterValue":"Nil"}
  ]
EOF

aws cloudformation create-stack \
  --stack-name Openvidu-${DATESTAMP} \
  --template-url https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-dev.json \
  --parameters file:///$TEMPJSON \
  --disable-rollback

aws cloudformation wait stack-create-complete --stack-name Openvidu-${DATESTAMP}

echo "Extracting service URL..."
URL=$(aws cloudformation describe-stacks --stack-name Openvidu-${DATESTAMP} | jq '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURL")) | .OutputValue' | tr -d \")

RES=$(curl --insecure --location -u OPENVIDUAPP:MY_SECRET --output /dev/null --silent --write-out "%{http_code}\\n" ${URL} | grep "200")

# Cleaning up
aws cloudformation delete-stack --stack-name Openvidu-${DATESTAMP}

rm $TEMPJSON

if [ $RES == 200 ]; then
	exit 0
else
	exit $RES
fi
