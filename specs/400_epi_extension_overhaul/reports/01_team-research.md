# Research Report: Task #400 — Epidemiology Extension Overhaul

**Task**: 400 - Overhaul epidemiology extension: /epi command, epi:study routing, and infrastructure completion
**Date**: 2026-04-10
**Mode**: Team Research (4 teammates: Primary / Alternatives / Critic / Horizons)
**Session**: sess_1744320300_a4f8b2

---

## Executive Summary

The `.claude/extensions/epidemiology/` extension is a **functional stub** that is currently **silently unreachable** through the standard `/research`, `/plan`, and `/implement` pipeline. Its `manifest.json` has no `routing` block, so all three core commands fall back to the generic `skill-researcher` / `skill-planner` / `skill-implementer` — the extension's own `skill-epidemiology-research` and `skill-epidemiology-implementation` have never been invoked by the standard workflow. The extension has 14 files, ~616 lines, no commands, no routing, two stub agents (~30 lines each), two stub skills, four context files (vs. present's 27), and a field-name bug in `index-entries.json` (`languages` vs. canonical `task_types`) that would block context loading even after a successful merge. No existing tasks use `task_type: "epidemiology"`, so migration risk is zero.

The overhaul brings the extension to parity with `present/` (the correct structural analogue — NOT `founder/`, which is over-engineered for a single-entry-point extension), adds a `/epi` command with Stage 0 interactive scoping that produces `epi:study` compound tasks, and completes the command→skill→agent infrastructure across all three operations. Recommended scope: **1 new command, 3 skills (research/plan/implement), 2-3 upgraded agents, ~10 new/expanded context files, plus manifest routing, field-name fix, and keyword routing update in `/task`.**

---

## Key Findings

### 1. Critical Routing Gap (verified by all four teammates)

The epidemiology `manifest.json` has no `routing` section. The core commands scan `extensions/*/manifest.json` for `.routing.research[$task_type]`; only `founder` and `present` declare routing tables. Every other extension (python, nix, latex, lean4, web, formal, z3, **epidemiology**) silently falls back to default skills. The epidemiology-specific agents are never invoked through the standard pipeline.

**Evidence**:
- `.claude/extensions/epidemiology/manifest.json` — no `routing` key (manifest keys: name, version, description, task_type, dependencies, provides, merge_targets)
- `.claude/commands/research.md` lines 313–342 — manifest loop with `skill-researcher` fallback
- Same gap confirmed in `plan.md` and `implement.md`

### 2. Current State Inventory (epidemiology/)

**14 files, 616 lines total.**

