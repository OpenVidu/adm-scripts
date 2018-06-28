#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import os

# Changing version in OpenVidu-browser
with open('package.json', 'r') as jsonFile:
	data = json.load(jsonFile)

data['version'] = os.environ['OPENVIDU_VERSION']

with open('package.json', 'w') as jsonFile:
	json.dump(data, jsonFile, sort_keys=True, indent=4)
