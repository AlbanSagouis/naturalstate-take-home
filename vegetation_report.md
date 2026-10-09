Herbaceous vegetation survey: data quality report
================
Alban Sagouis
2026-10-08

## 1. TL;DR

- **What.** A summary of the herbaceous vegetation survey by submission
  (32 submissions, 2 of them rejected in ODK) and by plot (30 of 31
  registered plots surveyed, 30 accepted surveys, 600 quadrats), and a
  map of the transects. Data are only counted and flagged, never
  changed. Sampling effort (brief item 1c) is assessed in section 5.
- **Key result.** Only 2 of 30 plots approach an asymptote: 20 quadrats
  do not saturate the species curve for the other 28 (section 5). Plots
  hold 6 to 24 identified taxa (median 14.5; 70 taxa in the whole data
  set). Richness is what 20 quadrats found, so it is a minimum, and
  completeness differs between plots, so comparisons should account for
  it.
- **Key decision.** Richness counts identified taxa only. Provisional
  unknowns (`herb_NNN` labels) are kept apart: they add 82 labels and
  are in 70% of the quadrats. Leaving out the records with an error flag
  gives 70 taxa in the data set (against 70) and changes the gamma
  richness of 4 plots.
- **What remains uncertain, and what Tech must do.** Many unknowns are
  probably named taxa (section 8.4). The data cannot tell abundance,
  only presence in a quadrat. Tech must stop the form from accepting
  free-text names that do not follow `Genus_species`, and must give each
  `herb_NNN` label a name in the entity list once it is identified, so
  that the same plant is counted once.

## 2. Data and checks overview

The report reads the tables staged by `R/vegetation/01_load_join.R` (32
survey submissions, 640 quadrats, 2243 species records, of which 947
picked from the species list and 1296 typed or reused in the
extra-species repeat) and the flags written by
`R/vegetation/02_run_checks.R`. Of the 32 submissions, 2 were rejected
in ODK: they are listed in the survey table and kept in the flags, but
are not counted in the plot or headline numbers and are not on the list
for the field teams.

### 2.1 Flags

The catalogue has 59 checks; 24 of them raised at least one flag. Errors
break a rule of the survey protocol or contradict other answers;
warnings need a look; info is context.

| severity | quadrat | species | survey | total |
|:---------|--------:|--------:|-------:|------:|
| error    |      10 |       1 |      0 |    11 |
| warning  |      37 |      83 |     28 |   148 |
| info     |      58 |     706 |     40 |   804 |

There are 11 errors, 148 warnings and 804 info flags. The errors and
warnings, with the person who can resolve each, are in
`issues_for_field_teams.md`; the full list is
`outputs/vegetation/flags.csv`.

### 2.2 How flags enter the summaries

Each survey and plot row shows the number of flags of each severity
(columns E, W, I), counted on the whole submission. Flags never remove a
record from the main tables. The plot rows and the headline numbers
count the submissions that were not rejected in ODK, and the flag counts
in a plot row come from those submissions; the survey rows show every
submission, rejected ones included. Section 7 shows what changes when
the error-flagged quadrats are left out.

## 3. Survey-level summary (brief item a)

One row per survey submission (one visit to one plot). A quadrat has
“species” when at least one species record exists for it, identified or
not.

