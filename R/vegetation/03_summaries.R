# 03: survey-level and plot-level summaries, in two versions: the main version (every
# submission except those rejected in ODK) and a sensitivity version that also leaves out
# the quadrats that carry an error flag. The survey table lists every submission, rejected
# ones included. Nothing is changed: both versions are filtered views of the staged tables.
# Inputs: data/processed/veg_*.csv (01), outputs/vegetation/flags.csv (02), vegplots.
# Run from the project root: Rscript R/vegetation/03_summaries.R

source(file = here::here("R", "vegetation", "config.R"))
paths <- veg_config$paths

# ---- Load -------------------------------------------------------------------
survey <- veg_read_csv(path = paths$survey, label = "veg_survey")
quadrat <- veg_read_csv(path = paths$quadrat, label = "veg_quadrat")
species_long <- veg_read_csv(
  path = paths$species_long,
  label = "veg_species_long"
)
flags <- veg_read_csv(path = paths$flags, label = "flags")
vegplots <- veg_read_entity(name = "vegplots")

# ---- Taxa and exclusions ----------------------------------------------------
records <- veg_record_taxa(species_long = species_long)
exclusions <- veg_exclusions(flags = flags, survey = survey, quadrat = quadrat)
veg_check_exclusions(
  exclusions = exclusions,
  survey = survey,
  quadrat = quadrat
)
# Main version: rejected submissions are out of the plot and headline numbers
accepted_view <- veg_apply_exclusions(
  survey = survey,
  quadrat = quadrat,
  records = records,
  exclusions = veg_rejected_exclusions(exclusions = exclusions)
)
flags_accepted <- veg_flags_accepted(flags = flags, survey = survey)
kept <- veg_apply_exclusions(
  survey = survey,
  quadrat = quadrat,
  records = records,
  exclusions = exclusions
)
veg_check_no_lost_records(
  quadrat_all = quadrat,
  quadrat_sens = kept$quadrat,
  survey_all = survey,
  survey_sens = kept$survey,
  exclusions = exclusions
)
n_names <- n_distinct(records$taxon, na.rm = TRUE)

# ---- Summaries --------------------------------------------------------------
build <- function(survey, quadrat, records, version) {
  survey_summary <- veg_survey_summary(
    survey = survey,
    quadrat = quadrat,
    records = records,
    flags = flags_accepted
  )
  plot_summary <- veg_plot_summary(
    survey = survey,
    quadrat = quadrat,
    records = records,
    vegplots = vegplots,
    flags = flags_accepted
  )
  veg_check_survey_summary(
    summary = survey_summary,
    survey = survey,
    quadrat = quadrat
  )
  veg_check_plot_summary(
    summary = plot_summary,
    vegplots = vegplots,
    survey = survey,
    quadrat = quadrat
  )
  # Flag counts describe the submissions, so they only reconcile when no flagged submission is left out
  if (version == "accepted") {
    veg_check_summaries_reconcile(
      survey_summary = survey_summary,
      plot_summary = plot_summary
    )
  }
  veg_check_richness_bound(
    survey_summary = survey_summary,
    plot_summary = plot_summary,
    n_names = n_names
  )
  list(
    survey = survey_summary,
    plot = plot_summary,
    totals = veg_totals(
      version = version,
      survey_summary = survey_summary,
      plot_summary = plot_summary,
      quadrat = quadrat,
      records = records,
      flags = flags_accepted
    )
  )
}
# The survey table lists every submission, rejected ones with their own counts
survey_table <- veg_survey_summary(
  survey = survey,
  quadrat = quadrat,
  records = records,
  flags = flags
)
veg_check_survey_summary(
  summary = survey_table,
  survey = survey,
  quadrat = quadrat
)
accepted <- build(
  survey = accepted_view$survey,
  quadrat = accepted_view$quadrat,
  records = accepted_view$records,
  version = "accepted"
)
excl_errors <- build(
  survey = kept$survey,
  quadrat = kept$quadrat,
  records = kept$records,
  version = "excluding_errors"
)

