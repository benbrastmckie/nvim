# Events Store Format

## Overview

`specs/events.jsonl` is the unified, append-only event/reflection log for the agent system. It
captures lifecycle timings, deviations, blockers, milestones, successes, and completion-time
reflections as a single stream of compact JSON lines, so downstream consumers (dashboards,
distillation passes, ad hoc `jq` queries) share one schema and one pair of helper scripts instead
of each hand-rolling their own log format.

This document specifies the per-line schema. The formal machine-checkable contract lives in
`context/schemas/events-schema.json` (draft-07 JSON Schema); the two must stay in sync.

## File Location

```
specs/events.jsonl
```

Repo-root-relative, sibling to `specs/errors.json`, `specs/state.json`, and `specs/TODO.md`.

## Lazy Creation and Never-Gitignored

- The file is **not** pre-created. It comes into existence the first time
  `scripts/events-append.sh` is invoked -- mirroring the existing `specs/errors.json` convention
  (which also does not exist until the first error is logged).
- Once created, it is a normal tracked file and is **never gitignored**. It accumulates for the
  lifetime of the repository.
- Both helper scripts (`events-append.sh`, `events-query.sh`) must tolerate the file's absence:
  the append helper creates it lazily; the query helper returns an empty result set and exits 0
  (never an error) when the file does not exist yet.
- No rotation or archival strategy is defined for this file. Unbounded growth over a long-lived
  repository is a known, explicitly out-of-scope gap -- flagged for a future task, not solved
  here.

## One-Compact-JSON-Object-Per-Line

Each line is exactly one JSON object, produced with `jq -c` (compact, single-line, no embedded
newlines), terminated by `\n`. This makes the file:

- Trivially `jq`-streamable: `jq` parses a stream of concatenated JSON values natively, so no
  `--slurp`/`-s` flag is needed for line-by-line filtering.
- Trivially `wc -l`-countable for a cheap total-event count.
- Append-only: lines are never rewritten or reordered in place; corrections are expressed as new
  lines (e.g. a later `success` event), never mutation of an earlier line.

Lines are built via `jq -c -n --arg`/`--argjson ...` into a shell variable and appended with a
single `printf '%s\n' "$line" >> "$EVENTS_FILE"` write -- never via string concatenation, which
risks JSON-escaping bugs. See `scripts/events-append.sh` for the reference implementation.

## Field Table

| Field | Required | Type | Notes |
|-------|----------|------|-------|
| `event_id` | yes | string | Unique, creation-order-sortable ID: `evt_{timestamp_ms}_{random6}`. Mirrors the existing `err_{timestamp}` / `sess_{timestamp}_{random}` ID conventions rather than inventing a new scheme (e.g. UUID). |
| `event_type` | yes | string (open) | The specific kind of event -- finer-grained than `category`. Free-form but documented (see below); new values may be added by future consumers without a schema revision. |
| `category` | yes | string (closed enum) | Exactly one of `deviation`, `blocker`, `milestone`, `success`. The primary filterable/groupable taxonomy for aggregate queries. |
| `timestamp` | yes | string | ISO 8601, matching every other timestamp convention in this codebase (`errors.json`, return-metadata files, `state.json`). |
| `duration_seconds` | no (nullable) | number \| null | Nullable -- point events (e.g. hitting a blocker) have no duration; a completed lifecycle stage does. Named `duration_seconds`, not `duration_ms`, to match the existing `metadata.duration_seconds` convention in `return-metadata-file.md`. |
| `session_id` | yes | string | The exact `sess_{timestamp}_{random}` value already generated at command gate-in -- the shared cross-link key joining events to a run. |
| `task` | no (nullable) | integer \| null | Bare (unpadded) task/project number, matching `errors.json`'s `context.task` and `state.json`'s `project_number` -- **not** the zero-padded directory string. Nullable because some events (e.g. a `/refresh` sweep) are not task-scoped. |
| `checkpoint` | no (nullable) | string \| null (open) | The lifecycle point the event occurred at. Open string with documented common values (see below); nullable for events with no single associated checkpoint. |
| `message` | yes | string | Short, human-readable one-line summary, mirroring `errors.json`'s `message` field. |
| `detail` | no | object (open) | Open, `event_type`-specific structured payload -- e.g. a completion-time reflection's `what_worked`/`what_was_hard`/`what_was_missed`/`successes` fields nest here without requiring a schema revision. Defaults to `{}` when absent. |
| `error_ref` | no (nullable) | string \| null | Optional cross-link to an `errors.json` entry's `id` (e.g. `"err_1736700000"`). **Always optional, never a hard foreign key** -- consumers must work correctly whether or not `specs/errors.json` exists or contains the referenced ID. |
| `cwd` | no (nullable) | string \| null | The invoking working directory (absolute path), when the caller supplied `--cwd`. Null for older rows written before this field existed, or for call sites with no reliable `cwd` source. **`cwd` is the only field stored for cross-repo federation** -- `repo` is deliberately NOT a stored field (see below). |
| `cc_session_id` | no (nullable) | string \| null | Claude Code's own native session UUID, captured verbatim from hook stdin's top-level `.session_id` field. The exact join key to OTel's `session.id` resource attribute (and to `history.jsonl`'s `sessionId`) -- see "Claude Code OTel Correlation" below. **Distinct from `session_id` above**: `session_id` is this schema's pre-existing `sess_{timestamp}_{random}` agent-system id; `cc_session_id` is Claude Code's own UUIDv4. The two ids live in different id spaces and neither replaces the other. Null when the event is emitted outside any hook context. |

