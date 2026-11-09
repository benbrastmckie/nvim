## Nix Extension

NixOS and Home Manager configuration support with MCP-NixOS integration for package/option
validation.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `nix` | MCP-NixOS, WebSearch, WebFetch, Read | Read, Write, Edit, Bash (nix flake check, nixos-rebuild, home-manager) |

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-nix-research | nix-research-agent | sonnet | NixOS/Home Manager/flakes research with MCP-NixOS |
| skill-nix-implementation | nix-implementation-agent | sonnet | Nix configuration implementation with verification |

### Commands

This extension provides no dedicated slash commands. Tasks with `task_type: nix` route through
the core lifecycle phases (research, plan, implement -- dispatched via `/orchestrate`) using the
skill-agent mappings above.

### Context

- `context/project/nix/README.md` - Key technologies, directory map, loading strategy
- `context/project/nix/domain/flakes.md` - Flake structure, inputs/outputs, build verification
- `context/project/nix/tools/nixos-rebuild-guide.md` - System rebuild, testing, rollback
- `context/project/nix/tools/home-manager-guide.md` - Home Manager CLI and configuration workflows
- `context/project/nix/tools/mcp-nixos-integration.md` - MCP-NixOS tools and CLI fallbacks
