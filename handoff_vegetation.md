Herbaceous vegetation QA/QC: handoff to the Tech team
================
Alban Sagouis
2026-10-08

## TL;DR

- **What to build.** A job that runs after the ODK data have reached the
  platform and produces four things: staged tables (typed and joined,
  nothing dropped), a long `veg_flag` table with one row per finding,
  survey and plot summaries, and a plot location layer for a map. The
  tables are in `sql/vegetation_schema.sql`. The checks themselves are
  specified by the catalogue and the R reference, not by SQL.
- **The key rule.** Checks are rows of a catalogue table (59 checks: 28
  error, 21 warning, 10 info). Each row holds the rule, severity,
  message and a `SELECT`. The runner only executes the rows and writes
  what they return. On the sample export that gives 963 flags (11 error,
  148 warning, 804 info) and a data set is never changed or filtered by
  a flag.
- **What Tech must do.** Create the tables, load the catalogue and
  parameter rows, write the staging step and one query per catalogue row
  (56 of 59 need no geometry), rebuild flags and summaries after every
  batch, serve the dashboard tables, and fix the form and entity-list
  issues in section 10. Done means the acceptance counts in section 12.
- **What is not Tech’s decision.** Which checks exist, their severity,
  every tolerance and the species identity rule. Biometrics inserts
  catalogue and parameter rows; Tech never edits one. There is no open
  scientific question in this document.

## 1. Inputs and outputs

### 1.1 What arrives

The brief says the ODK data have already reached the platform. This
handoff starts from the raw tables. Four ODK Central exports and four
entity lists are used.

| Raw table | Written by | Rows | Key | Parent key |
|:---|:---|---:|:---|:---|
| herbaceous_veg_survey | ODK Central | 32 | `KEY` (survey) |  |
| herbaceous_veg_survey-quadrat_repeat | ODK Central | 640 | `KEY` (quadrat) | `PARENT_KEY` = survey `KEY` |
| herbaceous_veg_survey-additional_species_repeat | ODK Central | 1296 | `KEY` | `PARENT_KEY` = quadrat `KEY` |
| register_vegetation_plots | ODK Central | 31 | `KEY` |  |
| vegplots (entity list) | ODK Central entities | 31 | `__id` |  |
| species (entity list) | ODK Central entities | 370 | `__id` |  |
| species_extra (entity list) | ODK Central entities | 250 | `__id` |  |
| project_team (entity list) | ODK Central entities | 6 | `__id` |  |

The row counts are those of the sample export. The raw table names above
are the ODK export names; call them whatever the platform’s raw layer
calls them. Everything that follows is keyed on the ODK `KEY` columns.

### 1.2 Keys and formats that need care

- **Repeat structure.** Survey `KEY` is the quadrat `PARENT_KEY`;
  quadrat `KEY` is the additional-species `PARENT_KEY`. The `KEY` of a
  repeat row is its parent key plus the path (`.../quadrat_repeat[3]`).
- **Plot key.** The survey column `plot_selection-selected_plot_uuid`
  equals the `__id` of the vegplots entity. The vegplots column
  `plot_uuid` is a different id: it matches the registration form.
  Joining a survey to vegplots on `plot_uuid` matches 0 of 32 surveys.
- **Species picked from the list.**
  `herb_species-selected_herb_species_uuids` holds entity UUIDs
  **separated by a space**. The derived name columns use `<br/>`; split
  the UUID cell on any white space or `<br/>`. Staging writes one
  `veg_species_record` row per UUID.
- **Species typed or provisional.** Species that are not on the list
  come through the additional-species repeat: `reuse_unknown` and
  `reuse_missing` carry an entity UUID, `new_unknown` and `new_missing`
  carry a name (`new_missing_canonical` is what the team typed).
- **Geopoints.** ODK exports a geopoint as four columns (`...-Latitude`,
  `-Longitude`, `-Altitude`, `-Accuracy`). The vegplots entity stores it
  as one string, `'lat lon alt acc'`, latitude first, space separated
  (for example 0.2195439 37.4812757 990.8 3.6). Staging parses it into
  `lat`, `lon`, `altitude_m`, `accuracy_m`; a blank is NULL.
- **Timestamps.** `SubmissionDate` is UTC (`...Z`). The form times carry
  the device offset (+02:00 in the sample). Parse them as `timestamptz`
  with the offset honoured (section 9).
- **Blank means NULL.** An empty ODK cell becomes NULL; whitespace is
  never trimmed at staging, because a stray space is something the
  checks report.

### 1.3 Column mapping, raw to staged

The mapping below is checked against the headers of the sample export
when this document is built, so a column named here exists in the raw
file.

| Raw table | Raw column | Staged column | Type |
|:---|:---|:---|:---|
| survey | `KEY` | `veg_survey.survey_key` | text |
| survey | `ReviewState` | `veg_survey.review_state` | text |
| survey | `FormVersion` | `veg_survey.form_version` | text |
| survey | `SubmissionDate` | `veg_survey.submitted_at` | timestamptz |
| survey | `survey_begin-start_time` | `veg_survey.started_at, survey_date` | timestamptz, date |
| survey | `survey_end-end_time` | `veg_survey.ended_at` | timestamptz |
| survey | `plot_selection-selected_plot_uuid` | `veg_survey.plot_entity_id` | text |
| survey | `plot_selection-plot_name` | `veg_survey.plot_name` | text |
| survey | `plot_selection-get_plot_status` | `veg_survey.plot_status` | text |
| survey | `field_team_specifics-recorder_uuid` | `veg_survey.recorder_uuid` | text |
| survey | `observations-quadrat_repeat_count` | `veg_survey.declared_quadrat_count` | integer |
| survey | `survey_end-quadrats_with_species` | `veg_survey.declared_quadrats_with_species` | integer |
| survey | `survey_end-background_geopoint-Latitude` | `veg_survey.bg_lat` | double precision |
| survey | `survey_end-background_geopoint-Accuracy` | `veg_survey.bg_accuracy_m` | double precision |
| quadrat_repeat | `KEY` | `veg_quadrat.quadrat_key` | text |
| quadrat_repeat | `PARENT_KEY` | `veg_quadrat.survey_key` | text |
| quadrat_repeat | `quadrat_number` | `veg_quadrat.quadrat_number` | integer |
| quadrat_repeat | `herbs_present` | `veg_quadrat.herbs_present` | text |
| quadrat_repeat | `herb_species-selected_herb_species_uuids` | `veg_quadrat.selected_species_uuids and one veg_species_record row per UUID` | text |
| quadrat_repeat | `herb_species-count_herb_species` | `veg_quadrat.declared_species_count` | integer |
| quadrat_repeat | `additional_species_present` | `veg_quadrat.additional_species_present` | text |
| quadrat_repeat | `location_quadrat-Latitude` | `veg_quadrat.lat` | double precision |
| quadrat_repeat | `location_quadrat-Accuracy` | `veg_quadrat.accuracy_m` | double precision |
| additional_species_repeat | `KEY` | `veg_species_record.record_id` | text |
| additional_species_repeat | `PARENT_KEY` | `veg_species_record.quadrat_key` | text |
| additional_species_repeat | `species_entry_mode` | `veg_species_record.entry_mode` | text |
| additional_species_repeat | `select_reuse_unknown` | `veg_species_record.species_uuid (this or select_reuse_missing)` | text |
| additional_species_repeat | `validated_name` | `veg_species_record.species_name` | text |
| additional_species_repeat | `new_missing_canonical` | `veg_species_record.typed_name` | text |
| register_vegetation_plots | `KEY` | `veg_registration.register_key` | text |
| register_vegetation_plots | `survey_end-end_time` | `veg_registration.ended_at` | timestamptz |

