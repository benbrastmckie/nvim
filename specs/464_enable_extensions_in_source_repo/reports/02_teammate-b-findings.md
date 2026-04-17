# Teammate B Findings: External Patterns and Prior Art
## Task 464 - Round 2 Research

**Focus**: Best practices for extension/plugin systems with dependency management, especially "core as extension" patterns, from external systems.

**Date**: 2026-04-16

---

## Key Findings

### Finding 1: "Core is Always Special" - The Universal Pattern

Across every major plugin/extension ecosystem surveyed, the unanimous design is: **core is implicit, not an extension**. Core is loaded unconditionally before any plugin/extension system activates. No production system treats core as a plugin that other plugins declare dependencies on.

| System | Core Treatment | Extension Dependency Mechanism |
|--------|---------------|-------------------------------|
| VS Code | Built-in APIs, always available | `extensionDependencies` in package.json (explicit IDs) |
| lazy.nvim | Neovim runtime, implicit | `dependencies` array (load before, recursively) |
| Gradle | Core plugins ship with Gradle | Short-name for core, full-ID for community |
| OSGi/Eclipse | `org.eclipse.core.runtime` bundle, required | `Require-Bundle` header in MANIFEST.MF |
| Backstage | Core services via DI container, always registered | `deps` argument in plugin init (interface, not name) |
| webpack | Internal compiler hooks, always present | `tapable` event system, no plugin-to-plugin deps |
| Emacs | `require`/`provide` feature system | Package-Requires header in .el files |
| npm | Standard library (Node core modules) | `peerDependencies` for host-level shared deps |
| Terraform | Core engine, separate from providers | `required_providers` version constraints |

The closest to "core as extension" is OSGi, where `org.eclipse.core.runtime` is technically a bundle - but it is auto-resolved and auto-started before any user bundles. It functions as a virtual "always provided" capability, not a user-managed dependency.

**Implication for Task 464**: The proposed "core" extension with empty `provides` and declarative-only semantics is consistent with how OSGi models it - it exists in the dependency graph as a name, but its actual artifacts are pre-loaded. This is a well-precedented pattern.

---

### Finding 2: Two Canonical Models for Dependency Declaration

#### Model A: Explicit Named Dependencies (VS Code, lazy.nvim, OSGi, Emacs packages)

Extensions name their dependencies explicitly. The loader resolves and loads them first, recursively.

```json
// VS Code package.json
{
  "extensionDependencies": ["ms-python.python", "ms-toolsai.jupyter"]
}
```

```lua
-- lazy.nvim plugin spec
{ "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } }
```

```
# OSGi MANIFEST.MF
Require-Bundle: org.eclipse.core.runtime;bundle-version="3.17.0"
```

**Characteristics:**
- Dependencies are strong (missing dep = fail to activate)
- Load order is guaranteed by recursive resolution before parent activates
- Cycle detection is mandatory (all systems implement it)
- Depth limits are common (lazy.nvim uses 5, OSGi has no limit but cycle detection stops infinite loops)

#### Model B: Capability-Based (OSGi Requirements/Capabilities, Backstage DI)

Rather than naming concrete dependencies, extensions declare abstract capabilities they need. The resolver finds what provides those capabilities.

```
# OSGi
Require-Capability: osgi.ee;filter:="(&(osgi.ee=JavaSE)(version=11))"
Provide-Capability: com.example.logging;version=1.0.0
```

This enables substitution: any bundle providing the capability satisfies the requirement, enabling runtime variation and loose coupling.

**Implication**: For the current system, Model A (named dependencies like `"dependencies": ["core"]`) is the right choice. It is simpler, sufficient, and matches what the infrastructure already supports. Model B would only become relevant if extensions needed to declare requirements against abstract capabilities (e.g., "I need something that provides memory storage").

---

### Finding 3: Topological Sort is Universal for Dependency Resolution

