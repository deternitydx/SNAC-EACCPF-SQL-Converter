-- SNAC EAC-CPF Postgres SCHEMA

-- Notes
-- =============
-- 1. Main tables are single words
-- 2. Join/link tables are denoted by domain_range
-- 3. General format of the text:
--
--      table name definition (
--  ------------------------
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


-- Sequence for version history (edit/audit trail)
CREATE SEQUENCE "version_history_id_seq"
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

create table version_history (
------------------------------
    id                  int                 primary key default nextval('version_history_id_seq'),
    user_id             int,                -- fk to user.id
    timestamp           timestamp           default now());  -- now()

create table split_merge_history (
----------------------------------
    from_id             int,                -- fk cpf.id
    to_id               int,                -- fk cpf.id
    timestamp           timestamp           default now());

create table cpf_internal (                      -- Describes one EAC-CPF record
-------------------
    id                  int                 default nextval('cpf_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
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
    maintenance_status  int,                -- (fk -> vocabulary.id) 
    valid               boolean,            -- Whether or not this is a valid CPF record
                                            primary key (id, version));

create unique index cpf_ark_idx on cpf (ark_id);

create view cpf as select * from cpf_internal where valid = true; 

create table name_internal (
--------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
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
    additional_parts    text,
                                            primary key(id, version));

create view name as select distinct on (id) * from name_internal order by id asc, version desc; 

create table dates_internal (
---------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- cpf record this date describes
    from_date           varchar(10),        -- standardized form
    from_bc             boolean             default false, -- just in case we ever run into a BC date
    from_original       text,               -- original date entered
    from_type           int,                -- (fk -> vocabulary.id) 
    to_date             varchar(10),        -- standardized form
    to_bc               boolean             default false, -- just in case we ever run into a BC date
    to_original         text,               -- original date entered
    to_type             int,                -- (fk -> vocabulary.id) 
    is_range            boolean             default false, -- if the date is not a range, then from_date will have the only date information
                                            primary key(id, version));

create view dates as select distinct on (id) * from dates_internal order by id asc, version desc; 

create table document_internal (
-------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    name                text,               -- from relationEntry's text
    href                text,               -- link to the resource
    document_type       int,                -- (fk -> vocabulary.id) -- type of the document
    xml_source          text,               -- from objectXMLWrap
                                            primary key(id, version));

create unique index document_href_idx on document (href);
create view document as select distinct on (id) * from document_internal order by id asc, version desc; 

create table nationality_internal (             
-------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    nationality         text,               -- string of the nationality
                                            primary key(id, version));

create unique index nationality_idx on nationality (nationality);
create view nationality as select distinct on (id) * from nationality_internal order by id asc, version desc; 

create table place_internal (
----------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    latitude            int,
    longitude           int,
    administrative_code text,
    country_code        text,
    name                text,
    geonames_id         text,
                                            primary key(id, version));

create view place as select distinct on (id) * from place_internal order by id asc, version desc; 


create table source_internal (
-----------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    source_type         int,                -- maybe unnecessary
    href                text,
    object_xml          text,
                                            primary key(id, version));

create unique index source_href_idx on source (href);

create view source as select distinct on (id) * from source_internal order by id asc, version desc; 


create table contributor_internal (         -- Contributors of data (VIAF, LC, WorldCat, etc)
---------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    short_name          text,               -- short name of the contributing entity (VIAF, LC, WorldCat, NLA, etc)
                                            primary key(id, version));

create unique index contributor_idx on contributor (short_name);

create view contributor as select distinct on (id) * from contributor_internal order by id asc, version desc; 

create table vocabulary (                   -- Controlled Vocabulary
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

create table cpf_otherids_internal (
----------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- (fk -> cpf.id)
    other_id            text,               -- other record id (usually from merge)
    link_type           int,                -- (fk -> vocabulary.id) -- type of link (right now, only MergedRecord)
                                            primary key(id, version));

create view cpf_otherids as select distinct on (id) * from cpf_otherids_internal order by id asc, version desc; 

create table cpf_sources_internal (
----------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- (fk -> cpf.id)
    source_id           int,                -- (fk -> control_sources.id)
                                            primary key(id, version));

create view cpf_sources as select distinct on (id) * from cpf_sources_internal order by id asc, version desc; 

create table cpf_history_internal (
----------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- (fk -> cpf.id)
    modified_time       date,
    event_type          int,                -- (fk -> vocabulary.id)     
    agent_type          int,                -- (fk -> vocabulary.id)     
    agent               text,
    description         text,
    diff                text,               -- keep the diff if we want to undo changes
                                            primary key(id, version));

create view cpf_history as select distinct on (id) * from cpf_history_internal order by id asc, version desc; 

create table cpf_occupation_internal (
-----------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- (fk -> cpf.id)
    occupation_id       int,                -- (fk -> vocabulary.id)
                                            primary key(id, version));

create view cpf_occupation as select distinct on (id) * from cpf_occupation_internal order by id asc, version desc; 

create table cpf_relations_internal (
-----------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    -- version relates to cpf_id1, since this is a 1-way relation
    cpf_id1             int,                -- (fk -> cpf.id)
    cpf_id2             int,                -- (fk -> cpf.id)
    relation_type       int,                -- (fk -> vocabulary.id) -- associated, corresponded, etc
    relation_entry      text,               -- relationEntry from the creation of the eac-cpf record (should be unnecessary in db)
    notes               text,               -- descriptive note.
                                            primary key(id, version));

create view cpf_relations as select distinct on (id) * from cpf_relations_internal order by id asc, version desc; 

create table cpf_place_internal (
----------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- (fk -> cpf.id)
    place_id            int,                -- (fk -> place.id)
    place_match_type    int,                -- (fk -> vocabulary.id) -- likelySame, maybeSame, unmatched
    original            text,
    confidence          int,                -- from snac place entry
                                            primary key(id, version));

create view cpf_place as select distinct on (id) * from cpf_place_internal order by id asc, version desc; 

create table cpf_function_internal (
----------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- (fk -> cpf.id)
    function_term       text,               -- function/term
    function_type       int,                -- (fk -> vocabulary.id) -- might be null, could be "DerivedFromRole"
                                            primary key(id, version));

create view cpf_function as select distinct on (id) * from cpf_function_internal order by id asc, version desc; 

create table cpf_document_internal (
-----------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- (fk -> cpf.id)
    document_id         int,                -- (fk -> document.id)
    document_role       int,                -- (fk -> vocabulary.id) -- creatorOf, referencedIn, etc
    link_type           text,               -- link type
    notes               text,               -- descriptive note.
                                            primary key(id, version));

create view cpf_document as select distinct on (id) * from cpf_document_internal order by id asc, version desc; 

create table cpf_nationality_internal (
------------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- (fk -> cpf.id)
    nationality_id      int,                -- (fk -> nationality.id)
                                            primary key(id, version));

create view cpf_nationality as select distinct on (id) * from cpf_nationality_internal order by id asc, version desc; 

create table cpf_subject_internal (
------------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    cpf_id              int,                -- (fk -> cpf.id)
    subject_id          int,                -- (fk -> vocabulary.id)
                                            primary key(id, version));

create view cpf_subject as select distinct on (id) * from cpf_subject_internal order by id asc, version desc; 

create table name_contributor_internal (         -- Link names to their contributing organization
--------------------------------
    id                  int                 default nextval('unique_id_seq'),
    version             int,                -- fk to version_history.id, sequence is unique foreign key
    name_id             int,                -- (fk -> name.id)
    contributor_id      int,                -- (fk -> contributor.id)
    name_type           int,                -- (fk -> vocabulary.id) -- type of name (authorizedForm, alternativeForm)
                                            primary key(id, version));

create view name_contributor as select distinct on (id) * from name_contributor_internal order by id asc, version desc; 
