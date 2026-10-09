# Synthetic input for the QA/QC check tests (issue #8).
# make_clean_ctx() is one fully valid survey (20 quadrats, one listed species
# each): no check may raise a flag on it. Each failing case changes one thing.

# Rule values and tolerances: the check functions take `config = veg_config`, and
# helper-veg.R sources them into the global environment, so the default must live there
assign(x = "veg_config", value = veg_config_for_tests(), envir = globalenv())

clean_survey_key <- "uuid:s1"

make_clean_ctx <- function() {
  keys <- paste0(clean_survey_key, "/q", 1:20)
  # Quadrats on the transect: two per 5 m mark, alternating sides (+-2.5 m).
  # 1 m is about 9.0e-6 degrees at the equator.
  along_m <- (rep(x = 0:9, each = 2) * 5) - 22.5
  side_m <- rep(x = c(2.5, -2.5), times = 10)
  deg <- 9.0e-6
  list(
    survey = tibble(
      KEY = clean_survey_key,
      ReviewState = "approved",
      SubmissionDate = "2026-05-27T12:00:00.000Z",
      FormVersion = "v1",
      `plot_selection-selected_plot_uuid` = "p1",
      `plot_selection-plot_name` = "Plot_1",
      `plot_selection-get_plot_status` = "primary",
      `survey_begin-selected_survey_uuid` = "d1",
      `survey_begin-start_time` = "2026-05-27T09:00:00.000+02:00",
      `survey_end-end_time` = "2026-05-27T10:00:00.000+02:00",
      `field_team_specifics-recorder_uuid` = "t1",
      `field_team_specifics-selected_project_team_uuid_multi` = "t1 t2",
      `observations-quadrat_repeat_count` = "20",
      `survey_end-quadrats_with_species` = "20",
      `survey_end-background_geopoint-Latitude` = "0.2",
      `survey_end-background_geopoint-Longitude` = "37",
      `survey_end-background_geopoint-Accuracy` = "3",
      vegplots_plot_uuid = "r1",
      vegplots_plot_status = "primary",
      vegplots_is_viable = "yes",
      vegplots_survey_uuids = "d1 d2",
      register_KEY = "uuid:r1",
      register_is_plot_viable = "yes",
      recorder_choice_name = "Aa_Aa"
    ),
    quadrat = tibble(
      KEY = keys,
      PARENT_KEY = clean_survey_key,
      quadrat_number = as.character(1:20),
      herbs_present = "yes",
      `herb_species-count_herb_species` = "1",
      additional_species_present = "no",
      `location_quadrat-Latitude` = as.character(0.2 + along_m * deg),
      `location_quadrat-Longitude` = as.character(37 + side_m * deg),
      `location_quadrat-Accuracy` = "3"
    ),
    species_long = tibble(
      source = "selected_list",
      record_id = paste0(keys, "#1"),
      survey_key = clean_survey_key,
      quadrat_key = keys,
      quadrat_number = as.character(1:20),
      species_uuid = uuid_a,
      species_name = "Alpha beta",
      scientific_name = "Alpha beta L.",
      family = "Poaceae",
      species_entry_mode = NA_character_,
      new_missing_canonical = NA_character_,
      review_status = NA_character_
    ),
    register = tibble(
      KEY = "uuid:r1",
      SubmissionDate = "2026-05-20T10:00:00.000Z",
      `survey_end-end_time` = "2026-05-20T11:00:00.000+02:00"
    ),
    vegplots = tibble(
      `__id` = "p1",
      geometry = "0.2 37 1000 3"
    ),
    species = tibble(
      `__id` = c(uuid_a, uuid_b),
      label = c("Alpha beta", "Gamma delta")
    ),
    species_extra = tibble(`__id` = "u1", label = "herb_001"),
    project_team = tibble(
      `__id` = c("t1", "t2"),
      choice_name = c("Aa_Aa", "Bb_Bb")
    )
  )
}

# Add an additional-species row to quadrat `q` of the clean survey
add_species_row <- function(
  ctx,
  q = 1,
  name = NA,
  mode = "reuse_missing",
  canonical = NA,
  uuid = NA,
  record_id = NULL
) {
  key <- paste0(clean_survey_key, "/q", q)
  record_id <- record_id %||% paste0(key, "/a", nrow(ctx$species_long))
  ctx$species_long <- bind_rows(
    ctx$species_long,
    tibble(
      source = "additional_repeat",
      record_id = record_id,
      survey_key = clean_survey_key,
      quadrat_key = key,
      quadrat_number = as.character(q),
      species_uuid = uuid,
      species_name = name,
      species_entry_mode = mode,
      new_missing_canonical = canonical
    )
  )
  ctx
}

# A second submission for the same plot and survey
add_survey_row <- function(ctx, key = "uuid:s2", ...) {
  row <- ctx$survey[1, ]
  row$KEY <- key
  extra <- list(...)
  for (name in names(extra)) {
    row[[name]] <- extra[[name]]
  }
  ctx$survey <- bind_rows(ctx$survey, row)
  ctx
}