| plot | date | recorder | duration (min) | n_quadrats | with species | taxa | unknowns | E | W | I | review |
|:---|:---|:---|---:|---:|---:|---:|---:|---:|---:|---:|:---|
| Plot_01 | 2026-05-23 | Grace_Achieng | 69.6 | 20 | 20 | 24 | 8 | 0 | 7 | 36 |  |
| Plot_02 | 2026-05-24 | Grace_Achieng | 100.3 | 20 | 19 | 12 | 7 | 0 | 6 | 27 |  |
| Plot_03 | 2026-05-20 | Samuel_Kiprotich | 58.7 | 20 | 18 | 7 | 8 | 0 | 4 | 31 |  |
| Plot_04 | 2026-05-25 | Grace_Achieng | 56.4 | 20 | 19 | 8 | 12 | 0 | 3 | 32 |  |
| Plot_05 | 2026-05-22 | Grace_Achieng | 102.5 | 20 | 19 | 13 | 4 | 0 | 12 | 14 |  |
| Plot_06 | 2026-05-23 | Grace_Achieng | 91.8 | 20 | 20 | 14 | 12 | 0 | 4 | 36 |  |
| Plot_07 | 2026-05-24 | Grace_Achieng | 56.5 | 20 | 20 | 8 | 10 | 0 | 1 | 35 |  |
| Plot_08 | 2026-05-19 | Samuel_Kiprotich | 236.0 | 20 | 20 | 16 | 15 | 0 | 9 | 40 |  |
| Plot_09 | 2026-05-21 | Grace_Achieng | 81.7 | 20 | 20 | 19 | 10 | 0 | 8 | 25 |  |
| Plot_10 | 2026-05-21 | Grace_Achieng | 63.2 | 20 | 20 | 17 | 4 | 1 | 4 | 23 |  |
| Plot_11 | 2026-05-26 | Grace_Achieng | 53.7 | 20 | 20 | 20 | 5 | 0 | 3 | 20 |  |
| Plot_12 | 2026-05-20 | Samuel_Kiprotich | 164.8 | 20 | 20 | 23 | 17 | 0 | 9 | 50 |  |
| Plot_13 | 2026-05-23 | Grace_Achieng | 70.4 | 20 | 20 | 8 | 4 | 0 | 0 | 31 |  |
| Plot_14 | 2026-05-21 | Grace_Achieng | 57.5 | 20 | 20 | 12 | 7 | 1 | 5 | 14 |  |
| Plot_15 | 2026-05-24 | Grace_Achieng | 60.2 | 20 | 20 | 15 | 7 | 1 | 5 | 18 |  |
| Plot_16 | 2026-05-27 | Grace_Achieng | 51.3 | 20 | 20 | 17 | 6 | 0 | 5 | 15 |  |
| Plot_17 | 2026-05-23 | Grace_Achieng | 43.9 | 20 | 20 | 13 | 9 | 0 | 0 | 35 |  |
| Plot_18 | 2026-05-26 | Grace_Achieng | 53.5 | 20 | 20 | 20 | 8 | 0 | 3 | 17 |  |
| Plot_18 | 2026-05-26 | Grace_Achieng | 26.0 | 20 | 20 | 18 | 7 | 0 | 2 | 19 | rejected |
| Plot_19 | 2026-05-22 | Grace_Achieng | 60.0 | 20 | 19 | 16 | 3 | 1 | 5 | 12 |  |
| Plot_20 | 2026-05-24 | Grace_Achieng | 54.0 | 20 | 20 | 12 | 5 | 0 | 2 | 22 |  |
| Plot_21 | 2026-05-26 | Samuel_Kiprotich | 24.5 | 20 | 20 | 19 | 11 | 1 | 6 | 28 | rejected |
| Plot_21 | 2026-05-26 | Grace_Achieng | 67.6 | 20 | 20 | 21 | 9 | 0 | 5 | 29 |  |
| Plot_22 | 2026-05-20 | Samuel_Kiprotich | 73.0 | 20 | 20 | 12 | 9 | 0 | 8 | 20 |  |
| Plot_24 | 2026-05-24 | Grace_Achieng | 38.0 | 20 | 20 | 7 | 4 | 0 | 2 | 30 |  |
| Plot_25 | 2026-05-25 | Grace_Achieng | 63.2 | 20 | 20 | 24 | 7 | 0 | 6 | 14 |  |
| Plot_26 | 2026-05-22 | Grace_Achieng | 109.8 | 20 | 20 | 12 | 11 | 0 | 6 | 27 |  |
| Plot_27 | 2026-05-22 | Grace_Achieng | 66.5 | 20 | 20 | 17 | 5 | 0 | 2 | 15 |  |
| Plot_28 | 2026-05-23 | Grace_Achieng | 64.4 | 20 | 19 | 13 | 9 | 1 | 1 | 46 |  |
| Plot_29 | 2026-05-26 | Samuel_Kiprotich | 42.1 | 20 | 20 | 21 | 3 | 1 | 2 | 17 |  |
| Plot_30 | 2026-05-21 | Grace_Achieng | 101.4 | 20 | 20 | 18 | 7 | 1 | 11 | 15 |  |
| Plot_46 | 2026-05-22 | Grace_Achieng | 33.0 | 20 | 20 | 6 | 3 | 3 | 2 | 11 |  |

- `taxa` is the number of identified taxa in the submission (section
  8.1).
