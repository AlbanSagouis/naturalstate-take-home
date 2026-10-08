# 02: per-species threshold evidence table, sensitivity table and figure.
# Reads data/processed/birds_validations_linked.csv (script 01).
# Run from the project root: Rscript R/birds/02_threshold_evidence.R

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
    scientificName = col_character(),
    commonName = col_character(),
    confidence = col_double(),
    outcome = col_integer()
  )
)
check_linked_input(validations = validations)

# ---- Evidence for one species ----------------------------------------------
add_prefix <- function(df, prefix) {
  stats::setNames(object = df, nm = paste0(prefix, names(df)))
}

species_evidence <- function(d) {
  score <- d$confidence
  y <- d$outcome
  plain <- fit_threshold(
    confidence = score,
    outcome = y,
    target = cfg$target_precision,
    clamp_max = cfg$clamp_max
  )
  boot <- bootstrap_threshold(
    confidence = score,
    outcome = y,
    n_boot = cfg$n_boot,
    level = cfg$ci_level,
    target = cfg$target_precision,
    clamp_max = cfg$clamp_max,
    seed = cfg$seed
  )
  thr <- plain$threshold
  # Precision of the validated clips at or above a cutoff. NA cutoff = no clips.
  precision_at <- function(cutoff) {
    if (is.na(cutoff)) {
      return(precision_summary(outcome = integer(0)))
    }
    precision_summary(outcome = y[score >= cutoff])
  }

  tibble(
    scientificName = d$scientificName[[1]],
    commonName = d$commonName[[1]],
    n_neg = sum(y == 0),
    n_pos = sum(y == 1),
    score_min = min(score),
    score_median = median(score),
    score_max = max(score)
  ) |>
    bind_cols(
      plain |>
        rename(
          glm_b0 = b0,
          glm_b1 = b1,
          glm_threshold = threshold,
          glm_warning = warning
        ),
      boot,
      add_prefix(df = precision_summary(outcome = y), prefix = "prec_all_"),
      add_prefix(df = precision_at(cutoff = thr), prefix = "prec_at_glm_")
    )
}

evidence <- validations |>
  group_split(commonName) |>
  lapply(FUN = species_evidence) |>
  bind_rows()

# ---- Decision rule ----------------------------------------------------------
# Two gates, the same for every species (see threshold_eligibility()). The
# bootstrap share of failed fits is reported next to them, not used as a gate.
eligibility <- threshold_eligibility(
  n_neg = evidence$n_neg,
  n_pos = evidence$n_pos,
  glm_threshold = evidence$glm_threshold,
  score_min = evidence$score_min,
  score_max = evidence$score_max,
  min_smaller_group = cfg$min_smaller_group
)
evidence <- evidence |>
  bind_cols(eligibility) |>
  mutate(
    boot_share_failed = boot_n_failed / cfg$n_boot,
    # The interval is uncertainty only; the cutoff is the plain glm threshold
    labelling_cutoff = if_else(eligible, glm_threshold, NA_real_)
  ) |>
  # A precision at the threshold means nothing for a species without one
  mutate(across(.cols = starts_with("prec_at_glm_"), .fns = \(x) {
    if_else(eligible, x, NA_real_)
  }))

# Sensitivity of who passes to the minimum size of the smaller group
min_group_pass <- lapply(
  X = cfg$min_smaller_group_sensitivity,
  FUN = function(k) {
    passes <- threshold_eligibility(
      n_neg = evidence$n_neg,
      n_pos = evidence$n_pos,
      glm_threshold = evidence$glm_threshold,
      score_min = evidence$score_min,
      score_max = evidence$score_max,
      min_smaller_group = k
    )[["eligible"]]
    tibble(
      min_smaller_group = k,
      n_pass = sum(passes),
      species_pass = paste(evidence$commonName[passes], collapse = ", ")
    )
  }
) |>
  bind_rows()

check_evidence_table(
  evidence = evidence,
  validations = validations,
  n_boot = cfg$n_boot,
  sensitivity = min_group_pass
)

