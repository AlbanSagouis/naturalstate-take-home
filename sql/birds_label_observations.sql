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
