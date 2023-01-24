#!/usr/bin/env bash
set -eu -o pipefail
set -x

echo "##################### EXECUTE: openvidu_release_s3_cf_and_scripts.sh #####################"

export AWS_DEFAULT_REGION=eu-west-1

[[ -z ${FROM_VERSION} ]] && echo "FROM_VERSION must be defined" && exit 1
[[ -z ${TO_VERSION} ]] && echo "TO_VERSION must be defined" && exit 1

echo "Updating files CF files from ${FROM_VERSION} to ${TO_VERSION}"
# aws s3 cp s3://aws.openvidu.io/CF-OpenVidu-"${FROM_VERSION}".yaml s3://aws.openvidu.io/CF-OpenVidu-"${TO_VERSION}".yaml --acl public-read
aws s3 cp s3://aws.openvidu.io/CF-OpenVidu-Pro-"${FROM_VERSION}".yaml s3://aws.openvidu.io/CF-OpenVidu-Pro-"${TO_VERSION}".yaml --acl public-read
aws s3 cp s3://aws.openvidu.io/CF-OpenVidu-Enterprise-"${FROM_VERSION}".yaml s3://aws.openvidu.io/CF-OpenVidu-Enterprise-"${TO_VERSION}".yaml --acl public-read

echo "Updating installation scripts from ${FROM_VERSION} to ${TO_VERSION}"
# aws s3 cp s3://aws.openvidu.io/install_openvidu_"${FROM_VERSION}".sh s3://aws.openvidu.io/install_openvidu_"${TO_VERSION}".sh --acl public-read
aws s3 cp s3://aws.openvidu.io/install_openvidu_pro_"${FROM_VERSION}".sh s3://aws.openvidu.io/install_openvidu_pro_"${TO_VERSION}".sh --acl public-read
aws s3 cp s3://aws.openvidu.io/install_media_node_"${FROM_VERSION}".sh s3://aws.openvidu.io/install_media_node_"${TO_VERSION}".sh --acl public-read
aws s3 cp s3://aws.openvidu.io/install_openvidu_enterprise_master_node_"${FROM_VERSION}".sh s3://aws.openvidu.io/install_openvidu_enterprise_master_node_"${TO_VERSION}".sh --acl public-read
