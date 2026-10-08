test_that("parse_validation_filename splits confidence, rank and recording", {
  out <- parse_validation_filename(
    filename = c(
      "0.107_4_RBS21_20230630_190000.wav",
      "1_12_RBS02_20230622_170002.wav"
    )
  )
  expect_equal(out$file_confidence, c(0.107, 1))
  expect_equal(out$rank, c(4L, 12L))
  expect_equal(
    out$recording,
    c("RBS21_20230630_190000", "RBS02_20230622_170002")
  )
})

test_that("parse_validation_filename errors on a malformed name", {
  expect_error(
    parse_validation_filename(filename = "not_a_valid_name.mp3"),
    "Unparseable"
  )
})

test_that("recording_hour_key snaps clock drift to the hour", {
  keys <- recording_hour_key(
    recording = c(
      "RBS21_20230624_060000",
      "RBS21_20230624_060002",
      "RBS21_20230624_055946"
    )
  )
  expect_equal(keys, rep("RBS21_20230624_06", 3))
})

test_that("recording_hour_key keeps different hours and devices apart", {
  keys <- recording_hour_key(
    recording = c(
      "RBS21_20230624_060000",
      "RBS21_20230624_070000",
      "RBS22_20230624_060000"
    )
  )
  expect_equal(dplyr::n_distinct(keys), 3)
})
