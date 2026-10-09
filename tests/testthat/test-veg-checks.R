# Tests for the QA/QC checks (issue #8): a failing and a passing example for
# every check, specific edge cases, and the guarantee that no check modifies
# its input.

catalogue <- veg_check_catalogue()

test_that("the clean example raises no flag at all", {
  flags <- veg_build_flags(ctx = make_clean_ctx(), catalogue = catalogue)
  expect_identical(nrow(flags), 0L)
  expect_identical(names(flags), veg_flag_columns)
})

test_that("every check has a failing example and every example belongs to a check", {
  expect_setequal(names(failing_cases), catalogue$id)
})

for (id in catalogue$id) {
  local({
    id <- id
    test_that(
      paste(
        id,
        "returns zero rows on the clean example and fires on the failing one"
      ),
      {
        clean <- make_clean_ctx()
        passing <- veg_run_one_check(
          id = id,
          ctx = clean,
          catalogue = catalogue
        )
        expect_identical(nrow(passing), 0L)
        failing <- veg_run_one_check(
          id = id,
          ctx = failing_cases[[id]](clean),
          catalogue = catalogue
        )
        expect_gt(nrow(failing), 0L)
        expect_true(all(failing$check_id == id))
      }
    )
  })
}

test_that("checks never modify their input tables", {
  for (id in catalogue$id) {
    ctx <- failing_cases[[id]](make_clean_ctx())
    before <- ctx
    veg_build_flags(ctx = ctx, catalogue = catalogue)
    expect_identical(ctx, before, info = id)
  }
})

test_that("a check that finds nothing returns zero rows, not an error", {
  empty <- make_clean_ctx()
  empty$quadrat <- empty$quadrat[0, ]
  empty$species_long <- empty$species_long[0, ]
  expect_no_error(flags <- veg_build_flags(ctx = empty, catalogue = catalogue))
  expect_s3_class(flags, "tbl_df")
})

# ---- Duplicate submissions ----------------------------------------------------

test_that("a rejected resubmission is info, two accepted ones are a warning, all rejected an error", {
  rejected <- failing_cases[["STR-07"]](make_clean_ctx())
  expect_identical(veg_chk_str07(ctx = rejected)$survey_key, "uuid:s2")
  expect_identical(nrow(veg_chk_str08(ctx = rejected)), 0L)
  expect_identical(nrow(veg_chk_str09(ctx = rejected)), 0L)

  two_accepted <- failing_cases[["STR-08"]](make_clean_ctx())
  expect_setequal(
    veg_chk_str08(ctx = two_accepted)$survey_key,
    c(clean_survey_key, "uuid:s2")
  )
  expect_identical(nrow(veg_chk_str07(ctx = two_accepted)), 0L)

  all_rejected <- add_survey_row(
    ctx = make_clean_ctx(),
    key = "uuid:s2",
    ReviewState = "rejected"
  )
  all_rejected$survey$ReviewState <- "rejected"
  expect_setequal(
    veg_chk_str09(ctx = all_rejected)$survey_key,
    c(clean_survey_key, "uuid:s2")
  )
  expect_identical(nrow(veg_chk_str07(ctx = all_rejected)), 0L)
})

test_that("the same plot in a different survey is not a duplicate", {
  ctx <- add_survey_row(
    ctx = make_clean_ctx(),
    key = "uuid:s2",
    `survey_begin-selected_survey_uuid` = "d2"
  )
  expect_identical(nrow(veg_chk_str08(ctx = ctx)), 0L)
})

# ---- Time ---------------------------------------------------------------------

test_that("timestamps are compared with their UTC offset honoured", {
  start <- veg_parse_time(x = "2026-05-27T09:41:43.843+02:00")
  submitted <- veg_parse_time(x = "2026-05-27T08:46:04.721Z")
  expect_lt(as.numeric(start), as.numeric(submitted))
  # Dropping the offset (the quick-look reading) makes the start look 2 h too late
  naive <- veg_parse_time(x = "2026-05-27T09:41:43.843+00:00")
  expect_gt(as.numeric(difftime(naive, submitted, units = "secs")), 60)

  ctx <- make_clean_ctx()
  ctx$survey[["survey_begin-start_time"]] <- "2026-05-27T09:41:43.843+02:00"
  ctx$survey[["survey_end-end_time"]] <- "2026-05-27T10:41:43.843+02:00"
  ctx$survey$SubmissionDate <- "2026-05-27T08:46:04.721Z"
  expect_identical(nrow(veg_chk_tim03(ctx = ctx)), 0L)
})

