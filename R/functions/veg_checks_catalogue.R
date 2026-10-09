# The check catalogue: the specification of every QA/QC check (issue #8).
# One row per check. `fun` is the function that implements it and is not part
# of the exported specification. Message templates use {plot}, {quadrat},
# {value} and {detail}. Severity logic (rulebook_vegetation.md):
# - error: breaks an SOP step or a data rule, or makes the record contradictory
#   or unusable. Must be resolved before the data are used.
# - warning: suspicious or off-tolerance; needs a human decision and may be fine.
# - info: context or follow-up work that needs no correction.

veg_sop_survey <- "Herbaceous Vegetation Surveys SOP (v2026.1)"
veg_sop_register <- "Vegetation Plot Registration SOP (v2026.1)"

veg_catalogue_row <- function(
  id,
  level,
  severity,
  rule,
  columns,
  sop_reference,
  message_template,
  who_can_resolve,
  what_to_check
) {
  tibble(
    id = id,
    level = level,
    severity = severity,
    rule = rule,
    columns = columns,
    sop_reference = sop_reference,
    message_template = message_template,
    who_can_resolve = who_can_resolve,
    what_to_check = what_to_check,
    fun = paste0(
      "veg_chk_",
      tolower(gsub(pattern = "-", replacement = "", x = id))
    )
  )
}

