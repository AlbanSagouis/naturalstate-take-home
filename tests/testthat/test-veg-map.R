# Tests for R/functions/veg_map.R and the map output checks (issue #10)

# Synthetic data: plot A (surveyed, primary, one error flag), B (surveyed, backup, info only),
# C (registered, not surveyed, no geometry). Latitude first in the geometry string, like ODK.
map_vegplots <- function() {
  tibble(
    plot_name = c("A", "B", "C"),
    plot_status = c("primary", "backup", "primary"),
    geometry = c("0.2 37.4 990.5 3.1", "0.3 37.5 980 4", NA)
  )
}
map_plot_summary <- function() {
  tibble(
    plot_name = c("A", "B", "C"),
    plot_status = c("primary", "backup", "primary"),
    surveyed = c(TRUE, TRUE, FALSE),
    n_error = c(1L, 0L, 0L),
    n_warning = c(2L, 0L, 0L)
  )
}
map_flags <- function() {
  tibble(
    plot_name = c("A", "A", "A", "B"),
    severity = c("info", "error", "warning", "info"),
    quadrat_key = c("qa1", "qa1", "qa2", NA)
  )
}
map_quadrat <- function() {
  tibble(
    KEY = c("qa1", "qa2", "qb1"),
    PARENT_KEY = c("sA", "sA", "sB"),
    survey_plot_name = c("A", "A", "B"),
    quadrat_number = c("1", "2", "1"),
    `location_quadrat-Latitude` = c("0.2", "0.20005", "0.3"),
    `location_quadrat-Longitude` = c("37.4", "37.4", "37.5")
  )
}

test_that("the geometry string is read as latitude, longitude, altitude, accuracy", {
  g <- veg_parse_geometry(x = c("0.2195439 37.4812757 990.8 3.6", NA))
  expect_equal(g$lat[[1]], 0.2195439)
  expect_equal(g$lon[[1]], 37.4812757)
  expect_equal(g$accuracy[[1]], 3.6)
  expect_true(is.na(g$lat[[2]]))
  # swapping the order would put the point far from the survey area
  expect_false(isTRUE(all.equal(g$lat[[1]], 37.4812757)))
})

test_that("worst severity ranks error over warning over info over none", {
  expect_equal(
    veg_worst_severity(severity = c("info", "error", "warning")),
    "error"
  )
  expect_equal(veg_worst_severity(severity = c("info", "warning")), "warning")
  expect_equal(veg_worst_severity(severity = c("info", "info")), "info")
  expect_equal(veg_worst_severity(severity = character()), "none")
  expect_equal(veg_worst_severity(severity = NA_character_), "none")
  expect_error(veg_worst_severity(severity = "fatal"))
})

test_that("worst severity per group ignores rows without a key", {
  f <- bind_rows(
    map_flags(),
    tibble(plot_name = "A", severity = "error", quadrat_key = NA)
  )
  w <- veg_worst_by(flags = f, by = "quadrat_key")
  expect_equal(sort(w$quadrat_key), c("qa1", "qa2"))
  expect_equal(w$worst_severity[w$quadrat_key == "qa1"], "error")
  expect_error(veg_worst_by(flags = f, by = "nothing"))
})

test_that("projection gives metres in the UTM zone and keeps NA", {
  xy <- veg_project_xy(lon = c(37.4, 37.4, NA), lat = c(0.2, 0.20009, 0.2))
  # 0.00009 degrees of latitude is about 10 m
  expect_equal(xy$y[[2]] - xy$y[[1]], 9.95, tolerance = 0.02)
  expect_equal(xy$x[[2]] - xy$x[[1]], 0, tolerance = 0.01)
  expect_true(is.na(xy$x[[3]]))
  # EPSG:32637 is the zone the distance checks pick for the study area
  expect_equal(veg_utm_epsg(lon = 37.4, lat = 0.2), veg_config$map_epsg)
  # 5 m on the ground in this CRS, not 5 degrees
  expect_lt(abs(xy$y[[2]] - xy$y[[1]]), 100)
})

test_that("plot locations: one row per registered plot, all surveyed plots located, colour = worst flag", {
  loc <- veg_plot_locations(
    vegplots = map_vegplots(),
    plot_summary = map_plot_summary(),
    flags = map_flags()
  )
  expect_equal(nrow(loc), 3)
  expect_equal(loc$worst_severity, c("error", "info", "none"))
  expect_equal(loc$surveyed, c(TRUE, TRUE, FALSE))
  expect_equal(loc$plot_status, c("primary", "backup", "primary"))
  expect_equal(loc$lat[[1]], 0.2)
  expect_equal(loc$lon[[1]], 37.4)
  expect_true(all(!is.na(loc$lon[loc$surveyed])))
  expect_true(is.na(loc$lon[[3]]))
  expect_no_error(veg_check_plot_locations(
    locations = loc,
    plot_summary = map_plot_summary(),
    flags = map_flags()
  ))
  # a flag on a plot that is not registered is refused
  bad_flags <- bind_rows(
    map_flags(),
    tibble(plot_name = "Z", severity = "error", quadrat_key = NA)
  )
  expect_error(veg_plot_locations(
    vegplots = map_vegplots(),
    plot_summary = map_plot_summary(),
    flags = bad_flags
  ))
})

