# 01: load BirdNET predictions and expert validations, check them, and link
# each validated clip to its prediction row where possible.
# Output: data/processed/birds_validations_linked.csv (+ link diagnostics).
# Run from the project root: Rscript R/birds/01_load_validate.R

library(dplyr)
library(readr)
library(checkmate)

source(file = here::here("R", "birds", "config.R"))
paths <- birds_config$paths

# ---- Load with explicit column types ---------------------------------------
predictions <- read_csv(
  file = paths$predictions,
  col_types = cols_only(
    selection = col_integer(),
    begin_time_s = col_double(),
    end_time_s = col_double(),
    common_name = col_character(),
    species_code = col_character(),
    confidence = col_double(),
    begin_path = col_character()
  )
)
validations <- read_csv(
  file = paths$validations,
  col_types = cols(
    scientificName = col_character(),
    commonName = col_character(),
    vBirdNET = col_character(),
    filename = col_character(),
    confidence = col_double(),
    outcome = col_integer()
  )
)

# ---- Checks: fail loudly, never repair --------------------------------------
assert_data_frame(x = predictions, any.missing = FALSE, min.rows = 1)
assert_data_frame(x = validations, any.missing = FALSE, min.rows = 1)
assert_numeric(x = predictions$confidence, lower = 0, upper = 1)
assert_subset(
  x = unique(validations$commonName),
  choices = unique(predictions$common_name)
)
assert_integerish(x = validations$outcome, lower = 0, upper = 1)
assert_numeric(x = validations$confidence, lower = 0, upper = 1)
assert_true(x = all(validations$confidence > 0))
assert_true(x = dplyr::n_distinct(validations$vBirdNET) == 1)

# Schema, uniqueness, species pairing and BirdNET run threshold (R/functions/)
check_predictions_input(predictions = predictions)
check_validations_input(validations = validations)

# ---- Parse filenames --------------------------------------------------------
validations <- validations |>
  bind_cols(parse_validation_filename(filename = validations$filename))

# The score in the filename and the confidence column must agree
assert_true(
  x = isTRUE(all.equal(
    target = validations$file_confidence,
    current = validations$confidence
  ))
)

# ---- Link validations to predictions ---------------------------------------
# There is no prediction ID in the validation file (see rulebook_birds.md, data issues
# upstream), so we match on species + recording + confidence at 3 decimals.
predictions <- predictions |>
  mutate(
    recording = tools::file_path_sans_ext(basename(begin_path)),
    rec_key = recording_hour_key(
      recording = recording,
      snap_units = birds_config$snap_units
    ),
    milli = confidence_to_milli(confidence = confidence)
  )
validations <- validations |>
  mutate(
    rec_key = recording_hour_key(
      recording = recording,
      snap_units = birds_config$snap_units
    ),
    milli = confidence_to_milli(confidence = confidence)
  )

# Collapse predictions to one row per (species, recording key, milli score) so
# the join cannot multiply validation rows. n_candidates > 1 means ambiguous.
prediction_keys <- predictions |>
  summarise(
    n_candidates = n(),
    selection = first(selection),
    begin_path = first(begin_path),
    begin_time_s = first(begin_time_s),
    .by = c(common_name, rec_key, milli)
  )

linked <- validations |>
  left_join(
    y = prediction_keys,
    by = join_by(commonName == common_name, rec_key, milli),
    relationship = "many-to-one",
    unmatched = "drop"
  ) |>
  mutate(
    link_status = case_when(
      is.na(n_candidates) ~ "unmatched",
      n_candidates == 1L ~ "unique",
      .default = "ambiguous"
    ),
    # Only a unique match identifies one prediction row
    selection = if_else(link_status == "unique", selection, NA_integer_),
    begin_path = if_else(link_status == "unique", begin_path, NA_character_),
    begin_time_s = if_else(link_status == "unique", begin_time_s, NA_real_)
  )
assert_true(x = nrow(linked) == nrow(validations))