## Cross-Repo Federation: `cwd` Stored, `repo` Derived (never stored)

Cross-repo federation is built on `cwd` alone. `events-append.sh` accepts an optional `--cwd PATH`
flag (never auto-detected -- the caller must supply it explicitly, typically from a hook's stdin
`.cwd` field) and writes it verbatim, or `null` when absent. No `repo` field is ever written to
`specs/events.jsonl`.

`events-query.sh` derives `repo` at query time as `basename(cwd)` (e.g. `cwd`
`"/home/user/.config/nvim"` -> `repo` `"nvim"`), added to every row in `jsonl`/`json-array` output
and aggregated as `by_repo` in `summary-counts` output. Rows with `cwd: null` derive `repo: null`
and are tolerated everywhere -- never an error, and never matched by a non-empty `--repo` filter.
This basename derivation is a deliberate simplification of "git toplevel of that cwd": a per-row
`git` invocation would be inconsistent with `events-query.sh`'s native-`jq` streaming-filter
design, and in practice the `cwd` captured by the events hooks is already the invoking repo root.

Storing only `cwd` (not a redundant `repo` field) keeps the schema minimal and avoids committing
to a stored-vs-derived inconsistency if the repo-naming convention ever changes -- only the query
layer would need updating, not every historical row.

## `category` Closed Enum

`category` is intentionally a closed, 4-value enum -- the stable taxonomy that aggregate/summary
consumers group and filter by:

| Value | Meaning |
|-------|---------|
| `deviation` | Execution diverged from the plan (skipped, altered, or deferred a step). |
| `blocker` | Work could not proceed without external resolution. |
| `milestone` | A meaningful checkpoint or phase boundary was reached. |
| `success` | A goal, phase, or task completed successfully. |

## `event_type` Open String -- Common Values

`event_type` is an open, extensible string. The starter/common values below are seeded by this
contract; consumers may add new values without a schema-breaking revision:

| Value | Typical `category` | Description |
|-------|--------------------|--------------|
| `lifecycle_stage` | `milestone` | A named lifecycle stage (see `checkpoint`) completed. |
| `deviation` | `deviation` | A plan step was skipped, altered, or deferred. |
| `blocker` | `blocker` | Execution stalled on an external dependency or missing input. |
| `milestone` | `milestone` | A phase or objective boundary was reached. |
| `success` | `success` | A goal, phase, or task completed. |
| `reflection` | `success` (typically) | A completion-time structured reflection payload, nested in `detail`. |
| `push_grant_issued` | `milestone` | A consent-gated push/destructive-action grant was minted (`hooks/please-grant.sh`); `detail` carries `remote`/`ref`/`sha`/`force`/`mint_source`/`request_text`. |
| `push_grant_consumed` | `success` | A consent-gated push/destructive-action grant was consumed to authorize one action (`push-grant-lib.sh`'s `pg_grant_consume`); `detail` carries `remote`/`ref`/`sha`/`force`/`mint_source`/`consumer`. |

## `checkpoint` Open String -- Common Values

`checkpoint` is an open, extensible string naming the lifecycle point an event is associated
with. Documented common values:

| Value | Source |
|-------|--------|
| `preflight` | `skill-base.sh` lifecycle stage |
| `context_injection` | `skill-base.sh` lifecycle stage |
| `verification` | `skill-base.sh` lifecycle stage |
| `postflight` | `skill-base.sh` lifecycle stage |
| `GATE_IN` | Command-level checkpoint (`command-gate-in.sh`) |
| `GATE_OUT` | Command-level checkpoint (`command-gate-out.sh`) |
| `phase_{N}` | Implementation phase marker, e.g. `phase_2` |

New checkpoint names may be added by future instrumentation without a schema revision --
`checkpoint` is never validated against a closed list.

## `detail` Open-Object Contract

`detail` carries `event_type`-specific structured data and is validated only as `"type": "object"`
with `additionalProperties: true` -- it imposes no fixed shape. This is deliberate: a completion-
time reflection's nested fields (e.g. `what_worked`, `what_was_hard`, `what_was_missed`,
`successes`) and any future payload shape can be added without revising `events-schema.json`.
When absent, treat `detail` as `{}`.

## `error_ref` Cross-Link Contract

`error_ref`, when present, holds the `id` of an entry in `specs/errors.json` (e.g.
`"err_1736700000"`). It is:

- **Always optional** -- most events have no associated error.
- **Never a hard foreign key** -- readers and writers must not assume `specs/errors.json` exists,
  and must not fail if the referenced ID cannot be resolved. The cross-link is informational only.

## Claude Code OTel Correlation

`events.jsonl` and Claude Code's own OpenTelemetry (OTel) export are two independent signal
tiers with an exact join key between them. This section settles field ownership so a future
reader can tell, for any signal, which side owns it and how to join across.

For the full four-tier source model (OTel, `events.jsonl`, `history.jsonl`, transcripts) and the
binding design constraints for telemetry-consuming `/distill` sub-modes, see
`context/project/memory/telemetry-guardrails.md` in the memory extension -- this section covers
only the `events.jsonl` half of that model.

### What OTel Owns

Read via `CLAUDE_CODE_ENABLE_TELEMETRY=1`; never written by agent-system code:

- Per-tool-call outcome: `tool_result.success`, `.error_type`, `.duration_ms`,
  `.decision_source`.
- Per-API-call outcome: `api_request` / `api_error` / `api_refusal`.
- Token and cost accounting: `claude_code.token.usage`, `.cost.usage`.
- Permission and decision provenance: `tool_decision.source`, `permission_mode_changed`.
- Session aggregates: `claude_code.session.count`, `.active_time.total`.

This is did-it-fail-and-why, and nothing task-, phase-, or plan-shaped -- OTel structurally has
no concept of a task number, a phase, or a plan deviation.

### What `events.jsonl` Owns

The categories `deviation` / `blocker` / `milestone` / `success`, and the `task` /
`checkpoint` fields (all unchanged by this correlation): task numbers, phase and checkpoint
boundaries, plan deviations, completion-time reflections, and the repo tag via the
already-implemented `cwd` field (see "Cross-Repo Federation" above).

### The Exact Join

`cc_session_id` on an `events.jsonl` line equals `session.id` on OTel events, spans, and
metrics for the same Claude Code session. No time-window heuristic is needed or permitted.
`cwd` is the secondary correlator, covering the rare mid-session `CwdChanged` case, and is also
the repo-tag source that makes OTel's non-standard `OTEL_RESOURCE_ATTRIBUTES` opt-in
unnecessary. Note explicitly: `cwd` is **not** a standard OTel resource attribute -- the
standard set is `session.id`, `user.id`, `user.email`, `user.account_uuid`, `user.account_id`,
`organization.id`, `app.version`, `app.entrypoint`, `terminal.type` -- which is exactly why the
repo tag lives on the `events.jsonl` side instead.

