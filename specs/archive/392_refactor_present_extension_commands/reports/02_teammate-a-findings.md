# Teammate A Findings: Deep Analysis of All 5 Present Extension Commands

**Task**: 392 - Refactor present extension commands (/grant, /budget, /funds, /timeline, /talk)
**Artifact**: 02_teammate-a-findings.md
**Teammate**: A (Primary Angle)
**Model**: Claude Sonnet 4.6
**Date**: 2026-04-09

---

## Overview

This report provides a complete execution flow analysis of all 5 present extension commands, their skills, agents, and the manifest routing. For each command, I document human-in-the-loop opportunities, task creation details, end results, and 2-3 improvement options incorporating the user's specific requirements.

---

## Key Findings Per Command

---

### 1. /grant Command

#### Complete Execution Flow

**Mode Detection** (no forcing questions in task creation):

```
/grant "description"  -> Task Creation Mode
/grant N --draft      -> Draft Mode
/grant N --budget     -> Budget Mode
/grant N --fix-it     -> Fix-It Scan Mode
/grant --revise N "description" -> Revise Mode
```

**Task Creation Mode** (no human-in-the-loop):
1. Parse $ARGUMENTS for description (no leading number = task creation)
2. Read `next_project_number` from state.json
3. Improve description (slug expansion, verb inference, capitalization)
4. Set `language = "grant"` (INCONSISTENT - should be "present")
5. Create slug from description
6. Update state.json and TODO.md
7. Git commit
8. Output: Task # + recommended workflow (research -> draft -> budget -> plan -> implement)

**Draft Mode** (no human-in-the-loop beyond optional prompt):
- GATE IN: lookup + validate task (language must be "grant", status allows drafting)
- DELEGATE: `skill-grant` with `workflow_type=proposal_draft`, `focus={draft_prompt}`
- GATE OUT: verify artifact in specs/{NNN}_{SLUG}/drafts/, verify status = "planned"

**Budget Mode** (same structure as Draft):
- DELEGATE: `skill-grant` with `workflow_type=budget_develop`

**Fix-It Scan Mode** (significant human-in-the-loop in skill):
- DELEGATE: `skill-grant` with `workflow_type=fix_it_scan`
- Inside skill: scans .tex/.md/.bib files, then multi-step AskUserQuestion for tag type selection, TODO item selection, topic grouping, QUESTION item selection

**Revise Mode** (no human-in-the-loop):
- Creates a new task linked to parent via `parent_grant` and `revises_directory` fields
- Does NOT validate grant directory is "present" language - specifically checks `grants/{N}_{slug}/`

#### Skill Execution (skill-grant)

11-stage execution:
1. Input validation (validates `language == "grant"` - BROKEN after fix)
2. Preflight status update (researching/planning/implementing)
3. Create `.postflight-pending` marker
4. Detect revision mode (checks `parent_grant` field)
5. Invoke `grant-agent` via Task tool with workflow_type + focus_prompt
6. Validate return format
7. Read `.return-meta.json`
8. Update status (postflight)
9. Link artifacts in state.json + TODO.md
10. Git commit
11. Cleanup marker + metadata files

**Workflow type routing in skill**:
- `funder_research`: researching -> researched
- `proposal_draft`: planning -> planned
- `budget_develop`: planning -> planned
- `progress_track`: no change
- `assemble`: implementing -> completed
- `fix_it_scan`: no change (direct execution, no subagent)

#### Agent (grant-agent, model: opus)

5 workflow types executed by agent. Key behaviors:
- Stage 0: Early metadata creation BEFORE work (interruption safety)
- Funder research: WebSearch + WebFetch for funder identification
- Proposal draft: Load templates, draft 7 proposal sections
- Budget develop: Load budget templates, identify cost categories, calculate line items
- Assemble: Validate prerequisites, gather artifacts, merge drafts, create `grants/{N}_{slug}/`
- Stage 6: Write metadata to `.return-meta.json` (NOT console)
- Stage 7: Return brief text summary (3-6 bullets)

#### Task Creation Details

Current (broken):
```json
{
  "language": "grant",  // should be "present"
  "task_type": "grant"  // MISSING - not currently set
}
```

Correct pattern:
```json
{
  "language": "present",
  "task_type": "grant"  // or "present:grant" per user requirement
}
```

#### End Result / Artifacts

