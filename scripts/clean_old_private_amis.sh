#!/bin/bash -x
set -eu -o pipefail

# Delete AMIs with specified prefixed older than MAX_DAYS
#
# Input parameters:
#
# MAX_DAYS: Default = 15
# PREFIX_AMIS: Multiline string with prefixes to delete

# Params intialization
MAX_DAYS="${MAX_DAYS:-15}"
[[ -n "${PREFIX_AMIS}" ]] || { echo "PREFIX_AMIS is not defined"; exit 1; }
export AWS_DEFAULT_REGION=eu-west-1
TARGET_REGIONS="eu-north-1
                eu-west-3
                eu-west-2
                eu-west-1
                sa-east-1
                ca-central-1
                ap-south-1
                ap-southeast-1
                ap-southeast-2
                ap-northeast-1
                ap-northeast-2
                ap-east-1
                eu-central-1
                us-east-1
                us-east-2
                us-west-1
                us-west-2
                me-south-1
                af-south-1"

# This function deletes ONLY private AMIs older than specific days
clean_old_amis_by_prefix() {
    # Parameters
    # $1 Prefix which AMIs must have to be deleted
    # $2 Max Days to keep Images
    local PREFIX="${1}"
    local MAX_DAYS="${2}"
    local DAYS_AGO
    DAYS_AGO="$(date +%Y-%m-%d -d "${MAX_DAYS} days ago")"

    # Creating Query to delete old AMIs
    # Shellcheck will warn about expansion. We don't want variable expansion in QUERY_TEMPLATE
    # shellcheck disable=SC2016
    local QUERY_TEMPLATE='Images[?CreationDate<`DAYS_AGO`]|[?starts_with(Name, `PREFIX`) == `true`][CreationDate, Name, ImageId, Public]'
    local QUERY_TEMPLATE="${QUERY_TEMPLATE//DAYS_AGO/${DAYS_AGO}}"
    local QUERY="${QUERY_TEMPLATE//PREFIX/${PREFIX}}"
    for REGION in ${TARGET_REGIONS}
    do
        # Array with AMIs which should not be deleted because it is being used
        CURRENT_AMIS_BEING_USED=()
        # Get AMIs which are currently used in the account
        AMI_ID_INSTANCE_ID_LIST="$(aws ec2 describe-instances --region "${REGION}" | jq -r '.Reservations[].Instances[].ImageId')"
        for AMI_ID_INSTANCE_ID in ${AMI_ID_INSTANCE_ID_LIST}; do
            AMI_ID=$(echo "${AMI_ID_INSTANCE_ID}" | cut -d'|' -f1)
            AMI_NAME="$(aws ec2 describe-images --region "${REGION}" --image-ids "${AMI_ID}" | jq -r '.Images[0].Name')"
            # Check if removable AMI is being used
            while IFS= read -r PREFIX; do
                PREFIX_TRIM=$(echo -e "${PREFIX}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                if [[ "${AMI_NAME}" == "${PREFIX_TRIM}"* ]]; then
                    CURRENT_AMIS_BEING_USED+=("${AMI_ID}")
                fi
            done <<< "$PREFIX_AMIS"
        done

        # Request to AWS
        # The result of the call will have this format
        # CreationDate \t Name \t AMI_ID \t Public
        local OLD_AMI_LIST
        OLD_AMI_LIST="$(aws ec2 describe-images \
            --region "${REGION}" \
            --filters Name=image-type,Values=machine Name=is-public,Values=false \
            --query "${QUERY}" \
            --output text | sort -k1)"

        # Delete AMIs
        # 1. First of all, check if the answer is empty
        if [[ -n "${OLD_AMI_LIST}" ]]; then
            # 2. Read each line of the answer
            while read -r OLD_AMI ; do
                # Parse the result
                local AMI_DATE AMI_NAME AMI_ID IS_PUBLIC SNAPSHOT_ID
                AMI_DATE=$(awk '{print $1}' < <(echo "$OLD_AMI"))
                AMI_NAME=$(awk '{print $2}' < <(echo "$OLD_AMI"))
                AMI_ID=$(awk '{print $3}' < <(echo "$OLD_AMI"))

                # 4. Check if the image is bein used
                USED_AMI="False"
                for USED_AMI_ID in "${CURRENT_AMIS_BEING_USED[@]}"; do
                    if [[ "${USED_AMI_ID}" == "${AMI_ID}" ]]; then
                        USED_AMI="True"
                    fi
                done

                if [[ "${USED_AMI}" == "False" ]]; then
                    IS_PUBLIC=$(awk '{print $4}' <(echo "$OLD_AMI"))
                    # 5. Check if image is public and the AMI name starts with the PREFIX variable
                    # It is filtered by the aws cli, but these checks are just in case
                    if [[ "${IS_PUBLIC}" != "False" ]]; then
                        echo "The image '${AMI_NAME}' - '${AMI_ID}' is public"
                        exit 1
                    fi
                    if [[ "${AMI_NAME}" != "${PREFIX}"* ]]; then
                        echo "The image '${AMI_NAME}' - '${AMI_ID}' does not start with the specified prefix: ${PREFIX}"
                        exit 1
                    fi
                    # 6. Get Snapshot ID to delete it
                    SNAPSHOT_ID="$(aws ec2 describe-images --region "${REGION}" \
                        --image-ids "${AMI_ID}" --output text \
                        --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId')"

                    # 7. Showing information about AMI to delete
                    echo "Deleting AMI: '${AMI_NAME}': Date: '${AMI_DATE}', AMI ID: '${AMI_ID}', SNAPSHOT ID: '${SNAPSHOT_ID}' Is public: '${IS_PUBLIC}', Region: ${REGION}"

                    # 8. Delete AMI
                    # 8.1 Deregister AMI
                    aws ec2 deregister-image --region "${REGION}" --image-id "${AMI_ID}"
                    # 8.2 Delete Snapshot
                    aws ec2 delete-snapshot --region "${REGION}" --snapshot-id "${SNAPSHOT_ID}"
                else
                    echo "AMI Id '${AMI_ID}' with name '${AMI_NAME}' will not be deleted because it is being used"
                fi
            done < <(echo "${OLD_AMI_LIST}")
        fi
    done
}

while IFS= read -r PREFIX; do
    clean_old_amis_by_prefix "${PREFIX}" "${MAX_DAYS}"
done <<< "$PREFIX_AMIS"
