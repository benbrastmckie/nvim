# Nix Style Guide

Formatting, naming, and best practices for Nix code.

## Official Formatter

**nixfmt** is the official Nix formatter (RFC 166), enforced in Nixpkgs contributions.

```bash
# Format file
nixfmt myfile.nix

# Check formatting
nixfmt --check myfile.nix
```

Available as `pkgs.nixfmt-rfc-style` or `pkgs.nixfmt`.

## Indentation

- Use 2 spaces (no tabs)
- Align continuation lines logically

```nix
# Good
{
  services.nginx = {
    enable = true;
    virtualHosts = {
      "example.com" = {
        root = /var/www;
      };
    };
  };
}

# Bad - inconsistent indentation
{
services.nginx = {
    enable = true;
  virtualHosts = { };
};
}
```

## Attribute Sets

Single attribute on one line:

```nix
{ enable = true; }
```

Multiple attributes on separate lines:

```nix
{
  enable = true;
  port = 8080;
  host = "localhost";
}
```

## Lists

Short lists on one line:

```nix
[ "vim" "git" "curl" ]
```

Long lists on multiple lines:

```nix
[
  "vim"
  "git"
  "curl"
  "ripgrep"
  "fd"
]
```

## Function Arguments

Short arguments on one line:

```nix
{ pkgs, lib }: { ... }
```

Many arguments on multiple lines:

```nix
{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Packages | lowercase-hyphen | `claude-code`, `my-package` |
| Options | dot.separated.path | `services.nginx.enable` |
| Variables | camelCase or snake_case | `myVar`, `my_var` |
| Modules | lowercase-hyphen.nix | `mcp-hub.nix` |
| Let bindings | camelCase | `let myValue = 1;` |

## Inherit Usage

Prefer `inherit` over repetition:

```nix
# Good
{ inherit pkgs lib config; }

# Avoid
{ pkgs = pkgs; lib = lib; config = config; }
```

Inherit from sets for clarity:

```nix
# Good - clear where values come from
let
  cfg = config.services.myservice;
in {
  inherit (cfg) port host;
}
```

## Avoid `with`

`with` is discouraged - makes code harder to read:

```nix
# Bad - unclear where vim, git come from
home.packages = with pkgs; [ vim git curl ];

# Better - explicit
home.packages = [ pkgs.vim pkgs.git pkgs.curl ];

# Also good - inherit in let
let
  inherit (pkgs) vim git curl;
in {
  home.packages = [ vim git curl ];
}
```

Exception: Short, clear contexts like `with lib;` at module top.

## Avoid Unnecessary `rec`

`rec` enables self-reference but has risks:

```nix
# Bad - rec not needed
rec {
  x = 1;
  y = 2;
}

# Bad - potential infinite recursion
rec {
  a = b + 1;
  b = a + 1;  # Infinite loop!
}

# Good - use let when you need references
let
  x = 1;
  y = x + 1;
in { inherit x y; }
```

## String Interpolation

Use `${...}` for interpolation:

```nix
# Good
"Hello, ${name}!"

# Avoid string concatenation
"Hello, " + name + "!"
```

Multi-line strings:

```nix
''
  Line 1
  Value: ${toString value}
  Line 3
''
```

## Comments

```nix
# Single line comment

/* Multi-line
   comment */

# Document options
port = lib.mkOption {
  type = lib.types.port;
  default = 8080;
  description = "Port to listen on";  # Use description field
};
```

## Anti-Patterns

### Deep Nesting

```nix
# Bad - hard to read
config.services.nginx.virtualHosts."example.com".locations."/".proxyPass = "...";

# Better - use intermediate variables
let
  vhost = config.services.nginx.virtualHosts."example.com";
in vhost.locations."/".proxyPass
```

### Missing Defaults

```nix
# Bad - will fail if option not set
config = {
  myService.package = cfg.customPackage;
};

# Good - provide sensible default
myService.package = cfg.customPackage or pkgs.defaultPackage;
```

### Hardcoded Paths

```nix
# Bad
src = /home/user/project;

# Good - use fetchFromGitHub or relative path
src = ./project;
src = fetchFromGitHub { ... };
```

## File Organization

```
.
├── flake.nix              # Entry point, inputs/outputs
├── flake.lock             # Pinned inputs (auto-generated)
├── configuration.nix      # NixOS system config
├── home.nix               # Home Manager config
├── hosts/                 # Per-host configurations
│   ├── desktop/
│   │   └── hardware-configuration.nix
│   └── laptop/
│       └── hardware-configuration.nix
├── modules/               # Custom NixOS modules
├── home-modules/          # Custom Home Manager modules
└── packages/              # Custom package definitions
    └── mypackage.nix
```

## Module Structure

```nix
# Standard module layout
{ config, lib, pkgs, ... }:

let
  cfg = config.services.myservice;
in {
  # 1. Options first
  options.services.myservice = { ... };

  # 2. Config second
  config = lib.mkIf cfg.enable { ... };
}
```
