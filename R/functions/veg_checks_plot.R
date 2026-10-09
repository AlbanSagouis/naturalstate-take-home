# Plot checks (PLT-xx): the plot a survey claims must exist, be viable, belong
# to the survey, be registered before it is surveyed. Uses the join columns
# written by 01_load_join.R (vegplots_*, register_*).

# PLT-01: the selected plot is missing from the registered plot list.
veg_chk_plt01 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  bad <- veg_is_blank(x = s$vegplots_plot_uuid)
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad]
  )
}

# PLT-02: the plot is not recorded as viable in the plot list or registration.
veg_chk_plt02 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  found <- !veg_is_blank(x = s$vegplots_plot_uuid)
  entity_no <- found &
    !is.na(s$vegplots_is_viable) &
    s$vegplots_is_viable != "yes"
  register_no <- found &
    !is.na(s$register_is_plot_viable) &
    s$register_is_plot_viable == "no"
  bad <- entity_no | register_no
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad],
    detail = dplyr::if_else(
      condition = register_no[bad],
      true = "registration",
      false = "plot list"
    )
  )
}

# PLT-03: the plot does not belong to the selected survey.
veg_chk_plt03 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  found <- !veg_is_blank(x = s$vegplots_plot_uuid)
  listed <- mapply(
    FUN = function(survey_uuids, wanted) {
      is.element(
        el = wanted,
        set = unlist(strsplit(x = survey_uuids %||% "", split = "\\s+"))
      )
    },
    s$vegplots_survey_uuids,
    s[["survey_begin-selected_survey_uuid"]],
    USE.NAMES = FALSE
  )
  bad <- found & !listed
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad]
  )
}

# PLT-04: the plot has no registration submission.
veg_chk_plt04 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  bad <- !veg_is_blank(x = s$vegplots_plot_uuid) &
    veg_is_blank(x = s$register_KEY)
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad]
  )
}

# PLT-05: the plot registration was finished after the survey started.
# Registration finished (device clock, form end time) after the survey started.
# The upload time of the registration is a separate, weaker signal (PLT-08).
veg_chk_plt05 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  registered <- veg_parse_time(
    x = ctx$register[["survey_end-end_time"]][
      match(x = s$register_KEY, table = ctx$register$KEY)
    ]
  )
  started <- veg_parse_time(x = s[["survey_begin-start_time"]])
  bad <- !is.na(registered) & !is.na(started) & registered > started
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad],
    detail = format(x = registered[bad], format = "%Y-%m-%d %H:%M", tz = "UTC")
  )
}

# PLT-06: a backup plot was surveyed instead of a primary plot.
veg_chk_plt06 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  bad <- !is.na(s[["plot_selection-get_plot_status"]]) &
    s[["plot_selection-get_plot_status"]] == "backup"
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad]
  )
}

# PLT-07: the plot status shown by the form differs from the plot list, or is missing.
# Status shown by the form differs from the plot list, or is missing
veg_chk_plt07 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  form <- s[["plot_selection-get_plot_status"]]
  listed <- s$vegplots_plot_status
  bad <- !veg_is_blank(x = s$vegplots_plot_uuid) &
    (veg_is_blank(x = form) | form != listed)
  bad[is.na(bad)] <- TRUE
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad],
    detail = paste0("form: ", form[bad], "; plot list: ", listed[bad])
  )
}

# PLT-08: the plot registration was uploaded after the survey started.
# Registration uploaded (server SubmissionDate) after the survey started. The
# form end time is earlier, so this is a delayed upload, not a registration
# after the survey; the plot could only be picked if the entity was on the device.
veg_chk_plt08 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  uploaded <- veg_parse_time(
    x = ctx$register$SubmissionDate[
      match(x = s$register_KEY, table = ctx$register$KEY)
    ]
  )
  started <- veg_parse_time(x = s[["survey_begin-start_time"]])
  bad <- !is.na(uploaded) & !is.na(started) & uploaded > started
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = s[["plot_selection-plot_name"]][bad],
    detail = format(x = uploaded[bad], format = "%Y-%m-%d %H:%M", tz = "UTC")
  )
}
