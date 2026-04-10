# Implementation Plan: Epidemiology Extension Overhaul

- **Task**: 400 - Overhaul epidemiology extension: /epi command, epi:study routing, and infrastructure completion
- **Status**: [NOT STARTED]
- **Effort**: 10 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md, reports/02_team-research.md
- **Artifacts**: plans/02_epi-extension-overhaul.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
  - .claude/rules/plan-format-enforcement.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The epidemiology extension is a functional stub with 14 files and ~616 lines that has never been reachable through the standard command pipeline due to a missing `routing` block in its manifest and a `languages` vs `task_types` field-name bug in index-entries.json. This plan overhauls the extension to first-class status using the `present/` extension as the structural reference model: adding a `/epi` command with 10-question interactive scoping (Pattern B materials-collection), compound `epi:study` task type routing, full skill and agent infrastructure for research/plan/implement, and ~1,400 lines of new domain context files covering study designs, causal inference, missing data, observational methods, reporting standards, and R package references. Definition of done: `/epi "study description"` creates an `epi:study` task, and `/research`, `/plan`, `/implement` on that task route through domain-specific agents that produce a study design report, implementation plan, and findings report.

### Research Integration

Two rounds of team research inform this plan:
- **Round 1** (01_team-research.md): Identified the critical routing gap, inventoried all 14 existing files, compared against founder/present extensions, established present as the correct reference model, resolved 8 architectural conflicts (compound routing yes, dedicated plan skill no, 2 sub-types only), and recommended 10 Stage 0 forcing questions.
- **Round 2** (02_team-research.md): Produced comprehensive R code patterns for all 7 major study designs, mapped the complete publication toolkit (tables, figures, reporting guidelines), identified 3 highest-risk domain gaps (causal inference, missing data, competing risks), and designed the hybrid context directory structure with 12-14 index entries and ~1,400-1,700 target lines.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances:
- **Extension slim standard enforcement** -- Bringing epidemiology to parity validates the extension standard
- **Agent frontmatter validation** -- New agents will use minimal frontmatter standard
- **Doc-lint improvements** -- Adding routing validation to check-extension-docs.sh prevents regression

## Goals & Non-Goals

**Goals**:
- Add `routing` block to manifest.json with `epi`, `epi:study`, and `epidemiology` alias keys
- Create `/epi` command with 10-question Stage 0 forcing flow producing `epi:study` tasks
- Build full skill thin-wrappers for research and implementation
- Build full agent execution flows for research (~300 lines) and implementation (~250 lines)
- Fix `index-entries.json` field-name bug and expand to ~12-14 entries
- Create ~10 new context files covering domain knowledge, patterns, templates, and tools
- Update task.md keyword routing, README.md, EXTENSION.md, and doc-lint script
- Clean up vestigial files (old agent/skill names, opencode-agents.json paths)

**Non-Goals**:
- Dedicated `skill-epi-plan` or plan agent (routes to core `skill-planner`)
- Quarto/Rmarkdown rendering pipeline
- renv/Docker reproducibility scaffolding
- Generic scoping command template (needs second example first)
- PubMed literature search automation
- Task "attachments" convention or scoping artifact directory type
- Sub-types beyond `epi:study` (defer `epi:analysis`, `epi:surveillance`, etc.)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Context files exceed token budget when loaded together | H | M | Use agent-scoped loading in index entries (research agent loads domain/, implement agent loads templates/) |
| `/epi` 10-question flow is too long for user patience | M | M | Make Q3 (causal structure), Q9 (R preferences), Q10 (analysis hints) accept "skip" |
| `rmcp` MCP server not functional in user environment | M | L | Note in agent instructions that rmcp is optional; fall back to Rscript |
| Compound routing not picked up by core commands | H | L | Verify by reading research.md/plan.md/implement.md routing logic; test with dry-run |
| Old file references break after agent/skill renames | M | M | Phase 6 includes explicit cleanup of all cross-references |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 5 | 1 |
| 3 | 4 | 3 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Manifest, Routing, and Index Fix [COMPLETED]

**Goal**: Make the epidemiology extension discoverable by the standard command pipeline. Fix all structural bugs that prevent routing and context loading.

