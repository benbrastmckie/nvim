# Teammate D Findings: Horizons Research (Round 2)
# Task 464: Enable Extension Loading in Global Source Repository

**Focus**: Long-term alignment and strategic direction - the "Core as Extension" vision

---

## Executive Summary

Round 1 correctly identified the minimal fix (strip-on-sync + guard relaxation) as the right
immediate answer. This Round 2 report takes that conclusion as settled and focuses entirely on
the longer horizon question: what does "core as extension" mean architecturally, is it the right
strategic direction, and how do we get there without disrupting the current system?

The core finding: **"core as extension" is the correct long-term direction, but the path there
runs through a concept the current system does not yet have -- a "virtual extension" or manifest-
only representation**. The creative insight in this analysis is that the physical reorganization
of files (moving all core agents into `.claude/extensions/core/`) is NOT required to achieve
the strategic benefits. A manifest-only description of what "core" provides, without any file
movement, unlocks versioning, marketplace metadata, profile composition, and dependency semantics
at near-zero migration cost.

---

## Part 1: The "Core as Extension" Vision -- End-to-End Architecture

### What Is the Bootstrap Layer?

If core becomes an extension, the system needs an irreducible minimum that exists before any
extension loads. That minimum is:

1. **The Lua extension infrastructure itself** (loader.lua, manifest.lua, state.lua, merge.lua,
   config.lua, picker.lua) -- these live in Neovim's plugin tree, not in `.claude/`, and have
   no dependency on loaded extensions.

2. **The extension picker command** (the Telescope entry point for loading/unloading extensions)
   -- also in Lua, not in `.claude/`.

3. **A minimal bootstrap manifest** that tells the loader where to find the "core" extension
   source. This could be a single JSON file at `.claude/bootstrap.json`:
   ```json
   {
     "core_extension": "~/.config/nvim/.claude/extensions/core",
     "auto_load": ["core"]
   }
   ```

The key insight: this bootstrap is tiny and stable. It does not need to change when core evolves.
Everything else -- agents, skills, rules, commands, context -- becomes extension-provided.

### What Is the "Core" Extension?

The core extension would declare everything currently in `.claude/` (minus `extensions/` itself):

```json
{
  "name": "core",
  "version": "2.0.0",
  "description": "Core agent system: task management, research, planning, implementation",
  "dependencies": [],
  "provides": {
    "agents": [
      "general-research-agent.md",
      "general-implementation-agent.md",
      "planner-agent.md",
      "meta-builder-agent.md",
      "code-reviewer-agent.md",
      "reviser-agent.md",
      "spawn-agent.md"
    ],
    "skills": [
      "skill-researcher",
      "skill-implementer",
      "skill-planner",
      "skill-orchestrator",
      "skill-git-workflow",
      "skill-todo",
      "skill-status-sync",
      "skill-refresh",
      "skill-fix-it",
      "skill-meta",
      "skill-reviser",
      "skill-spawn",
      "skill-tag",
      "skill-team-research",
      "skill-team-plan",
      "skill-team-implement"
    ],
    "commands": [
      "task.md", "research.md", "plan.md", "implement.md",
      "review.md", "todo.md", "meta.md", "errors.md",
      "fix-it.md", "refresh.md", "tag.md", "spawn.md", "merge.md", "revise.md"
    ],
    "rules": [
      "state-management.md", "git-workflow.md", "error-handling.md",
      "artifact-formats.md", "workflows.md", "plan-format-enforcement.md"
    ],
    "context": ["guides", "patterns", "reference", "formats", "architecture", "meta", "repo"]
  },
  "routing": {
    "research": {
      "general": "skill-researcher",
      "meta": "skill-researcher",
      "markdown": "skill-researcher"
    },
    "implement": {
      "general": "skill-implementer",
      "meta": "skill-implementer",
      "markdown": "skill-implementer"
    }
  }
}
```

This manifest is a description of what already exists. No files move.

