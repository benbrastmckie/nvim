# Research Report: Task 393 - Teammate D (Horizons)

**Task**: 393 - Unify routing field: replace separate language and task_type with single extension:task_type format
**Role**: Teammate D - HORIZONS (Strategic Direction and Future-Proofing)
**Started**: 2026-04-09T18:00:00Z
**Completed**: 2026-04-09T19:30:00Z
**Sources**: Codebase analysis (commands, manifests, state.json, context files, documentation)

---

## Key Findings

1. **The unified `extension:task_type` format is already partially in use.** The manifest routing tables for `founder` and `present` extensions use compound keys (`founder:deck`, `present:grant`). The inconsistency is that tasks in `state.json` still store two separate fields (`language` + `task_type`), while routing lookup synthesizes the compound key at runtime.

2. **Only two extensions (founder, present) have sub-typed routing.** The other 12 extensions use a flat language field with no sub-typing. This means unification primarily affects founder and present, not the whole extension ecosystem.

3. **No ROAD_MAP.md exists.** The roadmap file is absent; strategic context must be inferred from TODO.md task history and the current state of the system.

4. **The `task_type` field is used beyond routing** -- commands use it for validation ("is this a deck task?") and agents use it to select behavior within a skill. Collapsing it into `language` requires careful migration of these validation checks.

5. **Context index `load_when.languages` entries are misaligned.** The present extension's index entries use `"languages": ["grant"]` (not `"present:grant"`), which may prevent context from loading for extension tasks. This cross-cutting inconsistency will get worse without standardization.

6. **The filetypes and memory extensions have `language: null`**, indicating they are command-set extensions rather than language extensions. The unified field needs to handle this gracefully.

---

## Roadmap Alignment

No `specs/ROAD_MAP.md` exists in the project. Inferring strategic priorities from recent task history (tasks 382-393):

- **Tasks 382-391**: Rapid expansion of present extension (5 new commands) and systematic refactoring of existing commands. This shows a clear trend toward building more extension capabilities.
- **Task 392**: "Refactor present extension commands" -- this task immediately preceded 393 and explicitly standardized `language: "present"` with `task_type` differentiation across all 5 present commands.
- **Task 393** (this task): Follows naturally from 392. The refactor in 392 established a consistent two-field pattern; now the question is whether to merge those two fields into one.

**Alignment assessment**: HIGH. The project is clearly in an extension-building phase. Routing unification is a force multiplier: it reduces cognitive overhead for anyone building new extensions, makes routing tables self-documenting, and eliminates the runtime synthesis step that combines `language` and `task_type` into a compound key.

The direction of the project (more extensions, more sub-typed commands) makes this change more valuable over time, not less.

---

## Extension System Evolution

### Current State: Two Routing Tiers

**Tier 1 - Simple extensions** (12 of 14): `language` only, one routing target per operation.
- Examples: nvim, lean, latex, typst, python, nix, web, z3, epidemiology, formal

**Tier 2 - Multi-command extensions** (2 of 14): `language` + `task_type` for sub-routing.
- Examples: founder (11 sub-types), present (5 sub-types)
- Also: filetypes (null language, 5 commands, but no manifest routing)

### Evolution Trajectory

The system is clearly moving toward more multi-command extensions. The pattern of a domain having multiple specialized commands is well-established (founder has `/market`, `/analyze`, `/strategy`, `/legal`, `/project`, `/sheet`, `/finance`, `/deck`, `/meeting`). The present extension grew from 1 command to 5 in tasks 387-391.

**Future multi-command candidates**:
- `filetypes` currently has 5 commands (convert, table, slides, scrape, edit) but no sub-routing in its manifest. If it adds routing, it would need the compound format.
- `formal` currently has 4 sub-agents (formal, logic, math, physics) but treats them as a flat language without sub-commands. Adding dedicated commands per domain would require sub-routing.

### How Unification Enables Auto-Discovery

The current two-step synthesis (`language` + `task_type` -> compound key for manifest lookup) is a runtime join. If tasks stored `language: "founder:deck"` directly, the routing lookup becomes:

```bash
ext_skill=$(jq -r --arg lang "$language" '.routing.research[$lang] // empty' "$manifest")
```

This is simpler and already works -- it is literally what the `research.md` command does in Stage 2 when the compound key is stored directly. The fallback logic exists today because some tasks store `language: "founder"` without the subtype.

**Key insight**: The routing code in `research.md`, `plan.md`, and `implement.md` already handles compound language values. The system is ready for unified routing. What needs to change is the data (tasks in state.json) and the producers (commands that create tasks).

---

## Cross-Cutting Improvements

Beyond the immediate routing unification, several related inconsistencies exist that should be addressed alongside or after this change:

### 1. Context Index `load_when.languages` Misalignment

The present extension's `index-entries.json` uses `"languages": ["grant"]` for grant-specific context entries. This is wrong -- the language stored in tasks is `"present"` (or `"present:grant"` after this change). Context for grant tasks may silently fail to load.

**Scope**: Affects all 17 grant-related context entries in the present extension.
**Fix**: Update `load_when.languages` to use compound form (`"present:grant"`) after task 393 establishes the standard.

### 2. `task_type` Stored in Task Metadata vs. Encoded in Language

After unification, `task_type` as a separate field in state.json becomes redundant. However, commands use `task_type` for validation. The deck command does:
```bash
if [ "$task_lang" != "founder" ] || [ "$task_type" != "deck" ]; then
  echo "Error: Task is not a founder:deck task"
```

After unification, this becomes:
```bash
if [ "$task_lang" != "founder:deck" ]; then
  echo "Error: Task is not a founder:deck task"
```

This is a net simplification: one check instead of two. The `task_type` field in state.json can be deprecated (but should be kept as an optional field for backward compatibility with legacy tasks).

### 3. TODO.md Lacks `task_type` Display

The TODO.md entry format shows `**Language**: present` but not the sub-type. After unification to a compound field, this becomes `**Language**: present:grant` which is more informative. The schema reference shows a `**Type**: market` line for task_type, but existing TODO.md entries don't consistently use it.

**Fix**: Simplify by removing the separate `**Type**` line; the compound language field carries all routing information.

### 4. `filetypes` and `memory` Extensions Have `null` Language

These extensions provide commands but no language-based routing. They rely on command-specific dispatch (the user runs `/convert`, `/edit`, `/learn` directly). This is a legitimate pattern for utility extensions. The unified field should formally recognize a `null` (or absent) language as "command-only extension, no language routing."

### 5. Language Detection in `/task` Command

The `/task` command uses keyword detection to assign a language. Some of these create compound languages directly:
- `"deck", "slide"` -> `founder:deck`
- `"spreadsheet", "sheet"` -> `founder:sheet`

But others don't:
- `"timeline", "milestone"` -> `founder:project` (but present extension also has `/timeline`)
- `"budget"` -> ? (not in the keyword list)

After unification, the keyword detection table needs updating to generate unified compound keys consistently. The ambiguity between `founder:project` (project plan) and `present:timeline` (research timeline) needs explicit disambiguation.

### 6. Model Specification Inconsistency

Present extension commands use `model: claude-opus-4-5-20251101` (pinned, outdated) while core commands use `model: opus` (logical alias). This should be standardized to `model: opus` across all commands and agents.

---

## Naming Convention Audit

### Field Naming Inconsistencies Found

