#! /usr/bin/env python
#
# coding: utf-8

from xml.etree import ElementTree as et

ns = "http://maven.apache.org/POM/4.0.0"
et.register_namespace('', ns)
tree = et.ElementTree()
tree.parse('pom.xml')
p = tree.getroot().find("{%s}version" % ns)

print p.text