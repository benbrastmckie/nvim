# Implementation Plan: Task #330

- **Task**: 330 - Per-dispatch cost and timing record
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: Task 329 (per-task issue log) — already `[COMPLETED]`; its `issue-record.sh`
  call sites are live in the same file this task edits, so the file-footprint serialization
  hazard named in the task description no longer applies
- **Research Inputs**: specs/330_per_dispatch_cost_and_timing_record/reports/01_dispatch-metrics-script-design.md
- **Artifacts**: plans/01_dispatch-metrics-record.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build `dispatch-metrics.sh` as a close structural sibling of the already-shipped
`issue-record.sh`: one script, two modes (live postflight capture and `--backfill N`), appending
exactly one `flock`-guarded JSON line per dispatch to a per-task `metrics.jsonl`. The one piece of
genuine new complexity is the Claude Code transcript join — derive the project-directory slug from
the repo root, locate `$CLAUDE_CODE_SESSION_ID/subagents/agent-*.jsonl`, and select the right
candidate by exact-matching this dispatch's own `task_number` and `dispatch_seq` embedded verbatim
in the transcript's first (`user`-type) line — which yields model, per-class token totals, and a
per-tool call breakdown. Everything else (wall-clock from `dispatch_start_ts`, outcome,
`phases_completed`, commits, specs/-vs-outside-specs/ churn) is derivable without the transcript
and must keep working when the transcript is gone. Missing data is **omitted, never zeroed**.

**THE EDIT TARGET IS THE SOURCE STORE**: every file below lives under
`agent-system/extensions/core/`. Nothing is hand-authored under `.claude/**` — that tree is a
gitignored deploy artifact wiped by the next deploy (`rules/source-root-deploy-boundary` /
`rules/source-store-deploy-boundary.md`). Paths in this plan are relative to
`agent-system/extensions/core/` unless stated otherwise. No task-number references may appear in
any file written into the source store; cite filenames, section headings, and field names instead.

### Research Integration

Findings from the research report that this plan is built on, and which supersede the task
description where they conflict:

1. **The task description's transcript path shape is wrong and must not be coded against.** It
   claims flat siblings `~/.claude/projects/<slug>/agent-*.jsonl`. The confirmed live layout is
   nested: `~/.claude/projects/<slug>/<cc_session_id>/subagents/agent-<id>.jsonl` with a sibling
   `agent-<id>.meta.json` (`agentType`, `description`, `toolUseId`, `spawnDepth`). Re-confirmed
   during planning against this very session's own tree.
2. **The join is exact, not heuristic.** `cc_session_id` is the live
   `$CLAUDE_CODE_SESSION_ID` environment variable, readable in-process at the postflight call
   site (re-confirmed during planning: the value names the *lead* session and is identical inside
   a dispatched subagent's own bash calls). Each candidate transcript's first line is a
   `type: "user"` record whose `message.content` embeds the dispatch prompt's Context JSON block
   verbatim, including `"task_number"` and `"dispatch_seq"` — re-confirmed during planning by
   parsing a live `agent-*.jsonl` first line. Never nearest-timestamp, never
   `.meta.json`-description matching.
3. **Task 329 is already complete**, so `dispatch-metrics.sh` call sites can be added directly
   alongside the live `issue-record.sh` calls, following the identical non-fatal idiom.
4. **All three measured traps independently confirmed**: `events.jsonl`'s `duration_seconds` is
   the hook stage's own runtime (computed in `scripts/skill-base.sh` via
   `awk ... b-a` around a single preflight stage); `dispatch_seq` advances ~3 per dispatch
   because `orchestrate-cycle-plan.sh` mints at several sub-steps of one cycle; per-dispatch
   wall-clock has no `events.jsonl` field at all and must come from `dispatch_start_ts`.

Additional measurements taken during planning, beyond the research report:

5. **`scripts/dispatch-metrics.sh` and `scripts/tests/test-dispatch-metrics.sh` must be registered
   in `manifest.json`'s `provides.scripts` array or they will never deploy.** `provides.context`
   lists whole directories (including `formats`), so the new format doc deploys automatically —
   but `provides.scripts` is an individual-file list (`issue-record.sh` at ~line 109,
   `tests/test-issue-record.sh` at ~line 217). This is the single most easily-missed step in the
   whole task.
6. **A new context file also needs an `index-entries.json` entry** (source store, sibling of
   `manifest.json`) with `path`/`domain`/`subdomain`/`summary`/`line_count`/`keywords`/`topics`/
   `load_when`; `scripts/validate-context-index.sh` checks `line_count` approximately.
   `formats/issue-log.md`'s entry (~line 3601) is the template.
7. **The `dispatch_status` case statement has seven arms, not three** (`researched)`, `planned)`,
   `implemented)`, `partial)`, `failed|blocked)`, `needs_research)`, `*)`), and the whole statement
   sits inside `if [ "$have_outcome" = "true" ]`. The `partial)` arm's existing `issue-record.sh`
   call is gated on `partial_blocker_count -gt 0`, so a metrics call placed *inside* that gate
   would silently skip every ordinary in-flight partial. See Decision D2.
8. **Every `exit` in `orchestrate-cycle-postflight.sh` is an argument-validation exit before
   ~line 350**; there is no early exit between the status-transition case statement and the
   per-task commit. A single call site sited before the commit is therefore reached by every
   dispatch that survives argument validation.
9. **The per-task commit at WORK (i) stages `"${TASK_DIR}/"` wholesale**, so a `metrics.jsonl`
   written before that commit is committed with the work it describes — the same property
   `issues.jsonl` already enjoys.

### Prior Plan Reference

No prior plan. This is the task's first planning round.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and no roadmap flag was set;
no roadmap phases are included and no roadmap file was read or written.

## Goals & Non-Goals

**Goals**:
- One line per dispatch in `specs/{NNN}_{SLUG}/metrics.jsonl`, written at postflight time while
  the transcript is still on disk, covering completion, partial and blocked outcomes.
- Wall-clock measured from `.dispatch/{seq}.md`'s `dispatch_start_ts` to return — demonstrably
  not hook runtime.
- Token totals by class, live model, and tool-call counts read from the matched transcript;
  **omitted, not zeroed**, whenever the join fails for any reason.
- Line churn split into inside-`specs/` and outside-`specs/` halves.
- `--backfill N` producing explicitly marked-as-backfilled derived figures for an
  already-completed task, omitting what is unrecoverable.
