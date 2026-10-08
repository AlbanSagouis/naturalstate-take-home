# 03: robustness of the species thresholds to model form and to recorder /
# time-of-day structure in the validation sample.
# Reads data/processed/birds_validations_linked.csv (script 01) and
# data/processed/birds_threshold_evidence.csv (script 02, for the clip bootstrap).
# Run from the project root: Rscript R/birds/03_robustness_checks.R

library(dplyr)
library(readr)
library(ggplot2)
library(checkmate)

source(file = here::here("R", "birds", "config.R"))
cfg <- birds_config
paths <- cfg$paths

validations <- read_csv(
  file = paths$linked,
  col_types = cols_only(
    commonName = col_character(),
    confidence = col_double(),
    outcome = col_integer(),
    recording = col_character()
  )
)
assert_data_frame(x = validations, any.missing = FALSE, min.rows = 1)
assert_integerish(x = validations$outcome, lower = 0, upper = 1)

# Device, date and hour come from the recording name; week is counted from the
# first validated day so "week 1" means the same thing for every species.
validations <- validations |>
  bind_cols(parse_recording(recording = validations$recording)) |>
  mutate(
    hour_block = hour_block(hour = hour),
    week = as.integer(floor(x = as.numeric(date - min(date)) / 7)) + 1L
  )
assert_false(x = anyNA(validations$device))

species_list <- sort(unique(validations$commonName))
# A species is "fittable" for the covariate checks when both classes reach the
# smallest sensitivity cut (5): below that a refit per subset is meaningless.
n_by_species <- validations |>
  summarise(
    n_neg = sum(outcome == 0),
    n_pos = sum(outcome == 1),
    .by = commonName
  )
fittable <- n_by_species |>
  filter(
    n_neg >= min(cfg$min_smaller_group_sensitivity),
    n_pos >= min(cfg$min_smaller_group_sensitivity)
  ) |>
  pull(commonName)
cli::cli_alert_info(
  "Species with a fittable glm for the covariate checks: {paste(fittable, collapse = ', ')}"
)

# ---- 1. AIC: null vs confidence scale vs logit scale ------------------------
aic <- lapply(X = species_list, FUN = function(sp) {
  d <- filter(validations, commonName == sp)
  out <- aic_table(
    confidence = d$confidence,
    outcome = d$outcome,
    clamp_max = cfg$clamp_max
  )
  if (nrow(out) == 0) {
    cli::cli_alert_warning("{sp}: single outcome class, AIC table skipped.")
    return(NULL)
  }
  mutate(out, commonName = sp, n = nrow(d), .before = 1)
}) |>
  bind_rows()
write_csv(x = aic, file = paths$aic)

# ---- 2. Concentration of validated clips ------------------------------------
count_by <- function(d, dimension) {
  d |>
    mutate(level = as.character(.data[[dimension]])) |>
    summarise(
      n_clips = n(),
      n_neg = sum(outcome == 0),
      n_pos = sum(outcome == 1),
      .by = c(commonName, level)
    ) |>
    mutate(dimension = dimension, value = NA_real_, .before = level)
}
concentration_summary <- function(d) {
  neg_by_device <- d |>
    filter(outcome == 0) |>
    count(device, name = "n_neg") |>
    arrange(desc(n_neg))
  total <- sum(neg_by_device$n_neg)
  tibble(
    commonName = d$commonName[[1]],
    dimension = "summary",
    level = c(
      "n_devices",
      "n_devices_with_negatives",
      "share_negatives_top1_device",
      "share_negatives_top2_devices"
    ),
    value = c(
      n_distinct(d$device),
      nrow(neg_by_device),
      if (total > 0) sum(head(neg_by_device$n_neg, 1)) / total else NA_real_,
      if (total > 0) sum(head(neg_by_device$n_neg, 2)) / total else NA_real_
    )
  )
}
coverage <- bind_rows(
  count_by(d = validations, dimension = "device"),
  count_by(d = validations, dimension = "hour_block"),
  count_by(d = validations, dimension = "week"),
  validations |>
    group_split(commonName) |>
    lapply(FUN = concentration_summary) |>
    bind_rows()
) |>
  arrange(commonName, dimension, level)
