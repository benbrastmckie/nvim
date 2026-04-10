# Observational Methods

Advanced statistical methods for observational epidemiological studies in R.

## Competing Risks

When multiple event types can occur (e.g., death from cardiovascular disease vs. other causes), standard Kaplan-Meier overestimates cumulative incidence.

### Cumulative Incidence Function (CIF)

```r
library(tidycmprsk)

# Create competing risks object
# event: 0=censored, 1=event of interest, 2=competing event
cuminc_fit <- cuminc(Surv(time, event) ~ exposure, data = df)

# Plot CIF
ggcuminc(cuminc_fit, outcome = "1") +
  labs(x = "Time (years)", y = "Cumulative Incidence") +
  add_confidence_interval()

# Compare groups (Gray's test)
cuminc_fit
```

### Fine-Gray Regression

```r
library(tidycmprsk)

# Subdistribution hazard model
fg_fit <- crr(Surv(time, event) ~ exposure + age + sex, data = df)
tbl_regression(fg_fit, exponentiate = TRUE)

# Interpretation: subdistribution HR (sHR)
# sHR > 1 = higher cumulative incidence of event of interest
```

**CIF vs. 1-KM**: Always use CIF (not 1-KM) when competing risks exist. 1-KM treats competing events as censoring, which assumes independence of event types and overestimates cumulative incidence.

## Survey Methods

### Survey Design Specification

```r
library(survey)

# Stratified, cluster-sampled design with weights
des <- svydesign(
  id = ~psu,           # Primary sampling unit
  strata = ~stratum,   # Stratification variable
  weights = ~weight,   # Sampling weights
  nest = TRUE,         # PSUs nested within strata
  data = survey_df
)

# Replicate weights design (e.g., NHANES)
des_rep <- svrepdesign(
  data = survey_df,
  weights = ~weight,
  repweights = "repwt[0-9]+",
  type = "JK1"
)
```

### Survey Analysis

```r
library(srvyr)

# Tidyverse-style survey analysis
des_srvyr <- as_survey_design(survey_df,
                               ids = psu, strata = stratum, weights = weight)

# Weighted means and proportions
des_srvyr |>
  group_by(exposure) |>
  summarize(
    mean_age = survey_mean(age, vartype = "ci"),
    prop_female = survey_mean(sex == "Female", vartype = "ci")
  )

# Weighted regression
fit <- svyglm(outcome ~ exposure + age + sex, design = des, family = binomial)
exp(coef(fit))
exp(confint(fit))
```

## Mixed Effects Models

### Linear Mixed Effects

```r
library(lme4)

# Random intercept for cluster (e.g., clinic, region)
fit <- lmer(outcome ~ exposure + age + sex + (1 | cluster_id), data = df)
summary(fit)

# Random intercept and slope
fit2 <- lmer(outcome ~ exposure + age + (1 + exposure | cluster_id), data = df)

# ICC (intraclass correlation coefficient)
performance::icc(fit)
```

### Generalized Linear Mixed Effects

```r
# Binary outcome with cluster random effect
fit_glmer <- glmer(outcome ~ exposure + age + sex + (1 | cluster_id),
                   family = binomial, data = df)
exp(fixef(fit_glmer))  # Conditional ORs

# Robust standard errors for small number of clusters
library(clubSandwich)
coef_test(fit_glmer, vcov = "CR2")
```

**When to use robust SEs**: When number of clusters < 40, standard mixed model SEs may be anti-conservative. Use `clubSandwich::coef_test()` with CR2 correction.

## Sensitivity Analysis

### Bias Analysis with episensr

```r
library(episensr)

# Unmeasured confounding bias analysis
confounders(
  matrix(c(105, 85, 527, 93), nrow = 2),  # 2x2 table
  type = "OR",
  bias_parms = c(1.5, 0.6, 0.8)  # prev_exp_case, prev_exp_control, OR_confounder_outcome
)

# Misclassification bias analysis
misclassification(
  matrix(c(105, 85, 527, 93), nrow = 2),
  type = "outcome",
  bias_parms = c(0.95, 0.90, 0.95, 0.90)  # Se_exp, Se_unexp, Sp_exp, Sp_unexp
)

# Selection bias analysis
selection(
  matrix(c(105, 85, 527, 93), nrow = 2),
  bias_parms = c(0.94, 0.85, 0.78, 0.63)  # Selection probs
)

# Probabilistic bias analysis (multiple bias)
probsens.conf(
  matrix(c(105, 85, 527, 93), nrow = 2),
  type = "OR",
  reps = 50000,
  prev.exp = list("trapezoidal", c(0.35, 0.45, 0.55, 0.65)),
  prev.nexp = list("trapezoidal", c(0.15, 0.25, 0.35, 0.45)),
  risk = list("trapezoidal", c(1.0, 1.5, 2.0, 2.5))
)
```

### E-Values for Unmeasured Confounding

```r
library(EValue)

# Point estimate and CI
evalues.OR(est = 2.1, lo = 1.3, hi = 3.4, rare = TRUE)
# E-value: minimum strength of association (on RR scale)
# that an unmeasured confounder would need with BOTH
# exposure and outcome to explain away the observed OR
```

## Interaction on Additive Scale (RERI)

Additive interaction is the more biologically meaningful scale for public health. RERI = 0 means no additive interaction.

```r
library(interactionR)

# Fit model with product term
fit <- glm(outcome ~ exposure * modifier + covariates,
           family = binomial, data = df)

# Calculate RERI, AP, SI
interaction_result <- interactionR(fit,
                                    exposure_names = c("exposure", "modifier"),
                                    ci.type = "delta",
                                    em = FALSE)
interaction_result

# RERI > 0: positive interaction (super-additive)
# RERI = 0: no additive interaction
# RERI < 0: negative interaction (sub-additive)
# AP: attributable proportion due to interaction
# SI: synergy index (SI = 1 means no interaction)
```

## Modified Poisson Regression

When log-binomial regression fails to converge (common with many covariates), use Poisson regression with robust standard errors to estimate prevalence ratios or risk ratios directly.

```r
# Modified Poisson for prevalence/risk ratios
fit <- glm(outcome ~ exposure + age + sex,
           family = poisson(link = "log"), data = df)

# Robust (sandwich) standard errors
library(sandwich)
library(lmtest)
coeftest(fit, vcov = vcovHC(fit, type = "HC0"))

# Or equivalently with robust CIs
robust_se <- sqrt(diag(vcovHC(fit, type = "HC0")))
est <- coef(fit)
ci_lo <- exp(est - 1.96 * robust_se)
ci_hi <- exp(est + 1.96 * robust_se)
pr <- exp(est)

# Tidied output
tibble(
  term = names(est),
  prevalence_ratio = pr,
  ci_lower = ci_lo,
  ci_upper = ci_hi
)
```

**Why not log-binomial?**: `glm(family = binomial(link = "log"))` directly estimates risk/prevalence ratios but frequently fails to converge. Modified Poisson with sandwich SEs gives consistent estimates of the same parameter with valid (slightly conservative) inference.