The other staged columns follow the same pattern (same name with `-`
replaced by `_`, and the geopoint parts in the order latitude,
longitude, altitude, accuracy). The entity lists fill `veg_plot`,
`veg_species`, `veg_project_team`.

### 1.4 Outputs

| Output table | One row per | Written by | Read by |
|:---|:---|:---|:---|
| `veg_flag` | finding | the check runner | dashboard, field-team list |
| `veg_survey_summary` | version and submission | the summary step | dashboard |
| `veg_plot_summary` | version and registered plot | the summary step | dashboard |
| `veg_summary_totals` | version | the summary step | dashboard headline |
| `veg_plot_location` | registered plot | the summary step | dashboard map |
| `veg_excluded_record` | record left out of the sensitivity version | the summary step | dashboard footnote |
| `veg_check_run` | run | the runner | monitoring |

## 2. Pipeline stages

    raw ODK tables ──► staged tables ──► flags ──► summaries and map layer
                       (typed, joined,    (one row per     (accepted and
                        nothing dropped)   finding)         excluding_errors)

### 2.1 Stage rules

1.  **Raw to staged.** Type the columns, parse the geopoints and
    timestamps, split the species UUID cells, join the plot, species and
    team lookups. Row counts are exact: 640 quadrat rows in, 640 out;
    1296 additional-species rows in, 1296 `additional_repeat` rows out;
    947 picked-species rows are added from the UUID cells, giving 2,243
    `veg_species_record` rows in the sample. Nothing is dropped,
    repaired or reordered away. A lookup that does not match leaves the
    looked-up column NULL; an orphan row keeps its NULL parent. Only a
    missing file or a missing required column aborts the run.
2.  **Staged to flags.** Run every active catalogue row against the
    staged tables (section 3). Flags are facts about the submission and
    never filter anything.
3.  **Flags and staged to summaries.** Build the summary tables twice,
    for `accepted` and `excluding_errors` (section 5).

### 2.2 Tables

The definitions are in `sql/vegetation_schema.sql` (PostgreSQL 14 or
later) and reproduced here. It covers the staged tables, parameters,
check catalogue, flags and summaries.

``` sql
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
```

Notes on the tables:

- The staged tables have primary keys and types but **no CHECK
  constraints on data values** and no foreign keys between data rows. A
  blank count, an orphan or an accuracy of 5.066 m must load and be
  flagged, never be rejected by the database.
- `veg_parameter` and `veg_check_catalogue` are insert-only and owned by
  Biometrics. `veg_flag`, summaries and map layer are written only by
  the runner and are rebuilt, not edited.
- STR-03 to STR-05 test the uniqueness of keys in the raw export. If the
  raw layer already enforces a primary key they can never fire; they
  stay in the catalogue anyway, and Tech does not remove a check.

## 3. The check catalogue

### 3.1 The catalogue is configuration

The catalogue has 59 checks, in eight groups by prefix: structure (STR),
plot (PLT), quadrat completeness (QUA), consistency (CON), species
(SPE), spatial (SPA), time (TIM) and metadata (MET). The full text of
every column (id, level, severity, rule, columns, SOP reference, message
template, what to check, who can resolve) is in
`outputs/vegetation/check_catalogue.csv`; this is the specification and
the seed for `veg_check_catalogue`. The column `columns` of the CSV is
called `input_columns` in the table, because `columns` is an SQL
keyword.

| level   | error | warning | info |
|:--------|------:|--------:|-----:|
| quadrat |     9 |       3 |    2 |
| species |     6 |       8 |    1 |
| survey  |    13 |      10 |    7 |

Checks by level and severity

29 checks are resolved by the field team, 23 by the data manager and 7
by Tech (typically a form or export fault).

