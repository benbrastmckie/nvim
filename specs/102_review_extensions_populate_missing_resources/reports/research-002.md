# Research Report: Task #102 (Revised)

**Task**: 102 - review_extensions_populate_missing_resources
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T01:00:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of nvim/.claude/extensions/, ProofChecker/.claude/, Logos/Theory/.claude/, ModelChecker/.claude/, Neovim Lua extension system code
**Artifacts**: specs/102_review_extensions_populate_missing_resources/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

This revised research supersedes research-001.md based on user clarification. Three major changes are required:

1. **Create formal/ extension**: Consolidate logic, math, and physics research agents/skills/context into a single `formal/` extension. Source material exists in ProofChecker/.claude/ and Logos/Theory/.claude/ -- logic-research-agent, math-research-agent, skill-logic-research, skill-math-research, plus extensive context files for logic (11 domain, 4 process, 3 standards), math (12 files across algebra, category-theory, foundations, lattice-theory, order-theory, topology), and physics (1 domain file + README).
2. **Remove neovim/ extension**: Delete the existing neovim/ extension directory entirely. It is a stub (3 files) and neovim is the native domain of this repository.
3. **Rename claudemd-section.md to EXTENSION.md**: All 6 extension directories contain this file. The rename requires updating each manifest.json's `merge_targets.claudemd.source` field. No Lua code changes needed -- the extension loader reads the filename from manifest.json dynamically.

## Context and Scope

This research focuses on the user's three specific requirements, superseding the broader gap analysis in research-001.md. The original report's findings about lean, latex, typst, z3, and python extension gaps remain valid for separate work but are not the focus here.

## Findings

### 1. Rename claudemd-section.md to EXTENSION.md

#### Files to Rename (6 total)

| Extension | Current File | New File |
|-----------|-------------|----------|
| lean | `.claude/extensions/lean/claudemd-section.md` | `.claude/extensions/lean/EXTENSION.md` |
| latex | `.claude/extensions/latex/claudemd-section.md` | `.claude/extensions/latex/EXTENSION.md` |
| neovim | `.claude/extensions/neovim/claudemd-section.md` | `.claude/extensions/neovim/EXTENSION.md` |
| python | `.claude/extensions/python/claudemd-section.md` | `.claude/extensions/python/EXTENSION.md` |
| typst | `.claude/extensions/typst/claudemd-section.md` | `.claude/extensions/typst/EXTENSION.md` |
| z3 | `.claude/extensions/z3/claudemd-section.md` | `.claude/extensions/z3/EXTENSION.md` |

Note: The neovim extension's claudemd-section.md will be renamed then deleted as part of removing the neovim extension. But it should be renamed first if the formal/ extension needs to be created before neovim/ is removed.

#### Manifest.json Updates (6 total)

Each extension's `manifest.json` contains:
```json
"merge_targets": {
  "claudemd": {
    "source": "claudemd-section.md",   // Change to "EXTENSION.md"
    "target": ".claude/CLAUDE.md",
    "section_id": "extension_{name}"
  }
}
```

The `source` field must change from `"claudemd-section.md"` to `"EXTENSION.md"` in each manifest.

#### Lua Code Analysis: No Changes Required

The extension system reads the filename dynamically from manifest.json:

- **`init.lua:58`**: `local source_path = source_dir .. "/" .. config.source` -- reads `config.source` from manifest
- **`merge.lua:115`**: `inject_claudemd_section()` -- function name references "claudemd" but takes content as parameter, not filename
- **`merge.lua:153`**: `remove_claudemd_section()` -- same pattern, works on section markers not filenames
- **`manifest.lua:117`**: Validates `config.source` exists but does not check specific filename
- **`picker.lua`**: Does not reference claudemd-section.md at all
- **`state.lua`**: Does not reference claudemd-section.md at all

The `inject_claudemd_section` and `remove_claudemd_section` function names contain "claudemd" but this is a naming convention, not a filename dependency. Renaming the functions is optional cosmetic cleanup.

#### References in Neovim Configuration

