# Research Report: Task #330

**Task**: 330 - Per-dispatch cost and timing record
**Started**: 2026-10-03T00:00:00Z
**Completed**: 2026-10-03T00:00:00Z
**Effort**: 4-8 hours (per task estimate)
**Dependencies**: Task 329 (COMPLETED — see Findings below, this unblocks immediately)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/`, `agent-system/extensions/memory/context/`), live `~/.claude/projects/` transcript tree, `specs/state.json`, `specs/TODO.md`, `specs/ROADMAP.md`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The dispatch's stated transcript path shape is wrong and must be corrected before any
  script is written against it.** It claims flat sibling files
  `~/.claude/projects/<slug>/agent-*.jsonl`. The live, confirmed layout is nested:
  `~/.claude/projects/<slug>/<cc_session_id>/subagents/agent-<id>.jsonl` plus a sibling
  `agent-<id>.meta.json` (fields: `agentType`, `description`, `toolUseId`, `spawnDepth`). This
  matches `context/project/memory/telemetry-guardrails.md`'s already-documented "Tier 4:
  Transcripts and `.meta.json` Sidecars" model, which this task should cite rather than
  re-derive.
- **The join procedure is exact, not fuzzy.** `cc_session_id` is the orchestrator's own
  `$CLAUDE_CODE_SESSION_ID` environment variable, directly readable inside
  `orchestrate-cycle-postflight.sh`'s own bash process (verified empirically — this value is
  identical across the lead session and every subagent's own bash tool calls). Given
  `cc_session_id`, the correct `subagents/agent-*.jsonl` file for *this* dispatch is found by
  grepping each candidate file's first (`user`-type) line for the literal dispatch prompt text,
  which embeds this exact dispatch's `task_number` and `dispatch_seq` verbatim — an exact string
  match, never nearest-timestamp or description-string guessing.
- **Task 329 (the declared dependency) is already `[COMPLETED]`.** Its `issue-record.sh` calls
  are already live in exactly the three arms this task must also touch
  (`implemented`/`partial`/`failed|blocked` in `orchestrate-cycle-postflight.sh`). The
  file-footprint-serialization hazard the dispatch flagged no longer applies — `dispatch-metrics.sh`
  calls can be added directly alongside the existing `issue-record.sh` calls, following the
  identical non-fatal invocation idiom.
- **Recommended approach**: build `dispatch-metrics.sh` as a close structural sibling of
  `issue-record.sh` (same strict mode, same `flock`-guarded lazy-create append, same
  deploy-root-guard gate, same non-fatal call-site contract), add one call per arm in
  `orchestrate-cycle-postflight.sh`, and add `--backfill N` as a second mode in the same script
  rather than a separate file.

## Context & Scope

Researched what currently exists (nothing — no cost/token/model/tool-call figure is recorded
anywhere under `specs/` today, confirmed by grep), what is mechanically derivable from Claude
Code's own on-disk transcripts and from this repo's existing `events.jsonl`/git history, and the
exact call-site shape in `orchestrate-cycle-postflight.sh` this task must wire into. Scope is
research only — producing the concrete design grounding a plan can build `scripts/dispatch-metrics.sh`,
`scripts/tests/test-dispatch-metrics.sh`, and `context/formats/dispatch-metrics.md` from. No code
was written.

## Findings

### Codebase Patterns

**Postflight call-site structure** (`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
1708 lines total — re-measured live, since task 329 already edited this file and shifted line
numbers from whatever the dispatch's own stale measurement assumed):