| id | level | severity | who can resolve | rule |
|:---|:---|:---|:---|:---|
| STR-01 | quadrat | error | data manager | Every quadrat row belongs to a survey submission (PARENT_KEY exists in the survey table). |
| STR-02 | species | error | data manager | Every additional-species row belongs to a quadrat row. |
| STR-03 | survey | error | Tech | Survey KEY is unique. |
| STR-04 | quadrat | error | Tech | Quadrat KEY is unique. |
| STR-05 | species | error | Tech | Additional-species KEY is unique. |
| STR-06 | survey | error | field team | Every survey submission has quadrat rows. |
| STR-07 | survey | info | data manager | A rejected submission for a plot and survey that also has an accepted submission (two submissions for one plot). |
| STR-08 | survey | warning | data manager | More than one accepted (not rejected) submission for the same plot and survey: nobody decided which counts. |
| STR-09 | survey | error | field team | A plot whose submissions are all rejected has no usable survey. |
| PLT-01 | survey | error | data manager | The selected plot exists in the registered plot list (vegplots). |
| PLT-02 | survey | error | data manager | The plot is recorded as viable (plot list and registration). |
| PLT-03 | survey | error | data manager | The plot belongs to the selected survey. |
| PLT-04 | survey | error | field team | The plot has a registration submission. |
| PLT-05 | survey | error | data manager | The plot registration was finished (form end time) before the survey started. |
| PLT-06 | survey | info | data manager | A backup plot was surveyed (primary versus backup). |
| PLT-07 | survey | warning | data manager | The plot status shown by the form equals the status in the plot list. |
| PLT-08 | survey | info | data manager | The registration was uploaded before the survey started (otherwise: delayed upload). |
| PLT-09 | survey | info | data manager | The diversity of the plot is close to that of the other plots. |
| QUA-01 | survey | error | field team | A survey has exactly 20 quadrats. |
| QUA-02 | survey | error | field team | Quadrat numbers are 1 to 20, each once. |
| QUA-03 | survey | warning | data manager | The quadrat count the form recorded equals the number of quadrat rows. |
| QUA-04 | quadrat | info | data manager | A quadrat with no herbs has a species count of 0, not blank. |
| QUA-05 | quadrat | error | field team | Every quadrat has a geopoint. |
| QUA-06 | quadrat | error | field team | herbs_present is yes or no. |
| CON-01 | quadrat | error | field team | herbs_present = no means no species records. |
| CON-02 | quadrat | warning | field team | herbs_present = yes means at least one species record. |
| CON-03 | quadrat | error | data manager | The species count equals the number of species selected from the list. |
| CON-04 | quadrat | error | field team | additional_species_present = yes means at least one additional-species row. |
| CON-05 | quadrat | error | field team | Additional-species rows exist only when additional_species_present = yes. |
| CON-06 | survey | warning | Tech | quadrats_with_species equals the number of quadrats with a species record (selected or additional). |
| CON-07 | species | warning | field team | A species appears once per quadrat and source. |
| SPE-01 | species | error | data manager | Every selected species id resolves to the species list. |
| SPE-02 | species | warning | field team | A typed species name is Genus_species (capital genus, lower-case epithet, underscore, no authorship). |
| SPE-03 | species | info | field team | A provisional unknown (herb_NNN) needs a voucher and a later identification. |
| SPE-04 | species | error | field team | A species name is not a raw identifier (UUID). |
| SPE-05 | species | warning | field team | Typed names and listed species labels have no leading or trailing space. |
| SPE-06 | species | warning | field team | A typed name is not within 2 edits (15 percent of its length) of a different listed name, and its genus is not one letter off a listed genus (likely misspelling). |
| SPE-07 | species | warning | field team | A name is not both selected from the list and typed in one quadrat. |
| SPE-08 | species | warning | data manager | A new species name is entered as new only once; later records reuse it. |
| SPE-09 | species | warning | data manager | A typed name is not already on the species list. |
| SPE-10 | species | error | data manager | A reused extra-species id resolves to the extra-species list. |
| SPE-11 | species | error | field team | Every additional-species row has a name. |
| SPE-12 | species | warning | data manager | A reused extra-species label has no leading or trailing space (reported once per submission and label). |
| SPA-01 | quadrat | error | field team | Quadrat geopoint accuracy is at most 5 m. |
| SPA-02 | survey | warning | field team | The background geopoint accuracy is at most 5 m. |
| SPA-03 | survey | info | field team | The background geopoint is recorded. |
| SPA-04 | quadrat | warning | field team | A quadrat is within the belt around the plot midpoint (reach 25.1 m plus the GPS accuracy of both points). |
| SPA-05 | survey | warning | field team | The background geopoint is near the plot midpoint (same tolerance as SPA-04). |
| SPA-06 | quadrat | info | field team | Consecutive quadrats are at most 7.1 m apart (5 m along the tape, alternating sides) plus twice the combined GPS accuracy. |
| SPA-07 | quadrat | warning | field team | Two quadrats of a survey do not share identical coordinates. |
| TIM-01 | survey | error | Tech | The survey ends after it starts. |
| TIM-02 | survey | warning | field team | The survey lasts between 15 minutes and 3 hours. |
| TIM-03 | survey | warning | Tech | The survey does not start after it was submitted (more than 60 s). |
| TIM-04 | survey | info | field team | The survey is submitted within 12 hours of finishing. |
| TIM-05 | survey | error | Tech | Start, end and submission times are all present and readable. |
| MET-01 | survey | warning | data manager | All submissions use the same form version. |
| MET-02 | survey | info | data manager | The submission has a review state recorded in ODK Central. |
| MET-03 | survey | warning | data manager | A submission marked ‘has issues’ is resolved. |
| MET-04 | survey | error | field team | The recorder is in the project team and in this survey’s team. |

### 3.2 How Biometrics adds or changes a check

Biometrics edits rows; nobody edits code.

- **Change a severity, a message, the action text or who resolves it:**
  insert a new version of the catalogue row (`version + 1`, a later
  `valid_from`). Flags raised from then on carry the new version; flags
  of the old version are closed or re-raised on the next run.
- **Change a tolerance:** insert a new `veg_parameter` row (section 8).
  The queries read tolerances through `veg_param_num()` and
  `veg_param_text()`, never as literals.
- **Switch a check off:** insert a new version with `active = false`.
- **Add a check:** insert a row with a new id and a `check_sql` that
  returns the four columns `survey_key, quadrat_key, value, detail`.
  Placeholders `{plot}`, `{quadrat}`, `{value}` and `{detail}` in
  `message_template` are filled by the runner.

Tech’s part is the runner and the guard rails: it runs `check_sql` as a
read-only database role with a statement timeout, rejects a result that
does not have the four columns, and rolls back the whole run on any
error. Tech does not judge whether a rule is right.

The catalogue CSV does not contain the `check_sql` text. For the first
load Tech writes one query per row from the rule sentence, the input
columns and the reference implementation (`R/functions/veg_checks_*.R`,
one function `veg_chk_<id>` per check). A query is finished when its
flag count matches section 12. From then on the query text is
Biometrics’ to change.

### 3.3 The runner

For each active check the runner materialises the result of its query
into a temporary table, then records the findings: one row per check,
submission, quadrat and value, with `flag_id` the md5 of those four
(NULL as empty text), `first_seen_run` set the first time and
`last_seen_run` updated each time it is raised again. Afterwards one
`UPDATE` sets `resolved_at` on the findings of active checks that were
not raised in this run. The runner SQL is not supplied: it is a few
statements over `veg_flag` (section 4), and it was not run on PostgreSQL
here.

### 3.4 Which checks need geometry

3 checks need a distance between two points: SPA-04, SPA-05, SPA-06. The
other 56 are row-level or group-level comparisons in plain SQL: counts,
joins, comparisons, a regular expression, a time difference.

| id | severity | rule |
|:---|:---|:---|
| SPA-04 | warning | A quadrat is within the belt around the plot midpoint (reach 25.1 m plus the GPS accuracy of both points). |
| SPA-05 | warning | The background geopoint is near the plot midpoint (same tolerance as SPA-04). |
| SPA-06 | info | Consecutive quadrats are at most 7.1 m apart (5 m along the tape, alternating sides) plus twice the combined GPS accuracy. |

