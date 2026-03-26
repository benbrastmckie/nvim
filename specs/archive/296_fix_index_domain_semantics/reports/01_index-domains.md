# Research Report: Task #296

**Task**: 296 - Update index.json domain field semantics for promoted files
**Generated**: 2026-03-25
**Source**: Post-refactor audit of tasks 286-292
**Status**: Researched

---

## Context Summary

**Purpose**: Correct domain field values in index.json for files promoted from project/ to core level
**Scope**: index.json entries for meta/, processes/, repo/ files
**Affected Components**: .claude/context/index.json
**Domain**: meta
**Language**: meta

## Findings

After task 287 promoted `project/meta/`, `project/processes/`, and `project/repo/` to be direct children of `.claude/context/`, their index.json entries still use `"domain": "core"`. The domain field should reflect semantic meaning.

### Current State

All 76 entries in `.claude/context/index.json` have `"domain": "core"`. However:

- `meta/` files (meta-guide.md, etc.) — these are meta/system-builder patterns
- `processes/` files (workflows) — these are cross-cutting process docs
- `repo/` files (project-overview, etc.) — these are repository-level info

### Proposed Domain Values

| Path Prefix | Current Domain | Proposed Domain | Rationale |
|-------------|---------------|-----------------|-----------|
| `orchestration/`, `formats/`, `patterns/`, etc. | core | core | Correct — agent system infrastructure |
| `meta/` | core | meta | System-builder patterns, distinct subdomain |
| `processes/` | core | core | Cross-cutting workflows, truly core |
| `repo/` | core | repo | Repository-level info, distinct from agent patterns |

Alternatively, a simpler approach: use the existing subdomain field to distinguish. The domain "core" is acceptable for all since they ARE part of the core agent system now. The subdomain field already provides finer granularity.

### Recommendation

Check whether the `subdomain` field is already set correctly for these entries. If so, the domain field is fine as "core" — these files ARE core after promotion. The issue may be cosmetic only.

## Implementation

1. Read index.json to check subdomain values for meta/, processes/, repo/ entries
2. If subdomain is already set (e.g., "meta", "processes", "repo"), no domain change needed
3. If subdomain is missing or wrong, update it
4. Consider whether any consumers (jq queries, agents) filter by domain — if so, ensure consistency

## Effort Assessment

- **Estimated Effort**: 30 minutes
- **Complexity**: Low — may turn out to be a no-op if subdomains are already correct

---

*Generated from post-refactor audit of tasks 286-292.*
