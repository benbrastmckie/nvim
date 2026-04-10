# Study Designs in Epidemiology

Reference guide for selecting and implementing epidemiological study designs in R.

## Observational Study Designs

### Cohort Study (Prospective)

**Description**: Follow exposed and unexposed groups forward in time to measure disease incidence.
**When to use**: Known exposure, sufficient follow-up time, adequate funding.
**Key R packages**: `survival` (Cox PH, Kaplan-Meier), `timereg` (Aalen models)
**Primary model**: Cox proportional hazards (`coxph()`)
**Key output**: Hazard Ratio (HR) with 95% CI
**Reporting guideline**: STROBE (items 6a, 12b for follow-up)

```r
library(survival)
fit <- coxph(Surv(time, event) ~ exposure + age + sex, data = cohort_data)
summary(fit)  # HR = exp(coef)
cox.zph(fit)  # Proportional hazards assumption
```

### Cohort Study (Retrospective)

**Description**: Identify exposure groups from historical records, ascertain outcomes to present.
**When to use**: Existing records (EHR, registries), rare exposures, long latency diseases.
**Key R packages**: `survival`, `Epi` (Lexis diagrams for person-time)
**Primary model**: Cox PH or Poisson regression with person-time offset
**Key output**: HR or Incidence Rate Ratio (IRR)
**Reporting guideline**: STROBE + RECORD (for routinely collected data)

```r
library(Epi)
# Lexis diagram for person-time calculation
lex <- Lexis(entry = list(per = entry_date),
             exit = list(per = exit_date),
             exit.status = event, data = cohort_data)
```

### Case-Control Study (Unmatched)

**Description**: Compare exposure history between cases (diseased) and controls (non-diseased).
**When to use**: Rare diseases, multiple exposures of interest, limited resources.
**Key R packages**: `stats` (glm), `epitools` (odds ratio)
**Primary model**: Logistic regression (`glm(family = binomial)`)
**Key output**: Odds Ratio (OR) with 95% CI
**Reporting guideline**: STROBE (items 6b for case/control definitions)

```r
fit <- glm(case ~ exposure + age + sex, family = binomial, data = cc_data)
exp(coef(fit))       # Odds ratios
exp(confint(fit))    # 95% CIs
```

### Case-Control Study (Matched)

**Description**: Controls matched to cases on potential confounders (age, sex, etc.).
**When to use**: Strong confounding by matching variables, efficiency with rare diseases.
**Key R packages**: `survival` (conditional logistic), `MatchIt` (post-hoc matching)
**Primary model**: Conditional logistic regression (`clogit()`)
**Key output**: Matched OR with 95% CI
**Reporting guideline**: STROBE (report matching factors, ratio)

```r
library(survival)
# strata() identifies matched sets
fit <- clogit(case ~ exposure + strata(match_id), data = matched_data)
exp(coef(fit))
```

### Cross-Sectional Study

**Description**: Measure exposure and outcome simultaneously in a defined population.
**When to use**: Prevalence estimation, hypothesis generation, health surveys.
**Key R packages**: `survey` (complex survey designs), `epiR` (prevalence ratios)
**Primary model**: Log-binomial or modified Poisson for prevalence ratios
**Key output**: Prevalence Ratio (PR) or Prevalence Odds Ratio (POR)
**Reporting guideline**: STROBE (cross-sectional specific items)

```r
library(survey)
des <- svydesign(id = ~psu, strata = ~stratum, weights = ~weight, data = survey_data)
fit <- svyglm(outcome ~ exposure + age, design = des, family = quasibinomial)
exp(coef(fit))
```

## Experimental Study Designs

### Randomized Controlled Trial (Parallel)

**Description**: Randomly assign individuals to intervention or control, follow for outcomes.
**When to use**: Causal effect of intervention, equipoise exists, ethical to randomize.
**Key R packages**: `stats` (regression), `survival` (time-to-event), `lmtest` (robust tests)
**Primary model**: Depends on outcome type (linear, logistic, Cox)
**Key output**: Risk Difference (RD), Risk Ratio (RR), or HR
**Reporting guideline**: CONSORT (flow diagram, ITT analysis mandatory)

```r
# Intent-to-treat analysis
fit <- glm(outcome ~ treatment + stratification_var, family = binomial, data = rct_data)
# Risk difference via marginal standardization
library(marginaleffects)
avg_comparisons(fit, variables = "treatment")
```

### Cluster Randomized Trial

**Description**: Randomize clusters (clinics, schools) rather than individuals.
**When to use**: Intervention delivered at group level, contamination concerns.
**Key R packages**: `lme4` (mixed effects), `clubSandwich` (robust SEs), `CRTgeeDR`
**Primary model**: GLMM with random intercept for cluster
**Key output**: Adjusted OR/RR with cluster-corrected CIs
**Reporting guideline**: CONSORT extension for cluster trials

```r
library(lme4)
fit <- glmer(outcome ~ treatment + (1 | cluster_id), family = binomial, data = cluster_data)
# Robust SEs for small number of clusters
library(clubSandwich)
coef_test(fit, vcov = "CR2")
```

