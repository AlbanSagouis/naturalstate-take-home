# Building blocks shared by the QA/QC checks (issue #8).
# Every check is a function `veg_chk_<id>(ctx, config)` that takes the staged
# tables (all text, as written by 01_load_join.R, plus the reference tables)
# and returns the rows of the long flags table it raises, or zero rows. A check
# never modifies `ctx` and never aborts on a data error.

#' Rows raised by one check (the part the check itself knows)
#'
#' @param survey_key,quadrat_key,value,detail Vectors, recycled to the length of `survey_key`.
#' @return Tibble with zero rows when `survey_key` is empty.
veg_flag_rows <- function(
  survey_key = character(),
  quadrat_key = NA_character_,
  value = NA_character_,
  detail = NA_character_
) {
  n <- length(survey_key)
  tibble(
    survey_key = as.character(survey_key),
    quadrat_key = rep_len(x = as.character(quadrat_key), length.out = n),
    value = rep_len(x = as.character(value), length.out = n),
    detail = rep_len(x = as.character(detail), length.out = n)
  )
}

#' Parse ODK timestamps ("...T09:41:43.843+02:00" or "...Z") to UTC
#'
#' The offset is honoured: dropping it (reading the clock time as UTC) shifts
#' every start time by two hours relative to the submission time.
veg_parse_time <- function(x) {
  checkmate::assert_character(x = x)
  clean <- x |>
    stringi::stri_replace_first_regex(pattern = "Z$", replacement = "+0000") |>
    stringi::stri_replace_first_regex(
      pattern = "([+-][0-9]{2}):([0-9]{2})$",
      replacement = "$1$2"
    )
  as.POSIXct(x = clean, format = "%Y-%m-%dT%H:%M:%OS%z", tz = "UTC")
}

#' Split "lat lon altitude accuracy" (the vegplots geometry) into numbers
veg_parse_geometry <- function(x) {
  parts <- stringi::stri_split_fixed(
    str = x,
    pattern = " ",
    n = 4,
    simplify = TRUE
  )
  parts[stringi::stri_isempty(str = parts)] <- NA_character_
  tibble(
    lat = veg_to_numeric(x = parts[, 1]),
    lon = veg_to_numeric(x = parts[, 2]),
    accuracy = veg_to_numeric(x = parts[, 4])
  )
}

#' EPSG code of the UTM zone that contains the mean of the given points
veg_utm_epsg <- function(lon, lat) {
  zone <- floor((mean(x = lon, na.rm = TRUE) + 180) / 6) + 1
  hemisphere <- if (mean(x = lat, na.rm = TRUE) >= 0) 32600L else 32700L
  as.integer(hemisphere + zone)
}

#' Planar distance in metres between paired points (NA where a coordinate is NA)
#'
#' Distances are measured in the UTM zone of the points (metric, error well
#' under 1 m over 100 m), not with degrees.
veg_distance_m <- function(lon1, lat1, lon2, lat2) {
  checkmate::assert_numeric(x = lon1)
  ok <- !(is.na(lon1) | is.na(lat1) | is.na(lon2) | is.na(lat2))
  out <- rep(x = NA_real_, times = length(lon1))
  if (!any(ok)) {
    return(out)
  }
  epsg <- veg_utm_epsg(lon = c(lon1[ok], lon2[ok]), lat = c(lat1[ok], lat2[ok]))
  as_utm <- function(lon, lat) {
    sf::st_as_sf(
      x = data.frame(lon = lon, lat = lat),
      coords = c("lon", "lat"),
      crs = 4326
    ) |>
      sf::st_transform(crs = epsg)
  }
  out[ok] <- as.numeric(sf::st_distance(
    x = as_utm(lon = lon1[ok], lat = lat1[ok]),
    y = as_utm(lon = lon2[ok], lat = lat2[ok]),
    by_element = TRUE
  ))
  out
}

#' Fill a message template: {plot}, {quadrat}, {value}, {detail}
veg_fill_template <- function(template, values) {
  checkmate::assert_character(x = template)
  checkmate::assert_list(x = values)
  out <- template
  for (name in names(values)) {
    replacement <- if_else(
      condition = is.na(values[[name]]),
      true = "",
      false = as.character(values[[name]])
    )
    out <- stringi::stri_replace_all_fixed(
      str = out,
      pattern = paste0("{", name, "}"),
      replacement = replacement
    )
  }
  out
}

#' Name used to compare species: trimmed, lower case, underscores as spaces,
#' and the provisional label of "herb_104 (Genus species)" removed
veg_normalise_name <- function(x) {
  x |>
    stringi::stri_replace_first_regex(
      pattern = "^(herb|wood)_[0-9]+ \\((.*)\\)$",
      replacement = "$2"
    ) |>
    stringi::stri_replace_all_fixed(pattern = "_", replacement = " ") |>
    stringi::stri_trim_both() |>
    stringi::stri_replace_all_regex(pattern = "\\s+", replacement = " ") |>
    stringi::stri_trans_tolower()
}

#' Survey context columns used by many checks: one row per survey with parsed
#' times and numbers. Pure function of `ctx$survey`.
veg_survey_typed <- function(ctx) {
  s <- ctx$survey
  tibble(
    survey_key = s$KEY,
    start = veg_parse_time(x = s[["survey_begin-start_time"]]),
    end = veg_parse_time(x = s[["survey_end-end_time"]]),
    submitted = veg_parse_time(x = s$SubmissionDate)
  )
}

#' Quadrat table with numeric geopoint, count and survey columns used by checks
veg_quadrat_typed <- function(ctx) {
  q <- ctx$quadrat
  tibble(
    quadrat_key = q$KEY,
    survey_key = q$PARENT_KEY,
    quadrat_number = veg_to_numeric(x = q$quadrat_number),
    lat = veg_to_numeric(x = q[["location_quadrat-Latitude"]]),
    lon = veg_to_numeric(x = q[["location_quadrat-Longitude"]]),
    accuracy = veg_to_numeric(x = q[["location_quadrat-Accuracy"]])
  )
}

#' Plot midpoint (vegplots geometry) for each survey row
veg_plot_midpoints <- function(ctx) {
  geometry <- veg_parse_geometry(x = ctx$vegplots$geometry)
  mid <- bind_cols(
    select(.data = ctx$vegplots, plot_id = `__id`),
    geometry
  ) |>
    rename(mid_lat = lat, mid_lon = lon, mid_accuracy = accuracy) |>
    distinct(plot_id, .keep_all = TRUE)
  # A duplicated key is a data error that other checks flag; the first row is used here
  ctx$survey |>
    select(
      survey_key = KEY,
      plot_id = `plot_selection-selected_plot_uuid`
    ) |>
    distinct(survey_key, .keep_all = TRUE) |>
    left_join(
      y = mid,
      by = "plot_id",
      relationship = "many-to-one",
      unmatched = "drop"
    )
}

#' Keys of the submissions a reviewer rejected in ODK
veg_rejected_keys <- function(survey, config = veg_config) {
  # Duplicated keys are a data error that STR-03 flags, so uniqueness is not asserted here
  checkmate::assert_character(x = survey$KEY, any.missing = FALSE)
  survey$KEY[
    !is.na(survey$ReviewState) &
      survey$ReviewState == config$review_state_rejected
  ]
}
