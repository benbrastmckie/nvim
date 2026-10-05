# Sub-Mode: revise

This file is the COMPLETE and ONLY specification for skill-books-review's `--revise` sub-mode
execution. It MUST be followed exactly — there is no fuller version of this content anywhere
else. The `### Sub-Mode: revise` section of `skill-books-review/SKILL.md` points here via its
stub pointer, which sends an agent here whenever `--revise` is dispatched.

Interactive proposal of research-and-revision tasks against the books convention, evaluated from
observation evidence accumulated since the last `--revise` run. Follows the Shared Sub-Mode
Skeleton in `skill-books-review/SKILL.md`; deltas below. Structural models for this file are
`distill-meta-submode.md` (the AskUserQuestion / create-note-skip / confirmation-gate shape, and
delegation-rather-than-reimplementation discipline) and `distill-revise-submode.md` (the
watermark mechanism) — both in the memory extension's own pattern directory.

## Books Telemetry Posture

Cited by path, not restated in full: `context/project/memory/telemetry-guardrails.md`. Two
principles from it apply directly to this sub-mode:

- **Evaluator outside the loop.** Propose-then-human-review, never auto-apply. `--revise` never
  treats its own prior output as evidence, and no candidate becomes a task without the
  Interactive Selection gate below. This is the same rule that governs `/distill --revise` and
  `/distill --meta`; it governs this sub-mode identically.
- **CAPTURE ONLY.** The observation records this sub-mode reads are what each task's postflight
  captured, not a live telemetry read. `--revise` reports its evidence dated and sourced
  accordingly — never implying the observation evidence was gathered just now.

## Edge Case Checks

```
1. Read specs/books-evidence/observations.jsonl.
   If the file does not exist, or exists with zero lines:
   Display: "No books observation records found yet (specs/books-evidence/observations.jsonl is
   absent or empty). Nothing to evaluate until the books observer has written at least one
   record."
   Return early.
2. Read the watermark cursor from specs/books-evidence/revise-log.json (absent on first run --
   treat as "no prior watermark", not an error).
3. Filter digest lines to those whose recorded_at is strictly after the stored watermark cursor's
   considered_through.recorded_at (all lines, on first run).
   If zero lines remain after filtering:
   Display: "No new observation evidence since the last --revise run ({last considered_through
   timestamp}). Nothing new to consider."
   Return early.
4. Attempt to read the consuming repository's decision record, in EITHER shape: the flat
   docs/book-convention.md index (pre-split, or carrying any decision not yet split out), or the
   docs/book-convention/ directory (one file per decision, post-split). Both are checked;
   neither alone is required.
   If NEITHER can be found:
   Display: "Neither docs/book-convention.md nor docs/book-convention/ was found. Without the
   decision record, no proposal can name the convention clause it bears on, and no proposal may
   be made without one. Nothing can be proposed this run."
   Return early -- this is a HARD early return, not a degraded continuation: Candidate
   Identification below never runs without at least one of the two shapes.
5. Non-blocking: run the convention-version comparison -- see context/project/books/README.md's
   "Convention version pin and staleness comparison" section (pointer only, not restated here).
   Never a return; it reports and continues.
```

## Candidate Identification: Closed Discovery Rule

Read only the digest-log lines admitted by Edge Case Check 3 above (strictly after the watermark).
For each admitted line, dereference `record_path` to its canonical
`specs/{NNN}_{SLUG}/book.observation.json`, exactly as `skill-books-review/SKILL.md`'s shared data
path describes — the digest is a pointer, never a second source of truth; this sub-mode never
treats the digest line's own rollup as a substitute for the canonical record.

Group the resulting signals two ways:

- **By `convention_decision`** — the durable heading text named on a `burdens_created`/
  `burdens_lifted` entry (e.g. `"Decision 13: Exposure policy"`), or on a tagged
  `dimension_signals` entry carrying one (per `patterns/signal-tagging.md`'s optional
  `convention_decision` field).