- `--task-type` is parsed at line 244 (dispatch's claimed line 244 — unchanged).
- The `dispatch_status` case statement begins around line 950 (switch value set earlier from
  handoff/recovered `.return-meta.json`). The three target arms:
  - **`implemented)`** — the completion arm — spans lines 1008-1144. The live-write body (guarded
    by `is_live`) is lines 1051-1127. This is where `skill_postflight_update ... "implement" ...`
    runs, where the deploy-pending-refusal `issue-record.sh` call already exists (lines
    1078-1084), and where `skill_orchestrate_propagate_completion` is invoked (lines 1115-1120).
  - **`partial)`** — lines 1145-1176. A `issue-record.sh` call already exists at lines 1164-1169,
    gated on `partial_blocker_count -gt 0` (an ordinary in-flight partial with no blockers writes
    nothing and should likewise emit no metrics line beyond the dispatch's own completion/outcome
    record — see Recommendations).
  - **`failed|blocked)`** — lines 1177-1194, a single shared case arm. An `issue-record.sh` call
    already exists at lines 1185-1190. A `blocked` dispatch_status is NOT given its own separate
    case label — it shares this arm with `failed`. `dispatch-metrics.sh`'s own call here should
    pass `--outcome "$dispatch_status"` verbatim (resolving to either `failed` or `blocked`) so one
    call site serves both without a new branch.
- Variables already in scope at all three arms, usable directly as `dispatch-metrics.sh`
  arguments with no new plumbing: `task_number`, `task_type`, `agent_name` (parsed at line 245),
  `session_id`, `TASK_DIR`, `dispatch_status`, `dispatch_start_ts` (resolved at lines 353-358,
  epoch seconds from `.dispatch/{seq}.md`'s `dispatch_start_ts` field via `--dispatch-start-ts`,
  falling back to the multi-task state file's `.dispatch_start_ts[$t]`, failing closed to
  `9999999999` if neither is present), `expected_dispatch_seq` (lines 361-365 — the cycle's own
  minted dispatch_seq, always populated at this point, unlike `handoff_dispatch_seq` which can be
  empty on the recovery path), `phases_completed`/`phases_total` (lines 589-603, corroborated via
  `skill_corroborate_phase_counts`), `SCRIPT_DIR` (line 161).
- **Call convention already established and must be mirrored exactly**: every existing
  `issue-record.sh` call site in this file uses
  `bash "${SCRIPT_DIR}/issue-record.sh" "${issue_args[@]}" >/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2`.
  `dispatch-metrics.sh` should be invoked identically — non-fatal, stdout discarded, a distinct
  `Note:` stderr line on failure, never changing `verdict`/`halt`/exit code.

**`issue-record.sh` — the structural sibling to build against** (not a separate ad hoc design):

- `set -euo pipefail` (Class A, per `context/standards/shell-strict-mode.md`'s classification
  scheme — an ordinary non-counter writer script defaults to Class A).
- Single responsibility: append exactly one `jq -c -n`-built JSON line, under `flock -x` on a
  sibling `.{name}.lock` file, lazily creating the target `.jsonl` on first use. Never a
  read-merge-rewrite.
- `entry_id` convention: `{prefix}_{timestamp_ms}_{random6}` (mirrors `events.jsonl`'s `event_id`
  and `errors.json`'s `err_{timestamp}` — `dispatch-metrics.sh` should mint e.g.
  `met_{timestamp_ms}_{random6}`).
- Task-directory resolution: `--task-dir PATH` (absolute used verbatim, relative resolved against
  `PROJECT_ROOT`) or `--task N` (resolved via `scripts/lib/task-lookup-lib.sh`'s
  `task_lookup_entry`/`task_lookup_dir`, active-then-archive). `orchestrate-cycle-postflight.sh`
  already has `$TASK_DIR` in scope at all three arms, so the call site should always pass
  `--task-dir "$TASK_DIR"` directly — no need for the `--task N` fallback form at this call site
  (that form exists in `issue-record.sh` for other, manual callers).
- Sourced via `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then
  `source "${SCRIPT_DIR}/lib/common.sh"`, `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"`,
  `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` (refuses loudly if run from the source store
  directly rather than the deployed `.claude/scripts/` copy — same must apply to
  `dispatch-metrics.sh`), `source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"`.
- Closed-enum fields refuse loudly on an unrecognized value (`--kind`, `--severity`, `--phase`,
  `--resolution`, `--suggested-channel`); `--class` is deliberately the one open/lenient field
  (warn-and-append). For `dispatch-metrics.sh`, `outcome` is naturally a closed enum
  (`completed|partial|blocked|failed|deferred`), `phase`/`kind` should mirror the existing closed
  phase vocabulary where it already overlaps (`research|plan|implement|conclusion|other` from
  `issue-record.sh`, extended with the task's requested `aux kind` member).
- Test harness template: `scripts/tests/test-issue-record.sh` — `set -uo pipefail` (Class B:
  PASSED/FAILED counters), scratch `mktemp -d` project root with a minimal
  `<scratch>/.claude/scripts/{script,deploy-root-guard.sh,lib/common.sh,lib/task-lookup-lib.sh}`
  copy-in, deploy-tree-first-then-source-store-fallback script resolution (`$REPO_ROOT/.claude/scripts/X.sh`
  then `$SCRIPT_DIR/../X.sh`), exit 0/1/2 convention (all-pass / any-fail / environment error).
  `test-dispatch-metrics.sh` should copy this structure directly.

**`context/formats/issue-log.md` — the sibling format doc to pattern-match**: file location
(`specs/{NNN}_{SLUG}/{name}.jsonl`, lazy-created, never gitignored, append-only-by-line), a field
table, a worked JSON example, closed-enum admission tests stated as tables, and an explicit
"CAPTURE ONLY" boundary section. `context/formats/dispatch-metrics.md` should follow the same
shape, substituting the "CAPTURE ONLY" framing with the task's own non-blocking-posture framing
(a metrics failure never fails a dispatch, never changes status, never surfaces to the user).

### Transcript and Telemetry Findings (Tier 4)

**Confirmed live layout** (verified against this very session's own project directory,
`~/.claude/projects/-home-benjamin--config-nvim/`):

```
~/.claude/projects/<slug>/<cc_session_id>.jsonl          # lead session transcript
~/.claude/projects/<slug>/<cc_session_id>/
  ├── subagents/
  │   ├── agent-<agentId>.jsonl        # one subagent dispatch's full transcript
  │   └── agent-<agentId>.meta.json    # {agentType, description, toolUseId, spawnDepth, requestShape, requestNonInteractive}
  └── tool-results/
```

`<slug>` is the cwd with every non-alphanumeric character (`/` and `.`) replaced by `-`
(`/home/benjamin/.config/nvim` -> `-home-benjamin--config-nvim`).

This matches `context/project/memory/telemetry-guardrails.md`'s existing "Tier 4: Transcripts and
`.meta.json` Sidecars" section almost exactly (that section already documents the sidecar's
minimal field set and the 30-day window) — **the dispatch's own prose asserting flat sibling
`agent-*.jsonl` files is the thing that is wrong**, not this codebase's prior documentation. The
format doc this task writes should explicitly cite and align with that existing section rather
than re-deriving it, and should correct the record there if that section is ever found to assert
the flat-file shape (it does not, on the copy read during this research pass).

**The join, concretely**:

1. `cc_session_id` = `"$CLAUDE_CODE_SESSION_ID"`, read directly as an environment variable inside
   `orchestrate-cycle-postflight.sh`'s own process. Verified empirically: this value is identical
   whether read from the orchestrator's own top-level bash calls or from a dispatched subagent's
   own bash tool calls within the same task tree (`CLAUDE_CODE_SESSION_ID` names the *lead*
   session throughout, with `CLAUDE_CODE_FORK_SUBAGENT=1`/`CLAUDE_CODE_CHILD_SESSION=1` as the
   subagent markers — the session id itself never changes). This is the exact value
   `events-log-lifecycle.sh` already captures into `events.jsonl`'s `cc_session_id` field from
   hook stdin's top-level `.session_id` (see `context/formats/events-format.md`'s "Claude Code
   OTel Correlation" section) — same id space, same value, two different capture paths into the
   same fact.
2. Candidate directory: `~/.claude/projects/<slug>/<cc_session_id>/subagents/`. `<slug>` must be
   derived the same way Claude Code itself derives it (non-alphanumeric -> `-`) from `$PWD`/the
   repo root — this should be a small, tested helper, not inlined ad hoc, since getting the
   replacement rule wrong silently yields "no transcripts found" for every dispatch.
3. For each `agent-*.jsonl` in that directory, its first line is a `type: "user"` record whose
   `message.content` is the literal dispatch prompt text handed to the Agent tool — this prompt
   **always** embeds the Context JSON block verbatim, including `"task_number": N` and
   `"dispatch_seq": M`. Grepping (or `jq`-parsing) for both exact values against each candidate's
   first line gives an **exact, unambiguous** match — never a nearest-timestamp or
   description-string heuristic. (A `.meta.json`'s own `description` field, e.g. `"Research task
   330"`, is a usable secondary sanity check but is not precise enough alone to disambiguate
   re-dispatches of the same task+phase across multiple cycles; the embedded `dispatch_seq` is.)
4. Within the matched `agent-*.jsonl`: every `type: "assistant"` line carries `message.model`
   (e.g. `"claude-sonnet-5"` — the live model actually used, which may differ from a requested
   `--sonnet`/`--opus` flag, exactly as the dispatch requires) and `message.usage` —
   `{input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens,
   cache_creation: {ephemeral_5m_input_tokens, ephemeral_1h_input_tokens}, service_tier,
   inference_geo}`. Sum each class across every assistant line in the file for the dispatch's
   total token figures (by class, per the task's own "tokens by class" requirement).
5. Tool-call count and per-tool breakdown: every `message.content[]` entry of
   `type: "tool_use"` carries a `name` field. Counting occurrences of each `name` across every
   assistant line in the matched file gives both the total tool-call count and the per-tool
   breakdown the task asks for ("ideally a per-tool breakdown").
6. Wall-clock, independently cross-checked: the matched file's own first and last line
   `timestamp` fields bound the dispatch's actual transcript-observed duration — useful as a
   sanity cross-check against `dispatch_start_ts`-to-postflight-time, but the task's own primary
   wall-clock definition (`dispatch_start_ts` to return, read from `.dispatch/{seq}.md`) does not
   require the transcript at all and should remain the primary figure; the transcript span is a
   secondary corroboration only, and should not block metrics emission if the transcript is
   missing.

**Three measured traps — all directly confirmed in this pass, not merely restated from the
dispatch**:

- `events.jsonl`'s `lifecycle_stage`/`checkpoint: preflight` event's `duration_seconds` field is
  computed in `scripts/skill-base.sh` (around line 465) as
  `awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}'`, i.e. strictly the preflight
  *hook stage's own* wall time, not the dispatch's. Confirmed by reading the computation directly.
- `dispatch_seq_counter`/per-task `dispatch_seq` advance by roughly 3 per dispatch because
  `orchestrate-cycle-plan.sh` mints a fresh seq at several sub-steps of one cycle (not one mint
  per dispatch) — confirmed structurally from the comments around
  `orchestrate-cycle-plan.sh:2312-2331` ("dispatch_seq mint + dispatch_start_ts — one atomic
  multi-state write"), which is one of at least three such mint sites visible in that file.
- Per-phase wall-clock is derivable from phase-commit timestamps, not from `events.jsonl` directly
  — confirmed by the absence of any per-dispatch wall-clock field anywhere in `events.jsonl`'s
  schema (`context/formats/events-format.md`), and the presence of `dispatch_start_ts` as the
  correct per-dispatch start anchor already threaded through every arm (see above).

**Dispatch-count backfill source**: `lifecycle_stage`/`checkpoint: preflight` events are emitted
exactly once per dispatch (one `skill_preflight_update`/equivalent call per phase dispatch), so
counting `events.jsonl` lines with `event_type == "lifecycle_stage"`, `checkpoint == "preflight"`,
filtered by `task`/`session_id`, gives a dispatch count for `--backfill` — confirmed structurally
via `scripts/skill-base.sh`'s single preflight-stage event-emission call site.

**Commit/churn derivation for `--backfill` (and optionally live mode)**: every commit this
agent-system writes already embeds `Session: sess_{timestamp}_{random}` in its body (per
`.claude/rules/git-workflow.md`'s documented convention), and `dispatch_start_ts` is an epoch
second. `git log --since="@${dispatch_start_ts}" --grep="$session_id"` (git's approxidate
accepts `@<epoch>`) gives exactly the commits this dispatch's own session produced from
`dispatch_start_ts` to now, without needing any new commit-message convention. Lines-added/removed
split by `specs/` vs. outside-`specs/` is a `git diff --numstat` (or `git log --numstat`) over
that same commit range, summed separately for pathspecs `specs/` and `':!specs/'` — no existing
script in this codebase already does this split; it is new, straightforward surface area.

### External Resources

None consulted — this is a pure in-repo mechanism-design task; no external library or API is
involved. `context/standards/shell-strict-mode.md` and `context/project/memory/telemetry-guardrails.md`
are the two in-repo documents that most directly constrain the design and were read in full.

## Recommendations

1. **Write `dispatch-metrics.sh` as a structural sibling of `issue-record.sh`** — same strict
   mode (Class A, `set -euo pipefail`), same `flock`-guarded lazy-create single-line JSON append
   to `specs/{NNN}_{SLUG}/metrics.jsonl`, same `deploy-root-guard.sh` gate, same
   `--task-dir PATH` resolution (the only form the postflight call sites need), same `entry_id`
   convention (`met_{timestamp_ms}_{random6}`).
2. **Two modes in one script**: default (live, called from postflight) and `--backfill N`
   (derives whatever `--backfill` can from already-completed-task artifacts: phase-commit
   timestamps, `lifecycle_stage` preflight-event counts, git churn over the full commit range).
   Every `--backfill`-derived field carries an explicit `"backfilled": true` marker (per-field or
   per-record — a plan should decide the exact shape, but the marking must exist) so no report
   consumer ever treats a derived figure as measured.
3. **Resolve the transcript join as a small, separately testable function** (slug derivation +
   candidate-directory scan + exact `task_number`/`dispatch_seq` match against each candidate's
   first line) — this is the one piece of real complexity in the script and the one most worth a
   dedicated unit test (including the "transcript directory absent/stale beyond 30 days ->
   omit, don't zero" case the task's acceptance criteria explicitly names).
4. **Omission, not zeroing, on missing data** — both for `--backfill`'s token/tool-call fields and
   for live mode's transcript lookup when the join fails for any reason (wrong slug derivation,
   session not yet flushed to disk, directory genuinely absent). A `null` (absent) field is the
   correct output; a `0` is a false measurement.
5. **Call sites**: add one non-fatal `bash "${SCRIPT_DIR}/dispatch-metrics.sh" ... >/dev/null 2>&1 || echo "Note: dispatch-metrics recording failed (non-fatal)" >&2`
   call immediately adjacent to the existing `issue-record.sh` calls in all three arms
   (`implemented` lines 1008-1144, `partial` lines 1145-1176, `failed|blocked` lines 1177-1194 of
   the current `orchestrate-cycle-postflight.sh` — **re-measure before editing**, since this
   file changes across tasks in this same chain). Pass `--outcome "$dispatch_status"` verbatim in
   the shared `failed|blocked` arm rather than adding a new case label.
6. **`context/formats/dispatch-metrics.md`** should explicitly state the three measured traps as
   named warnings (verbatim-equivalent to the dispatch's own three bullets, now independently
   confirmed above), state the exact join procedure (env var + exact-match grep, not
   nearest-timestamp), state the 30-day retention window, and cross-reference
   `context/project/memory/telemetry-guardrails.md`'s Tier 4 section and `issue-log.md`'s sibling
   shape rather than duplicating either.
7. **`scripts/tests/test-dispatch-metrics.sh`** should copy `test-issue-record.sh`'s scratch-root
   harness structure, and must include (per the task's explicit acceptance bar): a case where no
   matching transcript exists and the token/tool-call fields come back absent rather than `0`;
   and a case proving a `dispatch-metrics.sh` failure (e.g. unwritable directory) does not
   propagate as a caller failure when invoked via the documented non-fatal form.

## Decisions

- `dispatch-metrics.sh` is one script covering both the live postflight-call path and
  `--backfill N`, not two separate scripts — mirrors `issue-record.sh`'s single-script,
  single-responsibility shape and avoids a second script duplicating the append/lock/schema
  logic.
- The transcript join uses the dispatch prompt's embedded `task_number`/`dispatch_seq` exact
  match, not timestamp-nearest or `.meta.json`-description matching — the exact match is strictly
  more reliable and was confirmed available in every transcript inspected during this research
  pass.
- `cc_session_id` is sourced from the live `$CLAUDE_CODE_SESSION_ID` environment variable at the
  postflight call site, not re-derived from `events.jsonl` — it is already present in-process with
  zero extra I/O, and confirmed identical to what `events-log-lifecycle.sh` independently captures
  into `events.jsonl`'s own `cc_session_id` field via a different path.
- The `failed|blocked` postflight arm gets exactly one `dispatch-metrics.sh` call (not two),
  passing `$dispatch_status` through as `--outcome`, matching that arm's existing single shared
  `issue-record.sh` call.

## Risks & Mitigations

- **Risk**: the project-directory slug-derivation rule is reimplemented incorrectly (e.g. missing
  a character class Claude Code itself substitutes), silently producing "no transcript found" for
  every dispatch forever. **Mitigation**: give this derivation its own named function with a
  dedicated unit test asserting the exact mapping confirmed in this report
  (`/home/benjamin/.config/nvim` -> `-home-benjamin--config-nvim`), not an inline one-off `sed`.
- **Risk**: Claude Code changes its own on-disk transcript layout in a future release (it has
  apparently already changed once, since the dispatch's own prose describes the now-superseded
  flat-file shape). **Mitigation**: the join function should fail soft (log-and-omit, never raise)
  on an unexpected directory shape, and `context/formats/dispatch-metrics.md` should name the
  Claude Code version this was last confirmed against (`2.1.288`, captured from a live transcript
  line's own `version` field during this research pass).
- **Risk**: a dispatch whose session_id is reused across an unusually long batch window could, in
  principle, have its commit-window git-log query (`--since=@dispatch_start_ts --grep=session_id`)
  pick up a stray commit from a different task if that other task's commit also happens to land in
  the same narrow window and (incorrectly) shares session text — in practice this cannot happen
  because `session_id` is minted per-task, not shared, so the `--grep` term alone already
  disambiguates by task; the `--since` bound only narrows further to this dispatch's own window
  within that task. No mitigation needed beyond using both filters together as designed.

## Context Extension Recommendations

- **Topic**: project-directory slug derivation (cwd -> `~/.claude/projects/<slug>` directory name).
- **Gap**: this mapping is not documented anywhere in `context/` today; it was reverse-engineered
  during this research pass from a live example.
- **Recommendation**: once `dispatch-metrics.sh` implements and tests this mapping, promote the
  confirmed rule into `context/project/memory/telemetry-guardrails.md`'s Tier 4 section (or a
  small adjacent note) so a future task does not have to re-derive it from scratch.

## Appendix

- Searches/greps used: `find`/`ls` over `~/.claude/projects/-home-benjamin--config-nvim/` and its
  `<session>/subagents/` subdirectory; `grep -n` over
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `issue-record.sh`, `skill-base.sh`, `events-log-lifecycle.sh`,
  `orchestrate-cycle-plan.sh`; `python3 -c` inline JSON parsing of live `agent-*.jsonl` lines to
  confirm `usage`/`model`/`tool_use` shapes; `jq` reads of `specs/state.json` and
  `.claude-extensions.json`.
- Key files read in full or substantial part: `agent-system/extensions/core/scripts/issue-record.sh`,
  `agent-system/extensions/core/scripts/tests/test-issue-record.sh`,
  `agent-system/extensions/core/context/formats/issue-log.md`,
  `agent-system/extensions/core/context/formats/events-format.md`,
  `agent-system/extensions/memory/context/project/memory/telemetry-guardrails.md`,
  `agent-system/extensions/core/context/standards/shell-strict-mode.md`,
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (relevant sections).
