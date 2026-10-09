# Tiny synthetic tables for the summary tests (issue #9).
# Plots: A (surveys s1 and s2, s2 rejected), B (s3), C (registered, not surveyed).
# Taxa: Alpha_beta in q1, q2, q3; Gamma_delta in q2; herb_001 (unknown) in q1 and q4.

sum_survey <- function() {
  tibble(
    KEY = c("s1", "s2", "s3"),
    ReviewState = c(NA, "rejected", NA),
    `plot_selection-plot_name` = c("A", "A", "B"),
    `plot_selection-get_plot_status` = c("primary", "primary", "backup"),
    `survey_begin-start_time` = c(
      "2026-05-26T09:00:00.000+02:00",
      "2026-05-27T09:00:00.000+02:00",
      "2026-05-28T09:00:00.000+02:00"
    ),
    `survey_end-end_time` = c(
      "2026-05-26T09:30:00.000+02:00",
      "2026-05-27T10:00:00.000+02:00",
      "2026-05-28T09:45:00.000+02:00"
    ),
    SubmissionDate = c(
      "2026-05-26T10:00:00.000Z",
      "2026-05-27T10:00:00.000Z",
      "2026-05-28T10:00:00.000Z"
    ),
    recorder_choice_name = c("Ann", "Ann", "Bo")
  )
}

sum_quadrat <- function() {
  tibble(
    KEY = c("q1", "q2", "q3", "q4"),
    PARENT_KEY = c("s1", "s1", "s2", "s3")
  )
}

sum_species_long <- function() {
  tibble(
    source = c(
      "selected_list",
      "additional_repeat",
      "selected_list",
      "selected_list",
      "selected_list",
      "additional_repeat"
    ),
    survey_key = c("s1", "s1", "s1", "s1", "s2", "s3"),
    quadrat_key = c("q1", "q1", "q2", "q2", "q3", "q4"),
    species_name = c(
      "Alpha beta",
      "herb_001",
      "Alpha beta",
      "Gamma delta",
      "Alpha beta",
      "herb_001"
    )
  )
}

sum_vegplots <- function() {
  tibble(
    plot_name = c("A", "B", "C"),
    plot_status = c("primary", "backup", "primary"),
    is_viable = c("yes", "yes", "no")
  )
}

# One warning on s1 and one error on quadrat q2
sum_flags <- function() {
  tibble(
    severity = c("warning", "error", "info"),
    survey_key = c("s1", "s1", "s3"),
    quadrat_key = c(NA, "q2", NA),
    plot_name = c("A", "A", "B")
  )
}

sum_records <- function() veg_record_taxa(species_long = sum_species_long())
