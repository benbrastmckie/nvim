# Research Report: Task #393 (Teammate C - Critic)

**Task**: 393 - Unify routing field: replace separate language and task_type with single extension:task_type format
**Role**: Teammate C (Critic) - Identify gaps, risks, and potential problems
**Started**: 2026-04-09T00:00:00Z
**Completed**: 2026-04-09T01:00:00Z
**Effort**: ~1 hour systematic codebase analysis
**Sources/Inputs**: Codebase analysis (Grep, Read), state.json, archive/state.json, all .claude/ files
**Artifacts**: specs/393_unify_routing_field_language_task_type/reports/01_teammate-c-findings.md

---

## Key Findings

1. **The refactoring is substantially larger than it might appear** -- 261 files reference "language", 52 files reference "task_type"; total impact is 300+ files across commands, skills, agents, context, docs, extensions, rules, and scripts.

2. **A partial implementation already exists and is INCONSISTENT** -- The routing system already supports `extension:task_type` compound keys in manifests, the `language` field already sometimes holds compound values (`"founder:deck"` found in archive, `"founder:financial-analysis"` in current codebase), but task-creation commands write `language` + `task_type` as two separate fields. This inconsistency is the root problem.

3. **Task 392 just completed the opposite of this task** -- Task 392 standardized to `language: "present"` + `task_type: {subtype}` across all present extension commands. Task 393 would need to undo the two-field approach from task 392 and replace it with a single `"present:{subtype}"` field -- touching the same 17+ files again.

4. **The `meta` language special-case is a critical blocker** -- Three separate places in the system special-case `language == "meta"` for different behavior (roadmap exclusion, claudemd_suggestions handling). A unified field like `"meta:implement"` would break these string-equality comparisons.

5. **There is already an anomalous precedent** -- `financial-analysis-agent.md` uses `"language": "founder:financial-analysis"` in its delegation metadata while all other founder agents use plain `"language": "founder"`. This inconsistency exists NOW before any refactoring.

---

## Breaking Change Analysis

### Category 1: jq Select Comparisons (CRITICAL RISK)

These jq expressions perform string-equality comparison on `.language` and would break with compound values:

| File | Line | Query | Risk if language becomes "meta:implement" |
|------|------|-------|------------------------------------------|
| `.claude/commands/todo.md` | 163 | `select(.language != "meta")` | Would include meta tasks in roadmap matching (WRONG) |
| `.claude/commands/todo.md` | 148 | `if [ "$language" = "meta" ]` | Shell comparison fails for "meta:task" |
| `.claude/context/orchestration/state-management.md` | 148 | `select(.language == "neovim")` | Would exclude "neovim:implement" tasks from neovim list |

**The `meta` case is the most severe**: The `/todo` command uses `select(.language != "meta")` to route completed tasks to ROAD_MAP.md vs `claudemd_suggestions`. If `"meta"` tasks become `"meta:something"`, this filter silently breaks -- all meta tasks would incorrectly attempt ROAD_MAP.md matching.

### Category 2: Shell Language Comparisons (HIGH RISK)

These shell conditionals use exact string matching on `$language`:

| File | Pattern | Risk |
|------|---------|------|
| `.claude/skills/skill-implementer/SKILL.md` | `if [ "$language" = "meta" ]` | Fails for compound values |
| `.claude/context/orchestration/routing.md` | `if [ "$language" == "neovim" ]` | Agent validation breaks |
| `.claude/context/orchestration/orchestration-core.md` | `if [ "$language" == "neovim" ]` | Same |
| `.claude/extensions/web/skills/...` | `if [ "$language" != "web" ]` | Fails for "web:react" |
| `.claude/extensions/lean/skills/...` | `if [ "$language" != "lean" ]` | Fails for compound |
| `.claude/extensions/nix/skills/...` | `if [ "$language" != "nix" ]` | Fails for compound |

### Category 3: jq Field Extraction (MEDIUM RISK)

All `jq -r '.language // "general"'` extractions continue to work if the language field just holds a compound string -- they don't do equality comparison, they pass the value downstream. However, the DOWNSTREAM code must be able to parse `"present:grant"` as a compound key.

