# Map of the transect locations (issue #10). Builds the plot-location table and
# the two static figures. Nothing is analysed here: severities and counts come
# from flags.csv, the quadrat fixes from the staged quadrat table, the plot
# centres from the vegplots entity list.

#' Worst severity of a set of flags
#'
#' @param severity Character vector of severities (NA or empty = no flag).
#' @param levels Severities, worst first, ending with the "no flag" level.
#' @return One string: the worst severity present, or the last level when none is.
veg_worst_severity <- function(severity, levels = veg_config$severity_levels) {
  checkmate::assert_character(x = severity)
  checkmate::assert_character(x = levels, min.len = 2, unique = TRUE)
  checkmate::assert_subset(x = severity[!is.na(severity)], choices = levels)
  present <- levels[is.element(el = levels, set = severity)]
  if (length(present) == 0) {
    return(levels[[length(levels)]])
  }
  present[[1]]
}

#' Worst severity per group, as a lookup table
#'
#' @param flags Flags table with `severity`.
#' @param by Column of `flags` to group on (rows with NA there are ignored).
#' @return Tibble with `by` and `worst_severity`.
veg_worst_by <- function(flags, by) {
  checkmate::assert_data_frame(x = flags)
  checkmate::assert_choice(x = by, choices = names(flags))
  flags |>
    filter(!is.na(.data[[by]])) |>
    summarise(
      worst_severity = veg_worst_severity(severity = severity),
      .by = all_of(by)
    )
}

#' Project longitude and latitude to a metric CRS
#'
#' @return Tibble with `x` and `y` in metres (NA where a coordinate is NA).
veg_project_xy <- function(lon, lat, epsg = veg_config$map_epsg) {
  checkmate::assert_numeric(x = lon)
  checkmate::assert_numeric(x = lat, len = length(lon))
  out <- tibble(
    x = rep(x = NA_real_, times = length(lon)),
    y = rep(x = NA_real_, times = length(lon))
  )
  ok <- !(is.na(lon) | is.na(lat))
  if (any(ok)) {
    xy <- sf::st_as_sf(
      x = data.frame(lon = lon[ok], lat = lat[ok]),
      coords = c("lon", "lat"),
      crs = 4326
    ) |>
      sf::st_transform(crs = epsg) |>
      sf::st_coordinates()
    out$x[ok] <- xy[, 1]
    out$y[ok] <- xy[, 2]
  }
  out
}

#' One row per registered plot: location, worst flag severity, surveyed, primary or backup
#'
#' The vegplots `geometry` is the geopoint of the plot centre in ODK format,
#' "latitude longitude altitude accuracy" (latitude first, unlike WKT), parsed by
#' `veg_parse_geometry()`. A plot without a geometry (registered, not viable)
#' keeps its row with NA coordinates: it cannot be drawn but must not vanish.
#'
#' @param vegplots Entity list of plots.
#' @param plot_summary Plot summary (one row per registered plot).
#' @param flags Long flags table (`plot_name`, `severity`).
#' @return Tibble: plot_name, lon, lat, worst_severity, surveyed, plot_status, n_error,
#'   n_warning, n_info, accuracy_m.
veg_plot_locations <- function(vegplots, plot_summary, flags) {
  checkmate::assert_data_frame(x = vegplots)
  checkmate::assert_names(
    x = names(vegplots),
    must.include = c("plot_name", "plot_status", "geometry")
  )
  checkmate::assert_data_frame(x = plot_summary)
  checkmate::assert_data_frame(x = flags)
  checkmate::assert_subset(
    x = flags$plot_name[!is.na(flags$plot_name)],
    choices = plot_summary$plot_name
  )
  centres <- bind_cols(
    select(.data = vegplots, plot_name),
    veg_parse_geometry(x = vegplots$geometry)
  )
  worst <- veg_worst_by(flags = flags, by = "plot_name")
  plot_summary |>
    select(plot_name, plot_status, surveyed, n_error, n_warning) |>
    inner_join(
      y = centres,
      by = "plot_name",
      relationship = "one-to-one",
      unmatched = c(x = "error", y = "drop")
    ) |>
    left_join(
      y = worst,
      by = "plot_name",
      relationship = "one-to-one",
      unmatched = "drop"
    ) |>
    left_join(
      y = select(
        .data = veg_flag_severity_counts(flags = flags, by = "plot_name"),
        plot_name,
        n_info
      ),
      by = "plot_name",
      relationship = "one-to-one",
      unmatched = "drop"
    ) |>
    mutate(
      n_info = coalesce(n_info, 0L),
      worst_severity = coalesce(
        worst_severity,
        last(veg_config$severity_levels)
      ),
      accuracy_m = accuracy
    ) |>
    select(
      plot_name,
      lon,
      lat,
      worst_severity,
      surveyed,
      plot_status,
      n_error,
      n_warning,
      n_info,
      accuracy_m
    )
}

