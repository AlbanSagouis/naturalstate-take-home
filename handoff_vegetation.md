Herbaceous vegetation QA/QC: handoff to the Tech team
================
Alban Sagouis
2026-10-08

## TL;DR

- **What to build.** A job that runs after the ODK data have reached the
  platform and produces staged tables (typed and joined, nothing
  dropped), a long `veg_flag` table with one row per finding, survey and
  plot summaries, and a plot location layer for a map. The tables are in
  `sql/vegetation_schema.sql`.
- **Key result.** 59 checks (28 error, 20 warning, 11 info) are rows of
  a catalogue table; the runner only executes them. The sample export
  gives 963 flags (11 error, 103 warning, 849 info). A flag never
  changes or filters data.
- **What Tech must do.** Create the tables, load the catalogue and
  parameter rows, write the staging step and one query per catalogue row
  (56 of 59 need no geometry), rebuild flags and summaries after every
  batch, serve the dashboard tables, and fix the upstream issues in
  section 10. Done means the acceptance counts in section 12.
- **Key decision.** Tech never decides a check, a severity, a tolerance
  or the species identity rule. Biometrics inserts catalogue and
  parameter rows. There is no open scientific question in this document.
  The SQL schema and runner were not run on PostgreSQL.

## 1. Inputs and outputs

### 1.1 What arrives

The ODK data have already reached the platform; this handoff starts from
the raw tables (four ODK Central exports and four entity lists).

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

Row counts are those of the sample export. Use the platform’s own raw
table names; all that follows is keyed on the ODK `KEY` columns.

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
- **Species typed or provisional.** Species not on the list come through
  the additional-species repeat: `reuse_*` modes carry an entity UUID,
  `new_*` modes carry a name (`new_missing_canonical` is what the team
  typed).
- **Geopoints.** ODK exports four columns (`...-Latitude`, `-Longitude`,
  `-Altitude`, `-Accuracy`). The vegplots entity stores one string,
  `'lat lon alt acc'` (for example 0.2195439 37.4812757 990.8 3.6).
  Staging parses it into `lat`, `lon`, `altitude_m`, `accuracy_m`; a
  blank is NULL.
- **Timestamps.** `SubmissionDate` is UTC (`...Z`). The form times carry
  the device offset (+02:00 in the sample). Parse them as `timestamptz`
  with the offset honoured (section 9).
- **Blank means NULL.** An empty ODK cell becomes NULL; whitespace is
  never trimmed at staging, because a stray space is something the
  checks report.

### 1.3 Column mapping, raw to staged

Each raw column below is checked against the sample export headers at
build time.

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
| quadrat_repeat | `KEY` | `veg_quadrat.quadrat_key` | text |
| quadrat_repeat | `PARENT_KEY` | `veg_quadrat.survey_key` | text |
| quadrat_repeat | `quadrat_number` | `veg_quadrat.quadrat_number` | integer |
| quadrat_repeat | `herbs_present` | `veg_quadrat.herbs_present` | text |
| quadrat_repeat | `herb_species-selected_herb_species_uuids` | `veg_quadrat.selected_species_uuids and one veg_species_record row per UUID` | text |
| quadrat_repeat | `herb_species-count_herb_species` | `veg_quadrat.declared_species_count` | integer |
| quadrat_repeat | `additional_species_present` | `veg_quadrat.additional_species_present` | text |
| additional_species_repeat | `KEY` | `veg_species_record.record_id` | text |
| additional_species_repeat | `PARENT_KEY` | `veg_species_record.quadrat_key` | text |
| additional_species_repeat | `species_entry_mode` | `veg_species_record.entry_mode` | text |
| additional_species_repeat | `select_reuse_unknown` | `veg_species_record.species_uuid (this or select_reuse_missing)` | text |
| additional_species_repeat | `validated_name` | `veg_species_record.species_name` | text |
| additional_species_repeat | `new_missing_canonical` | `veg_species_record.typed_name` | text |
| register_vegetation_plots | `KEY` | `veg_registration.register_key` | text |
| register_vegetation_plots | `survey_end-end_time` | `veg_registration.ended_at` | timestamptz |

