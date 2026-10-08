# Roadmap Update Pattern

**Purpose**: The caller contract for `scripts/roadmap-integration.sh`'s three modes — who
invokes which, when, and what each promises. The authored-vs-generated split itself lives in
`context/formats/roadmap-format.md` and is **not duplicated here** — read that file first for
*what* each section is; this file states *who calls which mode, when, and what it promises*.

---

## Responsibility Split

- **`--prune` is the `/todo`-shaped operation**: remove terminal tasks from `## Open work` and
  drop a whole Run line under `## Next` once every task it names is terminal. `/todo` already
  does the equivalent housekeeping for `TODO.md`/`state.json`; this extends the same cleanup to
  `specs/ROADMAP.md`.
- **`--regenerate` is the `/review`-shaped operation**: rebuild `## Open work` and `## Next`'s
  coverage appendix wholly from `state.json`, including each topic block's membership and every
  per-task status token. `/review` already re-derives system state from scratch; this is the
  mechanical analogue for `specs/ROADMAP.md`.

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

### `--regenerate`

- **Invocation**: `bash scripts/roadmap-integration.sh --regenerate [--roadmap PATH]
  [--state PATH] [--dry-run] [--max-tasks N]`
- **Promises**: rebuilds `## Open work` and the `## Next` coverage appendix from `state.json`,
  retaining every authored value named in `roadmap-format.md`'s Authored vs. Generated table
  (the six whole authored-verbatim sections, `## Next`'s Run lines with their rationale and the
  "Why this order:" prose, each task's `<- {annotation}` suffix, an authored `EXT-BLOCKED`
  token, and the Open work trailer — a free-standing paragraph that follows the last fenced
  topic block). Idempotent: running it twice in a row with no intervening state change produces
  a byte-identical file.
- **Never touches**: any of the retained values above.
- **Exit codes**: 0 on success, including the supported no-op when `--roadmap` names a path
  that does not exist (nothing is read, nothing is written); 1 on a malformed input.
- **`--dry-run`**: prints a unified diff to stdout and writes nothing — the review-before-write
  path. Run this by hand before trusting an unattended `--regenerate`.

### `--prune`

- **Invocation**: `bash scripts/roadmap-integration.sh --prune [--roadmap PATH] [--state PATH]
  [--dry-run]`
- **Promises**: drops a terminal task's line from `## Open work`, dropping the whole topic block
  if every task in it becomes terminal; drops a task number from a `## Next` Run line, dropping
  the whole line once every task it named is terminal. Corrects the affected block's `(count)`
  header. An unaffected line is left **byte-identical**, not just content-equivalent (original
  column spacing included).
- **Never touches**: everything `--regenerate` never touches, **plus** the `## Next` coverage
  appendix (left exactly as found, even if it has gone stale) and every Open work block/line
  that names no terminal task.
- **Exit codes**: same as `--regenerate`, including the same supported-no-op behavior for an
  absent `--roadmap` target.
- **`--dry-run`**: composes identically to `--regenerate --dry-run`.

---

## Stderr Marker

Every invocation, every mode, prints exactly one always-present, machine-readable line to
stderr:

```
<!-- roadmap-generation mode=M tasks=N topics=T runs=R pruned=P retained=A -->
```

A caller that only needs confirmation of what happened (counts, not content) should parse this
line rather than diffing stdout or the rewritten file.

---

## No Live Caller Yet

As of this contract, `roadmap-integration.sh` has no live caller: neither `/todo`'s skill
(`skills/skill-todo/SKILL.md`) nor `/review` (`commands/review.md`) invokes either mode. The
dependent wiring work was originally scoped to two tasks that were later abandoned and folded
into a broader backlog item's description — that item carries no dependency edge back to this
contract. The safe interim invocation, until that wiring lands, is `--dry-run` by hand. A wiring
follow-up should be filed to connect `/todo` to `--prune` and `/review` to `--regenerate`; a
separate, advisory lint over hand-authored `## Next` batch proposals is already planned as
dependent work elsewhere.

---

## Related

- `context/formats/roadmap-format.md` — the generation contract: section grammar, the
  authored-vs-generated split, and every retention key. This file is the caller contract only
  and does not restate that split.
- `scripts/roadmap-integration.sh` — the generator.
