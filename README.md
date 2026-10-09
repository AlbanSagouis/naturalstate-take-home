# Natural State take-home: Senior Data Scientist

## TL;DR

- **What.** Two challenges. Birds: a BirdNET confidence threshold per species with the Wood & Kahl
  (2024) method, and a label (`observed`, `below_threshold` or `no_threshold`) on all 29,491
  predictions. Vegetation: a QA/QC pipeline over the herbaceous ODK surveys (32 submissions, 2 of them
  rejected in ODK and left out of the plot numbers; 30 accepted surveys, 600 quadrats), summaries, a plot map and a dashboard. Each has a report for
  Biometrics and a handoff for Tech.
- **Key results.** Only the Abyssinian Nightjar gets a threshold (0.667, bootstrap interval 0.43 to
  0.83); the other three validated species get `no_threshold` because their validation data cannot
  support a fit. 3,147 of 29,491 predictions are `observed`. Vegetation: 59 checks raised 10
  errors, 140 warnings and 757 info flags on the accepted submissions (11, 148 and 804 on all 32);
  plots hold 6 to 24 identified taxa. Sampling effort: all 30 plots have 20 quadrats, and 2 of 30
  (Plot_07, Plot_26) approach an asymptote.
- **Key decisions.** One method and one precision target (0.99) for every species, so relative
  abundances stay comparable; a species without enough validation gets a request for more
  validation, not a special-case threshold. Vegetation data are flagged, never fixed or dropped;
  provisional unknowns are kept out of headline richness.
- **What Tech must do.** Create the birds tables and run the labelling statement after every
  upload, store recorder metadata and a prediction id with each validation, run the vegetation
  check catalogue on every new batch, and fix two form issues upstream (the
  `quadrats_with_species` calculation and a species label with a trailing space). Details are in
  the two handoffs.

## Deliverables

| Deliverable | What it is | For |
|:---|:---|:---|
| [birds_report.md](birds_report.md) | Birds methods report: thresholds, robustness checks, labelling | Biometrics |
| [handoff_birds.md](handoff_birds.md) | Birds handoff: labelling step, tables, metadata, monitoring | Tech |
| [vegetation_report.md](vegetation_report.md) | Vegetation QA/QC report: checks, summaries, map | Biometrics |
| [handoff_vegetation.md](handoff_vegetation.md) | Vegetation handoff: checks to run on the platform, dashboard spec | Tech |
| [issues_for_field_teams.md](issues_for_field_teams.md) | Errors and warnings per plot, with who can resolve each | Field teams, via Biometrics |
| [outputs/birds/birdnet_predictions_labelled.csv](outputs/birds/birdnet_predictions_labelled.csv) | Every prediction with `observation_status` and `observation` | Biometrics and Tech |
| [outputs/vegetation/](outputs/vegetation/) | Check catalogue, flags, summaries, plot locations, excluded records | Biometrics; catalogue also Tech |
| [docs/index.html](docs/index.html) | Mock-up QA/QC dashboard (source in `dashboard/`); screenshots in `figures/veg_dashboard_*.png` | Biometrics, as a spec for Tech |
| [sql/](sql/) | `birds_schema.sql` and `birds_label_observations.sql` (PostgreSQL) | Tech |

The reports are the stand-alone read; the dashboard is an extra.

## How to reproduce

### Packages

```r
renv::restore()
```

### Data layout

`data/raw/` is read-only and committed unchanged. Hashes are in `data/raw/MANIFEST.sha256`. To
verify them (from the repository root):

```bash
cd data/raw && shasum -a 256 -c MANIFEST.sha256
```

Intermediate tables are written to `data/processed/` (git-ignored, regenerated). Deliverables go to
`outputs/`, figures to `figures/`.

### Run order

Each config script loads the helper functions in `R/functions/`.

```r
# Birds
source("R/birds/01_load_validate.R")
source("R/birds/02_threshold_evidence.R")
source("R/birds/03_robustness_checks.R")
source("R/birds/04_label_observations.R")

# Vegetation
source("R/vegetation/01_load_join.R")
source("R/vegetation/02_run_checks.R")
source("R/vegetation/03_summaries.R")
source("R/vegetation/04_map.R")
source("R/vegetation/05_dashboard.R")  # renders dashboard/dashboard.qmd to docs/index.html
```

### Reports

The reports are R Markdown, knitted to GitHub-flavoured Markdown (the `.md` sits next to the
`.Rmd`). Run them after the scripts above.

```r
for (report in c(
  "birds_report", "handoff_birds",
  "vegetation_report", "handoff_vegetation", "issues_for_field_teams"
)) {
  rmarkdown::render(input = paste0(report, ".Rmd"))
}
```

### Tests

```r
testthat::test_dir(path = "tests/testthat")
```

## Data

The data are anonymised (confirmed by Natural State) and committed unchanged in `data/raw/`. The
brief, the SOPs and the Wood & Kahl paper are kept local and are not in this repository.

## Report

### Process

1. Discovery: I read the brief and the data and summarised what is there.
2. I used the `grill-me` skill on the plan: Claude Code questioned its open decisions one at a time
   before any code was written, on the decisions that matter (species without enough validation,
   threshold uncertainty, labelling, check severities), and I answered each.
3. I wrote the plan as GitHub issues, one per deliverable, plus one `data-issue` per upstream
   problem found in the data.
