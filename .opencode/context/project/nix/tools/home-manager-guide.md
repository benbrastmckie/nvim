# Home Manager Guide

Manage user environment and dotfiles.

## Installation Modes

### As NixOS Module

Home Manager integrated into NixOS rebuild:

```nix
# In flake.nix
home-manager.nixosModules.home-manager {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.user = import ./home.nix;
}
```

Rebuild applies both system and user config:

```bash
sudo nixos-rebuild switch --flake .#hostname
```

### Standalone

Separate from NixOS:

```nix
# In flake.nix
homeConfigurations.user = home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [ ./home.nix ];
};
```

Switch user config independently:

```bash
home-manager switch --flake .#user
```

## Commands

### switch

Build and activate home configuration:

```bash
# Standalone mode
home-manager switch --flake .#username

# With verbose output
home-manager switch --flake .#username -b backup
```

The `-b backup` flag backs up existing files that would be replaced.

### build

Build without activating:

```bash
home-manager build --flake .#username
```

Useful for checking if configuration builds.

### generations

List all generations:

```bash
home-manager generations
```

Output example:

```
2024-01-15 10:30 : id 42 -> /nix/store/...-home-manager-generation
2024-01-14 09:00 : id 41 -> /nix/store/...-home-manager-generation
```

### news

Show release news and changes:

```bash
home-manager news
```

## Rollback

### To Previous Generation

```bash
# List generations
home-manager generations

# Activate specific generation
/nix/store/...-home-manager-generation/activate
```

Or use the generation path from `generations` output.

### Via NixOS (Module Mode)

When using Home Manager as NixOS module:

```bash
# System rollback includes home config
sudo nixos-rebuild switch --rollback
```

## Configuration Options

### useGlobalPkgs

Share package set with NixOS:

```nix
home-manager.useGlobalPkgs = true;
```

Benefits:
- Consistent packages between system and user
- Overlays applied once
- Faster evaluation

### useUserPackages

Install packages to user profile:

```nix
home-manager.useUserPackages = true;
```

Packages appear in `~/.nix-profile/bin/`.

### extraSpecialArgs

Pass extra arguments to home.nix:

```nix
home-manager.extraSpecialArgs = {
  inherit pkgs-unstable;
};
```

Access in home.nix:

```nix
{ config, pkgs, pkgs-unstable, ... }:
{
  programs.neovim.package = pkgs-unstable.neovim-unwrapped;
}
```

## Debugging

### Check Configuration

```bash
# Evaluate specific option
nix eval .#homeConfigurations.user.config.programs.git.enable

# Show all managed files
home-manager build --flake .#user
ls -la result/home-files/
```

### Verbose Build

```bash
home-manager switch --flake .#user --show-trace
```

### Conflicts

When files conflict with existing dotfiles:

```bash
# Back up existing files
home-manager switch --flake .#user -b backup

# Files backed up to original-name.backup
```

## Common Patterns

### Program with Custom Config

```nix
programs.git = {
  enable = true;
  userName = "User";
  userEmail = "user@example.com";
};
```

### Mixed Stable/Unstable

```nix
{ pkgs, pkgs-unstable, ... }:
{
  home.packages = [
    pkgs.ripgrep           # Stable
    pkgs-unstable.neovim   # Unstable
  ];
}
```

### Conditional Config

```nix
{ config, lib, pkgs, ... }:
{
  programs.fish.enable = true;

  # Only if fish is enabled
  programs.starship = lib.mkIf config.programs.fish.enable {
    enable = true;
    enableFishIntegration = true;
  };
}
```

## File Locations

| Path | Purpose |
|------|---------|
| `~/.local/state/home-manager/` | Generations and state |
| `~/.nix-profile/` | User packages (if useUserPackages) |
| `~/.config/` | XDG config files (managed) |

## Quick Reference

| Command | Purpose |
|---------|---------|
| `home-manager switch` | Build and activate |
| `home-manager build` | Build only |
| `home-manager generations` | List generations |
| `home-manager news` | Show news |
| `home-manager packages` | List installed packages |
