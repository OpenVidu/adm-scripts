#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import os


# Changing version in openvidu-server frontend 
with open('openvidu-server/src/dashboard/package.json', 'r') as jsonFile:
	data = json.load(jsonFile)

data['dependencies']['openvidu-browser'] = os.environ['OPENVIDU_VERSION']

with open('openvidu-server/src/dashboard/package.json', 'w') as jsonFile:
	json.dump(data, jsonFile, sort_keys=True, indent=4)

# Changing version in openvidu-testapp
with open('openvidu-testapp/package.json', 'r') as jsonFile:
	data = json.load(jsonFile)

data['version'] = os.environ['OPENVIDU_VERSION']
data['dependencies']['openvidu-browser'] = os.environ['OPENVIDU_VERSION']

with open('openvidu-testapp/package.json', 'w') as jsonFile:
	json.dump(data, jsonFile, sort_keys=True, indent=4)