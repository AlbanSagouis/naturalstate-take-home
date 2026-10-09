Herbaceous vegetation survey: data quality report
================
Alban Sagouis
2026-10-08

## 1. TL;DR

- **What.** The herbaceous vegetation survey summarised by submission
  (32 submissions, 2 rejected in ODK) and by plot (30 of 31 registered
  plots surveyed, 30 accepted surveys, 600 quadrats), a sampling-effort
  assessment (section 5) and a map of the transects (section 6). Data
  are counted and flagged, never changed.
- **Key result.** Only 2 of 30 plots approach an asymptote (the species
  curve has levelled off): 20 quadrats are not enough for the other 28.
  Gamma richness (identified taxa in the whole plot) runs from 6 to 24
  (median 14.5; 70 taxa in the data set). It is a minimum. Completeness
  (observed taxa divided by the estimated total) differs between plots,
  so comparisons must account for it. Counting each unknown label as a
  taxon moves the median completeness only from 68% to 66%.
- **Key decision.** Richness counts identified taxa only. Provisional
  unknowns (`herb_NNN` labels) are kept apart: 82 labels, in 70% of the
  quadrats. Leaving out the records with an error flag leaves the
  data-set total unchanged and changes the taxa found in 4 plots.
- **What Tech must do.** Stop the form accepting free-text names that do
  not follow `Genus_species`, and give each `herb_NNN` label a name in
  the entity list once identified, so the same plant is counted once
  (section 8.4). Coverage (the share of individuals whose taxon is
  already seen) and completeness are both needed to call a plot
  near-complete. The data show presence in a quadrat, not abundance.

## 2. Data and checks overview

The report reads the tables staged by `R/vegetation/01_load_join.R` (32
submissions, 640 quadrats, 2243 species records, 1296 of them typed or
reused in the extra-species repeat) and the flags written by
`R/vegetation/02_run_checks.R`. The 2 submissions rejected in ODK are
listed in the survey table and kept in the flags, but are not counted in
the plot or headline numbers. Flags never remove a record from the main
tables; the `E`, `W`, `I` columns count flags by severity. Section 7
shows what changes when error-flagged quadrats are left out.

The catalogue has 59 checks; 24 raised at least one flag. Errors break a
protocol rule or contradict other answers; warnings need a look; info is
context. There are 11 errors, 103 warnings and 849 info flags. The
errors and warnings, with the person who can resolve each, are in
`issues_for_field_teams.md`; all flags are in
`outputs/vegetation/flags.csv`.

| severity | quadrat | species | survey | total |
|:---------|--------:|--------:|-------:|------:|
| error    |      10 |       1 |      0 |    11 |
| warning  |      37 |      38 |     28 |   103 |
| info     |      58 |     751 |     40 |   849 |

## 3. Survey-level summary (brief item a)

One row per survey submission (one visit to one plot). `taxa` is the
number of identified taxa (section 8.1); `review` is the ODK review
state, empty unless rejected.

