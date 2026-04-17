---
paths: ["**/*.nix"]
---

# Nix Development Rules

## Path Pattern

Applies to: `**/*.nix`

## Formatting Standards

### Indentation
- Use 2 spaces for indentation
- Never use tabs
- Soft line limit: 100 characters (excluding leading indentation)

### Expression Layout
- Single-line expressions that fit must remain on one line
- Multi-line lists/attributes require each item on its own line
- Empty sets/lists format compactly: `{}` or `[]`
- First items cannot be placed alongside opening brackets

### Comments
- Use `#` line comments for documentation
- Block comments `/* */` should convert to line comments
- Multiline comments: delimiters on separate lines, content indented

## Module Patterns

### NixOS Module Structure
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.myService;
in {
  options.services.myService = {
    enable = lib.mkEnableOption "my service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    # configuration here
  };
}
```

### Home Manager Module Structure
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.myProgram;
in {
  options.programs.myProgram = {
    enable = lib.mkEnableOption "my program";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.myProgram ];
  };
}
```

### Standard Function Signatures
Always use the `{ config, lib, pkgs, ... }:` pattern:
```nix
{ config, lib, pkgs, ... }:
# module body
```

### Options Definition
Always specify `type`, `default`, and `description`:
```nix
myOption = lib.mkOption {
  type = lib.types.str;
  default = "";
  description = "Description of the option";
};
```

### Priority Functions
- `lib.mkDefault` - Set overridable defaults
- `lib.mkForce` - Override values forcefully
- `lib.mkBefore` / `lib.mkAfter` - Control merge order for lists

## Flake Conventions

### Input Patterns
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # Follow pattern for consistency
  home-manager.url = "github:nix-community/home-manager";
  home-manager.inputs.nixpkgs.follows = "nixpkgs";

  # Non-flake input
  neovim-config = {
    url = "github:user/config";
    flake = false;
  };
};
```

### Output Schema
```nix
outputs = { self, nixpkgs, ... }@inputs: {
  nixosConfigurations."hostname" = nixpkgs.lib.nixosSystem { ... };
  homeConfigurations."user" = home-manager.lib.homeManagerConfiguration { ... };
  packages."x86_64-linux".default = derivation;
  devShells."x86_64-linux".default = derivation;
  overlays.default = final: prev: { ... };
};
```

### Overlay Patterns
Use `final`/`prev` naming (not the deprecated `self`/`super`):
```nix
overlays.default = final: prev: {
  myPackage = prev.myPackage.overrideAttrs (oldAttrs: {
    # overrides
  });
};
```

## Naming Conventions

| Entity | Convention | Examples |
|--------|------------|----------|
| Package names | lowercase with hyphens | `my-package`, `claude-code` |
| Options paths | dot-separated | `services.myService.enable` |
| Variables | snake_case | `cfg`, `pkgs_unstable`, `my_overlay` |
| Attribute names | camelCase (nixpkgs) | `buildInputs`, `extraGroups` |
| Module arguments | lowercase | `config`, `lib`, `pkgs` |
| Overlay variables | `final`, `prev` | (not `self`, `super`) |

## Common Patterns

### Conditional Configuration
```nix
config = lib.mkIf cfg.enable {
  # applied only when enabled
};
```

### Let Bindings
Use for local definitions:
```nix
let
  cfg = config.services.myService;
  pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
in {
  # use cfg and pkgs-unstable
}
```

### Inherit
Use to reduce repetition:
```nix
{ inherit (pkgs) git vim; }
# equivalent to: { git = pkgs.git; vim = pkgs.vim; }
```

### Package Overrides
```nix
myPackage = pkgs.myPackage.override {
  enableFeature = true;
};

myPackage = pkgs.myPackage.overrideAttrs (oldAttrs: {
  patches = oldAttrs.patches ++ [ ./my-patch.patch ];
});
```

## Testing and Verification

### Build Commands
```bash
# Check flake syntax and evaluate
nix flake check

# Build NixOS configuration
nixos-rebuild build --flake .#hostname

# Build Home Manager configuration
home-manager build --flake .#user

# Evaluate without building
nix eval .#nixosConfigurations.hostname.config.services
```

### Common Debug Commands
```bash
# Show flake outputs
nix flake show

# Enter a shell with dependencies
nix develop

# Build a specific package
nix build .#myPackage
```

## Do Not

- Use top-level `with pkgs;` (static analysis fails, unclear origins)
- Use `rec { ... }` (risk of infinite recursion, use `let ... in` instead)
- Use lookup paths `<nixpkgs>` (depends on external $NIX_PATH)
- Use bare URLs (RFC 45 deprecation; quote all URLs: `"https://..."`)
- Use `//` for nested updates (shallow merge loses nested data; use `lib.recursiveUpdate`)
- Hardcode store paths (non-reproducible)
- Omit type annotations in `mkOption` (validation failures)
- Use deprecated overlay variables `self`/`super` (use `final`/`prev`)

## Related Context

Load for detailed patterns:
- `@.claude/context/project/nix/domain/nix-language.md`
- `@.claude/context/project/nix/domain/flakes.md`
- `@.claude/context/project/nix/domain/nixos-modules.md`
- `@.claude/context/project/nix/domain/home-manager.md`
- `@.claude/context/project/nix/patterns/module-patterns.md`
- `@.claude/context/project/nix/patterns/overlay-patterns.md`
- `@.claude/context/project/nix/patterns/derivation-patterns.md`
- `@.claude/context/project/nix/standards/nix-style-guide.md`
