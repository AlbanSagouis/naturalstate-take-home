# Helpers to read the validation filenames and build a recording key.

#' Parse a validation filename
#'
#' Filenames look like `<confidence>_<rank>_<recording>.wav`, for example
#' `0.107_4_RBS21_20230630_190000.wav`. The recording name itself contains
#' underscores, so only the first two underscores separate fields.
#'
#' @param filename Character vector of validation filenames.
#' @return A tibble with file_confidence (numeric), rank (integer), recording
#'   (character, no extension). Errors if any filename does not match.
parse_validation_filename <- function(filename) {
  checkmate::assert_character(x = filename, any.missing = FALSE, min.len = 1)
  parts <- stringi::stri_match_first_regex(
    str = filename,
    pattern = "^([0-9.]+)_([0-9]+)_(.+)\\.wav$",
    case_insensitive = TRUE
  )
  if (anyNA(x = parts[, 1])) {
    bad <- filename[is.na(parts[, 1])]
    cli::cli_abort("Unparseable validation filename(s): {utils::head(bad, 3)}")
  }
  tibble::tibble(
    file_confidence = as.numeric(parts[, 2]),
    rank = as.integer(parts[, 3]),
    recording = parts[, 4]
  )
}

#' Build a recording key that tolerates clock drift
#'
#' Recording names are `<device>_<YYYYMMDD>_<HHMMSS>`. The predictions always
#' start on the hour (`..._170000`), but many validation recordings carry a
#' few seconds of offset (`..._060002`). The key is the device plus the start
#' time rounded to the nearest hour, so both spellings of one recording agree.
#'
#' @param recording Character vector of recording names without extension.
#' @param snap_units Passed to round() for date-times, default "hours".
#' @return Character vector, e.g. "RBS21_20230624_06".
recording_hour_key <- function(recording, snap_units = "hours") {
  checkmate::assert_character(x = recording, any.missing = FALSE, min.len = 1)
  parts <- stringi::stri_match_first_regex(
    str = recording,
    pattern = "^([A-Za-z0-9]+)_([0-9]{8})_([0-9]{6})$"
  )
  if (anyNA(x = parts[, 1])) {
    cli::cli_abort("Recording name(s) not in <device>_<date>_<time> form.")
  }
  start <- as.POSIXct(
    x = paste(parts[, 3], parts[, 4], sep = "_"),
    format = "%Y%m%d_%H%M%S",
    tz = "UTC"
  )
  rounded <- round(x = start, units = snap_units)
  paste(parts[, 2], format(x = rounded, format = "%Y%m%d_%H"), sep = "_")
}
