# Joins for the vegetation tables. Nothing is dropped, modified or multiplied:
# every join keeps all rows of the left table (data errors such as a missing
# lookup row stay visible as NA) and the callers assert the row counts.

#' Split cells holding several ids into one row per id
#'
#' @param data Data frame.
#' @param column Column holding the ids.
#' @param key Column to carry along.
#' @return Tibble with `key` (values of column `key`), `position` (order within the cell) and `id`.
veg_split_ids <- function(data, column, key = "KEY") {
  tokens <- veg_tokens(data = data, column = column, split = TRUE)
  dplyr::tibble(
    key = data[[key]][tokens$row],
    position = stats::ave(x = tokens$row, tokens$row, FUN = seq_along),
    id = tokens$token
  )
}

#' Resolve the ids of a multi-select column to labels
#'
#' Unresolved ids are kept (as the id itself) so that nothing disappears.
#'
#' @param lookup Data frame with `__id` and `column`.
#' @return Character vector, one string per row of `data`, labels joined by "; ".
veg_resolve_multi <- function(data, column, lookup, lookup_column) {
  tokens <- veg_tokens(data = data, column = column, split = TRUE)
  labels <- lookup[[lookup_column]][match(
    x = tokens$token,
    table = lookup[["__id"]]
  )]
  labels <- dplyr::if_else(
    condition = is.na(labels),
    true = tokens$token,
    false = labels
  )
  out <- rep(x = NA_character_, times = nrow(data))
  pieces <- split(
    x = labels,
    f = factor(x = tokens$row, levels = seq_len(nrow(data)))
  )
  out[lengths(pieces) > 0] <- vapply(
    X = pieces[lengths(pieces) > 0],
    FUN = paste,
    FUN.VALUE = character(1),
    collapse = "; "
  )
  out
}

#' Survey table: one row per ODK submission plus plot, survey-definition,
#' recorder, team, transport and plot-registration information
#'
#' The survey column `plot_selection-selected_plot_uuid` matches the entity id
#' (`__id`) of vegplots.csv, not its `plot_uuid` column (which matches the
#' registration form). `plot_selection-plot_status` is blank in the export, so
#' the status is the one in `plot_selection-get_plot_status`.
#'
#' @param survey,register ODK exports (text).
#' @param vegplots,surveys,project_team,transport Entity lists (text).
#' @return Tibble with one row per row of `survey`, in the same order.
veg_build_survey <- function(
  survey,
  register,
  vegplots,
  surveys,
  project_team,
  transport
) {
  plots <- vegplots |>
    dplyr::select(
      vegplots_id = `__id`,
      vegplots_plot_uuid = plot_uuid,
      vegplots_plot_status = plot_status,
      vegplots_is_viable = is_viable,
      vegplots_geohash = geohash,
      vegplots_stratum_label = stratum_label,
      vegplots_survey_uuids = survey_uuids
    )
  registered <- register |>
    dplyr::select(
      register_KEY = KEY,
      register_plot_uuid = `plot_selection-selected_plot_uuid`,
      register_ReviewState = ReviewState,
      register_is_plot_viable = `plot_selection-is_plot_viable`,
      register_sample_status = `plot_selection-sample_status`
    )
  defs <- surveys |>
    dplyr::select(
      surveydef_id = `__id`,
      surveydef_label = label,
      surveydef_target_group = target_group
    )
  recorders <- project_team |>
    dplyr::select(
      recorder_id = `__id`,
      recorder_choice_name = choice_name,
      recorder_affiliation = affiliation
    )
  transports <- transport |>
    dplyr::select(
      transport_id = `__id`,
      transport_choice_name = choice_name,
      transport_choice_status = choice_status
    )

  out <- survey |>
    dplyr::left_join(
      y = plots,
      by = dplyr::join_by(`plot_selection-selected_plot_uuid` == vegplots_id),
      relationship = "many-to-one",
      unmatched = "drop",
      keep = TRUE
    ) |>
    dplyr::left_join(
      y = registered,
      by = dplyr::join_by(vegplots_plot_uuid == register_plot_uuid),
      relationship = "many-to-one",
      unmatched = "drop",
      keep = TRUE
    ) |>
    dplyr::left_join(
      y = defs,
      by = dplyr::join_by(`survey_begin-selected_survey_uuid` == surveydef_id),
      relationship = "many-to-one",
      unmatched = "drop",
      keep = TRUE
    ) |>
    dplyr::left_join(
      y = recorders,
      by = dplyr::join_by(`field_team_specifics-recorder_uuid` == recorder_id),
      relationship = "many-to-one",
      unmatched = "drop",
      keep = TRUE
    ) |>
    dplyr::left_join(
      y = transports,
      by = dplyr::join_by(
        `field_team_specifics-selected_transport_type_uuid` == transport_id
      ),
      relationship = "many-to-one",
      unmatched = "drop",
      keep = TRUE
    )
  out$team_choice_names <- veg_resolve_multi(
    data = survey,
    column = "field_team_specifics-selected_project_team_uuid_multi",
    lookup = project_team,
    lookup_column = "choice_name"
  )
  # The lookup keys were only needed for the join
  out[c(
    "vegplots_id",
    "register_plot_uuid",
    "surveydef_id",
    "recorder_id",
    "transport_id"
  )] <- NULL
  out
}

