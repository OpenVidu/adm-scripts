#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import os


# Changing version in openvidu-call-react frontend
with open('openvidu-call-react/package.json', 'r') as jsonFile:
    data = json.load(jsonFile)

data['version'] = os.environ['OPENVIDU_REACT_VERSION']
data['dependencies']['openvidu-browser'] = os.environ['OPENVIDU_REACT_VERSION']

with open('openvidu-call-react/package.json', 'w') as jsonFile:
    json.dump(data, jsonFile, sort_keys=True, indent=4)

# Changing version in openvidu-react library
with open('library/package.json', 'r') as jsonFile:
    data = json.load(jsonFile)

data['version'] = os.environ['OPENVIDU_REACT_VERSION']
data['dependencies']['openvidu-browser'] = os.environ['OPENVIDU_REACT_VERSION']

with open('library/package.json', 'w') as jsonFile:
    json.dump(data, jsonFile, sort_keys=True, indent=4)
