# Research Report: Task #240

**Task**: Fix /market command forcing questions workflow
**Date**: 2026-03-18
**Focus**: Analysis of current founder/ extension implementation and required changes for forcing questions workflow
**Session**: sess_1773877196_3c55c1

## Summary

The task description contains a fundamental misunderstanding of the current founder/ extension implementation. Tasks 233 and 234 already implemented the forcing questions workflow, and task 238 added typst output generation. The /market, /analyze, and /strategy commands **already follow the pattern described in the task**. The commands currently:

1. Ask forcing questions during the research phase (via market-agent, analyze-agent, strategy-agent)
2. Create tasks with `language: "founder"` (not separate type fields)
3. Generate research reports with gathered context
4. Support explicit /plan and /implement invocations for subsequent phases

**Key Finding**: The task description requests functionality that already exists. What may be needed is clarification of how the system works, or potentially debugging specific behaviors that are not working as designed.

---

## Context & Scope

This research analyzes:
1. How tasks 233 and 234 implemented the forcing questions workflow
2. Current state of /market, /analyze, /strategy commands in founder/ extension
3. How language-based routing works for founder tasks
4. Whether any actual changes are needed

---

## Findings

### 1. Current Implementation Matches Requested Pattern

The task description states the /market command should:

| Requested Behavior | Current Implementation | Status |
|--------------------|------------------------|--------|
| Ask forcing questions before creating tasks | Commands create task first, then run research with forcing questions | Different sequence - task created first |
| Create task with 'market' type | Tasks created with `language: "founder"` | Different mechanism - uses language field |
| Include task description and research report | Research reports stored in `specs/{NNN}_{SLUG}/reports/` | Already implemented |
| /research routes to market-research agent | /market routes to skill-market -> market-agent | Different routing path |
| /plan routes to planner for typst file plan | /plan routes to skill-founder-plan -> founder-plan-agent | Already implemented |
| /implement constructs typst file | /implement routes to skill-founder-implement -> founder-implement-agent with Phase 5 typst generation | Already implemented |

### 2. Workflow Architecture (Tasks 233/234)

The current workflow follows this pattern:

```
/market "description"
    |
    v
CHECKPOINT 1: GATE IN
    |
    +--> Detect input type (description|task_number|file_path|--quick)
    |
    +--> Create task in state.json with language: "founder"
    |
    +--> Git commit task creation
    |
    v
STAGE 2: DELEGATE
    |
    +--> skill: "skill-market"
    |        |
    |        +--> Preflight: Update status to [RESEARCHING]
    |        |
    |        +--> Task tool -> market-agent
    |        |        |
    |        |        +--> Mode selection (AskUserQuestion)
    |        |        |
    |        |        +--> Forcing questions Q1-Q8 (one at a time)
    |        |        |
    |        |        +--> Generate research report
    |        |        |
    |        |        +--> Write metadata file
    |        |        |
    |        |        +--> Return brief summary
    |        |
    |        +--> Postflight: Update status to [RESEARCHED]
    |        |
    |        +--> Git commit research completion
    |
    v
CHECKPOINT 2: GATE OUT
    |
    +--> Display result with next steps
```

**User then explicitly runs**:
```
/plan {N}  -> Creates implementation plan (5 phases including typst)
/implement {N}  -> Executes plan, generates markdown + PDF output
```

### 3. Forcing Questions Implementation

The market-agent already implements a complete forcing questions workflow:

**Stage 2: Mode Selection**
```
Before we begin market sizing research, select your mode:

A) VALIDATE - Test assumptions with evidence gathering
B) SIZE - Comprehensive TAM/SAM/SOM with full methodology
C) SEGMENT - Deep dive into specific segments
D) DEFEND - Investor-ready with conservative estimates
```

