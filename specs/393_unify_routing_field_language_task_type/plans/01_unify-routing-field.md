# Implementation Plan: Task #393

- **Task**: 393 - Unify routing field: replace separate language and task_type with single extension:task_type format
- **Status**: [IMPLEMENTING]
- **Effort**: 14 hours
- **Dependencies**: None
- **Research Inputs**: specs/393_unify_routing_field_language_task_type/reports/01_team-research.md
- **Artifacts**: plans/01_unify-routing-field.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Rename the `language` routing field to `task_type` throughout the agent system, simultaneously merging the old secondary `task_type` field into it. The unified `task_type` field uses a compound format (`{extension}:{subtype}`) for extension sub-routing and bare strings (`meta`, `general`, `neovim`) for core/simple values. This touches approximately 261+ files that reference `language` as a field name, plus 52 files that reference the old `task_type` field. The work is primarily mechanical renaming but requires careful handling of `meta` special-case checks, context discovery `load_when.languages` arrays, and documentation.

Definition of done: (1) the `language` field no longer exists in any active code path -- replaced by `task_type` everywhere, (2) the old secondary `task_type` field is merged into the new primary `task_type`, (3) compound values like `present:grant` and `founder:deck` work end-to-end through routing, context discovery, and validation, (4) backward compatibility shim handles legacy tasks that still have the old `language` field.

### Research Integration

Team research (4 teammates) confirmed routing mechanics, `meta` special-case risks, and context discovery dependencies. Research recommended keeping `language` as the field name, but the user explicitly overrides this: the unified field is named `task_type`. This increases scope from ~90 files to ~261+ files due to the rename.

### Prior Plan Reference

Revised from v1 plan which kept `language` as field name and deprecated old `task_type`. This v2 plan inverts the approach: `language` is deprecated and `task_type` becomes the unified field.

## Goals & Non-Goals

**Goals**:
- Rename the `language` field to `task_type` across all commands, skills, agents, state files, and documentation
- Merge the old secondary `task_type` values into the new primary `task_type` using compound format
- Values: bare strings for core types (`meta`, `general`, `markdown`, `neovim`, `lean4`, etc.) and compound `extension:subtype` for sub-routed extensions (`present:grant`, `founder:deck`, etc.)
- Add backward-compatible shim for legacy tasks that still have old `language` field
- Update context discovery (`load_when.languages` -> `load_when.task_types` or equivalent)
- Update all jq queries from `.language` to `.task_type`
- Update TODO.md format from `**Language**:` to `**Task Type**:` (or similar display label)
- Update all shell variable references from `$language` to `$task_type`

**Non-Goals**:
- Supporting hierarchical routing beyond one colon level (`present:grant:nih`)
- Making core types use compound values (`meta:something` -- never needed)
- Migrating archived tasks (archive is read-only, backward compat shim handles them)
- Changing the actual routing logic (manifest lookup, skill resolution stay the same)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `meta` special-case breaks from rename | H | M | Rename all `language == "meta"` to `task_type == "meta"` atomically; value stays `"meta"` |
| Context discovery fails during transition | H | M | Rename `load_when.languages` to `load_when.task_types` in index.json and all queries simultaneously |
| Massive scope causes partial breakage | H | M | Phase the rename by layer (state/schema first, then commands, then skills/agents, then docs); verify at each phase |
| Shell variable rename misses edge cases | M | M | Comprehensive grep audit after each phase; automated search for `$language` and `.language` |
| CLAUDE.md documentation references stale | M | H | Dedicated documentation phase with exhaustive grep |
| `validate-wiring.sh` rejects new field name | L | H | Update script early in Phase 1 |
| Mixed old/new field names during rollout | M | L | Backward compat shim reads both `language` and `task_type`, preferring `task_type` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Schema, State, and Core Infrastructure [COMPLETED]

**Goal**: Rename `language` to `task_type` in state.json schema, state.json data, TODO.md format, and core configuration files so all downstream phases have a consistent foundation.

