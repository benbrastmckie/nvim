# Teammate B Findings: Extension Routing Audit

**Task**: 347 - Add Interactive Deck Plan Picker
**Date**: 2026-04-01
**Focus**: Extension skills, agents, and existing type-based patterns

---

## Key Findings

1. **The founder extension already has full `language:type` routing** in `manifest.json` for all three operations (research, plan, implement). The compound keys `founder:deck`, `founder:market`, etc. are already defined.

2. **`skill-deck-plan` already exists** as a fully-implemented separate skill at `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md`. It routes to `deck-planner-agent` and is completely distinct from `skill-founder-plan`.

3. **The `/plan` command does NOT use task_type for routing** -- it only looks up the base `language` key from state.json when querying manifest `routing.plan`. This is the core gap.

4. **The `/research` command already implements composite key routing** (`{language}:{task_type}`) but the `/plan` and `/implement` commands do not.

5. **All three deck-specific agents exist** (`deck-research-agent`, `deck-planner-agent`, `deck-builder-agent`) and are fully implemented with detailed interactive flows.

6. **`deck-planner-agent` implements rich AskUserQuestion interactions** -- 4-5 questions covering pattern, theme, content selection, and ordering -- that are completely bypassed when the wrong skill is invoked.

---

## Extension Routing Tables (Current State)

### Founder Extension `routing` section (manifest.json lines 43-76):

```json
"routing": {
  "research": {
    "founder": "skill-market",
    "founder:market": "skill-market",
    "founder:analyze": "skill-analyze",
    "founder:strategy": "skill-strategy",
    "founder:legal": "skill-legal",
    "founder:project": "skill-project",
    "founder:sheet": "skill-spreadsheet",
    "founder:finance": "skill-finance",
    "founder:deck": "skill-deck-research"
  },
  "plan": {
    "founder": "skill-founder-plan",
    "founder:market": "skill-founder-plan",
    "founder:analyze": "skill-founder-plan",
    "founder:strategy": "skill-founder-plan",
    "founder:legal": "skill-founder-plan",
    "founder:project": "skill-founder-plan",
    "founder:sheet": "skill-founder-plan",
    "founder:finance": "skill-founder-plan",
    "founder:deck": "skill-deck-plan"
  },
  "implement": {
    "founder": "skill-founder-implement",
    "founder:market": "skill-founder-implement",
    "founder:analyze": "skill-founder-implement",
    "founder:strategy": "skill-founder-implement",
    "founder:legal": "skill-founder-implement",
    "founder:project": "skill-founder-implement",
    "founder:sheet": "skill-founder-implement",
    "founder:finance": "skill-founder-implement",
    "founder:deck": "skill-deck-implement"
  }
}
```

**Observation**: The manifest has exactly the right routing entries. `founder:deck` is mapped to the deck-specific skills for all three operations. The problem is that `/plan` and `/implement` commands never construct or look up the composite key.

### Other Extensions

No other extension in the codebase defines a `routing` section with sub-type compound keys. Extensions audited:

| Extension | Has `routing` field | Compound keys |
|-----------|---------------------|---------------|
| founder | YES | YES (full set) |
| present | YES (partial) | NO - uses non-standard `skill-grant:assemble` format |
| epidemiology | NO | - |
| filetypes | NO | - |
| formal | NO | - |
| latex | NO | - |
| lean | NO | - |
| memory | NO | - |
| nix | NO | - |
| nvim | NO | - |
| python | NO | - |
| typst | NO | - |
| web | NO | - |
| z3 | NO | - |

The `present` extension has a non-standard routing entry `"grant": "skill-grant:assemble"` -- this appears to be a colon-separated skill:mode format, different from the `language:type` compound key pattern. It is not the same pattern and may be a legacy artifact.

---

## Existing Type-Based Patterns

### In `/research` command (`.claude/commands/research.md` lines 112-140)

The `/research` command is the ONLY command that already implements composite key routing. Lines 122-140:

```
if task_type is not null:
  # Try composite key first: "{language}:{task_type}"
  composite_key = "{language}:{task_type}"
  if composite_key in extension_routing:
    skill_name = extension_routing[composite_key]
  else:
    # Fallback to language-only routing
    skill_name = {language-based routing}
```

