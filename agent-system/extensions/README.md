# Extensions

Extensions provide domain-specific capabilities that are loaded on-demand into the core agent system.

## Extension Architecture

The core .claude/ system contains only language-agnostic elements:
- Core agents: general-research-agent, general-implementation-agent, planner-agent, meta-builder-agent
- Core skills: ~10 workflow skills (researcher, implementer, planner, meta, etc.)
- Core rules: artifact-formats, error-handling, git-workflow, state-management, workflows
- Core context: core/* patterns, project/meta, project/repo

Extensions add domain-specific elements:
- Domain agents (e.g., neovim-research-agent, lean-implementation-agent)
- Domain skills (e.g., skill-neovim-research, skill-lean-implementation)
- Domain rules (e.g., neovim-lua.md, lean4.md)
- Domain context (e.g., project/neovim/*, project/lean4/*)

## Available Extensions

| Extension | Task Type | Description | Docs |
|-----------|----------|-------------|------|
| nvim | neovim | Neovim configuration development | [README](nvim/README.md) |
| lean | lean4 | Lean 4 theorem proving with Mathlib | [README](lean/README.md) |
| latex | latex | LaTeX document preparation | [README](latex/README.md) |
| typst | typst | Modern document typesetting | [README](typst/README.md) |
| python | python | Python development | [README](python/README.md) |
| rust | rust | Rust development | [README](rust/README.md) |
| nix | nix | NixOS and Home Manager configuration | [README](nix/README.md) |
| web | web | Astro/Tailwind web development | [README](web/README.md) |
| z3 | z3 | Z3 SMT solver | [README](z3/README.md) |
| epidemiology | epi, epi:study | Epidemiology research with R, /epi command | [README](epidemiology/README.md) |
| formal | formal, logic, math, physics | Formal verification domains | [README](formal/README.md) |
| filetypes | - | File format conversion | [README](filetypes/README.md) |
| founder | founder | Business strategy and startup operations | [README](founder/README.md) |
| present | present | Grant writing and proposal development | [README](present/README.md) |
| memory | - | Learning and knowledge management | [README](memory/README.md) |
| slidev | - | Shared Slidev animation patterns and CSS style presets | [README](slidev/README.md) |

## Loading Extensions

Extensions are loaded via the editor's extension picker:
- Neovim: `<leader>ac` | OpenCode: `<leader>ao`

When an extension is loaded:
1. Stale index entries are cleaned (pre-load cleanup removes entries from non-loaded extensions)
2. Agent, skill, rule files are copied to .claude/
3. Context directories are copied to .claude/context/project/
4. Merge targets are processed (CLAUDE.md is regenerated from all loaded extensions, index.json entries merged, settings merged)
   - Core index entries are loaded via core's `merge_targets.index` (same mechanism as all extensions)
   - Extension-specific index entries are merged into .claude/context/index.json (tracked for unload)
5. Post-load verification runs to check integrity

Extensions can declare dependencies on other extensions via the `dependencies` array in manifest.json. When an extension with dependencies is loaded, unloaded dependencies are auto-loaded silently before proceeding. The picker preview shows each extension's dependencies and which loaded extensions depend on it.

## Extension Structure

Each extension follows this structure:

```
extensions/{name}/
  manifest.json       # Name, version, provides, merge_targets
  EXTENSION.md        # CLAUDE.md source content (standard extensions)
  index-entries.json  # Context index entries to merge
  agents/             # Agent definition files (.md)
  skills/             # Skill directories with SKILL.md
  rules/              # Rule files (.md)
  context/            # Context files (preserving project/* structure)
  scripts/            # Optional shell scripts
  merge-sources/      # Alternative CLAUDE.md source (core extension only)
    claudemd.md       # Used instead of EXTENSION.md for the core extension
```

### CLAUDE.md Source Pattern

`.claude/CLAUDE.md` is a **computed artifact** regenerated on every load/unload. The loader concatenates CLAUDE.md source files from all loaded extensions (core first, then others in sorted order).

- **Standard extensions**: provide `EXTENSION.md` at the extension root (`"source": "EXTENSION.md"` in manifest)
- **Core extension** (`extensions/core/`): provides `merge-sources/claudemd.md` as its CLAUDE.md source (`"source": "merge-sources/claudemd.md"` in manifest)

Do not edit `.claude/CLAUDE.md` directly -- changes will be overwritten. Edit the extension's CLAUDE.md source file instead.

## index-entries.json Format

**IMPORTANT**: All paths in index-entries.json must use canonical format:
- `project/*` for project-specific context
- `core/*` for core patterns

**DO NOT use**:
- `.claude/context/project/*` (absolute prefix)
- `context/project/*` (extra context prefix)

**Correct example**:
```json
{
  "entries": [
    {
      "path": "project/neovim/README.md",
      "domain": "project",
      "subdomain": "neovim",
      "summary": "Neovim extension README",
      "line_count": 42,
      "load_when": {
        "task_types": ["neovim"],
        "agents": ["neovim-research-agent"]
      }
    }
  ]
}
```

The authoritative field definition is
`agent-system/extensions/core/context/index.schema.json`; see also
`agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md`'s Index
Integration section for the same canonical shape.

## Post-Load Verification

After loading, the system verifies:
- All agent files exist in .claude/agents/
- All skill directories exist in .claude/skills/
- All rule files exist in .claude/rules/
- All context files referenced in index-entries.json exist
- EXTENSION.md content appears in regenerated CLAUDE.md
- Index entries were merged into index.json

Verification results are shown via notification.

## Creating New Extensions

1. Create extension directory in `agent-system/extensions/{name}/`
2. Create manifest.json with name, version, description, provides
3. Create EXTENSION.md with content that will appear in CLAUDE.md when loaded
4. Create index-entries.json with context index entries (use canonical paths)
5. Add agents/, skills/, rules/, context/ as needed
6. Test by loading via the extension picker

## Validation

Run wiring validation to verify extension integrity:

```bash
.claude/scripts/validate-wiring.sh --all
```

This checks:
- Core system integrity (agents, skills, rules, index.json)
- Extension wiring (when extensions are loaded)
- Context file existence
- Index entry consistency
