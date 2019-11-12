#!/usr/bin/env bash
set -eu -o pipefail
set -x

# Will update the DynamoDB table with the tuple [OV_VERSION,KMS_VERSION]

export AWS_DEFAULT_REGION=eu-west-1

aws dynamodb put-item \
  --table-name ov_kms \
  --item '{
    "ov":  {"S": '\"${OPENVIDU_VERSION}\"'},
    "kms": {"S": '\"${KMS_VERSION}\"'} 
    }'