- Funder research: `specs/{NNN}_{SLUG}/reports/{MM}_funder-analysis.md`
- Proposal draft: `specs/{NNN}_{SLUG}/drafts/{MM}_narrative-draft.md`
- Budget develop: `specs/{NNN}_{SLUG}/budgets/{MM}_line-item-budget.md`
- Progress track: `specs/{NNN}_{SLUG}/summaries/{MM}_progress-summary.md`
- Assemble: `grants/{N}_{slug}/narrative.md`, `budget.md`, `checklist.md`, `README.md`

#### Routing (manifest)

```json
"research": { "present:grant": "skill-grant" }
"implement": { "present:grant": "skill-grant:assemble" }
```

---

### 2. /budget Command

#### Complete Execution Flow

**Stage 0: Pre-Task Forcing Questions** (BEFORE task creation for new tasks)

Three AskUserQuestion calls:
1. Mode selection: MODULAR / DETAILED / NSF / FOUNDATION / SBIR
2. Project period: number of years, start date, mechanism
3. Direct cost cap: target annual direct cost amount

Stored as `forcing_data` object in task metadata.

**Checkpoint 1: GATE IN**
- Generate session ID
- Detect input type: `--quick` / task_number / file_path / description
- File path: read file, use as context for forcing questions
- Task number: load task, validate language is "budget" (INCONSISTENT)
- Description: run Stage 0 forcing questions, then create task

**Task Creation (Step 4)**:
```json
{
  "language": "budget",     // should be "present"
  "task_type": "budget",    // correct field, wrong language
  "forcing_data": { ... }   // mode, project_period, direct_cost_cap
}
```

**STOP after task creation** - command does not auto-invoke research.

**Stage 2: DELEGATE (task number input only)**

- STAGE 2A (legacy `--quick`): Invoke `skill-budget` with `mode={mode}`
- STAGE 2B (existing task): Invoke `skill-budget` with `task_number`

Skill workflow (11 stages):
1. Validate (language must be "budget" - BROKEN)
2. Preflight: status -> "researching"
3. Create postflight marker
3a. Calculate artifact number
4. Prepare delegation context (include forcing_data)
4b. Read summary format file (inject into agent prompt)
5. Invoke `budget-agent` via Task tool
6. Parse `.return-meta.json`
6a. Validate artifact content
7. Postflight status -> "researched"
8. Link artifacts (3: research, spreadsheet, metrics)
9. Git commit
10. Cleanup
11. Return summary

#### Agent (budget-agent, no model specified = inconsistent)

Highly interactive agent:
- Stage 0: Early metadata creation
- Stage 1: Parse delegation context, extract pre-gathered `forcing_data`
- Stage 2: Mode selection (only if not pre-gathered)
- Stage 3: Q1-Q2 - Personnel questions (one at a time, with push-back on vague answers)
- Stage 4: Q3-Q6 - Non-personnel direct costs (equipment, travel, participant, other)
- Stage 5: Q7-Q8 - Indirect costs (F&A rate, cost-sharing)
- Stage 6: Generate XLSX with Python/openpyxl (real Excel formulas for salary cap, F&A, escalation)
- Stage 7: Export JSON metrics
- Stage 8: Generate research report
- Stage 9: Write metadata
- Stage 10: Return brief text summary

**Push-back patterns**: Agent explicitly pushes back on vague answers (e.g., "standard salary" -> "What is the exact institutional base salary?")

#### Task Creation Details

```json
{
  "language": "budget",     // broken - should be "present"
  "task_type": "budget",    // correct field name
  "forcing_data": {
    "mode": "MODULAR|DETAILED|NSF|FOUNDATION|SBIR",
    "project_period": "...",
    "direct_cost_cap": "..."
  }
}
```

#### End Result / Artifacts

- `specs/{NNN}_{SLUG}/grant-budget.xlsx` - Multi-year XLSX with Excel formulas
- `specs/{NNN}_{SLUG}/budget-metrics.json` - JSON metrics export
- `specs/{NNN}_{SLUG}/reports/{MM}_{short-slug}.md` - Research report

Legacy mode: `present/grant-budget-{datetime}.xlsx`, `present/budget-metrics-{datetime}.json`

#### Routing (manifest)

```json
"research": { "present:budget": "skill-budget" }
"implement": { "present:budget": "skill-budget" }
```