# ---- Investigate the unmatched ---------------------------------------------
# Count link outcomes under several matching rules, from naive to final.
link_counts <- function(rule, rec_col, milli_fun) {
  pred_n <- predictions |>
    mutate(m = milli_fun(confidence), r = .data[[rec_col]]) |>
    count(common_name, r, m, name = "n")
  validations |>
    mutate(m = milli_fun(confidence), r = .data[[rec_col]]) |>
    left_join(
      y = pred_n,
      by = join_by(commonName == common_name, r, m),
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    summarise(
      unique = sum(n == 1L, na.rm = TRUE),
      ambiguous = sum(n > 1L, na.rm = TRUE),
      unmatched = sum(is.na(n))
    ) |>
    mutate(rule = rule, .before = 1)
}
truncate_milli <- function(x) as.integer(floor(x * 1000 + 1e-6))
diagnostics <- bind_rows(
  link_counts(
    rule = "exact recording name, rounded score",
    rec_col = "recording",
    milli_fun = confidence_to_milli
  ),
  link_counts(
    rule = "exact recording name, truncated score",
    rec_col = "recording",
    milli_fun = truncate_milli
  ),
  link_counts(
    rule = "hour-snapped recording, truncated score",
    rec_col = "rec_key",
    milli_fun = truncate_milli
  ),
  link_counts(
    rule = "hour-snapped recording, rounded score (final)",
    rec_col = "rec_key",
    milli_fun = confidence_to_milli
  )
)
cli::cli_h2("Link outcomes by matching rule")
print(diagnostics)

n_rec_exact <- sum(is.element(
  el = validations$recording,
  set = predictions$recording
))
n_rec_key <- sum(is.element(
  el = validations$rec_key,
  set = predictions$rec_key
))
seconds <- stringi::stri_sub(str = validations$recording, from = -2, to = -1)
n_offset <- sum(seconds != "00")
cli::cli_alert_info(
  "Validation recording name found verbatim in predictions: {n_rec_exact}/{nrow(validations)}; after hour-snapping: {n_rec_key}/{nrow(validations)}."
)
cli::cli_alert_info(
  "{n_offset} validation recording names have non-zero seconds (predictions always end in 00)."
)

# Residual unmatched: is the species+recording present, with a score within +-0.001?
residual <- linked |>
  filter(link_status == "unmatched") |>
  select(commonName, rec_key, milli, filename)
near <- residual |>
  inner_join(
    y = predictions |> select(common_name, rec_key, pred_milli = milli),
    by = join_by(commonName == common_name, rec_key),
    relationship = "many-to-many",
    unmatched = c("drop", "drop")
  ) |>
  filter(abs(milli - pred_milli) <= 1L) |>
  distinct(filename)
n_residual_key_absent <- sum(
  !is.element(el = residual$rec_key, set = predictions$rec_key)
)
cli::cli_alert_info(
  "Residual unmatched: {nrow(residual)} ({n_residual_key_absent} with recording absent from predictions, {nrow(near)} with a prediction within 0.001 of the score)."
)
diagnostics <- diagnostics |>
  mutate(
    n_validations = nrow(validations),
    residual_unmatched = nrow(residual),
    residual_recording_absent = n_residual_key_absent,
    residual_within_0.001 = nrow(near)
  )

cli::cli_h2("Final link status by species")
print(count(x = linked, commonName, link_status))

# ---- Write -------------------------------------------------------------------
fs::dir_create(path = dirname(paths$linked))
linked |>
  select(
    scientificName,
    commonName,
    vBirdNET,
    filename,
    confidence,
    outcome,
    recording,
    rec_key,
    rank,
    link_status,
    n_candidates,
    selection,
    begin_path,
    begin_time_s
  ) |>
  write_csv(file = paths$linked)
write_csv(x = diagnostics, file = paths$link_diagnostics)
cli::cli_alert_success("Wrote {paths$linked}")
