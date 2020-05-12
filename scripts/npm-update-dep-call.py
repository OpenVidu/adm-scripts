#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import os


# Changing versions in openvidu-call frontend
with open('openvidu-call-front/package.json', 'r') as jsonFile:
    data = json.load(jsonFile)

data['version'] = os.environ['OPENVIDU_CALL_VERSION']
data['dependencies']['openvidu-browser'] = os.environ['OPENVIDU_CALL_VERSION']

with open('openvidu-call-front/package.json', 'w') as jsonFile:
    json.dump(data, jsonFile, sort_keys=True, indent=4)

# Changing versions in openvidu-angular library
with open('openvidu-call-front/projects/openvidu-angular/package.json', 'r') as jsonFile:
    data = json.load(jsonFile)

data['version'] = os.environ['OPENVIDU_CALL_VERSION']
data['dependencies']['openvidu-browser'] = os.environ['OPENVIDU_CALL_VERSION']

with open('openvidu-call-front/projects/openvidu-angular/package.json', 'w') as jsonFile:
    json.dump(data, jsonFile, sort_keys=True, indent=4)

# Changing versions in backend
with open('openvidu-call-back/package.json', 'r') as jsonFile:
    data = json.load(jsonFile)

data['version'] = os.environ['OPENVIDU_CALL_VERSION']

with open('openvidu-call-back/package.json', 'w') as jsonFile:
    json.dump(data, jsonFile, sort_keys=True, indent=4)