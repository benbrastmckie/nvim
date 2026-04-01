# Teammate A Findings: Command Files and Core Routing Audit

**Task**: 347 - Add interactive deck plan picker
**Role**: Teammate A — Core routing audit
**Scope**: Command files (research.md, plan.md, implement.md), skill-orchestrator, task.md, state.json, context/index.json, extension manifests
**Date**: 2026-04-01

---

## Key Findings

### Finding 1: Compound Key is Stored in `language`, Not `task_type`

**Critical**: The actual convention in state.json stores compound routing keys directly in the `language` field (e.g., `"language": "founder:deck"`). There is NO `task_type` field in use — it is always `null` for all active tasks.

Evidence from state.json:
```json
{
  "project_number": 345,
  "project_name": "port_deck_typst_to_slidev",
  "language": "founder:deck",
  "task_type": null
}
```

This means the routing logic should split `language` on `:` to extract the base language and type, NOT look for a separate `task_type` field.

### Finding 2: `/plan` and `/implement` Do Not Support Compound Keys — At All

Both commands look up routing using ONLY the `language` field with a simple jq lookup:
```bash
ext_skill=$(jq -r --arg lang "$language" \
  '.routing.plan[$lang] // empty' "$manifest")
```

When `language = "founder:deck"`, this lookup queries the manifest for key `"founder:deck"`, which DOES exist in the manifest. **However**, there is a secondary problem: neither command extracts `task_type` or splits `language` on `:` to also try `"founder"` as a fallback when `"founder:deck"` is not in the manifest.

Wait — re-reading the manifest carefully:

```json
"plan": {
  "founder": "skill-founder-plan",
  "founder:deck": "skill-deck-plan"
}
```

The manifest DOES contain `"founder:deck"` as a key. So the jq lookup `'.routing.plan[$lang]'` with `$lang = "founder:deck"` should return `"skill-deck-plan"` correctly!

**This means the routing may actually work for tasks where `language = "founder:deck"`.** The bug is subtler: the `/plan` command routing block uses `$lang` from the GATE IN section but that section does NOT extract `task_type`. If the language field literally stores `"founder:deck"`, the jq lookup should match. The confusion in previous report may be because tasks were created with `language: "founder"` (not the compound form).

### Finding 3: `/research` Command Has Inconsistent Design

The `/research` command documents a `task_type`-based composite key approach (lines 50-52, 112-140), describing a model where `language = "founder"` and `task_type = "deck"` combine to form the lookup key. But this is **never populated** — all tasks have `task_type: null`.

The research command also does NOT have a bash loop over extension manifests — it only documents pseudocode in a "Skill Selection Logic" block without a concrete bash implementation for extension routing.

By contrast, `/plan` (lines 98-116) and `/implement` (lines 112-133) have actual bash loops over manifests.

### Finding 4: `/plan` Doesn't Extract `task_type` in GATE IN

The `/research` command (lines 50-52) extracts `task_type` in GATE IN:
```bash
task_type=$(echo "$task_data" | jq -r '.task_type // null')
```

The `/plan` command does NOT extract `task_type` at GATE IN — it only extracts `language` in STAGE 2.

The `/implement` command also does NOT extract `task_type` — only `language`.

### Finding 5: `/task` Command Has No Compound Language Detection

The `/task` command language detection table (lines 111-123) only maps simple language keywords. There is no mechanism to set `language = "founder:deck"` vs `language = "founder"`. The compound key in state.json for task 345 was almost certainly set manually or by an agent that understood the convention — the `/task` command itself cannot detect it.

The `/task` command also has no `task_type` field in the state.json update template (lines 131-143).

### Finding 6: Skill-Orchestrator Is Routing-Only and Doesn't Have Compound Key Support

The `skill-orchestrator/SKILL.md` (lines 42-50) only has a basic language routing table with 4 languages (`neovim`, `general`, `meta`, `markdown`). It has a note about extensions but no actual compound key logic. The orchestrator is a thin router and does not do manifest scanning.

### Finding 7: Context Index Has No Compound Key Routing Entries

`context/index.json` uses `load_when.languages[]` arrays for routing context files to agents. It does not use compound keys. There are no entries with `"founder:deck"` in `load_when.languages`.

### Finding 8: Founder Manifest Already Has Complete Compound Key Routing

The founder manifest (`founder/manifest.json`) has full compound key tables for all three operations:

```json
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
  ...
  "founder:deck": "skill-deck-plan"
},
"implement": {
  "founder": "skill-founder-implement",
  ...
  "founder:deck": "skill-deck-implement"
}
```

---

## Current Routing Chain (for each command)

### /research Routing Chain

