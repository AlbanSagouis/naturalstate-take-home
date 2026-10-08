# Helpers for the robustness checks: covariates from the recording name, AIC
# comparison, device-level bootstrap and a day-part model.

#' Split a recording name into device, date and hour
#'
#' Recording names are `<device>_<YYYYMMDD>_<HHMMSS>`. The hour is the start
#' hour as written (no snapping), which is enough for day-part blocks.
#'
#' @param recording Character vector of recording names without extension.
#' @return Tibble with device (character), date (Date), hour (integer).
parse_recording <- function(recording) {
  checkmate::assert_character(x = recording, any.missing = FALSE, min.len = 1)
  parts <- stringi::stri_match_first_regex(
    str = recording,
    pattern = "^([A-Za-z0-9]+)_([0-9]{8})_([0-9]{2})[0-9]{4}$"
  )
  if (anyNA(x = parts[, 1])) {
    cli::cli_abort("Recording name(s) not in <device>_<date>_<time> form.")
  }
  tibble::tibble(
    device = parts[, 2],
    date = as.Date(x = parts[, 3], format = "%Y%m%d"),
    hour = as.integer(parts[, 4])
  )
}

#' Hour-of-day blocks
#'
#' @param hour Integer hours 0-23.
#' @return Ordered factor with levels "00-05", "06-15", "16-19", "20-23".
hour_block <- function(hour) {
  checkmate::assert_integerish(
    x = hour,
    lower = 0,
    upper = 23,
    any.missing = FALSE
  )
  cut(
    x = hour,
    breaks = c(-1, 5, 15, 19, 23),
    labels = c("00-05", "06-15", "16-19", "20-23"),
    ordered_result = TRUE
  )
}

# glm that stores warnings instead of printing them (as in fit_threshold()).
quiet_glm <- function(formula, data) {
  withCallingHandlers(
    glm(formula = formula, family = binomial(), data = data),
    warning = function(w) invokeRestart(r = "muffleWarning")
  )
}

#' AIC comparison: null, confidence scale, logit scale
#'
#' Wood & Kahl compare these three per species. Confidence is clamped before
#' the logit, as in fit_threshold(). Returns zero rows for a single outcome
#' class, because the models are not identifiable.
#'
#' @inheritParams fit_threshold
#' @return Tibble: model, k (parameters), aic, delta_aic (0 = best).
aic_table <- function(confidence, outcome, clamp_max = 0.9999) {
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
  if (dplyr::n_distinct(outcome) < 2) {
    return(tibble::tibble(
      model = character(0),
      k = integer(0),
      aic = numeric(0),
      delta_aic = numeric(0)
    ))
  }
  d <- data.frame(
    outcome = outcome,
    conf = confidence,
    logit_conf = qlogis(
      p = clamp_confidence(confidence = confidence, max_value = clamp_max)
    )
  )
  fits <- list(
    null = quiet_glm(formula = outcome ~ 1, data = d),
    confidence_scale = quiet_glm(formula = outcome ~ conf, data = d),
    logit_scale = quiet_glm(formula = outcome ~ logit_conf, data = d)
  )
  tibble::tibble(
    model = names(fits),
    k = vapply(X = fits, FUN = function(f) length(coef(f)), FUN.VALUE = 1L),
    aic = vapply(X = fits, FUN = AIC, FUN.VALUE = 1)
  ) |>
    dplyr::mutate(delta_aic = aic - min(aic))
}

