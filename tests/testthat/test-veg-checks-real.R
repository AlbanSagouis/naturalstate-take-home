# The flags of the real data (staged by 01_load_join.R, written by 02_run_checks.R)
# reconcile with the code and with the numbers found when reading the data.

skip_if_no_staged <- function() {
  paths <- veg_config_for_tests()$paths
  testthat::skip_if_not(
    all(fs::file_exists(c(
      paths$survey,
      paths$quadrat,
      paths$species_long,
      paths$flags_processed
    ))),
    "staged vegetation tables or flags are not built (run R/vegetation/01 and 02)"
  )
}

real_ctx <- function() {
  cfg <- veg_config_for_tests()
  list(
    survey = veg_read_csv(path = cfg$paths$survey),
    quadrat = veg_read_csv(path = cfg$paths$quadrat),
    species_long = veg_read_csv(path = cfg$paths$species_long),
    register = veg_read_odk(table = "register", config = cfg),
    vegplots = veg_read_entity(name = "vegplots", config = cfg),
    species = veg_read_entity(name = "species", config = cfg),
    species_extra = veg_read_entity(name = "species_extra", config = cfg),
    project_team = veg_read_entity(name = "project_team", config = cfg)
  )
}

test_that("flag counts per check equal the counts the code reports and the written file", {
  skip_if_no_staged()
  cfg <- veg_config_for_tests()
  ctx <- real_ctx()
  catalogue <- veg_check_catalogue()
  flags <- veg_build_flags(ctx = ctx, catalogue = catalogue, config = cfg)
  counts <- veg_flag_counts(flags = flags, catalogue = catalogue)
  expect_no_error(veg_check_flags(flags = flags, catalogue = catalogue))
  expect_no_error(veg_check_flags_reconcile(
    flags = flags,
    catalogue = catalogue,
    counts = counts
  ))
  written <- readr::read_csv(
    file = cfg$paths$flags_processed,
    col_types = readr::cols(.default = "c")
  )
  expect_identical(nrow(written), nrow(flags))
  expect_identical(
    as.integer(table(factor(written$check_id, levels = catalogue$id))),
    counts$n_flags
  )
  # The tracked deliverable is the same table as the staged one
  tracked <- readr::read_csv(
    file = cfg$paths$flags,
    col_types = readr::cols(.default = "c")
  )
  expect_equal(as.data.frame(tracked), as.data.frame(written))
})

test_that("the written catalogue is the catalogue in the code", {
  skip_if_no_staged()
  cfg <- veg_config_for_tests()
  written <- readr::read_csv(
    file = cfg$paths$catalogue,
    col_types = readr::cols(.default = "c")
  )
  expected <- veg_check_catalogue() |>
    dplyr::select(-fun) |>
    dplyr::mutate(dplyr::across(
      .cols = dplyr::everything(),
      .fns = as.character
    ))
  expect_identical(as.data.frame(written), as.data.frame(expected))
})

test_that("the checks do not modify the real input tables", {
  skip_if_no_staged()
  ctx <- real_ctx()
  before <- ctx
  veg_build_flags(ctx = ctx, catalogue = veg_check_catalogue())
  expect_identical(ctx, before)
})

test_that("the real data give the counts found when reading the data by hand", {
  skip_if_no_staged()
  flags <- readr::read_csv(
    file = veg_config_for_tests()$paths$flags_processed,
    col_types = readr::cols(.default = "c")
  )
  n <- function(id) sum(flags$check_id == id)
  expect_identical(n("CON-04"), 10L) # additional_species_present = yes, no child rows
  expect_identical(n("QUA-04"), 7L) # blank species count where 0 is expected
  expect_identical(n("SPA-02"), 1L) # background accuracy 5.066 m
  expect_identical(n("SPA-03"), 3L) # three blank background geopoints
  expect_identical(n("SPA-01"), 0L) # no quadrat above 5 m
  expect_identical(n("STR-07"), 2L) # Plot_18 and Plot_21 rejected resubmissions
  expect_identical(n("STR-08"), 0L)
  expect_identical(n("SPE-02"), 45L) # every typed name uses a space
  expect_identical(n("TIM-03"), 0L) # the 15 late starts are a time-zone artefact
  expect_identical(n("QUA-01"), 0L)
  expect_identical(
    n("STR-01") + n("STR-02") + n("STR-03") + n("STR-04") + n("STR-05"),
    0L
  )
})

test_that("the field list of the real data is the error and warning flags", {
  skip_if_no_staged()
  cfg <- veg_config_for_tests()
  testthat::skip_if_not(
    fs::file_exists(cfg$paths$field_issues),
    "field issues not written"
  )
  flags <- readr::read_csv(
    file = cfg$paths$flags,
    col_types = readr::cols(.default = "c")
  )
  issues <- readr::read_csv(
    file = cfg$paths$field_issues,
    col_types = readr::cols(.default = "c")
  )
  survey <- veg_read_csv(path = cfg$paths$survey)
  rejected <- veg_rejected_keys(survey = survey)
  expect_gt(length(rejected), 0)
  on_list <- is.element(flags$severity, c("error", "warning")) &
    !is.element(flags$survey_key, rejected)
  expect_identical(nrow(issues), sum(on_list))
  expect_false(any(is.element(issues$survey_key, rejected)))
  # the rejected submissions do have error or warning flags, kept in flags.csv
  expect_gt(
    sum(
      is.element(flags$severity, c("error", "warning")) &
        is.element(flags$survey_key, rejected)
    ),
    0
  )
  expect_false(any(issues$severity == "info"))
})
