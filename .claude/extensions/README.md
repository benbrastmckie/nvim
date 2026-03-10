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

| Extension | Language | Description |
|-----------|----------|-------------|
| nvim | neovim | Neovim configuration development |
| lean | lean4 | Lean 4 theorem proving with Mathlib |
| latex | latex | LaTeX document preparation |
| typst | typst | Modern document typesetting |
| python | python | Python development |
| nix | nix | NixOS and Home Manager configuration |
| web | web | Astro/Tailwind web development |
| z3 | z3 | Z3 SMT solver |
| epidemiology | epidemiology | Epidemiology research with R |
| formal | formal, logic, math, physics | Formal verification domains |
| filetypes | - | File format conversion |

## Loading Extensions

Extensions are loaded via the Neovim picker:
- `<leader>ac` - Claude Code extension picker
- `<leader>ao` - OpenCode extension picker

When an extension is loaded:
1. Agent, skill, rule files are copied to .claude/
2. Context directories are copied to .claude/context/project/
3. Index entries are merged into .claude/context/index.json
4. EXTENSION.md content is injected into .claude/CLAUDE.md
5. Post-load verification runs to check integrity

## Extension Structure

Each extension follows this structure:

```
extensions/{name}/
  manifest.json       # Name, version, provides, merge_targets
  EXTENSION.md        # Content to inject into CLAUDE.md
  index-entries.json  # Context index entries to merge
  agents/             # Agent definition files (.md)
  skills/             # Skill directories with SKILL.md
  rules/              # Rule files (.md)
  context/            # Context files (preserving project/* structure)
  scripts/            # Optional shell scripts
```

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
      "load_when": {
        "languages": ["neovim"],
        "agents": ["neovim-research-agent"]
      }
    }
  ]
}
```

## Post-Load Verification

After loading, the system verifies:
- All agent files exist in .claude/agents/
- All skill directories exist in .claude/skills/
- All rule files exist in .claude/rules/
- All context files referenced in index-entries.json exist
- EXTENSION.md section was injected into CLAUDE.md
- Index entries were merged into index.json

Verification results are shown via notification.

## Creating New Extensions

1. Create extension directory in `.claude/extensions/{name}/`
2. Create manifest.json with name, version, description, provides
3. Create EXTENSION.md with content to inject into CLAUDE.md
4. Create index-entries.json with context index entries (use canonical paths)
5. Add agents/, skills/, rules/, context/ as needed
6. Test by loading via `<leader>ac`

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