| plot    | date       | recorder         | n_quadrats | taxa |   E |   W | review   |
|:--------|:-----------|:-----------------|-----------:|-----:|----:|----:|:---------|
| Plot_01 | 2026-05-23 | Grace_Achieng    |         20 |   24 |   0 |   6 |          |
| Plot_02 | 2026-05-24 | Grace_Achieng    |         20 |   12 |   0 |   4 |          |
| Plot_03 | 2026-05-20 | Samuel_Kiprotich |         20 |    7 |   0 |   2 |          |
| Plot_04 | 2026-05-25 | Grace_Achieng    |         20 |    8 |   0 |   3 |          |
| Plot_05 | 2026-05-22 | Grace_Achieng    |         20 |   13 |   0 |   9 |          |
| Plot_06 | 2026-05-23 | Grace_Achieng    |         20 |   14 |   0 |   1 |          |
| Plot_07 | 2026-05-24 | Grace_Achieng    |         20 |    8 |   0 |   1 |          |
| Plot_08 | 2026-05-19 | Samuel_Kiprotich |         20 |   16 |   0 |   3 |          |
| Plot_09 | 2026-05-21 | Grace_Achieng    |         20 |   19 |   0 |   4 |          |
| Plot_10 | 2026-05-21 | Grace_Achieng    |         20 |   17 |   1 |   1 |          |
| Plot_11 | 2026-05-26 | Grace_Achieng    |         20 |   20 |   0 |   3 |          |
| Plot_12 | 2026-05-20 | Samuel_Kiprotich |         20 |   23 |   0 |   4 |          |
| Plot_13 | 2026-05-23 | Grace_Achieng    |         20 |    8 |   0 |   0 |          |
| Plot_14 | 2026-05-21 | Grace_Achieng    |         20 |   12 |   1 |   4 |          |
| Plot_15 | 2026-05-24 | Grace_Achieng    |         20 |   15 |   1 |   4 |          |
| Plot_16 | 2026-05-27 | Grace_Achieng    |         20 |   17 |   0 |   4 |          |
| Plot_17 | 2026-05-23 | Grace_Achieng    |         20 |   13 |   0 |   0 |          |
| Plot_18 | 2026-05-26 | Grace_Achieng    |         20 |   20 |   0 |   3 |          |
| Plot_18 | 2026-05-26 | Grace_Achieng    |         20 |   18 |   0 |   2 | rejected |
| Plot_19 | 2026-05-22 | Grace_Achieng    |         20 |   16 |   1 |   3 |          |
| Plot_20 | 2026-05-24 | Grace_Achieng    |         20 |   12 |   0 |   2 |          |
| Plot_21 | 2026-05-26 | Samuel_Kiprotich |         20 |   19 |   1 |   5 | rejected |
| Plot_21 | 2026-05-26 | Grace_Achieng    |         20 |   21 |   0 |   4 |          |
| Plot_22 | 2026-05-20 | Samuel_Kiprotich |         20 |   12 |   0 |   7 |          |
| Plot_24 | 2026-05-24 | Grace_Achieng    |         20 |    7 |   0 |   2 |          |
| Plot_25 | 2026-05-25 | Grace_Achieng    |         20 |   24 |   0 |   4 |          |
| Plot_26 | 2026-05-22 | Grace_Achieng    |         20 |   12 |   0 |   4 |          |
| Plot_27 | 2026-05-22 | Grace_Achieng    |         20 |   17 |   0 |   2 |          |
| Plot_28 | 2026-05-23 | Grace_Achieng    |         20 |   13 |   1 |   1 |          |
| Plot_29 | 2026-05-26 | Samuel_Kiprotich |         20 |   21 |   1 |   2 |          |
| Plot_30 | 2026-05-21 | Grace_Achieng    |         20 |   18 |   1 |   8 |          |
| Plot_46 | 2026-05-22 | Grace_Achieng    |         20 |    6 |   3 |   1 |          |

Across submissions, `taxa` runs from 6 to 24 (median 15.5) and durations
from 24.5 to 236.0 minutes (median 61.7). Every submission has 20
quadrats, and 6 have at least one quadrat without any species record.
Each of the 2 rejected submissions belongs to a plot that also has an
accepted one.

## 4. Plot-level summary (brief item b)

One row per registered plot, from the submissions not rejected in ODK.
Two plots (Plot_21 and Plot_18) were submitted twice and one submission
was rejected, so no plot has more than 20 quadrats.