Commands already handle this (research.md, plan.md, implement.md have `cut -d: -f1` fallback), but context discovery queries do NOT.

### Category 4: Context Discovery (MEDIUM RISK)

The context index uses `load_when.languages[]` to match entries to tasks:

```bash
jq -r '.entries[] | select(.load_when.languages[]? == "neovim") | .path' .claude/context/index.json
```

If task language becomes `"neovim:implement"`, this query returns NO entries for neovim because `"neovim:implement" != "neovim"`. This silently breaks context loading for ALL neovim tasks.

**Affected entries count**: The index currently has entries with `"languages": ["neovim"]`, `"languages": ["meta"]`, etc. None use compound values. After refactoring, all context discovery queries would need to split on `:` and match the base extension name.

### Category 5: validate-wiring.sh (MEDIUM RISK)

The validation script explicitly checks:
```bash
validate_language_entries "$system_dir" "neovim"  # exact match against load_when.languages
validate_language_entries "$system_dir" "lean4"
validate_language_entries "$system_dir" "latex"
validate_language_entries "$system_dir" "typst"
```

If task languages become compound (`"neovim:implement"`), this validation logic becomes stale and misleading.

### Category 6: TODO.md Language Field Display (LOW RISK)

The `**Language**:` field in TODO.md currently shows values like `neovim`, `meta`, `general`. Routing code extracts this with:
```bash
grep "Language" | sed 's/\*\*Language\*\*: //'
```
A compound value `present:grant` would display fine but changes the human-readable format.

---

## Task 392 Overlap Assessment

Task 392 (completed, shipped) touched the following files with `language` and `task_type` changes:

### Files from Task 392 That Would Need Re-touching for Task 393

**Present extension commands (5 files)**:
- `.claude/extensions/present/commands/grant.md` -- just set `language: "present"`, `task_type: "grant"`; would change to `language: "present:grant"`, remove `task_type`
- `.claude/extensions/present/commands/budget.md` -- same pattern
- `.claude/extensions/present/commands/timeline.md` -- same pattern
- `.claude/extensions/present/commands/funds.md` -- same pattern
- `.claude/extensions/present/commands/talk.md` -- same pattern

**Present extension skills (5 files)**:
- Each skill validates `language != "present"` or `task_type != "{subtype}"` -- both checks would need to change to validate `language == "present:{subtype}"`

**Present extension agents (5 files)**:
- Each agent delegation metadata block has `"language": "present"` and `"task_type": "{subtype}"` -- would need to merge

**present/manifest.json**:
- Routing keys are already `"present:grant"`, `"present:budget"`, etc. -- no change needed here
- The manifest is already ahead of the task metadata format

**index-entries.json (17 entries)**:
- Task 392 just changed 17 grant entries from `"languages": ["grant"]` to `"languages": ["present"]`
- Under task 393's unified approach, these would need yet another format change IF context discovery uses compound key matching

**Total task 392 re-work**: Approximately 17-20 files touched in task 392 would need modification again. Minimum 40+ discrete changes that directly overlap task 392.

---

## Documentation Scope

### Files Requiring Significant Documentation Updates

