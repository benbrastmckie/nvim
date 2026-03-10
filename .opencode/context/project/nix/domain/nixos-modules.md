# NixOS Module System

Modular configuration with options and config.

## Module Structure

Basic module anatomy:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.myservice;
in {
  options.services.myservice = {
    enable = lib.mkEnableOption "my service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.myservice = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.mypackage}/bin/myservice --port ${toString cfg.port}";
    };
  };
}
```

## Module Arguments

Standard arguments available in all modules:

| Argument | Description |
|----------|-------------|
| `config` | Final merged configuration |
| `lib` | Nixpkgs library functions |
| `pkgs` | Package set (with overlays) |
| `options` | All declared options |
| `modulesPath` | Path to nixpkgs/nixos/modules |

Extra arguments via `specialArgs`:

```nix
# In flake.nix
specialArgs = { inherit pkgs-unstable; };

# In module
{ config, pkgs, pkgs-unstable, ... }:
```

## Declaring Options

### mkOption

```nix
options.mymodule = {
  setting = lib.mkOption {
    type = lib.types.str;
    default = "value";
    example = "example";
    description = "Description of the option";
  };
};
```

### mkEnableOption

Shorthand for boolean enable flags:

```nix
options.services.myservice.enable = lib.mkEnableOption "my service";
# Equivalent to:
# enable = lib.mkOption {
#   type = lib.types.bool;
#   default = false;
#   description = "Whether to enable my service";
# };
```

## Common Types

```nix
lib.types.bool                    # true or false
lib.types.str                     # String
lib.types.int                     # Integer
lib.types.port                    # Valid port number (1-65535)
lib.types.path                    # File system path
lib.types.package                 # Nix package

lib.types.listOf types.str        # List of strings
lib.types.attrsOf types.int       # Attribute set of integers
lib.types.nullOr types.str        # String or null
lib.types.enum [ "a" "b" "c" ]    # One of enumerated values
lib.types.oneOf [ types.str types.int ]  # Multiple possible types

lib.types.submodule {             # Nested module
  options = { ... };
}
```

## Configuration Functions

### mkIf

Conditional configuration (avoids infinite recursion):

```nix
config = lib.mkIf cfg.enable {
  environment.systemPackages = [ pkgs.mypackage ];
};
```

### mkMerge

Combine multiple config sets:

```nix
config = lib.mkMerge [
  { environment.systemPackages = [ pkgs.base ]; }
  (lib.mkIf cfg.enableExtra {
    environment.systemPackages = [ pkgs.extra ];
  })
];
```

### mkDefault

Lower priority default (can be overridden):

```nix
config = {
  services.nginx.enable = lib.mkDefault true;
};
```

### mkForce

Override all other definitions:

```nix
config = {
  services.nginx.enable = lib.mkForce false;
};
```

### mkOverride

Set specific priority (lower = higher priority):

```nix
lib.mkOverride 100 value  # Same as mkDefault
lib.mkOverride 50 value   # Same as mkForce
lib.mkOverride 1000 value # Lowest priority
```

## Imports

Include other modules:

```nix
{ config, ... }:
{
  imports = [
    ./submodule.nix
    ./hardware-configuration.nix
  ];

  # Config here
}
```

## Submodules

Nested configuration options:

```nix
options.services.myservice.hosts = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule {
    options = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 80;
      };
      root = lib.mkOption {
        type = lib.types.path;
      };
    };
  });
  default = {};
};
```

Usage:

```nix
services.myservice.hosts = {
  "example.com" = {
    port = 443;
    root = /var/www/example;
  };
};
```

## Module Evaluation Order

1. All imports are collected
2. All options are declared
3. All config values are defined
4. Values are merged by priority
5. Final config is built
