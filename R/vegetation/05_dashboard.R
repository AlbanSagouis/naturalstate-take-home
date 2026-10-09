# 05: render the dashboard (dashboard/dashboard.qmd) to docs/index.html. The only
# place Quarto is used; the dashboard reads the files written by 01 to 04 and
# runs no analysis. Run from the project root, after 04:
# Rscript R/vegetation/05_dashboard.R

source(file = here::here("R", "vegetation", "config.R"))
paths <- veg_config$paths

# Quarto starts its own R in dashboard/, which does not see the renv library
# (the project .Rprofile is only read from the project root): pass the library
# paths of this session on.
Sys.setenv(R_LIBS = paste(.libPaths(), collapse = ":"))
quarto::quarto_render(
  input = fs::path(paths$dashboard_dir, "dashboard.qmd"),
  output_file = "index.html",
  quiet = TRUE
)

# Quarto writes next to the source; GitHub Pages serves docs/
fs::dir_create(path = fs::path_dir(paths$dashboard_html))
fs::file_move(
  path = fs::path(paths$dashboard_dir, "index.html"),
  new_path = paths$dashboard_html
)
size_kb <- round(as.numeric(fs::file_size(path = paths$dashboard_html)) / 1024)
cli::cli_alert_success("Wrote {.path {paths$dashboard_html}} ({size_kb} kB)")
