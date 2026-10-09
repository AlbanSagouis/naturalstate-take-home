# 01: load the ODK exports and entity lists, check keys and inputs, build the
# joined survey, quadrat and long species tables, and write them to staging.
# Nothing is dropped or changed: data errors become rows in the key-integrity
# and input-findings tables (flags are raised in issue #8).
# Run from the project root: Rscript R/vegetation/01_load_join.R

library(dplyr)
library(checkmate)

source(file = here::here("R", "vegetation", "config.R"))
paths <- veg_config$paths

# ---- Load (structural problems abort here) ----------------------------------
survey_raw <- veg_read_odk(table = "survey")
quadrat_raw <- veg_read_odk(table = "quadrat")
additional_raw <- veg_read_odk(table = "additional")
register_raw <- veg_read_odk(table = "register")
species <- veg_read_entity(name = "species")
species_extra <- veg_read_entity(name = "species_extra")
vegplots <- veg_read_entity(name = "vegplots")
surveys <- veg_read_entity(name = "surveys")
project_team <- veg_read_entity(name = "project_team")
transport <- veg_read_entity(name = "transport")

cli::cli_h1("Loaded")
cli::cli_bullets(c(
  "*" = "survey: {nrow(survey_raw)} submissions",
  "*" = "quadrat: {nrow(quadrat_raw)} rows",
  "*" = "additional species: {nrow(additional_raw)} rows",
  "*" = "plot registrations: {nrow(register_raw)} submissions",
  "*" = "species list: {nrow(species)}; vegplots: {nrow(vegplots)}"
))