### How Does the Telescope Picker Change?

In the current system, the extension picker shows only domain extensions (nvim, lean, python,
etc.). In the core-as-extension world:

**Option A -- Core is always auto-loaded (invisible to picker)**: The bootstrap auto-loads core
before the picker is ever shown. The picker continues to show only domain extensions. "Load Core
Agent System" in the sync picker becomes "Sync Core Extension" which reads the core manifest to
know what to sync. Users never select/deselect core -- it is the base.

**Option B -- Core appears in picker as unremovable**: The picker shows core with a lock icon,
indicating it cannot be unloaded. All other extensions show their dependency on core. This is
more transparent but adds UI complexity for minimal benefit.

**Recommendation**: Option A. Core is conceptually different from domain extensions -- it is not
optional. The picker showing it as an entry would confuse users who expect to toggle it. Auto-
load at bootstrap is correct.

### How Does "Load Core Agent System" Change?

The most important transformation is in the sync workflow. Currently "Load Core Agent System"
scans `.claude/` in the source repo, applies a blocklist to filter out extension-provided files,
and copies the remainder. With core-as-extension:

1. The sync reads `.claude/extensions/core/manifest.json` from the source repo
2. Uses `provides` fields to enumerate what core delivers
3. Copies exactly those files to target repos

This is **more precise than the current blocklist approach**. Instead of "everything in .claude/
minus what extensions provide," it becomes "exactly what the core manifest says." This eliminates
the gap where docs/, lib/, tests/, templates/ receive no blocklist filtering (Teammate C's
finding) -- they simply are not in core's `provides`.

**Strategic insight**: The current blocklist is an exclusion filter (deny-list). Core manifest
becomes an inclusion filter (allow-list). Inclusion filters are always safer than exclusion
filters because they fail closed (unknown files are not synced) rather than open (unknown files
are synced unless explicitly excluded).

---

## Part 2: Dependency Graph Design

### Proposed Dependency Hierarchy

```
core              (no deps -- the root)
  ├── memory      (core -> memory: task completion, auto-retrieval)
  ├── nvim        (core -> nvim: neovim-specific patterns)
  ├── python      (core -> python: Python agent workflows)
  ├── lean        (core -> lean: Lean prover agent workflows)
  ├── lean4       (core -> lean: symlinked alias)
  ├── latex       (core -> latex: LaTeX document workflows)
  ├── typst       (core -> typst: Typst document workflows)
  ├── z3          (core -> z3: SMT solver workflows)
  ├── formal      (core -> formal: formal verification)
  ├── nix         (core -> nix: Nix configuration workflows)
  ├── web         (core -> web: web development workflows)
  ├── slidev      (core -> slidev: presentation framework resources)
  │   ├── present (slidev -> present: Slidev-based presentations)
  │   └── founder (slidev -> founder: founder presentation workflows)
  └── epi         (core -> epi: epidemiology workflows)
      └── filetypes (epi -> filetypes: domain-specific filetype support)
```

And the special memory interaction:
```
memory            (core)
lean              (core + memory for learned proof patterns)
```

### Should All Extensions Implicitly Depend on Core?

**Yes, but with explicit declaration preferred.** The reasoning:

- **Implicit dependency** (all extensions auto-depend on core): Simpler for extension authors,
  but makes the dependency invisible. Extension authors may not realize what "core" provides and
  accidentally duplicate it.

- **Explicit declaration** (each extension lists `"core"` in dependencies): Visible, auditable,
  and consistent with how other dependencies work. The loader already supports this. The cost
  is adding `"core"` to every extension manifest's `dependencies` array -- one line per
  extension, 14 extensions = 14 lines of change.

**Recommendation**: Require explicit declaration (`"core"` in `dependencies`) for all domain
extensions. This makes the dependency graph legible and maintains consistency with how
`slidev -> founder` works today. It also enables a future where "core-lite" is an option
(partial core load for lightweight workflows).

### Dependency Depth in Practice