### Naming Rule

Top-level `events.jsonl` fields keep flat `snake_case` (`cc_session_id` follows this
convention -- it is **not** named `session.id`, since dotted OTel names never become top-level
`events.jsonl` fields). `gen_ai.*` dotted names appear only as literal keys inside `detail`,
and only when that payload cites OTel-derived evidence -- e.g. a `--revise` correlation event
whose `detail` carries `{"gen_ai.usage.input_tokens": 1200, "error.type": "ENOENT"}` next to the
existing evidence citation. See `telemetry-guardrails.md`'s `gen_ai.*` borrowing rule for the
full vocabulary and its constraints; it is not restated here.

### Schema-Revision Note

`additionalProperties: false` on the schema's top-level object makes `cc_session_id` a
deliberate, versioned revision, exactly like `cwd` before it. Both fields are nullable, so no
backfill is required -- consumers must treat both as optionally-absent, and a legacy row written
before either field existed remains valid.

### The Degraded Path

When `CLAUDE_CODE_ENABLE_TELEMETRY=1` is unset in the user's environment, the OTel tier
contributes nothing. This is an explicitly-announced, first-class outcome -- modeled on the
existing "No Events Yet" degraded-path pattern for an empty `events.jsonl` -- never a silent
gap. A consumer joining on `cc_session_id` and finding no OTel data for that session must
announce "OTel not enabled for this session" rather than silently reporting zero results as if
outcome data had been checked and found empty.

### The Hooks Extension Point

Hooks are the sanctioned mechanism for capturing `cc_session_id` (and `cwd`) from Claude Code's
own context: every hook receives `session_id`, `prompt_id`, `transcript_path`, `cwd`,
`permission_mode`, and `hook_event_name` on stdin, across 30 hook event types. Stop and
SubagentStop additionally carry `last_assistant_message` explicitly, because `transcript_path`
is written asynchronously and may lag the in-memory conversation -- the same reason
`events-log-lifecycle.sh` reads `last_assistant_message` directly rather than the transcript
file for its Stop-path task-number fallback.

## Example Lines

```json
{"event_id":"evt_1736700000123_a1b2c3","event_type":"lifecycle_stage","category":"milestone","timestamp":"2026-07-15T10:22:31.123Z","duration_seconds":4.2,"session_id":"sess_1736700000_abc123","task":259,"checkpoint":"preflight","message":"Preflight completed","detail":{},"error_ref":null,"cwd":"/home/user/.config/nvim","cc_session_id":"3f9c2a10-8b4e-4c3d-9a1f-6e2d5c7b8a90"}
{"event_id":"evt_1736700005456_d4e5f6","event_type":"deviation","category":"deviation","timestamp":"2026-07-15T10:22:36.456Z","duration_seconds":null,"session_id":"sess_1736700000_abc123","task":259,"checkpoint":"phase_2","message":"Skipped optional retry step","detail":{"reason":"Not needed for this input size"},"error_ref":null,"cwd":"/home/user/.config/nvim","cc_session_id":"3f9c2a10-8b4e-4c3d-9a1f-6e2d5c7b8a90"}
{"event_id":"evt_1736700010789_g7h8i9","event_type":"blocker","category":"blocker","timestamp":"2026-07-15T10:22:41.789Z","duration_seconds":null,"session_id":"sess_1736700000_abc123","task":259,"checkpoint":null,"message":"Missing external credential","detail":{},"error_ref":"err_1736700000","cwd":null,"cc_session_id":null}
```

The third line shows the `null` case for both `cwd` and `cc_session_id` -- a call site with no
reliable source for either field.

## Related Documentation

- [Events Schema](../schemas/events-schema.json) -- formal draft-07 JSON Schema for a single line
- [Return Metadata Format](return-metadata-file.md) -- `session_id`/`duration_seconds` convention
- [Error Handling Rule](../../rules/error-handling.md) -- `errors.json` schema and `error_ref` target
- Telemetry Guardrails (`context/project/memory/telemetry-guardrails.md` in the memory
  extension) -- the full four-tier source model and binding design constraints for
  telemetry-consuming `/distill` sub-modes
