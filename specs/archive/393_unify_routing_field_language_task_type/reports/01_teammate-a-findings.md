# Research Report: Task #393 - Teammate A (Primary Angle)

**Task**: 393 - Unify routing field: replace separate language and task_type with single extension:task_type format
**Researcher**: Teammate A - Primary State Audit
**Started**: 2026-04-10T16:00:00Z
**Completed**: 2026-04-10T16:45:00Z
**Effort**: ~45 minutes
**Focus**: Current state audit, migration scope, backwards compatibility

---

## Key Findings

1. **The routing system is already partially unified**: The `language` field in state.json already supports compound keys like `founder:deck`, `present:grant`, `founder:financial-analysis` - the `task.md` command already detects and stores these directly (e.g., `"deck", "slide"` → `founder:deck`).

2. **`task_type` is a secondary disambiguation field**: It was added in task 392 to differentiate sub-types within extension languages (e.g., `language="present"`, `task_type="grant"`). The routing commands (`research.md`, `plan.md`, `implement.md`) look up the `language` field directly in manifest routing tables and already handle compound keys.

3. **The gap is non-uniform**: Some tasks store `language="founder"` + `task_type="market"` while others store `language="founder:deck"` (no task_type). The `research.md` command reads only `language` for routing and already handles compound format. `task_type` is extracted in the GATE IN of research.md but only stored - it is **not used to construct the routing key** in the core commands.

4. **Extension commands themselves set both fields**: Founder/present commands like `/market`, `/grant`, `/budget` set both `language` AND `task_type` when creating tasks. The routing commands then look only at `language` for routing, while skills/agents also check `task_type` for validation.

5. **Migration would consolidate redundancy**: The unified `{extension}:{task_type}` format in `language` alone (no separate `task_type`) is already how routing works in the commands. Migration means removing `task_type` as a separate field and ensuring commands set the compound `language` format.

---

## Current State Audit

### Field Usage Breakdown

#### `language` field (state.json `active_projects[].language`)

**Simple values** (core languages - no task_type needed):
- `general` - General purpose tasks
- `meta` - System/agent building tasks
- `markdown` - Documentation tasks
- `neovim` - Neovim/Lua configuration
- `lean4` - Lean theorem proving
- `latex` - LaTeX document tasks
- `typst` - Typst document tasks
- `python` - Python tasks
- `nix` - Nix configuration
- `web` - Web development (Astro, Tailwind)
- `z3` - SMT solver tasks
- `epidemiology` - Epidemiology modeling
- `formal` - Formal logic tasks
- `founder` - Generic founder task (fallback)
- `present` - Generic present task (fallback)

**Compound values** (already stored directly in `language` field):
- `founder:deck` - Detected by `/task` keyword matching ("deck", "slide", "presentation")
- `founder:sheet` - Detected by keyword ("spreadsheet", "sheet", "excel")
- `founder:finance` - Detected by keyword ("finance", "financial", "revenue")
- `founder:market` - Detected by keyword ("market size", "tam", "sam", "som")
- `founder:analyze` - Detected by keyword ("competitive", "competitor")
- `founder:strategy` - Detected by keyword ("strategy", "strategic", "roadmap")
- `founder:legal` - Detected by keyword ("legal", "contract", "agreement")
- `founder:project` - Detected by keyword ("project plan", "timeline", "milestone")
- `founder:financial-analysis` - Used in financial-analysis-agent metadata

**NOT stored as compound in `language` when created by extension commands** (uses separate `task_type` instead):
- `language="founder"` + `task_type="market"` (set by `/market` command)
- `language="founder"` + `task_type="analyze"` (set by `/analyze` command)
- `language="founder"` + `task_type="strategy"` (set by `/strategy` command)
- `language="founder"` + `task_type="legal"` (set by `/legal` command)
- `language="founder"` + `task_type="project"` (set by `/project` command)
- `language="founder"` + `task_type="deck"` (set by `/deck` command explicitly)
- `language="present"` + `task_type="grant"` (set by `/grant` command)
- `language="present"` + `task_type="budget"` (set by `/budget` command)
- `language="present"` + `task_type="timeline"` (set by `/timeline` command)
- `language="present"` + `task_type="funds"` (set by `/funds` command)
- `language="present"` + `task_type="talk"` (set by `/talk` command)

