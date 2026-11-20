# Roadmap Update Pattern

**Purpose**: The caller contract for `scripts/roadmap-integration.sh` — who invokes which mode,
when, and what each promises. What the rendered file contains lives in
`context/formats/roadmap-format.md` and is **not duplicated here** — read that file first for
*what* is rendered; this file states *who calls which mode, when, and what it promises*.

---

## Responsibility Split

- **Judgment** belongs to `roadmap-agent`, dispatched by `skill-roadmap` for `/roadmap`: which
  milestones exist, their aims and gates, batch membership and order, descriptions, and missing
  dependency edges. It writes those decisions to `specs/state.json` through `state-write.sh` and
  never writes `specs/ROADMAP.md` by hand.
- **Rendering** belongs to `roadmap-integration.sh`: it renders the whole file from state and
  exercises no judgment. `--regenerate` is the one write operation, called by four surfaces (see
  "## Live Callers").
- **`--prune` is a deprecated alias for `--regenerate`** — a file rendered from live state
  accumulates no terminal entries, so there is no separate cleanup operation to describe.

---

## Flags (full list; see `--help` for the authoritative, always-in-sync copy)

`--print` (default) · `--regenerate` · `--prune` · `--roadmap PATH` · `--state PATH` ·
`--dry-run` · `--help`. Giving more than one of `--print`/`--regenerate`/`--prune` together is a
named error, not a silent last-wins.

---

## Per-Mode Contract

### `--print`

- **Invocation**: `bash scripts/roadmap-integration.sh --print [--state PATH]`
- **Promises**: emits the whole rendered file to stdout. Mutates nothing.
- **Never touches**: `specs/ROADMAP.md` (not even read), `specs/state.json` (read-only).
- **Exit codes**: 0 on success; 1 on a malformed `--state`.
- Safe to run any time, including ad hoc from a shell, purely for inspection.
- **Emits no `OUTCOME:` line** — it never reads or writes an existing roadmap, so it has no
  write outcome to report.

### `--regenerate`

- **Invocation**: `bash scripts/roadmap-integration.sh --regenerate [--roadmap PATH]
  [--state PATH] [--dry-run]`
