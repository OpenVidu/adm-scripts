#!/bin/bash -x
set -eu -o pipefail

export AWS_ACCESS_KEY_ID=${NAEVA_AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${NAEVA_AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=us-east-1
export OV_TASKCAT_VERSION=0.8.42

pushd taskcat

curl -o taskcat.ym/templates/cfn-mkt-openvidu-server-pro-${OV_VERSION}.yaml http://aws.openvidu.io/cfn-mkt-openvidu-server-pro-${OV_VERSION}.yaml
sed -i "s/TEMPLATE_TO_TEST/cfn-mkt-openvidu-server-pro-${OV_VERSION}.yaml/" taskcat.yml

docker run \
  --name openvidu-taskcat-${BUILD_ID} \
  --rm -t \
  -w /workdir \
  -v ${PWD}:/workdir \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=${NAEVA_AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${NAEVA_AWS_SECRET_ACCESS_KEY} \
  openvidu/openvidu-taskcat:${OV_TASKCAT_VERSION} \
  /usr/local/bin/taskcat \
    -c taskcat.yml -p -v \
    -A ${NAEVA_AWS_ACCESS_KEY_ID} \
    -S ${NAEVA_AWS_SECRET_ACCESS_KEY}

popd
