# Dispatch Metrics Format

## Overview

`specs/{NNN}_{SLUG}/metrics.jsonl` is the per-task, append-only cost-and-timing capture log for
every orchestration dispatch — one line per dispatch, covering completion, partial, and blocked
outcomes alike. It exists because, measured directly against a live repository, no token, cost,
model, or tool-call figure is recorded anywhere under `specs/` today: those figures exist only
inside Claude Code's own transcripts, which roll off disk on a 30-day retention window (see
"The 30-Day Retention Window" below). Without this record, the cost of an orchestration is not
merely unreported — it is unrecoverable once the transcript is gone.

This document specifies the per-line schema, the exact transcript join procedure, three measured
traps that have already misled analysis and MUST NOT be repeated, the omission-not-zeroing rule,
and the `--backfill` marking contract.

**Single writer**: `scripts/dispatch-metrics.sh` is the only script that appends to this file.
See its header comment for the full CLI contract; this document is the schema and policy
contract it implements against. It is structured as a close sibling of
`context/formats/issue-log.md` (same per-task append-only shape, same lazy-creation,
flock-guarded, `jq -c -n`-built-line discipline) — read that document for the pattern this one
follows, rather than re-deriving it here.

## File Location

```
specs/{NNN}_{SLUG}/metrics.jsonl
```

One file per task directory, sibling to that task's `.return-meta.json`, `issues.jsonl`,
`plans/`, `reports/`, and `summaries/`.

## Lazy Creation and Never-Gitignored

- The file is **not** pre-created. It comes into existence the first time
  `dispatch-metrics.sh` is invoked for that task — mirroring `issues.jsonl`'s and
  `events.jsonl`'s lazy-creation convention.
- Once created, it is a normal tracked file and is **never gitignored**. Its lock file,
  `.metrics.lock`, is the ephemeral half and IS gitignored, matching `issues.jsonl`'s
  `.issues.lock` precedent.
- One JSON object per line, built with `jq -c -n` and appended under `flock`, never by string
  concatenation and never by a read-merge-rewrite — this file is append-only-by-line.

## CAPTURE ONLY — No Reporting Here

This task produces the record only. Any reporting, aggregation, dashboard, or cross-task rollup
over `metrics.jsonl` is a separate, later concern — mirroring `issue-log.md`'s own capture-only
boundary. Nothing here is surfaced mid-run or acted on automatically.

## Entry Field Table

Each line is exactly one JSON object. **Conditionally-present fields are OMITTED (absent key),
never `null`-as-zero and never `0`, when their underlying figure is unavailable** — see
"The Omission Rule" below, which applies to every field marked "no (omit when unavailable)".

