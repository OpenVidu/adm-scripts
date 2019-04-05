#!/bin/bash -x
set -eu -o pipefail

# Testing deployment of OpenVidu Server on AWS

# VARS
MODE=${MODE:-dev}
TYPE=${TYPE:-server}
DOMAIN_NAME=$(pwgen -A -0 10 1)
TEMPFILE=$(mktemp -t file-XXX --suffix .json)
TEMPJSON=$(mktemp -t cloudformation-XXX --suffix .json)

# Choosing the template
if [ "$MODE" == "dev" ] && [ "$TYPE" == "server" ]; then
	CF_FILE="https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-dev.json"
elif [ "$MODE" == "dev" ] && [ "$TYPE" == "demos" ]; then
	CF_FILE="https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Demos-dev.json"
elif [ "$MODE" == "prod" ] && [ "$TYPE" == "server" ]; then	
	CF_FILE="https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-latest.json"
elif [ "$MODE" == "prod" ] && [ "$TYPE" == "demos" ]; then	
	CF_FILE="https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Demos-latest.json"
elif [ "$MODE" == "pro" ]; then
  CF_FILE="https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CloudformationOpenViduPro.yaml"
else
	echo "Unknown combination"
	exit 0
fi

#############################
### Self signed certificate
#############################
if [ "$MODE" == "pro" ]; then
  cat > $TEMPJSON<<EOF
  [
    {"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},
    {"ParameterKey":"OpenViduSecret","ParameterValue":"MY_SECRET"},
    {"ParameterKey":"KibanaPassword","ParameterValue":"MY_SECRET"},
    {"ParameterKey":"HTTPSPort","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"SSHCidr","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"UDPRange","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"TCPRange","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"Nil"}
  ]
EOF
else
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
fi

aws cloudformation create-stack \
  --stack-name Openvidu-selfsigned-${DOMAIN_NAME} \
  --template-url ${CF_FILE} \
  --parameters file:///${TEMPJSON} \
  --disable-rollback

aws cloudformation wait stack-create-complete --stack-name Openvidu-selfsigned-${DOMAIN_NAME}

echo "Extracting service URL..."
URL=$(aws cloudformation describe-stacks --stack-name Openvidu-selfsigned-${DOMAIN_NAME} | jq -r '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURL")) | .OutputValue')

RES=$(curl --insecure --location -u OPENVIDUAPP:MY_SECRET --output /dev/null --silent --write-out "%{http_code}\\n" ${URL} | grep "200")

# Cleaning up
aws cloudformation delete-stack --stack-name Openvidu-selfsigned-${DOMAIN_NAME}

if [ "$RES" != "200" ]; then
  echo "deployment failed"
  exit 1
fi

#############################
### Providing a certificate
#############################
EIP=$(aws ec2 allocate-address)
IP=$(echo $EIP |  jq --raw-output '.PublicIp')
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

if [ "$MODE" == "pro" ]; then
  cat > $TEMPJSON<<EOF
  [
    {"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},
    {"ParameterKey":"WhichCert","ParameterValue":"owncert"},
    {"ParameterKey":"MyDomainName","ParameterValue":"${DOMAIN_NAME}.k8s.codeurjc.es"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"${IP}"},
    {"ParameterKey":"OpenViduSecret","ParameterValue":"MY_SECRET"},
    {"ParameterKey":"KibanaPassword","ParameterValue":"MY_SECRET"},
    {"ParameterKey":"HTTPSPort","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"SSHCidr","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"UDPRange","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"TCPRange","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"OwnCertCRT","ParameterValue":"https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/nginx.crt"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/nginx.key"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"Nil"}
  ]
EOF
else
  cat > $TEMPJSON<<EOF
  [
    {"ParameterKey": "KeyName","ParameterValue":"kms-aws-share-key" },
    {"ParameterKey":"MyDomainName","ParameterValue":"${DOMAIN_NAME}.k8s.codeurjc.es"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"${IP}"},
    {"ParameterKey":"WhichCert","ParameterValue":"owncert"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"openvidu@gmail.com"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"}, 
    {"ParameterKey":"OwnCertCRT","ParameterValue":"$(echo ${CRT})"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"$(echo ${KEY})"}
  ]
EOF
fi

aws cloudformation create-stack \
  --stack-name Openvidu-owncert-${DOMAIN_NAME} \
  --template-url ${CF_FILE} \
  --parameters file:///$TEMPJSON \
  --disable-rollback

aws cloudformation wait stack-create-complete --stack-name Openvidu-owncert-${DOMAIN_NAME}

echo "Extracting service URL..."
URL=$(aws cloudformation describe-stacks --stack-name Openvidu-owncert-${DOMAIN_NAME} | jq -r '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURLLE")) | .OutputValue')

RES=$(curl --insecure --location -u OPENVIDUAPP:MY_SECRET --output /dev/null --silent --write-out "%{http_code}\\n" ${URL} | grep "200")

# Cleaning up
aws cloudformation delete-stack --stack-name Openvidu-owncert-${DOMAIN_NAME}

sleep 60

ALLOCATION_ID=$(aws ec2 describe-addresses --public-ips ${IP} | jq -r ' .Addresses[0] | .AllocationId')
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

if [ "$RES" != "200" ]; then
  echo "deployment failed"
  exit 1
fi

#############################
### Let's encrypt certificate
#############################
EIP=$(aws ec2 allocate-address)
IP=$(echo $EIP |  jq --raw-output '.PublicIp')
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

if [ "$MODE" == "pro" ]; then
  cat > $TEMPJSON<<EOF
  [
    {"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},
    {"ParameterKey":"WhichCert","ParameterValue":"letsencrypt"},    
    {"ParameterKey":"MyDomainName","ParameterValue":"${DOMAIN_NAME}.k8s.codeurjc.es"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"${IP}"},
    {"ParameterKey":"OpenViduSecret","ParameterValue":"MY_SECRET"},
    {"ParameterKey":"KibanaPassword","ParameterValue":"MY_SECRET"},
    {"ParameterKey":"HTTPSPort","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"SSHCidr","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"UDPRange","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"TCPRange","ParameterValue":"0.0.0.0/0"},
    {"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"openvidu@gmail.com"}
  ]
EOF
else
cat > $TEMPJSON<<EOF
  [
    {"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},
    {"ParameterKey":"MyDomainName","ParameterValue":"${DOMAIN_NAME}.k8s.codeurjc.es"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"${IP}"},
    {"ParameterKey":"WhichCert","ParameterValue":"letsencrypt"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"openvidu@gmail.com"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"},
    {"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"}
  ]
EOF
fi

aws cloudformation create-stack \
  --stack-name Openvidu-letsencrypt-${DOMAIN_NAME} \
  --template-url ${CF_FILE} \
  --parameters file:///$TEMPJSON \
  --disable-rollback

aws cloudformation wait stack-create-complete --stack-name Openvidu-letsencrypt-${DOMAIN_NAME}

echo "Extracting service URL..."
URL=$(aws cloudformation describe-stacks --stack-name Openvidu-letsencrypt-${DOMAIN_NAME} | jq -r '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURLLE")) | .OutputValue')

RES=$(curl --location -u OPENVIDUAPP:MY_SECRET --output /dev/null --silent --write-out "%{http_code}\\n" ${URL} | grep "200")

# Cleaning up
aws cloudformation delete-stack --stack-name Openvidu-letsencrypt-${DOMAIN_NAME}

sleep 60

ALLOCATION_ID=$(aws ec2 describe-addresses --public-ips ${IP} | jq -r '.Addresses[0] | .AllocationId')
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

if [ "$RES" != "200" ]; then
  echo "deployment failed"
  exit 1
fi

# Cleaning
rm $TEMPFILE
rm $TEMPJSON
rm $TEMPCRT
rm $TEMPKEY