# ---- Sampling effort --------------------------------------------------------
# Is 20 quadrats enough to describe a plot? One table per version; the curves of the
# main version are drawn in the report and the dashboard.
effort_for <- function(view, plot_summary) {
  matrices <- veg_presence_matrices(
    quadrat = view$quadrat,
    survey = view$survey,
    records = view$records
  )
  curves <- veg_accumulation_curves(
    matrices = matrices,
    permutations = veg_config$accumulation_permutations,
    seed = veg_config$seed
  )
  effort <- veg_effort_table(matrices = matrices, curves = curves)
  veg_check_effort(effort = effort, plot_summary = plot_summary)
  list(effort = effort, curves = curves)
}
effort_accepted <- effort_for(
  view = accepted_view,
  plot_summary = accepted$plot
)
effort_excl_errors <- effort_for(
  view = kept,
  plot_summary = excl_errors$plot
)

# ---- Report -----------------------------------------------------------------
totals <- bind_rows(accepted$totals, excl_errors$totals)
cli::cli_h1("Summaries")
cli::cli_bullets(c(
  "v" = "{totals$n_surveys[1]} accepted surveys ({nrow(survey_table)} submissions), {totals$n_plots_surveyed[1]} of {totals$n_plots_registered[1]} plots, {totals$n_quadrats[1]} quadrats",
  "v" = "{totals$richness_all_plots[1]} identified taxa (+ {totals$n_unknown_labels_all_plots[1]} provisional unknown labels)",
  "v" = "{sum(effort_accepted$effort$quadrats_short == 0)} of {nrow(effort_accepted$effort)} plots have the {veg_config$expected_quadrats_per_plot} quadrats; {sum(effort_accepted$effort$approaches_asymptote, na.rm = TRUE)} approach an asymptote ({sum(effort_excl_errors$effort$approaches_asymptote, na.rm = TRUE)} excluding errors)",
  "i" = "excluding errors: {totals$n_surveys[2]} surveys, {totals$n_quadrats[2]} quadrats, {totals$richness_all_plots[2]} taxa ({nrow(exclusions$quadrats)} quadrats and {nrow(exclusions$surveys)} submissions left out)"
))

# ---- Write ------------------------------------------------------------------
# Numbers are written to two decimals: the data do not support more
two_decimals <- function(data) {
  mutate(
    .data = data,
    across(.cols = where(is.double), .fns = \(x) round(x, digits = 2))
  )
}
fs::dir_create(path = paths$outputs_dir)
write_csv(x = records, file = paths$record_taxa, na = "")
write_csv(
  x = two_decimals(data = survey_table),
  file = paths$survey_summary,
  na = ""
)
write_csv(
  x = two_decimals(data = excl_errors$survey),
  file = paths$survey_summary_sens,
  na = ""
)
write_csv(
  x = two_decimals(data = accepted$plot),
  file = paths$plot_summary,
  na = ""
)
write_csv(
  x = two_decimals(data = excl_errors$plot),
  file = paths$plot_summary_sens,
  na = ""
)
write_csv(x = two_decimals(data = totals), file = paths$totals, na = "")
write_csv(
  x = bind_rows(
    # The quadrats of a rejected submission are implied by the submission row
    mutate(
      .data = filter(
        .data = exclusions$quadrats,
        reason != "rejected_submission"
      ),
      level = "quadrat"
    ),
    mutate(
      .data = exclusions$surveys,
      level = "survey",
      quadrat_key = NA_character_
    )
  ) |>
    select(level, survey_key, quadrat_key, reason),
  file = paths$exclusions,
  na = ""
)
write_csv(
  x = two_decimals(data = effort_accepted$effort),
  file = paths$effort,
  na = ""
)
write_csv(
  x = two_decimals(data = effort_excl_errors$effort),
  file = paths$effort_sens,
  na = ""
)
write_csv(
  x = two_decimals(data = effort_accepted$curves),
  file = paths$accumulation_curves,
  na = ""
)
ggplot2::ggsave(
  filename = paths$figure_accumulation,
  plot = veg_plot_accumulation(
    curves = effort_accepted$curves,
    effort = effort_accepted$effort
  ),
  width = 7,
  height = 4.5,
  dpi = 150
)
cli::cli_alert_success("Wrote summaries to {.path {paths$outputs_dir}}")