## Systematic Review and Meta-Analysis

**Description**: Systematically search, appraise, and synthesize published studies.
**When to use**: Summarizing evidence across studies, resolving conflicting findings.
**Key R packages**: `meta` (generic meta-analysis), `metafor` (comprehensive), `dmetar` (helpers)
**Primary model**: Random-effects meta-analysis (DerSimonian-Laird or REML)
**Key output**: Pooled effect estimate with 95% CI, I-squared heterogeneity
**Reporting guideline**: PRISMA (search strategy, flow diagram, forest plot)

```r
library(meta)
m <- metagen(TE = log_or, seTE = se_log_or, studlab = study, data = studies,
             sm = "OR", method.tau = "REML")
forest(m)
funnel(m)        # Publication bias assessment
metabias(m)      # Egger's test
```

## Surveillance Studies

**Description**: Ongoing systematic collection and analysis of health data for public health action.
**When to use**: Outbreak detection, disease monitoring, trend assessment.
**Key R packages**: `surveillance` (aberration detection), `incidence2` (epidemic curves)
**Primary model**: Time-series regression, Farrington algorithm for aberration detection
**Key output**: Incidence trends, outbreak signals, seasonal patterns

```r
library(surveillance)
# Farrington algorithm for outbreak detection
sts <- sts(observed = counts, start = c(2020, 1), frequency = 52)
result <- farringtonFlexible(sts, control = list(range = 200:260))
plot(result)
```

## Modeling Studies

### Compartmental Models (SIR/SEIR)

**Description**: Divide population into compartments by disease state, model transitions with ODEs.
**When to use**: Epidemic forecasting, intervention evaluation, parameter estimation.
**Key R packages**: `EpiModel` (network + compartmental), `deSolve` (ODE solver), `odin` (compiled ODEs)
**Primary model**: System of ordinary differential equations
**Key output**: Epidemic curves, R0/Rt estimates, intervention impact

```r
library(EpiModel)
param <- param.dcm(inf.prob = 0.05, act.rate = 10, rec.rate = 1/14)
init <- init.dcm(s.num = 10000, i.num = 10, r.num = 0)
control <- control.dcm(type = "SIR", nsteps = 365)
mod <- dcm(param, init, control)
plot(mod)
```

### Agent-Based Models

**Description**: Simulate individual agents with heterogeneous attributes and interactions.
**When to use**: Heterogeneous populations, complex contact patterns, spatial dynamics.
**Key R packages**: `EpiModel` (network models), `SimInf` (fast stochastic), `ABM`
**Primary model**: Stochastic simulation on contact networks
**Key output**: Distribution of outcomes, network-level effects

## Quasi-Experimental Designs

### Difference-in-Differences (DiD)

**Description**: Compare pre-post changes between treated and control groups.
**When to use**: Policy evaluation, natural experiments with parallel trends assumption.
**Key R packages**: `did` (Callaway-Sant'Anna), `fixest` (fast fixed effects)
**Primary model**: Two-way fixed effects or Callaway-Sant'Anna estimator
**Key output**: Average Treatment Effect on the Treated (ATT)

```r
library(fixest)
fit <- feols(outcome ~ treatment:post | unit + time, data = panel_data)
summary(fit)
```

### Regression Discontinuity (RD)

**Description**: Exploit threshold-based treatment assignment for causal inference.
**When to use**: Treatment assigned by a cutoff (age, test score, policy threshold).
**Key R packages**: `rdrobust` (robust estimation), `rddensity` (manipulation testing)
**Primary model**: Local polynomial regression at the cutoff
**Key output**: Local Average Treatment Effect (LATE) at the cutoff

```r
library(rdrobust)
rd <- rdrobust(y = outcome, x = running_var, c = cutoff)
summary(rd)
rdplot(y = outcome, x = running_var, c = cutoff)
```

### Instrumental Variable (IV)

**Description**: Use an instrument correlated with exposure but not outcome (except through exposure).
**When to use**: Unmeasured confounding, Mendelian randomization.
**Key R packages**: `ivreg` (2SLS), `MendelianRandomization` (MR methods)
**Primary model**: Two-stage least squares (2SLS)
**Key output**: Local Average Treatment Effect (LATE)

```r
library(ivreg)
fit <- ivreg(outcome ~ exposure + covariates | instrument + covariates, data = df)
summary(fit, diagnostics = TRUE)  # Weak instrument test, Hausman test
```

## Quick Reference: Design Selection

| Research Question | Best Design | Key Measure |
|---|---|---|
| Cause of rare disease? | Case-control | OR |
| Effect of intervention? | RCT | RR, RD |
| Disease prognosis? | Prospective cohort | HR |
| Prevalence of condition? | Cross-sectional | PR |
| Policy impact? | DiD, RD | ATT, LATE |
| Summarize existing evidence? | Meta-analysis | Pooled estimate |
| Forecast epidemic trajectory? | Compartmental model | Rt, peak timing |
