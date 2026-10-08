---
name: r-code-style
description: Use when writing or reviewing R code — enforces Alban Sagouis's R style conventions (base pipe, stringi over stringr, explicit dplyr join safety, superseded-verb replacements, is.element/isTRUE preferences) and structural search with ast-grep's R support.
---

# R Code Style

Apply these conventions whenever writing or editing R code, and flag violations when reviewing it.

- **Pipe:** use the base R pipe `|>`, not `%>%`
- **is.element():** preferred over `%in%`
- **Selection:** use `[[]]` instead of `[]` where advantageous
- **Empty string:** `stringi::is_empty(x)` is preferred to `x == ""`
- **Logic:** use `isTRUE(x)` instead of `x == TRUE` for a single condition
  (`if ()`, `&&`, `||`). Never on a vector: `isTRUE()`, `any()` and `all()`
  all collapse it to one value, so `x[isTRUE(keep)]` selects nothing and
  raises no error. To select elements by a logical vector, subset by the
  vector itself, after asserting it has no NA
  (`checkmate::assert_logical(keep, any.missing = FALSE)`, then `x[keep]`).
- **Chunk names:** always give names to chunks in .Rmd and .qmd
- Use && and || where they make sense instead of & and |
- **Text manipulation:** stringi functions preferred over stringr
- **Grouping in dplyr:** use `.by = grouping_variable` instead of `dplyr::group_by(grouping_variable)` wherever possible
- **Argument names:** always write argument names explicitly in all function calls
- **Package namespacing:**
  - If a function from an external package is called **more than once** in a script or function: attach with `library(package_name)` (in scripts) or declare with `@importFrom package_name function_name` (in package documentation)
  - If a function is called **only once**: call it as `package_name::function_name()`
  - Exceptions: functions from packages cli and fs should always be called as package_name::function_name.
  - When using packages belonging to the tidyverse, load them independently instead of library(tidyverse).
- **Data quality checks:** write checks to ensure produced data quality is good and consistent over time — do not assume inputs are clean or outputs are immutable, better tested than sorry
- **Suppressing warnings/errors in tests:** `suppressWarnings()`, `suppressMessages()`, or `testthat::expect_no_error()`/`expect_no_warning()` are fine to use when a test's point is something else and an expected condition would otherwise clutter the output. But every suppression must be paired with a dedicated test asserting that the suppressed condition still fires as expected — `expect_warning(f(x), "expected message")` or `expect_condition(f(x), class = "my_warning_class")`. Suppressing without that sibling test hides regressions: if the condition's message, class, or trigger changes down the road, the suppressed test keeps passing and nothing catches the drift.
- **Joins:** always pass `relationship` and `unmatched` explicitly. Both
  default to silence, and both failure modes are the kind that corrupt a
  result without erroring: a duplicate key on the lookup side multiplies rows
  (and every sum computed downstream), an incomplete lookup fills columns with
  `NA`. `relationship = "many-to-one"` / `"one-to-one"` turns the first into a
  loud failure at the join, replacing a hand-written `anyDuplicated()` check.
  `unmatched = "error"` only guards the side that can lose rows, so whether it
  catches the `NA` fill depends on the verb (see the `left_join()` caveat
  below). Where a fan-out or a drop is genuinely
  intended, still say so — `relationship = "many-to-many"`,
  `unmatched = "drop"` — so a reader sees a decision rather than an omission.
  Which verb takes what (dplyr 1.2.1, verified):
  - `left_join()` / `right_join()` / `nest_join()`: both. `unmatched` is
    length 1 and applies to the side that can lose rows — `y` for
    `left_join()`, `x` for `right_join()`.
  - `inner_join()`: both, and `unmatched` may be length 2, named
    `c(x = , y = )`, since either side can lose rows.
  - `full_join()`: `relationship` only — nothing can be dropped, so passing
    `unmatched` is an error.
  - `semi_join()` / `anti_join()`: neither; they take no `...`. Reach for
    them when the intent is filtering, not joining.
  Caveat, verified in dplyr 1.2.1: to make "every row of `x` must find its
  lookup row" a loud failure, `left_join(unmatched = "error")` is **not**
  enough. It only errors on `y` keys that `x` never uses, and it silently
  keeps an unmatched `x` row with `NA`. Use `inner_join(..., relationship =
  "many-to-one", unmatched = c(x = "error", y = "drop"))` instead: it errors
  on an `x` key missing from the lookup, tolerates extra lookup rows, and
  keeps the row order of `x`. (Or `left_join()` followed by an explicit
  `anyNA()` check on the looked-up column.)
  Use `join_by()` over a character vector whenever the join is non-equi
  (`>=`, `between()`, `overlaps()`), rolling (`closest()`), needs `x$`/`y$`
  disambiguation, or matches differently-named columns — `join_by(local ==
  site)` reads in the natural order, whereas `by = c("local" = "site")` is a
  named vector whose direction is easy to reverse. For plain equality on
  identically-named columns the two are identical; switching is style only.
- **Superseded verbs:** `dplyr::transmute()` is superseded — do not use it.
  The replacement is not a rename: `mutate(.keep = "none")` keeps pre-existing
  columns in their *original* position, whereas `transmute()` reorders to
  argument order, so a bare swap silently scrambles output column order.
  Prefer `mutate(<only new/computed columns>) |> select(<explicit schema, with
  renames>)` — one `mutate()` for columns that don't come from a column
  (constants, scalars from the enclosing scope), then `select()` to declare the
  renames and the output order in one visible place. Identity self-assignments
  (`year = year`) disappear. There is no performance difference between
  `select()`, `rename()`, `mutate()` and `transmute()` here: none of them copy
  column data, only the column list is rebuilt (verified by address identity),
  so choose on clarity, not speed.
- **Counting distinct values:** `dplyr::n_distinct(x)` instead of
  `length(unique(x))`.
- **Recoding values:** `dplyr::case_match()` was deprecated in dplyr 1.2.0.
  ℹ Please use `dplyr::recode_values()` instead. Yes for real. Use it. Here is its definition:
  ```
  Recode_values() and replace_values() provide two ways to map old values to new values. They work by matching values against x and using the first match to determine the corresponding value in the output vector. You can also think of these functions as a way to use a lookup table to recode a vector.
  Use recode_values() when creating an entirely new vector.
  Use replace_values() when partially updating an existing vector.
  If you are just replacing a few values within an existing vector, then replace_values() is always a better choice because it is type stable and better expresses intent.
  A major difference between the two functions is what happens when no cases match:
  recode_values() falls through to a default.
  replace_values() retains the original values from x.
  recode_values(x, from1 ~ to1, from2 ~ to2), similar to case_when(), which is useful when you have a small number of cases.
  ```

## ast-grep with R support
Structural (AST-based) code search, faster and more precise than regex for syntax-shaped queries. R support configured globally via `~/.config/ast-grep/sgconfig.yml`.

```bash
sg -l r -p 'pattern' .
```

Metavariables: `_VAR` for named captures, `___` for wildcards — not `$VAR` (R uses `$` for column access). Bare `_` is invalid: it doesn't error, it just silently matches nothing.
