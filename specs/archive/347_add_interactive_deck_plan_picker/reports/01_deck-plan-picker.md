# Research Report: Task #347

**Task**: 347 - Add interactive deck plan picker
**Started**: 2026-04-01T14:00:00Z
**Completed**: 2026-04-01T14:30:00Z
**Effort**: 1h
**Dependencies**: Task 346 (deck library refactor -- completed)
**Sources/Inputs**: Codebase analysis of founder extension, /plan command, skill routing
**Artifacts**: specs/347_add_interactive_deck_plan_picker/reports/01_deck-plan-picker.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `deck-planner-agent.md` already exists with a complete interactive picker design (5 AskUserQuestion steps: pattern, theme, content, ordering, plus plan generation)
- The `skill-deck-plan` skill wrapper already exists and correctly delegates to `deck-planner-agent`
- The routing entry `"founder:deck": "skill-deck-plan"` already exists in the founder manifest
- **The routing is broken**: The `/plan` command only looks up routing by `language` (e.g., `founder`), never by `language:task_type` (e.g., `founder:deck`). This means deck tasks always route to `skill-founder-plan` instead of `skill-deck-plan`
- Fix requires updating the `/plan` command's routing lookup to check `language:task_type` before falling back to `language`-only routing

## Context & Scope

Task 347 asks for an interactive question picker in the deck planning workflow. Research revealed that the interactive picker agent (`deck-planner-agent.md`) and its skill wrapper (`skill-deck-plan`) were already created as part of task 346, but the routing from `/plan` to this skill is broken.

The investigation covered:
1. The `/plan` command routing logic
2. The founder extension manifest routing table
3. The `skill-founder-plan` skill (general founder planning)
4. The `skill-deck-plan` skill (deck-specific planning)
5. The `deck-planner-agent` (interactive picker agent)
6. The deck library `index.json` (available categories)
7. The `interactive-selection.md` standard (AskUserQuestion patterns)

## Findings

### 1. Routing Bug in /plan Command

**File**: `.claude/commands/plan.md` (lines 100-113)

The current routing logic:
```bash
ext_skill=$(jq -r --arg lang "$language" \
  '.routing.plan[$lang] // empty' "$manifest")
```

This only looks up by `$language` (e.g., `founder`), which always matches the first entry `"founder": "skill-founder-plan"`. It never constructs the compound key `founder:deck` to check `"founder:deck": "skill-deck-plan"`.

**The manifest already has both entries:**
```json
"plan": {
  "founder": "skill-founder-plan",
  "founder:deck": "skill-deck-plan"
}
```

The same bug affects `/research` and `/implement` routing for all extension task_type-specific routing (deck, sheet, finance, etc.).

### 2. deck-planner-agent Already Fully Designed

**File**: `.claude/extensions/founder/agents/deck-planner-agent.md`

The agent already defines 5 interactive stages:
- **Stage 3**: Pattern Selection (5 patterns: YC 10-slide, Lightning, Product Demo, Investor Update, Partnership)
- **Stage 4**: Theme Selection (5 themes: Dark Blue, Minimal Light, Premium Dark, Growth Green, Professional Blue)
- **Stage 5**: Content Selection (multi-select per slide position from 22 content templates)
- **Stage 6**: Slide Ordering (3 strategies: YC Standard, Story-First, Traction-Led)
- **Stage 7**: Plan Generation with Deck Configuration section

The agent queries `.context/deck/index.json` for all options and uses AskUserQuestion for each step.

### 3. skill-deck-plan Already Exists

**File**: `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md`

The skill wrapper is complete with:
- Preflight status updates
- Postflight marker creation
- Task tool delegation to `deck-planner-agent`
- Postflight status updates and artifact linking
- Git commit
- Cleanup

### 4. Deck Library index.json Categories

**File**: `.claude/extensions/founder/context/project/founder/deck/index.json`

Available options by category:
| Category | Count | Examples |
|----------|-------|---------|
| Themes | 5 | Dark Blue, Minimal Light, Premium Dark, Growth Green, Professional Blue |
| Patterns | 5 | YC 10-Slide, Lightning, Product Demo, Investor Update, Partnership |
| Animations | 6 | Fade In, Slide In Below, Metric Cascade, Rough Marks, Staggered List, Scale In Pop |
| Styles | 9 | 4 color schemes, 3 typography sets, 2 textures |
| Content | 22 | Cover (2), Problem (2), Solution (2), Traction (2), Market (2), Team (2), Ask (2), Business Model (2), Why Us/Now (2), Closing (2), Appendix (3) |
| Components | 4 | MetricCard, TeamMember, TimelineItem, ComparisonCol |