#' Quadrat fixes with their worst flag severity and position relative to the plot centre
#'
#' @param quadrat Staged quadrat table (text or numbers).
#' @param flags Long flags table with `quadrat_key`.
#' @param locations Output of `veg_plot_locations()`.
#' @return Tibble: plot_name, survey_key, quadrat_key, quadrat_number, lon, lat, worst_severity,
#'   dx_m, dy_m (metres east and north of the plot centre), dist_m (distance to the centre).
veg_quadrat_points <- function(quadrat, flags, locations) {
  checkmate::assert_data_frame(x = quadrat)
  checkmate::assert_names(
    x = names(quadrat),
    must.include = c(
      "KEY",
      "PARENT_KEY",
      "survey_plot_name",
      "quadrat_number",
      "location_quadrat-Latitude",
      "location_quadrat-Longitude"
    )
  )
  pts <- tibble(
    plot_name = quadrat$survey_plot_name,
    survey_key = quadrat$PARENT_KEY,
    quadrat_key = quadrat$KEY,
    quadrat_number = veg_to_numeric(x = as.character(quadrat$quadrat_number)),
    lon = veg_to_numeric(
      x = as.character(quadrat[["location_quadrat-Longitude"]])
    ),
    lat = veg_to_numeric(
      x = as.character(quadrat[["location_quadrat-Latitude"]])
    )
  )
  worst <- veg_worst_by(flags = flags, by = "quadrat_key")
  centre_xy <- bind_cols(
    select(.data = locations, plot_name),
    veg_project_xy(lon = locations$lon, lat = locations$lat)
  ) |>
    rename(cx = x, cy = y)
  pts |>
    left_join(
      y = worst,
      by = "quadrat_key",
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    mutate(
      worst_severity = coalesce(
        worst_severity,
        last(veg_config$severity_levels)
      )
    ) |>
    bind_cols(veg_project_xy(lon = pts$lon, lat = pts$lat)) |>
    inner_join(
      y = centre_xy,
      by = "plot_name",
      relationship = "many-to-one",
      unmatched = c(x = "error", y = "drop")
    ) |>
    mutate(dx_m = x - cx, dy_m = y - cy, dist_m = sqrt(dx_m^2 + dy_m^2)) |>
    select(
      plot_name,
      survey_key,
      quadrat_key,
      quadrat_number,
      lon,
      lat,
      worst_severity,
      dx_m,
      dy_m,
      dist_m
    )
}

# ---- Figure parts -------------------------------------------------------------

#' Scale bar drawn with plain ggplot2 annotation, in the units of the plot (metres)
veg_scale_bar <- function(x, y, length_m, label) {
  checkmate::assert_number(x = length_m, lower = 0)
  list(
    ggplot2::annotate(
      geom = "segment",
      x = x,
      xend = x + length_m,
      y = y,
      yend = y,
      linewidth = 1.2
    ),
    ggplot2::annotate(
      geom = "text",
      x = x + length_m / 2,
      y = y,
      label = label,
      vjust = -0.8,
      size = 3
    )
  )
}

#' North arrow (grid north of the projected CRS; within 0.1 degrees of true north here)
veg_north_arrow <- function(x, y, length_m) {
  list(
    ggplot2::annotate(
      geom = "segment",
      x = x,
      xend = x,
      y = y,
      yend = y + length_m,
      linewidth = 0.8,
      arrow = grid::arrow(
        length = grid::unit(x = 0.12, units = "in"),
        type = "closed"
      )
    ),
    ggplot2::annotate(
      geom = "text",
      x = x,
      y = y + length_m,
      label = "N",
      vjust = -0.4,
      size = 3.5,
      fontface = "bold"
    )
  )
}

#' Short plot label: "SavMon_LW_Plot_05" -> "05"
veg_short_plot <- function(x) {
  stringi::stri_replace_first_regex(
    str = x,
    pattern = "^SavMon_LW_Plot_",
    replacement = ""
  )
}

#' Overview map of all plot locations
#'
#' Fill = worst flag severity; shape = primary surveyed (circle), backup surveyed
#' (diamond), registered but not surveyed (hollow square). Plots without a
#' location are listed in the caption note, not drawn.
veg_plot_overview <- function(locations, config = veg_config) {
  checkmate::assert_data_frame(x = locations)
  drawn <- locations |>
    filter(!is.na(lon), !is.na(lat)) |>
    mutate(
      kind = case_when(
        !surveyed ~ "Registered, not surveyed",
        plot_status == "backup" ~ "Backup plot",
        TRUE ~ "Primary plot, surveyed"
      ),
      severity = factor(x = worst_severity, levels = config$severity_levels),
      label = veg_short_plot(x = plot_name)
    ) |>
    sf::st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE) |>
    sf::st_transform(crs = config$map_epsg)
  bb <- sf::st_bbox(obj = drawn)
  # Registered plots without coordinates cannot be drawn: say which, never drop them silently
  undrawn <- filter(.data = locations, is.na(lon) | is.na(lat))
  undrawn_note <- if (nrow(undrawn) > 0) {
    paste0(
      "Not drawn (no coordinates in the plot register): ",
      paste(veg_short_plot(x = undrawn$plot_name), collapse = ", "),
      " (registered, ",
      if (all(!undrawn$surveyed)) "not surveyed" else "some surveyed",
      ")."
    )
  }
  pad <- 0.08 * max(bb[["xmax"]] - bb[["xmin"]], bb[["ymax"]] - bb[["ymin"]])
  bar_m <- 2000
  ggplot2::ggplot(data = drawn) +
    ggplot2::geom_sf(
      mapping = ggplot2::aes(fill = severity, shape = kind),
      size = 3.6,
      colour = "grey15",
      stroke = 0.8
    ) +
    ggplot2::geom_sf_text(
      mapping = ggplot2::aes(label = label),
      size = 2.6,
      nudge_y = 0.045 * (bb[["ymax"]] - bb[["ymin"]]),
      colour = "grey15"
    ) +
    veg_scale_bar(
      x = bb[["xmin"]] - pad / 2,
      y = bb[["ymin"]] - pad / 2,
      length_m = bar_m,
      label = "2 km"
    ) +
    veg_north_arrow(
      x = bb[["xmax"]] + pad / 2,
      y = bb[["ymin"]] - pad / 2,
      length_m = 0.12 * (bb[["ymax"]] - bb[["ymin"]])
    ) +
    ggplot2::scale_fill_manual(
      values = config$severity_colours,
      drop = TRUE,
      labels = c(
        error = "Error",
        warning = "Warning",
        info = "Info only",
        none = "No flag"
      ),
      name = "Worst flag",
      guide = ggplot2::guide_legend(override.aes = list(shape = 21, size = 4))
    ) +
    ggplot2::scale_shape_manual(
      values = c(
        "Primary plot, surveyed" = 21,
        "Backup plot" = 23,
        "Registered, not surveyed" = 22
      ),
      name = "Plot"
    ) +
    ggplot2::coord_sf(
      crs = config$map_epsg,
      datum = NULL,
      xlim = c(bb[["xmin"]] - pad, bb[["xmax"]] + pad),
      ylim = c(bb[["ymin"]] - pad, bb[["ymax"]] + pad),
      expand = FALSE
    ) +
    ggplot2::labs(x = NULL, y = NULL, caption = undrawn_note) +
    config$theme +
    ggplot2::theme(
      plot.caption = ggplot2::element_text(hjust = 0),
      legend.position = "bottom",
      legend.box = "vertical",
      legend.margin = ggplot2::margin(),
      axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )
}

