# Research Report: Task #393

**Task**: 393 - Unify routing field: replace separate language and task_type with single extension:task_type format
**Date**: 2026-04-10
**Mode**: Team Research (4 teammates)

## Summary

The `.claude/` agent system already partially supports a unified `extension:task_type` compound routing format -- manifest routing tables use compound keys (`founder:deck`, `present:grant`), and the routing code in `research.md`, `plan.md`, and `implement.md` already handles compound language values with fallback. The inconsistency is that task-creating commands store two separate fields (`language` + `task_type`) while routing only uses `language`. The `task_type` field is dead code from a routing perspective. Unification means: (1) commands store compound values directly in `language`, (2) `task_type` is deprecated, and (3) companion systems (context discovery, meta special-cases, validation) are updated. Only 2 of 14 extensions (founder, present) need sub-typed routing; the other 12 use flat language values unchanged.

## Key Findings

### Primary Approach (from Teammate A)

- **52 files reference `task_type`** across commands (14), skills (21), agents (14), and core system (4)
- Task-creating extension commands set `language="founder"` + `task_type="market"` but routing commands only look up `language` in manifest tables -- `task_type` is extracted but never used for routing
- The manifest routing tables already define compound keys (`"founder:market": "skill-market"`) and the `/task` keyword detection already produces some compound values (`founder:deck`)
- Migration scope: 14 extension commands, ~35 skill/agent files, 5 core files, plus documentation
- Recommended approach: keep `language` field name, store compound values, deprecate `task_type`
- Backwards compatibility: lazy migration (existing tasks keep working via base-key fallback)

### Alternative Approaches (from Teammate B)

- **Field naming**: Keep `language` (renaming to `routing`/`scope`/`domain` would touch 80+ files for no functional benefit)
- **Delimiter**: Colon `:` is definitively correct -- already established in manifests, jq-safe, shell-safe. Slash conflicts with paths, dot conflicts with jq path syntax
- **Core languages** (`general`, `meta`, `markdown`): remain as bare strings, no subtype needed
- **`task_type` is currently dead code for routing**: both `research.md` and `implement.md` extract it but never use it in manifest lookup
- **Present extension gap**: task 392 added compound routing keys to manifest but did NOT add present sub-type keywords to `/task` detection
- **Historical inconsistency**: archive has both `"language": "founder:deck"` (1 task) and `"language": "meta", "task_type": "deck"` (18 tasks) -- the format was never consistent

### Gaps and Shortcomings (from Critic)

- **261 files reference `language`, 52 reference `task_type`** -- total impact estimated at 60-80 files
- **CRITICAL: `meta` special-cases would break** -- 3 locations use `language == "meta"` for load-bearing behavior (ROAD_MAP.md vs `claudemd_suggestions` routing in `/todo`). If meta tasks gained compound values, these silently break
- **Task 392 direct conflict**: task 392 JUST standardized the two-field approach (`language: "present"` + `task_type: "grant"`) across 17-20 files. Task 393 would re-touch all of them
- **Context discovery is a hidden dependency**: `load_when.languages` arrays in index.json use exact string matching. Compound language values would cause context to silently fail to load
- **Scope ambiguity**: task description doesn't clarify whether core languages (`meta`, `general`) also get compound values or only extension tasks
- **Mixed-format migration risk**: if old-format and new-format tasks coexist during migration, `/todo` filters could mis-route

### Strategic Horizons (from Teammate D)

- Only 2 of 14 extensions need sub-routing; the change is targeted, not wholesale rearchitecture
- Project is in extension-building phase (5 new present commands in tasks 387-391); routing unification is a force multiplier
- Context index `load_when.languages` misalignment is a cross-cutting issue to address alongside
- Future-proofing: hierarchical routing (`present:grant:nih`) is possible with the format but should not be designed for now
- Recommended: deprecate `task_type`, update context index, standardize null-language extension pattern

## Synthesis

### Conflicts Resolved

