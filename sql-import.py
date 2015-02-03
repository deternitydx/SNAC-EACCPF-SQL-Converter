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

    print("Parsing: ", filename.strip())
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
                
                if (dtag == "identity"):
                    for ident in desc:
                        itag = valueOf(ident.tag)
                        if (itag == "entityType"):
                            cpf["entity_type"] = ident.text
                        elif(itag == "nameEntry"):
                            # if it is the first, then it is the preferred name
                            # convention: first name in the name table is the preferred name
                            # language, preference_score, authorized_form,original, corporate_name, 
                            # contributor[{contributor, name_type}]
                            name = {}
                            name_contrib = []
                            name["preference_score"] = ident.get("{http://socialarchive.iath.virginia.edu/}preferenceScore")
                            for name_part in ident:
                                if (valueOf(name_part.tag) == "part"):
                                    name["original"] = name_part.text
                                elif (valueOf(name_part.tag) == "alternativeForm" or
                                      valueOf(name_part.tag) == "authorizedForm"):
                                    name_contrib.append({"contributor":name_part.text, "name_type":valueOf(name_part.tag)})
                                else:
                                    warning("Unknown Tag: ", tag, dtag, itag, valueOf(name_part.tag))
                            name["contributor"] = name_contrib
                            names.append(name)
                        else:
                            warning("Unknown Tag: ", tag, dtag, itag, valueOf(name_part.tag))
                elif (dtag == "description"):
                    for description in desc:
                        d2tag = valueOf(description.tag)
                        if (d2tag == "existDates"):
                            None
                            #TODO
                        elif (d2tag == "localDescription"):
                            if (termOnly(description.get("localType")) == "AssociatedSubject"):
                                subjects.append(description[0].text)
                                #if (description[1]):
                                #    warning("Unknown Tag: ", tag, dtag, d2tag, description[1].tag)
                            else:
                                warning("Unknown Attribute: ", tag, dtag, d2tag, "localType = ", description.get("localType"))
                        elif (d2tag == "languageUsed"):
                            None
                            #TODO
                        elif (d2tag == "occupation"):
                            None
                            #TODO
                        elif (d2tag == "biogHist"):
                            None
                            #TODO
                elif (dtag == "relations"):
                    for rel in desc:
                        rtag = valueOf(rel.tag)
                        if (rtag == "cpfRelation"):
                            None
                        elif (rtag == "resourceRelation"):
                            None
                        else:
                            warning("Unknown Tag: ", tag, dtag, rtag)
                else:
                    warning("Unknown Tag: ", tag, dtag)

        else:
            # Unknown tag
            warning("Unknown Tag: ", tag)

    #print (cpf)
    #print(cpf_otherids)