write_csv(x = coverage, file = paths$coverage)

# Top-2 negative devices per species, reused by the leave-out and the figure
top_neg_devices <- validations |>
  filter(outcome == 0) |>
  count(commonName, device, name = "n_neg") |>
  arrange(commonName, desc(n_neg), device) |>
  slice_head(n = 2, by = commonName)

# ---- 3. Leave-one-device-out ------------------------------------------------
refit_without <- function(d, dropped) {
  keep <- d[!is.element(el = d$device, set = dropped), ]
  label <- if (length(dropped) == 0) {
    "none (all devices)"
  } else {
    paste(dropped, collapse = " + ")
  }
  base <- tibble(
    commonName = d$commonName[[1]],
    dropped = label,
    n = nrow(keep),
    n_neg = sum(keep$outcome == 0),
    n_pos = sum(keep$outcome == 1)
  )
  if (n_distinct(keep$outcome) < 2) {
    return(mutate(
      base,
      threshold = NA_real_,
      in_range = NA,
      note = "single outcome class after dropping, no fit"
    ))
  }
  fit <- fit_threshold(
    confidence = keep$confidence,
    outcome = keep$outcome,
    target = cfg$target_precision,
    clamp_max = cfg$clamp_max
  )
  base |>
    mutate(
      threshold = fit$threshold,
      in_range = !is.na(threshold) &
        threshold >= min(keep$confidence) &
        threshold <= max(keep$confidence),
      note = fit$warning
    )
}
leave_out <- lapply(X = fittable, FUN = function(sp) {
  d <- filter(validations, commonName == sp)
  devices <- sort(unique(d$device))
  top2 <- top_neg_devices |> filter(commonName == sp) |> pull(device)
  scenarios <- c(list(character(0)), as.list(devices), list(top2))
  bind_rows(lapply(X = scenarios, FUN = function(dropped) {
    refit_without(d = d, dropped = dropped)
  }))
}) |>
  bind_rows()
write_csv(x = leave_out, file = paths$leave_device_out)

# ---- 4. Device-level bootstrap vs clip-level bootstrap ----------------------
clip_boot <- read_csv(
  file = paths$evidence,
  col_types = cols_only(
    commonName = col_character(),
    glm_threshold = col_double(),
    boot_lower = col_double(),
    boot_upper = col_double(),
    boot_n_failed = col_integer()
  )
) |>
  mutate(clip_boot_share_failed = boot_n_failed / cfg$n_boot) |>
  select(
    commonName,
    glm_threshold,
    clip_boot_lower = boot_lower,
    clip_boot_upper = boot_upper,
    clip_boot_share_failed
  )

device_boot <- lapply(X = fittable, FUN = function(sp) {
  d <- filter(validations, commonName == sp)
  bootstrap_threshold_device(
    confidence = d$confidence,
    outcome = d$outcome,
    device = d$device,
    n_boot = cfg$n_boot,
    level = cfg$ci_level,
    target = cfg$target_precision,
    clamp_max = cfg$clamp_max,
    seed = cfg$seed
  ) |>
    mutate(commonName = sp, n_devices = n_distinct(d$device), .before = 1)
}) |>
  bind_rows() |>
  # Species without a device bootstrap (single class or too few negatives) are dropped on purpose
  left_join(
    y = clip_boot,
    by = join_by(commonName),
    relationship = "one-to-one",
    unmatched = "drop"
  )
write_csv(x = device_boot, file = paths$device_bootstrap)

