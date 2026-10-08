# Single place for every analytical rule value in the BirdNET part.
# Change a value here and rerun the scripts; nothing else needs editing.
# Run all scripts from the project root (here::here() finds it).

birds_config <- list(
  # Link step: recordings are hourly, so snap start times to the hour
  snap_units = "hours",
  paths = list(
    predictions = here::here("data", "raw", "birds", "birdnet_predictions.csv"),
    validations = here::here("data", "raw", "birds", "validation_results.csv"),
    linked = here::here("data", "processed", "birds_validations_linked.csv"),
    link_diagnostics = here::here(
      "data",
      "processed",
      "birds_link_diagnostics.csv"
    )
  )
)

# Load the helper functions
for (f in fs::dir_ls(
  path = here::here("R", "functions"),
  regexp = "birds_.*\\.R$"
)) {
  source(file = f)
}
