# Overlay Patterns

Customize and extend the Nixpkgs package set.

## Basic Structure

```nix
final: prev: {
  # Your modifications here
}
```

- `final` (or `self`): The final package set after all overlays
- `prev` (or `super`): The package set before this overlay

## Add New Package

```nix
final: prev: {
  mypackage = final.callPackage ./mypackage.nix {};
}
```

Use `final.callPackage` to get dependencies from final set.

## Override Existing Package

Change build options:

```nix
final: prev: {
  vim = prev.vim.override {
    guiSupport = false;
    pythonSupport = true;
  };
}
```

Use `prev.vim` to reference the original package.

## Override Attributes

Modify derivation attributes:

```nix
final: prev: {
  hello = prev.hello.overrideAttrs (old: {
    version = "2.12";
    src = final.fetchFromGitHub {
      owner = "...";
      repo = "hello";
      rev = "v2.12";
      sha256 = "...";
    };
    # Can reference old attributes
    buildInputs = old.buildInputs ++ [ final.newdep ];
  });
}
```

## Go Package Overlay

Building a Go package:

```nix
myGoOverlay = final: prev: {
  mygoapp = final.buildGoModule rec {
    pname = "mygoapp";
    version = "1.0.0";

    src = final.fetchFromGitHub {
      owner = "owner";
      repo = "mygoapp";
      rev = "v${version}";
      sha256 = "sha256-...";
    };

    vendorHash = "sha256-...";

    nativeBuildInputs = with final; [ go ];
    buildInputs = with final; [ ];

    postInstall = ''
      ln -s $out/bin/mygoapp $out/bin/mga
    '';
  };
};
```

## Unstable Packages Overlay

Mix stable and unstable packages:

```nix
unstablePackagesOverlay = final: prev: {
  # Use package from unstable channel
  neovim = pkgs-unstable.neovim;

  # Custom wrapper scripts
  my-tool = final.callPackage ./packages/my-tool.nix {};

  # Override existing package
  mypackage = import ./packages/mypackage.nix prev.mypackage final.gst_all_1;
};
```

## Python Packages Overlay

Add custom Python packages:

```nix
pythonPackagesOverlay = final: prev:
let
  customPythonPackages = pySelf: pySuper: {
    mypackage = pySelf.callPackage ./packages/python-mypackage.nix {};
  };
in {
  python3 = prev.python3.override {
    packageOverrides = customPythonPackages;
  };
  python312 = prev.python312.override {
    packageOverrides = customPythonPackages;
  };
};
```

## Applying Overlays

### In flake.nix

```nix
let
  nixpkgsConfig = {
    inherit system;
    config.allowUnfree = true;
    overlays = [
      overlay1
      overlay2
      overlay3
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

### Order Matters

Overlays are applied in order:

```nix
overlays = [
  # First: base packages
  baseOverlay
  # Second: modifications (can reference base)
  modificationOverlay
  # Third: final adjustments
  finalOverlay
];
```

## final vs prev

Use **`final`** when:
- Getting dependencies for a new package
- Referencing packages that might be modified by later overlays

Use **`prev`** when:
- Overriding an existing package
- Accessing the "original" version before modification

```nix
final: prev: {
  # Use prev for the package being overridden
  vim = prev.vim.override { ... };

  # Use final for dependencies (gets latest version)
  mypackage = final.stdenv.mkDerivation {
    buildInputs = [ final.openssl ];  # Gets potentially-overlaid openssl
  };
}
```

## Debugging Overlays

```bash
# Check if package exists
nix eval .#nixosConfigurations.host.pkgs.mypackage.name

# Build package directly
nix build .#nixosConfigurations.host.pkgs.mypackage

# Show package derivation
nix show-derivation .#nixosConfigurations.host.pkgs.mypackage
```

## Common Patterns

### Wrapper Script

```nix
final: prev: {
  mycommand = final.writeShellScriptBin "mycommand" ''
    exec ${final.actualpackage}/bin/actual "$@"
  '';
}
```

### Pin to Specific Version

```nix
final: prev: {
  nodejs = prev.nodejs_18;  # Pin to Node.js 18
}
```

### Add Patches

```nix
final: prev: {
  package = prev.package.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./my-fix.patch
    ];
  });
}
```
