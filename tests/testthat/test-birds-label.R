test_that("label_observation handles at, just below and just above the cutoff", {
  out <- label_observation(confidence = c(0.8, 0.7999, 0.8001), cutoff = 0.8)
  expect_equal(out, c("observed", "below_threshold", "observed"))
})

test_that("label_observation gives no_threshold when the cutoff is NA", {
  expect_equal(
    label_observation(confidence = c(0.99, 0.2), cutoff = NA_real_),
    c("no_threshold", "no_threshold")
  )
})

test_that("label_observation accepts one cutoff per row", {
  out <- label_observation(
    confidence = c(0.9, 0.9, 0.9),
    cutoff = c(0.8, 0.95, NA)
  )
  expect_equal(out, c("observed", "below_threshold", "no_threshold"))
})

test_that("label_observation rejects a cutoff of the wrong length", {
  expect_error(label_observation(
    confidence = c(0.1, 0.2, 0.3),
    cutoff = c(0.5, 0.6)
  ))
})

# ---- label_predictions (table level) ----------------------------------------
lab_preds <- tibble::tibble(
  id = 1:6,
  common_name = c("A", "B", "A", "C", "A", "B"),
  confidence = c(0.8, 0.5, 0.7999, 0.99, 0.8001, 0.9)
)
lab_thr <- tibble::tibble(
  commonName = c("A", "B", "C"),
  labelling_cutoff = c(0.8, 0.6, NA)
)

test_that("label_predictions keeps rows, columns and order, new columns last", {
  out <- label_predictions(predictions = lab_preds, thresholds = lab_thr)
  expect_equal(nrow(out), nrow(lab_preds))
  expect_equal(out$id, lab_preds$id)
  expect_equal(
    names(out),
    c(names(lab_preds), "observation_status", "observation")
  )
  expect_equal(out[names(lab_preds)], lab_preds)
})

test_that("label_predictions labels at, below and above the cutoff", {
  out <- label_predictions(predictions = lab_preds, thresholds = lab_thr)
  expect_equal(
    out$observation_status,
    c(
      "observed",
      "below_threshold",
      "below_threshold",
      "no_threshold",
      "observed",
      "observed"
    )
  )
})

test_that("a species with NA cutoff is no_threshold with NA observation", {
  out <- label_predictions(predictions = lab_preds, thresholds = lab_thr)
  expect_equal(out$observation_status[[4]], "no_threshold")
  expect_true(is.na(out$observation[[4]]))
})

test_that("observation is the species name only for observed rows", {
  out <- label_predictions(predictions = lab_preds, thresholds = lab_thr)
  observed <- out$observation_status == "observed"
  expect_equal(out$observation[observed], out$common_name[observed])
  expect_true(all(is.na(out$observation[!observed])))
})

test_that("label_predictions errors on a species without a threshold row", {
  expect_error(label_predictions(
    predictions = lab_preds,
    thresholds = lab_thr[lab_thr$commonName != "B", ]
  ))
})