Every plugin system that supports ordered loading uses topological sort (Kahn's algorithm or DFS-based). The properties are well-understood:

1. **Build dependency graph**: Each node is a plugin, each edge A→B means "A depends on B (B loads first)"
2. **Compute in-degrees**: Count how many plugins depend on each plugin
3. **Process zero-in-degree nodes first**: These have no unresolved dependencies
4. **Decrement and re-queue**: After processing a node, decrement in-degrees of its dependents
5. **Cycle detection is free**: If any nodes remain after the sort, they are in cycles

The current system uses the simpler DFS-recursive approach (load each dependency immediately before the current plugin, pushing a `_loading_stack` for cycle detection). This is functionally equivalent to topological sort for a tree-shaped dependency graph. It only breaks if there are diamonds (A depends on both B and C, and B depends on C) - but the re-read-state pattern (`state = state_mod.read(...)` before each dep check) handles this: if C was already loaded by B's path, it is skipped when A encounters it directly.

**Implication**: The existing dependency resolution in `init.lua` is correct and doesn't need a topological sort rewrite. The stack-based DFS with re-read-state handles diamond dependencies correctly.

---

### Finding 4: Implicit vs. Explicit Dependencies - Tradeoffs

| Approach | Pro | Con | Used by |
|----------|-----|-----|---------|
| Always-implicit core | Zero overhead, no user action | Hard to test core in isolation | webpack, Gradle, Terraform |
| Explicit core dep | Visible in manifest, traceable | Boilerplate in all manifests | OSGi bundles (Require-Bundle) |
| DI container injection | No coupling, swappable impl | Complex setup, harder to debug | Backstage, Spring |

The lazy.nvim documentation explicitly recommends **against** over-declaring dependencies: "Only use dependencies if a plugin needs the dep to be installed AND loaded." Lua modules are auto-loaded on `require()`, so declaring them as dependencies can cause premature loading.

For the current system's JSON manifests, there is no auto-loading mechanism - the dependency must be declared. But the key insight from lazy.nvim: **prefer implicit loading over explicit declaration where possible**. If core were always-loaded (like Gradle's core plugins), no extension would need to declare `"dependencies": ["core"]`.

**Implication**: The cleanest architecture is:
1. Core is always-loaded (auto-loaded at first extension load, before any deps are resolved)
2. No extension needs to declare `"dependencies": ["core"]`
3. The `core` extension manifest exists for state tracking only

This is simpler than requiring all 16 extension manifests to be updated. The loader can auto-inject core loading before the dep resolution loop.

---

### Finding 5: Peer Dependencies Handle the "Host-Level Shared Dep" Problem

npm's `peerDependencies` model is the closest to the "core is provided by the host" pattern:

- A plugin declares `peerDependencies: { "react": ">=18" }` meaning "I need React but the host app provides it"
- The plugin does not bundle React; the host does
- This prevents React duplication and ensures one shared instance

This maps precisely to the current situation: extensions need the core agent system, but the core system is "provided by the host" (the sync mechanism deposits it in every project). Extensions should not bundle core files; they should declare a peer dependency on the core host.

In the current architecture: core files are synced to every project repo unconditionally. Loading a "core" extension is analogous to registering with the host that you depend on it - the actual files are already there via sync.

**Implication**: The "core" extension with empty `provides` (since files are host-provided via sync) maps cleanly to the peer dependency pattern. This validates Teammate A's Option A design.

---

### Finding 6: Package Registries Distinguish Tiers with Different Trust Levels

| Registry | Core/Official | Community | Distinction |
|----------|--------------|-----------|-------------|
| Gradle Plugin Portal | Bundled with Gradle | Requires full qualified ID + version | Short name vs. full ID |
| npm | No "npm core" | Community packages | No distinction (all equal) |
| Terraform Registry | HashiCorp official | Partner/Community | Badge tier system |
| VS Code Marketplace | Microsoft-signed | Community | Publisher: `vscode.` prefix = built-in |
| crates.io | `std` crate (implicit) | Community | Language-level; `std` is compiler-injected |

The Rust model is instructive: `std` is not in `Cargo.toml`; it is compiler-injected and always available. Extensions to `std` are declared explicitly. This clean separation avoids the bootstrap problem entirely.

**Implication**: The `core` extension being "owned" by the system (same repo, no external source) is the right placement. It should be treated as a first-party artifact that is discoverable but semantically different from community extensions.

---

### Finding 7: Symlinks Are Used for Local Development, Not Distribution

Monorepo tools (npm workspaces, yarn workspaces, pnpm, lerna) all use symlinks for local development to prevent file duplication:

```
node_modules/
  @company/shared-lib -> ../../packages/shared-lib  (symlink)
  plugin-a -> ../../packages/plugin-a              (symlink)
```

This enables:
- Instant reflection of changes (no rebuild/copy needed)
- Single source of truth
- Avoids node_modules nesting for internal packages

