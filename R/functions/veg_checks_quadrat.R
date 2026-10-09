# Quadrat completeness (QUA-xx) and consistency (CON-xx) checks.

#' Per quadrat: number of selected-list records and of additional-repeat rows
veg_quadrat_species_counts <- function(ctx) {
  sl <- ctx$species_long
  tibble(quadrat_key = ctx$quadrat$KEY) |>
    mutate(
      n_selected = vapply(
        X = quadrat_key,
        FUN = function(k) {
          sum(sl$source == "selected_list" & sl$quadrat_key == k, na.rm = TRUE)
        },
        FUN.VALUE = numeric(1),
        USE.NAMES = FALSE
      ),
      n_additional = vapply(
        X = quadrat_key,
        FUN = function(k) {
          sum(
            sl$source == "additional_repeat" & sl$quadrat_key == k,
            na.rm = TRUE
          )
        },
        FUN.VALUE = numeric(1),
        USE.NAMES = FALSE
      )
    )
}

veg_quadrat_view <- function(ctx) {
  q <- ctx$quadrat
  bind_cols(
    veg_quadrat_typed(ctx = ctx),
    tibble(
      herbs_present = q$herbs_present,
      count_species = veg_to_numeric(
        x = q[["herb_species-count_herb_species"]]
      ),
      additional_flag = q$additional_species_present
    ),
    select(
      .data = veg_quadrat_species_counts(ctx = ctx),
      n_selected,
      n_additional
    )
  )
}

# QUA-01: a survey that does not have exactly the expected number of quadrats.
veg_chk_qua01 <- function(ctx, config = veg_config) {
  n <- vapply(
    X = ctx$survey$KEY,
    FUN = function(k) sum(ctx$quadrat$PARENT_KEY == k, na.rm = TRUE),
    FUN.VALUE = numeric(1),
    USE.NAMES = FALSE
  )
  bad <- n != config$expected_quadrats_per_plot
  veg_flag_rows(survey_key = ctx$survey$KEY[bad], value = n[bad])
}

# QUA-02: quadrat numbers that are not 1 to 20, each once.
veg_chk_qua02 <- function(ctx, config = veg_config) {
  q <- veg_quadrat_typed(ctx = ctx)
  expected <- config$expected_quadrat_numbers
  rows <- lapply(X = ctx$survey$KEY, FUN = function(k) {
    numbers <- q$quadrat_number[q$survey_key == k]
    if (length(numbers) == 0) {
      return(NULL)
    }
    missing_n <- setdiff(x = expected, y = numbers)
    duplicated_n <- unique(numbers[duplicated(numbers)])
    outside <- unique(numbers[
      is.na(numbers) | !is.element(el = numbers, set = expected)
    ])
    if (length(missing_n) + length(duplicated_n) + length(outside) == 0) {
      return(NULL)
    }
    detail <- c(
      if (length(missing_n) > 0) {
        paste0("missing ", paste(missing_n, collapse = ","))
      },
      if (length(duplicated_n) > 0) {
        paste0("repeated ", paste(duplicated_n, collapse = ","))
      },
      if (length(outside) > 0) {
        paste0("outside range ", paste(outside, collapse = ","))
      }
    )
    veg_flag_rows(survey_key = k, value = paste(detail, collapse = "; "))
  })
  bind_rows(veg_flag_rows(), rows)
}

# QUA-03: the quadrat count recorded by the form differs from the number of quadrat rows.
veg_chk_qua03 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  declared <- veg_to_numeric(x = s[["observations-quadrat_repeat_count"]])
  actual <- vapply(
    X = s$KEY,
    FUN = function(k) sum(ctx$quadrat$PARENT_KEY == k, na.rm = TRUE),
    FUN.VALUE = numeric(1),
    USE.NAMES = FALSE
  )
  bad <- is.na(declared) | declared != actual
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = declared[bad],
    detail = actual[bad]
  )
}

# QUA-04: a quadrat with no herbs whose species count is blank instead of 0.
veg_chk_qua04 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_view(ctx = ctx)
  bad <- !is.na(v$herbs_present) &
    v$herbs_present == "no" &
    is.na(v$count_species)
  veg_flag_rows(
    survey_key = v$survey_key[bad],
    quadrat_key = v$quadrat_key[bad]
  )
}

