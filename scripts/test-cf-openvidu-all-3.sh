#!/bin/bash -x
set -eu -o pipefail

# Testing deployment of OpenVidu Server on AWS
# Server and demos in the same CF Template (yaml version)

# VARS
MODE=${MODE:-dev}
TYPE=${TYPE:-server}
DOMAIN_NAME=$(pwgen -A -0 10 1)
TEMPFILE=$(mktemp -t file-XXX --suffix .json)
TEMPJSON=$(mktemp -t cloudformation-XXX --suffix .json)

# Copy template to S3
if [ "${MODE}" == "dev" ]; then
  aws s3 cp CF-OpenVidu-dev.yaml s3://aws.openvidu.io --acl public-read
fi

# Choosing the template
if [ "$MODE" == "dev" ]; then
	CF_FILE="https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-dev.yaml"
elif [ "$MODE" == "prod" ]; then
	CF_FILE="https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-latest.yaml"
else
	echo "Unknown combination"
	exit 0
fi

#############################
### Self signed certificate
#############################
if [ "$TYPE" == "server" ]; then
cat > $TEMPJSON<<EOF
  [
    {"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"},
    {"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"Nil"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"Nil"},
    {"ParameterKey":"MyDomainName","ParameterValue":"Nil"},
    {"ParameterKey":"WantToDeployDemos","ParameterValue":"false"}
  ]
EOF
elif [ "$TYPE" == "demos" ]; then
cat > $TEMPJSON<<EOF
  [
    {"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"},
    {"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"Nil"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"Nil"},
    {"ParameterKey":"MyDomainName","ParameterValue":"Nil"},
    {"ParameterKey":"WantToDeployDemos","ParameterValue":"true"}
  ]
EOF
else
  echo "Unknown combination"
  exit 0
fi  

if [ "$MODE" == "dev" ]; then
  aws cloudformation create-stack \
    --stack-name Openvidu-selfsigned-${DOMAIN_NAME} \
    --template-url ${CF_FILE} \
    --parameters file:///${TEMPJSON} \
    --disable-rollback

  aws cloudformation wait stack-create-complete --stack-name Openvidu-selfsigned-${DOMAIN_NAME}

  echo "Extracting service URL..."
  URL=$(aws cloudformation describe-stacks --stack-name Openvidu-selfsigned-${DOMAIN_NAME} | jq -r '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURL")) | .OutputValue')

  sleep 10
  RES=$(curl --insecure --location -u OPENVIDUAPP:MY_SECRET --output /dev/null --silent --write-out "%{http_code}\\n" ${URL} | grep "200")

  # Cleaning up
  aws cloudformation delete-stack --stack-name Openvidu-selfsigned-${DOMAIN_NAME}

  if [ "$RES" != "200" ]; then
    echo "deployment failed"
    exit 1
  fi
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

aws s3 cp $TEMPKEY s3://public.openvidu.io/openvidu-cloudformation-fake.key --acl public-read
aws s3 cp $TEMPCRT s3://public.openvidu.io/openvidu-cloudformation-fake.crt --acl public-read

if [ "$TYPE" == "server" ]; then
cat > $TEMPJSON<<EOF
  [
    {"ParameterKey": "KeyName","ParameterValue":"kms-aws-share-key" },
    {"ParameterKey":"MyDomainName","ParameterValue":"${DOMAIN_NAME}.k8s.codeurjc.es"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"${IP}"},
    {"ParameterKey":"WhichCert","ParameterValue":"owncert"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"openvidu@gmail.com"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"}, 
    {"ParameterKey":"OwnCertCRT","ParameterValue":"http://public.openvidu.io/openvidu-cloudformation-fake.crt"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"http://public.openvidu.io/openvidu-cloudformation-fake.key"},
    {"ParameterKey":"WantToDeployDemos","ParameterValue":"false"}
  ]
EOF
elif [ "$TYPE" == "demos" ]; then
cat > $TEMPJSON<<EOF
  [
    {"ParameterKey": "KeyName","ParameterValue":"kms-aws-share-key" },
    {"ParameterKey":"MyDomainName","ParameterValue":"${DOMAIN_NAME}.k8s.codeurjc.es"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"${IP}"},
    {"ParameterKey":"WhichCert","ParameterValue":"owncert"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"openvidu@gmail.com"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"}, 
    {"ParameterKey":"OwnCertCRT","ParameterValue":"http://public.openvidu.io/openvidu-cloudformation-fake.crt"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"http://public.openvidu.io/openvidu-cloudformation-fake.key"},
    {"ParameterKey":"WantToDeployDemos","ParameterValue":"true"}
  ]
EOF
else
  echo "Unknown combination"
  exit 0
fi

if [ "$MODE" == "dev" ]; then
  aws cloudformation create-stack \
    --stack-name Openvidu-owncert-${DOMAIN_NAME} \
    --template-url ${CF_FILE} \
    --parameters file:///$TEMPJSON \
    --disable-rollback

  aws cloudformation wait stack-create-complete --stack-name Openvidu-owncert-${DOMAIN_NAME}

  echo "Extracting service URL..."
  URL=$(aws cloudformation describe-stacks --stack-name Openvidu-owncert-${DOMAIN_NAME} | jq -r '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURLLE")) | .OutputValue')

  sleep 10
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

if [ "$TYPE" == "server" ]; then
cat > $TEMPJSON<<EOF
  [
    {"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},
    {"ParameterKey":"MyDomainName","ParameterValue":"${DOMAIN_NAME}.k8s.codeurjc.es"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"${IP}"},
    {"ParameterKey":"WhichCert","ParameterValue":"letsencrypt"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"openvidu@gmail.com"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"},
    {"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"},
    {"ParameterKey":"WantToDeployDemos","ParameterValue":"false"}
  ]
EOF
elif [ "$TYPE" == "demos" ]; then
cat > $TEMPJSON<<EOF
  [
    {"ParameterKey":"KeyName","ParameterValue":"kms-aws-share-key"},
    {"ParameterKey":"MyDomainName","ParameterValue":"${DOMAIN_NAME}.k8s.codeurjc.es"},
    {"ParameterKey":"PublicElasticIP","ParameterValue":"${IP}"},
    {"ParameterKey":"WhichCert","ParameterValue":"letsencrypt"},
    {"ParameterKey":"LetsEncryptEmail","ParameterValue":"openvidu@gmail.com"},
    {"ParameterKey":"WantToSendInfo","ParameterValue":"false"},
    {"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},
    {"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"},
    {"ParameterKey":"WantToDeployDemos","ParameterValue":"true"}
  ]
EOF
else
  echo "Unknown combination"
  exit 0
fi

if [ "$MODE" == "dev" ] || [ "$MODE" == "prod" ]; then
  aws cloudformation create-stack \
    --stack-name Openvidu-letsencrypt-${DOMAIN_NAME} \
    --template-url ${CF_FILE} \
    --parameters file:///$TEMPJSON \
    --disable-rollback

  aws cloudformation wait stack-create-complete --stack-name Openvidu-letsencrypt-${DOMAIN_NAME}

  echo "Extracting service URL..."
  URL=$(aws cloudformation describe-stacks --stack-name Openvidu-letsencrypt-${DOMAIN_NAME} | jq -r '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURLLE")) | .OutputValue')

  sleep 10
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
fi

# Cleaning
rm $TEMPFILE
rm $TEMPJSON
rm $TEMPCRT
rm $TEMPKEY