| File | Lines | Status |
|------|-------|--------|
| manifest.json | 42 | Missing `routing`; `provides.commands: []` |
| README.md | 63 | Minimal; states "No dedicated commands" |
| EXTENSION.md | 35 | Uses old "Language Routing" framing |
| index-entries.json | 56 | 4 entries; uses `languages` (bug) instead of `task_types` |
| settings-fragment.json | 8 | Adds `rmcp` via `uvx`; not documented in README |
| opencode-agents.json | 32 | References non-existent `.opencode/` path |
| agents/epidemiology-research-agent.md | 29 | Stub (vs. talk-agent.md's 300 lines) |
| agents/epidemiology-implementation-agent.md | 30 | Stub |
| skills/skill-epidemiology-research/SKILL.md | 26 | Stub; no execution flow |
| skills/skill-epidemiology-implementation/SKILL.md | 47 | Stub; has MUST NOT but no execution stages |
| context/project/epidemiology/README.md | 39 | Adequate overview |
| context/project/epidemiology/tools/r-packages.md | 73 | Good reference |
| context/project/epidemiology/patterns/statistical-modeling.md | 60 | Good reference |
| context/project/epidemiology/tools/mcp-guide.md | 76 | Good reference |

**Missing structure**: no `commands/` directory, no `templates/` directory, no `domain/` context directory, no plan skill, no plan agent, no rules.

### 3. Reference Extension Comparison

| Capability | founder | present | epidemiology |
|------------|---------|---------|--------------|
| Routing block in manifest | Yes (11 compound keys) | Yes (6 compound keys) | **No** |
| Compound task_type keys | Yes | Yes | **No** (flat `epidemiology`) |
| Dedicated command files | 9 | 5 | **0** |
| Agents | 14 (full flows) | 5 (full flows) | 2 (stubs) |
| Skills | 14 (full flows) | 5 (full flows) | 2 (stubs) |
| Context index entries | ~40 | 27 | 4 |
| Plan skill | Yes (dedicated) | Routes to core `skill-planner` | **None** |
| Stage 0 forcing questions | Yes (all commands) | Yes (all commands) | **No** |
| Internal postflight pattern | Yes | Yes | No |
| Version | 3.0.0 | 1.0.0 | 1.0.0 |

**`present` is the correct reference model** (small, single-entry-point, growing). Founder's 9-command architecture is inappropriate and risks over-engineering. The present pattern of routing `plan` to the core `skill-planner` while keeping `research` and `implement` domain-specific is the recommended template.

### 4. Compound Routing Algorithm (how it works today)

The `/research`, `/plan`, `/implement` commands use inline two-pass lookup (not a shared helper):

1. First pass: exact compound key match (`epi:study` in `routing.research`)
2. Fallback: strip to base (`epi` in `routing.research`)
3. Final fallback: default skill (`skill-researcher`)

This is implemented identically in all three core command files (research.md lines 308–342 and parallel sections in plan.md / implement.md).

### 5. Context Loading Bug (index-entries.json field name)

`index-entries.json` declares `load_when.languages: ["r", "epidemiology"]`. The canonical `context/index.json` schema and all context discovery queries use `load_when.task_types`. The query in CLAUDE.md:

```bash
jq -r '.entries[] | select(any(.load_when.task_types[]?; . == $task_type)) | .path' .claude/context/index.json
```

Even if the extension is loaded and entries are merged, context files will never match because the field name is wrong. This must be fixed alongside routing.

### 6. Keyword Routing in `/task` Command

`.claude/commands/task.md` maps:
```
"epidemiology", "epimodel", "stan", "infectious" → epidemiology
```

After the rename, this must route to `epi:study` (or `epi`). "stan" is also used broadly in Bayesian contexts across other extensions and should be removed or scoped.

### 7. Doc-Lint Blind Spot

`.claude/scripts/check-extension-docs.sh` reports `epidemiology PASS` despite the missing routing block. The script does not validate `routing` presence. Fixing the extension without fixing the lint gate means any future extension can ship with the same bug.

### 8. AskUserQuestion Prior Art

Four distinct patterns exist in the codebase:

- **Pattern A — Mode-then-questions** (founder `/market`, `/strategy`): pick MODE first, then 3–5 domain questions
- **Pattern B — Materials-collection** (present `/slides`, `/grant`, founder `/deck`): type selection + file paths + audience/context narrative
- **Pattern C — File-first stateless** (filetypes `/convert`, `/scrape`): no forcing questions, no task creation
- **Pattern D — File-first autonomous** (founder `/meeting`): file path only, delegate immediately with web enrichment

**Pattern B is the closest fit for `/epi`** — study scoping is a materials-collection problem with file paths as primary inputs (data directories, protocols, codebooks, prior analyses).

### 9. R-Language Prior Art

Zero overlap with other extensions. The epidemiology extension is the sole R entry point in the repo. No `rmarkdown`, `quarto`, `tidyverse`, `lme4`, `epitools` references outside epidemiology/. Task 125 (archived) originally built the extension based on `EpiModel`, `epidemia`, `EpiNow2`, `EpiEstim`, `survival`, `rstan`, `cmdstanr`, `rmcp`, `mcptools`.

### 10. Zero Migration Risk

No tasks with `task_type: "epidemiology"` exist in `specs/state.json` or `specs/archive/`. Renaming to `epi:study` is a clean break. However, this also means the extension has **never been used** for any logged task; its design is unvalidated by real use.

### 11. Domain-Specific Gaps

Nothing in the current extension or task description addresses these epidemiology-essential concerns:

| Requirement | Present? |
|-------------|----------|
| IRB / ethics approval status | No |
| Pre-registration (OSF, ClinicalTrials.gov) | No |
| Reproducibility (renv / Docker / groundhog) | No |
| Reporting guidelines (STROBE / CONSORT / PRISMA) | No |
| Causal inference DAGs | Brief README mention only |
| Missing data handling (MCAR/MAR/MNAR, MI) | No |
| Sample size / power justification | No |
| Sensitivity analysis plan | Brief README mention only |
| Data confidentiality in commits | No |

The `/epi` scoping flow must at minimum collect study design type, ethics status, target reporting guideline, and causal structure (exposure/outcome/confounders) to avoid producing task metadata that leaves the implementation approach undefined.

### 12. Vestigial / Incorrect Artifacts

- `opencode-agents.json` references `.opencode/agent/subagents/epidemiology-research-agent.md` — no `.opencode/` directory exists at this level
- EXTENSION.md uses "Language: epidemiology → skill-epidemiology-research" framing instead of present's "Task Type" framing
- Implementation agent `Loads from: project/epidemiology/patterns/` but `patterns/` only has one file

---

## Synthesis: Recommended Approach

### Strategic Framing (per Horizons)

**Complete the extension to a first-class citizen using the compound-key pattern, and establish `/epi` as the canonical example of a scoping command for domain-specific studies.** Avoid two failure modes:

- **Over-ambitious**: do not generalize scoping into a reusable template during this task — pattern stabilization requires ≥2 working examples
- **Under-ambitious**: do not merely fix routing and leave `/epi` unbuilt — the command is the user-facing payoff

### Primary Recommendation (synthesizing Teammate A's primary and Teammate B's Alternative A)

Adopt a **present-style architecture** with compound `epi:study` routing, a single `/epi` command using Pattern B (materials-collection + mode selection), and upgraded (not from-scratch) skills/agents:

1. **Rename task_type prefix** from `epidemiology` → `epi` (keep extension directory name `epidemiology/` for continuity). Declare `task_type: "epi"` at manifest top level.

2. **Add full routing block** to `manifest.json`:
   ```json
   "routing": {
     "research": {
       "epidemiology": "skill-epi-research",  // backward compat alias
       "epi": "skill-epi-research",
       "epi:study": "skill-epi-research"
     },
     "plan": {
       "epidemiology": "skill-planner",
       "epi": "skill-planner",
       "epi:study": "skill-planner"
     },
     "implement": {
       "epidemiology": "skill-epi-implement",
       "epi": "skill-epi-implement",
       "epi:study": "skill-epi-implement"
     }
   }
   ```
   **Key synthesis decision**: route plan to core `skill-planner` (not a new `skill-epi-plan`) per present's pattern and Horizons' "what not to build now" guidance. A dedicated plan agent is deferred to a future task once research-report structure stabilizes. Differentiation comes from context files (STROBE, DAG patterns), not a new agent.

3. **Create `commands/epi.md`** using Pattern B (materials-collection). Accept three input types:
   - `/epi "description"` → Stage 0 forcing questions → create `epi:study` task → STOP at [NOT STARTED]
   - `/epi N` → resume existing `epi:study` task, delegate to `skill-epi-research`
   - `/epi /path/to/file.md` → read file as protocol/context → Stage 0 questions → create task

4. **Stage 0 Forcing Questions** (synthesis of A's 8-question list + C's domain requirements + D's causal structure):

   | # | Question | Stored as |
   |---|----------|-----------|
   | Q1 | Study design type (COHORT / CASE_CONTROL / CROSS_SECTIONAL / RCT / META_ANALYSIS / SURVEILLANCE / MODELING / OTHER) | `study_design` |
   | Q2 | Research question: outcome, exposure, population, time period | `research_question` |
   | Q3 | **Causal structure**: primary exposure, primary outcome, 1–3 suspected confounders (optional "skip") | `causal_structure` |
   | Q4 | Data paths (raw data dirs, codebooks, cleaned datasets — comma-separated or "none") | `data_paths[]` |
   | Q5 | Descriptive content paths (protocol, grant aims, preliminary notes, IRB submission, lit review) | `descriptive_paths[]` |
   | Q6 | Prior work references (`task:N` refs, prior scripts/reports/papers, or "none") | `prior_work[]` |
   | Q7 | **Ethics / pre-registration status** (APPROVED / PENDING / EXEMPT / NOT_REQUIRED / PREREGISTERED) | `ethics_status` |
   | Q8 | **Target reporting guideline** (STROBE / CONSORT / PRISMA / NONE) | `reporting_guideline` |
   | Q9 | R package preferences ("default" or specific package list) | `r_preferences` |
   | Q10 | Analysis plan hints (covariates, subgroups, sensitivity analyses, journal target) | `analysis_hints` |

   Store as `forcing_data` JSON object in state.json task entry (per founder/present convention). Agents load this via delegation context and skip re-asking.

   **Why Q3, Q7, Q8 are non-negotiable** (per Critic): causal structure enables DAG generation and determines statistical model; ethics status governs what data can be accessed and what must appear in the final report; reporting guideline determines the entire output structure.

5. **Skills to create/upgrade**:
   - **`skills/skill-epi-research/SKILL.md`** — full thin-wrapper skill following `skill-talk` pattern (11 stages: input validation → preflight → marker → delegation context with `forcing_data` → Task-tool invocation → metadata parse → postflight → artifact link → commit → cleanup → return). Supports two workflow types: `epi_research` (preflight=researching/success=researched) and `epi_assemble` (preflight=implementing/success=completed) — same skill handles both research and implement to reduce file count.
   - **`skills/skill-epi-implement/SKILL.md`** — full thin-wrapper skill OR alias to `skill-epi-research` with `workflow_type=epi_assemble` (present pattern). Recommend separate file for clarity.
   - Plan routes to core `skill-planner` — no new file.

6. **Agents to upgrade**:
   - **`agents/epi-research-agent.md`** (replacing `epidemiology-research-agent.md`) — full execution flow following `talk-agent.md` (~300 lines):
     - Stage 0: early metadata
     - Stage 1: parse delegation context (extract `forcing_data`)
     - Stage 2: load study-design context based on `study_design`
     - Stage 3: load source materials (read all `data_paths`, `descriptive_paths`, prior work via task refs or file reads)
     - Stage 4: survey data files (list, peek at structure, read codebooks)
     - Stage 5: design study analysis plan (select statistical model per study_design + outcome type, identify covariates from codebook, flag data quality issues, propose analysis phases)
     - Stage 6: identify gaps (missing data, undocumented variables, unclear outcomes)
     - Stage 7: write study design report with required sections: Executive Summary / Study Overview / Data Inventory / Proposed Analysis Phases / Variable Mapping / Statistical Approach / Data Quality Issues / R Package Recommendations / Content Gaps / Reporting Checklist (STROBE/CONSORT/PRISMA stub per `reporting_guideline`)
     - Stage 8: final metadata
     - Stage 9: brief text summary
   - **`agents/epi-implement-agent.md`** (replacing `epidemiology-implementation-agent.md`) — full phased flow:
     - Phase 1: Data preparation (read raw data, execute/write cleaning script → `analysis/01_data-clean.R`)
     - Phase 2: EDA (Table 1 by group, exposure-outcome visualizations, missing data assessment → `analysis/02_eda.R`)
     - Phase 3: Primary analysis (implement statistical model from plan, run via `Rscript`, capture output → `analysis/03_primary-analysis.R`)
     - Phase 4: Sensitivity analyses and model diagnostics → `analysis/04_sensitivity.R`
     - Phase 5: Reporting (compile results, format tables/figures, write `epi/{slug}-findings.md` per `reporting_guideline`)
   - **No `epi-plan-agent.md`** — plan routes to core `planner-agent` via `skill-planner`.

7. **Fix `index-entries.json`**:
   - Change `load_when.languages` → `load_when.task_types` in all 4 existing entries
   - Change values from `["r", "epidemiology"]` → `["epi", "epi:study"]`
   - Add `load_when.commands: ["/epi"]` trigger to all entries
   - Expand from 4 to ~12–14 entries as new context files are added

8. **New context files** (in `context/project/epidemiology/`):
   - `domain/study-designs.md` — cohort, case-control, cross-sectional, RCT, meta-analysis, surveillance, modeling (with R implementation hints)
   - `domain/r-workflow.md` — standard R project structure, renv basics, targets pipeline
   - `domain/data-management.md` — data cleaning, codebooks, missing data (MCAR/MAR/MNAR, MI)
   - `domain/reporting-standards.md` — STROBE / CONSORT / PRISMA with checklist stubs
   - `patterns/epi-scoping-questions.md` — question bank documentation for `/epi` Stage 0
   - `patterns/analysis-phases.md` — standard EDA → modeling → validation → reporting phases
   - `patterns/strobe-checklist.md` — 22 STROBE items as a reference (Horizons: zero-risk high-value addition)
   - `templates/study-protocol.md` — template for study design document
   - `templates/analysis-plan.md` — statistical analysis plan template
   - `templates/findings-report.md` — final findings report template
   - Keep existing: `tools/r-packages.md`, `tools/mcp-guide.md`, `patterns/statistical-modeling.md`, `README.md`

9. **Update `.claude/commands/task.md`** keyword routing:
   ```
   "epidemiology", "epi", "cohort", "case-control", "strobe" → epi:study
   ```
   Remove "stan" and "infectious" (too broad / too narrow).

10. **Update `EXTENSION.md` and `README.md`** to document:
    - `/epi` command signature and Stage 0 flow
    - Compound routing keys (`epi`, `epi:study`)
    - `rmcp` MCP server via `uvx` (currently undocumented in README)

11. **Fix `opencode-agents.json`** — either remove vestigial `.opencode/` references or move to appropriate location.

12. **Add `routing` validation to `check-extension-docs.sh`** — fail when a manifest declares `provides.commands` non-empty but has no `routing` block. Prevents regression.

### Alternative Approaches Considered

#### Alternative B: Formal-style Coordinator (per Teammate B)
Keep a flat `epi` task_type with no compound keys; upgrade `epi-research-agent` to function as a coordinator that inspects task keywords and routes internally to sub-agents (`epi-cohort-agent`, `epi-survival-agent`, `epi-infectious-agent`). **Rejected** — adds agent depth, routing becomes invisible in manifest inspection, and current task 400 explicitly requests `epi:study` compound routing.

#### Alternative C: Filetypes-style Stateless Command (per Teammate B)
Make `/epi` a pure scoping command that writes a scoping artifact to `specs/{NNN}_*/scoping/01_study-scope.md` without creating a task; user runs `/task` separately. **Rejected** — breaks the forcing_data pattern, requires new artifact directory type in `artifact-formats.md`, and introduces two-step ergonomic friction.

#### Alternative D: Founder-style Multi-Command (implied by task description)
Create separate `/epi-study`, `/epi-analysis`, `/epi-report` commands. **Rejected** by Critic and Horizons — over-engineering for an extension that has zero current users. Single `/epi` with mode selection is sufficient; sub-commands can be added later if usage reveals the need.

### Sub-typing: 2 keys vs. many

All four teammates converge on **2 compound keys initially**:
- `epi:study` (primary sub-type — study design through implementation and reporting)
- `epi` (bare fallback for legacy/generic tasks)

Defer `epi:analysis`, `epi:report`, `epi:surveillance`, `epi:review` until a concrete use case drives the split. Present has 5 sub-types but routes most of them to the same skills — epidemiology does not need more than 1 at this stage.

---

## Conflicts Found and Resolved

| # | Conflict | Resolution |
|---|----------|------------|
| 1 | A recommends renaming `task_type` to `epi`; B/C suggest keeping `epidemiology` alias for backward compat | **Both**: rename to `epi`, add `"epidemiology"` alias in routing table. Zero existing tasks, so alias is defensive-only. |
| 2 | A recommends `skill-epi-plan` (dedicated); B/D recommend routing plan to `skill-planner` | **Route to `skill-planner`** (present pattern). Horizons explicit: "do not build dedicated plan skill now". A's recommendation accepts this as option. |
| 3 | A proposes 3 sub-types (`epi:study`, `epi:analysis`, `epi:report`); B/C/D recommend only `epi:study` | **Only `epi:study`**. Defer others. |
| 4 | A says single skill handles research+implement (present pattern); C/D treat them as separate skills | **Separate skills for clarity** (`skill-epi-research`, `skill-epi-implement`), but implementation can be minimal wrappers around shared logic. |
| 5 | A includes 8 forcing questions; C adds ethics/IRB/reporting guidelines; D adds causal structure | **10 questions total** (merged): add ethics status (Q7), reporting guideline (Q8), and causal structure (Q3) on top of A's 8. |
| 6 | A uses `founder` and `present` equally as references; C warns founder over-engineers | **Present-primary**, founder secondary (only for compound routing table shape). |
| 7 | D recommends `scoping/` artifact directory (novel); others use `forcing_data` in state.json | **Use `forcing_data`** for now (matches existing pattern). Defer scoping artifact until artifact-formats.md is updated system-wide. |
| 8 | D recommends task "attachments" convention; others use simple path strings | **Simple path strings** in `forcing_data.data_paths[]` etc. Attachments convention is premature. |

---

## Gaps Identified (Unresolved — For Planner)

1. **Does `rmcp` actually work?** The extension declares `rmcp` via `uvx rmcp` but this has not been validated in the user's environment. Implementation phase must verify before agents rely on it.
2. **Should `/epi N` run research immediately or just resume?** Decision deferred to planner — recommend resume-only (per present/slides pattern).
3. **Absolute data paths in git commits** — forcing_data stored in state.json will contain absolute paths to data directories. If data is sensitive and specs/ is committed, paths leak. Planner should decide whether to warn users or store paths in a separate uncommitted file.
4. **Output format for findings report** — plain `.md` is the current default. Quarto/Rmarkdown deferred per Horizons' "defer" list.
5. **Lint script scope** — adding routing validation is recommended but adds scope. Planner decides whether to bundle or defer.
6. **`opencode-agents.json` vestigial path** — delete, leave as-is, or relocate? Needs user decision.
7. **"r" alias in routing** — currently documented in README as alias for epidemiology. Should be dropped (R is a general language, not epi-specific).

---

## Recommendations Summary (for Planner)

**Must include in plan**:
1. Add `routing` block to `manifest.json` with `epi`, `epi:study`, and `epidemiology` (alias) keys for all three operations
2. Rename `task_type` manifest field from `"epidemiology"` to `"epi"`
3. Create `commands/epi.md` with 10-question Stage 0 forcing flow (Pattern B: materials-collection with mode selection)
4. Create/upgrade `skills/skill-epi-research/SKILL.md` (full thin-wrapper, 11 stages)
5. Create/upgrade `skills/skill-epi-implement/SKILL.md` (full thin-wrapper, phased)
6. Route plan operations to core `skill-planner` in manifest routing table (no new plan skill)
7. Create/upgrade `agents/epi-research-agent.md` (full execution flow, ~300 lines, talk-agent pattern)
8. Create/upgrade `agents/epi-implement-agent.md` (full phased flow, 5 R-analysis phases)
9. Fix `index-entries.json` field name bug (`languages` → `task_types`) and expand to ~12–14 entries with `commands: ["/epi"]` triggers
10. Create new context files: `domain/study-designs.md`, `domain/r-workflow.md`, `domain/data-management.md`, `domain/reporting-standards.md`, `patterns/strobe-checklist.md`, `patterns/analysis-phases.md`, `patterns/epi-scoping-questions.md`, `templates/study-protocol.md`, `templates/analysis-plan.md`, `templates/findings-report.md`
11. Update `.claude/commands/task.md` keyword routing: `epidemiology|cohort|case-control|strobe` → `epi:study`
12. Update `EXTENSION.md` and `README.md` for new command, routing, and `rmcp` documentation
13. Fix or remove vestigial `opencode-agents.json` paths
14. Delete superseded files: `agents/epidemiology-research-agent.md`, `agents/epidemiology-implementation-agent.md`, `skills/skill-epidemiology-research/`, `skills/skill-epidemiology-implementation/`
15. Bump manifest version to `2.0.0`

**Should include**:
16. Add `routing` block presence check to `check-extension-docs.sh` (prevents regression)
17. Drop "r" alias from routing (too broad)

**Explicitly out of scope** (defer to future tasks per Horizons):
- Generic scoping command template (needs second example first)
- Dedicated `skill-epi-plan` with specialized planner agent
- Quarto / Rmarkdown output pipeline
- renv / Docker reproducibility scaffolding
- PubMed literature search via WebSearch (can be a research agent instruction, not infrastructure)
- Task "attachments" convention in artifact-formats.md
- Scoping artifact directory type

### Suggested Plan Phases

1. **Phase 1 — Routing and Manifest** (unblocks everything else): routing block, `task_type` rename, `index-entries.json` field fix, task.md keyword update, doc-lint check addition
2. **Phase 2 — Command**: `commands/epi.md` with Stage 0 forcing questions
3. **Phase 3 — Skills**: `skill-epi-research`, `skill-epi-implement` (full thin-wrapper flows)
4. **Phase 4 — Agents**: `epi-research-agent`, `epi-implement-agent` (full execution flows)
5. **Phase 5 — Context expansion**: domain/, patterns/, templates/ files
6. **Phase 6 — Documentation**: README, EXTENSION.md, cleanup (vestigial files, version bump)

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Output |
|----------|-------|--------|------------|--------|
| A | Primary approach + exhaustive inventory | completed | High | 876 lines — full file-by-file inventory, routing table design, complete `/epi` command spec, skill/agent execution stages, 25-file recommended file list |
| B | Alternatives + prior art | completed | High | 316 lines — 3 architectural patterns across all extensions, compound routing algorithm, 4 AskUserQuestion patterns, 3 alternatives (minimal/coordinator/stateless), R-language prior art survey |
| C | Critic — gaps and blind spots | completed | High | 188 lines — routing gap verification, `languages`/`task_types` bug, 12 concrete gaps, 10 open questions, 9 unvalidated assumptions, domain requirements checklist |
| D | Horizons — strategic alignment | completed | Medium | 207 lines — ROADMAP alignment (Phase 1 extension slim standard + frontmatter validation), must/should/should-not scoping, 6 creative options, 6-12 month trajectory, strategic framing |

**Synthesis confidence**: High. All four teammates independently verified the core routing gap, agreed on present-primary reference model, converged on 2 compound sub-types, and recommended thin-wrapper skills with upgraded agents. Disagreements were resolved in favor of the more conservative option (no dedicated plan skill, no multi-command architecture, no novel artifact types).

---

## References

- `.claude/extensions/epidemiology/` — full extension tree (14 files)
- `.claude/extensions/founder/manifest.json` — compound routing reference (11 keys)
- `.claude/extensions/present/manifest.json` — compound routing reference (6 keys)
- `.claude/extensions/present/commands/slides.md` — Stage 0 materials-collection pattern
- `.claude/extensions/present/agents/talk-agent.md` — full agent execution flow (~300 lines)
- `.claude/extensions/present/skills/skill-talk/SKILL.md` — thin-wrapper skill (11 stages) with internal postflight
- `.claude/extensions/founder/commands/market.md`, `strategy.md`, `deck.md` — Stage 0 mode-then-questions pattern
- `.claude/extensions/formal/agents/formal-research-agent.md` — agent-internal keyword routing (alternative)
- `.claude/commands/research.md` lines 308–342 — manifest routing lookup algorithm
- `.claude/commands/task.md` — keyword→task_type mapping table (needs update)
- `.claude/scripts/check-extension-docs.sh` — doc-lint (needs routing check added)
- `.claude/context/index.json` — canonical `load_when.task_types` field (not `languages`)
- `.claude/rules/artifact-formats.md` — artifact naming conventions
- `.claude/context/patterns/thin-wrapper-skill.md` — when to create vs. reuse skills
- `specs/archive/125_epidemiology_r_extension/reports/research-001.md` — original extension design
- `specs/ROADMAP.md` — Phase 1 extension slim standard and agent frontmatter validation alignment
- Teammate findings: `01_teammate-a-findings.md`, `01_teammate-b-findings.md`, `01_teammate-c-findings.md`, `01_teammate-d-findings.md`