**Tasks**:
- [ ] Update `state-management-schema.md`: rename `language` field to `task_type`, document compound format, mark old `language` as deprecated alias
- [ ] Update `state.json`: rename `"language"` key to `"task_type"` in all active_projects entries, merge any existing `task_type` values into compound format
- [ ] Update `TODO.md`: change `**Language**:` display label to `**Task Type**:` for all active tasks
- [ ] Update `CLAUDE.md` (root `.claude/CLAUDE.md`): rename all `language` references in routing tables, state.json examples, skill-to-agent mappings, context discovery queries
- [ ] Update `CLAUDE.md` Language-Based Routing section heading and content (rename to Task-Type-Based Routing or similar)
- [ ] Update `state-management.md` rule: rename language references
- [ ] Add backward compatibility shim documentation: if old `language` field is found without `task_type`, treat `language` value as `task_type`

**Timing**: 2.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/reference/state-management-schema.md`
- `specs/state.json`
- `specs/TODO.md`
- `.claude/CLAUDE.md`
- `CLAUDE.md` (root)
- `.claude/rules/state-management.md`

**Verification**:
- `grep -rn '"language"' specs/state.json` returns zero results
- `grep -n '**Language**' specs/TODO.md` returns zero results
- CLAUDE.md examples show `task_type` field throughout

---

### Phase 2: Core Commands and Routing [COMPLETED]

**Goal**: Update all core command files (`/task`, `/research`, `/plan`, `/implement`, `/revise`, etc.) to use `task_type` instead of `language` for routing decisions, jq queries, and shell variables.

**Tasks**:
- [ ] Update `/task` command (`task.md`): rename all `language` references to `task_type` in task creation, state.json writes, keyword detection; merge old `task_type` handling into new unified field; add present sub-type keywords (grant, budget, timeline, funds, talk)
- [ ] Update `/research` command (`research.md`): rename `$language` variable to `$task_type`, update jq queries from `.language` to `.task_type`, add backward compat shim (if task has old `language` field, read it as `task_type`)
- [ ] Update `/plan` command (`plan.md`): same rename pattern as research
- [ ] Update `/implement` command (`implement.md`): same rename pattern, preserve `meta` special-case checks using new field name
- [ ] Update `/revise` command (`revise.md`): rename language references
- [ ] Update `/review` command (`review.md`): rename language references
- [ ] Update `/todo` command (`todo.md`): rename language references, update TODO.md parsing for new `**Task Type**:` label
- [ ] Update `/meta` command (`meta.md`): rename language references
- [ ] Update `/errors` command (`errors.md`): rename language references
- [ ] Update `/fix-it` command (`fix-it.md`): rename language references
- [ ] Update `/spawn` command (`spawn.md`): rename language references
- [ ] Update `/task` subcommands (recover, expand, sync, abandon): rename language references
- [ ] Update `skill-orchestrator/SKILL.md`: rename routing logic from language to task_type

**Timing**: 3 hours

**Depends on**: 1

**Files to modify**:
- `.claude/commands/task.md`
- `.claude/commands/research.md`
- `.claude/commands/plan.md`
- `.claude/commands/implement.md`
- `.claude/commands/revise.md`
- `.claude/commands/review.md`
- `.claude/commands/todo.md`
- `.claude/commands/meta.md`
- `.claude/commands/errors.md`
- `.claude/commands/fix-it.md`
- `.claude/commands/spawn.md`
- `.claude/skills/skill-orchestrator/SKILL.md`

**Verification**:
- `grep -rn '\$language\b' .claude/commands/` returns zero results (excluding deprecated comments)
- `grep -rn '\.language' .claude/commands/` returns zero results (excluding deprecated comments)
- All jq queries use `.task_type` not `.language`

---

### Phase 3: Core Skills and Agents [COMPLETED]

**Goal**: Update all core skill and agent files to use `task_type` instead of `language` in delegation metadata, validation logic, and jq extraction.

**Tasks**:
- [ ] Update `skill-researcher/SKILL.md`: rename language to task_type in extraction, validation, delegation
- [ ] Update `skill-planner/SKILL.md`: same rename
- [ ] Update `skill-implementer/SKILL.md`: same rename, preserve `meta` check using `task_type == "meta"`
- [ ] Update `skill-meta/SKILL.md`: rename language references
- [ ] Update `skill-reviser/SKILL.md`: rename language references
- [ ] Update `skill-fix-it/SKILL.md`: rename language references
- [ ] Update `skill-spawn/SKILL.md`: rename language references
- [ ] Update `skill-status-sync/SKILL.md`: rename language references
- [ ] Update `skill-todo/SKILL.md`: rename language references
- [ ] Update `skill-git-workflow/SKILL.md`: rename language references
- [ ] Update `skill-team-research/SKILL.md`, `skill-team-plan/SKILL.md`, `skill-team-implement/SKILL.md`: rename language references
- [ ] Update `general-research-agent.md`: rename language to task_type in agent context
- [ ] Update `general-implementation-agent.md`: same rename
- [ ] Update `planner-agent.md`: same rename
- [ ] Update `meta-builder-agent.md`: same rename
- [ ] Update `code-reviewer-agent.md`: same rename
- [ ] Update `reviser-agent.md`: same rename
- [ ] Update `spawn-agent.md`: same rename

**Timing**: 2.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/skills/*/SKILL.md` (~13 skill files)
- `.claude/agents/*.md` (~7 agent files)

