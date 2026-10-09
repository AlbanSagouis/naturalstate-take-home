# Tests for R/functions/veg_summaries.R and the summary checks (issue #9)

test_that("exclusions: flagged quadrat, flagged survey and rejected submission", {
  ex <- veg_exclusions(
    flags = sum_flags(),
    survey = sum_survey(),
    quadrat = sum_quadrat()
  )
  expect_equal(sort(ex$quadrats$quadrat_key), c("q2", "q3"))
  expect_equal(
    ex$quadrats$reason[ex$quadrats$quadrat_key == "q2"],
    "error_flag_quadrat"
  )
  expect_equal(
    ex$quadrats$reason[ex$quadrats$quadrat_key == "q3"],
    "rejected_submission"
  )
  expect_equal(ex$surveys$survey_key, "s2")
  # An error without a quadrat leaves out the whole submission
  flags <- bind_rows(
    sum_flags(),
    tibble(
      severity = "error",
      survey_key = "s3",
      quadrat_key = NA_character_,
      plot_name = "B"
    )
  )
  ex2 <- veg_exclusions(
    flags = flags,
    survey = sum_survey(),
    quadrat = sum_quadrat()
  )
  expect_true(is.element("q4", ex2$quadrats$quadrat_key))
  expect_true(is.element("s3", ex2$surveys$survey_key))
  # A flagged quadrat that does not exist is a broken input
  bad <- bind_rows(
    sum_flags(),
    tibble(
      severity = "error",
      survey_key = "s1",
      quadrat_key = "q99",
      plot_name = "A"
    )
  )
  expect_error(
    veg_exclusions(flags = bad, survey = sum_survey(), quadrat = sum_quadrat()),
    "not in the quadrat table"
  )
})

test_that("a rejected submission leaves the main numbers and its flags leave the plot counts", {
  ex <- veg_exclusions(
    flags = sum_flags(),
    survey = sum_survey(),
    quadrat = sum_quadrat()
  )
  expect_equal(veg_rejected_keys(survey = sum_survey()), "s2")
  rej <- veg_rejected_exclusions(exclusions = ex)
  # Only the review decision: the error-flagged quadrat q2 is not part of it
  expect_equal(rej$quadrats$quadrat_key, "q3")
  expect_equal(rej$surveys$survey_key, "s2")
  main <- veg_apply_exclusions(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    exclusions = rej
  )
  expect_false(is.element("s2", main$survey$KEY))
  expect_true(is.element("q2", main$quadrat$KEY))
  plot_main <- veg_plot_summary(
    survey = main$survey,
    quadrat = main$quadrat,
    records = main$records,
    vegplots = sum_vegplots(),
    flags = veg_flags_accepted(flags = sum_flags(), survey = sum_survey())
  )
  # Plot A keeps the quadrats of its accepted survey only, one survey, none of s2's flags
  expect_equal(plot_main$n_surveys[plot_main$plot_name == "A"], 1L)
  flags_acc <- veg_flags_accepted(flags = sum_flags(), survey = sum_survey())
  expect_false(any(flags_acc$survey_key == "s2"))
  expect_equal(nrow(flags_acc), sum(sum_flags()$survey_key != "s2"))
  # Without the rule the plot would pool both visits
  pooled <- veg_plot_summary(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    vegplots = sum_vegplots(),
    flags = sum_flags()
  )
  expect_gt(
    pooled$n_quadrats[pooled$plot_name == "A"],
    plot_main$n_quadrats[plot_main$plot_name == "A"]
  )
  # A flags table without a survey key is a broken input
  expect_error(
    veg_flags_accepted(
      flags = select(.data = sum_flags(), -survey_key),
      survey = sum_survey()
    ),
    "must include"
  )
})

test_that("exclusion check accepts valid and rejects broken exclusions", {
  ex <- veg_exclusions(
    flags = sum_flags(),
    survey = sum_survey(),
    quadrat = sum_quadrat()
  )
  expect_no_error(veg_check_exclusions(
    exclusions = ex,
    survey = sum_survey(),
    quadrat = sum_quadrat()
  ))
  ex$quadrats$quadrat_key[1] <- "nope"
  expect_error(
    veg_check_exclusions(
      exclusions = ex,
      survey = sum_survey(),
      quadrat = sum_quadrat()
    ),
    "subset of"
  )
  ex <- veg_exclusions(
    flags = sum_flags(),
    survey = sum_survey(),
    quadrat = sum_quadrat()
  )
  ex$quadrats$reason[1] <- "because"
  expect_error(
    veg_check_exclusions(
      exclusions = ex,
      survey = sum_survey(),
      quadrat = sum_quadrat()
    ),
    "error_flag_quadrat"
  )
})