#' Quadrat fixes and transect line of a few plots, in metres from the plot centre
#'
#' A dashed circle marks the reach of the belt around the centre (half the
#' belt length plus half its width, the base of the SPA-04 tolerance);
#' quadrats outside it are the ones SPA-04 can flag once the GPS accuracy
#' allowance is added.
veg_plot_transects <- function(points, plots, config = veg_config) {
  checkmate::assert_data_frame(x = points)
  checkmate::assert_subset(x = plots, choices = points$plot_name)
  pts <- points |>
    filter(is.element(el = plot_name, set = plots), !is.na(dx_m)) |>
    mutate(
      panel = factor(
        x = veg_short_plot(x = plot_name),
        levels = veg_short_plot(x = plots)
      ),
      severity = factor(x = worst_severity, levels = config$severity_levels)
    ) |>
    arrange(survey_key, quadrat_number)
  reach <- veg_belt_reach_m(config = config)
  circle <- tidyr::expand_grid(
    panel = levels(pts$panel),
    angle = seq(from = 0, to = 2 * pi, length.out = 121)
  ) |>
    mutate(
      panel = factor(x = panel, levels = levels(pts$panel)),
      dx_m = reach * cos(angle),
      dy_m = reach * sin(angle)
    )
  lim <- ceiling(max(abs(c(pts$dx_m, pts$dy_m)), reach) / 10) * 10 + 10
  ggplot2::ggplot(mapping = ggplot2::aes(x = dx_m, y = dy_m)) +
    ggplot2::geom_path(
      data = circle,
      colour = config$brand[["navy"]],
      linetype = "dashed",
      linewidth = 0.5
    ) +
    ggplot2::geom_path(
      data = pts,
      mapping = ggplot2::aes(group = survey_key),
      colour = "grey40",
      linewidth = 0.5
    ) +
    ggplot2::geom_point(
      data = pts,
      mapping = ggplot2::aes(fill = severity),
      shape = 21,
      size = 2.6,
      colour = "grey15",
      stroke = 0.5
    ) +
    ggplot2::annotate(
      geom = "point",
      x = 0,
      y = 0,
      shape = 3,
      size = 3.5,
      colour = config$brand[["navy"]]
    ) +
    ggplot2::facet_wrap(
      facets = ggplot2::vars(panel),
      ncol = 2,
      labeller = ggplot2::as_labeller(function(x) paste("Plot", x))
    ) +
    ggplot2::scale_fill_manual(
      values = config$severity_colours,
      drop = TRUE,
      labels = c(
        error = "Error",
        warning = "Warning",
        info = "Info only",
        none = "No flag"
      ),
      name = "Worst flag of the quadrat"
    ) +
    ggplot2::coord_fixed(
      xlim = c(-lim, lim),
      ylim = c(-lim, lim),
      expand = FALSE
    ) +
    veg_scale_bar(x = -lim + 5, y = -lim + 8, length_m = 20, label = "20 m") +
    veg_north_arrow(x = lim - 8, y = lim - 28, length_m = 16) +
    ggplot2::labs(x = NULL, y = NULL) +
    config$theme +
    ggplot2::theme(
      legend.position = "bottom",
      axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )
}