# Sensitivity of the plain-glm threshold to the target precision and clamp
sensitivity_rows <- function(d) {
  targets <- lapply(X = cfg$target_sensitivity, FUN = function(target) {
    fit <- fit_threshold(
      confidence = d$confidence,
      outcome = d$outcome,
      target = target,
      clamp_max = cfg$clamp_max
    )
    tibble(
      parameter = "target_precision",
      value = target,
      glm_threshold = fit$threshold
    )
  })
  clamps <- lapply(X = cfg$clamp_sensitivity, FUN = function(clamp_max) {
    fit <- fit_threshold(
      confidence = d$confidence,
      outcome = d$outcome,
      target = cfg$target_precision,
      clamp_max = clamp_max
    )
    tibble(
      parameter = "clamp_max",
      value = clamp_max,
      glm_threshold = fit$threshold
    )
  })
  bind_rows(targets, clamps) |>
    mutate(commonName = d$commonName[[1]], .before = 1)
}
sensitivity <- validations |>
  group_split(commonName) |>
  lapply(FUN = sensitivity_rows) |>
  bind_rows()

fs::dir_create(path = dirname(paths$evidence))
write_csv(x = evidence, file = paths$evidence)
write_csv(x = sensitivity, file = paths$sensitivity)
write_csv(x = min_group_pass, file = paths$min_group_sensitivity)

# ---- Figure -----------------------------------------------------------------
grid <- seq(from = 0.001, to = 0.9999, length.out = 400)
curves <- evidence |>
  filter(eligible) |>
  reframe(
    confidence = grid,
    p_true = plogis(q = glm_b0 + glm_b1 * qlogis(p = grid)),
    .by = commonName
  )
panel_labels <- evidence |>
  mutate(
    panel = paste0(
      commonName,
      "\n",
      n_neg,
      " wrong / ",
      n_pos,
      " right; threshold ",
      if_else(
        eligible,
        as.character(round(x = glm_threshold, digits = 3)),
        "none"
      )
    ),
    # The threshold line is drawn only for fitted species
    line_at = labelling_cutoff
  ) |>
  select(commonName, panel, line_at)
plot_points <- validations |>
  left_join(
    y = panel_labels,
    by = join_by(commonName),
    relationship = "many-to-one",
    unmatched = "error"
  )
# Only fitted species get a curve; the others show their clips alone, on purpose
plot_curves <- curves |>
  inner_join(
    y = panel_labels,
    by = join_by(commonName),
    relationship = "many-to-one",
    unmatched = c(x = "error", y = "drop")
  )

fig <- ggplot() +
  geom_point(
    data = plot_points,
    mapping = aes(x = confidence, y = outcome),
    alpha = 0.4,
    position = position_jitter(width = 0, height = 0.04, seed = 1)
  ) +
  geom_line(
    data = plot_curves,
    mapping = aes(x = confidence, y = p_true),
    colour = "steelblue",
    linewidth = 0.8
  ) +
  geom_hline(
    yintercept = cfg$target_precision,
    linetype = "dashed",
    colour = "grey40"
  ) +
  geom_vline(
    data = panel_labels,
    mapping = aes(xintercept = line_at),
    colour = "firebrick",
    linewidth = 0.8,
    na.rm = TRUE
  ) +
  scale_x_continuous(limits = c(0, 1)) +
  facet_wrap(facets = vars(panel), ncol = 2) +
  labs(
    x = "BirdNET confidence",
    y = "Probability the prediction is correct",
    title = "Validated clips, with the fitted curve where a threshold exists",
    subtitle = "Dashed: 0.99 chance of being correct. Red line: fitted threshold (fitted species only)."
  ) +
  cfg$theme
ggsave(filename = paths$figure, plot = fig, width = 9, height = 7, dpi = 150)

cli::cli_h2("Evidence")
options(width = 250)
print(
  evidence |>
    select(
      commonName,
      n_neg,
      n_pos,
      smaller_group,
      glm_threshold,
      in_range,
      boot_lower,
      boot_upper,
      boot_share_failed,
      status,
      reason,
      labelling_cutoff
    ),
  n = Inf
)
print(
  evidence |>
    select(
      commonName,
      score_min,
      score_max,
      glm_warning,
      perfect_separation,
      near_separation,
      boot_n_ok,
      boot_n_failed,
      boot_n_warned,
      prec_all_precision,
      prec_at_glm_n,
      prec_at_glm_precision,
      prec_at_glm_cp_lower,
      prec_at_glm_rule3_lower
    )
)
cli::cli_h2("Who passes for each minimum smaller group")
print(min_group_pass)
print(
  sensitivity |>
    tidyr::pivot_wider(
      names_from = c(parameter, value),
      values_from = glm_threshold
    )
)
cli::cli_alert_success("Wrote evidence, sensitivity and figure.")
