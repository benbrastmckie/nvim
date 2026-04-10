---
name: skill-epidemiology-implementation
description: Implementation skill for R-based epidemiology analysis
allowed_tools: Read, Write, Edit, Bash, WebSearch, WebFetch, Grep, Glob, rmcp, mcptools
context: project/epidemiology/tools, project/epidemiology/patterns
---

# Epidemiology Implementation Skill

Routes epidemiology implementation tasks to `epidemiology-implementation-agent`.

## Usage

Invoked by orchestrator when task type is `epidemiology` or `r` and operation is implementation.

## Agent

- **Agent**: epidemiology-implementation-agent
- **Model**: opus

## Context

- R Packages: EpiModel, epidemia, EpiNow2, EpiEstim
- Stan/Bayesian Modeling
- Statistical Patterns: Regression, Survival, Time-series
- Data Visualization: ggplot2, survminer

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit R files** - All R/epidemiology work is done by agent
2. **Run R scripts/tests** - Verification is done by agent
3. **Analyze or grep source** - Analysis is agent work
4. **Write summary/reports** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
