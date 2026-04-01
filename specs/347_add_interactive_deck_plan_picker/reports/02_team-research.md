# Research Report: Task #347 — Add Interactive Deck Plan Picker

**Task**: 347 - Add interactive deck plan picker
**Date**: 2026-04-01
**Mode**: Team Research (2 teammates)

## Summary

The deck planning interactive flow already exists — `skill-deck-plan`, `deck-planner-agent` (with 4-5 AskUserQuestion interactions), and all routing entries in `founder/manifest.json` are fully implemented. The problem is purely a routing gap: `/plan` and `/implement` commands do not construct or look up compound `language:type` keys from extension manifests. `/research` documents composite key logic but uses pseudocode without a real bash manifest loop. The fix requires updating 3 command files to support compound key routing, plus updating `/task` to detect and produce compound language values.

## Key Findings

### 1. Compound Key Convention: `language` Field Stores the Composite

The actual convention (evidenced by task 345 in state.json) stores the compound key directly in the `language` field: `"language": "founder:deck"`. The `task_type` field exists in documentation but is always `null` in practice. The system should standardize on this approach.

### 2. All Deck Skills and Agents Already Exist

| Component | Path | Status |
|-----------|------|--------|
| `skill-deck-plan` | `.claude/extensions/founder/skills/skill-deck-plan/` | Fully implemented, never invoked |
| `skill-deck-implement` | `.claude/extensions/founder/skills/skill-deck-implement/` | Fully implemented, never invoked |
| `skill-deck-research` | `.claude/extensions/founder/skills/skill-deck-research/` | Working (research routing works) |
| `deck-planner-agent` | `.claude/extensions/founder/agents/deck-planner-agent.md` | Full interactive flow (4-5 questions) |
| `deck-builder-agent` | `.claude/extensions/founder/agents/deck-builder-agent.md` | Complete implementation |
| `deck-research-agent` | `.claude/extensions/founder/agents/deck-research-agent.md` | Working |

### 3. Manifest Routing Tables Are Complete

The founder extension manifest already defines correct compound key entries for all three operations:

```json
"plan":      { "founder": "skill-founder-plan",      "founder:deck": "skill-deck-plan" }
"implement": { "founder": "skill-founder-implement",  "founder:deck": "skill-deck-implement" }
"research":  { "founder": "skill-market",             "founder:deck": "skill-deck-research" }
```

### 4. Routing Gap Analysis

| Command | Has Manifest Loop | Constructs Composite Key | Fallback to Base Language | Status |
|---------|-------------------|-------------------------|--------------------------|--------|
| `/research` | NO (pseudocode only) | YES (pseudocode) | YES (pseudocode) | BROKEN — no real bash loop |
| `/plan` | YES (bash loop) | NO — uses `$language` directly | NO | PARTIAL — works if language IS compound |
| `/implement` | YES (bash loop) | NO — uses `$language` directly | NO | PARTIAL — works if language IS compound |

### 5. `/task` Cannot Produce Compound Language Values

The `/task` command's language detection table has no founder entries. A task described as "Build investor pitch deck" gets `language = "general"`, not `language = "founder:deck"`. Users must manually set the language.

### 6. `deck-planner-agent` Interactive Flow

The agent that SHOULD be invoked has a rich 5-stage interactive flow:
1. Pattern selection (single select) — YC 10-Slide, Lightning Talk, Product Demo, etc.
2. Theme selection (single select) — Dark Blue, Minimal Light, Premium Dark, etc.
3. Content selection per slide (multi select) — library content + NEW option
4. Ordering strategy (single select) — YC Standard, Story-First, Traction-Led
5. Main vs appendix slide assignment

This is exactly what the user wants but it's never reached because routing sends deck tasks to `founder-plan-agent` instead.

## Synthesis

### Conflict Resolved: Compound Key Storage Convention

- **Teammate A** found that state.json stores `"language": "founder:deck"` (compound in language field), with `task_type` always `null`
- **Teammate B** described the `/research` pseudocode as using separate `language` + `task_type` fields
- **Resolution**: The actual convention is compound in `language` field. The pseudocode in `/research` describes an alternate approach that was never implemented. Standardize on compound `language` field.

### Implication for Routing Fix

Since `language` already contains the compound key (e.g., `"founder:deck"`), the `/plan` and `/implement` bash manifest loops should already work via `jq '.routing.plan[$lang]'` where `$lang = "founder:deck"`. The real issue may be that the `/task` command creates tasks with `language = "founder"` (no compound), making the jq lookup match `"founder"` instead of `"founder:deck"`.

**Two fixes needed**:
1. `/task` must detect and produce compound language values (e.g., `"founder:deck"`)
2. All three commands need a base-language fallback: if `language = "founder:deck"` and no manifest entry matches, try `"founder"`

### No Gaps Identified

All required components exist. This is purely a routing/wiring fix.

## Recommendations

### Priority Order

| Priority | File | Change |
|----------|------|--------|
| 1 (Critical) | `.claude/commands/research.md` | Replace pseudocode with real bash manifest loop (lines ~102-151) |
| 2 (High) | `.claude/commands/plan.md` | Add base-language fallback for compound keys (lines ~98-116) |
| 3 (High) | `.claude/commands/implement.md` | Add base-language fallback for compound keys (lines ~112-133) |
| 4 (Medium) | `.claude/commands/task.md` | Add founder sub-type language detection (lines ~111-123) |
| 5 (Low) | `.claude/context/index.json` | Add `"founder:deck"` to relevant `load_when.languages` arrays |

### Recommended Routing Pattern (for all 3 commands)

```bash
language=$(echo "$task_data" | jq -r '.language // "general"')

skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    # Direct lookup (handles both "founder" and "founder:deck")
    ext_skill=$(jq -r --arg lang "$language" \
      '.routing.{operation}[$lang] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback: if compound key (contains ":"), try base language
if [ -z "$skill_name" ] && echo "$language" | grep -q ":"; then
  base_lang=$(echo "$language" | cut -d: -f1)
  for manifest in .claude/extensions/*/manifest.json; do
    if [ -f "$manifest" ]; then
      ext_skill=$(jq -r --arg lang "$base_lang" \
        '.routing.{operation}[$lang] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi

skill_name=${skill_name:-"{default_skill}"}
```

### Recommended `/task` Language Detection Additions

```
"deck", "slide", "presentation", "pitch deck" → founder:deck
"spreadsheet", "sheet", "excel" → founder:sheet
"finance", "financial", "revenue", "burn rate" → founder:finance
"market size", "tam", "sam", "som", "go-to-market" → founder:market
"competitive", "competitor analysis" → founder:analyze
"strategy", "strategic", "roadmap" → founder:strategy
"legal", "contract", "agreement" → founder:legal
"project", "timeline", "milestone" → founder:project
"founder" (generic) → founder
```

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Core routing and command file audit | completed | high |
| B | Extension skills, agents, and patterns | completed | high |

## References

- `.claude/commands/research.md` — pseudocode routing (lines 102-151)
- `.claude/commands/plan.md` — bash manifest loop (lines 98-116)
- `.claude/commands/implement.md` — bash manifest loop (lines 112-133)
- `.claude/commands/task.md` — language detection (lines 111-123)
- `.claude/extensions/founder/manifest.json` — routing tables (lines 43-76)
- `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` — deck planning skill
- `.claude/extensions/founder/agents/deck-planner-agent.md` — interactive deck planner
- `specs/state.json` — task 345 compound language evidence