test_that("an unreadable timestamp is NA, not an error", {
  expect_true(is.na(veg_parse_time(x = "not a time")))
})

test_that("a duration just inside the limits is not flagged", {
  ctx <- make_clean_ctx()
  ctx$survey[["survey_end-end_time"]] <- "2026-05-27T09:15:00.000+02:00"
  expect_identical(nrow(veg_chk_tim02(ctx = ctx)), 0L)
  ctx$survey[["survey_end-end_time"]] <- "2026-05-27T12:00:00.000+02:00"
  expect_identical(nrow(veg_chk_tim02(ctx = ctx)), 0L)
})

# ---- Plot ---------------------------------------------------------------------

test_that("a registration finished before the survey but uploaded after it is info only", {
  ctx <- failing_cases[["PLT-08"]](make_clean_ctx())
  expect_identical(nrow(veg_chk_plt05(ctx = ctx)), 0L)
  expect_identical(nrow(veg_chk_plt08(ctx = ctx)), 1L)
})

# ---- Species ------------------------------------------------------------------

test_that("the canonical-name regex accepts Genus_species and rejects the rest", {
  pattern <- veg_config$species_name_regex
  good <- c(
    "Chloris_virgata",
    "Pechuel-loeschea_leubnitziae",
    "Digitaria_eriantha"
  )
  bad <- c(
    "Chloris virgata",
    "chloris_virgata",
    "Chloris_Virgata",
    "Chloris_virgata ",
    " Chloris_virgata",
    "Chloris_virgata L.",
    "Chloris_virgata Digitaria_eriantha",
    "Chloris",
    "Chloris_",
    "herb_104",
    "Unknown_grass_sp1",
    "Chloris_virgata_var"
  )
  expect_true(all(stringi::stri_detect_regex(str = good, pattern = pattern)))
  expect_false(any(stringi::stri_detect_regex(str = bad, pattern = pattern)))
})

test_that("a correctly typed name raises no format or listing flag", {
  ctx <- add_species_row(
    ctx = make_clean_ctx(),
    name = "herb_005 (Zeta_omega)",
    mode = "new_missing",
    canonical = "Zeta_omega"
  )
  for (id in c("SPE-02", "SPE-05", "SPE-06", "SPE-08", "SPE-09")) {
    expect_identical(
      nrow(veg_run_one_check(id = id, ctx = ctx, catalogue = catalogue)),
      0L,
      info = id
    )
  }
})

test_that("misspellings: a distance of one is found, an exact match and a far name are not", {
  listed <- c("Ipomoea bolusiana", "Cenchrus ciliaris")
  out <- veg_misspelling_matches(
    typed = c("Ipomoea bolusiana", "Ipomoea bolusiano", "Cenchrus bifloris"),
    listed = listed,
    max_distance = 2,
    max_relative = 0.15
  )
  expect_true(is.na(out$suggestion[1]))
  expect_identical(out$suggestion[2], "ipomoea bolusiana")
  expect_true(is.na(out$suggestion[3]))
  expect_identical(
    nrow(veg_misspelling_matches(
      typed = character(),
      listed = listed,
      max_distance = 2,
      max_relative = 0.15
    )),
    0L
  )
})

test_that("a genus one letter off a listed genus is found", {
  ctx <- make_clean_ctx()
  ctx$species$label <- c("Ipomoea bolusiana", "Gamma delta")
  ctx <- add_species_row(
    ctx = ctx,
    name = "herb_005 (Ipomea_leucanthemum)",
    mode = "new_missing",
    canonical = "Ipomea_leucanthemum"
  )
  flags <- veg_chk_spe06(ctx = ctx)
  expect_identical(flags$detail, "Ipomoea")
})

test_that("the provisional label inside a built name is removed before names are compared", {
  expect_identical(
    veg_normalise_name(x = "herb_104 (Justicia divaricata )"),
    "justicia divaricata"
  )
  expect_identical(
    veg_normalise_name(x = "Justicia_divaricata"),
    "justicia divaricata"
  )
  expect_identical(veg_normalise_name(x = "herb_104"), "herb 104")
})

