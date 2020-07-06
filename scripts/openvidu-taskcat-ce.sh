#!/bin/bash -x
set -eu -o pipefail

export AWS_ACCESS_KEY_ID=${NAEVA_AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${NAEVA_AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=eu-west-1
export OV_TASKCAT_VERSION=0.8.42

pushd taskcat

mkdir -p taskcat.ym/templates
curl -o taskcat.ym/templates/CF-OpenVidu-${OV_VERSION}.yaml https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-${OV_VERSION}.yaml
sed -i "s/TEMPLATE_TO_TEST/CF-OpenVidu-${OV_VERSION}.yaml/" taskcat.yml

docker run \
  --name openvidu-taskcat-${BUILD_ID} \
  --rm -t \
  -w /workdir \
  -v ${PWD}:/workdir \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=${NAEVA_AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${NAEVA_AWS_SECRET_ACCESS_KEY} \
  openvidu/openvidu-taskcat:${OV_TASKCAT_VERSION} \
    && ls -l && /usr/local/bin/taskcat \
    -c taskcat.yml -p -v \
    -A ${NAEVA_AWS_ACCESS_KEY_ID} \
    -S ${NAEVA_AWS_SECRET_ACCESS_KEY}

popd