# Roadmap Update Pattern

**Purpose**: The caller contract for `scripts/roadmap-integration.sh`'s three modes — who
invokes which, when, and what each promises. The authored-vs-generated split itself lives in
`context/formats/roadmap-format.md` and is **not duplicated here** — read that file first for
*what* each section is; this file states *who calls which mode, when, and what it promises*.

---

## Responsibility Split

- **`--regenerate` is the `/review`-shaped operation, and is also called directly by
  `/orchestrate`'s own conclusion stage**: render `## Open work` and `## Next` wholly from
  `state.json`, including each topic block's membership, every per-task status token, and every
  `roadmap_batches` entry. `/review` already re-derives system state from scratch; this is the
  mechanical analogue for `specs/ROADMAP.md` — but `/review`'s own command body does not call
  this script (see "## Live Callers" below). The conclusion stage (Move 5, Step 5 — see
  `context/contracts/conclusion-stage.md`) does call it, once per batch run, immediately after
  Move 4 finalizes.
- **`--prune` is now a deprecated alias for `--regenerate`** (see its Per-Mode Contract entry
  below) — a file rendered wholly from live state cannot accumulate terminal cruft, so there is
  no separate `/todo`-shaped cleanup operation left to describe here.

---

## Flags (full list; see `--help` for the authoritative, always-in-sync copy)

`--print` (default) · `--regenerate` · `--prune` · `--roadmap PATH` · `--state PATH` ·
`--max-tasks N` · `--dry-run` · `--help`. Giving more than one of `--print`/`--regenerate`/
`--prune` together is a named error, not a silent last-wins.

---

## Per-Mode Contract

### `--print`

- **Invocation**: `bash scripts/roadmap-integration.sh --print [--state PATH] [--max-tasks N]`
- **Promises**: emits the generated sections (`## Open work`'s topic blocks, `## Next`'s
  coverage appendix) to stdout. Mutates nothing.
- **Never touches**: `specs/ROADMAP.md` (not even read), `specs/state.json` (read-only).
- **Exit codes**: 0 on success; 1 on a malformed `--state` or an unparseable
  `generate-task-order.sh --print` wave table.
- **`EXT-BLOCKED` never appears** in `--print` output — it has no schema source and this mode
  has no authored-retention input to read it from. This is expected, not a defect.
- Safe to run any time, including ad hoc from a shell, purely for inspection.
- **Emits no `OUTCOME:` line** — it never reads or writes an existing `specs/ROADMAP.md`, so it
  has no write outcome to report.

### `--regenerate`

- **Invocation**: `bash scripts/roadmap-integration.sh --regenerate [--roadmap PATH]
  [--state PATH] [--dry-run] [--max-tasks N]`
