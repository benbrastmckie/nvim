# Findings Report: {Study Title}

**Date**: {YYYY-MM-DD}
**Analyst**: {name}
**Study Design**: {design type}
**Reporting Guideline**: {STROBE / CONSORT / PRISMA}

## Executive Summary

{2-3 paragraphs summarizing the study rationale, key methods, and main findings. Write for a non-technical audience (e.g., PI, collaborators, policy makers). Lead with the main finding and its public health significance.}

{Primary finding: Among N participants followed for X years, exposure to {X} was associated with a {magnitude} {increase/decrease} in {outcome} (HR/OR = X.XX, 95% CI: X.XX-X.XX).}

{Sensitivity analyses {supported/qualified} the primary finding. The E-value of X.X suggests the result is {robust/potentially sensitive} to unmeasured confounding.}

## Methods Summary

### Study Population
- **Source population**: {description}
- **Eligibility**: {key inclusion/exclusion criteria}
- **Study period**: {dates}

### Exposure and Outcome
- **Exposure**: {definition and measurement}
- **Primary outcome**: {definition and ascertainment}
- **Follow-up**: {median follow-up time, IQR}

### Statistical Approach
- **Primary model**: {model type with covariates}
- **Confounding control**: {DAG-informed adjustment / propensity scores / other}
- **Missing data**: {approach used}

## Results

### Participant Flow

{Describe enrollment, exclusions, and final analytic sample. Reference flow diagram if created.}

- Screened: N
- Excluded: N (reasons: ...)
- Included in analysis: N
- Events observed: N ({outcome name})
- Median follow-up: X years (IQR: X-X)

### Baseline Characteristics (Table 1)

{Reference Table 1 below. Highlight key differences between exposure groups. Note any variables with substantial missing data.}

The study population comprised N participants (X% female, median age X years). Exposed and unexposed groups were {similar/different} with respect to {key variables}. {Notable imbalances: ...}

### Primary Outcome

**Unadjusted analysis**: {effect measure} = X.XX (95% CI: X.XX-X.XX)

**Adjusted analysis**: {effect measure} = X.XX (95% CI: X.XX-X.XX), adjusting for {covariate list}.

{Interpret the direction and magnitude of the association. Discuss statistical significance in context of clinical/public health significance.}

### Secondary Outcomes

{If applicable, report secondary outcomes with same structure as primary.}

| Outcome | Events | Adjusted Estimate | 95% CI | p-value |
|---------|--------|-------------------|--------|---------|
| {outcome 1} | N | X.XX | X.XX-X.XX | X.XXX |
| {outcome 2} | N | X.XX | X.XX-X.XX | X.XXX |

### Sensitivity Analyses

| Analysis | Estimate | 95% CI | Interpretation |
|----------|----------|--------|----------------|
| Primary (reference) | X.XX | X.XX-X.XX | - |
| Alternative adjustment set | X.XX | X.XX-X.XX | {consistent / attenuated} |
| Complete case only | X.XX | X.XX-X.XX | {consistent / different} |
| Propensity-weighted | X.XX | X.XX-X.XX | {consistent / different} |
| E-value | X.X | - | {strong / weak} robustness |

{Narrative summary: "Results were robust across sensitivity analyses" or "The finding was sensitive to..."}.

## Tables

### Table 1: Baseline Characteristics

{Insert gtsummary output or reference external file: `output/tables/table1.docx`}

### Table 2: Primary and Adjusted Results

{Insert model results or reference external file: `output/tables/table2.docx`}

### Table 3: Sensitivity Analyses

{Insert sensitivity analysis results}

## Figures

### Figure 1: {Main Result Visualization}

{Description of figure. File: `output/figures/figure1.png`}

### Figure 2: {Sensitivity Analysis Forest Plot}

{Description of figure. File: `output/figures/figure2.png`}

### Figure 3: {DAG / Study Design Diagram}

{Description of figure, if applicable.}

## Limitations

{Discuss in order of importance:}

1. **{Most important limitation}**: {description, expected direction and magnitude of bias}
2. **{Second limitation}**: {description}
3. **{Third limitation}**: {description}

{General statement about residual confounding, measurement error, generalizability.}

## Conclusions

{1-2 paragraphs. Restate the main finding. Place in context of existing literature. State implications for practice, policy, or future research. Avoid causal language for observational studies unless justified by design (e.g., target trial emulation with strong assumptions).}

## Appendix: Code Availability

- **Analysis code**: {repository URL or path}
- **R version**: {version}
- **Key packages**: {list with versions}
- **Pipeline**: {targets / Makefile / scripts}
- **Reproducibility**: `renv::restore()` to install exact package versions, `targets::tar_make()` to reproduce all results
- **Data availability**: {statement about data access for replication}