How the distances are computed, exactly:

1.  Both points are WGS 84 longitude and latitude (EPSG:4326).
2.  Both are transformed to the projected CRS **EPSG:32637** (WGS 84 /
    UTM zone 37N, in metres). Every plot of the sample lies in this
    zone; the parameter `map_epsg` holds it. The R reference picks the
    zone from the mean coordinate and a test asserts that it gives the
    same code.
3.  The distance is the planar Euclidean distance in metres between the
    projected points. Neither the earth’s curvature nor the altitude is
    used.
4.  Tolerance rule. For a quadrat (SPA-04) or the background geopoint
    (SPA-05): allowed = belt reach + accuracy of the point + accuracy of
    the plot midpoint, with belt reach = sqrt((belt_length_m / 2)^2 +
    (belt_width_m / 2)^2) = sqrt((50 / 2)^2 + (5 / 2)^2) = 25.1 m. A
    missing accuracy is replaced by `accuracy_limit_m` (5 m). The
    finding is raised when distance \> allowed (strictly).
5.  For consecutive quadrats (SPA-06, info): allowed =
    sqrt(quadrat_spacing_m^2 + belt_width_m^2) + 2 \* sqrt(acc_1^2 +
    acc_2^2) = sqrt(5^2 + 5^2) = 7.1 m plus twice the root-sum-square of
    the two accuracies. Only pairs with quadrat numbers n and n + 1 in
    the same submission are compared.
6.  A row with a missing coordinate on either side is skipped by these
    three checks (QUA-05 and SPA-03 report the missing point).

Any geometry library that follows steps 1 to 3 is acceptable (for
example PostGIS with `ST_Transform` and `ST_Distance`, or `pyproj` to
project and then plain Euclidean distance). The R reference uses `sf`.
None of these was compared with another here, so the first load should
check the three distance checks against the flag counts of section 12.

Five other checks are not plain row-level comparisons. STR-07, STR-08,
STR-09, MET-01 compare a submission with the other submissions of the
same plot (STR-07 to STR-09) or with the most common form version
(MET-01). SPE-06 needs an edit distance (the extension `fuzzystrmatch`,
`levenshtein()`, or a Python equivalent): at most 2 edits and at most
15% of the name length, or a genus exactly one letter off a listed genus
of at least 6 letters. SPE-06 is a suggestion for a human, never a
correction.

### 3.5 Two checks worth knowing

Two checks behave in ways worth knowing. CON-06 compares the form’s own
`quadrats_with_species` with the number of quadrats that have at least
one species record of either source; the form figure is wrong (section
10), so this check raises a warning for Tech, not for the field team.
SPE-02 does not trim before matching: a trailing space is a finding. All
45 typed names of the sample fail, because they use a space instead of
an underscore.

## 4. The flags table contract

- **Long format, one row per finding.** A finding is identified by
  check, submission, quadrat and value. `flag_id` is the `md5` of those
  four (NULL as empty text), so the same finding keeps its id across
  runs. The R reference files build the same md5, so the ids in
  `flags.csv` can be compared directly with the ids the runner produces.
- **Columns.**
  `flag_id, check_id, check_version, level, severity, survey_key, quadrat_key, plot_name, survey_date, recorder, value, detail, message, who_can_resolve`
  plus `first_seen_run`, `last_seen_run` and `resolved_at`. `level` and
  `severity` are copied from the catalogue row. `value` and `detail` are
  the raw numbers or strings behind the message, for example the
  distance and the allowed distance.
- **The flags never mutate data.** No staged, raw or summary value is
  changed because of a flag. Resolution happens upstream: someone edits
  the submission in ODK Central, or sets its review state, and the next
  run no longer raises the flag. The runner then sets `resolved_at`; if
  the finding comes back, `resolved_at` is cleared. Rows are never
  deleted, so the history of what was found when stays.
- **One severity per check.** `error` breaks an SOP step or a data rule,
  or makes a record contradictory; `warning` is suspicious and needs a
  human decision; `info` is context or follow-up that needs no
  correction. A flag never has a severity of its own.
- **Uniqueness.** Two rows of one check with the same survey, quadrat
  and value are one finding (`SELECT DISTINCT ON (flag_id)` in the
  runner).
- **Counts in the sample:** 963 flags from 24 of the 59 checks (section
  12 lists them).

## 5. Summaries

All summaries are rebuilt from the staged tables and `veg_flag` on every
run, in two versions (`version` column): `accepted` and
`excluding_errors`. The column definitions below are those of the sample
CSVs in `outputs/vegetation/` and are asserted against them at build
time.

### 5.1 Survey-level

One row per submission, `veg_survey_summary`. Columns:

| column | meaning |
|:---|:---|
| `survey_key` | Submission key |
| `plot_name` | Plot |
| `plot_status` | primary or backup (from the form) |
| `review_state` | ODK review state, NULL if none |
| `survey_date` | Local date of the start |
| `recorder` | Recorder label |
| `duration_min` | End minus start, minutes, 1 decimal |
| `n_quadrats` | Quadrat rows of the submission |
| `n_quadrats_with_species` | Quadrats with at least one species record (any source, identified or not) |
| `richness` | Distinct identified taxa |
| `n_unknown_labels` | Distinct provisional unknown labels |
| `richness_upper_bound` | richness + n_unknown_labels (an upper bound: a label can repeat a named taxon) |
| `n_error` | Error flags of the submission (never filtered) |
| `n_warning` | Warning flags of the submission |
| `n_info` | Info flags of the submission |

### 5.2 Plot-level

One row per registered plot (31 in the sample, of which 30 are
surveyed), `veg_plot_summary`. Only submissions that were not rejected
in ODK count, and the flag counts of a plot come from them too: a plot
submitted twice because one of the two submissions was rejected (Plot_18
and Plot_21) has one survey and 20 quadrats, like every other plot.
Columns:

| column | meaning |
|:---|:---|
| `plot_name` | Registered plot |
| `plot_status` | primary or backup |
| `is_viable` | From the registration |
| `surveyed` | At least one submission |
| `n_surveys` | Submissions of the plot that were not rejected in ODK |
| `n_quadrats` | Quadrats of those submissions |
| `gamma_richness` | Distinct identified taxa over the plot |
| `mean_quadrat_richness` | Mean identified taxa per quadrat |
| `share_quadrats_unknown` | Share of quadrats with at least one unknown record |
| `n_unknown_labels` | Distinct unknown labels over the plot |
| `richness_upper_bound` | gamma_richness + n_unknown_labels (an upper bound) |
| `n_error` | Error flags on the plot’s submissions |
| `n_warning` | Warning flags |

