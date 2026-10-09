# Checks on the outputs of the summaries (issue #9).
# These abort too: a summary that does not add up must not be written.

#' Exclusions refer to real records and have a known reason
veg_check_exclusions <- function(exclusions, survey, quadrat) {
  checkmate::assert_list(x = exclusions, names = "named")
  checkmate::assert_subset(
    x = exclusions$quadrats$quadrat_key,
    choices = quadrat$KEY,
    .var.name = "excluded quadrat keys"
  )
  checkmate::assert_subset(
    x = exclusions$surveys$survey_key,
    choices = survey$KEY,
    .var.name = "excluded survey keys"
  )
  checkmate::assert_character(
    x = exclusions$quadrats$quadrat_key,
    unique = TRUE,
    any.missing = FALSE
  )
  checkmate::assert_character(
    x = exclusions$surveys$survey_key,
    unique = TRUE,
    any.missing = FALSE
  )
  checkmate::assert_subset(
    x = c(exclusions$quadrats$reason, exclusions$surveys$reason),
    choices = c(
      "error_flag_quadrat",
      "error_flag_survey",
      "rejected_submission"
    )
  )
  invisible(exclusions)
}

#' Survey table: one row per submission, quadrats add up, counts are coherent
#'
#' @param summary Output of veg_survey_summary().
#' @param survey,quadrat The staged tables the summary was built from.
veg_check_survey_summary <- function(summary, survey, quadrat) {
  checkmate::assert_data_frame(x = summary)
  checkmate::assert_character(
    x = summary$survey_key,
    any.missing = FALSE,
    unique = TRUE
  )
  if (!setequal(x = summary$survey_key, y = survey$KEY)) {
    cli::cli_abort("survey summary: submissions differ from the survey table.")
  }
  if (sum(summary$n_quadrats) != nrow(quadrat)) {
    cli::cli_abort(
      "survey summary: {sum(summary$n_quadrats)} quadrats, the quadrat table has {nrow(quadrat)}."
    )
  }
  checkmate::assert_integerish(
    x = c(
      summary$n_quadrats,
      summary$richness,
      summary$n_unknown_labels,
      summary$n_error,
      summary$n_warning,
      summary$n_info
    ),
    lower = 0,
    any.missing = FALSE,
    .var.name = "survey summary counts"
  )
  if (any(summary$n_quadrats_with_species > summary$n_quadrats)) {
    cli::cli_abort("survey summary: more quadrats with species than quadrats.")
  }
  if (any(summary$richness_upper_bound < summary$richness)) {
    cli::cli_abort(
      "survey summary: richness with unknowns is below the headline richness."
    )
  }
  invisible(summary)
}

#' Plot table: one row per registered plot, surveyed plots match the survey table
#'
#' @param summary Output of veg_plot_summary().
#' @param vegplots Registered plots.
#' @param survey,quadrat The staged tables the summary was built from.
veg_check_plot_summary <- function(summary, vegplots, survey, quadrat) {
  checkmate::assert_data_frame(x = summary)
  checkmate::assert_character(
    x = summary$plot_name,
    any.missing = FALSE,
    unique = TRUE
  )
  if (!setequal(x = summary$plot_name, y = vegplots$plot_name)) {
    cli::cli_abort("plot summary: plots differ from the registered plots.")
  }
  surveyed <- unique(survey$`plot_selection-plot_name`)
  if (!setequal(x = summary$plot_name[summary$surveyed], y = surveyed)) {
    cli::cli_abort("plot summary: surveyed plots differ from the survey table.")
  }
  if (sum(summary$n_surveys) != nrow(survey)) {
    cli::cli_abort(
      "plot summary: {sum(summary$n_surveys)} surveys, the survey table has {nrow(survey)}."
    )
  }
  if (sum(summary$n_quadrats) != nrow(quadrat)) {
    cli::cli_abort(
      "plot summary: {sum(summary$n_quadrats)} quadrats, the quadrat table has {nrow(quadrat)}."
    )
  }
  not_surveyed <- summary[!summary$surveyed, ]
  if (
    any(not_surveyed$n_quadrats != 0) ||
      any(!is.na(not_surveyed$gamma_richness))
  ) {
    cli::cli_abort(
      "plot summary: a plot without surveys has quadrats or a richness."
    )
  }
  done <- summary[summary$surveyed, ]
  if (
    any(done$mean_quadrat_richness > done$gamma_richness) ||
      any(done$richness_upper_bound < done$gamma_richness)
  ) {
    cli::cli_abort(
      "plot summary: mean quadrat richness above plot richness, or unknowns below it."
    )
  }
  invisible(summary)
}

