# Input checks for the raw vegetation files.
# Two kinds, kept apart on purpose:
# - veg_assert_*: structural breakage (missing column, unreadable file). They
#   abort with cli::cli_abort().
# - veg_check_*: data errors. They never abort; they return
#   list(summary = one row, findings = one row per problem) which later become
#   the flags of the QA/QC (issue #8). The data are never changed.

#' Assert that required columns exist
#'
#' @param data Data frame.
#' @param required Column names.
#' @param label Name used in the message.
#' @return `data`, invisibly.
veg_assert_columns <- function(data, required, label) {
  missing_cols <- setdiff(x = required, y = names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      "{label}: missing required column{?s} {.field {missing_cols}}."
    )
  }
  invisible(data)
}

#' TRUE for NA, empty and whitespace-only strings
veg_is_blank <- function(x) {
  is.na(x) | stringi::stri_isempty(str = stringi::stri_trim_both(str = x))
}

#' Record identifier for findings: the key if present, else the row number
veg_record_key <- function(data, key = "KEY") {
  rows <- paste0("row_", seq_len(nrow(data)))
  if (!is.element(el = key, set = names(data))) {
    return(rows)
  }
  if_else(
    condition = veg_is_blank(data[[key]]),
    true = rows,
    false = data[[key]]
  )
}

#' Build one check result
#'
#' @param table,check Labels.
#' @param n_checked Number of items looked at.
#' @param record_key,column,value Vectors, one entry per problem.
#' @return list(summary, findings).
veg_check_result <- function(
  table,
  check,
  n_checked,
  record_key = character(),
  column = character(),
  value = character()
) {
  n_problem <- length(record_key)
  findings <- tibble(
    table = rep(x = table, times = n_problem),
    check = rep(x = check, times = n_problem),
    record_key = as.character(record_key),
    column = rep_len(x = as.character(column), length.out = n_problem),
    value = rep_len(x = as.character(value), length.out = n_problem)
  )
  summary <- tibble(
    table = table,
    check = check,
    n_checked = as.integer(n_checked),
    n_problem = as.integer(n_problem)
  )
  list(summary = summary, findings = findings)
}

#' Combine check results into one integrity table and one findings table
#'
#' @param results List of veg_check_result() outputs.
veg_bind_checks <- function(results) {
  checkmate::assert_list(x = results, types = "list", min.len = 1)
  list(
    integrity = bind_rows(lapply(X = results, FUN = `[[`, "summary")),
    findings = bind_rows(lapply(X = results, FUN = `[[`, "findings"))
  )
}

# ODK stores several selected entities in one cell. The export separates UUIDs
# with a space; the derived species lists use <br/>. Accept both.
veg_id_separator_regex <- "\\s+|<br/>"

#' Tokens of a column, one row per token (cells split when `split` is TRUE)
veg_tokens <- function(
  data,
  column,
  split = FALSE,
  separator = veg_id_separator_regex
) {
  x <- data[[column]]
  pieces <- if (split) {
    stringi::stri_split_regex(str = x, pattern = separator, omit_empty = TRUE)
  } else {
    as.list(x)
  }
  tibble(
    row = rep(x = seq_along(x), times = lengths(pieces)),
    token = unlist(x = pieces, use.names = FALSE) %||% character()
  ) |>
    filter(!veg_is_blank(x = token))
}

#' Key values that are blank
veg_check_missing <- function(
  data,
  column,
  table,
  check = paste0(column, "_missing"),
  key = "KEY"
) {
  bad <- veg_is_blank(x = data[[column]])
  veg_check_result(
    table = table,
    check = check,
    n_checked = nrow(data),
    record_key = veg_record_key(data = data, key = key)[bad],
    column = column
  )
}

#' Values that occur more than once (blank values are ignored)
veg_check_duplicated <- function(
  data,
  column,
  table,
  check = paste0(column, "_duplicated"),
  key = "KEY"
) {
  x <- data[[column]]
  bad <- !veg_is_blank(x = x) & (duplicated(x) | duplicated(x, fromLast = TRUE))
  veg_check_result(
    table = table,
    check = check,
    n_checked = sum(!veg_is_blank(x = x)),
    record_key = veg_record_key(data = data, key = key)[bad],
    column = column,
    value = x[bad]
  )
}

#' Values not found in a lookup (orphans); blank values are not checked
#'
#' @param lookup Character vector of valid values.
#' @param split Split cells holding several ids.
veg_check_in_lookup <- function(
  data,
  column,
  lookup,
  table,
  check,
  key = "KEY",
  split = FALSE
) {
  tokens <- veg_tokens(data = data, column = column, split = split)
  bad <- !is.element(el = tokens$token, set = lookup)
  veg_check_result(
    table = table,
    check = check,
    n_checked = nrow(tokens),
    record_key = veg_record_key(data = data, key = key)[tokens$row[bad]],
    column = column,
    value = tokens$token[bad]
  )
}

