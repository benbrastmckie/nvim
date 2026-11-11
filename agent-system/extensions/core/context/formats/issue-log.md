# Issue Log Format

## Overview

`specs/{NNN}_{SLUG}/issues.jsonl` is the per-task, append-only capture log for every issue and
win encountered while a task moves through research, plan, implement, and conclusion. It exists
because, measured across completed tasks, the cost of a convention gap, a gate collision, or a
tooling defect is otherwise unrecoverable after the fact: it survives today only as free prose
scattered across six places (implementation-summary "Plan Deviations" sections, decision-file
Q/A entries, progress-file fields present on some tasks and absent on others, handoff "What NOT
to Try" prose, rarely-populated handoff `blockers[]`/`dead_ends`, and `.return-meta.json`
`errors[]` populated only for partial/failed/blocked returns) — two of which
(`.return-meta.json`, `.orchestrator-handoff.json`) are overwritten on every dispatch, destroying
the detail they once held.

This document specifies the per-line schema. There is deliberately **no** companion
`context/schemas/issue-log-schema.json` — see "Deliberate Absence of a Machine Schema" below.

**Single writer**: `scripts/issue-record.sh` is the only script that appends to this file. See
its header comment for the full CLI contract; this document is the schema and policy contract it
implements against.

## File Location

```
specs/{NNN}_{SLUG}/issues.jsonl
```

One file per task directory, sibling to that task's `.return-meta.json`, `plans/`, `reports/`,
and `summaries/`.

## Lazy Creation and Never-Gitignored

- The file is **not** pre-created. It comes into existence the first time `issue-record.sh` is
  invoked for that task — mirroring `specs/events.jsonl`'s and `specs/errors.json`'s lazy-creation
  convention.
- Once created, it is a normal tracked file and is **never gitignored**. `issues.jsonl` is
  durable, freshness-gated provenance — the same class as `.orchestrator-handoff.json` and
  `.return-meta.json`, both of which the generated `specs/.gitignore` managed block's own header
  already calls out as deliberately excluded from the ephemeral runtime-file class. Its lock file,
  `.issues.lock`, is the ephemeral half and IS gitignored (see
  `context/standards/orchestrator-runtime-files.md`).
- One JSON object per line, built with `jq -c -n` and appended under `flock`, never by string
  concatenation and never by a read-merge-rewrite — this file is append-only-by-line, not an
  array document to be read back and rewritten.

## CAPTURE ONLY — A Hard Boundary

This log is write-only from every dispatch's perspective:

- **Nothing is surfaced to the user mid-run.** No proposal is generated, no gate is added, no
  task status is changed, and no mid-run summary of its contents is ever produced.
- **Review of the log belongs exclusively to the orchestration conclusion stage** — see
  `context/contracts/conclusion-stage.md`, whose three output channels (fix-now, follow-up task,
  agent-system change) are derived from these per-task logs. A mid-run surface is exactly the
  defect that design exists to avoid; do not add one here by analogy to any other log in this
  codebase.