test_that("plot location check refuses a lost plot, a surveyed plot without location and a wrong colour", {
  loc <- veg_plot_locations(
    vegplots = map_vegplots(),
    plot_summary = map_plot_summary(),
    flags = map_flags()
  )
  ps <- map_plot_summary()
  fl <- map_flags()
  expect_error(
    veg_check_plot_locations(
      locations = loc[-2, ],
      plot_summary = ps,
      flags = fl
    ),
    "differ"
  )
  no_xy <- loc
  no_xy$lon[[1]] <- NA
  expect_error(
    veg_check_plot_locations(locations = no_xy, plot_summary = ps, flags = fl),
    "without a location"
  )
  wrong <- loc
  wrong$worst_severity[[1]] <- "info"
  expect_error(
    veg_check_plot_locations(locations = wrong, plot_summary = ps, flags = fl),
    "worst severity"
  )
  fewer <- loc
  fewer$surveyed[[2]] <- FALSE
  expect_error(
    veg_check_plot_locations(locations = fewer, plot_summary = ps, flags = fl),
    "surveyed plots"
  )
  far <- loc
  far$lon[1:2] <- 10
  expect_error(
    veg_check_plot_locations(locations = far, plot_summary = ps, flags = fl),
    "CRS"
  )
})

test_that("quadrat points carry the worst quadrat severity and metres from the plot centre", {
  loc <- veg_plot_locations(
    vegplots = map_vegplots(),
    plot_summary = map_plot_summary(),
    flags = map_flags()
  )
  pts <- veg_quadrat_points(
    quadrat = map_quadrat(),
    flags = map_flags(),
    locations = loc
  )
  expect_equal(pts$worst_severity, c("error", "warning", "none"))
  expect_equal(pts$dist_m[[1]], 0, tolerance = 1e-6)
  # 0.00005 degrees north of the centre: about 5.5 m
  expect_equal(pts$dy_m[[2]], 5.5, tolerance = 0.02)
  expect_equal(pts$dist_m[[2]], sqrt(pts$dx_m[[2]]^2 + pts$dy_m[[2]]^2))
  expect_no_error(veg_check_quadrat_points(
    points = pts,
    quadrat = map_quadrat()
  ))
  expect_error(
    veg_check_quadrat_points(points = pts[-1, ], quadrat = map_quadrat()),
    "quadrats"
  )
  expect_error(veg_check_quadrat_points(
    points = bind_rows(pts, pts[1, ]),
    quadrat = map_quadrat()
  ))
  # a quadrat of a plot that is not in the location table is refused, not dropped
  q <- map_quadrat()
  q$survey_plot_name[[1]] <- "Z"
  expect_error(veg_quadrat_points(
    quadrat = q,
    flags = map_flags(),
    locations = loc
  ))
})

test_that("figures build, and the not-drawn plot is named", {
  loc <- veg_plot_locations(
    vegplots = map_vegplots(),
    plot_summary = map_plot_summary(),
    flags = map_flags()
  )
  p <- veg_plot_overview(locations = loc)
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$caption, "C")
  expect_no_error(ggplot2::ggplotGrob(p))
  pts <- veg_quadrat_points(
    quadrat = map_quadrat(),
    flags = map_flags(),
    locations = loc
  )
  expect_s3_class(
    veg_plot_transects(points = pts, plots = c("A", "B")),
    "ggplot"
  )
  expect_error(veg_plot_transects(points = pts, plots = "Q"))
})

test_that("real plot locations: 30 of 31 plots surveyed and located, backup flagged", {
  paths <- veg_config$paths
  skip_if_not(
    fs::file_exists(paths$plot_locations) && fs::file_exists(paths$plot_summary)
  )
  loc <- read_csv(file = paths$plot_locations, show_col_types = FALSE)
  ps <- read_csv(file = paths$plot_summary, show_col_types = FALSE)
  fl <- read_csv(file = paths$flags, show_col_types = FALSE)
  expect_equal(nrow(loc), 31)
  expect_equal(sum(loc$surveyed), 30)
  expect_true(all(!is.na(loc$lon[loc$surveyed])))
  expect_equal(loc$plot_name[loc$plot_status == "backup"], "SavMon_LW_Plot_46")
  expect_true(all(is.element(
    el = veg_config$map_example_plots,
    set = loc$plot_name
  )))
  survey <- veg_read_csv(path = paths$survey)
  # plot colours come from the flags of submissions that were not rejected
  fl_accepted <- veg_flags_accepted(flags = fl, survey = survey)
  expect_no_error(veg_check_plot_locations(
    locations = loc,
    plot_summary = ps,
    flags = fl_accepted
  ))
  # all flags would disagree for the plot whose only error sits on a rejected submission
  expect_error(
    veg_check_plot_locations(locations = loc, plot_summary = ps, flags = fl),
    "worst severity differs"
  )
  q <- veg_read_csv(path = paths$quadrat)
  pts <- veg_quadrat_points(quadrat = q, flags = fl, locations = loc)
  expect_no_error(veg_check_quadrat_points(points = pts, quadrat = q))
  # the plot centre is the transect midpoint: the median quadrat sits within 10 m of it (median over plots)
  mid <- pts |>
    summarise(
      m = sqrt(stats::median(dx_m)^2 + stats::median(dy_m)^2),
      .by = plot_name
    )
  expect_lt(stats::median(mid$m), 10)
})