| Location | Field | Value | Issue |
|----------|-------|-------|-------|
| state.json | `language` | `"founder"` | Semantic: means "extension", not "programming language" |
| state.json | `task_type` | `"deck"` | Redundant with compound language; creates join requirement |
| state.json | `project_name` | snake_case | OK, consistent |
| state.json | `project_number` | integer | OK, consistent |
| state.json | `next_project_number` | integer | Naming: "project" used instead of "task" |
| TODO.md | `**Language**:` | `present` | OK but misleading (it's an extension, not a language) |
| TODO.md | `**Type**:` | `market` | Inconsistently used; not all tasks with task_type show this |
| manifest.json | `language` | `"founder"` | Same semantic issue as state.json |
| manifest.json | `routing` | object | OK, clear purpose |

### Naming Observations

**The biggest naming issue**: Both `state.json` and `manifest.json` use `language` to mean what is really "extension-or-core-language." The field stores values like `"neovim"`, `"meta"`, `"general"`, `"founder"`, `"present"` -- a mix of programming languages, domain categories, and product names. The word "language" is overloaded.

**A future-proofing rename could be**: `routing_key` or `domain` instead of `language`. However, this would be a much larger change (all commands, documentation, state files) and is likely not worth doing alongside routing unification.

**Recommendation**: Keep `language` as the field name but update documentation to clarify it means "routing domain" not "programming language." The compound `extension:task_type` format makes the meaning clearer by analogy.

### Consistent Fields Across Manifests

All 14 manifests consistently have:
- `name` - matches directory name
- `version` - semantic version
- `description` - human-readable
- `language` - routing domain (null for utility extensions)
- `provides` - component lists
- `merge_targets` - CLAUDE.md and index.json merge specs

**Inconsistency**: The `routing` field is only present in `founder` and `present`. Other extensions route via a single default agent per operation (no sub-routing). The manifest schema should document `routing` as optional, only needed when an extension has multiple commands with different skills.

---

## Future-Proofing Considerations

### Considered: Multi-Extension Tasks

**Proposed format**: `lean4+python:bridge` for tasks spanning two extensions.

**Assessment**: Interesting but premature. The current system has no mechanism for loading two extensions' contexts simultaneously based on a single task language field. Context loading is done via `load_when.languages` in index entries -- a union query would be needed. The routing mechanism would also need to handle which extension's manifest to consult.

**Verdict**: Don't design for this now. If it's needed, it should be a separate feature. The unified single-extension compound format is sufficient for the next 2-3 years of extension development.

### Considered: Extension Versioning

**Proposed format**: `founder@3.0:deck`

**Assessment**: Unnecessary complexity. The extension system already has a `version` field in manifests. Version pinning at the task level would require the routing system to load a specific version of an extension, which the current file-copy loader cannot do. This is a future extension system feature, not a routing field feature.

**Verdict**: Omit from routing field. Task metadata can record the extension version at creation time as a separate informational field (`extension_version`) if needed.

### Considered: Hierarchical Routing

**Proposed format**: `present:grant:nih`

**Assessment**: Potentially useful. The grant extension already has multiple grant types (NIH R01, K-series, foundation, SBIR). These are currently handled within the grant-agent by reading the task description. If NIH grants needed a fundamentally different workflow (different agents, different skills), a third level would enable that.

**Implementation sketch**:
```json
"routing": {
  "research": {
    "present:grant": "skill-grant",
    "present:grant:nih": "skill-nih-grant",
    "present:grant:nsf": "skill-nsf-grant"
  }
}
```

The fallback logic (`try compound key, fall back to base key`) already handles two levels. A three-level key would just require an additional fallback step.

**Verdict**: The format supports it (hierarchical keys work in JSON objects), but only build it when needed. Don't over-engineer the routing code for hypothetical future sub-sub-types.

### Realistic Future Scenarios

1. **`filetypes` extension adds manifest routing**: The 5 commands (convert, table, slides, scrape, edit) could be unified under compound keys (`filetypes:convert`, `filetypes:edit`). This is likely the next extension to need sub-routing.

2. **`formal` extension adds dedicated sub-commands**: The 4 research agents (formal, logic, math, physics) are treated as sub-types via skill names but not via manifest routing. Adding `/logic`, `/math` commands would require sub-routing.

3. **Cross-extension skills**: Skills that work on any document type (e.g., a "proofreader" that handles latex, typst, and markdown) might need a `*:proofread` syntax or a separate dispatch mechanism. This is speculative.

---

## Strategic Recommendations

### Recommendation 1: Adopt `extension:task_type` as the Single Routing Field (HIGH PRIORITY)

**What to change**:
- Commands that create tasks should store `language: "founder:deck"` instead of `language: "founder"` + `task_type: "deck"`.
- The `task_type` field becomes a deprecated optional field (keep for backward compatibility, do not set for new tasks).
- The routing fallback logic in `research.md`, `plan.md`, `implement.md` already handles this correctly.

**Benefits**:
- Single field encodes all routing information
- Manifest routing table is directly queryable (no synthesis step)
- TODO.md entries become more informative: `Language: present:grant` vs `Language: present`
- Eliminates the "join" pattern where commands must combine two fields

### Recommendation 2: Update Context Index `load_when.languages` to Use Compound Keys (HIGH PRIORITY)

After the routing field unification, all context index entries that use extension sub-types in `load_when.languages` must use the compound form:
- `"languages": ["grant"]` -> `"languages": ["present:grant"]`
- `"languages": ["founder"]` -> `"languages": ["founder:market", "founder:analyze", ...]` (or keep `"founder"` as a broad match)

**Decision point**: Should `load_when.languages: ["founder"]` match all founder sub-types? If yes, the context loading logic needs a prefix-match option. If no, each context file must list all sub-types it applies to.

**Recommendation**: Use prefix matching for extension-wide context (e.g., context that applies to all founder tasks matches `"founder"` prefix). Use exact matching for sub-type-specific context. This is a new semantic in the context loading system that needs to be documented.

### Recommendation 3: Standardize `null`-Language Extension Pattern (MEDIUM PRIORITY)

Document that extensions with `"language": null` are "utility extensions" that route via direct command invocation, not via the `/research`, `/plan`, `/implement` pipeline. The filetypes and memory extensions follow this pattern. This distinction should be explicit in the extension creation guide.

### Recommendation 4: Update Keyword Detection in `/task` Command (MEDIUM PRIORITY)

The keyword-to-language detection table in task.md must produce unified compound language values:
- `"timeline", "milestone"` needs disambiguation: `founder:project` vs `present:timeline` (add context: "research timeline" -> `present:timeline`)
- `"budget"` should map to `present:budget`
- All founder sub-type keywords should produce `founder:X` directly

### Recommendation 5: Consider Renaming `language` to `domain` in Future Work (LOW PRIORITY)

The word "language" is semantically misleading -- it stores routing domains, not programming languages. A rename to `domain` or `routing_domain` would be more accurate. However, this is a large breaking change affecting all commands, documentation, context files, and state schemas. It should be deferred to a major version bump of the agent system (e.g., v4.0), not done as part of this task.

### Recommendation 6: Deprecate but Preserve `task_type` Field (MEDIUM PRIORITY)

After unification, the `task_type` field in state.json should be treated as deprecated:
- New tasks: do not set `task_type`
- Legacy tasks: retain as-is (don't migrate retroactively)
- Validation checks: migrate from `language == X && task_type == Y` to `language == X:Y`
- Schema documentation: mark as deprecated with migration note

The field should remain in the schema for at least one major version to allow passive migration.

---

## Confidence Level

**High** for the core claim: the `extension:task_type` compound format is the right direction. The evidence is clear -- the manifests already use it, the routing code already supports it, and task 392 just standardized a two-field pattern that this task proposes to collapse into one.

**Medium** for the scope of cross-cutting changes: the context index misalignment, TODO.md format, and keyword detection issues are real but require careful enumeration of all affected files before implementation.

**Low** for future-proofing scenarios (multi-extension, versioning, hierarchical): these are plausible but speculative. The design should not be constrained by hypothetical requirements.

---

## Appendix: Files Examined

**Core commands**: `research.md`, `implement.md`, `plan.md`, `task.md`
**Extension manifests**: All 14 extensions in `.claude/extensions/*/manifest.json`
**Extension docs**: `present/EXTENSION.md`, `founder/EXTENSION.md`
**Extension commands**: `grant.md`, `budget.md`, `deck.md`, `market.md`, `sheet.md`
**Schema reference**: `.claude/context/reference/state-management-schema.md`
**Architecture docs**: `.claude/docs/architecture/extension-system.md`, `creating-extensions.md`
**Context architecture**: `.claude/context/architecture/context-layers.md`
**State**: `specs/state.json`, `specs/TODO.md`
**Prior research**: `specs/392_refactor_present_extension_commands/reports/02_teammate-b-findings.md`