```
GATE IN:
  language = task_data.language  (e.g., "founder:deck")
  task_type = task_data.task_type  (always null currently)

STAGE 2 (pseudocode only — no bash manifest loop):
  if team_mode:
    -> skill-team-research
  else if task_type is not null:
    composite_key = "{language}:{task_type}"
    -> extension_routing[composite_key]
  else:
    -> language-based routing (general/meta/markdown -> skill-researcher)

MISSING: No bash loop over manifests for compound key lookup
MISSING: No handling of language="founder:deck" (compound already in language field)

Result: For language="founder:deck", falls through to default skill-researcher (BROKEN)
```

### /plan Routing Chain

```
GATE IN:
  task_data loaded from state.json
  (language NOT extracted here — done in STAGE 2)

STAGE 2:
  language=$(echo "$task_data" | jq -r '.language // "general"')
  # language = "founder:deck"

  for manifest in .claude/extensions/*/manifest.json:
    ext_skill=$(jq -r --arg lang "$language" \
      '.routing.plan[$lang] // empty' "$manifest")
    # jq lookup: .routing.plan["founder:deck"] -> "skill-deck-plan" ✓

  skill_name=${skill_name:-"skill-planner"}

Result: IF language IS stored as "founder:deck", this lookup SHOULD work correctly.
        IF language IS stored as "founder" (no compound), this always routes to "skill-founder-plan".
```

### /implement Routing Chain

```
GATE IN:
  task_data loaded from state.json
  (language NOT extracted here — done in STAGE 2)

STAGE 2:
  language=$(echo "$task_data" | jq -r '.language // "general"')
  # language = "founder:deck"

  for manifest in .claude/extensions/*/manifest.json:
    ext_skill=$(jq -r --arg lang "$language" \
      '.routing.implement[$lang] // empty' "$manifest")
    # jq lookup: .routing.implement["founder:deck"] -> "skill-deck-implement" ✓

  skill_name=${skill_name:-"skill-implementer"}

Result: Same as /plan — works IF language stored as compound, broken if stored as simple.
```

---

## Files Requiring Changes

### 1. `/task` Command — Language Detection (task.md, lines 111-123)

**Current**: Only detects simple language names. Cannot produce compound keys like `founder:deck`.

**Change needed**: Add founder sub-type detection. When task description mentions deck/slide/presentation keywords AND founder context, set `language = "founder:deck"`. Similarly for other sub-types (sheet, finance, etc.).

**Specific location**: `task.md` lines 111-123 (Detect language section)

```
Current:
  - (no founder entry — founder tasks would match nothing and fall to "general")

Needed:
  - "founder", "market", "go-to-market", "gtm" → founder
  - "deck", "slide", "presentation", "pitch" with founder context → founder:deck
  - "spreadsheet", "sheet", "excel" with founder context → founder:sheet
  - "finance", "financial", "revenue", "burn" with founder context → founder:finance
  - "market size", "tam", "sam", "som" → founder:market
  - "competitive", "competitor", "analysis" → founder:analyze
  - "strategy", "strategic", "roadmap" → founder:strategy
  - "legal", "contract", "agreement" → founder:legal
  - "project", "timeline", "milestone" → founder:project
```

### 2. `/research` Command — Routing Logic (research.md, lines 96-151)

**Current**: Has documentation for compound key routing but NO actual bash manifest loop. Only has pseudocode.

**Change needed**: Add a concrete bash implementation (manifest loop) matching the pattern used in `/plan` and `/implement`, but with compound key support:

```bash
language=$(echo "$task_data" | jq -r '.language // "general"')

skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    # Direct lookup (handles both simple "founder" and compound "founder:deck")
    ext_skill=$(jq -r --arg lang "$language" \
      '.routing.research[$lang] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback: if language is compound (contains ":"), try base language
if [ -z "$skill_name" ] && echo "$language" | grep -q ":"; then
  base_lang=$(echo "$language" | cut -d: -f1)
  for manifest in .claude/extensions/*/manifest.json; do
    if [ -f "$manifest" ]; then
      ext_skill=$(jq -r --arg lang "$base_lang" \
        '.routing.research[$lang] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi

skill_name=${skill_name:-"skill-researcher"}
```

**Specific location**: Replace pseudocode at research.md lines 122-140.

### 3. `/plan` Command — Fallback for Compound Keys (plan.md, lines 98-116)

**Current**: Correctly looks up compound key if `language = "founder:deck"`. However, lacks fallback to base language when compound key not found in manifest.

**Change needed**: Add fallback to base language when compound key lookup fails:

```bash
language=$(echo "$task_data" | jq -r '.language // "general"')

skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg lang "$language" \
      '.routing.plan[$lang] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback: if language is compound (contains ":"), try base language
if [ -z "$skill_name" ] && echo "$language" | grep -q ":"; then
  base_lang=$(echo "$language" | cut -d: -f1)
  for manifest in .claude/extensions/*/manifest.json; do
    if [ -f "$manifest" ]; then
      ext_skill=$(jq -r --arg lang "$base_lang" \
        '.routing.plan[$lang] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi

skill_name=${skill_name:-"skill-planner"}
```

