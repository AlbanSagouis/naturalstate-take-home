# Tests for R/functions/veg_taxa.R (issues #8 and #9)

test_that("names are classified and normalised only for harmless typing differences", {
  out <- veg_classify_names(
    x = c(
      "Alpha beta",
      " Alpha  beta ",
      "alpha_beta",
      "Pechuel-loeschea leubnitziae",
      "herb_017",
      "wood_002",
      "herb_104 (Justicia divaricata )",
      "herb_105 ( )",
      "123e4567-e89b-42d3-a456-426614174000",
      NA,
      "  "
    )
  )
  expect_equal(
    out$taxon[1:4],
    c("Alpha_beta", "Alpha_beta", "Alpha_beta", "Pechuel-loeschea_leubnitziae")
  )
  expect_equal(
    out$taxon_class,
    c(
      "identified",
      "identified",
      "identified",
      "identified",
      "placeholder",
      "placeholder",
      "identified",
      "placeholder",
      "uuid_text",
      "unnamed",
      "unnamed"
    )
  )
  expect_equal(out$taxon[7], "Justicia_divaricata")
  expect_equal(
    out$unknown_label[c(5, 6, 8, 9)],
    c(
      "herb_017",
      "wood_002",
      "herb_105",
      "123e4567-e89b-42d3-a456-426614174000"
    )
  )
  expect_true(all(is.na(out$taxon[out$taxon_class != "identified"])))
  # A misspelling is not harmless: it stays a different taxon
  expect_false(identical(
    veg_classify_names(x = "Brachiara dura")$taxon,
    veg_classify_names(x = "Brachiaria dura")$taxon
  ))
  expect_error(veg_classify_names(x = 1), "character")
})

test_that("records keep every species row and refuse orphans", {
  species_long <- tibble(
    source = c("selected_list", "additional_repeat"),
    survey_key = c("s1", "s1"),
    quadrat_key = c("q1", "q1"),
    species_name = c("Alpha beta", "herb_001")
  )
  records <- veg_record_taxa(species_long = species_long)
  expect_equal(nrow(records), 2)
  expect_equal(records$taxon, c("Alpha_beta", NA))
  species_long$survey_key[1] <- NA
  expect_error(veg_record_taxa(species_long = species_long), "missing")
})

test_that("a placeholder with a proposed name is recognised whatever its case", {
  out <- veg_classify_names(
    x = c("Herb_104 (Justicia divaricata)", "herb_104 (Justicia divaricata)")
  )
  expect_equal(out$taxon, rep(x = "Justicia_divaricata", times = 2))
  expect_equal(out$taxon_class, rep(x = "identified", times = 2))
})

test_that("typed misspellings are read as the name they look like, without changing the input", {
  records <- tibble(
    source = c("additional_repeat", "additional_repeat", "selected_list"),
    survey_key = "s1",
    quadrat_key = c("q1", "q2", "q3"),
    species_name = c(
      "herb_092 (Ipomea sinensis)",
      "Brachiara dura",
      "Alpha beta"
    )
  ) |>
    mutate(veg_classify_names(x = species_name))
  flags <- tibble(
    check_id = c("SPE-06", "SPE-06", "SPE-02"),
    value = c("Ipomea sinensis", "Brachiara dura", "x"),
    message = c(
      "Quadrat 1: \"Ipomea sinensis\" looks like a misspelling of \"Ipomoea\".",
      "Quadrat 2: \"Brachiara dura\" looks like a misspelling of \"Brachiaria dura\".",
      "other"
    )
  )
  out <- veg_merge_misspellings(records = records, flags = flags)
  expect_equal(
    out$taxon,
    c("Ipomoea_sinensis", "Brachiaria_dura", "Alpha_beta")
  )
  # the input is untouched and without SPE-06 flags nothing changes
  expect_equal(records$taxon[2], "Brachiara_dura")
  expect_equal(
    veg_merge_misspellings(records = records, flags = flags[3, ])$taxon,
    records$taxon
  )
})
