#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import os

# Changing version in OpenVidu-browser
with open('package.json', 'r') as jsonFile:
	data = json.load(jsonFile)

print data['version']