| Field | Required | Type | Notes |
|-------|----------|------|-------|
| `entry_id` | yes | string | `met_{timestamp_ms}_{random6}`, mirroring `issues.jsonl`'s `iss_...` and `events.jsonl`'s `evt_...` conventions. |
| `recorded_at` | yes | string | ISO 8601 UTC, matching every other timestamp convention in this codebase. |
| `task` | yes | integer | The task number this dispatch belongs to. |
| `phase` | yes | string (closed: `research` \| `plan` \| `implement` \| `aux` \| `conclusion` \| `other`) | The lifecycle phase of the dispatch. Refuses loudly on an unrecognized value. |
| `agent` | yes | string | The dispatched agent's name, verbatim (e.g. `general-implementation-agent`). |
| `outcome` | yes | string (closed: `completed` \| `partial` \| `blocked` \| `failed` \| `deferred`) | Refuses loudly on an unrecognized value. |
| `dispatch_seq` | yes | integer | The cycle's own minted dispatch sequence number for this dispatch. |
| `session_id` | yes | string | The agent-system `sess_{timestamp}_{random}` value for the recording dispatch. |
| `wall_clock_seconds` | no (omit when unavailable) | number | Dispatch start (`.dispatch/{seq}.md`'s `dispatch_start_ts`) to postflight return. **This is NOT `events.jsonl`'s `duration_seconds`** — see Trap (a) below. Omitted (never negative, never zero-as-placeholder) when `dispatch_start_ts` is absent or carries the fail-closed sentinel `9999999999`. |
| `backfilled` | yes | boolean | `false` on every record written by the live postflight call site. `true` on every record written by `--backfill N` — see "The `--backfill` Marking Contract" below. |
| `cc_session_id` | no (omit when unknown) | string | Claude Code's own native session UUID (`$CLAUDE_CODE_SESSION_ID`). Recorded whenever known, **including when the transcript join itself failed** — it is the durable join key for any later recovery attempt within the retention window. |
| `model` | no (omit when the join fails or yields no model) | string \| array of string | The live model actually used, read from the matched transcript's `message.model` field — **not** the model a `--sonnet`/`--opus`/`--fable` flag requested. When more than one distinct model appears across the transcript, this is the **set** of distinct values, not a single arbitrarily-picked one. |
| `tokens` | no (omit the whole sub-object when the join fails) | object `{input, cache_creation, cache_read, output}` | Summed from `message.usage.{input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens}` across every `type: "assistant"` line in the matched transcript. Every one of the four classes is itself omitted individually if a transcript line lacks it — never summed as if it were `0`. |
| `tool_calls` | no (omit the whole sub-object when the join fails) | object `{total, by_name{}}` | `total` counts every `message.content[]` entry of `type: "tool_use"` across the transcript; `by_name` tallies the same entries keyed by their `name` field. |
| `phases_completed` | no (omit when not applicable to this dispatch) | integer | How many plan phases this dispatch closed, mirroring the handoff/`.return-meta.json` field of the same name. |
| `phases_total` | no (omit when not applicable to this dispatch) | integer | The plan's total phase count, mirroring the handoff/`.return-meta.json` field of the same name. |
| `commits` | no (omit when the git query fails or finds none) | object `{count, subjects[]}` | Derived from `git log --since="@${dispatch_start_ts}" --grep="$session_id"` over the repo root. **Deliberately excludes the postflight bookkeeping commit** that stages this very metrics record. |
| `churn` | no (omit either or both halves when the git query fails) | object `{specs{added,removed}, outside_specs{added,removed}}` | `git log --numstat` over the same commit set as `commits`, summed separately for pathspec `specs/` and `':!specs/'`. **The split matters**: `specs/` churn is bookkeeping, `outside_specs/` churn is product — collapsing the two into one number erases that distinction. |
| `gate_runs` | no (omit when the transcript does not show gate/verification invocations with durations) | array or object | Populated **only** where the transcript genuinely shows gate/verification invocations with durations. Where it does not, this key is absent — never a synthesized zero, never an inferred duration. |
| `transcript` | no (omit when the join fails) | object `{path, span_seconds}` | `path` is the matched transcript file; `span_seconds` is the first-to-last-line `timestamp` span, recorded as a **secondary corroboration of wall-clock only** — `wall_clock_seconds` from `dispatch_start_ts` stays the primary figure, and a missing transcript must never block emission of the rest of the record. |
| `figure_provenance` | no (omit on an unmarked/measured record) | object | Present only on a `backfilled: true` record (or a record where a backfill run opportunistically re-joined the transcript). Maps each present figure's name to `measured` or `derived`. Absent entirely on an ordinary live-postflight record — see "The `--backfill` Marking Contract" below. |

### Worked Example (live postflight record, join succeeded)

```json
{"entry_id":"met_1759539743123_a1b2c3","recorded_at":"2026-10-03T23:42:23Z","task":42,"phase":"implement","agent":"general-implementation-agent","outcome":"completed","dispatch_seq":5,"session_id":"sess_1759539700_ab12cd","wall_clock_seconds":4123.7,"backfilled":false,"cc_session_id":"53633f54-4eac-4b2d-b1d5-f641d51ec21d","model":"claude-sonnet-5","tokens":{"input":842,"cache_creation":312004,"cache_read":1882391,"output":9112},"tool_calls":{"total":187,"by_name":{"Read":62,"Bash":94,"Edit":28,"Write":3}},"phases_completed":3,"phases_total":7,"commits":{"count":2,"subjects":["phase 1: freeze the record schema","phase 2: skeleton and transcript-free fields"]},"churn":{"specs":{"added":120,"removed":30},"outside_specs":{"added":640,"removed":45}},"transcript":{"path":"/home/benjamin/.claude/projects/-home-benjamin--config-nvim/53633f54-4eac-4b2d-b1d5-f641d51ec21d/subagents/agent-aad1158bea446f08d.jsonl","span_seconds":4089.2}}
```

### Worked Example (transcript gone — omitted, never zeroed)

```json
{"entry_id":"met_1759539800456_d4e5f6","recorded_at":"2026-10-03T23:43:20Z","task":42,"phase":"implement","agent":"general-implementation-agent","outcome":"partial","dispatch_seq":6,"session_id":"sess_1759539700_ab12cd","wall_clock_seconds":891.0,"backfilled":false}
```

Note the second example has **no** `tokens`, `tool_calls`, `model`, `cc_session_id`, `commits`,
`churn`, `transcript`, or `gate_runs` keys at all — not `null`, not `0`, simply absent.

## The Omission Rule

An unavailable figure is an **ABSENT key**, never `0` and never `null`-as-zero. A `0` is a false
measurement — it asserts "this dispatch used zero tokens" when the truth is "this dispatch's
token usage could not be read." This applies identically to `tokens` (and each of its four
classes individually), `tool_calls`, `model`, `gate_runs`, `commits`, `churn`, `transcript`, and
`wall_clock_seconds`-with-a-sentinel-start. This is an acceptance-tested property of
`dispatch-metrics.sh` (see `scripts/tests/test-dispatch-metrics.sh`'s required tests), not a
style convention a future edit might casually relax.

## The Exact Join Procedure

The join from a dispatch to its own transcript is **exact, never heuristic**:

1. Resolve `cc_session_id`: `--cc-session-id` if passed explicitly, else
   `${CLAUDE_CODE_SESSION_ID:-}` read live from the environment. This is the **lead** session's
   id — identical inside a dispatched subagent's own Bash tool calls, confirmed live.
2. Derive the project-directory slug from the repo root: every non-alphanumeric character in the
   absolute repo-root path is replaced with `-`. Worked example:
   `/home/benjamin/.config/nvim` → `-home-benjamin--config-nvim`. This is a single named
   function (`metrics_project_slug`), never an inline one-off `sed`, specifically so it can carry
   its own unit test.
3. Enumerate candidates:
   `~/.claude/projects/<slug>/<cc_session_id>/subagents/agent-*.jsonl`.
4. For each candidate, read **only its first line**. That line is always a `type: "user"` record
   whose `message.content` is a plain string embedding the dispatch prompt's `Context` JSON block
   verbatim, including `"task_number": N` and `"dispatch_seq": M` as literal substrings (once the
   JSON string's own escaping is unwound — e.g. via `jq -r '.message.content'`, never raw-grepped
   against the still-escaped line).
5. Accept the single candidate whose first line contains BOTH this dispatch's own `task_number`
   AND its `dispatch_seq` as exact matches (anchored so `330` does not match `3300`, and so
   `12` does not match `120` or `212`). Candidate selection is **never** nearest-timestamp
   matching and **never** `.meta.json`'s `description` field matching — the sidecar's
   `description` is at most a sanity check and cannot disambiguate re-dispatches of the same
   task+phase across cycles.
6. Zero matches, more than one match, an absent directory, an absent session subtree, an
   unparseable line, or a missing `jq` — every one of these fails soft: a distinct stderr note,
   and every transcript-derived field OMITTED from the record. Never a raise, never a `0`, never
   an arbitrary pick among multiple matches.

Confirmed Claude Code version at the time this join was designed and tested: **2.1.288**. An
unexpected directory shape (Claude Code changing its on-disk transcript layout again — it has
done so once already) fails soft by the same rule above, rather than raising.

From the matched file, once found:

- **`model`**: read `message.model` from every `type: "assistant"` line. Record the distinct
  value, or the distinct **set** of values when more than one model appears across the
  transcript — never silently collapse to one.
- **`tokens`**: sum `message.usage.{input_tokens, cache_creation_input_tokens,
  cache_read_input_tokens, output_tokens}` across every `type: "assistant"` line. Omit a class
  individually if some line lacks it, rather than treating the missing reading as `0`.
- **`tool_calls`**: count every `message.content[]` entry of `type: "tool_use"` into `.total`,
  tallied by `.name` into `.by_name`.
- **`gate_runs`**: populated only where the transcript genuinely shows gate/verification
  invocations with durations. Absent otherwise.
- **`transcript.span_seconds`**: the first-to-last-line `timestamp` span, recorded purely as
  secondary corroboration of `wall_clock_seconds` — never the primary figure.

## Four Measured Traps — Named Warnings

Each of the following has already misled analysis in this codebase and MUST NOT be repeated.

### Trap (a): `events.jsonl`'s `duration_seconds` is NOT phase duration

`duration_seconds` on an `events.jsonl` `lifecycle_stage` event is **the hook script's own
runtime** — measured range 0.2–2.6 seconds. A real dispatch's wall-clock is on the order of
hundreds to thousands of seconds. Treating `duration_seconds` as phase duration is wrong by
**three orders of magnitude**. The correct per-dispatch wall-clock anchor is
`.dispatch/{seq}.md`'s own `dispatch_start_ts` field, measured against the time of the postflight
call that writes this record.

### Trap (b): `dispatch_seq` is NOT a dispatch count

The `dispatch_seq_counter` advances roughly **3 per dispatch**, because
`orchestrate-cycle-plan.sh` mints a new sequence number at several sub-steps within one cycle.
Counting distinct `dispatch_seq` values (or taking the final counter value) as "number of
dispatches" overcounts by roughly 3x. The correct dispatch count is derived from `events.jsonl`
lines with `event_type == "lifecycle_stage"` and `checkpoint == "preflight"`, filtered to the
task in question — this is exactly what `--backfill` mode does (see below).

### Trap (c): per-phase wall-clock comes from phase-commit timestamps, not from (a) or (b)

Per-dispatch wall-clock comes from `dispatch_start_ts` (Trap (a)'s correct anchor). Per-**phase**
wall-clock — a different, coarser-grained figure spanning potentially several dispatches — comes
from **phase-commit timestamps** (the `git log` timestamps of commits matching the
`{N} phase {P}: {name}`-shaped commit-subject convention documented in `rules/git-workflow.md`),
never from `events.jsonl`'s `duration_seconds` and never from counting `dispatch_seq` values.

### Trap (d): `--backfill N` selects commits by subject grep, which task-number reuse breaks

`--backfill N` finds the dispatches to reconstruct by grepping commit subjects for this repo's
`task N:` / `task N phase P:` convention. Task numbers are **not durable** — they are renumbered
by vault operations (see `rules/state-management.md`), so number `N` may have belonged to an
entirely unrelated task earlier in history, and that task's commits match the same grep.

Measured: `--backfill 329` run live matched **20 commits**, including commits from an unrelated
historical task that had also carried number 329 for a typst-primary documentation update. The
extra commits are not distinguishable from the intended ones by subject alone.

Consequences for anyone reading or writing backfilled records:

- A `backfilled: true` record's `commits` block may over-count, and any figure derived from it
  (notably `churn`) may aggregate unrelated work. `figure_provenance` marks such figures
  `derived`, never `measured` — treat a `derived` figure from a backfill run as an upper bound.
- Do **not** persist a backfill run's output into a task directory without first checking the
  matched subjects. The live run above was deliberately not persisted for this reason.
- A live postflight record (`backfilled: false`) is unaffected: it counts only commits made
  between `dispatch_start_ts` and the postflight run, with no subject grep involved.

This is a known, documented limitation, not a defect to work around silently. Making the
selection reuse-safe requires a durable per-dispatch commit key rather than a subject grep, which
is tracked as its own work item.

## The 30-Day Retention Window — Capture at Postflight Time, Not Later

Tier 4 transcripts (see
`context/project/memory/telemetry-guardrails.md`'s "Tier 4: Transcripts and `.meta.json`
Sidecars" section) have a **measured 30-day retention window**. Token and tool-call figures are
therefore perishable: they MUST be read and written at **postflight time**, while the transcript
is still on disk. A design that defers transcript reading to report time silently produces empty
metrics for anything older than a month — this is precisely why `dispatch-metrics.sh` is called
from `orchestrate-cycle-postflight.sh` directly, rather than from any later reporting pass.
`--backfill` mode (below) exists for the case where a task completed before this capture
mechanism was wired in, or where postflight's own call failed non-fatally; it recovers what is
still derivable and marks the rest as unrecoverable, rather than pretending the perished figures
can be reconstructed.

## The `--backfill` Marking Contract

`dispatch-metrics.sh --backfill N` derives, for an already-completed task `N`, what is **still**
derivable without a live transcript, emitting one record per recovered phase-commit (subjects
matching the `{N}: {action}` / `{N} phase {P}: {name}` commit-subject convention documented in
`rules/git-workflow.md`):

- Per-phase wall-clock as the delta between each recovered phase-commit's timestamp and its
  predecessor's (Trap (c)'s correct source; the first recovered commit carries no
  `wall_clock_seconds` since it has no predecessor).
- A dispatch count from `events.jsonl`'s `lifecycle_stage`/`preflight` events (Trap (b)'s correct
  source), filtered to the task and reported to stderr as a corroborating diagnostic — it is
  **not** written into any individual record, since no single phase-commit maps uniquely to one
  dispatch count.
- Git churn over the task's full recovered commit range (every matched phase-commit, summed via
  `git show --numstat`), split `specs/` vs `':!specs/'`. Computed **once** per `--backfill`
  invocation and attached identically to every record it emits — not recomputed per commit.
