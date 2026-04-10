# Data Management for Epidemiology

Project structure, data cleaning, and data ethics for R-based epidemiological research.

## R Project Structure

```
project-name/
  project-name.Rproj        # RStudio project file
  _targets.R                 # targets pipeline definition
  renv.lock                  # Package versions
  data-raw/                  # Raw, unmodified source data (never edit)
    raw_survey_2024.csv
    redcap_export_2024-01-15.csv
    codebook_original.xlsx
  data/                      # Cleaned, analysis-ready data
    analytic_cohort.rds      # Primary analytic dataset
    codebook.csv             # Variable-level metadata
  R/                         # Reusable functions
    clean_data.R             # Data cleaning functions
    derive_variables.R       # Derived variable definitions
    analysis_helpers.R       # Custom analysis utilities
  analysis/                  # Analysis scripts (numbered for order)
    01_data_preparation.R
    02_descriptive.R
    03_primary_analysis.R
    04_sensitivity.R
    05_figures_tables.R
  output/                    # Generated results
    tables/
    figures/
    reports/
  docs/                      # Study documentation
    analysis_plan.md
    data_dictionary.md
  .gitignore                 # Exclude data, output, credentials
```

## Data Cleaning Patterns

### Initial Import and Inspection

```r
library(readr)
library(janitor)
library(dplyr)
library(skimr)

# Import with explicit column types
raw <- read_csv("data-raw/survey.csv",
                col_types = cols(
                  id = col_character(),
                  age = col_double(),
                  sex = col_factor(levels = c("Male", "Female")),
                  enrollment_date = col_date(format = "%m/%d/%Y")
                ))

# Clean variable names (lowercase, underscores, no special chars)
df <- raw |> clean_names()

# Quick data overview
skim(df)
```

### Common Cleaning Operations

```r
library(lubridate)

df_clean <- df |>
  # Remove duplicates
  distinct(participant_id, .keep_all = TRUE) |>

  # Standardize categorical variables
  mutate(
    sex = factor(sex, levels = c("Male", "Female")),
    race_eth = factor(race_eth) |> fct_recode(
      "NH White" = "White",
      "NH Black" = "Black or African American"
    )
  ) |>

  # Derive age from dates

  mutate(
    age_at_enrollment = as.numeric(
      difftime(enrollment_date, birth_date, units = "days")
    ) / 365.25
  ) |>

  # Winsorize extreme values
  mutate(bmi = case_when(
    bmi < 10 | bmi > 70 ~ NA_real_,
    TRUE ~ bmi
  ))
```

### Type Parsing with readr

```r
# Fix mistyped columns after import
df <- df |>
  mutate(
    # Parse numeric from string
    lab_value = parse_number(lab_value_text),
    # Parse date with mixed formats
    visit_date = parse_date(visit_date_raw, format = "%Y-%m-%d")
  )

# Detect parsing problems
problems(raw)
```

## Codebook Conventions

### Using labelled for Variable Metadata

```r
library(labelled)

df <- df |>
  set_variable_labels(
    exposure_smoking = "Current smoking status (self-reported)",
    outcome_cvd = "Incident cardiovascular disease event",
    covar_age = "Age at enrollment (years)",
    covar_bmi = "Body mass index (kg/m^2)"
  ) |>
  set_value_labels(
    exposure_smoking = c("Never" = 0, "Former" = 1, "Current" = 2),
    outcome_cvd = c("No" = 0, "Yes" = 1)
  )

# Generate codebook
var_label(df)
val_labels(df)

# Export machine-readable codebook
library(sjlabelled)
codebook_df <- tibble(
  variable = names(df),
  label = get_label(df),
  type = sapply(df, class),
  n_missing = sapply(df, function(x) sum(is.na(x)))
)
write_csv(codebook_df, "data/codebook.csv")
```

## REDCap Integration

```r
library(REDCapR)

# Export data from REDCap
records <- redcap_read(
  redcap_uri = Sys.getenv("REDCAP_URI"),
  token = Sys.getenv("REDCAP_TOKEN")
)$data

# Export metadata (data dictionary)
metadata <- redcap_metadata_read(
  redcap_uri = Sys.getenv("REDCAP_URI"),
  token = Sys.getenv("REDCAP_TOKEN")
)$data

# Store token in .Renviron (never hardcode)
# REDCAP_URI=https://redcap.institution.edu/api/
# REDCAP_TOKEN=ABCDEF1234567890
```

## Data Ethics and PHI Protection

### .gitignore Patterns for Health Data

```gitignore
# Raw and processed data
data-raw/
data/
*.csv
*.xlsx
*.sas7bdat
*.rds
*.rda
*.dta

# Credentials
.Renviron
.env
credentials/
*.pem
*.key

# Output that may contain individual data
output/tables/
output/reports/

# Keep codebook and documentation
!data/codebook.csv
!data-raw/README.md
```

### De-identification Checklist

Before sharing or committing any data, verify removal of all 18 HIPAA identifiers:

1. Names
2. Geographic data smaller than state
3. Dates (except year) related to an individual
4. Phone numbers
5. Fax numbers
6. Email addresses
7. Social Security numbers
8. Medical record numbers
9. Health plan beneficiary numbers
10. Account numbers
11. Certificate/license numbers
12. Vehicle identifiers and serial numbers
13. Device identifiers and serial numbers
14. Web URLs
15. IP addresses
16. Biometric identifiers
17. Full-face photographs
18. Any other unique identifying number

### Practical De-identification in R

```r
# Create study ID mapping (store separately, securely)
id_map <- df |>
  select(mrn) |>
  distinct() |>
  mutate(study_id = sprintf("S%04d", row_number()))

# De-identify
df_deidentified <- df |>
  left_join(id_map, by = "mrn") |>
  select(-mrn, -name, -address, -phone, -email, -ssn) |>
  mutate(
    # Shift dates by random offset per participant
    enrollment_date = enrollment_date + sample(-30:30, n(), replace = TRUE),
    # Truncate age at 90
    age = pmin(age, 90),
    # Generalize geography
    region = case_when(
      state %in% c("NY", "NJ", "CT") ~ "Northeast",
      TRUE ~ "Other"
    )
  ) |>
  select(-state, -zip)
```

## Variable Naming Conventions

Use consistent prefixes to identify variable roles in epidemiological datasets:

| Prefix | Role | Examples |
|---|---|---|
| `exposure_` | Primary exposure(s) | `exposure_smoking`, `exposure_pm25` |
| `outcome_` | Outcome variable(s) | `outcome_mortality`, `outcome_hospitalization` |
| `covar_` | Covariates/confounders | `covar_age`, `covar_sex`, `covar_bmi` |
| `time_` | Time variables | `time_followup`, `time_enrollment` |
| `event_` | Event indicators | `event_death`, `event_censored` |
| `strata_` | Stratification variables | `strata_site`, `strata_period` |
| `weight_` | Sampling/analysis weights | `weight_survey`, `weight_ipw` |
| `id_` | Identifiers | `id_participant`, `id_cluster` |
| `derived_` | Computed variables | `derived_age_group`, `derived_bmi_category` |
