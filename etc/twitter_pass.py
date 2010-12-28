#!/usr/bin/python
# Use this to generate your base64 encoded string for basic authentication
# Syntax: twitter_pass.py <username> <password>
import base64
import sys

s = "%s:%s" % (sys.argv[1], sys.argv[2])
print s + " --> " + base64.b64encode(s)
