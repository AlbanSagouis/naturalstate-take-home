# Reconciliation on the real staged tables (issue #9). Skipped when the pipeline
# (R/vegetation/01 to 03) has not been run.

test_that("real summaries reconcile with the staged tables", {
  paths <- veg_config$paths
  skip_if_not(
    fs::file_exists(paths$survey) &&
      fs::file_exists(paths$flags) &&
      fs::file_exists(paths$survey_summary)
  )
  survey <- veg_read_csv(path = paths$survey)
  quadrat <- veg_read_csv(path = paths$quadrat)
  species_long <- veg_read_csv(path = paths$species_long)
  flags <- veg_read_csv(path = paths$flags)
  vegplots <- veg_read_entity(name = "vegplots")
  records <- veg_record_taxa(species_long = species_long)

  # Headline numbers of the 2026-05 export (32 submissions, 640 quadrats); update them
  # here, and nowhere else, when the export changes
  expect_equal(nrow(survey), 32)
  expect_equal(nrow(quadrat), 640)
  survey_summary <- veg_survey_summary(
    survey = survey,
    quadrat = quadrat,
    records = records,
    flags = flags
  )
  plot_summary <- veg_plot_summary(
    survey = survey,
    quadrat = quadrat,
    records = records,
    vegplots = vegplots,
    flags = flags
  )
  expect_equal(nrow(survey_summary), 32)
  expect_equal(sum(survey_summary$n_quadrats), 640)
  expect_equal(
    sum(plot_summary$surveyed),
    n_distinct(survey$`plot_selection-plot_name`)
  )
  expect_equal(nrow(plot_summary), nrow(vegplots))
  expect_equal(
    sum(survey_summary$n_error),
    sum(flags$severity == "error" & !is.na(flags$survey_key))
  )
  expect_no_error(veg_check_summaries_reconcile(
    survey_summary = survey_summary,
    plot_summary = plot_summary
  ))
  n_names <- n_distinct(records$taxon, na.rm = TRUE)
  expect_no_error(veg_check_richness_bound(
    survey_summary = survey_summary,
    plot_summary = plot_summary,
    n_names = n_names
  ))

  # The written deliverable is the same as a fresh computation
  written <- read_csv(
    file = paths$survey_summary,
    show_col_types = FALSE
  )
  expect_equal(written$richness, survey_summary$richness)
  expect_equal(written$n_quadrats, survey_summary$n_quadrats)

  # No record is lost between the staged long table and the taxa table
  expect_equal(nrow(records), nrow(species_long))
  # Every selected-list species is an identified taxon
  expect_true(all(
    records$taxon_class[records$source == "selected_list"] == "identified"
  ))

  exclusions <- veg_exclusions(
    flags = flags,
    survey = survey,
    quadrat = quadrat
  )
  kept <- veg_apply_exclusions(
    survey = survey,
    quadrat = quadrat,
    records = records,
    exclusions = exclusions
  )
  expect_no_error(veg_check_no_lost_records(
    quadrat_all = quadrat,
    quadrat_sens = kept$quadrat,
    survey_all = survey,
    survey_sens = kept$survey,
    exclusions = exclusions
  ))
  # Every error flag with a quadrat lands in the exclusions
  errors <- flags$quadrat_key[
    flags$severity == "error" & !is.na(flags$quadrat_key)
  ]
  expect_true(all(is.element(errors, exclusions$quadrats$quadrat_key)))
})

test_that("real plot summary counts accepted submissions only", {
  paths <- veg_config$paths
  skip_if_not(
    fs::file_exists(paths$plot_summary) && fs::file_exists(paths$survey_summary)
  )
  plots <- read_csv(file = paths$plot_summary, show_col_types = FALSE)
  surveys <- read_csv(
    file = paths$survey_summary,
    show_col_types = FALSE
  )
  rejected <- surveys[
    !is.na(surveys$review_state) & surveys$review_state == "rejected",
  ]
  expect_gt(nrow(rejected), 0)
  # Every surveyed plot has the quadrats of its accepted submissions, none of a rejected one
  accepted <- surveys[
    is.na(surveys$review_state) | surveys$review_state != "rejected",
  ]
  expected <- accepted |>
    summarise(n = sum(n_quadrats), .by = plot_name)
  joined <- inner_join(
    x = expected,
    y = plots,
    by = "plot_name",
    relationship = "one-to-one",
    unmatched = c(x = "error", y = "drop")
  )
  expect_equal(joined$n, joined$n_quadrats)
  expect_lte(max(plots$n_quadrats), veg_config$expected_quadrats_per_plot)
})

test_that("the totals count only the flags of accepted submissions", {
  paths <- veg_config$paths
  skip_if_not(
    fs::file_exists(paths$survey) &&
      fs::file_exists(paths$flags) &&
      fs::file_exists(paths$totals)
  )
  survey <- veg_read_csv(path = paths$survey)
  flags <- veg_read_csv(path = paths$flags)
  accepted_flags <- veg_flags_accepted(flags = flags, survey = survey)
  # Rejected submissions carry flags, so the two counts must differ
  expect_lt(nrow(accepted_flags), nrow(flags))
  totals <- read_csv(paths$totals, show_col_types = FALSE)
  for (severity in c("error", "warning", "info")) {
    expect_equal(
      totals[[paste0("n_flags_", severity)]],
      rep(sum(accepted_flags$severity == severity), times = nrow(totals))
    )
  }
})

test_that("the accepted headline numbers are those of the 2026-05 export", {
  paths <- veg_config$paths
  skip_if_not(fs::file_exists(paths$totals))
  accepted <- read_csv(paths$totals, show_col_types = FALSE) |>
    filter(version == "accepted")
  # 32 submissions minus the 2 rejected in ODK, and 640 quadrats minus their 40
  expect_equal(accepted$n_surveys, 30)
  expect_equal(accepted$n_quadrats, 600)
})

test_that("the written effort table reconciles with the plot summary", {
  paths <- veg_config$paths
  skip_if_not(
    fs::file_exists(paths$effort) &&
      fs::file_exists(paths$plot_summary) &&
      fs::file_exists(paths$accumulation_curves)
  )
  effort <- read_csv(paths$effort, show_col_types = FALSE)
  plots <- read_csv(paths$plot_summary, show_col_types = FALSE)
  expect_no_error(veg_check_effort(effort = effort, plot_summary = plots))
  # The 2026-05 export: every accepted plot has its 20 quadrats and iNEXT estimates all of them
  expect_true(all(effort$quadrats_short == 0))
  expect_true(all(effort$estimate_status == "ok"))
  curves <- read_csv(paths$accumulation_curves, show_col_types = FALSE)
  expect_equal(
    curves$richness[
      curves$n_quadrats == 20 & curves$plot_name == effort$plot_name[1]
    ],
    effort$observed_richness[1]
  )
})
