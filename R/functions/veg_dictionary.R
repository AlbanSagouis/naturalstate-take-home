# Data dictionary of the staged vegetation tables. Raw ODK columns are listed
# automatically (meaning "as exported"), so the dictionary cannot drift from
# the tables; only the added or special columns are described by hand.

veg_dictionary_notes <- c(
  KEY = "ODK primary key of the row (submission or repeat instance)",
  PARENT_KEY = "KEY of the parent row (survey for a quadrat, quadrat for an additional-species row)",
  quadrat_number = "Quadrat number along the transect (SOP: 1 to 20)",
  `plot_selection-selected_plot_uuid` = "Plot chosen in the form; matches vegplots.csv __id, not its plot_uuid column",
  `plot_selection-get_plot_status` = "Plot status read by the form (primary or backup); plot_selection-plot_status is blank in the export",
  `herb_species-selected_herb_species_uuids` = "Species picked from the entity list: UUIDs separated by a space",
  vegplots_plot_uuid = "vegplots.csv plot_uuid (joins to the registration form)",
  vegplots_plot_status = "vegplots.csv plot_status",
  vegplots_is_viable = "vegplots.csv is_viable",
  vegplots_geohash = "vegplots.csv geohash",
  vegplots_stratum_label = "vegplots.csv stratum_label",
  vegplots_survey_uuids = "vegplots.csv survey_uuids",
  register_KEY = "KEY of the plot registration submission for this plot",
  register_ReviewState = "ReviewState of the registration submission",
  register_is_plot_viable = "plot_selection-is_plot_viable of the registration",
  register_sample_status = "plot_selection-sample_status of the registration",
  surveydef_label = "surveys.csv label of the survey definition",
  surveydef_target_group = "surveys.csv target_group",
  recorder_choice_name = "project_team.csv choice_name of the recorder",
  recorder_affiliation = "project_team.csv affiliation of the recorder",
  transport_choice_name = "transport.csv choice_name",
  transport_choice_status = "transport.csv choice_status (active or inactive)",
  team_choice_names = "project_team.csv choice_name of each team member, joined by '; ' (unresolved UUIDs kept as the UUID)",
  survey_plot_name = "plot_selection-plot_name of the parent survey",
  survey_plot_status = "plot_selection-get_plot_status of the parent survey",
  survey_start_time = "survey_begin-start_time of the parent survey",
  survey_ReviewState = "ReviewState of the parent survey",
  n_additional_rows = "Number of additional-species rows whose PARENT_KEY is this quadrat",
  source = "selected_list (picked from the species list) or additional_repeat (additional-species repeat)",
  record_id = "KEY of the additional-species row; for selected_list rows quadrat KEY + '#' + position in the cell",
  survey_key = "KEY of the parent survey (NA if the quadrat is an orphan)",
  quadrat_key = "KEY of the quadrat the record belongs to",
  species_uuid = "Species entity UUID (selected_list) or reused entity UUID (additional_repeat)",
  species_name = "selected_list: species.csv label (NA if unresolved); additional_repeat: validated_name as received",
  scientific_name = "species.csv scientific_name (selected_list only)",
  family = "species.csv family (selected_list only)",
  species_entry_mode = "Entry mode in the additional-species repeat (new/reuse x missing/unknown)",
  new_missing_canonical = "As exported",
  review_status = "As exported",
  table = "Table the check ran on",
  check = "Name of the check",
  n_checked = "Number of items looked at",
  n_problem = "Number of items with a problem",
  record_key = "KEY of the record with the problem (row_N when the key is blank)",
  column = "Column the check looked at",
  value = "The value that was refused or found, as received"
)

veg_dictionary_default <- "As exported by ODK Central, unchanged"
veg_dictionary_numeric <- "As exported by ODK Central, read as a number (text that is not a number becomes NA and is reported in veg_input_findings)"

#' Build the dictionary rows for one staged table
#'
#' @param data The staged table.
#' @param table Table name.
#' @param notes Named character vector of meanings.
#' @param numeric_columns Columns that were read as numbers (the others are text as received).
veg_dictionary_table <- function(
  data,
  table,
  notes = veg_dictionary_notes,
  numeric_columns = character()
) {
  checkmate::assert_data_frame(x = data)
  checkmate::assert_character(x = numeric_columns, any.missing = FALSE)
  meaning <- unname(notes[names(data)])
  raw <- is.na(meaning)
  meaning[raw] <- if_else(
    condition = is.element(el = names(data)[raw], set = numeric_columns),
    true = veg_dictionary_numeric,
    false = veg_dictionary_default
  )
  tibble(table = table, column = names(data), meaning = meaning)
}

#' Write the dictionary as plain text
#'
#' @param tables Named list of staged tables.
#' @param path Output file.
#' @param numeric_columns Named list (names as in `tables`) of the columns read as numbers.
veg_write_dictionary <- function(tables, path, numeric_columns = list()) {
  checkmate::assert_list(x = tables, names = "named")
  checkmate::assert_list(x = numeric_columns, names = "named")
  rows <- bind_rows(lapply(
    X = names(tables),
    FUN = function(name) {
      veg_dictionary_table(
        data = tables[[name]],
        table = name,
        numeric_columns = numeric_columns[[name]] %||% character()
      )
    }
  ))
  lines <- c(
    "Staged vegetation tables (written by R/vegetation/01_load_join.R)",
    "Format: column | meaning (source column = the column itself unless stated)",
    "Raw ODK columns keep their exported names and values (text as received), except the columns",
    "marked as read as numbers.",
    ""
  )
  for (name in names(tables)) {
    part <- rows[rows$table == name, ]
    lines <- c(
      lines,
      paste0("## ", name, " (", nrow(tables[[name]]), " rows)"),
      paste(part$column, part$meaning, sep = " | "),
      ""
    )
  }
  writeLines(text = lines, con = path)
  invisible(rows)
}
