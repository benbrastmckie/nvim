# Research Report: Task #400 - Teammate A (Primary Approach)

**Task**: 400 - Overhaul epidemiology extension: /epi command, epi:study routing, and infrastructure completion
**Role**: PRIMARY APPROACH
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T01:00:00Z
**Effort**: ~60 min
**Sources/Inputs**: Codebase exploration (all files in epidemiology/, founder/, present/ extensions)
**Artifacts**: This report
**Standards**: report-format.md, return-metadata-file.md

---

## Key Findings

### 1. Exhaustive Inventory: epidemiology/ Extension

**Total files**: 14 files, 616 lines

| File | Lines | Role | Status |
|------|-------|------|--------|
| `manifest.json` | 42 | Extension declaration, no routing table | MISSING routing section |
| `README.md` | 63 | Human-readable overview | Adequate but minimal |
| `EXTENSION.md` | 35 | CLAUDE.md merge snippet | Adequate |
| `index-entries.json` | 56 | 4 context entries for context/index.json | Adequate |
| `settings-fragment.json` | 8 | Adds rmcp MCP server | Present |
| `opencode-agents.json` | 32 | OpenCode agent definitions | Present |
| `agents/epidemiology-research-agent.md` | 29 | Stub agent, very thin | UNDERDEVELOPED |
| `agents/epidemiology-implementation-agent.md` | 30 | Stub agent, very thin | UNDERDEVELOPED |
| `skills/skill-epidemiology-research/SKILL.md` | 26 | Stub skill, no execution flow | UNDERDEVELOPED |
| `skills/skill-epidemiology-implementation/SKILL.md` | 47 | Has MUST NOT section but no execution flow | UNDERDEVELOPED |
| `context/project/epidemiology/README.md` | 39 | Domain overview | Adequate |
| `context/project/epidemiology/tools/r-packages.md` | 73 | R package reference | Good |
| `context/project/epidemiology/patterns/statistical-modeling.md` | 60 | Modeling patterns | Good |
| `context/project/epidemiology/tools/mcp-guide.md` | 76 | MCP integration guide | Good |

**Critical observations**:
- The `manifest.json` has NO `routing` section whatsoever. There is only a flat `task_type: "epidemiology"` field.
- `provides.commands` is empty array `[]` - no dedicated command file exists.
- The two agent files are stubs: 29-30 lines each vs. talk-agent.md (300 lines) and deck-research-agent.md (420 lines).
- The two skill files are stubs: 26-47 lines each vs. skill-talk (318 lines) and skill-deck-research (330 lines). They lack the full execution flow (Stage 1 through Stage 11 pattern).
- There is NO plan skill, NO plan agent. The extension does not cover plan routing.
- Context has 4 entries (all loaded by `languages` and `agents` fields only, not by `commands`).
- No `commands/` directory exists.
- No `templates/` directory exists.
- No `rules/` directory exists.
- No domain knowledge directory (`domain/`) equivalent to present/context/project/present/domain/.

### 2. Exhaustive Inventory: founder/ Extension (Reference A)

**Total files**: ~100+ files, deeply developed

**Structural strengths**:
- `manifest.json` has full `routing` table with 3 sections (research/plan/implement), 11 compound keys each: `founder`, `founder:market`, `founder:analyze`, `founder:strategy`, `founder:legal`, `founder:project`, `founder:sheet`, `founder:finance`, `founder:financial-analysis`, `founder:deck`, `founder:meeting`
- `provides.commands` lists 9 command files: `market.md`, `analyze.md`, `strategy.md`, `legal.md`, `project.md`, `sheet.md`, `finance.md`, `deck.md`, `meeting.md`
- Each command uses the STAGE 0 pre-task forcing question pattern
- 13 agents, 14 skills - all with full execution flows
- Rich context: `domain/`, `patterns/`, `templates/` (including Typst templates), `deck/` subdirectory with themes, components, patterns
- Full `routing` table: base `founder` -> `skill-market`, compound `founder:deck` -> `skill-deck-research` for research but `skill-deck-plan` for plan and `skill-deck-implement` for implement (deck has its own complete skill triple)
- version `3.0.0` - mature, iterated extension

**Key routing pattern** (manifest.json):
```json
"routing": {
  "research": {
    "founder": "skill-market",
    "founder:market": "skill-market",
    "founder:deck": "skill-deck-research"
  },
  "plan": {
    "founder": "skill-founder-plan",
    "founder:deck": "skill-deck-plan"
  },
  "implement": {
    "founder": "skill-founder-implement",
    "founder:deck": "skill-deck-implement"
  }
}
```

