# Observation labelling.

#' Label detections against a species cutoff
#'
#' Status values: "observed" (confidence at or above the cutoff),
#' "below_threshold" (under the cutoff), "no_threshold" (species has no cutoff,
#' cutoff is NA). The cutoff itself counts as observed.
#'
#' @param confidence Numeric detection scores, no NA.
#' @param cutoff Numeric cutoff(s): length 1 or same length as confidence.
#' @return Character vector of statuses.
label_observation <- function(confidence, cutoff) {
  checkmate::assert_numeric(x = confidence, any.missing = FALSE)
  checkmate::assert_numeric(x = cutoff)
  checkmate::assert_true(x = length(cutoff) %in% c(1L, length(confidence)))
  dplyr::case_when(
    is.na(cutoff) ~ "no_threshold",
    confidence >= cutoff ~ "observed",
    .default = "below_threshold"
  )
}

#' Label every prediction row against its species cutoff
#'
#' Keeps all columns of `predictions` in their order and adds
#' `observation_status` and `observation` (the species common name when the
#' status is "observed", else NA) as the last two columns. Row order and count
#' are preserved. A species with no row in `thresholds` is an error.
#'
#' @param predictions Data frame with `common_name` and `confidence`.
#' @param thresholds Data frame with one row per species: `commonName` and
#'   `labelling_cutoff` (NA when the species has no fitted threshold).
#' @return `predictions` with two extra columns.
label_predictions <- function(predictions, thresholds) {
  checkmate::assert_data_frame(x = predictions)
  checkmate::assert_names(
    x = names(predictions),
    must.include = c("common_name", "confidence")
  )
  checkmate::assert_data_frame(x = thresholds)
  checkmate::assert_names(
    x = names(thresholds),
    must.include = c("commonName", "labelling_cutoff")
  )
  checkmate::assert_false(x = anyDuplicated(thresholds$commonName) > 0)
  cutoffs <- thresholds[c("commonName", "labelling_cutoff")]
  # left_join() cannot check unmatched x rows, inner_join() can: a prediction
  # without a threshold row errors, unused threshold rows are dropped.
  labelled <- predictions |>
    dplyr::inner_join(
      y = cutoffs,
      by = dplyr::join_by(common_name == commonName),
      relationship = "many-to-one",
      unmatched = c(x = "error", y = "drop")
    )
  labelled |>
    dplyr::mutate(
      observation_status = label_observation(
        confidence = confidence,
        cutoff = labelling_cutoff
      ),
      observation = dplyr::if_else(
        observation_status == "observed",
        common_name,
        NA_character_
      )
    ) |>
    dplyr::select(-labelling_cutoff)
}
