---
name: biometrics-tech-handoff
description: Use when writing a handoff from a Biometrics or data-science analysis to the Tech (software) team so a statistical method can run automatically on the platform. Gives the document structure (TL;DR, schemas, runtime vs refit, config, edge cases, versioning, monitoring, acceptance tests, upstream issues) and the rules (no open science question, Tech never decides a threshold or a check).
---

# Biometrics to Tech handoff

Use for a document that turns an analysis into something developers can implement and run
unattended. Model: `handoff_birds.Rmd` (knitted to `handoff_birds.md`) with
`sql/birds_schema.sql` and `sql/birds_label_observations.sql`.

## Audience

Software developers (here Python, SQL, PostgreSQL, Docker Compose, ODK). They do not need the
science, only a ready product: a deterministic rule and a table of parameters that someone else
owns.

## Structure (## and ### headings, Rmd knitted to GitHub markdown)

1. **TL;DR for Tech**, 3 to 5 bullets: what to build, the key rule, what Tech must do, what is
   not Tech's decision.
2. **Inputs and outputs**: each table, who writes it, with the SQL schema (DDL) shown in the
   document and saved under `sql/`. Include a unique id for every input row and a table of
   parameters (thresholds, rules) with a version and a `valid_from`.
3. **The contract**: how outputs are derived from inputs, the exact rule in one line, the fixed
   meaning of every status value, one worked example with real rows.
4. **Pipeline steps and triggers**: separate the runtime step (cheap, deterministic, no
   statistics, idempotent, in SQL under `sql/`) from the offline refit (owned by Biometrics,
   triggered by new validations or a new software version, versioned, inserts rows Tech never
   edits).
5. **Configuration Biometrics can change without code**: values, current setting, meaning, and
   a statement that the platform never reads them at runtime.
6. **Edge cases and failure behaviour**: a table of case and behaviour. A state without a
   parameter ("no threshold yet") is a normal status with a reason, not an error.
7. **Metadata to store**: the fields needed later for checks, each justified in one sentence.
8. **Monitoring**: the per-batch numbers (shares per category) as a query, and the diagnostic
   columns a refit dashboard reads.
9. **Upstream data issues**: point to the data-issue, say what the export must carry.
10. **Acceptance tests**: a table of 6 to 8 input rows with expected outputs, derived from real
    data, including boundary values and the "no parameter" states.
11. **Versioning**: what is versioned, how, and how an output row traces back to the parameter
    row that produced it.
12. **Stack note**: one line; do not design their deployment.

## Rules

- No open scientific question in the handoff. Science questions go to Biometrics and domain
  experts in the report. Settle them first.
- Tech never decides a threshold or a check. Parameter rows are inserted by Biometrics and never
  edited by Tech.
- State every decision with its reason (and the alternative rejected); log it in the project's rulebook.
- Use real examples from the data, not invented rows. Constructed rows (for example a boundary
  value) are labelled as constructed.
- Every number comes from a file via inline chunks; nothing typed by hand. Show SQL by reading
  the `.sql` file in a chunk so document and file cannot diverge.
- Runtime SQL must be idempotent and keyed on a unique id; test its logic on a small fixture
  (the rule, a rerun, a parameter change) when no target database is available locally.
- Leave out language comparisons, parity fixtures, infrastructure design and sampling design.