test_that("quadrat counts keep empty quadrats and separate unknowns", {
  counts <- veg_quadrat_counts(quadrat = sum_quadrat(), records = sum_records())
  expect_equal(counts$n_identified, c(1L, 2L, 1L, 0L))
  expect_equal(counts$n_unknown, c(1L, 0L, 0L, 1L))
  expect_equal(counts$has_unknown, c(TRUE, FALSE, FALSE, TRUE))
  # A quadrat without any record still has a row, with zeros
  none <- veg_quadrat_counts(
    quadrat = sum_quadrat(),
    records = sum_records()[0, ]
  )
  expect_equal(nrow(none), 4)
  expect_true(all(none$n_records == 0L))
})

test_that("survey summary: one row per submission, headline richness excludes unknowns", {
  s <- veg_survey_summary(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    flags = sum_flags()
  )
  expect_equal(s$survey_key, c("s1", "s2", "s3"))
  expect_equal(s$n_quadrats, c(2L, 1L, 1L))
  expect_equal(s$richness, c(2L, 1L, 0L))
  expect_equal(s$n_unknown_labels, c(1L, 0L, 1L))
  expect_equal(s$richness_upper_bound, c(3L, 1L, 1L))
  expect_equal(s$n_quadrats_with_species, c(2L, 1L, 1L))
  expect_equal(s$duration_min, c(30, 60, 45))
  expect_equal(s$survey_date, c("2026-05-26", "2026-05-27", "2026-05-28"))
  expect_equal(s$n_error, c(1L, 0L, 0L))
  expect_equal(s$n_warning, c(1L, 0L, 0L))
  expect_equal(s$n_info, c(0L, 0L, 1L))
  expect_no_error(veg_check_survey_summary(
    summary = s,
    survey = sum_survey(),
    quadrat = sum_quadrat()
  ))
})

test_that("survey summary refuses an orphan quadrat", {
  q <- bind_rows(sum_quadrat(), tibble(KEY = "q9", PARENT_KEY = "sX"))
  expect_error(
    veg_survey_summary(
      survey = sum_survey(),
      quadrat = q,
      records = sum_records(),
      flags = sum_flags()
    ),
    "not in the survey table"
  )
})

test_that("survey summary check fails on lost quadrats, missing surveys and incoherent counts", {
  s <- veg_survey_summary(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    flags = sum_flags()
  )
  lost <- s
  lost$n_quadrats[1] <- 1L
  expect_error(
    veg_check_survey_summary(
      summary = lost,
      survey = sum_survey(),
      quadrat = sum_quadrat()
    ),
    "quadrats"
  )
  expect_error(
    veg_check_survey_summary(
      summary = s[-1, ],
      survey = sum_survey(),
      quadrat = sum_quadrat()
    ),
    "differ"
  )
  more <- s
  more$n_quadrats_with_species[1] <- 9L
  expect_error(
    veg_check_survey_summary(
      summary = more,
      survey = sum_survey(),
      quadrat = sum_quadrat()
    ),
    "more quadrats"
  )
  unk <- s
  unk$richness_upper_bound[1] <- 0L
  expect_error(
    veg_check_survey_summary(
      summary = unk,
      survey = sum_survey(),
      quadrat = sum_quadrat()
    ),
    "unknowns"
  )
})