#### `task_type` field (state.json `active_projects[].task_type`)

**Schema definition** (from `state-management-schema.md`):
```json
"task_type": null   // or string value when set
```
- Marked as optional, no default value
- Currently only populated by extension commands that use it
- Core language tasks (`meta`, `general`, `neovim`, etc.) never set `task_type`

**Values currently in use**:

| Extension | task_type values | Files that set it |
|-----------|-----------------|-------------------|
| founder | market, analyze, strategy, legal, project, deck, sheet, finance, meeting | 9 command files |
| present | grant, budget, timeline, funds, talk | 5 command files |

### Files Using `task_type` (52 total files)

**Commands** (14 files):
- `.claude/extensions/founder/commands/market.md` - sets task_type="market"
- `.claude/extensions/founder/commands/analyze.md` - sets task_type="analyze"
- `.claude/extensions/founder/commands/strategy.md` - sets task_type="strategy"
- `.claude/extensions/founder/commands/legal.md` - sets task_type="legal"
- `.claude/extensions/founder/commands/project.md` - sets task_type="project"
- `.claude/extensions/founder/commands/deck.md` - reads and validates task_type="deck"
- `.claude/extensions/founder/commands/sheet.md` - sets task_type="sheet"
- `.claude/extensions/founder/commands/finance.md` - sets task_type="finance"
- `.claude/extensions/founder/commands/meeting.md` - sets task_type="meeting"
- `.claude/extensions/present/commands/grant.md` - sets task_type="grant"
- `.claude/extensions/present/commands/budget.md` - sets task_type="budget"
- `.claude/extensions/present/commands/timeline.md` - sets task_type="timeline"
- `.claude/extensions/present/commands/funds.md` - reads and validates task_type="funds"
- `.claude/extensions/present/commands/talk.md` (inferred)

**Skills** (21 files):
- `.claude/extensions/founder/skills/skill-market/SKILL.md`
- `.claude/extensions/founder/skills/skill-analyze/SKILL.md`
- `.claude/extensions/founder/skills/skill-strategy/SKILL.md`
- `.claude/extensions/founder/skills/skill-legal/SKILL.md`
- `.claude/extensions/founder/skills/skill-project/SKILL.md`
- `.claude/extensions/founder/skills/skill-deck-research/SKILL.md`
- `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md`
- `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md`
- `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md`
- `.claude/extensions/founder/skills/skill-finance/SKILL.md`
- `.claude/extensions/founder/skills/skill-meeting/SKILL.md`
- `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md` - reads task_type for content routing
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` - reads task_type for content routing
- `.claude/extensions/present/skills/skill-grant/SKILL.md`
- `.claude/extensions/present/skills/skill-budget/SKILL.md`
- `.claude/extensions/present/skills/skill-timeline/SKILL.md`
- `.claude/extensions/present/skills/skill-funds/SKILL.md`
- `.claude/extensions/present/skills/skill-talk/SKILL.md`

**Agents** (14 files):
- `.claude/extensions/founder/agents/market-agent.md`
- `.claude/extensions/founder/agents/analyze-agent.md`
- `.claude/extensions/founder/agents/strategy-agent.md`
- `.claude/extensions/founder/agents/legal-council-agent.md`
- `.claude/extensions/founder/agents/project-agent.md`
- `.claude/extensions/founder/agents/deck-research-agent.md`
- `.claude/extensions/founder/agents/deck-planner-agent.md`
- `.claude/extensions/founder/agents/deck-builder-agent.md`
- `.claude/extensions/founder/agents/spreadsheet-agent.md`
- `.claude/extensions/founder/agents/finance-agent.md`
- `.claude/extensions/founder/agents/meeting-agent.md`
- `.claude/extensions/founder/agents/founder-plan-agent.md` - reads task_type to select report template
- `.claude/extensions/founder/agents/founder-implement-agent.md`
- Multiple present agents

**Core system files** (4 files):
- `.claude/commands/research.md` - extracts task_type in GATE IN
- `.claude/context/reference/state-management-schema.md` - defines the field
- `.claude/context/templates/orchestrator-template.md` - uses in general template sense
- `.claude/extensions/founder/context/project/founder/domain/migration-guide.md` - documents v2->v3 migration
- `.claude/extensions/founder/context/project/founder/domain/workflow-reference.md` - documents task_type routing

### How Routing Currently Works (Critical Finding)

The routing commands (`research.md`, `plan.md`, `implement.md`) work exclusively from the `language` field using manifest lookup:

```bash
# Stage 2 routing in research.md, plan.md, implement.md:
language=$(echo "$task_data" | jq -r '.language // "general"')