# ---- 5. Day-part check ------------------------------------------------------
# Two-level day-parts chosen from the hours actually sampled (see coverage):
# Nightjar is nocturnal: evening 16-23 vs night 0-6.
# Firefinch is diurnal: day 06-17 vs dawn/night (18-05).
# The first level listed is the reference.
daypart_of <- function(sp, hour) {
  if (sp == "Abyssinian Nightjar") {
    return(if_else(hour >= 16, "evening_16_23", "night_00_06"))
  }
  if_else(hour >= 6 & hour <= 17, "day_06_17", "dawn_night_18_05")
}
daypart <- lapply(
  X = intersect(
    x = c("Abyssinian Nightjar", "Red-billed Firefinch"),
    y = fittable
  ),
  FUN = function(sp) {
    d <- filter(validations, commonName == sp)
    dp <- daypart_of(sp = sp, hour = d$hour)
    fit_daypart_threshold(
      confidence = d$confidence,
      outcome = d$outcome,
      daypart = dp,
      target = cfg$target_precision,
      clamp_max = cfg$clamp_max
    ) |>
      mutate(commonName = sp, .before = 1)
  }
) |>
  bind_rows()
write_csv(x = daypart, file = paths$daypart)

# ---- 6. Calibration check ---------------------------------------------------
# Does the fitted logit-scale curve match the observed rate by score band?
calibration <- lapply(X = fittable, FUN = function(sp) {
  d <- filter(validations, commonName == sp)
  out <- calibration_by_band(
    confidence = d$confidence,
    outcome = d$outcome,
    n_bands = cfg$n_calibration_bands,
    target = cfg$target_precision,
    clamp_max = cfg$clamp_max,
    level = cfg$ci_level
  )
  if (nrow(out) == 0) {
    cli::cli_alert_warning("{sp}: calibration skipped.")
    return(NULL)
  }
  mutate(out, commonName = sp, .before = 1)
}) |>
  bind_rows()
write_csv(x = calibration, file = paths$calibration)

# Why this figure: the threshold comes from a smooth S-shaped curve, and a curve
# can look fine in the middle and be wrong where it matters. Here the validated
# clips are grouped into score bands and the share the experts found correct
# (black, with an interval) is set against what the fitted curve predicts (red).
# If the two agree band by band, the model describes the data; if not, the
# threshold read off the curve is not to be trusted. The band sizes are shown,
# because a band with few clips says little. This is a model check, not a
# recorder check.
fig_calibration <- ggplot(
  data = calibration,
  mapping = aes(x = conf_mean)
) +
  geom_abline(slope = 1, intercept = 0, colour = "grey80") +
  geom_errorbar(
    mapping = aes(ymin = ci_lower, ymax = ci_upper),
    width = 0,
    colour = "grey40"
  ) +
  geom_point(mapping = aes(y = observed, size = n, shape = thin)) +
  geom_line(mapping = aes(y = predicted), colour = "firebrick") +
  geom_point(mapping = aes(y = predicted), colour = "firebrick", size = 1.5) +
  scale_shape_manual(
    values = c("FALSE" = 16, "TRUE" = 1),
    labels = c(
      "FALSE" = "band of 10 or more clips",
      "TRUE" = "thin band (under 10 clips)"
    )
  ) +
  facet_wrap(facets = vars(commonName), ncol = 2) +
  labs(
    x = "Mean BirdNET confidence in band",
    y = "Share of clips the experts found correct",
    size = "Clips",
    shape = NULL,
    title = "Calibration: observed rate by score band vs the fitted curve",
    subtitle = "Black: share found correct, with 95% interval. Red: what the fitted curve predicts. Grey line: perfect agreement.",
    caption = paste(
      strwrap(
        x = "A top band at or above the threshold appears only when the threshold lies inside the validated score range.",
        width = 100
      ),
      collapse = "\n"
    )
  ) +
  cfg$theme +
  theme(legend.position = "bottom")
ggsave(
  filename = paths$figure_calibration,
  plot = fig_calibration,
  width = 9,
  height = 4.8,
  dpi = 150
)