Other staged columns follow the same pattern (`-` becomes `_`).
Geopoints (the background point `survey_end-background_geopoint-*` and
the quadrat point `location_quadrat-*`) become `lat`, `lon`,
`altitude_m`, `accuracy_m` (`bg_` prefix for the background point). The
entity lists fill `veg_plot`, `veg_species`, `veg_project_team`.

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
    `veg_species_record` rows in the sample. Nothing is dropped or
    repaired. An unmatched lookup leaves the column NULL; an orphan
    keeps its parent key. Only a missing file or required column aborts
    the run.
2.  **Staged to flags.** Run every active catalogue row against the
    staged tables (section 3). Flags never filter anything.
3.  **Flags and staged to summaries.** Build the summary tables twice,
    for `accepted` and `excluding_errors` (section 5).

### 2.2 Tables

The definitions are in `sql/vegetation_schema.sql` (PostgreSQL 14 or
later): 17 tables, two parameter functions and one view. The file is the
contract and is not repeated here. It was not run on PostgreSQL in this
work, so the first step is to run it and fix any syntax error without
changing a column. Groups:

| Group | Tables |
|:---|:---|
| Staged data | `veg_plot`, `veg_species`, `veg_project_team`, `veg_registration`, `veg_survey`, `veg_quadrat`, `veg_species_record` |
| Configuration (Biometrics) | `veg_parameter`, `veg_check_catalogue`, functions `veg_param_num()` and `veg_param_text()` |
| Flags and runs | `veg_flag`, view `veg_flag_open`, `veg_check_run` |
| Summaries | `veg_survey_summary`, `veg_plot_summary`, `veg_plot_sampling_effort`, `veg_summary_totals`, `veg_plot_location`, `veg_excluded_record` |

Notes on the tables:

- The staged tables have primary keys and types but **no CHECK
  constraints on data values** and no foreign keys between data rows: a
  blank count, an orphan or an accuracy of 5.066 m must load and be
  flagged, never rejected.
- `veg_parameter` and `veg_check_catalogue` are insert-only and owned by
  Biometrics. `veg_flag`, summaries and map layer are written only by
  the runner and are rebuilt, not edited.
- STR-03 to STR-05 test key uniqueness in the raw export. If the raw
  layer enforces a primary key they never fire; they stay, because Tech
  does not remove a check.

## 3. The check catalogue

### 3.1 The catalogue is configuration

The catalogue has 59 checks in eight families by id prefix: structure
(STR), plot (PLT), quadrat completeness (QUA), consistency (CON),
species (SPE), spatial (SPA), time (TIM) and metadata (MET).
`outputs/vegetation/check_catalogue.csv` holds every column (id, level,
severity, rule, columns, SOP reference, message template, what to check,
who can resolve). It is the specification and the seed for
`veg_check_catalogue`; its `columns` is `input_columns` in the table,
because `columns` is an SQL keyword.

| level   | error | warning | info |
|:--------|------:|--------:|-----:|
| quadrat |     9 |       3 |    2 |
| species |     6 |       7 |    2 |
| survey  |    13 |      10 |    7 |

Checks by level and severity

28 checks are resolved by the field team, 23 by the data manager and 8
by Tech (typically a form or export fault).

| family | error | warning | info |
|:-------|------:|--------:|-----:|
| CON    |     4 |       3 |    0 |
| MET    |     1 |       2 |    1 |
| PLT    |     5 |       1 |    3 |
| QUA    |     4 |       1 |    1 |
| SPA    |     1 |       4 |    2 |
| SPE    |     4 |       6 |    2 |
| STR    |     7 |       1 |    1 |
| TIM    |     2 |       2 |    1 |

Checks by family (id prefix) and severity

The rule sentence of each check is not repeated here. Read it in
`outputs/vegetation/check_catalogue.csv`; the reference implementation
is `R/functions/veg_checks_*.R`.

### 3.2 How Biometrics adds or changes a check

- **Change a severity, message, action text or resolver:** insert a new
  catalogue row version (`version + 1`, later `valid_from`). New flags
  carry it; old-version flags are closed or re-raised on the next run.