test_that("a provisional unknown is flagged once per quadrat even if listed twice", {
  ctx <- add_species_row(
    ctx = make_clean_ctx(),
    name = "herb_001",
    mode = "reuse_unknown",
    uuid = "u1"
  )
  ctx <- add_species_row(
    ctx = ctx,
    name = "herb_001",
    mode = "reuse_unknown",
    uuid = "u1"
  )
  expect_identical(
    nrow(
      veg_build_flags(ctx = ctx, catalogue = catalogue) |>
        dplyr::filter(check_id == "SPE-03")
    ),
    1L
  )
})

# ---- Spatial ------------------------------------------------------------------

test_that("distances are metric and the UTM zone follows the points", {
  d <- veg_distance_m(
    lon1 = 37,
    lat1 = 0.2,
    lon2 = 37,
    lat2 = 0.2 + 100 * 9.0e-6
  )
  expect_equal(d, 100, tolerance = 0.01)
  expect_identical(veg_utm_epsg(lon = 37.5, lat = 0.2), 32637L)
  expect_identical(veg_utm_epsg(lon = 37.5, lat = -1.3), 32737L)
  expect_true(is.na(veg_distance_m(
    lon1 = NA_real_,
    lat1 = 0,
    lon2 = 37,
    lat2 = 0
  )))
})

test_that("the belt reach is half the diagonal of a 50 m x 5 m belt", {
  expect_equal(veg_belt_reach_m(config = veg_config), sqrt(25^2 + 2.5^2))
})

test_that("a quadrat at the end of the belt is inside the tolerance, one 40 m away is not", {
  ctx <- make_clean_ctx()
  expect_identical(nrow(veg_chk_spa04(ctx = ctx)), 0L)
  ctx$quadrat[["location_quadrat-Latitude"]][1] <- as.character(
    0.2 + 40 * 9.0e-6
  )
  expect_identical(veg_chk_spa04(ctx = ctx)$quadrat_key, ctx$quadrat$KEY[1])
})

test_that("an accuracy of exactly 5 m passes and 5.066 m fails", {
  ctx <- make_clean_ctx()
  ctx$survey[["survey_end-background_geopoint-Accuracy"]] <- "5"
  expect_identical(nrow(veg_chk_spa02(ctx = ctx)), 0L)
  ctx$survey[["survey_end-background_geopoint-Accuracy"]] <- "5.066"
  expect_identical(nrow(veg_chk_spa02(ctx = ctx)), 1L)
})

# ---- Flags table --------------------------------------------------------------

test_that("flags carry the catalogue's level, severity and resolver and a filled message", {
  ctx <- failing_cases[["CON-03"]](make_clean_ctx())
  flags <- veg_build_flags(ctx = ctx, catalogue = catalogue) |>
    dplyr::filter(check_id == "CON-03")
  expect_identical(flags$severity, "error")
  expect_identical(flags$level, "quadrat")
  expect_identical(flags$plot_name, "Plot_1")
  expect_identical(flags$survey_date, "2026-05-27")
  expect_identical(flags$recorder, "Aa_Aa")
  expect_match(flags$message, "Quadrat 1 counts 3 species but 1 are selected")
  expect_false(grepl(pattern = "\\{", x = flags$message))
})

test_that("flag ids are unique md5 hashes that do not depend on other flags", {
  ctx <- failing_cases[["SPE-08"]](make_clean_ctx())
  flags <- veg_build_flags(ctx = ctx, catalogue = catalogue)
  expect_match(flags$flag_id, "^[0-9a-f]{32}$")
  expect_false(anyDuplicated(flags$flag_id) > 0)
  # a known value: md5 of "a|b|c|d" (the recipe the SQL runner uses)
  expect_identical(
    veg_flag_id(
      check_id = "a",
      survey_key = "b",
      quadrat_key = "c",
      value = "d"
    ),
    digest::digest(object = "a|b|c|d", algo = "md5", serialize = FALSE)
  )
  # NULL quadrat and value are empty text, as concat_ws(coalesce(x, '')) in SQL
  expect_identical(
    veg_flag_id(check_id = "a", survey_key = "b", quadrat_key = NA, value = NA),
    digest::digest(object = "a|b||", algo = "md5", serialize = FALSE)
  )
  # removing another finding leaves the id unchanged
  more <- veg_build_flags(
    ctx = failing_cases[["CON-03"]](ctx),
    catalogue = catalogue
  )
  shared <- intersect(flags$flag_id, more$flag_id)
  expect_gt(length(shared), 0)
})