The documentation table at lines 114-120 explicitly names `founder:deck -> skill-deck-research` as the example.

### In `/plan` command (`.claude/commands/plan.md` lines 98-116)

The `/plan` command uses ONLY the base `language` key. The routing code at lines 98-116:

```bash
for manifest in .claude/extensions/*/manifest.json; do
  ext_skill=$(jq -r --arg lang "$language" \
    '.routing.plan[$lang] // empty' "$manifest")
```

It queries `'.routing.plan[$lang]'` with only `$lang` -- never constructs a composite key. A task with `language=founder, task_type=deck` will always match `routing.plan["founder"]` = `skill-founder-plan`, bypassing `skill-deck-plan`.

### In `/implement` command (`.claude/commands/implement.md` lines 114-129)

Identical problem to `/plan`:

```bash
for manifest in .claude/extensions/*/manifest.json; do
  ext_skill=$(jq -r --arg lang "$language" \
    '.routing.implement[$lang] // empty' "$manifest")
```

Only queries base language key. A `founder:deck` task routes to `skill-founder-implement` instead of `skill-deck-implement`.

---

## Deck-Specific Skills/Agents Inventory

### Skills (all in `.claude/extensions/founder/skills/`)

| Skill | File | Agent It Delegates To | Status |
|-------|------|-----------------------|--------|
| `skill-deck-research` | `skill-deck-research/SKILL.md` | `deck-research-agent` | Fully implemented, working (research.md has correct composite routing) |
| `skill-deck-plan` | `skill-deck-plan/SKILL.md` | `deck-planner-agent` | Fully implemented, NEVER INVOKED by /plan |
| `skill-deck-implement` | `skill-deck-implement/SKILL.md` | `deck-builder-agent` | Fully implemented, NEVER INVOKED by /implement |
| `skill-founder-plan` | `skill-founder-plan/SKILL.md` | `founder-plan-agent` | Working but routes all founder tasks including deck |
| `skill-founder-implement` | `skill-founder-implement/SKILL.md` | `founder-implement-agent` | Working but routes all founder tasks including deck |

### Agents (all in `.claude/extensions/founder/agents/`)

| Agent | File | Purpose | Interactive? |
|-------|------|---------|--------------|
| `deck-research-agent` | `deck-research-agent.md` | Material synthesis, 10-slide mapping | Minimal (1-2 questions max) |
| `deck-planner-agent` | `deck-planner-agent.md` | Interactive pattern/theme/content/ordering selection | YES - 4-5 AskUserQuestion interactions |
| `deck-builder-agent` | `deck-builder-agent.md` | Slidev deck assembly from library content | No interactive questions |
| `founder-plan-agent` | `founder-plan-agent.md` | Generic founder plan with forcing questions | YES - general forcing questions |
| `founder-implement-agent` | `founder-implement-agent.md` | Generic founder implementation | No |

### `deck-planner-agent` Interactive Flow (5 stages):

1. **Stage 3**: Pattern selection (single select) - YC 10-Slide, Lightning Talk, Product Demo, Investor Update, Partnership
2. **Stage 4**: Theme selection (single select) - Dark Blue, Minimal Light, Premium Dark, Growth Green, Professional Blue
3. **Stage 5**: Content selection (multi select per slide) - library content + NEW option per slide
4. **Stage 6**: Slide ordering strategy (single select) - YC Standard, Story-First, Traction-Led
5. **Stage 5 conditional**: Main vs appendix slide assignment

The agent reads `.context/deck/index.json` for dynamic library content (patterns, themes, content files). It supports a `--quick` flag to skip Steps 1-2 for fast path.

---

## AskUserQuestion Patterns Found

### Pattern 1: Single Select (from `deck-planner-agent.md`)

```json
{
  "question": "Select a deck pattern:",
  "header": "Pattern Selection",
  "options": [
    { "label": "YC 10-Slide Investor Pitch", "description": "Standard Y Combinator format (10 slides)" },
    { "label": "Lightning Talk", "description": "5-minute format (5 slides)" }
  ]
}
```

### Pattern 2: Multi Select (from `task.md` `--review` mode, lines 454-471)

