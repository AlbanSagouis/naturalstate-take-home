# Spatial checks (SPA-xx). Distances are measured in metres in the UTM zone of
# the points (see veg_distance_m). Tolerances combine the belt geometry from
# the SOP with the GPS accuracy the device reports for the two points compared.

#' Largest distance from the plot midpoint to a point on the belt (m)
#'
#' Half the belt length along the transect and half the belt width across it.
veg_belt_reach_m <- function(config = veg_config) {
  sqrt((config$belt_length_m / 2)^2 + (config$belt_width_m / 2)^2)
}

# SPA-01: Quadrat geopoint accuracy worse than the limit.
veg_chk_spa01 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_typed(ctx = ctx)
  bad <- !is.na(v$accuracy) & v$accuracy > config$accuracy_limit_m
  veg_flag_rows(
    survey_key = v$survey_key[bad],
    quadrat_key = v$quadrat_key[bad],
    value = v$accuracy[bad]
  )
}

# SPA-02: Background geopoint accuracy worse than the limit.
veg_chk_spa02 <- function(ctx, config = veg_config) {
  accuracy <- veg_to_numeric(
    x = ctx$survey[["survey_end-background_geopoint-Accuracy"]]
  )
  bad <- !is.na(accuracy) & accuracy > config$accuracy_limit_m
  veg_flag_rows(survey_key = ctx$survey$KEY[bad], value = accuracy[bad])
}

# SPA-03: Background geopoint not recorded.
veg_chk_spa03 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  bad <- veg_is_blank(x = s[["survey_end-background_geopoint-Accuracy"]]) |
    veg_is_blank(x = s[["survey_end-background_geopoint-Latitude"]]) |
    veg_is_blank(x = s[["survey_end-background_geopoint-Longitude"]])
  veg_flag_rows(survey_key = s$KEY[bad])
}

# SPA-04: Quadrat farther from the plot midpoint than the belt allows.
# Tolerance =
# belt reach + the accuracy of the quadrat fix + the accuracy of the midpoint
# fix (the limit when the midpoint accuracy is unknown).
veg_chk_spa04 <- function(ctx, config = veg_config) {
  q <- veg_quadrat_typed(ctx = ctx)
  mid <- veg_plot_midpoints(ctx = ctx)
  q <- dplyr::left_join(
    x = q,
    y = mid,
    by = "survey_key",
    relationship = "many-to-one",
    unmatched = "drop"
  )
  q$distance <- veg_distance_m(
    lon1 = q$lon,
    lat1 = q$lat,
    lon2 = q$mid_lon,
    lat2 = q$mid_lat
  )
  tolerance <- veg_belt_reach_m(config = config) +
    dplyr::coalesce(q$accuracy, config$accuracy_limit_m) +
    dplyr::coalesce(q$mid_accuracy, config$accuracy_limit_m)
  bad <- !is.na(q$distance) & q$distance > tolerance
  veg_flag_rows(
    survey_key = q$survey_key[bad],
    quadrat_key = q$quadrat_key[bad],
    value = round(q$distance[bad], digits = 1),
    detail = round(tolerance[bad], digits = 1)
  )
}

# SPA-05: Background geopoint far from the plot midpoint.
veg_chk_spa05 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  mid <- veg_plot_midpoints(ctx = ctx)
  mid <- mid[match(x = s$KEY, table = mid$survey_key), ]
  distance <- veg_distance_m(
    lon1 = veg_to_numeric(x = s[["survey_end-background_geopoint-Longitude"]]),
    lat1 = veg_to_numeric(x = s[["survey_end-background_geopoint-Latitude"]]),
    lon2 = mid$mid_lon,
    lat2 = mid$mid_lat
  )
  tolerance <- veg_belt_reach_m(config = config) +
    dplyr::coalesce(
      veg_to_numeric(x = s[["survey_end-background_geopoint-Accuracy"]]),
      config$accuracy_limit_m
    ) +
    dplyr::coalesce(mid$mid_accuracy, config$accuracy_limit_m)
  bad <- !is.na(distance) & distance > tolerance
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = round(distance[bad], digits = 1),
    detail = round(tolerance[bad], digits = 1)
  )
}

# SPA-06: Consecutive quadrats farther apart than the layout allows.
# Consecutive quadrats (n, n+1) are 5 m apart along the tape and on alternating
# sides: at most sqrt(spacing^2 + belt width^2) = 7.1 m apart. The two fixes
# each have a reported accuracy; the error of their difference is taken as
# 2 x sqrt(acc1^2 + acc2^2) (two standard deviations if the accuracy is one),
# not the plain sum, which flags a fifth of all pairs.
veg_chk_spa06 <- function(ctx, config = veg_config) {
  q <- veg_quadrat_typed(ctx = ctx)
  q <- q[!is.na(q$quadrat_number), ]
  q <- q[order(q$survey_key, q$quadrat_number), ]
  n <- nrow(q)
  if (n < 2) {
    return(veg_flag_rows())
  }
  from <- seq_len(n - 1)
  to <- from + 1
  consecutive <- q$survey_key[from] == q$survey_key[to] &
    q$quadrat_number[to] == q$quadrat_number[from] + 1
  distance <- veg_distance_m(
    lon1 = q$lon[from],
    lat1 = q$lat[from],
    lon2 = q$lon[to],
    lat2 = q$lat[to]
  )
  tolerance <- sqrt(config$quadrat_spacing_m^2 + config$belt_width_m^2) +
    2 *
      sqrt(
        dplyr::coalesce(q$accuracy[from], config$accuracy_limit_m)^2 +
          dplyr::coalesce(q$accuracy[to], config$accuracy_limit_m)^2
      )
  bad <- consecutive & !is.na(distance) & distance > tolerance
  veg_flag_rows(
    survey_key = q$survey_key[to][bad],
    quadrat_key = q$quadrat_key[to][bad],
    value = round(distance[bad], digits = 1),
    detail = round(tolerance[bad], digits = 1)
  )
}

# SPA-07: Two quadrats of one survey with identical coordinates.
veg_chk_spa07 <- function(ctx, config = veg_config) {
  q <- veg_quadrat_typed(ctx = ctx)
  q <- q[!is.na(q$lat) & !is.na(q$lon), ]
  key <- paste(q$survey_key, q$lat, q$lon)
  bad <- is.element(el = key, set = key[duplicated(key)])
  veg_flag_rows(
    survey_key = q$survey_key[bad],
    quadrat_key = q$quadrat_key[bad],
    value = paste(q$lat[bad], q$lon[bad])
  )
}