| File | Current References | Update Required |
|------|-------------------|-----------------|
| `.claude/CLAUDE.md` | "Language-Based Routing" table with `general`, `meta`, `markdown` as core languages | Rename field or add sub-field explanation |
| `.claude/context/reference/state-management-schema.md` | Full `task_type` field section (lines 76-92) | Remove `task_type` section, update `language` field docs |
| `.claude/rules/state-management.md` | "language" in field list | Minor update |
| `.claude/rules/workflows.md` | "Route to appropriate skill by language" | Minor update |
| `.claude/rules/plan-format-enforcement.md` | `**Type**: language identifier (meta, neovim, general, etc.)` | Update examples |
| `.claude/docs/guides/creating-agents.md` | Agent delegation examples with `"language": "meta"` | Update examples |
| `.claude/docs/guides/creating-extensions.md` | `"language": "your-domain"` manifest template | Update template |
| `.claude/docs/guides/adding-domains.md` | `"language": "your-domain"` | Update |
| `.claude/docs/guides/creating-skills.md` | Examples with `"language": {language}` | Update |
| `.claude/docs/guides/context-loading-best-practices.md` | `task_type == 'meta'` examples | Remove task_type references |
| `.claude/docs/examples/fix-it-flow-example.md` | 5 example tasks with `"language": "meta"` | Update |
| `.claude/docs/examples/research-flow-example.md` | 2 example tasks with `"language": "meta"` | Update |
| `.claude/docs/reference/standards/multi-task-creation-standard.md` | `"language": "meta"` example | Update |
| `.claude/context/orchestration/orchestrator.md` | Language-based routing documentation | Major update |
| `.claude/context/orchestration/routing.md` | Routing standard with language extraction | Major update |
| `.claude/context/orchestration/orchestration-core.md` | Language extraction patterns | Major update |
| `.claude/context/orchestration/state-management.md` | `select(.language == "neovim")` example | Update |
| `.claude/context/architecture/generation-guidelines.md` | `"language": "{language}"` templates | Update |
| `.claude/context/patterns/thin-wrapper-skill.md` | `"language": "{language}"` | Update |
| `.claude/context/templates/thin-wrapper-skill.md` | `"language": "{language}"` | Update |
| `.claude/agents/meta-builder-agent.md` | Language detection keywords (meta, neovim, etc.) | Update |
| `.claude/agents/spawn-agent.md` | `new_tasks[].language` field docs | Update |
| `.claude/extensions/founder/context/.../workflow-reference.md` | Entire task_type section (23 references) | Major update |
| `.claude/extensions/founder/context/.../migration-guide.md` | task_type migration history | Update |

**Estimated documentation file count**: 25-30 files requiring content updates beyond just `language`/`task_type` field changes.

**Total file impact estimate**: 60-80 files (combining code + docs + examples).

---

## Migration Risk Assessment

### Risk 1: Mixed-Format State.json During Migration

**Scenario**: Migration is in progress. Some tasks use `language: "present"` + `task_type: "grant"` (old format), others use `language: "present:grant"` (new format). The `/todo` command archives tasks one by one. The `select(.language != "meta")` filter would correctly exclude `"meta"` format tasks but would fail to exclude `"meta:something"` format tasks if any meta tasks were already migrated.

**Impact**: Potential incorrect ROAD_MAP.md annotations if mixed-format tasks exist simultaneously.

**Mitigation**: Must update all detection logic BEFORE migrating any task data. This requires either an atomic flag or a migration script.

### Risk 2: Archive State.json Contains Historical Tasks

The archive state.json contains tasks with `"language": "founder:deck"` (1 task at line 119) AND tasks with `"language": "meta"`, `"task_type": "deck"`. These are ALREADY inconsistent in the archive. A migration that changes only active tasks leaves archive tasks with different formats -- potentially confusing any tooling that reads the archive.

**Impact**: Medium. Archive is mostly read-only but `/todo` vault operation reads it.

### Risk 3: No Backward Compatibility for Extension Tasks

Extension commands create tasks with specific language values. If the format changes from `language: "present", task_type: "grant"` to `language: "present:grant"`, any in-flight task that was created before the migration but routed after would hit the new routing logic.

**Impact**: Tasks in `researching` or `planning` state during migration would potentially mis-route. The `/research N` command would extract `language: "present"` (old format) and look up `"present"` in the manifest routing table -- but if the manifest was updated first, `"present"` might no longer be a key (only `"present:grant"` etc. would exist).

**Mitigation needed**: The manifest routing MUST maintain backward-compatible `"present"` key alongside `"present:grant"` until all tasks are migrated.

### Risk 4: `meta` Special-Cases Are Load-Bearing

The `meta` language is not just a routing discriminator -- it drives fundamentally different completion behavior:
- `meta` tasks: write `claudemd_suggestions`, skip ROAD_MAP.md
- Non-meta tasks: write `roadmap_items`, update ROAD_MAP.md

