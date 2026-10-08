# Calibration check: does the fitted logit-scale model match the observed
# true-positive rate within score bands?

#' Assign clips to score bands
#'
#' `n_bands` bands of roughly equal numbers of clips (quantiles of confidence).
#' When `threshold` lies inside the validated range, clips at or above it form
#' one extra top band, built first, so the region that decides the label is
#' always visible. Ties in confidence are never split across bands.
#'
#' @param confidence Numeric scores in [0, 1].
#' @param n_bands Number of quantile bands for the clips below the threshold.
#' @param threshold Species glm threshold, or NA for no top band.
#' @return Integer vector, band 1 = lowest scores; every clip gets one band.
assign_score_bands <- function(confidence, n_bands = 5L, threshold = NA_real_) {
  checkmate::assert_numeric(
    x = confidence,
    lower = 0,
    upper = 1,
    any.missing = FALSE,
    min.len = 1
  )
  checkmate::assert_count(x = n_bands, positive = TRUE)
  checkmate::assert_number(x = threshold, na.ok = TRUE)

  has_top <- !is.na(threshold) &&
    threshold > min(confidence) &&
    threshold <= max(confidence)
  top <- if (has_top) {
    confidence >= threshold
  } else {
    rep(FALSE, length(confidence))
  }

  below <- confidence[!top]
  breaks <- unique(quantile(
    x = below,
    probs = seq(from = 0, to = 1, length.out = n_bands + 1),
    names = FALSE
  ))
  # A single distinct value cannot be cut: one band
  bands <- if (length(breaks) < 2) {
    rep(1L, length(below))
  } else {
    as.integer(cut(x = below, breaks = breaks, include.lowest = TRUE))
  }
  out <- integer(length(confidence))
  out[!top] <- bands
  out[top] <- max(c(bands, 0L)) + 1L
  out
}

#' Observed vs fitted true-positive rate by score band
#'
#' Fits the same model as fit_threshold() (outcome ~ qlogis(clamped
#' confidence)), then compares, per band, the observed rate (Clopper-Pearson
#' interval) with the mean fitted probability. Returns zero rows, with a
#' message, for a single outcome class.
#'
#' @inheritParams fit_threshold
#' @param n_bands Number of quantile bands below the threshold.
#' @param level Confidence level of the interval.
#' @param thin_n Bands with fewer clips than this are flagged thin.
#' @return Tibble: band, is_top_band, conf_min, conf_max, conf_mean, n, n_correct,
#'   observed, ci_lower, ci_upper, predicted, difference (observed minus
#'   predicted), thin.
calibration_by_band <- function(
  confidence,
  outcome,
  n_bands = 5L,
  target = 0.99,
  clamp_max = 0.9999,
  level = 0.95,
  thin_n = 10L
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
  checkmate::assert_number(x = level, lower = 0.5, upper = 0.9999)
  checkmate::assert_count(x = thin_n, positive = TRUE)

  empty <- tibble::tibble(
    band = integer(0),
    is_top_band = logical(0),
    conf_min = numeric(0),
    conf_max = numeric(0),
    conf_mean = numeric(0),
    n = integer(0),
    n_correct = integer(0),
    observed = numeric(0),
    ci_lower = numeric(0),
    ci_upper = numeric(0),
    predicted = numeric(0),
    difference = numeric(0),
    thin = logical(0)
  )
  if (dplyr::n_distinct(outcome) < 2) {
    cli::cli_alert_warning("Single outcome class, calibration skipped.")
    return(empty)
  }

  fit <- fit_threshold(
    confidence = confidence,
    outcome = outcome,
    target = target,
    clamp_max = clamp_max
  )
  band <- assign_score_bands(
    confidence = confidence,
    n_bands = n_bands,
    threshold = fit$threshold
  )
  d <- tibble::tibble(
    band = band,
    confidence = confidence,
    outcome = outcome,
    predicted = plogis(
      q = fit$b0 +
        fit$b1 *
          qlogis(
            p = clamp_confidence(confidence = confidence, max_value = clamp_max)
          )
    )
  )
  d |>
    dplyr::summarise(
      conf_min = min(confidence),
      conf_max = max(confidence),
      conf_mean = mean(confidence),
      n = dplyr::n(),
      n_correct = sum(outcome),
      predicted = mean(predicted),
      .by = band
    ) |>
    dplyr::arrange(band) |>
    dplyr::mutate(
      is_top_band = !is.na(fit$threshold) & conf_min >= fit$threshold,
      observed = n_correct / n,
      ci_lower = vapply(
        X = seq_len(dplyr::n()),
        FUN = function(i) {
          binom.test(
            x = n_correct[[i]],
            n = n[[i]],
            conf.level = level
          )$conf.int[[1]]
        },
        FUN.VALUE = 1
      ),
      ci_upper = vapply(
        X = seq_len(dplyr::n()),
        FUN = function(i) {
          binom.test(
            x = n_correct[[i]],
            n = n[[i]],
            conf.level = level
          )$conf.int[[2]]
        },
        FUN.VALUE = 1
      ),
      difference = observed - predicted,
      thin = n < thin_n
    ) |>
    dplyr::select(
      band,
      is_top_band,
      conf_min,
      conf_max,
      conf_mean,
      n,
      n_correct,
      observed,
      ci_lower,
      ci_upper,
      predicted,
      difference,
      thin
    )
}
