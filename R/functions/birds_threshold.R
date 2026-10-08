# Wood & Kahl (2024) threshold: per species glm(outcome ~ qlogis(confidence)).

#' Threshold from logistic coefficients
#'
#' threshold = plogis((qlogis(target) - b0) / b1). Returns NA when the slope is
#' not positive or any input is not finite, because the formula then has no
#' meaning (confidence would not raise precision).
#'
#' @param b0,b1 Intercept and slope on the logit scale.
#' @param target Target precision, strictly between 0 and 1 (default 0.99).
#' @return Single number in (0, 1) or NA_real_.
threshold_from_coef <- function(b0, b1, target = 0.99) {
  checkmate::assert_true(x = target > 0 && target < 1)
  if (!is.finite(b0) || !is.finite(b1) || b1 <= 0) {
    return(NA_real_)
  }
  plogis(q = (qlogis(p = target) - b0) / b1)
}

#' Fit the plain glm threshold for one species
#'
#' Warnings from glm are caught and stored as text rather than printed, so a
#' loop over species or bootstrap resamples stays quiet but nothing is lost.
#'
#' @param confidence Numeric validated scores in [0, 1].
#' @param outcome 0/1 vector, 1 = true positive.
#' @param target Target precision.
#' @param clamp_max Passed to clamp_confidence().
#' @return One-row tibble: b0, b1, threshold, warning (NA if none),
#'   perfect_separation (score ranges of the two classes do not overlap),
#'   near_separation (glm warned that fitted probabilities were 0 or 1).
fit_threshold <- function(
  confidence,
  outcome,
  target = 0.99,
  clamp_max = 0.9999
) {
  checkmate::assert_numeric(
    x = confidence,
    lower = 0,
    upper = 1,
    any.missing = FALSE,
    min.len = 1
  )
  checkmate::assert_integerish(
    x = outcome,
    lower = 0,
    upper = 1,
    any.missing = FALSE,
    len = length(confidence)
  )

  result <- tibble::tibble(
    b0 = NA_real_,
    b1 = NA_real_,
    threshold = NA_real_,
    warning = NA_character_,
    perfect_separation = NA,
    near_separation = NA
  )
  if (dplyr::n_distinct(outcome) < 2) {
    result$warning <- "single outcome class, no fit"
    return(result)
  }

  fit_data <- data.frame(
    outcome = outcome,
    logit_conf = qlogis(
      p = clamp_confidence(confidence = confidence, max_value = clamp_max)
    )
  )
  seen <- character(0)
  fit <- withCallingHandlers(
    glm(formula = outcome ~ logit_conf, family = binomial(), data = fit_data),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart(r = "muffleWarning")
    }
  )
  b <- unname(coef(fit))
  result$b0 <- b[[1]]
  result$b1 <- b[[2]]
  result$threshold <- threshold_from_coef(
    b0 = b[[1]],
    b1 = b[[2]],
    target = target
  )
  result$warning <- if (length(seen) > 0) {
    paste(unique(seen), collapse = " | ")
  } else {
    NA_character_
  }
  result$near_separation <- any(stringi::stri_detect_fixed(
    str = seen,
    pattern = "fitted probabilities"
  ))
  result$perfect_separation <- max(confidence[outcome == 0]) <
    min(confidence[outcome == 1]) ||
    max(confidence[outcome == 1]) < min(confidence[outcome == 0])
  result
}

#' Does a species get a fitted threshold?
#'
#' Two gates, identical for every species: (a) the plain glm threshold lies
#' inside the validated score range, so it is interpolated and not
#' extrapolated; (b) the smaller of the two outcome groups has at least
#' `min_smaller_group` clips. Stability under resampling is reported
#' elsewhere and is not a gate. Vectorised over species.
#'
#' @param n_neg,n_pos Counts of wrong and right validated clips.
#' @param glm_threshold Plain glm threshold (NA when no fit).
#' @param score_min,score_max Validated score range.
#' @param min_smaller_group Minimum size of the smaller outcome group.
#' @return Tibble: smaller_group, in_range, eligible, status ("fitted threshold" or
#'   "no_threshold") and reason (plain language, NA when fitted).
threshold_eligibility <- function(
  n_neg,
  n_pos,
  glm_threshold,
  score_min,
  score_max,
  min_smaller_group
) {
  checkmate::assert_count(x = min_smaller_group, positive = TRUE)
  smaller_group <- pmin(n_neg, n_pos)
  in_range <- !is.na(glm_threshold) &
    glm_threshold >= score_min &
    glm_threshold <= score_max
  enough <- smaller_group >= min_smaller_group

  reason_count <- dplyr::case_when(
    smaller_group == 0 ~ "single outcome class, no fit",
    !enough ~ paste0(
      "smaller group has ",
      smaller_group,
      " clips, minimum ",
      min_smaller_group
    ),
    .default = NA_character_
  )
  # With a single class there is no threshold to place, so no range message
  reason_range <- dplyr::case_when(
    smaller_group == 0 ~ NA_character_,
    is.na(glm_threshold) ~ "no usable threshold (slope not positive)",
    glm_threshold > score_max ~ paste0(
      "fitted threshold ",
      format(x = round(x = glm_threshold, digits = 3), nsmall = 3),
      " is above the highest validated score ",
      format(x = round(x = score_max, digits = 3), nsmall = 3)
    ),
    glm_threshold < score_min ~ paste0(
      "fitted threshold ",
      format(x = round(x = glm_threshold, digits = 3), nsmall = 3),
      " is below the lowest validated score ",
      format(x = round(x = score_min, digits = 3), nsmall = 3)
    ),
    .default = NA_character_
  )
  reason <- vapply(
    X = seq_along(smaller_group),
    FUN = function(i) {
      parts <- c(reason_count[[i]], reason_range[[i]])
      parts <- parts[!is.na(parts)]
      if (length(parts) == 0) NA_character_ else paste(parts, collapse = "; ")
    },
    FUN.VALUE = character(1)
  )
  eligible <- enough & in_range
  tibble::tibble(
    smaller_group = smaller_group,
    in_range = in_range,
    eligible = eligible,
    status = dplyr::if_else(eligible, "fitted threshold", "no_threshold"),
    reason = reason
  )
}
