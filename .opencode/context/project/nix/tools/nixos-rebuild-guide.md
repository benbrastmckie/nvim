# nixos-rebuild Guide

Build and apply NixOS system configurations.

## Common Commands

### switch

Build and immediately activate:

```bash
sudo nixos-rebuild switch --flake .#hostname
```

- Builds the system
- Activates immediately
- Creates boot entry for rollback

### boot

Build and activate on next reboot:

```bash
sudo nixos-rebuild boot --flake .#hostname
```

- Builds the system
- Does NOT activate now
- Sets as default boot entry

### test

Build and activate temporarily:

```bash
sudo nixos-rebuild test --flake .#hostname
```

- Builds the system
- Activates immediately
- Does NOT create boot entry
- Reverts on reboot

### build

Build without activating:

```bash
nixos-rebuild build --flake .#hostname
```

- Builds the system
- No activation, no boot entry
- Good for testing if config builds

## Flake Usage

With flakes (recommended):

```bash
# Current directory flake
sudo nixos-rebuild switch --flake .#hostname

# Specific flake path
sudo nixos-rebuild switch --flake /path/to/config#hostname

# Remote flake
sudo nixos-rebuild switch --flake github:user/config#hostname
```

Without `#hostname`, uses current hostname:

```bash
sudo nixos-rebuild switch --flake .
```

## Rollback

### Immediate Rollback

```bash
# Switch to previous generation
sudo nixos-rebuild switch --rollback
```

### Boot Menu Rollback

1. Reboot system
2. Select previous generation from boot menu
3. If it works, make permanent:

```bash
sudo nix-env --switch-generation <number> -p /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### List Generations

```bash
sudo nix-env --list-generations -p /nix/var/nix/profiles/system
```

## VM Testing

Build a VM for safe testing:

```bash
nixos-rebuild build-vm --flake .#hostname
./result/bin/run-*-vm
```

The VM:
- Boots your configuration
- Has no persistence by default
- Safe for testing changes

## Debugging

### Show Build Output

```bash
sudo nixos-rebuild switch --flake .#hostname --show-trace
```

### Verbose Output

```bash
sudo nixos-rebuild switch --flake .#hostname -L
```

### Dry Run

See what would be built:

```bash
nixos-rebuild dry-build --flake .#hostname
```

### Check Configuration

Evaluate without building:

```bash
nix eval .#nixosConfigurations.hostname.config.services.nginx.enable
```

## Update Workflow

Typical update process:

```bash
# 1. Update flake inputs
nix flake update

# 2. Build to check for issues
nixos-rebuild build --flake .

# 3. Test temporarily
sudo nixos-rebuild test --flake .

# 4. If tests pass, apply permanently
sudo nixos-rebuild switch --flake .

# 5. Commit the flake.lock
git add flake.lock
git commit -m "Update flake inputs"
```

## Remote Deployment

Build locally, deploy remotely:

```bash
nixos-rebuild switch --flake .#remote-host \
  --target-host user@remote-host \
  --use-remote-sudo
```

Or build remotely:

```bash
nixos-rebuild switch --flake .#remote-host \
  --target-host user@remote-host \
  --build-host user@remote-host \
  --use-remote-sudo
```

## Garbage Collection

Clean old generations:

```bash
# Remove all but last 5 generations
sudo nix-collect-garbage --delete-older-than 30d

# Remove specific generation
sudo nix-env --delete-generations 42 -p /nix/var/nix/profiles/system
```

## Quick Reference

| Command | Activates | Boot Entry | Use Case |
|---------|-----------|------------|----------|
| `switch` | Yes | Yes | Normal updates |
| `boot` | No | Yes | Safe updates |
| `test` | Yes | No | Testing changes |
| `build` | No | No | Check if builds |
| `build-vm` | N/A | N/A | Safe testing |
