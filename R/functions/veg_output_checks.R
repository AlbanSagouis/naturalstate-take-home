# Checks on the outputs of the QA/QC: the catalogue and the flags table.
# These abort (a broken output must not be written).

veg_severities <- c("error", "warning", "info")
veg_levels <- c("survey", "plot", "quadrat", "species")
veg_resolvers <- c("field team", "data manager", "Tech")

#' Check the catalogue
#'
#' @param catalogue Output of veg_check_catalogue().
#' @return `catalogue`, invisibly.
veg_check_catalogue_valid <- function(catalogue) {
  checkmate::assert_data_frame(x = catalogue, min.rows = 1)
  checkmate::assert_names(
    x = names(catalogue),
    must.include = c(
      "id",
      "level",
      "severity",
      "rule",
      "columns",
      "sop_reference",
      "message_template",
      "who_can_resolve",
      "what_to_check",
      "fun"
    )
  )
  checkmate::assert_character(
    x = catalogue$id,
    pattern = "^[A-Z]{3}-[0-9]{2}$",
    any.missing = FALSE,
    unique = TRUE
  )
  checkmate::assert_subset(x = catalogue$severity, choices = veg_severities)
  checkmate::assert_subset(x = catalogue$level, choices = veg_levels)
  checkmate::assert_subset(
    x = catalogue$who_can_resolve,
    choices = veg_resolvers
  )
  for (column in c(
    "rule",
    "columns",
    "sop_reference",
    "message_template",
    "what_to_check"
  )) {
    checkmate::assert_character(
      x = catalogue[[column]],
      min.chars = 1,
      any.missing = FALSE,
      .var.name = column
    )
  }
  placeholders <- unique(unlist(stringi::stri_extract_all_regex(
    str = catalogue$message_template,
    pattern = "\\{[a-z]+\\}"
  )))
  unknown <- setdiff(
    x = placeholders[!is.na(placeholders)],
    y = c("{plot}", "{quadrat}", "{value}", "{detail}")
  )
  if (length(unknown) > 0) {
    cli::cli_abort(
      "catalogue: unknown placeholder{?s} {unknown} in message templates."
    )
  }
  missing_fun <- catalogue$fun[
    !vapply(
      X = catalogue$fun,
      FUN = exists,
      FUN.VALUE = logical(1),
      mode = "function"
    )
  ]
  if (length(missing_fun) > 0) {
    cli::cli_abort("catalogue: no function for {missing_fun}.")
  }
  invisible(catalogue)
}

#' Check the flags table against the catalogue
#'
#' Required columns, allowed severities and levels, every check id known to the
#' catalogue, severity, level and resolver identical to the catalogue, unique
#' flag ids, no duplicate flags, non-empty messages.
#'
#' @param flags Output of veg_build_flags().
#' @param catalogue Output of veg_check_catalogue().
#' @return `flags`, invisibly.
veg_check_flags <- function(flags, catalogue) {
  veg_check_catalogue_valid(catalogue = catalogue)
  checkmate::assert_data_frame(x = flags)
  checkmate::assert_names(x = names(flags), identical.to = veg_flag_columns)
  checkmate::assert_subset(x = flags$severity, choices = veg_severities)
  checkmate::assert_subset(x = flags$level, choices = veg_levels)
  checkmate::assert_subset(x = flags$who_can_resolve, choices = veg_resolvers)
  unknown <- setdiff(x = unique(flags$check_id), y = catalogue$id)
  if (length(unknown) > 0) {
    cli::cli_abort("flags: check id{?s} {unknown} not in the catalogue.")
  }
  checkmate::assert_character(
    x = flags$flag_id,
    any.missing = FALSE,
    unique = TRUE
  )
  checkmate::assert_character(
    x = flags$message,
    min.chars = 1,
    any.missing = FALSE
  )
  spec <- catalogue[match(x = flags$check_id, table = catalogue$id), ]
  for (column in c("level", "severity", "who_can_resolve")) {
    if (!identical(x = flags[[column]], y = spec[[column]])) {
      cli::cli_abort("flags: {column} differs from the catalogue.")
    }
  }
  if (
    anyDuplicated(flags[c("check_id", "survey_key", "quadrat_key", "value")]) >
      0
  ) {
    cli::cli_abort(
      "flags: duplicate flags (same check, survey, quadrat and value)."
    )
  }
  invisible(flags)
}

#' Counts per check and severity, for the console and for reconciliation
veg_flag_counts <- function(flags, catalogue) {
  counts <- dplyr::count(x = flags, check_id, name = "n_flags")
  catalogue |>
    dplyr::select(check_id = id, level, severity) |>
    dplyr::left_join(
      y = counts,
      by = "check_id",
      relationship = "one-to-one",
      unmatched = "drop"
    ) |>
    dplyr::mutate(n_flags = dplyr::coalesce(n_flags, 0L))
}

#' The counts printed or written equal the flags table
#'
#' @param counts Output of veg_flag_counts().
veg_check_flags_reconcile <- function(flags, catalogue, counts) {
  by_check <- table(factor(x = flags$check_id, levels = catalogue$id))
  if (
    !identical(
      x = as.integer(by_check),
      y = as.integer(counts$n_flags[match(
        x = catalogue$id,
        table = counts$check_id
      )])
    )
  ) {
    cli::cli_abort("flags do not reconcile with the counts per check.")
  }
  if (sum(counts$n_flags) != nrow(flags)) {
    cli::cli_abort(
      "counts per check sum to {sum(counts$n_flags)}, flags have {nrow(flags)} rows."
    )
  }
  by_severity <- dplyr::count(x = flags, severity)
  from_counts <- dplyr::summarise(
    .data = counts,
    n = sum(n_flags),
    .by = severity
  )
  merged <- dplyr::full_join(
    x = by_severity,
    y = from_counts,
    by = "severity",
    relationship = "one-to-one"
  )
  if (any(dplyr::coalesce(merged$n.x, 0L) != dplyr::coalesce(merged$n.y, 0L))) {
    cli::cli_abort("flags do not reconcile with the counts per severity.")
  }
  invisible(flags)
}