### 5. AskUserQuestion Pattern Compliance

The `deck-planner-agent` follows the `interactive-selection.md` standard:
- Uses proper header, question, options, multiSelect format
- Stage 3 (Pattern) and Stage 4 (Theme) use single-select
- Stage 5 (Content) uses multi-select per slide position
- Stage 6 (Ordering) uses single-select
- Threshold guidelines are respected (5-10 options per question)

### 6. The Same Routing Bug Affects /research and /implement

The `/research` and `/implement` commands likely use the same routing pattern. The manifest defines compound keys for all three:

```json
"research": { "founder:deck": "skill-deck-research" },
"plan": { "founder:deck": "skill-deck-plan" },
"implement": { "founder:deck": "skill-deck-implement" }
```

All three commands need the same routing fix.

## Recommendations

### Minimal Fix: Update /plan Command Routing (Primary)

Update `.claude/commands/plan.md` lines 100-113 to check compound key first:

```bash
language=$(echo "$task_data" | jq -r '.language // "general"')
task_type=$(echo "$task_data" | jq -r '.task_type // empty')

skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    # Try compound key first (e.g., "founder:deck")
    if [ -n "$task_type" ]; then
      ext_skill=$(jq -r --arg key "${language}:${task_type}" \
        '.routing.plan[$key] // empty' "$manifest")
    fi
    # Fallback to language-only key (e.g., "founder")
    if [ -z "$ext_skill" ]; then
      ext_skill=$(jq -r --arg lang "$language" \
        '.routing.plan[$lang] // empty' "$manifest")
    fi
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

skill_name=${skill_name:-"skill-planner"}
```

### Same Fix for /research and /implement Commands

Apply the identical compound-key-first routing pattern to:
- `.claude/commands/research.md`
- `.claude/commands/implement.md`

### No Changes Needed To

- `deck-planner-agent.md` -- already complete
- `skill-deck-plan/SKILL.md` -- already complete
- `manifest.json` -- routing entries already correct
- `index.json` -- library already populated

## Decisions

- The fix is a routing-only change in the `/plan` (and `/research`, `/implement`) commands
- No new files need to be created
- The `deck-planner-agent` and `skill-deck-plan` are ready to use once routing is fixed
- The compound key pattern `language:task_type` is already the manifest convention; the commands just don't use it

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Routing change breaks non-deck founder tasks | High | Low | Compound key lookup falls back to language-only, so existing behavior is preserved |
| task_type field missing in state.json for older tasks | Low | Medium | Use `// empty` null-safe jq pattern; falls back to language-only routing |
| Other extensions with compound keys also affected | Medium | Low | This fix enables all compound-key routing, which is the intended behavior |

## File Change Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `.claude/commands/plan.md` | Edit | Add compound key routing lookup (lines 100-113) |
| `.claude/commands/research.md` | Edit | Add compound key routing lookup (same pattern) |
| `.claude/commands/implement.md` | Edit | Add compound key routing lookup (same pattern) |

**Total files changed**: 3
**Lines changed**: ~10 per file (replace routing block)
**Effort**: 30 minutes

## Appendix

### Search Queries Used
- `Glob: .claude/extensions/founder/skills/*plan*` -- found skill-founder-plan, skill-deck-plan
- `Glob: .claude/extensions/founder/agents/*plan*` -- found founder-plan-agent, deck-planner-agent
- `Read: manifest.json` -- found routing table with compound keys
- `Read: /plan command` -- found routing logic bug
- `Grep: AskUserQuestion` -- found 48 files using the pattern
- `Read: interactive-selection.md` -- confirmed standard compliance

### References
- `.claude/extensions/founder/manifest.json` -- Extension routing table
- `.claude/commands/plan.md` -- /plan command with routing bug
- `.claude/extensions/founder/agents/deck-planner-agent.md` -- Complete interactive picker agent
- `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` -- Skill wrapper for deck planning
- `.claude/extensions/founder/context/project/founder/deck/index.json` -- Deck library index
- `.claude/context/standards/interactive-selection.md` -- AskUserQuestion standard