### 5.3 The species identity rule and the diversity index

These two definitions are fixed by Biometrics (parameters and rules, not
Tech’s choice).

#### Identity

Every species record (picked from the list, or typed, or reused) is
classified into an *identified taxon* or a *provisional unknown*:

1.  Trim outer white space, collapse double spaces, turn spaces into
    underscores, capitalise the first letter. The result is the taxon
    name. `Pogonarthria fleckii` and `Pogonarthria_fleckii` are one
    taxon.
2.  `herb_104 (Justicia divaricata )` (a placeholder with a proposed
    name in brackets) is read as its proposed name,
    `Justicia_divaricata`.
3.  A bare placeholder (`herb_NNN`, `wood_NNN`, pattern
    `unknown_label_regex`), a UUID typed as text, or a record with no
    name is a **provisional unknown**. Unknowns are counted apart
    (`n_unknown_labels`, the distinct labels) and never enter
    `richness`; the tables show `richness_upper_bound` next to it.
4.  Misspellings are **not** merged (SPE-06 only suggests a correction),
    and records are counted once per taxon however many times they
    occur.

In the sample this gives 70 identified taxa and 82 provisional labels
over 2,243 records.

#### Plot diversity outliers (PLT-09)

No diversity index is stored in the summaries. PLT-09 (info, data
manager) uses Shannon’s `H` only to find odd plots. For each plot, pool
the quadrats of its submissions that were not rejected; for each
identified taxon `i` let `f_i` be the number of quadrats in which it
occurs and `p_i = f_i / sum(f)`; `H = -sum(p_i * ln(p_i))` (natural
log). There is no abundance, only presence per 1 m by 1 m quadrat. Plots
with no identified taxon have no `H`. With at least
`shannon_outlier_min_plots` plots (10), compute the median and the
scaled median absolute deviation (MAD, constant 1.4826) of `H` over the
plots; every submission of a plot with `abs(H - median) / MAD` above
`shannon_outlier_mad` (3) is flagged. No flag when the MAD is 0. On the
sample it raises 0 flags.

### 5.4 The sensitivity version

Both versions are filtered views of the same staged data, never a
repair. Exactly what is left out, recorded one row per record in
`veg_excluded_record`. Rule 1 applies to both versions (`accepted` is
every submission not rejected, in the plot and totals tables); rules 2
to 4 only to `excluding_errors`, except orphans:

1.  **A submission with `ReviewState = 'rejected'`**: the submission and
    all its quadrats and species records (reason `rejected_submission`).
    The survey table of `accepted` still lists the submission, with its
    `review_state` and its own flag counts, so it can be seen; no plot
    row, total, map colour or plot flag count includes it.
2.  **A quadrat with at least one `error` flag**: that quadrat and its
    species records, and nothing else of the submission (reason
    `error_flag_quadrat`).
3.  **An `error` flag with no quadrat (survey level)**: the whole
    submission (reason `error_flag_survey`). The sample has none.
4.  **Orphan records** (a quadrat or species row whose parent is
    missing): left out of both versions, because no summary can place
    them; reason `orphan_record`. The sample has none.

Warnings and info never exclude. The flag counts (`n_error`,
`n_warning`, `n_info`) are the same in both versions, because flags
describe what was submitted; both leave out the flags of rejected
submissions from plot counts. The flags themselves stay in `veg_flag`.
The parameter `excluded_severity` (error) names the severity that
triggers rule 2.

In the sample 2 submissions (the 2 rejected resubmissions, with their 0
quadrats) leave both versions, and 10 further quadrats with an error
flag leave `excluding_errors`. Quadrats go from 600 to 590 (surveys stay
30). Richness over all plots stays 70; the gamma richness of 4 plots
changes.

### 5.5 Sampling effort

One row per surveyed plot and version, `veg_plot_sampling_effort`. It
answers whether a plot’s quadrats have found most of the taxa the plot
holds. Tech computes four values and a status per plot from the plot’s
quadrats (identified taxa only, because unknown labels are not stable
units; accepted submissions only, as in section 5.2) and applies two
thresholds. The accumulation curves, the Chao2 interval and the gain
over the last quadrats are not on the platform; they stay in
`vegetation_report.md`.

Let `T` be the number of quadrats of the plot, `S` the observed richness
(`observed_richness`), `f_i` the number of quadrats in which taxon `i`
occurs, `U = sum(f_i)`, `Q1` the number of taxa with `f_i = 1` and `Q2`
the number with `f_i = 2`.

- **Chao2 estimate** (`estimated_richness`), the bias-corrected
  incidence estimator: `S + (T - 1) / T * Q1^2 / (2 * Q2)` when
  `Q2 > 0`, and `S + (T - 1) / T * Q1 * (Q1 - 1) / 2` when `Q2 = 0`.
- **Sample coverage** (`sample_coverage`): `1 - Q1 / U * A`, with
  `A = (T - 1) * Q1 / ((T - 1) * Q1 + 2 * Q2)` when `Q2 > 0`,
  `A = (T - 1) * (Q1 - 1) / ((T - 1) * (Q1 - 1) + 2)` when `Q2 = 0` and
  `Q1 > 0`, and `A = 0` when `Q1 = 0` (coverage 1).
- **Completeness** (`completeness`): `S / estimated_richness`.
- **Approaches an asymptote** (`approaches_asymptote`): completeness at
  least `completeness_min` (0.9) and coverage at least `coverage_min`
  (0.95). NULL when there is no estimate.
- **Status** (`estimate_status`): `ok`; `no_taxa` when the plot has no
  identified taxon (estimate, coverage and completeness NULL); `failed`
  when the estimate cannot be computed (same NULLs). Neither is an error
  of the run.

Both formulas were verified against `iNEXT::ChaoRichness` and
`iNEXT::DataInfo` (incidence raw data) on small random matrices; they
agree to the printed precision. The two thresholds are provisional
values in `veg_parameter`, Biometrics owns them (section 8), and Tech
reads them with `veg_param_num()`. A plot with fewer quadrats than
`quadrats_required` is still computed; `n_quadrats` and
`quadrats_required` sit next to the estimate so the shortfall is
visible.

In the sample, all 30 plots have 20 quadrats and 2 of them approach an
asymptote (SavMon_LW_Plot_07, SavMon_LW_Plot_26). The rest are
under-sampled for the stated thresholds, and the estimate is a lower
bound.

## 6. Dashboard views the platform must serve