- `session_id`, when recoverable from a commit's own body (the `Session: sess_{...}` trailer
  `git-workflow.md`'s commit-message convention already carries); omitted otherwise.

`agent`, `dispatch_seq`, `cc_session_id`, `model`, `tokens`, and `tool_calls` are **omitted
entirely** on every backfilled record in the current implementation: none is recoverable from git
history alone, and the exact-match transcript join (`metrics_transcript_join`) requires a known
`dispatch_seq`, which a historical commit does not carry. A future enhancement could attempt the
opportunistic re-join this document's design anticipated — for a transcript still inside the
30-day window, if a correlating `cc_session_id`/`dispatch_seq` pair can be recovered by some other
means — but the current implementation does not attempt it; this is a recorded limitation, not an
implied claim that it runs today.

Every record `--backfill` writes carries `backfilled: true` at the top level, plus a populated
`figure_provenance` object mapping each present figure's name to `measured` or `derived`. An
**unmarked** record (no `backfilled` key at all is never valid — `backfilled: false` is the
unmarked/measured state) is measured throughout; a record with `backfilled: true` has at least
one derived figure, named explicitly in `figure_provenance` (`commits` is `measured` — the
subject is read verbatim off the commit; `wall_clock_seconds`, when present, and `churn` are
always `derived`). Token and tool-call figures are **omitted, never zeroed** — exactly the same
omission rule as the live path.

