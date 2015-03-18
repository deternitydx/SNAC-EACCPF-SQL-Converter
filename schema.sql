-- SNAC EAC-CPF Postgres SCHEMA

-- Notes
-- =============
-- 1. Main tables are single words
-- 2. Join/link tables are denoted by domain_range
-- 3. General format of the text:
--
--      table name definition (
--      ------------------------
--      field       type        notes/parameters,
--      ...         ...         ...
--
-- 4. Organized as follows:
--      A. Sequence definitions
--      B. Main tables
--      C. Join/Link tables

--
-- A. Sequences
--

-- Sequence for unique cpf IDs
CREATE SEQUENCE "cpf_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Sequence for unique identifiers
CREATE SEQUENCE "unique_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Sequence for controlled vocabulary
CREATE SEQUENCE "vocabulary_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- B. Main Tables
--

create table users (                    -- Users of the system (editors, authors, etc)
----------------------
id                  int                 primary key default nextval('unique_id_seq'),
userid              text                unique,        -- text-based user ids
email               text,               -- contact information for tracking
name                text);              -- full name text

create table cpf (                      -- Describes one EAC-CPF record
-------------------
id                  int                 primary key default nextval('cpf_id_seq'),
ark_id              text                unique,        -- control/cpfId
name_id             int,                               -- (fk -> name.id) -- for convenience
entity_type         int                 not null,      -- (fk -> vocabulary.id) -- record language
gender              int,                               -- (fk -> vocabulary.id) 
language_code       int                 not null,      -- (fk -> vocabulary.id) -- record language
script_code         int                 not null,       -- (fk -> vocabulary.id) 
language_used       int,                -- (fk -> vocabulary.id) -- from languageUsed/language 
script_used         int,                -- (fk -> vocabulary.id) -- from languageUsed,script (what the entity used)
biog_hist           text,
conven_dec_citation text,               -- from control/conventionDeclaration/citation (currently just VIAF)
maintenance_agency  text,
maintenance_status  int);               -- (fk -> vocabulary.id) 

create unique index cpf_ark_idx on cpf (ark_id);

create table name (
--------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- CPF record this name describes
language            int,                -- (fk -> vocabulary.id) 
preference_score    float,              -- Preference to use this name
authorized_form     text,
original            text,               -- actual name (in <part>)
corporate_name      text,
prefix              text,
first               text,
middle              text,
last                text,
suffix              text,
additional_parts    text);

create table dates (
---------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- cpf record this date describes
from_date           varchar(10),        -- standardized form
from_bc             boolean             default false, -- just in case we ever run into a BC date
from_original       text,               -- original date entered
from_type           int,                -- (fk -> vocabulary.id) 
to_date             varchar(10),        -- standardized form
to_bc               boolean             default false, -- just in case we ever run into a BC date
to_original         text,               -- original date entered
to_type             int,                -- (fk -> vocabulary.id) 
is_range            boolean             default false);-- if the date is not a range, then from_date will have the only date information

create table document (
-------------------------
id                  int                 primary key default nextval('unique_id_seq'),
name                text,               -- from relationEntry's text
href                text,               -- link to the resource
document_type       int,                -- (fk -> vocabulary.id) -- type of the document
xml_source          text);              -- from objectXMLWrap

create unique index document_href_idx on document (href);

create table nationality (             
-------------------------
id                  int                 primary key default nextval('unique_id_seq'),
nationality         text);              -- string of the nationality

create unique index nationality_idx on nationality (nationality);

create table place (
----------------------
id                  int                 primary key default nextval('unique_id_seq'),
latitude            int,
longitude           int,
administrative_code text,
country_code        text,
name                text,
geonames_id         text);

create unique index subject_idx on subject (subject);

create table contributor (              -- Contributors of data (VIAF, LC, WorldCat, etc)
---------------------------
id                  int                 primary key default nextval('unique_id_seq'),
short_name          text);              -- short name of the contributing entity (VIAF, LC, WorldCat, NLA, etc)

create unique index contributor_idx on contributor (short_name);

create table vocabulary (               -- Controlled Vocabulary
--------------------------------
id                  int                 primary key default nextval('vocabulary_id_seq'),
type                text,               -- Type of the vocab
value               text);              -- Values the vocab may take

create unique index vocabulary_idx on vocabulary(id);
create index vocabulary_type_idx on vocabulary(type);
create index vocabulary_value_idx on vocabulary(value);

--
-- C. Join/Link Tables
--

create table cpf_otherids (
----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
other_id            text,               -- other record id (usually from merge)
link_type           int);               -- (fk -> vocabulary.id) -- type of link (right now, only MergedRecord)

create table cpf_sources (
----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
source_id           int);               -- (fk -> control_sources.id)

create table cpf_history (
----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
modified_time       date,
event_type          int,                -- (fk -> vocabulary.id)     
agent_type          int,                -- (fk -> vocabulary.id)     
agent               text,
description         text,
diff                text);              -- keep the diff if we want to undo changes

create table cpf_occupation (
-----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
occupation_id       int);               -- (fk -> vocabulary.id)

create table cpf_relations (
-----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id1             int,                -- (fk -> cpf.id)
cpf_id2             int,                -- (fk -> cpf.id)
relation_type       int,                -- (fk -> vocabulary.id) -- associated, corresponded, etc
relation_entry      text,               -- relationEntry from the creation of the eac-cpf record (should be unnecessary in db)
notes               text);              -- descriptive note.

create table cpf_place (
----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
place_id            int,                -- (fk -> place.id)
place_match_type    int,                -- (fk -> vocabulary.id) -- likelySame, maybeSame, unmatched
original            text,
confidence          int);               -- from snac place entry

create table cpf_function (
----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
function_term       text,               -- function/term
function_type       int);               -- (fk -> vocabulary.id) -- might be null, could be "DerivedFromRole"

create table cpf_document (
-----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
document_id         int,                -- (fk -> document.id)
document_role       int,                -- (fk -> vocabulary.id) -- creatorOf, referencedIn, etc
link_type           text,               -- link type
notes               text);              -- descriptive note.

create table cpf_nationality (
------------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
nationality_id      int);               -- (fk -> nationality.id)

create table cpf_subject (
------------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
subject_id          int);               -- (fk -> vocabulary.id)

create table name_contributor (         -- Link names to their contributing organization
--------------------------------
id                  int                 primary key default nextval('unique_id_seq'),
name_id             int,                -- (fk -> name.id)
contributor_id      int,                -- (fk -> contributor.id)
name_type           int);               -- (fk -> vocabulary.id) -- type of name (authorizedForm, alternativeForm)