- `unknowns` is the number of different provisional labels (`herb_NNN`),
  not counted in `taxa`.
- `duration (min)` is the time from the start to the end of the form.
- `review` is the ODK review state. It is empty when no state is
  recorded, which is the case for every submission except the rejected
  ones.

Across submissions, `taxa` runs from 6 to 24 (median 15.5). Durations
run from 24.5 to 236.0 minutes (median 61.7). Every submission has 20
quadrats. 6 submissions have at least one quadrat without any species
record. 2 submissions are rejected in ODK; each belongs to a plot that
also has an accepted submission. They are listed here but not counted in
the plot rows or the headline numbers.

## 4. Plot-level summary (brief item b)

One row per registered plot, from the submissions that were not rejected
in ODK. Two plots (Plot_21 and Plot_18) were submitted twice and one of
the two submissions was rejected, so only the accepted one counts: no
plot has more than 20 quadrats.

| plot | type | state | surveys | n_quadrats | taxa (gamma) | mean per quadrat | unknown quadrats | unknowns | E | W |
|:---|:---|:---|---:|---:|---:|---:|---:|---:|---:|---:|
| Plot_01 | primary | surveyed | 1 | 20 | 24 | 2.90 | 90% | 8 | 0 | 7 |
| Plot_02 | primary | surveyed | 1 | 20 | 12 | 1.25 | 85% | 7 | 0 | 6 |
| Plot_03 | primary | surveyed | 1 | 20 | 7 | 0.85 | 80% | 8 | 0 | 4 |
| Plot_04 | primary | surveyed | 1 | 20 | 8 | 1.35 | 80% | 12 | 0 | 3 |
| Plot_05 | primary | surveyed | 1 | 20 | 13 | 1.60 | 50% | 4 | 0 | 12 |
| Plot_06 | primary | surveyed | 1 | 20 | 14 | 2.45 | 90% | 12 | 0 | 4 |
| Plot_07 | primary | surveyed | 1 | 20 | 8 | 2.05 | 85% | 10 | 0 | 1 |
| Plot_08 | primary | surveyed | 1 | 20 | 16 | 3.35 | 90% | 15 | 0 | 9 |
| Plot_09 | primary | surveyed | 1 | 20 | 19 | 3.40 | 75% | 10 | 0 | 8 |
| Plot_10 | primary | surveyed | 1 | 20 | 17 | 2.35 | 65% | 4 | 1 | 4 |
| Plot_11 | primary | surveyed | 1 | 20 | 20 | 2.75 | 65% | 5 | 0 | 3 |
| Plot_12 | primary | surveyed | 1 | 20 | 23 | 2.90 | 100% | 17 | 0 | 9 |
| Plot_13 | primary | surveyed | 1 | 20 | 8 | 1.85 | 90% | 4 | 0 | 0 |
| Plot_14 | primary | surveyed | 1 | 20 | 12 | 3.30 | 45% | 7 | 1 | 5 |
| Plot_15 | primary | surveyed | 1 | 20 | 15 | 1.20 | 75% | 7 | 1 | 5 |
| Plot_16 | primary | surveyed | 1 | 20 | 17 | 3.85 | 55% | 6 | 0 | 5 |
| Plot_17 | primary | surveyed | 1 | 20 | 13 | 2.10 | 95% | 9 | 0 | 0 |
| Plot_18 | primary | surveyed | 1 | 20 | 20 | 2.80 | 60% | 8 | 0 | 3 |
| Plot_19 | primary | surveyed | 1 | 20 | 16 | 2.45 | 25% | 3 | 1 | 5 |
| Plot_20 | primary | surveyed | 1 | 20 | 12 | 1.75 | 75% | 5 | 0 | 2 |
| Plot_21 | primary | surveyed | 1 | 20 | 21 | 3.25 | 80% | 9 | 0 | 5 |
| Plot_22 | primary | surveyed | 1 | 20 | 12 | 2.45 | 60% | 9 | 0 | 8 |
| Plot_23 | primary | not surveyed | 0 | 0 | \- | \- | \- | 0 | 0 | 0 |
| Plot_24 | primary | surveyed | 1 | 20 | 7 | 0.50 | 90% | 4 | 0 | 2 |
| Plot_25 | primary | surveyed | 1 | 20 | 24 | 3.60 | 40% | 7 | 0 | 6 |
| Plot_26 | primary | surveyed | 1 | 20 | 12 | 1.95 | 85% | 11 | 0 | 6 |
| Plot_27 | primary | surveyed | 1 | 20 | 17 | 3.05 | 45% | 5 | 0 | 2 |
| Plot_28 | primary | surveyed | 1 | 20 | 13 | 1.00 | 90% | 9 | 1 | 1 |
| Plot_29 | primary | surveyed | 1 | 20 | 21 | 3.60 | 55% | 3 | 1 | 2 |
| Plot_30 | primary | surveyed | 1 | 20 | 18 | 3.50 | 40% | 7 | 1 | 11 |
| Plot_46 | backup | surveyed | 1 | 20 | 6 | 1.65 | 40% | 3 | 3 | 2 |

