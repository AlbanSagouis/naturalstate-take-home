# Single place for every path and rule value in the vegetation QA/QC part.
# Independent of the BirdNET config. Run all scripts from the project root
# (here::here() finds it).

# The function files sourced below call dplyr and readr functions without a prefix
library(dplyr)
library(readr)

veg_raw_dir <- here::here("data", "raw", "vegetation")
veg_processed_dir <- here::here("data", "processed")

veg_config <- list(
  # ---- Rule values from the SOPs (used by later issues) ---------------------
  # Geopoint accuracy (m) above which a point breaks the SOP
  accuracy_limit_m = 5,
  expected_quadrats_per_plot = 20L,
  expected_quadrat_numbers = 1:20,
  # Quadrat spacing along the transect (m)
  quadrat_spacing_m = 5,
  # Canonical species format: Genus_species (SOP)
  # Genus capitalised, epithet lower case, joined by "_"; one hyphen allowed in
  # either part (e.g. Pechuel-loeschea_leubnitziae); no authorship, no spaces.
  species_name_regex = "^[A-Z][a-z]+(-[a-z]+)?_[a-z]+(-[a-z]+)?$",
  # Provisional labels for unidentified plants, e.g. herb_002
  unknown_label_regex = "^(herb|wood)_[0-9]+$",
  uuid_regex = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
  # ---- Check tolerances (issue #8; reasons in rulebook.md) -------------------
  # Belt transect (SOP): 50 m long, 5 m wide; the midpoint is the plot centre
  belt_length_m = 50,
  belt_width_m = 5,
  # Duration of a survey (start to end of form) outside this range is implausible
  duration_min_minutes = 15,
  duration_max_minutes = 180,
  # A start time later than the submission time by more than this is a clock error
  start_after_submission_tolerance_s = 60,
  # Submitted more than this many hours after the form was finished
  late_submission_hours = 12,
  # Misspelling: at most this edit distance, and at most this share of the name length
  misspelling_max_distance = 2,
  misspelling_max_relative = 0.15,
  # A genus one letter off a listed genus counts when it has at least this many letters
  misspelling_min_genus_length = 6,
  # ODK ReviewState values that mean "looked at"
  review_state_approved = "approved",
  review_state_rejected = "rejected",
  review_state_issues = "hasIssues",
  # ---- Map and dashboard (issue #10; reasons in rulebook.md) -----------------
  # Projected CRS for map distances: WGS 84 / UTM zone 37N, the zone of every plot
  # (the checks pick the zone from the points; a test asserts they agree)
  map_epsg = 32637L,
  # Severity ranking, worst first; "none" = no flag
  severity_levels = c("error", "warning", "info", "none"),
  # ---- Raw inputs -----------------------------------------------------------
  paths = list(
    odk = list(
      survey = fs::path(
        veg_raw_dir,
        "odk_exports",
        "herbaceous_veg_survey.csv"
      ),
      quadrat = fs::path(
        veg_raw_dir,
        "odk_exports",
        "herbaceous_veg_survey-quadrat_repeat.csv"
      ),
      additional = fs::path(
        veg_raw_dir,
        "odk_exports",
        "herbaceous_veg_survey-additional_species_repeat.csv"
      ),
      register = fs::path(
        veg_raw_dir,
        "odk_exports",
        "register_vegetation_plots.csv"
      )
    ),
    entity_dir = fs::path(veg_raw_dir, "entity_lists"),
    # ---- Outputs ------------------------------------------------------------
    survey = fs::path(veg_processed_dir, "veg_survey.csv"),
    quadrat = fs::path(veg_processed_dir, "veg_quadrat.csv"),
    species_long = fs::path(veg_processed_dir, "veg_species_long.csv"),
    key_integrity = fs::path(veg_processed_dir, "veg_key_integrity.csv"),
    input_findings = fs::path(veg_processed_dir, "veg_input_findings.csv"),
    dictionary = here::here("data", "definitions_vegetation_staged.txt"),
    outputs_dir = here::here("outputs", "vegetation"),
    flags_processed = fs::path(veg_processed_dir, "veg_flags.csv"),
    flags = here::here("outputs", "vegetation", "flags.csv"),
    catalogue = here::here("outputs", "vegetation", "check_catalogue.csv"),
    field_issues = here::here(
      "outputs",
      "vegetation",
      "issues_for_field_teams.csv"
    ),
    # ---- Summaries (issue #9) -----------------------------------------------
    survey_summary = here::here("outputs", "vegetation", "survey_summary.csv")
  ),
  # ---- Columns that must exist (structural: missing ones abort) -------------
  required_columns = list(
    survey = c(
      "KEY",
      "ReviewState",
      "SubmissionDate",
      "plot_selection-selected_plot_uuid",
      "plot_selection-plot_name",
      "plot_selection-get_plot_status",
      "plot_selection-plot_status",
      "survey_begin-selected_survey_uuid",
      "survey_begin-start_time",
      "field_team_specifics-recorder_uuid",
      "field_team_specifics-selected_project_team_uuid_multi",
      "field_team_specifics-selected_transport_type_uuid",
      "observations-quadrat_repeat_count",
      "survey_end-quadrats_with_species",
      "survey_end-background_geopoint-Latitude",
      "survey_end-background_geopoint-Longitude",
      "survey_end-background_geopoint-Accuracy"
    ),
    quadrat = c(
      "KEY",
      "PARENT_KEY",
      "quadrat_number",
      "herbs_present",
      "herb_species-selected_herb_species_uuids",
      "herb_species-count_herb_species",
      "additional_species_present",
      "location_quadrat-Latitude",
      "location_quadrat-Longitude",
      "location_quadrat-Accuracy"
    ),
    additional = c(
      "KEY",
      "PARENT_KEY",
      "species_entry_mode",
      "validated_name",
      "select_reuse_unknown",
      "select_reuse_missing",
      "new_missing_canonical"
    ),
    register = c(
      "KEY",
      "ReviewState",
      "plot_selection-selected_plot_uuid",
      "plot_selection-plot_name",
      "plot_selection-is_plot_viable",
      "plot_selection-sample_status"
    ),
    species = c("__id", "label", "scientific_name"),
    species_extra = c("__id", "label"),
    vegplots = c("__id", "plot_uuid", "plot_name", "plot_status", "is_viable"),
    surveys = c("__id", "label", "target_group"),
    project_team = c("__id", "label", "choice_name"),
    transport = c("__id", "label", "choice_status")
  ),
  # ---- Columns typed as numbers after the raw checks ------------------------
  numeric_columns = list(
    survey = c(
      "observations-quadrat_repeat_count",
      "survey_end-quadrats_with_species",
      "survey_end-background_geopoint-Latitude",
      "survey_end-background_geopoint-Longitude",
      "survey_end-background_geopoint-Altitude",
      "survey_end-background_geopoint-Accuracy"
    ),
    quadrat = c(
      "quadrat_number",
      "herb_species-count_herb_species",
      "location_quadrat-Latitude",
      "location_quadrat-Longitude",
      "location_quadrat-Altitude",
      "location_quadrat-Accuracy"
    ),
    additional = c(
      "observation_index",
      "count_prior_new_in_submission",
      "assigned_unknown_index"
    ),
    register = character()
  )
)

# Load the helper functions
invisible(lapply(
  X = fs::dir_ls(path = here::here("R", "functions"), regexp = "veg_.*\\.R$"),
  FUN = source
))
