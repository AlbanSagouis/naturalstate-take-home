# Single place for every path and rule value in the vegetation QA/QC part.
# Independent of the BirdNET config. Run all scripts from the project root
# (here::here() finds it).

veg_raw_dir <- here::here("data", "raw", "vegetation")
veg_processed_dir <- here::here("data", "processed")

veg_config <- list(
  # ---- Input checks ---------------------------------------------------------
  uuid_regex = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
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
    dictionary = here::here("data", "definitions_vegetation_staged.txt")
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