#' Parents with no child row (the reverse direction of an orphan check)
#'
#' @param child_parent_values PARENT_KEY values of the child table.
veg_check_no_children <- function(
  parent,
  child_parent_values,
  table,
  check,
  parent_key = "KEY"
) {
  bad <- !is.element(el = parent[[parent_key]], set = child_parent_values)
  veg_check_result(
    table = table,
    check = check,
    n_checked = nrow(parent),
    record_key = veg_record_key(data = parent, key = parent_key)[bad],
    column = parent_key
  )
}

#' Rows whose yes/no flag disagrees with the existence of child rows
#'
#' @param expect_children TRUE: flag is `yes_value` but there are no child rows.
#'   FALSE: child rows exist but the flag is not `yes_value`.
veg_check_flag_children <- function(
  data,
  flag_column,
  yes_value = "yes",
  child_parent_values,
  expect_children,
  table,
  check,
  key = "KEY"
) {
  flagged <- !is.na(data[[flag_column]]) & data[[flag_column]] == yes_value
  has_children <- is.element(el = data[[key]], set = child_parent_values)
  bad <- if (expect_children) {
    flagged & !has_children
  } else {
    !flagged & has_children
  }
  veg_check_result(
    table = table,
    check = check,
    n_checked = nrow(data),
    record_key = veg_record_key(data = data, key = key)[bad],
    column = flag_column,
    value = data[[flag_column]][bad]
  )
}

#' Tokens that do not match a regular expression (e.g. a malformed UUID)
veg_check_pattern <- function(
  data,
  column,
  pattern,
  table,
  check,
  key = "KEY",
  split = FALSE
) {
  tokens <- veg_tokens(data = data, column = column, split = split)
  bad <- !stringi::stri_detect_regex(str = tokens$token, pattern = pattern)
  veg_check_result(
    table = table,
    check = check,
    n_checked = nrow(tokens),
    record_key = veg_record_key(data = data, key = key)[tokens$row[bad]],
    column = column,
    value = tokens$token[bad]
  )
}

#' Non-blank cells that cannot be read as a number
veg_check_numeric <- function(
  data,
  columns,
  table,
  check = "numeric_unparseable",
  key = "KEY"
) {
  checkmate::assert_subset(x = columns, choices = names(data))
  per_column <- lapply(X = columns, FUN = function(column) {
    x <- data[[column]]
    bad <- !veg_is_blank(x = x) & is.na(veg_to_numeric(x = x))
    list(
      n = sum(!veg_is_blank(x = x)),
      key = veg_record_key(data = data, key = key)[bad],
      column = rep(x = column, times = sum(bad)),
      value = x[bad]
    )
  })
  veg_check_result(
    table = table,
    check = check,
    n_checked = sum(vapply(
      X = per_column,
      FUN = `[[`,
      FUN.VALUE = numeric(1),
      "n"
    )),
    record_key = unlist(x = lapply(X = per_column, FUN = `[[`, "key")) %||%
      character(),
    column = unlist(x = lapply(X = per_column, FUN = `[[`, "column")) %||%
      character(),
    value = unlist(x = lapply(X = per_column, FUN = `[[`, "value")) %||%
      character()
  )
}

#' Geopoint checks: coordinates present, and within the valid range
#'
#' Accuracy against the SOP limit is a rule check for issue #8, not here.
#'
#' @return list of two veg_check_result() outputs (missing, out of range).
veg_check_geopoint <- function(
  data,
  latitude,
  longitude,
  table,
  prefix,
  key = "KEY"
) {
  lat <- veg_to_numeric(x = data[[latitude]])
  lon <- veg_to_numeric(x = data[[longitude]])
  missing <- is.na(lat) | is.na(lon)
  out_of_range <- !missing & (abs(lat) > 90 | abs(lon) > 180)
  keys <- veg_record_key(data = data, key = key)
  list(
    veg_check_result(
      table = table,
      check = paste0(prefix, "_missing"),
      n_checked = nrow(data),
      record_key = keys[missing],
      column = latitude
    ),
    veg_check_result(
      table = table,
      check = paste0(prefix, "_out_of_range"),
      n_checked = sum(!missing),
      record_key = keys[out_of_range],
      column = latitude,
      value = paste(lat[out_of_range], lon[out_of_range])
    )
  )
}
