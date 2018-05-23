#!/bin/bash -x
set -eu -o pipefail

EIP=$(aws ec2 allocate-address)
IP=$(echo $EIP |  jq --raw-output '.PublicIp')
DOMAIN_NAME=$(pwgen -A -0 10 1)

cat >file.json<<EOF
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
  --change-batch file:////home/nordri/sandbox/AWS/CF-EIP-Route53/file.json

rm file.json
sleep 60

aws cloudformation create-stack \
  --stack-name Openvidu-${DOMAIN_NAME} \
  --template-url https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-latest.json \
  --parameters '[{"ParameterKey":"KeyName","ParameterValue":"nordri-aws-urjc"}, {"ParameterKey":"MyDomainName","ParameterValue":"'${DOMAIN_NAME}'.k8s.codeurjc.es"},{"ParameterKey":"PublicElasticIP","ParameterValue":"'$IP'"},{"ParameterKey":"WhichCert","ParameterValue":"letsencrypt"},{"ParameterKey":"LetsEncryptEmail","ParameterValue":"openvidu@gmail.com"},{"ParameterKey":"WantToSendInfo","ParameterValue":"false"},{"ParameterKey":"OwnCertCRT","ParameterValue":"AAA"},{"ParameterKey":"OwnCertKEY","ParameterValue":"BBB"}]' 

aws cloudformation wait stack-create-complete --stack-name Openvidu-${DOMAIN_NAME}

echo "Extracting service URL..."
URL=$(aws cloudformation describe-stacks --stack-name Openvidu-${DOMAIN_NAME} | jq '.Stacks[0] | .Outputs[] | select(.OutputKey | contains("WebsiteURLLE")) | .OutputValue' | tr -d \")

RES=$(curl --location -u OPENVIDUAPP:MY_SECRET --output /dev/null --silent --write-out "%{http_code}\\n" ${URL} | grep "200")

# Cleaning up
aws cloudformation delete-stack --stack-name Openvidu-${DOMAIN_NAME}

sleep 60

ALLOCATION_ID=$(aws ec2 describe-addresses --public-ips ${IP} | jq -c ' .Addresses[0] | .AllocationId' | tr -d \")
aws ec2 release-address --allocation-id ${ALLOCATION_ID} 

cat >file.json<<EOF
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
  --change-batch file:////home/nordri/sandbox/AWS/CF-EIP-Route53/file.json

rm file.json

if [ $RES == 200 ]; then
	exit 0
else
	exit $RES
fi
