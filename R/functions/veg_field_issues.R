# The list of errors and warnings for the data providers (field teams),
# built from the flags table. Info flags stay in the flags table, and so do the flags of
# submissions rejected in ODK: there is nothing to fix on a submission nobody uses.

veg_field_issue_columns <- c(
  "plot",
  "date",
  "quadrat",
  "recorder",
  "severity",
  "message",
  "what_to_check",
  "sop_section",
  "who_can_resolve",
  "check_id",
  "survey_key"
)

#' @param flags,catalogue As for veg_check_flags().
#' @param quadrat Staged quadrat table (KEY and quadrat_number), to show the quadrat number.
#' @param rejected_keys Keys of the submissions rejected in ODK (veg_rejected_keys()); their
#'   flags are left off the list.
#' @return Tibble with the columns in `veg_field_issue_columns`, ordered by plot,
#'   date, quadrat, severity (errors first).
veg_field_issues <- function(
  flags,
  catalogue,
  quadrat,
  rejected_keys = character(0)
) {
  checkmate::assert_character(x = rejected_keys, any.missing = FALSE)
  numbers <- distinct(
    .data = select(
      .data = quadrat,
      quadrat_key = KEY,
      quadrat = quadrat_number
    ),
    quadrat_key,
    .keep_all = TRUE
  )
  spec <- select(
    .data = catalogue,
    check_id = id,
    what_to_check,
    sop_section = sop_reference
  )
  flags |>
    filter(
      is.element(el = severity, set = c("error", "warning")),
      !is.element(el = survey_key, set = rejected_keys)
    ) |>
    left_join(
      y = spec,
      by = "check_id",
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    left_join(
      y = numbers,
      by = "quadrat_key",
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    mutate(plot = plot_name, date = survey_date) |>
    arrange(
      plot,
      date,
      survey_key,
      match(x = severity, table = veg_severities),
      check_id,
      as.integer(quadrat)
    ) |>
    select(all_of(veg_field_issue_columns))
}
