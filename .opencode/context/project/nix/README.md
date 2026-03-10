# Nix Context

Domain knowledge for NixOS and Home Manager configuration development.

## Directory Structure

```
project/nix/
├── README.md                    # This file
├── domain/                      # Core Nix concepts
│   ├── nix-language.md         # Nix expression syntax
│   ├── flakes.md               # Flake structure and inputs
│   ├── nixos-modules.md        # NixOS module system
│   └── home-manager.md         # Home Manager modules
├── patterns/                    # Implementation patterns
│   ├── module-patterns.md      # Module definition patterns
│   ├── overlay-patterns.md     # Overlay patterns
│   └── derivation-patterns.md  # Package derivation patterns
├── standards/                   # Coding standards
│   └── nix-style-guide.md      # Formatting, naming conventions
└── tools/                       # Tool-specific guides
    ├── nixos-rebuild-guide.md  # System rebuild workflows
    └── home-manager-guide.md   # Home Manager workflows
```

## Loading Strategy

**Always load first**:
- This README for overview
- `domain/nix-language.md` for Nix syntax fundamentals

**Load for flake work**:
- `domain/flakes.md` for inputs, outputs, follows patterns

**Load for system configuration**:
- `domain/nixos-modules.md` for options, config, mkIf

**Load for user configuration**:
- `domain/home-manager.md` for programs, services, files

**Load for package work**:
- `patterns/overlay-patterns.md` for adding/modifying packages
- `patterns/derivation-patterns.md` for building packages

## Configuration Assumptions

This context assumes:
- NixOS with flakes enabled
- Home Manager as NixOS module or standalone
- Nixpkgs unstable channel
- Standard flake structure (flake.nix at repo root)

## Key Concepts

### Flakes

Flakes provide reproducible, hermetic builds:
- Explicit inputs with lock file
- Standardized outputs schema
- Input following for consistency

### Module System

NixOS uses a modular configuration:
- Options declare interfaces
- Config provides implementations
- Imports compose modules

### Home Manager

User-level configuration management:
- Programs configuration (git, neovim, etc.)
- User services (systemd user units)
- Dotfile management

### Overlays

Customize the package set:
- Override existing packages
- Add new packages
- Modify build inputs

## Agent Context Loading

Agents should load context based on task type:

| Task Type | Required Context |
|-----------|-----------------|
| New package | derivation-patterns.md, overlay-patterns.md |
| System config | nixos-modules.md, module-patterns.md |
| User config | home-manager.md, module-patterns.md |
| Flake changes | flakes.md |
| General | nix-language.md, nix-style-guide.md |