# One failing example per check: a function that turns the clean context into
# one where the check must fire.
failing_cases <- list(
  `STR-01` = function(ctx) {
    ctx$quadrat$PARENT_KEY[1] <- "uuid:other"
    ctx
  },
  `STR-02` = function(ctx) {
    add_species_row(ctx = ctx, name = "x", uuid = "u1") |>
      (\(c) {
        c$species_long$quadrat_key[nrow(c$species_long)] <- "uuid:gone/q1"
        c
      })()
  },
  `STR-03` = function(ctx) add_survey_row(ctx = ctx, key = clean_survey_key),
  `STR-04` = function(ctx) {
    ctx$quadrat <- bind_rows(ctx$quadrat, ctx$quadrat[1, ])
    ctx
  },
  `STR-05` = function(ctx) {
    ctx <- add_species_row(
      ctx = ctx,
      name = "herb_001",
      uuid = "u1",
      record_id = "dup"
    )
    add_species_row(
      ctx = ctx,
      q = 2,
      name = "herb_001",
      uuid = "u1",
      record_id = "dup"
    )
  },
  `STR-06` = function(ctx) add_survey_row(ctx = ctx, key = "uuid:s2"),
  `STR-07` = function(ctx) {
    add_survey_row(ctx = ctx, key = "uuid:s2", ReviewState = "rejected")
  },
  `STR-08` = function(ctx) add_survey_row(ctx = ctx, key = "uuid:s2"),
  `STR-09` = function(ctx) {
    ctx$survey$ReviewState <- "rejected"
    ctx
  },
  `PLT-01` = function(ctx) {
    ctx$survey$vegplots_plot_uuid <- NA_character_
    ctx
  },
  `PLT-02` = function(ctx) {
    ctx$survey$vegplots_is_viable <- "no"
    ctx
  },
  `PLT-03` = function(ctx) {
    ctx$survey$vegplots_survey_uuids <- "other"
    ctx
  },
  `PLT-04` = function(ctx) {
    ctx$survey$register_KEY <- NA_character_
    ctx
  },
  `PLT-05` = function(ctx) {
    ctx$register[["survey_end-end_time"]] <- "2026-05-27T11:00:00.000+02:00"
    ctx
  },
  `PLT-06` = function(ctx) {
    ctx$survey[["plot_selection-get_plot_status"]] <- "backup"
    ctx$survey$vegplots_plot_status <- "backup"
    ctx
  },
  `PLT-07` = function(ctx) {
    ctx$survey$vegplots_plot_status <- "backup"
    ctx
  },
  `PLT-08` = function(ctx) {
    ctx$register$SubmissionDate <- "2026-05-27T09:00:00.000Z"
    ctx
  },
  `QUA-01` = function(ctx) {
    ctx$quadrat <- ctx$quadrat[-20, ]
    ctx
  },
  `QUA-02` = function(ctx) {
    ctx$quadrat$quadrat_number[20] <- "19"
    ctx
  },
  `QUA-03` = function(ctx) {
    ctx$survey[["observations-quadrat_repeat_count"]] <- "19"
    ctx
  },
  `QUA-04` = function(ctx) {
    ctx$quadrat$herbs_present[1] <- "no"
    ctx$quadrat[["herb_species-count_herb_species"]][1] <- NA_character_
    ctx
  },
  `QUA-05` = function(ctx) {
    ctx$quadrat[["location_quadrat-Latitude"]][1] <- NA_character_
    ctx
  },
  `QUA-06` = function(ctx) {
    ctx$quadrat$herbs_present[1] <- NA_character_
    ctx
  },
  `CON-01` = function(ctx) {
    ctx$quadrat$herbs_present[1] <- "no"
    ctx
  },
  `CON-02` = function(ctx) {
    ctx$species_long <- ctx$species_long[-1, ]
    ctx
  },
  `CON-03` = function(ctx) {
    ctx$quadrat[["herb_species-count_herb_species"]][1] <- "3"
    ctx
  },
  `CON-04` = function(ctx) {
    ctx$quadrat$additional_species_present[1] <- "yes"
    ctx
  },
  `CON-05` = function(ctx) {
    add_species_row(ctx = ctx, q = 2, name = "herb_001", uuid = "u1")
  },
  `CON-06` = function(ctx) {
    ctx$survey[["survey_end-quadrats_with_species"]] <- "19"
    ctx
  },
  `CON-07` = function(ctx) {
    ctx$species_long <- bind_rows(
      ctx$species_long,
      ctx$species_long[1, ]
    )
    ctx$species_long$record_id[21] <- "other"
    ctx
  },
  `SPE-01` = function(ctx) {
    ctx$species_long$species_name[1] <- NA_character_
    ctx
  },
  `SPE-02` = function(ctx) {
    add_species_row(
      ctx = ctx,
      name = "herb_005 (Zeta omega)",
      mode = "new_missing",
      canonical = "Zeta omega"
    )
  },
  `SPE-03` = function(ctx) {
    add_species_row(
      ctx = ctx,
      name = "herb_001",
      mode = "reuse_unknown",
      uuid = "u1"
    )
  },
  `SPE-04` = function(ctx) {
    add_species_row(
      ctx = ctx,
      name = uuid_c,
      mode = "new_missing",
      canonical = uuid_c
    )
  },
  `SPE-05` = function(ctx) {
    add_species_row(
      ctx = ctx,
      name = "herb_005 (Zeta_omega )",
      mode = "new_missing",
      canonical = "Zeta_omega "
    )
  },
  `SPE-06` = function(ctx) {
    add_species_row(
      ctx = ctx,
      name = "herb_005 (Alpha_bata)",
      mode = "new_missing",
      canonical = "Alpha_bata"
    )
  },
  `SPE-07` = function(ctx) {
    add_species_row(
      ctx = ctx,
      name = "Alpha beta",
      mode = "reuse_missing",
      uuid = "u1"
    )
  },
  `SPE-08` = function(ctx) {
    ctx <- add_species_row(
      ctx = ctx,
      q = 1,
      name = "herb_005 (Zeta_omega)",
      mode = "new_missing",
      canonical = "Zeta_omega"
    )
    add_species_row(
      ctx = ctx,
      q = 2,
      name = "herb_006 (Zeta_omega)",
      mode = "new_missing",
      canonical = "Zeta_omega"
    )
  },
  `SPE-09` = function(ctx) {
    add_species_row(
      ctx = ctx,
      name = "herb_005 (Alpha_beta)",
      mode = "new_missing",
      canonical = "Alpha_beta"
    )
  },
  `SPE-10` = function(ctx) {
    add_species_row(
      ctx = ctx,
      name = "herb_002",
      mode = "reuse_unknown",
      uuid = "not-in-list"
    )
  },
  `SPE-11` = function(ctx) {
    add_species_row(ctx = ctx, name = NA, mode = "reuse_missing")
  },
  `SPE-12` = function(ctx) {
    add_species_row(
      ctx = ctx,
      name = "Zeta omega ",
      mode = "reuse_missing",
      uuid = "u1"
    )
  },
  `SPA-01` = function(ctx) {
    ctx$quadrat[["location_quadrat-Accuracy"]][1] <- "6"
    ctx
  },
  `SPA-02` = function(ctx) {
    ctx$survey[["survey_end-background_geopoint-Accuracy"]] <- "5.066"
    ctx
  },
  `SPA-03` = function(ctx) {
    ctx$survey[["survey_end-background_geopoint-Accuracy"]] <- NA_character_
    ctx
  },
  `SPA-04` = function(ctx) {
    ctx$quadrat[["location_quadrat-Latitude"]][5] <- as.character(0.2 + 0.001)
    ctx
  },
  `SPA-05` = function(ctx) {
    ctx$survey[["survey_end-background_geopoint-Latitude"]] <- as.character(
      0.2 + 0.001
    )
    ctx
  },
  `SPA-06` = function(ctx) {
    ctx$quadrat[["location_quadrat-Latitude"]][11] <- as.character(
      as.numeric(ctx$quadrat[["location_quadrat-Latitude"]][11]) + 0.0002
    )
    ctx
  },
  `SPA-07` = function(ctx) {
    ctx$quadrat[["location_quadrat-Latitude"]][2] <- ctx$quadrat[[
      "location_quadrat-Latitude"
    ]][1]
    ctx$quadrat[["location_quadrat-Longitude"]][2] <- ctx$quadrat[[
      "location_quadrat-Longitude"
    ]][1]
    ctx
  },
  `TIM-01` = function(ctx) {
    ctx$survey[["survey_end-end_time"]] <- "2026-05-27T08:00:00.000+02:00"
    ctx
  },
  `TIM-02` = function(ctx) {
    ctx$survey[["survey_end-end_time"]] <- "2026-05-27T09:05:00.000+02:00"
    ctx
  },
  `TIM-03` = function(ctx) {
    ctx$survey$SubmissionDate <- "2026-05-27T06:50:00.000Z"
    ctx
  },
  `TIM-04` = function(ctx) {
    ctx$survey$SubmissionDate <- "2026-05-29T12:00:00.000Z"
    ctx
  },
  `TIM-05` = function(ctx) {
    ctx$survey[["survey_begin-start_time"]] <- NA_character_
    ctx
  },
  `MET-01` = function(ctx) {
    add_survey_row(ctx = ctx, key = "uuid:s2", FormVersion = "v2")
  },
  `MET-02` = function(ctx) {
    ctx$survey$ReviewState <- NA_character_
    ctx
  },
  `MET-03` = function(ctx) {
    ctx$survey$ReviewState <- "hasIssues"
    ctx
  },
  `MET-04` = function(ctx) {
    ctx$survey[["field_team_specifics-recorder_uuid"]] <- "t9"
    ctx
  }
)
