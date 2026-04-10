# Research Report: Task #393 - Teammate B (Alternative Approaches)

**Task**: 393 - Unify routing field: replace separate language and task_type with single extension:task_type format
**Role**: Teammate B - Alternative Approaches Researcher
**Started**: 2026-04-09T00:00:00Z
**Completed**: 2026-04-09T01:00:00Z
**Effort**: ~1 hour
**Sources/Inputs**: Codebase analysis (commands, manifests, state.json, context index, archived tasks)
**Artifacts**: This report

---

## Executive Summary

- The system ALREADY uses compound `extension:subtype` keys (e.g., `founder:deck`) in routing tables but has historically stored tasks using TWO separate fields: `language` + `task_type`
- Only ONE archived task (task 345) has `language: "founder:deck"` as a compound key; 18 other tasks used the two-field approach (`language: "meta", task_type: "deck"`)
- The colon `:` delimiter is the best choice: it is already established in the manifest routing tables, works correctly with jq `$var` lookup, and avoids shell/path conflicts
- The unified field should be named `language` (not renamed): this minimizes breaking changes while embedding sub-type information
- Core languages (`general`, `meta`, `markdown`) should remain as bare values without a subtype; the format is additive for extension sub-types only
- The `present` extension was recently refactored (task 392) to use compound routing keys but its sub-types are NOT yet in task.md language detection
- **Recommended approach**: Retain the `language` field name; merge `task_type` into it as `extension:subtype`; update task detection in `task.md` and deprecate `task_type` field

---

## Context & Scope

This research examined:
1. All 14 extension manifest routing tables
2. The task creation language detection in `task.md`
3. How routing lookups work in `research.md` and `implement.md`
4. Historical usage patterns in `specs/archive/state.json` (18 tasks with `task_type`, 1 with compound language key)
5. The state-management schema definition of `task_type`
6. How jq handles compound keys with different delimiter characters

---

## Findings

### 1. Naming Analysis (Field Name Options)

#### Option A: Retain `language` (recommended)

**Format**: `language: "founder:deck"` or `language: "neovim"`

**Pros**:
- Zero schema migration complexity: same field name
- Already works in research.md and implement.md routing logic (both commands extract `language` and already handle `"founder:deck"` compound keys with fallback to base language)
- Context index.json uses `load_when.languages` array already aligned with simple language strings
- The schema in state-management-schema.md already shows `language` as the primary field
- TODO.md already renders it as `- **Language**: founder:deck`

**Cons**:
- Semantically imprecise: `founder:deck` is a routing specifier, not strictly a "language"
- Could confuse new contributors about meaning of `language: "founder:deck"`

#### Option B: `routing`

**Format**: `routing: "founder:deck"` or `routing: "neovim"`

**Pros**:
- Semantically accurate: explicitly a routing directive
- Makes the purpose of the field unambiguous
- Clean break from "language" concept

**Cons**:
- Mass breaking change: ~100+ references to `.language` in state.json, commands, skills, agents, context files
- Requires updating TODO.md entry format `**Language**:` -> `**Routing**:` everywhere
- context/index.json uses `load_when.languages` which would need renaming too
- High migration cost for naming clarity gain that is marginal in practice

#### Option C: `scope` or `domain`

**Format**: `scope: "founder:deck"` or `domain: "neovim"`

**Cons**:
- `scope` conflicts with programming scope concepts
- `domain` is used loosely in context architecture already
- Same migration cost as Option B without better semantics

#### Option D: `route`

**Format**: `route: "founder:deck"`

**Pros**: Concise, unambiguous
**Cons**: Same migration cost as Option B; not established anywhere in current system

#### Verdict: Option A (retain `language`) wins on cost-benefit

The current routing logic in research.md and implement.md ALREADY handles compound language keys correctly:
- Extracts `language` from state.json
- Does direct manifest lookup by compound key (`founder:deck`)
- Falls back to base language (`founder`) if compound key not found

Renaming the field would require changes across 80+ files with no functional improvement.

---

### 2. Format Analysis (Delimiter Options)

The key question: which character should separate `extension` from `subtype`?

#### Colon `:` (current choice in manifest routing tables)

**jq compatibility**: Works perfectly. The colon is a legal JSON key character.

```bash
# Works correctly
jq -r --arg lang "founder:deck" '.routing.research[$lang]' manifest.json
# Returns: "skill-deck-research"
```

