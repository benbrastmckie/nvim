# The Observation Record

**One record per books-topic task**, written by `scripts/books-observe.sh` (this extension's own
post-task observer, registered on the generic topic/task_type-keyed observer seam) so that the
question "is the books convention actually working?" is answerable from accumulated evidence
rather than from recollection. This document is the schema the script implements against — every
field name below is load-bearing: the script, its test suite, and `signal-tagging.md` all cite
this document rather than re-deriving the vocabulary independently.

**Origin of the vocabulary**: the seven-dimension/polarity vocabulary and the repo-side/agent-side
field split below are not invented here. A consuming repository that has already designed this
exact record names `docs/book-evidence.md` plus three `book-evidence-{snapshot,run,observation}-v1.md`
schema companions as the authority, and names this extension as the OBSERVATION record's sole
writer. This standard conforms to that vocabulary verbatim (citing the two filenames above, never
a task number) so a future cross-repository rollup never has to reconcile two differently-spelled
enumerations. Any consuming repository without such a contract is unaffected: the vocabulary below
is useful on its own, and the fields it feeds are present-or-`absent` regardless of whether a
repo-side contract exists.

## Version marker

Every record carries `"schema_version": "observation-v1"` at the top level. A future revision of
this standard that changes field shapes bumps this string; `books-observe.sh` writes exactly one
version per record, never a mix.

## The record's required-vs-omitted posture, stated once

**Omit, never zero (D5).** A field this script cannot derive is DROPPED from the record — never
`0`, never `null`-as-zero, never a fabricated count. Where the repo-side schema names a sentinel
string explicitly (`"absent"`), that literal string is used instead of omission, because the
schema treats "no probe supplied this" as a distinct, nameable state rather than a merely-missing
key. Both conventions mean the same thing operationally (nothing to report) and are documented
per-field below so a reader never has to guess which applies.

## Top-level schema