**Tasks**:
- [ ] Update `manifest.json`: rename `task_type` from `"epidemiology"` to `"epi"`, add full `routing` block with keys for `epi`, `epi:study`, and `epidemiology` (backward alias) across research/plan/implement operations
- [ ] Route plan operations to `skill-planner` (core), research to `skill-epi-research`, implement to `skill-epi-implement`
- [ ] Fix `index-entries.json`: change `load_when.languages` to `load_when.task_types` in all 4 existing entries, update values from `["r", "epidemiology"]` to `["epi", "epi:study"]`, add `load_when.commands: ["/epi"]` trigger
- [ ] Update `.claude/commands/task.md` keyword routing: `"epidemiology", "epi", "cohort", "case-control", "strobe"` maps to `epi:study` (remove "stan" and "infectious")
- [ ] Add routing block presence check to `.claude/scripts/check-extension-docs.sh` -- fail when manifest declares `provides.skills` non-empty but has no `routing` block
- [ ] Bump manifest version to `2.0.0`

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/epidemiology/manifest.json` -- add routing block, rename task_type, bump version
- `.claude/extensions/epidemiology/index-entries.json` -- fix field name bug, update task_type values
- `.claude/commands/task.md` -- update keyword-to-task_type mapping
- `.claude/scripts/check-extension-docs.sh` -- add routing validation

**Verification**:
- `jq '.routing' .claude/extensions/epidemiology/manifest.json` returns non-null with all 3 operation types
- `jq '.[] | .load_when.task_types' .claude/extensions/epidemiology/index-entries.json` returns `["epi", "epi:study"]` for all entries
- `grep -c 'epi:study' .claude/commands/task.md` returns >= 1
- `.claude/scripts/check-extension-docs.sh` exits 0 for epidemiology

---

### Phase 2: /epi Command [COMPLETED]

**Goal**: Create the `/epi` command file that accepts a description, path, or task number and runs a 10-question interactive scoping flow to produce an `epi:study` task with `forcing_data`.

**Tasks**:
- [ ] Create `.claude/extensions/epidemiology/commands/epi.md` following Pattern B (materials-collection) from present's `/slides` command
- [ ] Implement three input modes: `/epi "description"` (new task), `/epi N` (resume existing), `/epi /path/to/file` (read file as protocol then scope)
- [ ] Implement 10-question Stage 0 forcing flow: study design type (Q1), research question (Q2), causal structure (Q3, skippable), data paths (Q4), descriptive content paths (Q5), prior work references (Q6), ethics status (Q7), reporting guideline (Q8), R preferences (Q9, skippable), analysis hints (Q10, skippable)
- [ ] Store answers as `forcing_data` JSON in state.json task entry per founder/present convention
- [ ] Create task with `task_type: "epi:study"` and `forcing_data` attached, then STOP at [NOT STARTED]
- [ ] Update manifest.json `provides.commands` to include `"/epi"`

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/epidemiology/commands/epi.md` -- CREATE new command file (~200-250 lines)
- `.claude/extensions/epidemiology/manifest.json` -- update `provides.commands` array

**Verification**:
- `commands/epi.md` exists with all 10 questions documented
- Command handles all three input modes (description, task number, file path)
- `forcing_data` schema includes all 10 fields
- Manifest `provides.commands` lists `"/epi"`

---

### Phase 3: Skills [COMPLETED]

**Goal**: Create full thin-wrapper skills for research and implementation that route through the epidemiology agents.