test_that("plot summary: gamma, mean, unknowns, unsurveyed plot", {
  p <- veg_plot_summary(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    vegplots = sum_vegplots(),
    flags = sum_flags()
  )
  expect_equal(p$plot_name, c("A", "B", "C"))
  expect_equal(p$surveyed, c(TRUE, TRUE, FALSE))
  expect_equal(p$n_surveys, c(2L, 1L, 0L))
  expect_equal(p$n_quadrats, c(3L, 1L, 0L))
  expect_equal(p$gamma_richness, c(2L, 0L, NA_integer_))
  # Info flags are counted in the survey table and the map layer, not in the plot table
  expect_false(is.element(el = "n_info", set = names(p)))
  # No diversity index in the table: it is only used by the plot-diversity check
  expect_false(any(is.element(el = c("shannon", "hill1"), set = names(p))))
  expect_equal(p$mean_quadrat_richness[1], (1 + 2 + 1) / 3)
  expect_equal(p$share_quadrats_unknown[1], 1 / 3)
  expect_equal(p$richness_upper_bound[1], 3L)
  expect_equal(p$n_quadrats[3], 0L)
  expect_equal(p$plot_status, c("primary", "backup", "primary"))
  expect_no_error(veg_check_plot_summary(
    summary = p,
    vegplots = sum_vegplots(),
    survey = sum_survey(),
    quadrat = sum_quadrat()
  ))
})

test_that("plot summary refuses a surveyed plot that is not registered", {
  expect_error(
    veg_plot_summary(
      survey = sum_survey(),
      quadrat = sum_quadrat(),
      records = sum_records(),
      vegplots = sum_vegplots()[-2, ],
      flags = sum_flags()
    ),
    "not registered"
  )
})

test_that("plot summary check fails on unregistered, lost surveys and impossible values", {
  p <- veg_plot_summary(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    vegplots = sum_vegplots(),
    flags = sum_flags()
  )
  chk <- function(p, vegplots = sum_vegplots()) {
    veg_check_plot_summary(
      summary = p,
      vegplots = vegplots,
      survey = sum_survey(),
      quadrat = sum_quadrat()
    )
  }
  expect_error(chk(p = p[-3, ]), "differ")
  lost <- p
  lost$n_surveys[1] <- 1L
  expect_error(chk(p = lost), "surveys")
  lost <- p
  lost$n_quadrats[1] <- 1L
  expect_error(chk(p = lost), "quadrats")
  ghost <- p
  ghost$n_quadrats[3] <- 1L
  ghost$n_quadrats[1] <- 2L
  expect_error(chk(p = ghost), "without surveys")
  mean_high <- p
  mean_high$mean_quadrat_richness[1] <- 50
  expect_error(chk(p = mean_high), "mean quadrat richness")
})

test_that("survey and plot summaries reconcile, and a mismatch is caught", {
  s <- veg_survey_summary(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    flags = sum_flags()
  )
  p <- veg_plot_summary(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    vegplots = sum_vegplots(),
    flags = sum_flags()
  )
  expect_no_error(veg_check_summaries_reconcile(
    survey_summary = s,
    plot_summary = p
  ))
  p2 <- p
  p2$n_error[1] <- 5L
  expect_error(
    veg_check_summaries_reconcile(survey_summary = s, plot_summary = p2),
    "n_error"
  )
  s2 <- s
  s2$richness[1] <- 10L
  expect_error(
    veg_check_summaries_reconcile(survey_summary = s2, plot_summary = p),
    "more taxa"
  )
  p3 <- p
  p3$n_surveys[1] <- 1L
  expect_error(
    veg_check_summaries_reconcile(survey_summary = s, plot_summary = p3),
    "number of surveys"
  )
})

test_that("richness never exceeds the distinct names", {
  s <- veg_survey_summary(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    flags = sum_flags()
  )
  p <- veg_plot_summary(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    vegplots = sum_vegplots(),
    flags = sum_flags()
  )
  expect_equal(
    veg_check_richness_bound(
      survey_summary = s,
      plot_summary = p,
      n_names = 2L
    ),
    2L
  )
  expect_error(
    veg_check_richness_bound(
      survey_summary = s,
      plot_summary = p,
      n_names = 1L
    ),
    "exceeds"
  )
})