4. I implemented one issue at a time. Every commit message references its issue (`refs #n` while
   in progress, `closes #n` when done).
5. I logged decisions in [rulebook_birds.md](rulebook_birds.md) and
   [rulebook_vegetation.md](rulebook_vegetation.md) (decision, reason, alternatives) and as
   comments on the issue.

The decision trail is in the [issue list](https://github.com/AlbanSagouis/naturalstate-take-home/issues).

### Decision making

The AI wrote code and first drafts. The scientific direction was mine. In particular:

- **Environment sensitivity.** I raised the question whether thresholds transfer across recorders,
  times and places, directed the recorder and environment sensitivity analysis, and made it a
  routine step. See "Do thresholds transfer across recorders, times and places?" and "Why the two
  robustness figures are drawn" in [rulebook_birds.md](rulebook_birds.md#robustness-and-environmental-effects).
  I raised the potential date effect and seasonality for the same reason.
- **What the Wood & Kahl tutorial does.** I had the supplementary tutorial investigated to see what
  it does and does not do before adopting the recipe.
- **Eligibility as two questions.** I questioned the first minimum-count rule and split eligibility
  into two separate questions: do the data allow a threshold, and does it generalise
  ([rulebook](rulebook_birds.md#bird-thresholds)).
- **No threshold without evidence.** Species without enough validation get no threshold and a
  request for more validation, not a special case. I chose one method and one precision target for
  every species, so relative abundances stay comparable.
- **Stability is reported, not a gate.** I decided that bootstrap stability is reported with the
  threshold and designed to feed a refit-monitoring dashboard, rather than blocking a result.
- **Nightjar scope.** I labelled the nightjar for all hours with its evidence scope stated (its
  wrong clips are all from the evening), and asked for random night clips.
- **AIC.** I wanted AIC explored but not used to choose a model.
- **Field-team list.** I decided that the list for the data providers holds errors and warnings,
  each with who can resolve it ([rulebook](rulebook_vegetation.md#reporting)).
- **Rejected submissions.** I decided that submissions rejected in ODK are left out of every plot and
  headline number, counted in the report and the dashboard, and left off the field-team list.
- **Sampling effort.** I asked for the sampling-effort assessment from the brief to be kept, with
  the asymptote thresholds marked provisional until Natural State confirms them.
- **Diversity indices.** I decided that Shannon is used only to find outlying plots, never reported
  as a result, and that richness is reported twice (identified taxa, and an upper bound with the
  unknown labels).
- **Format.** I asked for reports as knitted R Markdown, so numbers in the text come from the code.
- **Throughout.** I directed and reviewed all the AI work, file by file.

### Skills

R code follows my `r-code-style` skill, a short set of conventions that Claude Code loads when it
writes R: base pipe, explicit argument names, `stringi` over `stringr`, `.by =` grouping, explicit
join safety and input checks rather than assumptions about clean data. AI-written code arrives in
the style I would write by hand, which makes it quicker to review. During this work I added a
caveat to it (`unmatched = "error"` in a `left_join` does not catch data keys missing from the
lookup) and published it to my personal skill registry. The skill is in
[.claude/skills/r-code-style/](.claude/skills/r-code-style/).

I scaffolded the repository with `data-wrangling-compendium-skeleton`: `renv`, the two
`rulebook_*.md` decision logs, `AGENTS.md` for AI agents and the git hooks below. The skills this project is set up
with are listed in the committed manifest
[.agents/akm.json](.agents/akm.json): `biometrics-tech-handoff`, `data-wrangling-compendium-skeleton`, `grill-me` and
`r-code-style`. I used `grill-me` to question the plan before any code was written (see Process).

I captured `biometrics-tech-handoff` from the first handoff (birds) once the structure had
settled, and reused it for the second (vegetation): TL;DR for Tech, schemas, runtime versus refit,
config, edge cases, versioning, monitoring, acceptance tests, and the rule that Tech never decides
a threshold or a check. It is in [.claude/skills/biometrics-tech-handoff/](.claude/skills/biometrics-tech-handoff/).
It is listed in the manifest.

If Biometrics does not already have one, a shared R style skill would be a cheap win: one file in a
shared repository, versioned with the code, loaded by everyone's AI assistant, so conventions live
in one place and reviews can focus on the science.

### Git hooks

Hooks live in `.git/hooks/` and are not pushed, so they are described here and in `AGENTS.md`.
Bypass either with `--no-verify`.

- pre-commit: formats staged R files with `air` and restages them (fails if `air` is missing or a
  file has unstaged edits), and reminds, without blocking, to update the rulebook when analysis
  code or a `.qmd` is staged without it.
- pre-push: fetches origin and warns, with a confirm prompt, if the remote branch has commits the
  local branch lacks. Skips on first push and in detached HEAD.

### AI use

The brief encourages AI use. I can explain every line. Claude Code wrote code, tests and first
drafts of the reports and handoffs, under my direction and in the style enforced by the skills. It
did not choose the scientific approach, the severity of a check or what counts as evidence for a
threshold; those decisions are mine and are in [rulebook_birds.md](rulebook_birds.md) and
[rulebook_vegetation.md](rulebook_vegetation.md), and every number in the
reports is computed in the `.Rmd` code, not typed.

## Licence

Code is MIT licensed (see [LICENSE](LICENSE)). The data in `data/raw/` belong to Natural State. The
Natural State logo in `assets/` is used for the mock-up dashboard only.