# Direct compound key lookup in manifest routing tables
ext_skill=$(jq -r --arg lang "$language" '.routing.research[$lang] // empty' "$manifest")

# Fallback: if compound (contains ":"), try base language
if [ -z "$skill_name" ] && echo "$language" | grep -q ":"; then
  base_lang=$(echo "$language" | cut -d: -f1)
  # ...look up base_lang in manifests
fi
```

**The `task_type` field is NOT used by routing commands to construct the routing key.** It is:
1. Extracted in research.md GATE IN but stored without use in routing
2. Used by skills/agents for **validation** (confirming they got the right task)
3. Used by shared agents (`founder-plan-agent`, `founder-implement-agent`) to select content templates

**Implication**: For routing to work with compound keys, the `language` field must already contain the compound value (e.g., `founder:deck`, `present:grant`). Tasks created by `/market`, `/analyze` etc. with `language="founder"` + `task_type="market"` DO NOT route to `skill-market` via the compound key - they rely on the base `founder` key routing to `skill-market` as the default.

### Routing Table Analysis

**Founder manifest routing (research)**:
```json
"research": {
  "founder": "skill-market",       // base key - used when task_type="market" but language="founder"
  "founder:market": "skill-market",
  "founder:analyze": "skill-analyze",
  "founder:strategy": "skill-strategy",
  "founder:legal": "skill-legal",
  "founder:project": "skill-project",
  "founder:sheet": "skill-spreadsheet",
  "founder:finance": "skill-finance",
  "founder:financial-analysis": "skill-financial-analysis",
  "founder:deck": "skill-deck-research",
  "founder:meeting": "skill-meeting"
}
```

**Present manifest routing (research)**:
```json
"research": {
  "present": "skill-grant",         // base key - fallback
  "present:grant": "skill-grant",
  "present:budget": "skill-budget",
  "present:timeline": "skill-timeline",
  "present:funds": "skill-funds",
  "present:talk": "skill-talk"
}
```

**Key insight**: The manifests already have compound keys defined. The problem is that extension commands set `language="founder"` + `task_type="market"` instead of `language="founder:market"`. So tasks route via the base `"founder"` key (landing on `skill-market` as default) rather than via `"founder:market"`.

---

## Proposed Unified Format

### Single Field Design

Replace the two-field system with a single unified routing field stored in `language`:

```json
// BEFORE (two fields)
{
  "language": "founder",
  "task_type": "market"
}

// AFTER (single field)
{
  "language": "founder:market"
}
```

```json
// BEFORE (present extension)
{
  "language": "present",
  "task_type": "grant"
}