- **Change a tolerance:** insert a new `veg_parameter` row (section 8).
  The queries read tolerances through `veg_param_num()` and
  `veg_param_text()`, never as literals.
- **Switch a check off:** insert a new version with `active = false`.
- **Add a check:** insert a row with a new id and a `check_sql` that
  returns the four columns `survey_key, quadrat_key, value, detail`.
  Placeholders `{plot}`, `{quadrat}`, `{value}` and `{detail}` in
  `message_template` are filled by the runner.

Tech’s part is the runner and the guard rails: `check_sql` runs as a
read-only role with a statement timeout, a result without the four
columns is rejected, and any error rolls back the whole run. Tech does
not judge whether a rule is right.

The CSV has no `check_sql`. For the first load Tech writes one query per
row from the rule, the input columns and the reference implementation
(`R/functions/veg_checks_*.R`, one function `veg_chk_<id>` per check). A
query is finished when its flag count matches section 12; after that the
text is Biometrics’ to change.

### 3.3 The runner

For each active check the runner materialises the query result into a
temporary table and upserts the findings into `veg_flag` (section 4):
`first_seen_run` is set once, `last_seen_run` on every run that raises
the finding. One `UPDATE` then sets `resolved_at` on findings of active
checks not raised in this run. The runner SQL is not supplied (a few
statements) and was not run on PostgreSQL.

### 3.4 Which checks need geometry

3 checks need a distance between two points: SPA-04, SPA-05, SPA-06. The
other 56 are plain SQL: counts, joins, comparisons, a regular
expression, a time difference.

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

Any library that follows steps 1 to 3 is acceptable (PostGIS
`ST_Transform` and `ST_Distance`, or `pyproj` then Euclidean distance).
The R reference uses `sf`; none was compared with another, so check the
three distance checks against section 12.

Five other checks are not row-level. STR-07, STR-08, STR-09, MET-01
compare a submission with the other submissions of the plot (STR-07 to
STR-09) or with the most common form version (MET-01). SPE-06 needs an
edit distance (`fuzzystrmatch`, `levenshtein()`): at most 2 edits and at
most 15% of the name length, or a genus exactly one letter off a listed
genus of at least 6 letters. SPE-06 is a suggestion for a human, never a
correction.

### 3.5 Two checks worth knowing

CON-06 compares the form’s `quadrats_with_species` with the quadrats
that have a species record of either source. The form figure is wrong
(section 10), so this is for Tech, not the field team. SPE-02 does not
trim before matching. All 45 typed names of the sample fail it, because
the form accepts a space where the SOP asks for an underscore; it is
information for Tech.

## 4. The flags table contract

- **Long format, one row per finding.** A finding is identified by
  check, submission, quadrat and value. `flag_id` is the `md5` of those
  four (NULL as empty text), so the same finding keeps its id across
  runs. The R reference builds the same md5, so compare with `flags.csv`
  on `flag_id`.
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
- **Sample:** 963 flags from 24 of the 59 checks (section 12).

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
surveyed), `veg_plot_summary`. Only submissions not rejected in ODK
count, flag counts included: a plot submitted twice with one rejection
(Plot_18 and Plot_21) has one survey and 20 quadrats, like every other
plot. Columns:

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

Fixed by Biometrics, not Tech’s choice.

#### Identity

Every species record is classified as an *identified taxon* or a
*provisional unknown*:

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
    (`n_unknown_labels`) and never enter `richness`;
    `richness_upper_bound` sits next to it.
4.  Misspellings are **not** merged (SPE-06 only suggests a correction),
    and records are counted once per taxon however many times they
    occur.

In the sample this gives 70 identified taxa and 82 provisional labels
over 2,243 records.

#### Plot diversity outliers (PLT-09)

No diversity index is stored. PLT-09 (info, data manager) uses Shannon’s
`H` only to find odd plots. Pool the quadrats of a plot’s non-rejected
submissions; for each identified taxon `i` let `f_i` be the number of
quadrats where it occurs and `p_i = f_i / sum(f)`;
`H = -sum(p_i * ln(p_i))`. There is no abundance, only presence. Plots
with no identified taxon have no `H`. With at least
`shannon_outlier_min_plots` plots (10), compute the median and the
scaled median absolute deviation (MAD, constant 1.4826) of `H` over the
plots; every submission of a plot with `abs(H - median) / MAD` above
`shannon_outlier_mad` (3) is flagged. No flag when the MAD is 0. On the
sample it raises 0 flags.