- **Promises**: renders `## Next` and `## Open work` **wholly from state** —
  `roadmap_batches`/`roadmap_notes` for `## Next`, `active_projects`/`roadmap_annotation`/
  `roadmap_ext_blocked`/`roadmap_notes.open_work_trailer` for `## Open work` (see
  `roadmap-format.md`'s Authored vs. Generated table). There is no retained authored content in
  the rendering path at all — every value either comes from state or is one of the six
  authored-verbatim sections `--regenerate` never touches. Idempotent: running it twice in a row
  with no intervening state change produces a byte-identical file.
- **Never touches**: the six authored-verbatim/measured-by-hand sections (`## Goal`, `## Gate
  state`, `## Checks before and after every call`, `## Settled decisions`, `## Standing rules`,
  `## Unfiled observations`).
- **Exit codes**: 0 on success, including the supported no-op when `--roadmap` names a path
  that does not exist (nothing is read, nothing is written); 1 on a malformed input.
- **`--dry-run`**: prints a unified diff to stdout and writes nothing — the review-before-write
  path. Run this by hand before trusting an unattended `--regenerate`.
- **Emits an `OUTCOME:` line to stderr** naming whether the write actually changed the file
  (or, under `--dry-run`, would have) — see "## Stderr Marker" below for why this is the
  did-it-change answer the frozen marker cannot give. The absent-`--roadmap` no-op above is
  exempt: it returns before a write is attempted, so it emits no `OUTCOME:` line.

### `--prune` (deprecated alias)

- **Invocation**: `bash scripts/roadmap-integration.sh --prune [--roadmap PATH] [--state PATH]
  [--dry-run]`
- **Promises**: prints one named stderr deprecation note, then performs `--regenerate`. A file
  rendered wholly from live state accumulates no terminal cruft: a batch or Open work entry
  naming only terminal members is simply never rendered by `--regenerate` in the first place, so
  there is nothing left for a separate prune pass to do. Measured on this repository before this
  change landed: `--prune` reported `pruned=0`.
- **Caller contract unchanged**: the flag is still accepted, and the stderr marker's `pruned=`
  field is still present (always `0`), so every existing caller — including the conclusion
  stage's documented invocation, if any repo wires one — keeps working unchanged.
- **Exit codes / `--dry-run` / `OUTCOME:` line**: identical to `--regenerate`, since `--prune` is
  now that same code path.

---

## Stderr Marker

Every invocation, every mode, prints exactly one always-present, machine-readable line to
stderr:

```
<!-- roadmap-generation mode=M tasks=N topics=T runs=R pruned=P retained=A -->
```

This line's six count fields are byte-identical between a write that changed the file and a
write that left it unchanged — it answers "how many" (tasks/topics/runs/pruned/retained), not
"did anything change". A caller that needs the latter — did `--regenerate`/`--prune` actually
rewrite the file, or was this run a no-op — should parse the `OUTCOME:` line below instead of
diffing stdout or the rewritten file; a caller that only needs the counts still parses this
marker line as before.

---

## Live Callers

`--regenerate` has exactly one live caller today: `/orchestrate`'s conclusion stage (Move 5,
Step 5 — see `context/contracts/conclusion-stage.md`), which invokes it once per batch run,
immediately after Move 4 finalizes, and commits `specs/ROADMAP.md` alone. Neither `/todo`'s
skill (`skills/skill-todo/SKILL.md`) nor `/review` (`commands/review.md`) invokes this script.

`--prune` has no live caller, and is now a deprecated alias for `--regenerate` (see above) —
there is no longer a distinct behavior for a caller to adopt.

**Ruling**: wiring `/todo` to `--regenerate` and `/review` to `--regenerate` is acknowledged as an
open gap and is deliberately left unwired. A mode is not wired into a command merely to make
this contract's caller table symmetric with the conclusion stage's own live call. If a concrete
operational need for that wiring arises, file it via `/task` or `/spawn` rather than wiring it
preemptively here.

**The advisory batch-proposal lint's disposition.** A separate record owns an advisory lint over
hand-authored `## Next` batch blocks (`.claude/scripts/lint/lint-roadmap-batch-proposals.sh`,
invoked from the conclusion stage's Step 5 — see `context/contracts/conclusion-stage.md`),
carrying a hard constraint that it must never author, suggest, or rank a batch. Now that `##
Next` is rendered wholly from `roadmap_batches` rather than hand-authored, that lint's subject
matter — a hand-authored Run line to check — no longer exists in the shape it was written
against. Its disposition is **superseded in its parse layer, not merely narrowed**: the lint is
wired into no gate (zero references in `verify-deploy.sh`, `gate-registry.data`, or
`tests/run-all.sh`), so nothing breaks mechanically in the interim, but its parse target is gone.
The rescoping-or-retirement decision is left to that lint's own owner and is **not made here**.

---

## Related

- `context/formats/roadmap-format.md` — the generation contract: section grammar, the
  authored-vs-generated split, and every retention key. This file is the caller contract only
  and does not restate that split.
- `scripts/roadmap-integration.sh` — the generator.