Current maximum depth across all 14 extensions: 2 (slidev -> founder). With core added as root:
maximum depth becomes 3 (core -> slidev -> founder). The existing depth limit of 5 has plenty
of headroom.

The theoretical maximum depth for real-world use cases is approximately 4:
`core -> memory -> domain -> domain-variant` (e.g., `core -> memory -> lean -> lean4-advanced`).
The depth limit of 5 is appropriate.

### Optional vs. Required Dependencies

The current system treats all dependencies as required (dependency load failure blocks parent
extension load). This is correct for hard dependencies (lean genuinely needs memory for its
learned-pattern context). But some useful composition patterns involve soft dependencies:

**Example**: An `epi` extension might use memory for learned domain knowledge IF memory is loaded,
but can function without it. Currently the only way to express this is to either declare a hard
dependency (always loads memory) or declare no dependency (never benefits from memory integration).

**Proposal**: Add an `optional_dependencies` array to manifest.json:
```json
{
  "dependencies": ["core"],
  "optional_dependencies": ["memory"]
}
```

Optional dependencies are loaded if already present but not auto-loaded if absent. This enables
richer composition without forcing users to install everything. This is a medium-term enhancement,
not required for the immediate fix.

### Should the Picker Show the Dependency Graph?

The picker already shows basic dependency information. With core-as-extension, enhance it to show
the full transitive chain:

```
[ ] lean - Lean theorem prover support
    Requires: core (loaded), memory (not loaded - will auto-load)
    Enables: lean4 (alias)
```

This level of transparency is achievable with modest UI changes and is a natural enhancement
once the dependency graph is formal.

---

## Part 3: What Core-as-Extension Enables

### Extension Versioning and Compatibility

**Today**: No versioning. If core changes, all extensions break silently because there is no
compatibility contract.

**With core-as-extension**: Each extension can declare `"core_min_version": "2.0.0"` in its
manifest. The loader checks compatibility before loading. Extension authors know which core APIs
they depend on. Breaking core changes can be versioned and communicated.

This is the single most important strategic benefit of core-as-extension. Versioning without
file movement is achievable today (just add a version field to CLAUDE.md), but semantic
dependency constraints require the manifest system.

### Extension Marketplace / Registry

**Today**: Extensions are discovered by scanning `.claude/extensions/*/manifest.json`. There is
no central catalog, no ratings, no search.

**With core-as-extension**: A marketplace catalog becomes:
```json
{
  "extensions": [
    {
      "name": "lean",
      "version": "1.2.0",
      "requires": {"core": ">=2.0.0", "memory": ">=1.0.0"},
      "tags": ["theorem-proving", "formal-verification"],
      "author": "neotex-team"
    }
  ]
}
```

This is the `marketplace.json` that ROADMAP Phase 1 already calls for. Core-as-extension
provides the semantic foundation that makes marketplace constraints meaningful.

### Profiles (Sets of Extensions for Different Workflows)

**Profiles** are the highest-leverage capability unlocked by formal dependency management:

```json
{
  "name": "formal-verification-profile",
  "extensions": ["core", "memory", "lean", "z3", "formal"],
  "description": "Complete formal verification workflow"
}
```

A user working on a new project could select a profile from the picker, which auto-loads all
constituent extensions in dependency order. Profiles are composable and reusable across repos.

This pattern requires the manifest dependency system (to know load order) but not necessarily
physical reorganization of core files.

### Partial Core (Loading Only Research Workflow)

With core as a single monolithic extension, partial core is not possible. But if core is further
decomposed into sub-extensions:

```
core-base       (state management, git workflow, error handling)
  ├── core-research   (skill-researcher, general-research-agent)
  ├── core-planning   (skill-planner, planner-agent)
  └── core-implement  (skill-implementer, general-implementation-agent)
```

This enables a "researcher-only" profile that loads `core-base + core-research` without pulling
in the full planning and implementation machinery. **This is future-looking and not required now**,
but designing core's manifest to be decomposable (using fine-grained `provides` sections) makes
this possible later.