- **`<leader>ae`** (`which-key.lua:243`): Opens the ClaudeExtensions picker. Does NOT reference claudemd-section.md.
- **`<leader>ac`** (`which-key.lua:242`): Opens ClaudeCommands picker. Not related to extensions.
- No other keymaps reference extension file names.

#### References in specs/ (Documentation Only)

The specs/ directory contains 30+ references to `claudemd-section.md` in research reports, plans, and summaries from tasks 99 and 101. These are historical documentation and do not need updating -- they describe the state at the time of those tasks.

### 2. Remove neovim/ Extension

#### Current State

The neovim/ extension is a stub with 3 files:
- `neovim/manifest.json` - Declares agents, skills, rules, context that don't exist in the extension
- `neovim/claudemd-section.md` - CLAUDE.md injection section for neovim language routing
- `neovim/index-entries.json` - Context index entries

The manifest declares providing resources that live in the main `.claude/` directory, not in the extension:
```json
"provides": {
  "agents": ["neovim-research-agent.md", "neovim-implementation-agent.md"],
  "skills": ["skill-neovim-research", "skill-neovim-implementation"],
  "rules": ["neovim-lua.md"],
  "context": ["project/neovim"]
}
```

These resources are already native to this repository.

#### Removal Steps

1. Delete `extensions/neovim/` directory entirely (3 files)
2. No unload needed since it was never loaded into any project
3. Verify no other extension declares a dependency on neovim

#### Dependencies Check

All existing extension manifests have `"dependencies": []`. No cross-extension dependencies exist.

### 3. Create formal/ Extension

#### Source Material Inventory

The ProofChecker and Logos/Theory projects contain identical formal reasoning resources (they share the same .claude/ infrastructure). Using ProofChecker as the canonical source:

##### Agents (2 existing + 1 new needed)

| Agent | Source Path | Status |
|-------|------------|--------|
| `logic-research-agent.md` | ProofChecker/.claude/agents/ | Exists, needs adaptation |
| `math-research-agent.md` | ProofChecker/.claude/agents/ | Exists, needs adaptation |
| `physics-research-agent.md` | N/A | NEW -- must be created |

The existing agents are substantial (700+ lines for logic, similar for math) and include:
- Frontmatter: `model: opus`
- Full execution flow with 7 stages
- Mathlib lookup MCP tool integration
- ROAD_MAP.md reflection pattern (logic)
- Context extension recommendations pattern
- Dynamic context discovery via index.json queries

A physics-research-agent does not exist in any project. It would need to be created from scratch, likely modeled after the math-research-agent but adapted for physics domains (dynamical systems, Hamiltonian mechanics, etc.).

##### Skills (2 existing + 1 new needed)

| Skill | Source Path | Status |
|-------|------------|--------|
| `skill-logic-research/SKILL.md` | ProofChecker/.claude/skills/ | Exists, needs adaptation |
| `skill-math-research/SKILL.md` | ProofChecker/.claude/skills/ | Exists, needs adaptation |
| `skill-physics-research/SKILL.md` | N/A | NEW -- must be created |

Both existing skills are thin wrappers that delegate to their respective agents via the Task tool. They include:
- Input validation
- Agent delegation with delegation context JSON
- Skill-internal postflight (status update, artifact linking, git commit)
- Error handling and partial progress support

##### Context Files

**Logic Context** (18 files from ProofChecker/.claude/context/project/logic/):

| Subdirectory | Files | Content |
|-------------|-------|---------|
| `domain/` | 11 files | bilateral-propositions, bilateral-semantics, counterfactual-semantics, kripke-semantics-overview, lattice-theory-concepts, mereology-foundations, metalogic-concepts, proof-theory-concepts, spatial-domain, task-semantics, topological-foundations-domain |
| `processes/` | 4 files | modal-proof-strategies, proof-construction, temporal-proof-strategies, verification-workflow |
| `standards/` | 3 files | naming-conventions, notation-standards, proof-conventions |
| Root | 1 file | README.md |

