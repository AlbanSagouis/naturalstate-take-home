# Sampling effort (issue #9; reasons in rulebook_vegetation.md): is 20 quadrats enough to describe a plot?
# Only presence/absence per 1 m x 1 m quadrat exists, so every estimate here is
# incidence-based (quadrats are the sampling units). Identified taxa only: the
# provisional unknowns are not stable units (see veg_summaries.R).

#' Species-by-quadrat presence matrices, one per plot
#'
#' Every quadrat of the plot is a column, also quadrats without any identified
#' taxon (an empty column is information about effort, not missing data).
#'
#' @param quadrat Staged quadrat table (KEY, PARENT_KEY), already filtered.
#' @param survey Staged survey table (KEY, plot name).
#' @param records Output of veg_record_taxa(), filtered the same way.
#' @param include_unknowns Count each provisional unknown label as a taxon (upper bound).
#' @return Named list (names are plot names) of integer 0/1 matrices.
veg_presence_matrices <- function(
  quadrat,
  survey,
  records,
  include_unknowns = FALSE
) {
  checkmate::assert_flag(x = include_unknowns)
  quadrat_plot <- quadrat |>
    select(quadrat_key = KEY, survey_key = PARENT_KEY) |>
    inner_join(
      y = select(
        .data = survey,
        survey_key = KEY,
        plot_name = `plot_selection-plot_name`
      ),
      by = "survey_key",
      relationship = "many-to-one",
      unmatched = c(x = "error", y = "drop")
    )
  # With include_unknowns every provisional label counts as a taxon of its own (an upper
  # bound: a label can repeat a named taxon)
  if (include_unknowns) {
    records <- mutate(.data = records, taxon = coalesce(taxon, unknown_label))
  }
  present <- records |>
    filter(!is.na(taxon)) |>
    distinct(quadrat_key, taxon)
  plots <- sort(unique(quadrat_plot$plot_name))
  out <- lapply(X = plots, FUN = function(plot) {
    keys <- quadrat_plot$quadrat_key[quadrat_plot$plot_name == plot]
    here <- present[is.element(el = present$quadrat_key, set = keys), ]
    taxa <- sort(unique(here$taxon))
    m <- matrix(
      data = 0L,
      nrow = length(taxa),
      ncol = length(keys),
      dimnames = list(taxa, keys)
    )
    m[cbind(
      match(x = here$taxon, table = taxa),
      match(x = here$quadrat_key, table = keys)
    )] <- 1L
    m
  })
  stats::setNames(object = out, nm = plots)
}

#' Random species accumulation curve of one plot (vegan::specaccum)
#'
#' @return Tibble: n_quadrats, richness (mean over orderings), sd.
veg_accumulation_curve <- function(m, permutations, seed) {
  checkmate::assert_matrix(x = m)
  checkmate::assert_count(x = permutations, positive = TRUE)
  checkmate::assert_count(x = seed)
  # specaccum fails on a plot without taxa: the curve is flat at zero
  if (nrow(m) == 0) {
    return(tibble(n_quadrats = seq_len(ncol(m)), richness = 0, sd = 0))
  }
  # The order of quadrats is random on purpose; a fixed seed keeps the curve reproducible and
  # with_seed leaves the session's random numbers untouched
  curve <- withr::with_seed(
    seed = seed,
    code = vegan::specaccum(
      comm = t(m),
      method = "random",
      permutations = permutations
    )
  )
  tibble(n_quadrats = curve$sites, richness = curve$richness, sd = curve$sd)
}

#' Asymptotic richness and sample coverage of one plot (iNEXT, incidence_raw)
#'
#' Never fails silently: a plot where iNEXT cannot estimate gets
#' `estimate_status = "failed"` or "no_taxa" with the reason, and NA estimates.
#' Warnings from iNEXT are kept in `estimate_note`.
#'
#' @param m Presence matrix of one plot (taxa x quadrats).
#' @return One-row tibble: observed_richness, estimated_richness (Chao2),
#'   estimated_lcl, estimated_ucl, sample_coverage, estimate_status, estimate_note.
veg_inext_plot <- function(m) {
  checkmate::assert_matrix(x = m)
  observed <- nrow(m)
  empty <- tibble(
    observed_richness = observed,
    estimated_richness = NA_real_,
    estimated_lcl = NA_real_,
    estimated_ucl = NA_real_,
    sample_coverage = NA_real_,
    estimate_status = "no_taxa",
    estimate_note = "no identified taxon in any quadrat"
  )
  if (observed == 0) {
    return(empty)
  }
  storage.mode(m) <- "integer"
  notes <- character()
  result <- tryCatch(
    expr = withCallingHandlers(
      expr = {
        info <- iNEXT::DataInfo(x = list(plot = m), datatype = "incidence_raw")
        chao <- iNEXT::ChaoRichness(x = m, datatype = "incidence_raw")
        list(info = info, chao = chao)
      },
      warning = function(w) {
        notes <<- c(notes, conditionMessage(w))
        invokeRestart(r = "muffleWarning")
      }
    ),
    error = function(e) e
  )
  if (inherits(x = result, what = "error")) {
    return(mutate(
      .data = empty,
      estimate_status = "failed",
      estimate_note = conditionMessage(result)
    ))
  }
  tibble(
    observed_richness = observed,
    estimated_richness = result$chao$Estimator[[1]],
    estimated_lcl = result$chao[["95% Lower"]][[1]],
    estimated_ucl = result$chao[["95% Upper"]][[1]],
    sample_coverage = result$info$SC[[1]],
    estimate_status = "ok",
    estimate_note = paste(unique(notes), collapse = "; ")
  )
}

