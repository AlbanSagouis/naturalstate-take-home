-- Vegetation QA/QC handoff (#11): staged tables, parameters, check catalogue, flags, summaries.
-- Target: PostgreSQL 14 or later. Not run on a PostgreSQL server here. The three distance
-- checks (SPA-04, SPA-05, SPA-06) need a geometry library (PostGIS or a Python equivalent).
-- Run once. The raw ODK tables are assumed to exist already (see the handoff, section 1).
--
-- Rule for the staged tables: they carry primary keys and types, and NO CHECK constraints
-- on data values, no NOT NULL on measured values and no foreign keys between data rows.
-- A bad value (blank count, orphan row, accuracy of 5.066 m) must load and be flagged,
-- never be rejected by the database. The checks are the validation.

-- ---------------------------------------------------------------------------------------
-- Stage 1: staged tables (typed and joined, nothing dropped). Written by the staging step.
-- ---------------------------------------------------------------------------------------

-- Registered plots: one row per plot of the vegplots entity list.
CREATE TABLE veg_plot (
    plot_entity_id text PRIMARY KEY,          -- vegplots __id; the survey's selected_plot_uuid
    plot_uuid      text,                      -- vegplots plot_uuid; key to the registration form
    plot_name      text NOT NULL UNIQUE,
    plot_status    text,                      -- primary or backup
    is_viable      text,                      -- yes or no, as in the entity list
    -- The entity "geometry" is an ODK geopoint string 'lat lon alt acc' (latitude first,
    -- space separated). Keep the string and its four parsed parts. NULL when absent.
    geometry_raw   text,
    lat            double precision,
    lon            double precision,
    altitude_m     double precision,
    accuracy_m     double precision
);

-- Species lists: the main list and the extra list (free-text and provisional names).
CREATE TABLE veg_species (
    species_uuid    text PRIMARY KEY,         -- entity __id
    list_name       text NOT NULL,            -- 'species' or 'species_extra'
    label           text NOT NULL,            -- kept exactly as received, outer spaces included
    scientific_name text,
    family          text
);

CREATE TABLE veg_project_team (
    member_uuid text PRIMARY KEY,
    label       text
);

-- Plot registration submissions (register_vegetation_plots form).
CREATE TABLE veg_registration (
    register_key  text PRIMARY KEY,           -- ODK KEY
    review_state  text,
    submitted_at  timestamptz,                -- SubmissionDate (UTC)
    ended_at      timestamptz,                -- survey_end-end_time, offset honoured
    plot_uuid     text,                       -- plot_selection-selected_plot_uuid
    plot_name     text,
    is_plot_viable text,
    sample_status text
);

-- Herbaceous survey submissions: one row per submission (survey KEY).
CREATE TABLE veg_survey (
    survey_key        text PRIMARY KEY,       -- ODK KEY of the submission
    review_state      text,                   -- NULL, approved, hasIssues or rejected
    form_version      text,
    edits             integer,
    submitted_at      timestamptz,            -- SubmissionDate, UTC
    started_at        timestamptz,            -- survey_begin-start_time, offset honoured
    ended_at          timestamptz,            -- survey_end-end_time, offset honoured
    -- Local calendar date of the start as written by the device (first 10 characters of the
    -- ODK string). Used for the survey_date column of the flags and summaries.
    survey_date       date,
    plot_entity_id    text,                   -- plot_selection-selected_plot_uuid -> veg_plot
    plot_name         text,
    plot_status       text,                   -- plot_selection-get_plot_status (the form's
                                              -- plot_selection-plot_status is blank in the export)
    survey_def_uuid   text,                   -- survey_begin-selected_survey_uuid
    recorder_uuid     text,
    recorder_label    text,
    team_uuids        text,                   -- space-separated UUIDs
    register_key      text,                   -- registration submission of the plot, if found
    declared_quadrat_count          integer,  -- observations-quadrat_repeat_count
    declared_quadrats_with_species  integer,  -- survey_end-quadrats_with_species (form calculation)
    bg_lat            double precision,       -- survey_end-background_geopoint-*
    bg_lon            double precision,
    bg_altitude_m     double precision,
    bg_accuracy_m     double precision
);
CREATE INDEX veg_survey_plot_idx ON veg_survey (plot_name);

-- Quadrats: one row per quadrat_repeat row. survey_key is NOT a foreign key on purpose:
-- an orphan row loads and is flagged (STR-01).
CREATE TABLE veg_quadrat (
    quadrat_key      text PRIMARY KEY,        -- ODK KEY of the repeat row
    survey_key       text,                    -- ODK PARENT_KEY
    quadrat_number   integer,
    herbs_present    text,                    -- yes / no
    selected_species_uuids text,              -- space-separated entity UUIDs, as received
    declared_species_count integer,           -- herb_species-count_herb_species, NULL if blank
    additional_species_present text,          -- yes / no
    lat              double precision,        -- location_quadrat-*
    lon              double precision,
    altitude_m       double precision,
    accuracy_m       double precision
);
CREATE INDEX veg_quadrat_survey_idx ON veg_quadrat (survey_key);

-- One row per species record: a species picked from the list (one row per UUID of the
-- space-separated cell) or a row of the additional-species repeat.
CREATE TABLE veg_species_record (
    record_id     text PRIMARY KEY,           -- additional row: its KEY; picked species:
                                              -- quadrat_key || '#' || position in the cell
    source        text NOT NULL,              -- 'selected_list' or 'additional_repeat'
    survey_key    text,
    quadrat_key   text,                       -- ODK PARENT_KEY for additional rows
    species_uuid  text,                       -- picked or reused entity UUID, NULL for new names
    species_name  text,                       -- list label, or the form's validated_name
    typed_name    text,                       -- new_missing_canonical: what the team typed
    entry_mode    text,                       -- reuse_unknown, reuse_missing, new_unknown, new_missing
    review_status text
);
CREATE INDEX veg_species_record_quadrat_idx ON veg_species_record (quadrat_key);

-- ---------------------------------------------------------------------------------------
-- Configuration owned by Biometrics: parameters and the check catalogue. Insert-only.
-- ---------------------------------------------------------------------------------------

CREATE TABLE veg_parameter (
    name        text NOT NULL,
    valid_from  timestamptz NOT NULL DEFAULT now(),
    value_num   double precision,
    value_text  text,
    meaning     text NOT NULL,
    PRIMARY KEY (name, valid_from),
    CHECK ((value_num IS NULL) <> (value_text IS NULL))
);

-- Current value of a parameter: the latest row that has already started. Check queries
-- call these two functions instead of hard-coding a tolerance.
CREATE FUNCTION veg_param_num(p text) RETURNS double precision
LANGUAGE sql STABLE AS $$
    SELECT value_num FROM veg_parameter
    WHERE name = p AND valid_from <= now()
    ORDER BY valid_from DESC LIMIT 1
$$;

CREATE FUNCTION veg_param_text(p text) RETURNS text
LANGUAGE sql STABLE AS $$
    SELECT value_text FROM veg_parameter
    WHERE name = p AND valid_from <= now()
    ORDER BY valid_from DESC LIMIT 1
$$;

-- One row per check and version. Biometrics inserts a new version to change anything;
-- old versions stay so that every flag traces back to the row that raised it.
CREATE TABLE veg_check_catalogue (
    check_id         text NOT NULL,           -- e.g. CON-04
    version          integer NOT NULL DEFAULT 1,
    valid_from       timestamptz NOT NULL DEFAULT now(),
    active           boolean NOT NULL DEFAULT true,
    level            text NOT NULL CHECK (level IN ('survey', 'quadrat', 'species')),
    severity         text NOT NULL CHECK (severity IN ('error', 'warning', 'info')),
    rule             text NOT NULL,           -- the rule in one sentence
    input_columns    text NOT NULL,           -- 'columns' in check_catalogue.csv
    sop_reference    text,
    message_template text NOT NULL,           -- placeholders {plot} {quadrat} {value} {detail}
    what_to_check    text NOT NULL,           -- action text for the person who resolves it
    who_can_resolve  text NOT NULL CHECK (who_can_resolve IN ('field team', 'data manager', 'Tech')),
    -- A SELECT returning exactly: survey_key, quadrat_key, value, detail (all text, NULL
    -- allowed except survey_key). Zero rows means no finding. Written by Biometrics.
    check_sql        text,
    PRIMARY KEY (check_id, version)
);

-- ---------------------------------------------------------------------------------------
-- Stage 2: flags. Long format, one row per finding. Written by the check runner only.
-- ---------------------------------------------------------------------------------------

CREATE TABLE veg_check_run (
    run_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    started_at    timestamptz NOT NULL DEFAULT now(),
    finished_at   timestamptz,
    n_surveys     integer,
    n_quadrats    integer,
    n_flags_error   integer,
    n_flags_warning integer,
    n_flags_info    integer,
    status        text NOT NULL DEFAULT 'running',  -- running, ok, failed
    error_message text                              -- set when status is 'failed'
);

CREATE TABLE veg_flag (
    -- Deterministic: md5 of check_id, survey_key, quadrat_key and value (NULL as empty
    -- text), so the same finding keeps its id from run to run.
    flag_id         text PRIMARY KEY,
    check_id        text NOT NULL,
    check_version   integer NOT NULL,
    level           text NOT NULL,
    severity        text NOT NULL,            -- copied from the catalogue row that raised it
    survey_key      text NOT NULL,
    quadrat_key     text,                     -- NULL for survey-level flags
    plot_name       text,
    survey_date     date,
    recorder        text,
    value           text,
    detail          text,
    message         text NOT NULL,            -- template filled in
    who_can_resolve text NOT NULL,
    first_seen_run  bigint NOT NULL REFERENCES veg_check_run (run_id),
    last_seen_run   bigint NOT NULL REFERENCES veg_check_run (run_id),
    -- Set when a later run no longer raises the flag (the data were corrected upstream);
    -- cleared again if it returns. Rows are never deleted.
    resolved_at     timestamptz,
    FOREIGN KEY (check_id, check_version) REFERENCES veg_check_catalogue (check_id, version)
);
CREATE INDEX veg_flag_survey_idx ON veg_flag (survey_key);
CREATE INDEX veg_flag_open_idx ON veg_flag (severity, check_id) WHERE resolved_at IS NULL;

-- ---------------------------------------------------------------------------------------
-- Stage 3: summaries. Rebuilt in full on every run. Two versions of each table:
-- 'accepted' (every submission not rejected in ODK) and 'excluding_errors' (the sensitivity
-- version, see the handoff).
-- ---------------------------------------------------------------------------------------

-- Records left out of the summaries, with the reason: rejected submissions leave both
-- versions (plot and totals tables), the rest only 'excluding_errors'. Nothing is deleted
-- from the staged tables; this table is the whole difference.
CREATE TABLE veg_excluded_record (
    level       text NOT NULL CHECK (level IN ('survey', 'quadrat')),
    survey_key  text NOT NULL,
    quadrat_key text NOT NULL DEFAULT '',     -- '' at survey level
    reason      text NOT NULL,                -- rejected_submission, error_flag_survey,
                                              -- error_flag_quadrat, orphan_record
    PRIMARY KEY (level, survey_key, quadrat_key)
);

CREATE TABLE veg_survey_summary (
    version    text NOT NULL CHECK (version IN ('accepted', 'excluding_errors')),
    survey_key text NOT NULL,
    plot_name  text,
    plot_status text,
    review_state text,
    survey_date date,
    recorder   text,
    duration_min numeric(7, 1),
    n_quadrats integer NOT NULL,
    n_quadrats_with_species integer NOT NULL,
    richness   integer NOT NULL,              -- identified taxa
    n_unknown_labels integer NOT NULL,
    richness_upper_bound integer NOT NULL,
    n_error    integer NOT NULL,              -- flags of the submission, never filtered
    n_warning  integer NOT NULL,
    n_info     integer NOT NULL,
    PRIMARY KEY (version, survey_key)
);

CREATE TABLE veg_plot_summary (
    version    text NOT NULL CHECK (version IN ('accepted', 'excluding_errors')),
    plot_name  text NOT NULL,
    plot_status text,
    is_viable  text,
    surveyed   boolean NOT NULL,
    n_surveys  integer NOT NULL,
    n_quadrats integer NOT NULL,
    gamma_richness integer,                   -- NULL when not surveyed
    mean_quadrat_richness double precision,
    share_quadrats_unknown double precision,
    n_unknown_labels integer NOT NULL,
    richness_upper_bound integer,
    n_error    integer NOT NULL,
    n_warning  integer NOT NULL,
    n_info     integer NOT NULL,
    PRIMARY KEY (version, plot_name)
);

-- Sampling effort: one row per surveyed plot and version. Incidence-based, identified
-- taxa only, on the quadrats of the version (rejected submissions are never in).
-- The curves, the Chao2 interval and the gain over the last quadrats stay in the report.
CREATE TABLE veg_plot_sampling_effort (
    version    text NOT NULL CHECK (version IN ('accepted', 'excluding_errors')),
    plot_name  text NOT NULL,
    n_quadrats integer NOT NULL,
    quadrats_required integer NOT NULL,       -- veg_parameter expected_quadrats_per_plot
    observed_richness integer NOT NULL,       -- identified taxa
    estimated_richness double precision,      -- Chao2; NULL unless estimate_status = 'ok'
    sample_coverage double precision,         -- Chao and Jost incidence coverage, 0 to 1
    completeness double precision,            -- observed_richness / estimated_richness
    approaches_asymptote boolean,             -- completeness >= completeness_min AND
                                              -- sample_coverage >= coverage_min (veg_parameter);
                                              -- NULL without an estimate
    estimate_status text NOT NULL CHECK (estimate_status IN ('ok', 'no_taxa', 'failed')),
    PRIMARY KEY (version, plot_name)
);

CREATE TABLE veg_summary_totals (
    version    text PRIMARY KEY CHECK (version IN ('accepted', 'excluding_errors')),
    n_surveys  integer NOT NULL,
    n_plots_registered integer NOT NULL,
    n_plots_surveyed integer NOT NULL,
    n_quadrats integer NOT NULL,
    richness_all_plots integer NOT NULL,
    n_unknown_labels_all_plots integer NOT NULL,
    mean_quadrat_richness double precision,
    share_quadrats_unknown double precision,
    n_flags_error integer NOT NULL,
    n_flags_warning integer NOT NULL,
    n_flags_info integer NOT NULL
);

-- Map layer: one row per registered plot. Coordinates are the plot centre (veg_plot).
CREATE TABLE veg_plot_location (
    plot_name  text PRIMARY KEY,
    lon        double precision,              -- NULL for a plot without geometry
    lat        double precision,
    worst_severity text NOT NULL CHECK (worst_severity IN ('error', 'warning', 'info', 'none')),
    surveyed   boolean NOT NULL,
    plot_status text,
    n_error    integer NOT NULL,
    n_warning  integer NOT NULL,
    accuracy_m double precision
);

-- Open flags only: what the dashboard reads.
CREATE VIEW veg_flag_open AS
SELECT * FROM veg_flag WHERE resolved_at IS NULL;
