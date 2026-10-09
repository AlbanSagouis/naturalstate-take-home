test_that("veg_assert_columns aborts on a missing column and passes otherwise", {
  d <- tibble(a = 1, b = 2)
  expect_invisible(veg_assert_columns(
    data = d,
    required = c("a", "b"),
    label = "d"
  ))
  expect_error(
    veg_assert_columns(data = d, required = c("a", "z"), label = "d"),
    "missing required column"
  )
})

test_that("veg_check_missing flags blank and whitespace-only keys, not valid ones", {
  d <- tibble(KEY = c("a", NA, "  ", "b"))
  r <- veg_check_missing(data = d, column = "KEY", table = "t")
  expect_equal(r$summary$n_problem, 2L)
  expect_equal(r$findings$record_key, c("row_2", "row_3"))
  ok <- veg_check_missing(
    data = tibble(KEY = c("a", "b")),
    column = "KEY",
    table = "t"
  )
  expect_equal(ok$summary$n_problem, 0L)
  expect_equal(nrow(ok$findings), 0)
})

test_that("veg_check_duplicated flags every copy of a duplicated key", {
  r <- veg_check_duplicated(
    data = tibble(KEY = c("a", "b", "a", NA, NA)),
    column = "KEY",
    table = "t"
  )
  expect_equal(r$summary$n_problem, 2L)
  expect_equal(r$summary$n_checked, 3L)
  ok <- veg_check_duplicated(
    data = tibble(KEY = c("a", "b")),
    column = "KEY",
    table = "t"
  )
  expect_equal(ok$summary$n_problem, 0L)
})

test_that("veg_check_in_lookup reports orphans and splits multi-id cells", {
  d <- tibble(KEY = c("1", "2", "3"), P = c("a", "zz", NA))
  r <- veg_check_in_lookup(
    data = d,
    column = "P",
    lookup = c("a", "b"),
    table = "t",
    check = "c"
  )
  expect_equal(r$findings$value, "zz")
  expect_equal(r$findings$record_key, "2")
  expect_equal(r$summary$n_checked, 2L)
  multi <- tibble(KEY = "1", P = "a zz<br/>b")
  rm <- veg_check_in_lookup(
    data = multi,
    column = "P",
    lookup = c("a", "b"),
    table = "t",
    check = "c",
    split = TRUE
  )
  expect_equal(rm$summary$n_checked, 3L)
  expect_equal(rm$findings$value, "zz")
})

test_that("veg_check_no_children finds parents without child rows", {
  r <- veg_check_no_children(
    parent = tibble(KEY = c("a", "b")),
    child_parent_values = c("a", "a"),
    table = "t",
    check = "c"
  )
  expect_equal(r$findings$record_key, "b")
  ok <- veg_check_no_children(
    parent = tibble(KEY = "a"),
    child_parent_values = "a",
    table = "t",
    check = "c"
  )
  expect_equal(ok$summary$n_problem, 0L)
})

test_that("veg_check_flag_children catches both directions of disagreement", {
  d <- tibble(KEY = c("a", "b", "c"), flag = c("yes", "yes", "no"))
  yes_no_rows <- veg_check_flag_children(
    data = d,
    flag_column = "flag",
    child_parent_values = "a",
    expect_children = TRUE,
    table = "t",
    check = "c"
  )
  expect_equal(yes_no_rows$findings$record_key, "b")
  rows_no_yes <- veg_check_flag_children(
    data = d,
    flag_column = "flag",
    child_parent_values = c("a", "c"),
    expect_children = FALSE,
    table = "t",
    check = "c"
  )
  expect_equal(rows_no_yes$findings$record_key, "c")
})

test_that("veg_check_pattern flags malformed UUIDs", {
  d <- tibble(KEY = "1", U = paste(uuid_a, "not-a-uuid"))
  r <- veg_check_pattern(
    data = d,
    column = "U",
    pattern = "^[0-9a-f]{8}-",
    table = "t",
    check = "c",
    split = TRUE
  )
  expect_equal(r$findings$value, "not-a-uuid")
  expect_equal(r$summary$n_checked, 2L)
  ok <- veg_check_pattern(
    data = d[0, ],
    column = "U",
    pattern = "^x",
    table = "t",
    check = "c",
    split = TRUE
  )
  expect_equal(ok$summary$n_problem, 0L)
})