# ---- Input checks (data errors become findings, never abort) ----------------
checks <- list(
  # keys
  veg_check_missing(data = survey_raw, column = "KEY", table = "survey"),
  veg_check_duplicated(data = survey_raw, column = "KEY", table = "survey"),
  veg_check_missing(data = quadrat_raw, column = "KEY", table = "quadrat"),
  veg_check_duplicated(data = quadrat_raw, column = "KEY", table = "quadrat"),
  veg_check_missing(
    data = additional_raw,
    column = "KEY",
    table = "additional"
  ),
  veg_check_duplicated(
    data = additional_raw,
    column = "KEY",
    table = "additional"
  ),
  veg_check_missing(data = register_raw, column = "KEY", table = "register"),
  veg_check_duplicated(data = register_raw, column = "KEY", table = "register"),
  veg_check_duplicated(
    data = vegplots,
    column = "__id",
    table = "vegplots",
    key = "__id"
  ),
  # parent keys, both directions
  veg_check_missing(
    data = quadrat_raw,
    column = "PARENT_KEY",
    table = "quadrat"
  ),
  veg_check_in_lookup(
    data = quadrat_raw,
    column = "PARENT_KEY",
    lookup = survey_raw$KEY,
    table = "quadrat",
    check = "parent_key_orphan"
  ),
  veg_check_missing(
    data = additional_raw,
    column = "PARENT_KEY",
    table = "additional"
  ),
  veg_check_in_lookup(
    data = additional_raw,
    column = "PARENT_KEY",
    lookup = quadrat_raw$KEY,
    table = "additional",
    check = "parent_key_orphan"
  ),
  veg_check_no_children(
    parent = survey_raw,
    child_parent_values = quadrat_raw$PARENT_KEY,
    table = "survey",
    check = "survey_without_quadrats"
  ),
  veg_check_flag_children(
    data = quadrat_raw,
    flag_column = "additional_species_present",
    child_parent_values = additional_raw$PARENT_KEY,
    expect_children = TRUE,
    table = "quadrat",
    check = "additional_present_without_rows"
  ),
  veg_check_flag_children(
    data = quadrat_raw,
    flag_column = "additional_species_present",
    child_parent_values = additional_raw$PARENT_KEY,
    expect_children = FALSE,
    table = "quadrat",
    check = "additional_rows_without_flag"
  ),
  # lookups used by the joins
  veg_check_in_lookup(
    data = survey_raw,
    column = "plot_selection-selected_plot_uuid",
    lookup = vegplots$`__id`,
    table = "survey",
    check = "plot_uuid_not_in_vegplots"
  ),
  veg_check_in_lookup(
    data = survey_raw,
    column = "survey_begin-selected_survey_uuid",
    lookup = surveys$`__id`,
    table = "survey",
    check = "survey_uuid_not_in_surveys"
  ),
  veg_check_in_lookup(
    data = survey_raw,
    column = "field_team_specifics-recorder_uuid",
    lookup = project_team$`__id`,
    table = "survey",
    check = "recorder_uuid_not_in_team"
  ),
  veg_check_in_lookup(
    data = survey_raw,
    column = "field_team_specifics-selected_project_team_uuid_multi",
    lookup = project_team$`__id`,
    table = "survey",
    check = "team_uuid_not_in_team",
    split = TRUE
  ),
  veg_check_in_lookup(
    data = survey_raw,
    column = "field_team_specifics-selected_transport_type_uuid",
    lookup = transport$`__id`,
    table = "survey",
    check = "transport_uuid_not_in_transport"
  ),
  veg_check_in_lookup(
    data = vegplots,
    column = "plot_uuid",
    lookup = register_raw$`plot_selection-selected_plot_uuid`,
    table = "vegplots",
    check = "plot_not_in_registration",
    key = "__id"
  ),
  veg_check_duplicated(
    data = survey_raw,
    column = "plot_selection-plot_name",
    table = "survey",
    check = "plot_multiple_submissions"
  ),
  # species UUIDs
  veg_check_pattern(
    data = quadrat_raw,
    column = "herb_species-selected_herb_species_uuids",
    pattern = veg_config$uuid_regex,
    table = "quadrat",
    check = "species_uuid_malformed",
    split = TRUE
  ),
  veg_check_in_lookup(
    data = quadrat_raw,
    column = "herb_species-selected_herb_species_uuids",
    lookup = species$`__id`,
    table = "quadrat",
    check = "species_uuid_not_in_species",
    split = TRUE
  ),
  veg_check_in_lookup(
    data = additional_raw,
    column = "select_reuse_unknown",
    lookup = species_extra$`__id`,
    table = "additional",
    check = "reused_unknown_uuid_not_in_species_extra"
  ),
  veg_check_in_lookup(
    data = additional_raw,
    column = "select_reuse_missing",
    lookup = species_extra$`__id`,
    table = "additional",
    check = "reused_missing_uuid_not_in_species_extra"
  ),
  veg_check_missing(
    data = additional_raw,
    column = "validated_name",
    table = "additional",
    check = "species_name_blank"
  ),
  # numbers and geopoints
  veg_check_numeric(
    data = survey_raw,
    columns = veg_config$numeric_columns$survey,
    table = "survey"
  ),
  veg_check_numeric(
    data = quadrat_raw,
    columns = veg_config$numeric_columns$quadrat,
    table = "quadrat"
  ),
  veg_check_numeric(
    data = additional_raw,
    columns = veg_config$numeric_columns$additional,
    table = "additional"
  )
)
checks <- c(
  checks,
  veg_check_geopoint(
    data = survey_raw,
    latitude = "survey_end-background_geopoint-Latitude",
    longitude = "survey_end-background_geopoint-Longitude",
    table = "survey",
    prefix = "background_geopoint"
  ),
  veg_check_geopoint(
    data = quadrat_raw,
    latitude = "location_quadrat-Latitude",
    longitude = "location_quadrat-Longitude",
    table = "quadrat",
    prefix = "quadrat_geopoint"
  )
)
checked <- veg_bind_checks(results = checks)

# ---- Type, then join --------------------------------------------------------
survey_typed <- veg_type_numeric(
  data = survey_raw,
  columns = veg_config$numeric_columns$survey
)
quadrat_typed <- veg_type_numeric(
  data = quadrat_raw,
  columns = veg_config$numeric_columns$quadrat
)
additional_typed <- veg_type_numeric(
  data = additional_raw,
  columns = veg_config$numeric_columns$additional
)

veg_survey <- veg_build_survey(
  survey = survey_typed,
  register = register_raw,
  vegplots = vegplots,
  surveys = surveys,
  project_team = project_team,
  transport = transport
)
veg_quadrat <- veg_build_quadrat(
  quadrat = quadrat_typed,
  survey = veg_survey,
  additional = additional_typed
)
veg_species_long <- veg_build_species_long(
  quadrat = quadrat_typed,
  additional = additional_typed,
  species = species
)

