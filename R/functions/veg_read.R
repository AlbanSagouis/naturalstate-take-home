# Readers for the ODK exports and entity lists. Raw column names are kept as
# they are and nothing is added. Everything is read as text first so that a
# malformed number is still visible to the input checks; numeric columns are
# typed afterwards with veg_type_numeric().

#' Read one CSV as text, failing loudly if it is missing, unreadable or lacks
#' required columns
#'
#' Blank cells become NA; whitespace is kept as received (stray spaces in free
#' text are a data issue to flag, not to trim away).
#'
#' @param path File path.
#' @param required Column names that must exist.
#' @param label Name used in messages.
#' @return A tibble of character columns.
veg_read_csv <- function(
  path,
  required = character(),
  label = fs::path_file(path)
) {
  checkmate::assert_string(x = path)
  checkmate::assert_character(x = required, any.missing = FALSE)
  if (!fs::file_exists(path = path)) {
    cli::cli_abort("{label}: file not found at {.path {path}}.")
  }
  out <- tryCatch(
    expr = readr::read_csv(
      file = path,
      col_types = readr::cols(.default = readr::col_character()),
      na = "",
      trim_ws = FALSE,
      progress = FALSE
    ),
    error = function(e) {
      cli::cli_abort("{label}: unreadable ({conditionMessage(e)}).")
    }
  )
  veg_assert_columns(data = out, required = required, label = label)
  out
}

#' Read one of the four ODK exports
#'
#' @param table One of "survey", "quadrat", "additional", "register".
#' @param config The vegetation config.
veg_read_odk <- function(
  table = c("survey", "quadrat", "additional", "register"),
  config = veg_config
) {
  table <- match.arg(arg = table)
  veg_read_csv(
    path = config$paths$odk[[table]],
    required = config$required_columns[[table]],
    label = table
  )
}

#' Read an entity list (species, vegplots, surveys, project_team, ...)
#'
#' @param name File name without extension, e.g. "species".
#' @param config The vegetation config.
veg_read_entity <- function(name, config = veg_config) {
  checkmate::assert_string(x = name)
  veg_read_csv(
    path = fs::path(config$paths$entity_dir, paste0(name, ".csv")),
    required = config$required_columns[[name]] %||% character(),
    label = name
  )
}

#' Convert text to numbers without warnings
#'
#' Only strings that look like a number are converted; everything else becomes
#' NA. veg_check_numeric() reports the strings that were refused.
#'
#' @param x Character vector.
#' @return Numeric vector.
veg_to_numeric <- function(x) {
  checkmate::assert_character(x = x)
  ok <- !is.na(x) &
    stringi::stri_detect_regex(
      str = x,
      pattern = "^\\s*-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?\\s*$"
    )
  out <- rep(x = NA_real_, times = length(x))
  out[ok] <- as.numeric(x[ok])
  out
}

#' Type the listed columns as numbers
#'
#' @param data Data frame of text columns.
#' @param columns Column names to convert.
veg_type_numeric <- function(data, columns) {
  checkmate::assert_data_frame(x = data)
  checkmate::assert_subset(x = columns, choices = names(data))
  data[columns] <- lapply(X = data[columns], FUN = veg_to_numeric)
  data
}
