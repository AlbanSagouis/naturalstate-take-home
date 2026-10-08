test_that("clamp_confidence clamps 1.0 and leaves other values alone", {
  expect_equal(
    clamp_confidence(confidence = c(0.5, 0.9999, 1), max_value = 0.9999),
    c(0.5, 0.9999, 0.9999)
  )
  expect_true(is.finite(qlogis(p = clamp_confidence(confidence = 1))))
})

test_that("clamp_confidence rejects out of range scores", {
  expect_error(clamp_confidence(confidence = 1.2))
})

test_that("confidence_to_milli rounds half up on 4 decimal scores", {
  expect_equal(
    confidence_to_milli(confidence = c(0.1134, 0.1135, 0.107, 1)),
    c(113L, 114L, 107L, 1000L)
  )
})
