# R Packages for Epidemiology

Guide to key R packages used in epidemiological research and infectious disease modeling.

## EpiModel
**Purpose**: Mathematical Modeling of Infectious Disease Dynamics
- **Models**: Deterministic compartmental models (DCM), stochastic individual-contact models (ICM), stochastic network models (Network)
- **Disease Types**: SI, SIR, SIS
- **Key Features**: Network modeling with ERGMs (Statnet integration)
- **Example Usage**:
  ```r
  library(EpiModel)
  param <- param.dcm(inf.prob = 0.2, act.rate = 1, rec.rate = 1/20)
  init <- init.dcm(s.num = 1000, i.num = 1, r.num = 0)
  control <- control.dcm(type = "SIR", nsteps = 500)
  mod <- dcm(param, init, control)
  plot(mod)
  ```

## epidemia
**Purpose**: Flexible Epidemic Modeling with Bayesian Inference
- **Approach**: Semi-mechanistic Bayesian models
- **Backend**: Precompiled Stan programs
- **Key Features**: Time-varying reproduction numbers, latent infections, multilevel models
- **Example Usage**:
  ```r
  library(epidemia)
  # Define model components (transmission, observations, latent infections)
  args <- EuropeCovid$args
  fit <- do.call(epim, args)
  plot_rt(fit)
  ```

## EpiNow2
**Purpose**: Estimate Real-Time Case Counts and Time-Varying Parameters
- **Approach**: Renewal equation with Bayesian inference (Stan)
- **Key Features**: Rt estimation, forecasting, delay distributions (incubation, reporting)
- **Example Usage**:
  ```r
  library(EpiNow2)
  # Estimate Rt from case data
  estimates <- epinow(reported_cases = cases)
  plot(estimates)
  ```

## EpiEstim
**Purpose**: Estimate Time-Varying Reproduction Numbers from Epidemic Curves
- **Approach**: Cori et al. (2013) method
- **Key Features**: Simple, fast Rt estimation from incidence time series
- **Example Usage**:
  ```r
  library(EpiEstim)
  res_parametric_si <- estimate_R(Incid, method="parametric_si",
                                  config = make_config(list(mean_si = 2.6, std_si = 1.5)))
  plot(res_parametric_si, legend = FALSE)
  ```

## epiparameter
**Purpose**: Library of Epidemiological Parameters
- **Features**: Database of parameters (R0, incubation periods) from literature
- **Usage**: Retrieve distributions for use in models
- **Example Usage**:
  ```r
  library(epiparameter)
  # Get incubation period for COVID-19
  covid_incubation <- epidist_db(disease = "COVID-19", epi_dist = "incubation")
  ```

## Other Essential Packages
- **survival**: Core survival analysis (Surv, coxph)
- **survminer**: Visualization for survival models (ggsurvplot)
- **epitools**: Epidemiology tools (odds ratio, risk ratio, confidence intervals)
- **Epi**: Analysis of follow-up data (Lexis diagrams)

---

## Extended Package Reference by Category

### Tables and Reporting

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **gtsummary** | Publication-ready summary and regression tables | `tbl_summary()`, `tbl_regression()`, `tbl_merge()`, `tbl_stack()` |
| **modelsummary** | Regression tables comparing multiple models | `modelsummary()`, `modelplot()` |
| **gt** | Flexible HTML/LaTeX/Word table creation | `gt()`, `tab_header()`, `fmt_number()` |
| **flextable** | Word-compatible tables (preferred for clinical journals) | `flextable()`, `save_as_docx()`, `as_flextable()` |

```r
# gtsummary: Table 1
library(gtsummary)
df |>
  tbl_summary(by = exposure, include = c(age, sex, bmi, comorbidity)) |>
  add_overall() |>
  add_p() |>
  bold_p()

# gtsummary: Regression table
fit |> tbl_regression(exponentiate = TRUE)

# flextable: Export to Word
tbl |> as_flex_table() |> flextable::save_as_docx(path = "table1.docx")
```

