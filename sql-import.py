from __future__ import print_function
import codecs
import os
import fileinput
import sys
# Import XML parser
import xml.etree.ElementTree as ET

# Portability
try:
    register_namespace = ET.register_namespace
except AttributeError:
    def register_namespace(prefix, uri):
        ET._namespace_map[uri] = prefix

# Error printing
def warning(*objs):
    print("WARN: ", *objs, file=sys.stderr)

# Define the namespaces to use
namespaces = { "snac" : "urn:isbn:1-931666-33-4" ,
        "snac2" : "http://socialarchive.iath.virginia.edu/control/term#",
        "schema" : "http://schema.org/",
        "xlink" : "http://www.w3.org/1999/xlink",
        "snac3" : "http://socialarchive.iath.virginia.edu/"}
# Register the namespaces
ET.register_namespace("snac", "urn:isbn:1-931666-33-4")
#ET.register_namespace("snac2", "http://socialarchive.iath.virginia.edu/control/term#")
#ET.register_namespace("snac3", "http://socialarchive.iath.virginia.edu/")
#ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")

# For each file given on standard input, parse and look at
for filename in fileinput.input():

    tree = ET.parse(filename.strip())
    root = tree.getroot()

    # Parse each known tag, in order.  Any missing, report to the warning function.  That way, we can keep track of all problematic or missing tags from the schema
    for node in root:
        warning(node.tag)