However, symlinks introduce issues:
- Git clean may remove symlinked content
- Some tools don't follow symlinks correctly
- Distribution (publishing to registry) requires real copies

**Implication for Task 464**: Symlinks were proposed in Round 1 as a way for the source repo to "load" extensions without copying files. The Round 1 synthesis correctly concluded this is unnecessary since the blocklist already prevents file copy leakage. However, the symlink pattern is useful context: it shows that "load without copy" (by reference, not by value) is a well-established pattern in monorepos. If the blocklist approach has gaps, symlink-based loading would be a fallback.

---

### Finding 8: Backstage's Dependency Injection as "Core as Service"

Backstage solves "core is special" through DI injection, not extension loading:

```typescript
// Plugin declares what it needs from core
const myPlugin = createBackendPlugin({
  pluginId: 'my-plugin',
  register(env) {
    env.registerInit({
      deps: {
        logger: coreServices.logger,       // always available
        database: coreServices.database,   // always available
        http: coreServices.httpRouter,     // always available
      },
      async init({ logger, database, http }) {
        // Core services injected; never need to "load" them
      }
    });
  }
});
```

Key properties:
- Core services are registered unconditionally at backend creation
- Plugins declare interface dependencies, not implementation dependencies
- Circular deps cause startup failure (detected at runtime, not compile time)
- Core services cannot be unregistered

**Implication**: If the current system were to evolve toward a more sophisticated model, a DI-based approach (where extensions register handlers that receive core capabilities) would be cleaner than explicit extension loading. But this is a future architectural direction, not relevant for the minimal fix.

---

### Finding 9: Webpack's "Hooks" Pattern Avoids the Dependency Problem Entirely

Webpack's tapable plugin system demonstrates an alternative: plugins don't depend on each other at all. They hook into events emitted by the core compiler.

```javascript
class MyPlugin {
  apply(compiler) {
    compiler.hooks.emit.tapAsync('MyPlugin', (compilation, callback) => {
      // Respond to core events; no plugin-to-plugin deps needed
    });
  }
}
```

This works because: all inter-plugin communication flows through core events. Plugin A doesn't need Plugin B; both respond to the same core hook. Core is the communication bus.

**Implication**: The current extension system could evolve toward an event-based model where extensions register handlers for system events (e.g., "before sync", "after task create"). This would eliminate inter-extension dependencies entirely. But again, this is future direction.

---

### Finding 10: Version Constraints and Breaking Changes in Core

How successful ecosystems handle core breaking changes:

- **Terraform**: Core (v1.x) provides stability promises; providers version independently. Breaking changes to core require major version bump.
- **VS Code**: Extensions declare minimum engine version (`"engines": {"vscode": "^1.85.0"}`). VS Code has strong backwards compatibility commitment.
- **Backstage**: Core package version changes require plugin updates; they use `@backstage/cli` to automate compatibility checks.
- **OSGi**: Version ranges in `Require-Bundle` allow flexible constraint satisfaction.

The common theme: **core versions slowly; extensions version frequently**. Core stability is a primary design goal.

