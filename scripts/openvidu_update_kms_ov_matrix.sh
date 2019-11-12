#!/usr/bin/env bash
set -eu -o pipefail
set -x

# Will update the DynamoDB table with the tuple [OV_VERSION,KMS_VERSION]

export AWS_DEFAULT_REGION=eu-west-1

while [[ $# -gt 0 ]]; do
    case "${1-}" in
        --openvidu-version)
        	if [[ -n "${2-}" ]]; then
                export OV_VERSION="$2"
                shift
            else
                echo "ERROR: --openvidu-version expects <OpenViduVersion>"
                exit 1
            fi
            ;;
        --kurento-version)
        	if [[ -n "${2-}" ]]; then
                export KMS_VERSION="$2"
                shift
            else
                echo "ERROR: --kurento-version expects <KurentoVersion>"
                exit 1
            fi
            ;;
        *)
			echo "ERROR: Unknown argument '${1-}'"
            exit 1
            ;;
    esac
    shift
done

aws dynamodb put-item \
  --table-name ov_kms \
  --item "{
    \"ov\":  {\"S\": \"${OV_VERSION}\"},
    \"kms\": {\"S\": \"${KMS_VERSION}\"} 
    }"

