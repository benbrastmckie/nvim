# STROBE Checklist Quick Reference

22-item checklist for reporting observational studies (cohort, case-control, cross-sectional).

## Title and Abstract

- [ ] **Item 1(a)**: Indicate study design in title or abstract
- [ ] **Item 1(b)**: Provide informative, balanced abstract (structured: background, methods, results, conclusions)

## Introduction

- [ ] **Item 2**: Explain scientific background and rationale
  - *R hint*: Literature search context, what is known and unknown
- [ ] **Item 3**: State specific objectives, including any pre-specified hypotheses
  - *R hint*: Primary exposure, primary outcome, direction of hypothesis

## Methods

- [ ] **Item 4**: Present key elements of study design early in the paper
  - *R hint*: State "prospective cohort", "matched case-control", etc.
- [ ] **Item 5**: Describe setting, locations, and relevant dates (enrollment, exposure, follow-up, data collection)
- [ ] **Item 6**: **(Cohort)** Give eligibility criteria, sources and methods of selection, and follow-up methods. **(Case-control)** Give eligibility, sources and methods of case ascertainment and control selection, rationale for case/control choice. **(Cross-sectional)** Give eligibility and sources/methods of participant selection.
  - *R hint*: Document inclusion/exclusion in code with counts at each step
- [ ] **Item 7**: Define all outcomes, exposures, predictors, confounders, and effect modifiers. Give diagnostic criteria.
  - *R hint*: `labelled::set_variable_labels()` for variable documentation
- [ ] **Item 8**: For each variable, give sources of data and details of assessment methods. If applicable, describe comparability of assessment methods.
- [ ] **Item 9**: Describe any efforts to address potential sources of bias
  - *R hint*: DAG (`dagitty`), propensity score methods (`MatchIt`), sensitivity analysis (`episensr`)
- [ ] **Item 10**: Explain how the study size was arrived at
  - *R hint*: `pwr` package for power calculations
- [ ] **Item 11**: Explain how quantitative variables were handled (grouping, transformations). Explain choices of groupings if applicable.
  - *R hint*: Document cut-points and transformations in `R/derive_variables.R`
- [ ] **Item 12**: Describe all statistical methods, including:
  - (a) Methods for confounding control
  - (b) Methods for subgroups and interactions
  - (c) How missing data were addressed
  - (d) **(Cohort)** How loss to follow-up was addressed. **(Case-control)** How matching was accounted for. **(Cross-sectional)** How sampling strategy was accounted for.
  - (e) Sensitivity analyses
  - *R hint*: `gtsummary::tbl_regression()` for all model results

## Results

- [ ] **Item 13**: Report numbers at each stage (eligible, included, completed follow-up, analyzed). Give reasons for non-participation. Consider a flow diagram.
  - *R hint*: `consort` package for flow diagrams
- [ ] **Item 14**: Give characteristics of participants (demographic, clinical, social) and information on exposures and confounders. Indicate number with missing data.
  - *R hint*: `gtsummary::tbl_summary()` for baseline table (Table 1)
- [ ] **Item 15**: **(Cohort)** Report number of outcome events or summary measures over time. **(Case-control)** Report numbers in each exposure category. **(Cross-sectional)** Report number of outcome events or summary measures.
- [ ] **Item 16**: Give unadjusted estimates and, if applicable, confounder-adjusted estimates with precision (e.g., 95% CI). Report category boundaries for continuous variables that were categorized. If relevant, report meaningful periods of follow-up.
  - *R hint*: Report both crude and adjusted estimates side-by-side
- [ ] **Item 17**: Report other analyses done (subgroups, interactions, sensitivity)
  - *R hint*: Forest plot comparing primary and sensitivity analyses

## Discussion

- [ ] **Item 18**: Summarize key results with reference to study objectives
- [ ] **Item 19**: Discuss limitations (sources of bias, imprecision). Discuss direction and magnitude of any potential bias.
  - *R hint*: E-values (`EValue` package) quantify robustness to unmeasured confounding
- [ ] **Item 20**: Give a cautious overall interpretation considering objectives, limitations, multiplicity of analyses, results from similar studies
- [ ] **Item 21**: Discuss generalizability (external validity) of results

## Other Information

- [ ] **Item 22**: Give source of funding and role of funders. State conflicts of interest.
