#!/bin/bash -x
set -eu -o pipefail

EIP=$(aws ec2 allocate-address)
IP=$(echo $EIP |  jq --raw-output '.PublicIp')
DOMAIN_NAME=$(pwgen -A -0 10 1)
TEMPFILE=$(mktemp -t file-XXX --suffix .json)

cat >$TEMPFILE<<EOF
{
  "Comment": "Testing OpenVidu Server Lets Encrypt Certificate.",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "${DOMAIN_NAME}.k8s.codeurjc.es.",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "${IP}"
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id ZVWKFNM0CR0BK \
  --change-batch file:///$TEMPFILE

sleep 60

# Generate own certificate
TEMPKEY=$(mktemp -t file-XXX --suffix .key)
TEMPCRT=$(mktemp -t file-XXX --suffix .crt)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $TEMPKEY -out $TEMPCRT -subj "/CN=$DOMAIN_NAME.k8s.codeurjc.es"
KEY=$(cat $TEMPKEY)
CRT=$(cat $TEMPCRT)

TEMPJSON=$(mktemp -t cloudformation-XXX --suffix .json)

cat > $TEMPJSON<<EOF
  [
    { "ParameterKey": "KeyName","ParameterValue":"kms-aws-share-key" },
    {"ParameterKey":"MyDomainName","ParameterValue":"${DOMAIN_NAME}.k8s.codeurjc.es"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"${IP}"},
    {"ParameterKey":"WhichCert","ParameterValue":"owncert"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"openvidu@gmail.com"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"}, 
    {"ParameterKey":"OwnCertCRT","ParameterValue":"$(echo ${CRT})"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"$(echo ${KEY})"}
  ]
EOF

aws cloudformation create-stack   --stack-name Openvidu-${DOMAIN_NAME}   --template-url https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Demos-latest.json   --parameters file:///$TEMPJSON --disable-rollback

aws cloudformation wait stack-create-complete --stack-name Openvidu-${DOMAIN_NAME}

echo "Extracting service URL..."
URL=$(aws cloudformation describe-stacks --stack-name Openvidu-${DOMAIN_NAME} | jq '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURLLE")) | .OutputValue' | tr -d \")

RES=$(curl --insecure --location -u OPENVIDUAPP:MY_SECRET --output /dev/null --silent --write-out "%{http_code}\\n" ${URL} | grep "200")

# Cleaning up
aws cloudformation delete-stack --stack-name Openvidu-${DOMAIN_NAME}

sleep 60

ALLOCATION_ID=$(aws ec2 describe-addresses --public-ips ${IP} | jq -c ' .Addresses[0] | .AllocationId' | tr -d \")
aws ec2 release-address --allocation-id ${ALLOCATION_ID} 

cat >$TEMPFILE<<EOF
{
  "Comment": "Deleting OpenVidu Server Lets Encrypt Certificate.",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "${DOMAIN_NAME}.k8s.codeurjc.es.",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "${IP}"
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id ZVWKFNM0CR0BK \
  --change-batch file:///$TEMPFILE

rm $TEMPFILE
rm $TEMPJSON
rm $TEMPCRT
rm $TEMPKEY

if [ $RES == 200 ]; then
	exit 0
else
	exit $RES
fi