### 5.4 The sensitivity version

Both versions are filtered views of the same staged data, never a
repair. Each record left out is a row in `veg_excluded_record`. Rule 1
applies to both versions, rules 2 and 3 only to `excluding_errors`, rule
4 to both:

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

Warnings and info never exclude. Flag counts are the same in both
versions (flags describe what was submitted); plot counts leave out
flags of rejected submissions. The parameter `excluded_severity` (error)
names the severity that triggers rule 2.

In the sample 2 submissions (the 2 rejected resubmissions, with their 0
quadrats) leave both versions, and 10 further quadrats with an error
flag leave `excluding_errors`. Quadrats go from 600 to 590 (surveys stay
30). Richness over all plots stays 70; the gamma richness of 4 plots
changes.

### 5.5 Sampling effort

One row per surveyed plot and version, `veg_plot_sampling_effort`. It
answers whether a plot’s quadrats have found most of its taxa. Tech
computes four values and a status per plot from its quadrats (identified
taxa only; accepted submissions only, as in section 5.2) and applies two
thresholds. Accumulation curves, the Chao2 interval and the gain over
the last quadrats stay in `vegetation_report.md`.

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

Both formulas agree with `iNEXT::ChaoRichness` and `iNEXT::DataInfo` on
small random matrices. The two thresholds are provisional
`veg_parameter` values owned by Biometrics (section 8). A plot with
fewer quadrats than `quadrats_required` is still computed; `n_quadrats`
and `quadrats_required` sit next to the estimate.

In the sample, all 30 plots have 20 quadrats and 2 of them approach an
asymptote (SavMon_LW_Plot_07, SavMon_LW_Plot_26). The rest are
under-sampled for the stated thresholds, and the estimate is a lower
bound.

## 6. Dashboard views the platform must serve

The dashboard prototype `dashboard/dashboard.qmd` (Quarto, rendered to
`docs/index.html`) is a **mock-up of the content**, not an interface
specification: it reads the CSVs and runs no analysis. Tech serves the
tables below to the front end, which owns layout and components.

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
  incremental logic is not worth it. Running twice on unchanged data
  changes only `last_seen_run` and the run table. Flags are upserted on
  `flag_id`; summaries are replaced in the same transaction.
- **One transaction, one run at a time.** Take an advisory lock at the
  start (`pg_advisory_xact_lock`). If a check raises an error the whole
  run rolls back, the previous results stay visible, and `veg_check_run`
  records `status = 'failed'` with `error_message`. The dashboard shows
  the time of the last `ok` run.
- **A rejected duplicate.** A reviewer rejects one of two submissions
  for a plot in ODK. The rejected row stays in the raw and staged tables
  and raises STR-07 (info); it is listed in the survey table but counted
  in no plot row or total, in either version. Two accepted submissions
  of one plot raise STR-08 (warning); a plot whose submissions are all
  rejected raises STR-09 (error). A later change of review state is
  followed by the next run.
- **A backup plot.** A normal plot with `plot_status = 'backup'`:
  surveyed like any other, raises PLT-06 (info), has its own map symbol.
  The data hold no link to the primary it replaces, so none is checked.
- **Fixing an error upstream.** Someone corrects the submission in ODK
  Central; the next run sets `resolved_at`. Tech never corrects a value
  in the platform.

## 8. Configuration Biometrics can change without code

These values live in `veg_parameter`, seeded from
`R/vegetation/config.R` (the reference). A change is a new row with a
later `valid_from`; the next run uses it. Tech does not edit them, and
code reads them only through `veg_param_num()` and `veg_param_text()`.

| parameter | current | meaning |
|:---|:---|:---|
| `accuracy_limit_m` | `5` | Accuracy (m) above which a geopoint breaks the SOP (SPA-01, SPA-02); stand-in for a missing accuracy in distance checks |
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