| plot | type | state | n_quadrats | taxa (gamma) | mean per quadrat | unknown quadrats | E | W |
|:---|:---|:---|---:|---:|---:|---:|---:|---:|
| Plot_01 | primary | surveyed | 20 | 24 | 2.90 | 90% | 0 | 6 |
| Plot_02 | primary | surveyed | 20 | 12 | 1.25 | 85% | 0 | 4 |
| Plot_03 | primary | surveyed | 20 | 7 | 0.85 | 80% | 0 | 2 |
| Plot_04 | primary | surveyed | 20 | 8 | 1.35 | 80% | 0 | 3 |
| Plot_05 | primary | surveyed | 20 | 13 | 1.60 | 50% | 0 | 9 |
| Plot_06 | primary | surveyed | 20 | 14 | 2.45 | 90% | 0 | 1 |
| Plot_07 | primary | surveyed | 20 | 8 | 2.05 | 85% | 0 | 1 |
| Plot_08 | primary | surveyed | 20 | 16 | 3.35 | 90% | 0 | 3 |
| Plot_09 | primary | surveyed | 20 | 19 | 3.40 | 75% | 0 | 4 |
| Plot_10 | primary | surveyed | 20 | 17 | 2.35 | 65% | 1 | 1 |
| Plot_11 | primary | surveyed | 20 | 20 | 2.75 | 65% | 0 | 3 |
| Plot_12 | primary | surveyed | 20 | 23 | 2.90 | 100% | 0 | 4 |
| Plot_13 | primary | surveyed | 20 | 8 | 1.85 | 90% | 0 | 0 |
| Plot_14 | primary | surveyed | 20 | 12 | 3.30 | 45% | 1 | 4 |
| Plot_15 | primary | surveyed | 20 | 15 | 1.20 | 75% | 1 | 4 |
| Plot_16 | primary | surveyed | 20 | 17 | 3.85 | 55% | 0 | 4 |
| Plot_17 | primary | surveyed | 20 | 13 | 2.10 | 95% | 0 | 0 |
| Plot_18 | primary | surveyed | 20 | 20 | 2.80 | 60% | 0 | 3 |
| Plot_19 | primary | surveyed | 20 | 16 | 2.45 | 25% | 1 | 3 |
| Plot_20 | primary | surveyed | 20 | 12 | 1.75 | 75% | 0 | 2 |
| Plot_21 | primary | surveyed | 20 | 21 | 3.25 | 80% | 0 | 4 |
| Plot_22 | primary | surveyed | 20 | 12 | 2.45 | 60% | 0 | 7 |
| Plot_23 | primary | not surveyed | 0 | \- | \- | \- | 0 | 0 |
| Plot_24 | primary | surveyed | 20 | 7 | 0.50 | 90% | 0 | 2 |
| Plot_25 | primary | surveyed | 20 | 24 | 3.60 | 40% | 0 | 4 |
| Plot_26 | primary | surveyed | 20 | 12 | 1.95 | 85% | 0 | 4 |
| Plot_27 | primary | surveyed | 20 | 17 | 3.05 | 45% | 0 | 2 |
| Plot_28 | primary | surveyed | 20 | 13 | 1.00 | 90% | 1 | 1 |
| Plot_29 | primary | surveyed | 20 | 21 | 3.60 | 55% | 1 | 2 |
| Plot_30 | primary | surveyed | 20 | 18 | 3.50 | 40% | 1 | 8 |
| Plot_46 | backup | surveyed | 20 | 6 | 1.65 | 40% | 3 | 1 |

`taxa (gamma)` is the identified taxa found in all quadrats of the plot;
`mean per quadrat` is the average in one 1 m x 1 m quadrat and does not
depend on the number of quadrats; `unknown quadrats` is the share of
quadrats with at least one provisional unknown; `type` is primary or
backup.

30 of the 31 registered plots were surveyed. The plot not surveyed is
Plot_23 (primary and not viable in the registration). The backup plot
Plot_46 was surveyed and has 6 taxa, against a median of 15 for the
surveyed primary plots.

## 5. Assessment of sampling effort (brief item c)

Is 20 quadrats enough to describe the plant community of a plot? The
data hold presence or absence of a taxon per quadrat, so the answer uses
incidence-based methods on identified taxa (section 8.1). The thresholds
are working values to confirm with Natural State.

- 30 plots were surveyed; 30 have the 20 quadrats expected, so
  differences are in what the quadrats found, not in effort.
- Only 2 of 30 plots approach an asymptote (Plot_07 and Plot_26).
- Completeness runs from 25% to 99% (median 68%); 8 plots stay under
  50%. Sample coverage runs from 0.41 to 0.98 (median 0.88); 27 plots
  are below 0.95.

### 5.1 Method

For each plot the quadrats are the columns of a taxon-by-quadrat
presence matrix (`R/functions/veg_effort.R`, run by
`R/vegetation/03_summaries.R`). Empty quadrats stay in the matrix: they
are information about effort.

- **Accumulation curve.** `vegan::specaccum(method = "random")` adds
  quadrats in random order (100 orderings, seed 20261008). A curve still
  rising at the last quadrat says more quadrats would find new taxa.
- **Chao2 richness.** `iNEXT` estimates the asymptotic richness from
  incidence data (30 of 30 plots gave an estimate), with a 95% interval.
  It uses the taxa seen in one and two quadrats only, so it is a lower
  bound.