**Command pattern**: Each command (e.g., `/deck`, `/strategy`) accepts:
- `"description"` -> STAGE 0 forcing questions -> task creation -> STOP at [NOT STARTED]
- `TASK_NUMBER` -> validate task -> delegate to skill -> STOP at [RESEARCHED]
- `/path/to/file` -> read file + forcing questions -> task creation
- `--quick [args]` -> legacy standalone mode

### 3. Exhaustive Inventory: present/ Extension (Reference B)

**Total files**: ~70+ files

**Structural strengths**:
- `manifest.json` has full `routing` table with 3 sections, 6 compound keys each: `present`, `present:grant`, `present:budget`, `present:timeline`, `present:funds`, `present:talk`
- `provides.commands` lists 5 command files: `grant.md`, `budget.md`, `timeline.md`, `funds.md`, `slides.md`
- Each command uses STAGE 0 pre-task forcing questions
- 5 agents, 5 skills - all with full execution flows using the internal postflight pattern
- Rich context: `domain/` (8 files), `patterns/` (8 files), `templates/` (5+ files), `standards/` (2 files), `talk/` (deep component library with patterns, themes, Vue components, content templates)
- `index-entries.json` has 27 entries (vs. epidemiology's 4)
- Present shows that the `plan` routing can re-use the core `skill-planner` (the present manifest routes all plan operations to `"skill-planner"`) while having domain-specific research and implement skills

**Key routing pattern** (manifest.json):
```json
"routing": {
  "research": {
    "present:talk": "skill-talk"
  },
  "plan": {
    "present:talk": "skill-planner"
  },
  "implement": {
    "present:talk": "skill-talk"
  }
}
```
Note: present routes research AND implement through `skill-talk` (single skill handles both), while plan routes through the core `skill-planner`.

### 4. Gap Analysis: What Epidemiology is Missing vs. founder/present

| Feature | epidemiology/ | founder/ | present/ |
|---------|--------------|---------|---------|
| Routing table in manifest | NO | YES (11 compound keys) | YES (6 compound keys) |
| Compound task_type keys (`epi:study`) | NO | YES | YES |
| `/epi` command file | NO | YES (9 commands) | YES (5 commands) |
| Full skill execution flows | NO (stubs only) | YES (14 skills) | YES (5 skills) |
| Plan skill | NO | YES (`skill-founder-plan`) | YES (routes to `skill-planner`) |
| Plan agent | NO | YES (`founder-plan-agent`) | NO (uses core `planner-agent`) |
| Implementation agent with phased workflow | NO (stub) | YES | YES |
| Context domain/ directory | NO | YES | YES |
| Context patterns/ (full) | Partial (1 file) | YES (many) | YES (many) |
| Context templates/ | NO | YES (Typst templates) | YES |
| Context standards/ | NO | NO | YES |
| index-entries with commands trigger | NO | YES | YES |
| Forcing questions scoping workflow | NO | YES | YES |
| Internal postflight pattern in skills | NO | YES | YES |
| Version > 1.0.0 | NO (v1.0.0) | YES (v3.0.0) | YES (v1.0.0) |

---

## Recommended Approach

### Overview

The recommended approach brings epidemiology to parity with the present/ extension (which is the closer analogue: domain-specific research workflows, not startup pitching). The core of the work is:

1. **Add routing table** to manifest.json with compound `epi:study`, `epi:analysis`, `epi:report` keys
2. **Create `/epi` command** using the STAGE 0 forcing questions pattern from `/slides` and `/strategy`
3. **Upgrade agent files** from 29-line stubs to full execution-flow agents
4. **Upgrade skill files** from stubs to full thin-wrapper skills with internal postflight
5. **Add plan routing** (use core `skill-planner` like present does, or create `skill-epi-plan` for domain-specific planning)
6. **Expand context** with domain/, patterns/, templates/ directories and update index-entries.json
7. **Rename extension prefix** from `epidemiology` to `epi` to match the compound key pattern (`epi:study`)

### File-by-File Plan

#### Files to MODIFY:

**1. `manifest.json`** - Add routing table and update structure

```json
{
  "name": "epidemiology",
  "version": "2.0.0",
  "description": "Epidemiology research extension for R. Provides /epi command for scoping studies, with compound routing epi:study, epi:analysis, epi:report.",
  "task_type": "epi",
  "dependencies": [],
  "provides": {
    "agents": [
      "epi-research-agent.md",
      "epi-plan-agent.md",
      "epi-implement-agent.md"
    ],
    "skills": [
      "skill-epi-research",
      "skill-epi-plan",
      "skill-epi-implement"
    ],
    "commands": ["epi.md"],
    "rules": [],
    "context": ["project/epidemiology"],
    "scripts": [],
    "hooks": []
  },
  "routing": {
    "research": {
      "epi": "skill-epi-research",
      "epi:study": "skill-epi-research",
      "epi:analysis": "skill-epi-research",
      "epi:report": "skill-epi-research"
    },
    "plan": {
      "epi": "skill-epi-plan",
      "epi:study": "skill-epi-plan",
      "epi:analysis": "skill-epi-plan",
      "epi:report": "skill-epi-plan"
    },
    "implement": {
      "epi": "skill-epi-implement",
      "epi:study": "skill-epi-implement",
      "epi:analysis": "skill-epi-implement",
      "epi:report": "skill-epi-implement"
    }
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_epidemiology"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    },
    "settings": {
      "source": "settings-fragment.json",
      "target": ".claude/settings.local.json"
    },
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json"
    }
  }
}
```

**Key decision**: The base `task_type` in the manifest top-level should change from `"epidemiology"` to `"epi"` to match the compound key prefix. Routing entries should cover `epi` (bare fallback) and `epi:study`, `epi:analysis`, `epi:report` (compound sub-types).

**2. `index-entries.json`** - Add 8-12 new entries

Add entries for new domain/ context files, each with `"commands": ["/epi"]` in `load_when`. Follow the present extension's pattern of triggering on both agents AND commands. Example new entry:

```json
{
  "path": "project/epidemiology/domain/study-designs.md",
  "domain": "project",
  "subdomain": "epidemiology",
  "topics": ["cohort", "case-control", "cross-sectional", "rct", "meta-analysis"],
  "keywords": ["study-design", "epidemiology", "observational", "experimental"],
  "summary": "Epidemiology study design types with R implementation approaches",
  "line_count": 120,
  "load_when": {
    "languages": ["epi", "epidemiology"],
    "agents": ["epi-research-agent"],
    "commands": ["/epi"]
  }
}
```

**3. `EXTENSION.md`** - Update to reflect new command, routing, compound keys, and agent names.

**4. `README.md`** - Update to document `/epi` command and compound task_type routing.

#### Files to CREATE:

**5. `commands/epi.md`** - New `/epi` command (full design below)

**6. `skills/skill-epi-research/SKILL.md`** - Full thin-wrapper research skill (upgrade from stub)

**7. `skills/skill-epi-plan/SKILL.md`** - New plan skill (can route to core `planner-agent` OR to `epi-plan-agent`)

**8. `skills/skill-epi-implement/SKILL.md`** - Full thin-wrapper implement skill (upgrade from stub)

**9. `agents/epi-research-agent.md`** - Full research agent (upgrade from 29-line stub)

**10. `agents/epi-plan-agent.md`** - New plan agent (or route plan to core `planner-agent`)

**11. `agents/epi-implement-agent.md`** - Full implementation agent (upgrade from 30-line stub)

**12-20. Context files** in `context/project/epidemiology/domain/`:
- `study-designs.md` - cohort, case-control, cross-sectional, RCT, meta-analysis, surveillance
- `r-workflow.md` - Standard R project structure, renv, targets pipeline
- `data-management.md` - Data cleaning, codebooks, missing data strategies
- `reporting-standards.md` - STROBE, CONSORT, PRISMA reporting checklists

**21-24. Context files** in `context/project/epidemiology/patterns/`:
- `epi-scoping-questions.md` - Question bank for /epi command scoping
- `analysis-phases.md` - Standard EDA -> modeling -> validation -> reporting phases
- `r-code-patterns.md` - R script templates for common analysis tasks

**25-28. Context files** in `context/project/epidemiology/templates/`:
- `study-protocol.md` - Template for study design document
- `analysis-plan.md` - Statistical analysis plan template
- `findings-report.md` - Final findings report template (markdown)

#### Files to RENAME (or keep with deprecation note):

The existing `epidemiology-research-agent.md` and `epidemiology-implementation-agent.md` should be superseded by `epi-research-agent.md` and `epi-implement-agent.md`. The old files can be removed or redirected.

Similarly, `skill-epidemiology-research` and `skill-epidemiology-implementation` should be superseded by `skill-epi-research` and `skill-epi-implement`.

---

### `/epi` Command Design

**File**: `.claude/extensions/epidemiology/commands/epi.md`

**Frontmatter**:
```yaml
---
description: Create epidemiology study tasks with structured scoping questions for R-based analysis
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Bash(sed:*), Read, Edit, AskUserQuestion
argument-hint: "description" | TASK_NUMBER | /path/to/file.md
model: opus
---
```

**Input types** (following founder/present pattern):
| Input | Behavior |
|-------|----------|
| Description string | STAGE 0 forcing questions, create `epi:study` task, stop at [NOT STARTED] |
| Task number | Load existing task, delegate to skill-epi-research, stop at [RESEARCHED] |
| File path | Read file as study description/protocol, ask questions, create task |

**STAGE 0: PRE-TASK FORCING QUESTIONS**

The scoping questions cover the 8 key dimensions of an epidemiology study:

**Q1: Study Design Type**
```
What type of epidemiological study is this?

- COHORT: Prospective or retrospective cohort study
- CASE_CONTROL: Case-control study (incident or prevalent cases)
- CROSS_SECTIONAL: Cross-sectional survey or analysis
- RCT: Randomized controlled trial (analysis of existing trial data)
- META_ANALYSIS: Systematic review and meta-analysis
- SURVEILLANCE: Surveillance data analysis or outbreak investigation
- OTHER: Other design (describe)
```
Store as `forcing_data.study_design`.

**Q2: Research Question - Outcome, Exposure, Population**
```
Describe the core research question:
- What is the primary outcome (disease, event, measure)?
- What is the primary exposure or intervention?
- Who is the study population (age, geography, clinical setting)?
- What is the time period or data source?
```
Store as `forcing_data.research_question`.

**Q3: Data Paths - Raw Data and Codebooks**
```
What data files are available for this analysis?

Provide any combination of:
- Paths to raw data directories (e.g., /path/to/data/)
- Paths to codebooks or data dictionaries (e.g., /path/to/codebook.csv)
- Paths to previously cleaned datasets
- "none" if data has not been acquired yet

Separate multiple entries with commas.
```
Store as `forcing_data.data_paths` (parse into array).

**Q4: Prior Analyses and Literature**
```
Are there prior analyses, reports, or literature to inform this study?

Provide any combination of:
- Task references (e.g., "task:N" to pull prior research reports)
- File paths to prior analysis scripts, reports, or papers
- "none" if starting fresh

Separate multiple entries with commas.
```
Store as `forcing_data.prior_work` (parse into array).

**Q5: Descriptive Content Paths**
```
Do you have descriptive text that should inform the study design?

Examples: study protocol documents, grant aims, preliminary analysis notes, IRB submission, literature review summaries.

Provide file paths or "none":
```
Store as `forcing_data.descriptive_paths` (parse into array).

**Q6: R Package Preferences**
```
Do you have R package preferences for this analysis?

Default packages will be selected based on study design. If you prefer specific packages, indicate here:
- Survival analysis: survival, survminer (default) OR cmprsk (competing risks)
- Longitudinal: lme4/nlme (default) OR geepack (GEE)
- Bayesian: brms (default) OR epidemia/Stan
- Data manipulation: tidyverse (default) OR data.table
- Other preferences: (specify)

Enter "default" to use recommended packages, or list your preferences:
```
Store as `forcing_data.r_preferences`.

**Q7: Analysis Plan Hints**
```
Do you have any specific analysis plan requirements or constraints?

Examples:
- Covariates to include/exclude
- Subgroup analyses required
- Sensitivity analyses planned
- Reporting standards (STROBE, CONSORT, PRISMA)
- Journal or audience target

Enter your requirements or "none":
```
Store as `forcing_data.analysis_hints`.

**Q8: Reporting Format**
```
What is the desired output format for findings?

- MARKDOWN: Markdown report (default, always generated)
- TYPST: Typst document for PDF output (requires typst CLI)
- RMARKDOWN: R Markdown document for reproducible reporting
- QUARTO: Quarto document
```
Store as `forcing_data.report_format`.

**Post-Q: Store forcing_data object**:
```json
{
  "study_design": "COHORT",
  "research_question": "Does X exposure increase Y outcome risk in Z population?",
  "data_paths": ["/path/to/data/", "/path/to/codebook.csv"],
  "prior_work": ["task:234", "/path/to/prior-analysis.R"],
  "descriptive_paths": ["/path/to/protocol.md"],
  "r_preferences": "default",
  "analysis_hints": "STROBE reporting required, adjust for age/sex/SES",
  "report_format": "MARKDOWN",
  "gathered_at": "ISO_TIMESTAMP"
}
```

**Task creation** (in state.json):
```json
{
  "project_number": N,
  "project_name": "epi_study_SLUG",
  "status": "not_started",
  "task_type": "epi:study",
  "description": "Epidemiology study: DESCRIPTION",
  "forcing_data": { ... },
  "created": "ISO_TIMESTAMP"
}
```

Note: `task_type` is the compound key `"epi:study"` (not just `"epi"`), following the present/founder pattern of storing the sub-type as the full compound key.

**STAGE 2 (task number input): Delegate to skill-epi-research**

When input is a task number:
1. Validate task exists, `task_type` starts with `"epi:"`
2. Invoke `skill-epi-research` with task context and forcing_data
3. Gate out: verify status updated to `"researched"`

**Output - Task Created Summary**:
```
Epidemiology study task created: Task #{N}

Scoping Data Gathered:
- Study Design: {study_design}
- Research Question: {summary}
- Data Sources: {N} paths provided
- Prior Work: {N} references
- R Preferences: {r_preferences}
- Report Format: {report_format}

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to analyze all materials and produce study design report
- Run /plan {N} to create phased R implementation plan
- Run /implement {N} to execute analysis, review results, write final report
```

---

### Skill Design

#### `skill-epi-research/SKILL.md`

**Pattern**: Follows `skill-talk/SKILL.md` (thin wrapper with internal postflight).

**Workflow types**:
| Workflow Type | Preflight Status | Success Status |
|---------------|-----------------|----------------|
| epi_research | researching | researched |
| epi_assemble | implementing | completed |

**Agent**: `epi-research-agent`

**Execution stages** (11-stage pattern like skill-talk):
1. Input validation (task_number, session_id)
2. Preflight status update (state.json + TODO.md)
3. Create postflight marker
4. Prepare delegation context (pass forcing_data from task metadata)
5. Invoke agent via Task tool
6. Parse metadata file
7. Update task status (postflight)
8. Link artifacts in state.json + TODO.md
9. Git commit
10. Cleanup
11. Return brief summary

#### `skill-epi-plan/SKILL.md`

**Strategy**: Route to core `skill-planner` (same as present extension does). This avoids creating yet another plan skill. The core planner-agent can read the epi research report and produce a phased R analysis plan.

**Alternative**: Create a dedicated `skill-epi-plan` + `epi-plan-agent` that understands epidemiology-specific plan phases. This provides better domain knowledge but increases scope.

**Recommendation**: Start with routing plan to `skill-planner` (lower scope, sufficient for v2.0.0). The research report from `epi-research-agent` will contain enough structured information for `planner-agent` to produce a good plan.

```yaml
---
name: skill-epi-plan
description: Epidemiology study planning - routes to planner-agent
allowed-tools: Task, Bash, Edit, Read, Write
---
```
Routes to the core `planner-agent` with epidemiology context loaded.

#### `skill-epi-implement/SKILL.md`

**Pattern**: Full thin wrapper like `skill-talk` or `skill-grant`.

**Key responsibilities**:
1. Preflight status update
2. Delegate to `epi-implement-agent` via Task tool
3. Postflight: status, artifacts, git commit, cleanup

---

### Agent Design

#### `epi-research-agent.md`

**Model**: opus (following convention for research agents)

**Execution flow** (following talk-agent.md pattern):

- **Stage 0**: Initialize early metadata
- **Stage 1**: Parse delegation context (extract forcing_data)
- **Stage 2**: Load study design context (based on `forcing_data.study_design`)
- **Stage 3**: Load source materials
  - Read all `forcing_data.data_paths` (data directories, codebooks)
  - Read all `forcing_data.descriptive_paths` (protocols, notes)
  - Load prior work from `forcing_data.prior_work` (task references, file paths)
- **Stage 4**: Survey data files - list files, peek at structure (head/str/glimpse), read codebooks
- **Stage 5**: Design study analysis plan
  - Select appropriate statistical model based on study_design + outcome type
  - Identify covariates from codebook
  - Flag data quality issues
  - Propose analysis phases
- **Stage 6**: Identify gaps (missing data, undocumented variables, unclear outcomes)
- **Stage 7**: Write study design report to `specs/{NNN}_{SLUG}/reports/{MM}_epi-research.md`

Report structure:
```markdown
# Epidemiology Study Design Report: Task #{N}

## Executive Summary
[1-3 sentence overview]

## Study Overview
- Design: {study_design}
- Research Question: {research_question}
- Population: {population}
- Exposure: {exposure}
- Outcome: {outcome}
- Data Source: {data_paths summary}

## Data Inventory
[Table of datasets found, variable counts, date ranges]

## Proposed Analysis Phases
1. Data cleaning and variable construction
2. Descriptive analysis and Table 1
3. Primary analysis ({model type})
4. Sensitivity analyses
5. Validation and diagnostics
6. Reporting

## Variable Mapping
[Map research question variables to dataset columns]

## Statistical Approach
[Detailed rationale for model selection]

## Data Quality Issues
[Missing data patterns, outliers, inconsistencies]

## R Package Recommendations
[Specific packages for this analysis]

## Content Gaps
[Information needed before analysis can begin]
```

- **Stage 8**: Write final metadata
- **Stage 9**: Return brief text summary

#### `epi-implement-agent.md`

**Model**: opus

**Execution flow**:

- **Stage 0**: Initialize early metadata
- **Stage 1**: Parse delegation context, read plan file
- **Stage 2**: Detect resume phase
- **Phase 1: Data Preparation**
  - Read raw data files
  - Execute cleaning script (or write it if not existing)
  - Validate output: row counts, variable distributions
  - Write `analysis/01_data-clean.R`
- **Phase 2: Exploratory Data Analysis**
  - Generate Table 1 (descriptive statistics by exposure/group)
  - Create exposure-outcome visualizations
  - Assess missing data patterns
  - Write `analysis/02_eda.R`
- **Phase 3: Primary Analysis**
  - Implement primary statistical model from plan
  - Run via Rscript, capture output
  - Write `analysis/03_primary-analysis.R`
- **Phase 4: Sensitivity and Validation**
  - Implement sensitivity analyses
  - Check model assumptions (proportional hazards, linearity, etc.)
  - Write `analysis/04_sensitivity.R`
- **Phase 5: Reporting**
  - Compile results into findings report
  - Format tables and figures
  - Write final report to `epi/{slug}-findings.md` (and optionally `.typ` or `.Rmd`)
- **Stage N**: Write metadata with artifact paths

---

### Routing Fallback Chain

The orchestrator queries the routing table using this lookup order:

1. Exact compound match: `epi:study` -> `skill-epi-research`
2. Base extension match: `epi` -> `skill-epi-research`
3. Core fallback: `skill-researcher`

The manifest should declare both the compound form and the base form to support both explicit (`/epi` command creates `epi:study`) and legacy (`/task "epidemiology study"` creates bare `epi`) task types.

**IMPORTANT**: The current extension uses `task_type: "epidemiology"` in the manifest top-level field and has no routing table. After the overhaul:
- Old tasks with `task_type: "epidemiology"` will not route correctly unless a backward-compat entry is added
- Recommendation: Add `"epidemiology": "skill-epi-research"` entries in the routing table as backward-compat aliases

```json
"routing": {
  "research": {
    "epidemiology": "skill-epi-research",
    "epi": "skill-epi-research",
    "epi:study": "skill-epi-research",
    "epi:analysis": "skill-epi-research",
    "epi:report": "skill-epi-research"
  },
  "plan": {
    "epidemiology": "skill-epi-plan",
    "epi": "skill-epi-plan",
    "epi:study": "skill-epi-plan",
    "epi:analysis": "skill-epi-plan",
    "epi:report": "skill-epi-plan"
  },
  "implement": {
    "epidemiology": "skill-epi-implement",
    "epi": "skill-epi-implement",
    "epi:study": "skill-epi-implement",
    "epi:analysis": "skill-epi-implement",
    "epi:report": "skill-epi-implement"
  }
}
```

---

### Complete File List to Create/Modify

**Modify** (6 files):
1. `.claude/extensions/epidemiology/manifest.json` - Add routing table, update version to 2.0.0, update agent/skill names
2. `.claude/extensions/epidemiology/README.md` - Update for /epi command and compound routing
3. `.claude/extensions/epidemiology/EXTENSION.md` - Update routing table and agent names
4. `.claude/extensions/epidemiology/index-entries.json` - Expand to 12-16 entries, add commands trigger
5. `.claude/extensions/epidemiology/opencode-agents.json` - Update agent names
6. `.claude/extensions/epidemiology/settings-fragment.json` - No change needed

**Create** (15-20 files):
7. `.claude/extensions/epidemiology/commands/epi.md` - New /epi command (full design above)
8. `.claude/extensions/epidemiology/skills/skill-epi-research/SKILL.md` - Full thin wrapper
9. `.claude/extensions/epidemiology/skills/skill-epi-plan/SKILL.md` - Plan routing
10. `.claude/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` - Full thin wrapper
11. `.claude/extensions/epidemiology/agents/epi-research-agent.md` - Full research agent
12. `.claude/extensions/epidemiology/agents/epi-plan-agent.md` (optional, or skip and use core planner)
13. `.claude/extensions/epidemiology/agents/epi-implement-agent.md` - Full implementation agent
14. `.claude/extensions/epidemiology/context/project/epidemiology/domain/study-designs.md`
15. `.claude/extensions/epidemiology/context/project/epidemiology/domain/r-workflow.md`
16. `.claude/extensions/epidemiology/context/project/epidemiology/domain/data-management.md`
17. `.claude/extensions/epidemiology/context/project/epidemiology/domain/reporting-standards.md`
18. `.claude/extensions/epidemiology/context/project/epidemiology/patterns/epi-scoping-questions.md`
19. `.claude/extensions/epidemiology/context/project/epidemiology/patterns/analysis-phases.md`
20. `.claude/extensions/epidemiology/context/project/epidemiology/templates/study-protocol.md`
21. `.claude/extensions/epidemiology/context/project/epidemiology/templates/analysis-plan.md`
22. `.claude/extensions/epidemiology/context/project/epidemiology/templates/findings-report.md`

**Delete/supersede** (after content migrated):
- `agents/epidemiology-research-agent.md` (superseded by epi-research-agent.md)
- `agents/epidemiology-implementation-agent.md` (superseded by epi-implement-agent.md)
- `skills/skill-epidemiology-research/SKILL.md` (superseded by skill-epi-research)
- `skills/skill-epidemiology-implementation/SKILL.md` (superseded by skill-epi-implement)

---

## Evidence/Examples

### Example 1: manifest.json routing table (from founder/)

The founder extension shows the complete routing table pattern. The key insight is that each compound key maps to a different skill for research vs. plan vs. implement (e.g., `founder:deck` uses `skill-deck-research` for research, `skill-deck-plan` for plan). For epidemiology with a single study sub-type, the same skill can handle all three.

```json
"routing": {
  "research": {
    "founder:deck": "skill-deck-research"
  },
  "plan": {
    "founder:deck": "skill-deck-plan"
  },
  "implement": {
    "founder:deck": "skill-deck-implement"
  }
}
```

### Example 2: STAGE 0 forcing questions (from /slides command)

The `/slides` command's STAGE 0 is the closest template to the proposed `/epi` command. Both collect:
- A type selection (talk type vs. study design)
- Source material paths
- Context description

Key convention: `forcing_data` is a JSON object stored in `task.forcing_data` in state.json. Skills pass this to agents who use it to skip re-asking questions.

```markdown
## STAGE 0: PRE-TASK FORCING QUESTIONS

### Step 0.1: Talk Type
Use AskUserQuestion to present talk type options:
```
What type of talk is this?
- CONFERENCE: Research talk (15-20 min)
- SEMINAR: Departmental seminar (45-60 min)
...
```
Store response as `forcing_data.talk_type`.

### Step 0.4: Store Forcing Data
```json
{
  "talk_type": "{selected_type}",
  "source_materials": ["{material_1}"],
  "audience_context": "{description}",
  "gathered_at": "{ISO timestamp}"
}
```
```

### Example 3: Internal postflight pattern (from skill-talk)

The present extension uses the "skill-internal postflight" pattern where the skill (not the orchestrator) handles postflight operations. The key stages:

```
Stage 2: Preflight Status Update (state.json + TODO.md -> [RESEARCHING])
Stage 3: Create .postflight-pending marker
Stage 4: Prepare delegation context (include forcing_data)
Stage 5: Invoke subagent via Task tool (NOT Skill tool)
Stage 6: Read .return-meta.json metadata file
Stage 7: Update task status based on metadata
Stage 8: Link artifacts in state.json + TODO.md
Stage 9: Git commit
Stage 10: Cleanup (rm .postflight-pending, .return-meta.json)
Stage 11: Return brief text summary
```

### Example 4: Agent execution flow (from talk-agent.md)

The talk-agent.md shows the full agent pattern at 300 lines. Key requirements:
- MUST create early metadata at Stage 0 before any substantive work
- MUST return brief text summary (NOT JSON)
- MUST NOT use AskUserQuestion (questions go in report as content gaps)
- MUST update `partial_progress` on significant milestones
- Status value must be `"researched"` not `"completed"`

### Example 5: Present routing both research and implement to same skill

```json
"routing": {
  "research": {
    "present:talk": "skill-talk"
  },
  "plan": {
    "present:talk": "skill-planner"
  },
  "implement": {
    "present:talk": "skill-talk"
  }
}
```

This shows that the same skill can handle both research and implement by using `workflow_type` parameter (e.g., `talk_research` vs. `assemble`). The epidemiology extension can do the same: use `skill-epi-research` for both research (`epi_research` workflow) and implement (`epi_assemble` workflow), with plan routing to either `skill-planner` or `skill-epi-plan`.

---

## Decisions

1. **Extension prefix**: Use `epi` (not `epidemiology`) for compound task type keys. Keep `epidemiology` as the extension name in manifest but change `task_type` from `"epidemiology"` to `"epi"`. Add `"epidemiology"` as backward-compat alias in routing table.

2. **Plan routing**: Route `epi:study` plan to core `skill-planner` (like present does) rather than creating a dedicated `skill-epi-plan`. This is lower scope and the core planner is sufficient when given a well-structured research report.

3. **Agent naming**: Rename agents from `epidemiology-*-agent` to `epi-*-agent` for consistency with the `epi` prefix. Preserves the extension's short identity.

4. **Single research+implement skill**: Use `skill-epi-research` for both research and implement workflows (like `skill-talk`), differentiated by `workflow_type` parameter. This reduces total file count.

5. **Context expansion**: Create `domain/`, `templates/` subdirectories in context. The most valuable additions are `study-designs.md` and `analysis-phases.md` which directly support the forcing question flow.

6. **No mcp_servers change**: The existing `settings-fragment.json` with `rmcp` is correct. No new MCP servers needed.

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing tasks with `task_type: "epidemiology"` | Add backward-compat alias `"epidemiology"` in routing table |
| Scope creep - 20+ new files is a large implementation | Phase the work: Phase 1 = manifest + command + skills; Phase 2 = agents; Phase 3 = context |
| Agent files for R analysis need domain accuracy | Keep existing context files (r-packages.md, statistical-modeling.md) as base; agent imports them |
| `/epi` command with 8 forcing questions is heavyweight | All 8 questions are essential; reduce to 5 minimum (skip Q6 R preferences, Q8 report format as they have defaults) |
| Plan routing to core planner-agent loses domain specificity | Research report must be well-structured; include explicit phase recommendations |

---

## Context Extension Recommendations

- **Topic**: Epidemiology extension routing and /epi command pattern
- **Gap**: No documentation in `.claude/context/` covers how extension commands create compound task_type tasks (e.g., `epi:study`). The pattern is implicit in founder/present but not documented as a reusable pattern.
- **Recommendation**: Create `.claude/context/patterns/extension-command-pattern.md` documenting the STAGE 0 forcing questions -> task creation -> /research /plan /implement workflow for extension commands.

---

## Confidence Level

**High** for:
- Current state inventory (read every file directly)
- Gap analysis (systematic comparison against founder/present)
- Routing table design (follows exact founder/present patterns)
- `/epi` command structure (follows `/slides` and `/strategy` closely)
- Skill design (follows `skill-talk` pattern)
- Agent design (follows `talk-agent.md` pattern)

**Medium** for:
- Whether `skill-epi-plan` should route to core `skill-planner` vs. dedicated agent (depends on how domain-specific the plans need to be)
- Which context files to create (priorities could shift based on actual use cases)
- Whether 3 sub-types (`epi:study`, `epi:analysis`, `epi:report`) are the right decomposition vs. just `epi:study`

**Low** for:
- Whether to create an `epi-plan-agent.md` vs. relying on `planner-agent` (requires user input on expected plan quality)

---

## Appendix: Search Queries Used

- Codebase: All files in `.claude/extensions/epidemiology/` (read exhaustively)
- Codebase: All files in `.claude/extensions/founder/` (read manifest, commands/deck.md, commands/strategy.md, agents/deck-research-agent.md, skills/skill-deck-research/, skills/skill-founder-implement/, skills/skill-founder-plan/)
- Codebase: All files in `.claude/extensions/present/` (read manifest, commands/slides.md, commands/grant.md, agents/talk-agent.md, agents/grant-agent.md, skills/skill-talk/, skills/skill-grant/)
- Codebase: `specs/TODO.md` for task 400 description
- Codebase: `.claude/context/index.json` for context discovery mechanism
- No web searches needed (all information from codebase)