# ---- Reconcile: no row lost or multiplied -----------------------------------
n_selected_tokens <- nrow(veg_tokens(
  data = quadrat_raw,
  column = "herb_species-selected_herb_species_uuids",
  split = TRUE
))
assert_true(
  x = nrow(veg_survey) == nrow(survey_raw),
  .var.name = "survey rows after joins"
)
assert_true(
  x = identical(x = veg_survey$KEY, y = survey_raw$KEY),
  .var.name = "survey order kept"
)
assert_true(
  x = nrow(veg_quadrat) == nrow(quadrat_raw),
  .var.name = "quadrat rows after joins"
)
assert_true(
  x = identical(x = veg_quadrat$KEY, y = quadrat_raw$KEY),
  .var.name = "quadrat order kept"
)
assert_true(
  x = nrow(veg_species_long) == n_selected_tokens + nrow(additional_raw),
  .var.name = "species rows = selected UUIDs + additional rows"
)
assert_true(
  x = sum(veg_species_long$source == "additional_repeat") ==
    nrow(additional_raw),
  .var.name = "additional rows kept"
)
# Raw columns must come through untouched (as text)
raw_text_cols <- setdiff(
  x = names(survey_raw),
  y = veg_config$numeric_columns$survey
)
assert_true(
  x = identical(x = veg_survey[raw_text_cols], y = survey_raw[raw_text_cols]),
  .var.name = "raw survey text columns unchanged"
)

# Join outcomes, so orphans and unresolved lookups are visible rather than silent
join_checks <- list(
  veg_check_result(
    table = "survey",
    check = "join_plot_unmatched",
    n_checked = nrow(veg_survey),
    record_key = veg_survey$KEY[is.na(veg_survey$vegplots_plot_uuid)],
    column = "plot_selection-selected_plot_uuid"
  ),
  veg_check_result(
    table = "quadrat",
    check = "join_survey_unmatched",
    n_checked = nrow(veg_quadrat),
    # The join key itself: a quadrat whose PARENT_KEY is not a survey KEY (blank included)
    record_key = veg_quadrat$KEY[
      !is.element(el = veg_quadrat$PARENT_KEY, set = veg_survey$KEY)
    ],
    column = "PARENT_KEY"
  ),
  veg_check_result(
    table = "species_long",
    check = "join_quadrat_unmatched",
    n_checked = nrow(veg_species_long),
    record_key = veg_species_long$record_id[is.na(veg_species_long$survey_key)],
    column = "quadrat_key"
  ),
  veg_check_result(
    table = "species_long",
    check = "selected_species_unresolved",
    n_checked = sum(veg_species_long$source == "selected_list"),
    record_key = veg_species_long$record_id[
      veg_species_long$source == "selected_list" &
        is.na(veg_species_long$species_name)
    ],
    column = "species_uuid"
  )
)
joined <- veg_bind_checks(results = join_checks)
integrity <- bind_rows(checked$integrity, joined$integrity)
findings <- bind_rows(checked$findings, joined$findings)

# ---- Report -----------------------------------------------------------------
cli::cli_h1("Staged")
cli::cli_bullets(c(
  "v" = "survey: {nrow(veg_survey)} rows (raw {nrow(survey_raw)})",
  "v" = "quadrat: {nrow(veg_quadrat)} rows (raw {nrow(quadrat_raw)})",
  "v" = "species long: {nrow(veg_species_long)} rows = {n_selected_tokens} selected + {nrow(additional_raw)} additional"
))
problems <- filter(.data = integrity, n_problem > 0)
cli::cli_h1(
  "Key integrity: {nrow(problems)} of {nrow(integrity)} checks have findings"
)
for (i in seq_len(nrow(problems))) {
  cli::cli_alert_warning(
    "{problems$table[i]} / {problems$check[i]}: {problems$n_problem[i]} of {problems$n_checked[i]}"
  )
}

# ---- Write ------------------------------------------------------------------
fs::dir_create(path = fs::path_dir(paths$survey))
readr::write_csv(x = veg_survey, file = paths$survey, na = "")
readr::write_csv(x = veg_quadrat, file = paths$quadrat, na = "")
readr::write_csv(x = veg_species_long, file = paths$species_long, na = "")
readr::write_csv(x = integrity, file = paths$key_integrity, na = "")
readr::write_csv(x = findings, file = paths$input_findings, na = "")
veg_write_dictionary(
  tables = list(
    veg_survey = veg_survey,
    veg_quadrat = veg_quadrat,
    veg_species_long = veg_species_long,
    veg_key_integrity = integrity,
    veg_input_findings = findings
  ),
  path = paths$dictionary,
  numeric_columns = list(
    veg_survey = veg_config$numeric_columns$survey,
    veg_quadrat = veg_config$numeric_columns$quadrat
  )
)
cli::cli_alert_success(
  "Wrote staging tables to {.path {fs::path_dir(paths$survey)}}"
)
