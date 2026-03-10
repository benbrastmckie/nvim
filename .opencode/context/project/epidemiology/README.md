# Epidemiology Domain

Research and implementation guide for epidemiology, public health, and infectious disease modeling using R.

## Core Concepts

- **Study Designs**: Observational (Cohort, Case-Control) vs. Experimental (RCT)
- **Measures of Frequency**: Prevalence, Incidence, Cumulative Incidence
- **Measures of Association**: Risk Ratio, Odds Ratio, Hazard Ratio
- **Causal Inference**: Confounding, Interaction, Directed Acyclic Graphs (DAGs)

## Modeling Approaches

### Infectious Disease Dynamics
- **Compartmental Models**: SI, SIR, SEIR (Deterministic & Stochastic)
- **Network Models**: Contact networks, sexual transmission networks (ERGMs)
- **Agent-Based Models**: Individual simulation

### Statistical Modeling
- **Regression**: Linear, Logistic, Poisson, Negative Binomial
- **Survival Analysis**: Cox Proportional Hazards, Kaplan-Meier
- **Longitudinal Analysis**: GEE, Mixed Effects Models
- **Bayesian Inference**: Stan, MCMC, Hierarchical Models

## Tooling Ecosystem

- **R Packages**: `EpiModel`, `epidemia`, `EpiNow2`, `EpiEstim`, `survival`
- **MCP Servers**: `rmcp` (General Statistics), `mcptools` (Custom R Functions)
- **Visualization**: `ggplot2`, `survminer`, `DiagrammeR` (for DAGs)

## Workflow

1. **Research Design**: Define question, select study type, identify data sources
2. **Data Preparation**: Clean, transform, and impute missing data
3. **Exploratory Analysis**: Descriptive statistics, visualization
4. **Model Selection**: Choose appropriate statistical or dynamic model
5. **Implementation**: Code model in R (or Stan via R)
6. **Validation**: Sensitivity analysis, model diagnostics
7. **Reporting**: Interpret results, visualize findings, document limitations