- `taxa (gamma)` is the number of identified taxa found in all the
  quadrats of the plot.
- `mean per quadrat` is the average number of identified taxa in one 1 m
  x 1 m quadrat. It does not depend on the number of quadrats, so it
  compares plots with different effort.
- `unknown quadrats` is the share of the plot’s quadrats with at least
  one provisional unknown.
- `type` is the plot status in the registration: primary or backup.

30 of the 31 registered plots were surveyed. The plot not surveyed is
Plot_23 (primary and not viable in the registration). The backup plot
Plot_46 was surveyed and has 6 taxa, against a median of 15 for the
surveyed primary plots.

## 5. Assessment of sampling effort (brief item c)

Is 20 quadrats enough to describe the plant community of a plot? The
data hold presence or absence of a taxon in each 1 m x 1 m quadrat, so
the question is answered with incidence-based methods: the quadrats are
the sampling units, and only identified taxa are used (section 8.1). The
assessment is provisional: the thresholds below are working values to
confirm with Natural State.

- 30 plots were surveyed; 30 of them have the 20 quadrats expected, so
  the effort is the same everywhere and differences are in what the
  quadrats found.
- Only 2 of 30 plots approach an asymptote (Plot_07 and Plot_26). For
  the other 28, 20 quadrats do not saturate the species curve.
- Completeness (observed taxa divided by the Chao2 estimate) runs from
  25% to 99% (median 68%). Sample coverage runs from 0.41 to 0.98
  (median 0.88).

### 5.1 Method

For each plot the 20 quadrats are the columns of a taxon-by-quadrat
presence matrix (`R/functions/veg_effort.R`, run by
`R/vegetation/03_summaries.R`). Quadrats without any identified taxon
stay in the matrix, because an empty quadrat is information about
effort.

- **Accumulation curve.** `vegan::specaccum(method = "random")` adds
  quadrats in random order (100 orderings, seed 20261008 in the
  configuration) and the mean number of taxa is drawn against the number
  of quadrats. A curve that is still rising at the last quadrat says
  that more quadrats would still find new taxa.
- **Chao2 richness.** The `iNEXT` package estimates the asymptotic
  richness from the incidence data (30 of 30 plots gave an estimate),
  with a 95% interval. It uses the taxa seen in one and in two quadrats
  only, so it is a lower bound of the true richness.
- **Completeness** is observed taxa divided by the Chao2 estimate.
- **Sample coverage** (`iNEXT`) is the share of the plot’s taxa,
  weighted by how often they occur, that the sample has already found.
- **Gain over the last 5 quadrats** is the number of taxa the mean curve
  adds between quadrat 15 and quadrat 20. It is a plain reading of the
  slope of the curve.
- **Approaches an asymptote** when completeness is at least 0.9 and
  sample coverage is at least 0.95. Both thresholds are provisional.

Two versions exist, as for the other tables. The main version uses the
submissions that were not rejected in ODK (`sampling_effort.csv`). The
sensitivity version also leaves out the quadrats with an error flag
(`sampling_effort_excl_errors.csv`); 8 plot(s) then have fewer than 20
quadrats, which shows in the quadrat column of that file.

### 5.2 Results