The dashboard prototype `dashboard/dashboard.qmd` (Quarto, rendered to
`docs/index.html`) is a **mock-up of the content**, not a specification
of the interface: it reads the CSVs and runs no analysis. Tech serves
the tables below to the React/TypeScript front end; layout and
components are the front end’s own.

| View | Table | Columns | Filters |
|:---|:---|:---|:---|
| Headline boxes | `veg_summary_totals` | all | `version` |
| Survey-level | `veg_survey_summary` | all (section 5.1) | `version`, `plot_name`, `review_state`, `survey_date` range |
| Plot-level | `veg_plot_summary` | all (section 5.2) | `version`, `surveyed`, `plot_status` |
| Sampling effort | `veg_plot_sampling_effort` | all (section 5.5) | `version`, `approaches_asymptote`, `estimate_status` |
| Flags by severity | `veg_flag_open` | all except `flag_id` internals | `severity`, `check_id`, `plot_name`, `who_can_resolve`, `survey_date` range |
| Map layer | `veg_plot_location` | `plot_name, lon, lat, worst_severity, surveyed, plot_status, n_error, n_warning, n_info` | `worst_severity`, `surveyed` |
| Freshness | `veg_check_run` | `finished_at` of the latest `status = 'ok'` run | none |

Contract details:

- `version` defaults to `accepted`; the sensitivity version is a toggle.
  Every view that has a `version` column must show which one is on
  screen.
- The flags view counts by `severity` in the order error, warning, info
  and lists the open flags (`resolved_at IS NULL`); resolved flags can
  be shown on request.