- **Recording is always non-fatal.** A failure to record an issue or win must never fail the
  dispatch that attempted it. Every call site uses the documented non-fatal invocation form (see
  `scripts/issue-record.sh`'s header).

## When an Agent Should Record

Record **as the event arises, during the phase**, not reconstructed at the end. The moments that
should trigger a call:

- A deviation from the plan (a step skipped, altered, or deferred).
- A blocker that stalls progress, whether or how it was eventually cleared.
- A workaround applied in place of the originally planned approach.
- A gate collision (a verification tier, lint, or test that blocked progress unexpectedly).
- An unusually smooth or time-saving result — a `kind: "win"` entry — on equal footing with an
  issue. Positive signal currently has no home at all in this codebase; this log gives it one.

End-of-dispatch reconstruction is exactly what produces the free prose this log replaces. An
agent that waits until its final `.return-meta.json` or handoff write to think about what went
wrong has already lost the detail that recording-in-the-moment would have kept.

## Entry Field Table

Each line is exactly one JSON object with the fields below.

| Field | Required | Type | Notes |
|-------|----------|------|-------|
| `entry_id` | yes | string | Unique, creation-order-sortable ID: `iss_{timestamp_ms}_{random6}`, mirroring `events.jsonl`'s `event_id` and `errors.json`'s `err_{timestamp}` conventions. |
| `timestamp` | yes | string | ISO 8601 UTC, matching every other timestamp convention in this codebase. |
| `kind` | yes | string (closed: `issue` \| `win`) | Positive and negative signal share one schema and one file, on equal footing. |
| `class` | yes | string (open, extensible) | One of the 16 seed classes below, or a new value — see "Extensibility Rule" below. |
| `severity` | yes | string (closed: see "Severity Scale" below) | |
| `phase` | no (nullable) | string (closed: `research` \| `plan` \| `implement` \| `conclusion` \| `other`) | The lifecycle phase the entry belongs to. |
| `dispatch_seq` | no (nullable) | integer | The dispatch sequence number this entry belongs to, when known. |
| `what_happened` | yes | string | Free prose, one paragraph. The one truly required narrative field — everything else is structured metadata around it. |
| `evidence_path` | no (nullable) | string | Path to the artifact, log line, commit, or transcript substantiating the entry. |
| `estimated_cost` | no (nullable) | object `{value, unit}` | `value` is a number; `unit` is one of `minutes`, `dispatches`, `gate_runs` — recorded explicitly rather than forcing everything into minutes. For an issue, cost **lost**; for a win, cost **saved**. |
| `resolution` | no (nullable) | string (closed: `fixed_inline` \| `worked_around` \| `open`) | A null or omitted value is treated identically to `"open"` by the conclusion stage's filter — there is no way to write a schema-legal `kind: "issue"` entry whose resolution is permanently unreachable by that stage. |
| `suggested_channel` | no (nullable) | string (closed: `fix_now` \| `follow_up_task` \| `agent_system`) | A **hint** for the conclusion stage. Never a decision — nothing reads this field to act automatically. |
| `tags` | no | object (open) | See "The `tags` Seam" below. Defaults to `{}` when absent. |
| `task_dir` | yes | string | Repo-relative task directory this entry belongs to (e.g. `specs/042_example-task`), written by the script itself from its resolved target — not a caller-supplied field. |
| `session_id` | no (nullable) | string | The `sess_{timestamp}_{random}` value for the recording dispatch, when known. |

### Worked Example

```json
{"entry_id":"iss_1759539743123_a1b2c3","timestamp":"2026-10-03T23:42:23Z","kind":"issue","class":"gate collision","severity":"costly","phase":"implement","dispatch_seq":5,"what_happened":"shellcheck flagged SC2064 on a trap set during Phase 3; the trap had to be rewritten with single-quoted expansion before the phase's own verification tier could pass.","evidence_path":"scripts/issue-record.sh:112","estimated_cost":{"value":15,"unit":"minutes"},"resolution":"fixed_inline","suggested_channel":"fix_now","tags":{},"task_dir":"specs/042_example-task","session_id":"sess_1759539700_ab12cd"}
```

## Severity Scale

An ordered, closed, four-rung scale, chosen so two agents classify the same event the same way:

| Rung | Admission test |
|------|-----------------|
| `blocking` | Work could not proceed at all until this was resolved — the dispatch stalled or had to hand off because of it. |
| `costly` | Work proceeded, but only after a measurable detour — a re-plan, a rewrite, a re-measure, a retry loop. |
| `minor` | Work proceeded with a small, local correction (a one-line fix, a re-run) that cost noticeably less than a `costly` detour. |
| `none` | No cost was incurred at all — reserved for `kind: "win"` entries recording a smoothly-ahead-of-expectation result with nothing to fix. |

## `estimated_cost` Unit Convention

`estimated_cost` is a `{value, unit}` pair, never a bare number, because not every cost is
naturally minutes:

- `minutes` — wall-clock time lost (issue) or saved (win).
- `dispatches` — whole additional dispatch cycles consumed (issue) or avoided (win).
- `gate_runs` — additional verification/gate invocations required (issue) or skipped (win).

Record the unit that actually fits the event; do not force a `gate_runs` cost into a fabricated
minutes estimate.

## Seed Class Enum — The 16-Class Taxonomy

Empirically grounded in 16 completed tasks measured in a prior verification-focused repository,
plus one class added to distinguish infrastructure/transport unavailability from work failure.
Each class below is a one-line gloss, not a full taxonomy document:

| Class | Gloss |
|-------|-------|
| `design-record defect or ambiguity` | The design record (plan, report, or spec) was wrong, self-contradictory, or silent on a case the implementer actually hit. |
| `gate collision` | Two verification gates (or a gate and a plan step) disagreed or blocked each other. |
| `missing cheap verification tier` | A fast, cheap check that would have caught the problem earlier did not exist at the point it was needed. |
| `vacuous or silent pass` | A test, gate, or check reported success without actually exercising the thing it claimed to verify. |
| `tooling bug or gap` | A script, CLI, or library had a genuine defect or a missing capability, independent of this task's own logic. |
| `resource/OOM including misdiagnosis` | A resource exhaustion (memory, disk, rate limit) occurred, or was initially misdiagnosed as something else. |
| `plan scope-hypothesis wrong` | A plan's stated scope hypothesis (file count, line range, enumerated set) did not match what was actually found. |
| `planned feature absent` | Something the plan assumed already existed in the codebase did not. |
| `language or module-system gotcha` | A language or build/module-system quirk (shell quoting, import resolution, etc.) cost time independent of this task's design. |
| `environment` | The local or CI environment (missing binary, version mismatch, permissions) caused the cost. |
| `cross-task ownership/territory` | Two tasks or dispatches touched the same file footprint unexpectedly. |
| `stale deploy or source-store boundary` | Work landed in `.claude/**` instead of the source store, or a stale deployed copy was consulted instead of the source. |
| `orchestration defect` | The orchestrator/loop machinery itself (cycle logic, dispatch building, postflight) misbehaved. |
| `stale workaround` | A previously-applied workaround was still in place after its root cause was fixed, or outlived its justification. |
| `cost-forced exclusion or substituted verification` | A verification step was narrowed, skipped, or substituted because the full form was judged too costly, and this was the record of that trade-off. |
| `infrastructure/transport unavailable` | An external system was genuinely unreachable or self-reported unavailable (an HTTP 503 from a backing service, a transport `ESERVFAIL`, a dead MCP connection). An entry of this class records infrastructure being unavailable, not the task's own work failing. Nothing in cycle accounting reads this field today — cycle-accounting treatment of transport deaths is a separate concern owned elsewhere and deliberately not changed here. |

### Extensibility Rule

`class` is **deliberately open, not a closed enum**. `scripts/issue-record.sh` accepts any value:
when the value is outside the 16 seed classes above, the script **warns to stderr and proceeds**
— it never refuses the call. This is the one deliberate divergence from
`scripts/system-defect-record.sh`'s closed-enum-refuses-loudly posture; do not "fix" this script
into a closed enum by analogy to that one. The point of the open enum is that a genuinely new
failure mode must be recordable the first time it is hit, not only after a schema revision adds
it. The conclusion stage is expected to tally unknown-class entries across tasks as part of its
own synthesis, and a class that recurs often enough is a candidate to be promoted into this
document's seed list in a future revision — that promotion is a documentation change here, never
an enforcement change in the writer.

## The `tags` Seam

`tags` is an **open object**. Core neither validates its interior shape nor depends on any key
inside it. This is the seam an extension's own dimension-tagging scheme uses to attach
extension-specific structured metadata (e.g. a `lean4` extension tagging an entry with the
Mathlib declaration it concerns) without requiring any change to `issue-record.sh`, this
document, or the core schema. When absent, treat `tags` as `{}`.

### Occurrence Collapse

A general write-side convention for a caller that has already discovered N occurrences of one
underlying event **before its first `issue-record.sh` call** for that event: write exactly one
line carrying `tags.occurrence = {count, first_seen, last_seen}` (`count` an integer, the two
timestamps ISO 8601 UTC), passed via the existing `--tags-json` flag — for example
`--tags-json '{"occurrence":{"count":123,"first_seen":"2026-10-03T23:40:00Z","last_seen":"2026-10-03T23:42:23Z"}}'`.
This needs no schema change and no writer change: `tags` is already open, and `--tags-json` is
already a general-purpose pass-through. It is available to any caller and to any error class,
not a Sapience-specific mechanism — the same convention that collapses a run of byte-identical
Sapience 503 bodies into one entry also collapses a single dispatch's scores of same-class
"scope excursion" rows into one entry, as long as the caller itself already knows the count
before its first call.

This is a **write-side** collapse: it reduces how many lines a caller writes for one known-repeated
event. It is distinct from, and does not duplicate, the **read-side** cross-entry collapse that
`scripts/orchestrate-conclusion-aggregate.sh`'s `group_by(.class)` pipeline already performs when
synthesizing the conclusion stage's proposals across every entry already written — that grouping
happens automatically at read time regardless of whether any individual line used
`tags.occurrence`. A caller that does not know its own repeat count in advance should simply write
one line per occurrence and let the read-side grouping do its job.

## The Three-Store Topology

Three stores exist in this codebase for recording failures and lifecycle events, and each has a
distinct, narrow verdict rather than overlapping freely:

- **`issues.jsonl` via `issue-record.sh`** is the general-purpose capture surface for any failure
  or win inside a task context. This document is its schema and policy contract.
- **`events.jsonl` via `events-append.sh`** is the append-only lifecycle store, and is the only one
  of the three that accepts a null `task` — making it the capture surface for an error that arises
  when no task directory exists at all. See `context/formats/events-format.md`.
- **`errors.json` via `errors-append.sh`** is a narrower, decoupled triage surface with its own
  living-record schema, read by the `/errors` command. It is not the general error-handling write
  path; see `rules/error-handling.md`'s "Where Errors Are Stored" subsection for the full
  description of its scope relative to the other two stores.

A reader asking "what has gone wrong" should start from `issues.jsonl` for task-scoped work,
`events.jsonl` for anything outside a task context, and `errors.json` only for the narrower triage
case `/errors` serves.

## Central Cross-Repo Log

`issue-record.sh` and `events-append.sh` each promote a subset of what they write to a single
central, cross-repo log, so one place shows what has been breaking across every repository that
shares this agent system — without requiring a usable repo registry or any repository
enumeration.

- **Path**: `specs/central-errors.jsonl`, under the repository that owns the source store (the
  repository whose `.claude-extensions.json` resolves an extension's `source_dir` to a directory
  inside that same repository's own git toplevel).
- **Shape**: one JSON object per line, built with `jq -c -n`, never string concatenation.
- **Envelope fields**: `central_id` (`cen_{timestamp_ms}_{random6}`), `recorded_at` (ISO 8601
  UTC), `origin_repo` (the writing repository's absolute root), `origin_store` (`issues.jsonl` or
  `events.jsonl`), and `entry` (the original store line, verbatim and unmodified).
- **Promotion filter**: from `issues.jsonl`, only a line with `kind == "issue"` is promoted (a
  `kind: "win"` is not); from `events.jsonl`, only a line with `category == "blocker"` is
  promoted. Nothing else is promoted from either store.
- **Bound**: a single-generation rotation — the file is capped at a stated line count and rotated
  to one prior generation, never allowed to grow unbounded the way `events.jsonl` has.
- **Failure posture**: an absent or unwritable target is a silent no-op, by design — the same
  silent-degradation posture the rest of this logging path already takes. This is a decision, not
  an accident: a logging path must never become a reason a dispatch fails.
- **Reading rule**: this log is the cross-repo inbox. An entry written in the repository that owns
  the source store stays in its own task log and is **not** duplicated into this file (the
  owning-repo skip) — a reader asking "what has been breaking everywhere" reads this file together
  with that repository's own task logs, not this file alone.

## Relation to the Six Existing Issue-Bearing Surfaces

Each existing surface's relation to `issues.jsonl` is one of **SUBSUME** (the old surface stops
being written), **MIRROR** (both are written; the log is a parallel, durable record of the same
event), **LEAVE** (independent, with the boundary stated), or **RETIRE** (the old surface is
removed outright because its signal has a live replacement).

| Surface | Verdict | Boundary |
|---------|---------|----------|
| `.return-meta.json` `errors[]` | **MIRROR** | `errors[]` keeps its current shape, its four required fields, its per-dispatch-overwritten lifetime, and its structural consumers unchanged — see `context/formats/return-metadata-file.md`'s `errors[]` section for the MIRROR statement on that side. Every call site that builds an `errors[]` entry should also call `issue-record.sh` with the same `message`/`recommendation` content, so the detail survives the next dispatch's overwrite without the field's own semantics changing at all. |
| `progress/phase-N-progress.json` `approaches_tried[]` | **MIRROR** | (The surface's actual field name is `approaches_tried[]` — `progress-file.md` has no `deviations[]` field; "Plan Deviations" is a free-prose heading in the implementation summary, not a progress-file JSON field.) `approaches_tried[]` keeps recording in-phase attempts and their outcomes exactly as today; a failed approach worth recording there is also worth an `issue-record.sh` call so it survives past this phase's own progress file, which is itself overwritten across continuations. |
| Handoff `blockers[]` | **MIRROR** | The handoff keeps naming blockers for the immediate successor dispatch to read. Because `.orchestrator-handoff.json` is overwritten on every dispatch, a `blockers[]` entry about to be written should also be recorded via `issue-record.sh` at the same moment — see `context/contracts/wrap-up.md`'s reinforcement of this pairing at the `blockers[]` write site. |
| Handoff `dead_ends` | **MIRROR** | Same overwrite hazard as `blockers[]`, same remedy: a `dead_ends` entry about to be written to the handoff should also be recorded via `issue-record.sh`, typically with `resolution: "worked_around"` or `"open"` and `class` set to whatever concrete class the dead end actually was (e.g. `tooling bug or gap`), rather than left as the handoff's own free-text-only record. |
| `system_defect` events (`specs/events.jsonl`, `event_type: "system_defect"`) | **LEAVE** | Independent populations and independent enums: `system_defect` covers only mechanically detected, closed-16-class schema violations via `scripts/system-defect-record.sh`, while `issues.jsonl` covers everything an agent judges worth recording, under an open, extensible class enum. The two overlap deliberately at the two call sites in `orchestrate-cycle-postflight.sh` where both already fire adjacently for the same underlying event — this is intended overlap, not duplication to be collapsed. |
| state.json `reflection` field | **RETIRE** | Dead on arrival: its only writer, `scripts/orchestrator-postflight.sh`, has no live callers (`scripts/skill-base.sh` already documents this in-repo), and it appears in essentially none of the measured `.return-meta.json` files or `state.json` entries across multiple repos. Retired end-to-end in the same pass that introduced this log — see `context/formats/return-metadata-file.md` and `context/reference/state-management-schema.md` for the removal, and `context/formats/events-format.md`'s `reflection` event-type row for the separate, still-live event-store producer-status note. `kind: "win"` is the live home for the positive signal the field was meant to carry, and `kind: "issue"` for the negative half. **Executed**, not pending — this verdict was carried out in the same implementation pass that added this document. |

## Deliberate Absence of a Machine Schema

`events-format.md` and the decisions-file contract (`docs/architecture/handoff-schema.md`'s
"Decisions File Schema" section) both pair their prose contract with a machine-checkable JSON
Schema. This document deliberately breaks that pairing convention: there is no
`context/schemas/issue-log-schema.json`. This is a recorded, low-cost follow-up, not a silent
omission — a future pass can add one once the open `class`/`tags` fields have settled enough
usage to make a schema worth writing without immediately needing a revision.

## Unknown-Class Tally — A Note for the Conclusion Stage

Because `class` is open, the conclusion stage (`context/contracts/conclusion-stage.md`, deriving
its three output channels from these logs) is expected to tally entries whose `class` falls
outside the 16-class seed list above, across tasks, as part of its own synthesis. A class that
recurs often enough across tasks is a candidate for promotion into this document's seed enum in a
future revision. This tally is explicitly the conclusion stage's job, not this log's own —
recording here stays CAPTURE ONLY.