| Field | Required | Type | Notes |
|---|---|---|---|
| `schema_version` | yes | string | `"observation-v1"`. |
| `task` | yes | integer | The books-topic task number this record belongs to. |
| `recorded_at` | yes | string | ISO 8601 UTC. |
| `topic` | no (omit if unset) | string | The task's `topic` value as read by the observer invocation (`$3`). |
| `task_type` | no (omit if unset) | string | The task's `task_type` value (`$2`). |
| `backfilled` | yes | boolean | `false` on every record written by the live observer invocation; `true` on every record `--backfill` writes. See "Dual Provenance Marking" below. |
| `figure_provenance` | no (present only when `backfilled: true`, or a live record that opportunistically re-derived a figure) | object | Maps each present figure's name to `measured` or `derived` — the generic half of provenance marking, mirrored from `context/formats/dispatch-metrics.md`. |
| `generic` | no (omit the whole group if neither source file existed) | object | The join half — see "The Join (Generic Half)" below. |
| `book_requires_churn` | no (omit if the commit range yielded nothing to count) | object | `{added, removed, source}` counts of `book_requires` lines touched across `.lean` files in the task's own commit range, plus this group's own `source: collected \| backfilled` marker (D2). Mechanically computed, no probe. |
| `validated_by_promotions` | no (omit if no commits yielded a promotion) | object | `{source, entries: []}` — `entries` holds `{decision, from, to, commit}` objects (see "Books Fact 2" below), keyed by the Decision's own durable heading text, never an invented identifier; `source` is this group's own `collected \| backfilled` marker (D2). |
| `verification_tiers` | no (omit the whole group; literal `"absent"` string is used only for `snapshot_delta`, not here) | object | `{source, tiers: {}}` — `tiers` holds per-tier run counts/outcomes/time for `lake_build`, `layer_lint`, `certify`, `full_gate`, `recheck`, present only when a RUN log exists and carries entries for this task; `source` is this group's own marker. |
| `certifier_outcomes` | no (omit if no RUN log entries) | object | `{outcome_classes: {}, refusals: [], warnings: [], source}` — read from the RUN log, never inferred; `source` is this group's own marker. |
| `vacuous_passes` | yes (first-class — see "Vacuous Passes" below) | array of object \| the literal string `"absent"` | Each entry `{tier, detail, source}`. Never computed by negation of a pass. |
| `snapshot_delta` | yes | object `{source, delta}` \| the literal string `"absent"` | `delta` is the before/after output from the consuming repository's own snapshot probe, when one exists and is executable; `source` is this group's own marker. The literal `"absent"` string (no wrapping object) is used instead whenever no probe ran. See "Probe Ownership Boundary" below. |
| `burdens_created` | yes | array of object (default `[]`) | See "Paired Burdens" below. Never absent even when empty. |
| `burdens_lifted` | yes | array of object (default `[]`) | See "Paired Burdens" below. Never absent even when empty. |
| `dimension_signals` | no (omit if `issues.jsonl` carried no tagged entries) | object | Issue-log entries grouped by `tags.dimension` × `tags.polarity`, plus `untagged_count`. See "Computed vs. Supplied" below. |
| `unrecognized_tags` | no (omit if empty) | array of object | Each entry `{entry_id, field, value}` for a `tags.dimension`/`tags.polarity` value outside the frozen enums — reported, never silently coerced or dropped. |
| `record_path` | yes | string | The canonical per-task path this exact record was written to (self-referential, so the digest log's pointer can always be dereferenced back). |
| `convention_version` | no (omit if unset) | string | This corpus's `convention_version` pin (`manifest.json`) at the time this record was written, sourced from the consuming repository's own `- **Convention version**:` marker (`books/book-convention.md`'s second header bullet; Decision 19, `books/book-convention/19-convention-versioning-and-lockstep.md`). See `README.md`'s "Convention version pin and staleness comparison" section for the full non-blocking comparison this field feeds. |

### The Join (Generic Half) — `generic`

| Field | Required | Type | Notes |
|---|---|---|---|
| `issues_present` | yes (inside `generic`) | boolean | Whether `issues.jsonl` existed for this task at observation time. |
| `metrics_present` | yes (inside `generic`) | boolean | Whether `metrics.jsonl` existed for this task at observation time. |
| `issue_counts` | no (omit if `issues_present` is false) | object | `{by_kind: {issue, win}, by_severity: {...}, by_class: {...}}`. |
| `dispatch_count` | no (omit if `metrics_present` is false) | integer | Count of `metrics.jsonl` lines for this task. |
| `phases` | no (omit if `metrics_present` is false) | object | `{completed, total}`, taken from the latest `metrics.jsonl` line that carries both. |
| `outcomes` | no (omit if `metrics_present` is false) | object | Tally of `metrics.jsonl` `outcome` values. |
| `wall_clock_seconds_total` | no (omit if no line carries `wall_clock_seconds`) | number | Sum across every `metrics.jsonl` line that carries the field. |

## The Seven Dimensions

Every signal in this record — a `dimension_signals` entry, a `burdens_created`/`burdens_lifted`
entry, a `hand_harvested_signal`-equivalent on the repo side — is classified against exactly these
seven keys, spelled verbatim as `docs/book-evidence.md` defines them. **Do not respell, abbreviate,
or add an eighth.**

| Key | Dispatch letter | Definition |
|---|---|---|
| `maintainability` | (a) | Can a scientist or engineer who did not author a book understand and safely change its metadata later? |
| `cross_pollination` | (b) | Does the convention make it easier or harder for one customer's formalization work to be reused by, or cross-checked against, a different customer's? |
| `guardrails_qa` | (c) | Does the convention catch a real defect before it ships, or does it add a gate that can be satisfied vacuously? |
| `token_cost_efficiency` | (d) | Does following the convention cost more or fewer tokens/dispatches/gate-runs than the alternative it replaced? |
| `readability` | (e) | Can an engineer read a book well enough to explain it to a customer, without reading the underlying Lean proofs? |
| `intuitive_exposure` | (f) | Does the convention expose a book's parts (its exports, its guarantees, its status) the way a user would expect to find them? |
| `compiling_composing` | (g) | Does the convention help or hurt build and composition efficiency? **Carries two first-class sub-fields, never folded into a general performance note**: `import_weight` (how much a book's own imports cost downstream consumers) and `compilation_weight` (how much the book itself costs to elaborate/certify). |

A signal may carry **one or more** of the seven keys — a single event can bear on more than one
dimension at once (e.g. a change that improves `readability` at the cost of `compiling_composing`).

## The Polarity Rule

Every signal carries exactly one polarity: `positive` or `negative`. There is no third value and
no default. **A signal with no dimension tag is still retained and counted — as `untagged` — never
defaulted to a dimension it was not actually tagged with.** An unrecognized polarity value (neither
`positive` nor `negative`) is reported in `unrecognized_tags`, never silently coerced to one or the
other and never dropped from the record.

## Paired Burdens — A Schema Requirement, Not a Reviewer Habit

A convention change that lifts one maintenance burden usually creates another. **`burdens_created[]`
and `burdens_lifted[]` are both ALWAYS present on every record, defaulting to `[]`, never one
present without the other.** This is enforced by the observer itself (never omitted as a pair) and
asserted by the test suite — a record with one key and not the other is a test failure, not a
style nit.

Each entry is at minimum:

```json
{"description": "...", "dimension": "readability", "convention_decision": "Decision 13: Exposure policy"}
```

`convention_decision` names the bearing Decision **by its durable heading text** (e.g. `"Decision
13: Exposure policy"`), never an invented identifier — the same durable-anchor discipline
`rules/no-task-references-in-deliverables.md` requires everywhere else in this corpus. A burden
with no clearly bearing Decision may omit `convention_decision`, but `description` and `dimension`
are always present.

**The read contract — how the observer finds a burden among ordinary tagged entries.** A
`dimension`+`polarity` pair alone marks a general signal, not necessarily a maintenance burden —
most negative signals are not burden trades. The `tags` object therefore carries one additional,
optional sub-field reserved for this: `tags.burden`, valued `"created"` or `"lifted"`. An
`issues.jsonl` entry with `tags.burden` present populates exactly one of `burdens_created[]` /
`burdens_lifted[]` (never both from one entry): `description` is drawn from the entry's own
`what_happened`, `dimension` from `tags.dimension[0]` (the first dimension when more than one is
present), and `convention_decision` from an optional `tags.convention_decision` string — read
verbatim, never derived from prose. An entry with no `tags.burden` key contributes to
`dimension_signals` (below) as ordinary signal, never to either burdens array. See
`patterns/signal-tagging.md`'s paired-burden worked example for the exact `--tags-json` payload
shape.

## Computed vs. Supplied — The Division of Labour

**MECHANICAL fields are COMPUTED by the observer**: tier runs and their timings, churn counts,
outcome classes, and the snapshot delta. The observer never guesses these — it reads them from the
generic logs, the RUN log, or the snapshot probe, or omits them.

**DIMENSION TAGS ARE SUPPLIED BY WORKING AGENTS**, through the open `tags` object on an
`issues.jsonl` entry (`context/formats/issue-log.md`'s extension seam, unchanged by this task) —
never guessed or inferred by the observer. `signal-tagging.md` is the companion document that
instructs working agents how to populate `tags.dimension`/`tags.polarity`. The observer's own job
on this half is strictly to READ: group tagged entries, count untagged ones, and flag unrecognized
values. An observer that invented a tag for an untagged entry would defeat the entire point of
having working agents supply it — this is a hard boundary, not a convenience the observer may cross
when the agents happen to have been sloppy.

## Vacuous Passes — First-Class, Never Inferred

A gate that passed while checking nothing is, measured across this corpus, the single most
expensive signal — `books-gate.sh`'s own `pass_vacuous` status exists for exactly this reason (see
`domain/gate-tiers.md`). `vacuous_passes` is therefore a REQUIRED top-level field (never omitted
the way a merely-unavailable group is): it is either an array of `{tier, detail, source}` entries
populated from a supplied source (the RUN log, or a direct `pass_vacuous`-class outcome recorded in
`issues.jsonl`), or the literal string `"absent"` when no such source exists for this task. It is
**never** computed by negating an ordinary pass — the observer has no way to know a pass was
vacuous unless something told it so, and guessing would manufacture a false signal in exactly the
place this record exists to prevent one.

## Probe Ownership Boundary (D3)

**The repository owns its probes and the contract for them; the extension owns the join.** This
extension ships no snapshot probe and the observer's correctness must never depend on one
existing. The standard pins the CONVENTIONAL PATH the observer looks for —
`books/tool/book-snapshot.sh`, relative to the consuming repository's own root — with the
`--json` and `--diff A B` flags the repo-side schema document itself describes. The observer:

1. Tests whether that path exists and is executable.
2. If so, invokes `book-snapshot.sh --diff <before> <after> --json` and folds its output into
   `snapshot_delta`.
3. If not, writes the literal string `"absent"` to `snapshot_delta` — never attempting to
   synthesize a snapshot itself, and never treating the absence as an error.

Looking for a conventional path is not shipping a probe: nothing in this extension creates,
requires, or depends on `books/tool/book-snapshot.sh` existing. A consuming repository that never
builds one simply gets `"absent"` on every record, forever — which is correct output, not a
degraded mode.

**Confirmed, not merely documented**: in the reference consuming repository, `books/tool/`
carries no `book-snapshot.sh` at all (checked directly, not inferred). Every record this
observer writes there exercises step 3 above and gets the documented `"absent"` sentinel — the
probe's NAME and CONTRACT (`books/tool/book-snapshot.sh`, `--json` for a single read, `--diff A
B --json` for a before/after delta) are pinned above for whichever repository eventually builds
one; its current absence here is the designed behavior, not a defect to track.

## The RUN Log (Verification Tiers, Certifier Outcomes)

`verification_tiers`, `certifier_outcomes`, and the supplied half of `vacuous_passes` are read from
`specs/books-evidence/runs.jsonl` **when it exists**, filtered to entries whose `caller_context.task`
matches this task's number. This file's own schema and writer belong to the consuming repository
(`book-evidence-run-v1.md`); this extension reads it, never writes it. When the file is absent, or
has no entries for this task, the corresponding record groups are omitted (`verification_tiers`,
`certifier_outcomes`) or set to `"absent"` (`vacuous_passes`) — never a zeroed tally standing in for
"no runs happened."

## Dual Provenance Marking (D2)

Two provenance conventions coexist on this record because neither subsumes the other:

1. **The generic `figure_provenance` map** (`context/formats/dispatch-metrics.md`'s shape):
   present only on a `backfilled: true` record (or a live record that opportunistically re-derived
   a figure), mapping each present figure's name to `measured` or `derived`. This covers the
   joined `generic` half.
2. **The per-field-group `source: collected | backfilled` marker**
   (`book-evidence-observation-v1.md`'s shape): attached to each books-specific group
   (`book_requires_churn`, `validated_by_promotions`, `verification_tiers`, `certifier_outcomes`,
   `snapshot_delta`) individually, because a books-specific group can be collected live even on an
   otherwise-backfilled record's generic half, and vice versa.

`backfilled` is never conflated with `collected`: a `backfilled` figure cannot carry a real host
fingerprint or a live-timer wall-clock, and the marker says so explicitly rather than implying a
live measurement occurred.

## Record Location — Primary File Plus Derived Digest (D1)

**The canonical record is one file per task**: `specs/{NNN}_{SLUG}/book.observation.json`, beside
that task's `.decisions.json` — the consuming repository's own owner-ruled location for the
OBSERVATION kind (distinct from RUN, which is a shared append-only log at
`specs/books-evidence/runs.jsonl`). This extension conforms to that existing, settled ruling rather
than re-litigating it.

**A compact digest line is additionally appended** to
`specs/books-evidence/observations.jsonl` on every write — one line per record, carrying at
minimum `{task, recorded_at, record_path, backfilled}` plus a short rollup of the dimension
signals present. This digest is **explicitly a pointer/derived index over the canonical records,
never a second source of truth**: a reader who needs the full record always dereferences
`record_path` back to the per-task file. The digest exists so that "is the convention actually
working?" is answerable by reading one accumulating file, without visiting every task directory —
the dispatch's own "appended to a log" framing is satisfied by this digest, while the
already-settled per-task canonical location is preserved unchanged.

## Consuming-Repository Field Split (Generic Summary)

If your consuming repository supplies a probe shaped like `book-evidence-observation-v1.md`'s
contract, expect this split (summarized generically here — see that document, by filename, for
the repository-specific prose this standard deliberately does not copy):

- **Repo-side** (the repository's own probe, build-free, derived from `git log`,
  `.decisions.json`, and directory listings): per-phase wall-clock, commit churn split
  inside/outside `specs/`, plan-version count, decision count, and hand-harvested signals
  classified against this same seven-dimension/polarity vocabulary.
- **Agent-side** (this extension's own job, from `events.jsonl`/`state.json`/the generic logs,
  never re-implemented by the repository): dispatch count, lifecycle transitions, and
  agent-process cost — the `generic` group above.

A consuming repository with no such probe simply never populates the repo-side half; this
extension's own `generic` join and books-specific computed fields are unaffected either way.

## Related

- `patterns/signal-tagging.md` — how working agents populate the `tags` seam this standard reads.
- `context/formats/issue-log.md` — the `tags` seam itself, and the 15-class issue taxonomy.
- `context/formats/dispatch-metrics.md` — the sibling generic log, the `figure_provenance` shape,
  and the `--backfill` marking contract this standard's own `--backfill` mirrors.
- `domain/gate-tiers.md` — the vacuous-pass concept this standard makes first-class.
- `domain/known-gap-register.md` — whether a real consuming repository has built either repo-side
  probe yet; re-check before assuming either exists.
