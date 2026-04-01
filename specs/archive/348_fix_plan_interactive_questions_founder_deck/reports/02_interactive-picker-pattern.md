# Research Report: Task #348 (Round 2)

**Task**: 348 - Fix /plan command not showing interactive questions for founder:deck tasks
**Started**: 2026-04-01T19:00:00Z
**Completed**: 2026-04-01T19:30:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 347 (compound key routing - completed)
**Sources/Inputs**: Codebase analysis of skill-deck-plan, deck-planner-agent, skill-fix-it, /fix-it command
**Artifacts**: specs/348_fix_plan_interactive_questions_founder_deck/reports/02_interactive-picker-pattern.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The previous report (round 1) incorrectly identified "extension not loaded" as root cause. The ACTUAL problem is architectural: interactive questions are defined inside `deck-planner-agent` but `skill-deck-plan` does not have `AskUserQuestion` in its `allowed-tools`, and agents spawned via the `Task` tool may not reliably surface `AskUserQuestion` to the user
- The fix requires moving the 4 interactive `AskUserQuestion` calls from `deck-planner-agent` into `skill-deck-plan` (the skill layer), asking them BEFORE spawning the agent, and passing user selections as structured input to the agent
- This matches the established pattern used by `skill-fix-it` which uses `AskUserQuestion` directly in the skill for all interactive selection before creating tasks
- Two files need modification: `skill-deck-plan/SKILL.md` (add questions + AskUserQuestion to allowed-tools) and `deck-planner-agent.md` (remove interactive stages, accept selections as input)

## Context & Scope

Task 347 fixed routing so `/plan` on a `founder:deck` task correctly resolves to `skill-deck-plan` which invokes `deck-planner-agent`. The routing works. The problem is that the agent's interactive questions (pattern, theme, content, ordering) are presented as plain text output to the task runner rather than as proper `AskUserQuestion` interactive pickers that the user can click on.

## Findings

### Finding 1: The Allowed-Tools Gap

**`skill-deck-plan/SKILL.md` frontmatter** (line 4):
```
allowed-tools: Task, Bash, Edit, Read, Write
```

**`skill-fix-it/SKILL.md` frontmatter** (line 4):
```
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
```

The deck plan skill does NOT have `AskUserQuestion` in its allowed-tools. The fix-it skill DOES. This is the primary technical gap -- the skill cannot present interactive pickers because it lacks tool permission.

### Finding 2: Agent vs Skill Question Ownership

The `deck-planner-agent.md` defines 4 sequential `AskUserQuestion` interactions:

| Stage | Question Type | Options |
|-------|--------------|---------|
| Stage 3: Pattern Selection | single select | YC 10-Slide, Lightning Talk, Product Demo, Investor Update, Partnership Proposal |
| Stage 4: Theme Selection | single select | Dark Blue, Minimal Light, Premium Dark, Growth Green, Professional Blue |
| Stage 5: Content Selection | multi select per slide | Library content entries + NEW option per slide position |
| Stage 6: Slide Ordering | single select | YC Standard, Story-First, Traction-Led |

The agent lists `AskUserQuestion` in its "Allowed Tools" section (line 25), but agents spawned via the `Task` tool run in a subagent context where `AskUserQuestion` may not surface properly to the user -- it becomes plain text output from the subagent rather than an interactive picker.

### Finding 3: The Reference Pattern (skill-fix-it)

`skill-fix-it` is a "direct execution" skill that demonstrates the correct pattern:

1. **Skill has `AskUserQuestion` in allowed-tools** (frontmatter line 4)
2. **All interactive selection happens in the skill itself** (Steps 6-7.7)
3. **No agent delegation** -- skill-fix-it does not use the `Task` tool at all
4. **Questions use structured JSON format** with `question`, `header`, `multiSelect`, and `options` fields

Example from skill-fix-it Step 6:
```json
{
  "question": "Which task types should be created?",
  "header": "Task Types",
  "multiSelect": true,
  "options": [
    {"label": "fix-it task", "description": "Combine 8 FIX:/NOTE: tags into single task"},
    {"label": "TODO tasks", "description": "Create tasks for 7 TODO: items"}
  ]
}
```

### Finding 4: The Desired Architecture Change

**Current flow** (broken):
```
/plan {N}
  -> skill-deck-plan (no AskUserQuestion tool)
    -> Task("deck-planner-agent")
      -> Agent tries AskUserQuestion (plain text, not interactive)
      -> Agent generates plan
    -> Postflight
```

**Desired flow** (fix):
```
/plan {N}
  -> skill-deck-plan (WITH AskUserQuestion tool)
    -> Read research report and deck library index
    -> AskUserQuestion: Pattern selection (single select)
    -> AskUserQuestion: Theme selection (single select)
    -> AskUserQuestion: Content selection (multi select per slide)
    -> AskUserQuestion: Slide ordering (single select)
    -> Task("deck-planner-agent", {user selections as structured input})
      -> Agent receives selections, generates plan (no questions asked)
    -> Postflight
```

### Finding 5: Exact Changes Needed

#### File 1: `skill-deck-plan/SKILL.md`

**Change 1 - Frontmatter** (line 4):
```
# FROM:
allowed-tools: Task, Bash, Edit, Read, Write

# TO:
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
```

