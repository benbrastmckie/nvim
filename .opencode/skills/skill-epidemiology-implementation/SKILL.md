---
name: skill-epidemiology-implementation
description: Implementation skill for R-based epidemiology analysis
allowed_tools: Read, Write, Edit, Bash, WebSearch, WebFetch, Grep, Glob, rmcp, mcptools
context: project/epidemiology/tools, project/epidemiology/patterns
---

# Epidemiology Implementation Skill

Routes epidemiology implementation tasks to `epidemiology-implementation-agent`.

## Usage

Invoked by orchestrator when task language is `epidemiology` or `r` and operation is implementation.

## Agent

- **Agent**: epidemiology-implementation-agent
- **Model**: opus

## Context

- R Packages: EpiModel, epidemia, EpiNow2, EpiEstim
- Stan/Bayesian Modeling
- Statistical Patterns: Regression, Survival, Time-series
- Data Visualization: ggplot2, survminer