### Missing Data

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **mice** | Multiple imputation by chained equations | `mice()`, `with()`, `pool()`, `complete()` |
| **naniar** | Missing data visualization and assessment | `vis_miss()`, `gg_miss_var()`, `gg_miss_upset()`, `mcar_test()` |
| **VIM** | Visualization and imputation of missing values | `aggr()`, `matrixplot()`, `marginplot()` |

```r
# mice: Standard 4-step workflow
library(mice)
imp <- mice(df, m = 20, method = "pmm", seed = 42)
fit <- with(imp, glm(outcome ~ exposure + age, family = binomial))
pooled <- pool(fit)
summary(pooled, conf.int = TRUE, exponentiate = TRUE)

# naniar: Quick assessment
library(naniar)
vis_miss(df)
gg_miss_var(df)
```

### Propensity Scores and Matching

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **MatchIt** | Propensity score matching (nearest, optimal, CEM, genetic) | `matchit()`, `match.data()`, `summary()` |
| **WeightIt** | Propensity score and balancing weights | `weightit()`, `summary()` |
| **cobalt** | Balance assessment for matching/weighting | `bal.tab()`, `love.plot()`, `bal.plot()` |

```r
# MatchIt: Nearest-neighbor matching
library(MatchIt)
m <- matchit(treatment ~ age + sex + bmi, data = df, method = "nearest", caliper = 0.2)
matched <- match.data(m)

# cobalt: Love plot for balance assessment
library(cobalt)
love.plot(m, threshold = 0.1, abs = TRUE)
```

### Competing Risks

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **tidycmprsk** | Tidy competing risks analysis (CIF, Fine-Gray) | `cuminc()`, `crr()`, `ggcuminc()` |
| **cmprsk** | Classic competing risks (CIF, Fine-Gray) | `cuminc()`, `crr()` |

```r
# tidycmprsk: Cumulative incidence function
library(tidycmprsk)
cif <- cuminc(Surv(time, event) ~ exposure, data = df)
ggcuminc(cif, outcome = "1") + add_confidence_interval()

# Fine-Gray subdistribution hazard model
fg <- crr(Surv(time, event) ~ exposure + age + sex, data = df)
```

### Causal Inference

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **dagitty** | DAG specification, d-separation, adjustment sets | `dagitty()`, `adjustmentSets()`, `impliedConditionalIndependencies()` |
| **ggdag** | ggplot2-based DAG visualization | `ggdag()`, `ggdag_adjustment_set()`, `ggdag_paths()` |
| **mediation** | Causal mediation analysis | `mediate()`, `summary()`, `plot()` |

```r
# dagitty: Find adjustment sets
library(dagitty)
dag <- dagitty('dag { X -> Y; C -> X; C -> Y }')
adjustmentSets(dag, exposure = "X", outcome = "Y")

# ggdag: Visualize
library(ggdag)
ggdag_adjustment_set(dag, exposure = "X", outcome = "Y") + theme_dag()
```

### Sensitivity Analysis

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **episensr** | Quantitative bias analysis (misclassification, confounding, selection) | `misclassification()`, `confounders()`, `selection()`, `probsens.conf()` |
| **EValue** | E-values for unmeasured confounding sensitivity | `evalues.OR()`, `evalues.RR()`, `evalues.HR()` |

```r
# EValue: Sensitivity to unmeasured confounding
library(EValue)
evalues.OR(est = 2.5, lo = 1.8, hi = 3.5, rare = TRUE)

# episensr: Probabilistic bias analysis
library(episensr)
confounders(matrix(c(105, 85, 527, 93), nrow = 2), type = "OR",
            bias_parms = c(1.5, 0.6, 0.8))
```

### Bayesian

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **brms** | Bayesian regression (Stan backend, formula interface) | `brm()`, `prior()`, `pp_check()`, `loo()` |
| **rstanarm** | Bayesian regression (pre-compiled Stan models, faster) | `stan_glm()`, `stan_glmer()`, `posterior_predict()` |
| **bayesplot** | Visualization for Bayesian models | `mcmc_trace()`, `mcmc_dens()`, `ppc_dens_overlay()` |

```r
# brms: Bayesian logistic regression
library(brms)
fit <- brm(outcome ~ exposure + age + (1 | cluster),
           family = bernoulli(), data = df,
           prior = prior(normal(0, 2.5), class = "b"))
summary(fit)
pp_check(fit)
```

