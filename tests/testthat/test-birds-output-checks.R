make_linked <- function() {
  tibble::tibble(
    scientificName = c(rep("Sp a", 4), rep("Sp b", 2)),
    commonName = c(rep("A", 4), rep("B", 2)),
    confidence = c(0.2, 0.4, 0.6, 0.9, 0.3, 0.5),
    outcome = c(0L, 0L, 1L, 1L, 0L, 1L)
  )
}
make_evidence <- function() {
  tibble::tibble(
    commonName = c("A", "B"),
    n_neg = c(2L, 1L),
    n_pos = c(2L, 1L),
    score_min = c(0.2, 0.3),
    score_max = c(0.9, 0.5),
    boot_n_ok = c(90L, 0L),
    boot_n_failed = c(10L, 100L),
    status = c("fitted threshold", "no_threshold"),
    reason = c(NA, "smaller group has 1 clips, minimum 30"),
    labelling_cutoff = c(0.5, NA)
  )
}
make_sens <- function() {
  tibble::tibble(
    min_smaller_group = c(5L, 10L, 30L),
    species_pass = c("A, B", "A", "")
  )
}
check <- function(evidence = make_evidence(), sensitivity = make_sens()) {
  check_evidence_table(
    evidence = evidence,
    validations = make_linked(),
    n_boot = 100,
    sensitivity = sensitivity
  )
}

test_that("a valid linked input and evidence table pass", {
  expect_no_error(check_linked_input(validations = make_linked()))
  expect_no_error(check())
})

test_that("linked input checks fail on bad columns, scores and pairing", {
  expect_error(
    check_linked_input(dplyr::select(make_linked(), -outcome)),
    "outcome"
  )
  v <- make_linked()
  v$confidence[[1]] <- 0
  expect_error(check_linked_input(validations = v), "\\(0, 1\\]")
  v <- make_linked()
  v$scientificName[[5]] <- "Sp a"
  expect_error(check_linked_input(validations = v), "one-to-one")
  expect_error(check_linked_input(validations = make_linked()[0, ]), "no clips")
  v <- make_linked()
  v$outcome[[1]] <- 2L
  expect_error(check_linked_input(validations = v), "outcome")
})

test_that("commonName must be unique", {
  e <- make_evidence()
  e$commonName[[2]] <- "A"
  expect_error(check(evidence = e), "not unique")
})

test_that("counts must match the validated clips", {
  e <- make_evidence()
  e$n_pos[[1]] <- 3L
  expect_error(check(evidence = e), "validated clips")
})

test_that("status, cutoff and reason must agree", {
  e <- make_evidence()
  e$labelling_cutoff[[1]] <- NA
  expect_error(check(evidence = e), "exactly when")
  e <- make_evidence()
  e$reason[[1]] <- "oops"
  expect_error(check(evidence = e), "reason must be set only")
  e <- make_evidence()
  e$reason[[2]] <- NA
  expect_error(check(evidence = e), "reason must be set only")
})

test_that("a fitted cutoff must be strictly inside the validated range", {
  e <- make_evidence()
  e$labelling_cutoff[[1]] <- 0.9
  expect_error(check(evidence = e), "outside")
  e$labelling_cutoff[[1]] <- 0.1
  expect_error(check(evidence = e), "outside")
})

test_that("bootstrap counts must add up to n_boot unless no bootstrap ran", {
  e <- make_evidence()
  e$boot_n_ok[[1]] <- 80L
  expect_error(check(evidence = e), "n_boot")
  e <- make_evidence()
  e$boot_n_ok[[2]] <- NA
  e$boot_n_failed[[2]] <- NA
  expect_no_error(check(evidence = e))
})

test_that("a stricter minimum cannot add species", {
  s <- make_sens()
  s$species_pass <- c("A", "A, B", "")
  expect_error(check(sensitivity = s), "stricter minimum")
})