test_that("a duplicated survey key and NA keys do not abort the checks", {
  ctx <- failing_cases[["STR-03"]](make_clean_ctx())
  expect_no_error(veg_rejected_keys(survey = ctx$survey))
  ctx$quadrat$PARENT_KEY[1] <- NA_character_
  expect_no_error(flags <- veg_build_flags(ctx = ctx, catalogue = catalogue))
  expect_false(anyNA(flags$check_id))
  expect_gt(nrow(veg_chk_qua01(ctx = ctx)), 0L)
})

test_that("SPA-03 flags a missing end-of-survey longitude", {
  ctx <- make_clean_ctx()
  ctx$survey[["survey_end-background_geopoint-Longitude"]] <- NA_character_
  expect_equal(nrow(veg_chk_spa03(ctx = ctx)), 1L)
})

test_that("a template is filled; a missing value becomes empty", {
  out <- veg_fill_template(
    template = c("a {value} b {detail}", "{plot}"),
    values = list(value = c("x", NA), detail = c(1, 2), plot = c("p", "q"))
  )
  expect_identical(out, c("a x b 1", "q"))
})

# ---- Catalogue and flags checks -----------------------------------------------

test_that("the catalogue is valid and a broken one is refused", {
  expect_no_error(veg_check_catalogue_valid(catalogue = catalogue))
  expect_error(veg_check_catalogue_valid(
    catalogue = dplyr::mutate(
      catalogue,
      severity = replace(severity, 1, "fatal")
    )
  ))
  expect_error(veg_check_catalogue_valid(
    catalogue = dplyr::mutate(catalogue, id = replace(id, 2, id[1]))
  ))
  expect_error(
    veg_check_catalogue_valid(
      catalogue = dplyr::mutate(
        catalogue,
        message_template = replace(message_template, 1, "{nope}")
      )
    ),
    "placeholder"
  )
  expect_error(
    veg_check_catalogue_valid(
      catalogue = dplyr::mutate(
        catalogue,
        fun = replace(fun, 1, "veg_chk_missing")
      )
    ),
    "no function"
  )
  expect_error(veg_check_catalogue_valid(
    catalogue = dplyr::mutate(
      catalogue,
      who_can_resolve = replace(who_can_resolve, 1, "somebody")
    )
  ))
})

test_that("every catalogue row cites an SOP or the ODK data rule and names its columns", {
  expect_true(all(grepl(
    pattern = "SOP|ODK data rule",
    x = catalogue$sop_reference
  )))
  expect_true(all(nchar(catalogue$columns) > 0))
})

test_that("the flags checks accept a good table and refuse each kind of damage", {
  flags <- veg_build_flags(
    ctx = failing_cases[["CON-03"]](make_clean_ctx()),
    catalogue = catalogue
  )
  expect_no_error(veg_check_flags(flags = flags, catalogue = catalogue))
  expect_error(veg_check_flags(
    flags = dplyr::select(flags, -message),
    catalogue = catalogue
  ))
  expect_error(veg_check_flags(
    flags = dplyr::mutate(flags, severity = "fatal"),
    catalogue = catalogue
  ))
  expect_error(
    veg_check_flags(
      flags = dplyr::mutate(flags, check_id = "ZZZ-99"),
      catalogue = catalogue
    ),
    "not in the catalogue"
  )
  expect_error(
    veg_check_flags(
      flags = dplyr::mutate(flags, severity = "info"),
      catalogue = catalogue
    ),
    "differs from the catalogue"
  )
  expect_error(
    veg_check_flags(
      flags = dplyr::bind_rows(flags, dplyr::mutate(flags, flag_id = "F99999")),
      catalogue = catalogue
    ),
    "duplicate"
  )
  expect_error(veg_check_flags(
    flags = dplyr::mutate(flags, message = ""),
    catalogue = catalogue
  ))
  expect_error(veg_check_flags(
    flags = dplyr::bind_rows(flags, flags),
    catalogue = catalogue
  ))
})