- A metrics failure never fails a dispatch, never changes status, never surfaces a user-facing
  error.
- A written record schema (`context/formats/dispatch-metrics.md`) stating the join procedure, the
  three measured traps as named warnings, and the 30-day retention window.

**Non-Goals**:
- Any reporting, aggregation, dashboard, or cross-task rollup over `metrics.jsonl`. This task
  produces the record only; consumption is a separate concern (mirroring `issue-log.md`'s own
  capture-only boundary).
- Any `sess_*`-to-OTel join. `context/project/memory/telemetry-guardrails.md` records that join
  as absent; this task does not attempt to create it.
- Cost in currency. Token counts by class and the model name are recorded; price-per-token
  multiplication is deliberately left out (prices change and are not on disk).
- Changing `events.jsonl`'s schema, `issue-record.sh`, or `orchestrate-churn.sh`.
- Promoting the slug-derivation rule into `telemetry-guardrails.md` (a named follow-up in the
  research report's Context Extension Recommendations, not this task).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Slug derivation reimplemented wrongly, silently yielding "no transcript found" forever | H | M | Own named function + dedicated unit test asserting the exact confirmed mapping `/home/benjamin/.config/nvim` -> `-home-benjamin--config-nvim`; never an inline one-off `sed` |
| Missing transcript silently recorded as `0` tokens, poisoning every later analysis | H | M | Omission is a tested acceptance criterion (Phase 5), not a convention; `jq` builds the line from `null`-valued variables that are dropped, never defaulted to `0` |
| New scripts not registered in `manifest.json` → never deployed, silently dead | H | M | Registration is an explicit task inside Phases 2 and 5, and Phase 7 verifies the deployed copies exist |
| Metrics call placed inside the `partial)` arm's blocker gate, skipping ordinary partials | M | M | Decision D2: one call site outside every arm-local gate; Phase 7 verifies a partial with no blockers still produces a line |
| Claude Code changes its on-disk transcript layout again (it already has once) | M | M | Join fails soft (log-and-omit, never raise); format doc names the confirmed version `2.1.288` |
| `orchestrate-cycle-postflight.sh` line numbers drift (other tasks edit this file) | M | H | Every phase touching it carries a Scope Hypothesis requiring re-measurement by anchor text, never by line number |
| A metrics bug propagates as a dispatch failure | H | L | Non-fatal call idiom copied verbatim from the live `issue-record.sh` call sites; Phase 5 tests that an induced failure does not fail the caller |
| `--backfill` figures later mistaken for measured figures | M | M | Per-record `backfilled: true` marker plus a `figure_provenance` object; the format doc states that an unmarked record is measured and a marked one is derived |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5, 6 | 3, 4 |
| 5 | 7 | 5, 6 |

Phases within the same wave can execute in parallel. Phase 5 (tests + manifest) and Phase 6
(postflight call site) touch disjoint files and are genuinely parallel-safe; Phase 6's only
dependency on Phase 3 is that the script's argument surface is final before a call site is
written against it.

---

### Phase 1: Freeze the Record Schema in `context/formats/dispatch-metrics.md` [COMPLETED]

**Goal**: A written record contract exists before any code is written against it, so the script,
the tests, and the format doc cannot drift. This phase is prose only.

**Tasks**:
- [x] Create `context/formats/dispatch-metrics.md`, patterning its shape on *(completed)*
      `context/formats/issue-log.md` (file-location section, field table, worked JSON example,
      closed-enum admission tables, boundary section).
- [x] State the file location: `specs/{NNN}_{SLUG}/metrics.jsonl`, lazily created on first use, *(completed)*
      never gitignored, append-only by line, one line per dispatch.
- [x] Define the field table. Required on every record: `entry_id` *(completed)*
      (`met_{timestamp_ms}_{random6}`), `recorded_at`, `task`, `phase`, `agent`, `outcome`,
      `dispatch_seq`, `session_id`, `wall_clock_seconds`, `backfilled`. Conditionally present:
      `cc_session_id`, `model`, `tokens{input, cache_creation, cache_read, output}`,
      `tool_calls{total, by_name{}}`, `phases_completed`, `phases_total`,
      `commits{count, subjects[]}`, `churn{specs{added, removed}, outside_specs{added, removed}}`,
      `gate_runs`, `transcript{path, span_seconds}`, `figure_provenance{}`.
- [x] State the closed enums: `phase` ∈ `research|plan|implement|aux|conclusion|other`; *(completed)*
      `outcome` ∈ `completed|partial|blocked|failed|deferred`. Both refuse loudly on an
      unrecognized value, matching `issue-record.sh`'s posture for its true closed-set fields.
- [x] State the **omission rule** explicitly and prominently: an unavailable figure is an *(completed)*
      ABSENT key, never `0` and never `null`-as-zero. A `0` is a false measurement. This applies
      to `tokens`, `tool_calls`, `model`, and `gate_runs` alike — and `gate_runs` is recorded as
      absent, not zero, wherever the transcript does not show gate invocations.
- [x] State the exact join procedure: `$CLAUDE_CODE_SESSION_ID` → *(completed)*
      `~/.claude/projects/<slug>/<cc_session_id>/subagents/agent-*.jsonl`, `<slug>` = repo root
      with every non-alphanumeric character replaced by `-` (worked example:
      `/home/benjamin/.config/nvim` → `-home-benjamin--config-nvim`), candidate selected by exact
      match of `task_number` AND `dispatch_seq` against the candidate's first `type: "user"`
      line. Name the confirmed Claude Code version (`2.1.288`) and state that an unexpected
      directory shape fails soft.
- [x] State the **three measured traps as named warnings**, each with its measured evidence: *(completed)*
      (a) `events.jsonl`'s `duration_seconds` is the hook script's own runtime (measured range
      0.2–2.6 s) and is NOT phase duration — treating it as such is wrong by three orders of
      magnitude; (b) `dispatch_seq` is NOT a dispatch count (advances ~3 per dispatch); (c)
      per-dispatch wall-clock comes from `.dispatch/{seq}.md`'s `dispatch_start_ts`, and
      per-phase wall-clock from phase-commit timestamps — never from either of the above.
- [x] State the **30-day transcript retention window** and the consequence: token and tool-call *(completed)*
      figures are perishable and MUST be captured at postflight time; a design that defers
      transcript reading to report time silently produces empty metrics for anything older than
      a month.
- [x] State the `--backfill` marking contract: `backfilled: true` at record level plus a *(completed)*
      `figure_provenance` object mapping each present figure to `measured` or `derived`; an
      unmarked record is measured throughout.
- [x] State the non-blocking posture: a metrics failure never fails a dispatch, never changes *(completed)*
      status, never emits a user-facing error — warn on stderr and continue; and give the
      mandatory non-fatal call idiom verbatim.
- [x] Cross-reference (do not duplicate) `context/project/memory/telemetry-guardrails.md`'s *(completed)*
      "Tier 4: Transcripts and `.meta.json` Sidecars" section, `context/formats/issue-log.md` as
      the sibling record shape, and `context/formats/events-format.md`'s Claude Code OTel
      Correlation section for `cc_session_id`'s other capture path. Honour
      `telemetry-guardrails.md`'s absent `sess_*`-to-OTel join and evaluator-outside-the-loop
      constraints.
- [x] Add the matching entry to `index-entries.json` (source store), copying the *(completed)*
      `formats/issue-log.md` entry's field set; set `line_count` to the file's real line count.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `context/formats/dispatch-metrics.md` - new file: the record schema, join procedure, three
  traps, retention window, backfill marking, non-blocking posture
- `index-entries.json` - new context-index entry for the format doc

**Verification**:
- `context/formats/dispatch-metrics.md` exists, is non-empty, and contains a field table, both
  closed-enum tables, all three named trap warnings, the 30-day window, and the omission rule.
- `grep -c 'dispatch-metrics.md' index-entries.json` returns 1 and `jq . index-entries.json`
  parses.
- `grep -rn 'task 3[0-9][0-9]\|tasks [0-9]' context/formats/dispatch-metrics.md` returns nothing
  (no task-number references in a source-store deliverable).

---

### Phase 2: `dispatch-metrics.sh` — Skeleton and Transcript-Free Fields [COMPLETED]

**Goal**: A deployable, runnable `dispatch-metrics.sh` that appends a complete record using only
figures derivable without the transcript, with the arg surface, enums, locking, and append path
final.

**Tasks**:
- [x] Create `scripts/dispatch-metrics.sh` with `set -euo pipefail` (Class A per *(completed)*
      `context/standards/shell-strict-mode.md` — an ordinary non-counter writer script), the
      `SCRIPT_DIR`/`common_repo_root`/`deploy-root-guard.sh`/`task-lookup-lib.sh` preamble copied
      structurally from `scripts/issue-record.sh`, and a header comment block in the same shape
      (usage, single responsibility, source-store-not-runnable note, mandatory non-fatal call
      idiom, exit codes).
- [x] Argument surface: `--task-dir PATH` (absolute verbatim, relative against `PROJECT_ROOT`) or *(completed)*
      `--task N` (via `task_lookup_entry`/`task_lookup_dir`); `--phase`, `--agent`, `--outcome`,
      `--dispatch-seq`, `--dispatch-start-ts`, `--session`, `--cc-session-id`,
      `--phases-completed`, `--phases-total`. Closed-set `--phase`/`--outcome` refuse loudly on
      an unrecognized value; required-and-empty refuses with nothing written (exit 1).
- [x] `entry_id` as `met_{timestamp_ms}_{random6}`, mirroring `issue-record.sh`'s construction. *(completed)*
- [x] `wall_clock_seconds` = now − `--dispatch-start-ts`. Refuse to emit the figure (omit it) when *(completed)*
      `dispatch_start_ts` is absent or equals the caller's fail-closed sentinel `9999999999`,
      rather than emitting a negative or absurd number. Add an inline comment naming the
      hook-runtime trap so a future reader cannot mistake the provenance.
- [x] Commits and churn: `git log --since="@${dispatch_start_ts}" --grep="$session_id"` over the *(completed)*
      repo root for `commits.count` and `commits.subjects[]`; `git log --numstat` over that same
      commit set, summed separately for pathspec `specs/` and `':!specs/'`, for
      `churn.specs{added,removed}` and `churn.outside_specs{added,removed}`. Both halves are
      omitted when the git query fails or the repo root is not a git tree.
- [x] Append exactly one `jq -c -n`-built line (never string concatenation) to *(completed)*
      `${TASK_DIR}/metrics.jsonl` under `flock -x` on `${TASK_DIR}/.metrics.lock`, lazily creating
      the target on first use. Never read-merge-rewrite.
- [x] Build the line so that every conditionally-present field is **dropped when unavailable**, *(completed)*
      not defaulted — e.g. assemble optional sub-objects as `jq` arguments that are omitted from
      the object construction when their source variable is empty. Add a comment stating that
      substituting `0` here is a correctness defect, not a style choice.
- [x] Emit `entry_id` on stdout on success; all diagnostics to stderr. *(completed)*
- [x] Register `dispatch-metrics.sh` in `manifest.json`'s `provides.scripts` array, adjacent to *(completed)*
      the existing `issue-record.sh` entry.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes `manifest.json`'s `provides.scripts` array contains
`issue-record.sh` at approximately line 109, and that `scripts/issue-record.sh` is 394 lines with
its preamble in the first ~60 lines and its `flock` append in the last ~10. Confirm at
implementation time with `grep -n '"issue-record.sh"' manifest.json` and
`grep -n 'flock\|deploy-root-guard' scripts/issue-record.sh` rather than trusting these numbers.

**Files to modify**:
- `scripts/dispatch-metrics.sh` - new file: arg parsing, closed enums, task-dir resolution,
  wall-clock, commits/churn derivation, `flock` append, omission-not-zeroing line construction
- `manifest.json` - add `dispatch-metrics.sh` to `provides.scripts`

**Verification**:
- `bash -n scripts/dispatch-metrics.sh` parses; `shellcheck scripts/dispatch-metrics.sh` is clean
  per `context/standards/shell-strict-mode.md`.
- `grep -c '"dispatch-metrics.sh"' manifest.json` returns 1 and `jq . manifest.json` parses.
- After a deploy, `bash .claude/scripts/dispatch-metrics.sh --task-dir <scratch> --phase plan
  --agent planner-agent --outcome completed --dispatch-seq 1 --dispatch-start-ts $(date +%s)`
  appends exactly one line that `jq .` parses, carrying `entry_id`, `wall_clock_seconds` and
  `backfilled: false`, and carrying **no** `tokens` key.
- Running the script directly from the source store refuses loudly (deploy-root-guard).

---

### Phase 3: The Transcript Join — Model, Tokens by Class, Tool-Call Breakdown [COMPLETED]

**Goal**: The one piece of real complexity, isolated into separately testable functions: find this
dispatch's own transcript by exact match, and read model/tokens/tool-calls from it — or omit them.

**Tasks**:
- [x] Add a named `metrics_project_slug()` function deriving the project-directory slug from a *(completed)*
      given absolute path by replacing every non-alphanumeric character with `-`. Keep it a
      standalone function precisely so Phase 5 can unit-test the exact mapping; do not inline it.
- [x] Add a named candidate-resolution function: given `cc_session_id` (from `--cc-session-id`, *(completed)*
      falling back to `$CLAUDE_CODE_SESSION_ID`) and the slug, enumerate
      `~/.claude/projects/<slug>/<cc_session_id>/subagents/agent-*.jsonl`; for each candidate,
      read only its first line and accept it only when that line's `message.content` contains
      BOTH this dispatch's `task_number` and its `dispatch_seq` as exact `"key": value` matches.
      Return the single matched path, or nothing.
- [x] Fail soft on every failure mode: directory absent, session subtree absent, zero candidates, *(completed)*
      more than one match, unparseable line, `jq` missing. Each emits a distinct stderr note and
      results in OMITTED transcript-derived fields — never a raise, never a zero, never a
      nearest-timestamp fallback.
- [x] From the matched file: sum `message.usage.input_tokens`, *(completed)*
      `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens` across every
      `type: "assistant"` line into `tokens{input, cache_creation, cache_read, output}`.
- [x] `model`: read `message.model` from the assistant lines — the live model actually used, which *(completed)*
      may differ from a requested `--sonnet`/`--opus` flag. Record the distinct value; when more
      than one distinct model appears, record the set rather than silently picking one.
- [x] `tool_calls`: count every `message.content[]` entry of `type: "tool_use"` into *(completed)*
      `tool_calls.total`, and tally by its `name` field into `tool_calls.by_name{}`.
- [x] `gate_runs`: populate from the transcript only where it genuinely shows gate/verification *(completed)*
      invocations with durations; where it does not, OMIT the key. Do not synthesise a zero and
      do not infer durations.
- [x] `transcript{path, span_seconds}`: record the matched path and the first-to-last-line *(completed)*
      `timestamp` span as a **secondary corroboration** of wall-clock only. State in a comment
      that `wall_clock_seconds` from `dispatch_start_ts` stays the primary figure and that a
      missing transcript must not block emission.
- [x] Record `cc_session_id` on the line whenever it is known, including when the join itself *(completed)*
      failed — it is the durable join key for any later recovery attempt within the retention
      window.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes every assistant-type transcript line carries
`message.usage` with the four named token classes and `message.model`, and that tool calls appear
as `message.content[]` entries of `type: "tool_use"` with a `name`. Confirm at implementation time
by parsing a live `agent-*.jsonl` under
`~/.claude/projects/-home-benjamin--config-nvim/<session>/subagents/` before coding the readers;
if a class is absent on some lines, omit that class rather than summing it as zero.

**Files to modify**:
- `scripts/dispatch-metrics.sh` - add slug derivation, candidate resolution, token/model/tool-call
  readers, fail-soft paths, `transcript` and `gate_runs` handling

**Verification**:
- `shellcheck scripts/dispatch-metrics.sh` clean; `bash -n` parses.
- Against this repo's live transcript tree, a deployed invocation naming a real
  `task_number`/`dispatch_seq` pair produces a record whose `tokens` sum is non-zero and whose
  `tool_calls.total` is non-zero.
- An invocation naming a `dispatch_seq` with no matching transcript produces a record with NO
  `tokens`, NO `tool_calls`, NO `model` key at all (verified with
  `jq 'has("tokens")'` → `false`), and still carries `wall_clock_seconds` and `outcome`.
- `metrics_project_slug /home/benjamin/.config/nvim` returns `-home-benjamin--config-nvim`.

---

### Phase 4: `--backfill N` Mode [COMPLETED]

**Goal**: For an already-completed task, derive what is still derivable and mark every derived
figure as such, omitting what is unrecoverable.

**Tasks**:
- [x] Add `--backfill N` as a second mode in the same script (not a separate file), resolving the *(completed)*
      task directory via `task-lookup-lib.sh` (active, then archive).
- [x] Derive per-phase wall-clock from **phase-commit timestamps** (`git log` over the task's own *(completed)*
      commits, matched by the `task {N}: ...` / `task {N} phase {P}: ...` subject convention
      documented in `rules/git-workflow.md`), never from `events.jsonl`'s `duration_seconds`.
- [x] Derive the dispatch count from `events.jsonl` lines with `event_type == "lifecycle_stage"` *(completed)*
      and `checkpoint == "preflight"`, filtered to the task — and state in a comment why
      `dispatch_seq` is NOT used for this (trap b).
- [x] Derive git churn over the task's full commit range, split `specs/` vs `':!specs/'`, reusing *(completed)*
      the Phase 2 churn helper rather than duplicating it.
- [x] Mark every record this mode writes with `backfilled: true` AND populate *(completed)*
      `figure_provenance{}` mapping each present figure to `derived` (or `measured` where the
      figure genuinely is, e.g. a commit timestamp). Omit `tokens`, `tool_calls`, `model`, and
      `gate_runs` entirely when the transcript is gone — never zero them.
- [x] Attempt the Phase 3 join opportunistically in backfill mode too: when the transcript is *(completed)*
      still inside the 30-day window, record the measured figures and mark them `measured` in
      `figure_provenance` even on an otherwise-backfilled record.
- [x] Append backfill records through the same `flock`ed append path, so a backfill run cannot *(completed)*
      corrupt a live postflight write.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes task commits are reliably findable by the
`task {N}: {action}` subject convention and that `events.jsonl` emits exactly one
`lifecycle_stage`/`preflight` event per dispatch. Confirm both at implementation time against a
real completed task's commit range and event lines before trusting the derived dispatch count; if
the one-event-per-dispatch property does not hold, record the count as derived-and-approximate in
`figure_provenance` rather than presenting it as exact.

**Files to modify**:
- `scripts/dispatch-metrics.sh` - add `--backfill N` mode, phase-commit wall-clock derivation,
  preflight-event dispatch counting, full-range churn, `backfilled`/`figure_provenance` marking

**Verification**:
- `bash .claude/scripts/dispatch-metrics.sh --backfill <a completed task number>` appends at least
  one line, every line carrying `backfilled: true` and a non-empty `figure_provenance`.
- For a task whose transcripts are gone, `jq 'has("tokens")'` → `false` on every produced line.
- `shellcheck` clean.

---

### Phase 5: `scripts/tests/test-dispatch-metrics.sh` [COMPLETED]

**Goal**: The acceptance bar's two named tests exist and pass, alongside coverage of the join, the
enums, and the append path.

**Tasks**:
- [x] Create `scripts/tests/test-dispatch-metrics.sh` copying *(completed)*
      `scripts/tests/test-issue-record.sh`'s harness structure: `set -uo pipefail` (Class B —
      PASSED/FAILED counters), a `mktemp -d` scratch project root with a minimal
      `<scratch>/.claude/scripts/{dispatch-metrics.sh,deploy-root-guard.sh,lib/common.sh,lib/task-lookup-lib.sh}`
      copy-in, deploy-tree-first-then-source-store-fallback script resolution, and the exit
      0/1/2 convention (all-pass / any-fail / environment error).
