# Checks on the linked validations (input of script 02) and on its evidence table.

#' Check the linked validation table read by script 02
#'
#' @param validations Tibble with scientificName, commonName, confidence, outcome.
#' @return `validations`, invisibly.
check_linked_input <- function(validations) {
  checkmate::assert_names(
    x = names(validations),
    must.include = c("scientificName", "commonName", "confidence", "outcome")
  )
  # Open at 0 (a score of 0 has no logit), closed at 1 (clamped before the fit)
  checkmate::assert_numeric(
    x = validations$confidence,
    lower = 0,
    upper = 1,
    any.missing = FALSE
  )
  if (any(validations$confidence <= 0)) {
    cli::cli_abort("linked validations: confidence must be in (0, 1].")
  }
  checkmate::assert_integerish(
    x = validations$outcome,
    lower = 0,
    upper = 1,
    any.missing = FALSE
  )
  if (anyNA(validations$commonName) || nrow(validations) == 0) {
    cli::cli_abort("linked validations: no clips or missing commonName.")
  }
  assert_one_to_one(data = validations, a = "scientificName", b = "commonName")
  invisible(validations)
}

#' Check the per-species evidence table
#'
#' @param evidence One row per species, as built by script 02.
#' @param validations The linked validations the evidence was built from.
#' @param n_boot Number of bootstrap resamples requested.
#' @param sensitivity Table with min_smaller_group and species_pass (species
#'   names joined by ", "), one row per minimum.
#' @return `evidence`, invisibly.
check_evidence_table <- function(evidence, validations, n_boot, sensitivity) {
  # 1. one row per species
  if (anyDuplicated(evidence$commonName) > 0) {
    cli::cli_abort("evidence: commonName is not unique.")
  }

  # 2. counts agree with the clips that went in
  n_clips <- dplyr::count(x = validations, commonName, name = "n_clips")
  counted <- evidence |>
    dplyr::select(commonName, n_neg, n_pos, score_min, score_max) |>
    dplyr::left_join(
      y = n_clips,
      by = dplyr::join_by(commonName),
      relationship = "one-to-one",
      unmatched = "error"
    )
  if (
    nrow(counted) != nrow(n_clips) ||
      any(counted$n_neg + counted$n_pos != counted$n_clips)
  ) {
    cli::cli_abort(
      "evidence: n_neg + n_pos differs from the number of validated clips."
    )
  }

  # 3. status, cutoff and reason agree in both directions
  fitted <- evidence$status == "fitted threshold"
  if (!identical(fitted, !is.na(evidence$labelling_cutoff))) {
    cli::cli_abort(
      "evidence: status is 'fitted' exactly when labelling_cutoff is set."
    )
  }
  if (!identical(!fitted, !is.na(evidence$reason))) {
    cli::cli_abort(
      "evidence: reason must be set only for no_threshold species."
    )
  }
  if (
    !all(is.element(
      el = evidence$status,
      set = c("fitted threshold", "no_threshold")
    ))
  ) {
    cli::cli_abort("evidence: unknown status value.")
  }

  # 4. a fitted cutoff is interpolated inside the validated range
  cutoff <- counted[fitted, ]
  value <- evidence$labelling_cutoff[fitted]
  if (
    any(
      value <= 0 |
        value >= 1 |
        value <= cutoff$score_min |
        value >= cutoff$score_max
    )
  ) {
    cli::cli_abort(
      "evidence: a fitted cutoff lies outside (score_min, score_max) or (0, 1)."
    )
  }

  # 5. every resample is either ok or failed. Species where no bootstrap ran
  # would have NA in both columns and are skipped.
  ran <- !is.na(evidence$boot_n_ok) & !is.na(evidence$boot_n_failed)
  if (any(evidence$boot_n_ok[ran] + evidence$boot_n_failed[ran] != n_boot)) {
    cli::cli_abort("evidence: boot_n_ok + boot_n_failed differs from n_boot.")
  }

  # 6. a stricter minimum can only remove species
  ordered <- sensitivity[order(sensitivity$min_smaller_group), ]
  passing <- lapply(
    X = ordered$species_pass,
    FUN = function(x) {
      # An empty string means nobody passes
      stringi::stri_split_fixed(str = x, pattern = ", ", omit_empty = TRUE)[[1]]
    }
  )
  for (i in seq_len(length(passing) - 1)) {
    if (!all(is.element(el = passing[[i + 1]], set = passing[[i]]))) {
      cli::cli_abort(
        "sensitivity: a species passes a stricter minimum but not a looser one."
      )
    }
  }
  invisible(evidence)
}