### Core Customization (Override Core Agents with Custom Versions)

The current conflict-detection system (loader checks if target files exist before copying) prevents
overriding core agents with custom versions. With core-as-extension:

- Core loads first (files copied to `.claude/`)
- A "custom-core" extension loads second, with `force=true` for specific files, replacing the
  core version with a customized one

This enables organizations to maintain their own versions of core agents that extend or override
the defaults -- the foundation of a true extension ecosystem. This requires a "file replacement"
loading mode that does not currently exist, but the manifest infrastructure supports expressing it.

### Extension Testing in CI

With extensions loadable in the source repo (the immediate fix), CI can:

1. Load the nvim extension
2. Run `check-extension-docs.sh`
3. Verify the load/unload cycle leaves no artifacts
4. Unload the extension
5. Verify clean state

This testing pattern is blocked by the current guard and is enabled by both the immediate fix
(relaxing the guard) and the long-term vision (formal manifest allows CI to declare test profiles).

---

## Part 4: Migration Path

### Phase 0 (Immediate, This Task): Minimal Fix

1. Add `strip_extension_sections()` to sync.lua (strip CLAUDE.md extension sections on sync-out)
2. Relax self-loading guard to notification rather than error
3. Extend `update_artifact_from_global()` to apply manifest blocklist

**Effort**: 2-3 days. **Risk**: Low. **Value**: Immediate (source repo can load extensions).

No architectural changes. No manifest changes. Pure sync-layer and guard changes.

### Phase 1 (Weeks): Virtual Core Manifest

Add `.claude/extensions/core/manifest.json` that **describes** what core provides without moving
any files. The loader and sync gain the ability to read this manifest, but it is initially
informational only. No behavior changes until Phase 2.

This is the lowest-friction way to introduce core-as-extension thinking. The manifest can be
authored by reading the current directory structure (it is essentially a description of what
already exists). Review and iterate on the `provides` fields to ensure they are accurate.

**Effort**: 1-2 days (authoring the manifest). **Risk**: Zero (informational only). **Value**:
Establishes the conceptual model; unblocks marketplace metadata work.

### Phase 2 (Months): Sync Reads Core Manifest

Modify the sync system to use core's manifest `provides` as the inclusion filter for "Load Core
Agent System," replacing the current exclusion-based blocklist approach.

This changes the sync from "everything minus extensions" to "exactly what core declares." The
manifest from Phase 1 must be accurate before this phase begins -- a discrepancy would cause
files to be left out of sync.

**Validation gate**: Run both approaches in parallel (old blocklist + new manifest-based) and
compare output. Differences indicate manifest gaps. Iterate until outputs match, then switch.

**Effort**: 1-2 weeks (sync modification + validation). **Risk**: Medium (sync is critical path).
**Value**: Closes all unprotected category gaps (docs, lib, tests, templates) without explicit
exclusion lists.

### Phase 3 (Months): Domain Extensions Declare Core Dependency

Add `"core"` to `dependencies` in all 14 extension manifests. This is mechanical and low-risk.
The loader already handles dependency resolution; no loader changes needed.

**Effort**: 1 day. **Risk**: Low (additive manifest change). **Value**: Formal dependency graph;
enables versioning constraints.

### Phase 4 (Quarters): Version Constraints and Marketplace

Add `core_min_version` fields to extension manifests. Add version checking to the loader.
Publish the first version of `marketplace.json`. This is the ROADMAP Phase 1 marketplace
metadata work, now with semantic foundation.

**Effort**: 2-4 weeks. **Risk**: Low-medium. **Value**: Extension ecosystem becomes composable
and versioned.

### Backwards Compatibility Throughout

At every phase:
- All domain extensions continue to load and unload as before
- The sync system continues to work for existing consumer repos
- The picker UI changes are additive (new information shown, not information removed)
- No changes to how Claude Code discovers `.claude/` content