- **Promises**: writes the whole file from state — the intro from `primary_goals` and
  `roadmap_milestones`, one section per milestone, and the last part from `roadmap_context` (see
  `roadmap-format.md`'s Section Order). Nothing is read back out of the file being written.
  Idempotent: running it twice in a row with no intervening state change produces a
  byte-identical file.
- **Output path**: `--roadmap` when given; otherwise `roadmap_context.output_path`; otherwise
  `specs/ROADMAP.md`.
- **Refuses** to overwrite a file whose first line is not the generated sentinel (exit 1, no
  write; see "## Refusal Predicate").
- **Exit codes**: 0 on success, including the supported no-op when the output path does not
  exist and the store holds no milestone (nothing is written); 1 on a malformed input or a
  refusal.
- **`--dry-run`**: prints a unified diff to stdout and writes nothing — the review-before-write
  path.
- **Emits an `OUTCOME:` line to stderr** naming whether the write changed the file (or, under
  `--dry-run`, would have) — see "## Stderr Marker". The absent-path no-op and a refusal return
  before a write is attempted, so neither emits an `OUTCOME:` line.

### `--prune` (deprecated alias)

- **Invocation**: `bash scripts/roadmap-integration.sh --prune [--roadmap PATH] [--state PATH]
  [--dry-run]`
- **Promises**: prints one named stderr deprecation note, then performs `--regenerate`.
- **Caller contract**: the flag is accepted, and the stderr marker's `pruned=` field is present
  (always `0`), so a caller that passes it keeps working.
- **Exit codes / `--dry-run` / `OUTCOME:` line**: identical to `--regenerate`; it is the same
  code path.

---

## Stderr Marker

Every invocation that reaches mode dispatch prints exactly one machine-readable line to stderr:

```
<!-- roadmap-generation mode=M tasks=N topics=T runs=R pruned=P retained=A -->
```

`runs=` counts the batches under milestones that are not closed; `pruned=` and `retained=` are
always `0`. The six count fields are identical between a write that changed the file and a write
that left it unchanged — the marker answers "how many", not "did anything change". A caller that
needs the latter parses the `OUTCOME:` line (shapes in `roadmap-format.md`) instead of diffing
the rewritten file.

---

## Refusal Predicate

`scripts/lib/roadmap-preflight-lib.sh classify PATH` returns one of five verdicts, testing the
sentinel first:

| Verdict | File | `--regenerate` |
|---|---|---|
| `generated` | first line is the generated sentinel | overwrites |
| `absent` | does not exist | writes when the store holds a milestone; otherwise a no-op |
| `classic`, `stage`, `unknown` | hand-authored | refuses, naming `migrate-roadmap-to-milestones.sh` |

The generator applies this predicate itself on every write; no flag overrides it.

## Preflight Obligation (every write-mode caller)

Before any write-mode invocation, every caller classifies the output path first:

```bash
verdict="$(bash .claude/scripts/lib/roadmap-preflight-lib.sh classify specs/ROADMAP.md)"
```

- **`generated`**: proceed straight to the write-mode call.
- **`absent`**: an interactive caller proceeds without a question — creating a generated file
  where none exists destroys nothing. The non-interactive conclusion stage does not create one
  (see caller 1 below).
- **`classic`/`stage`/`unknown`**: the file is hand-authored and must be migrated before it can
  be generated. An interactive caller runs `migrate-roadmap-to-milestones.sh --dry-run`, shows
  its accounting, asks one `AskUserQuestion`, and on approval runs the migration with an explicit
  `--retained` path. A caller with no approver degrades loudly and leaves durable evidence. Never
  a silent skip, and never an unapproved write.

**Hard constraint**: this preflight sits strictly in front of the generator's own refusal. It
never weakens or bypasses that refusal, and no caller hand-authors roadmap content in its place.
The library's `scaffold` action writes the sentinel line alone onto an absent path and refuses
every other path. A new write-mode caller inherits this obligation; it is not special-cased per
caller.

## Live Callers

`--regenerate` has four live callers, independent of each other:

1. `scripts/orchestrate-conclusion-roadmap.sh`, the mechanical executor of `/orchestrate`'s
   conclusion-stage roadmap-update step (Step 5 — see `context/contracts/conclusion-stage.md`).
   It fires once per invocation, unconditionally, from Move 4's finalize sequence
   (`skills/skill-orchestrate/SKILL.md`'s Move 4, immediately after the Batch Gate Stage) and
   commits the resolved output path alone. **Arm**: non-interactive — it regenerates on
   `generated`, and on `absent`/`classic`/`stage`/`unknown` degrades loudly with durable
   evidence, naming the migration for a hand-authored file, since this surface has no approver.
2. `roadmap-agent.md`'s own Write Contract, dispatched by `skill-roadmap/SKILL.md` for every
   `/roadmap` invocation. `skill-roadmap/SKILL.md`'s Stage 1 preflight runs before the agent is
   dispatched, so the agent's `--regenerate` call lands on a `generated` or `absent` path.
   **Arm**: interactive — one `AskUserQuestion` offering the migration on a hand-authored file.
3. `/todo` (`commands/todo.md`, Stage 6.6), which classifies, regenerates, and commits the
   roadmap alone after Stage 6's archival commit and Stage 6.5's metrics sync. **Arm**:
   interactive, the same single-question shape as `/roadmap`.
4. `/review` (`commands/review.md`, Section 6.8), which classifies, regenerates, and commits the
   roadmap alone after Section 5's task creation and Section 6.7's Task Order management;
   `--brief` mode (Section 1.1) exits before reaching it and performs no roadmap write. **Arm**:
   interactive, for the same reason as `/todo`.

Both `/todo` and `/review` are direct-execution command bodies that never delegate to a
subagent, so neither is governed by `context/standards/postflight-tool-restrictions.md`'s base
tables — those tables, and `scripts/lint/lint-postflight-boundary.sh`'s enforcement of them, are
scoped to skills that delegate via the Agent tool.

`--prune` has no live caller.

**Rollout order.** Once a repository's deployed scripts render the whole file, a hand-authored
roadmap stops regenerating at the conclusion stage until the migration has run. Run the
migration in the same sitting as the deploy that introduces the generator.

## The Advisory Batch Lint's Disposition

`scripts/lint/lint-roadmap-batch-proposals.sh` is **retargeted at state**, and that is its
single disposition:

- **Input**: the authored entries in `specs/state.json` — the batches under
  `roadmap_milestones[].batches[]` of every non-closed milestone (read through
  `scripts/lib/roadmap-entries-lib.sh`, which falls back to a flat `roadmap_batches` array in a
  store that carries no `roadmap_milestones` key), plus the bounded roadmap prose fields for its
  path-citation finding. It never opens `specs/ROADMAP.md`: the rendered file holds no authored
  text to check.
- **Call site**: `scripts/orchestrate-conclusion-roadmap.sh`, the `LINT_SCRIPT` invocation, run
  on every preflight verdict — the lint's input is state, so a roadmap file that could not be
  regenerated does not silence it.
- **Contract**: advisory. Its exit code is never affected by findings, and it validates a batch
  that was already authored; it never authors, suggests, ranks or corrects one. Member integrity
  (abandoned, expanded or unresolvable members) is `validate-state.sh` Check 13's finding, not
  this lint's.

Retiring the lint was the alternative. It was rejected on its merits: an under-inclusive batch
is caught at dispatch time by the admission gate regardless, but only the lint reports it when
the batch is authored, and that finding is as meaningful over state entries as it was over
rendered lines.

---

## Related

- `context/formats/roadmap-format.md` — the generation contract: section order, field bounds,
  the pruning ledger, the migration. This file is the caller contract only.
- `context/contracts/conclusion-stage.md` — Step 5, the non-interactive caller.
- `scripts/roadmap-integration.sh` — the generator.
