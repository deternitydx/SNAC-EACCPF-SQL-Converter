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
--      A. Controlled Vocabulary Types (Enum definitions)
--      B. Sequence definitions
--      C. Main tables
--      D. Join/Link tables

--
-- A. Controlled Vocabulary Types
--

create type enum_entity_type as enum (
    'person',
    'corporateBody',
    'family'
);


create type enum_language_code as enum (
);


create type enum_script_code as enum (
);


create type enum_language as enum (
);


create type enum_maintenance_status as enum (
);


create type enum_source_type as enum (
);


create type enum_record_type as enum (
);


create type enum_event_type as enum (
);

create type enum_agent_type as enum (
);

create type enum_relation_type as enum (
    'correspondedWith',
    'associatedWith'
);

create type enum_place_match as enum (
    'maybeSame',
    'likelySame',
    'unmatched'
);

create type enum_function_type as enum (
    'DerivedFromRole'
);

create type enum_document_role as enum (
    'creatorOf',
    'referencedIn'
);

create type enum_name_type as enum (
    'authorizedForm',
    'alternativeForm'
);

create type enum_date_type as enum (
    'Birth',
    'Death'
);


--
-- B. Sequences
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


--
-- C. Main Tables
--

create table cpf (                      -- Describes one EAC-CPF record
-------------------
id                  int                 primary key default nextval('cpf_id_seq'),
ark_id              text                unique,        -- control/cpfId
name_id             int,                -- (fk -> name.id) -- for convenience
entity_type         enum_entity_type    not null,
language_code       enum_language_code  not null,
script_code         enum_script_code    not null,
biog_hist           text,
conven_dec_citation text,               -- from control/conventionDeclaration/citation (currently just VIAF)
maintenance_agency  text,
maintenance_status  enum_maintenance_status);

create unique index cpf_ark_idx on cpf (ark_id);

create table name (
--------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- CPF record this name describes
language            enum_language,
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
from_type           enum_date_type,
to_date             varchar(10),        -- standardized form
to_bc               boolean             default false, -- just in case we ever run into a BC date
to_original         text,               -- original date entered
to_type             enum_date_type,
is_range            boolean             default false);-- if the date is not a range, then from_date will have the only date information

create table source (
-----------------------
id                  int                 primary key default nextval('unique_id_seq'),
source_type         enum_source_type,   -- maybe unnecessary
href                text,
object_xml          text);

create table document (
-------------------------
id                  int                 primary key default nextval('unique_id_seq'),
name                text,               -- from relationEntry's text
href                text,               -- link to the resource
xml_source          text);              -- from objectXMLWrap

create table occupation (               -- could be split into a join table
-------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
term                text);              -- string of the occupation

create table place (
----------------------
id                  int                 primary key default nextval('unique_id_seq'),
latitude            int,
longitude           int,
administrative_code text,
country_code        text,
name                text,
geonames_id         text);

create table subject (
--------------------------
id                  int                 primary key default nextval('unique_id_seq'),
subject             text,               -- subject name from localDescription/term
authority           text);              -- if an authority for the subject is needed

create table contributor (              -- Contributors of data (VIAF, LC, WorldCat, etc)
---------------------------
id                  int                 primary key default nextval('unique_id_seq'),
short_name          text);              -- short name of the contributing entity (VIAF, LC, WorldCat, NLA, etc)


--
-- D. Join/Link Tables
--

create table cpf_otherids (
----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
other_id            text,               -- other record id (usually from merge)
link_type           enum_record_type);  -- type of link (right now, only MergedRecord)

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
event_type          enum_event_type,
agent_type          enum_agent_type,
description         text,
diff                text);              -- keep the diff if we want to undo changes

create table cpf_relations (
-----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id1             int,                -- (fk -> cpf.id)
cpf_id2             int,                -- (fk -> cpf.id)
relation_type       enum_relation_type, -- associated, corresponded, etc
relation_entry      text,               -- relationEntry from the creation of the eac-cpf record (should be unnecessary in db)
notes               text);              -- descriptive note.

create table cpf_place (
----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
place_id            int,                -- (fk -> place.id)
place_match_type    enum_place_match,   -- likelySame, maybeSame, unmatched
original            text,
confidence          int);               -- from snac place entry

create table cpf_function (
----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
function_term       text,               -- function/term
function_type       enum_function_type);-- might be null, could be "DerivedFromRole"

create table cpf_document (
-----------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
document_id         int,                -- (fk -> document.id)
document_role       enum_document_role, -- creatorOf, referencedIn, etc
href                text,               -- xlink:href to the resource (unnecessary)
notes               text);              -- descriptive note.

create table cpf_subject (
------------------------------
id                  int                 primary key default nextval('unique_id_seq'),
cpf_id              int,                -- (fk -> cpf.id)
subject_id          int);               -- (fk -> subject.id)

create table name_contributor (         -- Link names to their contributing organization
--------------------------------
id                  int                 primary key default nextval('unique_id_seq'),
name_id             int,                -- (fk -> name.id)
contributor_id      int,                -- (fk -> contributor.id)
name_type           enum_name_type);    -- type of name (authorizedForm, alternativeForm)
