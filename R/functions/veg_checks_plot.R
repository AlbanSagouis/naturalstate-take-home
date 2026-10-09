# Plot checks (PLT-xx): the plot a survey claims must exist, be viable, belong
# to the survey, be registered before it is surveyed. Uses the join columns
# written by 01_load_join.R (vegplots_*, register_*).

# PLT-01: the selected plot is missing from the registered plot list.
veg_chk_plt01 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  bad <- veg_is_blank(x = s$vegplots_plot_uuid)
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad]
  )
}

# PLT-02: the plot is not recorded as viable in the plot list or registration.
veg_chk_plt02 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  found <- !veg_is_blank(x = s$vegplots_plot_uuid)
  entity_no <- found &
    !is.na(s$vegplots_is_viable) &
    s$vegplots_is_viable != "yes"
  register_no <- found &
    !is.na(s$register_is_plot_viable) &
    s$register_is_plot_viable == "no"
  bad <- entity_no | register_no
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad],
    detail = if_else(
      condition = register_no[bad],
      true = "registration",
      false = "plot list"
    )
  )
}

# PLT-03: the plot does not belong to the selected survey.
veg_chk_plt03 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  found <- !veg_is_blank(x = s$vegplots_plot_uuid)
  listed <- mapply(
    FUN = function(survey_uuids, wanted) {
      is.element(
        el = wanted,
        set = unlist(strsplit(x = survey_uuids %||% "", split = "\\s+"))
      )
    },
    s$vegplots_survey_uuids,
    s[["survey_begin-selected_survey_uuid"]],
    USE.NAMES = FALSE
  )
  bad <- found & !listed
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad]
  )
}

# PLT-04: the plot has no registration submission.
veg_chk_plt04 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  bad <- !veg_is_blank(x = s$vegplots_plot_uuid) &
    veg_is_blank(x = s$register_KEY)
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad]
  )
}

# PLT-05: the plot registration was finished after the survey started.
# Registration finished (device clock, form end time) after the survey started.
# The upload time of the registration is a separate, weaker signal (PLT-08).
veg_chk_plt05 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  registered <- veg_parse_time(
    x = ctx$register[["survey_end-end_time"]][
      match(x = s$register_KEY, table = ctx$register$KEY)
    ]
  )
  started <- veg_parse_time(x = s[["survey_begin-start_time"]])
  bad <- !is.na(registered) & !is.na(started) & registered > started
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad],
    detail = format(x = registered[bad], format = "%Y-%m-%d %H:%M", tz = "UTC")
  )
}

# PLT-06: a backup plot was surveyed instead of a primary plot.
veg_chk_plt06 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  bad <- !is.na(s[["plot_selection-get_plot_status"]]) &
    s[["plot_selection-get_plot_status"]] == "backup"
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad]
  )
}

# PLT-07: the plot status shown by the form differs from the plot list, or is missing.
# Status shown by the form differs from the plot list, or is missing
veg_chk_plt07 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  form <- s[["plot_selection-get_plot_status"]]
  listed <- s$vegplots_plot_status
  bad <- !veg_is_blank(x = s$vegplots_plot_uuid) &
    (veg_is_blank(x = form) | form != listed)
  bad[is.na(bad)] <- TRUE
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad],
    detail = paste0("form: ", form[bad], "; plot list: ", listed[bad])
  )
}

# PLT-08: the plot registration was uploaded after the survey started.
# Registration uploaded (server SubmissionDate) after the survey started. The
# form end time is earlier, so this is a delayed upload, not a registration
# after the survey; the plot could only be picked if the entity was on the device.
veg_chk_plt08 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  uploaded <- veg_parse_time(
    x = ctx$register$SubmissionDate[
      match(x = s$register_KEY, table = ctx$register$KEY)
    ]
  )
  started <- veg_parse_time(x = s[["survey_begin-start_time"]])
  bad <- !is.na(uploaded) & !is.na(started) & uploaded > started
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad],
    detail = format(x = uploaded[bad], format = "%Y-%m-%d %H:%M", tz = "UTC")
  )
}

#' Shannon's H' of each plot, on the number of quadrats in which each identified taxon occurs
#'
#' Only presence per quadrat exists, so this is a frequency-based index. It is used to find
#' odd plots, not to describe diversity.
#'
#' @param records Output of veg_record_taxa(), with the plot name added as `plot_name`.
#' @return Tibble: plot_name, shannon (plots with no identified taxon are absent).
veg_plot_shannon <- function(records) {
  checkmate::assert_names(
    x = names(records),
    must.include = c("plot_name", "quadrat_key", "taxon")
  )
  records |>
    filter(!is.na(taxon)) |>
    distinct(plot_name, quadrat_key, taxon) |>
    summarise(f = n(), .by = c(plot_name, taxon)) |>
    summarise(
      shannon = vegan::diversity(x = f, index = "shannon"),
      .by = plot_name
    )
}

#' Plots whose Shannon index is far from that of the other plots
#'
#' @param shannon Output of veg_plot_shannon().
#' @return Tibble of the outlying plots: plot_name, shannon, median, z (robust z-score).
#'   Zero rows when there are too few plots or the plots do not differ at all.
veg_shannon_outliers <- function(shannon, config = veg_config) {
  checkmate::assert_names(
    x = names(shannon),
    must.include = c("plot_name", "shannon")
  )
  none <- tibble(
    plot_name = character(),
    shannon = double(),
    median = double(),
    z = double()
  )
  spread <- stats::mad(x = shannon$shannon)
  if (nrow(shannon) < config$shannon_outlier_min_plots || !isTRUE(spread > 0)) {
    return(none)
  }
  centre <- stats::median(x = shannon$shannon)
  shannon |>
    mutate(median = centre, z = (shannon - centre) / spread) |>
    filter(abs(z) > config$shannon_outlier_mad)
}

# PLT-09: the diversity of the plot is far from that of the other plots.
# Shannon's H' per plot, from the submissions that were not rejected, is compared with the
# median of the plots (robust z-score). Used only to find odd or poor data, never to
# describe diversity. Every accepted submission of an outlying plot is flagged.
veg_chk_plt09 <- function(ctx, config = veg_config) {
  rejected <- veg_rejected_keys(survey = ctx$survey, config = config)
  survey <- ctx$survey[!is.element(el = ctx$survey$KEY, set = rejected), ]
  # A duplicated survey key is a data error that STR-03 flags; the first row is used here
  plots <- survey |>
    select(survey_key = KEY, plot_name = `plot_selection-plot_name`) |>
    distinct(survey_key, .keep_all = TRUE)
  placed <- ctx$species_long |>
    filter(!is.na(survey_key), !is.na(quadrat_key)) |>
    inner_join(
      y = plots,
      by = "survey_key",
      relationship = "many-to-one",
      unmatched = c(x = "drop", y = "drop")
    )
  records <- bind_cols(
    placed,
    select(
      .data = veg_classify_names(x = placed$species_name, config = config),
      taxon
    )
  )
  outliers <- veg_shannon_outliers(
    shannon = veg_plot_shannon(records = records),
    config = config
  )
  flagged <- plots |>
    inner_join(
      y = outliers,
      by = "plot_name",
      relationship = "many-to-one",
      unmatched = c(x = "drop", y = "drop")
    )
  veg_flag_rows(
    survey_key = flagged$survey_key,
    value = format(x = round(x = flagged$shannon, digits = 2), nsmall = 2),
    detail = format(x = round(x = flagged$median, digits = 2), nsmall = 2)
  )
}
