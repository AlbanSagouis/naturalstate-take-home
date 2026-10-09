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