# QUA-05: a quadrat without a geopoint.
veg_chk_qua05 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_typed(ctx = ctx)
  bad <- is.na(v$lat) | is.na(v$lon)
  veg_flag_rows(
    survey_key = v$survey_key[bad],
    quadrat_key = v$quadrat_key[bad]
  )
}

# QUA-06: herbs_present that is not yes or no.
veg_chk_qua06 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_view(ctx = ctx)
  bad <- is.na(v$herbs_present) |
    !is.element(el = v$herbs_present, set = c("yes", "no"))
  veg_flag_rows(
    survey_key = v$survey_key[bad],
    quadrat_key = v$quadrat_key[bad],
    value = v$herbs_present[bad]
  )
}

# ---- Consistency --------------------------------------------------------------

# CON-01: herbs_present = no but species records exist.
veg_chk_con01 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_view(ctx = ctx)
  bad <- !is.na(v$herbs_present) &
    v$herbs_present == "no" &
    (v$n_selected + v$n_additional) > 0
  veg_flag_rows(
    survey_key = v$survey_key[bad],
    quadrat_key = v$quadrat_key[bad],
    value = v$n_selected[bad] + v$n_additional[bad]
  )
}

# CON-02: herbs_present = yes but no species record exists.
veg_chk_con02 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_view(ctx = ctx)
  bad <- !is.na(v$herbs_present) &
    v$herbs_present == "yes" &
    (v$n_selected + v$n_additional) == 0
  veg_flag_rows(
    survey_key = v$survey_key[bad],
    quadrat_key = v$quadrat_key[bad]
  )
}

# CON-03: the species count differs from the number of species selected from the list.
veg_chk_con03 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_view(ctx = ctx)
  bad <- !is.na(v$count_species) & v$count_species != v$n_selected
  veg_flag_rows(
    survey_key = v$survey_key[bad],
    quadrat_key = v$quadrat_key[bad],
    value = v$count_species[bad],
    detail = v$n_selected[bad]
  )
}

# CON-04: additional_species_present = yes but no additional-species row exists.
veg_chk_con04 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_view(ctx = ctx)
  bad <- !is.na(v$additional_flag) &
    v$additional_flag == "yes" &
    v$n_additional == 0
  veg_flag_rows(
    survey_key = v$survey_key[bad],
    quadrat_key = v$quadrat_key[bad]
  )
}

# CON-05: additional-species rows exist although additional_species_present is not yes.
veg_chk_con05 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_view(ctx = ctx)
  bad <- (is.na(v$additional_flag) | v$additional_flag != "yes") &
    v$n_additional > 0
  veg_flag_rows(
    survey_key = v$survey_key[bad],
    quadrat_key = v$quadrat_key[bad],
    value = v$n_additional[bad]
  )
}

# CON-06: quadrats_with_species differs from the number of quadrats with a species record.
# The form's own summary counts quadrats with at least one species record
veg_chk_con06 <- function(ctx, config = veg_config) {
  v <- veg_quadrat_view(ctx = ctx)
  s <- ctx$survey
  actual <- vapply(
    X = s$KEY,
    FUN = function(k) {
      sum(v$survey_key == k & (v$n_selected + v$n_additional) > 0, na.rm = TRUE)
    },
    FUN.VALUE = numeric(1),
    USE.NAMES = FALSE
  )
  declared <- veg_to_numeric(x = s[["survey_end-quadrats_with_species"]])
  bad <- is.na(declared) | declared != actual
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = declared[bad],
    detail = actual[bad]
  )
}

# CON-07: the same species twice in one quadrat from the same source.
# The same species twice in one quadrat from the same source
veg_chk_con07 <- function(ctx, config = veg_config) {
  sl <- ctx$species_long
  sl$name_key <- if_else(
    condition = veg_is_blank(x = sl$species_uuid),
    true = veg_normalise_name(x = sl$species_name),
    false = sl$species_uuid
  )
  dup <- sl |>
    filter(!is.na(name_key)) |>
    mutate(
      n_same = n(),
      .by = c(source, quadrat_key, name_key)
    ) |>
    filter(n_same > 1) |>
    distinct(source, quadrat_key, name_key, .keep_all = TRUE)
  veg_flag_rows(
    survey_key = dup$survey_key,
    quadrat_key = dup$quadrat_key,
    value = dup$species_name
  )
}
