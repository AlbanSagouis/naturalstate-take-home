# Helpers for BirdNET confidence scores.

#' Clamp confidence away from 1 so the logit is finite
#'
#' qlogis(1) is Inf, which breaks the glm. Scores above `max_value` are set
#' to `max_value`; nothing else changes.
#'
#' @param confidence Numeric vector in [0, 1].
#' @param max_value Upper limit, below 1 (default 0.9999).
#' @return Numeric vector, same length.
clamp_confidence <- function(confidence, max_value = 0.9999) {
  checkmate::assert_numeric(
    x = confidence,
    lower = 0,
    upper = 1,
    any.missing = FALSE
  )
  checkmate::assert_number(x = max_value, lower = 0.5, upper = 0.999999999)
  pmin(confidence, max_value)
}

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