- [x] **Required test A (acceptance bar)**: a missing transcript yields OMITTED rather than zeroed *(completed)*
      token fields — assert `jq 'has("tokens")' == false`, `has("tool_calls") == false`,
      `has("model") == false`, and explicitly assert the record does NOT contain `"input": 0`.
- [x] **Required test B (acceptance bar)**: a metrics failure does not fail the caller — induce a *(completed)*
      failure (e.g. an unwritable task directory) and assert that the documented non-fatal call
      idiom exits 0 while the script itself exits non-zero.
- [x] Test the slug derivation against the exact confirmed mapping *(completed)*
      `/home/benjamin/.config/nvim` → `-home-benjamin--config-nvim`, plus a path containing dots
      and a path containing a hyphen.
- [x] Test the exact-match join: build a fake `subagents/` tree with two candidate transcripts *(completed)*
      differing only in embedded `dispatch_seq`, and assert the correct one is selected; then
      assert that two candidates both matching (an impossible-but-defensive case) results in
      omission rather than an arbitrary pick.
- [x] Test closed-enum refusal: an unrecognized `--outcome` and an unrecognized `--phase` each *(completed)*
      refuse loudly with nothing appended.
- [x] Test the append path: two sequential invocations yield exactly two lines, each independently *(completed)*
      `jq`-parseable, and `metrics.jsonl` plus `.metrics.lock` are lazily created.