#' Per-plot sampling effort and completeness table
#'
#' The asymptote rule is stated in the config: a plot "approaches an asymptote"
#' when observed richness is at least `completeness_min` of the Chao2 estimate
#' and sample coverage is at least `coverage_min`. A plot without an estimate is
#' never classified as approaching one (NA).
#'
#' @param matrices Output of veg_presence_matrices().
#' @param curves Tibble of accumulation curves (plot_name, n_quadrats, richness).
veg_effort_table <- function(matrices, curves, config = veg_config) {
  checkmate::assert_list(x = matrices, names = "unique", min.len = 1)
  tail_n <- config$accumulation_tail_quadrats
  rows <- lapply(X = names(matrices), FUN = function(plot) {
    inext <- veg_inext_plot(m = matrices[[plot]])
    curve <- curves[curves$plot_name == plot, ]
    n <- ncol(matrices[[plot]])
    gain <- if (n > tail_n) {
      curve$richness[curve$n_quadrats == n] -
        curve$richness[curve$n_quadrats == n - tail_n]
    } else {
      NA_real_
    }
    bind_cols(
      tibble(
        plot_name = plot,
        n_quadrats = n,
        quadrats_required = config$expected_quadrats_per_plot,
        quadrats_short = config$expected_quadrats_per_plot - n
      ),
      inext,
      tibble(gain_last_quadrats = gain)
    )
  })
  bind_rows(rows) |>
    mutate(
      completeness = observed_richness / estimated_richness,
      approaches_asymptote = completeness >= config$completeness_min &
        sample_coverage >= config$coverage_min
    ) |>
    select(
      plot_name,
      n_quadrats,
      quadrats_required,
      quadrats_short,
      observed_richness,
      estimated_richness,
      estimated_lcl,
      estimated_ucl,
      sample_coverage,
      completeness,
      gain_last_quadrats,
      approaches_asymptote,
      estimate_status,
      estimate_note
    )
}

#' Accumulation curves for all plots, one tibble
veg_accumulation_curves <- function(matrices, permutations, seed) {
  curves <- lapply(X = names(matrices), FUN = function(plot) {
    veg_accumulation_curve(
      m = matrices[[plot]],
      permutations = permutations,
      seed = seed
    ) |>
      mutate(plot_name = plot, .before = 1)
  })
  bind_rows(curves)
}

#' Figure: accumulation curves of all plots in one panel
#'
#' Lines are coloured by whether the plot approaches an asymptote, so the plots
#' still far from one stand out. The dashed line is the 20 quadrats of the SOP.
veg_plot_accumulation <- function(curves, effort, config = veg_config) {
  data <- left_join(
    x = curves,
    y = select(.data = effort, plot_name, approaches_asymptote),
    by = "plot_name",
    relationship = "many-to-one",
    unmatched = "error"
  ) |>
    mutate(
      group = case_when(
        is.na(approaches_asymptote) ~ "no estimate",
        approaches_asymptote ~ "approaches an asymptote",
        .default = "does not"
      )
    )
  ggplot2::ggplot(
    data = data,
    mapping = ggplot2::aes(
      x = n_quadrats,
      y = richness,
      group = plot_name,
      colour = group
    )
  ) +
    ggplot2::geom_vline(
      xintercept = config$expected_quadrats_per_plot,
      linetype = "dashed",
      colour = "grey50"
    ) +
    ggplot2::geom_line(linewidth = 0.5, alpha = 0.8) +
    ggplot2::scale_colour_manual(
      values = c(
        "approaches an asymptote" = config$brand[["green"]],
        "does not" = config$brand[["navy"]],
        "no estimate" = "grey50"
      )
    ) +
    ggplot2::labs(
      x = "Quadrats sampled (random order, mean of permutations)",
      y = "Identified taxa",
      colour = NULL
    ) +
    config$theme +
    ggplot2::theme(legend.position = "bottom")
}
