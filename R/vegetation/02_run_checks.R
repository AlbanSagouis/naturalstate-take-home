# 02: run every QA/QC check on the staged tables and write the flags.
# The data are never changed: a check raises rows of one long flags table.
# Inputs: data/processed/veg_*.csv (from 01_load_join.R) and the entity lists.
# Run from the project root: Rscript R/vegetation/02_run_checks.R

library(dplyr)

source(file = here::here("R", "vegetation", "config.R"))
paths <- veg_config$paths

# ---- Load -------------------------------------------------------------------
ctx <- list(
  survey = veg_read_csv(path = paths$survey, label = "veg_survey"),
  quadrat = veg_read_csv(path = paths$quadrat, label = "veg_quadrat"),
  species_long = veg_read_csv(
    path = paths$species_long,
    label = "veg_species_long"
  ),
  register = veg_read_odk(table = "register"),
  vegplots = veg_read_entity(name = "vegplots"),
  species = veg_read_entity(name = "species"),
  species_extra = veg_read_entity(name = "species_extra"),
  project_team = veg_read_entity(name = "project_team")
)
ctx_before <- ctx

# ---- Run --------------------------------------------------------------------
catalogue <- veg_check_catalogue()
veg_check_catalogue_valid(catalogue = catalogue)
flags <- veg_build_flags(ctx = ctx, catalogue = catalogue, config = veg_config)
veg_check_flags(flags = flags, catalogue = catalogue)
counts <- veg_flag_counts(flags = flags, catalogue = catalogue)
veg_check_flags_reconcile(flags = flags, catalogue = catalogue, counts = counts)
stopifnot("checks changed their input" = identical(x = ctx, y = ctx_before))

# ---- Report -----------------------------------------------------------------
cli::cli_h1("Flags: {nrow(flags)} from {nrow(catalogue)} checks")
by_severity <- count(x = flags, severity) |>
  arrange(match(x = severity, table = veg_severities))
for (i in seq_len(nrow(by_severity))) {
  cli::cli_alert_info("{by_severity$severity[i]}: {by_severity$n[i]}")
}
fired <- filter(.data = counts, n_flags > 0)
cli::cli_h2("Checks that raised flags ({nrow(fired)} of {nrow(counts)})")
for (i in seq_len(nrow(fired))) {
  cli::cli_alert_warning(
    "{fired$check_id[i]} [{fired$severity[i]}, {fired$level[i]}]: {fired$n_flags[i]}"
  )
}
silent <- counts$check_id[counts$n_flags == 0]
cli::cli_alert_success("No flags from: {paste(silent, collapse = ', ')}")

# ---- Write ------------------------------------------------------------------
fs::dir_create(path = paths$outputs_dir)
readr::write_csv(
  x = select(.data = catalogue, -fun),
  file = paths$catalogue,
  na = ""
)
readr::write_csv(x = flags, file = paths$flags, na = "")
readr::write_csv(x = flags, file = paths$flags_processed, na = "")
readr::write_csv(
  x = counts,
  file = fs::path(veg_processed_dir, "veg_flag_counts.csv"),
  na = ""
)

# ---- Errors and warnings for the data providers -----------------------------
issues <- veg_field_issues(
  flags = flags,
  catalogue = catalogue,
  quadrat = ctx$quadrat,
  rejected_keys = veg_rejected_keys(survey = ctx$survey)
)
readr::write_csv(x = issues, file = paths$field_issues, na = "")
cli::cli_alert_success(
  "Wrote {nrow(flags)} flags and {nrow(issues)} error/warning rows for the field teams to {.path {paths$outputs_dir}}"
)