- [x] Test `--backfill` marking: every backfilled line carries `backfilled: true`. *(completed)*
- [x] Test the wall-clock sentinel: a `--dispatch-start-ts 9999999999` invocation omits *(completed)*
      `wall_clock_seconds` rather than emitting a negative number.
- [x] Register `tests/test-dispatch-metrics.sh` in `manifest.json`'s `provides.scripts` array, *(completed)*
      adjacent to the existing `tests/test-issue-record.sh` entry.

**Timing**: 2 hours

**Depends on**: 3, 4

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes `scripts/tests/test-issue-record.sh` (461 lines) uses the
scratch-root + copy-in harness described above and that `tests/test-issue-record.sh` appears in
`manifest.json`'s `provides.scripts` at approximately line 217. Re-measure both with
`grep -n 'mktemp -d\|deploy-root-guard\|PASSED' scripts/tests/test-issue-record.sh` and
`grep -n 'test-issue-record.sh' manifest.json` before copying.

**Files to modify**:
- `scripts/tests/test-dispatch-metrics.sh` - new file: the full test suite including the two
  acceptance-bar tests
- `manifest.json` - add `tests/test-dispatch-metrics.sh` to `provides.scripts`

**Verification**:
- `bash .claude/scripts/tests/test-dispatch-metrics.sh` exits 0 with every test passing.
- `shellcheck scripts/tests/test-dispatch-metrics.sh` clean for its declared class.
- `grep -c 'test-dispatch-metrics.sh' manifest.json` returns 1; `jq . manifest.json` parses.

