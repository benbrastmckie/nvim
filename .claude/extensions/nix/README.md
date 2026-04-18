# Nix Extension

NixOS and Home Manager configuration support with `mcp-nixos` integration for package/option search and validation. Provides research and implementation agents for Nix flakes, modules, overlays, and derivations with live package lookups.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `nix` | nix-research-agent | NixOS/Home Manager/flakes research with MCP-NixOS |
| `nix` | nix-implementation-agent | Nix configuration implementation with verification |

## Installation

Loaded via the extension picker. Once loaded, `nix` becomes a recognized task type.

## MCP Tool Setup

### mcp-nixos

Provides real-time package and option lookups against nixpkgs and NixOS modules.

```bash
uvx mcp-nixos
```

Configured automatically in `manifest.json`. Requires `uv` to be installed on your system (`curl -LsSf https://astral.sh/uv/install.sh | sh`).

**Capabilities** (used by `nix-research-agent` and `nix-implementation-agent`):

| Tool call | Purpose |
|-----------|---------|
| `mcp__nixos__nix(action="search", query="pkgname", source="nixpkgs")` | Package search |
| `mcp__nixos__nix(action="options", query="services.X", source="nixos-options")` | NixOS option lookup |
| `mcp__nixos__nix_versions(package="nodejs")` | Available package versions |

**Graceful degradation**: When MCP is unavailable, agents fall back to WebSearch and CLI commands (`nix search`, `nixos-option`).

## Commands

This extension provides no commands of its own. Use the core `/research`, `/plan`, and `/implement` commands with tasks typed as `nix`.

## Architecture

```
nix/
├── manifest.json              # Extension configuration
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── README.md                  # This file
├── settings-fragment.json     # Permission/allowlist merge fragment
│
├── skills/
│   ├── skill-nix-research/        # Research wrapper
│   └── skill-nix-implementation/  # Implementation wrapper
│
├── agents/
│   ├── nix-research-agent.md      # Nix/flakes research with MCP
│   └── nix-implementation-agent.md # Nix implementation with verification
│
├── rules/
│   └── nix.md                 # Nix coding conventions (auto-applied)
│
└── context/
    └── project/
        └── nix/
            ├── domain/        # Nix language, flakes, NixOS modules
            ├── patterns/      # Modules, overlays, derivations
            ├── standards/     # Style guide
            └── tools/         # nixos-rebuild, home-manager guides
```

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-nix-research | nix-research-agent | NixOS/Home Manager/flakes research with MCP-NixOS |
| skill-nix-implementation | nix-implementation-agent | Nix configuration implementation with verification |

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `nix` | mcp-nixos, WebSearch, WebFetch, Read | Read, Write, Edit, Bash(nix flake check, nixos-rebuild, home-manager) |

## Workflow

```
/research <task>            (task_type: nix)
    |
    v
skill-nix-research -> nix-research-agent
    |  (mcp-nixos package/option search, nixpkgs exploration)
    v
specs/{NNN}_{SLUG}/reports/MM_{slug}.md
    |
    v
/plan <task>
    |
    v
specs/{NNN}_{SLUG}/plans/MM_{slug}.md
    |
    v
/implement <task>
    |
    v
skill-nix-implementation -> nix-implementation-agent
    |  (edits .nix files, runs nix flake check, validates build)
    v
specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md
```

## Output Artifacts

| Phase | Artifact |
|-------|----------|
| Research | `specs/{NNN}_{SLUG}/reports/MM_{slug}.md` |
| Plan | `specs/{NNN}_{SLUG}/plans/MM_{slug}.md` |
| Implementation | `.nix` file edits plus `specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md` |

## Key Patterns

### Flake Workflow

```bash
# Check flake syntax and evaluate outputs
nix flake check

# Show flake outputs
nix flake show

# Build NixOS configuration
nixos-rebuild build --flake .#hostname

# Build Home Manager configuration
home-manager build --flake .#user

# Evaluate specific expression
nix eval .#path
```

The implementation agent runs `nix flake check` after each phase of edits to validate syntax and evaluation.

### Module Pattern

NixOS modules follow the standard function-with-options structure:

```nix
{ config, lib, pkgs, ... }:

{
  options.services.myService = {
    enable = lib.mkEnableOption "my service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
  };

  config = lib.mkIf config.services.myService.enable {
    systemd.services.myService = { ... };
  };
}
```

### Package Validation via MCP

Before adding a package reference to a flake, the research agent verifies existence via `mcp__nixos__nix(action="search", ...)` to avoid typos and confirm the package is available in the target nixpkgs channel.

## Rules Applied

- `nix.md` - Nix coding conventions (auto-applied to `*.nix` files)

## Context References

- `@.claude/extensions/nix/context/project/nix/domain/nix-language.md`
- `@.claude/extensions/nix/context/project/nix/domain/flakes.md`
- `@.claude/extensions/nix/context/project/nix/patterns/module-patterns.md`
- `@.claude/extensions/nix/context/project/nix/tools/nixos-rebuild-guide.md`

## References

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Flakes Wiki](https://nixos.wiki/wiki/Flakes)
- [mcp-nixos project](https://github.com/mcp-nixos/mcp-nixos)