The migration is designed so that each phase is independently valuable and reversible.

---

## Part 5: Creative Alternatives

### Alternative A: Virtual Core Manifest (No File Movement)

This is the central strategic recommendation of this report. Instead of physically reorganizing
core into `.claude/extensions/core/`, create a manifest that **describes** the existing layout:

```json
{
  "name": "core",
  "virtual": true,
  "version": "2.0.0",
  "provides": {
    "agents": ["general-research-agent.md", ...],
    "skills": ["skill-researcher", ...],
    "commands": ["task.md", "research.md", ...]
  }
}
```

The `"virtual": true` flag signals to the loader: "do not attempt to copy files from this
extension's directory -- they are already in `.claude/` by definition." The manifest is used
for:

- Sync: determines what gets included in "Load Core Agent System" (allow-list approach)
- Versioning: consumers can check core version compatibility
- Marketplace: core appears in catalogs with its own version history
- Dependency resolution: domain extensions declare `"dependencies": ["core"]`

**This achieves all the strategic benefits without any file reorganization.** It is the minimum
viable core-as-extension.

### Alternative B: Manifest-Driven Sync (Replaces Blocklist Approach)

The current sync system reads the source repo's `.claude/` directory and applies an exclusion
blocklist (built from all extension manifests). The manifest-driven alternative:

1. Read core manifest `provides` fields
2. For each category (agents, skills, commands, etc.), sync only the files listed in `provides`
3. Everything not in `provides` is implicitly excluded

