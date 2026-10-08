# 04: label every BirdNET prediction as observed / below_threshold /
# no_threshold using the per-species labelling cutoff from script 02.
# Output: outputs/birds/birdnet_predictions_labelled.csv (tracked on purpose):
# the raw prediction file plus observation_status and observation.
# Run from the project root: Rscript R/birds/04_label_observations.R

library(dplyr)
library(readr)
library(checkmate)

source(file = here::here("R", "birds", "config.R"))
paths <- birds_config$paths

# ---- Load with explicit column types (all columns) --------------------------
predictions <- read_csv(
  file = paths$predictions,
  col_types = cols(
    selection = col_integer(),
    view = col_character(),
    channel = col_integer(),
    begin_time_s = col_double(),
    end_time_s = col_double(),
    low_freq_hz = col_double(),
    high_freq_hz = col_double(),
    common_name = col_character(),
    species_code = col_character(),
    confidence = col_double(),
    begin_path = col_character(),
    file_offset_s = col_double(),
    folder = col_character()
  )
)
thresholds <- read_csv(
  file = paths$evidence,
  col_types = cols_only(
    commonName = col_character(),
    status = col_character(),
    labelling_cutoff = col_double()
  )
)

# ---- Checks and labelling ----------------------------------------------------
assert_data_frame(x = predictions, any.missing = FALSE, min.rows = 1)
check_predictions_input(predictions = predictions)
labelled <- label_predictions(
  predictions = predictions,
  thresholds = thresholds
)

allowed <- c("observed", "below_threshold", "no_threshold")
assert_true(x = nrow(labelled) == nrow(predictions))
assert_names(
  x = names(labelled),
  identical.to = c(names(predictions), "observation_status", "observation")
)
assert_subset(x = labelled$observation_status, choices = allowed)
assert_false(x = anyNA(labelled$observation_status))
assert_true(
  x = identical(
    x = is.na(labelled$observation),
    y = labelled$observation_status != "observed"
  )
)
# A species with a missing cutoff may only ever be no_threshold
no_cutoff <- thresholds$commonName[is.na(thresholds$labelling_cutoff)]
assert_true(
  x = all(
    labelled$observation_status[is.element(labelled$common_name, no_cutoff)] ==
      "no_threshold"
  )
)
assert_true(
  x = all(
    labelled$observation_status[!is.element(labelled$common_name, no_cutoff)] !=
      "no_threshold"
  )
)
assert_set_equal(
  x = unique(labelled$common_name),
  y = unique(predictions$common_name)
)

# ---- Report ------------------------------------------------------------------
cli::cli_h2("Observation status by species")
status_counts <- labelled |>
  count(common_name, observation_status) |>
  tidyr::pivot_wider(
    names_from = observation_status,
    values_from = n,
    values_fill = 0L
  )
print(status_counts, n = Inf)
cli::cli_alert_info(
  "{nrow(labelled)} rows labelled: {sum(labelled$observation_status == 'observed')} observed."
)

# ---- Write -------------------------------------------------------------------
fs::dir_create(path = dirname(paths$labelled))
write_csv(x = labelled, file = paths$labelled)
cli::cli_alert_success("Wrote {paths$labelled}")
