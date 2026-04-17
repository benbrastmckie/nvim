# Nix Language Reference

Core Nix expression language syntax.

## Let Expressions

Local bindings with `let...in`:

```nix
let
  x = 1;
  y = 2;
in x + y  # => 3
```

Bindings can reference each other in any order:

```nix
let
  b = a + 1;  # Forward reference OK
  a = 1;
in b  # => 2
```

## Attribute Sets

Key-value collections (like objects/dicts):

```nix
{
  name = "example";
  version = "1.0";
  nested.value = 42;  # Creates { nested = { value = 42; }; }
}
```

Access with `.`:

```nix
let attrs = { x = 1; y = 2; };
in attrs.x  # => 1
```

Optional access with `or`:

```nix
attrs.missing or "default"  # => "default" if missing
```

## Inherit

Shorthand for `name = name`:

```nix
let x = 1; y = 2;
in { inherit x y; }  # => { x = 1; y = 2; }
```

From another set:

```nix
let attrs = { a = 1; b = 2; c = 3; };
in { inherit (attrs) a b; }  # => { a = 1; b = 2; }
```

## Recursive Sets (rec)

Self-referential attribute sets:

```nix
rec {
  x = 1;
  y = x + 1;  # Can reference x
}  # => { x = 1; y = 2; }
```

**Caution**: Avoid `rec` when possible; prefer `let` or `final`/`self` pattern.

## With Expression

Brings attributes into scope:

```nix
with pkgs; [ vim git ]  # Equivalent to [ pkgs.vim pkgs.git ]
```

**Caution**: `with` is discouraged; prefer explicit `inherit` or full paths.

Does NOT shadow existing `let` bindings:

```nix
let x = 1;
in with { x = 2; }; x  # => 1 (let binding wins)
```

## Functions

Lambda syntax:

```nix
x: x + 1          # Single argument
x: y: x + y       # Curried (two arguments)
```

Pattern matching for attribute sets:

```nix
{ config, lib, pkgs, ... }: {
  # Module body
}
```

- `...` accepts extra attributes
- Common in NixOS/Home Manager modules

Default arguments:

```nix
{ x ? 1, y ? 2 }: x + y
```

Call with named arguments:

```nix
(f { x = 10; })  # y defaults to 2
```

## Lists

Whitespace-separated (no commas):

```nix
[ 1 2 3 "string" ./path ]
```

Concatenate with `++`:

```nix
[ 1 2 ] ++ [ 3 4 ]  # => [ 1 2 3 4 ]
```

## Strings

Multi-line with `''`:

```nix
''
  Line 1
  Line 2
''
```

String interpolation:

```nix
let name = "world";
in "Hello, ${name}!"
```

Paths (unquoted):

```nix
./relative/path
/absolute/path
```

## Common Builtins

```nix
builtins.map (x: x * 2) [ 1 2 3 ]          # => [ 2 4 6 ]
builtins.filter (x: x > 0) [ -1 0 1 2 ]    # => [ 1 2 ]
builtins.attrNames { a = 1; b = 2; }       # => [ "a" "b" ]
builtins.hasAttr "x" { x = 1; }            # => true
builtins.elem 2 [ 1 2 3 ]                  # => true
builtins.length [ 1 2 3 ]                  # => 3
builtins.toString 42                        # => "42"
```

## Lib Functions

Common `lib` utilities (from nixpkgs):

```nix
lib.mkIf condition value       # Conditional config
lib.mkMerge [ cfg1 cfg2 ]      # Merge configs
lib.optional cond value        # [ value ] if cond, else []
lib.optionals cond list        # list if cond, else []
lib.optionalString cond str    # str if cond, else ""
lib.concatStringsSep ", " list # Join with separator
lib.filterAttrs pred set       # Filter attribute set
lib.mapAttrs f set             # Map over attribute set
lib.recursiveUpdate base ext   # Deep merge
```

## Import

Load another Nix file:

```nix
import ./other.nix             # Evaluate other.nix
import ./module.nix { inherit pkgs; }  # Pass arguments
```

## Lazy Evaluation

Nix evaluates lazily:

```nix
let
  unused = throw "never evaluated";
  used = 42;
in used  # => 42, no error
```

Only evaluates what's needed for the result.
