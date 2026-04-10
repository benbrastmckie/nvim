# Epidemiology Domain

Research and implementation guide for epidemiology, public health, and infectious disease modeling using R.

## Directory Map

```
context/project/epidemiology/
  README.md                          # This file
  domain/                            # Core domain knowledge
    study-designs.md                 # Study design reference (cohort, RCT, DiD, etc.)
    causal-inference.md              # DAGs, propensity scores, target trials, E-values
    missing-data.md                  # MCAR/MAR/MNAR, mice workflow, sensitivity
    data-management.md               # Project structure, cleaning, PHI, naming
    reporting-standards.md           # STROBE, CONSORT, PRISMA, RECORD, TRIPOD
    r-workflow.md                    # renv, targets, Quarto, here
  patterns/                          # Analysis patterns and workflows
    statistical-modeling.md          # GLMs, survival, Bayesian, diagnostics
    observational-methods.md         # Competing risks, survey, mixed effects, bias
    analysis-phases.md               # 5-phase workflow (prep -> EDA -> analysis -> sensitivity -> reporting)
    strobe-checklist.md              # 22-item STROBE quick reference
  templates/                         # Fill-in templates for agents
    analysis-plan.md                 # Statistical analysis plan template
    findings-report.md               # Final findings report template
  tools/                             # Tooling reference
    r-packages.md                    # R package guide by category (~45 packages)
    mcp-guide.md                     # MCP server configuration (rmcp, mcptools)
```

## Usage

Agents load context files based on task type and command routing. When the epidemiology extension is active (loaded via `<leader>ac`), the `/epi` command and `epidemiology` task type become available.

Context files are indexed in `.claude/context/index.json` with `load_when` conditions specifying which agents, commands, and task types trigger loading. Files are loaded lazily -- only when matched by the current operation.

### How Agents Use These Files

- **Research agents**: Load `domain/` files for background knowledge when investigating epidemiological questions
- **Planning agents**: Load `patterns/analysis-phases.md` and `templates/analysis-plan.md` to structure implementation plans
- **Implementation agents**: Load `patterns/statistical-modeling.md`, `patterns/observational-methods.md`, and `tools/r-packages.md` for R code patterns
- **All agents**: Load `domain/reporting-standards.md` and `patterns/strobe-checklist.md` when preparing outputs for publication

## Core Concepts

- **Study Designs**: Observational (cohort, case-control, cross-sectional), experimental (RCT, cluster RCT), quasi-experimental (DiD, RD, IV), meta-analysis, surveillance, modeling
- **Measures of Frequency**: Prevalence, incidence rate, cumulative incidence
- **Measures of Association**: Risk Ratio (RR), Odds Ratio (OR), Hazard Ratio (HR), Rate Ratio (IRR), Prevalence Ratio (PR), Risk Difference (RD)
- **Causal Inference**: DAGs, confounding, collider bias, mediation, propensity scores, target trial emulation, E-values

## Modeling Approaches

### Infectious Disease Dynamics
- **Compartmental Models**: SI, SIR, SEIR (deterministic and stochastic)
- **Network Models**: Contact networks, sexual transmission networks (ERGMs)
- **Agent-Based Models**: Individual simulation with heterogeneous attributes

### Statistical Modeling
- **Regression**: Linear, logistic, Poisson, modified Poisson, negative binomial
- **Survival Analysis**: Cox PH, Kaplan-Meier, competing risks (Fine-Gray, CIF)
- **Longitudinal**: GEE, mixed effects (lme4), repeated measures
- **Bayesian**: brms (formula interface to Stan), rstanarm, hierarchical models
- **Causal Methods**: Propensity score matching/weighting, mediation, IV/2SLS

## Tooling Ecosystem

### Core R Packages
- **Data**: readr, dplyr, tidyr, janitor, labelled, here
- **Analysis**: survival, lme4, brms, survey, mice, MatchIt
- **Epi-specific**: EpiModel, EpiNow2, EpiEstim, epidemia, epiR, epitools, episensr
- **Tables**: gtsummary, gt, flextable, modelsummary
- **Figures**: ggplot2, survminer, forestploter, patchwork, ggdag
- **Reproducibility**: renv, targets, Quarto

### MCP Servers (Optional)
- **rmcp**: General statistical analysis tools (regression, correlation, hypothesis testing)
- **mcptools**: Custom R function exposure (domain-specific calculations)

### Reporting Standards
- STROBE (observational), CONSORT (RCT), PRISMA (systematic review), RECORD (EHR), TRIPOD+AI (prediction)