### Basic Epidemiology

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **epiR** | Measures of association, diagnostic test evaluation | `epi.2by2()`, `epi.tests()`, `epi.prev()` |
| **epitools** | Risk and rate calculations | `oddsratio()`, `riskratio()`, `ratetable()` |
| **Epi** | Person-time, Lexis diagrams, standardization | `Lexis()`, `splitLexis()`, `ci.cum()` |

```r
# epiR: 2x2 table analysis
library(epiR)
tab <- table(df$exposure, df$outcome)
epi.2by2(tab, method = "cohort.count")
# Reports: RR, OR, AR, PAR with CIs
```

### Figures and Visualization

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **survminer** | Kaplan-Meier and Cox visualization | `ggsurvplot()`, `ggcoxdiagnostics()`, `ggforest()` |
| **forestploter** | Publication-quality forest plots | `forest()` |
| **patchwork** | Combine multiple ggplots | `+`, `/`, `plot_layout()` |
| **ggforestplot** | Forest plots from data frames | `forestplot()` |

```r
# survminer: KM plot with risk table
library(survminer)
fit <- survfit(Surv(time, event) ~ exposure, data = df)
ggsurvplot(fit, risk.table = TRUE, pval = TRUE, conf.int = TRUE)

# patchwork: Combine plots
library(patchwork)
(plot_km + plot_forest) / plot_subgroup + plot_layout(heights = c(2, 1))
```

### Prediction Models

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **rms** | Regression modeling strategies (Harrell) | `lrm()`, `cph()`, `validate()`, `calibrate()`, `nomogram()` |
| **pROC** | ROC curves and AUC | `roc()`, `auc()`, `ci.auc()`, `coords()` |
| **probably** | Tidymodels calibration tools | `cal_plot_logistic()`, `cal_plot_windowed()` |

```r
# rms: Validated prediction model
library(rms)
dd <- datadist(df); options(datadist = "dd")
fit <- lrm(outcome ~ exposure + rcs(age, 4) + sex, data = df, x = TRUE, y = TRUE)
validate(fit, B = 200)       # Bootstrap internal validation
calibrate(fit, B = 200)      # Calibration plot

# pROC: ROC curve
library(pROC)
roc_obj <- roc(df$outcome, predict(fit, type = "fitted"))
plot(roc_obj, print.auc = TRUE)
ci.auc(roc_obj)
```

### Reproducibility

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **renv** | Project-local package management | `init()`, `snapshot()`, `restore()`, `status()` |
| **targets** | Pipeline management (dependency-aware) | `tar_target()`, `tar_make()`, `tar_read()`, `tar_visnetwork()` |
| **here** | Portable file paths from project root | `here()` |

```r
# targets: Define pipeline in _targets.R
library(targets)
list(
  tar_target(data, read_csv(here("data-raw", "cohort.csv"))),
  tar_target(model, coxph(Surv(time, event) ~ exposure, data = data)),
  tar_target(table, tbl_regression(model, exponentiate = TRUE))
)
```

### Survey Analysis

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **survey** | Complex survey design and analysis | `svydesign()`, `svyglm()`, `svymean()`, `svytable()` |
| **srvyr** | Tidyverse interface to survey package | `as_survey_design()`, `survey_mean()`, `survey_total()` |

```r
# survey: Design-based analysis
library(survey)
des <- svydesign(id = ~psu, strata = ~stratum, weights = ~weight, data = df)
svyglm(outcome ~ exposure + age, design = des, family = binomial)
```

### Interaction Analysis

| Package | Purpose | Key Functions |
|---------|---------|---------------|
| **interactionR** | RERI, AP, SI for additive interaction | `interactionR()` |

```r
# interactionR: Additive interaction measures
library(interactionR)
fit <- glm(outcome ~ exposure * modifier + age, family = binomial, data = df)
interactionR(fit, exposure_names = c("exposure", "modifier"),
             ci.type = "delta", em = FALSE)
# RERI > 0: super-additive interaction
# AP: proportion of combined effect due to interaction
# SI: synergy index (1 = no interaction)
```
