# Teammate B Findings: Alternative Patterns and Prior Art

## Key Findings

### 1. Existing Documentation Is More Complete Than Expected

The `.claude/docs/architecture/extension-system.md` file (417 lines) already documents the
extension system in substantial detail, covering:

- System overview with ASCII diagram (Load/Unload flow)
- Directory structure for extension layout and state file schema
- Core components: Manifest, Loader, Merger, State, Config — each with function-level detail
- Full load/unload process (step-by-step numbered lists)
- Index lifecycle
- Settings merging
- Picker integration
- Error handling and recovery

This file lives at `/home/benjamin/.config/nvim/.claude/docs/architecture/extension-system.md`
and is cross-referenced from the `docs-README.md`.

**Gap**: This document refers to "the loader" as a black box. It documents what each Lua module
does (by function name) but does NOT:
- Name the Lua source files or their paths (`lua/neotex/plugins/ai/shared/extensions/`)
- Explain that the loader is Neovim plugin code (Layer 1) vs the agent system (Layer 2)
- Make the distinction between the two physical layers explicit

### 2. The Two-Layer Architecture Is Implicit, Not Documented

The core conceptual gap is that no document names or explains the **two distinct layers**:

- **Layer 1**: Neovim Lua plugin code at `lua/neotex/plugins/ai/shared/extensions/` — manages
  which files exist in `.claude/`
- **Layer 2**: Markdown/JSON files in `.claude/` — read by Claude Code as the agent system

The `.claude/docs/architecture/system-overview.md` documents a "three-layer architecture"
(commands → skills → agents) but that is the internal agent routing, not the loader/agent-system
split. The loader layer is invisible in all existing documentation.

### 3. EXTENSION.md Is the Source of Truth for Routing; README.md Is for Humans

The pattern across all extensions:

| File | Purpose | Audience | Size limit |
|------|---------|----------|-----------|
| `EXTENSION.md` | Injected into CLAUDE.md at load time | Claude Code (agent routing) | 60 lines (enforced by `extension-slim-standard.md`) |
| `README.md` | Human-readable reference | Developers/users | 120-400 lines |
| `manifest.json` | Machine-readable extension metadata | Extension loader (Lua code) | N/A |

The `extension-slim-standard.md` standard at
`.claude/docs/reference/standards/extension-slim-standard.md` establishes the 60-line cap
and four required sections for `EXTENSION.md`. This is the most rigorous documentation
standard in the system.

Current `EXTENSION.md` compliance (all extensions):

| Extension | Lines | Status |
|-----------|-------|--------|
| core | 54 | compliant |
| epidemiology | 46 | compliant |
| filetypes | 23 | compliant |
| formal | 60 | compliant (at limit) |
| founder | 39 | compliant |
| latex | 29 | compliant |
| lean | 31 | compliant |
| memory | 41 | compliant |
| nix | 62 | **over limit by 2** |
| nvim | 41 | compliant |
| present | 64 | **over limit by 4** |
| python | 30 | compliant |
| slidev | 12 | compliant |
| typst | 30 | compliant |
| web | 25 | compliant |
| z3 | 29 | compliant |

### 4. README.md Files Follow a Documented Template

The `extension-readme-template.md` at
`.claude/extensions/core/templates/extension-readme-template.md` defines a section-applicability
matrix distinguishing "simple" from "complex" extensions. Complex extensions (nvim, nix, lean,
memory) get full templates including architecture trees, workflow diagrams, and output artifact
tables. Simple extensions (latex, python, typst, z3) use abbreviated versions.

This template-based approach is sound but the template lives in `extensions/core/templates/`
(source), not in `docs/` (user-facing). New extension authors must know to look there.

### 5. Redundancy Pattern: EXTENSION.md vs README.md

Both `EXTENSION.md` and `README.md` contain identical or near-identical routing tables for
every extension. Example (nvim extension):

- `EXTENSION.md:9` — Language Routing table with `skill-neovim-research`
- `README.md:62` — Language Routing table with `skill-neovim-research` (slightly different column header "Task Type" vs "Language")
- `EXTENSION.md:15-16` — Skill-Agent Mapping table
- `README.md:55-56` — Same Skill-Agent Mapping table

This is intentional by design (EXTENSION.md is for Claude Code; README.md is for humans) but
the slight divergences (different column headers, missing tools column in EXTENSION.md) create
a maintenance surface where the two files can drift.

### 6. Documentation Is Not Generated From manifest.json

The manifest.json files contain machine-readable metadata (`provides`, `routing`,
`merge_targets`) that directly corresponds to content in EXTENSION.md and README.md. Currently,
this content is hand-maintained in three places:
1. `manifest.json` (authoritative for the loader)
2. `EXTENSION.md` (authoritative for Claude Code routing)
3. `README.md` (authoritative for humans)

No tooling exists to validate that these stay in sync, and no documentation describes
how they relate.

**Opportunity**: The routing tables in EXTENSION.md and README.md could be generated from
`manifest.json`'s `routing` field, eliminating one source of drift. The `check-extension-docs.sh`
script validates READMEs/manifests exist and cross-references but does not verify routing
table consistency.

### 7. The `extensions.json` State File Is Well-Documented in Docs; Not in Context