**Stages 3-5: TAM/SAM/SOM Forcing Questions**
- Q1: Problem Scope - "What specific problem does your product solve? For whom?"
- Q2: Entity Count - "How many entities worldwide have this problem?"
- Q3: Price Point - "What's the maximum anyone would pay annually to solve this?"
- Q4: Data Sources - "What data sources support these numbers?"
- Q5: Geography - "Which geographies can you actually serve today?"
- Q6: Segments NOT Served - "Which segments can you NOT serve? Why?"
- Q7: Capture Rate - "What's your realistic market share in Year 1? Year 3?"
- Q8: Competition - "Who are the top 3 competitors for this exact segment?"

All questions are asked one at a time via AskUserQuestion with push-back patterns for vague answers.

### 4. Language-Based Routing (Not Type-Based)

The founder extension uses `language: "founder"` for task routing, not a separate `type` field:

**From manifest.json**:
```json
{
  "routing": {
    "research": {
      "founder": "skill-market"
    },
    "plan": {
      "founder": "skill-founder-plan"
    },
    "implement": {
      "founder": "skill-founder-implement"
    }
  }
}
```

**Key Insight**: There is no distinction between "market", "analyze", and "strategy" types at the task level. All founder tasks use `language: "founder"`. The distinction happens at the command level:

| Command | Creates Task | Routes To | Report Type |
|---------|--------------|-----------|-------------|
| /market | language: founder | skill-market -> market-agent | market-sizing |
| /analyze | language: founder | skill-analyze -> analyze-agent | competitive-analysis |
| /strategy | language: founder | skill-strategy -> strategy-agent | gtm-strategy |

When the user runs `/plan` or `/implement` on a founder task, the system routes based on `language: "founder"` to skill-founder-plan and skill-founder-implement. These agents read the research report to determine report type (market-sizing, competitive-analysis, or gtm-strategy) and generate appropriate outputs.

### 5. Typst Output Generation (Task 238)

Task 238 implemented Phase 5 in the founder-implement-agent:

**Phase 5: Typst Document Generation**
1. Check typst availability
2. Create founder/ directory
3. Generate self-contained .typ file (no imports)
4. Compile to PDF: `typst compile "founder/${report_type}-${slug}.typ" "founder/${report_type}-${slug}.pdf"`

**Template files**:
- `.claude/extensions/founder/context/project/founder/templates/typst/market-sizing.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/competitive-analysis.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/gtm-strategy.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ` (base)

---

## Analysis: What Might Be The Actual Issue?

The task description requests functionality that appears to already exist. Possible interpretations:

### Interpretation A: Misunderstanding of Current System

The user may not have seen the implementation from tasks 233/234/238. The system already:
- Asks forcing questions during research
- Creates tasks with proper routing
- Generates typst output

**Resolution**: No code changes needed. Provide documentation or demonstration.

### Interpretation B: Forcing Questions Should Happen BEFORE Task Creation

Current flow:
```
/market "description" -> Creates task -> Runs forcing questions
```

Requested flow (if interpreted literally):
```
/market -> Asks forcing questions -> Creates task with gathered data
```

**Resolution**: Restructure commands to:
1. Ask initial forcing questions first
2. Use answers to create task with richer description
3. Store Q&A data in task metadata

### Interpretation C: Different Task Types Desired

Current system uses one `language: "founder"` for all founder tasks.

If the user wants separate types:
```json
{
  "language": "founder",
  "task_type": "market"  // or "analyze" or "strategy"
}
```

**Resolution**: Add `task_type` field to state.json schema, update routing to use task_type for finer-grained control.

### Interpretation D: Routing Issues With /research

Current `/research` command may not route founder tasks correctly to market-agent:

From manifest.json:
```json
"research": {
  "founder": "skill-market"
}
```

This routes ALL founder research to skill-market, regardless of whether it's a market, analyze, or strategy task.

**Resolution**: Either:
1. Add task_type field and route based on that
2. Parse task description to determine routing
3. Use separate skills (skill-market-research, skill-analyze-research, skill-strategy-research)

---

## Recommendations

### If Interpretation A (Misunderstanding)

