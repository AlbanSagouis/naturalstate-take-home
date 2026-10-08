# Bootstrap uncertainty for the threshold.

#' Bootstrap interval for the glm threshold
#'
#' Resamples validated clips with replacement (within one species), refits
#' fit_threshold() each time and takes percentile limits. Resamples with a
#' single outcome class or a non-positive slope give NA and are counted, not
#' hidden. The seed is set inside so results are reproducible per call.
#'
#' @inheritParams fit_threshold
#' @param n_boot Number of resamples.
#' @param level Interval level, e.g. 0.95.
#' @param seed Integer seed.
#' @return One-row tibble: boot_lower, boot_median, boot_upper, boot_n_ok,
#'   boot_n_failed (NA threshold), boot_n_warned (glm warned).
bootstrap_threshold <- function(
  confidence,
  outcome,
  n_boot = 2000L,
  level = 0.95,
  target = 0.99,
  clamp_max = 0.9999,
  seed = 1L
) {
  checkmate::assert_numeric(
    x = confidence,
    lower = 0,
    upper = 1,
    any.missing = FALSE,
    min.len = 2
  )
  checkmate::assert_integerish(
    x = outcome,
    lower = 0,
    upper = 1,
    any.missing = FALSE,
    len = length(confidence)
  )
  checkmate::assert_count(x = n_boot, positive = TRUE)
  checkmate::assert_number(x = level, lower = 0.5, upper = 0.9999)
  set.seed(seed = seed)

  n <- length(confidence)
  one_resample <- function(i) {
    idx <- sample.int(n = n, size = n, replace = TRUE)
    fit <- fit_threshold(
      confidence = confidence[idx],
      outcome = outcome[idx],
      target = target,
      clamp_max = clamp_max
    )
    c(threshold = fit$threshold, warned = as.numeric(!is.na(fit$warning)))
  }
  draws <- vapply(
    X = seq_len(n_boot),
    FUN = one_resample,
    FUN.VALUE = c(threshold = 0, warned = 0)
  )
  thr <- draws["threshold", ]
  ok <- !is.na(thr)

  tibble::tibble(
    boot_lower = if (any(ok)) {
      unname(quantile(x = thr[ok], probs = (1 - level) / 2))
    } else {
      NA_real_
    },
    boot_median = if (any(ok)) median(x = thr[ok]) else NA_real_,
    boot_upper = if (any(ok)) {
      unname(quantile(x = thr[ok], probs = 1 - (1 - level) / 2))
    } else {
      NA_real_
    },
    boot_n_ok = sum(ok),
    boot_n_failed = sum(!ok),
    boot_n_warned = sum(draws["warned", ])
  )
}
