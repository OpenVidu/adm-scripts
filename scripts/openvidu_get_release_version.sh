#!/bin/bash -x
set -e

[ ! -z "$RELEASE_URL" ] || exit 1

echo $(curl "$RELEASE_URL" | jq --raw-output '.tag_name' | cut -d"v" -f2)

