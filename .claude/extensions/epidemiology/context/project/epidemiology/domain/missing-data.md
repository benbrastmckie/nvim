# Missing Data in Epidemiology

Assessment, imputation, and sensitivity analysis for incomplete data.

## Missing Data Mechanisms

| Mechanism | Definition | Example | Implication |
|---|---|---|---|
| MCAR | Missingness unrelated to any data | Random lab equipment failure | Complete case analysis unbiased (but less efficient) |
| MAR | Missingness depends on observed data | Older patients skip follow-up (age observed) | Multiple imputation appropriate |
| MNAR | Missingness depends on unobserved data | Sickest patients too ill to attend visit | Requires sensitivity analysis |

## Assessment with naniar

```r
library(naniar)

# Visualize missing data patterns
vis_miss(df)                    # Heatmap of missingness
gg_miss_var(df)                 # Count of missing per variable
gg_miss_upset(df)               # Upset plot of co-missingness patterns
gg_miss_fct(df, fct = group)    # Missingness by factor level

# Numerical summaries
miss_var_summary(df)   # % missing per variable
miss_case_summary(df)  # % missing per observation
n_miss(df)             # Total missing values

# Shadow matrix for exploring missingness relationships
df_shadow <- bind_shadow(df)
# Now test: is missingness in variable X related to observed variable Y?
ggplot(df_shadow, aes(x = age, fill = bmi_NA)) +
  geom_histogram() +
  facet_wrap(~bmi_NA)
```

**Assessing MCAR**: Use Little's MCAR test (in `naniar::mcar_test()` or `misty::na.test()`). Significant p-value suggests data are NOT MCAR. However, failing to reject does not confirm MCAR.

## Multiple Imputation with mice

### Standard 4-Step Workflow

```r
library(mice)

# Step 1: Inspect data and imputation setup
md.pattern(df)           # Missing data pattern
init <- mice(df, maxit = 0)
meth <- init$method       # Default imputation methods
pred <- init$predictorMatrix

# Customize: exclude ID variables from prediction
pred[, "id"] <- 0

# Step 2: Impute (m = number of imputed datasets)
imp <- mice(df, m = 20, method = meth, predictorMatrix = pred,
            maxit = 30, seed = 42, printFlag = FALSE)

# Step 3: Analyze each imputed dataset
fit <- with(imp, glm(outcome ~ exposure + age + sex, family = binomial))

# Step 4: Pool results using Rubin's rules
pooled <- pool(fit)
summary(pooled, conf.int = TRUE, exponentiate = TRUE)  # ORs with CIs
```

### Imputation Method Selection

| Variable Type | Default Method | Alternative |
|---|---|---|
| Continuous (normal) | `pmm` (predictive mean matching) | `norm` (Bayesian linear) |
| Binary | `logreg` | `pmm` |
| Ordinal (2-5 levels) | `polr` | `pmm` |
| Nominal (>2 levels) | `polyreg` | - |
| Count | `pmm` | `poisson` |

**Tip**: `pmm` is robust to non-normality and preserves the data distribution. Prefer it unless you have strong reasons to use parametric methods.

### Convergence Diagnostics

```r
# Trace plots: check for convergence (no trends, good mixing)
plot(imp)

# Stripplots: compare imputed vs observed values
stripplot(imp, bmi ~ .imp, pch = 20)

# Density plots: imputed distributions should be plausible
densityplot(imp, ~ bmi)

# If traces show trends: increase maxit
# If imputed values are implausible: check predictor matrix and methods
```

### Number of Imputations

Rule of thumb: m >= fraction of incomplete cases (as percentage). If 35% of cases have any missing data, use m >= 35. Minimum m = 20 for most analyses.

## Sensitivity Analysis for MNAR

### Delta Adjustment Method

Shift imputed values by a fixed amount (delta) to assess sensitivity to MNAR.

```r
# Delta adjustment: add delta to imputed values for outcome
# Positive delta = missing outcomes are worse than imputed
imp_delta <- mice(df, m = 20, maxit = 30, seed = 42)

# Post-processing: shift imputed values
imp_delta_shifted <- complete(imp_delta, action = "long", include = TRUE)
imp_delta_shifted$outcome[imp_delta_shifted$.imp > 0 &
                           is.na(df$outcome[imp_delta_shifted$.id])] <-
  imp_delta_shifted$outcome[imp_delta_shifted$.imp > 0 &
                             is.na(df$outcome[imp_delta_shifted$.id])] + delta

# Re-analyze with shifted data
imp_shifted <- as.mids(imp_delta_shifted)
fit_shifted <- with(imp_shifted, glm(outcome ~ exposure, family = binomial))
pool(fit_shifted)
```

### Tipping Point Analysis

Increase delta incrementally until the result changes significance. Report the delta at which conclusions change.

```r
deltas <- seq(0, 2, by = 0.25)
results <- lapply(deltas, function(d) {
  # Apply delta adjustment and re-analyze
  # Return pooled estimate and p-value
})
# Plot: estimate vs delta, mark where CI crosses null
```

## When Complete Case Analysis Is Appropriate

Complete case analysis (listwise deletion) is valid when:
1. Data are MCAR (missingness unrelated to any variable)
2. Missingness is in the outcome only (for regression, under certain conditions)
3. Very low proportion missing (< 5%) across all variables
4. The analysis model conditions on the variables that predict missingness

Even when valid, complete case analysis is less efficient than multiple imputation. Report the number and percentage excluded due to missing data.
