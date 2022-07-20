#!/bin/bash
set -eu -o pipefail
#-----------------------------------------------------------------
#
# The purpose of this script is to don't deprecate any AMI
#
#
#
# Example:
# ./stop_ami_deprecation.sh
#
#-----------------------------------------------------------------
OWNER=${1}
export AWS_DEFAULT_REGION=eu-west-1
# Check commands before execution to fail on permission errors
aws ec2 describe-regions > /dev/null
aws ec2 describe-images --owner "${OWNER}" > /dev/null

declare -a REGIONS=($(aws ec2 describe-regions --output json | jq -r '.Regions[].RegionName' | tr "\\n" " " ))
for REGION in "${REGIONS[@]}" ; do
    declare -a AMIS=($(aws ec2 describe-images --region "${REGION}" --owner "${OWNER}" | jq -r '.Images[].ImageId' | tr "\\n" " " ))
    for AMI in "${AMIS[@]}" ; do
        echo "Disabling deprecation of ${AMI}..."
        aws ec2 disable-image-deprecation --region "${REGION}" --image-id "${AMI}"
    done
done