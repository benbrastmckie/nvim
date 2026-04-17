# Research Report: Task #464 (Round 2)

**Task**: Enable extension loading in global source repository without sync leakage
**Date**: 2026-04-16
**Mode**: Team Research (4 teammates)
**Focus**: Core-as-extension architecture with dependency management

## Summary

Round 2 investigated the user's preferred approach: restructuring the core agent system as a base-level extension that all other extensions depend on. The team converged on a **virtual core manifest** approach — creating a manifest that *describes* the existing core files without moving them. This avoids the bootstrap problem and migration cost while unlocking versioning, dependency semantics, and a safer allow-list-based sync. The Round 1 sync fixes (strip-on-sync, guard relaxation) remain prerequisites and are orthogonal to this architectural work.

## Key Findings

### 1. A Literal "Core as Extension" Has Fundamental Contradictions

Teammate C identified three architectural impossibilities with physically moving core into `extensions/core/`:

- **Bootstrap impossibility**: The Lua extension loader runs before any extension loads. It cannot load itself. There is no "pre-loader" to bootstrap core.
- **State circularity**: `extensions.json` (which tracks loaded extensions) lives in `.claude/` — the directory core would "provide." You cannot record core's installation in a file core is supposed to create.
- **Sync has no extension-source concept**: sync.lua reads from installed locations (`.claude/agents/`), not from extension source directories. Moving core to `extensions/core/` would require rewriting all 15 artifact type scans.

A literal restructuring would affect 175+ files and require parallel changes to the OpenCode system.

### 2. The Virtual Core Manifest Eliminates Migration Cost

Teammates A and D independently converged on the same insight: create `extensions/core/manifest.json` that **describes** the existing layout without moving any files.

Teammate A's "skinny core" variant uses **empty `provides`** — core exists purely as a dependency anchor. Teammate D's variant uses **populated `provides`** with a `"virtual": true` flag — enabling manifest-driven sync (allow-list).

