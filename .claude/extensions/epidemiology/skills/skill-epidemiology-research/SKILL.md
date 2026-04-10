---
name: skill-epidemiology-research
description: Research skill for epidemiology and study design
allowed_tools: Read, Write, Edit, Bash, WebSearch, WebFetch, Grep, Glob
context: project/epidemiology
---

# Epidemiology Research Skill

Routes epidemiology research tasks to `epidemiology-research-agent`.

## Usage

Invoked by orchestrator when task type is `epidemiology` or `r` and operation is research.

## Agent

- **Agent**: epidemiology-research-agent
- **Model**: opus

## Context

- Study Designs (Cohort, Case-Control, Cross-Sectional)
- Bias and Confounding
- Causal Inference (DAGs)
- Infectious Disease Dynamics (R0, Generation Time)