// AFTER
{
  "language": "present:grant"
}
```

### Simple Cases (No Change Needed)

Tasks with simple language values that need no sub-type:
```json
{ "language": "meta" }       // no change
{ "language": "general" }    // no change
{ "language": "neovim" }     // no change
{ "language": "lean4" }      // no change
```

### Compound Cases (Changed)

Extension tasks with sub-types:
```json
{ "language": "founder:market" }     // was: language=founder, task_type=market
{ "language": "founder:deck" }       // already stored this way via /task keyword detection!
{ "language": "present:grant" }      // was: language=present, task_type=grant
{ "language": "present:talk" }       // was: language=present, task_type=talk
```

### Field Name for the Unified Field

The unified field should remain named `language` (not renamed to `routing`). Reasons:
1. Already used in all commands, manifests, skills, and agents
2. Already supports compound format (research.md comments say "may be simple 'founder' or compound 'founder:deck'")
3. Manifest routing tables already keyed on the language field
4. TODO.md entry format uses `- **Language**: {value}`
5. Context index uses `load_when.languages` arrays

Renaming would require changing every file that reads the `language` field, adding cost without benefit.

---

## Migration Scope

### Files Requiring Changes

**Category 1: Extension Commands** (need to set compound language, drop task_type)

*Founder extension (9 files)*:
- `.claude/extensions/founder/commands/market.md` - change `language="founder"` + `task_type="market"` → `language="founder:market"`
- `.claude/extensions/founder/commands/analyze.md` - `→ language="founder:analyze"`
- `.claude/extensions/founder/commands/strategy.md` - `→ language="founder:strategy"`
- `.claude/extensions/founder/commands/legal.md` - `→ language="founder:legal"`
- `.claude/extensions/founder/commands/project.md` - `→ language="founder:project"`
- `.claude/extensions/founder/commands/deck.md` - already uses language for validation, remove task_type from creation
- `.claude/extensions/founder/commands/sheet.md` - `→ language="founder:sheet"`
- `.claude/extensions/founder/commands/finance.md` - `→ language="founder:finance"`
- `.claude/extensions/founder/commands/meeting.md` - `→ language="founder:meeting"`

*Present extension (5 files)*:
- `.claude/extensions/present/commands/grant.md` - `→ language="present:grant"`
- `.claude/extensions/present/commands/budget.md` - `→ language="present:budget"`
- `.claude/extensions/present/commands/timeline.md` - `→ language="present:timeline"`
- `.claude/extensions/present/commands/funds.md` - `→ language="present:funds"`
- `.claude/extensions/present/commands/talk.md` - `→ language="present:talk"`

**Category 2: Skills** (need to update validation - check language field instead of task_type)

*Founder extension (18 skill files with task_type references)*:
- Replace: `task_type=$(jq -r '.task_type // null' ...)` + separate validation
- With: Parse compound from `language` field: `sub_type=$(echo "$language" | cut -d: -f2)`

*Present extension (5 skill files with task_type references)*:
- Same pattern: derive sub-type from compound language value

**Category 3: Agents** (need to update metadata and validation)

*Founder extension (14 agent files)*:
- Return metadata: replace `"task_type": "market"` with language compound already present
- Validation logic: check language compound instead of separate task_type

*Present extension (5 agent files)*:
- Same pattern

**Category 4: Core System Documentation**

- `.claude/context/reference/state-management-schema.md` - remove `task_type` field from schema, update field table
- `.claude/CLAUDE.md` - update Language-Based Routing section, state.json structure example
- `.claude/commands/research.md` - remove task_type extraction from GATE IN (line 255)
- `.claude/extensions/founder/context/project/founder/domain/migration-guide.md` - add v3→v4 migration section
- `.claude/extensions/founder/context/project/founder/domain/workflow-reference.md` - update task_type field docs
- `.claude/extensions/founder/EXTENSION.md` - update routing documentation

**Category 5: TODO.md Format**

Current `TODO.md` entry format shows:
```markdown
- **Language**: meta
```
No changes needed here - language values will just show compound format:
```markdown
- **Language**: present:grant
```

**Category 6: `task.md` Command** (partial - already mostly correct)

The `/task` keyword detection already outputs compound language values for *some* founder subtypes (e.g., `founder:deck`). It does NOT yet output compound values for present extension sub-types. No changes needed if extension commands handle their own task creation.

However, the `task.md` language detection table would benefit from documentation updates to reflect all available compound keys.

### Files NOT Requiring Changes

The following already work correctly with the proposed unified format:
- `research.md` routing logic (already reads compound language)
- `plan.md` routing logic (already reads compound language)
- `implement.md` routing logic (already reads compound language)
- All manifest `routing` tables (already keyed on compound language values)
- Context index `load_when.languages` arrays (work with any string value)

---

## Backwards Compatibility

### Active Tasks in state.json

The current `state.json` has no active tasks with compound-format extension languages. All completed tasks used `language="meta"` or `language="general"`.

However, in a general migration, existing tasks with `language="founder"` + `task_type="market"` would need handling:

**Option A: Lazy migration** (recommended)
- Leave existing tasks unchanged
- Routing commands already handle base language (e.g., `"founder"` → `skill-market` as default)
- No active task data is lost
- When tasks are archived and recovered, they retain old format (acceptable)

**Option B: One-time migration script**
```bash
# Migrate founder tasks
jq '(.active_projects[] | select(.language == "founder" and .task_type != null)) |=
  .language = (.language + ":" + .task_type) | del(.task_type)' specs/state.json