- **By dimension** — one of the seven keys from `standards/observation-record.md`.

Rank candidates by:
1. **Recurrence** — the same Decision/dimension combination appearing across multiple admitted
   records outranks a single occurrence.
2. **Paired-burden asymmetry** — a Decision with one or more `burdens_created[]` entries and zero
   matching `burdens_lifted[]` entries outranks a Decision whose burdens are already paired off.

**This is a closed discovery rule.** `--revise` does not invent new detection logic beyond
recurrence and paired-burden asymmetry over the admitted records — mirroring `--meta`'s own
refusal clause ("Do not write new detection logic here"; see `distill-meta-submode.md`). A
pattern this rule does not surface is not a candidate this run, however suggestive it might look
on manual inspection.

## Mandatory Preliminary Research Step (Precondition on Presenting Any Candidate)

Before any candidate ranked above may be presented to the user, enumerate the decision set from
**both** shapes the consuming repository's record may be in:

- Every file under `docs/book-convention/*.md`, sorted by numeric prefix (the post-split,
  one-file-per-decision shape), **plus**
- any `## Decision` heading still remaining in the flat `docs/book-convention.md` index (a
  decision not yet split out, or the whole record pre-split).

For every Decision a candidate touches, capture:

1. That Decision's **durable heading text**, verbatim. In the directory shape this is the
   decision file's **H1** (`# Decision N: ...`); in the flat shape it is the index's own
   `## Decision N: ...` heading (e.g. `"Decision 13: Exposure policy"` either way).
2. That Decision's current `- **Validated by**:` marker line, **verbatim** — the **one-line
   reduced marker**, including its `→ full exercise history and citations:` pointer where one is
   present (every directory-shape marker carries one; a flat-index marker not yet split out may
   not).
3. The **paired evidence file path**, `docs/book-convention-evidence/NN-slug.md`, read off the
   reduced marker's own pointer target, so a proposal can cite the exercise history behind the
   reduced marker rather than only the reduced marker itself.

The marker vocabulary has exactly three forms (adopted from the decision record's own scheme, not
invented here — see `domain/known-gap-register.md`'s "marker vocabulary, adopted not invented"
section):

| Form | Meaning |
|---|---|
| `none yet [-- reason]` | No instance at all; the reason is recorded when there is one. |
| `partially, <instances>` | Some clauses have instances; the marker names which are exercised, which are not, and which are contradicted. |
| Anything else (an instance named outright) | **Binding** — work that cannot satisfy it stops and escalates. |

`books/scripts/lint-validated-by.sh` (in the consuming repository) is the mechanical linter for
this marker's presence and well-formedness across both shapes; this sub-mode reads the marker the
linter already validates, rather than re-validating it itself.

**The bar, stated directly**: a candidate that cannot name its Decision's durable heading text
and quote that Decision's current reduced marker verbatim **is not ready to be proposed and is
dropped** — never guessed at, never presented with a placeholder marker. This drop happens
silently from the user's perspective (it never reaches Interactive Selection below) but is
recorded in this run's log entry so the drop itself is auditable.

`domain/known-gap-register.md` is a **navigation aid only** — a dated projection of which
Decisions are binding/partial/none-yet as of its own last refresh. Its own text says so: "This
file is a dated projection, not an authority. The authority ... is the `- **Validated by**:`
marker ... When this file and either authority disagree, the authority wins and this file is
stale." This sub-mode reads the **live** marker from the decision record itself — whichever shape
holds it — for every candidate, every run, and uses the register only to orient a human reader
toward where to look — never as a substitute for the live read.

## Dry-Run

When `--dry-run` is active, display the full candidate set that survived the Mandatory
Preliminary Research Step, each with its Decision's durable heading text and marker verbatim, and
return early:

