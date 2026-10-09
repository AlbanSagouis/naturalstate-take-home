# Checks on the outputs of the map (issue #10).

#' Plot-location table: one row per registered plot, every surveyed plot on the map
veg_check_plot_locations <- function(
  locations,
  plot_summary,
  flags,
  config = veg_config
) {
  checkmate::assert_data_frame(x = locations)
  checkmate::assert_names(
    x = names(locations),
    must.include = c(
      "plot_name",
      "lon",
      "lat",
      "worst_severity",
      "surveyed",
      "plot_status"
    )
  )
  if (
    anyDuplicated(locations$plot_name) > 0 ||
      !setequal(x = locations$plot_name, y = plot_summary$plot_name)
  ) {
    cli::cli_abort(
      "plot locations: plots differ from the {nrow(plot_summary)} registered plots."
    )
  }
  checkmate::assert_subset(
    x = locations$worst_severity,
    choices = config$severity_levels
  )
  checkmate::assert_subset(
    x = locations$plot_status,
    choices = c("primary", "backup")
  )
  checkmate::assert_logical(x = locations$surveyed, any.missing = FALSE)
  if (sum(locations$surveyed) != sum(plot_summary$surveyed)) {
    cli::cli_abort(
      "plot locations: {sum(locations$surveyed)} surveyed plots, the plot summary has {sum(plot_summary$surveyed)}."
    )
  }
  missing_xy <- locations$plot_name[
    locations$surveyed & (is.na(locations$lon) | is.na(locations$lat))
  ]
  if (length(missing_xy) > 0) {
    cli::cli_abort(
      "plot locations: surveyed plot(s) without a location: {missing_xy}."
    )
  }
  drawn <- locations[!is.na(locations$lon) & !is.na(locations$lat), ]
  checkmate::assert_numeric(
    x = drawn$lat,
    lower = -90,
    upper = 90,
    any.missing = FALSE
  )
  checkmate::assert_numeric(
    x = drawn$lon,
    lower = -180,
    upper = 180,
    any.missing = FALSE
  )
  # The map and the distance checks must measure in the same UTM zone
  if (
    nrow(drawn) > 0 &&
      veg_utm_epsg(lon = drawn$lon, lat = drawn$lat) != config$map_epsg
  ) {
    cli::cli_abort(
      "plot locations: the plots are not in the map CRS EPSG:{config$map_epsg}."
    )
  }
  # The colour is the worst severity of the plot's flags, recomputed from the flags table
  expected <- vapply(
    X = locations$plot_name,
    FUN = function(p) {
      veg_worst_severity(
        severity = flags$severity[
          !is.na(flags$plot_name) & flags$plot_name == p
        ]
      )
    },
    FUN.VALUE = character(1)
  )
  if (any(expected != locations$worst_severity)) {
    cli::cli_abort(
      "plot locations: worst severity differs from the flags for {locations$plot_name[expected != locations$worst_severity]}."
    )
  }
  invisible(locations)
}

#' Quadrat points: every quadrat of the staged table once, distances non-negative
veg_check_quadrat_points <- function(points, quadrat) {
  checkmate::assert_data_frame(x = points)
  if (
    nrow(points) != nrow(quadrat) ||
      anyDuplicated(points$quadrat_key) > 0 ||
      !setequal(x = points$quadrat_key, y = quadrat$KEY)
  ) {
    cli::cli_abort(
      "quadrat points: {nrow(points)} points for {nrow(quadrat)} quadrats, or keys differ."
    )
  }
  checkmate::assert_numeric(x = points$dist_m, lower = 0)
  invisible(points)
}