**Verification**:
- `grep -rn '\blanguage\b' .claude/skills/*/SKILL.md` returns only deprecated/compat references
- `grep -rn '\blanguage\b' .claude/agents/*.md` returns only deprecated/compat references
- `meta` special-case check in skill-implementer uses `task_type == "meta"`

---

### Phase 4: Extension Commands, Skills, and Agents [COMPLETED]

**Goal**: Update all extension files (founder, present, and all other extensions) to use `task_type` instead of `language` in commands, skills, agents, and manifests.

**Tasks**:
- [ ] Update 9 founder commands: change `language` field to `task_type` with compound values (e.g., `task_type: "founder:deck"`), remove old secondary `task_type` field
- [ ] Update 5 present commands: same pattern (e.g., `task_type: "present:grant"`)
- [ ] Update all other extension commands (neovim, lean4, latex, typst, python, nix, web, z3, epidemiology, formal): rename `language` to `task_type` (bare values like `task_type: "neovim"`)
- [ ] Update founder skills (~10 files): rename `language` validation to `task_type`, use compound values
- [ ] Update present skills (~5 files): same rename pattern
- [ ] Update all other extension skills: rename `language` to `task_type`
- [ ] Update founder agents (~8 files): rename `language` in delegation metadata
- [ ] Update present agents (~6 files): same rename
- [ ] Update all other extension agents: rename `language` to `task_type`
- [ ] Update all `manifest.json` files: rename `language` field to `task_type` in routing tables
- [ ] Update extension loader/merger if it references `language` field