# ---- Figure: pooled curve, top-2 negative devices highlighted ---------------
# Why this figure: Wood & Kahl warn that a threshold only holds for the conditions
# it was validated under (recorder hardware, place, season). One pooled curve
# can hide that most of a species' wrong clips come from one or two recorders.
# The recorders holding most of the wrong clips are coloured red. If the red
# clips sat on a different curve from the grey ones, the pooled threshold would
# be an average of two behaviours. What the figure shows for nightjar is that
# the red clips are wrong clips only: those recorders have no right clips, so
# recorder and score cannot be separated in this sample. Firefinch is the
# comparison: its wrong clips are spread over 22 recorders (the top two hold
# about a third), so no recorder dominates. Together they show what to look for
# on every refit, and why the validation request asks for varied recorders.

fig_species <- intersect(
  x = c("Abyssinian Nightjar", "Red-billed Firefinch"),
  y = fittable
)
fig_points <- validations |>
  filter(is.element(el = commonName, set = fig_species)) |>
  left_join(
    y = top_neg_devices |>
      filter(is.element(el = commonName, set = fig_species)) |>
      mutate(group = "two recorders with most wrong clips") |>
      select(commonName, device, group),
    by = join_by(commonName, device),
    relationship = "many-to-one",
    unmatched = "error"
  ) |>
  mutate(group = coalesce(group, "other recorders"))
fig_curves <- read_csv(
  file = paths$evidence,
  col_types = cols_only(
    commonName = col_character(),
    glm_b0 = col_double(),
    glm_b1 = col_double(),
    status = col_character()
  )
) |>
  # No curve for a species without a threshold
  filter(
    is.element(el = commonName, set = fig_species),
    status == "fitted threshold"
  ) |>
  reframe(
    confidence = seq(from = 0.001, to = 0.9999, length.out = 400),
    p_true = plogis(q = glm_b0 + glm_b1 * qlogis(p = confidence)),
    .by = commonName
  )
fig <- ggplot() +
  geom_point(
    data = fig_points,
    mapping = aes(x = confidence, y = outcome, colour = group),
    alpha = 0.5,
    position = position_jitter(width = 0, height = 0.04, seed = 1)
  ) +
  geom_line(
    data = fig_curves,
    mapping = aes(x = confidence, y = p_true),
    linewidth = 0.8
  ) +
  geom_hline(
    yintercept = cfg$target_precision,
    linetype = "dashed",
    colour = "grey40"
  ) +
  scale_colour_manual(
    values = c(
      "two recorders with most wrong clips" = "firebrick",
      "other recorders" = "grey55"
    )
  ) +
  facet_wrap(facets = vars(commonName), ncol = 2) +
  labs(
    x = "BirdNET confidence",
    y = "Probability the prediction is correct",
    colour = NULL,
    title = "Validated clips by recorder, with the fitted curve where a threshold exists",
    subtitle = "Red: the two recorders holding most of the species' wrong clips. Dashed: 0.99 chance of being correct."
  ) +
  cfg$theme +
  theme(legend.position = "bottom")
ggsave(
  filename = paths$figure_device,
  plot = fig,
  width = 9,
  height = 4.5,
  dpi = 150
)

# ---- Console summary --------------------------------------------------------
options(width = 200)
cli::cli_h2("AIC")
print(
  aic |> filter(delta_aic == 0) |> select(commonName, winner = model, aic),
  n = Inf
)
print(aic, n = Inf)
cli::cli_h2("Concentration summary")
print(
  coverage |>
    filter(dimension == "summary") |>
    tidyr::pivot_wider(names_from = level, values_from = value),
  n = Inf
)
cli::cli_h2("Negatives and positives by hour block and week")
print(
  coverage |>
    filter(is.element(el = dimension, set = c("hour_block", "week"))) |>
    select(commonName, dimension, level, n_neg, n_pos),
  n = Inf
)
cli::cli_h2("Leave-one-device-out")
print(leave_out, n = Inf)
cli::cli_h2("Device vs clip bootstrap")
print(device_boot)
cli::cli_h2("Day-part")
print(daypart)
cli::cli_h2("Calibration by score band")
print(
  calibration |>
    mutate(across(.cols = where(is.numeric), .fns = \(x) round(x, 3))),
  n = Inf
)
cli::cli_alert_success(
  "Wrote AIC, coverage, leave-device-out, device bootstrap, day-part, calibration tables and figures."
)
