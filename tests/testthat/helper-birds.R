# Load the BirdNET helper functions for the tests.
invisible(lapply(
  X = fs::dir_ls(path = here::here("R", "functions"), regexp = "birds_.*\\.R$"),
  FUN = source
))

# Synthetic data: truth follows plogis(-3 + 6 * qlogis(confidence)) in expectation
make_synthetic <- function(n = 600, seed = 42) {
  set.seed(seed = seed)
  confidence <- runif(n = n, min = 0.05, max = 0.995)
  outcome <- rbinom(
    n = n,
    size = 1,
    prob = plogis(q = -3 + 6 * qlogis(p = confidence))
  )
  list(confidence = confidence, outcome = outcome)
}
