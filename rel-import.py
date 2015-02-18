from __future__ import print_function
import codecs
import os
import fileinput
import sys
# Import XML parser
import xml.etree.ElementTree as ET
# Import Postgres connector
import psycopg2 as pgsql

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
    
# Insert into database
def insert_db(db, table, var) :
    # Try to select on the exact string we're inserting.  If exists, then return that ID.
    keys = []
    values = []
    for k in var.keys():
        keys.append(k)
        values.append(var[k])
    selstr = ''.join(["SELECT id FROM ", table, " WHERE ", "=%s AND ".join(keys), "=%s LIMIT 1"])
    db.execute(selstr, values)
    tmp = db.fetchone()
    if tmp is not None:
        return tmp[0]
    # Select didn't return any rows, so do the normal insert.
    insstr = ''.join(["INSERT INTO ", table, " (", ",".join(var.keys()), ") values ( %(", ")s,%(".join(var.keys()), ")s ) RETURNING id;"])
    db.execute(insstr, var)
    return db.fetchone()[0]

# Insert into database
def lookup_cpf_byark(db, ark) :
    # Try to select on the exact string we're inserting.  If exists, then return that ID.
    db.execute("SELECT id FROM cpf WHERE ark_id=%s LIMIT 1", (ark))
    tmp = db.fetchone()
    if tmp is not None:
        return tmp[0]
    return None
    
# Update a table in the database
def update_db(db, table, var, where) :
    insstr = ''.join(["UPDATE ", table, " SET (", ",".join(var.keys()), ") = ( %(", ")s,%(".join(var.keys()), ")s ) WHERE ", where, " RETURNING id;"])
    db.execute(insstr, var)
    return db.fetchone()[0]


# Define the namespaces to use
namespaces = { "snac" : "urn:isbn:1-931666-33-4" ,
        "snac2" : "http://socialarchive.iath.virginia.edu/control/term#",
        "schema" : "http://schema.org/",
        "xlink" : "http://www.w3.org/1999/xlink",
        "snac3" : "http://socialarchive.iath.virginia.edu/"}
# Register the namespaces
ET.register_namespace("eac-cpf", "urn:isbn:1-931666-33-4")
ET.register_namespace("snac2", "http://socialarchive.iath.virginia.edu/control/term#")
ET.register_namespace("snac", "http://socialarchive.iath.virginia.edu/")
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")

languages = {}
scripts = {}

# Connect to the postgres DB
db = pgsql.connect("host=localhost dbname=eaccpf user=snac password=snacsnac")
db_cur = db.cursor()