---

### 3. /funds Command

#### Complete Execution Flow

**Stage 0: Pre-Task Forcing Questions** (BEFORE task creation for new tasks)

Five AskUserQuestion calls (most thorough forcing questions of all 5 commands):
1. Mode selection: LANDSCAPE / PORTFOLIO / JUSTIFY / GAP
2. Research area/project (pushes back on vague descriptions)
3. Funding history/current awards (requires specific award numbers)
4. Target funders/programs
5. Budget parameters (requires specific dollar amounts)
6. Decision context (determines required depth)

Stored as `forcing_data` with 6 fields.

**Checkpoint 1: GATE IN**
- Input type detection: `--quick` / task_number / description
- Task number validation: language must be "present" AND task_type must be "funds" (CORRECT)
  - NOTE: Uses `| not` pattern for jq safety (shows awareness of Issue #1132)
  - But: two separate `| not` checks instead of combined validation

**Task Creation (Step 4)**:
```json
{
  "language": "present",    // CORRECT
  "task_type": "funds",     // CORRECT
  "forcing_data": {
    "mode": "...",
    "research_area": "...",
    "funding_history": "...",
    "target_funders": "...",
    "budget_parameters": "...",
    "decision_context": "..."
  }
}
```

**STOP after task creation** - does not auto-invoke research.

**Stage 2: DELEGATE (task number input only)**

- STAGE 2A (legacy `--quick`): Invoke `skill-funds` directly
- STAGE 2B (existing task): Invoke `skill-funds` with `task_number`

Skill workflow (11 stages, same structure as budget):
- Includes Stage 4b: reads summary format file, injects into agent prompt (only funds skill does this)
- Stage 6a: Validates artifact content against format spec

#### Agent (funds-agent, model: opus)

Four analysis modes:
- LANDSCAPE: WebSearch + WebFetch for funder databases (NIH Reporter, Grants.gov)
- PORTFOLIO: Deep-dive into specific funder's award patterns
- JUSTIFY: Cross-check budget against funder guidelines, compliance score
- GAP: Map funded vs unfunded areas, identify strategic opportunities

Optional XLSX output (openpyxl, mode-specific sheets).

#### Task Creation Details

```json
{
  "language": "present",    // CORRECT
  "task_type": "funds",     // CORRECT
  "forcing_data": { /* 6 fields */ }
}
```

#### End Result / Artifacts

- `specs/{NNN}_{SLUG}/reports/{MM}_funding-{mode-slug}.md` - Analysis report
- `specs/{NNN}_{SLUG}/funding-landscape.xlsx` (optional) - Mode-specific XLSX
- `specs/{NNN}_{SLUG}/funding-metrics.json` (optional) - JSON metrics

#### Routing (manifest)

```json
"research": { "present:funds": "skill-funds" }
"implement": { "present:funds": "skill-funds" }
```

---

### 4. /timeline Command

#### Complete Execution Flow

**Structural difference**: Forcing questions happen IN the research stage (Stage 0 after GATE IN), NOT pre-task. This is the opposite of budget/funds/talk.

**Task Creation Mode** (no forcing questions):
1. Parse $ARGUMENTS (no number = task creation)
2. Read next_project_number
3. Improve description
4. Set `language = "timeline"` (INCONSISTENT - should be "present")
5. No `task_type` field (MISSING)
6. No `forcing_data` (gathered later in research mode instead)
7. Update state.json + TODO.md, git commit
8. Output: Task # + recommended workflow

**Research Mode** (task number input):

**GATE IN**:
- Lookup + validate task
- Language must be "timeline" (will break after fix)
- Determine workflow_type based on status

**Stage 0: Forcing Questions** (AFTER gate in, not pre-task):

3 AskUserQuestion calls:
1. Grant mechanism: R01 (5yr) / R01 (3yr) / R21 / K-series / U01 / Other
2. Project period (text input for exact dates)
3. Specific aims overview (brief descriptions)

These are stored in task metadata as `forcing_data`:
```json
{
  "mechanism": "...",
  "period": "...",
  "aims_overview": "..."
}
```

This is far fewer questions than what timeline-agent actually asks (8 rounds of forcing questions), meaning there's double-questioning: command asks 3, agent asks 6-7 more.

**DELEGATE**: `skill-timeline` with `workflow_type=timeline_research`

Skill workflow (11 stages, standard pattern):
- Stage 3a: Artifact number calculation (for research vs plan type)
- Forces passing of `forcing_data` to agent via delegation context

#### Agent (timeline-agent, model: opus)

Most interactive agent - 8 stages of forcing questions:
1. Grant mechanism + project period (duplicates command's Q1-Q2)
2. Completion criteria
3. Key stakeholders
4. Specific aims (duplicates command's Q3)
5. Cross-aim dependencies
6. Deliverables per aim
7. Task decomposition (experiments + milestones per aim)
8. Regulatory requirements (multiSelect: IRB, IACUC, DSMB, IND/IDE, ClinicalTrials.gov, etc.)
9. PERT estimation (3-point: optimistic, most likely, pessimistic for each task)
10. Resource allocation (effort by budget period)

Produces structured report with:
- Specific Aims WBS
- PERT Estimates Table
- Critical Path analysis
- Regulatory Milestones with lead times
- Resource Allocation
- Risk Register
- Raw JSON data block for Typst rendering

#### Task Creation Details

Current (broken):
```json
{
  "language": "timeline",  // should be "present"
  // task_type: missing entirely
  // forcing_data: not gathered pre-task (only in research mode)
}
```

Correct pattern:
```json
{
  "language": "present",
  "task_type": "timeline",
  "forcing_data": { /* gathered pre-task, like budget/funds/talk */ }
}
```

#### End Result / Artifacts

- `specs/{NNN}_{SLUG}/reports/{MM}_timeline-research.md` - Comprehensive timeline report with WBS, PERT, critical path

#### Routing (manifest)

```json
"research": { "present:timeline": "skill-timeline" }
"implement": { "present:timeline": "skill-timeline" }
```

---

### 5. /talk Command

#### Complete Execution Flow

**Stage 0: Pre-Task Forcing Questions** (BEFORE task creation):

3 AskUserQuestion calls:
1. Talk type: CONFERENCE / SEMINAR / DEFENSE / POSTER / JOURNAL_CLUB
2. Source materials: task references (task:N), file paths, or "none"
3. Audience context: research topic, audience type, time limit, emphasis

Stored as `forcing_data`:
```json
{
  "talk_type": "CONFERENCE",
  "source_materials": ["task:500", "/path/to/manuscript.md"],
  "audience_context": "..."
}
```

**GATE IN**:
- Input type: task_number / file_path / description
- File path: read as primary source material, then run Stage 0 questions with file as context

**Task Creation**:
```json
{
  "language": "present",    // CORRECT
  "task_type": "talk",      // CORRECT
  "forcing_data": { ... }
}
```

**STOP after task creation** - does not auto-invoke research.

**Stage 2: Research Delegation (task number input only)**

Validate: language == "present" AND task_type == "talk"
Delegate: `skill-talk` with `workflow_type=talk_research`

#### Agent (talk-agent, model: opus)

**Notable**: Agent MUST NOT use AskUserQuestion (per critical requirements). Content gaps go in the report, not interactive questions. This is unique among the 5 agents.

Agent loads slide patterns based on talk_type:
- CONFERENCE: `talk/patterns/conference-standard.json` (12-18 slides)
- SEMINAR: `talk/patterns/seminar-deep-dive.json` (30-45 slides)
- DEFENSE: `talk/patterns/defense-grant.json` (25-40 slides)
- JOURNAL_CLUB: `talk/patterns/journal-club.json` (10-15 slides)

For each slide in pattern:
1. Extract relevant content from source materials
2. Identify matching content template from `talk/contents/`
3. Map to template content_slots
4. Flag slides where source materials insufficient

**Unique behavior**: The agent includes "Recommended Theme" in the report. However, the user wants theme/content/order choices to be confirmed BEFORE planning, not just recommended in a report.

#### Task Creation Details

```json
{
  "language": "present",    // CORRECT
  "task_type": "talk",      // CORRECT
  "forcing_data": {
    "talk_type": "CONFERENCE",
    "source_materials": ["..."],
    "audience_context": "..."
  }
}
```

#### End Result / Artifacts

- `specs/{NNN}_{SLUG}/reports/{MM}_talk-research.md` - Slide-mapped report with content for each slide, speaker notes, content gaps, recommended theme
- Final assembly (via /implement): `talks/{N}_{slug}/slides.md`, `style.css`, `README.md`

#### Routing (manifest)

```json
"research": { "present:talk": "skill-talk" }
"implement": { "present:talk": "skill-talk" }
```

---

## Cross-Command Architecture Summary

### Structural Patterns

| Command | Pre-task Questions | Task Language | task_type | Subagent Model |
|---------|-------------------|---------------|-----------|----------------|
| /grant  | NONE              | "grant" (wrong) | MISSING | opus           |
| /budget | 3 questions       | "budget" (wrong) | "budget" | none (wrong)  |
| /funds  | 5 questions       | "present" (correct) | "funds" | opus        |
| /timeline | NONE (in research) | "timeline" (wrong) | MISSING | opus       |
| /talk   | 3 questions       | "present" (correct) | "talk" | opus         |

### Manifest Routing (Already Correct)

The manifest uses `present:{subtype}` keys, which means task creation must produce `language: "present"` with appropriate `task_type`. Only /funds and /talk currently match.

### Human-in-the-Loop Opportunities

| Command | Interactive Calls | Timing | Depth |
|---------|-------------------|--------|-------|
| /grant  | None in task creation | N/A | 0 |
| /grant draft | None (optional prompt only) | N/A | 0 |
| /grant fix-it | AskUserQuestion x4 | IN skill | High |
| /budget | 3 questions | Pre-task | Low |
| /budget agent | 8 questions | During research | High |
| /funds  | 5 questions | Pre-task | Medium |
| /funds agent | 0-2 follow-ups | During analysis | Low |
| /timeline | 3 questions | In research | Low |
| /timeline agent | 8 questions | During research | High |
| /talk   | 3 questions | Pre-task | Low |
| /talk agent | 0 questions | Never | None |

---

## Recommended Approach Per Command

---

### /grant: 3 Options for Improvement

The user wants /grant to begin with interactive questions gathering paths to content, regulatory materials, and grant guidelines BEFORE creating the task.

**Option A: Minimal - Language + task_type fix only (baseline)**

Fix the broken language field and add task_type. Keep current structure (no pre-task questions). Commands creates task with `language: "present"`, `task_type: "present:grant"`. Update skill validation to check `language == "present"` and `task_type == "grant"`.

*Pros*: Minimal change, lowest risk, mechanical fix.
*Cons*: Does not address the user's core requirement for pre-task interactive gathering.

**Option B: Recommended - Add pre-task grant intake questions (matches user requirement)**

Before creating the task, ask 3-5 targeted questions to gather grant context. This matches the user's explicit request to "gather paths to content, regulatory materials, and grant guidelines" before creating the task.

Proposed Stage 0 for grant task creation:

```
Q1: Grant mechanism and funder
"What type of grant is this? (e.g., NIH R01, NSF CAREER, foundation grant)"

Q2: Existing content paths
"Do you have existing content to draw from?
- File paths to specific aims, manuscripts, papers (comma-separated)
- Task references (e.g., task:400 to pull from a previous grant)
- 'none' to start fresh"

Q3: Regulatory and compliance context
"What regulatory materials are relevant?
- Funder program announcement (PA/FOA) URL or path
- Institutional guidelines (budget templates, effort limits)
- Prior IRB/IACUC protocols to reference
- 'none' if not yet identified"

Q4: Grant guidelines
"What are the key grant constraints?
- Page limits for each section (narrative, budget justification, etc.)
- Required sections per funder instructions
- Due date and internal deadline"

Store as forcing_data:
{
  "mechanism": "NIH R01",
  "content_paths": ["task:400", "/path/to/aims.md"],
  "regulatory_materials": ["https://...", "/path/to/policy.md"],
  "constraints": { "page_limits": {...}, "due_date": "..." }
}
```

Task creation output shows gathered data. Then research/draft/budget/plan/implement proceed with this context pre-loaded.

*Pros*: Matches user's explicit requirement, consistent with /budget and /funds pattern, enables agents to use pre-gathered paths instead of asking again.
*Cons*: More upfront friction for simple tasks; may need `--quick` bypass.

**Option C: Full Restructure - Unify grant as "present:grant" sub-pattern**

Complete architectural alignment with budget/funds/talk:
- `/grant "description"` -> pre-task questions -> task creation -> STOP
- `/grant N` -> resume research (funder research phase)
- `/grant N --draft` -> draft mode (unchanged)
- `/grant N --budget` -> budget mode (unchanged)
- Revise and fix-it modes preserved

Additionally, rename `task_type` from "grant" to "present:grant" for manifest alignment.

*Pros*: Maximum architectural consistency, best long-term maintainability.
*Cons*: Largest change scope, existing users must adapt.

**Recommendation**: Option B. The user's requirement is clear and explicit. The structural change is modest (add Stage 0 before current task creation). Grant-specific modes (draft, budget, revise, fix-it) remain unchanged.

---

### /budget: 3 Options for Improvement

**Option A: Language fix only**

Change `language: "budget"` to `language: "present"`. Add `model: opus`. Update Co-Authored-By. Update skill validation. Minimal change.

*Pros*: Fast, low risk.
*Cons*: Leaves 3-question forcing set unchanged; budget agent still asks 8 more questions (double-asking overlap on mode selection and project period).

**Option B: Recommended - Language fix + reduce question overlap**

Fix language/model/co-authored-by. Additionally, expand pre-task forcing questions to cover more ground, reducing overlap with agent's 8 questions. Currently the command asks mode + period + direct_cost_cap. The agent then re-asks mode (if not pre-gathered) and period again implicitly.

Restructure pre-task questions to be more complete:
```
Q1: Grant type (MODULAR/DETAILED/NSF/FOUNDATION/SBIR) - EXISTING
Q2: Funder and mechanism (e.g., "NIH R01, NIGMS", "NSF CAREER") - NEW
Q3: Project period (years + start date) - EXISTING
Q4: Direct cost target - EXISTING
Q5: Key personnel count (rough estimate) - NEW
```

This gives the budget-agent cleaner context and reduces re-asking.

*Pros*: Better user experience, cleaner agent context.
*Cons*: Slightly more upfront questions.

**Option C: Rename task_type to match manifest pattern**

Use `task_type: "present:budget"` instead of `task_type: "budget"` to exactly match manifest routing keys. Update skill validation to check `task_type == "present:budget"`.

*Pros*: Perfect manifest alignment.
*Cons*: More validation logic; manifest routing already works with `language: "present"` + checking task_type.

**Recommendation**: Option B. Fix all mechanical inconsistencies and modestly improve the question set to reduce double-questioning.

---

### /funds: 3 Options for Improvement

/funds already has the correct language ("present") and task_type ("funds"). Fixes needed: model and co-authored-by (mechanical).

**Option A: Mechanical fixes only**

Fix `model: claude-opus-4-5-20251101` to `model: opus`. Fix Co-Authored-By. Fix the two `| not` jq validation patterns (they work but are syntactically inconsistent with the rest of the system).

*Pros*: Minimal risk to a command that already works correctly.
*Cons*: No functional improvement.

**Option B: Recommended - Fix + expand funder guidance**

Fix mechanics + enhance pre-task questions with smarter defaults. Currently Q3 (target funders) asks for specifics but doesn't offer a discovery mode. Add option to trigger automatic landscape discovery:

```
Q3 enhancement:
"Which funders or programs are you targeting?
- Specify known funders (e.g., 'NIH NIGMS R01', 'NSF BIO')
- Or type 'discover' to survey the full landscape for your research area"
```

This makes the LANDSCAPE mode more discoverable and reduces friction when users don't yet know target funders.

*Pros*: Better UX for early-stage funding exploration.
*Cons*: Minor - small additional logic for handling 'discover' keyword.

**Option C: Add file path input support**

/funds is the only command that doesn't support file path input (unlike /budget, /talk, /grant). Adding it would allow `/funds /path/to/current-budget.md` to use the file as context for analysis.

*Pros*: Parity with other commands.
*Cons*: Modest implementation work; may not be needed for all use cases.

**Recommendation**: Option A as baseline (mechanical fixes), then Option B for the next iteration. Option C is worth noting for the plan.

---

### /timeline: 3 Options for Improvement

Timeline has the most structural inconsistency: language is "timeline" (wrong), task_type is missing, and forcing questions happen in research mode (after task creation) instead of pre-task.

**Option A: Language + task_type fix only (minimal)**

Change `language: "timeline"` to `language: "present"`. Add `task_type: "timeline"`. Update skill validation. Move forcing questions to pre-task Stage 0 like /budget and /funds.

The 3 current forcing questions (mechanism, period, aims) become pre-task Stage 0. The agent's 8 questions (which largely overlap with these 3) then skip the pre-gathered ones.

*Pros*: Structural alignment with the rest of the system.
*Cons*: The 3 command questions + 8 agent questions still have significant overlap (mechanism is asked twice, aims are asked twice). Need to explicitly wire pre-gathered data skip logic in agent.

**Option B: Recommended - Structural alignment + question consolidation**

Move the 3 questions to pre-task Stage 0. BUT also extend to 5-6 questions to better scaffold what the agent needs:

```
Stage 0 for /timeline (pre-task):
Q1: Grant mechanism (with options: R01/R21/K-series/U01/Other) - EXISTING
Q2: Project period (start + end dates) - EXISTING
Q3: Number of specific aims (1/2/3/4+) - NEW
Q4: Key completion criteria (2-3 milestone targets) - NEW
Q5: Regulatory requirements expected? (quick multiSelect: IRB/IACUC/FDA/None) - PARTIAL (agent does this in detail)
Q6: Existing aims document or file? (path or 'none') - NEW (path to existing specific aims page)
```

Store as richer `forcing_data`. Agent then skips Q1-Q5 equivalents and dives into detailed decomposition.

*Pros*: Eliminates double-asking, front-loads context gathering, makes agent more efficient.
*Cons*: More pre-task questions; some users may want to go directly to the research phase.

**Option C: Split into two commands**

Given that timeline is fundamentally different from the others (it's a research planning tool, not a grant writing tool), consider splitting:
- `/timeline "description"` - create task with pre-task questions
- `/timeline N` - run research (delegates to skill-timeline)
- Remove forcing questions from the research flow entirely; all gathered pre-task

This is essentially Option B but with explicit acknowledgment that the timeline command IS fundamentally "pre-task questionnaire -> research -> plan -> implement" and should commit fully to that pattern.

*Pros*: Clean separation of concerns, most consistent with budget/funds/talk.
*Cons*: Same as Option B - more pre-task friction.

**Recommendation**: Option B. The user's requirement is structural alignment and consistency. Moving questions to pre-task and adding 2-3 more targeted questions reduces agent overhead and creates a consistent user experience.

---

### /talk: 3 Options for Improvement

/talk already has the correct language ("present") and task_type ("talk"). The primary user requirement is: the plan agent should present choices of themes, content, and order to confirm design BEFORE proposing a plan.

Currently, the talk-agent puts theme in the report (Stage 6), and planning happens via `/plan N`. There's no interactive design confirmation between research and planning.

**Option A: Mechanical fixes only**

Fix `model: claude-opus-4-5-20251101` to `model: opus`. Fix Co-Authored-By. No structural change.

*Pros*: Fast, low risk.
*Cons*: Does not address the user's core requirement for design confirmation before planning.

**Option B: Recommended - Add design confirmation phase**

The user wants theme/content/order confirmed BEFORE the planner creates a plan. This requires a new phase between research and planning:

**Pattern**: After `/talk N` (research) completes and produces the slide-mapped report with theme recommendations, the next `/plan N` invocation should trigger a design confirmation dialog BEFORE creating the full plan:

Proposal: Modify `skill-talk` (or add a new workflow `talk_design`) that:
1. Reads the research report
2. Presents via AskUserQuestion:
   - Theme choices (with visual descriptions of 3-4 themes)
   - Key message ordering (let user confirm or reorder the 3 key messages)
   - Slide count / section emphasis (which sections to expand vs compress)
   - Any content to deprioritize
3. Stores user choices in task metadata as `design_decisions`
4. Then calls skill-planner with `design_decisions` injected

This design confirmation could be triggered by:
- A new `/talk N --design` flag (explicit)
- Automatically by `/plan N` when task is talk type and no design_decisions exist (implicit)

**Option B1 (explicit)**: New `/talk N --design` step in the workflow:
```
/talk "description"  -> pre-task questions -> task creation
/research N          -> talk_research -> slide-mapped report
/talk N --design     -> design confirmation -> stores design_decisions
/plan N              -> creates plan using design_decisions
/implement N         -> assembles Slidev presentation
```

**Option B2 (implicit)**: `/plan N` on a talk task with no design_decisions triggers confirmation:
```
/plan N (talk task with no design_decisions):
  -> Read research report
  -> AskUserQuestion: theme, order, emphasis
  -> Store as design_decisions
  -> Invoke skill-planner with design_decisions
```

*Pros*: Addresses the user's explicit requirement, improves presentation quality.
*Cons*: B1 adds a step to the workflow; B2 requires changes to the core /plan command or skill-talk's plan routing.

**Option C: Full design system**

Implement a design system where themes are stored as JSON config files and the agent renders visual previews (ASCII or text) of theme options. More elaborate, enables reusable themes across talks.

*Pros*: Long-term architectural value.
*Cons*: Significant scope expansion; implementation complexity.

**Recommendation**: Option B1 (new `--design` flag). It's explicit, low-friction for users who want to skip it, and doesn't require changes to core commands. The manifest routing can be updated to add `present:talk:design` as a workflow type in skill-talk.

---

## Evidence and Examples

### Language Inconsistency Evidence

From `grant.md` task creation:
```bash
# Line 96-102 (current, broken)
'.next_project_number = {NEW_NUMBER} |
 .active_projects = [{
   "project_number": {N},
   "project_name": "slug",
   "status": "not_started",
   "language": "grant",  # <-- WRONG
```

From `funds.md` task creation:
```bash
# Line 213-226 (current, correct)
'.active_projects += [{
  project_number: $num,
  project_name: $name,
  status: "not_started",
  language: "present",  # <-- CORRECT
  task_type: $task_type,  # <-- CORRECT
```

### Manifest Routing Shows Intent

From `manifest.json`:
```json
"routing": {
  "research": {
    "present": "skill-grant",
    "present:grant": "skill-grant",     // <-- expects present:grant
    "present:budget": "skill-budget",   // <-- expects present:budget
    "present:timeline": "skill-timeline"
  }
}
```

The manifest ALREADY encodes the correct structure. The commands just need to catch up.

### Double-Questioning in Timeline

From `timeline.md` (command, Stage 0 in research mode):
```
Q1: "What grant mechanism is this timeline for?" (R01/R21/K-series...)
Q3: "Briefly describe your specific aims"
```

From `timeline-agent.md` (agent, Stage 2-3):
```
Q1: "What is the grant mechanism and project period?" (R01/R21/K-series...)
Q4: "List your Specific Aims with brief descriptions"
```

Mechanism and aims are asked TWICE. Pre-gathering in Stage 0 + wiring to agent skip logic eliminates this.

### Talk Agent: No Interactive Questions (Unique Behavior)

From `talk-agent.md` critical requirements:
```
MUST NOT:
3. Use AskUserQuestion (questions go in the report as content gaps)
```

This is the ONLY agent that never asks interactive questions. The design confirmation requirement from the user cannot be implemented in the agent without changing this rule. The solution is to handle design confirmation in a separate skill step (the `--design` flag approach).

---

## Confidence Level

| Finding | Confidence |
|---------|-----------|
| Language inconsistency (grant=wrong, present=correct) | HIGH - confirmed from manifest routing |
| Double-questioning in timeline (command + agent overlap) | HIGH - verified by reading both files |
| /talk agent cannot ask questions (explicit rule) | HIGH - stated in critical requirements |
| Pre-task questions for /grant needed | HIGH - user's explicit requirement |
| Design confirmation for /talk before /plan | HIGH - user's explicit requirement |
| Option B being the best for each command | MEDIUM - based on stated requirements and architecture patterns |
| Recommendation to use task_type = "present:grant" format | MEDIUM - manifest uses "present:grant" keys but task_type field values don't need to match exactly |

---

## Summary of Key Improvements Recommended

1. **All commands**: Fix `language` to `"present"`, fix model to `opus`, fix Co-Authored-By
2. **All commands**: Add `task_type` field if missing (`grant`, `budget`, `timeline`)
3. **All skills**: Update validation to check `language == "present"` + `task_type` for subtype
4. **/grant**: Add Stage 0 pre-task forcing questions (content paths, regulatory materials, grant guidelines)
5. **/timeline**: Move forcing questions to pre-task Stage 0, extend to 5-6 questions, wire skip logic in agent
6. **/talk**: Add `--design` flag triggering a design confirmation phase (theme, order, emphasis) between research and planning
7. **Manifest**: Update `routing` to include design confirmation workflow type for talk
