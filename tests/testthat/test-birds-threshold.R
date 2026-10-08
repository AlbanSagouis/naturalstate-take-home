test_that("threshold_from_coef matches the Wood & Kahl formula", {
  # b0 = 0, b1 = 1: threshold is qlogis(target) back-transformed = target
  expect_equal(threshold_from_coef(b0 = 0, b1 = 1, target = 0.99), 0.99)
  # b0 = -2, b1 = 2, target 0.5: plogis((0 + 2) / 2) = plogis(1)
  expect_equal(
    threshold_from_coef(b0 = -2, b1 = 2, target = 0.5),
    plogis(q = 1)
  )
})

test_that("threshold_from_coef is NA for a non-positive or non-finite slope", {
  expect_true(is.na(threshold_from_coef(b0 = 1, b1 = -1)))
  expect_true(is.na(threshold_from_coef(b0 = NA_real_, b1 = 1)))
})

test_that("fit_threshold recovers a known threshold on synthetic data", {
  d <- make_synthetic()
  fit <- fit_threshold(confidence = d$confidence, outcome = d$outcome)
  expect_equal(fit$b0, -3, tolerance = 0.5)
  expect_equal(fit$b1, 6, tolerance = 0.2)
  # true threshold: plogis((qlogis(0.99) + 3) / 6)
  expect_equal(
    fit$threshold,
    plogis(q = (qlogis(p = 0.99) + 3) / 6),
    tolerance = 0.05
  )
  expect_true(is.na(fit$warning))
  expect_false(fit$perfect_separation)
})

test_that("fit_threshold returns NA with a message for a single outcome class", {
  fit <- fit_threshold(confidence = c(0.2, 0.5, 0.9), outcome = c(1, 1, 1))
  expect_true(is.na(fit$threshold))
  expect_match(fit$warning, "single outcome class")
})

test_that("fit_threshold records the glm warning under perfect separation instead of emitting it", {
  confidence <- c(0.1, 0.2, 0.3, 0.7, 0.8, 0.9)
  outcome <- c(0, 0, 0, 1, 1, 1)
  # The helper must stay quiet (it catches the glm warning) ...
  expect_no_warning(
    fit <- fit_threshold(confidence = confidence, outcome = outcome)
  )
  # ... and must report it in the result, so nothing is silently lost.
  expect_match(fit$warning, "fitted probabilities|did not converge")
  expect_true(fit$perfect_separation)
  expect_true(fit$near_separation)
})

test_that("fit_threshold handles a score of exactly 1 through clamping", {
  fit <- fit_threshold(
    confidence = c(0.1, 0.2, 0.4, 0.6, 0.8, 1, 0.3, 0.9, 0.5, 0.95),
    outcome = c(0, 0, 0, 1, 0, 1, 0, 1, 1, 1)
  )
  expect_true(is.finite(fit$b1))
})

elig <- function(n_neg, n_pos, thr, lo = 0.2, hi = 0.95, min_n = 30L) {
  threshold_eligibility(
    n_neg = n_neg,
    n_pos = n_pos,
    glm_threshold = thr,
    score_min = lo,
    score_max = hi,
    min_smaller_group = min_n
  )
}

test_that("threshold_eligibility passes at exactly the minimum and fails one below", {
  at <- elig(n_neg = 30, n_pos = 100, thr = 0.9)
  expect_true(at$eligible)
  expect_equal(at$status, "fitted threshold")
  expect_true(is.na(at$reason))
  below <- elig(n_neg = 100, n_pos = 29, thr = 0.9)
  expect_false(below$eligible)
  expect_equal(below$status, "no_threshold")
  expect_equal(below$reason, "smaller group has 29 clips, minimum 30")
})

test_that("threshold_eligibility fails when the threshold is outside the validated range", {
  above <- elig(n_neg = 50, n_pos = 50, thr = 0.998, hi = 0.907)
  expect_false(above$eligible)
  expect_equal(
    above$reason,
    "fitted threshold 0.998 is above the highest validated score 0.907"
  )
  below <- elig(n_neg = 50, n_pos = 50, thr = 0.1, lo = 0.2)
  expect_match(below$reason, "below the lowest validated score 0.200")
})

test_that("threshold_eligibility fails for a single outcome class", {
  one <- elig(n_neg = 0, n_pos = 40, thr = NA_real_)
  expect_false(one$eligible)
  expect_equal(one$reason, "single outcome class, no fit")
})

test_that("threshold_eligibility combines reasons when several gates fail", {
  both <- elig(n_neg = 1, n_pos = 40, thr = 0.998, hi = 0.907)
  expect_equal(
    both$reason,
    paste0(
      "smaller group has 1 clips, minimum 30; ",
      "fitted threshold 0.998 is above the highest validated score 0.907"
    )
  )
})

test_that("threshold_eligibility is vectorised over species", {
  out <- elig(n_neg = c(33, 1), n_pos = c(60, 60), thr = c(0.9, 0.9))
  expect_equal(out$status, c("fitted threshold", "no_threshold"))
})

test_that("bootstrap_threshold is reproducible and brackets the point estimate", {
  d <- make_synthetic(n = 300)
  a <- bootstrap_threshold(
    confidence = d$confidence,
    outcome = d$outcome,
    n_boot = 200,
    seed = 1
  )
  b <- bootstrap_threshold(
    confidence = d$confidence,
    outcome = d$outcome,
    n_boot = 200,
    seed = 1
  )
  expect_equal(a, b)
  point <- fit_threshold(
    confidence = d$confidence,
    outcome = d$outcome
  )$threshold
  expect_lte(a$boot_lower, point)
  expect_gte(a$boot_upper, point)
  expect_equal(a$boot_n_ok + a$boot_n_failed, 200)
})

test_that("bootstrap_threshold counts resamples that lose a class", {
  # One negative among 30: about a third of resamples contain none
  out <- bootstrap_threshold(
    confidence = seq(from = 0.1, to = 0.99, length.out = 30),
    outcome = c(0, rep(1, 29)),
    n_boot = 300,
    seed = 3
  )
  expect_gt(out$boot_n_failed, 0)
})