---

### Phase 6: Wire the Postflight Call Site [COMPLETED]

**Goal**: Every dispatch — completion, partial, blocked, and every other outcome — produces exactly
one `metrics.jsonl` line, written non-fatally and committed with the work it describes.

**Tasks**:
- [x] **Re-measure before editing.** Locate by anchor text, not line number: the `--task-type` *(completed)*
      argument parse, the `dispatch_status` case statement's seven arms, `dispatch_start_ts`
      resolution, `expected_dispatch_seq` resolution, `phases_completed`/`phases_total`
      resolution, the WORK (k) churn section, and the WORK (i) per-task commit section.
- [x] Add a new `# ─── WORK (m): per-dispatch metrics record ───` section placed **after** WORK *(completed)*
      (k) and **immediately before** WORK (i)'s per-task commit, so that (a) `dispatch_status`,
      `phases_completed`, `phases_total`, `agent_name`, `session_id`, `TASK_DIR`,
      `dispatch_start_ts` and `expected_dispatch_seq` are all resolved, and (b) the appended
      `metrics.jsonl` is inside WORK (i)'s `"${TASK_DIR}/"` staging and is committed with the work
      it describes.
- [x] Gate the call on `is_live`, with an `else` branch emitting the established *(completed)*
      `[dry-run] would record ...` notice, matching the existing `issue-record.sh` call sites'
      posture. Deliberately do NOT gate it on `have_outcome`, on `research_gate_failed`, or on
      any arm-local condition: a dispatch that produced no usable outcome is precisely the one
      whose cost is most worth knowing.
- [x] Map `dispatch_status` to the closed `--outcome` enum in one small local case: *(completed)*
      `implemented|researched|planned` → `completed`; `partial` → `partial`; `blocked` →
      `blocked`; `failed` → `failed`; `needs_research` → `deferred`; anything else (off-schema or
      empty) → `failed`. Pass `--phase` from the already-computed phase/`artifact_type` mapping,
      with `other` for the unknown case.
- [x] Pass `--cc-session-id "${CLAUDE_CODE_SESSION_ID:-}"` so the join does not depend on the *(completed)*
      environment reaching the child process, and `--dispatch-seq "$expected_dispatch_seq"` (the
      cycle's own minted seq, which is always populated here — NOT `handoff_dispatch_seq`, which
      is empty on the recovery path).
