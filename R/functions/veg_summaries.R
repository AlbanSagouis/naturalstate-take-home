# Survey-level and plot-level summaries (issue #9). Nothing is changed or fixed:
# a summary only counts what the staged tables contain. Records can be left out
# of the sensitivity version (veg_exclusions), never repaired. The species identity rule
# (identified taxon or provisional unknown) is in veg_taxa.R.

#' The part of the exclusions that is a reviewer's decision
#'
#' A rejected submission is left out of the plot-level and headline numbers of every
#' version, not only of the sensitivity version: the reviewer already judged it
#' unusable, and counting it would give a plot the quadrats of two visits.
#'
#' @param exclusions Output of veg_exclusions().
veg_rejected_exclusions <- function(exclusions) {
  list(
    quadrats = filter(
      .data = exclusions$quadrats,
      reason == "rejected_submission"
    ),
    surveys = filter(
      .data = exclusions$surveys,
      reason == "rejected_submission"
    )
  )
}

#' Flags that belong to submissions that were not rejected
#'
#' The flags of a rejected submission stay in flags.csv and in the survey table; the plot
#' counts and the map use this subset, so a plot is not coloured by a submission nobody uses.
veg_flags_accepted <- function(flags, survey, config = veg_config) {
  checkmate::assert_names(x = names(flags), must.include = "survey_key")
  flags[
    !is.element(
      el = flags$survey_key,
      set = veg_rejected_keys(survey = survey, config = config)
    ),
  ]
}

