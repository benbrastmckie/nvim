---
name: skill-books-review
description: Books convention performance review (--review, strictly read-only) and interactive research-and-revision task proposal (--revise). Invoke for /books command.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Books Review Skill (Direct Execution)

Direct execution skill paired with `/books`. Handles both of `/books`'s sub-modes
(`--review`/`--revise`) by reproducing `skill-distill/SKILL.md`'s proven hub shape: one shared
sub-mode skeleton stated once, plus a one-line stub pointer per sub-mode out to that sub-mode's
own complete specification. This file deliberately carries **no `Agent` tool** in its
frontmatter above, so no interactive gate in `--revise` can be pushed into a dispatched
subagent — `AskUserQuestion` is not reachable from one on this harness (measured). Every
multiSelect, per-candidate choice, and confirmation gate in this skill's sub-modes executes
inline, in the lead session that invoked `/books`. Only a bounded, non-interactive research or
aggregation pass may ever be delegated.

This skill executes inline without spawning a subagent for any of its interactive steps.

## Mode: books

Invoked by `/books` with `mode=books`. Both sub-modes share one data path, stated here once:

1. Enumerate books-topic observation records from the append-only digest log
   `specs/books-evidence/observations.jsonl` — one compact line per task, each carrying at
   minimum `{task, recorded_at, record_path, backfilled}` plus a short dimension-signal rollup.
2. For each digest line of interest, dereference its `record_path` field to read the canonical
   per-task record at `specs/{NNN}_{SLUG}/book.observation.json`.

**The digest is a pointer, never a second source of truth.** Quoting
`context/project/books/standards/observation-record.md` directly: the digest is "explicitly a
pointer/derived index over the canonical records, never a second source of truth" — a reader who
needs the full record always dereferences `record_path` back to the per-task file. Neither
sub-mode below treats the digest's own rollup fields as a substitute for reading the canonical
record; the digest is only how a sub-mode cheaply decides which canonical records to read.

### Sub-Mode Dispatch

| Sub-Mode | Description | Status |
|----------|-------------|--------|
| `review` | Strictly read-only convention performance review | Available |
| `revise` | Interactive proposal of research-and-revision tasks | Available |

Both sub-modes are available. No placeholder responses needed.

## Shared Sub-Mode Skeleton

Every `/books` sub-mode follows the same seven-step shape, the books-domain analogue of
`skill-distill/SKILL.md`'s own `## Shared Sub-Mode Skeleton`. This section states that shape
once, with named, generic placeholders; each sub-mode's own specification — in its extracted
`books-<submode>-submode.md` file, reached via the stub pointer at that sub-mode's heading below
— states only its deltas from this skeleton: its specific candidate logic, prompts, execution
steps, and log payload, rather than restating the shape itself.

1. **Edge Case Checks** — Validate preconditions before identifying candidates (e.g. the digest
   log exists and has at least one line resolvable to a readable canonical record). If a
   precondition fails, display a specific message and return early without further action. Also
   run the non-blocking convention-version comparison here — see `context/project/books/README.md`'s
   "Convention version pin and staleness comparison" section for the full procedure; this is a
   pointer, not a restatement.
2. **Candidate Identification** — Compute the sub-mode's specific candidate set from the
   canonical per-task records reached via the shared data path above. If a shared dependency
   (the digest log, a specific record field) is used, cite it by name rather than re-deriving it.
3. **Dry-Run** — When `--dry-run` is active, display what the sub-mode would do (the specific
   candidate list, with sub-mode-relevant fields) and return early. No file is modified.
4. **Interactive Selection (MANDATORY STOP)** — Present candidates via `AskUserQuestion`
   (`multiSelect: true` for any sub-mode selecting among multiple candidates), **in the lead
   session only**. This step is non-negotiable in every sub-mode that proposes a mutation: no
   task may be created, and the convention is never edited, without an explicit, user-confirmed
   selection at this step.
5. **Execution** — Apply the confirmed operation. This step's actual content is the most
   sub-mode-specific of the seven and is stated in full in each sub-mode's own section.
6. **Watermark Advance** — the books analogue of `skill-distill`'s Batch Index Regeneration:
   after the entire batch of confirmed operations completes (not after each individual one),
   advance the watermark cursor recording which observations this run considered. Batched once
   after the confirmed set, never per-candidate.
7. **Log Entry** — Log the operation to the sub-mode's own log file, per that sub-mode's own
   log schema.

**Non-mutating sub-mode (`--review`) does not carry step 4's mandatory stop, since nothing is
proposed for the user to confirm — this is stated here explicitly, rather than left as a silent
omission.** This is the identical sanctioned deviation `skill-distill/SKILL.md`'s own `report`/
`auto`/`--review` sub-modes already document for themselves: the absence of a mutation gate is a
considered design decision (there is nothing to confirm before writing, because `--review`
writes only its own dated report), not an oversight. `--revise` carries step 4 in full, and its
own specification additionally places a second, explicit confirmation gate after backlog
reconciliation and before any task is created — see `books-revise-submode.md`.

**Lead-session clause.** Every `AskUserQuestion` multiSelect, every per-candidate choice, and
every confirmation gate in `--revise` executes in the lead session that invoked `/books` —
never inside a dispatched subagent. `AskUserQuestion` is not reachable from a dispatched
subagent on this harness (measured; a separate backlog item exists to correct any contrary claim
elsewhere and rehome the affected gates). Only a bounded, non-interactive research or
aggregation pass — e.g. reading `books/book-convention.md`'s markers, or querying
`specs/state.json`'s open backlog — may be delegated; the gate itself never is.

### Sub-Mode: review

READ .claude/context/project/books/patterns/books-review-submode.md now and follow it exactly.

### Sub-Mode: revise

READ .claude/context/project/books/patterns/books-revise-submode.md now and follow it exactly.