- **Completeness** is observed taxa divided by the Chao2 estimate.
  **Sample coverage** (`iNEXT`) is the share of the plot’s individuals
  whose taxon the sample has already found.
- **Gain** over the last 5 quadrats is the number of taxa the mean curve
  adds between quadrat 15 and 20.
- **Approaches an asymptote** when completeness is at least 0.9 and
  coverage is at least 0.95 (both provisional).

The main version uses the submissions not rejected in ODK
(`sampling_effort.csv`). The sensitivity version also leaves out
error-flagged quadrats (`sampling_effort_excl_errors.csv`); 8 plot(s)
then have fewer than 20 quadrats.

### 5.2 Results

| plot | quadrats | observed | Chao2 (95% interval) | completeness | coverage | approaches asymptote |
|:---|---:|---:|---:|---:|---:|:---|
| Plot_05 | 20 | 13 | 51.5 (19.0 to 261.1) | 25% | 0.72 | no |
| Plot_10 | 20 | 17 | 64.5 (24.5 to 317.0) | 26% | 0.79 | no |
| Plot_24 | 20 | 7 | 21.2 (10.2 to 71.5) | 33% | 0.41 | no |
| Plot_30 | 20 | 18 | 52.2 (27.8 to 138.0) | 34% | 0.87 | no |
| Plot_12 | 20 | 23 | 57.2 (30.3 to 183.4) | 40% | 0.80 | no |
| All plots (median; asymptote: count) | 20 | 14.5 | 24.2 | 68% | 0.88 | 2 of 30 |

The five plots with the lowest completeness are shown; all 30 are in
`outputs/vegetation/sampling_effort.csv`. The median gain over the last
5 quadrats is 1.71 taxa (range 0.37 to 3.35).

![Species accumulation curves of the surveyed plots: mean number of
identified taxa (line) against the number of quadrats added in random
order, one panel per plot. Description: most curves are still rising at
the twentieth quadrat; a few flatten out near the end; plots differ
widely in the height of the curve.](figures/veg_accumulation.png)

The Chao2 intervals are wide for plots with many rare taxa (the upper
limit exceeds three times the observed richness in 21 plots), so the
completeness of a single plot is uncertain; the pattern across plots is
the robust part. The sensitivity version gives 2 plot(s) that approach
an asymptote and the same median completeness (68%).

Identification favours common taxa, so the estimates describe a
non-random part of each plot. As a check I repeated the table with every
unknown label counted as a taxon, an upper bound because a label can
repeat a named taxon (`sampling_effort_upper_bound.csv`). The picture
holds: median completeness is 66% (against 68%) and 1 plot(s) approach
an asymptote (Plot_13).

### 5.3 What this means, and decisions

20 quadrats do not saturate the species curve for 28 of 30 plots, so
more quadrats would still find new taxa there. Richness is a lower
bound, and a plot with fewer taxa may only be sampled less completely:
compare plots at equal coverage or use the estimate with its interval,
not the observed count alone. This is a statement about the adequacy of
these data, not a recommendation on survey design. Status: provisional,
recorded in `rulebook_vegetation.md`.

- **Incidence-based, quadrats as units.** Only presence exists, so
  abundance-based estimators (Chao1, rarefaction on individuals) do not
  apply.
- **Chao2 and coverage together.** Alternatives: curves alone (no
  number, no rule for “enough”) or Chao2 alone (unstable with few rare
  taxa). The asymptote rule needs both.
- **Thresholds 0.9 and 0.95.** Common working values for “near
  complete”; a lower completeness threshold would add plots to the 2. To
  confirm with Natural State.
- **Identified taxa only.** Same rule as for richness (section 8.1).
- **Random order.** Quadrats of a transect are spatially ordered, so
  field order would mix spatial structure into the curve. The seed is
  fixed.

## 6. Map of transect locations (brief item d)

Plots and quadrats are coloured by the worst flag: error, then warning,
then info; a plot without a flag is green. The colours are defined once
in the configuration and reused in the dashboard. Data are anonymised,
so real coordinates are shown.

### 6.1 All plots

The overview places the 30 registered plots that have coordinates in the
plot register (all 30 surveyed plots). 1 registered plot (Plot_23, not
viable, not surveyed) has none and is only named in the figure. The
backup plot (Plot_46) is a diamond. Distances use EPSG:32637 (UTM zone
37N). There is no web basemap, so the figure works offline.

