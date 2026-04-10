# Statistical Analysis Plan: {Study Title}

**Version**: 1.0
**Date**: {YYYY-MM-DD}
**Principal Investigator**: {name}
**Statistician**: {name}

## 1. Study Overview

- **Design**: {cohort / case-control / cross-sectional / RCT / other}
- **Population**: {brief description of study population and setting}
- **Primary Outcome**: {outcome variable, definition, ascertainment method}
- **Primary Exposure**: {exposure variable, definition, measurement}
- **Study Period**: {start date to end date}
- **Reporting Guideline**: {STROBE / CONSORT / PRISMA / RECORD}

## 2. Data Sources

| File | Description | Format | Records | Key Variables |
|------|-------------|--------|---------|---------------|
| {filename} | {description} | {CSV/RDS/SAS} | {N} | {list key vars} |

### Data Linkage

{Describe any linkage between data sources, linkage keys, and expected match rate. If no linkage, state "Not applicable."}

## 3. Variable Definitions

### Primary Variables

| Variable | Role | Type | Source | Coding | Notes |
|----------|------|------|--------|--------|-------|
| {name} | Exposure | Binary | {source} | 0=unexposed, 1=exposed | {notes} |
| {name} | Outcome | Time-to-event | {source} | Surv(time, event) | {censoring rules} |

### Covariates

| Variable | Role | Type | Source | Coding | Rationale |
|----------|------|------|--------|--------|-----------|
| {name} | Confounder | Continuous | {source} | Years | DAG-identified |
| {name} | Confounder | Categorical | {source} | {levels} | DAG-identified |
| {name} | Effect modifier | Binary | {source} | 0/1 | Pre-specified |

### Derived Variables

| Variable | Definition | R Code |
|----------|-----------|--------|
| {name} | {description} | `case_when(bmi < 25 ~ "Normal", ...)` |

## 4. Analysis Population

### Inclusion Criteria

1. {criterion 1}
2. {criterion 2}
3. {criterion 3}

### Exclusion Criteria

1. {criterion 1 with rationale}
2. {criterion 2 with rationale}

### Expected Sample Size

- **Total eligible**: ~{N}
- **After exclusions**: ~{N}
- **Power calculation**: {describe power analysis or state "exploratory"}
  - Detectable effect size: {OR/HR/RR = X with 80% power at alpha = 0.05}

## 5. Statistical Methods

### 5.1 Descriptive Analysis

- Baseline characteristics (Table 1) stratified by {exposure / treatment arm}
- Continuous variables: median (IQR) or mean (SD) based on distribution
- Categorical variables: n (%)
- Standardized mean differences for balance assessment
- R: `gtsummary::tbl_summary(by = exposure)`

### 5.2 Primary Analysis

- **Model**: {Cox PH / logistic regression / Poisson / linear regression}
- **Outcome**: {outcome variable}
- **Exposure**: {exposure variable}
- **Adjustment set**: {list covariates, justified by DAG}
- **Effect measure**: {HR / OR / RR / RD} with 95% CI
- **Assumptions to check**: {proportional hazards / linearity / overdispersion}

```r
# Primary model specification
fit <- {model_function}({outcome_formula} ~ {exposure} + {covariates}, data = df)
```

### 5.3 Sensitivity Analyses

| Analysis | Rationale | Method |
|----------|-----------|--------|
| Alternative confounder set | Assess sensitivity to adjustment strategy | {different covariates} |
| Complete case analysis | Compare with MI results | Restrict to complete cases |
| E-value | Unmeasured confounding sensitivity | `EValue::evalues.{OR/RR}()` |
| {Competing risks} | {Informative censoring} | Fine-Gray model |
| {Propensity score} | {Robustness check} | IPW or matching |

### 5.4 Subgroup Analyses

| Subgroup | Variable | Levels | Test for Interaction |
|----------|----------|--------|---------------------|
| {name} | {variable} | {levels} | Product term p-value |

## 6. Missing Data Strategy

- **Expected missingness**: {describe which variables and anticipated % missing}
- **Mechanism assessment**: `naniar::vis_miss()`, Little's MCAR test
- **Primary approach**: {complete case / multiple imputation / other}
- **MI specification**: {if MI: m = X imputations, pmm for continuous, logreg for binary}
- **MNAR sensitivity**: {delta adjustment / tipping point analysis / not applicable}

## 7. Multiple Comparisons

- **Primary analysis**: Single primary comparison, no adjustment needed
- **Secondary/subgroup analyses**: {Bonferroni / FDR / interpret as exploratory}
- **Number of pre-specified comparisons**: {N}

## 8. Software

- **R version**: {version}
- **Key packages**: {list with versions from renv.lock}
- **Reproducibility**: renv for package management, targets for pipeline, here for paths
- **Code repository**: {location}

## 9. Timeline

| Milestone | Target Date |
|-----------|------------|
| SAP finalized | {date} |
| Data preparation complete | {date} |
| Primary analysis complete | {date} |
| Manuscript draft | {date} |

## Appendix A: DAG

{Include DAG image or dagitty specification}

```
dag {
  Exposure -> Outcome
  {confounders} -> Exposure
  {confounders} -> Outcome
}
```

## Appendix B: Amendments

| Date | Version | Change | Rationale |
|------|---------|--------|-----------|
| {date} | 1.0 | Initial version | - |
