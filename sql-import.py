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

# Get the name of a tag
def valueOf(tag):
    return tag.split("}")[1][0:]

# Get the value of a term
def termOnly(term):
    return term.split("#")[1][0:]

# Define the namespaces to use
namespaces = { "snac" : "urn:isbn:1-931666-33-4" ,
        "snac2" : "http://socialarchive.iath.virginia.edu/control/term#",
        "schema" : "http://schema.org/",
        "xlink" : "http://www.w3.org/1999/xlink",
        "snac3" : "http://socialarchive.iath.virginia.edu/"}
# Register the namespaces
ET.register_namespace("snac", "urn:isbn:1-931666-33-4")
ET.register_namespace("snac2", "http://socialarchive.iath.virginia.edu/control/term#")
ET.register_namespace("snac3", "http://socialarchive.iath.virginia.edu/")
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")

languages = {}
scripts = {}

# For each file given on standard input, parse and look at
for filename in fileinput.input():

    tree = ET.parse(filename.strip())
    root = tree.getroot()

    # Tables in SQL
    cpf = {}
    names = []
    dates = []
    sources = []
    documents = []
    occupations = []
    places = []
    subjects = []
    contributors = []
    cpf_otherids = []
    cpf_sources = []
    cpf_history = []
    cpf_relations = []
    cpf_place = []
    cpf_function = []
    cpf_document = []
    cpf_subject = []
    name_contributor = []

    # Parse each known tag, in order.  Any missing, report to the warning function.  That way, we can keep track of all problematic or missing tags from the schema
    for node in root:
        tag = valueOf(node.tag)
        
        if (tag == "control"):
            # Handle control elements
            for control in node:
                ctag = valueOf(control.tag)
            
                if (ctag == "recordId"):
                    cpf["ark_id"] = control.text
                elif (ctag == "otherRecordId"):
                    cpf_otherids.append({'link_type': termOnly(control.get('localType')), 'other_id': control.text})
                elif (ctag == "maintenanceStatus"):
                    cpf["maintenance_status"] = control.text
                elif (ctag == "maintenanceAgency"):
                    cpf["maintenance_agency"] = control[0].text
                elif (ctag == "languageDeclaration"):
                    cpf["language_code"] = control[0].get('languageCode')
                    languages[control[0].get('languageCode')] = control[0].text
                    cpf["script_code"] = control[1].get('scriptCode')
                    scripts[control[1].get('scriptCode')] = control[1].text
                elif (ctag == "conventionDeclaration"):
                    cpf["conven_dec_citation"] = control[0].text
                elif (ctag == "maintenanceHistory"):
                    # Need to handle the list of Maintenance Events
                    # None;
                    # modified_time, event_type, agent_type, description, diff
                    for maint_event in control:
                        # handle each event individually
                        maint_history = {}
                        if (valueOf(maint_event.tag) == 'maintenanceEvent'):
                            #handle
                            for maint_part in maint_event:
                                if (valueOf(maint_part.tag) == 'eventType'):
                                    maint_history["event_type"] = maint_part.text
                                elif (valueOf(maint_part.tag) == 'eventDateTime'):
                                    maint_history["modified_time"] = maint_part.text
                                elif (valueOf(maint_part.tag) == 'agentType'):
                                    maint_history["agent_type"] = maint_part.text
                                elif (valueOf(maint_part.tag) == 'agent'):
                                    maint_history["agent"] = maint_part.text
                                elif (valueOf(maint_part.tag) == 'eventDescription'):
                                    maint_history["description"] = maint_part.text
                                else:
                                    warning("Unknown Tag: ", tag, ctag, valueOf(maint_event.tag), valueOf(maint_part.tag))
                        else:
                            warning("Unknown Tag: ", tag, ctag, valueOf(maint_event.tag))
                elif (ctag == "sources"):
                    for source in control:
                        sources.append({'source_type': source.get('{http://www.w3.org/1999/xlink}type'), 'href': source.get('{http://www.w3.org/1999/xlink}href')});
                else:
                    warning("Unknown Tag: ", tag, ctag)

        elif (tag == "cpfDescription"):
            # Handle cpfDescription
            for desc in node:
                dtag = valueOf(desc.tag)
                
                #print(dtag)
        else:
            # Unknown tag
            warning("Unknown Tag: ", tag)

    #print (cpf)
    #print(cpf_otherids)
