The Rulebook
============

Running log of analytical decisions: the judgement calls that would otherwise live only in code
or in my head. Write each one down the day it is made, with the question, the decision, and why.
Each decision is also added as a comment on its GitHub issue.

Entry format: **Question**: the decision, in one line. *(issue #n)* The rule, and why.

# Bird thresholds
- **Species with complete or quasi-separation (oriole, plover)**: no logistic fit is attempted.
  *(decided at setup, to confirm in #3)* The fit is unstable or impossible without negatives;
  precision is reported empirically with a binomial CI instead.
- **Confidence of exactly 1.0**: clamped (e.g. to 0.9999) before the logit. *(decided at setup)*
  qlogis(1) is infinite.

# Observation labelling
- **Species below threshold or without one**: `observation` is NA and `observation_status` says
  why (observed / below_threshold / no_threshold). *(decided at setup)*

# Vegetation checks and severities
- **Flag, never fix**: the QA/QC pipeline never modifies the data. *(from the brief)*

# Field-team reporting
- **Audience split**: the errors list for field teams only contains issues a field team can act
  on; pipeline-internal problems (keys, joins) stay out. *(decided at setup)*

# Data issues upstream
- **Validations lack a prediction ID**: matching on recording + species + confidence is partial.
  *(decided at setup)* Reported as an upstream data issue, not worked around.
