# Research Report: Task #392

**Task**: 392 - Refactor present extension commands (/grant, /budget, /funds, /timeline, /talk)
**Started**: 2026-04-09T23:00:00Z
**Completed**: 2026-04-09T23:15:00Z
**Effort**: medium
**Dependencies**: 391 (completed - manifest integration)
**Sources/Inputs**:
- All 5 present extension command files (grant.md, budget.md, funds.md, timeline.md, talk.md)
- All 5 present extension skill files (skill-grant, skill-budget, skill-funds, skill-timeline, skill-talk)
- Present extension manifest.json, EXTENSION.md
- Core commands (task.md) and founder extension commands (deck.md) for pattern comparison
- Task 391 research report for historical context
**Artifacts**: - specs/392_refactor_present_extension_commands/reports/01_refactor-present-commands.md
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The five present extension commands have significant inconsistencies in language assignment, model specification, Co-Authored-By lines, and structural patterns
- The `grant` and `timeline` commands use standalone language values (`language: "grant"`, `language: "timeline"`) instead of the unified `language: "present"` with `task_type` subfield used by `funds` and `talk`
- The `budget` command uses `language: "budget"` -- a third inconsistent pattern
- Model specifications are inconsistent: 3 commands use the deprecated `claude-opus-4-5-20251101`, 1 has no model, and none use the standard `opus` shorthand used by core commands
- The grant command (oldest) has a substantially different structure (hybrid multi-mode with legacy support) compared to the newer forcing-question pattern used by budget, funds, and talk
- Standardizing all commands to use `language: "present"` with `task_type` differentiation aligns with the manifest routing (`present:grant`, `present:budget`, etc.) established in task 391

## Context & Scope

Task 391 integrated all five commands into the present extension manifest, establishing a routing pattern that uses `present:{subtype}` keys. However, the commands themselves were created at different times (grant first, then budget, timeline, funds, talk in tasks 387-390) and have accumulated inconsistencies. This task aims to systematically align all five commands to a common pattern.

## Findings

### 1. Language Assignment Inconsistencies

This is the highest-impact issue. The manifest routing uses `present:{subtype}` keys, but the commands create tasks with different language values:

| Command | Creates tasks with | Expected (per manifest) | task_type field |
|---------|-------------------|------------------------|-----------------|
| /grant | `language: "grant"` | `language: "present"` | none |
| /budget | `language: "budget"` | `language: "present"` | `"budget"` |
| /timeline | `language: "timeline"` | `language: "present"` | none |
| /funds | `language: "present"` | `language: "present"` | `"funds"` |
| /talk | `language: "present"` | `language: "present"` | `"talk"` |

**Impact**: The manifest routing keys are `present:grant`, `present:budget`, etc. If a task has `language: "grant"` instead of `language: "present"`, the orchestrator routing lookup will fail to match the manifest routing table. Only `/funds` and `/talk` correctly use the unified pattern.

**Required change**: All commands should create tasks with `language: "present"` and a `task_type` field for subtype differentiation.

### 2. Model Specification Inconsistencies

| Command | Current model field | Core command standard |
|---------|--------------------|-----------------------|
| /grant | `claude-opus-4-5-20251101` | `opus` |
| /budget | (none) | `opus` |
| /funds | `claude-opus-4-5-20251101` | `opus` |
| /timeline | `claude-opus-4-5-20251101` | `opus` |
| /talk | `claude-opus-4-5-20251101` | `opus` |

**Required change**: All commands should use `model: opus` to match core command conventions.

### 3. Co-Authored-By Line Inconsistencies

| Command | Co-Authored-By |
|---------|---------------|
| /grant | `Claude Opus 4.5 <noreply@anthropic.com>` |
| /budget | `Claude Opus 4.5 <noreply@anthropic.com>` |
| /funds | `Claude Opus 4.6 (1M context) <noreply@anthropic.com>` |
| /timeline | `Claude Opus 4.6 (1M context) <noreply@anthropic.com>` |
| /talk | `Claude Opus 4.5 <noreply@anthropic.com>` |

**Required change**: All should use the current standard: `Claude Opus 4.6 (1M context) <noreply@anthropic.com>` (matching core CLAUDE.md conventions).

### 4. Structural Pattern Differences

The commands follow two distinct architectural patterns:

**Pattern A -- Hybrid multi-mode** (grant only):
- Supports task creation, draft, budget, fix-it, revise, and legacy modes
- Mode detection via flag parsing (--draft, --budget, --fix-it, --revise)
- Has legacy workflow_type deprecation warning
- Delegates to skill-grant with workflow_type parameter
- Most complex command (548 lines)

**Pattern B -- Forcing-question flow** (budget, funds, talk):
- Stage 0: Pre-task forcing questions (AskUserQuestion)
- Stage 1: Task creation with forcing_data in metadata
- Stage 2: Delegation to skill (for task number input)
- Simpler, more uniform structure
- 300-500 lines each

**Pattern C -- Minimal hybrid** (timeline):
- Task creation + research mode only
- Has forcing questions but in the research stage (not pre-task)
- Language set to "timeline" (wrong)
- Missing task_type field
- Simpler structure (~300 lines)

### 5. Skill Validation Inconsistencies

The skills validate different language values:

| Skill | Validates | Should validate |
|-------|-----------|----------------|
| skill-grant | `language == "grant"` | `language == "present"` |
| skill-budget | `language == "budget"` | `language == "present"` |
| skill-funds | `language == "present"` | `language == "present"` (correct) |
| skill-timeline | `language == "timeline"` | `language == "present"` |
| skill-talk | `language == "present"` | `language == "present"` (correct) |

### 6. EXTENSION.md Language Routing Table

The EXTENSION.md currently shows a mixed routing table:

```
| grant    | -        | skill-grant    | skill-grant    |
| present  | budget   | skill-budget   | skill-budget   |
| present  | timeline | skill-timeline | skill-timeline |
| present  | funds    | skill-funds    | skill-funds    |
| present  | talk     | skill-talk     | skill-talk     |
```

After refactoring, all should show `language: "present"` with different `task_type` values.

### 7. Manifest Routing Alignment

The manifest.json routing (updated by task 391) already uses the correct pattern:

```json
"routing": {
  "research": {
    "present": "skill-grant",
    "present:grant": "skill-grant",
    "present:budget": "skill-budget",
    ...
  }
}
```

This means the routing is ready for `language: "present"` with subtypes, but the commands creating tasks with `language: "grant"` or `language: "budget"` will break this routing.

### 8. Additional Discrepancies

- **grant command** validates `language == "grant"` in skill but the manifest routes `present:grant`
- **budget command** supports file path input (`/budget /path/to/file.md`); grant, talk also support file path; funds and timeline do not
- **timeline command** places forcing questions in the research stage rather than pre-task (Stage 0), unlike budget/funds/talk
- **grant command** has a Revise Mode and Fix-It Mode that other commands lack (these are domain-specific and likely should stay)
- **budget command** references `present/grant-budget-{datetime}.xlsx` for legacy output -- this path should reference the present extension context

## Decisions

1. **Unified language**: All commands will use `language: "present"` with `task_type` for differentiation
2. **Model field**: All commands will use `model: opus`
3. **Co-Authored-By**: All commands will use `Claude Opus 4.6 (1M context) <noreply@anthropic.com>`
4. **Grant-specific modes preserved**: Draft, budget, revise, and fix-it modes on /grant are domain-specific and should remain, but their task creation should use `language: "present"`, `task_type: "grant"`
5. **Timeline forcing questions**: Move to pre-task Stage 0 pattern to match budget/funds/talk
6. **Skill validation**: Update all skills to validate `language == "present"` and check `task_type` for additional validation

## Recommendations

### Priority 1: Language + task_type standardization (highest impact)

Update all 5 commands to create tasks with `language: "present"` and appropriate `task_type`:
- `/grant` -> `language: "present"`, `task_type: "grant"`
- `/budget` -> `language: "present"`, `task_type: "budget"`
- `/timeline` -> `language: "present"`, `task_type: "timeline"`
- `/funds` -> already correct
- `/talk` -> already correct

Update all 5 skills to validate `language == "present"` (not "grant", "budget", or "timeline").

### Priority 2: Model and Co-Authored-By normalization

Mechanical find-and-replace across all 5 commands:
- `model: claude-opus-4-5-20251101` -> `model: opus`
- Add `model: opus` to budget.md frontmatter
- Normalize all Co-Authored-By lines

### Priority 3: EXTENSION.md update

Update the language routing table to show all entries as `language: "present"`.

### Priority 4: Timeline structural alignment (optional)

Move timeline forcing questions from research stage to pre-task Stage 0 to match the pattern used by budget, funds, and talk. This is a structural improvement but lower priority than the language fix.

## Risks & Mitigations

- **Risk**: Existing tasks in state.json with `language: "grant"` or `language: "budget"` will break routing after this change
  - **Mitigation**: Check state.json for any active present-related tasks; if found, update their language field as part of the refactor
- **Risk**: Skills that validate `language == "grant"` will reject tasks with `language == "present"` until skills are updated simultaneously
  - **Mitigation**: Update commands and skills in the same commit/phase to maintain consistency
- **Risk**: Grant command's --revise mode creates child tasks with `language: "grant"` and `parent_grant` field
  - **Mitigation**: Update revise mode to use `language: "present"`, `task_type: "grant"`

## Appendix

### Files requiring changes

**Commands** (5 files):
1. `.claude/extensions/present/commands/grant.md` - language, model, co-authored-by, task_type addition
2. `.claude/extensions/present/commands/budget.md` - language fix (budget -> present), model addition, co-authored-by
3. `.claude/extensions/present/commands/timeline.md` - language fix (timeline -> present), task_type addition, model, co-authored-by
4. `.claude/extensions/present/commands/funds.md` - model fix, co-authored-by already correct
5. `.claude/extensions/present/commands/talk.md` - model fix, co-authored-by

**Skills** (3 files needing language validation changes):
1. `.claude/extensions/present/skills/skill-grant/SKILL.md` - validate present instead of grant
2. `.claude/extensions/present/skills/skill-budget/SKILL.md` - validate present instead of budget
3. `.claude/extensions/present/skills/skill-timeline/SKILL.md` - validate present instead of timeline

**Extension metadata** (1 file):
1. `.claude/extensions/present/EXTENSION.md` - language routing table update

### Estimated change counts
- Total files: 9
- Estimated edits: ~25-30 discrete changes
- Complexity: Low (mostly mechanical replacements with a few structural additions)