**Math Context** (14 files from ProofChecker/.claude/context/project/math/):

| Subdirectory | Files | Content |
|-------------|-------|---------|
| `algebra/` | 2 files | groups-and-monoids, rings-and-fields |
| `category-theory/` | 6 files | basics, cauchy-completion, enriched-categories, lawvere-metric-spaces, monoidal-categories, profunctors |
| `foundations/` | 1 file | dependent-type-theory |
| `lattice-theory/` | 2 files | bilattice-theory, lattices |
| `order-theory/` | 2 files | monoidal-posets, partial-orders |
| `topology/` | 2 files | scott-topology, topological-spaces |
| Root | 1 file | README.md |

**Physics Context** (2 files from ProofChecker/.claude/context/project/physics/):

| Subdirectory | Files | Content |
|-------------|-------|---------|
| `dynamical-systems/` | 1 file | dynamical-systems (core definitions: iteration, orbits, fixed points, flows) |
| Root | 1 file | README.md |

Physics is currently minimal by design. The README notes future expansion areas: Hamiltonian mechanics, conservation laws, statistical mechanics, temporal logic connections.

#### Adaptation Requirements

The source agents and skills are ProofChecker-specific. Adaptations needed for the formal/ extension:

1. **Remove project-specific references**: ROAD_MAP.md reflection, project directory paths (Theories/, docs/)
2. **Generalize codebase source patterns**: Replace `Theories/**/*.lean` with generic patterns
3. **Keep Mathlib MCP tool integration**: The lean_leansearch, lean_loogle, lean_leanfinder tools are valuable for any formal reasoning project
4. **Adjust context paths**: Change from `.claude/context/project/logic/` to extension-relative paths
5. **Create physics-research-agent**: New agent modeled after math-research-agent, adapted for physics domains

#### Proposed formal/ Extension Structure

```
.claude/extensions/formal/
  manifest.json
  EXTENSION.md                    # (using new naming convention)
  index-entries.json
  agents/
    logic-research-agent.md
    math-research-agent.md
    physics-research-agent.md     # NEW
  skills/
    skill-logic-research/SKILL.md
    skill-math-research/SKILL.md
    skill-physics-research/SKILL.md  # NEW
  context/
    project/
      logic/
        README.md
        domain/                   # 11 files
        processes/                # 4 files
        standards/                # 3 files
      math/
        README.md
        algebra/                  # 2 files
        category-theory/          # 6 files
        foundations/               # 1 file
        lattice-theory/            # 2 files
        order-theory/              # 2 files
        topology/                  # 2 files
      physics/
        README.md
        dynamical-systems/         # 1 file
```

Total files: ~42 content files + 3 metadata files (manifest, EXTENSION.md, index-entries.json)

#### manifest.json Template

```json
{
  "name": "formal",
  "version": "1.0.0",
  "description": "Formal reasoning support: logic, mathematics, and physics research with Mathlib integration",
  "language": "formal",
  "dependencies": [],
  "provides": {
    "agents": [
      "logic-research-agent.md",
      "math-research-agent.md",
      "physics-research-agent.md"
    ],
    "skills": [
      "skill-logic-research",
      "skill-math-research",
      "skill-physics-research"
    ],
    "commands": [],
    "rules": [],
    "context": ["project/logic", "project/math", "project/physics"],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_formal"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "mcp_servers": {}
}
```

#### Language Routing Consideration

The formal/ extension introduces a new language value: `"formal"`. The existing routing system supports:
- neovim, latex, typst, general, meta, lean4, z3, python

The `formal` language would need to be added to the routing table in CLAUDE.md and potentially split into sub-routes (logic, math, physics) at the skill level. Alternatively, the extension could declare three separate languages or use the existing routing infrastructure with a shared skill prefix.

**Recommended approach**: Use `"formal"` as the single language with the skill selecting the appropriate sub-agent based on task description keywords.

## Decisions

