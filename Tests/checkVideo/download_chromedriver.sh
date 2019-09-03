#!/bin/bash -x
set -eu -o pipefail

# Get ChromeDriver
CHROMEDRIVER_VERSION=$(curl --silent https://chromedriver.storage.googleapis.com/LATEST_RELEASE)
wget -O chromedriver.zip https://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip
unzip -o chromedriver.zip -d .
rm -Rfv chromedriver.zip
