#!/bin/bash -x
set -eu -o pipefail

# Launch XVFB
/usr/bin/Xvfb :99 -screen 0 1024x768x16 &

# Wait for XVFB
while ! xdpyinfo >/dev/null 2>&1
do
  sleep 0.50s
  echo "Waiting xvfb..."
done

# Launch test
python3 /usr/local/bin/testVideo.py

cat