| plot | quadrats | observed | Chao2 (95% interval) | completeness | coverage | approaches asymptote |
|:---|---:|---:|---:|---:|---:|:---|
| Plot_05 | 20 | 13 | 51.5 (19.0 to 261.1) | 25% | 0.72 | no |
| Plot_10 | 20 | 17 | 64.5 (24.5 to 317.0) | 26% | 0.79 | no |
| Plot_24 | 20 | 7 | 21.2 (10.2 to 71.5) | 33% | 0.41 | no |
| Plot_30 | 20 | 18 | 52.2 (27.8 to 138.0) | 34% | 0.87 | no |
| Plot_12 | 20 | 23 | 57.2 (30.3 to 183.4) | 40% | 0.80 | no |
| Plot_28 | 20 | 13 | 32.2 (16.8 to 111.2) | 40% | 0.56 | no |
| Plot_03 | 20 | 7 | 14.6 (7.9 to 68.7) | 48% | 0.77 | no |
| Plot_15 | 20 | 15 | 30.8 (18.5 to 86.0) | 49% | 0.60 | no |
| Plot_19 | 20 | 16 | 31.2 (18.9 to 96.7) | 51% | 0.84 | no |
| Plot_21 | 20 | 21 | 40.2 (24.8 to 119.2) | 52% | 0.86 | no |
| All plots (median; asymptote: count) | 20 | 14.5 | 24.2 | 68% | 0.88 | 2 of 30 |

The ten plots with the lowest completeness are shown; all 30 plots are
in `outputs/vegetation/sampling_effort.csv`, with the gain over the last
5 quadrats (median 1.71 taxa, range 0.37 to 3.35). Per plot, the lowest
completeness is 25% and 8 plots stay under 50%. 27 of 30 plots have a
coverage below 0.95.

![Species accumulation curves of the surveyed plots: mean number of
identified taxa (line) against the number of quadrats added in random
order, one panel per plot. Description: most curves are still rising at
the twentieth quadrat; a few flatten out near the end; plots differ
widely in the height of the curve.](figures/veg_accumulation.png)

The Chao2 intervals are wide for the plots with many rare taxa (the
upper limit exceeds three times the observed richness in 21 plots), so
the completeness of a single plot is uncertain; the pattern across plots
is the robust part. The sensitivity version gives 2 plot(s) that
approach an asymptote and a median completeness of 68%, against 68% in
the main version.

### 5.3 What this means

- **The brief’s question.** 20 quadrats do not saturate the species
  curve for 28 of 30 plots. More quadrats would still find new taxa
  there.
- **Plot comparisons.** The richness of a plot is a lower bound.
  Completeness varies a lot between plots (25% to 99%), so a plot with
  fewer taxa may only be a plot that was sampled less completely. Plot
  richness comparisons should account for it, for example by comparing
  at equal coverage or by using the estimate with its interval, not the
  observed count alone.
- **For the data provider.** Adding quadrats in the plots with low
  completeness would improve their richness estimate. This is a
  statement about the adequacy of these data, not a recommendation on
  the survey design.

### 5.4 Decisions, alternatives and status

- **Incidence-based, quadrats as units.** Only presence or absence
  exists, so abundance-based estimators (Chao1, rarefaction on
  individuals) do not apply.
- **Chao2 and coverage together.** Alternative: the curves alone, which
  give no number and no rule for “enough”. Alternative: Chao2 without
  coverage, which depends on one estimator that is unstable with few
  rare taxa. Both are reported, and the asymptote rule needs both.
- **Thresholds 0.9 and 0.95.** Common working values for “near
  complete”; other values would change the count of 2 plots (a lower
  completeness threshold would add plots). They are provisional and to
  confirm with Natural State.
- **Identified taxa only.** Same rule as for richness (section 8.1):
  provisional unknowns are not stable units.
- **Random order, 100 orderings.** The quadrats of a transect are
  spatially ordered, so the field order would mix spatial structure into
  the curve; random order gives the expected curve. The seed is fixed
  for reproducibility.
- **Status.** Provisional; the estimates and the thresholds are written
  in `rulebook.md`.

## 6. Map of transect locations (brief item d)

This section shows where the plots are and where the quadrats of a few
plots were recorded, coloured by the worst flag of the plot (or of the
quadrat). Colour is the severity of the worst flag: error, then warning,
then info; a plot without a flag is green. The colours are defined once
in the configuration and are also used in the dashboard (section 6.3).
Data are anonymised, so real coordinates are shown.

### 6.1 All plots