## Non-Blocking Posture

A metrics-recording failure **never** fails a dispatch, never changes a task's status, and never
emits a user-facing error. This is the identical posture `issue-record.sh`,
`update-task-status.sh`, and `state-write.sh --regen-todo` already carry. Every call site uses
the mandatory non-fatal invocation idiom:

```bash
bash .claude/scripts/dispatch-metrics.sh ... \
  >/dev/null 2>&1 || echo "Note: dispatch-metrics recording failed (non-fatal)" >&2
```

`dispatch-metrics.sh`'s own stdout on success is exactly one line: the appended record's
`entry_id`. All diagnostics go to stderr.

## Cross-References (Not Duplicated Here)

- `context/project/memory/telemetry-guardrails.md`'s "Tier 4: Transcripts and `.meta.json`
  Sidecars" section — the 30-day window and blind-spot statement this document's own retention
  section is built on. This document does not attempt the absent `sess_*`-to-OTel join that
  telemetry-guardrails.md records as a structural gap, and respects its
  evaluator-outside-the-loop constraint: nothing here proposes automated action from these
  figures.
- `context/formats/issue-log.md` — the sibling per-task append-only record this format
  deliberately mirrors in shape (lazy creation, never-gitignored, `flock`-guarded `jq -c -n`
  append, non-blocking posture). `issues.jsonl` and `metrics.jsonl` are sibling logs and should
  stay structurally consistent as both evolve.
- `context/formats/events-format.md`'s "Claude Code OTel Correlation" section — the other capture
  path for `cc_session_id` (via hook stdin's top-level `.session_id` field), independent of the
  `$CLAUDE_CODE_SESSION_ID` environment read this document's join procedure uses.
