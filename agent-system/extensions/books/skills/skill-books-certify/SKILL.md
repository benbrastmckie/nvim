---
name: skill-books-certify
description: Thin passthrough over the certify driver for graph-wide book certification. Invoke for /certify command.
allowed-tools: Bash
---

# Books Certify Skill (Direct Execution)

Direct execution skill paired with `/certify`. Runs the pre-launch check, then forwards the
caller's arguments verbatim to `books-certify.sh`, the extension's resolve-and-invoke wrapper
around the consuming repository's own certification driver.

This skill executes inline without spawning a subagent.

## Execution

### Step 1: Pre-launch check

```bash
bash .claude/scripts/books-certify.sh --check "$@"
```

If this exits non-zero, report its findings and stop — do not proceed to a real run against a
tree that failed its own readiness check.

### Step 2: Invoke the real driver

```bash
bash .claude/scripts/books-certify.sh "$@"
```

Report the exit code and the full output verbatim: `0` every book certified, `1` a book was
refused or a build failed, `2` usage error, `3` the wrapper could not find the real driver (books
tooling absent in this repository).

## Error Recovery

Identical to `commands/certify.md`'s Error Recovery section: distinguish a genuine refusal from
a resource failure per the driver's own classification; report a usage error with the corrected
syntax from that command's Options table.

## Return Format

Brief text summary (NOT JSON): pre-launch check result, certification exit code, and a
one-line-per-book verdict summary when the driver produced one.