test_that("sensitivity version is a filtered view that loses exactly the excluded records", {
  ex <- veg_exclusions(
    flags = sum_flags(),
    survey = sum_survey(),
    quadrat = sum_quadrat()
  )
  kept <- veg_apply_exclusions(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    exclusions = ex
  )
  expect_equal(kept$survey$KEY, c("s1", "s3"))
  expect_equal(kept$quadrat$KEY, c("q1", "q4"))
  expect_false(is.element("q2", kept$records$quadrat_key))
  expect_no_error(veg_check_no_lost_records(
    quadrat_all = sum_quadrat(),
    quadrat_sens = kept$quadrat,
    survey_all = sum_survey(),
    survey_sens = kept$survey,
    exclusions = ex
  ))
  expect_error(
    veg_check_no_lost_records(
      quadrat_all = sum_quadrat(),
      quadrat_sens = sum_quadrat()[1:3, ],
      survey_all = sum_survey(),
      survey_sens = kept$survey,
      exclusions = ex
    ),
    "quadrats"
  )
  expect_error(
    veg_check_no_lost_records(
      quadrat_all = sum_quadrat(),
      quadrat_sens = kept$quadrat,
      survey_all = sum_survey(),
      survey_sens = sum_survey(),
      exclusions = ex
    ),
    "surveys"
  )
  # The staged tables are untouched
  expect_equal(nrow(sum_quadrat()), 4)
})

test_that("totals and the plot shift describe the two versions", {
  ex <- veg_exclusions(
    flags = sum_flags(),
    survey = sum_survey(),
    quadrat = sum_quadrat()
  )
  kept <- veg_apply_exclusions(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    exclusions = ex
  )
  version <- function(survey, quadrat, records, label) {
    s <- veg_survey_summary(
      survey = survey,
      quadrat = quadrat,
      records = records,
      flags = sum_flags()
    )
    p <- veg_plot_summary(
      survey = survey,
      quadrat = quadrat,
      records = records,
      vegplots = sum_vegplots(),
      flags = sum_flags()
    )
    list(
      p = p,
      totals = veg_totals(
        version = label,
        survey_summary = s,
        plot_summary = p,
        quadrat = quadrat,
        records = records,
        flags = sum_flags()
      )
    )
  }
  a <- version(
    survey = sum_survey(),
    quadrat = sum_quadrat(),
    records = sum_records(),
    label = "accepted"
  )
  e <- version(
    survey = kept$survey,
    quadrat = kept$quadrat,
    records = kept$records,
    label = "excluding_errors"
  )
  expect_equal(a$totals$n_surveys, 3L)
  expect_equal(e$totals$n_surveys, 2L)
  expect_equal(a$totals$richness_all_plots, 2L)
  expect_equal(e$totals$richness_all_plots, 1L)
  expect_equal(a$totals$n_plots_surveyed, 2L)
  expect_equal(a$totals$n_flags_error, 1L)
  shift <- veg_plot_shift(plot_all = a$p, plot_sens = e$p)
  expect_equal(shift$plot_name, c("A", "B"))
  expect_equal(shift$gamma_richness_change[1], -1)
  expect_equal(shift$n_quadrats_change, c(-2, 0))
  expect_error(
    veg_plot_shift(plot_all = a$p, plot_sens = e$p[-1, ]),
    "must have a match"
  )
})

test_that("severity counts add the severities that are missing, also for no flags", {
  one <- veg_flag_severity_counts(
    flags = tibble(severity = "warning", survey_key = "s1"),
    by = "survey_key"
  )
  expect_equal(one$n_warning, 1L)
  expect_equal(c(one$n_error, one$n_info), c(0L, 0L))
  none <- veg_flag_severity_counts(
    flags = tibble(severity = character(), survey_key = character()),
    by = "survey_key"
  )
  expect_equal(nrow(none), 0L)
  expect_named(none, c("survey_key", "n_error", "n_warning", "n_info"))
})

test_that("a surveyed plot whose quadrats are all excluded has zero quadrats and no means", {
  quadrat <- sum_quadrat()[sum_quadrat()$KEY != "q4", ]
  records <- sum_records()[sum_records()$quadrat_key != "q4", ]
  plot <- veg_plot_summary(
    survey = sum_survey(),
    quadrat = quadrat,
    records = records,
    vegplots = sum_vegplots(),
    flags = sum_flags()
  )
  b <- plot[plot$plot_name == "B", ]
  expect_true(b$surveyed)
  expect_equal(c(b$n_quadrats, b$gamma_richness), c(0L, 0L))
  expect_true(all(is.na(b$mean_quadrat_richness)))
})

test_that("a survey without a plot name is refused", {
  survey <- sum_survey()
  survey$`plot_selection-plot_name`[3] <- NA_character_
  expect_error(
    veg_plot_summary(
      survey = survey,
      quadrat = sum_quadrat(),
      records = sum_records(),
      vegplots = sum_vegplots(),
      flags = sum_flags()
    ),
    "not registered"
  )
})
