# Statistical Modeling Patterns

Common statistical analysis patterns and workflows in epidemiology using R and Stan.

## Regression Analysis (Generalized Linear Models)

### Logistic Regression (Binary Outcome)
**Purpose**: Assess association between exposure and binary disease status.
**Packages**: `stats`, `epitools`
**Workflow**:
1.  **Model**: `glm(outcome ~ exposure + age + sex, family = binomial)`
2.  **Estimate**: `summary(model)$coefficients` (Log Odds)
3.  **Odds Ratio**: `exp(coef(model))` (Odds Ratio)
4.  **Confidence Intervals**: `exp(confint(model))`

### Poisson Regression (Count Data)
**Purpose**: Analyze rates of disease occurrence.
**Packages**: `stats`, `MASS` (Negative Binomial)
**Workflow**:
1.  **Model**: `glm(cases ~ exposure + offset(log(population)), family = poisson)`
2.  **Rate Ratio**: `exp(coef(model))`

## Survival Analysis (Time-to-Event)

### Kaplan-Meier Estimator
**Purpose**: Describe survival function over time.
**Packages**: `survival`, `survminer`
**Workflow**:
1.  **Object**: `Surv(time, status)`
2.  **Fit**: `survfit(Surv(time, status) ~ group)`
3.  **Plot**: `ggsurvplot(fit)`

### Cox Proportional Hazards Model
**Purpose**: Assess effect of covariates on hazard rate.
**Packages**: `survival`
**Workflow**:
1.  **Model**: `coxph(Surv(time, status) ~ exposure + age)`
2.  **Hazard Ratio**: `exp(coef(model))`
3.  **Assumption Check**: `cox.zph(model)` (Schoenfeld Residuals)

## Bayesian Inference with Stan

### Hierarchical Models
**Purpose**: Analyze multilevel data (e.g., individuals within regions).
**Packages**: `rstan`, `brms`, `epidemia`
**Workflow**:
1.  **Define Model**: Specify priors, likelihood, and hierarchy.
2.  **Compile**: `stan_model(file = "model.stan")`
3.  **Sample**: `sampling(model, data = list(...))`
4.  **Diagnostics**: R-hat, traceplots (`bayesplot`)
5.  **Inference**: Posterior summaries (`posterior`)

### Time-Varying Reproduction Number (Rt)
**Purpose**: Estimate transmission potential over time.
**Packages**: `EpiNow2`, `EpiEstim`
**Workflow (EpiNow2)**:
1.  **Data**: Time series of reported cases.
2.  **Delays**: specify generation time, incubation period.
3.  **Estimate**: `epinow(reported_cases = cases, generation_time = generation_time)`
4.  **Visualize**: `plot(estimates)`

## Logistic Regression: Complete Pattern with Diagnostics

### Model Fitting and Interpretation

```r
fit <- glm(outcome ~ exposure + age + sex + bmi, family = binomial, data = df)

# Odds ratios with 95% CIs
exp(cbind(OR = coef(fit), confint(fit)))

# Tidy output with gtsummary
library(gtsummary)
tbl_regression(fit, exponentiate = TRUE)
```

### Diagnostics

```r
# Hosmer-Lemeshow goodness-of-fit test
library(ResourceSelection)
hoslem.test(fit$y, fitted(fit), g = 10)
# Non-significant p = adequate fit; significant = poor calibration

# ROC curve and AUC
library(pROC)
roc_obj <- roc(df$outcome, predict(fit, type = "response"))
auc(roc_obj)
plot(roc_obj, print.auc = TRUE)

# Influential observations (Cook's distance)
plot(fit, which = 4)
cooks_d <- cooks.distance(fit)
influential <- which(cooks_d > 4 / nrow(df))

# Multicollinearity (VIF)
library(car)
vif(fit)  # VIF > 5 suggests collinearity; > 10 is severe

# Residual diagnostics
# Deviance residuals
plot(fit, which = 1)
# Binned residual plot (better for binary outcomes)
library(arm)
binnedplot(fitted(fit), residuals(fit, type = "response"))
```

## Modified Poisson Regression

When log-binomial fails to converge, use Poisson with robust SEs to estimate prevalence ratios or risk ratios directly.

```r
# Fit Poisson model (will overestimate SE without correction)
fit_poisson <- glm(outcome ~ exposure + age + sex,
                   family = poisson(link = "log"), data = df)

# Robust (sandwich) standard errors correct the variance
library(sandwich)
library(lmtest)

# Corrected inference
coeftest(fit_poisson, vcov = vcovHC(fit_poisson, type = "HC0"))

# Extract robust CIs
robust_vcov <- vcovHC(fit_poisson, type = "HC0")
robust_se <- sqrt(diag(robust_vcov))
est <- coef(fit_poisson)

results <- data.frame(
  PR = exp(est),
  CI_lower = exp(est - 1.96 * robust_se),
  CI_upper = exp(est + 1.96 * robust_se)
)
results
```

**When to use**: Cross-sectional studies (prevalence ratios), cohort studies with common outcomes (>10%) where OR overestimates RR.

