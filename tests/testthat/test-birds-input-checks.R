make_validations <- function() {
  tibble::tibble(
    scientificName = c("Sp a", "Sp a", "Sp b"),
    commonName = c("A", "A", "B"),
    vBirdNET = "v2.4",
    filename = c(
      "0.101_1_R1_20230101_000000.wav",
      "0.5_1_R1_20230101_010000.wav",
      "0.9_0_R2_20230101_000000.wav"
    ),
    confidence = c(0.101, 0.5, 0.9),
    outcome = c(1L, 0L, 1L)
  )
}
make_predictions <- function() {
  tibble::tibble(
    selection = 1:3,
    begin_time_s = c(0, 3, 0),
    end_time_s = c(3, 6, 3),
    common_name = c("A", "A", "B"),
    species_code = c("a1", "a1", "b1"),
    confidence = c(0.1, 0.5, 0.9),
    begin_path = c("p/R1.WAV", "p/R1.WAV", "p/R2.WAV")
  )
}

test_that("valid inputs pass", {
  expect_no_error(check_validations_input(make_validations()))
  expect_no_error(check_predictions_input(predictions = make_predictions()))
})

test_that("required columns are enforced", {
  expect_error(
    check_validations_input(dplyr::select(make_validations(), -outcome)),
    "outcome"
  )
  expect_error(
    check_predictions_input(
      predictions = dplyr::select(make_predictions(), -end_time_s)
    ),
    "end_time_s"
  )
})

test_that("duplicated validation filenames are an error", {
  v <- make_validations()
  v$filename[[2]] <- v$filename[[1]]
  expect_error(check_validations_input(v), "duplicated validation filename")
})

test_that("species names must pair one-to-one", {
  v <- make_validations()
  v$commonName[[3]] <- "A"
  expect_error(check_validations_input(v), "one-to-one")
  p <- make_predictions()
  p$species_code[[3]] <- "a1"
  expect_error(check_predictions_input(predictions = p), "one-to-one")
})

test_that("confidence below the BirdNET run threshold fails, rounding slack passes", {
  v <- make_validations()
  v$confidence[[1]] <- 0.05
  expect_error(check_validations_input(v), "run threshold")
  p <- make_predictions()
  p$confidence[[1]] <- 0.05
  expect_error(check_predictions_input(predictions = p), "run threshold")
  v$confidence[[1]] <- 0.1
  expect_no_error(check_validations_input(v))
})

test_that("validation confidence beyond 3 decimals fails", {
  v <- make_validations()
  v$confidence[[2]] <- 0.5004
  expect_error(check_validations_input(v), "3 decimals")
})

test_that("duplicated prediction keys and non-3 s segments fail", {
  p <- make_predictions()
  p[2, c("begin_time_s", "end_time_s")] <- list(0, 3)
  expect_error(check_predictions_input(predictions = p), "duplicated")
  p <- make_predictions()
  p$end_time_s[[1]] <- 5
  expect_error(check_predictions_input(predictions = p), "3 s long")
})
