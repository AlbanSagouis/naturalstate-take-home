# Load the vegetation helper functions for the tests and build tiny synthetic
# ODK tables (2 surveys, 3 quadrats, 3 additional-species rows).
invisible(lapply(
  X = fs::dir_ls(path = here::here("R", "functions"), regexp = "veg_.*\\.R$"),
  FUN = source
))

uuid_a <- "11111111-1111-4111-8111-111111111111"
uuid_b <- "22222222-2222-4222-8222-222222222222"
uuid_c <- "33333333-3333-4333-8333-333333333333"

make_veg <- function() {
  list(
    survey = tibble(
      KEY = c("uuid:s1", "uuid:s2"),
      ReviewState = c(NA, "rejected"),
      `plot_selection-selected_plot_uuid` = c("p1", "p1"),
      `plot_selection-plot_name` = c("Plot_1", "Plot_1"),
      `plot_selection-get_plot_status` = c("primary", "primary"),
      `survey_begin-selected_survey_uuid` = c("d1", "d1"),
      `survey_begin-start_time` = c(
        "2026-01-01T09:00:00",
        "2026-01-02T09:00:00"
      ),
      `field_team_specifics-recorder_uuid` = c("t1", "t1"),
      `field_team_specifics-selected_project_team_uuid_multi` = c(
        "t1 t2",
        "t1"
      ),
      `field_team_specifics-selected_transport_type_uuid` = c("x1", "x1"),
      `survey_end-background_geopoint-Latitude` = c("0.5", NA),
      `survey_end-background_geopoint-Longitude` = c("37.1", NA),
      `survey_end-background_geopoint-Accuracy` = c("3.2", NA)
    ),
    quadrat = tibble(
      KEY = c("uuid:s1/q1", "uuid:s1/q2", "uuid:s2/q1"),
      PARENT_KEY = c("uuid:s1", "uuid:s1", "uuid:s2"),
      quadrat_number = c("1", "2", "1"),
      additional_species_present = c("yes", "no", "yes"),
      `herb_species-selected_herb_species_uuids` = c(
        paste(uuid_a, uuid_b),
        NA,
        uuid_c
      )
    ),
    additional = tibble(
      KEY = c("uuid:s1/q1/a1", "uuid:s1/q1/a2", "uuid:s2/q1/a1"),
      PARENT_KEY = c("uuid:s1/q1", "uuid:s1/q1", "uuid:s2/q1"),
      species_entry_mode = c("reuse_unknown", "new_missing", "reuse_missing"),
      validated_name = c("herb_001", "Some plant", "Genus species"),
      select_reuse_unknown = c("u1", NA, NA),
      select_reuse_missing = c(NA, NA, "m1"),
      new_missing_canonical = c(NA, "Some plant", NA),
      review_status = NA_character_
    ),
    species = tibble(
      `__id` = c(uuid_a, uuid_b),
      label = c("Alpha beta", "Gamma delta"),
      scientific_name = c("Alpha beta L.", "Gamma delta L."),
      family = c("Poaceae", "Fabaceae")
    ),
    vegplots = tibble(
      `__id` = "p1",
      plot_uuid = "r1",
      plot_status = "primary",
      is_viable = "yes",
      geohash = "gh",
      stratum_label = "savanna",
      survey_uuids = "d1"
    ),
    register = tibble(
      KEY = "uuid:r1",
      ReviewState = NA_character_,
      `plot_selection-selected_plot_uuid` = "r1",
      `plot_selection-is_plot_viable` = "yes",
      `plot_selection-sample_status` = "primary"
    ),
    surveys = tibble(
      `__id` = "d1",
      label = "savmon|herbs",
      target_group = "herbs"
    ),
    project_team = tibble(
      `__id` = c("t1", "t2"),
      label = c("A", "B"),
      choice_name = c("Aa_Aa", "Bb_Bb"),
      affiliation = c("X", "Y")
    ),
    transport = tibble(
      `__id` = "x1",
      label = "Vehicle",
      choice_name = "vehicle",
      choice_status = "active"
    )
  )
}

# Paths of the real pipeline, without loading the full config script
veg_config_for_tests <- function() {
  env <- new.env()
  sys.source(file = here::here("R", "vegetation", "config.R"), envir = env)
  env$veg_config
}
