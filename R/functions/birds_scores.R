# Helpers for BirdNET confidence scores.

#' Convert a confidence to integer thousandths, rounding half up
#'
#' Validation scores are given to 3 decimals, predictions to 4. Comparing
#' integers avoids floating point trouble. The small offset makes exact
#' halves (0.1135) round up, since 0.1135 * 1000 may be stored as 113.49999.
#'
#' @param confidence Numeric vector.
#' @return Integer vector of thousandths.
confidence_to_milli <- function(confidence) {
  checkmate::assert_numeric(x = confidence, any.missing = FALSE)
  as.integer(round(x = confidence * 1000 + 1e-6, digits = 0))
}