1. **Scope of core languages** (A/B vs C disagreement):
   - A and B recommend core languages (`meta`, `general`, `neovim`) stay as bare strings
   - C flags this creates two patterns (bare vs compound) which is "MORE inconsistent, not less"
   - **Resolution**: Core languages STAY as bare strings. The system already has this split (12 extensions are bare, 2 have compounds). The compound format is additive for extensions with sub-routing. The key decision: `meta` tasks NEVER get subtypes. This preserves the 3 critical `== "meta"` checks.

2. **Task 392 overlap** (A minimizes, C escalates):
   - A treats task 392 overlap as routine (same files, different changes)
   - C quantifies it: 17-20 files re-touched, doing the "opposite" of what 392 just did
   - **Resolution**: The overlap is real but manageable. Task 392 established `task_type` as a separate field; task 393 collapses it back into `language`. The changes are mechanical (remove `task_type` field, make `language` compound). The alternative -- leaving two fields indefinitely -- is worse long-term.

3. **Migration approach** (A: lazy vs C: migration script):
   - A recommends lazy migration (leave existing tasks, they route via base-key fallback)
   - C recommends a one-time migration script to avoid mixed-format state
   - **Resolution**: Use BOTH. Add a compatibility shim in routing commands (if `task_type` exists and language is bare, construct compound key) for backward compat during transition. Then provide a migration script for state.json cleanup. Currently zero active founder/present tasks exist, so the script is low-risk.

### Gaps Identified

1. **Context discovery needs companion fix**: `load_when.languages` arrays use exact matching. Must update to support either compound values or prefix matching. This is NOT optional -- without it, context silently fails to load for tasks with compound language values.

2. **`/task` keyword detection missing present sub-types**: No keywords map to `present:grant`, `present:budget`, `present:talk`, etc. This gap predates task 393 but must be addressed.

3. **`validate-wiring.sh` needs update**: Script validates fixed language values only; needs compound key awareness.

4. **Archive state.json consistency**: Archive already contains mixed formats. Should be cleaned up but is low priority (archive is mostly read-only).

### Recommendations

1. **Keep `language` field name** -- unanimous across all teammates
2. **Use colon `:` delimiter** -- already established in manifests, jq-safe
3. **Core languages remain bare** -- `meta`, `general`, `markdown`, `neovim` etc. never get subtypes
4. **Extension commands store compound values directly** -- `language: "present:grant"` not `language: "present"` + `task_type: "grant"`
5. **Deprecate `task_type` field** -- keep in schema for backward compat, don't set for new tasks
6. **Add routing compatibility shim** -- in `research.md`/`plan.md`/`implement.md`: if `task_type` exists and language is bare, construct compound key
7. **Update context discovery** -- `load_when.languages` must support compound values or prefix matching
8. **Fix `/task` keyword detection** -- add present sub-type keywords, disambiguate `timeline`
9. **Update `meta` special-case checks** -- use `startsWith("meta")` or `cut -d: -f1` pattern (defensive, even though meta won't get subtypes)
10. **Provide state.json migration script** -- one-time jq to merge `language` + `task_type` for legacy tasks

### Estimated Scope

| Category | Files | Changes |
|----------|-------|---------|
| Extension commands (founder) | 9 | Remove task_type, make language compound |
| Extension commands (present) | 5 | Remove task_type, make language compound |
| Extension skills | ~23 | Update validation from task_type to compound language |
| Extension agents | ~19 | Update delegation metadata, validation |
| Core commands | 3-4 | Add compatibility shim, remove task_type extraction |
| Core documentation | 25-30 | Update examples, schema, guides |
| Context index | 2-3 | Update load_when.languages entries |
| Scripts | 1-2 | Update validate-wiring.sh |
| **Total** | **~90** | Mechanical changes, phased over 4-6 phases |

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary state audit & migration scope | completed | high |
| B | Naming, delimiters, edge cases, alternatives | completed | high |
| C | Breaking changes, risks, scope quantification | completed | high |
| D | Strategic horizons, future-proofing, cross-cutting | completed | high |

## References

- specs/393_unify_routing_field_language_task_type/reports/01_teammate-a-findings.md
- specs/393_unify_routing_field_language_task_type/reports/01_teammate-b-findings.md
- specs/393_unify_routing_field_language_task_type/reports/01_teammate-c-findings.md
- specs/393_unify_routing_field_language_task_type/reports/01_teammate-d-findings.md
