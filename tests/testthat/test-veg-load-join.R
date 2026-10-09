build_all <- function(v = make_veg()) {
  survey <- veg_build_survey(
    survey = v$survey,
    register = v$register,
    vegplots = v$vegplots,
    surveys = v$surveys,
    project_team = v$project_team,
    transport = v$transport
  )
  quadrat <- veg_build_quadrat(
    quadrat = v$quadrat,
    survey = survey,
    additional = v$additional
  )
  long <- veg_build_species_long(
    quadrat = v$quadrat,
    additional = v$additional,
    species = v$species
  )
  list(survey = survey, quadrat = quadrat, long = long)
}

test_that("veg_to_numeric converts numbers and refuses text without warning", {
  expect_no_warning(out <- veg_to_numeric(x = c("1.5", "-2", "abc", NA, "1e3")))
  expect_equal(out, c(1.5, -2, NA, NA, 1000))
})

test_that("veg_read_csv reads text, keeps blanks as NA and aborts on problems", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(text = c("KEY,x", "a,1", "b,"), con = path)
  out <- veg_read_csv(path = path, required = "KEY")
  expect_equal(out$x, c("1", NA))
  expect_error(
    veg_read_csv(path = path, required = "nope"),
    "missing required column"
  )
  expect_error(veg_read_csv(path = "no_such_file.csv"), "file not found")
})

test_that("survey join keeps every row and order, with lookups filled", {
  out <- build_all()$survey
  expect_equal(out$KEY, c("uuid:s1", "uuid:s2"))
  expect_equal(out$vegplots_plot_status, c("primary", "primary"))
  expect_equal(out$register_KEY, c("uuid:r1", "uuid:r1"))
  expect_equal(out$team_choice_names, c("Aa_Aa; Bb_Bb", "Aa_Aa"))
  expect_equal(out$transport_choice_status, c("active", "active"))
})

test_that("survey join keeps a survey whose plot is unknown (NA, not dropped)", {
  v <- make_veg()
  v$survey[["plot_selection-selected_plot_uuid"]][2] <- "ghost"
  out <- build_all(v)$survey
  expect_equal(nrow(out), 2)
  expect_equal(is.na(out$vegplots_plot_uuid), c(FALSE, TRUE))
})

test_that("survey join fails loudly when a lookup key is duplicated", {
  v <- make_veg()
  v$vegplots <- bind_rows(v$vegplots, v$vegplots)
  expect_error(build_all(v), "must match at most 1 row")
})

test_that("unresolved team members keep their UUID", {
  v <- make_veg()
  v$survey[["field_team_specifics-selected_project_team_uuid_multi"]][
    2
  ] <- "t1 zz"
  expect_equal(build_all(v)$survey$team_choice_names[2], "Aa_Aa; zz")
})

test_that("quadrat table keeps all quadrats, counts children, shows orphans", {
  out <- build_all()$quadrat
  expect_equal(nrow(out), 3)
  expect_equal(out$n_additional_rows, c(2L, 0L, 1L))
  expect_equal(out$survey_plot_name, rep(x = "Plot_1", times = 3))
  v <- make_veg()
  v$quadrat$PARENT_KEY[3] <- "uuid:ghost"
  orphan <- build_all(v)$quadrat
  expect_equal(nrow(orphan), 3)
  expect_true(is.na(orphan$survey_plot_name[3]))
})

test_that("long species table has one row per record and resolves UUIDs", {
  out <- build_all()$long
  expect_equal(nrow(out), 3 + 3)
  expect_equal(sum(out$source == "selected_list"), 3)
  expect_equal(
    out$species_name[out$source == "selected_list"],
    c("Alpha beta", "Gamma delta", NA)
  )
  extra <- out[out$source == "additional_repeat", ]
  expect_equal(extra$species_name, c("herb_001", "Some plant", "Genus species"))
  expect_equal(extra$species_uuid, c("u1", NA, "m1"))
  expect_false(anyNA(out$survey_key))
})

test_that("orphan additional rows stay in the long table with NA survey", {
  v <- make_veg()
  v$additional$PARENT_KEY[1] <- "uuid:ghost"
  out <- build_all(v)$long
  expect_equal(nrow(out), 6)
  expect_equal(sum(is.na(out$survey_key)), 1)
})

test_that("cells with <br/> separators are split too", {
  v <- make_veg()
  v$quadrat[["herb_species-selected_herb_species_uuids"]][1] <- paste0(
    uuid_a,
    "<br/>",
    uuid_b
  )
  expect_equal(sum(build_all(v)$long$source == "selected_list"), 3)
})

test_that("the real pipeline output reconciles with the raw files", {
  paths <- veg_config_for_tests()$paths
  skip_if_not(all(fs::file_exists(c(
    paths$survey,
    paths$quadrat,
    paths$species_long
  ))))
  n_raw <- function(path) nrow(veg_read_csv(path = path))
  expect_equal(
    nrow(read_csv(paths$survey, show_col_types = FALSE)),
    n_raw(paths$odk$survey)
  )
  expect_equal(
    nrow(read_csv(paths$quadrat, show_col_types = FALSE)),
    n_raw(paths$odk$quadrat)
  )
  n_selected <- nrow(veg_tokens(
    data = veg_read_csv(path = paths$odk$quadrat),
    column = "herb_species-selected_herb_species_uuids",
    split = TRUE
  ))
  expect_equal(
    nrow(read_csv(paths$species_long, show_col_types = FALSE)),
    n_selected + n_raw(paths$odk$additional)
  )
})

test_that("the dictionary describes added columns, marks numeric columns and defaults raw ones", {
  table <- tibble(
    KEY = "a",
    `x-Latitude` = 1.5,
    `x-name` = "n",
    n_additional_rows = 0L
  )
  rows <- veg_dictionary_table(
    data = table,
    table = "t",
    numeric_columns = "x-Latitude"
  )
  meaning <- stats::setNames(object = rows$meaning, nm = rows$column)
  expect_match(meaning[["KEY"]], "primary key")
  expect_match(meaning[["x-Latitude"]], "read as a number")
  expect_identical(meaning[["x-name"]], veg_dictionary_default)
  expect_match(meaning[["n_additional_rows"]], "additional-species rows")
  # without the numeric list the same column is described as plain text
  plain <- veg_dictionary_table(data = table, table = "t")
  expect_identical(
    plain$meaning[plain$column == "x-Latitude"],
    veg_dictionary_default
  )
  expect_error(veg_dictionary_table(data = "not a table", table = "t"))
  # the findings columns have their own meaning, not the raw-column default
  findings <- veg_dictionary_table(
    data = tibble(
      table = "t",
      check = "c",
      record_key = "k",
      column = "x",
      value = "v"
    ),
    table = "veg_input_findings"
  )
  expect_false(any(findings$meaning == veg_dictionary_default))
})