# For each file given on standard input, parse and look at
for filename in fileinput.input():

    print("Parsing: ", filename.strip(), file=sys.stderr)
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
    nationalities = []
    biogHists = []
    cpf_otherids = []
    cpf_history = []
    cpf_relations = []

    # Parse each known tag, in order.  Any missing, report to the warning function.  
    # That way, we can keep track of all problematic or missing tags from the schema
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
                        cpf_history.append(maint_history)
                elif (ctag == "sources"):
                    for source in control:
                        sources.append({'source_type': source.get('{http://www.w3.org/1999/xlink}type'), 'href': source.get('{http://www.w3.org/1999/xlink}href')});
                        # TODO: what about the full text of the source?
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
                            for edates in description:
                                if (valueOf(edates.tag) == "dateRange"):
                                    date = {}
                                    date["is_range"] = True
                                    if (valueOf(edates[0].tag) == "fromDate"):
                                        if (edates[0].text is not None):
                                            date["from_date"] = edates[0].get("standardDate")
                                            date["from_original"] = edates[0].text
                                            date["from_type"] = termOnly(edates[0].get("localType"))
                                        if (len(edates) > 1 and valueOf(edates[1].tag) == "toDate" and edates[1].text is not None):
                                            date["to_date"] = edates[1].get("standardDate")
                                            date["to_original"] = edates[1].text
                                            date["to_type"] = termOnly(edates[1].get("localType"))
                                    elif (valueOf(edates[0].tag) == "toDate"):
                                        if (edates[0].text is not None):
                                            date["to_date"] = edates[0].get("standardDate")
                                            date["to_original"] = edates[0].text
                                            date["to_type"] = termOnly(edates[0].get("localType"))
                                    else:
                                        warning("Unknown Tag: ", tag, dtag, d2tag, valueOf(edates.tag), valueOf(edates[0].tag))
                                    dates.append(date)
                                elif (valueOf(edates.tag) == "date"):
                                    date = {}
                                    date["is_range"] = False
                                    date["from_date"] = edates.get("standardDate")
                                    date["from_original"] = edates.text
                                    date["from_type"] = termOnly(edates.get("localType"))
                                    dates.append(date)
                                else:
                                    warning("Unknown Tag: ", tag, dtag, d2tag, valueOf(edates.tag))
                        elif (d2tag == "place"):
                            #TODO Handle place tags and snac:placeEntry items
                            None
                        elif (d2tag == "localDescription"):
                            if (termOnly(description.get("localType")) == "AssociatedSubject"):
                                subjects.append(description[0].text)
                                if (len(description) > 1):
                                    warning("Unknown Tag: ", tag, dtag, d2tag, description[1].tag)
                            elif (termOnly(description.get("localType")) == "nationalityOfEntity"):
                                nationalities.append(description[0].text)
                                if (len(description) > 1):
                                    warning("Unknown Tag: ", tag, dtag, d2tag, description[1].tag)
                            elif (termOnly(description.get("localType")) == "gender"):
                                cpf["gender"] = description[0].text
                                if (len(description) > 1):
                                    warning("Unknown Tag: ", tag, dtag, d2tag, description[1].tag)
                            else:
                                warning("Unknown Attribute: ", tag, dtag, d2tag, "localType = ", description.get("localType"))
                        elif (d2tag == "languageUsed"):
                            for lang in description:
                                if (valueOf(lang.tag) == "language"):
                                    cpf["language_used"] = lang.get("languageCode")
                                elif (valueOf(lang.tag) == "script"):
                                    cpf["script_used"] = lang.get("scriptCode")
                                else:
                                    warning("Unknown Tag: ", tag, dtag, d2tag, lang.tag)
                        elif (d2tag == "occupation"):
                            occupations.append(description[0].text)
                            if (len(description) > 1):
                                warning("Unknown Tag: ", tag, dtag, d2tag, description[1].tag)
                        elif (d2tag == "biogHist"):
                            biogHists.append(ET.tostring(description, encoding="UTF-8"))
                elif (dtag == "relations"):
                    for rel in desc:
                        rtag = valueOf(rel.tag)
                        if (rtag == "cpfRelation"):
                            relation = {}
                            if (len(rel) > 1):
                                warning("Unknown Tag: ", tag, dtag, d2tag, description[1].tag)
                            relation["relation_type"] = termOnly(rel.get("{http://www.w3.org/1999/xlink}arcrole"))
                            relation["relation_ark_id"] = rel.get("{http://www.w3.org/1999/xlink}href")
                            relation["relation_other_type"] = termOnly(rel.get("{http://www.w3.org/1999/xlink}role"))
                            if (len(rel) > 0):
                                relation["relation_entry"] = rel[0].text
                            else:
                                relation["relation_entry"] = "" 
                            cpf_relations.append(relation)
                        elif (rtag == "resourceRelation"):
                            relation = {}
                            relation["document_role"] = termOnly(rel.get("{http://www.w3.org/1999/xlink}arcrole"))
                            relation["href"] = rel.get("{http://www.w3.org/1999/xlink}href")
                            relation["document_type"] = termOnly(rel.get("{http://www.w3.org/1999/xlink}role"))
                            relation["link_type"] = rel.get("{http://www.w3.org/1999/xlink}type")
                            for relitem in rel:
                                if (valueOf(relitem.tag) == "relationEntry"):
                                    relation["name"] = relitem.text
                                elif (valueOf(relitem.tag) == "objectXMLWrap"):
                                    relation["xml_source"] = ET.tostring(relitem, encoding="UTF-8")
                                elif (valueOf(relitem.tag) == "descriptiveNote"):
                                    relation["notes"] = ET.tostring(relitem, encoding="UTF-8")
                                else:
                                    warning("Unknown Tag: ", tag, dtag, rtag, relitem.tag)
                            documents.append(relation)
                        else:
                            warning("Unknown Tag: ", tag, dtag, rtag)
                else:
                    warning("Unknown Tag: ", tag, dtag)

        else:
            warning("Unknown Tag: ", tag)

    # DB interactions:
    # db_cur.execute("SQL STATEMENT %(name)s", {name:"blah",...})
    # db_cur.execute("SQL STATEMENT %s, %s", ("first", "second"))
    # INSERT INTO table (var, var) VALUES (%s, %s);
    
    
    # TODO Handle the following data
    #print("PLACES", places)
    #print("RELS", cpf_relations)


    # Create CPF record in database and get ID, returns id    
    cpfid = lookup_cpf_byark(db_cur,cpf["ark_id"])
    if (cpfid is not None):
        for rel in cpf_relations:
            relid = lookup_cpf_byark(db_cur, rel["relation_ark_id"])
            if relid is not None:
                insert_db(db_cur, 'cpf_relations', {'cpf_id1':cpfid, 'cpf_id2':relid, 'relation_type':rel["relation_type"], 'relation_entry': rel["relation_entry"]})

    # Commit the changes
    db.commit()
    
# Close the database connection
db_cur.close()
db.close()
        
