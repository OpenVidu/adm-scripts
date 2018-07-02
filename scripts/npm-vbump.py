#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import os
import argparse

def bump_version(ENV_VAR):
	with open('package.json', 'r') as jsonFile:
		data = json.load(jsonFile)

	data['version'] = os.environ[ENV_VAR]

	with open('package.json', 'w') as jsonFile:
		json.dump(data, jsonFile, sort_keys=True, indent=4)

def main():

	parser = argparse.ArgumentParser(
		description = "We need to now which envvar should pass to the package.json")

	parser.add_argument("--envvar",
		                metavar = "envvar",
		                help = "OPENVIDU_VERSION or OPENVIDU_CALL_VERSION",
		                default = "OPENVIDU_VERSION")

	args = parser.parse_args()

	bump_version(args.envvar)

if __name__ == "__main__":
	main()