If `meta` tasks become `meta:something` (e.g., `meta:system-build`), the string comparisons at:
- `todo.md` line 148: `if [ "$language" = "meta" ]`
- `todo.md` line 163: `select(.language != "meta")`
- `skill-implementer/SKILL.md` line 290: `if [ "$language" = "meta" ]`

...all fail silently. This is not a cosmetic issue -- it changes what data gets written to state.json and whether ROAD_MAP.md is annotated.

**Assessment**: The `meta` language MUST remain as a simple string value `"meta"` if any sub-typing is introduced. If the task asks for `meta:build` or `meta:create` as subtypes, ALL three locations above must be updated to use startsWith() or `cut -d: -f1` extraction.

---

## Blind Spots and Missing Considerations

### Blind Spot 1: The Task Description Is Ambiguous About Direction

The task says "replace separate language and task_type with single extension:task_type format." But:
- For tasks with `language: "meta"` (no task_type), what is the unified format? `"meta"` unchanged? Or `"meta:task"`?
- For tasks with `language: "general"` (no task_type), does it become `"general"`? Or does the field get renamed?
- Is this about ONLY extension tasks (founder, present, lean4...) or ALL tasks including core ones?

The ambiguity in scope is a hidden risk. If only extension tasks are unified and core tasks (`meta`, `general`, `neovim`, `general`) keep simple language values, the system becomes MORE inconsistent, not less.

### Blind Spot 2: Context Index `load_when.languages` Is a SEPARATE Field

The task description and discussion focuses on task metadata (state.json and TODO.md). But context files in `index.json` have their own `load_when.languages` arrays that must ALSO be updated if the language format changes. These are independent from task routing -- they control which documentation is loaded for each agent session. Currently indexed under simple values: `["neovim"]`, `["meta"]`, etc.

After unification, does context discovery need to:
- Match `"neovim"` against `"neovim:implement"`?
- Use `startsWith` or `split(":")|first`?

This is NOT mentioned in the task description at all.

### Blind Spot 3: The /task Command Language Detection Would Break

The `/task` command auto-detects language from keywords (lines 111-132 of task.md). Currently it detects:
- "deck", "slide", "presentation" -> `founder:deck`
- "spreadsheet", "sheet", "excel" -> `founder:sheet`

But it then writes ONLY `"language": "detected"` to state.json (line 147 shows the placeholder). The actual detection must infer the compound format directly. If the task creates `language: "founder:deck"`, there's no need for `task_type`. But if `task` creates `language: "founder"` + `task_type: "deck"`, that's still two fields.

The task command keyword mapping on lines 123-131 already outputs compound keys like `founder:deck` -- meaning the task command is ALREADY in the unified format for some detection cases but not others. This is an existing inconsistency.

### Blind Spot 4: The meta-builder-agent Creates Tasks Too

The `meta-builder-agent` creates tasks programmatically. Lines 238-241 show keyword detection for meta, neovim, latex, general. It doesn't generate task_type. Any unification would need to update the agent's task creation code too.

### Blind Spot 5: Other Inconsistencies Not Addressed By This Task

The codebase has several related inconsistencies beyond language/task_type:
- `financial-analysis-agent.md` already uses `"language": "founder:financial-analysis"` in delegation metadata -- inconsistent with all other founder agents using `"language": "founder"`
- Some founder commands validate `task_lang` + `task_type` separately while others construct the compound key for display only
- The `validate-wiring.sh` script only validates fixed language values (meta, neovim, lean4, latex, typst) -- it has no mechanism to validate extension sub-types
- Archive state.json has tasks with both `"language": "founder:deck"` and `"language": "meta", "task_type": "deck"` -- demonstrating the format has already been inconsistent across time

### Blind Spot 6: The Route Fallback Logic Is Already Partially There

The research, plan, and implement commands already have fallback logic for compound language keys:
```bash
if [ -z "$skill_name" ] && echo "$language" | grep -q ":"; then
  base_lang=$(echo "$language" | cut -d: -f1)
  # look up base_lang in manifests
fi
```