This turns sync from a "scan and filter" operation into a "enumerate and copy" operation. The
implementation is simpler (no blocklist building, no set operations) and safer (unknown files
are never synced). The `update_artifact_from_global()` bypass issue (Teammate C's finding) is
automatically resolved -- individual file updates only work for files in core's `provides`.

**Implementation path**: The core manifest (Alternative A) is the prerequisite. Once the
manifest exists and is accurate, manifest-driven sync is a sync.lua refactor.

### Alternative C: Sync Reads Core Manifest Directly (Without Virtual Flag)

Rather than a special `"virtual": true` flag, the sync system could simply look for a manifest
at `.claude/extensions/core/manifest.json` when deciding what to sync. If it exists, use it as
the inclusion list. If it doesn't exist, fall back to the current blocklist approach.

This is more pragmatic than Alternative A but achieves the same effect. The `"virtual"` concept
is an implementation detail -- the manifest is just a file that happens to describe what's
already in `.claude/`.

### Alternative D: CLAUDE.md as the Core Manifest (No New File)

The most radical simplification: CLAUDE.md already contains a complete description of what the
core system provides (commands, agents, skills, routing tables). A parser that reads CLAUDE.md
and extracts this information could serve as the "core manifest" without requiring a separate
JSON file.

**Pros**: No new file format; CLAUDE.md is already maintained; humans naturally update it.
**Cons**: CLAUDE.md is human-authored narrative, not machine-readable specification; parsing is
brittle; CLAUDE.md sections can drift from actual file contents.

**Assessment**: Clever but fragile. The manifest approach (Alternative A) is more reliable because
it is explicitly machine-authored for machine consumption.

---

## Key Findings

### Finding 1: Physical Reorganization Is Not Required

The core insight of this round is that the strategic benefits of "core as extension" (versioning,
marketplace, dependency graphs, profiles) do not require physically moving files into
`.claude/extensions/core/`. A virtual manifest that **describes** the existing layout achieves
all the same semantic benefits. This eliminates the 6-12 month migration cost estimated in Round 1.

### Finding 2: Sync Allow-List Is Safer Than Blocklist

The current sync uses an exclusion blocklist (Teammate C found unprotected categories: docs, lib,
tests, templates). A manifest-driven inclusion allow-list is inherently safer: unknown files are
not synced. The core manifest provides the allow-list. This solves the unprotected category
problem as a byproduct.

### Finding 3: The Dependency Graph Is Already Mostly Correct

The current extensions already use the `dependencies` array correctly (slidev -> founder,
slidev -> present, lean -> memory). The only missing edge is "all domain extensions depend on
core." Adding `"core"` to each extension's dependencies array is the formalization of what is
already architecturally true. This is a 14-line change across 14 manifests.

### Finding 4: Profile Composition Is the Highest-Leverage Long-Term Feature

Among all the capabilities unlocked by core-as-extension, **profiles** (declarative sets of
extensions) provide the most user-visible value. A user starting a new repo today must manually
select and load extensions. Profiles would let them say "I'm doing formal verification work"
and get the right setup automatically. This capability is blocked until the dependency graph is
formal -- which the virtual manifest approach enables.

### Finding 5: Backwards Compatibility Is Achievable at Every Step

The migration path is designed so that each phase is independently deployable and reversible.
No phase requires coordinated changes across the loader, sync, picker, and extension manifests
simultaneously. This contrasts with the "full core-as-extension restructuring" approach evaluated
in Round 1, which would require all subsystems to change together.

---

## Strategic Recommendations

### Immediate (This Task)
Implement the Phase 0 minimal fix as identified in Round 1:
- `strip_extension_sections()` in sync.lua
- Relax self-loading guard to notification
- Extend `update_artifact_from_global()` with blocklist

### Near-Term (Next 1-3 Tasks)
After Phase 0 is stable, add the virtual core manifest (Phase 1):
- Author `.claude/extensions/core/manifest.json` with `"virtual": true`
- This file is purely descriptive and changes no behavior
- Review and ensure `provides` fields accurately reflect what core delivers

### Medium-Term (Roadmap Alignment)
When implementing marketplace metadata (ROADMAP Phase 1):
- Switch sync to manifest-driven allow-list (Phase 2 above)
- Add `"core"` dependency to all extension manifests (Phase 3 above)
- Publish `marketplace.json` using the now-formal dependency graph

### Long-Term (6-12 Months)
When implementing extension hot-reload (ROADMAP Phase 2):
- Add version constraints to extension manifests
- Design profile composition system
- Consider optional dependency support for soft integrations (e.g., epi + memory)

---

## Confidence Level: High

The virtual manifest approach is grounded in the observation that manifests are already the
authoritative description mechanism for extensions in this system. Extending the concept to
core (with a `"virtual"` flag to indicate no file copying) is a minimal, consistent extension
of an existing pattern. The sync allow-list analysis is based on direct reading of
`sync.lua:scan_all_artifacts()` and the confirmed gap in Teammate C's findings. Confidence in
the migration path is high because each phase is independently testable and reversible.

The profile composition and partial core decomposition sections are more speculative
(medium confidence) but logically consistent with the manifest dependency architecture.

---

## Files Referenced

- `/home/benjamin/.config/nvim/specs/464_enable_extensions_in_source_repo/reports/01_team-research.md`
  -- Round 1 synthesis; confirmed minimal fix approach and identified core-as-extension gaps
- `/home/benjamin/.config/nvim/specs/464_enable_extensions_in_source_repo/reports/01_teammate-b-findings.md`
  -- Alternative architectures; blocklist vs. state-aware exclusion analysis
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua`
  -- Self-loading guard (lines 212-229); dependency resolution; force flag pattern
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  -- `preserve_sections()`/`restore_sections()` infrastructure; CONFIG_MARKDOWN_FILES handling
- `/home/benjamin/.config/nvim/.claude/docs/architecture/extension-system.md`
  -- Extension lifecycle; manifest format; index entry lifecycle
- `/home/benjamin/.config/nvim/.claude/context/guides/extension-development.md`
  -- Dependency declaration; auto-loading behavior; resource-only extension pattern
- `/home/benjamin/.config/nvim/specs/ROADMAP.md`
  -- Marketplace metadata (Phase 1); extension hot-reload (Phase 2)
