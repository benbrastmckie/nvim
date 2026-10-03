---
description: Single-book developer loop -- resolve a book's manifest, build its module scope, validate, and check the environment
allowed-tools: Read, Bash, Grep, Glob
argument-hint: "<book-name> [--lib DIR]"
---

# /book Command

Single-book developer loop for a **lean book**: resolve the named book's `book.toml`, build its
module scope, run the `book.toml` validator, then the module-grain environment-walk check
against the built library directory.

**Out of scope**: full documentation reconciliation (checking a book's rendered docs against its
current certificate) is NOT performed by this command. It is owned by the already-scoped
reconciliation work (a `/reconcile` command, a lifecycle postflight hook, and a write guard —
recorded as a move-vs-stay decision for the `books` extension, not built here). If this
command's output surfaces a drifted-docs signal, it is reported, never silently skipped or
"fixed" inline.

## Syntax

```
/book <book-name> [--lib DIR]
```

- `<book-name>` — the book's `name` as declared in its `book.toml` (not a file path).
- `--lib DIR` — a built library root to pass through to `books-tool check`; repeatable. Defaults
  to the owning package's own `.lake/build/lib/lean` when omitted and that path exists.

## Execution

**EXECUTE NOW**: Follow all steps in sequence.

---

### STEP 1: Resolve the book's manifest

**EXECUTE NOW**: Find the `book.toml` whose `[book].name` matches the requested book name.

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
echo "Resolved: ${book_name} -> ${manifest} (module: ${module})"
```

**On success**: **IMMEDIATELY CONTINUE** to STEP 2.

---

### STEP 2: Build the book's module scope

**EXECUTE NOW**: Build the owning package so the book module and everything it directly imports
is current.

```bash
pkg_dir=$(dirname "$(dirname "$book_dir")")
( cd "$pkg_dir" && lake build "$module" )
```

If the build fails, report the failure and **STOP** — do not proceed to validation against a
stale `.olean`.

**On success**: **IMMEDIATELY CONTINUE** to STEP 3.

---

### STEP 3: Validate the manifest

**EXECUTE NOW**: Run the manifest validator. Determine the built library root for this
invocation's `--lib` argument (the flag given on the command line, else the owning package's
default build output).

```bash
lib_dir="${lib_arg:-${pkg_dir}/.lake/build/lib/lean}"
books-tool validate "$manifest" --lib "$lib_dir"
```

A non-zero exit here means the manifest, or its environment cross-checks (the `name` field
against the `book` command's argument, the `module` field resolving to a module carrying a
`book` row), failed. Report every finding; do not proceed to STEP 4 on a validation failure.

**On success**: **IMMEDIATELY CONTINUE** to STEP 4.

---

### STEP 4: Environment-walk check

**EXECUTE NOW**: Run the layer-matrix record-of-truth check scoped to this book's module prefix.

```bash
books-tool check --lib "$lib_dir" --only "$module"
```

Report every finding (module assignment, layer relation, and any import-matrix violation). A
non-zero exit is reported as-is; this command does not attempt to auto-fix a layer violation.

---

## Error Recovery

### No book.toml found
Report the exact name searched for and suggest `find . -name book.toml` to list what exists.

### Build failure
Report the `lake build` output verbatim; do not run STEP 3/4 against a stale build.

### Validator or environment-check findings
Report every finding verbatim. Documentation reconciliation is out of scope (see above) — a
drifted-docs signal is reported, not silently dropped.