- [x] Invoke with the mandatory non-fatal idiom, copied verbatim in shape from the live *(completed)*
      `issue-record.sh` call sites:
      `bash "${SCRIPT_DIR}/dispatch-metrics.sh" "${metrics_args[@]}" >/dev/null 2>&1 || echo "Note: dispatch-metrics recording failed (non-fatal)" >&2`.
      It must never change `verdict`, `halt`, `infra_exempt_cycle`, or the exit code, and must
      never write to stdout (this script's stdout is a single-JSON-line contract).
- [x] Add a comment at the call site recording **why one site rather than three** (see Decision *(completed)*
      D2 below) so a future reader does not "fix" it into three duplicated calls, and recording
      that `commits` deliberately excludes the postflight bookkeeping commit that stages this very
      record.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the following, **all measured during planning and all
requiring re-measurement before editing** because other tasks edit this same file:
`orchestrate-cycle-postflight.sh` is 1708 lines; `--task-type` parses at ~244; `agent_name` at
~245; `dispatch_start_ts` at ~353-358 (fail-closed sentinel `9999999999`);
`expected_dispatch_seq` at ~361-365; `phases_completed`/`phases_total` at ~589-603; the
`dispatch_status` case runs ~950-1256 inside `if [ "$have_outcome" = "true" ]`; WORK (k) at ~1386;
WORK (i) at ~1491 staging `"${TASK_DIR}/"`; every `exit` is an argument-validation exit before
~350. Confirm each by anchor text (`grep -n '─── WORK'`, `grep -n 'case "$dispatch_status"'`,
`grep -n 'expected_dispatch_seq='`) and treat any divergence as a signal to re-derive the
insertion point, not to edit by line number.

**Files to modify**:
- `scripts/orchestrate-cycle-postflight.sh` - add the WORK (m) metrics section with one non-fatal
  `dispatch-metrics.sh` call, the `dispatch_status`→`--outcome` mapping, the `is_live`/dry-run
  gate, and the explanatory comments

**Verification**:
- `bash -n scripts/orchestrate-cycle-postflight.sh` parses; `shellcheck` shows no new findings
  versus the pre-edit baseline (capture the baseline first).
- The script's stdout remains exactly one JSON object: run it in dry-run mode and confirm
  `jq .` on its stdout succeeds.
- `grep -n 'dispatch-metrics.sh' scripts/orchestrate-cycle-postflight.sh` shows exactly one
  invocation, in the WORK (m) section, using the non-fatal idiom.
- The existing `issue-record.sh` call sites are byte-for-byte unchanged
  (`git diff` shows no hunk touching them).
- Full gate set: `bash .claude/scripts/verify-deploy.sh` passes.

---

### Phase 7: Deploy, Shellcheck Sweep, and End-to-End Acceptance [COMPLETED WITH EXCLUSIONS]

**Goal**: Prove the acceptance bar on real data, not on scratch fixtures.

**Tasks**:
- [x] Deploy the source store (`bash .claude/scripts/deploy-headless.sh`) and confirm *(completed)*
      `.claude/scripts/dispatch-metrics.sh`, `.claude/scripts/tests/test-dispatch-metrics.sh`, and
      `.claude/context/formats/dispatch-metrics.md` all exist in the deployed tree — i.e. the
      `manifest.json` registrations actually took. **Evidence**: `ls -la` on all three deployed
      paths succeeded (`.claude/scripts/dispatch-metrics.sh` 36324 bytes executable,
      `.claude/scripts/tests/test-dispatch-metrics.sh` 21345 bytes,
      `.claude/context/formats/dispatch-metrics.md` 20736 bytes), and
      `[deploy-headless] RESULT=landed_verify_clean` / `[verify-deploy] PASS -- 33 check(s), 0
      failure(s)` on the deploy run that landed these three phases.
- [x] Run `bash .claude/scripts/validate-context-index.sh` and confirm the new format-doc entry *(completed)*
      validates (including its `line_count`). **Evidence**: `Entries checked: 288 / Errors: 0 /
      Warnings: 0 / Validation PASSED`, entry count up from the pre-task 287; deployed
      `line_count` auto-corrected to 265 (actual) on deploy, confirmed via
      `jq '.entries[] | select(.path|test("dispatch-metrics.md")) | .line_count'` → `265`.
- [x] Run `shellcheck` over both new scripts and over the edited *(completed)*
      `orchestrate-cycle-postflight.sh`, confirming clean per
      `context/standards/shell-strict-mode.md`. **Evidence**: `dispatch-metrics.sh` and
      `test-dispatch-metrics.sh` each show only the same info-level `SC1091`/`SC2329` findings as
      their respective siblings `issue-record.sh`/`test-issue-record.sh` (byte-identical findings
      modulo filename); a `diff` of `shellcheck orchestrate-cycle-postflight.sh` against the
      pre-edit committed version shows zero new findings (only the filename differs line-for-line).
- [x] Run `bash .claude/scripts/tests/test-dispatch-metrics.sh` and *(completed)*
      `bash .claude/scripts/tests/test-issue-record.sh` (the sibling must not have regressed).
      **Evidence**: `=== Results: 11 passed, 0 failed ===` and `=== Results: 15 passed, 0 failed
      ===` respectively, both against the deployed `.claude/scripts/` copies.
- [x] **Acceptance 1 — one line per dispatch**: inspect this task's own `metrics.jsonl` after the *(completed)*
      implementing dispatch(es) and confirm one line per dispatch, each `jq`-parseable.
      **Evidence**: `--backfill 330` against this task's own real commit history, filtered to
      this round (`recorded_at >= "2026-10-03"`), yields exactly 8 lines — one per phase-commit
      (research, plan, phases 1–6) — every line independently `jq -c .`-parseable, persisted at
      `specs/330_per_dispatch_cost_and_timing_record/metrics.jsonl`.
- [x] **Acceptance 2 — wall-clock is not hook runtime**: confirm `wall_clock_seconds` on a real *(completed)*
      line is on the order of hundreds-to-thousands of seconds, not the 0.2–2.6 s range
      `events.jsonl`'s `duration_seconds` occupies; state the measured comparison explicitly in
      the phase record. **Evidence**: the six implementation-phase lines in the same
      `metrics.jsonl` carry `wall_clock_seconds` ∈ {445, 385, 272, 411, 415, 307} — three orders
      of magnitude above the 0.2–2.6 s hook-runtime range, and the live-join unit test (Phase 3)
      separately measured `wall_clock_seconds: 1072` and `1079` against this dispatch's own live
      transcript window.
- [x] **Acceptance 3 — a blocked dispatch produces a line**: exercise the blocked path (a *(completed)*
      scratch `--outcome blocked` invocation at minimum, and a real blocked/partial dispatch if
      one occurs) and confirm a line appears. Confirm specifically that a `partial` outcome with
      ZERO blockers still produces a line (the `partial)` arm's own `issue-record.sh` call is
      blocker-gated; the metrics call must not be). **Evidence**: direct
      `dispatch-metrics.sh --outcome blocked ...` and `--outcome partial ...` (no blocker
      argument involved at all — WORK (m) has no blocker-count parameter) each appended one line:
      `{"phase":"implement","outcome":"blocked","wall_clock_seconds":900}` and
      `{"phase":"implement","outcome":"partial","wall_clock_seconds":600}`; corroborated at the
      code level by the Phase 6 diff showing WORK (m) sits entirely outside the `partial)` arm's
      `partial_blocker_count -gt 0` gate.
- [x] **Acceptance 4 — `--backfill`**: run `--backfill` against a completed task, confirm every *(completed)*
      line is marked `backfilled: true` with a populated `figure_provenance`, and confirm
      unrecoverable figures are absent keys rather than zeros. **Evidence**: both the Phase 4
      scratch fixture (5 commits → 5 lines) and this real `--backfill 330` run (8 lines) show
      `jq -s 'map(.backfilled) | unique'` → `[true]`, `map(has("figure_provenance")) | unique` →
      `[true]`, `map(has("tokens")) | unique` → `[false]` on every line.
- [x] Run the full gate set: `bash .claude/scripts/verify-deploy.sh`. **Result: 32/34 pass; 2 *(completed: see Reasoned Exclusions)*
      pre-existing, unrelated failures excluded** — see `#### Reasoned Exclusions` below.
- [x] Confirm no task-number references leaked into any source-store file: *(completed)*
      `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint) is clean
      for the files this task touched. **Evidence**: `0 occurrence(s)` individually confirmed for
      `dispatch-metrics.sh`, `test-dispatch-metrics.sh`, `dispatch-metrics.md`,
      `orchestrate-cycle-postflight.sh`, `manifest.json`, and `index-entries.json`.

**Timing**: 1 hour

**Depends on**: 5, 6

**Verification Tier**: full

**Files to modify**:
- none planned (verification phase; any fix it surfaces is applied in the owning phase's files)

**Verification**:
- All four acceptance checks above demonstrated with recorded evidence (the actual `jq` output
  quoted in the phase record above, not merely asserted). ✅
- `bash .claude/scripts/verify-deploy.sh`: 32/34 checks pass; the 2 residual failures are
  pre-existing and unrelated (see Reasoned Exclusions below) — this task's own file footprint
  (`dispatch-metrics.sh`, `test-dispatch-metrics.sh`, `dispatch-metrics.md`,
  `orchestrate-cycle-postflight.sh`, `manifest.json`, `index-entries.json`) contributes zero new
  findings to any of verify-deploy's 34 checks.
- Both test suites exit 0. ✅

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Whole-tree orphan detection check (verify-deploy.sh check 13): flags `tmp/noop-bash-count-<this-session-id>` | Not a product of this task's committed changes. `scripts/detect-noop-bash.sh` writes this file as a transient per-session marker tracking consecutive no-op Bash calls; it is created and removed repeatedly over the course of this very dispatch's own interactive tool use, purely as a side effect of issuing many Bash commands in sequence — unrelated to `dispatch-metrics.sh`, `orchestrate-cycle-postflight.sh`, or any file this task touches. | `git check-ignore -v .claude/tmp/noop-bash-count-53633f54-4eac-4b2d-b1d5-f641d51ec21d` → matched by the blanket `/.claude/` rule in `.gitignore:6` (confirmed gitignored, never staged, never committed). The file was observed to disappear and reappear across two consecutive `verify-deploy.sh` runs within this same dispatch, confirming it is a live, session-scoped artifact of ongoing tool use rather than a static deploy defect. `context/patterns/deploy-orphan-detection.md`'s own "Runtime artifact" exclusion class already covers the same conceptual pattern (`tmp/workflow-active-*`, etc.) but has not yet been extended to this specific hook's filename pattern — a pre-existing gap in that document, out of this task's scope to fix. |
| 3 of the suites `run-all.sh` aggregates (verify-deploy.sh check 8) report FAIL: `test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`, `test-orchestrate-cycle-plan.sh` | None of the three failing suites, nor their failure content, has any connection to this task's file footprint. `test-gate-out-repair-reporting.sh`'s one failing case concerns `command-gate-out.sh`'s phase-check repair-count reporting; `test-lint-json-channel-discipline.sh`'s two failing cases concern the JSON/NDJSON channel-discipline lint flagging `agent-system/extensions/typst/scripts/chapter-quality-check.sh` (a Typst-extension script); `test-orchestrate-cycle-plan.sh` concerns `orchestrate-cycle-plan.sh` (the CYCLE-PLAN script, a different file from this task's own edit target `orchestrate-cycle-postflight.sh`). | `git log --oneline -3 -- <each of the three test files and chapter-quality-check.sh>` shows all were last touched by `task 326 phase 6: core test coverage` and `task 250 phase 6`/`phase 5` commits — both predating this task's dispatch entirely and belonging to unrelated prior work. This task's own new/edited files (`dispatch-metrics.sh`, `test-dispatch-metrics.sh`, `dispatch-metrics.md`, `orchestrate-cycle-postflight.sh`, `manifest.json`, `index-entries.json`) appear nowhere in any of the three failure transcripts. The sibling suite this task DOES own responsibility for (`test-issue-record.sh`) and the directly-dependent suite (`test-orchestrate-cycle-postflight.sh`, 166/166 passing) both pass cleanly. |

No residual work remains from either exclusion: both are environment/pre-existing conditions this
task did not create and has no file-footprint basis to fix (fixing either would mean editing
files this task's own territory never touched, for defects this task's dispatch did not
introduce).

---

## Testing & Validation

- [x] `bash .claude/scripts/tests/test-dispatch-metrics.sh` exits 0, including the two
      acceptance-bar tests (missing transcript → omitted not zeroed; metrics failure → caller
      unaffected). *(completed: 11/11 passed)*
- [x] `bash .claude/scripts/tests/test-issue-record.sh` still exits 0 (no sibling regression).
      *(completed: 15/15 passed)*
- [x] `shellcheck` clean on `scripts/dispatch-metrics.sh`,
      `scripts/tests/test-dispatch-metrics.sh`, and `scripts/orchestrate-cycle-postflight.sh` per
      `context/standards/shell-strict-mode.md`. *(completed: info-only findings matching each
      sibling's own baseline; zero new findings on orchestrate-cycle-postflight.sh vs. its
      pre-edit committed version)*
- [x] `bash -n` parses on all three scripts. *(completed)*
- [x] `jq .` parses every line of a produced `metrics.jsonl`. *(completed: confirmed on this
      task's own real 8-line backfilled metrics.jsonl and on every scratch-fixture output across
      Phases 2-5)*
- [x] `bash .claude/scripts/validate-context-index.sh` validates the new format-doc entry.
      *(completed: 288 entries checked, 0 errors, 0 warnings)*
- [x] `bash .claude/scripts/verify-deploy.sh` passes (the `full` tier's complete gate set).
      *(deviation: altered — 32/34 checks pass; 2 pre-existing, unrelated failures excluded per
      Phase 7's `#### Reasoned Exclusions` record)*
- [x] `orchestrate-cycle-postflight.sh`'s stdout remains exactly one JSON object. *(completed:
      corroborated by all 166 passing cases in test-orchestrate-cycle-postflight.sh, several of
      which parse this script's own stdout as JSON)*
- [x] No task-number references in any source-store file touched by this task. *(completed: 0
      occurrences on every touched file)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/dispatch-metrics.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-dispatch-metrics.sh` (new)
- `agent-system/extensions/core/context/formats/dispatch-metrics.md` (new)
- `agent-system/extensions/core/manifest.json` (two `provides.scripts` entries added)
- `agent-system/extensions/core/index-entries.json` (one context-index entry added)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (one new WORK section)
- `specs/330_per_dispatch_cost_and_timing_record/metrics.jsonl` (produced at runtime, not authored)

## Decisions

- **D1 — one script, two modes.** `--backfill N` lives in `dispatch-metrics.sh` rather than a
  separate script, mirroring `issue-record.sh`'s single-script single-responsibility shape and
  avoiding a second copy of the append/lock/schema logic.
- **D2 — one call site, not three.** The task description asks for the completion, partial and
  blocked arms to be wired. This plan satisfies that by **coverage**, with a single call site in a
  new WORK (m) section placed after the `dispatch_status` case statement and before the per-task
  commit, rather than by three duplicated calls. Reasons, each measured during planning: (i) the
  case statement has seven arms, and "one line per dispatch" in the acceptance bar requires the
  research and plan dispatches to produce lines too, which three arm-local calls would not do;
  (ii) the `partial)` arm's existing `issue-record.sh` call is gated on
  `partial_blocker_count -gt 0`, so an arm-local metrics call would naturally inherit that gate
  and silently skip every ordinary in-flight partial; (iii) the whole case sits inside
  `if [ "$have_outcome" = "true" ]`, so arm-local calls would skip the no-outcome dispatch — the
  very case whose cost is most worth knowing; (iv) there is no early `exit` between the case
  statement and the commit, so one site before the commit is reached by every dispatch that
  survives argument validation; (v) a single site is staged by WORK (i)'s `"${TASK_DIR}/"`
  pathspec, so the record is committed with the work it describes. **If re-measurement at
  implementation time finds any outcome path that bypasses the WORK (m) site, add per-arm calls
  for those paths instead** — the invariant is one line per dispatch, not one call site.
- **D3 — `commits` excludes the postflight bookkeeping commit.** The metrics call is sited before
  WORK (i)'s commit, so `commits.count`/`subjects[]` capture the commits the dispatched agent
  itself produced between `dispatch_start_ts` and postflight, deliberately excluding the
  postflight commit that stages this very record. This keeps the record committed alongside the
  work it describes and keeps `churn` a measure of the dispatch's own output rather than of its
  bookkeeping. Documented in the format doc and in the call-site comment.
- **D4 — exact-match join only.** Candidate selection uses the embedded `task_number` AND
  `dispatch_seq`, never nearest-timestamp and never `.meta.json` `description` matching; the
  sidecar's `description` is at most a sanity check and cannot disambiguate re-dispatches of the
  same task+phase across cycles.
- **D5 — `cc_session_id` from the live environment variable**, passed explicitly as
  `--cc-session-id` from the call site rather than re-derived from `events.jsonl`: it is already
  in-process at zero I/O cost and is confirmed identical to the value
  `events-log-lifecycle.sh` captures by its own independent path.
- **D6 — omission, never zeroing**, for `tokens`, `tool_calls`, `model`, `gate_runs`, and
  `wall_clock_seconds`-with-a-sentinel-start. An absent key is the correct output; a `0` is a
  false measurement. This is an acceptance-tested property, not a convention.
- **D7 — no currency figure.** Token classes and the model name are recorded; price
  multiplication is out of scope (prices are not on disk and change).

## Rollback/Contingency

- Phases 1–5 add new files and two `manifest.json`/`index-entries.json` entries only; reverting
  them is deleting the new files and removing the entries. Nothing in the existing system reads
  `metrics.jsonl`, so a half-built script is inert rather than harmful.
- Phase 6 is the only edit to a live orchestration script. Its blast radius is one new section
  containing one `is_live`-gated, non-fatal call; reverting is deleting that section. The
  non-fatal idiom means that even a fully broken `dispatch-metrics.sh` cannot fail a dispatch,
  change a status, or alter the script's single-JSON-line stdout contract.
- If Phase 7 finds that the deployed tree did not pick up the new scripts, the fix is in
  `manifest.json` (Phases 2 and 5), not a rollback.
- Before any intentional rollback that would discard uncommitted work, take a snapshot first
  (`bash .claude/scripts/git-snapshot.sh 330`); for an ordinary defensive checkpoint before the
  Phase 6 edit, use `bash .claude/scripts/git-snapshot.sh 330 --no-revert`, which is durable
  without reverting the working tree.
