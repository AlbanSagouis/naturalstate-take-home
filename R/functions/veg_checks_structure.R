# Structure checks (STR-xx): keys, parents, and duplicate submissions.

# STR-01: every quadrat row points to a survey submission that exists.
veg_chk_str01 <- function(ctx, config = veg_config) {
  q <- ctx$quadrat
  bad <- !is.element(el = q$PARENT_KEY, set = ctx$survey$KEY)
  veg_flag_rows(
    survey_key = q$PARENT_KEY[bad],
    quadrat_key = q$KEY[bad],
    value = q$PARENT_KEY[bad]
  )
}

# STR-02: every additional-species row points to a quadrat row that exists.
veg_chk_str02 <- function(ctx, config = veg_config) {
  sl <- ctx$species_long
  bad <- !is.na(sl$source) &
    sl$source == "additional_repeat" &
    !is.element(el = sl$quadrat_key, set = ctx$quadrat$KEY)
  veg_flag_rows(
    survey_key = sl$survey_key[bad],
    quadrat_key = sl$quadrat_key[bad],
    value = sl$record_id[bad]
  )
}

# One duplicated-key check per table; the value is the duplicated key
veg_dup_keys <- function(keys) {
  keys[
    !veg_is_blank(x = keys) &
      (duplicated(keys) | duplicated(keys, fromLast = TRUE))
  ]
}

# STR-03: duplicated survey KEY values.
veg_chk_str03 <- function(ctx, config = veg_config) {
  dup <- unique(veg_dup_keys(keys = ctx$survey$KEY))
  veg_flag_rows(survey_key = dup, value = dup)
}

# STR-04: duplicated quadrat KEY values.
veg_chk_str04 <- function(ctx, config = veg_config) {
  q <- ctx$quadrat
  bad <- !veg_is_blank(x = q$KEY) &
    is.element(el = q$KEY, set = unique(veg_dup_keys(keys = q$KEY)))
  veg_flag_rows(
    survey_key = q$PARENT_KEY[bad],
    quadrat_key = q$KEY[bad],
    value = q$KEY[bad]
  )
}

# STR-05: duplicated additional-species record keys.
veg_chk_str05 <- function(ctx, config = veg_config) {
  sl <- ctx$species_long
  add <- sl[!is.na(sl$source) & sl$source == "additional_repeat", ]
  bad <- is.element(
    el = add$record_id,
    set = unique(veg_dup_keys(keys = add$record_id))
  )
  veg_flag_rows(
    survey_key = add$survey_key[bad],
    quadrat_key = add$quadrat_key[bad],
    value = add$record_id[bad]
  )
}

# STR-06: survey submissions with no quadrat rows.
veg_chk_str06 <- function(ctx, config = veg_config) {
  bad <- !is.element(el = ctx$survey$KEY, set = ctx$quadrat$PARENT_KEY)
  veg_flag_rows(survey_key = ctx$survey$KEY[bad])
}

# Submissions grouped by plot and survey definition. A plot is meant to be
# surveyed once per survey; a second submission is a resubmission.
veg_submission_groups <- function(ctx, config = veg_config) {
  s <- ctx$survey
  tibble(
    survey_key = s$KEY,
    plot = s[["plot_selection-plot_name"]],
    survey_def = s[["survey_begin-selected_survey_uuid"]],
    rejected = !is.na(s$ReviewState) &
      s$ReviewState == config$review_state_rejected
  ) |>
    mutate(
      n_submissions = n(),
      n_accepted = sum(!rejected),
      .by = c(plot, survey_def)
    )
}

# STR-07: a rejected submission for a plot and survey that also has an accepted one.
# Rejected submission whose plot has an accepted one: the resubmission case
# (Plot_18, Plot_21). Context only, the rejection is the resolution.
veg_chk_str07 <- function(ctx, config = veg_config) {
  g <- veg_submission_groups(ctx = ctx, config = config)
  bad <- g$rejected & g$n_accepted >= 1
  veg_flag_rows(survey_key = g$survey_key[bad], value = g$plot[bad])
}

# STR-08: more than one accepted submission for the same plot and survey.
# Two or more accepted (not rejected) submissions for one plot and survey:
# nobody has decided which one counts.
veg_chk_str08 <- function(ctx, config = veg_config) {
  g <- veg_submission_groups(ctx = ctx, config = config)
  bad <- !g$rejected & g$n_accepted >= 2
  veg_flag_rows(survey_key = g$survey_key[bad], value = g$plot[bad])
}

# STR-09: a plot whose submissions are all rejected.
# Plot with submissions but all of them rejected: no usable data for the plot
veg_chk_str09 <- function(ctx, config = veg_config) {
  g <- veg_submission_groups(ctx = ctx, config = config)
  bad <- g$n_accepted == 0
  veg_flag_rows(survey_key = g$survey_key[bad], value = g$plot[bad])
}
