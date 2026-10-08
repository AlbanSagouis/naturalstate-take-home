# Load the BirdNET helper functions for the tests.
for (f in fs::dir_ls(
  path = here::here("R", "functions"),
  regexp = "birds_.*\\.R$"
)) {
  source(file = f)
}
