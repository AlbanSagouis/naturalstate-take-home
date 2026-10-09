# Run the catalogue on the staged tables and build the long flags table.

#' Flags table: the columns every flag has
veg_flag_columns <- c(
  "flag_id",
  "check_id",
  "level",
  "severity",
  "survey_key",
  "quadrat_key",
  "plot_name",
  "survey_date",
  "recorder",
  "value",
  "message",
  "who_can_resolve"
)

#' Stable id of a finding: md5 of check, submission, quadrat and value
#'
#' Same recipe as the SQL runner (NULL as empty text), so the same finding keeps
#' its id across runs and across R and SQL.
veg_flag_id <- function(check_id, survey_key, quadrat_key, value) {
  text <- paste(
    check_id,
    survey_key,
    dplyr::coalesce(quadrat_key, ""),
    dplyr::coalesce(value, ""),
    sep = "|"
  )
  vapply(
    X = text,
    FUN = digest::digest,
    FUN.VALUE = character(1),
    algo = "md5",
    serialize = FALSE,
    USE.NAMES = FALSE
  )
}

#' Run one check from the catalogue; adds `check_id`
veg_run_one_check <- function(id, ctx, catalogue, config = veg_config) {
  fun <- get(x = catalogue$fun[catalogue$id == id], mode = "function")
  out <- fun(ctx = ctx, config = config)
  checkmate::assert_data_frame(x = out, .var.name = paste0("result of ", id))
  checkmate::assert_names(
    x = names(out),
    must.include = c("survey_key", "quadrat_key", "value", "detail")
  )
  dplyr::mutate(
    .data = out,
    check_id = rep_len(x = id, length.out = nrow(out)),
    .before = 1
  )
}

#' Run every check and build the flags table
#'
#' Flags are made unique per check, submission, quadrat and value, and ordered
#' by check, submission order in the export and quadrat number.
#'
#' @param ctx List of staged tables: survey, quadrat, species_long, register,
#'   vegplots, species, species_extra, project_team.
#' @return Tibble with the columns in `veg_flag_columns`.
veg_build_flags <- function(
  ctx,
  catalogue = veg_check_catalogue(),
  config = veg_config
) {
  raised <- dplyr::bind_rows(lapply(
    X = catalogue$id,
    FUN = veg_run_one_check,
    ctx = ctx,
    catalogue = catalogue,
    config = config
  ))
  if (nrow(raised) == 0) {
    return(dplyr::as_tibble(stats::setNames(
      object = lapply(X = veg_flag_columns, FUN = function(x) character()),
      nm = veg_flag_columns
    )))
  }
  survey_info <- dplyr::tibble(
    survey_key = ctx$survey$KEY,
    survey_order = seq_len(nrow(ctx$survey)),
    plot_name = ctx$survey[["plot_selection-plot_name"]],
    survey_date = stringi::stri_sub(
      str = ctx$survey[["survey_begin-start_time"]],
      from = 1,
      length = 10
    ),
    recorder = ctx$survey$recorder_choice_name
  ) |>
    dplyr::distinct(survey_key, .keep_all = TRUE)
  quadrat_info <- dplyr::tibble(
    quadrat_key = ctx$quadrat$KEY,
    quadrat_number = veg_to_numeric(x = ctx$quadrat$quadrat_number)
  ) |>
    dplyr::distinct(quadrat_key, .keep_all = TRUE)
  spec <- dplyr::select(
    .data = catalogue,
    check_id = id,
    level,
    severity,
    message_template,
    who_can_resolve
  )

  raised |>
    dplyr::left_join(
      y = spec,
      by = "check_id",
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    dplyr::left_join(
      y = survey_info,
      by = "survey_key",
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    dplyr::left_join(
      y = quadrat_info,
      by = "quadrat_key",
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    dplyr::distinct(
      check_id,
      survey_key,
      quadrat_key,
      value,
      .keep_all = TRUE
    ) |>
    dplyr::arrange(check_id, survey_order, quadrat_number, value) |>
    dplyr::mutate(
      flag_id = veg_flag_id(
        check_id = check_id,
        survey_key = survey_key,
        quadrat_key = quadrat_key,
        value = value
      ),
      message = veg_fill_template(
        template = message_template,
        values = list(
          plot = plot_name,
          quadrat = quadrat_number,
          value = value,
          detail = detail
        )
      )
    ) |>
    dplyr::select(dplyr::all_of(veg_flag_columns))
}