test_that("veg_check_numeric flags non-numeric text and ignores blanks", {
  d <- tibble(KEY = c("a", "b", "c"), x = c("1.5", "abc", NA))
  r <- veg_check_numeric(data = d, columns = "x", table = "t")
  expect_equal(r$findings$record_key, "b")
  expect_equal(r$findings$column, "x")
  expect_equal(r$summary$n_checked, 2L)
  ok <- veg_check_numeric(data = d[c(1, 3), ], columns = "x", table = "t")
  expect_equal(ok$summary$n_problem, 0L)
})

test_that("veg_check_geopoint flags missing and out-of-range points", {
  d <- tibble(
    KEY = c("a", "b", "c"),
    lat = c("0.5", NA, "95"),
    lon = c("37", "37", "37")
  )
  r <- veg_check_geopoint(
    data = d,
    latitude = "lat",
    longitude = "lon",
    table = "t",
    prefix = "gp"
  )
  expect_equal(r[[1]]$findings$record_key, "b")
  expect_equal(r[[2]]$findings$record_key, "c")
  expect_equal(r[[1]]$summary$check, "gp_missing")
  # longitude has its own limit (180), and a point at the limits is valid
  edge <- tibble(
    KEY = c("a", "b", "c"),
    lat = c("90", "0", "0"),
    lon = c("180", "181", "-181")
  )
  e <- veg_check_geopoint(
    data = edge,
    latitude = "lat",
    longitude = "lon",
    table = "t",
    prefix = "gp"
  )
  expect_equal(e[[2]]$findings$record_key, c("b", "c"))
  expect_equal(e[[1]]$summary$n_problem, 0L)
})

test_that("veg_bind_checks stacks summaries and findings", {
  a <- veg_check_result(
    table = "t",
    check = "a",
    n_checked = 3,
    record_key = "k",
    column = "x",
    value = "v"
  )
  b <- veg_check_result(table = "t", check = "b", n_checked = 5)
  out <- veg_bind_checks(results = list(a, b))
  expect_equal(out$integrity$n_problem, c(1L, 0L))
  expect_equal(nrow(out$findings), 1)
  expect_error(veg_bind_checks(results = list()))
})

test_that("data errors in the synthetic tables never abort the checks", {
  v <- make_veg()
  v$quadrat$PARENT_KEY[3] <- "uuid:ghost"
  expect_no_error(
    r <- veg_check_in_lookup(
      data = v$quadrat,
      column = "PARENT_KEY",
      lookup = v$survey$KEY,
      table = "quadrat",
      check = "orphan"
    )
  )
  expect_equal(r$summary$n_problem, 1L)
})

test_that("id cells split on any whitespace, including non-breaking spaces and line breaks, and on <br/>", {
  nbsp <- "\u00a0"
  data <- tibble(
    KEY = c("a", "b", "c"),
    ids = c(paste0("u1", nbsp, "u2"), "u3\nu4\tu5", "u6<br/>u7")
  )
  tokens <- veg_tokens(data = data, column = "ids", split = TRUE)
  expect_identical(tokens$token, paste0("u", 1:7))
  expect_identical(tokens$row, c(1L, 1L, 2L, 2L, 2L, 3L, 3L))
  # Without splitting the cell stays one token
  expect_identical(
    nrow(veg_tokens(data = data, column = "ids", split = FALSE)),
    3L
  )
})

test_that("blank means NA, empty or whitespace only (non-breaking space included), nothing else", {
  nbsp <- "\u00a0"
  expect_identical(
    veg_is_blank(x = c(NA, "", " ", nbsp, "\n", "x", paste0(nbsp, "x"))),
    c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE)
  )
  expect_identical(
    veg_record_key(data = tibble(KEY = c("a", NA, " "))),
    c("a", "row_2", "row_3")
  )
})