The overview places the 30 registered plots that have coordinates in the
plot register (all 30 surveyed plots; the plot centre is the geopoint
stored as “latitude longitude altitude accuracy” in the plot entity
list). 1 registered plot (Plot_23, not viable, not surveyed) has no
coordinates and cannot be drawn; it is named in the figure. The backup
plot (Plot_46) is drawn as a diamond. Distances use EPSG:32637 (UTM zone
37N), the zone used by the spatial checks. There is no web basemap, so
the figure works offline.

![Map of the plot locations. Circles are primary plots that were
surveyed, the diamond is the backup plot. Fill is the worst flag of the
plot: dark red error, amber warning, grey info only. A scale bar of 2 km
and a north arrow are drawn. Description: 30 points in a band about 14
km wide from west to east and 5 km from south to north; three points lie
to the north-east, away from the main band; most points are amber, with
dark red points in the middle and the south-east and two grey points in
the west.](figures/veg_transect_map.png)

What stands out:

- 8 surveyed plots have an error flag (dark red) and 20 have at worst a
  warning. Only 2 plots (13 and 17) have no warning or error. No plot is
  free of flags, because every surveyed plot has info-level flags
  (mostly unknown taxa). Error plots are spread along the whole band, so
  the errors do not point to one area. They are data-entry errors
  (quadrats marked as having extra species with none recorded, one extra
  species without a name), not location problems.
- Four error plots (10, 14, 19, 30) lie in the south-east cluster, so a
  field team visiting that cluster can check four submissions in one
  trip.
- The backup plot Plot_46 lies north-east next to plot 05 and about 5 km
  north of the main band; it has 3 error flags (the same kind of
  data-entry error).
- Plots 05, 09 and 46 are isolated to the north-east. They need their
  own trip, which matters for follow-up visits, not for data quality.

### 6.2 Quadrats along the transects

The second figure shows the quadrat fixes of four plots in metres from
the plot centre, with the line joining the quadrats in numbering order.
The dashed circle has the radius of the belt reach (half the 50 m length
and half the 5 m width, 25.1 m); the check SPA-04 flags a quadrat when
it lies beyond this reach plus the GPS accuracy of its fix and of the
plot centre. The colour is the worst flag of the quadrat (any check).
Plots 01, 05 and 11 each have quadrats beyond the belt; plot 16 stays
inside it.

![Quadrat positions of plots 01, 05, 11 and 16 in metres from the plot
centre (cross), joined by a line in quadrat order. A dashed circle marks
the reach of the belt; a 20 m scale bar and a north arrow are drawn.
Description: in plot 01 one quadrat lies about 75 m to the north-west of
the centre while the others cluster near the circle; in plot 05 a group
of about eight quadrats lies north of the circle, outside the belt; in
plot 11 one quadrat is about 50 m north; in plot 16 all quadrats sit
along an east-west line inside the
circle.](figures/veg_transect_zoom.png)

- Plot 01: one quadrat (18) is 74.6 m from the plot centre, far beyond
  the belt; the line to it shows one fix far from the others; the other
  19 quadrats form a normal transect.
- Plot 05: the whole transect is shifted about 30 m north of the plot
  centre (6 quadrats flagged). Either the transect was laid out from
  another point or the plot centre is wrong; the data cannot tell which.
  This is the clearest case for a field team to check.
- Plot 11: one quadrat about 50 m away, like plot 01 (a single fix).
- Plot 16: a clean example, all fixes inside the belt.
- Overall 35 quadrats in 18 plots are flagged by SPA-04 (warning). They
  are warnings, not errors, because the GPS may drift under tree cover
  and the plot centre is stored with 3 to 5 m accuracy.

### 6.3 Interactive dashboard

An interactive version of these views is an extra, not part of the
deliverable: the report stands alone. The dashboard has four pages
(summaries with survey and plot tables, a map of the plots coloured by
worst flag severity with a popup per plot, a flags table that can be
filtered by severity, check and plot, and the sampling effort). It reads
the same files as this report (`outputs/vegetation/` and `figures/`) and
runs no new analysis.

- Source: [`dashboard/`](dashboard/) (`dashboard.qmd`, Quarto
  `format: dashboard`); rendered page: `docs/index.html`.
- Planned address, once GitHub Pages is switched on:
  <https://albansagouis.github.io/naturalstate-take-home/>.
- The Natural State logo and colours are used for this mock-up only.

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