1. **File rename scope**: Only manifest.json files need updating for the rename. No Lua code changes required.
2. **Neovim extension removal**: Straightforward directory deletion. No dependencies to handle.
3. **formal/ extension source**: Use ProofChecker as canonical source (identical to Logos/Theory).
4. **Physics agent**: Must be created from scratch. Minimal scope matching the small physics context.
5. **Language routing**: Single "formal" language with internal sub-routing to logic/math/physics agents.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Physics agent is thin due to minimal context | Low -- context can grow over time | Start with minimal agent, expand as physics context grows |
| ProofChecker-specific references leak into extension | Medium -- breaks in non-ProofChecker projects | Careful review during adaptation, remove all project-specific paths |
| Formal language routing conflicts with existing routes | Medium -- tasks may not route correctly | Test routing with sample tasks after implementation |
| Extensions loaded in active projects may reference old claudemd-section.md filename | Low -- extensions.json tracks installed files, not source names | Check for any active extensions.json files before rename |

## Implementation Plan Outline

### Phase 1: Rename claudemd-section.md to EXTENSION.md (all extensions)

For each of the 6 extensions (lean, latex, neovim, python, typst, z3):
1. `git mv .claude/extensions/{name}/claudemd-section.md .claude/extensions/{name}/EXTENSION.md`
2. Update `manifest.json` source field from `"claudemd-section.md"` to `"EXTENSION.md"`

### Phase 2: Remove neovim/ extension

1. `rm -rf .claude/extensions/neovim/`
2. Verify no references break

### Phase 3: Create formal/ extension structure

1. Create directory structure
2. Create `manifest.json` with formal language configuration
3. Create `EXTENSION.md` with language routing and skill-agent mapping
4. Create `index-entries.json` with context file entries

### Phase 4: Populate formal/ agents

1. Copy and adapt `logic-research-agent.md` from ProofChecker
2. Copy and adapt `math-research-agent.md` from ProofChecker
3. Create new `physics-research-agent.md` based on math-research-agent template

### Phase 5: Populate formal/ skills

1. Copy and adapt `skill-logic-research/SKILL.md` from ProofChecker
2. Copy and adapt `skill-math-research/SKILL.md` from ProofChecker
3. Create new `skill-physics-research/SKILL.md` based on math-research template

### Phase 6: Populate formal/ context files

1. Copy logic context (18 files) from ProofChecker
2. Copy math context (14 files) from ProofChecker
3. Copy physics context (2 files) from ProofChecker

### Phase 7: Verification

1. Validate all manifest.json files parse correctly
2. Verify extension picker shows formal/ extension
3. Test load/unload of formal/ extension
4. Verify EXTENSION.md content injects correctly into CLAUDE.md

## Appendix

### Search Queries Used

- `Glob: **/*claudemd-section*` in `.claude/extensions/` -- found 6 files
- `Grep: claudemd-section|EXTENSION\.md` in `lua/` -- found all Lua references
- `Grep: ClaudeExtensions|claudemd-section` in `lua/` -- found picker and command registration
- `find` in ProofChecker/.claude/ -- inventoried formal reasoning resources
- `find` in Logos/Theory/.claude/ -- confirmed identical resources
- `find` in ModelChecker/.claude/ -- confirmed no formal reasoning resources
- `Grep: claudemd-section` in `.claude/docs/` and `.claude/context/` -- no documentation references

### Key File Locations

| File | Purpose |
|------|---------|
| `lua/neotex/plugins/ai/claude/extensions/init.lua` | Extension load/unload API -- reads manifest.source dynamically |
| `lua/neotex/plugins/ai/claude/extensions/merge.lua` | CLAUDE.md section injection -- uses section markers, not filenames |
| `lua/neotex/plugins/ai/claude/extensions/manifest.lua` | Manifest validation -- validates source field exists, not specific name |
| `lua/neotex/plugins/ai/claude/extensions/picker.lua` | Telescope picker for `<leader>ae` -- no filename references |
| `lua/neotex/plugins/ai/claude/extensions/state.lua` | Extension state tracking via extensions.json |
| `lua/neotex/plugins/editor/which-key.lua:243` | `<leader>ae` keybinding for extension picker |
