#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import os


# Changing version in openvidu-call frontend
with open('front/openvidu-call/package.json', 'r') as jsonFile:
    data = json.load(jsonFile)

data['version'] = os.environ['OPENVIDU_CALL_VERSION']
data['dependencies']['openvidu-browser'] = os.environ['OPENVIDU_CALL_VERSION']

with open('front/openvidu-call/package.json', 'w') as jsonFile:
    json.dump(data, jsonFile, sort_keys=True, indent=4)

# Changing version in openvidu-angular library
with open('front/openvidu-call/projects/openvidu-angular/package.json', 'r') as jsonFile:
    data = json.load(jsonFile)

data['version'] = os.environ['OPENVIDU_CALL_VERSION']

with open('front/openvidu-call/projects/openvidu-angular/package.json', 'w') as jsonFile:
    json.dump(data, jsonFile, sort_keys=True, indent=4)