```
[DRY RUN] /books --revise candidates ({count}):
  - {Decision heading text} -- marker: "{verbatim marker}" -- evidence: {record_path list}

No tasks created. Watermark NOT advanced.
```

## Interactive Selection (MANDATORY STOP, Lead Session Only)

**All of the following executes in the lead session that invoked `/books`. None of it may be
delegated to a dispatched subagent.** `AskUserQuestion` is not reachable from one on this harness
(measured) — see `skill-books-review/SKILL.md`'s lead-session clause, not restated further here.

(a) **Candidate multiSelect** — `AskUserQuestion` with `multiSelect: true`, one option per
candidate, each option's `description` carrying the Decision's durable heading text, its marker
verbatim, and the evidence citations (`record_path` values and the dimension/recurrence/asymmetry
basis for ranking it):

```json
{
  "question": "books --revise surfaced {N} candidates since the last run. Which should be considered further?",
  "header": "Convention Revision Candidates",
  "multiSelect": true,
  "options": [
    {
      "label": "{Decision heading text}",
      "description": "Marker: \"{verbatim marker}\". Evidence: {record_path_1}, {record_path_2}. Basis: {recurrence count} occurrences / paired-burden asymmetry of {N}."
    }
  ]
}
```

(b) **Per-candidate choice** — for each candidate selected in (a), a second `AskUserQuestion` (or
a combined per-row selector) offers:
- **Create as task** — proceeds to the binding-clause fork and backlog reconciliation below.
- **Note in report only** — recorded in the revise-log but no task created.
- **Skip** — discarded entirely.

**(c), the confirmation gate, runs after Backlog Reconciliation below — it is stated there, not
here, because it must show each candidate's *reconciled* outcome, not the raw pre-reconciliation
choice.** Ordering, stated once so it is unambiguous: (a) multiSelect -> (b) per-candidate
choice -> Binding-Clause Fork -> Backlog Reconciliation -> (c) confirmation gate -> Execution.

## Execution: Binding-Clause Fork (Before Backlog Reconciliation)

For each candidate confirmed as "Create as task" in step (b), check its Decision's marker form:

- **Binding** (an instance named outright, per the three-form vocabulary above): file as a
  **research-and-escalate task**. This is a **description-text convention on an ordinarily-typed
  task** (`task_type: "meta"`), not a new `task_type`, state field, or enum value — because
  nothing in this agent system mechanically reads such a field today, and inventing one here
  would be exactly the "new primitive" this plan's own research ruled out. The task's description
  states explicitly: its phases perform **research only** and surface findings for the repository
  owner's ruling; it never implements a convention change itself.
- **Non-binding** (`none yet` or `partially`): follows the ordinary task-creation path below —
  no escalation framing required.

## Two Prohibitions (Labelled Clauses)

1. **`--revise` NEVER edits the books convention.** It proposes tasks; the tasks do the work
   through the normal research/plan/implement lifecycle. No file write under
   `docs/book-convention.md` (or any consuming-repository convention record) originates from this
   sub-mode, ever.
2. **`--revise` NEVER bypasses the consuming repository's own escalation protocol.** A candidate
   against a binding clause is always filed as a research-and-escalate task (the fork above),
   never as a direct revision task that would let ordinary implementation proceed past a binding
   marker.

## Backlog Reconciliation (After Create/Note/Skip, Before the Confirmation Gate)

