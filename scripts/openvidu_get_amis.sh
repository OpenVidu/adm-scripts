#!/bin/bash
#-----------------------------------------------------------------
#
# This script prints all AMIs of OpenVidu CE, Pro, Enterprise
#
# Arguments:
#   - Argument 1: OpenVidu Version
#
#
# Example:
# ./openvidu_get_amis.sh 2.21.0
#
#-----------------------------------------------------------------

set -eu -o pipefail

VERSION=${1:-}
if [[ -z "${VERSION}" ]]; then
    echo "OpenVidu Version needs to be defined as first argument"
fi

function genericRegions() {
    local BASE_URL="${1}"
    local VERSION="${2}"
    curl --silent "${BASE_URL}""${VERSION}"".yaml" |
        grep -B 1 'AMI:' |
        grep -v '\-\-' |
        tr '"' ' ' |
        xargs -n3 |
        sed 's/ //g' |
        cut -d':' -f1
}

function genericAMIs() {
    local BASE_URL="${1}"
    local VERSION="${2}"
    curl --silent "${BASE_URL}""${VERSION}"".yaml" |
        grep -B 1 'AMI:' |
        grep -v '\-\-' |
        tr '"' ' ' |
        xargs -n3 |
        sed 's/ //g' |
        cut -d':' -f3
}

function genericCheckFile() {
    local BASE_URL="${1}"
    local VERSION="${2}"
    curl -o /dev/null --silent -Iw '%{http_code}' \
        "${BASE_URL}""${VERSION}"".yaml"
}

function getOpenViduCERegions() {
    genericRegions "https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-" "${VERSION}"
}

function getOpenViduCEAMIs() {
    genericAMIs "https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-" "${VERSION}"
}

function getOpenViduProRegions() {
    genericRegions "https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Pro-" "${VERSION}"
}

function getOpenViduProAMIs() {
    genericAMIs "https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Pro-" "${VERSION}"
}

function getOpenViduEnterpriseRegions() {
    genericRegions "https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Enterprise-" "${VERSION}"
}

function getOpenViduEnterpriseAMIs() {
    genericAMIs "https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Enterprise-" "${VERSION}"
}

function getCFPrefixURLByEdition() {
    local EDITION=${1:-}
    case ${EDITION} in
        "CE")
            echo "https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-"
            ;;

        "PRO")
            echo "https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Pro-"
            ;;

        "ENTERPRISE")
            echo "https://s3-eu-west-1.amazonaws.com/aws.openvidu.io/CF-OpenVidu-Enterprise-"
            ;;
        *)
            echo "Not valid edition: '${EDITION}'"
            exit 1
            ;;
    esac
}

function getRegionsByEdition() {
    local EDITION=${1:-}
    case ${EDITION} in
        "CE")
            getOpenViduCERegions
            ;;
        "PRO")
            getOpenViduProRegions
            ;;

        "ENTERPRISE")
            getOpenViduEnterpriseRegions
            ;;
        *)
            echo "Not valid edition '${EDITION}'"
            exit 1
            ;;
    esac
}

function getAMIsByEdition() {
    local EDITION=${1:-}
    case ${EDITION} in
        "CE")
            getOpenViduCEAMIs
            ;;
        "PRO")
            getOpenViduProAMIs
            ;;

        "ENTERPRISE")
            getOpenViduEnterpriseAMIs
            ;;
        *)
            echo "Not valid edition '${EDITION}'"
            exit 1
            ;;
    esac
}

function printAMIsByEdition() {
    local EDITION=${1:-}
    local PREFIX_ULR FILE_CHECK_STATUS
    PREFIX_ULR="$(getCFPrefixURLByEdition "${EDITION}")"
    FILE_CHECK_STATUS="$(genericCheckFile "${PREFIX_ULR}" "${VERSION}")"
    if [[ "${FILE_CHECK_STATUS}" == "200" ]]; then
        local REGIONS AMIS NUM_REGIONS NUM_AMIS RESULT REGIONS_ARRAY AMIS_ARRAY
        REGIONS="$(getRegionsByEdition "${EDITION}")"
        AMIS="$(getAMIsByEdition "${EDITION}")"
        NUM_REGIONS="$(echo "$REGIONS" | wc -l)"
        NUM_AMIS="$(echo "$AMIS" | wc -l)"
        if [[ "${NUM_REGIONS}" != "${NUM_AMIS}" ]]; then
            echo "Wrong number of regions and AMIs"
            exit 1
        fi
        readarray -t REGIONS_ARRAY <<< "$REGIONS"
        readarray -t AMIS_ARRAY <<< "$AMIS"
        RESULT=""
        for index in "${!REGIONS_ARRAY[@]}"; do
            if [[ "${REGIONS_ARRAY[index]}" == "eu-west-1" ]]; then
                echo "Ignoring eu-west-1... ${AMIS_ARRAY[index]}"
            else
                if [[ "${index}" == $((NUM_REGIONS - 1)) ]]; then
                    RESULT+="${REGIONS_ARRAY[index]}:${AMIS_ARRAY[index]}"
                else
                    RESULT+="${REGIONS_ARRAY[index]}:${AMIS_ARRAY[index]},"
                fi
            fi
        done
        echo "OpenVidu ${EDITION} AMIs"
        echo "${RESULT}"
    elif [[ "${FILE_CHECK_STATUS}" == "404" ]]; then
        echo "Cloudformation for OpenVidu ${EDITION} version ${VERSION} does not exist"
    fi
}

printAMIsByEdition "CE"
printAMIsByEdition "PRO"
printAMIsByEdition "ENTERPRISE"