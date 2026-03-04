# Research Report: Task #125

**Task**: OC_125 - Add epidemiology research extension for R and related tooling
**Date**: 2026-03-04
**Language**: meta
**Focus**: What else is common to use for epidemiology research with agent systems in 2026?

## Summary

Research focused on common tools and packages used for epidemiology workflows that could be surfaced through agent systems in 2026. The most common additions beyond general R tooling are domain-specific epidemiology packages (EpiModel, epidemia, EpiNow2, EpiEstim, epiparameter) and probabilistic modeling backends (Stan via epidemia/EpiNow2). These are appropriate to reflect in extension context, recommended MCP tooling, and agent skill guidance.

## Findings

### Epidemiology modeling packages in R

- **EpiModel** provides deterministic, stochastic, and network epidemic models (SI/SIR/SIS) and is a widely used modeling framework in R for infectious disease dynamics.
  - Source: https://epimodel.github.io/EpiModel/
  - CRAN: https://cran.r-project.org/package=EpiModel

- **epidemia** provides Bayesian epidemiological models and uses Stan under the hood for fitting (through a precompiled Stan program).
  - Source: https://imperialcollegelondon.github.io/epidemia/index.html
  - Stan usage: https://imperialcollegelondon.github.io/epidemia/reference/epim.html

### Real-time reproduction number and forecasting

- **EpiNow2** is commonly used for estimating time-varying reproduction numbers and forecasting; it uses a renewal-equation approach with Bayesian inference via Stan.
  - CRAN: https://cran.r-project.org/web/packages/EpiNow2/index.html
  - Docs: https://epiforecasts.io/EpiNow2/

- **EpiEstim** is commonly used to estimate time-varying reproduction numbers from incidence time series.
  - Source: https://rdrr.io/cran/EpiEstim/

### Epidemiological parameter tooling

- **epiparameter** provides classes and helper functions for working with epidemiological parameters and parameter databases.
  - Source: https://cran.r-project.org/web/packages/epiparameter/index.html

### MCP tooling for R in agent systems

- **rmcp** provides an MCP server with statistical analysis tools; it is a practical MCP option for R-based workflows.
  - Source: https://github.com/finite-sample/rmcp

- **mcptools** provides a CRAN MCP implementation that can expose R functions as MCP tools, which makes it suitable for custom epidemiology workflows.
  - Source: https://cran.r-project.org/web/packages/mcptools/mcptools.pdf
  - Server guide: https://cran.r-project.org/web/packages/mcptools/vignettes/server.html

## Recommendations

1. Include references to common epidemiology packages (EpiModel, epidemia, EpiNow2, EpiEstim, epiparameter) in the extension context and skills documentation.
2. Provide guidance for Stan-backed modeling via epidemia/EpiNow2 and note Stan dependencies in extension requirements.
3. Add MCP server options for both rmcp (broad statistical tools) and mcptools (custom epidemiology-specific tools).

## Risks & Considerations

- Some packages depend on Stan and may require toolchain setup; the extension should document prerequisites and troubleshooting.
- MCP server availability depends on R/Python environment provisioning; agent guidance should include fallback workflows when MCP servers are unavailable.

## Next Steps

Run `/plan OC_125` to create an implementation plan.
