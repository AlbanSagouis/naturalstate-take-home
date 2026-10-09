Rulebook: vegetation
====================

Running log of analytical decisions: the judgement calls that would otherwise live only in code
or in my head. Write each one down the day it is made, with the topic, the decision, and why.
Each decision is also added as a comment on its GitHub issue.

# Vegetation checks and severities

- **Flag, never fix**: the QA/QC pipeline never modifies the data. *(from the brief)*

- **Load and join never drop or change a record**: the four ODK exports are read as text with raw
  column names kept, joins are left joins with `relationship = "many-to-one"`, and the row counts
  are asserted equal to the raw files. *(#7)* Orphans, unmatched lookups and duplicate keys become
  rows in `veg_key_integrity.csv` and `veg_input_findings.csv`, which feed the flags of #8. The
  alternative (inner joins with `unmatched = "error"`) would abort on the first data error and
  hide the rest.

- **Two kinds of input check**: structural breakage (missing file or required column) aborts
  with `cli_abort`; data errors never abort and return findings. *(#7)* A broken input cannot be
  analysed, a data error is the thing the pipeline exists to report.

- **Plot join key**: the survey column `plot_selection-selected_plot_uuid` matches the `__id` of
  `vegplots.csv`; the `plot_uuid` column of `vegplots.csv` matches the registration form. *(#7)*
  The status comes from `plot_selection-get_plot_status` because `plot_selection-plot_status` is
  blank in every row. Joining on `plot_uuid` directly would match 0 of 32 surveys.

- **Species ids are split on whitespace or `<br/>`**: the export separates the selected species
  UUIDs with a space, the derived name lists use `<br/>`. *(#7)* Accepting both costs nothing and
  survives a change of the export format.

- **Long species table keeps the text as received**: `selected_list` rows are resolved against
  `species.csv` (unresolved UUIDs kept with NA name); `additional_repeat` rows carry
  `validated_name` unchanged, whatever its format. *(#7)* Normalising names is a flag in #8, not a
  fix here.

- **Severity logic**: error = breaks an SOP step or a data rule, or makes a record contradictory or
  unusable; warning = suspicious or off tolerance, needs a human decision and may be fine; info =
  context or follow-up that needs no correction. *(provisional, #8; to confirm with Natural State)*
  One severity per check, fixed in the catalogue (59 checks), so a flag count per check is also a
  count per severity. Alternative: severity per flag (for example by distance), rejected because the
  flags table would then no longer reconcile with a tracked specification Tech can implement.
  Final flags: 963 = 11 error, 148 warning, 804 info (706 of the info flags are provisional
  `herb_NNN` labels).

- **Catalogue is the specification**: `outputs/vegetation/check_catalogue.csv` has id, level,
  severity, rule, columns, SOP reference, message template, who can resolve it, plus a ninth column
  `what_to_check` (the action text used in the field list). *(provisional, #8)* Each check is one
  function `veg_chk_<id>(ctx, config)` that takes the staged tables and returns rows (zero rows
  when it finds nothing, never an error); the runner adds the survey context and fills the message.
  Alternative: one script of ad hoc filters, rejected because Tech could not implement the checks
  from it.

- **Duplicate submissions**: a rejected submission whose plot and survey also have an accepted one
  is info (STR-07; Plot_18 and Plot_21, 2 flags); two or more accepted submissions for one plot and
  survey are a warning (STR-08, 0 flags); a plot whose submissions are all rejected is an error
  (STR-09, 0 flags). *(provisional, #8)* The rejection is the resolution of the duplicate, so it
  needs no action, while an unresolved duplicate means nobody decided which visit counts. The
  rejected rows stay in the data, the survey table and the flags, but not in the plot and headline
  counts (see "Rejected submissions" below). Alternative: flag the rejected ones as warning, rejected because it asks the field
  team to fix something already resolved.

- **Canonical species name regex**: `^[A-Z][a-z]+(-[a-z]+)?_[a-z]+(-[a-z]+)?$`. *(provisional, #8)*
  Derived from the SOP definition (genus and specific epithet joined by an underscore, no
  authorship, section 2) and section 5 step 7 (names separated by a single space). A hyphen is
  allowed in the genus or epithet because the typed list contains `Pechuel-loeschea`. Applied to
  the text the team typed (`new_missing_canonical`, 45 rows): 45 of 45 fail, all because they use a
  space, and 45 of 45 pass once spaces become underscores and the outer spaces are trimmed. The
  form itself only rejects `,;()` in that field. The quick-look figure "233 of 273" was not
  reproduced, since the counting basis is unknown; `species.csv` and `species_extra.csv` labels
  use a space too, so the regex is not applied to them. Alternative: also allow a space, rejected
  because it would accept exactly what the SOP forbids.

- **Likely misspellings**: a typed name is flagged when it is within 2 edits (`utils::adist`) and
  15 percent of its length of a different name on the species list, or when its genus is exactly one
  letter off a listed genus and has at least 6 letters. *(provisional, #8)* Whole-name matching found
  nothing (the list has 370 names and the typed names are not near any), the genus rule found 3
  (`Ipomea` for `Ipomoea`, `Brachiara` for `Brachiaria`, two `Ipomea`). Conservative on purpose:
  a name within the limit is a suggestion for a human, never a correction. Alternative: fuzzy match
  with a larger distance, rejected because it proposes unrelated species (`Crotolaria` is 12 edits
  from its closest whole name).

- **Spatial tolerances**: distances are metric, in the UTM zone of the points (EPSG:32637 for this
  site, chosen from the mean coordinate), using sf. *(provisional, #8)* A quadrat is flagged
  (SPA-04, warning) when it is farther from the plot midpoint (vegplots geometry) than the belt
  reach sqrt(25^2 + 2.5^2) = 25.1 m plus the reported accuracy of the quadrat fix plus that of the
  midpoint (5 m if unknown): 35 quadrats in 18 plots. The background geopoint uses the same
  tolerance (SPA-05, 3 surveys). Consecutive quadrats are at most sqrt(5^2 + 5^2) = 7.1 m apart
  (5 m along the tape, alternating sides) plus 2 x sqrt(acc1^2 + acc2^2) (SPA-06): 51 pairs, info
  only, since the plain sum of accuracies flagged a fifth of all pairs, which is GPS noise. The SOP
  has 20 quadrats at 10 marks of 5 m (two per mark, one each side), so the farthest quadrat is
  25.1 m from the midpoint. Alternative: a fixed 30 m cut-off, rejected because it ignores the
  reported accuracy.

- **Accuracy limit by level**: a quadrat geopoint above 5 m is an error (SPA-01, 0 flags, the
  maximum is exactly 5); the end-of-survey background geopoint above 5 m is a warning (SPA-02, one
  survey at 5.066 m); a blank background geopoint is info (SPA-03, 3 surveys). *(provisional, #8)*
  The SOP (section 4.2) asks for 5 m or better, but only the quadrat geopoints enter the protocol;
  the background geopoint is context.

- **Timestamps are compared in UTC with their offset**: the 15 surveys that "start more than 60 s
  after submission" in the quick look are an artefact of dropping the `+02:00` offset (reproduced:
  15 with the offset ignored, 0 with it honoured), so TIM-03 raises no flag. *(provisional, #8)*
  Duration outside 15 to 180 minutes is a warning (1 survey at 236 minutes); submission more than
  12 hours after the end is info (1 survey at 16.8 hours). The limits are judgement, not SOP values.

- **Registered before surveyed uses the registration form's end time**: the server upload time
  (`SubmissionDate`) of 3 registrations is later than the survey start (Plot_03, Plot_08, Plot_22)
  but the form end time is earlier in every case, so PLT-05 (error) has 0 flags and PLT-08
  (info) has 3. *(provisional, #8)* Registration on the device precedes the upload, and the plot
  was selectable in the picker. Alternative: use the upload time, which would raise 3 errors that
  are delayed uploads.

- **Backup plot**: surveying a backup plot is info (PLT-06; Plot_46). *(provisional, #8)* The SOP
  allows a backup when the primary is non-viable; the registration lists one non-viable primary
  (Plot_23) and the data hold no link between a backup and the primary it replaces, so that link
  cannot be checked.

- **Quadrats-with-species summary is a form calculation, flagged as a warning for Tech**: the form's
  `survey_end-quadrats_with_species` equals the number of quadrats with additional-species rows
  and ignores quadrats whose species were all picked from the list (matches in 32 of 32 surveys),
  so it understates in 23 surveys (CON-06). *(provisional, #8)* The SOP (section 5 step 13) tells
  the team to judge plausibility from that figure. Warning rather than error because the field team
  cannot cause or fix it.

- **Blank species count where 0 is expected is info**: 7 quadrats with `herbs_present = no` have a
  blank count (QUA-04). *(provisional, #8)* The zero is implied by the answer and the staged tables
  keep the blank as received; the downstream summaries treat it as 0.

- **Reused labels with a stray space are reported once per submission**: the extra-species label
  `Evolvulus alsinoides ` (trailing space) is reused in 64 records; SPE-12 gives one flag per
  submission and label (19 flags) and the fix is one edit in the entity list. *(provisional, #8)*
  Flagging each quadrat would bury the 2 typed-name spacing errors (SPE-05).

- **Provisional unknowns stay as info and are flagged per quadrat**: `herb_NNN` records
  (SPE-03, 706 flags, 82 distinct labels in the staged data) need a voucher and a later
  identification (SOP section 5 step 7 and section 6). *(provisional, #8)* They are expected, so
  they are not an error; the flags make the follow-up list.

- **Further checks added after reading the data**: SPE-08 (a new name entered as new more than once,
  6 flags, including two provisional labels for one species), SPE-09 (typed name already on the list,
  1: `Pechuel-loeschea leubnitziae`), SPE-12, CON-07 (same species twice in a quadrat, 7), SPA-07
  (two quadrats with identical coordinates, 2 in Plot_01), SPA-06, PLT-07 (form status differs from
  the plot list, 0), PLT-08, TIM-05 (unreadable time, 0), MET-01 to MET-04 (form version, review
  state, recorder in the team). *(provisional, #8)* Each is justified in the catalogue and has a
  failing and a passing test.

# Reporting

- **Errors list**: contains all flags of severity `error` and `warning`, not only those a field
  team can act on. *(provisional, 2026-10-08, #7; to confirm once the actual flags are seen)* Info
  stays in the flags table and the dashboard.

- **Errors list after seeing the flags**: the list for the data providers holds the 11 errors and 148
  warnings (159 items in 30 submissions of 28 plots), 110 for the field team, 26 for the data
  manager and 23 for Tech. *(provisional, #8; to confirm)* Keeping all of them, with
  `who_can_resolve`, lets the data manager forward each item to the right person; the Tech items
  (the form summary) are marked so the field team does not act on them.

# Data issues upstream

- **Plot registrations and surveys are not linked by a key in the survey export**: the chain is
  survey `selected_plot_uuid` = `vegplots.__id`, then `vegplots.plot_uuid` = registration
  `selected_plot_uuid`. *(#7)* Two names for different ids in two tables is easy to join wrongly
  (0 of 32 matches); worth a column rename or a note in the ODK form documentation.

- **Free-text species names are not in the SOP format**: none of the 1296 additional-species rows
  matches `Genus_species` (names use a space, or a label such as `herb_104 (Justicia divaricata )`
  with a stray space). *(#7)* The strict regex is kept in the config; #8 decides how to flag.

- **The form's quadrats-with-species summary ignores listed species**: it counts only quadrats with
  additional-species rows (32 of 32 surveys match that definition). *(#8)* The count is shown to the
  team at submission (SOP section 5 step 13), so it misleads; fix the calculation in the ODK form.

- **The typed-name field accepts anything but `,;()`**: all 45 typed names use a space where the SOP
  asks for an underscore, 2 have a trailing space and 3 have a genus one letter off a listed genus.
  *(#8)* A form constraint that requires `Genus_species` for each name would stop it at entry.

- **The extra-species list has a label with a trailing space**: `Evolvulus alsinoides ` (reused 64
  times). *(#8)* One edit in the entity list.

- **Registrations are uploaded after the surveys that use them**: for 3 plots (Plot_03, Plot_08,
  Plot_22) the server upload is hours after the survey start although the form end time is
  earlier. *(#8)* Tell teams to upload registrations before surveying; the plot picker can only show
  an entity that exists on the device.

# Vegetation summaries

- **Species identity rule**: a distinct identified taxon is a name from the species list or a typed
  name, after trimming outer and double spaces, turning spaces into underscores and capitalising
  the first letter; each taxon is counted once. *(provisional, #9; to confirm with Natural State)*
  Only typing differences that cannot change the meaning are removed. Misspellings
  (`Brachiara dura`) are not merged: a fuzzy merge would be a taxonomic decision, and the checks
  already flag them (SPE-06). Alternative: merge with the check suggestion, rejected.

- **A placeholder with a proposed name counts as that name**: `herb_104 (Justicia divaricata )` is
  read as `Justicia_divaricata`. *(provisional, #9; to confirm)* The team named the plant when it
  created the label, and this merges `herb_059` and `herb_104`, which SPE-08 flags as one species.
  Alternative: leave every `herb_NNN` as unknown, which would count the same species twice.

- **Provisional unknowns are counted apart and never in headline richness**: plain `herb_NNN` or
  `wood_NNN` labels, raw UUID text and records without a name. *(provisional, #9)* A label is not a
  stable taxon (22 of the 44 labels that carry a proposed name also appear as a plain label, so the
  same plant sits behind several records). Tables give the distinct unknown labels per submission
  and plot and `richness_upper_bound` (identified taxa plus all distinct labels), named an upper
  bound because a label can repeat a named taxon; identified richness is the headline. Alternative:
  count each label as a taxon, rejected because it inflates richness by a count that is not taxonomic.

- **The summary tables are kept narrow**: the plot table has no info-flag count (the 757 info flags
  of the accepted submissions are noise there; the survey table, the map layer and `flags.csv` keep
  them), numbers are written to two decimals, and `excluded_records.csv` lists the error-flagged
  quadrats and the rejected submissions, not the 40 quadrats of the rejected submissions, which the
  submission rows imply. *(#9)* Alternative: keep every column and row, rejected because it buries
  the few columns a reader needs.

- **Shannon H is used only to find outlying plots (PLT-09)**: for each plot, the number of quadrats in
  which each identified taxon occurs, `p = f / sum(f)`, `H = -sum(p ln p)`; a plot is flagged
  (info, data manager) when `|H - median| / MAD` exceeds `shannon_outlier_mad` (3, scaled MAD) and at
  least `shannon_outlier_min_plots` (10) plots exist. *(#8, #9)* There is no abundance, only
  presence per quadrat, so an abundance-based diversity index does not exist, and a diversity
  number in the tables would invite reading it as a result. The summaries report richness only.
  Alternatives: report H and `exp(H)` in the plot table, rejected for that reason; Simpson,
  rejected for the same reason; no outlier check, rejected because a plot with one recorded
  taxon would pass unnoticed.

- **Survey-level and plot-level definitions**: a quadrat "has species" when any species record
  exists for it, identified or not; the plot table has one row per registered plot (31), with
  `surveyed` and primary or backup; a plot's quadrats are those of its submissions that were not
  rejected in ODK (see "Rejected submissions" below). *(#9)* Mean richness per quadrat is the
  effort-free number for comparing plots, next to the effort assessment.

- **Sensitivity version leaves out error-flagged quadrats**: a quadrat with an error flag is left
  out and the rest of its submission stays; an error flag without a quadrat leaves out the whole
  submission. *(provisional, #9)* The errors in the data (CON-04, SPE-11) concern one quadrat, so
  excluding the submission would remove 19 good quadrats. Warnings and info never exclude. The data are not changed: the tables are
  filtered views, and `excluded_records.csv` lists everything left out.

- **Flag counts in the summaries describe the submission**: the sensitivity tables show the same
  counts of errors, warnings and info as the main tables, both from the submissions that were not
  rejected. *(#9)* Flags are facts about what was
  submitted; only quadrats, taxa and indices are recomputed.

- **Sampling effort (brief item 1c) is assessed per plot from incidence data**: quadrats (1 m x 1 m)
  are the sampling units and only identified taxa count (provisional unknown labels are not stable
  units). *(#9)* Per plot: quadrats against the 20 expected, a species accumulation curve
  (`vegan::specaccum`, method random, 100 orderings), the Chao2 richness estimate with a 95 percent
  interval and the sample coverage (`iNEXT`, `incidence_raw`), completeness (observed / Chao2), and
  the gain in taxa over the last 5 quadrats of the curve. A plot "approaches an asymptote" when
  completeness is at least 0.9 and coverage at least 0.95; a plot without an estimate is NA, never
  "approaches". iNEXT warnings go to `estimate_note` and failures to `estimate_status` (ok, no_taxa,
  failed), never silent. The verdict is a descriptive statistic of data adequacy, not a design
  recommendation. Both versions are produced (main, and excluding error-flagged quadrats). The brief
  asks for an assessment of sampling effort and the owner reversed an earlier decision to drop it.
  Alternatives: accumulation curves only, rejected because they leave the question to the eye;
  the exact `specaccum` method, rejected because the random method gives a standard deviation and is
  the usual choice; Chao2 without coverage, rejected because coverage guards against plots dominated
  by rare species. Validators abort if the effort table does not reconcile with the plot summary,
  if Chao2 is below the observed richness, or if completeness or coverage fall outside [0, 1].

- **Effort thresholds are provisional and the random curves use a fixed seed**: `completeness_min`
  (0.9) and `coverage_min` (0.95) are in `R/vegetation/config.R` and are to be confirmed with
  Natural State. *(provisional, #9)* The accumulation curves use seed 20261008 inside
  `withr::with_seed`, so the results reproduce and the session RNG is untouched. A plot with no
  taxa gets a flat zero curve because `specaccum` fails on it. Alternative: an unseeded run, rejected
  because the curves would change at every run.

- **Rejected submissions are out of the plot and headline numbers**: a submission with ODK
  `ReviewState = rejected` is listed in the survey table, with its review state and its own flag
  counts, but counts in no plot row, total, plot flag count or map colour. *(provisional, #9; to
  confirm that the review state is final)* The reviewer already judged it unusable, and counting it
  would give Plot_18 and Plot_21 40 quadrats against 20 for every other plot. The headline numbers
  are 30 accepted surveys and 600 quadrats (the survey table lists 32 submissions and 640
  quadrats). Plot_21's one error sits on its rejected submission, so the plot is not coloured by it.
  The flags of rejected submissions stay in `flags.csv` but are off the field-team list (nothing to
  fix on a submission nobody uses: 1 error and 8 warnings). The dashboard and the report show the
  count of rejected submissions. The versions of the summaries are `accepted` (every submission not
  rejected) and `excluding_errors`. Alternative: pool both submissions of a plot and show the
  sensitivity version, rejected because the quadrats should not be counted twice.

# Data issues upstream (vegetation summaries)

- **Provisional labels are not linked to the names given to them**: 22 of 44 `herb_NNN` labels that
  carry a proposed name in one record appear as a plain label in other records. *(#9)* Tech should
  store the proposed name on the label in the entity list so every record of the label resolves to
  one taxon; until then those records count as unknowns.

# Map and dashboard (vegetation)

- **What the plot map shows**: one point per registered plot at the centre stored in the vegplots
  `geometry` (ODK geopoint "latitude longitude altitude accuracy", latitude first), coloured by
  the worst severity among the plot's flags (error, then warning, then info, then none). *(#10)*
  The geometry is the transect midpoint: the median quadrat sits within 10 m of it, and it agrees
  with the geohash of the entity list to the precision of the 7-character geohash. A plot without
  a geometry (Plot_23, registered, not viable, not surveyed) cannot be drawn: it keeps its row in
  `plot_locations.csv` with empty coordinates and is named in the figure instead of vanishing.
  Alternative: dropping it from the table, rejected because the table must reconcile with the 31
  registered plots.

- **Map distances use EPSG:32637**: the figures are drawn in WGS 84 / UTM zone 37N, the zone every
  plot is in and the zone the distance checks pick from the points. *(#10)* A check asserts that
  the plots are in that zone; a plot outside it would need a new CRS. The north arrow shows grid
  north (less than 0.1 degrees from true north here).

- **Severity colours**: error dark red `#A50F15`, warning amber `#F2BC57`, info grey `#8C8C8C`, no
  flag soft green `#7DBE98`, defined once in `veg_config`. *(provisional, #10; to confirm with
  Natural State's visual identity)* Dark red and amber differ clearly in luminance, grey is
  neutral, and every point has a dark outline so that colour is not the only cue. Green stays
  reserved for "no issue", as in the brand notes. Alternative: the Okabe-Ito vermillion/orange
  pair, rejected because the two are close to each other for people with red-green colour
  blindness.

- **Plot kinds are shown by shape**: circle = primary and surveyed, diamond = backup, hollow
  square = registered but not surveyed. *(#10)* Colour already carries severity. On the real data
  the hollow square is never drawn because the only unsurveyed plot has no coordinates; the legend
  drops unused entries.

- **Quadrat colour is the worst flag of any check on that quadrat**: info flags (unknown taxa)
  make most quadrats grey. *(provisional, #10)* This follows the brief (colour by worst severity)
  but hides the spatial flag among the others. Alternative: colour by spatial checks only
  (SPA-xx), rejected for the first version to keep one meaning of the colours everywhere; the
  dashed circle (belt reach, 25.1 m) shows the spatial problem instead.

- **Example plots for the zoom are chosen by hand**: plots 01 (one quadrat 75 m away), 05 (whole
  transect shifted about 30 m), 11 (one quadrat 50 m away) and 16 (all quadrats inside the belt).
  *(provisional, #10)* They show the main kinds of pattern behind SPA-04. They are listed in
  `veg_config$map_example_plots`; the map says nothing about the other plots beyond what the flags
  table says.

- **The dashboard is an extra and runs no analysis**: four panels (survey summary, plot summary,
  map, filterable flags table) read `outputs/vegetation/*.csv`. *(provisional, #10; scope to confirm)* Source in `dashboard/`,
  rendered to `docs/index.html` by `R/vegetation/05_dashboard.R`. The report stands alone; the
  dashboard adds filtering and a clickable map.

- **Dashboard flags table uses a small self-contained JavaScript filter**: `DT` and `reactable`
  are not installed and nothing is installed for the mock-up. *(#10)* Three drop-down filters
  (severity, check, plot) show or hide rows of one static table; no search box, no paging. The
  HTML is passed to pandoc as a raw block, because 960 rows in Markdown made pandoc hang.

- **Dashboard map uses satellite imagery**: Esri World Imagery tiles under the plot markers.
  *(provisional, #10; terms of use to confirm before wider sharing)* The dashboard is meant to be
  opened from a web address, where tiles load; tested through a local web server. Opened from disk
  or offline the markers still draw, without imagery. The imagery shows the setting of the plots
  (fields, tracks, rivers), which a plain background cannot. The static report figures keep no
  basemap so that they work offline. Alternative: OpenStreetMap tiles, rejected because a map of
  plots in the bush is clearer on satellite imagery.

- **Branding by `_brand.yml`, without the brand font**: Quarto 1.10 applies the colours and the
  logo of `dashboard/_brand.yml`. *(provisional, #10; brand details to confirm)* The Google font
  Inter (an approximation of the brand font) added 13 MB to the self-contained page and needs a
  network at render time, so the page uses the system sans-serif font. The logo file was an AVIF
  image with a `.png` name; it was converted to a real PNG in `assets/ns_logo.png` and is used for
  the mock-up only.

- **Dashboard colours are softer than the brand and the logo sits on white**: navy `#4A5E9A`, blue
  `#6F86BD`, green `#7DBE98` and warning amber `#F2BC57`, against the brand `#0D247A`, `#214097` and
  `#17B052`; the navbar is white so the logo needs no box. *(provisional, #10; to confirm with
  Natural State's visual identity)* Full-strength brand colours looked heavy next to the data. The
  same values are used in the static figures through `veg_config`. The dashboard overrides are in `dashboard/_brand.yml` and
  `dashboard/custom.scss`.

- **Hosting**: the planned address is https://albansagouis.github.io/naturalstate-take-home/
  (GitHub Pages from `docs/` on the main branch), stated in the report as "once GitHub Pages is
  switched on". *(provisional, #10; to confirm)* Until it is switched on the report relies on the
  three screenshots, taken with headless Firefox because no Chrome is installed.

# Handoff to Tech (vegetation)

- **The catalogue is configuration with the query in the row**: `veg_check_catalogue` holds
  rule, severity, message, who resolves, and a `check_sql` that returns `survey_key,
  quadrat_key, value, detail`. *(provisional, #11)* Biometrics adds or changes a check by
  inserting a row, Tech only runs it with a read-only role and rolls back on a malformed
  result. The catalogue CSV has no query text, so Tech writes all 59 from the rule
  sentence and the R reference, and the flag counts of the acceptance table decide when a
  query is right. Alternative: checks as Python code, rejected because every change would then
  need a developer, and a developer would be deciding a check.

- **Flags have a deterministic id and are closed, not deleted**: `flag_id` is the md5 of check,
  submission, quadrat and value; a flag not raised again gets `resolved_at`. *(#11)* The R
  reference builds the same md5, so the id of a finding does not change when other flags
  appear or disappear. A run-order number would.
  Keeping closed flags preserves what was found when. Alternative: delete and re-insert,
  rejected because it loses the history and the first-seen run.

- **Every run is a full recompute in one transaction**: staged tables, checks and summaries
  are rebuilt, flags are upserted. *(#11)* The data are small (32 surveys, 640 quadrats) so
  change detection would add code for no gain, and a failed run rolls back and leaves the last
  good results visible. Alternative: incremental recompute per survey, rejected because the
  group checks (STR-07 to STR-09, MET-01) depend on other submissions.

- **Staged tables take bad data without complaint**: primary keys and types only, no CHECK on
  values and no foreign keys between data rows. *(#11)* A constraint violation would reject
  the very rows the QA/QC exists to report. Only a missing file or required column aborts.

- **Summaries are tables rebuilt each run, in two versions**: `version` is `accepted` or
  `excluding_errors`. *(provisional, #11)* The dashboard defaults to `accepted` and offers
  the other as a toggle, as the prototype does. Alternative: views computed on read, rejected
  because the species identity rule and the estimators are too heavy for a request.

- **Orphan records are left out of both summary versions**: reason `orphan_record` in
  `veg_excluded_record`. *(provisional, #11)* No summary can place a row without a parent. The
  R reference aborts in that case (`veg_record_taxa` asserts no missing keys); the platform must
  not stop the dashboard for one bad row, so it excludes and flags it (STR-01, STR-02).
  Alternative: abort, rejected for an unattended job. The sample has none.

- **A duplicate key in a lookup aborts the R staging joins**: the joins are many-to-one, so a plot
  registered twice or a plot id twice in the plot list stops the run. *(provisional, #11; the
  platform behaviour is to confirm)* A lookup duplicate would otherwise multiply survey rows and
  every count built on them, silently. The duplicate is also written as a finding
  (`veg_key_integrity`), and the sample has none. Unlike orphan records, which the platform
  excludes and flags, there is no obvious safe row to keep, so the platform behaviour is left to
  Biometrics. Alternative: keep the first match, rejected because it hides which registration is
  right.

- **Distances use EPSG:32637 and strict inequalities**: planar distance in metres after
  projecting both WGS 84 points; flag when distance is strictly greater than the allowed
  distance. *(#11)* Any geometry library that follows the stated steps is acceptable; none was
  compared with another here, so the first load checks the distance flag counts. The R code picks the zone from the mean coordinate; the platform
  fixes it in the parameter `map_epsg`, because all plots lie in zone 37N.

- **Time stamps keep their offset; staging must not drop it**: `timestamptz` for every form time.
  *(#11)* Dropping the +02:00 makes 15 of 32 surveys appear to start after they were submitted
  (TIM-03); the handoff names it as the first thing to look at if TIM-03 fires.

- **Handoff content kept out on purpose**: parity fixtures between R and Python, Redis design,
  and any scientific open question. *(#11)* The acceptance table (counts per check and
  severity, plus concrete rows) is the contract, as in the birds handoff.
