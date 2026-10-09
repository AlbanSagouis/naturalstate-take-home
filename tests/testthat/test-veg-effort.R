# Tests for R/functions/veg_effort.R and veg_check_effort (issue #9)

# A plot of 20 quadrats with 6 taxa; the last taxon is seen in one quadrat only
effort_matrix <- function() {
  m <- matrix(data = 0L, nrow = 6, ncol = 20)
  m[1, ] <- 1L
  m[2, 1:15] <- 1L
  m[3, 1:10] <- 1L
  m[4, 1:6] <- 1L
  m[5, 1:3] <- 1L
  m[6, 1] <- 1L
  dimnames(m) <- list(paste0("T", 1:6), paste0("q", 1:20))
  m
}

test_that("presence matrices keep empty quadrats and one matrix per plot", {
  mats <- veg_presence_matrices(
    quadrat = sum_quadrat(),
    survey = sum_survey(),
    records = sum_records()
  )
  expect_named(mats, c("A", "B"))
  # Plot A has q1, q2 (s1) and q3 (s2); q3 holds Alpha_beta, q1 and q2 too
  expect_equal(dim(mats$A), c(2L, 3L))
  expect_equal(unname(mats$A["Alpha_beta", ]), c(1L, 1L, 1L))
  # Plot B has q4 only, which holds an unknown label: no identified taxon, one empty column
  expect_equal(dim(mats$B), c(0L, 1L))
  expect_equal(colnames(mats$B), "q4")
})

test_that("an accumulation curve rises to the observed richness and is reproducible", {
  m <- effort_matrix()
  a <- veg_accumulation_curve(m = m, permutations = 20, seed = 1)
  b <- veg_accumulation_curve(m = m, permutations = 20, seed = 1)
  expect_equal(a, b)
  expect_equal(a$n_quadrats, 1:20)
  expect_false(is.unsorted(a$richness))
  expect_equal(a$richness[20], 6)
  expect_equal(a$sd[20], 0)
  # the curve does not disturb the session's random numbers
  set.seed(42)
  expected <- runif(1)
  set.seed(42)
  veg_accumulation_curve(m = m, permutations = 5, seed = 1)
  expect_equal(runif(1), expected)
})

test_that("a plot without taxa gets a flat zero curve instead of an error", {
  m <- matrix(
    data = 0L,
    nrow = 0,
    ncol = 4,
    dimnames = list(NULL, paste0("q", 1:4))
  )
  out <- veg_accumulation_curve(m = m, permutations = 5, seed = 1)
  expect_equal(out$richness, rep(x = 0, times = 4))
  expect_error(
    veg_accumulation_curve(m = 1:3, permutations = 5, seed = 1),
    "matrix"
  )
})

test_that("Chao2 and coverage come from iNEXT and never fail silently", {
  ok <- veg_inext_plot(m = effort_matrix())
  expect_equal(ok$estimate_status, "ok")
  expect_equal(ok$observed_richness, 6)
  expect_gte(ok$estimated_richness, 6)
  expect_true(ok$sample_coverage > 0 && ok$sample_coverage <= 1)
  none <- veg_inext_plot(
    m = matrix(
      data = 0L,
      nrow = 0,
      ncol = 3,
      dimnames = list(NULL, paste0("q", 1:3))
    )
  )
  expect_equal(none$estimate_status, "no_taxa")
  expect_true(is.na(none$estimated_richness))
})

test_that("the effort table counts missing quadrats and applies the asymptote rule", {
  m <- effort_matrix()
  short <- m[, 1:12]
  mats <- list(complete = m, short = short)
  curves <- veg_accumulation_curves(
    matrices = mats,
    permutations = 10,
    seed = 1
  )
  strict <- veg_effort_table(matrices = mats, curves = curves)
  expect_equal(strict$quadrats_short, c(0, 8))
  expect_equal(strict$n_quadrats, c(20, 12))
  expect_equal(
    strict$completeness,
    strict$observed_richness / strict$estimated_richness
  )
  # the rule is in the config: with no thresholds every estimated plot approaches an asymptote
  open <- veg_effort_table(
    matrices = mats,
    curves = curves,
    config = modifyList(
      veg_config,
      list(completeness_min = 0, coverage_min = 0)
    )
  )
  expect_true(all(open$approaches_asymptote))
  # and with impossible thresholds none does
  closed <- veg_effort_table(
    matrices = mats,
    curves = curves,
    config = modifyList(
      veg_config,
      list(completeness_min = 1.1, coverage_min = 1.1)
    )
  )
  expect_false(any(closed$approaches_asymptote))
  # a plot without estimate is never classified as approaching one
  empty <- matrix(
    data = 0L,
    nrow = 0,
    ncol = 20,
    dimnames = list(NULL, paste0("q", 1:20))
  )
  mixed <- veg_effort_table(
    matrices = list(empty = empty),
    curves = veg_accumulation_curves(
      matrices = list(empty = empty),
      permutations = 5,
      seed = 1
    )
  )
  expect_true(is.na(mixed$approaches_asymptote))
})

test_that("the accumulation figure is a ggplot with one line per plot", {
  mats <- list(a = effort_matrix(), b = effort_matrix()[, 1:12])
  curves <- veg_accumulation_curves(matrices = mats, permutations = 5, seed = 1)
  effort <- veg_effort_table(matrices = mats, curves = curves)
  fig <- veg_plot_accumulation(curves = curves, effort = effort)
  expect_s3_class(fig, "ggplot")
  expect_equal(dplyr::n_distinct(fig$data$plot_name), 2)
})

test_that("the effort check accepts a coherent table and refuses impossible ones", {
  plot_summary <- tibble(
    plot_name = c("a", "b"),
    surveyed = c(TRUE, TRUE),
    n_quadrats = c(20L, 12L)
  )
  mats <- list(a = effort_matrix(), b = effort_matrix()[, 1:12])
  curves <- veg_accumulation_curves(matrices = mats, permutations = 5, seed = 1)
  effort <- veg_effort_table(matrices = mats, curves = curves)
  expect_no_error(veg_check_effort(
    effort = effort,
    plot_summary = plot_summary
  ))
  expect_error(
    veg_check_effort(effort = effort[1, ], plot_summary = plot_summary),
    "plots in the effort table"
  )
  wrong_count <- effort
  wrong_count$n_quadrats[2] <- 11L
  expect_error(
    veg_check_effort(effort = wrong_count, plot_summary = plot_summary),
    "differ from the plot summary"
  )
  below <- effort
  below$estimated_richness[1] <- 1
  expect_error(veg_check_effort(effort = below, plot_summary = plot_summary))
  bad_share <- effort
  bad_share$sample_coverage[1] <- 1.2
  expect_error(
    veg_check_effort(effort = bad_share, plot_summary = plot_summary),
    "sample_coverage"
  )
})
