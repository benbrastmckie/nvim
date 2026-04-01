# Implementation Plan: Add Interactive Deck Plan Picker

- **Task**: 347 - Add interactive deck plan picker
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: Task 346 (deck library refactor -- completed)
- **Research Inputs**: reports/01_deck-plan-picker.md, reports/02_team-research.md
- **Artifacts**: plans/02_deck-plan-picker.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The interactive deck plan picker (`deck-planner-agent`, `skill-deck-plan`) and all manifest routing entries already exist from task 346 but are never invoked because the `/plan`, `/implement`, and `/research` commands do not support compound `language:task_type` routing keys (e.g., `"founder:deck"`). The fix requires updating 3 command files to add a base-language fallback for compound keys, and updating `/task` to detect and produce compound language values for founder sub-types. No new skills, agents, or manifest entries need to be created.

### Research Integration

Research reports 01 and 02 (including team findings from teammates A and B) agree on the root cause and fix approach:

- **Root cause**: The `/plan` and `/implement` commands do a simple jq lookup with `$language` against manifest routing tables. When `language = "founder:deck"` this works, but the `/task` command never produces compound language values, so tasks get `language = "founder"` which always matches `skill-founder-plan`.
- **Secondary issue**: The `/research` command documents composite key routing in pseudocode but has no bash manifest loop -- it uses a different routing structure than `/plan` and `/implement`.
- **Convention**: The actual convention stores compound keys in the `language` field directly (e.g., `"language": "founder:deck"`), not in a separate `task_type` field (which is always `null`).
- **All deck components exist**: `deck-planner-agent` (5-stage interactive flow), `skill-deck-plan`, `skill-deck-implement`, `skill-deck-research`, and full manifest routing tables are already implemented.

## Goals & Non-Goals

**Goals**:
- Enable the `/plan` command to route `founder:deck` tasks to `skill-deck-plan` (which invokes `deck-planner-agent` with interactive picker)
- Enable the `/implement` command to route `founder:deck` tasks to `skill-deck-implement`
- Add a real bash manifest loop to the `/research` command (replacing pseudocode)
- Enable `/task` to detect and produce compound language values for founder sub-types
- Add base-language fallback so compound keys that are not in a manifest degrade gracefully to the base language routing

**Non-Goals**:
- Modifying `deck-planner-agent.md` (already complete with 5-stage interactive flow)
- Modifying `skill-deck-plan`, `skill-deck-implement`, or `skill-deck-research` (already complete)
- Modifying `manifest.json` (routing entries already correct)
- Adding compound key support to `context/index.json` (lower priority, can be done separately)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Routing change breaks existing founder tasks | High | Low | Compound key lookup falls back to base language, preserving existing behavior |
| `/task` keyword detection produces false positives for founder sub-types | Medium | Low | Use specific keyword sets; only match when context is clear |
| `/research` bash loop change breaks existing research routing | Medium | Low | Follow same pattern as `/plan` and `/implement` loops; test with existing tasks |
| Other extensions with future compound keys affected | Low | Low | The fallback pattern is generic and benefits all extensions |

## Implementation Phases

### Phase 1: Fix /plan and /implement Command Routing [NOT STARTED]

**Goal**: Add base-language fallback to both commands so `"founder:deck"` resolves to `skill-deck-plan` (direct match) and unknown compound keys fall back to the base language.

**Tasks**:
- [ ] Edit `.claude/commands/plan.md` lines 98-117: Replace the simple manifest loop with the compound-key-with-fallback pattern
- [ ] Edit `.claude/commands/implement.md` lines 114-132: Apply the same compound-key-with-fallback pattern
- [ ] Update the routing documentation tables in both files to include `founder:deck` entries

**Timing**: 30 minutes

**Files to modify**:
- `.claude/commands/plan.md` - Replace routing block (lines 98-117) with compound key + fallback loop; update routing table (lines 119-124)
- `.claude/commands/implement.md` - Replace routing block (lines 114-132) with compound key + fallback loop; update routing table (lines 135-139)

