test_that("precision_summary reports precision and a Clopper-Pearson interval", {
  out <- precision_summary(outcome = c(rep(1, 98), 0, 0))
  expect_equal(out$precision, 0.98)
  expect_equal(out$cp_lower, binom.test(x = 98, n = 100)$conf.int[[1]])
  expect_true(is.na(out$rule3_lower))
})

test_that("precision_summary gives the rule-of-three bound when there are no errors", {
  out <- precision_summary(outcome = rep(1, 60))
  expect_equal(out$rule3_lower, 1 - 3 / 60)
})

test_that("precision_summary returns NA for an empty set", {
  expect_true(is.na(precision_summary(outcome = integer(0))$precision))
})