#' Records to leave out of the sensitivity version, and of the main version when rejected
#'
#' Rule: a quadrat with an error-severity flag is left out (the other quadrats of
#' the submission stay); an error flag without a quadrat (survey level) leaves out
#' the whole submission; a submission with ReviewState "rejected" is left out (reason
#' `rejected_submission`; this one also leaves the main version, see veg_rejected_exclusions()).
#'
#' @param flags Long flags table (outputs/vegetation/flags.csv).
#' @param survey,quadrat Staged tables.
#' @return List: `quadrats` (quadrat_key, survey_key, reason) and `surveys`
#'   (survey_key, reason).
veg_exclusions <- function(flags, survey, quadrat, config = veg_config) {
  checkmate::assert_data_frame(x = flags)
  checkmate::assert_names(
    x = names(flags),
    must.include = c("severity", "survey_key", "quadrat_key")
  )
  checkmate::assert_character(
    x = survey$KEY,
    any.missing = FALSE,
    unique = TRUE
  )
  checkmate::assert_character(
    x = quadrat$KEY,
    any.missing = FALSE,
    unique = TRUE
  )
  errors <- filter(.data = flags, severity == config$excluded_severity)

  rejected <- veg_rejected_keys(survey = survey, config = config)
  survey_errors <- unique(errors$survey_key[is.na(errors$quadrat_key)])
  quadrat_errors <- unique(errors$quadrat_key[!is.na(errors$quadrat_key)])
  unknown_quadrats <- setdiff(x = quadrat_errors, y = quadrat$KEY)
  if (length(unknown_quadrats) > 0) {
    cli::cli_abort(
      "{length(unknown_quadrats)} error-flagged quadrat key{?s} not in the quadrat table."
    )
  }

  surveys <- bind_rows(
    tibble(
      survey_key = rejected,
      reason = rep(x = "rejected_submission", times = length(rejected))
    ),
    tibble(
      survey_key = survey_errors,
      reason = rep(x = "error_flag_survey", times = length(survey_errors))
    )
  ) |>
    distinct(survey_key, .keep_all = TRUE)
  by_quadrat <- tibble(
    quadrat_key = quadrat_errors,
    reason = rep(x = "error_flag_quadrat", times = length(quadrat_errors))
  )
  quadrats <- quadrat |>
    select(quadrat_key = KEY, survey_key = PARENT_KEY) |>
    left_join(
      y = surveys,
      by = "survey_key",
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    left_join(
      y = rename(.data = by_quadrat, reason_quadrat = reason),
      by = "quadrat_key",
      relationship = "one-to-one",
      unmatched = "drop"
    ) |>
    mutate(reason = coalesce(reason, reason_quadrat)) |>
    filter(!is.na(reason)) |>
    select(quadrat_key, survey_key, reason)
  list(quadrats = quadrats, surveys = surveys)
}

#' Drop the excluded records from the staged tables (a view, not a repair)
veg_apply_exclusions <- function(survey, quadrat, records, exclusions) {
  list(
    survey = filter(
      .data = survey,
      !is.element(el = KEY, set = exclusions$surveys$survey_key)
    ),
    quadrat = filter(
      .data = quadrat,
      !is.element(el = KEY, set = exclusions$quadrats$quadrat_key)
    ),
    records = filter(
      .data = records,
      !is.element(el = quadrat_key, set = exclusions$quadrats$quadrat_key)
    )
  )
}

#' Per quadrat: identified taxa, distinct unknown labels, any record at all
#'
#' @return Tibble with one row per quadrat in `quadrat` (zero counts kept):
#'   quadrat_key, survey_key, n_identified, n_unknown, has_unknown, n_records.
veg_quadrat_counts <- function(quadrat, records) {
  checkmate::assert_data_frame(x = quadrat)
  checkmate::assert_data_frame(x = records)
  counted <- records |>
    summarise(
      n_identified = n_distinct(taxon, na.rm = TRUE),
      n_unknown = n_distinct(unknown_label, na.rm = TRUE),
      has_unknown = any(!is.element(el = taxon_class, set = "identified")),
      n_records = n(),
      .by = quadrat_key
    )
  quadrat |>
    select(quadrat_key = KEY, survey_key = PARENT_KEY) |>
    left_join(
      y = counted,
      by = "quadrat_key",
      relationship = "one-to-one",
      unmatched = "error"
    ) |>
    mutate(
      n_identified = coalesce(n_identified, 0L),
      n_unknown = coalesce(n_unknown, 0L),
      has_unknown = coalesce(has_unknown, FALSE),
      n_records = coalesce(n_records, 0L)
    )
}

#' Flags per key and severity, as three count columns
veg_flag_severity_counts <- function(flags, by) {
  checkmate::assert_string(x = by)
  counts <- flags |>
    filter(!is.na(.data[[by]])) |>
    summarise(n = n(), .by = c(all_of(by), severity)) |>
    tidyr::pivot_wider(names_from = severity, values_from = n, values_fill = 0L)
  for (severity in c("error", "warning", "info")) {
    if (!is.element(el = severity, set = names(counts))) {
      counts[[severity]] <- integer(length = nrow(counts))
    }
  }
  counts |>
    select(all_of(by), n_error = error, n_warning = warning, n_info = info)
}

#' Survey-level table: one row per submission
#'
#' @param survey,quadrat Staged tables (already filtered for a sensitivity version).
#' @param records Output of veg_record_taxa(), filtered the same way.
#' @param flags All flags (flag counts describe the submission, so they are never filtered).
veg_survey_summary <- function(survey, quadrat, records, flags) {
  checkmate::assert_data_frame(x = survey)
  checkmate::assert_character(
    x = survey$KEY,
    any.missing = FALSE,
    unique = TRUE
  )
  per_quadrat <- veg_quadrat_counts(quadrat = quadrat, records = records)
  unorphaned <- setdiff(x = unique(per_quadrat$survey_key), y = survey$KEY)
  if (length(unorphaned) > 0) {
    cli::cli_abort(
      "{length(unorphaned)} quadrat{?s} point to a submission that is not in the survey table."
    )
  }
  by_quadrat <- per_quadrat |>
    summarise(
      n_quadrats = n(),
      n_quadrats_with_species = sum(n_records > 0),
      .by = survey_key
    )
  by_species <- records |>
    summarise(
      richness = n_distinct(taxon, na.rm = TRUE),
      n_unknown_labels = n_distinct(unknown_label, na.rm = TRUE),
      richness_upper_bound = richness + n_unknown_labels,
      .by = survey_key
    )
  times <- veg_survey_typed(ctx = list(survey = survey))
  survey |>
    mutate(
      survey_key = KEY,
      plot_name = .data[["plot_selection-plot_name"]],
      plot_status = .data[["plot_selection-get_plot_status"]],
      review_state = ReviewState,
      survey_date = stringi::stri_sub(
        str = .data[["survey_begin-start_time"]],
        from = 1,
        length = 10
      ),
      recorder = recorder_choice_name,
      duration_min = round(
        as.numeric(difftime(
          time1 = times$end,
          time2 = times$start,
          units = "mins"
        )),
        digits = 1
      )
    ) |>
    select(
      survey_key,
      plot_name,
      plot_status,
      review_state,
      survey_date,
      recorder,
      duration_min
    ) |>
    left_join(
      y = by_quadrat,
      by = "survey_key",
      relationship = "one-to-one",
      unmatched = "drop"
    ) |>
    left_join(
      y = by_species,
      by = "survey_key",
      relationship = "one-to-one",
      unmatched = "drop"
    ) |>
    left_join(
      y = veg_flag_severity_counts(flags = flags, by = "survey_key"),
      by = "survey_key",
      relationship = "one-to-one",
      unmatched = "drop"
    ) |>
    mutate(across(
      .cols = c(
        n_quadrats,
        n_quadrats_with_species,
        richness,
        n_unknown_labels,
        richness_upper_bound,
        n_error,
        n_warning,
        n_info
      ),
      .fns = \(x) coalesce(as.integer(x), 0L)
    ))
}

#' Plot-level table: one row per registered plot
#'
#' Richness is reported twice: identified taxa only, and with the provisional unknown
#' labels added. Diversity indices are not reported; the plot-diversity check PLT-09 uses
#' Shannon's H' only to find odd plots.
#'
#' @param survey,quadrat,records Staged tables (filtered for a sensitivity version).
#' @param vegplots The entity list of registered plots (plot_name, plot_status, is_viable).
#' @param flags All flags; plot counts use the `plot_name` column.
veg_plot_summary <- function(survey, quadrat, records, vegplots, flags) {
  checkmate::assert_names(
    x = names(vegplots),
    must.include = c("plot_name", "plot_status", "is_viable")
  )
  checkmate::assert_character(
    x = vegplots$plot_name,
    any.missing = FALSE,
    unique = TRUE
  )
  survey_plot <- select(
    .data = survey,
    survey_key = KEY,
    plot_name = `plot_selection-plot_name`
  )
  unregistered <- setdiff(x = survey_plot$plot_name, y = vegplots$plot_name)
  if (length(unregistered) > 0) {
    cli::cli_abort("Surveyed plot{?s} not registered: {unregistered}.")
  }
  per_quadrat <- veg_quadrat_counts(quadrat = quadrat, records = records) |>
    inner_join(
      y = survey_plot,
      by = "survey_key",
      relationship = "many-to-one",
      unmatched = c(x = "error", y = "drop")
    )
  by_quadrat <- per_quadrat |>
    summarise(
      n_quadrats = n(),
      mean_quadrat_richness = mean(n_identified),
      share_quadrats_unknown = mean(has_unknown),
      .by = plot_name
    )
  by_survey <- survey_plot |>
    summarise(n_surveys = n(), .by = plot_name)
  records_plot <- records |>
    inner_join(
      y = survey_plot,
      by = "survey_key",
      relationship = "many-to-one",
      unmatched = c(x = "error", y = "drop")
    )
  by_species <- records_plot |>
    summarise(
      gamma_richness = n_distinct(taxon, na.rm = TRUE),
      n_unknown_labels = n_distinct(unknown_label, na.rm = TRUE),
      .by = plot_name
    )
  vegplots |>
    select(plot_name, plot_status, is_viable) |>
    left_join(
      y = by_survey,
      by = "plot_name",
      relationship = "one-to-one",
      unmatched = "error"
    ) |>
    left_join(
      y = by_quadrat,
      by = "plot_name",
      relationship = "one-to-one",
      unmatched = "error"
    ) |>
    left_join(
      y = by_species,
      by = "plot_name",
      relationship = "one-to-one",
      unmatched = "error"
    ) |>
    left_join(
      y = veg_flag_severity_counts(flags = flags, by = "plot_name"),
      by = "plot_name",
      relationship = "one-to-one",
      unmatched = "drop"
    ) |>
    mutate(
      surveyed = !is.na(n_surveys),
      across(
        .cols = c(
          n_surveys,
          n_quadrats,
          n_unknown_labels,
          n_error,
          n_warning
        ),
        .fns = \(x) coalesce(as.integer(x), 0L)
      ),
      gamma_richness = if_else(
        condition = surveyed,
        true = coalesce(gamma_richness, 0L),
        false = NA_integer_
      ),
      richness_upper_bound = gamma_richness + n_unknown_labels
    ) |>
    select(
      plot_name,
      plot_status,
      is_viable,
      surveyed,
      n_surveys,
      n_quadrats,
      gamma_richness,
      mean_quadrat_richness,
      share_quadrats_unknown,
      n_unknown_labels,
      richness_upper_bound,
      n_error,
      n_warning
    ) |>
    arrange(plot_name)
}

#' Overall totals of one version of the summaries (one row)
#'
#' @param version Label of the version ("accepted" or "excluding_errors").
#' @param n_registered Number of registered plots.
veg_totals <- function(
  version,
  survey_summary,
  plot_summary,
  quadrat,
  records,
  flags
) {
  checkmate::assert_string(x = version)
  per_quadrat <- veg_quadrat_counts(quadrat = quadrat, records = records)
  surveyed <- filter(.data = plot_summary, surveyed)
  tibble(
    version = version,
    n_surveys = nrow(survey_summary),
    n_plots_registered = nrow(plot_summary),
    n_plots_surveyed = nrow(surveyed),
    n_quadrats = nrow(per_quadrat),
    richness_all_plots = n_distinct(records$taxon, na.rm = TRUE),
    n_unknown_labels_all_plots = n_distinct(
      records$unknown_label,
      na.rm = TRUE
    ),
    richness_upper_bound_all_plots = richness_all_plots +
      n_unknown_labels_all_plots,
    mean_quadrat_richness = mean(per_quadrat$n_identified),
    gamma_richness_min = min(surveyed$gamma_richness),
    gamma_richness_median = stats::median(surveyed$gamma_richness),
    gamma_richness_max = max(surveyed$gamma_richness),
    share_quadrats_unknown = mean(per_quadrat$has_unknown),
    n_flags_error = sum(flags$severity == "error"),
    n_flags_warning = sum(flags$severity == "warning"),
    n_flags_info = sum(flags$severity == "info")
  )
}

#' Change in the plot-level numbers when the flagged records are left out
#'
#' @return One row per surveyed plot: all-records value, excluding-errors value
#'   and their difference, for quadrats, gamma richness and mean quadrat richness.
veg_plot_shift <- function(plot_all, plot_sens) {
  metrics <- c(
    "n_quadrats",
    "gamma_richness",
    "mean_quadrat_richness"
  )
  keep <- function(data, suffix) {
    data |>
      filter(surveyed) |>
      select(plot_name, all_of(metrics)) |>
      rename_with(.fn = \(x) paste0(x, suffix), .cols = all_of(metrics))
  }
  out <- inner_join(
    x = keep(data = plot_all, suffix = "_all"),
    y = keep(data = plot_sens, suffix = "_sens"),
    by = "plot_name",
    relationship = "one-to-one",
    unmatched = c(x = "error", y = "error")
  )
  for (metric in metrics) {
    out[[paste0(metric, "_change")]] <- out[[paste0(metric, "_sens")]] -
      out[[paste0(metric, "_all")]]
  }
  out
}