- The map layer is coloured by `worst_severity` (error, warning, info,
  none; the colours are error = \#A50F15, warning = \#F2BC57, info =
  \#8C8C8C, none = \#7DBE98, defined in the config), with a different
  symbol for `plot_status = 'backup'` and for a plot that is registered
  but not surveyed. 1 plot of the sample has no coordinates; it stays in
  the table and is simply not drawn.
- The data are anonymised, so real coordinates and names may be shown.

The prototype’s three views, for the content only:

![Prototype: survey and plot summaries with the headline
boxes.](figures/veg_dashboard_summaries.png)

![Prototype: plot locations coloured by worst flag
severity.](figures/veg_dashboard_map.png)

![Prototype: flags table with severity, check and plot
filters.](figures/veg_dashboard_flags.png)

## 7. Triggers and runtime

- **When it runs.** After every ODK sync that brings a new or edited
  submission, a changed `ReviewState`, or a changed entity row (compare
  `SubmissionDate`, `Edits`, `ReviewState` and the entity `__updatedAt`
  with the last run), and after Biometrics inserts a catalogue or
  parameter row. A run does not need to know what changed.
- **Idempotent, full recompute.** A run rebuilds the staged tables,
  evaluates every active check and rebuilds the summaries from scratch.
  The sample has 32 surveys, 640 quadrats and 2,243 species records, so
  incremental logic would cost more than it saves. Running twice on
  unchanged data changes only `last_seen_run` and the run table. Flags
  are upserted on `flag_id`; summary tables are replaced inside the same
  transaction.
- **One transaction, one run at a time.** Take an advisory lock at the
  start (`pg_advisory_xact_lock`). If a check raises an error the whole
  run rolls back, the previous results stay visible, and `veg_check_run`
  records `status = 'failed'` with `error_message`. The dashboard shows
  the time of the last `ok` run.
- **A rejected duplicate.** A reviewer rejects one of two submissions
  for a plot in ODK. The rejected row stays in the raw and staged
  tables. It raises STR-07 (info: “rejected; the plot also has an
  accepted submission”); it is listed in the survey table but counted in
  no plot row or total, in either version. Two accepted submissions of
  one plot and survey raise STR-08 (warning); a plot whose submissions
  are all rejected raises STR-09 (error). When the reviewer later
  changes the review state, the next run follows.
- **A backup plot.** The SOP allows a backup plot when a primary one is
  not viable. It is a normal plot with `plot_status = 'backup'`:
  surveyed like any other, raises PLT-06 (info), appears in every table
  and on the map with its own symbol. The data hold no link between a
  backup and the primary it replaces, so none is checked.
- **Fixing an error upstream.** Someone corrects the submission in ODK
  Central; the next run closes the flag (`resolved_at`). Tech never
  corrects a value in the platform.

## 8. Configuration Biometrics can change without code

These values live in `veg_parameter` (and the severity per check in
`veg_check_catalogue`). They are seeded from `R/vegetation/config.R`,
which is the reference. A change is a new row with a later `valid_from`;
the next run uses it. Tech does not edit them, and the platform reads
them only through `veg_param_num()` and `veg_param_text()` (never copied
into code).

| parameter | current | meaning |
|:---|:---|:---|
| `accuracy_limit_m` | `5` | Geopoint accuracy (m) above which a point breaks the SOP (SPA-01, SPA-02); also the stand-in for a missing accuracy in the distance checks |
| `belt_length_m` | `50` | Belt transect length (m); the midpoint is the plot centre |
| `belt_width_m` | `5` | Belt transect width (m) |
| `quadrat_spacing_m` | `5` | Quadrat spacing along the transect (m) |
| `expected_quadrats_per_plot` | `20` | Quadrats required per plot (QUA-01) |
| `duration_min_minutes` | `15` | Shortest plausible survey, minutes (TIM-02) |
| `duration_max_minutes` | `180` | Longest plausible survey, minutes (TIM-02) |
| `late_submission_hours` | `12` | Submitted later than this after the form ended is info (TIM-04) |
| `start_after_submission_tolerance_s` | `60` | A start later than the submission by more than this is a clock error (TIM-03) |
| `misspelling_max_distance` | `2` | Largest edit distance for a likely misspelling (SPE-06) |
| `misspelling_max_relative` | `0.15` | Largest edit distance as a share of the name length (SPE-06) |
| `misspelling_min_genus_length` | `6` | Shortest genus for the one-letter-off genus rule (SPE-06) |
| `species_name_regex` | `^[A-Z][a-z]+(-[a-z]+)?_[a-z]+(-[a-z]+)?$` | Canonical Genus_species pattern (SPE-02) |
| `unknown_label_regex` | `^(herb\&#124;wood)_[0-9]+$` | Provisional unknown labels, e.g. herb_002 (SPE-03, identity rule) |
| `uuid_regex` | `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$` | A UUID typed as text (SPE-04, identity rule) |
| `completeness_min` | `0.9` | Smallest observed/estimated richness for a plot to approach an asymptote (section 5.5, provisional) |
| `coverage_min` | `0.95` | Smallest sample coverage for a plot to approach an asymptote (section 5.5, provisional) |
| `excluded_severity` | `error` | Severity whose flagged quadrats the sensitivity version leaves out |
| `map_epsg` | `32637` | Projected CRS for the distance checks |

Not parameters, on purpose: the severity of a check (one value per
catalogue row), the identity rule steps and the formulas of section 5,
including the effort formulas (changing them changes what the numbers
mean, so Biometrics ships a new document and a new SQL version), and the
set of review states (`approved`, `rejected`, `hasIssues`, which are ODK
Central’s).

## 9. Edge cases and failure behaviour

A state without a value is a normal state with a flag, not an error.
Only a missing file or a missing required column aborts a run.

| Case | Behaviour |
|:---|:---|
| Missing quadrat geopoint | Loads as NULL. QUA-05 (error) flags the quadrat. Distance checks skip it. |
| Missing background geopoint | NULL. SPA-03 (info) flags the survey. SPA-05 skips it. |
| Plot without geometry | `veg_plot` lat and lon NULL; distance checks skip its quadrats; kept in `veg_plot_location` with NULL coordinates. |
| Blank species count with no herbs | NULL. QUA-04 (info). Not treated as an error; summaries do not use the count. |
| Blank species count with herbs | NULL. CON-03 compares only non-blank counts; CON-02 flags a quadrat marked with herbs but no record. |
| Orphan quadrat or species row | Loads with its parent key. STR-01 or STR-02 (error). Left out of both summary versions (reason `orphan_record`). |
| Duplicate key in a lookup (a plot registered twice, a plot id twice in the plot list) | A choice made in the R reference: the staging joins are many-to-one, so the run aborts rather than let a duplicate multiply survey rows (the duplicate is already a row in `veg_key_integrity`). What the platform does instead is for Biometrics to decide, not Tech. The sample has none. |
| Survey without quadrats | QUA-01 (error); it appears in the survey summary with `n_quadrats = 0`. |
| Unknown species UUID in a quadrat | `species_name` NULL. SPE-01 (error). In the summaries it is an unnamed record, so a provisional unknown, never a taxon. |
| Reused extra-list UUID not found | SPE-10 (error); same summary treatment. |
| Species name with a stray space | SPE-05 or SPE-12 (warning). The identity rule trims it, so the taxon is still counted. |
| Declared quadrat count differs | QUA-03 (warning). |
| New form version | MET-01 (warning) flags every submission whose `FormVersion` differs from the most common one. Staging reads columns by name: a new extra column is ignored, a **missing required column aborts the run** and names the column. |
| Time zone offset | See below. |
| Timestamp that cannot be parsed | NULL. TIM-05 (error); the other time checks skip it. |
| Parameter or catalogue row missing | The run aborts (a check without its parameter is not run silently). |
| A check query returns a wrong column set | The run aborts and rolls back; nothing partial is written. |
| Run twice on the same data | No change except `last_seen_run`. |
| A flagged record is edited in ODK | Next run: `resolved_at` set, summaries follow the new data. |

### 9.1 The time zone artefact

ODK form times carry the device offset (+02:00 in every row of the
sample) while `SubmissionDate` is UTC. If staging drops the offset (for
example by casting to `timestamp` instead of `timestamptz`), 15 of the
32 surveys appear to start more than 60 s after they were submitted.
With the offset honoured it is 0, and TIM-03 raises no flag. If TIM-03
fires on many rows after a change to staging, look at the time parsing
first.

## 10. Metadata and form issues for Tech to fix upstream

These are faults in the ODK forms and entity lists, not in the analysis.
Each is also a catalogue flag, so the platform will show it until it is
fixed.

1.  **`quadrats_with_species` calculation (form).** The end-of-survey
    figure `survey_end-quadrats_with_species` counts only quadrats that
    have additional-species rows. It ignores quadrats whose species were
    all picked from the list. It equals the additional-species
    definition in 32 of 32 surveys and understates the truth in 23
    (CON-06). The SOP (section 5, step 13) tells the team to judge
    plausibility from this figure, so it misleads at the moment of
    submission. Fix the calculation to count quadrats with a picked or
    an additional species.
2.  **Trailing space in an entity label.** The extra-species entity
    `Evolvulus alsinoides` has a trailing space in its label and is
    reused 64 times (SPE-12, 19 flags). One edit in the entity list.
3.  **The typed-name field accepts anything but `,;()`.** All 45 typed
    names in the sample use a space where the SOP asks for an
    underscore, and 2 have a stray outer space. Add a form constraint
    that requires `Genus_species` (the pattern is `species_name_regex`).
4.  **`plot_selection-plot_status` is blank in every row.** The form
    stores the status in `get_plot_status`; staging uses that one.
    Populate or drop the blank column.
5.  **Two ids with similar names for different things.** Survey
    `selected_plot_uuid` equals vegplots `__id`; vegplots `plot_uuid` is
    the key to the registration form. Rename a column or document it in
    the form’s data dictionary.
6.  **Provisional labels are not linked to the names given to them.** A
    `herb_NNN` label that carries a proposed name in one record appears
    as a plain label in others. Storing the proposed name on the entity
    would let every record of the label resolve to one taxon.
7.  **Registrations uploaded after the surveys that use them** (PLT-08,
    info, 3 plots). The registration form’s end time is earlier in every
    case; the upload was late. A process reminder for the teams, not a
    platform fault.

## 11. Monitoring

### 11.1 Per batch

The numbers that tell whether a batch is healthy: flags per severity,
and the share of surveys with at least one error flag. A sudden jump
usually means a changed form, a changed export or a staging bug (for
example the time offset above), not worse fieldwork.

``` sql
-- Flags raised by the latest run, per severity
SELECT severity, count(*) AS n_flags
FROM veg_flag
WHERE last_seen_run = (SELECT max(run_id) FROM veg_check_run WHERE status = 'ok')
GROUP BY severity;

-- Share of surveys with at least one open error flag
SELECT avg((EXISTS (
           SELECT 1 FROM veg_flag_open AS f
           WHERE f.survey_key = s.survey_key AND f.severity = 'error'
       ))::int) AS share_surveys_with_error
FROM veg_survey AS s;
```

| severity | flags |
|:---------|------:|
| error    |    11 |
| warning  |   148 |
| info     |   804 |

Sample export: flags per severity

In the sample 9 of 32 surveys (28%) have at least one error flag. 706 of
the 804 info flags are provisional unknown labels, which are expected
and not a sign of poor data.

### 11.2 Per run

`veg_check_run` carries `started_at`, `finished_at`, `status`,
`error_message` and the flag counts per severity. Alert on
`status = 'failed'`, on a run with no `ok` in the last day after new
submissions arrived, and on a check whose flag count changes by more
than a few times between two runs with no change in the data.

## 12. Acceptance tests

Done means: on the sample export the runner produces exactly these flag
counts, per check and severity, and the concrete rows below behave as
stated. The counts come from `outputs/vegetation/flags.csv`. The
`flag_id` in that file is the same md5 the runner produces, so compare
on `flag_id`, or on check id, submission, quadrat and value.

### 12.1 Flag counts per check

| check  | level   | severity | expected flags |
|:-------|:--------|---------:|:---------------|
| CON-04 | quadrat |    error | 10             |
| CON-06 | survey  |  warning | 23             |
| CON-07 | species |  warning | 7              |
| MET-02 | survey  |     info | 30             |
| PLT-06 | survey  |     info | 1              |
| PLT-08 | survey  |     info | 3              |
| QUA-04 | quadrat |     info | 7              |
| SPA-02 | survey  |  warning | 1              |
| SPA-03 | survey  |     info | 3              |
| SPA-04 | quadrat |  warning | 35             |
| SPA-05 | survey  |  warning | 3              |
| SPA-06 | quadrat |     info | 51             |
| SPA-07 | quadrat |  warning | 2              |
| SPE-02 | species |  warning | 45             |
| SPE-03 | species |     info | 706            |
| SPE-05 | species |  warning | 2              |
| SPE-06 | species |  warning | 3              |
| SPE-08 | species |  warning | 6              |
| SPE-09 | species |  warning | 1              |
| SPE-11 | species |    error | 1              |
| SPE-12 | species |  warning | 19             |
| STR-07 | survey  |     info | 2              |
| TIM-02 | survey  |  warning | 1              |
| TIM-04 | survey  |     info | 1              |

Total: 963 flags: 11 error, 148 warning, 804 info. The other 35 checks
must return **zero rows** on the sample: STR-01, STR-02, STR-03, STR-04,
STR-05, STR-06, STR-08, STR-09, PLT-01, PLT-02, PLT-03, PLT-04, PLT-05,
PLT-07, PLT-09, QUA-01, QUA-02, QUA-03, QUA-05, QUA-06, CON-01, CON-02,
CON-03, CON-05, SPE-01, SPE-04, SPE-07, SPE-10, SPA-01, TIM-01, TIM-03,
TIM-05, MET-01, MET-03, MET-04.

### 12.2 Concrete rows

| Case | Input | Expected result | Origin |
|:---|:---|:---|:---|
| Additional species declared, none recorded | Quadrat 19 of SavMon_LW_Plot_21: `additional_species_present = yes`, 0 additional-species rows | CON-04, error, `value` NULL | Real |
| Form summary understates the quadrats with species | SavMon_LW_Plot_16: declared 19 quadrats with species; 20 have a record | CON-06, warning, `value` 19, `detail` 20 | Real |
| Typed name with a stray space | `typed_name = 'Justicia divaricata '` in SavMon_LW_Plot_16 | SPE-02, warning, `value` as typed | Real |
| The same name written correctly | `typed_name = 'Justicia_divaricata'` | No SPE-02 flag | Constructed |
| End-of-survey accuracy just above the limit | SavMon_LW_Plot_30: background accuracy 5.066 m | SPA-02, warning, `value` 5.066 | Real |
| Quadrat accuracy exactly at the limit | 8 quadrat fixes in the sample have accuracy 5 m | No SPA-01 flag (the rule is strictly above) | Real |
| Quadrat far outside the belt | SavMon_LW_Plot_01, Quadrat 18: 74.6 m from the midpoint, allowed 34.4 m | SPA-04, warning, `value` 74.6, `detail` 34.4 | Real |
| Distance exactly equal to the allowed distance | A quadrat 34.4 m from the midpoint with the same accuracies | No SPA-04 flag (the rule is strictly greater) | Constructed |
| Rejected resubmission | SavMon_LW_Plot_21: the submission with `ReviewState = rejected`; the accepted submission of the plot has `ReviewState` NULL | STR-07, info, on the rejected one only; the rejected one is in `veg_excluded_record` (`rejected_submission`) | Real |
| Start time with the +02:00 offset honoured | `started_at = 2026-05-27T09:41:43.843+02:00`, `submitted_at = 2026-05-27T08:46:04.721Z` | No TIM-03 flag (-3861 s). With the offset dropped it would be 3338 s and a false flag | Real, with the failure constructed |

Also test: a second run on unchanged data leaves every `flag_id` and the
flag counts unchanged and changes only `last_seen_run`; raising a
tolerance by inserting a later `veg_parameter` row changes only the
flags of the checks that read it; correcting a flagged value in a copy
of the data sets `resolved_at` on the next run; the summary totals are
30 surveys, 600 quadrats and 70 identified taxa (`accepted`), and 30
surveys and 590 quadrats (`excluding_errors`); the survey table lists 32
submissions.

### 12.3 Sampling effort

For the `accepted` version, `veg_plot_sampling_effort` must reproduce
`outputs/vegetation/sampling_effort.csv` for `n_quadrats`,
`quadrats_required`, `observed_richness`, `estimated_richness`,
`sample_coverage`, `completeness`, `approaches_asymptote` and
`estimate_status`, within rounding (the CSV also holds the interval, the
gain over the last quadrats and a note, which Tech does not compute).
The file has 30 plots, of which 2 approach an asymptote. The
`excluding_errors` rows are checked the same way against
`sampling_effort_excl_errors.csv` (30 plots). A plot with no identified
taxon gets `no_taxa` and NULLs, and changing `completeness_min` by
inserting a later `veg_parameter` row changes only
`approaches_asymptote`.

## 13. Versioning

- This document and the two SQL files are versioned in git. A schema
  change is a migration that only adds columns.
- The catalogue is versioned by row: `(check_id, version)` with
  `valid_from`; parameters by `(name, valid_from)`. Old rows stay.
- Every flag stores the `check_version` that raised it and the run that
  first and last saw it, so a flag traces back to the exact catalogue
  row, and `check_sql`, that produced it.
- The identity rule and the formulas of section 5 are versioned with
  this document.

## 14. Stack

Python 3.13, SQL on PostgreSQL, Redis and Docker Compose on Azure, ODK
Central, React 18, TypeScript and Vite, as already in use; this handoff
adds tables, a runner and data contracts, and prescribes nothing about
the deployment.