1. No code changes required
2. Document the existing workflow clearly
3. Demonstrate with example invocation

### If Interpretation B (Pre-Task Questions)

**Changes Required**:

1. **market.md** (command):
   - Move forcing questions BEFORE task creation
   - Use gathered answers to create richer task description
   - Store Q&A data in task metadata field

2. **state.json schema**:
   - Add `forcing_question_data` field to task entries

3. **Flow change**:
   ```
   /market -> Mode selection -> Q1-Q8 -> Create task with gathered data -> Write research report
   ```

### If Interpretation C/D (Type-Based Routing)

**Changes Required**:

1. **state.json schema**:
   ```json
   {
     "project_number": N,
     "project_name": "...",
     "language": "founder",
     "task_type": "market|analyze|strategy",
     ...
   }
   ```

2. **market.md, analyze.md, strategy.md**:
   - Add `task_type` field when creating tasks

3. **manifest.json routing**:
   - Update to route based on task_type OR
   - Create type-specific routing

4. **/research command**:
   - Update to check task_type for founder tasks
   - Route to appropriate skill/agent

---

## Existing File Inventory

### Commands
- `.claude/extensions/founder/commands/market.md` - Already implements task creation + skill delegation
- `.claude/extensions/founder/commands/analyze.md` - Same pattern
- `.claude/extensions/founder/commands/strategy.md` - Same pattern

### Skills
- `.claude/extensions/founder/skills/skill-market/SKILL.md` - Routes to market-agent
- `.claude/extensions/founder/skills/skill-analyze/SKILL.md` - Routes to analyze-agent
- `.claude/extensions/founder/skills/skill-strategy/SKILL.md` - Routes to strategy-agent
- `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md` - Planning with research integration
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` - Implementation with typst

### Agents
- `.claude/extensions/founder/agents/market-agent.md` - Forcing questions + research report
- `.claude/extensions/founder/agents/analyze-agent.md` - Competitive analysis questions
- `.claude/extensions/founder/agents/strategy-agent.md` - GTM strategy questions
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Plan from research
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Execute plan, generate typst

### Templates
- `.claude/extensions/founder/context/project/founder/templates/typst/*.typ` - Typst templates

---

## Questions For Clarification

Before implementing changes, clarification is needed:

1. **Is the current workflow not functioning as documented?**
   - If so, what specific behavior is broken?

2. **Should forcing questions happen before task creation?**
   - Current: Task created first, then forcing questions
   - Requested: Forcing questions first, then task with gathered data

3. **Is separate task_type routing needed?**
   - Current: All founder tasks route same way
   - Requested: market vs analyze vs strategy routing distinction

4. **What triggered this task?**
   - Was there a specific failure or unexpected behavior?
   - Is this about adding new functionality or fixing existing?

---

## Context Extension Recommendations

None. This is a meta task modifying the founder extension itself. No new context files needed.

---

## Next Steps

1. **Clarify requirements** with user before implementation
2. If code changes needed, run `/plan 240` to create implementation plan
3. Changes likely involve:
   - Command restructuring (if pre-task questions needed)
   - Schema updates (if task_type routing needed)
   - Routing updates (manifest.json and skill routing)

---

## Appendix: Key Patterns Already Implemented

### Forcing Questions One-at-a-Time Pattern

From `forcing-questions.md`:
```
1. Re-ground: State project, current context
2. Simplify: Explain in plain language
3. Ask: One specific question
4. Push: If vague, push back
```

### Push-Back Triggers

| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "Many businesses..." | "Can you name a specific number? What source?" |
| "The market is huge" | "How huge? $1B? $100B? What's your basis?" |
| "Everyone needs this" | "Name one specific company that needs this." |

### Report Type Detection

From `founder-plan-agent.md`:
```
| Keywords | Report Type |
|----------|-------------|
| market, sizing, TAM, SAM, SOM | market-sizing |
| competitive, competitor, analysis | competitive-analysis |
| GTM, go-to-market, strategy, launch | gtm-strategy |
```