![Map of the plot locations. Circles are primary plots that were
surveyed, the diamond is the backup plot. Fill is the worst flag of the
plot: dark red error, amber warning, grey info only. A scale bar of 2 km
and a north arrow are drawn. Description: 30 points in a band about 14
km wide from west to east and 5 km from south to north; three points lie
to the north-east, away from the main band; most points are amber, with
dark red points in the middle and the south-east and two grey points in
the west.](figures/veg_transect_map.png)

- 8 surveyed plots have an error flag and 20 at worst a warning; only 2
  plots (13 and 17) have neither. Error plots are spread along the whole
  band, and the errors are data-entry errors (quadrats marked as having
  extra species with none recorded, one extra species without a name),
  not location problems.
- Four error plots (10, 14, 19, 30) lie in the south-east cluster, so
  one field trip can check four submissions.
- The backup plot Plot_46 lies north-east next to plot 05, about 5 km
  north of the main band, with 3 error flags of the same kind. Plots 05,
  09 and 46 are isolated to the north-east and need their own trip.

### 6.2 Quadrats along the transects

The second figure shows the quadrat fixes of four plots in metres from
the plot centre, joined in numbering order. The dashed circle is the
belt reach (half the 50 m length and half the 5 m width, 25.1 m); check
SPA-04 flags a quadrat beyond this reach plus the GPS accuracy of its
fix and of the plot centre. Colour is the worst flag of the quadrat.

![Quadrat positions of plots 01, 05, 11 and 16 in metres from the plot
centre (cross), joined by a line in quadrat order. A dashed circle marks
the reach of the belt; a 20 m scale bar and a north arrow are drawn.
Description: in plot 01 one quadrat lies about 75 m to the north-west of
the centre while the others cluster near the circle; in plot 05 a group
of about eight quadrats lies north of the circle, outside the belt; in
plot 11 one quadrat is about 50 m north; in plot 16 all quadrats sit
along an east-west line inside the
circle.](figures/veg_transect_zoom.png)

- Plot 01: quadrat 18 is 74.6 m from the plot centre, far beyond the
  belt; the other 19 form a normal transect. Plot 11 has a similar
  single fix about 50 m away.
- Plot 05: the whole transect is shifted about 30 m north of the plot
  centre (6 quadrats flagged). Either the transect was laid out from
  another point or the plot centre is wrong; the data cannot tell which.
  This is the clearest case for a field team to check.
- Plot 16 is a clean example, all fixes inside the belt.
- Overall 35 quadrats in 18 plots are flagged by SPA-04. They are
  warnings, not errors, because GPS may drift under tree cover and the
  plot centre has 3 to 5 m accuracy.

### 6.3 Interactive dashboard

An interactive dashboard is an extra, not part of the deliverable. It
has four pages (summaries, a map, a filterable flags table and the
sampling effort), reads the same files as this report and runs no new
analysis. Source: [`dashboard/`](dashboard/) (Quarto
`format: dashboard`); rendered page: `docs/index.html`; live on GitHub
Pages at <https://albansagouis.com/naturalstate-take-home/> (the
`github.io` address redirects there). The Natural State logo and colours
are used for this mock-up only.

![Dashboard, summaries page: five value boxes (accepted surveys, plots
surveyed, quadrats, identified taxa, flag counts) above a table of the
survey summary with a second tab for the plot
summary.](figures/veg_dashboard_summaries.png)

![Dashboard, map page: the plot locations as coloured circles (dark red
error, amber warning, grey info only) on Esri satellite imagery, with a
legend; the backup plot has a navy rim.](figures/veg_dashboard_map.png)

![Dashboard, flags page: three drop-down filters (severity, check, plot)
with the count of shown flags above a table of the 963 flags, errors
first.](figures/veg_dashboard_flags.png)

## 7. Sensitivity: leaving out the records with an error flag

The plot and headline tables exist a second time without the quadrats
that carry an error flag (`survey_summary_excl_errors.csv`,
`plot_summary_excl_errors.csv`). What is left out is listed in
`outputs/vegetation/excluded_records.csv`: the 10 quadrats with an error
flag (only the quadrat); the whole submission for an error not tied to a
quadrat (none here); and the 2 rejected submissions with their 0
quadrats, which are left out of both versions.

