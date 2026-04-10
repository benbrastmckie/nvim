# Reporting Standards in Epidemiology

Guidelines for transparent reporting of epidemiological research.

## STROBE (Strengthening the Reporting of Observational Studies in Epidemiology)

**Applies to**: Cohort, case-control, and cross-sectional studies
**Items**: 22-item checklist (with design-specific extensions)
**Reference**: https://www.strobe-statement.org/

Key requirements:
- Describe study design in title or abstract
- State specific objectives and hypotheses
- Define all variables (exposures, outcomes, confounders, effect modifiers)
- Describe data sources and measurement methods
- Explain how study size was determined
- Describe all statistical methods including confounding control
- Report participant flow (numbers at each stage)
- Give characteristics of participants and missing data information
- Report unadjusted and adjusted estimates with precision

**R tooling**: `gtsummary::tbl_summary()` for Table 1, `gtsummary::tbl_regression()` for model results, `consort` package for flow diagrams.

## CONSORT (Consolidated Standards of Reporting Trials)

**Applies to**: Randomized controlled trials (parallel, cluster, non-inferiority)
**Items**: 25-item checklist + flow diagram
**Reference**: https://www.consort-statement.org/

Key requirements:
- Structured abstract with trial design, methods, results, conclusions
- Flow diagram showing enrollment, allocation, follow-up, analysis
- Intention-to-treat (ITT) as primary analysis
- Report both absolute and relative effect sizes
- Describe randomization (sequence generation, allocation concealment)
- Describe blinding and who was blinded
- Report all pre-specified outcomes and any post-hoc analyses
- Trial registration number

**R tooling**: `consort` package for flow diagrams, `gtsummary::tbl_summary()` for baseline characteristics by arm.

## PRISMA (Preferred Reporting Items for Systematic Reviews and Meta-Analyses)

**Applies to**: Systematic reviews and meta-analyses
**Items**: 27-item checklist + flow diagram
**Reference**: https://www.prisma-statement.org/

Key requirements:
- Registered protocol (PROSPERO)
- Complete search strategy for all databases
- Study selection process with flow diagram (records identified, screened, included)
- Risk of bias assessment for included studies
- Forest plot showing individual study and pooled estimates
- Heterogeneity assessment (I-squared, Q statistic)
- Publication bias assessment (funnel plot, Egger's test)
- GRADE certainty of evidence assessment

**R tooling**: `meta::forest()`, `meta::funnel()`, `meta::metabias()`, `robvis` for risk-of-bias visualization.

## RECORD (REporting of studies Conducted using Observational Routinely-collected health Data)

**Applies to**: Studies using EHR, claims, registry, or administrative data
**Items**: Extension of STROBE with 13 additional items
**Reference**: https://www.record-statement.org/

Key additional requirements:
- Describe the database, data linkage methods, and data cleaning
- Report codes used to identify exposures, outcomes, and covariates (ICD, CPT, etc.)
- Describe validation of algorithms or case definitions
- Report data access and cleaning methods
- Describe how data linkage was performed and quality assessed

## TRIPOD+AI (Transparent Reporting of a multivariable prediction model for Individual Prognosis Or Diagnosis)

**Applies to**: Clinical prediction models and AI/ML diagnostic models
**Key requirements**:
- Report discrimination (C-statistic/AUC) and calibration (calibration plot, Hosmer-Lemeshow)
- Describe development and validation datasets separately
- Report handling of missing data in predictors
- Provide model equation or sufficient detail for independent validation
- For AI models: describe architecture, training process, hyperparameter tuning

**R tooling**: `rms::val.prob()` for calibration, `pROC::roc()` for discrimination, `probably::cal_plot_*()` for calibration plots.

## Design-to-Guideline Mapping

| Study Design | Primary Guideline | Extensions |
|---|---|---|
| Prospective cohort | STROBE | RECORD (if EHR data) |
| Retrospective cohort | STROBE | RECORD (if EHR data) |
| Case-control | STROBE | RECORD (if EHR data) |
| Cross-sectional | STROBE | RECORD (if EHR data) |
| RCT (parallel) | CONSORT | Cluster, non-inferiority extensions |
| Cluster RCT | CONSORT-cluster | - |
| Systematic review | PRISMA | PRISMA-IPD (individual patient data) |
| Prediction model | TRIPOD+AI | - |
| Diagnostic accuracy | STARD | - |
| Qualitative research | SRQR or COREQ | - |
