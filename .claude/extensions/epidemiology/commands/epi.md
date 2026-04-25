---
description: Create epidemiology study tasks with pre-task forcing questions for R-based analysis
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Bash(sed:*), Read, Edit, AskUserQuestion
argument-hint: "description" | TASK_NUMBER | /path/to/protocol.md
model: opus
---

# /epi Command

Epidemiology study creation command with structured scoping and task system integration.

## Overview

This command initiates epidemiology study tasks through a 10-question forcing flow. It asks essential scoping questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow. The command focuses on collecting study design parameters, data sources, and analysis preferences for R-based epidemiological analysis.

## Syntax

- `/epi "Cohort study of vaccine effectiveness in elderly populations"` - Ask questions, create task with gathered data
- `/epi 500` - Resume existing epi:study task (delegate to research)
- `/epi /path/to/protocol.md` - Read file as study protocol, then scope

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask 10 forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, delegate to research, stop at [RESEARCHED] |
| File path | Read file as protocol, ask forcing questions, create task |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: task number input.

### Step 0.1: Study Design Type

Use AskUserQuestion:

```
What study design type?

- COHORT: Prospective or retrospective cohort study
- CASE_CONTROL: Case-control study
- CROSS_SECTIONAL: Cross-sectional survey or prevalence study
- RCT: Randomized controlled trial
- META_ANALYSIS: Systematic review and meta-analysis
- QUASI_EXPERIMENTAL: Quasi-experimental or natural experiment
- SURVEILLANCE: Disease surveillance or outbreak investigation
- MODELING: Mathematical or statistical modeling study
```

Store response as `forcing_data.study_design`.

### Step 0.2: Research Question

Use AskUserQuestion:

```
What is the primary research question?

State the question clearly, including population, exposure/intervention, comparator, and outcome where applicable (PICO/PECO format encouraged).
```

Store response as `forcing_data.research_question`.

### Step 0.3: Causal Structure

Use AskUserQuestion:

```
Describe the hypothesized causal pathway, or type 'skip' if not applicable.

Include key confounders, mediators, and effect modifiers if known. DAG notation welcome (e.g., "A -> Y, A -> M -> Y, C -> A, C -> Y").
```

Store response as `forcing_data.causal_structure` (null if skipped).

### Step 0.4: Data Paths

Use AskUserQuestion:

```
What data files or directories should be used?

Provide comma-separated file or directory paths to datasets (e.g., "/data/cohort.csv, /data/registry/").
Type 'none' if data will be provided later.
```

Store response as `forcing_data.data_paths` (parse into array, empty array if "none").

### Step 0.5: Descriptive Content Paths

Use AskUserQuestion:

```
Any protocols, codebooks, or data dictionaries to include?

Provide comma-separated paths to supporting documents (e.g., "/docs/protocol.pdf, /docs/codebook.xlsx").
Type 'none' if not applicable.
```

Store response as `forcing_data.descriptive_paths` (parse into array, empty array if "none").

### Step 0.6: Prior Work References

Use AskUserQuestion:

```
Any prior analyses, publications, or task references to build on?

Provide comma-separated references:
- Task references: "task:100"
- File paths: "/path/to/analysis.R"
- Citations: "Author et al. 2024"
Type 'none' if starting fresh.
```

Store response as `forcing_data.prior_work` (parse into array, empty array if "none").

### Step 0.7: Ethics Status

Use AskUserQuestion:

```
What is the ethics/IRB status?

- IRB_APPROVED: IRB/ethics board approved
- EXEMPT: Exempt from review (e.g., secondary data, de-identified)
- PENDING: Application submitted, awaiting approval
- NOT_APPLICABLE: No human subjects (e.g., simulation, publicly available aggregate data)
```

Store response as `forcing_data.ethics_status`.

### Step 0.8: Reporting Guideline

Use AskUserQuestion:

```
Which reporting guideline applies?

- STROBE: Observational studies (cohort, case-control, cross-sectional)
- CONSORT: Randomized trials
- PRISMA: Systematic reviews and meta-analyses
- RECORD: Routinely collected health data studies
- TRIPOD: Prediction model studies
- OTHER: Specify guideline name
- AUTO_DETECT: Let the system choose based on study design
```

Store response as `forcing_data.reporting_guideline`. If AUTO_DETECT, infer from study_design:
- COHORT/CASE_CONTROL/CROSS_SECTIONAL -> STROBE
- RCT -> CONSORT
- META_ANALYSIS -> PRISMA
- SURVEILLANCE -> RECORD
- MODELING/QUASI_EXPERIMENTAL -> STROBE

### Step 0.9: R Preferences

Use AskUserQuestion:

```
Any R preferences? Type 'skip' to use defaults.

Examples:
- Package preferences (tidyverse, data.table, base R)
- Statistical framework (frequentist, Bayesian)
- Specific packages (survival, lme4, brms, EpiEstim, epitools)
- Output format (Quarto, R Markdown, plain R scripts)
```

Store response as `forcing_data.r_preferences` (null if skipped).

### Step 0.10: Analysis Hints

Use AskUserQuestion:

```
Any specific analysis hints? Type 'skip' if none.

Examples:
- Models to fit (Cox PH, logistic regression, Poisson, negative binomial)
- Sensitivity analyses (e-value, quantitative bias analysis, multiple imputation)
- Subgroups of interest (age strata, sex, comorbidity categories)
- Specific estimands (ATT, ATE, CATE)
```

Store response as `forcing_data.analysis_hints` (null if skipped).

### Step 0.11: Assemble Forcing Data

```json
{
  "study_design": "{selected_type}",
  "research_question": "...",
  "causal_structure": "..." or null,
  "data_paths": ["path1", "path2"],
  "descriptive_paths": ["path1"],
  "prior_work": ["task:100", "path/to/paper.pdf"],
  "ethics_status": "{status}",
  "reporting_guideline": "{guideline}",
  "r_preferences": "..." or null,
  "analysis_hints": "..." or null,
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Epi] Epidemiology Study Creation
```

### Step 1: Generate Session ID

```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

### Step 2: Detect Input Type

```bash
# Check for task number
if echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then
  input_type="task_number"
  task_number="$ARGUMENTS"

# Check for file path
elif echo "$ARGUMENTS" | grep -qE '^\.|^/|^~|\.md$|\.txt$|\.tex$|\.pdf$|\.csv$|\.R$'; then
  input_type="file_path"
  file_path="$ARGUMENTS"

# Default: treat as description for new task
else
  input_type="description"
  description="$ARGUMENTS"
fi
```

### Step 3: Handle Input Type

**If task number**:
Load existing task, validate task_type starts with "epi", then delegate to research via skill-orchestrator.

**If file path**:
Read the file as study protocol or source material. Run Stage 0 forcing questions (Steps 0.1-0.10) with the file content as context. Then proceed to task creation.

**If description**:
Run Stage 0 forcing questions (Steps 0.1-0.10), then proceed to task creation.

---

## STAGE 1: TASK CREATION

**This stage runs for new tasks only (description or file path input).**

### Step 1: Read next_project_number

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
```

### Step 2: Create slug from description

- Lowercase, replace spaces with underscores
- Remove special characters
- Max 50 characters

### Step 3: Update state.json

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg desc "$description" \
  --argjson forcing "$forcing_data_json" \
  --arg slug "$slug" \
  --argjson num "$next_num" \
  '.next_project_number = ($num + 1) |
   .active_projects = [{
     "project_number": $num,
     "project_name": $slug,
     "status": "not_started",
     "task_type": "epi:study",
     "description": $desc,
     "forcing_data": $forcing,
     "created": $ts,
     "last_updated": $ts
   }] + .active_projects' \
  specs/state.json > specs/tmp/state.json && \
  mv specs/tmp/state.json specs/state.json
```

### Step 4: Update TODO.md

**Part A - Update frontmatter**:
```bash
sed -i 's/^next_project_number: [0-9]*/next_project_number: {NEW_NUMBER}/' \
  specs/TODO.md
```

**Part B - Add task entry** by prepending to `## Tasks` section:
```markdown
### {N}. {Title}
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: epi:study

**Description**: {description}
```

### Step 5: Git commit

```bash
git add specs/
git commit -m "task {N}: create {title}

Session: {session_id}"
```

### Step 6: Output

```
Epidemiology study task #{N} created: {TITLE}
Status: [NOT STARTED]
Task Type: epi:study
Study Design: {study_design}
Artifacts path: specs/{NNN}_{SLUG}/ (created on first artifact)

Recommended workflow:
1. /research {N} - Analyze materials and design study
2. /plan {N} - Create implementation plan
3. /implement {N} - Execute analysis in R
```

---

## STAGE 2: RESEARCH DELEGATION (task number input only)

When input is a task number, delegate to the appropriate research skill.

### Step 1: Validate Task

```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
# Validate task_type starts with "epi"
# Validate status is not terminal (block completed, abandoned, expanded)
```

### Step 2: Delegate

Route through skill-orchestrator which will select the appropriate epi research skill:

**Invoke Skill tool**:
```
skill: "skill-orchestrator"
args: "command=research task_number={N} session_id={session_id}"
```

### Step 3: Gate Out

Verify research completed:
- Check status updated to "researched" in state.json
- Check for report artifact in specs/{NNN}_{SLUG}/reports/

**On success, output**:
```
Epidemiology research completed for Task #{N}
Status: [RESEARCHED]
Report: specs/{NNN}_{SLUG}/reports/{MM}_epi-research.md

Next steps:
1. /plan {N} - Create implementation plan
2. /implement {N} - Execute analysis in R
```

---

## Error Handling

### Task Creation Errors
- Invalid description: Return guidance on expected format
- State update failure: Log error, do not commit partial state

### Research Errors
- Task not found: Return error with guidance to create task first
- Wrong task_type: Return error suggesting `/epi` for epidemiology tasks
- Invalid status: Return error with current status and valid transitions

### Forcing Question Errors
- Empty required fields (Q1, Q2, Q7): Re-prompt with explanation of why required
- Invalid study design: Re-prompt with valid options
- Invalid ethics status: Re-prompt with valid options
- File path not found: Report error, offer to continue without file

### Git Commit Failure
- Non-blocking: Log failure but continue with success response
- Report to user that manual commit may be needed

---

## Output Format (Errors)

```
Epi command error:
- {error description}
- {recovery guidance}
```
