# Natural State take-home (Senior Data Scientist)

## Context
Take-home for Natural State. Brief: brief/NS - Senior Data Scientist - Take Home Project.pdf
(git-ignored, kept locally).
Two challenges: BirdNET species thresholds (Wood & Kahl 2024) and herbaceous vegetation ODK QA/QC.
Time budget 4-6 h. AI use is encouraged but Alban must be able to explain every line.

## Hard rules
- Never modify files in data/raw/. Read-only. Hashes are in data/raw/MANIFEST.sha256.
- Vegetation: flag data errors, never fix or drop them.
- Every analytical decision is written into the relevant report with its rationale and alternatives,
  and into the rulebook of that part (rulebook_birds.md or rulebook_vegetation.md).
- Propose before writing anything substantial; keep changes small and reviewable.
- Work is tracked in GitHub issues. Every commit message references its issue
  ("refs #n" while in progress, "closes #n" when done). Decisions taken while working are added
  as a comment on the issue, not only in the code.

## Conventions
- R code follows the r-code-style skill (.claude/skills/r-code-style/). Reports are R Markdown
  (.Rmd) knitted to GitHub-flavoured Markdown with `rmarkdown::github_document`. Quarto only where
  nothing else works (the vegetation dashboard).
- Every report starts with a TL;DR (3-5 bullets: what, key result, key decision, what Tech must do).
- renv for packages. Static figures in figures/ (ggplot2, sf).
- Validate inputs explicitly (schemas, keys, joins with relationship/unmatched).
- SQL targets PostgreSQL.
- Style: follows the global tidyverse default (base pipe, `.by =`, stringi), no exceptions.
- Code lives in R/functions/, R/birds/ and R/vegetation/.

## Git hooks
Two hooks live in `.git/hooks/` (not pushed, so described here). Bypass with `--no-verify`.
- pre-commit: runs `air format` on staged .R files and restages them. Blocks if `air` is not on
  PATH or if a staged R file also has unstaged edits (stage or stash them first). Also reminds
  (never blocks) to update the matching rulebook (rulebook_birds.md or rulebook_vegetation.md) when R/birds/,
  R/vegetation/ or *.qmd files are staged without a rulebook.
- pre-push: fetches origin and warns, with a confirm prompt, if the remote branch has commits the
  local branch lacks. Skips on first push and in detached HEAD.

## Domain notes
- ODK repeats: survey KEY -> quadrat PARENT_KEY; quadrat KEY -> additional_species PARENT_KEY.
- Wood & Kahl: glm(outcome ~ qlogis(confidence), family = binomial) per species;
  threshold = plogis((qlogis(0.99) - b0) / b1).
