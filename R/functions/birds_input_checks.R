# Input checks for the raw BirdNET files. They fail loudly and never repair.

#' Assert that two columns pair one-to-one
#'
#' Two names for one species (or one name for two species) would silently split
#' or merge the per-species fits, so the pairing is checked explicitly.
#'
#' @param data Data frame.
#' @param a,b Column names (strings).
#' @return `data`, invisibly.
assert_one_to_one <- function(data, a, b) {
  pairs <- dplyr::distinct(.data = data[c(a, b)])
  if (anyDuplicated(pairs[[a]]) > 0 || anyDuplicated(pairs[[b]]) > 0) {
    cli::cli_abort(
      "{.field {a}} and {.field {b}} do not pair one-to-one."
    )
  }
  invisible(data)
}

#' Check the BirdNET run threshold on a confidence column
#'
#' @param confidence Numeric scores.
#' @param min_confidence BirdNET run threshold.
#' @param tolerance Slack for scores rounded to 3 decimals (0.101 vs 0.1).
#' @param label Name of the file, used in the message.
assert_min_confidence <- function(
  confidence,
  min_confidence = 0.1,
  tolerance = 1e-3,
  label
) {
  if (any(confidence < min_confidence - tolerance)) {
    cli::cli_abort(
      "{label}: confidence below the BirdNET run threshold of {min_confidence}."
    )
  }
  invisible(confidence)
}

#' Check the validation file before linking
#'
#' @param validations Tibble read from validation_results.csv.
#' @return `validations`, invisibly.
check_validations_input <- function(validations) {
  required <- c(
    "scientificName",
    "commonName",
    "vBirdNET",
    "filename",
    "confidence",
    "outcome"
  )
  checkmate::assert_names(x = names(validations), must.include = required)

  # A repeated clip would be counted twice in every per-species fit
  n_dup <- sum(duplicated(validations$filename))
  if (n_dup > 0) {
    cli::cli_abort("{n_dup} duplicated validation filename(s).")
  }
  assert_one_to_one(data = validations, a = "scientificName", b = "commonName")
  assert_min_confidence(
    confidence = validations$confidence,
    label = "validations"
  )
  # Scores are stored at 3 decimals; more would break the link on milli scores
  if (
    any(
      abs(
        validations$confidence * 1000 - round(validations$confidence * 1000)
      ) >
        1e-6
    )
  ) {
    cli::cli_abort("validations: confidence has more than 3 decimals.")
  }
  invisible(validations)
}

#' Check the prediction file before linking
#'
#' @param predictions Tibble read from birdnet_predictions.csv.
#' @param segment_s Expected segment length in seconds.
#' @return `predictions`, invisibly.
check_predictions_input <- function(predictions, segment_s = 3) {
  required <- c(
    "selection",
    "begin_time_s",
    "end_time_s",
    "common_name",
    "species_code",
    "confidence",
    "begin_path"
  )
  checkmate::assert_names(x = names(predictions), must.include = required)

  assert_one_to_one(data = predictions, a = "species_code", b = "common_name")
  assert_min_confidence(
    confidence = predictions$confidence,
    label = "predictions"
  )
  keys <- predictions[c("begin_path", "begin_time_s", "common_name")]
  n_dup <- sum(duplicated(keys))
  if (n_dup > 0) {
    cli::cli_abort(
      "{n_dup} duplicated (begin_path, begin_time_s, common_name) prediction(s)."
    )
  }
  if (any(predictions$end_time_s - predictions$begin_time_s != segment_s)) {
    cli::cli_abort("predictions: not every segment is {segment_s} s long.")
  }
  invisible(predictions)
}