| Number | Accepted submissions | Excluding errors |
|:---|---:|---:|
| Surveys | 30 | 30 |
| Quadrats | 600 | 590 |
| Identified taxa, whole data set | 70 | 70 |
| Provisional unknown labels | 82 | 81 |
| Taxa upper bound (with unknown labels) | 152 | 151 |
| Mean taxa per quadrat | 2.37 | 2.38 |
| Median taxa per plot (gamma) | 14.5 | 14 |
| Maximum taxa per plot (gamma) | 24 | 24 |

Per plot, gamma richness changes in 4 of 30 plots (largest fall 1 taxa,
median change 0). The mean taxa per quadrat moves by at most 0.11. The
data-set richness is unchanged (a taxon only found in a left-out quadrat
would lower it). The rank correlation of gamma richness between the two
versions is 1.00. Flag counts are the same in both versions; only
quadrats, taxa and indices are recomputed.

## 8. Decisions and limits

### 8.1 What counts as a species

Distinct identified taxa are the names picked from the species list plus
the names typed in the extra-species repeat, after harmless typing
differences are removed (trimmed spaces, underscores, capital first
letter). Each taxon is counted once. A record such as
`herb_104 (Justicia divaricata )` is read as its proposed name, because
the team named it (45 records).

Provisional unknowns (plain placeholders such as `herb_017`, raw UUID
text, records with no name: 712 of 2243 records) are counted separately
and kept out of the headline richness, because one plant can sit behind
several labels. Including them would change the data-set richness from
70 to 152 (`summary_totals.csv`, `richness_upper_bound` in
`plot_summary.csv`). A misspelling (for example `Brachiara`) is not
merged: it is flagged (SPE-06). Reading the 3 typed misspellings as the
name they look like leaves the data-set total at 70 taxa
(`richness_sensitivity.csv`): each misspelled name is the only record of
its taxon.

### 8.2 Diversity indices

There is no abundance, so the tables report richness only. Shannon’s H
on quadrat frequencies is used for one purpose: check PLT-09 flags a
plot whose H is more than 3 scaled median absolute deviations from the
plot median (information flag, at least 10 plots; 0 flagged).
Alternatives rejected: H in the plot table (invites reading it as a
biodiversity result that twenty small quadrats cannot support),
Simpson’s index (same objection), and no outlier check (a plot with a
single taxon would pass unnoticed).

### 8.3 What the sensitivity version leaves out

An error-flagged quadrat is left out and the other quadrats of the
submission stay, because the errors here concern one quadrat. A
submission rejected in ODK is left out of both versions as a whole: the
reviewer judged it unusable, and keeping it would give a plot the
quadrats of two visits. Alternative: drop whole submissions with any
error, which discards good quadrats. Data are never changed; the tables
are filtered views, and warnings and info flags never exclude a record.

### 8.4 Limits

- Presence or absence only, 20 quadrats of 1 m x 1 m in one visit:
  richness is a minimum, and the effort estimates (section 5) rest on
  provisional thresholds and a lower-bound estimator with wide
  intervals.
- 712 records (32%) are provisional unknowns whose taxa may be
  identified ones. Many `herb_NNN` labels with a proposed name also
  appear as a plain label elsewhere (22 of 44), so a link table kept by
  the data manager would remove most of the problem. It is not applied
  here because it would change the data.
- The report follows the ODK review state; whether the reviewer was
  right to reject the two submissions is not checked, and the data do
  not say why they were rejected.
- A quadrat count does not test whether quadrats were placed as the
  protocol asks; the spatial checks do.

## Reproduce

The numbers in this report come from the files in `data/processed/` and
`outputs/vegetation/`. Script 05 renders the dashboard (it needs
Quarto). To regenerate and check them, run from the project root in a
fresh R session:

``` r
source(here::here("R", "vegetation", "01_load_join.R"))
source(here::here("R", "vegetation", "02_run_checks.R"))
source(here::here("R", "vegetation", "03_summaries.R"))
source(here::here("R", "vegetation", "04_map.R"))
source(here::here("R", "vegetation", "05_dashboard.R"))
testthat::test_dir(here::here("tests", "testthat"))
rmarkdown::render(here::here("issues_for_field_teams.Rmd"))
rmarkdown::render(here::here("vegetation_report.Rmd"))
```