The key properties of both:
- No files move from their current locations
- No bootstrap problem (the manifest is just data; the Lua loader reads it like any other)
- No state circularity (core "loading" just records state, doesn't copy files)
- The existing dependency resolution (`_loading_stack`, circular detection, `max_depth=5`) works unchanged

### 3. No Production System Treats Core as an Equal Extension

Teammate B surveyed VS Code, lazy.nvim, Gradle, OSGi, Backstage, webpack, Emacs, npm, and Terraform. The universal pattern: **core is implicit or special-cased, never a user-managed extension**. The closest precedent is OSGi's `org.eclipse.core.runtime` — technically a "bundle" but auto-resolved before any user bundles load.

The npm `peerDependencies` pattern maps precisely to this situation: core is "host-provided" via sync, and extensions declare a peer dependency on it without bundling it themselves.

### 4. The Dependency System Is Fully Implemented but Unused

All 16 extensions currently have `"dependencies": []`. The infrastructure — recursive resolution, `_loading_stack` circular detection, `max_depth=5` limit, re-read-state for diamond dependencies — is complete and works. Adding `"core"` to dependency arrays requires zero code changes to the dependency logic.

### 5. Allow-List Sync Is Safer Than Blocklist

The current sync uses a blocklist (exclude extension files). Teammate C found that docs, lib, tests, templates, and systemd categories have no blocklist coverage. A manifest-driven **allow-list** (sync only what core's `provides` declares) is inherently safer — unknown files are never synced. The virtual core manifest makes this possible.

### 6. The Round 1 Sync Fixes Remain Prerequisites

All teammates agree: the core-as-extension architecture does **not** solve the sync leakage problems identified in Round 1:
- CLAUDE.md section injection still leaks (needs `strip_extension_sections()`)
- `settings.local.json` is a confirmed real leak — lean, nix, and epi extensions merge MCP configs into it
- `update_artifact_from_global()` still bypasses the blocklist

These fixes are orthogonal and must be implemented regardless of architectural approach.

## Synthesis

### Conflicts Resolved

| Conflict | Teammate A | Teammate C | Resolution |
|---|---|---|---|
| Core as extension feasibility | Skinny manifest with empty `provides` | Bootstrap impossibility, 175+ file migration | **No conflict** — A's approach doesn't move files or require bootstrapping. C's critique applies to literal restructuring, not the virtual manifest. |
| Implicit vs explicit core dep | Both work, no code changes needed | N/A | **Auto-load recommended** (B's finding from Gradle/webpack) with explicit `"dependencies": ["core"]` as optional best practice (D's recommendation for auditability). |
| Scope of work | ~60 lines + 3 files | ~30-40 lines (minimal fix only) | **Both are needed**: Phase 0 = sync fixes (30-40 lines), Phase 1 = virtual manifest (3 files + 14 one-line manifest updates). |

### Gaps Identified

1. **No version pinning mechanism** — extensions cannot declare `"core_min_version"`. Breaking core changes would silently break extensions. (Future work, not blocking.)
2. **No optional dependencies** — all deps are hard (fail to load if missing). Soft/optional deps would enable richer composition. (Future work.)
3. **OpenCode parallel system** needs its own core manifest if this approach is adopted. (Can be deferred since both systems share the parameterized config.)

### Recommended Architecture

**Two-track approach:**

**Track 1: Immediate Sync Fix (Phase 0)** — solves the user's actual problem:
1. `strip_extension_sections()` in sync.lua — strip `<!-- SECTION: extension_* -->` blocks from source CLAUDE.md before sync
2. Strip extension-merged keys from `settings.local.json` before sync
3. Relax self-loading guard to notification
4. Extend `update_artifact_from_global()` with manifest blocklist

**Track 2: Virtual Core Manifest (Phase 1-3)** — establishes the architectural vision:

**Phase 1**: Create `extensions/core/manifest.json`:
```json
{
  "name": "core",
  "version": "1.0.0",
  "virtual": true,
  "description": "Core agent system: task management, research, planning, implementation",
  "dependencies": [],
  "provides": {
    "agents": ["general-research-agent.md", "planner-agent.md", ...],
    "skills": ["skill-researcher", "skill-implementer", ...],
    "commands": ["task.md", "research.md", ...],
    "rules": ["state-management.md", "git-workflow.md", ...],
    "context": ["guides", "patterns", "reference", "formats", ...]
  }
}
```
The `"virtual": true` flag signals: do not copy files — they are already in `.claude/` by definition.

**Phase 2**: Switch sync from blocklist to manifest-driven allow-list. Sync reads core's `provides` to know exactly what to copy. This closes the unprotected category gaps automatically.

**Phase 3**: Add `"dependencies": ["core"]` to all 14 extension manifests. Auto-load core when any extension loads (implicit, like Gradle). This formalizes the dependency graph.

**Phase 4** (future): Version constraints, profile composition, optional dependencies.

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Physical file reorganization | No | Virtual manifest achieves same benefits without migration |
| Core loading semantics | Auto-load (implicit) | Matches Gradle/webpack pattern; avoids 14 manifest changes initially |
| Sync approach (long-term) | Allow-list from manifest | Safer than blocklist; closes unprotected category gaps |
| Core in picker | Hidden (auto-loaded) | Core is not optional; showing it in picker confuses users |
| `"virtual": true` flag | Yes | Clean signal to loader: skip file copy step |

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Current architecture + design | completed | high | Complete load/unload flow documentation; skinny core manifest with empty provides |
| B | External patterns + prior art | completed | high | No system treats core as equal extension; npm peer deps validates approach |
| C | Critical evaluation | completed | high | Bootstrap impossibility; settings.local.json leak confirmed; 175+ file migration scope |
| D | Strategic vision | completed | high | Virtual manifest eliminates migration; allow-list safer than blocklist; phased migration path |

## References

### External Patterns
- VS Code `extensionDependencies` — explicit named dependencies
- lazy.nvim `dependencies` — recursive DFS loading with depth limits
- npm `peerDependencies` — host-provided shared dependencies
- OSGi `Require-Bundle` — core bundle auto-resolved before user bundles
- Gradle core plugins — implicit, short-name resolution

### Code Paths
- `init.lua:206-484` — `manager.load()` complete flow
- `init.lua:268-296` — dependency resolution with `_loading_stack`
- `manifest.lua:233-261` — `aggregate_extension_artifacts()` blocklist builder
- `sync.lua:258-269` — CLAUDE.md section leak path
- `sync.lua:693-712` — `scan_all_artifacts()` root_files
- `state.lua:70` — extensions.json path (inside `.claude/`)

### Teammate Reports
- `specs/464_enable_extensions_in_source_repo/reports/02_teammate-a-findings.md`
- `specs/464_enable_extensions_in_source_repo/reports/02_teammate-b-findings.md`
- `specs/464_enable_extensions_in_source_repo/reports/02_teammate-c-findings.md`
- `specs/464_enable_extensions_in_source_repo/reports/02_teammate-d-findings.md`
