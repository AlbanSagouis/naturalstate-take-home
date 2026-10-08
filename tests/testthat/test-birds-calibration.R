test_that("every clip gets exactly one band, and the top band starts at the threshold", {
  d <- make_synthetic(n = 300)
  b <- assign_score_bands(
    confidence = d$confidence,
    n_bands = 5L,
    threshold = 0.9
  )
  expect_length(b, 300)
  expect_false(anyNA(b))
  expect_equal(sort(unique(b)), 1:6)
  expect_true(all(d$confidence[b == 6] >= 0.9))
  expect_true(all(d$confidence[b < 6] < 0.9))
  # Without a usable threshold there is no extra band
  b_na <- assign_score_bands(confidence = d$confidence, n_bands = 5L)
  expect_equal(sort(unique(b_na)), 1:5)
  b_out <- assign_score_bands(confidence = d$confidence, threshold = 2)
  expect_equal(sort(unique(b_out)), 1:5)
})

test_that("observed and predicted rates are computed per band", {
  d <- make_synthetic(n = 400)
  out <- calibration_by_band(
    confidence = d$confidence,
    outcome = d$outcome,
    n_bands = 4L
  )
  expect_equal(sum(out$n), 400)
  expect_equal(sum(out$n_correct), sum(d$outcome))
  expect_equal(out$observed, out$n_correct / out$n)
  expect_equal(out$difference, out$observed - out$predicted)
  expect_true(all(out$ci_lower <= out$observed & out$observed <= out$ci_upper))

  # Hand check of the first band
  fit <- fit_threshold(confidence = d$confidence, outcome = d$outcome)
  b <- assign_score_bands(
    confidence = d$confidence,
    n_bands = 4L,
    threshold = fit$threshold
  )
  i <- b == 1
  expect_equal(out$n[[1]], sum(i))
  expect_equal(out$observed[[1]], mean(d$outcome[i]))
  expect_equal(
    out$predicted[[1]],
    mean(plogis(
      q = fit$b0 + fit$b1 * qlogis(p = pmin(d$confidence[i], 0.9999))
    ))
  )
  expect_equal(
    out$ci_lower[[1]],
    binom.test(x = sum(d$outcome[i]), n = sum(i))$conf.int[[1]]
  )
})

test_that("bands with fewer than thin_n clips are flagged thin", {
  d <- make_synthetic(n = 400)
  out <- calibration_by_band(
    confidence = d$confidence,
    outcome = d$outcome,
    n_bands = 4L,
    thin_n = 150L
  )
  expect_equal(out$thin, out$n < 150)
  expect_true(any(out$thin))
  expect_false(any(
    calibration_by_band(
      confidence = d$confidence,
      outcome = d$outcome,
      thin_n = 1L
    )$thin
  ))
})

test_that("a species with a single outcome class is skipped with a message", {
  out <- NULL
  expect_message(
    out <- calibration_by_band(
      confidence = c(0.2, 0.5, 0.9),
      outcome = c(1L, 1L, 1L)
    ),
    "calibration skipped"
  )
  expect_equal(nrow(out), 0)
})
