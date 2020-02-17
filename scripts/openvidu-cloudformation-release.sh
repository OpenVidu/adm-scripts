#!/bin/bash -x
set -e -o pipefail

case $OPENVIDU_PROJECT in

  cloudformation_ov_cluster_free)

    ## Free edition of CloudFormation for OpenVidu Pro

    CF_VERSION=${OPENVIDU_PRO_VERSION}

    # CF Version
    sed "s/@CF_RELEASE@/${CF_VERSION}/" cfn-OpenViduServerPro-cluster.yaml.template > cfn-OpenViduServerPro-cluster-${OPENVIDU_PRO_VERSION}.yaml
    # OV Version
    sed -i "s/@OV_V@/${OPENVIDU_PRO_VERSION}/" cfn-OpenViduServerPro-cluster-${OPENVIDU_PRO_VERSION}.yaml

    cp -v cfn-OpenViduServerPro-cluster-${OPENVIDU_PRO_VERSION}.yaml cfn-OpenViduServerPro-cluster-latest.yaml

    # Keeping the template
    git add cfn-OpenViduServerPro-cluster-${OPENVIDU_PRO_VERSION}.yaml
    git commit -m "New Release ${OPENVIDU_PRO_VERSION}" cfn-OpenViduServerPro-cluster-${OPENVIDU_PRO_VERSION}.yaml
    git push origin master

    # Creating tag
    git tag v${CF_VERSION} || exit 1
    git push --tags

    aws s3 cp cfn-OpenViduServerPro-cluster-${OPENVIDU_PRO_VERSION}.yaml s3://aws.openvidu.io --acl public-read
    aws s3 cp cfn-OpenViduServerPro-cluster-latest.yaml                  s3://aws.openvidu.io --acl public-read

    ;;


  cloudformation_ov_server)

    ## Community edition
    git checkout $GIT_BRANCH
    cd cloudformation-openvidu

    CF_VERSION=${OPENVIDU_VERSION}

    TUTORIALS_RELEASE=$(curl --silent "https://api.github.com/repos/openvidu/openvidu-tutorials/releases/latest" | jq --raw-output '.tag_name' | cut -d"v" -f2)
    OV_CALL_RELEASE=$(curl --silent "https://api.github.com/repos/openvidu/openvidu-call/releases/latest" | jq --raw-output '.tag_name' | cut -d"v" -f2)

    [ ! -z "$OVD_VERSION" ] || OVD_VERSION=${TUTORIALS_RELEASE}
    [ ! -z "$OVC_VERSION" ] || OVC_VERSION=${OV_CALL_RELEASE}

    # CF Version
    sed "s/@CF_V@/${CF_VERSION}/g" CF-OpenVidu-TEMPLATE.yaml > CF-OpenVidu-$OPENVIDU_VERSION.yaml
    # OV Version
    sed -i "s/@OV_V@/${OPENVIDU_VERSION}/" CF-OpenVidu-$OPENVIDU_VERSION.yaml
    # OV Demos Version
    sed -i "s/@OVD_V@/${OVD_VERSION}/" CF-OpenVidu-$OPENVIDU_VERSION.yaml
    # OV Call Version
    sed -i "s/@OVC_V@/${OVC_VERSION}/" CF-OpenVidu-$OPENVIDU_VERSION.yaml

    cp CF-OpenVidu-$OPENVIDU_VERSION.yaml CF-OpenVidu-latest.yaml

    # Update CF of specific version
    aws s3 cp CF-OpenVidu-$OPENVIDU_VERSION.yaml s3://aws.openvidu.io --acl public-read

    # Update latest only if branch is master
    if [[ $GIT_BRANCH == "master" ]]; then
      aws s3 cp CF-OpenVidu-latest.yaml s3://aws.openvidu.io --acl public-read
    fi

    git tag v${CF_VERSION} || exit 1
    git push --tags

    ;;

  cloudformation_ov_pro_server)

    ## Release for marketplace

    pushd aws_marketplace

    sed "s/OV_AMI/${OV_AMI}/" cfn-mkt-openvidu-server-pro.yaml.template > cfn-mkt-openvidu-server-pro-${OPENVIDU_PRO_VERSION}.yaml
    sed -i "s/KMS_AMI/${KMS_AMI}/" cfn-mkt-openvidu-server-pro-${OPENVIDU_PRO_VERSION}.yaml

    aws s3 cp cfn-mkt-openvidu-server-pro-${OPENVIDU_PRO_VERSION}.yaml s3://aws.openvidu.io --acl public-read

    popd

    ;;

  *)
    echo "No project specified"
    exit 1

esac
