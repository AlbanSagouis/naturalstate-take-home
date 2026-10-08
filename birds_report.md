BirdNET species thresholds: methods report (first draft)
================
Alban Sagouis
2026-10-08

## 1. TL;DR

- **What I did.** I followed the Wood & Kahl (2024) recipe to turn 551
  expert-validated BirdNET clips into a confidence threshold per
  species, for four species, and added checks for model fit, recorder
  effects and day-part effects (#3).
- **Key result.** Only the Abyssinian Nightjar gets a threshold: 0.667
  (bootstrap interval 0.43 to 0.83). The other three (African
  Black-headed Oriole, Three-banded Plover, Red-billed Firefinch) get
  `no_threshold` because the validation sample cannot support a fit.
- **Key decision.** One method and one precision target (0.99) for every
  species. A species that fails the data gates is not given a
  special-case threshold. It is given a request for more validation.
- **What is uncertain.** The 0.99 is a claim from the model, not
  something observed. The nightjar threshold rests on 33 wrong clips,
  almost all from two recorders and all from the evening, so its reach
  beyond those conditions is not established.
- **What I ask of the experts.** Random validation clips across more
  areas, periods and recorders for every species, and especially random
  nightjar clips at night (section 9).

## 2. Data and how it was validated

BirdNET gave 29,491 predictions. The experts validated 551 clips across
four species. Each clip was marked right (outcome 1) or wrong (outcome
0). I call these right clips and wrong clips throughout.

| Species | Wrong clips | Right clips | Lowest score | Highest score |
|:---|---:|---:|:---|:---|
| Abyssinian Nightjar | 33 | 117 | 0.102 | 1.000 |
| African Black-headed Oriole | 0 | 150 | 0.104 | 0.989 |
| Red-billed Firefinch | 95 | 6 | 0.101 | 0.907 |
| Three-banded Plover | 1 | 149 | 0.102 | 0.994 |

### 2.1 The validation sample is enriched, not random

Wood & Kahl step 1 asks for validation clips spread across the whole
confidence range, so that the curve has data at both ends. This is also
why the share of right clips in the sample is not the precision of
BirdNET in the full data.

I do not know how the clips were chosen. They score higher than the
predictions as a whole (nightjar median 0.65 against 0.32), which fits a
sample enriched for high scores. The firefinch is the exception (0.14
against 0.14). If the clips were also picked for being clear examples,
the fitted curve would look better than it should, and I cannot rule
that out.

### 2.2 Linking validations to predictions

The validation file has no prediction ID, so I link on recording,
species and score as a best effort and report how well it works. Nothing
in the thresholds or the labels depends on that link. Matching on the
exact recording name leaves 298 of 551 validations unmatched (only 263
of the 551 recording names are found verbatim in the predictions). The
cause is recorder clock drift: 288 validation recording names have a
seconds field other than `00`, while the predictions always end in `00`.
Snapping start times to the nearest hour, and comparing scores at three
decimals, gives 458 unique matches, 65 ambiguous and 28 unmatched. Of
those unmatched, 25 are rounding differences under 0.001 and 1 recording
is absent from the predictions.

The missing prediction ID is an upstream data issue. The fix is for the
validation export to carry the clip’s start position in the recording
(or a prediction ID), the same recording identifier as the predictions,
and scores at full precision. The handoff to Tech (#5) spells this out.

## 3. The model

For each species I fit a logistic regression of the clip outcome (right
or wrong) on the BirdNET confidence, after transforming the confidence
to the logit scale (the log of odds, which stretches the 0 to 1 range so
scores near 1 are not squeezed together). This is the Wood & Kahl
method. The fitted curve gives the chance that a prediction is right at
any score. The threshold is the score at which that chance reaches 0.99,
found by solving the fitted curve for 0.99 (0.99 is set in the config
file as the target precision).

### 3.1 One addition of mine

A confidence of exactly 1.0 has no finite logit, and the Wood & Kahl
code does not handle it. I set those scores to 0.9999 before the
transform. Moving this value to 0.999 or 0.99999 does not change the
nightjar threshold at three decimals (0.667 in all three cases).

### 3.2 What the confidence column is

The confidence column is the bounded 0 to 1 BirdNET score. The BirdNET
sensitivity setting is not recorded in the data, but it does not change
the threshold in confidence units.

## 4. Who gets a threshold

Two separate questions.

### 4.1 Question 1: do the data allow a threshold?

This decides whether a species gets one. There are two gates, applied
identically to every species:

1.  The fitted threshold lies inside the range of scores that were
    validated.
2.  The smaller of the two outcome groups (wrong clips or right clips)
    has at least 30 clips.

The 30 is deliberately strict. It is set in the config file and could be
relaxed if expert validation time makes it unreasonable. The table shows
what happens at 5, 10 and 30.

| Minimum in smaller group | Species passing | Which               |
|-------------------------:|----------------:|:--------------------|
|                        5 |               1 | Abyssinian Nightjar |
|                       10 |               1 | Abyssinian Nightjar |
|                       30 |               1 | Abyssinian Nightjar |

The answer is the same at 5, 10 and 30: only the nightjar passes
(smaller group of 33). The firefinch has a smaller group of 6, so it
would pass the count gate at 5, but its fitted threshold (0.998) sits
above every validated score (highest 0.907), so it fails the range gate.
Plover (1 wrong clip) and oriole (0 wrong clips) fail the count gate at
every setting.

Stability under bootstrap is reported, not a gate. The bootstrap
(resampling with replacement) redraws the validated clips, as many as
the original sample, and refits the curve 2,000 times. I report the
share of bootstrap fits that fail and the interval of the bootstrapped
thresholds. Today the count and range gates already give the same
answer, so a third gate would add a number to defend without a new
result. I keep the numbers because refits will need them (section 8).

### 4.2 Question 2: does it generalise?

A threshold is fitted on the clips the experts validated. Question 2
asks whether it would still hold for clips from other recorders, other
hours of the day, other dates or other places.

This question does not decide whether a species gets a threshold: only
the two gates in 4.1 do. Instead, the answer is reported next to the
threshold as its **scope**, meaning the conditions it was actually
checked under. The checks are in section 7. For the nightjar they show
that the threshold rests mostly on evening clips from a few recorders,
so its reach beyond those conditions is not established.

### 4.3 One method and one precision target for every species

No species gets a stricter or looser cutoff than the method gives. More
certainty is available (more validation, a more cautious cutoff), but it
costs expert time and cannot reasonably be afforded for every species. A
stricter cutoff for some species would lower their counts for reasons
unrelated to biology and distort relative abundances across species. One
limit to state: a common precision target does not make recall equal
across species. Wood & Kahl note this and say recall may matter more for
between-species comparisons. I have no recall figure in the data, so I
do not report one here.

## 5. Results per species

| Species | Wrong clips | Right clips | Smaller group | In range | Threshold estimate | Bootstrap interval | Failed bootstrap fits | Outcome |
|:---|---:|---:|---:|:---|:---|:---|:---|:---|
| Abyssinian Nightjar | 33 | 117 | 33 | TRUE | 0.667 | 0.43 to 0.83 | 0% | fitted threshold |
| African Black-headed Oriole | 0 | 150 | 0 | FALSE | none | none | 100% | no_threshold |
| Red-billed Firefinch | 95 | 6 | 6 | FALSE | 0.998 | 0.95 to 1.00 | 14% | no_threshold |
| Three-banded Plover | 1 | 149 | 1 | TRUE | 0.259 | 0.21 to 0.80 | 37% | no_threshold |

The threshold estimate is shown for every species the model could fit,
for transparency. It becomes a threshold only where the outcome says so.
The plover estimate comes from a single wrong clip and the firefinch
estimate lies outside the validated range.

The nightjar threshold is 0.667. In the validation sample, 74 of the 74
clips at or above it were right. With so few clips, the lower end of a
95% interval on that precision is 0.951, so the data do not rule out a
real precision below 0.99.

![Validated clips and the fitted curve per species. The red line marks
the threshold, fitted species only; the dashed line is a 0.99 chance of
being correct. Description: Four panels, one per species, showing
validated clips as right (top) or wrong (bottom) against BirdNET
confidence. Only the Abyssinian Nightjar panel has a fitted curve and a
vertical threshold line near 0.67.](figures/birds_threshold_fits.png)

Labelling uses the point estimate: predictions at or above the fitted
threshold are `observed`. The bootstrap interval is stored and reported
next to it, but there is no second, more cautious cutoff.

## 6. Model checks

### 6.1 Calibration

The figure groups the validated clips into score bands and compares the
share the experts found right (black, with a 95% interval) with what the
fitted curve predicts (red). Agreement means the curve describes the
data in that band.

![Calibration by score band: share found right against the fitted curve.
Description: Two panels, nightjar and firefinch. Black points with
intervals show the share of right clips per score band; a red line shows
the fitted curve. For the nightjar the points sit close to the red line;
the top band holds many clips and sits at
1.](figures/birds_calibration.png)

For the nightjar the points sit close to the curve in most bands, and
the top band (scores from 0.702, 74 clips) has 74 right clips against
0.999 predicted. For the firefinch the shares are small and the
intervals wide, so there is no clear misfit but little else to learn.

### 6.2 AIC

I computed AIC (a score that compares models by fit, penalising extra
terms) for three models, as in the Wood & Kahl tutorial: no score, score
on the confidence scale, and score on the logit scale. I did not use it
to choose a model. We use only the logit-scale model. Difference from
the best model, per species:

| Species              | No score | Confidence scale | Logit scale |
|:---------------------|---------:|-----------------:|------------:|
| Abyssinian Nightjar  |     81.5 |              0.0 |         1.0 |
| Red-billed Firefinch |      2.3 |              0.4 |         0.0 |
| Three-banded Plover  |      0.0 |              1.1 |         1.2 |

For the nightjar the score clearly matters and the two scales are close
to tied. For the firefinch the score barely helps. For the plover the
comparison is not meaningful with one wrong clip.

### 6.3 What the checks show

They show that the nightjar curve fits the clips we have. They do not
show that it holds for other recorders, times or places; that is section
7.

## 7. Sensitivity analysis: recorder, day-part, date

### 7.1 Why

Wood & Kahl warn that a threshold only holds for the conditions it was
validated under, but their tutorial does not run the check. I made it a
routine step. Device, date and hour come from the recording names.
Recorder model and sample rate are not in the data.

### 7.2 Recorders

For the nightjar, 33 wrong clips sit on 4 of 15 recorders, and 88% of
them are on two recorders (RBS79 and RBS75), which have no right clips.
Recorder and score therefore cannot be separated. The firefinch is the
comparison: its wrong clips are spread over 22 recorders and the top two
hold 36%.

![Validated clips by recorder. Red marks the two recorders holding most
of the species’ wrong clips. Description: Two panels, nightjar and
firefinch, showing validated clips against confidence. Red points mark
clips from the two recorders with most wrong clips; for the nightjar
they cluster among the wrong clips at low
scores.](figures/birds_device_effects.png)

### 7.3 Leave-one-recorder-out (a jackknife at recorder level)

I refit the nightjar threshold dropping each recorder in turn. It stays
between 0.60 and 0.70 (full data 0.667). Dropping both of the two
recorders with most wrong clips gives 0.686, with 4 wrong clips left.

### 7.4 Device-level bootstrap against clip bootstrap

Resampling recorders (with replacement) instead of clips gives 0.44 to
0.82 for the nightjar, against 0.43 to 0.83 from resampling clips. The
two agree, so treating clips as independent does not make the interval
look better than it is. For the firefinch the recorder-level interval is
0.81 to 1.00, with 12% of fits failing, and every leave-one-out value
stays between 0.988 and 1.000, outside the validated range.

### 7.5 Day-part

| Species | Day-part | Wrong clips | Right clips | Estimable | Delta AIC |
|:---|:---|---:|---:|:---|---:|
| Abyssinian Nightjar | evening_16_23 | 33 | 74 | FALSE | n/a |
| Abyssinian Nightjar | night_00_06 | 0 | 43 | FALSE | n/a |
| Red-billed Firefinch | dawn_night_18_05 | 6 | 1 | TRUE | 1.281 |
| Red-billed Firefinch | day_06_17 | 89 | 5 | TRUE | 1.281 |

All 33 nightjar wrong clips are from hours 16 to 23, and all 43 clips
from hours 0 to 6 are right. A day-part effect cannot be estimated for
the nightjar because the night group has no wrong clips. Device, time of
day and score cannot be separated in this sample. Night looks cleaner,
so applying the evening-based threshold at night errs on the safe side,
but that is unverified. For the firefinch, adding a day-part term does
not improve the fit (delta AIC 1.3), though only 7 of its clips are dawn
or night.

### 7.6 Date and season

Nightjar validated clips by week of the recording period:

| Week | Clips | Wrong clips | Right clips |
|:-----|------:|------------:|------------:|
| 1    |    11 |           1 |          10 |
| 2    |    96 |          14 |          82 |
| 3    |    42 |          17 |          25 |
| 4    |     1 |           1 |           0 |

Date cannot be separated either. Nightjar wrong clips rise from 1 of 11
clips in week 1 to 17 of 42 in week 3, but 29 of the 32 wrong clips in
weeks 2 to 4 come from RBS79 and RBS75, which were validated only
between 27 June and 11 July. Among the other recorders, wrong clips are
rare in every week (1 of 11 in week 1, 2 of 84 in week 2, and 1 of 26 in
week 3). Date is a potential effect worth testing once validation covers
more weeks and recorders, but this sample cannot tell it apart from the
recorder effect.

Season is a separate reason for caution. Vocal activity is seasonal, and
breeding calls in particular do not happen all year, so the kind of
sound BirdNET scores can change through the year. All validated clips
come from 23 days in June and July 2023, a single season. A threshold
fitted on them may not hold at other times of year, which is why Wood &
Kahl advise another round of validation when the season changes.

### 7.7 Reading

The nightjar threshold is stable to dropping any one recorder and to
resampling recorders, so the number is stable. Its scope is not
established: it is estimated mostly from evening clips and from a few
recorders.

### 7.8 This should run on every refit

The recorder check, the device bootstrap and the day-part check are
cheap once the data exist, and a refit is exactly when new recorders,
hours and places enter the sample.

## 8. Planning for refits

When new validations arrive and thresholds are refitted, the same
diagnostics table (clip counts, range check, bootstrap failure share and
interval, calibration, recorder and hour checks) can feed a monitoring
dashboard for the senior data scientist and Biometrics. They can then
see at a glance whether a refit is trustworthy. The recorder and
environment sensitivity analysis is their job, run at project level on
every refit. There is one recorder per SD card, so the comparison is
across devices within a project.

## 9. Requests to the ornithologist and Biometrics

1.  **Random validation clips for every species**, drawn across more
    areas, recorders, hours of the day and seasons, and across the whole
    recording period for each recorder, so the sample captures the
    variation in each species’ calls and does not tie recorder, hour and
    date together. Species with no threshold (oriole, plover, firefinch)
    need this first.
2.  **Random nightjar clips at night.** Today every wrong nightjar clip
    is from the evening.
3.  **Metadata.** Tech should pass the recorder, BirdNET version and
    settings, site, habitat and date-time with every prediction. The
    full list is in the handoff to Tech (#5).

## 10. Limits

- **Scope of the nightjar threshold.** 33 wrong clips, 88% on two
  recorders, all in the evening. It is labelled for all hours, with that
  evidence scope stated.
- **One grid and a short period.** All validated clips come from one
  grid over 23 days (2023-06-20 to 2023-07-12). The grid is Grid2: every
  one of the predictions comes from it. The days sit in one season, so
  nothing in this sample tests whether the thresholds hold across the
  year.
- **Recall** is not equalised across species by a common precision
  target.

## 11. Observation labelling (#4)

### 11.1 The rule

Every prediction gets two new fields. `observation_status` is `observed`
when the species has a threshold and the confidence is at or above it,
`below_threshold` when the species has a threshold and the confidence is
below it, and `no_threshold` when the species has none. `observation`
holds the species name for `observed` rows and is empty otherwise. The
experts’ validations do not override the model’s label.

### 11.2 Result

| Species                     | observed | below_threshold | no_threshold |
|:----------------------------|---------:|----------------:|-------------:|
| Abyssinian Nightjar         |    3,147 |           7,040 |            0 |
| African Black-headed Oriole |        0 |               0 |       18,054 |
| Red-billed Firefinch        |        0 |               0 |          235 |
| Three-banded Plover         |        0 |               0 |        1,015 |

Of the 29,491 predictions, 3,147 (10.7%) are observations, 7,040 (23.9%)
are below threshold and 19,304 (65.5%) have no threshold. The labelled
file is `outputs/birds/birdnet_predictions_labelled.csv`: the 13 raw
columns plus the two new ones, one row per prediction.

### 11.3 Limits

Only the nightjar has observations. The oriole alone is 61% of all
predictions and has none until it is validated more widely (section 9).
The nightjar labels apply to all hours of the day, but its threshold was
checked only on evening clips from a few recorders (sections 7 and 10).

## Reproduce

The numbers in this report come from the files in `data/processed/`,
`outputs/birds/` and the raw predictions. The report is produced by
`rmarkdown::render("birds_report.Rmd")`. To regenerate and check the
numbers, run from the project root in a fresh R session:

``` r
source(here::here("R", "birds", "01_load_validate.R"))
source(here::here("R", "birds", "02_threshold_evidence.R"))
source(here::here("R", "birds", "03_robustness_checks.R"))
source(here::here("R", "birds", "04_label_observations.R"))
testthat::test_dir(here::here("tests", "testthat"))
rmarkdown::render(here::here("birds_report.Rmd"))
```