This means if a task has `language: "present:grant"`, the system would:
1. Try to find `"present:grant"` in manifest routing (success for present extension, which already has this key)
2. If not found, fall back to `"present"` as base lang

This is already implemented. The routing infrastructure supports unified format -- the gap is only in task metadata creation.

---

## What's NOT Being Asked That Arguably Should Be

### Issue 1: The `task_type` Field in TODO.md Display

The schema shows `task_type` maps to `- **Type**: {value}` in TODO.md. If `task_type` is removed, this display field disappears. The plan should clarify whether the unified language value (e.g., `present:grant`) is displayed differently in TODO.md or if the Type line is removed.

### Issue 2: Migration Script for Existing Tasks

The task description says nothing about migrating existing tasks in state.json. Currently active tasks have the two-field format. Should the implementation include a one-time migration script? Or does it only affect new tasks created after implementation?

### Issue 3: The Manifest `language` Field Is Separate from Task `language`

The manifest.json `"language": "founder"` field is the EXTENSION language identifier, not the TASK language. These happen to have the same value currently, but they serve different purposes. Unifying task metadata format doesn't require changing manifest.json structure at all.

### Issue 4: Naming Ambiguity -- "extension:task_type" vs "language:task_type"

The task title says "extension:task_type format." But for core languages like `meta`, `general`, `neovim` -- these are NOT extensions in the technical sense (they don't have manifest.json files -- well, `nvim` does have a manifest but `meta` and `general` don't). The term "extension:task_type" implies all values would have the colon format, which creates the question: is `meta` really `meta:meta`? Or `meta:` (with empty subtype)? Or just `meta` unchanged?

---

## Confidence Level

**Overall**: HIGH confidence in the scope assessment.
**Specific confidence by area**:

| Area | Confidence | Basis |
|------|-----------|-------|
| Breaking changes from `meta` special-cases | HIGH | Direct code inspection of 3 specific locations |
| Task 392 re-work scope (17-20 files) | HIGH | Verified via task 392 summary + present extension file counts |
| Total file impact (60-80 files) | MEDIUM | Count methodology: grep counts, file enumeration |
| Context index `load_when.languages` impact | HIGH | Verified via grep and index structure review |
| Migration risk from mixed-format tasks | MEDIUM | Inferred from system behavior, not tested |
| Archive state inconsistency | HIGH | Directly observed `"language": "founder:deck"` in archive/state.json line 119 |

---

## Summary Risk Matrix

| Risk | Severity | Likelihood | Current Mitigation | Gap |
|------|----------|------------|-------------------|-----|
| meta special-cases breaking | CRITICAL | HIGH | None | Must update 3 locations before data migration |
| Task 392 re-work | HIGH | CERTAIN | None | Task 392 just created the exact opposite approach |
| Context discovery silent failure | HIGH | HIGH | None | `load_when.languages` queries use exact match |
| In-flight task mis-routing | MEDIUM | MEDIUM | Manifest backward compat | Need backward-compat routing keys |
| Archive state inconsistency | LOW | CERTAIN | Archive is read-only | Low operational impact |
| validate-wiring.sh stale | LOW | CERTAIN | Non-blocking warnings | Update script to handle compound keys |

---

## Recommendations for Plan Phase

1. **Define scope precisely first**: Clarify whether unified format applies to ALL tasks (including meta, general) or only extension tasks (founder, present, lean4, etc.)

2. **Update detection logic BEFORE data migration**: All `== "meta"` comparisons must be updated to handle both simple and compound values before any state.json tasks are changed format

3. **Keep manifest backward-compat keys**: While migrating, manifests should keep `"present"` key alongside `"present:grant"` etc.

4. **Address context discovery separately**: `load_when.languages` array matching in context/index.json needs a companion fix -- either update context entries to use compound values OR update discovery queries to use prefix matching

5. **Write a migration script**: Don't require manual task-by-task updates -- create a one-shot jq migration for state.json that merges `language` + `task_type` into compound form for existing tasks

6. **Consider whether `task_type` in TODO.md display field survives**: Decide if `- **Type**: {value}` line is removed or changed to display the subtype portion of the compound language