**Timing**: 3 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/founder/commands/*.md` (9 files)
- `.claude/extensions/present/commands/*.md` (5 files)
- `.claude/extensions/*/commands/*.md` (remaining extensions)
- `.claude/extensions/*/skills/*/SKILL.md` (~30+ files)
- `.claude/extensions/*/agents/*.md` (~20+ files)
- `.claude/extensions/*/manifest.json` (14 files)

**Verification**:
- `grep -rn '"language"' .claude/extensions/*/manifest.json` returns zero results
- `grep -rn '\blanguage\b' .claude/extensions/*/commands/` returns only deprecated/compat references
- Extension routing resolves `task_type: "present:grant"` to correct skill

---

### Phase 5: Context Discovery, Index, and Rules [COMPLETED]

**Goal**: Update context discovery system (`load_when.languages` -> `load_when.task_types`), context index, and all rule files that reference the `language` field.

**Tasks**:
- [ ] Update `.claude/context/index.json`: rename all `load_when.languages` arrays to `load_when.task_types`
- [ ] Update all context discovery queries in commands/skills/agents: change `load_when.languages` to `load_when.task_types` in jq queries
- [ ] Update `.claude/context/patterns/context-discovery.md`: rename language references to task_type
- [ ] Update `.claude/context/architecture/context-layers.md`: rename language references
- [ ] Update `.claude/context/orchestration/routing.md`: rename language references
- [ ] Update `.claude/rules/artifact-formats.md`: rename language references
- [ ] Update `.claude/rules/workflows.md`: rename language references if any
- [ ] Update `.claude/context/formats/plan-format.md`: update Type field description
- [ ] Update `.claude/context/reference/artifact-templates.md`: rename language references
- [ ] Update `.claude/context/patterns/multi-task-operations.md`: rename language references
- [ ] Update `.claude/docs/reference/standards/` files: rename language references
- [ ] Add compound value support to `load_when.task_types` matching: for `task_type: "present:grant"`, match entries with `task_types: ["present"]` (prefix matching)

**Timing**: 2 hours

**Depends on**: 3, 4

**Files to modify**:
- `.claude/context/index.json`
- `.claude/context/patterns/context-discovery.md`
- `.claude/context/architecture/context-layers.md`
- `.claude/context/orchestration/routing.md`
- `.claude/context/formats/plan-format.md`
- `.claude/context/reference/artifact-templates.md`
- `.claude/context/patterns/multi-task-operations.md`
- `.claude/rules/artifact-formats.md`
- `.claude/rules/workflows.md`
- `.claude/docs/reference/standards/*.md`

**Verification**:
- `grep -rn 'load_when.languages' .claude/` returns zero results
- Context loads correctly for `task_type: "present:grant"` (prefix match on `present`)
- Context loads correctly for bare `task_type: "meta"` (exact match)

---

### Phase 6: Validation Scripts, Final Audit, and Cleanup [NOT STARTED]

**Goal**: Update validation scripts, perform exhaustive grep audit, verify end-to-end routing, and clean up any remaining `language` references.

**Tasks**:
- [ ] Update `validate-wiring.sh`: rename `language` validation to `task_type`, add compound key awareness
- [ ] Update `.claude/scripts/export-to-markdown.sh` if it references `language`
- [ ] Run exhaustive grep: `grep -rn '\blanguage\b' .claude/` -- every hit must be either (1) deprecated/compat reference, (2) English prose (e.g., "natural language"), or (3) this plan file
- [ ] Run exhaustive grep: `grep -rn 'load_when.languages' .claude/` -- must return zero
- [ ] Run exhaustive grep: `grep -rn '"language"' specs/state.json` -- must return zero
- [ ] Run `validate-wiring.sh` to confirm all routing passes
- [ ] Verify sample routing paths:
  - `task_type: "meta"` -> `skill-researcher` (bare value)
  - `task_type: "present:grant"` -> `skill-grant` (compound value)
  - `task_type: "neovim"` -> `skill-neovim-research` (extension bare value)
- [ ] Update `.claude/README.md` if it references `language` field
- [ ] Final review of all CLAUDE.md files for stale `language` references

**Timing**: 1 hour

**Depends on**: 5

**Files to modify**:
- `.claude/scripts/validate-wiring.sh`
- `.claude/scripts/export-to-markdown.sh` (if needed)
- `.claude/README.md` (if needed)
- Any remaining files identified by grep audit

**Verification**:
- `validate-wiring.sh` passes without errors
- `grep -rn '\blanguage\b' .claude/ specs/state.json specs/TODO.md` shows only English prose, deprecated comments, or plan/report files
- All three sample routing paths resolve correctly
- No active code path reads `language` without the backward compat shim

## Testing & Validation

- [ ] Backward compat shim correctly reads old `language` field as `task_type` for legacy tasks
- [ ] Core task type routing (`meta`, `general`, `markdown`) is unaffected by rename
- [ ] Extension routing resolves compound values (`founder:deck` -> `skill-deck-research`)
- [ ] Context discovery loads correct entries via `load_when.task_types` for both bare and compound values
- [ ] `meta` special-case checks in `skill-implementer` still correctly route using `task_type == "meta"`
- [ ] `/task` keyword detection produces compound `task_type` values for present sub-types
- [ ] `validate-wiring.sh` passes with new field name and compound key awareness
- [ ] TODO.md displays `**Task Type**:` label correctly
- [ ] state.json uses `task_type` field for all active projects
- [ ] No active jq query references `.language` (only `.task_type`)

## Artifacts & Outputs

- Updated state.json schema and data (language -> task_type rename)
- Updated TODO.md format (Language -> Task Type label)
- Updated all CLAUDE.md files with new field name and routing documentation
- Updated ~12 core commands with task_type routing and backward compat shim
- Updated ~13 core skills and ~7 core agents
- Updated ~14+ extension command files with compound task_type values
- Updated ~50+ extension skill/agent files
- Updated 14 extension manifests
- Updated context index (load_when.languages -> load_when.task_types)
- Updated validation scripts and remaining documentation

## Rollback/Contingency

The backward compatibility shim provides bidirectional support: tasks with old `language` field are read as `task_type` via the shim, and new-format tasks use `task_type` directly. If issues arise mid-migration:

1. **Partial rollback**: Revert to any phase boundary; the shim handles both field names
2. **Full rollback**: `git revert` the implementation commits; restore `language` field in state.json
3. **Forward fix**: Since all changes are mechanical text replacements (field rename), any individual file can be corrected independently
4. **Emergency**: If routing breaks, the base-key fallback in manifests still resolves bare values regardless of field name
