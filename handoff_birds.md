BirdNET observations: handoff to the Tech team
================
Alban Sagouis
2026-10-08

## TL;DR

- **What to build.** A labelling step that runs after the ML predictions
  are stored: it joins every prediction to a thresholds table and writes
  one row per prediction to an observations table. It is one SQL
  statement (`sql/birds_label_observations.sql`) and four tables
  (`sql/birds_schema.sql`). No statistics run at runtime.
- **The key rule.** `confidence >= cutoff` gives `observed`, a smaller
  confidence gives `below_threshold`, and a missing cutoff or missing
  thresholds row gives `no_threshold`. `observation` holds the species
  name only when the status is `observed`. In the current data 3,147 of
  29,491 predictions are observed.
- **What Tech must do.** Create the tables, run the statement after
  every upload, store the metadata listed below with every prediction,
  make the validation export carry the prediction id (data-issue \#5),
  and expose the monitoring numbers.
- **What is not Tech’s decision.** Thresholds. Biometrics inserts rows
  into the thresholds table; Tech reads them and never edits one. 3 of 4
  species currently have no threshold, which is a normal state the
  pipeline handles, not an error.

## Inputs and outputs

### Inputs

- `birdnet_predictions`: one row per BirdNET detection, written by the
  existing ML pipeline. The current file has 29,491 rows for 4 species
  and the columns selection, view, channel, begin_time_s, end_time_s,
  low_freq_hz, high_freq_hz, common_name, species_code, confidence,
  begin_path, file_offset_s, folder.
- `birdnet_thresholds`: one row per species, BirdNET version and
  settings, written by Biometrics. Today 1 row holds a fitted threshold
  and 3 rows hold none.
- `birdnet_validations`: expert verdicts on predictions. Used offline by
  Biometrics for refits; Tech only stores them.

### Outputs

- `birdnet_observations`: one row per prediction with
  `observation_status`, `observation`, the `threshold_id` used and a
  reason when there is no label.

The table definitions are in the next section and in
`sql/birds_schema.sql`.

## The labelling contract

### How observations are derived from predictions

A prediction is a detection with a BirdNET confidence. It becomes an
observation only if its confidence reaches the cutoff for that species,
the BirdNET version and the settings that produced it. The cutoff is the
confidence at which the validated clips of that species reach 99%
precision. Biometrics estimates it offline; at runtime it is just a
number in a table.

The rule is applied in this order, and the first line that matches
decides:

1.  No thresholds row matches the prediction’s species, BirdNET version
    and settings, or the matching row has `cutoff` NULL:
    `observation_status = 'no_threshold'`.
2.  `confidence >= cutoff`: `observation_status = 'observed'`.
3.  Otherwise: `observation_status = 'below_threshold'`.

### The three statuses

| `observation_status` | Fixed meaning | `observation` |
|:---|:---|:---|
| `observed` | The species is recorded as present at this time and place. | Species common name |
| `below_threshold` | A cutoff exists and the confidence is under it. Not an observation. | NULL |
| `no_threshold` | No cutoff exists for this species, version and settings. Not an observation, not a rejection. | NULL |

Thresholds rows have a `status` of either `fitted threshold` (cutoff
present) or `no_threshold` (cutoff NULL, with a `reason`). Tech does not
interpret the reason; it copies it to `status_reason` in the
observations table.

### Worked example

Real rows from the current data, labelled with the real cutoff for
Abyssinian Nightjar (abynig1): 0.6666.

| prediction_key | species_code | confidence | cutoff | observation_status | observation |
|:---|:---|---:|---:|:---|:---|
| Grid2/RBS14/RBS14_20230702_230000.WAV\|675\|abynig1 | abynig1 | 0.6665 | 0.6666 | below_threshold | NULL |
| Grid2/RBS14/RBS14_20230703_040000.WAV\|3032\|abynig1 | abynig1 | 0.6668 | 0.6666 | observed | Abyssinian Nightjar |
| Grid2/RBS15/RBS15_20230628_190000.WAV\|1095\|abynig1 | abynig1 | 1.0000 | 0.6666 | observed | Abyssinian Nightjar |
| Grid2/RBS02/RBS02_20230705_070000.WAV\|1457\|abhori1 | abhori1 | 0.9985 | none | no_threshold | NULL |
| Grid2/RBS57/RBS57_20230628_070000.WAV\|351\|rebfir2 | rebfir2 | 0.9073 | none | no_threshold | NULL |
| Grid2/RBS75/RBS75_20230707_110000.WAV\|2831\|thbplo1 | thbplo1 | 0.9997 | none | no_threshold | NULL |

Rows 1 and 2 are the nightjar predictions closest to the cutoff on
either side. Row 3 is the highest nightjar confidence, which is exactly
1: no logit is computed at runtime, so 1.0 needs no special handling.
The remaining rows are each other species’ highest-confidence
prediction. They still get `no_threshold`, however confident BirdNET is,
because no threshold has been established for them.

## Tables

### Schema

The definitions are in `sql/birds_schema.sql` (PostgreSQL 14 or later)
and reproduced here.

``` sql
-- BirdNET handoff (#6): tables for predictions, validations, thresholds and observations.
-- Target: PostgreSQL 14 or later. Run once; the labelling step is sql/birds_label_observations.sql.

CREATE TABLE birdnet_predictions (
    -- Stable id assigned by the ML pipeline: the same clip prediction must always get the
    -- same id, so reruns and re-ingests never duplicate it.
    prediction_id    text PRIMARY KEY,
    recording_id     text NOT NULL,
    species_code     text NOT NULL,
    common_name      text NOT NULL,
    confidence       double precision NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    begin_time_s     double precision NOT NULL,
    end_time_s       double precision NOT NULL,
    -- Metadata stored with every prediction (see the handoff for why)
    project_id       text NOT NULL,
    site_id          text NOT NULL,
    habitat          text,
    device_id        text NOT NULL,
    recorder_model   text,
    sample_rate_hz   integer,
    recorded_at      timestamptz NOT NULL,
    birdnet_version  text NOT NULL,
    -- All BirdNET settings in one object, e.g. {"sensitivity": ..., "overlap": ...}.
    -- Written with the same keys as in birdnet_thresholds.settings, because the
    -- labelling join compares the two objects for equality.
    birdnet_settings jsonb NOT NULL,
    ingested_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX birdnet_predictions_lookup_idx
    ON birdnet_predictions (species_code, birdnet_version);

CREATE TABLE birdnet_validations (
    validation_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- One expert verdict per prediction. Late validations simply arrive later.
    prediction_id  text NOT NULL UNIQUE REFERENCES birdnet_predictions (prediction_id),
    outcome        smallint NOT NULL CHECK (outcome IN (0, 1)),  -- 1 = right, 0 = wrong
    validated_at   timestamptz NOT NULL DEFAULT now()
);

-- Written by Biometrics only (INSERT). Tech's role gets SELECT, never UPDATE or DELETE.
-- A refit adds new rows with a later valid_from; old rows stay, so every label stays
-- traceable to the row that produced it.
CREATE TABLE birdnet_thresholds (
    threshold_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    species_code       text NOT NULL,
    birdnet_version    text NOT NULL,
    settings           jsonb NOT NULL,
    b0                 double precision,           -- fitted intercept
    b1                 double precision,           -- fitted slope on the logit of the score
    threshold_estimate double precision,           -- model estimate, kept even when no_threshold
    cutoff             double precision CHECK (cutoff > 0 AND cutoff <= 1),
    ci_low             double precision,           -- bootstrap interval, reported only
    ci_high            double precision,
    n_negative         integer NOT NULL,           -- validated clips that were wrong
    n_positive         integer NOT NULL,           -- validated clips that were right
    smaller_group      integer NOT NULL,
    in_range           boolean NOT NULL,
    boot_share_failed  double precision,
    status             text NOT NULL CHECK (status IN ('fitted threshold', 'no_threshold')),
    reason             text,                       -- why there is no threshold; NULL if fitted
    fitted_at          timestamptz NOT NULL,
    valid_from         timestamptz NOT NULL,
    UNIQUE (species_code, birdnet_version, settings, valid_from),
    -- A cutoff exists exactly when the status says a threshold was fitted
    CHECK ((status = 'fitted threshold') = (cutoff IS NOT NULL))
);

-- The labelling output. One row per prediction; threshold_id records the thresholds row
-- used (NULL when no row matched the species, BirdNET version and settings).
CREATE TABLE birdnet_observations (
    prediction_id      text PRIMARY KEY REFERENCES birdnet_predictions (prediction_id),
    threshold_id       bigint REFERENCES birdnet_thresholds (threshold_id),
    observation_status text NOT NULL
        CHECK (observation_status IN ('observed', 'below_threshold', 'no_threshold')),
    -- Species name for observed, NULL otherwise
    observation        text,
    status_reason      text,
    labelled_at        timestamptz NOT NULL DEFAULT now(),
    CHECK ((observation_status = 'observed') = (observation IS NOT NULL))
);
CREATE INDEX birdnet_observations_threshold_idx ON birdnet_observations (threshold_id);
```

### Notes on the tables

- `prediction_id` must be assigned by the ML pipeline and must be the
  same on every re-ingest of the same detection. In the current file,
  recording path + start time + species code is a unique key (0
  duplicates in 29,491 rows) and can seed it.
- `birdnet_thresholds` is insert-only for Biometrics. A refit adds rows;
  it never changes old ones. The check constraint ties `cutoff` to
  `status` so a row cannot say “fitted” without a number.
- `settings` and `birdnet_settings` are compared for equality, so both
  must be written with the same keys by the same code.

## The runtime labelling step

`sql/birds_label_observations.sql` is one
`INSERT ... SELECT ... ON CONFLICT` statement.

``` sql
-- BirdNET handoff (#6): runtime labelling step. A join and a comparison, no statistics.
-- Safe to rerun at any time: prediction_id is the primary key of birdnet_observations,
-- so a rerun with unchanged thresholds changes nothing, and after Biometrics inserts a new
-- thresholds row the rerun relabels exactly the predictions whose threshold row changed.
-- To label only a new batch, add a predicate on p (for example p.ingested_at > ...).

INSERT INTO birdnet_observations
    (prediction_id, threshold_id, observation_status, observation, status_reason, labelled_at)
WITH ranked AS (
    -- The current row per species, BirdNET version and settings: the latest valid_from
    -- that has already started.
    SELECT t.*,
           ROW_NUMBER() OVER (
               PARTITION BY t.species_code, t.birdnet_version, t.settings
               ORDER BY t.valid_from DESC, t.threshold_id DESC
           ) AS recency
    FROM birdnet_thresholds AS t
    WHERE t.valid_from <= now()
),
current_thresholds AS (
    SELECT * FROM ranked WHERE recency = 1
)
SELECT p.prediction_id,
       c.threshold_id,
       CASE
           WHEN c.cutoff IS NULL THEN 'no_threshold'
           WHEN p.confidence >= c.cutoff THEN 'observed'
           ELSE 'below_threshold'
       END,
       CASE
           WHEN c.cutoff IS NOT NULL AND p.confidence >= c.cutoff THEN p.common_name
       END,
       CASE
           WHEN c.threshold_id IS NULL
               THEN 'no thresholds row for this species, BirdNET version and settings'
           WHEN c.cutoff IS NULL THEN c.reason
       END,
       now()
FROM birdnet_predictions AS p
LEFT JOIN current_thresholds AS c
       ON c.species_code = p.species_code
      AND c.birdnet_version = p.birdnet_version
      AND c.settings = p.birdnet_settings
WHERE TRUE
ON CONFLICT (prediction_id) DO UPDATE
SET threshold_id       = EXCLUDED.threshold_id,
    observation_status = EXCLUDED.observation_status,
    observation        = EXCLUDED.observation,
    status_reason      = EXCLUDED.status_reason,
    labelled_at        = EXCLUDED.labelled_at
WHERE birdnet_observations.threshold_id IS DISTINCT FROM EXCLUDED.threshold_id;
```

- It picks the current thresholds row per species, BirdNET version and
  settings: the latest `valid_from` that has already started.
- It is idempotent. `prediction_id` is the primary key of
  `birdnet_observations`, so a rerun with unchanged thresholds updates
  nothing (the `WHERE` on the conflict clause skips rows whose
  `threshold_id` is unchanged).
- After Biometrics inserts a new thresholds row, the next run relabels
  exactly the predictions whose row changed and stamps the new
  `threshold_id`. Run it after every upload and after every refit; no
  other trigger is needed.
- It contains no statistics and no logit. Run it in one transaction.

## Refitting

Thresholds are refitted offline by Biometrics, never by the platform. A
refit is triggered by new validations or by a new BirdNET version
(current validations are from BirdNET v2.4), is versioned by BirdNET
version and settings, and ends with Biometrics inserting rows into
`birdnet_thresholds`. Tech does nothing for a refit except rerun the
labelling statement; the table never has rows edited or deleted by Tech.

## Configuration Biometrics can change without code

These values live in `R/birds/config.R`, are used only by the offline
refit and are never read at runtime. Changing one produces new
thresholds rows, not a code change on the platform.

| value | current | meaning |
|:---|---:|:---|
| target_precision | 0.99 | Precision the cutoff must reach on the validated clips |
| min_smaller_group | 30.00 | Fewest clips the smaller outcome group (right or wrong) may have for a fit |
| n_boot | 2000.00 | Bootstrap resamples for the interval and failure share |
| ci_level | 0.95 | Level of the reported interval (`ci_low`, `ci_high`) |

The range gate (the fitted threshold must lie inside the validated score
range) is applied to every species on every refit and has no switch; its
result is the `in_range` column.

## Edge cases and failure behaviour

| Case | Behaviour |
|:---|:---|
| Species with no thresholds row | `no_threshold`, `threshold_id` NULL, reason says no row matches. Not an error. |
| Matching row with `cutoff` NULL | `no_threshold`, `threshold_id` of that row, its `reason` copied. |
| Confidence exactly 1.0 | Compared like any other value. No logit at runtime, so nothing can overflow. |
| Confidence equals the cutoff | `observed` (the rule is `>=`). |
| New BirdNET version or different settings | No row matches, so `no_threshold` with a reason. Labels return when Biometrics inserts rows for the new version. |
| The statement is run twice | No change. |
| Same detection ingested twice | The primary key on `prediction_id` rejects the duplicate; the ML pipeline should use `ON CONFLICT DO NOTHING`. |
| Validation arrives late | It is stored and used at the next refit. Labels change only when a new thresholds row is inserted. |
| Row with confidence outside 0 to 1 | Rejected by the check constraint on insert. Fix at the source. |

## Metadata to store with every prediction

Store device, recorder model, sample rate, BirdNET version and settings
(including sensitivity and overlap), site, habitat and datetime, so that
Biometrics can check at refit time whether a threshold holds across
recorders, sites and times, which cannot be recovered afterwards. Tech
only stores and exposes these fields; the analysis is not Tech’s. The
columns are in `birdnet_predictions`.

## Monitoring

### Per batch

The share of predictions labelled `observed`, per species and batch. A
sudden change usually means a new BirdNET version or settings (all
`no_threshold`) or a broken upload.

``` sql
SELECT p.project_id,
       p.ingested_at::date AS batch_date,
       p.species_code,
       count(*) AS n_predictions,
       avg((o.observation_status = 'observed')::int) AS share_observed,
       avg((o.observation_status = 'no_threshold')::int) AS share_no_threshold
FROM birdnet_observations AS o
JOIN birdnet_predictions AS p USING (prediction_id)
GROUP BY p.project_id, p.ingested_at::date, p.species_code;
```

Current values in the example data:

| species_code | status           | n_predictions | observed | share_observed |
|:-------------|:-----------------|--------------:|---------:|---------------:|
| abynig1      | fitted threshold |         10187 |     3147 |            31% |
| abhori1      | no_threshold     |         18054 |        0 |             0% |
| rebfir2      | no_threshold     |           235 |        0 |             0% |
| thbplo1      | no_threshold     |          1015 |        0 |             0% |

### Refit monitoring

A Biometrics dashboard reads the diagnostic columns of
`birdnet_thresholds`: `n_negative`, `n_positive`, `smaller_group`,
`in_range`, `boot_share_failed`, `ci_low`, `ci_high`, `status` and
`reason`. Tech exposes the table to the dashboard; nothing else is
needed.

## Upstream data issue

Validations cannot be linked reliably to predictions today. The
validation export must carry the prediction id (or the clip start
position), a recording id shared with the predictions, and
full-precision scores. Details and the evidence are in data-issue \#5.
This blocks `birdnet_validations.prediction_id`, so it matters for
refits, not for runtime labelling.

## Acceptance tests

Each row is an input prediction and its expected output, derived from
the real data and the real Abyssinian Nightjar cutoff
(0.66663805871385351). Run with one thresholds row for the nightjar
(`fitted threshold`, `birdnet_version` fixed, settings fixed) plus the
rows for the other species in the table below.

| n | case | species_code | confidence | expected_status | expected_observation | expected_threshold | expected_reason |
|---:|:---|:---|---:|:---|:---|:---|:---|
| 1 | Real nightjar, just below the cutoff | abynig1 | 0.6665 | below_threshold | NULL | nightjar row | NULL |
| 2 | Real nightjar, just above the cutoff | abynig1 | 0.6668 | observed | Abyssinian Nightjar | nightjar row | NULL |
| 3 | Nightjar, confidence equal to the cutoff (constructed) | abynig1 | 0.66663805871385351 | observed | Abyssinian Nightjar | nightjar row | NULL |
| 4 | Real nightjar, confidence 1.0 | abynig1 | 1 | observed | Abyssinian Nightjar | nightjar row | NULL |
| 5 | Real African Black-headed Oriole prediction, no threshold | abhori1 | 0.9985 | no_threshold | NULL | that species’ row | single outcome class, no fit |
| 6 | Real Red-billed Firefinch prediction, no threshold | rebfir2 | 0.9073 | no_threshold | NULL | that species’ row | smaller group has 6 clips, minimum 30; fitted threshold 0.998 is above the highest validated score 0.907 |
| 7 | Real Three-banded Plover prediction, no threshold | thbplo1 | 0.9997 | no_threshold | NULL | that species’ row | smaller group has 1 clips, minimum 30 |
| 8 | Nightjar from an unseen BirdNET version (constructed) | abynig1 | 1 | no_threshold | NULL | NULL | no thresholds row for this species, BirdNET version and settings |

Also test: running the statement twice leaves `labelled_at` unchanged on
every row; inserting a later `valid_from` row for the nightjar relabels
only nightjar predictions and changes their `threshold_id`; a row with
confidence 1.5 is rejected on insert.

## Versioning

- This document and both SQL files are versioned in git; a schema change
  is a migration that only adds columns.
- Thresholds are versioned by their rows: `birdnet_version`, `settings`,
  `fitted_at` and `valid_from`. Old rows stay.
- Every observation stores the `threshold_id` it was labelled with, so
  any label can be traced to the exact row and the statement that
  produced it.

## Stack

Python 3.13, PostgreSQL, Redis and Docker Compose on Azure, as already
in use; this handoff adds tables and one SQL statement and prescribes
nothing about the deployment.
