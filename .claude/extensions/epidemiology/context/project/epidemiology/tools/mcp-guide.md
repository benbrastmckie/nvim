# MCP Guide for Epidemiology

> **Note**: The rmcp MCP server is optional and may not be configured in all environments. When unavailable, fall back to `Rscript` via the Bash tool for R execution. All examples below work with either approach.

Guide to using Model Context Protocol (MCP) servers with R-based epidemiology workflows.

## rmcp (finite-sample/rmcp)

General-purpose R MCP server providing a suite of statistical tools.

### Installation
```bash
pip install rmcp
```

### Usage (Agent Configuration)
```json
"mcp_servers": {
  "rmcp": {
    "command": "rmcp",
    "args": ["start"]
  }
}
```

### Key Tools
- `linear_model`: OLS regression (Robust SEs, R-squared)
- `logistic_regression`: Binary outcome modeling (Odds Ratios)
- `correlation_analysis`: Pearson/Spearman/Kendall
- `time_series_analysis`: ARIMA, decomposition
- `hypothesis_testing`: t-tests, ANOVA, Chi-square

### Example Agent Prompt
"Use the `rmcp` server to run a logistic regression on `outcome ~ exposure + confounder` using the dataset `data.csv`."

---

## mcptools (CRAN)

Customizable MCP server implementation in R. Allows exposing specific R functions as MCP tools.

### Installation (R)
```r
install.packages("mcptools")
```

### Usage (Agent Configuration)
```json
"mcp_servers": {
  "mcptools": {
    "command": "Rscript",
    "args": ["-e", "mcptools::mcp_server()"]
  }
}
```

### Defining Custom Tools (in .Rprofile or script)
Create an R script that defines your custom epidemiology functions and registers them:

```r
library(mcptools)

# Define custom tool
calculate_incidence <- function(cases, population) {
  incidence_rate <- (cases / population) * 100000
  return(list(incidence_per_100k = incidence_rate))
}

# Register with server
mcp_tool("calculate_incidence", calculate_incidence, "Calculate incidence rate per 100k")

# Start server
mcp_server()
```

### Best Practices
- **rmcp**: Use for standard statistical analysis where pre-built tools suffice.
- **mcptools**: Use for domain-specific calculations or complex model wrappers (e.g., calling `EpiModel` functions).
