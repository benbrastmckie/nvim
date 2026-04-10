# Causal Inference in Epidemiology

Methods and R tools for causal reasoning in observational studies.

## Directed Acyclic Graphs (DAGs)

### Drawing and Analyzing DAGs

```r
library(dagitty)
library(ggdag)

# Define DAG
dag <- dagitty('dag {
  Exposure -> Outcome
  Confounder -> Exposure
  Confounder -> Outcome
  Mediator -> Outcome
  Exposure -> Mediator
}')

# Identify minimally sufficient adjustment sets
adjustmentSets(dag, exposure = "Exposure", outcome = "Outcome")

# Test implied conditional independencies
impliedConditionalIndependencies(dag)

# Visualize with ggdag
ggdag(dag) + theme_dag()
ggdag_adjustment_set(dag, exposure = "Exposure", outcome = "Outcome")
```

### Common DAG Structures

**Confounding path**: X <- C -> Y. Adjust for C to block the non-causal path.

**Mediator**: X -> M -> Y. Do NOT adjust for M if estimating total effect.

**Collider**: X -> C <- Y. Do NOT adjust for C (opens non-causal path).

**M-bias**: Adjusting for a pre-treatment variable can open a biasing path. Always draw the DAG first.

## Collider Bias and Selection Bias

Collider bias occurs when conditioning on a common effect of exposure and outcome (or their causes). Common scenarios:

- **Selection/participation bias**: Conditioning on being in the study when factors related to both exposure and outcome influence participation
- **Loss to follow-up**: Analyzing only completers when dropout depends on exposure and outcome
- **Berkson's bias**: Hospital-based studies where hospitalization is a collider

**Detection**: Draw the full DAG including selection nodes. If any path opens through conditioning, collider bias is present.

## Mediation vs Confounding

### Mediation Analysis

Decompose total effect into direct and indirect (mediated) pathways.

```r
library(mediation)

# Step 1: Mediator model
med_fit <- lm(mediator ~ exposure + covariates, data = df)

# Step 2: Outcome model
out_fit <- glm(outcome ~ exposure + mediator + covariates,
               family = binomial, data = df)

# Step 3: Mediation analysis
med_result <- mediate(med_fit, out_fit,
                      treat = "exposure", mediator = "mediator",
                      boot = TRUE, sims = 1000)
summary(med_result)
# Reports: ACME (indirect), ADE (direct), Total Effect, Proportion Mediated
```

**Key assumptions for mediation**:
1. No unmeasured exposure-outcome confounding
2. No unmeasured mediator-outcome confounding
3. No unmeasured exposure-mediator confounding
4. No effect of exposure on mediator-outcome confounders

## Propensity Score Methods

### Matching with MatchIt

```r
library(MatchIt)

# Estimate propensity scores and match
m <- matchit(treatment ~ age + sex + comorbidity + ses,
             data = df, method = "nearest", ratio = 1,
             caliper = 0.2)
summary(m)  # Balance diagnostics
plot(m, type = "jitter")

# Extract matched data
matched_df <- match.data(m)

# Analyze matched data (with matching weights)
fit <- glm(outcome ~ treatment, family = binomial,
           data = matched_df, weights = weights)
```

### Weighting with WeightIt

```r
library(WeightIt)

# Inverse probability weights (ATE)
w <- weightit(treatment ~ age + sex + comorbidity + ses,
              data = df, method = "ps", estimand = "ATE")
summary(w)

# ATT weights
w_att <- weightit(treatment ~ age + sex + comorbidity + ses,
                  data = df, method = "ps", estimand = "ATT")
```

### Balance Diagnostics with cobalt

```r
library(cobalt)

# Check balance after matching or weighting
bal.tab(m, thresholds = c(m = 0.1))  # SMD < 0.1

# Love plot (visual balance)
love.plot(m, threshold = 0.1, abs = TRUE,
          var.order = "unadjusted")

# Balance table after weighting
bal.tab(w, thresholds = c(m = 0.1))
```

**Balance targets**: Standardized mean difference (SMD) < 0.1 for all covariates. Variance ratios between 0.5 and 2.0.

## Target Trial Emulation

Framework from Hernan & Robins for designing observational analyses as if they were RCTs.

### Seven Components to Specify

| Component | Target Trial | Observational Emulation |
|---|---|---|
| Eligibility | Inclusion/exclusion criteria | Same, applied at time zero |
| Treatment strategies | Interventions compared | Exposure definitions |
| Assignment | Randomization | Measured confounders + PS/IP weighting |
| Start of follow-up | Randomization date | Time zero (eligibility + treatment) |
| Outcome | Primary endpoint | Same |
| Causal contrast | ITT or per-protocol | ITT analog or per-protocol with IP weighting |
| Analysis plan | Statistical methods | Same, plus confounding adjustment |

### Implementation Pattern

```r
# 1. Define eligibility at time zero
eligible <- df |>
  filter(meets_inclusion & !meets_exclusion) |>
  filter(time == index_date)

# 2. Clone-censor-weight for per-protocol
# Clone each person into treatment strategies
# Censor when protocol is violated
# Weight for informative censoring with IPCW

# 3. Estimate with marginal structural model
library(WeightIt)
w <- weightit(treatment ~ confounders, data = eligible, method = "ps")
fit <- glm(outcome ~ treatment, family = binomial, data = eligible, weights = w$weights)
```

## E-Values for Unmeasured Confounding

Quantify how strong unmeasured confounding would need to be to explain away an observed association.

```r
library(EValue)

# For an observed OR of 2.5 (95% CI: 1.8, 3.5)
evalues.OR(est = 2.5, lo = 1.8, hi = 3.5, rare = TRUE)
# Returns: E-value for point estimate and CI lower bound

# For an observed RR
evalues.RR(est = 1.7, lo = 1.2, hi = 2.4)

# Interpretation: E-value of 4.4 means an unmeasured confounder
# would need RR >= 4.4 with both exposure AND outcome
# to explain away the observed association
```

**Interpretation guide**:
- E-value >> 1: Substantial unmeasured confounding needed to nullify result
- E-value close to 1: Even weak unmeasured confounding could explain finding
- Always report E-value for both point estimate and confidence limit