**Routing pattern to apply** (identical for both, substituting `plan`/`implement`):
```bash
language=$(echo "$task_data" | jq -r '.language // "general"')

skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
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

**Verification**:
- Read the edited files and confirm the compound key lookup + fallback pattern is present
- Confirm that a task with `language = "founder:deck"` would match `skill-deck-plan` in `/plan` and `skill-deck-implement` in `/implement`
- Confirm that a task with `language = "founder"` still matches `skill-founder-plan` / `skill-founder-implement`

---

### Phase 2: Fix /research Command Routing [NOT STARTED]

**Goal**: Replace the pseudocode routing in `/research` with a concrete bash manifest loop matching the pattern used in `/plan` and `/implement`, including compound key support.

**Tasks**:
- [ ] Edit `.claude/commands/research.md` lines 112-140: Replace the pseudocode "Skill Selection Logic" block with a real bash manifest loop
- [ ] Preserve the routing documentation table (lines 104-120) but update it to show compound key examples
- [ ] Ensure the team mode check remains above the manifest loop

**Timing**: 30 minutes

**Files to modify**:
- `.claude/commands/research.md` - Replace pseudocode skill selection logic (lines 122-140) with bash manifest loop; update documentation table

**Verification**:
- Read the edited file and confirm the bash manifest loop exists (matching `/plan` and `/implement` pattern)
- Confirm compound key routing works: `"founder:deck"` resolves to `skill-deck-research`
- Confirm base language fallback works: unknown compound key falls back to base language
- Confirm team mode routing is not affected (checked before manifest loop)

---

### Phase 3: Update /task Language Detection [NOT STARTED]

**Goal**: Enable the `/task` command to detect and produce compound language values for founder sub-types so that new deck tasks get `language = "founder:deck"` automatically.

**Tasks**:
- [ ] Edit `.claude/commands/task.md` lines 111-123: Add founder sub-type detection entries to the language detection table
- [ ] Add entries for: `deck/slide/presentation/pitch` -> `founder:deck`, `spreadsheet/sheet/excel` -> `founder:sheet`, `finance/financial/revenue/burn` -> `founder:finance`, `market size/tam/sam/som` -> `founder:market`, `competitive/competitor` -> `founder:analyze`, `strategy/strategic/roadmap` -> `founder:strategy`, `legal/contract/agreement` -> `founder:legal`, `project/timeline/milestone` -> `founder:project`, and generic `founder/market/go-to-market/gtm` -> `founder`
- [ ] Ensure compound entries are checked before the generic `founder` entry (most-specific-first ordering)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/commands/task.md` - Add founder sub-type detection entries (after line 122, before the "Otherwise -> general" fallback)

**Verification**:
- Read the edited file and confirm all founder sub-type entries are present
- Confirm ordering: compound entries (e.g., `founder:deck`) are listed before the generic `founder` fallback
- Confirm a task described as "Build investor pitch deck" would match `founder:deck`
- Confirm a task described as "Create go-to-market strategy" would match `founder:strategy` or `founder`

---

### Phase 4: Validation and Documentation [NOT STARTED]

**Goal**: Verify the full routing chain works end-to-end and update the routing documentation tables in all modified files.

**Tasks**:
- [ ] Re-read all 4 modified files to verify consistency across commands
- [ ] Verify that the routing tables in `/plan`, `/implement`, and `/research` all document the `founder:deck` routing
- [ ] Verify that the `/task` language detection covers all founder sub-types from the manifest
- [ ] Cross-check against the manifest routing table to ensure no sub-types are missed

**Timing**: 30 minutes

**Files to verify**:
- `.claude/commands/plan.md` - Routing block and table
- `.claude/commands/implement.md` - Routing block and table
- `.claude/commands/research.md` - Routing block and table
- `.claude/commands/task.md` - Language detection table
- `.claude/extensions/founder/manifest.json` - Cross-reference routing entries (read-only)

**Verification**:
- All 4 command files have consistent compound key routing patterns
- All manifest sub-types are represented in `/task` language detection
- No regression in existing routing (base language lookups still work)

## Testing & Validation

- [ ] Read each modified command file and trace the routing logic for `language = "founder:deck"` -- should resolve to `skill-deck-plan`, `skill-deck-implement`, `skill-deck-research` respectively
- [ ] Read each modified command file and trace the routing logic for `language = "founder"` -- should still resolve to `skill-founder-plan`, `skill-founder-implement`, `skill-market` respectively
- [ ] Read `/task` language detection and confirm "Build investor pitch deck" would produce `language = "founder:deck"`
- [ ] Verify the fallback: an unknown compound key like `"founder:unknown"` should fall back to `"founder"` routing
- [ ] Cross-check all founder manifest routing keys against `/task` language detection entries

## Artifacts & Outputs

- `specs/347_add_interactive_deck_plan_picker/plans/02_deck-plan-picker.md` (this file)
- Modified: `.claude/commands/plan.md`
- Modified: `.claude/commands/implement.md`
- Modified: `.claude/commands/research.md`
- Modified: `.claude/commands/task.md`

## Rollback/Contingency

All changes are to markdown command files in `.claude/commands/`. If routing breaks:
1. Revert via `git checkout .claude/commands/plan.md .claude/commands/implement.md .claude/commands/research.md .claude/commands/task.md`
2. Tasks with `language = "founder"` will continue to route to generic founder skills (existing behavior)
3. No data loss risk -- only routing logic is modified, no state or artifact files are changed