#' The survey table and the plot table tell the same story
#'
#' Quadrats, surveys and flags add up between the two, and a plot never has a
#' smaller richness than any of its surveys.
veg_check_summaries_reconcile <- function(survey_summary, plot_summary) {
  for (column in c("n_quadrats", "n_error", "n_warning")) {
    if (sum(survey_summary[[column]]) != sum(plot_summary[[column]])) {
      cli::cli_abort("survey and plot summaries disagree on {column}.")
    }
  }
  if (nrow(survey_summary) != sum(plot_summary$n_surveys)) {
    cli::cli_abort(
      "survey and plot summaries disagree on the number of surveys."
    )
  }
  best <- survey_summary |>
    summarise(max_survey = max(richness), .by = plot_name) |>
    inner_join(
      y = plot_summary,
      by = "plot_name",
      relationship = "one-to-one",
      unmatched = c(x = "error", y = "drop")
    )
  if (any(best$max_survey > best$gamma_richness)) {
    cli::cli_abort("a survey has more taxa than its plot.")
  }
  invisible(survey_summary)
}

#' No richness can exceed the number of distinct names that exist
#'
#' @param n_names Distinct identified taxa in the staged species table.
veg_check_richness_bound <- function(survey_summary, plot_summary, n_names) {
  checkmate::assert_count(x = n_names)
  top <- max(
    c(survey_summary$richness, plot_summary$gamma_richness),
    na.rm = TRUE
  )
  if (top > n_names) {
    cli::cli_abort(
      "richness {top} exceeds the {n_names} distinct names in the species table."
    )
  }
  invisible(top)
}

#' The sensitivity version loses exactly the excluded records
veg_check_no_lost_records <- function(
  quadrat_all,
  quadrat_sens,
  survey_all,
  survey_sens,
  exclusions
) {
  if (nrow(quadrat_sens) + nrow(exclusions$quadrats) != nrow(quadrat_all)) {
    cli::cli_abort(
      "sensitivity: {nrow(quadrat_sens)} + {nrow(exclusions$quadrats)} excluded quadrats != {nrow(quadrat_all)}."
    )
  }
  if (nrow(survey_sens) + nrow(exclusions$surveys) != nrow(survey_all)) {
    cli::cli_abort(
      "sensitivity: {nrow(survey_sens)} + {nrow(exclusions$surveys)} excluded surveys != {nrow(survey_all)}."
    )
  }
  invisible(TRUE)
}

#' The effort table covers the surveyed plots and its numbers are possible
#'
#' Quadrat counts must equal those of the plot summary of the same version, a Chao2 estimate
#' cannot be below the observed richness, and completeness and coverage are shares.
veg_check_effort <- function(effort, plot_summary) {
  checkmate::assert_character(
    x = effort$plot_name,
    any.missing = FALSE,
    unique = TRUE
  )
  surveyed <- filter(.data = plot_summary, surveyed)
  checkmate::assert_set_equal(
    x = effort$plot_name,
    y = surveyed$plot_name,
    .var.name = "plots in the effort table"
  )
  counts <- inner_join(
    x = effort,
    y = select(.data = surveyed, plot_name, n_quadrats_summary = n_quadrats),
    by = "plot_name",
    relationship = "one-to-one",
    unmatched = c(x = "error", y = "error")
  )
  if (any(counts$n_quadrats != counts$n_quadrats_summary)) {
    cli::cli_abort(
      "Quadrat counts of the effort table differ from the plot summary."
    )
  }
  ok <- filter(.data = effort, estimate_status == "ok")
  checkmate::assert_true(x = all(ok$estimated_richness >= ok$observed_richness))
  checkmate::assert_numeric(
    x = ok$completeness,
    lower = 0,
    upper = 1,
    any.missing = FALSE
  )
  checkmate::assert_numeric(
    x = ok$sample_coverage,
    lower = 0,
    upper = 1,
    any.missing = FALSE
  )
  checkmate::assert_subset(
    x = effort$estimate_status,
    choices = c("ok", "no_taxa", "failed")
  )
  invisible(effort)
}