For each candidate confirmed as "Create as task" (after the binding-clause fork above has decided
its framing), compare it against the open backlog (`specs/state.json`'s `active_projects`) and
apply `docs/reference/standards/multi-task-creation-standard.md`:

- **Component 0** — one task per finding, unless a closed reason justifies splitting.
- **Component 4a** — file-footprint overlap with an existing open task adds a dependency edge
  rather than creating a disconnected duplicate.
- **Component 7** — final user confirmation (the Interactive Selection confirmation gate above
  IS this component for this sub-mode; they are not two separate gates).

Four admissible outcomes per comparison, and no fifth:

| Outcome | When |
|---|---|
| **Create** | No open task's `file_scope`/description overlaps this candidate's bearing Decision or files. |
| **Widen** an open task | An open task already targets the same Decision but not this candidate's full evidence scope. |
| **Add a dependency edge** | An open task's `file_scope` overlaps this candidate's likely implementation files (Component 4a). |
| **Narrow a file scope** | An open task's `file_scope` is broader than warranted once this candidate's evidence is known, and narrowing it avoids a collision. |

## (c) Confirmation Gate (After Backlog Reconciliation, Before Anything Is Written)

Before anything is actually written, show the full list of confirmed "Create as task" candidates
**with their reconciled outcome from Backlog Reconciliation above** (never the raw
pre-reconciliation candidate) and require an explicit "Yes, create/apply" confirmation — Multi-
Task Creation Standard Component 7, mirroring `distill-meta-submode.md`'s own confirmation gate.
This is the Shared Sub-Mode Skeleton's Interactive Selection (MANDATORY STOP) step, completed:
**no task is created, no dependency edge added, and no file scope narrowed without this explicit
confirmation.**

## Execution: Delegation to `/task`

**Task creation delegates to the existing `/task` primitive. Do not reimplement it inline** —
mirroring `distill-meta-submode.md`'s identical delegation discipline for `meta-builder-agent`.
This sub-mode passes the reconciled outcome (create / widen / dependency edge / narrow scope),
the Decision's durable heading text and verbatim marker, the research-and-escalate framing when
the binding fork applies, and the evidence `record_path` list; `/task` (or, for an escalation
task, the same primitive with the research-and-escalate description convention applied) owns the
actual `specs/state.json`/`TODO.md` write.

**Doc-edit-proposal rule**: a candidate whose remedy is "edit this prose, not a code/structure
change" is a **report-only finding**. `--revise` MUST NOT edit any file itself beyond its own log.
A prose-edit recommendation is always surfaced as a finding for the user to act on, never applied
automatically — and never used to route around the "no convention edits" prohibition above.

## Watermark Advance

After the confirmed batch (create/widen/dependency-edge/narrow-scope decisions, note-only
recordings, and skips) is fully applied — and **only** after, never per-candidate — advance the
watermark by writing one new entry to `specs/books-evidence/revise-log.json` (a file sibling to
`specs/books-evidence/observations.jsonl` and `specs/books-evidence/runs.jsonl`, not a
`.memory/`-dependent store), modelled on `distill-meta-submode.md`'s Meta Log Schema:

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "revise_{timestamp}",
      "timestamp": "ISO8601",
      "type": "revise",
      "session_id": "sess_...",
      "considered_through": {
        "recorded_at": "ISO8601 of the latest admitted digest line this run",
        "record_path": "specs/{NNN}_{SLUG}/book.observation.json"
      },
      "proposals": {
        "surfaced": 0,
        "created_as_task": 0,
        "noted_only": 0,
        "skipped": 0,
        "task_numbers_created": []
      },
      "notes": ""
    }
  ],
  "summary": {
    "total_revise_runs": 0,
    "total_proposals_created": 0,
    "last_operation": null
  }
}
```

**Do not advance the cursor on a dry run or an aborted confirmation.** The next run's Edge Case
Check 3 reads this file's latest `considered_through.recorded_at` as its watermark. Stated
plainly: without this advance, a second `--revise` run re-proposes the first run's evidence
in full, defeating the entire point of the watermark.

## Digest-Is-A-Pointer (Repeated From the Shared Skeleton)

As stated in `skill-books-review/SKILL.md`'s shared data path: `specs/books-evidence/
observations.jsonl` is "explicitly a pointer/derived index over the canonical records, never a
second source of truth" (`standards/observation-record.md`, verbatim). Every candidate this
sub-mode presents is sourced from a dereferenced canonical `book.observation.json` record, never
from the digest line's own rollup fields alone.