Not parameters, on purpose: check severity (a catalogue column), the
identity rule and the formulas of section 5 (changing them changes what
the numbers mean, so Biometrics ships a new document and SQL version),
and the review states (`approved`, `rejected`, `hasIssues`, which are
ODK Central’s).

## 9. Edge cases and failure behaviour

A state without a value is a normal state with a flag, not an error.
Only a missing file or required column aborts a run. Repeat runs and ODK
edits are covered in sections 4 and 7; the time zone case is below.

| Case | Behaviour |
|:---|:---|
| Missing quadrat geopoint | Loads as NULL. QUA-05 (error) flags the quadrat. Distance checks skip it. |
| Missing background geopoint | NULL. SPA-03 (info) flags the survey. SPA-05 skips it. |
| Plot without geometry | `veg_plot` lat and lon NULL; distance checks skip its quadrats; kept in `veg_plot_location` with NULL coordinates. |
| Blank species count | NULL. QUA-04 (info) if no herbs; CON-03 compares only non-blank counts; CON-02 flags herbs marked but no record. Summaries do not use the count. |
| Orphan quadrat or species row | Loads with its parent key. STR-01 or STR-02 (error). Left out of both summary versions (reason `orphan_record`). |
| Duplicate key in a lookup (a plot registered twice, a plot id twice in the plot list) | A choice made in the R reference: the staging joins are many-to-one, so the run aborts rather than let a duplicate multiply survey rows (the duplicate is already a row in `veg_key_integrity`). What the platform does instead is for Biometrics to decide, not Tech. The sample has none. |
| Survey without quadrats | QUA-01 (error); it appears in the survey summary with `n_quadrats = 0`. |
| Unknown species UUID in a quadrat | `species_name` NULL. SPE-01 (error). In the summaries it is an unnamed record, so a provisional unknown, never a taxon. |
| Reused extra-list UUID not found | SPE-10 (error); same summary treatment. |
| Species name with a stray space | SPE-05 or SPE-12 (warning); the identity rule trims it. |
| New form version | MET-01 (warning) flags every submission whose `FormVersion` differs from the most common one. Staging reads columns by name: a new extra column is ignored, a **missing required column aborts the run** and names the column. |
| Timestamp that cannot be parsed | NULL. TIM-05 (error); the other time checks skip it. |
| Parameter or catalogue row missing | The run aborts (a check without its parameter is not run silently). |
| A check query returns a wrong column set | The run aborts and rolls back; nothing partial is written. |

### 9.1 The time zone artefact

ODK form times carry the device offset (+02:00 in every row of the
sample) while `SubmissionDate` is UTC. If staging drops the offset (for
example by casting to `timestamp` instead of `timestamptz`), 15 of the
32 surveys appear to start more than 60 s after they were submitted.
With the offset honoured it is 0, and TIM-03 raises no flag. If TIM-03
fires on many rows after a staging change, check the time parsing first.

## 10. Metadata and form issues for Tech to fix upstream

These are faults in the ODK forms and entity lists, not in the analysis.
Each is also a catalogue flag, shown until fixed.

1.  **`quadrats_with_species` calculation (form).**
    `survey_end-quadrats_with_species` counts only quadrats with
    additional-species rows and ignores quadrats whose species were all
    picked from the list. It equals the additional-species definition in
    32 of 32 surveys and understates the truth in 23 (CON-06). The SOP
    (section 5, step 13) tells the team to judge plausibility from it.
    Count quadrats with a picked or an additional species.
2.  **Trailing space in an entity label.** The extra-species entity
    `Evolvulus alsinoides` has one and is reused 64 times (SPE-12, 19
    flags). One edit in the entity list.
3.  **The typed-name field accepts anything but `,;()`.** All 45 typed
    names use a space where the SOP asks for an underscore, and 2 have a
    stray outer space. Add a constraint requiring `Genus_species`
    (pattern `species_name_regex`).
4.  **`plot_selection-plot_status` is blank in every row.** Staging uses
    `get_plot_status`. Populate or drop the blank column.
5.  **Two similar ids for different things.** Survey
    `selected_plot_uuid` equals vegplots `__id`; vegplots `plot_uuid`
    keys the registration form. Rename or document.
