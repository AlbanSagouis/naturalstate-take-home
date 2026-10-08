test_that("parse_recording splits device, date and hour", {
  out <- parse_recording(
    recording = c("RBS21_20230630_190000", "RBS02_20230701_060002")
  )
  expect_equal(out$device, c("RBS21", "RBS02"))
  expect_equal(out$date, as.Date(c("2023-06-30", "2023-07-01")))
  expect_equal(out$hour, c(19L, 6L))
  expect_error(parse_recording(recording = "bad_name"), "not in")
})

test_that("hour_block cuts at block edges", {
  expect_equal(
    as.character(hour_block(hour = c(0L, 5L, 6L, 15L, 16L, 19L, 20L, 23L))),
    c("00-05", "00-05", "06-15", "06-15", "16-19", "16-19", "20-23", "20-23")
  )
  expect_error(hour_block(hour = 24L))
})

test_that("aic_table has three models, best at delta 0, and handles one class", {
  d <- make_synthetic()
  out <- aic_table(confidence = d$confidence, outcome = d$outcome)
  expect_equal(out$model, c("null", "confidence_scale", "logit_scale"))
  expect_equal(min(out$delta_aic), 0)
  expect_equal(out$model[[which.min(out$aic)]], "logit_scale")
  expect_equal(
    nrow(aic_table(confidence = c(0.5, 0.6), outcome = c(1L, 1L))),
    0L
  )
})

test_that("device bootstrap is reproducible and covers the full-data threshold", {
  d <- make_synthetic(n = 300)
  device <- rep(x = paste0("D", 1:10), length.out = 300)
  a <- bootstrap_threshold_device(
    confidence = d$confidence,
    outcome = d$outcome,
    device = device,
    n_boot = 200L,
    seed = 3L
  )
  b <- bootstrap_threshold_device(
    confidence = d$confidence,
    outcome = d$outcome,
    device = device,
    n_boot = 200L,
    seed = 3L
  )
  expect_equal(a, b)
  full <- fit_threshold(
    confidence = d$confidence,
    outcome = d$outcome
  )$threshold
  expect_true(a$dboot_lower <= full && full <= a$dboot_upper)
  expect_equal(a$dboot_n_ok + a$dboot_n_failed, 200L)
})

test_that("device bootstrap counts failures when one outcome class dominates", {
  out <- bootstrap_threshold_device(
    confidence = c(0.5, 0.6, 0.7, 0.8),
    outcome = c(1L, 1L, 1L, 0L),
    device = c("A", "A", "A", "B"),
    n_boot = 50L,
    seed = 1L
  )
  expect_gt(out$dboot_n_failed, 0)
  expect_equal(out$dboot_share_failed, out$dboot_n_failed / 50)
})

test_that("fit_daypart_threshold gives two thresholds, or NA when a level has no negatives", {
  d <- make_synthetic(n = 600)
  dp <- rep(x = c("a", "b"), length.out = 600)
  out <- fit_daypart_threshold(
    confidence = d$confidence,
    outcome = d$outcome,
    daypart = dp
  )
  expect_equal(nrow(out), 2L)
  expect_equal(
    out$n_neg,
    c(sum(d$outcome[dp == "a"] == 0), sum(d$outcome[dp == "b"] == 0))
  )
  expect_true(all(out$estimable))
  expect_false(anyNA(out$threshold))
  # level "b" made all positives: cannot be estimated
  y2 <- ifelse(dp == "b", 1L, d$outcome)
  bad <- fit_daypart_threshold(
    confidence = d$confidence,
    outcome = y2,
    daypart = dp
  )
  expect_false(any(bad$estimable))
  expect_true(all(is.na(bad$threshold)))
  expect_equal(bad$n_neg[bad$daypart == "b"], 0L)
})
