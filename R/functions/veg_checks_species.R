# Species checks (SPE-xx). `species_long` has one row per species record:
# `selected_list` rows picked from the species list, `additional_repeat` rows
# from the additional-species repeat. The text typed by the team is in
# `new_missing_canonical` (entry mode new_missing); `species_name` is what the
# form built from it, e.g. "herb_104 (Justicia divaricata )".

veg_additional_rows <- function(ctx) {
  ctx$species_long[ctx$species_long$source == "additional_repeat", ]
}

# One flag per quadrat and value, whatever the number of identical rows
veg_species_flags <- function(rows, value) {
  rows$value_out <- value
  rows <- distinct(
    .data = rows,
    survey_key,
    quadrat_key,
    value_out,
    .keep_all = TRUE
  )
  veg_flag_rows(
    survey_key = rows$survey_key,
    quadrat_key = rows$quadrat_key,
    value = rows$value_out
  )
}

# SPE-01: A selected species id that does not resolve to the species list.
veg_chk_spe01 <- function(ctx, config = veg_config) {
  sl <- ctx$species_long
  bad <- sl[sl$source == "selected_list" & is.na(sl$species_name), ]
  veg_species_flags(rows = bad, value = bad$species_uuid)
}

# SPE-02: A typed species name not in the Genus_species format.
# The typed text is the only free text; reused
# entity labels are checked when they were typed.
veg_chk_spe02 <- function(ctx, config = veg_config) {
  add <- veg_additional_rows(ctx = ctx)
  typed <- add[!veg_is_blank(x = add$new_missing_canonical), ]
  bad <- typed[
    !stringi::stri_detect_regex(
      str = typed$new_missing_canonical,
      pattern = config$species_name_regex
    ),
  ]
  veg_species_flags(rows = bad, value = bad$new_missing_canonical)
}

# SPE-03: A provisional unknown species (herb_NNN) that needs a voucher and later identification.
veg_chk_spe03 <- function(ctx, config = veg_config) {
  add <- veg_additional_rows(ctx = ctx)
  bad <- add[
    !is.na(add$species_name) &
      stringi::stri_detect_regex(
        str = add$species_name,
        pattern = config$unknown_label_regex
      ),
  ]
  veg_species_flags(rows = bad, value = bad$species_name)
}

# SPE-04: A species name that is a raw identifier (UUID) instead of a name.
veg_chk_spe04 <- function(ctx, config = veg_config) {
  add <- veg_additional_rows(ctx = ctx)
  text <- coalesce(add$new_missing_canonical, add$species_name)
  is_uuid <- !is.na(text) &
    stringi::stri_detect_regex(
      str = stringi::stri_trim_both(str = text),
      pattern = config$uuid_regex
    )
  veg_species_flags(rows = add[is_uuid, ], value = text[is_uuid])
}

# SPE-05: Leading or trailing white space in a typed name or a listed species label.
# Leading or trailing white space in the text a team member typed, or in the
# label of a species picked from the species list
veg_chk_spe05 <- function(ctx, config = veg_config) {
  sl <- ctx$species_long
  text <- if_else(
    condition = sl$source == "selected_list",
    true = sl$species_name,
    false = sl$new_missing_canonical
  )
  bad <- !is.na(text) & text != stringi::stri_trim_both(str = text)
  veg_species_flags(rows = sl[bad, ], value = paste0("\"", text[bad], "\""))
}

# Typed names one or two letters away from a name on the species list
veg_misspelling_matches <- function(typed, listed, max_distance, max_relative) {
  typed_n <- veg_normalise_name(x = typed)
  listed_n <- unique(veg_normalise_name(x = listed))
  listed_n <- listed_n[!is.na(listed_n)]
  out <- tibble(
    typed = typed,
    suggestion = NA_character_,
    distance = NA_real_
  )
  if (length(typed) == 0 || length(listed_n) == 0) {
    return(out)
  }
  distances <- utils::adist(x = typed_n, y = listed_n)
  best <- apply(X = distances, MARGIN = 1, FUN = which.min)
  out$distance <- distances[cbind(seq_along(typed), best)]
  out$suggestion <- listed_n[best]
  limit <- pmin(max_distance, floor(max_relative * nchar(typed_n)))
  # distance 0 is an exact match (SPE-09), not a misspelling
  out$suggestion[!(out$distance > 0 & out$distance <= limit)] <- NA_character_
  out
}