The plot and headline tables above exist a second time without the
quadrats that carry an error flag (`survey_summary_excl_errors.csv` and
`plot_summary_excl_errors.csv`). Both versions leave out the rejected
submissions. What is left out is listed in
`outputs/vegetation/excluded_records.csv`:

- the 10 quadrats that carry an error flag (only the quadrat, not the
  rest of the submission);
- the whole submission for an error that is not tied to a quadrat (none
  in these data);
- the 2 submissions rejected in ODK, with their 0 quadrats; they are
  left out of both versions, not only of this one.

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

Per plot, the gamma richness changes in 4 of 30 plots (largest fall 1
taxa, median change 0). The mean number of taxa per quadrat moves by at
most 0.11. The data-set richness is unchanged (a taxon only found in a
left-out quadrat would lower it). The rank correlation of gamma richness
between the two versions is 1.00. The flag counts in the sensitivity
tables are the same as in the main tables (they describe the
submissions); only quadrats, taxa and indices are recomputed.

## 8. Decisions and limits

### 8.1 What counts as a species

Distinct identified taxa are the names picked from the species list plus
the names typed in the extra-species repeat, after harmless typing
differences are removed: outer and double spaces are trimmed, spaces
become underscores, the first letter is a capital. Each taxon is counted
once, however often it was recorded. A record such as
`herb_104 (Justicia divaricata )` is read as its proposed name, because
the team named it (45 records).

Provisional unknowns are the plain placeholders (`herb_017`), raw UUID
text and records with no name: 712 of 2243 records. They are counted
separately and are not in the headline richness, because the same plant
can sit behind several labels and one label is not a stable taxon.
Including them would change the data-set richness from 70 to 152; the
totals file (`summary_totals.csv`) and the `richness_upper_bound` column
of `plot_summary.csv` give the same view. A misspelling (for example
`Brachiara`) is not merged: it stays a separate taxon and is flagged in
the checks (SPE-06) for the field team.

### 8.2 Diversity indices

There is no abundance, only presence in each of the quadrats, so no
abundance-based diversity index exists, and a diversity index would say
little about the vegetation. The tables therefore report richness only
(identified taxa, and with the provisional unknown labels added).
Shannon’s H on quadrat frequencies (H = -sum(p ln p), with p the share
of the plot’s total quadrat frequency) is used for one purpose: check
PLT-09 flags a plot whose H is more than 3 scaled median absolute
deviations from the median of the plots, as a sign of an incomplete,
repeated or misread species list. It needs at least 10 plots and raises
an information flag for the data manager. On the sample it flags 0
plots. Alternatives: report H in the plot table (rejected: invites
reading it as a biodiversity result when twenty small quadrats cannot
support one), Simpson’s index (the same objection), and no outlier check
(rejected: a plot with a single recorded taxon would pass unnoticed).

### 8.3 What the sensitivity version leaves out

A quadrat with an error flag is left out and the other quadrats of the
submission stay: the errors in these data are about one quadrat (extra
species announced but not recorded; an extra species without a name) and
say nothing about the other 19. A submission rejected in ODK is left out
of both versions as a whole: the reviewer already judged it unusable,
and counting it would give a plot the quadrats of two visits. The data
themselves are never changed: the tables are filtered views. Warnings
and info flags never exclude a record.

### 8.4 Limits

- Presence or absence only: no cover or counts, so no abundance-based
  diversity and no density.
- 20 quadrats per plot, 1 m x 1 m each, in one visit: richness is what
  those quadrats found, a minimum for the plot.
- The sampling-effort estimates (section 5) rest on 20 quadrats per plot
  and provisional thresholds; Chao2 is a lower bound and its intervals
  are wide.
- 712 records (32%) are provisional unknowns, and the taxa behind them
  may be identified ones. If an unknown label were linked to a named
  taxon, richness would fall for plots where the same plant is counted
  twice and rise for plots whose unknowns are new taxa. Many of the
  `herb_NNN` labels with a proposed name also appear as a plain label in
  other quadrats (22 of 44), so a link table maintained by the data
  manager would remove most of the problem. It is not applied here
  because it would be a change to the data.
- Whether the reviewer was right to reject the two submissions is not
  checked: the report follows the ODK review state. The accepted and the
  rejected submission of a plot differ in duration, and in recorder for
  one plot, but the data do not say why one was rejected.
- A quadrat count per plot does not test whether the quadrats were
  placed as the protocol asks; the spatial checks are in the flag list.

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
