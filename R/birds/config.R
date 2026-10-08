# Single place for every analytical rule value in the BirdNET part.
# Change a value here, rerun scripts 01 and 02, nothing else needs editing.
# Run all scripts from the project root (here::here() finds it).

birds_config <- list(
  # Decision rule: the smaller of the two outcome groups (wrong or right clips)
  # needs at least this many clips. Deliberately safe; may be relaxed if the
  # cost of expert validation time makes it unreasonable.
  min_smaller_group = 30L,
  # Wood & Kahl: threshold at which precision reaches this level
  target_precision = 0.99,
  # Scores of exactly 1 are set to this before the logit
  clamp_max = 0.9999,
  # Bootstrap on the threshold: reported as uncertainty, not a gate
  n_boot = 2000L,
  ci_level = 0.95,
  seed = 20261008L,
  # Sensitivity grids
  min_smaller_group_sensitivity = c(5L, 10L, 30L),
  target_sensitivity = c(0.90, 0.95, 0.99, 0.995),
  clamp_sensitivity = c(0.999, 0.9999, 0.99999),
  # One theme for every figure in the BirdNET part
  theme = ggplot2::theme_light(base_size = 11),
  # Link step: recordings are hourly, so snap start times to the hour
  snap_units = "hours",
  # Calibration check: quantile bands below the species threshold (a top band
  # at or above the threshold is added on top of these)
  n_calibration_bands = 5L,
  paths = list(
    predictions = here::here("data", "raw", "birds", "birdnet_predictions.csv"),
    validations = here::here("data", "raw", "birds", "validation_results.csv"),
    linked = here::here("data", "processed", "birds_validations_linked.csv"),
    link_diagnostics = here::here(
      "data",
      "processed",
      "birds_link_diagnostics.csv"
    ),
    evidence = here::here("data", "processed", "birds_threshold_evidence.csv"),
    sensitivity = here::here(
      "data",
      "processed",
      "birds_threshold_sensitivity.csv"
    ),
    min_group_sensitivity = here::here(
      "data",
      "processed",
      "birds_min_group_sensitivity.csv"
    ),
    figure = here::here("figures", "birds_threshold_fits.png"),
    aic = here::here("data", "processed", "birds_aic.csv"),
    coverage = here::here("data", "processed", "birds_covariate_coverage.csv"),
    leave_device_out = here::here(
      "data",
      "processed",
      "birds_leave_device_out.csv"
    ),
    device_bootstrap = here::here(
      "data",
      "processed",
      "birds_device_bootstrap.csv"
    ),
    daypart = here::here("data", "processed", "birds_daypart.csv"),
    figure_device = here::here("figures", "birds_device_effects.png"),
    calibration = here::here("data", "processed", "birds_calibration.csv"),
    figure_calibration = here::here("figures", "birds_calibration.png")
  )
)

# Load the helper functions
invisible(lapply(
  X = fs::dir_ls(path = here::here("R", "functions"), regexp = "birds_.*\\.R$"),
  FUN = source
))