**Specific location**: plan.md lines 100-116 (Extension Routing block)

### 4. `/implement` Command — Fallback for Compound Keys (implement.md, lines 112-133)

**Same change as /plan** — add fallback to base language when compound key not found.

**Specific location**: implement.md lines 114-132 (Extension Routing block)

### 5. `context/index.json` — Compound Language Routing (optional)

The context index uses `load_when.languages[]` arrays. Founder extension context entries likely only have `"founder"` not `"founder:deck"`. After routing fix, if agents need deck-specific context, entries should include `"founder:deck"`.

**Note**: This is a lower priority change — the routing fix to commands is the critical path.

---

## Recommended Approach

### Two-Tier Strategy

The system uses two different ways to encode compound routing keys:

**Tier 1 (Current practice, task 345)**: Store compound key directly in `language` field: `"language": "founder:deck"`
- Requires commands to do direct jq lookup with the compound key (already works in plan/implement)
- Requires `/research` to get a real bash manifest loop (currently only pseudocode)
- Requires `/task` to be able to produce compound language values

**Tier 2 (Designed but unused)**: Store `"language": "founder"` + `"task_type": "deck"` separately
- Requires commands to build composite key from two fields
- The `/research` command pseudocode documents this approach but it's never populated

**Recommendation**: Standardize on Tier 1 (compound in `language` field). It's simpler, already works in plan/implement, and is the actual current convention. Update:

1. `/task` command to detect and produce compound language values (e.g., "founder:deck")
2. `/research` command to add a real bash manifest loop (matching plan/implement pattern)
3. Both `/plan` and `/implement` to add base-language fallback when compound key not in manifest
4. Remove the confusing `task_type` pseudocode from `/research` (or update it to explain Tier 1)

### Priority Order

1. **Critical** (routing is completely broken): `/research` command — add bash manifest loop
2. **High** (routing works but no fallback): `/plan` and `/implement` — add base-language fallback
3. **Medium** (new tasks can't be created correctly): `/task` — add compound language detection
4. **Low** (context loading may be wrong for deck tasks): `context/index.json` — add `founder:deck` entries

---

## Evidence/Examples

### Evidence 1: Manifest Has Compound Keys

File: `.claude/extensions/founder/manifest.json` lines 44-75

```json
"plan": {
  "founder": "skill-founder-plan",
  "founder:deck": "skill-deck-plan"
  ...
}
```

### Evidence 2: Real Task Uses Compound Language Field

File: `specs/state.json`

```json
{
  "project_number": 345,
  "language": "founder:deck",
  "task_type": null
}
```

### Evidence 3: /plan Uses Simple jq Lookup (works for compound if stored in language)

File: `.claude/commands/plan.md` lines 100-113

```bash
ext_skill=$(jq -r --arg lang "$language" \
  '.routing.plan[$lang] // empty' "$manifest")
```

With `$lang = "founder:deck"`, the manifest lookup for `".routing.plan["founder:deck"]"` returns `"skill-deck-plan"` — this WORKS.

### Evidence 4: /research Has No Bash Manifest Loop

File: `.claude/commands/research.md` lines 102-151

The entire routing section uses indented pseudocode blocks (`if task_type is not null:`, `composite_key = ...`) with no bash `for manifest in ...` loop. There is no equivalent to the manifest scanning bash code in plan.md and implement.md.

### Evidence 5: /task Cannot Produce Compound Language Values

File: `.claude/commands/task.md` lines 111-123

No "founder" entry exists in the language detection table. A task described as "Build investor pitch deck" would get `language = "general"`, not `language = "founder:deck"`.

---

## Confidence Level

**High** for all findings. All conclusions are based on direct file reading, not inference:
- All 3 command files read in full
- skill-orchestrator SKILL.md read in full
- task.md read in full
- state.json read in full (all tasks have `task_type: null`)
- founder manifest.json read in full
- context/index.json confirmed read (first 100 lines; routing not in these entries)
- Previous research report (01_deck-plan-picker.md) cross-referenced

The only uncertainty is whether the `/plan` and `/implement` jq lookup actually works end-to-end when `language = "founder:deck"` — it should based on code reading, but has not been tested live.

---

## Summary of All Files Requiring Changes

| File | Priority | Change Type | Description |
|------|----------|-------------|-------------|
| `.claude/commands/research.md` lines 102-151 | Critical | Replace | Add bash manifest loop matching plan/implement pattern |
| `.claude/commands/plan.md` lines 98-116 | High | Edit | Add base-language fallback for compound keys |
| `.claude/commands/implement.md` lines 112-133 | High | Edit | Add base-language fallback for compound keys |
| `.claude/commands/task.md` lines 111-123 | Medium | Edit | Add founder sub-type language detection |
| `.claude/context/index.json` (founder entries) | Low | Edit | Add `founder:deck` to load_when.languages |