**Tasks**:
- [ ] Rewrite `skills/skill-epidemiology-research/SKILL.md` as `skills/skill-epi-research/SKILL.md` -- full thin-wrapper following `skill-talk` pattern (11 stages: input validation, preflight status update, marker, delegation context with `forcing_data`, subagent invocation of `epi-research-agent`, metadata parse, postflight status update, artifact linking, git commit, cleanup, return)
- [ ] Rewrite `skills/skill-epidemiology-implementation/SKILL.md` as `skills/skill-epi-implement/SKILL.md` -- full thin-wrapper with phased delegation to `epi-implement-agent`
- [ ] Delete old skill directories: `skills/skill-epidemiology-research/`, `skills/skill-epidemiology-implementation/`
- [ ] Update manifest.json `provides.skills` to reference new skill names

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/epidemiology/skills/skill-epi-research/SKILL.md` -- CREATE (~100-120 lines)
- `.claude/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` -- CREATE (~100-120 lines)
- `.claude/extensions/epidemiology/skills/skill-epidemiology-research/SKILL.md` -- DELETE
- `.claude/extensions/epidemiology/skills/skill-epidemiology-implementation/SKILL.md` -- DELETE
- `.claude/extensions/epidemiology/manifest.json` -- update provides.skills

**Verification**:
- Both new skills reference correct agent names (`epi-research-agent`, `epi-implement-agent`)
- Both follow 11-stage thin-wrapper pattern
- Old skill directories removed
- Manifest `provides.skills` lists `skill-epi-research` and `skill-epi-implement`

---

### Phase 4: Agents [NOT STARTED]

**Goal**: Build full execution-flow agents for research and implementation, replacing the 30-line stubs.

**Tasks**:
- [ ] Create `agents/epi-research-agent.md` (~300 lines) following `talk-agent.md` pattern with stages: Stage 0 early metadata, Stage 1 parse delegation context (extract `forcing_data`), Stage 2 load study-design context based on `study_design` field, Stage 3 load source materials (read all `data_paths`, `descriptive_paths`, prior work), Stage 4 survey data files (list directory, peek at structure, read codebooks), Stage 5 design study analysis plan (select statistical model per study_design + outcome type, identify covariates, flag data quality), Stage 6 identify gaps (missing data patterns, undocumented variables, unclear outcomes), Stage 7 write study design report (sections: Executive Summary, Study Overview, Data Inventory, Proposed Analysis Phases, Variable Mapping, Statistical Approach, Data Quality Issues, R Package Recommendations, Content Gaps, Reporting Checklist), Stage 8 final metadata, Stage 9 brief text summary
- [ ] Create `agents/epi-implement-agent.md` (~250 lines) with phased execution: Phase 1 data preparation (read raw data, write cleaning script `analysis/01_data-clean.R`), Phase 2 EDA (Table 1, visualizations, missing data assessment `analysis/02_eda.R`), Phase 3 primary analysis (implement model from plan `analysis/03_primary-analysis.R`), Phase 4 sensitivity analyses and diagnostics (`analysis/04_sensitivity.R`), Phase 5 reporting (compile results, format tables/figures, write findings report per `reporting_guideline`)
- [ ] Delete old agent files: `agents/epidemiology-research-agent.md`, `agents/epidemiology-implementation-agent.md`
- [ ] Ensure both agents use minimal frontmatter standard (`name`, `description`, `model: opus` for research agent)

**Timing**: 2 hours

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/epidemiology/agents/epi-research-agent.md` -- CREATE (~300 lines)
- `.claude/extensions/epidemiology/agents/epi-implement-agent.md` -- CREATE (~250 lines)
- `.claude/extensions/epidemiology/agents/epidemiology-research-agent.md` -- DELETE
- `.claude/extensions/epidemiology/agents/epidemiology-implementation-agent.md` -- DELETE

**Verification**:
- Research agent has 9+ stages with clear execution flow
- Implementation agent has 5 analysis phases with R script output paths
- Both agents reference `forcing_data` from delegation context
- Both use minimal frontmatter standard
- Old agent files removed

---

### Phase 5: Context Files [COMPLETED]

**Goal**: Create ~10 new context files and expand 2 existing ones to provide agents with the domain knowledge needed for competent epidemiology assistance. Target ~1,400 lines total.