The `extensions.json` runtime state file schema is documented in:
- `.claude/docs/architecture/extension-system.md` (lines 71-96)

But there is no context file (under `.claude/context/`) that documents this schema for agent
use. Agents that need to understand the loaded extension state would need to read the docs
directory, which is not in the context index.

### 8. The Shared Extensions Module Is Completely Undocumented

The Lua module at `lua/neotex/plugins/ai/shared/extensions/` (8 files, ~3,500 LOC) is the
actual implementation of everything described in the extension system docs. No document in
`.claude/` or the project acknowledges that it exists. The term "shared" in the module path
refers to the parameterized design (used by both Claude and OpenCode pickers), but this
parameterization is also not documented.

Files in this module:
- `config.lua` (77 lines) — Configuration presets (Claude vs OpenCode)
- `init.lua` (819 lines) — Public API: load, unload, get_details, list_available
- `loader.lua` (628 lines) — File copy engine
- `manifest.lua` (294 lines) — Manifest parsing and validation
- `merge.lua` (739 lines) — CLAUDE.md/index.json merge strategies
- `picker.lua` (286 lines) — Telescope-based picker UI
- `state.lua` (239 lines) — extensions.json read/write
- `verify.lua` (430 lines) — Post-load verification

---

## Recommended Approach

### Option A: Add a "Two-Layer Architecture" Section to Existing Docs (Minimal)

Amend `.claude/docs/architecture/extension-system.md` with a new "Two-Layer Architecture"
section at the top that explicitly names:
1. The Neovim Lua layer: path, module list, role (manages files on disk)
2. The Agent System layer: path, role (read by Claude Code)

This is a surgical addition of ~30 lines to an already comprehensive document. It addresses
the core conceptual gap without creating new maintenance burden.

**Pros**: Low effort, single-file change, directly addresses the gap.
**Cons**: Still leaves the Lua source code undocumented for developers.

### Option B: Create a Dedicated Developer Reference Document (Moderate)

Create `.claude/docs/architecture/extension-loader-reference.md` that:
1. Explains the two-layer separation explicitly
2. Lists each Lua module with its path and single-sentence purpose
3. Documents the `extensions.json` schema (already partially in extension-system.md)
4. Describes the parameterization (Claude vs OpenCode config presets)
5. Points to the existing `extension-system.md` for the what/why and itself for the where/how

**Pros**: Clean separation of concerns; extension-system.md stays as the user guide.
**Cons**: New file to maintain; some redundancy with extension-system.md.

### Option C: Extract and Auto-Document from Code (Ambitious)

Add a linting step to `check-extension-docs.sh` that validates routing table consistency
between `manifest.json`, `EXTENSION.md`, and `README.md`. This would:
1. Parse `manifest.json`'s `routing` field
2. Verify the routing table in `EXTENSION.md` matches
3. Warn on divergence

**Pros**: Prevents drift without maintenance overhead; addresses Finding #6.
**Cons**: Requires bash parsing of markdown tables (fragile); significant implementation effort.

### Recommendation: Option A + partial Option C

1. Add a "Two-Layer Architecture" section to `extension-system.md` (Option A) — 20-30 lines.
2. Add a note in `extension-slim-standard.md` pointing to the Lua source path so developers
   who work on the loader know where to look — 5 lines.
3. Add a routing validation check to `check-extension-docs.sh` that at minimum warns when
   `manifest.json`'s routing keys differ from documented task types in `EXTENSION.md` — this is
   a simpler check than full table validation (Option C partial).

---

## Evidence/Examples

### The Documentation Gap in Concrete Terms

Current `extension-system.md` line 158-169:
```
### 2. Loader (loader.lua)

The loader handles file copy operations:

**Functions**:
- `copy_simple_files()` - Copy agents, commands, rules
...
```

This references `loader.lua` by name but gives no path. A developer maintaining the system
has no way to find it from this documentation alone without grepping the codebase.

The actual path: `lua/neotex/plugins/ai/shared/extensions/loader.lua`

### Redundancy Example: nvim routing table appears 3 times

1. `manifest.json` lines 28-38: `routing` field (machine-readable)
2. `EXTENSION.md` lines 4-9: Language Routing table (agent-facing)
3. `README.md` lines 59-62: Language Routing table (human-facing)

All three say the same thing in different formats. The EXTENSION.md and README.md versions
have slight divergences (column naming, tool lists).

### Template Location Gap

Extension README template lives at:
- `extensions/core/templates/extension-readme-template.md` (source/input file)

But new extension developers are pointed to:
- `.claude/extensions/{name}/README.md` (output expectation)

There is no link from the creation guide (`creating-extensions.md`) to the template file.
The guide at line 34 shows `touch README.md` but gives no template reference.

---

## Confidence Level: High

The evidence is direct code and file inspection. The documentation gaps are concrete and
verifiable:
1. No `.claude/` document names `lua/neotex/plugins/ai/shared/extensions/` (confirmed by grep)
2. The two-layer architecture is never named explicitly (confirmed by grep for "layer 1",
   "layer 2", "two-layer", "Neovim.*loader")
3. Routing table redundancy is directly observable via diff
4. `nix` and `present` EXTENSION.md files exceed the 60-line standard (line count confirmed)
