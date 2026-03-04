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