**Change 2 - Add new stages between Stage 4 (Context Preparation) and Stage 5 (Invoke Agent)**:

Insert 4 new stages (call them Stage 4.1 through Stage 4.4) that:

1. **Stage 4.1: Read research report** - Extract slide content analysis, purpose, gaps
2. **Stage 4.2: Load deck library index** - Read `.context/deck/index.json` (initialize from extension seed if missing)
3. **Stage 4.3: Interactive questions** - Execute 4 sequential AskUserQuestion calls:
   - Pattern selection (query index.json for patterns, present as single-select)
   - Theme selection (query index.json for themes, present as single-select)
   - Content selection (per slide position, present as multi-select with library entries + NEW option)
   - Slide ordering (present ordering strategies from selected pattern)
4. **Stage 4.4: Prepare enhanced delegation context** - Add user selections to delegation context:
   ```json
   {
     "user_selections": {
       "pattern": {"id": "yc-10-slide", "name": "YC 10-Slide Investor Pitch"},
       "theme": {"id": "dark-blue", "name": "Dark Blue (AI Startup)"},
       "content_manifest": {"cover": "cover-standard", "problem": "NEW", ...},
       "main_slides": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
       "appendix_slides": [11, 12],
       "ordering": "yc-standard"
     }
   }
   ```

**Change 3 - Update Stage 5 (Invoke Agent)** - Include `user_selections` in the agent prompt so the agent receives pre-gathered choices.

**Change 4 - Update the return format** to include pattern/theme/ordering from user selections.

#### File 2: `deck-planner-agent.md`

**Change 1 - Remove Stages 3-6** (Interactive questions). These move to the skill.

**Change 2 - Add Stage 3: Parse User Selections** - New stage that extracts `user_selections` from delegation context instead of asking questions.

**Change 3 - Remove AskUserQuestion from Allowed Tools section** (line 25). The agent no longer needs it.

**Change 4 - Update Overview** to reflect that the agent receives pre-selected choices rather than asking questions.

**Change 5 - Update Error Handling** - Remove "User Abandonment" case (that now happens in the skill). Add "Missing User Selections" case for when the skill fails to pass selections.

### Finding 6: The --quick Flag Consideration

The current `deck-planner-agent` handles `--quick` by skipping Steps 1-2 (defaulting to YC 10-slide + dark-blue theme). This logic should also move to `skill-deck-plan`:

- If `--quick` flag is set, skip AskUserQuestion calls for pattern and theme
- Use defaults: `pattern = "yc-10-slide"`, `theme = "dark-blue"`
- Still execute content selection and ordering questions (or skip those too for full quick mode)

### Finding 7: Library Initialization Belongs in Skill

The `deck-planner-agent` Stage 1.5 initializes the deck library from the extension seed:
```bash
if [ ! -f .context/deck/index.json ]; then
  mkdir -p .context/deck
  cp -r .claude/extensions/founder/context/project/founder/deck/* .context/deck/
fi
```

This should also move to the skill (before questions are asked), since the skill needs to query `index.json` to build the AskUserQuestion options.

## Decisions

- The fix requires modifying 2 files: `skill-deck-plan/SKILL.md` and `deck-planner-agent.md`
- Interactive questions move from agent to skill to match the `skill-fix-it` established pattern
- The agent becomes a "plan generator" that receives pre-gathered selections
- Library initialization moves to the skill since it needs the index to build question options
- The `--quick` flag bypass also moves to the skill

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Skill becomes significantly longer and more complex | The pattern is well-established by skill-fix-it; the complexity is inherent to interactive flows |
| Agent loses flexibility to ask follow-up questions | Add a "content gaps" follow-up question in the skill if research report shows critical gaps |
| Breaking change if agent is invoked by other paths | deck-planner-agent is only invoked by skill-deck-plan (verified via grep) |
| Content selection question may be very long for 10+ slides | Use the "Select all" pattern from skill-fix-it for large option lists |

## Appendix

### Files Read

| File | Path | Purpose |
|------|------|---------|
| skill-deck-plan | `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` | Current skill definition (266 lines) |
| deck-planner-agent | `.claude/extensions/founder/agents/deck-planner-agent.md` | Current agent with interactive questions (404 lines) |
| skill-fix-it | `.claude/skills/skill-fix-it/SKILL.md` | Reference pattern for AskUserQuestion in skills (550 lines) |
| /fix-it command | `.claude/commands/fix-it.md` | Reference command showing interactive flow (305 lines) |
| /deck command | `.claude/extensions/founder/commands/deck.md` | Deck command definition showing full workflow (486 lines) |
| Task 347 summary | `specs/347_*/summaries/02_deck-plan-picker-summary.md` | What task 347 implemented (routing fix) |
| Task 347 plan | `specs/347_*/plans/02_deck-plan-picker.md` | Task 347 implementation plan |
| Round 1 report | `specs/348_*/reports/01_plan-interactive-questions.md` | Previous (incorrect) research |

### AskUserQuestion JSON Schema

From skill-fix-it examples, the tool accepts:

```json
{
  "question": "User-facing question text",
  "header": "Section header for the picker",
  "multiSelect": true,
  "options": [
    {
      "label": "Option display text",
      "description": "Additional context shown below label"
    }
  ]
}
```

For single-select, use `"multiSelect": false` (or omit it).
