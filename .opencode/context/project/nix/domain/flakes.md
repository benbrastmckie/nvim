# Flakes Reference

Nix flakes for reproducible, composable configurations.

## Basic Structure

```nix
{
  description = "System configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}
```

## Inputs

### URL Formats

```nix
inputs = {
  # GitHub
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # Git repository
  myrepo.url = "git+https://example.com/repo.git";

  # Local path
  local.url = "path:/home/user/project";

  # Specific revision
  pinned.url = "github:NixOS/nixpkgs/abc123";

  # Flake in subdirectory
  subdir.url = "github:owner/repo?dir=subdir";
};
```

### Input Following

Ensure consistent nixpkgs across inputs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager.url = "github:nix-community/home-manager/master";
  home-manager.inputs.nixpkgs.follows = "nixpkgs";  # Use our nixpkgs

  # Other inputs also follow nixpkgs
  some-flake.url = "github:user/flake";
  some-flake.inputs.nixpkgs.follows = "nixpkgs";
};
```

## Outputs Schema

```nix
outputs = { self, nixpkgs, ... }: {
  # NixOS system configurations
  nixosConfigurations.hostname = nixpkgs.lib.nixosSystem { ... };

  # Home Manager configurations (standalone)
  homeConfigurations.username = home-manager.lib.homeManagerConfiguration { ... };

  # Packages
  packages.x86_64-linux.default = ...;
  packages.x86_64-linux.mypackage = ...;

  # Development shells
  devShells.x86_64-linux.default = ...;

  # Overlays
  overlays.default = final: prev: { ... };

  # NixOS modules
  nixosModules.default = { ... };

  # Library functions
  lib.myFunction = ...;
};
```

## NixOS Configuration

Example multi-host configuration:

```nix
nixosConfigurations = {
  desktop = lib.nixosSystem {
    inherit system;
    modules = [
      ./configuration.nix
      ./hosts/desktop/hardware-configuration.nix
      { networking.hostName = "desktop"; }

      # Apply overlays
      { nixpkgs = nixpkgsConfig; }

      # Home Manager as NixOS module
      home-manager.nixosModules.home-manager {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.user = import ./home.nix;
        home-manager.extraSpecialArgs = {
          inherit pkgs-unstable;
        };
      }
    ];
    specialArgs = {
      inherit username;
      inherit pkgs-unstable;
    };
  };
};
```

## Lock File (flake.lock)

Auto-generated, pins inputs to specific revisions.

### Update Commands

```bash
# Update all inputs
nix flake update

# Update single input
nix flake lock --update-input nixpkgs

# Show current inputs
nix flake metadata
```

## specialArgs vs extraSpecialArgs

Pass extra arguments to modules:

```nix
# For NixOS modules
specialArgs = {
  inherit username;
  inherit pkgs-unstable;
};

# For Home Manager modules (when using as NixOS module)
home-manager.extraSpecialArgs = {
  inherit pkgs-unstable;
};
```

Access in modules:

```nix
{ config, pkgs, pkgs-unstable, ... }:  # pkgs-unstable from extraSpecialArgs
```

## Multiple Hosts

```nix
nixosConfigurations = {
  desktop = lib.nixosSystem {
    modules = [
      ./configuration.nix
      ./hosts/desktop/hardware-configuration.nix
      { networking.hostName = "desktop"; }
    ];
  };

  laptop = lib.nixosSystem {
    modules = [
      ./configuration.nix
      ./hosts/laptop/hardware-configuration.nix
      { networking.hostName = "laptop"; }
    ];
  };
};
```

## Common Patterns

### Overlay Application

```nix
let
  nixpkgsConfig = {
    inherit system;
    config.allowUnfree = true;
    overlays = [
      myOverlay
      unstableOverlay
    ];
  };
  pkgs = import nixpkgs nixpkgsConfig;
in {
  nixosConfigurations.host = lib.nixosSystem {
    modules = [
      { nixpkgs = nixpkgsConfig; }
      ./configuration.nix
    ];
  };
}
```

### Unstable Packages

```nix
let
  pkgs-unstable = import nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in {
  # Pass to modules via specialArgs
  specialArgs = { inherit pkgs-unstable; };
}
```

## Debugging

```bash
# Show flake outputs
nix flake show

# Evaluate specific output
nix eval .#nixosConfigurations.hostname.config.system.stateVersion

# Build without switching
nix build .#nixosConfigurations.hostname.config.system.build.toplevel
```