test_that("reconciliation passes on matching counts and fails on any difference", {
  flags <- veg_build_flags(
    ctx = failing_cases[["SPE-08"]](make_clean_ctx()),
    catalogue = catalogue
  )
  counts <- veg_flag_counts(flags = flags, catalogue = catalogue)
  expect_no_error(veg_check_flags_reconcile(
    flags = flags,
    catalogue = catalogue,
    counts = counts
  ))
  expect_identical(counts$n_flags[counts$check_id == "SPE-08"], 2L)
  wrong <- dplyr::mutate(
    counts,
    n_flags = replace(n_flags, check_id == "SPE-08", 1L)
  )
  expect_error(
    veg_check_flags_reconcile(
      flags = flags,
      catalogue = catalogue,
      counts = wrong
    ),
    "reconcile"
  )
  expect_error(
    veg_check_flags_reconcile(
      flags = flags[-1, ],
      catalogue = catalogue,
      counts = counts
    ),
    "reconcile"
  )
})

# ---- Issues for the field teams -------------------------------------------------

test_that("the field list holds errors and warnings only, with action and SOP section", {
  ctx <- failing_cases[["SPE-03"]](failing_cases[["CON-03"]](make_clean_ctx()))
  flags <- veg_build_flags(ctx = ctx, catalogue = catalogue)
  issues <- veg_field_issues(
    flags = flags,
    catalogue = catalogue,
    quadrat = ctx$quadrat
  )
  expect_identical(names(issues), veg_field_issue_columns)
  expect_true(all(is.element(issues$severity, c("error", "warning"))))
  expect_identical(
    nrow(issues),
    sum(is.element(flags$severity, c("error", "warning")))
  )
  expect_true("CON-03" %in% issues$check_id)
  expect_false("SPE-03" %in% issues$check_id)
  expect_true(all(nchar(issues$what_to_check) > 0))
  expect_identical(issues$quadrat[issues$check_id == "CON-03"], "1")
})

test_that("flags of a rejected submission stay in the flags but are off the field list", {
  ctx <- failing_cases[["CON-03"]](make_clean_ctx())
  flags <- veg_build_flags(ctx = ctx, catalogue = catalogue)
  key <- unique(flags$survey_key[is.element(
    flags$severity,
    c("error", "warning")
  )])
  expect_gt(length(key), 0)
  kept <- veg_field_issues(
    flags = flags,
    catalogue = catalogue,
    quadrat = ctx$quadrat
  )
  dropped <- veg_field_issues(
    flags = flags,
    catalogue = catalogue,
    quadrat = ctx$quadrat,
    rejected_keys = key
  )
  expect_gt(nrow(kept), 0)
  expect_identical(nrow(dropped), 0L)
  # a key that matches nothing changes nothing
  other <- veg_field_issues(
    flags = flags,
    catalogue = catalogue,
    quadrat = ctx$quadrat,
    rejected_keys = "uuid:none"
  )
  expect_identical(nrow(other), nrow(kept))
  expect_error(veg_field_issues(
    flags = flags,
    catalogue = catalogue,
    quadrat = ctx$quadrat,
    rejected_keys = NA_character_
  ))
})

test_that("the field list is empty, not an error, when there are no errors or warnings", {
  flags <- veg_build_flags(ctx = make_clean_ctx(), catalogue = catalogue)
  issues <- veg_field_issues(
    flags = flags,
    catalogue = catalogue,
    quadrat = make_clean_ctx()$quadrat
  )
  expect_identical(nrow(issues), 0L)
  expect_identical(names(issues), veg_field_issue_columns)
})

test_that("a padded reused label is reported once per submission, whatever the number of quadrats", {
  ctx <- add_species_row(
    ctx = make_clean_ctx(),
    q = 1,
    name = "Zeta omega ",
    mode = "reuse_missing",
    uuid = "u1"
  )
  ctx <- add_species_row(
    ctx = ctx,
    q = 2,
    name = "Zeta omega ",
    mode = "reuse_missing",
    uuid = "u1"
  )
  flags <- veg_chk_spe12(ctx = ctx)
  expect_identical(nrow(flags), 1L)
  expect_true(is.na(flags$quadrat_key))
})

test_that("flag rows and geometry parsing handle empty and incomplete input", {
  expect_identical(nrow(veg_flag_rows()), 0L)
  expect_identical(
    names(veg_flag_rows()),
    c("survey_key", "quadrat_key", "value", "detail")
  )
  geometry <- veg_parse_geometry(
    x = c("0.2 37.4 990.8 3.6", "0.2 37.4 990.8", NA)
  )
  expect_identical(geometry$accuracy, c(3.6, NA, NA))
  expect_identical(geometry$lat, c(0.2, 0.2, NA))
})
