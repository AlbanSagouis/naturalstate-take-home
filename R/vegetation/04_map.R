# 05: map of the transect locations. Writes outputs/vegetation/plot_locations.csv
# (also the map layer of the dashboard) and two static figures: an overview of
# all plots and a zoom on a few transects. No analysis: flags, summaries and
# quadrat fixes are read from the earlier steps.
# Run from the project root, after 03: Rscript R/vegetation/04_map.R

source(file = here::here("R", "vegetation", "config.R"))
paths <- veg_config$paths

# ---- Load -------------------------------------------------------------------
vegplots <- veg_read_entity(name = "vegplots")
quadrat <- veg_read_csv(path = paths$quadrat, label = "veg_quadrat")
plot_summary <- read_csv(
  file = paths$plot_summary,
  show_col_types = FALSE
)
flags <- read_csv(file = paths$flags, show_col_types = FALSE)
survey <- veg_read_csv(path = paths$survey, label = "veg_survey")
# Plot colours and counts use submissions that were not rejected (as the plot summary does);
# the quadrat points keep every flag
flags_accepted <- veg_flags_accepted(flags = flags, survey = survey)

# ---- Build ------------------------------------------------------------------
locations <- veg_plot_locations(
  vegplots = vegplots,
  plot_summary = plot_summary,
  flags = flags_accepted
)
points <- veg_quadrat_points(
  quadrat = quadrat,
  flags = flags,
  locations = locations
)
veg_check_plot_locations(
  locations = locations,
  plot_summary = plot_summary,
  flags = flags_accepted
)
veg_check_quadrat_points(points = points, quadrat = quadrat)

# ---- Write ------------------------------------------------------------------
fs::dir_create(path = paths$outputs_dir)
write_csv(x = locations, file = paths$plot_locations, na = "")
ggplot2::ggsave(
  filename = paths$figure_map,
  plot = veg_plot_overview(locations = locations),
  width = 6.5,
  height = 4.6,
  dpi = 150
)
ggplot2::ggsave(
  filename = paths$figure_transects,
  plot = veg_plot_transects(
    points = points,
    plots = veg_config$map_example_plots
  ),
  width = 6.5,
  height = 7.5,
  dpi = 150
)

cli::cli_h1("Map")
cli::cli_bullets(c(
  "v" = "{sum(!is.na(locations$lon))} of {nrow(locations)} registered plots have a location",
  "i" = "worst severity: {paste(names(table(locations$worst_severity)), table(locations$worst_severity), collapse = ', ')}",
  "v" = "Wrote {.path {paths$plot_locations}}, {.path {paths$figure_map}}, {.path {paths$figure_transects}}"
))
