---
name: skill-books-build
description: Single-book developer loop -- resolve, build, validate, and environment-check one book. Invoke for /book command.
allowed-tools: Read, Bash, Grep, Glob
---

# Books Build Skill (Direct Execution)

Direct execution skill paired with `/book`. Resolves the named book's `book.toml`, builds its
module scope, runs the manifest validator, then the module-grain environment-walk check against
the built library directory.

This skill executes inline without spawning a subagent.

**Out of scope**: full documentation reconciliation is not performed here — report a drifted-docs
signal if one surfaces, never silently skip it. It is owned by the already-scoped reconciliation
work (see `commands/book.md`'s own out-of-scope note).

## Execution

### Step 1: Resolve the book's manifest

Find the `book.toml` whose `[book].name` matches the requested book name:

```bash
book_name="$1"
manifest=""
for candidate in $(find . -name "book.toml" -not -path "*/.lake/*" 2>/dev/null); do
  name_in_toml=$(grep -m1 '^name' "$candidate" | sed -E 's/^name\s*=\s*"([^"]+)".*/\1/')
  if [ "$name_in_toml" = "$book_name" ]; then
    manifest="$candidate"
    break
  fi
done

if [ -z "$manifest" ]; then
  echo "No book.toml found whose [book].name == '${book_name}'." >&2
  exit 1
fi

book_dir="$(dirname "$manifest")"
module=$(grep -m1 '^module' "$manifest" | sed -E 's/^module\s*=\s*"([^"]+)".*/\1/')
```

---

### Step 2: Build the book's module scope

```bash
pkg_dir=$(dirname "$(dirname "$book_dir")")
( cd "$pkg_dir" && lake build "$module" )
```

If the build fails, report the failure and stop — do not proceed to validation against a stale
`.olean`.

---

### Step 3: Validate the manifest

```bash
lib_dir="${lib_arg:-${pkg_dir}/.lake/build/lib/lean}"
books-tool validate "$manifest" --lib "$lib_dir"
```

A non-zero exit means the manifest, or its environment cross-checks, failed. Report every
finding; do not proceed to Step 4 on a validation failure.

---

### Step 4: Environment-walk check

```bash
books-tool check --lib "$lib_dir" --only "$module"
```

Report every finding (module assignment, layer relation, any import-matrix violation). A
non-zero exit is reported as-is — this skill does not attempt to auto-fix a layer violation.

## Return Format

Brief text summary (NOT JSON): book resolved, build result, validator result, environment-check
result, any out-of-scope signal surfaced.