6.  **Provisional labels are not linked to the names given to them.** A
    `herb_NNN` label with a proposed name in one record is a plain label
    in others. Storing the proposed name on the entity would resolve
    every record of the label to one taxon.
7.  **Registrations uploaded after the surveys that use them** (PLT-08,
    info, 3 plots). A process reminder for the teams, not a platform
    fault.

## 11. Monitoring

### 11.1 Per batch

Healthy batch: flags per severity and the share of surveys with an error
flag. A sudden jump usually means a changed form, export or staging bug
(such as the time offset), not worse fieldwork.

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
| warning  |   103 |
| info     |   849 |

Sample export: flags per severity

In the sample 9 of 32 surveys (28%) have at least one error flag. 706 of
the 849 info flags are provisional unknown labels, which are expected
and not a sign of poor data.

### 11.2 Per run

`veg_check_run` carries `started_at`, `finished_at`, `status`,
`error_message` and the flag counts per severity. Alert on
`status = 'failed'`, on a run with no `ok` in the last day after new
submissions arrived, and on a check whose flag count changes by more
than a few times between two runs with no change in the data.

## 12. Acceptance tests

Done means: on the sample export the runner produces exactly these flag
counts per check and severity (from `outputs/vegetation/flags.csv`,
compared on `flag_id`) and the concrete rows below behave as stated.

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
| SPE-02 | species |     info | 45             |
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

Total: 963 flags: 11 error, 103 warning, 849 info. The other 35 checks
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
| Typed name with a stray space | `typed_name = 'Justicia divaricata '` in SavMon_LW_Plot_16 | SPE-02, info, `value` as typed | Real |
| The same name written correctly | `typed_name = 'Justicia_divaricata'` | No SPE-02 flag | Constructed |
| End-of-survey accuracy just above the limit | SavMon_LW_Plot_30: background accuracy 5.066 m | SPA-02, warning, `value` 5.066 | Real |
| Quadrat accuracy exactly at the limit | 8 quadrat fixes in the sample have accuracy 5 m | No SPA-01 flag (the rule is strictly above) | Real |
| Quadrat far outside the belt | SavMon_LW_Plot_01, Quadrat 18: 74.6 m from the midpoint, allowed 34.4 m | SPA-04, warning, `value` 74.6, `detail` 34.4 | Real |
| Distance exactly equal to the allowed distance | A quadrat 34.4 m from the midpoint with the same accuracies | No SPA-04 flag (the rule is strictly greater) | Constructed |
| Rejected resubmission | SavMon_LW_Plot_21: the submission with `ReviewState = rejected`; the accepted submission of the plot has `ReviewState` NULL | STR-07, info, on the rejected one only; the rejected one is in `veg_excluded_record` (`rejected_submission`) | Real |
| Start time with the +02:00 offset honoured | `started_at = 2026-05-27T09:41:43.843+02:00`, `submitted_at = 2026-05-27T08:46:04.721Z` | No TIM-03 flag (-3861 s). With the offset dropped it would be 3338 s and a false flag | Real, with the failure constructed |

Also test: a second run on unchanged data changes only `last_seen_run`;
inserting a later `veg_parameter` row changes only the flags of checks
that read it; correcting a flagged value in a copy of the data sets
`resolved_at`; the summary totals are 30 surveys, 600 quadrats and 70
identified taxa (`accepted`), and 30 surveys and 590 quadrats
(`excluding_errors`); the survey table lists 32 submissions.

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

- This document and the SQL files are versioned in git. A schema change
  only adds columns.
- The catalogue is versioned by row: `(check_id, version)` with
  `valid_from`; parameters by `(name, valid_from)`. Old rows stay.
- Every flag stores its `check_version` and first and last run, so it
  traces back to the catalogue row and `check_sql` that produced it.
- The identity rule and the formulas of section 5 are versioned with
  this document.

## 14. Stack

Python 3.13, SQL on PostgreSQL, Redis and Docker Compose on Azure, ODK
Central, React 18, TypeScript and Vite, as already in use; this handoff
adds tables, a runner and data contracts, and prescribes nothing about
the deployment.
