# Derivation Patterns

Building packages with Nix.

## Basic mkDerivation

```nix
{ lib, stdenv, fetchFromGitHub, cmake, openssl }:

stdenv.mkDerivation {
  pname = "mypackage";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v1.0.0";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ cmake ];  # Build-time tools
  buildInputs = [ openssl ];       # Libraries to link against

  meta = with lib; {
    description = "My package description";
    homepage = "https://example.com";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
```

## Build Phases

Standard phases in order:

1. **unpackPhase** - Extract source
2. **patchPhase** - Apply patches
3. **configurePhase** - Run ./configure or cmake
4. **buildPhase** - Compile (make)
5. **checkPhase** - Run tests
6. **installPhase** - Install to $out
7. **fixupPhase** - Post-processing

Override any phase:

```nix
stdenv.mkDerivation {
  # ...

  configurePhase = ''
    ./custom-configure --prefix=$out
  '';

  buildPhase = ''
    make -j$NIX_BUILD_CORES
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp myprogram $out/bin/
  '';
}
```

## Wrapper Scripts

Simple wrappers:

```nix
{ lib, writeShellScriptBin, nodejs }:

writeShellScriptBin "mytool" ''
  exec ${nodejs}/bin/npx my-tool@latest "$@"
''
```

## Go Packages

Using `buildGoModule`:

```nix
{ lib, buildGoModule, fetchFromGitHub, tmux, gh }:

buildGoModule rec {
  pname = "mygoapp";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "mygoapp";
    rev = "v${version}";
    sha256 = "sha256-...";
  };

  vendorHash = "sha256-...";

  nativeBuildInputs = [ go ];
  buildInputs = [ tmux gh ];

  postInstall = ''
    ln -s $out/bin/mygoapp $out/bin/mga
  '';

  meta = with lib; {
    description = "My Go application";
    homepage = "https://github.com/owner/mygoapp";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
```

## Python Packages

### Using buildPythonPackage

```nix
{ lib, buildPythonPackage, fetchPypi, numpy }:

buildPythonPackage rec {
  pname = "mypackage";
  version = "1.0.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-...";
  };

  propagatedBuildInputs = [ numpy ];

  pythonImportsCheck = [ "mypackage" ];

  meta = with lib; {
    description = "My Python package";
    license = licenses.mit;
  };
}
```

### Wheel Package

```nix
{ lib, buildPythonPackage, fetchurl, ... }:

buildPythonPackage rec {
  pname = "mypackage";
  version = "1.0.0";
  format = "wheel";

  src = fetchurl {
    url = "https://.../${pname}-${version}-py3-none-manylinux_2_17_x86_64.whl";
    sha256 = "sha256-...";
  };

  pythonImportsCheck = [ "mypackage" ];
}
```

## Fetchers

### fetchFromGitHub

```nix
src = fetchFromGitHub {
  owner = "owner";
  repo = "repo";
  rev = "v${version}";  # or commit hash
  sha256 = "sha256-...";
};
```

### fetchurl

```nix
src = fetchurl {
  url = "https://example.com/package-${version}.tar.gz";
  sha256 = "sha256-...";
};
```

### fetchgit

```nix
src = fetchgit {
  url = "https://git.example.com/repo.git";
  rev = "abc123...";
  sha256 = "sha256-...";
};
```

## Getting Hash Values

```bash
# For fetchFromGitHub
nix-prefetch-github owner repo --rev v1.0.0

# For fetchurl
nix-prefetch-url https://example.com/file.tar.gz

# Let Nix tell you (use fake hash first)
# Set sha256 = "" or sha256 = lib.fakeSha256
# Build will fail and show correct hash
```

## nativeBuildInputs vs buildInputs

| Attribute | Purpose | Examples |
|-----------|---------|----------|
| `nativeBuildInputs` | Build-time tools (run on build machine) | cmake, pkg-config, makeWrapper |
| `buildInputs` | Libraries to link against | openssl, zlib, curl |
| `propagatedBuildInputs` | Dependencies exposed to downstream | (for libraries) |

## Post-Processing

### makeWrapper

Add environment variables or paths:

```nix
{ makeWrapper, lib }:

stdenv.mkDerivation {
  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/myprogram \
      --prefix PATH : ${lib.makeBinPath [ dep1 dep2 ]} \
      --set MY_VAR "value"
  '';
}
```

### Symlinks

```nix
postInstall = ''
  ln -s $out/bin/longname $out/bin/short
'';
```

## Debugging Builds

```bash
# Enter build environment
nix-shell -p mypackage

# Build with verbose output
nix build .#mypackage -L

# Keep failed build directory
nix build .#mypackage --keep-failed

# Show derivation
nix show-derivation .#mypackage
```
