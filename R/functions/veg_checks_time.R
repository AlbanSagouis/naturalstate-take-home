# Time (TIM-xx) and metadata (MET-xx) checks. Timestamps are compared in UTC
# with their ODK offset honoured (see veg_parse_time).

# TIM-01: Survey ends before it starts.
veg_chk_tim01 <- function(ctx, config = veg_config) {
  t <- veg_survey_typed(ctx = ctx)
  bad <- !is.na(t$start) & !is.na(t$end) & t$end < t$start
  veg_flag_rows(survey_key = t$survey_key[bad])
}

# TIM-02: Survey duration outside the plausible range.
veg_chk_tim02 <- function(ctx, config = veg_config) {
  t <- veg_survey_typed(ctx = ctx)
  minutes <- as.numeric(difftime(
    time1 = t$end,
    time2 = t$start,
    units = "mins"
  ))
  bad <- !is.na(minutes) &
    minutes >= 0 &
    (minutes < config$duration_min_minutes |
      minutes > config$duration_max_minutes)
  veg_flag_rows(survey_key = t$survey_key[bad], value = round(minutes[bad]))
}

# TIM-03: Survey starts after it was submitted.
veg_chk_tim03 <- function(ctx, config = veg_config) {
  t <- veg_survey_typed(ctx = ctx)
  seconds <- as.numeric(difftime(
    time1 = t$start,
    time2 = t$submitted,
    units = "secs"
  ))
  bad <- !is.na(seconds) & seconds > config$start_after_submission_tolerance_s
  veg_flag_rows(survey_key = t$survey_key[bad], value = round(seconds[bad]))
}

# TIM-04: Survey submitted long after it finished.
veg_chk_tim04 <- function(ctx, config = veg_config) {
  t <- veg_survey_typed(ctx = ctx)
  hours <- as.numeric(difftime(
    time1 = t$submitted,
    time2 = t$end,
    units = "hours"
  ))
  bad <- !is.na(hours) & hours > config$late_submission_hours
  veg_flag_rows(
    survey_key = t$survey_key[bad],
    value = round(hours[bad], digits = 1)
  )
}

# TIM-05: Start, end or submission time missing or unreadable.
veg_chk_tim05 <- function(ctx, config = veg_config) {
  t <- veg_survey_typed(ctx = ctx)
  bad <- is.na(t$start) | is.na(t$end) | is.na(t$submitted)
  veg_flag_rows(survey_key = t$survey_key[bad])
}

# MET-01: Form version different from the one most submissions used.
veg_chk_met01 <- function(ctx, config = veg_config) {
  v <- ctx$survey$FormVersion
  versions <- table(v[!is.na(v)])
  if (length(versions) == 0) {
    return(veg_flag_rows())
  }
  modal <- names(versions)[which.max(versions)]
  bad <- is.na(v) | v != modal
  veg_flag_rows(
    survey_key = ctx$survey$KEY[bad],
    value = v[bad],
    detail = modal
  )
}

# MET-02: Submission with no review state recorded in ODK Central.
veg_chk_met02 <- function(ctx, config = veg_config) {
  r <- ctx$survey$ReviewState
  reviewed <- c(
    config$review_state_approved,
    config$review_state_rejected,
    config$review_state_issues
  )
  bad <- is.na(r) | !is.element(el = r, set = reviewed)
  veg_flag_rows(survey_key = ctx$survey$KEY[bad], value = r[bad])
}

# MET-03: Submission marked "has issues" and not yet resolved.
veg_chk_met03 <- function(ctx, config = veg_config) {
  r <- ctx$survey$ReviewState
  bad <- !is.na(r) & r == config$review_state_issues
  veg_flag_rows(survey_key = ctx$survey$KEY[bad], value = r[bad])
}

# MET-04: Recorder not in the project team or not in this survey's team.
veg_chk_met04 <- function(ctx, config = veg_config) {
  s <- ctx$survey
  recorder <- s[["field_team_specifics-recorder_uuid"]]
  team <- strsplit(
    x = s[["field_team_specifics-selected_project_team_uuid_multi"]] %||% "",
    split = "\\s+"
  )
  in_team <- mapply(
    FUN = function(r, members) !is.na(r) && is.element(el = r, set = members),
    recorder,
    team,
    USE.NAMES = FALSE
  )
  in_project <- !is.na(recorder) &
    is.element(el = recorder, set = ctx$project_team$`__id`)
  bad <- !in_team | !in_project
  veg_flag_rows(
    survey_key = s$KEY[bad],
    value = dplyr::coalesce(s$recorder_choice_name[bad], recorder[bad]),
    detail = dplyr::if_else(
      condition = in_project[bad],
      true = "not in the survey team",
      false = "not in the project team list"
    )
  )
}