veg_check_catalogue <- function() {
  r <- veg_catalogue_row
  bind_rows(
    # ---- Structure -------------------------------------------------------------
    r(
      "STR-01",
      "quadrat",
      "error",
      "Every quadrat row belongs to a survey submission (PARENT_KEY exists in the survey table).",
      "quadrat.PARENT_KEY; survey.KEY",
      "ODK data rule (repeat structure); Herbaceous SOP section 3",
      "Quadrat {quadrat} points to a survey submission that is not in the export.",
      "data manager",
      "Re-export the data; check that the survey submission was not deleted."
    ),
    r(
      "STR-02",
      "species",
      "error",
      "Every additional-species row belongs to a quadrat row.",
      "additional_species_repeat.PARENT_KEY; quadrat.KEY",
      "ODK data rule (repeat structure)",
      "A species record ({value}) points to a quadrat that is not in the export.",
      "data manager",
      "Re-export the data; check that the quadrat was not deleted."
    ),
    r(
      "STR-03",
      "survey",
      "error",
      "Survey KEY is unique.",
      "survey.KEY",
      "ODK data rule (primary key)",
      "Submission key {value} appears more than once.",
      "Tech",
      "Check the export and the ODK Central sync for duplicated rows."
    ),
    r(
      "STR-04",
      "quadrat",
      "error",
      "Quadrat KEY is unique.",
      "quadrat.KEY",
      "ODK data rule (primary key)",
      "Quadrat key {value} appears more than once.",
      "Tech",
      "Check the export and the ODK Central sync for duplicated rows."
    ),
    r(
      "STR-05",
      "species",
      "error",
      "Additional-species KEY is unique.",
      "additional_species_repeat.KEY",
      "ODK data rule (primary key)",
      "Species record key {value} appears more than once.",
      "Tech",
      "Check the export and the ODK Central sync for duplicated rows."
    ),
    r(
      "STR-06",
      "survey",
      "error",
      "Every survey submission has quadrat rows.",
      "survey.KEY; quadrat.PARENT_KEY",
      "Herbaceous SOP section 5 steps 5-13 (20 quadrats per plot)",
      "This submission has no quadrat data at all.",
      "field team",
      "Check whether the survey was submitted before the quadrats were filled in; resubmit if needed."
    ),
    r(
      "STR-07",
      "survey",
      "info",
      "A rejected submission for a plot and survey that also has an accepted submission (two submissions for one plot).",
      "survey.ReviewState; plot_selection-plot_name; survey_begin-selected_survey_uuid",
      "Herbaceous SOP section 5 step 15 (confirm submission)",
      "This submission of {value} was rejected; the plot also has an accepted submission.",
      "data manager",
      "Nothing to do if the accepted submission is the correct one; exclude the rejected one from analysis."
    ),
    r(
      "STR-08",
      "survey",
      "warning",
      "More than one accepted (not rejected) submission for the same plot and survey: nobody decided which counts.",
      "survey.ReviewState; plot_selection-plot_name; survey_begin-selected_survey_uuid",
      "Herbaceous SOP section 5 step 16 (one visit per plot)",
      "{value} has more than one accepted submission for the same survey.",
      "data manager",
      "Decide which submission is the valid one and reject the other in ODK Central."
    ),
    r(
      "STR-09",
      "survey",
      "error",
      "A plot whose submissions are all rejected has no usable survey.",
      "survey.ReviewState; plot_selection-plot_name; survey_begin-selected_survey_uuid",
      "Herbaceous SOP section 5 step 16",
      "Every submission of {value} was rejected, so there is no usable survey for this plot.",
      "field team",
      "Resurvey the plot or reinstate one of the submissions."
    ),
    # ---- Plot ------------------------------------------------------------------
    r(
      "PLT-01",
      "survey",
      "error",
      "The selected plot exists in the registered plot list (vegplots).",
      "plot_selection-selected_plot_uuid; vegplots.__id",
      "Herbaceous SOP section 5 step 4",
      "The plot {value} is not in the list of registered plots.",
      "data manager",
      "Check the plot choice in the form and the plot list."
    ),
    r(
      "PLT-02",
      "survey",
      "error",
      "The plot is recorded as viable (plot list and registration).",
      "vegplots.is_viable; register.plot_selection-is_plot_viable",
      "Herbaceous SOP section 5 step 4; Registration SOP section 5 steps 3 and 5",
      "{value} was surveyed although it is recorded as not viable ({detail}).",
      "data manager",
      "Check whether the plot was wrongly marked non-viable or the wrong plot was surveyed."
    ),
    r(
      "PLT-03",
      "survey",
      "error",
      "The plot belongs to the selected survey.",
      "vegplots.survey_uuids; survey_begin-selected_survey_uuid",
      "Herbaceous SOP section 5 step 4",
      "{value} does not belong to the survey chosen in the form.",
      "data manager",
      "Check the survey choice and the survey list of the plot."
    ),
    r(
      "PLT-04",
      "survey",
      "error",
      "The plot has a registration submission.",
      "survey.register_KEY; register.KEY",
      "Herbaceous SOP section 4 and section 5 step 1; Registration SOP section 3",
      "{value} has no plot registration.",
      "field team",
      "Register the plot with the registration form."
    ),
    r(
      "PLT-05",
      "survey",
      "error",
      "The plot registration was finished (form end time) before the survey started.",
      "register.survey_end-end_time; survey_begin-start_time",
      "Herbaceous SOP section 5 step 1",
      "{value} was registered ({detail} UTC) after this survey started.",
      "data manager",
      "Check the registration time and the survey time."
    ),
    r(
      "PLT-06",
      "survey",
      "info",
      "A backup plot was surveyed (primary versus backup).",
      "plot_selection-get_plot_status",
      "Registration SOP section 5 step 5 (backup replaces a non-viable plot)",
      "{value} is a backup plot; confirm it replaces a plot recorded as not viable.",
      "data manager",
      "Confirm the primary plot it replaces is recorded as not viable."
    ),
    r(
      "PLT-07",
      "survey",
      "warning",
      "The plot status shown by the form equals the status in the plot list.",
      "plot_selection-get_plot_status; vegplots.plot_status",
      "Herbaceous SOP section 5 step 4 (confirm the plot status)",
      "The status of {value} differs between the form and the plot list ({detail}).",
      "data manager",
      "Check which status is right and correct the plot list."
    ),
    r(
      "PLT-08",
      "survey",
      "info",
      "The registration was uploaded before the survey started (otherwise: delayed upload).",
      "register.SubmissionDate; survey_begin-start_time",
      "Herbaceous SOP section 4.2 (refresh forms) and Registration SOP section 5 step 10",
      "{value} was uploaded ({detail} UTC) after this survey started; it was registered earlier on the device.",
      "data manager",
      "None needed if the registration form time is earlier; remind teams to upload registrations before surveys."
    ),
    r(
      "PLT-09",
      "survey",
      "info",
      "The diversity of the plot is close to that of the other plots.",
      "species records of the plot's submissions",
      "ODK data rule",
      "The diversity of this plot (Shannon {value}) is far from the median of the plots ({detail}).",
      "data manager",
      "Check that the species lists of this plot are complete and correctly entered; very low or very high diversity can come from a missing, repeated or misread list."
    ),
    # ---- Quadrat completeness ----------------------------------------------------
    r(
      "QUA-01",
      "survey",
      "error",
      "A survey has exactly 20 quadrats.",
      "quadrat.PARENT_KEY",
      "Herbaceous SOP section 3 and section 5 step 13",
      "This survey has {value} quadrats instead of 20.",
      "field team",
      "Check whether quadrats are missing or entered twice."
    ),
    r(
      "QUA-02",
      "survey",
      "error",
      "Quadrat numbers are 1 to 20, each once.",
      "quadrat.quadrat_number",
      "Herbaceous SOP section 3 and section 5 steps 11-12",
      "Quadrat numbers are wrong: {value}.",
      "field team",
      "Check the quadrat numbering against the field sheet."
    ),
    r(
      "QUA-03",
      "survey",
      "warning",
      "The quadrat count the form recorded equals the number of quadrat rows.",
      "observations-quadrat_repeat_count; quadrat.PARENT_KEY",
      "Herbaceous SOP section 3",
      "The form counted {value} quadrats but {detail} are in the data.",
      "data manager",
      "Check for lost or added quadrat rows."
    ),
    r(
      "QUA-04",
      "quadrat",
      "info",
      "A quadrat with no herbs has a species count of 0, not blank.",
      "herb_species-count_herb_species; herbs_present",
      "Herbaceous SOP section 5 step 6",
      "Quadrat {quadrat} has no herbs and the species count is blank instead of 0.",
      "data manager",
      "None needed; treat the blank as 0 and keep the rule documented."
    ),
    r(
      "QUA-05",
      "quadrat",
      "error",
      "Every quadrat has a geopoint.",
      "location_quadrat-Latitude; location_quadrat-Longitude",
      "Herbaceous SOP section 5 step 9",
      "Quadrat {quadrat} has no location.",
      "field team",
      "Check whether the geopoint was recorded; note the quadrat position if not."
    ),
    r(
      "QUA-06",
      "quadrat",
      "error",
      "herbs_present is yes or no.",
      "herbs_present",
      "Herbaceous SOP section 5 step 6",
      "Quadrat {quadrat} does not say whether herbs are present ({value}).",
      "field team",
      "Check the quadrat on the field sheet."
    ),
    # ---- Consistency -------------------------------------------------------------
    r(
      "CON-01",
      "quadrat",
      "error",
      "herbs_present = no means no species records.",
      "herbs_present; selected species; additional species",
      "Herbaceous SOP section 5 steps 6-7",
      "Quadrat {quadrat} says no herbs are present but {value} species are listed.",
      "field team",
      "Check whether herbs were present and correct the answer or the species list."
    ),
    r(
      "CON-02",
      "quadrat",
      "warning",
      "herbs_present = yes means at least one species record.",
      "herbs_present; selected species; additional species",
      "Herbaceous SOP section 5 steps 6-7",
      "Quadrat {quadrat} says herbs are present but no species is listed.",
      "field team",
      "Check the species list of the quadrat."
    ),
    r(
      "CON-03",
      "quadrat",
      "error",
      "The species count equals the number of species selected from the list.",
      "herb_species-count_herb_species; selected_herb_species_uuids",
      "Herbaceous SOP section 5 step 7",
      "Quadrat {quadrat} counts {value} species but {detail} are selected.",
      "data manager",
      "Check the species selection."
    ),
    r(
      "CON-04",
      "quadrat",
      "error",
      "additional_species_present = yes means at least one additional-species row.",
      "additional_species_present; additional_species_repeat",
      "Herbaceous SOP section 5 step 7",
      "Quadrat {quadrat} says extra species were found but none is recorded.",
      "field team",
      "Look up the extra species on the field sheet and send them to the data manager."
    ),
    r(
      "CON-05",
      "quadrat",
      "error",
      "Additional-species rows exist only when additional_species_present = yes.",
      "additional_species_present; additional_species_repeat",
      "Herbaceous SOP section 5 step 7",
      "Quadrat {quadrat} lists {value} extra species but says none were found.",
      "field team",
      "Check whether the extra species belong to this quadrat."
    ),
    r(
      "CON-06",
      "survey",
      "warning",
      "quadrats_with_species equals the number of quadrats with a species record (selected or additional).",
      "survey_end-quadrats_with_species; species records",
      "Herbaceous SOP section 5 step 13",
      "The end summary says {value} quadrats had species; the data show {detail}.",
      "Tech",
      "Form issue: the summary counts only quadrats with extra species. Fix the form calculation so step 13 of the SOP can rely on it."
    ),
    r(
      "CON-07",
      "species",
      "warning",
      "A species appears once per quadrat and source.",
      "selected species; additional species",
      "Herbaceous SOP section 3 (presence recorded per quadrat)",
      "Quadrat {quadrat}: {value} is listed more than once.",
      "field team",
      "Remove the duplicate if it is the same plant."
    ),
    # ---- Species -----------------------------------------------------------------
    r(
      "SPE-01",
      "species",
      "error",
      "Every selected species id resolves to the species list.",
      "selected_herb_species_uuids; species.__id",
      "Herbaceous SOP section 5 step 7",
      "Quadrat {quadrat}: species id {value} is not on the species list.",
      "data manager",
      "Check the species list version."
    ),
    r(
      "SPE-02",
      "species",
      "warning",
      "A typed species name is Genus_species (capital genus, lower-case epithet, underscore, no authorship).",
      "new_missing_canonical",
      "Herbaceous SOP section 2 (Canonical) and section 5 step 7",
      "Quadrat {quadrat}: the name \"{value}\" is not written as Genus_species.",
      "field team",
      "Write the name as Genus_species (for example Chloris_virgata)."
    ),
    r(
      "SPE-03",
      "species",
      "info",
      "A provisional unknown (herb_NNN) needs a voucher and a later identification.",
      "species_name; species_entry_mode",
      "Herbaceous SOP section 5 step 7 and section 6",
      "Quadrat {quadrat}: {value} is not identified yet.",
      "field team",
      "Identify the voucher or photographs and send the name to Natural State."
    ),
    r(
      "SPE-04",
      "species",
      "error",
      "A species name is not a raw identifier (UUID).",
      "new_missing_canonical; validated_name",
      "Herbaceous SOP section 5 step 7",
      "Quadrat {quadrat}: the species name {value} is an identifier, not a name.",
      "field team",
      "Replace it with the species name."
    ),
    r(
      "SPE-05",
      "species",
      "warning",
      "Typed names and listed species labels have no leading or trailing space.",
      "new_missing_canonical; species.label",
      "Herbaceous SOP section 5 step 7",
      "Quadrat {quadrat}: the name {value} has a space at the start or end.",
      "field team",
      "Remove the space."
    ),
    r(
      "SPE-06",
      "species",
      "warning",
      "A typed name is not within 2 edits (15 percent of its length) of a different listed name, and its genus is not one letter off a listed genus (likely misspelling).",
      "new_missing_canonical; species.label",
      "Herbaceous SOP section 4.2 and section 5 step 7",
      "Quadrat {quadrat}: \"{value}\" looks like a misspelling of \"{detail}\".",
      "field team",
      "Check the spelling and select the species from the list if it is the same."
    ),
    r(
      "SPE-07",
      "species",
      "warning",
      "A name is not both selected from the list and typed in one quadrat.",
      "selected species; additional species",
      "Herbaceous SOP section 5 step 7",
      "Quadrat {quadrat}: {value} is both selected from the list and added as extra.",
      "field team",
      "Keep one entry."
    ),
    r(
      "SPE-08",
      "species",
      "warning",
      "A new species name is entered as new only once; later records reuse it.",
      "new_missing_canonical",
      "Herbaceous SOP section 4.2 and section 6",
      "Quadrat {quadrat}: {value} was entered as a new species more than once.",
      "data manager",
      "Merge the duplicate new-species entries."
    ),
    r(
      "SPE-09",
      "species",
      "warning",
      "A typed name is not already on the species list.",
      "new_missing_canonical; species.label",
      "Herbaceous SOP section 4.2 and section 5 step 7",
      "Quadrat {quadrat}: {value} is already on the species list and should have been selected.",
      "data manager",
      "Replace the typed entry with the list species."
    ),
    r(
      "SPE-10",
      "species",
      "error",
      "A reused extra-species id resolves to the extra-species list.",
      "select_reuse_unknown; select_reuse_missing; species_extra.__id",
      "ODK data rule (entity lookup)",
      "Quadrat {quadrat}: reused species id {value} is not in the extra-species list.",
      "data manager",
      "Check the entity list."
    ),
    r(
      "SPE-11",
      "species",
      "error",
      "Every additional-species row has a name.",
      "validated_name",
      "Herbaceous SOP section 5 step 7",
      "Quadrat {quadrat}: an extra species has no name.",
      "field team",
      "Look up the species on the field sheet."
    ),
    r(
      "SPE-12",
      "species",
      "warning",
      "A reused extra-species label has no leading or trailing space (reported once per submission and label).",
      "validated_name; species_extra.label",
      "Herbaceous SOP section 5 step 7",
      "The reused name {value} has a space at the start or end.",
      "data manager",
      "Fix the label once in the extra-species list."
    ),
    # ---- Spatial -----------------------------------------------------------------
    r(
      "SPA-01",
      "quadrat",
      "error",
      "Quadrat geopoint accuracy is at most 5 m.",
      "location_quadrat-Accuracy",
      "Herbaceous SOP section 4.2",
      "Quadrat {quadrat}: location accuracy is {value} m, above 5 m.",
      "field team",
      "Set the device to 5 m accuracy or better and wait for a good fix."
    ),
    r(
      "SPA-02",
      "survey",
      "warning",
      "The background geopoint accuracy is at most 5 m.",
      "survey_end-background_geopoint-Accuracy",
      "Herbaceous SOP section 4.2",
      "The end-of-survey location accuracy is {value} m, above 5 m.",
      "field team",
      "Set the device to 5 m accuracy or better."
    ),
    r(
      "SPA-03",
      "survey",
      "info",
      "The background geopoint is recorded.",
      "survey_end-background_geopoint-*",
      "Herbaceous SOP section 4.2 (device configuration)",
      "No end-of-survey location was recorded.",
      "field team",
      "None needed unless the plot location must be confirmed."
    ),
    r(
      "SPA-04",
      "quadrat",
      "warning",
      "A quadrat is within the belt around the plot midpoint (reach 25.1 m plus the GPS accuracy of both points).",
      "location_quadrat-*; vegplots.geometry",
      "Herbaceous SOP section 2 (Belt transect) and Registration SOP section 3",
      "Quadrat {quadrat} is {value} m from the plot midpoint; the belt allows {detail} m.",
      "field team",
      "Check the quadrat location and the plot midpoint."
    ),
    r(
      "SPA-05",
      "survey",
      "warning",
      "The background geopoint is near the plot midpoint (same tolerance as SPA-04).",
      "survey_end-background_geopoint-*; vegplots.geometry",
      "Herbaceous SOP section 2 (Belt transect)",
      "The end-of-survey location is {value} m from the plot midpoint; the plot allows {detail} m.",
      "field team",
      "Check that the survey was done at the registered plot."
    ),
    r(
      "SPA-06",
      "quadrat",
      "info",
      "Consecutive quadrats are at most 7.1 m apart (5 m along the tape, alternating sides) plus twice the combined GPS accuracy.",
      "location_quadrat-*",
      "Herbaceous SOP section 5 steps 11-12",
      "Quadrat {quadrat} is {value} m from the previous one; expected at most {detail} m.",
      "field team",
      "Check quadrat numbering and locations."
    ),
    r(
      "SPA-07",
      "quadrat",
      "warning",
      "Two quadrats of a survey do not share identical coordinates.",
      "location_quadrat-*",
      "Herbaceous SOP section 5 step 9",
      "Quadrat {quadrat} has exactly the same location as another quadrat of this survey.",
      "field team",
      "Wait for a new fix at each quadrat."
    ),
    # ---- Time and metadata -------------------------------------------------------
    r(
      "TIM-01",
      "survey",
      "error",
      "The survey ends after it starts.",
      "survey_begin-start_time; survey_end-end_time",
      "ODK data rule (timestamps)",
      "The survey end time is before its start time.",
      "Tech",
      "Check the device clock."
    ),
    r(
      "TIM-02",
      "survey",
      "warning",
      "The survey lasts between 15 minutes and 3 hours.",
      "survey_begin-start_time; survey_end-end_time",
      "Herbaceous SOP section 5 (20 quadrats with photos)",
      "The survey took {value} minutes, outside the expected 15 to 180.",
      "field team",
      "Check that the whole plot was surveyed and the form was not left open."
    ),
    r(
      "TIM-03",
      "survey",
      "warning",
      "The survey does not start after it was submitted (more than 60 s).",
      "survey_begin-start_time; SubmissionDate",
      "ODK data rule (timestamps)",
      "The survey start is {value} seconds after the submission time.",
      "Tech",
      "Check the device clock and time zone."
    ),
    r(
      "TIM-04",
      "survey",
      "info",
      "The survey is submitted within 12 hours of finishing.",
      "survey_end-end_time; SubmissionDate",
      "Herbaceous SOP section 6 (submit as soon as possible)",
      "The survey was submitted {value} hours after it ended.",
      "field team",
      "None needed; submit as soon as there is a connection."
    ),
    r(
      "TIM-05",
      "survey",
      "error",
      "Start, end and submission times are all present and readable.",
      "survey_begin-start_time; survey_end-end_time; SubmissionDate",
      "ODK data rule (timestamps)",
      "A time stamp of this survey is missing or unreadable.",
      "Tech",
      "Check the export."
    ),
    r(
      "MET-01",
      "survey",
      "warning",
      "All submissions use the same form version.",
      "FormVersion",
      "ODK data rule (form version)",
      "This submission used form version {value}; most use {detail}.",
      "data manager",
      "Check whether the data differ in structure between versions."
    ),
    r(
      "MET-02",
      "survey",
      "info",
      "The submission has a review state recorded in ODK Central.",
      "ReviewState",
      "Herbaceous SOP section 5 step 15",
      "No review state is recorded for this submission.",
      "data manager",
      "Set a review state in ODK Central (approved, has issues or rejected)."
    ),
    r(
      "MET-03",
      "survey",
      "warning",
      "A submission marked 'has issues' is resolved.",
      "ReviewState",
      "Herbaceous SOP section 5 step 15",
      "This submission is marked as having issues.",
      "data manager",
      "Resolve the issues noted in ODK Central."
    ),
    r(
      "MET-04",
      "survey",
      "error",
      "The recorder is in the project team and in this survey's team.",
      "field_team_specifics-recorder_uuid; project_team",
      "Herbaceous SOP section 5 step 3",
      "The recorder {value} is not in the survey team ({detail}).",
      "field team",
      "Check the recorder and team members in the form."
    )
  )
}