**Alternative**: Try `glm(family = binomial(link = "log"))` first. If it fails to converge (common), switch to modified Poisson.

## Mixed Effects Models

### Linear Mixed Effects (lme4)

```r
library(lme4)

# Random intercept for cluster
fit_lmer <- lmer(outcome ~ exposure + age + sex + (1 | cluster_id), data = df)
summary(fit_lmer)

# Random intercept + random slope
fit_lmer2 <- lmer(outcome ~ exposure + age + (1 + exposure | cluster_id), data = df)

# ICC
performance::icc(fit_lmer)

# Compare models
anova(fit_lmer, fit_lmer2)
```

### Generalized Linear Mixed Effects

```r
# Binary outcome with cluster random intercept
fit_glmer <- glmer(outcome ~ exposure + age + sex + (1 | cluster_id),
                   family = binomial, data = df)

# Fixed effects (conditional ORs)
exp(fixef(fit_glmer))
exp(confint(fit_glmer, method = "Wald"))
```

### Robust SEs for Small Cluster Counts

```r
# When number of clusters < 40, use clubSandwich for CR2 correction
library(clubSandwich)

# Coefficient tests with small-sample correction
coef_test(fit_glmer, vcov = "CR2")

# Confidence intervals
conf_int(fit_glmer, vcov = "CR2")
```

**Guidance**: Use `lmer()` for continuous outcomes, `glmer()` for binary/count outcomes. For > 40 clusters, standard SEs are usually adequate. For < 40 clusters, always use `clubSandwich`.

## Bayesian Regression with brms

### Basic Bayesian GLM

```r
library(brms)

# Bayesian logistic regression
fit_bayes <- brm(
  outcome ~ exposure + age + sex,
  family = bernoulli(),
  data = df,
  prior = c(
    prior(normal(0, 2.5), class = "b"),       # Weakly informative for coefficients
    prior(normal(0, 5), class = "Intercept")   # Wider for intercept
  ),
  chains = 4, iter = 2000, warmup = 1000, seed = 42
)

summary(fit_bayes)
# Posterior ORs
exp(fixef(fit_bayes))
```

### Bayesian Hierarchical Model

```r
# Multilevel model with group-level effects
fit_hier <- brm(
  outcome ~ exposure + age + sex + (1 | cluster_id),
  family = bernoulli(),
  data = df,
  prior = c(
    prior(normal(0, 2.5), class = "b"),
    prior(exponential(1), class = "sd")  # Half-exponential for group SD
  ),
  chains = 4, iter = 4000, warmup = 2000, seed = 42
)
```

### Diagnostics

```r
# Trace plots and density
plot(fit_bayes)

# Posterior predictive checks
pp_check(fit_bayes, ndraws = 100)

# R-hat and ESS (in summary output)
# R-hat should be < 1.01
# Bulk ESS and Tail ESS should be > 400

# LOO cross-validation for model comparison
loo(fit_bayes)
```

**Prior specification guidance**:
- `normal(0, 2.5)` for coefficients: weakly informative, allows effects up to ~OR 150
- `student_t(3, 0, 2.5)` for coefficients: heavier tails, more robust
- `exponential(1)` for SDs: weakly informative half-exponential
- Always run a prior predictive check: `brm(..., sample_prior = "only")`

## Model Diagnostics: Extended Reference

### Variance Inflation Factor (VIF)

```r
library(car)
vif(fit)
# VIF > 5: moderate collinearity, consider removing or combining variables
# VIF > 10: severe collinearity, must address
# GVIF^(1/(2*Df)) for categorical predictors
```

### Influential Observations

```r
# Cook's distance
plot(fit, which = 4)
# dfbetas (influence on each coefficient)
dfbetas_mat <- dfbetas(fit)
# Observations with |dfbeta| > 2/sqrt(n) are influential

# Sensitivity: refit excluding influential points
influential_ids <- which(cooks.distance(fit) > 4 / nrow(df))
fit_no_influential <- update(fit, data = df[-influential_ids, ])
# Compare estimates
```

### Residual Plots by Model Type

| Model | Residual Type | Plot | What to Look For |
|-------|---------------|------|-----------------|
| Linear | Standardized | Residuals vs fitted | No pattern, constant spread |
| Logistic | Deviance | Binned residual plot | Points within 95% bands |
| Poisson | Deviance | Residuals vs fitted | No pattern; check overdispersion |
| Cox PH | Schoenfeld | `cox.zph()` plot | No trend over time (PH holds) |
| Cox PH | Martingale | Martingale vs covariate | Linearity of continuous covariates |
| Cox PH | dfbeta | `ggcoxdiagnostics()` | No extreme influential obs |

### Overdispersion Check (Poisson/Binomial)

```r
# Quick check: residual deviance / df should be near 1
deviance(fit) / df.residual(fit)
# > 1.5 suggests overdispersion

# Formal test
library(AER)
dispersiontest(fit)

# Solutions: quasi-Poisson, negative binomial, or robust SEs
fit_nb <- MASS::glm.nb(count ~ exposure + offset(log(person_time)), data = df)
```
