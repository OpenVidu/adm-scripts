#!/bin/bash -x
set -e -o pipefail

case $OPENVIDU_PROJECT in

  cloudformation_ov_cluster_free)

    cd clustering

    CF_VERSION=$(date +"%Y%m%d%H%M%S")
    git tag ${CF_VERSION} || exit 1
    git push --tags

    # CF Version
    sed "s/@CF_RELEASE@/${CF_VERSION}/" cfn-OpenViduServerPro-cluster.yaml.template > cfn-OpenViduServerPro-cluster-$OPENVIDU_VERSION.yaml
    # OV Version
    sed -i "s/@OV_V@/${OPENVIDU_VERSION}/" cfn-OpenViduServerPro-cluster-$OPENVIDU_VERSION.yaml

    cp -v cfn-OpenViduServerPro-cluster-$OPENVIDU_VERSION.yaml cfn-OpenViduServerPro-cluster-latest.yaml

    aws s3 cp cfn-OpenViduServerPro-cluster-$OPENVIDU_VERSION.yaml s3://aws.openvidu.io --acl public-read 
    aws s3 cp cfn-OpenViduServerPro-cluster-latest.yaml            s3://aws.openvidu.io --acl public-read 

    ;;

  cloudformation_free)

    cd cloudformation-openvidu

    CF_VERSION=$(date +"%Y%m%d%H%M%S")
    git tag ${CF_VERSION} || exit 1
    git push --tags

    TUTORIALS_RELEASE=$(curl --silent "https://api.github.com/repos/openvidu/openvidu-tutorials/releases/latest" | jq --raw-output '.tag_name' | cut -d"v" -f2)
    OV_CALL_RELEASE=$(curl --silent "https://api.github.com/repos/openvidu/openvidu-call/releases/latest" | jq --raw-output '.tag_name' | cut -d"v" -f2)

    [ ! -z "$OVD_VERSION" ] || OVD_VERSION=${TUTORIALS_RELEASE}
    [ ! -z "$OVC_VERSION" ] || OVC_VERSION=${OV_CALL_RELEASE}

    # CF Version
    sed "s/@CF_V@/${CF_VERSION}/" CF-OpenVidu-TEMPLATE.yaml > CF-OpenVidu-$OPENVIDU_VERSION.yaml
    # OV Version
    sed -i "s/@OV_V@/${OPENVIDU_VERSION}/" CF-OpenVidu-$OPENVIDU_VERSION.yaml
    # OV Demos Version
    sed -i "s/@OVD_V@/${OVD_VERSION}/" CF-OpenVidu-$OPENVIDU_VERSION.yaml
    # OV Call Version
    sed -i "s/@OVC_V@/${OVC_VERSION}/" CF-OpenVidu-$OPENVIDU_VERSION.yaml

    cp CF-OpenVidu-$OPENVIDU_VERSION.yaml CF-OpenVidu-latest.yaml

    aws s3 cp CF-OpenVidu-$OPENVIDU_VERSION.yaml s3://aws.openvidu.io --acl public-read 
    aws s3 cp CF-OpenVidu-latest.yaml s3://aws.openvidu.io --acl public-read 

    ;;

  *)
    echo "No project specified"
    exit 1

esac