```
- Cleaner but risky (modifies existing task data)
- Archive state.json would also need migration

**Option C: Dual-field support during transition**
- Skills read both `language` (compound) and `task_type` (fallback) for a period
- Gradually phase out task_type

**Recommendation**: Option A (lazy migration) for existing tasks + Option B for a small targeted script to migrate the handful of non-completed active tasks if any exist. Given current state.json has no active founder/present tasks, migration cost is near zero.

### Validation Patterns in Skills

Skills currently validate with two separate checks:
```bash
if [ "$language" != "present" ]; then error; fi
if [ "$task_type" != "grant" ]; then error; fi
```

After migration, validate compound format:
```bash
if [ "$language" != "present:grant" ]; then error; fi
```

Or more robustly:
```bash
ext=$(echo "$language" | cut -d: -f1)
sub=$(echo "$language" | cut -d: -f2)
if [ "$ext" != "present" ] || [ "$sub" != "grant" ]; then error; fi
```

### Shared Agent Content Routing

The `founder-plan-agent` and `founder-implement-agent` use `task_type` to select output templates:

```markdown
## Primary: Use task_type from delegation context (if present):
| task_type | Report Type | Template |
...
```

After migration, these agents would extract sub-type from language:
```bash
# Before:
task_type from context or state.json

# After:
language from context (e.g., "founder:market")
task_type=$(echo "$language" | cut -d: -f2)  # extract "market"
```

No behavioral change - same template selection logic using the extracted sub-type.

---

## Recommended Approach

### Phase 1: Schema cleanup (1 file)
Update `state-management-schema.md` to:
- Mark `task_type` as deprecated
- Add documentation for compound language format
- Provide migration notes

### Phase 2: Extension command updates (14 files)
For each founder/present extension command:
- Change task creation JSON: remove `task_type` field, make `language` compound
- Update validation code that reads `task_type` from state

### Phase 3: Skill/agent updates (35+ files)
For each skill and agent:
- Remove `task_type` extraction from state.json queries
- Update validation to check compound language
- Derive sub-type from language compound when needed
- Update return metadata: remove `task_type` field, compound language already present

### Phase 4: Core system updates (5 files)
- Remove `task_type` extraction from `research.md` GATE IN
- Update `state-management-schema.md` to remove `task_type` field entirely
- Update `CLAUDE.md` state.json structure example
- Update founder domain docs

### Priority

- **High priority**: Extension commands (Phase 2) - these create new tasks with the old format
- **Medium priority**: Schema docs (Phase 1) - documentation alignment
- **Low priority**: Skills/agents (Phase 3) - they work in practice due to routing commands handling `language`

---

## Confidence Level

**High confidence** on:
- Current state of all files using `task_type` (comprehensive Grep search)
- How routing commands work (read source)
- That `language` field already supports compound format (confirmed in research.md, plan.md, implement.md)
- That manifests already have compound routing keys
- Migration scope (14 command files, ~35 skill/agent files, 5 core files)

**Medium confidence** on:
- Whether shared agents (founder-plan-agent, founder-implement-agent) have other places they use `task_type` beyond template selection (only spot-checked a few)
- The exact implementation in `.claude/commands/spawn.md` and `.claude/commands/todo.md` regarding task_type

**Low confidence** on:
- Whether any outside integrations (OpenCode agents JSON) reference `task_type` - briefly noted `opencode-agents.json` exists but not examined

---

## Appendix: Search Queries Used

1. `Grep pattern="task_type" path=".claude" output_mode=files_with_matches` - Found 52 files
2. `Grep pattern="task_type" path=".claude/extensions/founder" glob="*.md"` - Commands/skills/agents
3. `Grep pattern="task_type" path=".claude/extensions/present" glob="*.md"` - Present extension
4. `Grep pattern="language.*founder:|language.*present:"` - Compound language values
5. `Read .claude/commands/research.md` - Routing implementation
6. `Read .claude/commands/plan.md` - Plan routing
7. `Read .claude/commands/implement.md` - Implement routing
8. `Read .claude/extensions/present/manifest.json` - Present routing table
9. `Read .claude/extensions/founder/manifest.json` - Founder routing table
10. `Read .claude/context/reference/state-management-schema.md` - Field definitions
11. `Read .claude/extensions/founder/context/project/founder/domain/workflow-reference.md` - task_type docs
12. `jq` queries on context/index.json for languages field
