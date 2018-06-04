#!/bin/bash -x
set -eu -o pipefail

DATESTAMP=$(date +%s)

aws cloudformation create-stack \
  --stack-name Openvidu-${DATESTAMP} \
  --template-url https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Demos-latest.json \
  --parameters '[{"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},{"ParameterKey":"WantToSendInfo","ParameterValue":"false"},{"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},{"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"}]' 

aws cloudformation wait stack-create-complete --stack-name Openvidu-${DATESTAMP}

echo "Extracting service URL..."
URL=$(aws cloudformation describe-stacks --stack-name Openvidu-${DATESTAMP} | jq '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURLLE")) | .OutputValue' | tr -d \")

RES=$(curl --location -u OPENVIDUAPP:MY_SECRET --output /dev/null --silent --write-out "%{http_code}\\n" ${URL} | grep "200")

# Cleaning up
aws cloudformation delete-stack --stack-name Openvidu-${DOMAIN_NAME}

if [ $RES == 200 ]; then
	exit 0
else
	exit $RES
fi