```json
{
  "question": "Select follow-up tasks to create:",
  "header": "Follow-up Tasks",
  "multiSelect": true,
  "options": [
    {
      "label": "Phase 2: implement_validation_rules",
      "description": "Goal: {phase_goal} | Effort: {effort}"
    }
  ]
}
```

### Pattern 3: Confirmation (from `skill-tag/SKILL.md`)

```json
{
  "question": "Create and push version tag?",
  "header": "Version Tag Confirmation",
  "options": ["Yes, proceed", "No, cancel"]
}
```

### Pattern 4: General pattern (from `meta-builder-agent.md`)

Meta-builder agent rule: "ALL user choices MUST use AskUserQuestion with the `options` parameter to render interactive checkboxes/radio buttons."

**Key constraint noted**: AskUserQuestion is listed in `allowed-tools` frontmatter only for skills/commands that explicitly need it. `skill-deck-plan` does NOT list AskUserQuestion in its `allowed-tools` (only `Task, Bash, Edit, Read, Write`) -- but `deck-planner-agent` (the subagent) does have access to AskUserQuestion.

---

## Files Requiring Changes

### Primary Changes Needed

1. **`.claude/commands/plan.md`** - Add composite key routing (same pattern as `research.md`)
   - Lines 98-116: Replace language-only jq query with composite key lookup
   - Need: Extract `task_type` from task data, try `{language}:{task_type}` first, fall back to `{language}`

2. **`.claude/commands/implement.md`** - Add composite key routing (same pattern as `research.md`)
   - Lines 114-129: Same change as plan.md

### Secondary Changes (Documentation/Display Only)

3. **`.claude/commands/plan.md`** - Update routing table (lines 119-125) to document deck routing:
   - Add row: `founder:deck | skill-deck-plan`

4. **`.claude/commands/implement.md`** - Update routing table (lines 133-143) to document deck routing:
   - Add row: `founder:deck | skill-deck-implement`

### No Changes Needed

- **`manifest.json`**: Already has correct composite key routing for all three operations
- **`skill-deck-plan/SKILL.md`**: Fully implemented, just not being invoked
- **`skill-deck-implement/SKILL.md`**: Fully implemented, just not being invoked
- **`deck-planner-agent.md`**: Complete with 4-5 interactive steps
- **`deck-builder-agent.md`**: Complete implementation
- **`deck-research-agent.md`**: Already working via research.md

---

## Gaps Between Manifest and Command Routing

| Operation | Manifest Entry | Command Routing Logic | Gap |
|-----------|---------------|----------------------|-----|
| `/research` | `"founder:deck": "skill-deck-research"` | Constructs composite key, looks up correctly | **NO GAP** - working |
| `/plan` | `"founder:deck": "skill-deck-plan"` | Only uses base `$lang` key `"founder"` -> `skill-founder-plan` | **GAP: deck tasks use wrong skill** |
| `/implement` | `"founder:deck": "skill-deck-implement"` | Only uses base `$lang` key `"founder"` -> `skill-founder-implement` | **GAP: deck tasks use wrong skill** |

### Root Cause

The `/research` command was updated to support composite key routing (it extracts `task_type` and tries the compound key), but `/plan` and `/implement` were not updated with the same logic.

### Effect of the Gap

When a user creates a deck task (`language: founder, task_type: deck`) and runs:
- `/research N` -- Works correctly, routes to `skill-deck-research` -> `deck-research-agent`
- `/plan N` -- Broken, routes to `skill-founder-plan` -> `founder-plan-agent` (generic founder planning, no library interaction)
- `/implement N` -- Broken, routes to `skill-founder-implement` -> `founder-implement-agent` (generic founder implementation, no Slidev deck generation)

---

## Confidence Level: HIGH

All findings based on direct file reads. The gap is clearly demonstrated by comparing:
- `research.md` lines 122-140 (has composite key logic)
- `plan.md` lines 98-116 (lacks composite key logic)
- `implement.md` lines 114-129 (lacks composite key logic)

The fix is minimal: apply the same composite key pattern from `research.md` STAGE 2 to both `plan.md` and `implement.md`. No new skill or agent files need to be created.