**Shell safety**: Safe in variable values (`language="founder:deck"`). The colon is benign in bash variable values and is not interpreted as a path separator in non-path contexts.

**File path safety**: Does NOT appear in file paths, so no conflict with directory or file naming.

**Readability**: `founder:deck` is compact and visually clear. The colon convention is established in many systems (Docker image tags `image:tag`, YAML anchors, URL schemes `scheme://`).

**Existing usage**: Already the ONLY delimiter used in manifest routing tables for both `founder` and `present` extensions:
```json
"research": {
  "founder:deck": "skill-deck-research",
  "founder:sheet": "skill-spreadsheet",
  "present:grant": "skill-grant"
}
```

**Verdict: Colon is the correct choice** - already established, jq-compatible, shell-safe.

#### Slash `/`

**jq compatibility**: Works with variable lookup (`$lang` variable). BREAKS with literal path syntax (`.routing["founder/deck"]` requires quoting but `.routing.founder/deck` is a jq path error).

**Shell safety**: Slash is interpreted as path separator in many shell contexts. `language="founder/deck"` stored in variables is fine, but using it in `for manifest in .claude/extensions/*/manifest.json` type loops could cause confusion. The routing command code in `research.md` uses `grep -q ":"` to detect compound keys: this would need to change to `grep -q "/"`.

**Verdict**: Works but introduces path-separator confusion. No advantage over colon.

#### Dot `.`

**jq compatibility**: Works with variable lookup. BREAKS with literal path syntax (`.routing.founder.deck` would mean nested object `{founder: {deck: ...}}`). Requires quoting: `.routing."founder.deck"`.

**Shell safety**: Fine in variable values.

**Verdict**: Breaks jq literal path syntax. Introduces dot-separated namespace confusion. Avoid.

#### Underscore `_`

**Format**: `founder_deck`

**jq compatibility**: Works perfectly.

**Readability**: `founder_deck` could be confused with a single flat token. Loses the hierarchical `extension:subtype` semantics.

**Existing precedent**: None in routing tables. State.json already uses underscores for snake_case slugs.

**Verdict**: Technically feasible but loses semantic clarity. The grouping structure is obscured.

#### Double-colon `::`

**Format**: `founder::deck`

**jq compatibility**: Works.

**Readability**: Familiar from C++ namespace syntax. More verbose than `:`.

**Verdict**: Unnecessary verbosity vs single colon. No benefit.

---

### 3. Edge Cases

#### 3.1 Core Languages Without Subtypes

Core languages (`general`, `meta`, `markdown`) have NO extension-provided routing. They route through the default `skill-researcher` / `skill-implementer` path.

**Question**: Should `general` tasks become `general:default` or stay `general`?

**Analysis**: The routing logic in research.md already falls through to `skill-researcher` when no manifest routing is found. There is NO benefit to adding `:default` suffix to core languages. The compound format is ADDITIVE - only extension sub-types need it.

**Decision**: Core languages remain as bare strings: `general`, `meta`, `markdown`. No subtype needed or useful.

#### 3.2 Extension Languages Without Subtypes

Some extensions (nvim, lean4, python, nix, web, latex, typst, z3, epidemiology, formal) have single language values with NO sub-types in their routing tables:

```json
// nvim manifest: no compound routing keys
// lean manifest: no compound routing keys
// python manifest: no compound routing keys
```

These use `language: "neovim"`, `language: "lean4"`, etc. and route to a single research+implement agent pair.

**Decision**: These remain as bare language values. No subtype compound key needed.

#### 3.3 Extensions WITH Subtypes

Only two extensions currently use compound routing keys:
- `founder`: has 10 sub-types (`deck`, `market`, `analyze`, `strategy`, `legal`, `project`, `sheet`, `finance`, `financial-analysis`, `meeting`)
- `present`: has 5 sub-types (`grant`, `budget`, `timeline`, `funds`, `talk`)

**The current inconsistency**: Tasks for founder subtypes historically used BOTH approaches:
- Tasks 262-270, 340-344, 378-381: `{language: "meta", task_type: "deck"}` (two-field)
- Task 345: `{language: "founder:deck"}` (compound key)

The manifest routing tables ONLY work with the compound key approach. The two-field approach was an older implementation pattern that was never fully integrated into the routing lookup.

#### 3.4 The `task_type` Field Currently Has No Routing Effect

Critically: examining research.md and implement.md, the current routing code extracts `language` and ignores `task_type`:

```bash
# From research.md CHECKPOINT 1 GATE IN:
language=$(echo "$task_data" | jq -r '.language // "general"')
task_type=$(echo "$task_data" | jq -r '.task_type // null')
```

`task_type` is EXTRACTED but then NEVER USED in the routing logic below (Stage 2 DELEGATE). The compound key lookup only uses `language`. This means the existing `task_type` field is currently dead code from a routing perspective.

#### 3.5 Task Detection in task.md

The language detection in `/task` command (step 4) shows the CURRENT state of compound key production:

**Compound keys already produced**:
```
"deck", "slide", "presentation", "pitch deck" → founder:deck
"spreadsheet", "sheet", "excel" → founder:sheet
"finance", "financial", "revenue", "burn rate" → founder:finance
"market size", "tam", "sam", "som" → founder:market
"competitive", "competitor" → founder:analyze
"strategy", "strategic", "roadmap" → founder:strategy
"legal", "contract", "agreement" → founder:legal
"project plan", "timeline", "milestone" → founder:project
"founder", "go-to-market", "gtm" → founder
```

**Missing compound keys** (present extension sub-types NOT yet in task.md detection):
- `present:grant` - no detection keywords
- `present:budget` - no detection keywords
- `present:timeline` - "timeline" currently maps to `founder:project`
- `present:funds` - no detection keywords
- `present:talk` - no detection keywords

This is a gap created by the task 392 refactor that wasn't fully completed.

#### 3.6 The `formal` Extension's Multiple Sub-Agents

The `formal` extension provides 4 specialized research agents (formal, logic, math, physics) but uses a single language value `formal` with NO compound key sub-types in the manifest. All formal tasks currently use `language: "formal"` and route to `skill-formal-research`. There is no sub-type discrimination in the routing table.

If sub-types were added for formal (e.g., `formal:logic`, `formal:math`), this would require updating both the manifest and task detection. This is an opportunity but not a current gap.

---

### 4. Existing Compound Key Support

#### Where It Works (Manifest Level)

The manifest routing tables FULLY support compound keys. Both `founder` and `present` manifests define compound keys, and the routing lookup in research.md/implement.md handles them correctly:

```bash
# From research.md Stage 2 DELEGATE:
# Step 1: Try exact compound key match
ext_skill=$(jq -r --arg lang "$language" '.routing.research[$lang] // empty' "$manifest")

# Step 2: If compound key not found, try base language
if [ -z "$skill_name" ] && echo "$language" | grep -q ":"; then
  base_lang=$(echo "$language" | cut -d: -f1)
  # try base_lang lookup...
fi
```

This fallback pattern handles the case where a task has `language: "founder:meeting"` but the manifest only has `founder` routing - it falls back to the base founder routing.

#### Where It Breaks (Task Creation and Storage)

The gap is at TASK CREATION time:
1. `/task` command detects `founder:deck` from description keywords but does NOT detect `present:grant`, `present:talk`, etc.
2. When `task_type` was set separately (e.g., `{language: "meta", task_type: "deck"}`), the routing logic never used `task_type` for manifest lookup - it only used `language`

#### Where It's Inconsistent (TODO.md Display)

TODO.md entry format shows `- **Language**: {value}`. With compound keys, this displays `- **Language**: founder:deck`. The field has no explicit type sub-field. Currently, `task_type` would show as `- **Type**: deck` (per schema), but no evidence of this being rendered in practice.

---

### 5. Recommended Approach

**Strategy: Consolidate to compound `language` field; deprecate `task_type`**

#### Phase 1: Clarify Intent in Schema Documentation

Update `state-management-schema.md`:
- Document that `language` accepts compound format `extension:subtype`
- Mark `task_type` as deprecated (schedule for removal)
- Add examples showing both `language: "neovim"` (bare) and `language: "founder:deck"` (compound)

#### Phase 2: Fix Task Detection Gaps in task.md

Add present extension sub-type detection to language detection step:
```
"grant", "grant writing", "grant proposal" → present:grant
"research budget", "budget planning" → present:budget
"conference talk", "academic talk", "seminar" → present:talk
"funding", "fellowship", "research funding" → present:funds
```

Note: "timeline" currently maps to `founder:project`. Need to disambiguate.

#### Phase 3: Fix research.md to Use language Only

Remove the dead `task_type` extraction code or use it to construct compound key as fallback:

```bash
# Current (broken - task_type never used for routing):
language=$(echo "$task_data" | jq -r '.language // "general"')
task_type=$(echo "$task_data" | jq -r '.task_type // null')

# Option A: Remove task_type entirely (after migration)
language=$(echo "$task_data" | jq -r '.language // "general"')

# Option B: Construct compound key from task_type as migration aid
language=$(echo "$task_data" | jq -r '.language // "general"')
task_type=$(echo "$task_data" | jq -r '.task_type // ""')
if [ -n "$task_type" ] && ! echo "$language" | grep -q ":"; then
  language="${language}:${task_type}"
fi
```

Option B provides backward compatibility during migration.

#### Phase 4: Schema Cleanup

After all active and new tasks use compound keys, remove `task_type` field from schema. Update `state-management-schema.md`.

---

### 6. Summary of Key Technical Decisions

| Decision | Recommendation | Rationale |
|----------|----------------|-----------|
| Field name | Keep `language` | Zero migration cost; routing code already uses it |
| Delimiter | Colon `:` | Already established in manifests; jq-safe; shell-safe |
| Core languages | Stay bare (`general`, `meta`) | No sub-types needed; routing already falls through to defaults |
| `task_type` | Deprecate, merge into `language` | Currently dead code for routing; compound key is the real path |
| present sub-types | Add to task.md detection | Missing gap from task 392 refactor |
| Compound routing | Already works | research.md and implement.md handle compound keys correctly |

---

## Decisions

- The colon delimiter is the established standard (both in manifest routing tables and historically in task 345 usage)
- Renaming `language` to `routing` or another name is not worth the migration cost
- `task_type` field should be treated as deprecated/unused for routing purposes
- The `present` extension gap in task.md is a concrete bug to fix

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Existing tasks with `task_type: "deck"` won't route to deck-specific skills | Medium | Add Option B backward-compat code in research.md |
| "timeline" keyword ambiguity (founder:project vs present:timeline) | Medium | Use context clues or more specific keywords for each |
| Compound keys in TODO.md `Language` field look unusual | Low | Just cosmetic; users adapt quickly |
| jq `!= ` operator can't compare compound keys differently than simple ones | None | jq string comparison works correctly for all key formats |
| Dot delimiter would break jq path syntax | High | Don't use dot; use colon |

---

## Context Extension Recommendations

- **Topic**: Unified routing field - compound language keys
- **Gap**: No context file explicitly documents the `extension:subtype` compound language key format as the canonical approach
- **Recommendation**: Update `state-management-schema.md` `task_type` section to add deprecation notice and document compound language key as the unified approach

---

## Appendix

### Verification Tests Run

```bash
# Confirmed: colon keys work in jq
echo '{"routing": {"founder:deck": "skill-deck-research"}}' \
  | jq -r --arg lang "founder:deck" '.routing[$lang]'
# Output: skill-deck-research

# Confirmed: dot keys break jq path syntax (but work with variable)
echo '{"routing": {"founder.deck": "skill-deck-research"}}' \
  | jq --arg lang "founder.deck" '.routing[$lang]'
# Output: "skill-deck-research" (works via variable)

# Confirmed: slash keys work but are path-confusing
echo '{"routing": {"founder/deck": "skill-deck-research"}}' \
  | jq -r --arg lang "founder/deck" '.routing[$lang]'
# Output: skill-deck-research
```

### Archived Task Analysis

| Pattern | Count | Example |
|---------|-------|---------|
| Compound key `language: "ext:type"` | 1 | task 345: `founder:deck` |
| Two-field `language: "meta", task_type: "type"` | 18 | tasks 262-270, 340-344, 378-381 |
| Extension bare key `language: "founder"` | Many | task 234+ |
| Core language only | Majority | `meta`, `general`, `neovim` |

### Manifests Using Compound Routing Keys

| Extension | Sub-types in routing |
|-----------|---------------------|
| `founder` | 10 sub-types (deck, market, analyze, strategy, legal, project, sheet, finance, financial-analysis, meeting) |
| `present` | 5 sub-types (grant, budget, timeline, funds, talk) |
| All others | 0 sub-types (single language routing) |

### Files Requiring Changes (Minimal Set)

For Option A (compound key unification):
1. `.claude/commands/task.md` - Add present sub-type detection keywords
2. `.claude/commands/research.md` - Remove/deprecate `task_type` extraction (or add migration fallback)
3. `.claude/context/reference/state-management-schema.md` - Document compound format, deprecate `task_type`

For Option B (also rename field):
Add to above + update all 80+ files containing `.language` references.
