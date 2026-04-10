# Analysis Phases

Standard 5-phase workflow for epidemiological data analysis with expected outputs per phase.

## Phase 1: Data Preparation

**Goal**: Clean, validated, analysis-ready dataset with documentation.

**Steps**:
1. Import raw data with explicit column types
2. Clean variable names (`janitor::clean_names()`)
3. Validate data against codebook (ranges, categories, cross-checks)
4. Apply inclusion/exclusion criteria, document counts at each step
5. Derive analysis variables (categorize continuous, compute composites)
6. Create analytic dataset and codebook

**Expected outputs**:
- `R/clean_data.R` -- Cleaning functions
- `R/derive_variables.R` -- Derived variable definitions
- `data/analytic_cohort.rds` -- Analysis-ready dataset
- `data/codebook.csv` -- Variable metadata (name, label, type, range, % missing)
- Participant flow counts (N screened, N excluded by each criterion, N included)

**Quality checks**:
```r
# Validate no unexpected missing values in key variables
stopifnot(sum(is.na(df$exposure)) == 0)
# Validate date ranges
stopifnot(all(df$enrollment_date >= as.Date("2020-01-01")))
# Validate factor levels
stopifnot(all(levels(df$sex) %in% c("Male", "Female")))
```

## Phase 2: Exploratory Data Analysis (EDA)

**Goal**: Understand data distributions, identify issues, generate hypotheses.

**Steps**:
1. Table 1: Baseline characteristics by exposure group
2. Missing data assessment (pattern, mechanism, proportion)
3. Outcome distribution and event rates
4. Exposure-outcome bivariate associations
5. Check for collinearity among covariates
6. Identify outliers and influential observations

**Expected outputs**:
- Table 1 (`gtsummary::tbl_summary()` stratified by exposure)
- Missing data visualization (`naniar::vis_miss()`)
- Outcome distribution plots
- Correlation matrix or VIF table for covariates

```r
library(gtsummary)
df |>
  select(exposure, age, sex, bmi, comorbidity, outcome) |>
  tbl_summary(by = exposure, missing = "ifany") |>
  add_overall() |>
  add_p() |>
  bold_p()
```

## Phase 3: Primary Analysis

**Goal**: Estimate the primary exposure-outcome association with appropriate adjustment.

**Steps**:
1. Specify primary model based on study design and outcome type
2. Fit unadjusted model
3. Fit adjusted model (covariates from DAG or protocol)
4. Check model assumptions (PH for Cox, linearity, overdispersion)
5. Extract effect estimates with confidence intervals
6. Calculate E-value for sensitivity to unmeasured confounding

**Expected outputs**:
- Unadjusted and adjusted effect estimates (OR, HR, RR, RD)
- Model assumption diagnostics
- E-value for unmeasured confounding

```r
# Unadjusted
fit_crude <- coxph(Surv(time, event) ~ exposure, data = df)
# Adjusted (confounders identified from DAG)
fit_adj <- coxph(Surv(time, event) ~ exposure + age + sex + bmi, data = df)

# Assumption check
cox.zph(fit_adj)

# Tidy results
library(gtsummary)
tbl_regression(fit_adj, exponentiate = TRUE)
```

## Phase 4: Sensitivity Analyses

**Goal**: Assess robustness of primary findings to alternative assumptions.

**Steps**:
1. Alternative model specifications (different confounder sets, functional forms)
2. Subgroup analyses (pre-specified in protocol)
3. Quantitative bias analysis (unmeasured confounding, misclassification)
4. Missing data sensitivity (if applicable: compare complete case, MI, MNAR scenarios)
5. Competing risks analysis (if applicable)
6. Dose-response analysis (if exposure has multiple levels)

**Expected outputs**:
- Forest plot of primary and sensitivity estimates
- Subgroup results table
- Bias analysis results (episensr output or E-values)
- Summary paragraph: which findings are robust, which are sensitive

```r
# Compare models in forest plot
models <- list(
  "Crude" = fit_crude,
  "Age/Sex adjusted" = fit_partial,
  "Fully adjusted" = fit_adj,
  "Propensity weighted" = fit_ipw
)
# Extract estimates and plot
```

## Phase 5: Reporting

**Goal**: Manuscript-ready tables, figures, and narrative text.

**Steps**:
1. Finalize Table 1 (baseline characteristics)
2. Create results tables (primary + sensitivity estimates)
3. Generate publication-quality figures (KM curves, forest plots, DAG)
4. Write results narrative referencing tables and figures
5. Complete reporting checklist (STROBE/CONSORT)
6. Compile supplementary materials

**Expected outputs**:
- `output/tables/table1.docx` -- Baseline characteristics
- `output/tables/table2.docx` -- Primary and adjusted results
- `output/figures/figure1.png` -- Main result visualization
- `output/figures/figure2.png` -- Sensitivity analysis forest plot
- Completed STROBE/CONSORT checklist
- Quarto manuscript draft (if applicable)

```r
# Publication-ready table export
library(gtsummary)
tbl_merge(list(tbl_crude, tbl_adjusted),
          tab_spanner = c("Unadjusted", "Adjusted")) |>
  as_flex_table() |>
  flextable::save_as_docx(path = here("output/tables/table2.docx"))
```