#' Quadrat table: every quadrat row, with the key columns of its survey
#'
#' Built from the quadrat side (many quadrats to one survey), so an orphan
#' quadrat stays a row with NA survey columns instead of vanishing.
#'
#' @param quadrat Quadrat repeat (text or typed).
#' @param survey Output of veg_build_survey().
#' @param additional Additional-species repeat, used to count child rows.
veg_build_quadrat <- function(quadrat, survey, additional) {
  survey_keys <- survey |>
    dplyr::select(
      survey_KEY = KEY,
      survey_plot_name = `plot_selection-plot_name`,
      survey_plot_status = `plot_selection-get_plot_status`,
      survey_start_time = `survey_begin-start_time`,
      survey_ReviewState = ReviewState
    )
  children <- dplyr::count(
    x = additional,
    PARENT_KEY,
    name = "n_additional_rows"
  )
  quadrat |>
    dplyr::left_join(
      y = survey_keys,
      by = dplyr::join_by(PARENT_KEY == survey_KEY),
      relationship = "many-to-one",
      unmatched = "drop",
      keep = TRUE
    ) |>
    dplyr::left_join(
      y = children,
      by = dplyr::join_by(KEY == PARENT_KEY),
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    dplyr::mutate(n_additional_rows = dplyr::coalesce(n_additional_rows, 0L)) |>
    dplyr::select(-survey_KEY)
}

#' Long species table: one row per species record per quadrat
#'
#' `selected_list` rows come from the UUIDs picked from the species entity list
#' (resolved against species.csv; unresolved UUIDs are kept with NA name).
#' `additional_repeat` rows come from the additional-species repeat; the name is
#' the text as received (free text, provisional label or entity label).
#'
#' @param quadrat,additional ODK repeats (text).
#' @param species species.csv (text).
#' @return Tibble, selected rows first (quadrat order), then additional rows
#'   (file order).
veg_build_species_long <- function(quadrat, additional, species) {
  selected <- veg_split_ids(
    data = quadrat,
    column = "herb_species-selected_herb_species_uuids",
    key = "KEY"
  ) |>
    dplyr::rename(quadrat_key = key, species_uuid = id) |>
    dplyr::left_join(
      y = dplyr::select(
        .data = species,
        species_uuid = `__id`,
        species_name = label,
        scientific_name,
        family
      ),
      by = "species_uuid",
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    dplyr::mutate(
      source = "selected_list",
      record_id = paste0(quadrat_key, "#", position)
    ) |>
    dplyr::select(-position)

  extra <- additional |>
    dplyr::select(
      record_id = KEY,
      quadrat_key = PARENT_KEY,
      species_entry_mode,
      species_name = validated_name,
      select_reuse_unknown,
      select_reuse_missing,
      new_missing_canonical,
      review_status
    ) |>
    dplyr::mutate(
      source = "additional_repeat",
      species_uuid = dplyr::coalesce(select_reuse_unknown, select_reuse_missing)
    ) |>
    dplyr::select(-select_reuse_unknown, -select_reuse_missing)

  quadrat_keys <- quadrat |>
    dplyr::select(quadrat_key = KEY, survey_key = PARENT_KEY, quadrat_number)

  dplyr::bind_rows(selected, extra) |>
    dplyr::left_join(
      y = quadrat_keys,
      by = "quadrat_key",
      relationship = "many-to-one",
      unmatched = "drop"
    ) |>
    dplyr::select(
      source,
      record_id,
      survey_key,
      quadrat_key,
      quadrat_number,
      species_uuid,
      species_name,
      scientific_name,
      family,
      species_entry_mode,
      new_missing_canonical,
      review_status
    )
}
