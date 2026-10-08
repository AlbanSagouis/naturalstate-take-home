# Precision of validated clips, with an interval.

#' Precision with Clopper-Pearson interval
#'
#' @param outcome 0/1 vector of validated clips (1 = true positive).
#' @return One-row tibble: n, n_pos, precision, cp_lower, cp_upper, and
#'   rule3_lower. rule3_lower is 1 - 3/n and only filled when there are zero
#'   errors: the rule-of-three 95% lower bound on precision.
precision_summary <- function(outcome) {
  checkmate::assert_integerish(
    x = outcome,
    lower = 0,
    upper = 1,
    any.missing = FALSE
  )
  n <- length(outcome)
  n_pos <- sum(outcome)
  if (n == 0) {
    return(tibble::tibble(
      n = 0L,
      n_pos = 0L,
      precision = NA_real_,
      cp_lower = NA_real_,
      cp_upper = NA_real_,
      rule3_lower = NA_real_
    ))
  }
  ci <- binom.test(x = n_pos, n = n)$conf.int
  tibble::tibble(
    n = n,
    n_pos = n_pos,
    precision = n_pos / n,
    cp_lower = ci[[1]],
    cp_upper = ci[[2]],
    rule3_lower = if (n_pos == n) 1 - 3 / n else NA_real_
  )
}