# SPE-06: A typed name that is probably a misspelling of a listed name or genus.
# Whole name within the edit-distance limit of a listed name, or a genus
# spelled one letter off a listed genus (Ipomea for Ipomoea), when the genus
# itself is not on the list.
veg_chk_spe06 <- function(ctx, config = veg_config) {
  add <- veg_additional_rows(ctx = ctx)
  typed <- add[!veg_is_blank(x = add$new_missing_canonical), ]
  whole <- veg_misspelling_matches(
    typed = typed$new_missing_canonical,
    listed = ctx$species$label,
    max_distance = config$misspelling_max_distance,
    max_relative = config$misspelling_max_relative
  )$suggestion
  genus <- function(x) {
    stringi::stri_extract_first_regex(
      str = veg_normalise_name(x = x),
      pattern = "^[^ ]+"
    )
  }
  listed_genera <- unique(genus(x = ctx$species$label))
  listed_genera <- listed_genera[!is.na(listed_genera)]
  typed_genus <- genus(x = typed$new_missing_canonical)
  near_genus <- rep(x = NA_character_, times = length(typed_genus))
  if (length(typed_genus) > 0 && length(listed_genera) > 0) {
    distances <- utils::adist(x = typed_genus, y = listed_genera)
    best <- apply(X = distances, MARGIN = 1, FUN = which.min)
    close <- distances[cbind(seq_along(typed_genus), best)] == 1 &
      nchar(typed_genus) >= config$misspelling_min_genus_length
    near_genus[close] <- listed_genera[best][close]
  }
  suggestion <- coalesce(whole, near_genus)
  # Show the suggestion the way the list writes it (capital first letter)
  suggestion <- paste0(
    stringi::stri_trans_toupper(
      str = stringi::stri_sub(str = suggestion, from = 1, length = 1)
    ),
    stringi::stri_sub(str = suggestion, from = 2)
  )
  suggestion[is.na(whole) & is.na(near_genus)] <- NA_character_
  bad <- !is.na(suggestion)
  rows <- typed[bad, ]
  rows$value_out <- stringi::stri_trim_both(str = rows$new_missing_canonical)
  rows$detail_out <- suggestion[bad]
  rows <- distinct(
    .data = rows,
    survey_key,
    quadrat_key,
    value_out,
    .keep_all = TRUE
  )
  veg_flag_rows(
    survey_key = rows$survey_key,
    quadrat_key = rows$quadrat_key,
    value = rows$value_out,
    detail = rows$detail_out
  )
}

# SPE-07: A name both picked from the list and typed or reused in the same quadrat.
veg_chk_spe07 <- function(ctx, config = veg_config) {
  sl <- ctx$species_long
  sl$name_key <- veg_normalise_name(x = sl$species_name)
  selected <- sl[
    sl$source == "selected_list" & !is.na(sl$name_key),
    c("quadrat_key", "name_key")
  ]
  add <- sl[sl$source == "additional_repeat" & !is.na(sl$name_key), ]
  bad <- add[
    is.element(
      el = paste(add$quadrat_key, add$name_key),
      set = paste(selected$quadrat_key, selected$name_key)
    ),
  ]
  veg_species_flags(rows = bad, value = bad$name_key)
}

# SPE-08: The same new species name typed as new more than once.
veg_chk_spe08 <- function(ctx, config = veg_config) {
  add <- veg_additional_rows(ctx = ctx)
  typed <- add[!veg_is_blank(x = add$new_missing_canonical), ]
  key <- veg_normalise_name(x = typed$new_missing_canonical)
  bad <- typed[is.element(el = key, set = key[duplicated(key)]), ]
  veg_species_flags(
    rows = bad,
    value = stringi::stri_trim_both(str = bad$new_missing_canonical)
  )
}

# SPE-09: A typed name that is already on the species list.
veg_chk_spe09 <- function(ctx, config = veg_config) {
  add <- veg_additional_rows(ctx = ctx)
  typed <- add[!veg_is_blank(x = add$new_missing_canonical), ]
  key <- veg_normalise_name(x = typed$new_missing_canonical)
  bad <- typed[
    is.element(el = key, set = veg_normalise_name(x = ctx$species$label)),
  ]
  veg_species_flags(
    rows = bad,
    value = stringi::stri_trim_both(str = bad$new_missing_canonical)
  )
}

# SPE-10: A reused extra-species id that does not resolve to the extra-species list.
veg_chk_spe10 <- function(ctx, config = veg_config) {
  add <- veg_additional_rows(ctx = ctx)
  bad <- add[
    !veg_is_blank(x = add$species_uuid) &
      !is.element(el = add$species_uuid, set = ctx$species_extra$`__id`),
  ]
  veg_species_flags(rows = bad, value = bad$species_uuid)
}

# SPE-11: An additional-species row with no name.
veg_chk_spe11 <- function(ctx, config = veg_config) {
  add <- veg_additional_rows(ctx = ctx)
  bad <- add[veg_is_blank(x = add$species_name), ]
  veg_species_flags(rows = bad, value = bad$record_id)
}

# SPE-12: A reused extra-species label with a leading or trailing space.
# A reused label from the extra-species list carries a leading or trailing
# space. The defect sits in the entity list (one fix there), not in each
# quadrat, so it is reported once per submission and label.
veg_chk_spe12 <- function(ctx, config = veg_config) {
  add <- veg_additional_rows(ctx = ctx)
  reused <- !is.na(add$species_entry_mode) &
    stringi::stri_startswith_fixed(
      str = add$species_entry_mode,
      pattern = "reuse"
    )
  bad <- reused &
    !is.na(add$species_name) &
    add$species_name != stringi::stri_trim_both(str = add$species_name)
  rows <- add[bad, ]
  rows$quadrat_key <- NA_character_
  veg_species_flags(rows = rows, value = paste0("\"", rows$species_name, "\""))
}