**Tasks**:
- [ ] Create `context/project/epidemiology/domain/study-designs.md` (~180 lines) -- cohort, case-control, cross-sectional, RCT, meta-analysis, surveillance, modeling, quasi-experimental; each with R package pointers, key output, and statistical model
- [ ] Create `context/project/epidemiology/domain/causal-inference.md` (~130 lines) -- DAGs with dagitty/ggdag, adjustment sets, collider bias, mediation vs confounding, propensity scores (MatchIt/WeightIt/cobalt), target trial emulation reference
- [ ] Create `context/project/epidemiology/domain/missing-data.md` (~110 lines) -- MCAR/MAR/MNAR assessment with naniar, mice 4-step workflow, pooling rules, sensitivity to missing data mechanism
- [ ] Create `context/project/epidemiology/domain/data-management.md` (~130 lines) -- R project structure, data cleaning patterns, codebook conventions, REDCapR integration, data ethics and PHI in git
- [ ] Create `context/project/epidemiology/domain/reporting-standards.md` (~90 lines) -- STROBE (observational), CONSORT (RCT), PRISMA (systematic review), RECORD (EHR), TRIPOD+AI (prediction), with R tool mapping
- [ ] Create `context/project/epidemiology/domain/r-workflow.md` (~90 lines) -- renv basics, targets pipeline, Quarto manuscript authoring reference, journal format strategy (Word vs LaTeX)
- [ ] Create `context/project/epidemiology/patterns/observational-methods.md` (~130 lines) -- competing risks (tidycmprsk/CIF vs 1-KM), survey methods (survey/srvyr), mixed effects (lme4 + clubSandwich), sensitivity analysis (episensr/EValue), RERI (interactionR)
- [ ] Create `context/project/epidemiology/patterns/analysis-phases.md` (~90 lines) -- standard 5-phase workflow (data prep, EDA, primary analysis, sensitivity, reporting) with expected outputs per phase
- [ ] Create `context/project/epidemiology/patterns/strobe-checklist.md` (~70 lines) -- 22 STROBE items as reference with R annotation hints
- [ ] Create `context/project/epidemiology/templates/analysis-plan.md` (~130 lines) -- statistical analysis plan fill-in template
- [ ] Create `context/project/epidemiology/templates/findings-report.md` (~110 lines) -- final findings report fill-in template
- [ ] Expand `context/project/epidemiology/patterns/statistical-modeling.md` -- add logistic regression, modified Poisson, mixed effects, Bayesian (brms), model diagnostics beyond cox.zph (~150 lines added)
- [ ] Expand `context/project/epidemiology/tools/r-packages.md` -- add ~30 packages covering tables (gtsummary, modelsummary), missing data (mice, naniar), propensity scores (MatchIt, WeightIt), competing risks (tidycmprsk), causal inference (dagitty, ggdag), sensitivity (episensr, EValue), Bayesian (brms), basic epi (epiR, epitools), figures (survminer, forestploter, patchwork), prediction (rms, pROC), reproducibility (renv, targets) (~200 lines added)
- [ ] Update `context/project/epidemiology/tools/mcp-guide.md` -- note rmcp is optional, add fallback to Rscript
- [ ] Update `context/project/epidemiology/README.md` -- expand to ~80 lines with directory map and usage overview

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/epidemiology/context/project/epidemiology/domain/study-designs.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/domain/causal-inference.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/domain/missing-data.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/domain/data-management.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/domain/reporting-standards.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/domain/r-workflow.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/patterns/observational-methods.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/patterns/analysis-phases.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/patterns/strobe-checklist.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/templates/analysis-plan.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/templates/findings-report.md` -- CREATE
- `.claude/extensions/epidemiology/context/project/epidemiology/patterns/statistical-modeling.md` -- EXPAND
- `.claude/extensions/epidemiology/context/project/epidemiology/tools/r-packages.md` -- EXPAND
- `.claude/extensions/epidemiology/context/project/epidemiology/tools/mcp-guide.md` -- UPDATE
- `.claude/extensions/epidemiology/context/project/epidemiology/README.md` -- EXPAND

**Verification**:
- All new files exist under the correct directory paths
- `domain/` has 6 files, `patterns/` has 4 files (1 existing + 3 new), `templates/` has 2 files, `tools/` has 2 files (existing)
- Total new context lines approximately 1,400-1,700
- Each file has a context header comment with priority and version

---

### Phase 6: Documentation, Index, and Cleanup [NOT STARTED]

**Goal**: Update all cross-references, expand index-entries.json to cover new files, clean up vestigial artifacts, update extension documentation, and verify end-to-end consistency.

**Tasks**:
- [ ] Expand `index-entries.json` from 4 to ~14 entries covering all new context files with appropriate `load_when` scoping: domain files for research agent + /epi command, patterns for both agents, templates for implement agent only, tools for both agents + /epi
- [ ] Update `EXTENSION.md` -- replace "Language Routing" framing with "Task Type" framing, document `/epi` command, compound routing keys, skill/agent mapping
- [ ] Update `README.md` -- document `/epi` command signature and Stage 0 flow, compound routing, rmcp MCP server, full file inventory
- [ ] Fix `opencode-agents.json` -- update agent file references to new names (`epi-research-agent.md`, `epi-implement-agent.md`) or remove if `.opencode/` path is entirely vestigial
- [ ] Remove `settings-fragment.json` reference to `rmcp` if undocumented, or document it in README
- [ ] Verify all manifest.json cross-references are consistent: `provides.commands`, `provides.skills`, `provides.agents`, `routing` keys all reference actual files
- [ ] Run `check-extension-docs.sh` to validate the extension passes all checks including new routing validation
- [ ] Verify no remaining references to old names (`epidemiology-research-agent`, `epidemiology-implementation-agent`, `skill-epidemiology-research`, `skill-epidemiology-implementation`) anywhere in the extension directory

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**:
- `.claude/extensions/epidemiology/index-entries.json` -- expand to ~14 entries
- `.claude/extensions/epidemiology/EXTENSION.md` -- rewrite framing and document new infrastructure
- `.claude/extensions/epidemiology/README.md` -- full documentation update
- `.claude/extensions/epidemiology/opencode-agents.json` -- fix or remove vestigial paths

**Verification**:
- `jq 'length' .claude/extensions/epidemiology/index-entries.json` returns ~14
- `check-extension-docs.sh` exits 0
- `grep -r "epidemiology-research-agent\|epidemiology-implementation-agent\|skill-epidemiology-research\|skill-epidemiology-implementation" .claude/extensions/epidemiology/` returns no matches
- EXTENSION.md references `/epi` command and `epi:study` routing
- README.md has complete file inventory

## Testing & Validation

- [ ] Routing verification: `jq '.routing.research["epi:study"]' manifest.json` returns `"skill-epi-research"`
- [ ] Index loading: context discovery query with `task_type="epi:study"` returns all domain/patterns files
- [ ] Command discovery: `jq '.routing.plan["epi"]' manifest.json` returns `"skill-planner"`
- [ ] Keyword routing: `grep "epi:study" .claude/commands/task.md` confirms keyword mapping
- [ ] Doc-lint: `check-extension-docs.sh` exits 0 for all extensions
- [ ] No stale references: no files reference old agent/skill names
- [ ] Skill thin-wrapper pattern: both skills follow 11-stage structure
- [ ] Agent execution flow: research agent has 9+ stages, implement agent has 5 R-analysis phases
- [ ] Context coverage: `find .claude/extensions/epidemiology/context -name "*.md" | wc -l` returns >= 15

## Artifacts & Outputs

- `.claude/extensions/epidemiology/manifest.json` -- updated with routing, version 2.0.0
- `.claude/extensions/epidemiology/commands/epi.md` -- new /epi command
- `.claude/extensions/epidemiology/skills/skill-epi-research/SKILL.md` -- new research skill
- `.claude/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` -- new implement skill
- `.claude/extensions/epidemiology/agents/epi-research-agent.md` -- new research agent
- `.claude/extensions/epidemiology/agents/epi-implement-agent.md` -- new implement agent
- `.claude/extensions/epidemiology/context/project/epidemiology/domain/` -- 6 new files
- `.claude/extensions/epidemiology/context/project/epidemiology/patterns/` -- 3 new files + 1 expanded
- `.claude/extensions/epidemiology/context/project/epidemiology/templates/` -- 2 new files
- `.claude/extensions/epidemiology/context/project/epidemiology/tools/` -- 2 expanded files
- `.claude/extensions/epidemiology/index-entries.json` -- expanded to ~14 entries
- `.claude/extensions/epidemiology/EXTENSION.md` -- rewritten
- `.claude/extensions/epidemiology/README.md` -- expanded
- `.claude/commands/task.md` -- keyword routing updated
- `.claude/scripts/check-extension-docs.sh` -- routing validation added

## Rollback/Contingency

All changes are within the `.claude/extensions/epidemiology/` directory (except task.md keyword update and check-extension-docs.sh). Rollback via `git checkout HEAD -- .claude/extensions/epidemiology/ .claude/commands/task.md .claude/scripts/check-extension-docs.sh` restores the previous state. Since no existing tasks use `task_type: "epidemiology"`, there is zero migration risk. The old agent/skill files will be preserved in git history.