**Implication**: If a "core" extension manifest is created, it should have a version (`1.0.0`). Extensions declaring `"dependencies": ["core"]` should NOT need to specify a version constraint (since there's only one version, and it lives in the same repo). Version constraints become relevant only if core is distributed separately from extensions.

---

## Recommended Approach

Based on external patterns, the following is recommended for Task 464:

### Primary Recommendation: Auto-Loaded Core with Empty Provides

Create `extensions/core/manifest.json` with:
- `"provides": {}` (empty - no file copying)
- `"merge_targets": {}` (initially empty, or minimal CLAUDE.md section)
- `"dependencies": []` (core has no deps)

In `init.lua`, modify the extension loader to **auto-load core before resolving any extension's dependencies**:

```lua
-- At the start of the dependency resolution loop:
if extension_name ~= "core" then
  local core_state = state_mod.is_loaded(state, "core")
  if not core_state then
    manager.load("core", { confirm = false, project_dir = project_dir, ... })
  end
end
```

This eliminates the need to update all 16 extension manifests to add `"dependencies": ["core"]`. Core is always loaded first, implicitly, matching how Gradle/webpack/Terraform handle their core.

### Alternative: Explicit Dependency Declaration

If implicit auto-loading is undesirable (e.g., for auditability), add `"dependencies": ["core"]` to all 16 extension manifests. This is the OSGi/VS Code model: explicit, traceable, but requires updating all manifests.

**Tradeoff**: Implicit (cleaner API, no manifest boilerplate) vs. Explicit (visible in manifest, survives code changes that might remove the auto-load).

### On Sync Leakage (Orthogonal to Dependency System)

The sync leakage problem (CLAUDE.md section injection, settings.json keys) is a separate concern not addressed by any dependency management pattern from external systems. Closest analog:

- **npm `peerDependencies` warning system**: Warns about mismatches but doesn't strip them
- **Turborepo's `syncpack`**: Enforces version consistency, strips mismatches

The `strip_extension_sections()` function (identified in Round 1) is the right approach. No external ecosystem provides a ready-made pattern for this specific problem (syncing files while stripping content that was injected by local extensions).

---

## Evidence and Examples

### VS Code Extension Dependencies
From official VS Code docs: `extensionDependencies` activates the listed extensions before the declaring extension. If any dependency fails to activate, the declaring extension also fails. This is the same semantics as the current `init.lua` implementation.

Source: [VS Code Extension Manifest](https://code.visualstudio.com/api/references/extension-manifest)

### lazy.nvim Dependency Loading Sequence
From DeepWiki analysis of lazy.nvim source: When `M._load()` is called, at step 7 it recursively calls `M.load(plugin.dependencies, {})` before sourcing the parent plugin's files. Dependencies are fully loaded before the parent continues.

Source: [lazy.nvim Plugin Loading - DeepWiki](https://deepwiki.com/folke/lazy.nvim/4.2-plugin-loading-and-initialization)

### Kahn's Algorithm for Cycle Detection
If the length of the sorted result is less than the number of nodes, some nodes were never added to the queue because their in-degree never reached 0 - indicating a cycle.

Source: [Topological Sort - DEV Community](https://dev.to/dawkaka/topological-sort-and-why-youre-getting-cyclic-dependency-errors-20g6)

### Backstage Core Services
"These core services will always be present in a backend instance created with `createBackend` and can all be overridden with custom implementations if needed."

Source: [Backstage Backend Services](https://backstage.io/docs/backend-system/architecture/services/)

### OSGi Resolution Model
"The resolver constructs a complete, closed set of Resources from a list of initial Requirements and available repositories." Core runtime bundle (`org.eclipse.core.runtime`) is the foundational capability that all other bundles implicitly require.

Source: [OSGi Resolving - enRoute](https://enroute.osgi.org/FAQ/200-resolving.html)

---

## Confidence Level

**High** for the external patterns (based on direct documentation review and authoritative sources).

**Medium** for the application to the specific codebase - the mapping relies on Teammate A's code analysis (which I cannot independently verify). The architectural patterns align well with what Teammate A describes, particularly:
- The dependency resolution DFS with stack matches lazy.nvim's approach
- The blocklist mechanism for sync filtering has no direct external parallel (it is a custom solution for a custom problem)
- The "core with empty provides" pattern aligns with the OSGi/peer dependency model

**Key uncertainty**: Whether auto-loading core (implicit) vs. manifest-declared dependency (explicit) is preferable. External systems are split: Gradle/webpack/Rust use implicit; VS Code/OSGi use explicit. The deciding factor for this system should be whether auditability of the `extensions.json` state file matters more than minimizing manifest boilerplate.

---

## Summary Table

| Research Area | Finding | Confidence |
|--------------|---------|-----------|
| Core-as-extension pattern | No production system treats core as an equal extension; it is implicit or special-cased | High |
| Dependency declaration model | Named explicit deps (VS Code/OSGi) vs. auto-injection (Gradle/webpack) - both valid | High |
| Topological sort | Universal for ordered loading; DFS-recursive (current) is correct for tree graphs | High |
| Cycle detection | Kahn's algorithm: if nodes remain after sort, there's a cycle; current stack approach is equivalent | High |
| Symlink vs. copy | Symlinks used for local dev monorepos to avoid duplication; not for distribution | High |
| Sync leakage | No external pattern directly addresses this; custom strip-on-sync is the right approach | Medium |
| Version constraints | Core should version slowly; extension deps on core typically don't need version ranges if co-located | High |
| Peer deps analogy | npm peerDeps maps well: host provides core, extensions declare peer dep, no bundling | High |
