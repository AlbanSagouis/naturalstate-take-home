Rulebook: birds
===============

Running log of analytical decisions: the judgement calls that would otherwise live only in code
or in my head. Write each one down the day it is made, with the topic, the decision, and why.
Each decision is also added as a comment on its GitHub issue.

# Bird thresholds

- **No threshold for species without enough validation evidence**: oriole (0 wrong clips), plover
  (1 wrong clip) and firefinch (fitted threshold 0.998 is above every validated score, max 0.907)
  get `no_threshold`. *(#3)* Every species goes through the same process; a species that cannot
  support a fit gets `no_threshold` and a request to Biometrics for more validation, not a
  special-case threshold. The plain glm gives plover 0.259 from a single wrong clip, which is not
  evidence. The request is for expert validation of randomly drawn clips covering more areas, time
  periods and recorders, to capture the variation in each species' calls.

- **Eligibility for a fitted threshold has two separate questions**: (1) do the data allow a
  threshold, (2) does it generalise. *(#3)* Only (1) decides whether a species gets a threshold;
  (2) is the recorder and environment sensitivity analysis and is reported as stated scope. For
  (1) there are two gates: the fitted threshold lies inside the validated score range, and the
  smaller of the two outcome groups (wrong or right clips) has at least 30 clips. The value 30 is
  deliberately safe, set in config, and may be relaxed if the cost of expert validation time makes
  it unreasonable. Applied identically to every species. Today only nightjar qualifies (smaller
  group 33; firefinch 6, plover 1, oriole 0).

- **Stability under bootstrap resampling is reported, not a gate**: the bootstrap redraws the
  validated clips with replacement, as many as the original sample, and refits the curve 2,000
  times. For each species we report the share of bootstrap fits that fail (nightjar 0%, firefinch
  14%, plover 37%, oriole 100%) and the interval of the bootstrapped thresholds. *(#3)* Today the
  count and range gates already give the same answer, so a third gate would add a number to defend
  and no new result. The numbers are kept because this is built for the future: when new
  validations arrive and thresholds are refitted, the same table (count, range, failure share,
  interval, calibration, device and hour checks) can feed a monitoring dashboard for the senior
  data scientist and Biometrics, who can see at a glance whether a refit is trustworthy.

- **AIC was explored, not used to choose a model**: we publish one model, the logit-scale logistic
  regression used by Wood & Kahl, for every species. *(#3)* AIC was computed for the null,
  confidence-scale and logit-scale models as in their tutorial (nightjar: score matters, delta AIC
  81 vs null, confidence and logit tied; firefinch: score barely helps, delta 2.3; plover: not
  meaningful with one wrong clip). It compares models, it does not show a threshold is reliable,
  so reliability rests on the minimum count, the range check and the stability of the bootstrap
  fits.

- **One method and one precision target for every species**: no species gets a stricter or looser
  cutoff than the method gives. *(#3)* More certainty is available (more validation, a more
  cautious cutoff), but it costs expert time and cannot reasonably be afforded for every species.
  A stricter cutoff for some species would lower their counts for reasons unrelated to biology and
  distort relative abundances across species. Limit to state: a common precision target does not
  equalise recall across species (Wood & Kahl note this and say recall may matter more for
  between-species comparisons).

- **Labelling cutoff is the point estimate; the uncertainty is reported, not acted on**:
  predictions at or above the fitted 99% score are labelled `observed`. *(#3)* This is the Wood &
  Kahl recipe and what the brief describes. The 95% interval from bootstrapping the validated
  clips (nightjar: 0.43 to 0.83) is stored and reported next to the threshold so the reader sees
  how uncertain it is, but there is no second, more cautious labelling cutoff: it would apply to
  one species and add a switch for Tech to build. The wide interval is part of the case for more
  validation.

- **Nightjar is labelled for all hours, with its evidence scope stated**: all 33 wrong clips are
  from hours 16-23 and the 43 clips from hours 0-6 are all correct. *(#3)* Night looks cleaner, so
  applying the evening-based threshold at night errs on the safe side, though that is unverified.
  The report asks for random nightjar clips at night to test it.

- **Confidence of exactly 1.0**: clamped (to 0.9999) before the logit. *(decided at setup)*
  qlogis(1) is infinite, and Wood & Kahl's code does not handle it.

# Robustness and environmental effects

- **Do thresholds transfer across recorders, times and places?** Investigating whether a species
  threshold belongs to the species or to the conditions it was validated under, I made a
  recorder-level sensitivity analysis a routine step, not an optional extra. *(#3)* Wood & Kahl
  warn that thresholds only hold for the conditions sampled, but their tutorial does not run the
  check. The check uses device, date and hour recovered from the recording names (recorder model
  and sample rate are not in the data). Finding: 29 of 33 nightjar wrong clips sit on two devices
  (RBS79, RBS75) and all 33 are at hours 16-23, while all 43 clips from hours 0-6 are right, so
  device, time of day and score cannot be separated in this sample. Dropping any one device (a
  leave-one-out, or jackknife, check at recorder level) leaves the nightjar threshold at 0.60-0.70
  (full data 0.667), and a device-level bootstrap (0.44-0.82) matches the clip-level one, so the
  number is stable but its scope is not established: it is estimated mostly from evening clips.

- **Why the two robustness figures are drawn**: the device figure asks whether the pooled
  threshold hides a recorder effect (Wood & Kahl: thresholds only hold for the conditions
  validated). *(#3)* For nightjar the wrong clips come almost only from two recorders that have no
  right clips, so recorder and score cannot be separated. Firefinch is the comparison: its wrong
  clips are spread over 22 recorders (the top two hold about a third), so no recorder dominates.
  The calibration figure is a model check: it compares the share the experts found correct with
  what the fitted curve predicts, band by band, and shows how many clips each band holds.

- **Metadata that the Tech team must store with every prediction**: device, recorder model, sample
  rate, BirdNET version and settings (sensitivity, overlap), site, habitat, datetime. *(#5)* Tech
  only stores and exposes it. The recorder and environment sensitivity analysis would be
  Biometrics and the senior data scientist's job: it runs at project level on every refit (one
  recorder per SD card, so the comparison is across devices within a project).

# Observation labelling

- **The nightjar evidence scope is stated in the report only, not as a column in the labelled
  file**: the labelled predictions carry `observation` and `observation_status` and nothing about
  scope. *(#4)* The caveat (validated on evening clips only) is the same for every nightjar row,
  so a column would add bulk without information per row and something for Tech to carry; the
  report states it once, where it is explained.

- **Species below threshold or without one**: `observation` is NA and `observation_status` says
  why (observed / below_threshold / no_threshold). *(decided at setup)*

# Data issues upstream

- **Validated clips are linked to predictions on device + date + hour, species and score**:
  recording start times are snapped to the nearest hour and scores are compared at 3 decimals.
  *(2026-10-08, #2)* Matching on the exact recording name leaves 298 of 551 validations unmatched
  because recorder clocks drift: 288 validation recording names have non-zero seconds, while
  predictions always end in `00`. After snapping: 458 unique, 65 ambiguous, 28 unmatched (25 are
  rounding differences under 0.001, one recording is absent from the predictions). The link is for
  reporting only; thresholds do not need it.

- **Validations lack a prediction ID**: matching on recording + species + confidence is partial.
  *(decided at setup)* Reported as an upstream data issue, not worked around.

# Handoff to Tech (birds)

- **The handoff contains no open scientific question**: Tech receives a deterministic labelling
  rule and a thresholds table whose rows Biometrics owns. *(#6)* Science questions (validation
  coverage, recorder and time scope) stay in the report and go to Biometrics and the
  ornithologist. A species without a threshold is a normal state (`no_threshold`), never an
  error and never a decision for Tech. Alternative: ask Tech to choose a fallback cutoff, which
  would make a developer decide a science threshold.

- **Labelling is a join plus a comparison, with no statistics at runtime**: `confidence >=
  cutoff` against the current thresholds row for species, BirdNET version and settings. *(#6)*
  The fit, bootstrap and gates run offline in R; the platform never computes a logit, so a
  confidence of exactly 1.0 needs no clamp there. Alternative: fit on the platform, rejected
  because it moves the statistics into code Biometrics cannot change.

- **The labelling statement converges rather than only inserting**: it is one `INSERT ... ON
  CONFLICT (prediction_id) DO UPDATE` that rewrites a row only when its `threshold_id` changes.
  *(#6)* A rerun with unchanged thresholds is a no-op; a new thresholds row relabels exactly the
  affected predictions, and each observation stores the `threshold_id` it used. Alternative:
  `DO NOTHING`, which would leave old labels on superseded thresholds with no rule for when to
  relabel.

- **A BirdNET version or settings change gives `no_threshold` with a reason**: thresholds are
  keyed by species, BirdNET version and settings, and no row is borrowed from another
  version. *(#6)* The confidence scale of a new version is unvalidated, so reusing the old cutoff
  would be a silent science decision. Alternative: fall back to the nearest version, rejected.

- **Thresholds rows are insert-only and owned by Biometrics**: a refit adds rows with a later
  `valid_from`; Tech has read access only. *(#6)* This keeps every past label traceable. A check
  constraint ties `cutoff` to `status`.

- **The range gate is not a configurable value**: the handoff lists target precision, minimum
  smaller group and bootstrap size as Biometrics' config, and the range gate as a rule applied to
  every species whose result is the `in_range` column. *(#6)* `R/birds/config.R` has no switch for
  it, and adding one would let a species skip a check.

- **Handoff content kept out on purpose**: Python-versus-R discussion, parity fixtures, Redis
  design and the stratified validation sampling design. *(#6)* They are interview material, not
  what Tech needs to build the step. The acceptance tests are derived from the real data and the
  real nightjar cutoff instead.

- **Skill `biometrics-tech-handoff` captures the structure**: TL;DR for Tech, tables, runtime
  versus refit, config, edge cases, versioning, monitoring, acceptance tests, upstream issues.
  *(#6)* It is reused for the vegetation handoff (#11).
