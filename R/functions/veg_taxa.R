# Species identity: which records are identified taxa and which are provisional unknowns
# (issue #8, used by the plot-diversity check, and #9, used by the summaries).
#
# Species identity rule (provisional, see rulebook_vegetation.md):
#   identified taxon   = a name from the species list, or a typed name, after
#                        harmless typing differences are removed (outer and double
#                        spaces, spaces to underscores, capital first letter), and
#                        "herb_104 (Genus species)" read as its proposed name;
#   provisional unknown = herb_NNN / wood_NNN placeholders, raw UUID text and
#                        records without a name. Counted apart, never in richness.

#' Classify and normalise species names
#'
#' @param x Character vector of names as recorded.
#' @param config Rule values (`unknown_label_regex`, `uuid_regex`).
#' @return Tibble with one row per element of `x`: `taxon` (normalised name,
#'   NA for unknowns), `taxon_class` (identified, placeholder, uuid_text or
#'   unnamed) and `unknown_label` (the placeholder or UUID, NA otherwise).
veg_classify_names <- function(x, config = veg_config) {
  checkmate::assert_character(x = x)
  clean <- x |>
    stringi::stri_trim_both() |>
    stringi::stri_replace_all_regex(pattern = "\\s+", replacement = " ")
  clean[!is.na(clean) & stringi::stri_isempty(str = clean)] <- NA_character_
  lower <- stringi::stri_trans_tolower(str = clean)

  is_unnamed <- is.na(clean)
  is_uuid <- !is_unnamed &
    stringi::stri_detect_regex(str = lower, pattern = config$uuid_regex)
  is_bare <- !is_unnamed &
    !is_uuid &
    stringi::stri_detect_regex(
      str = lower,
      pattern = config$unknown_label_regex
    )
  # "herb_104 (Justicia divaricata )": a placeholder that carries a proposed name
  inner <- stringi::stri_match_first_regex(
    str = clean,
    pattern = "(?i)^((?:herb|wood)_[0-9]+) \\((.*)\\)$"
  )
  inner_name <- stringi::stri_trim_both(str = inner[, 3])
  is_named_placeholder <- !is_unnamed &
    !is_uuid &
    !is_bare &
    !is.na(inner_name) &
    !stringi::stri_isempty(str = inner_name)
  is_empty_placeholder <- !is_unnamed &
    !is_uuid &
    !is_bare &
    !is.na(inner[, 1]) &
    !is_named_placeholder

  name <- clean
  name[is_named_placeholder] <- inner_name[is_named_placeholder]
  name <- stringi::stri_replace_all_fixed(
    str = name,
    pattern = " ",
    replacement = "_"
  )
  name <- paste0(
    stringi::stri_trans_toupper(
      str = stringi::stri_sub(str = name, from = 1, length = 1)
    ),
    stringi::stri_sub(str = name, from = 2)
  )

  taxon_class <- rep(x = "identified", times = length(x))
  taxon_class[is_unnamed] <- "unnamed"
  taxon_class[is_uuid] <- "uuid_text"
  taxon_class[is_bare | is_empty_placeholder] <- "placeholder"
  unknown <- !is.element(el = taxon_class, set = "identified")
  label <- rep(x = NA_character_, times = length(x))
  label[is_bare] <- lower[is_bare]
  label[is_empty_placeholder] <- stringi::stri_trans_tolower(
    str = inner[is_empty_placeholder, 2]
  )
  label[is_uuid] <- lower[is_uuid]
  name[unknown] <- NA_character_
  tibble(taxon = name, taxon_class = taxon_class, unknown_label = label)
}

#' One row per species record (selected from the list or typed), with its taxon
#'
#' @param species_long Staged long species table (veg_species_long).
#' @return Tibble: source, survey_key, quadrat_key, species_name (as recorded),
#'   taxon, taxon_class, unknown_label.
veg_record_taxa <- function(species_long, config = veg_config) {
  checkmate::assert_data_frame(x = species_long)
  checkmate::assert_names(
    x = names(species_long),
    must.include = c("source", "survey_key", "quadrat_key", "species_name")
  )
  # An orphan record cannot be placed in a survey, so no summary could count it
  checkmate::assert_character(x = species_long$survey_key, any.missing = FALSE)
  checkmate::assert_character(x = species_long$quadrat_key, any.missing = FALSE)
  species_long |>
    select(source, survey_key, quadrat_key, species_name) |>
    bind_cols(veg_classify_names(
      x = species_long$species_name,
      config = config
    ))
}
