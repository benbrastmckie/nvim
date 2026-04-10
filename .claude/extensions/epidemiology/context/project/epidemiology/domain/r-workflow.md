# R Workflow for Epidemiology

Reproducibility, pipeline management, and manuscript preparation tools.

## Package Management with renv

```r
# Initialize renv in a new project
renv::init()

# After installing/updating packages, snapshot the lockfile
renv::snapshot()

# Restore packages on a new machine (from renv.lock)
renv::restore()

# Check for outdated packages
renv::status()

# Update a specific package
renv::update("gtsummary")
```

**Best practices**:
- Commit `renv.lock` to git (records exact package versions)
- Commit `renv/activate.R` to git (bootstraps renv on new machines)
- Add `renv/library/` to `.gitignore` (local cache, not portable)
- Run `renv::snapshot()` before each commit that changes dependencies

## Pipeline Management with targets

```r
# _targets.R (project root)
library(targets)
library(tarchetypes)

tar_option_set(packages = c("dplyr", "survival", "gtsummary"))

list(
  # Data preparation
  tar_target(raw_data, read_csv("data-raw/cohort.csv")),
  tar_target(clean_data, clean_cohort(raw_data)),
  tar_target(analytic_data, derive_variables(clean_data)),

  # Descriptive analysis
  tar_target(table1, make_table1(analytic_data)),
  tar_target(missing_report, assess_missingness(analytic_data)),

  # Primary analysis
  tar_target(cox_model, fit_cox(analytic_data)),
  tar_target(cox_results, tidy_cox(cox_model)),

  # Sensitivity analyses
  tar_target(sensitivity_results, run_sensitivity(analytic_data)),

  # Figures and tables
  tar_target(km_plot, plot_kaplan_meier(analytic_data)),
  tar_target(forest_plot, plot_forest(cox_results, sensitivity_results)),

  # Report
  tar_quarto(manuscript, "docs/manuscript.qmd")
)
```

### Running the Pipeline

```r
# Run the full pipeline (skips up-to-date targets)
tar_make()

# Visualize the dependency graph
tar_visnetwork()

# Read a specific target
tar_read(cox_results)

# Check which targets are outdated
tar_outdated()

# Clean and rebuild everything
tar_destroy()
tar_make()
```

**Benefits for epidemiology**:
- Changing a covariate in `derive_variables()` automatically re-runs all downstream analyses
- Expensive models (MCMC, MI) are cached and only re-run when inputs change
- The DAG makes the analytic pipeline auditable

## Manuscript Preparation with Quarto

### Quarto Manuscript Structure

```yaml
# docs/manuscript.qmd (YAML header)
---
title: "Association of X with Y: A Cohort Study"
author:
  - name: "Author One"
    affiliations: "Department of Epidemiology"
format:
  docx:
    reference-doc: template.docx
  pdf:
    documentclass: article
bibliography: references.bib
csl: american-journal-of-epidemiology.csl
execute:
  echo: false
  warning: false
---
```

### Cross-References

```markdown
As shown in @fig-km-plot, survival differed significantly between groups.
Baseline characteristics are presented in @tbl-baseline.
The full model results appear in @tbl-cox-results.

```{r}
#| label: fig-km-plot
#| fig-cap: "Kaplan-Meier survival curves by exposure group."
tar_read(km_plot)
```

```{r}
#| label: tbl-baseline
#| tbl-cap: "Baseline characteristics of the study population."
tar_read(table1)
```
```

### Journal Format Strategy

| Target | Format | Notes |
|---|---|---|
| Clinical journals (JAMA, NEJM, Lancet) | Word (`.docx`) | Use reference template for styling |
| Statistics journals (Biometrics, Stat Med) | LaTeX (`.pdf`) | Direct PDF or LaTeX source |
| Preprint servers (medRxiv) | PDF | Any clean PDF |
| Internal reports | HTML | Interactive tables and figures |

```r
# Render to specific format
quarto::quarto_render("manuscript.qmd", output_format = "docx")
quarto::quarto_render("manuscript.qmd", output_format = "pdf")
```

## Portable Paths with here

```r
library(here)

# Always use here() for file paths (works from any subdirectory)
raw <- read_csv(here("data-raw", "survey.csv"))
write_rds(df, here("data", "analytic.rds"))
ggsave(here("output", "figures", "figure1.png"))

# Never use setwd() or absolute paths in scripts
```

**How it works**: `here()` finds the project root by looking for `.Rproj`, `.here`, or `.git` files, then constructs paths relative to that root. Scripts work the same whether run from the project root, a subdirectory, or interactively.