#' Device-level (cluster) bootstrap of the threshold
#'
#' Resamples whole devices with replacement, so clips from one recorder stay
#' together, and refits fit_threshold() on the stacked clips. Failed fits
#' (single class, non-positive slope) are counted, not hidden.
#'
#' @inheritParams bootstrap_threshold
#' @param device Character vector, one device per clip.
#' @return One-row tibble: dboot_lower, dboot_median, dboot_upper,
#'   dboot_n_ok, dboot_n_failed, dboot_share_failed.
bootstrap_threshold_device <- function(
  confidence,
  outcome,
  device,
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
  checkmate::assert_character(
    x = device,
    any.missing = FALSE,
    len = length(confidence)
  )
  checkmate::assert_count(x = n_boot, positive = TRUE)
  checkmate::assert_number(x = level, lower = 0.5, upper = 0.9999)
  set.seed(seed = seed)

  rows_by_device <- split(x = seq_along(confidence), f = device)
  n_dev <- length(rows_by_device)
  one_resample <- function(i) {
    idx <- unlist(
      x = rows_by_device[sample.int(n = n_dev, size = n_dev, replace = TRUE)],
      use.names = FALSE
    )
    fit_threshold(
      confidence = confidence[idx],
      outcome = outcome[idx],
      target = target,
      clamp_max = clamp_max
    )$threshold
  }
  thr <- vapply(X = seq_len(n_boot), FUN = one_resample, FUN.VALUE = 0)
  ok <- !is.na(thr)
  q <- function(p) {
    if (any(ok)) unname(quantile(x = thr[ok], probs = p)) else NA_real_
  }

  tibble::tibble(
    dboot_lower = q(p = (1 - level) / 2),
    dboot_median = q(p = 0.5),
    dboot_upper = q(p = 1 - (1 - level) / 2),
    dboot_n_ok = sum(ok),
    dboot_n_failed = sum(!ok),
    dboot_share_failed = mean(!ok)
  )
}

#' Does adding a two-level day-part improve the logit-scale glm?
#'
#' Compares outcome ~ logit_conf with outcome ~ logit_conf + daypart by AIC and
#' gives the threshold implied for each level. If any level has a single
#' outcome class (e.g. no negatives) its effect cannot be estimated (the
#' coefficient diverges), so coefficients and thresholds are NA and
#' estimable is FALSE; the AIC columns are then not meaningful either.
#'
#' @inheritParams fit_threshold
#' @param daypart Factor or character, two levels, no NA. First level is the reference.
#' @return One row per level: daypart, n_neg, n_pos, estimable, shift
#'   (intercept change vs the reference), threshold, aic_base, aic_daypart,
#'   delta_aic (daypart minus base; negative favours the day-part model).
fit_daypart_threshold <- function(
  confidence,
  outcome,
  daypart,
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
  checkmate::assert_atomic_vector(
    x = daypart,
    any.missing = FALSE,
    len = length(confidence)
  )
  daypart <- factor(x = daypart)
  checkmate::assert_true(x = nlevels(daypart) == 2)

  # Counted on the vectors before building the tibble: inside mutate(), the
  # name `daypart` would refer to the column, not the input vector.
  lvl <- levels(daypart)
  n_neg <- vapply(
    X = lvl,
    FUN = function(l) sum(outcome[daypart == l] == 0),
    FUN.VALUE = 1L,
    USE.NAMES = FALSE
  )
  n_pos <- vapply(
    X = lvl,
    FUN = function(l) sum(outcome[daypart == l] == 1),
    FUN.VALUE = 1L,
    USE.NAMES = FALSE
  )
  counts <- tibble::tibble(
    daypart = lvl,
    n_neg = n_neg,
    n_pos = n_pos,
    estimable = n_neg > 0 & n_pos > 0 & dplyr::n_distinct(outcome) == 2,
    shift = NA_real_,
    threshold = NA_real_,
    aic_base = NA_real_,
    aic_daypart = NA_real_,
    delta_aic = NA_real_
  )
  if (!all(counts$estimable)) {
    return(counts |> dplyr::mutate(estimable = FALSE))
  }
  d <- data.frame(
    outcome = outcome,
    daypart = daypart,
    logit_conf = qlogis(
      p = clamp_confidence(confidence = confidence, max_value = clamp_max)
    )
  )
  base <- quiet_glm(formula = outcome ~ logit_conf, data = d)
  full <- quiet_glm(formula = outcome ~ logit_conf + daypart, data = d)
  b <- unname(coef(full)) # intercept, slope, shift of level 2
  counts |>
    dplyr::mutate(
      shift = c(0, b[[3]]),
      threshold = vapply(
        X = shift,
        FUN = function(s) {
          threshold_from_coef(b0 = b[[1]] + s, b1 = b[[2]], target = target)
        },
        FUN.VALUE = 1
      ),
      aic_base = AIC(base),
      aic_daypart = AIC(full),
      delta_aic = aic_daypart - aic_base
    )
}
