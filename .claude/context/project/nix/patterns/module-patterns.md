# Module Patterns

Common NixOS and Home Manager module patterns.

## Enable Pattern

Standard pattern for optional features:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.myservice;
in {
  options.services.myservice = {
    enable = lib.mkEnableOption "my service";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.mypackage ];
    systemd.services.myservice = { ... };
  };
}
```

**Key points**:
- Use `mkEnableOption` for the enable flag
- Wrap all config in `mkIf cfg.enable`
- Extract `cfg` in `let` for cleaner code

## Package Override Pattern

Allow users to specify custom package:

```nix
options.services.myservice = {
  enable = lib.mkEnableOption "my service";

  package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.mypackage;
    description = "Package to use for my service";
  };
};

config = lib.mkIf cfg.enable {
  environment.systemPackages = [ cfg.package ];
};
```

Usage:

```nix
services.myservice = {
  enable = true;
  package = pkgs-unstable.mypackage;  # Use unstable version
};
```

## Conditional Configuration

Multiple conditions with `mkMerge`:

```nix
config = lib.mkMerge [
  # Always applied when enabled
  (lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  })

  # Only when extra features enabled
  (lib.mkIf (cfg.enable && cfg.enableExtras) {
    environment.systemPackages = [ pkgs.extras ];
  })

  # Platform-specific
  (lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    systemd.services.myservice = { ... };
  })
];
```

## Submodule Pattern

Nested configuration for multiple instances:

```nix
options.services.virtualHosts = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule {
    options = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 80;
      };
      root = lib.mkOption {
        type = lib.types.path;
      };
      ssl = lib.mkEnableOption "SSL";
    };
  });
  default = {};
};

config = lib.mkIf (cfg.virtualHosts != {}) {
  networking.firewall.allowedTCPPorts =
    lib.mapAttrsToList (name: host: host.port) cfg.virtualHosts;
};
```

Usage:

```nix
services.virtualHosts = {
  "example.com" = {
    port = 443;
    root = /var/www/example;
    ssl = true;
  };
  "api.example.com" = {
    port = 8080;
    root = /var/www/api;
  };
};
```

## Home Manager Module Example

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.myprogram;
in {
  options.programs.myprogram = {
    enable = mkEnableOption "my program";

    package = mkOption {
      type = types.package;
      default = pkgs.myprogram;
      description = "The package to use";
    };

    port = mkOption {
      type = types.int;
      default = 8080;
      description = "Port to listen on";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.sessionVariables = {
      MY_PROGRAM_PORT = toString cfg.port;
    };

    xdg.configFile."myprogram/.keep".text = "";
  };
}
```

## Default Values Pattern

Use `mkDefault` for overrideable defaults:

```nix
config = lib.mkIf cfg.enable {
  # Low priority - can be overridden by user
  services.nginx.enable = lib.mkDefault true;

  # Normal priority
  services.nginx.virtualHosts.${cfg.domain} = { ... };
};
```

## Module Composition

Split large modules:

```nix
# main.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ./options.nix
    ./config.nix
  ];
}

# options.nix
{ lib, ... }:
{
  options.services.myservice = {
    enable = lib.mkEnableOption "my service";
    # ... more options
  };
}

# config.nix
{ config, lib, pkgs, ... }:
let cfg = config.services.myservice;
in {
  config = lib.mkIf cfg.enable {
    # ... configuration
  };
}
```

## Assertions

Validate configuration:

```nix
config = lib.mkIf cfg.enable {
  assertions = [
    {
      assertion = cfg.port > 1024 || config.security.sudo.wheelNeedsPassword;
      message = "Ports below 1024 require elevated privileges";
    }
  ];

  # ... rest of config
};
```

## Warnings

Non-fatal messages:

```nix
config = lib.mkIf cfg.enable {
  warnings = lib.optional (cfg.deprecated)
    "services.myservice.deprecated is deprecated, use newOption instead";
};
```
