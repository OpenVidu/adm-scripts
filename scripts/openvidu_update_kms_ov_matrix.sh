#!/bin/bash -x
set -eu -o pipefail

# Will update the DynamoDB table with the tuple [OV_VERSION,KMS_VERSION]

export AWS_DEFAULT_REGION=eu-west-1
aws dynamodb put-item \
  --table-name ov_kms \
  --item '{
    "ov":  {"S": "${OV_VERSION}"},
    "kms": {"S": "${KMS_VERSION}"} 
    }'
