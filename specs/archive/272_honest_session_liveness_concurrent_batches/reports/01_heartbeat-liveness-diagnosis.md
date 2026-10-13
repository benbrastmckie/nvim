# Research Report: Task #272

**Task**: 272 - Honest session liveness for concurrent batches
**Started**: 2026-10-07T00:00:00Z
**Completed**: 2026-10-07T00:00:00Z
**Effort**: large (touches `scripts/task-lock.sh`, `commands/orchestrate.md`,
`scripts/orchestrate-predispatch-review.sh`, `docs/architecture/orchestrate-state-machine.md`,
and — per this report's Piece 1 finding — up to 11 domain `*-implementation-agent.md` files)
**Dependencies**: task 165 (owns `orchestrate-batch-admit.sh`, not touched here), task 51
(relocates `scripts/task-lock.sh`'s runtime-file neighbors; substantive ordering dependency, not
mere footprint serialization), task 275 (consumes this task's output; Piece 4 moved there)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/task-lock.sh`,
`update-phase-status.sh`, `command-gate-in.sh`, `commands/orchestrate.md`,
`orchestrate-predispatch-review.sh`, all `*-implementation-agent*.md` files across every loaded
extension), live evidence repo `~/Projects/BimodalLogic` (`.agent-logs/heartbeat-trace.log`,
`specs/.sessions/`, `git log`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, shell-strict-mode.md

## Executive Summary

- **Piece 1 is a design gap, not a routing regression**, and it is much larger than a one-line
  fix. Live evidence confirms it directly: in `~/Projects/BimodalLogic`, task 696 (12
  phase-completion commits) and task 649 (9 phase-completion commits) have **zero**
  `heartbeat-trace.log` lines, ever — while sibling tasks dispatched through
  `general-implementation-agent` in the same date range trace cleanly (e.g. task 698, 26
  phase-transition heartbeats on 2026-09-29 alone). Root cause, found by direct inspection: the
  heartbeat was mechanized by embedding it **inside `update-phase-status.sh`**, and only
  `general-implementation-agent.md`'s Stage 4D was updated to call that script as primary (with
  a direct-Edit fallback documented explicitly as "if the script is unavailable"). Of the 13
  domain `*-implementation-agent.md` files in this deploy, **11 still use direct Edit-tool
  phase-heading mutation as their sole, primary mechanism** — `update-phase-status.sh` is never
  invoked, so `heartbeat_after_phase_transition()` is never entered. Task 696 and 649 are
  Lean/Typst tasks, routed to exactly the two agents (`lean-implementation-agent.md` /
  `lean-implementation-hard-agent.md`, `typst-implementation-agent.md`) that were never
  migrated. This reproduces, in a sibling file, the exact failure class the mechanization was
  built to close.
- **Piece 2's third lock state is well-precedented and narrowly scoped.** `cmd_check` (line 1010)
  and `cmd_acquire`'s held-lock overlap pass (the "Stale overlapping foreign lock: warn and
  proceed" branch) both reason on heartbeat-age alone, with no pid-liveness dimension — even
  though `holder.json` already carries `pid`/`pid_source` (added for `cmd_reap`'s own
  pid-liveness floor) and the session registry already carries a battle-tested,
  already-factored-out `session_liveness()` with the exact six-reason vocabulary this piece
  needs. The correct consumption path is session_id-keyed: look up the per-task lock's
  `holder_session` in `specs/.sessions/${holder_session}.json` and run that file through
  `session_liveness()`, never compare pids directly for self-exclusion purposes.
- **Piece 3 is a small, mechanical fix.** `cmd_session_register` already computes the union
  `file_scope` correctly (loop `get_file_scope($tn)` over the session's `task_numbers_json`, then
  `jq -s -c 'add | unique'`); `cmd_session_heartbeat` reads the stored `file_scope_json` back
  verbatim and never recomputes it. Extracting that computation into one shared helper and
  calling it from both commands closes the gap with no behavior change to `session-register`.
- **Absorbed item (a) is confirmed exactly as described**: `commands/orchestrate.md` calls
  `orchestrate-predispatch-review.sh` (line 202) before it mints `batch_session_id` (line ~250),
  so `--session-id` is never passed and Class E prints its `SKIPPED` line on every run.
  `common_session_id()` has no dependency on anything computed between those two points, so the
  mint can move earlier with no other ordering hazard.
- **Absorbed item (b)'s misleading message** ("Batching is not yet supported...") is confirmed at
  both `commands/orchestrate.md:236` and `docs/architecture/orchestrate-state-machine.md:736`,
  verbatim identical, contradicting `batch-orchestration-guardrails.md`'s "Batching Is the
  Default" framing. Text-only fix, two sites.
- **The "ALSO OBSERVED" dead-registry-entries question is already answered by existing code**:
  `session-reap` is NOT unwired from any lifecycle sweep — `skill-refresh/SKILL.md` (lines
  258-265) and `commands/refresh.md` already call `task-lock.sh session-reap` on explicit
  `/refresh` invocation. The five dead entries observed live are stale only because `/refresh`
  has not been run recently in that repo, not because the reap path is missing. **No code change
  is needed here**; this narrows the task's scope relative to what the dispatch's phrasing
  ("Argue the reap-policy choice... rather than assuming either") might suggest.

## Context & Scope

This is phase=research, dispatch_seq=5, for task 272 (`meta`, scoped to
`agent-system/extensions/core/`, never `.claude/**`). The dispatch names three in-scope pieces
(1: diagnose the heartbeat silence; 2: a third lock state for stale-but-pid-alive; 3: re-derive
registry `file_scope` on heartbeat) plus two absorbed defects (a: dead Class E review; b: stale
batch-size message) and one "also observed, argue don't assume" item (dead session-registry
entries). Piece 4 (per-orchestration identity) has explicitly moved to task 275 and is out of
scope here. `scripts/orchestrate-batch-admit.sh` is explicitly out of scope (task 165's surface).

All investigation below was done by direct inspection of the source-store files
(`agent-system/extensions/core/...`) plus the live evidence repo `~/Projects/BimodalLogic`, which
is reachable from this environment and was used to verify every "measured evidence" claim in the
dispatch rather than taking it on faith.

## Findings

### Piece 1 — Heartbeat silence: confirmed design gap (incomplete propagation), not a routing regression

**The mechanism itself is sound and exactly where the dispatch says it is.**
`update-phase-status.sh`'s `heartbeat_after_phase_transition()` (defined ~line 159, called once
at line 276, before either the "Phase N not found" exit or the idempotency early-exit) calls
`task-lock.sh heartbeat` then `task-lock.sh session-heartbeat`, and writes one `_hb_trace` line
per subcommand into `.agent-logs/heartbeat-trace.log` for **every** branch, including every
no-op class (`no-holder`, `unparseable-holder`, `session-mismatch`, `task-lock-unresolved`).
Because every branch traces, the only way to get **zero** trace lines for a task is for
`update-phase-status.sh` to never be invoked at all for that task's phase transitions.

**Verification against the live evidence repo** (not just the dispatch's prose):

```
$ wc -l ~/Projects/BimodalLogic/.agent-logs/heartbeat-trace.log
852
$ grep -oP '^\[\K2026-\d\d-\d\d' .agent-logs/heartbeat-trace.log | sort | uniq -c
    ... 80 2026-09-29 ...   (task 698 alone: 26 lines that day)
$ grep -c "task 696 \|task 649 " .agent-logs/heartbeat-trace.log
0
$ git log --all --oneline | grep -E "^\w+ task (696|649)"
# 12 "task 696 phase N: ..." commits, 9 "task 649 phase N: ..." commits
```

Both affected tasks (696 = a Lean formal-proof "stability modal substrate" task; 649 = a Typst
"Lean code environment" documentation task) produced real, git-committed phase-completion
commits with zero corresponding heartbeat trace lines, while contemporaneous tasks (697, 698,
700, 701, ...) trace cleanly in the same log over the same date range. This is not a cadence or
timing artifact — it is a structural absence, confirmed by direct code inspection:

```
$ grep -n "Phase Status Updates\|update-phase-status.sh" .claude/agents/lean-implementation-agent.md
89:## Phase Status Updates (MANDATORY)
95:Use Edit tool to mark the phase `[IN PROGRESS]`: ...
109:Use Edit tool to mark the phase `[COMPLETED]` ...
# zero mentions of update-phase-status.sh anywhere in the file
```

The same pattern (direct Edit-tool phase-heading mutation as the *sole* mechanism, with no
`update-phase-status.sh` call anywhere) was confirmed in
`lean-implementation-hard-agent.md` and `typst-implementation-agent.md` — the exact two agent
families that handled tasks 696 and 649. Scanning every implementation agent across every loaded
extension in this repo:

| Agent | Calls `update-phase-status.sh`? | Phase-heading mechanism |
|---|---|---|
| `general-implementation-agent.md` | **Yes** (Stage 4A, 4D, Stage 5a backstop) | Script primary; raw Edit documented as explicit "Fallback: If the script is unavailable" |
| `lean-implementation-agent.md` | No | Raw Edit only |
| `lean-implementation-hard-agent.md` | No | Raw Edit only |
| `typst-implementation-agent.md` | No | Raw Edit only |
| `latex-implementation-agent.md` | No | Raw Edit only |
| `books-implementation-agent.md` | No | Raw Edit only |
| `cslib-implementation-agent.md` | No | Raw Edit only |
| `cslib-implementation-hard-agent.md` | No | (has its own "Phase Status Updates (MANDATORY)" section; no script call) |
| `z3-implementation-agent.md` | No | Raw Edit only |
| `python-implementation-agent.md` | No | Raw Edit only |
| `rust-implementation-agent.md` | No | Raw Edit only |
| `founder-implement-agent.md` | No | Raw Edit only |
| `neovim-implementation-agent.md` | No | Raw Edit only |

(`nix-implementation-agent.md` and `email-implementation-agent.md` contain neither a "Phase
Status Updates" section nor an `update-phase-status.sh` call — those task types appear not to
use the multi-phase plan-heading convention at all, so they are out of scope for this defect
rather than silently affected by it; this should be confirmed, not assumed, if either is pulled
into the fix.)

**This answers the scope-determining question directly**: the dispatch warns "a routing
regression... is a SMALL fix; a design gap is not." This is the design-gap case. The heartbeat
mechanization effort (per `update-phase-status.sh`'s own header comment, written to fix exactly
this class of defect — "prose heartbeat instructions... fired 0 times... while THIS script's own
invocation fired 16/16") was correctly designed but was deployed to exactly one of 13 structurally
parallel agent definitions. The dispatch task 272 is right not to rebuild a second mechanism; the
existing one should be *extended in reach*, not re-architected. Two credible remedies, in
increasing order of robustness (a planning decision, not resolved here):

1. **Mechanical propagation**: edit each of the ~11 affected agent files to mirror
   `general-implementation-agent.md`'s own pattern exactly — call `update-phase-status.sh` as
   primary, keep the existing Edit-tool instructions verbatim but reframed as the documented
   fallback. Low risk (copies an already-proven pattern), bounded (one section per file), but
   does not prevent the next new domain agent from reintroducing the gap.
2. **Structural fix**: have a mechanism independent of agent prose (e.g. a PostToolUse hook on
   the Edit tool that pattern-matches a `### Phase N: ... [STATUS]` heading change and fires the
   heartbeat side-channel itself) so coverage does not depend on every agent file separately
   remembering to call the script. Higher effort, closes the class of bug permanently rather than
   per-file.

**Secondary findings, confirmed but smaller** (as the dispatch itself flags as "genuinely real
regardless of" the primary answer):
- The heartbeat is reachable *only* via a phase-status transition inside
  `update-phase-status.sh`; a task sitting in one long phase (or any task-type without
  phase-headed plans at all) emits nothing between transitions. A time-based or
  dispatch-boundary trigger would close this independent of the propagation fix above.
- `_hb_trace`'s verdict lines (`ok`, `noop:no-lock`, `noop:session-mismatch`,
  `noop:unknown`, `error:task-lock-unresolved`, etc.) are written today and consumed by nothing —
  confirmed: `grep -rl "heartbeat-trace.log"` across the scripts tree finds only the writer
  itself. A consumer (even a simple `/refresh`-time summarizer) would make the `noop:*`/`error:*`
  classes actionable rather than write-only.

### Piece 2 — Third lock state for stale-heartbeat-but-pid-alive

**Confirmed gap, confirmed precedent.** `cmd_check` (task-lock.sh:1010) computes only
`held-fresh`/`held-stale` from `age_minutes(heartbeat_at)` vs. `TASK_LOCK_STALE_MIN` (default 30)
— no pid dimension is consulted at all, even though `holder.json` already carries `pid`/
`pid_source` fields (written by every `write_holder` call site, originally added to support
`cmd_reap`'s own pid-liveness floor at line ~1109: "a lock whose recorded holder pid is
confirmably still alive is never reaped on timestamp age alone").

`cmd_acquire`'s held-lock cross-task overlap pass has the identical gap in a more consequential
spot: when an overlapping foreign lock's heartbeat age exceeds `TASK_LOCK_STALE_MIN`, it
unconditionally emits `WARN: ... is stale (> ... min); proceeding without modifying it.` — no pid
check at all, so a genuinely live session's lock (heartbeat merely delayed — exactly the class of
delay Piece 1 explains) becomes advisory-only. This is the precise incident the dispatch
describes (`heartbeat_age_min=33 threshold_min=30` with the SAME session reported `live:true,
liveness_reason:"pid-alive"` by `session-list`).

The reusable tool already exists and is already factored out for exactly this purpose:
`session_liveness()` (task-lock.sh:1558) takes a session-registry entry file path and returns
`"<age_minutes> <reason>"` where reason is one of `corrupt`, `dead-pid`, `dead-pid-within-grace`,
`stale-heartbeat`, `pid-alive`, `undeterminable`, governed by
`SESSION_REGISTRY_DEAD_PID_MIN=10` / `SESSION_REGISTRY_REAP_MIN=240`. Its own header states it was
factored out precisely so `cmd_session_list` and `session_contention()` share one verdict.

**Correct consumption shape (session_id-keyed, not pid-keyed)**: for a `held-stale` per-task lock,
read `holder_session` from `holder.json` (already done), resolve
`specs/.sessions/${holder_session}.json`, and if that file exists, feed it to `session_liveness()`
to obtain the pid dimension — rather than reading `holder.json`'s own `pid` field and comparing it
to the *caller's* pid. The dispatch's "KEY ON session_id, NEVER ON pid" constraint is about
self-exclusion specifically: task 165's absorbed incident showed two *different* `/orchestrate`
sessions sharing one pid (`pid_source: "ancestor-claude"`, because both ran inside one Claude Code
process's ancestry). A self-exclusion test that compared pids directly would treat a foreign
session as self and silently disable detection for the most common concurrency shape this
feature is meant to serve. Keying the liveness lookup by `holder_session` (never by raw pid
equality against the caller) sidesteps this entirely — `session_liveness()` is read-only and
tells you about the *named session*, not about "sameness" to the caller.

With that verdict in hand, `cmd_check` can emit a third line distinct from `held-fresh`/
`held-stale` (e.g. `held-stale-pid-alive`, carrying the same `heartbeat_age_min`/`threshold_min`/
`never_heartbeated` fields plus the new liveness reason) — satisfying the ACCEPTANCE criterion
that "Existing consumers of task-lock.sh's output lines (which read them as prefixes/substrings)
keep working," since a new state is a new, longer line, not a rewrite of the existing two.
`cmd_acquire`'s overlap pass should consult the same verdict before degrading to WARN-and-proceed
— at minimum escalating the warning's wording, and arguably declining to proceed when the
foreign session is demonstrably `pid-alive` (a planning decision, not resolved here, since it
changes acquire's refusal semantics and needs the fixture test the ACCEPTANCE section requires).

A session-registry entry may not exist at all for a given `holder_session` (e.g. a session that
never called `session-register`, or one already reaped) — this must fall back to today's
two-state behavior rather than erroring, mirroring every other no-op-not-abort convention already
used throughout this file.

### Piece 3 — Re-derive registry file_scope on heartbeat

Confirmed exactly as described. `cmd_session_register` (task-lock.sh:1437) computes the union
scope once, at registration:

```bash
echo "$task_numbers_json" | jq -c '.[]' | while IFS= read -r tn; do
  get_file_scope "$tn"
done > "$scopes_tmp"
file_scope_json=$(jq -s -c 'add | unique' "$scopes_tmp")
```

`cmd_session_heartbeat` (task-lock.sh:1494) reads every other field (`pid`, `pid_source`,
`command`, `task_numbers_json`, `started_at`) straight off the existing registry entry and
re-writes them unchanged alongside a fresh `heartbeat_at` — `file_scope_json` is one of the
fields read back verbatim, never recomputed. `task_numbers_json` is also read back verbatim
(unchanged, correctly — the session's task set does not change mid-flight; only the per-task
`file_scope` inside `specs/state.json` can widen after registration).

**Minimal fix**: factor the `get_file_scope` loop + `jq -s -c 'add | unique'` computation out of
`cmd_session_register` into one shared helper (e.g. `derive_union_file_scope(task_numbers_json)`),
call it from `cmd_session_register` exactly as today (no behavior change there — same inputs, same
output), and call it again from `cmd_session_heartbeat` in place of the verbatim-read
`file_scope_json`, using the already-read `task_numbers_json` as input. This closes the gap with
no schema change and no change to any consumer of the registry entry's shape.

### Absorbed (a) — Class E contention review is dead on arrival

Confirmed at `commands/orchestrate.md`: the `orchestrate-predispatch-review.sh` call is at line
202; `batch_session_id="$(common_session_id)"` is minted at line ~250, after the dependency-graph
construction and the MAX_TASKS guard. `common_session_id()` (`scripts/lib/common.sh:141`) echoes
`sess_<epoch>_<6hex>` with no external dependency. The fix is a pure reordering: move the
`source .claude/scripts/lib/common.sh` / `batch_session_id="$(common_session_id)"` pair to before
the predispatch-review call, and pass `--session-id "$batch_session_id"` into that call. As the
dispatch notes, the review runs before `session-register`, so the caller's own session is not yet
in the registry at review time — harmless, since Class E's purpose is to surface *other* live
sessions, and `session_contention()`'s self-session_id exclusion (confirmed present in
`cmd_acquire`'s own session-registry contention pass) is a no-op against an entry that does not
exist yet, not a false negative.

### Absorbed (b) — Stale batch-size message

Confirmed verbatim-identical at `commands/orchestrate.md:236` and
`docs/architecture/orchestrate-state-machine.md:736`:
`echo "Batching is not yet supported. Running with first $MAX_TASKS tasks only."` This directly
contradicts `context/patterns/batch-orchestration-guardrails.md`'s opening section ("Batching Is
the Default... not a specialized throughput optimization reserved for large backlogs"). Both
sites need the same text-only correction, something in the shape of: `"Batch size $task_count
exceeds MAX_TASKS=$MAX_TASKS. Running with the first $MAX_TASKS tasks only."` — dropping the
"not yet supported" framing without dropping the operationally useful "first N only" fact.

### Also observed — dead session-registry entries: already correctly wired, no action needed

The dispatch's own text frames this as an open question to argue rather than assume. Direct
inspection resolves it: `skills/skill-refresh/SKILL.md` (lines 258-265) already calls
`.claude/scripts/task-lock.sh session-reap` (both `--dry-run` and live forms), and
`commands/refresh.md`'s "Stale Session Registry Entries" section documents exactly this sweep,
explicit-invocation-only, mirroring the task-lock reap and orchestration-runtime-file reap sweeps
immediately above it in the same document. `task-lock.sh`'s own comment ("session-reap...
NEVER called from session-register/-heartbeat/-release") is describing the *automatic* paths
correctly — it is not claiming no lifecycle site calls it at all, and `/refresh` is exactly such a
site. The five dead entries observed live in `~/Projects/BimodalLogic/specs/.sessions/` are stale
because `/refresh` has not been invoked recently there, not because the reap path is unwired.
**No code or documentation change is needed for this item**; it should be dropped from the
implementation plan's scope (or at most noted as "verified already correct, no action"). The
PID-recycling risk the dispatch flags (a reaped dead pid being reassigned to a new live process,
which would make a leaked entry falsely read as live) is a pre-existing, inherent limitation of
`kill -0`-based liveness and is orthogonal to the reap-wiring question — it is not newly
introduced or worsened by anything in scope here, and is better tracked as a known limitation
than as an action item for this task.

## Recommendations

1. **Piece 1**: adopt remedy 1 (mechanical propagation of the established
   `update-phase-status.sh`-primary / Edit-fallback pattern to the ~11 affected agent files) as
   the task-272-scoped fix, given the file_scope constraint (`agent-system/extensions/core/`
   only) excludes editing non-core-extension agent files such as `lean-implementation-agent.md`,
   `typst-implementation-agent.md` etc., which live under their own extensions
   (`agent-system/extensions/lean/`, `.../typst/`, etc.) — **this task's own `file_scope` does not
   cover those files**. Recommend the plan either (a) scope Piece 1's fix to documenting the gap
   plus fixing the shared mechanism's own reach (e.g. the secondary "consume `_hb_trace`, add a
   time/dispatch-boundary trigger" items, which are in `agent-system/extensions/core/`), and spawn
   a follow-on per-extension task (or a batch of them) to migrate each domain agent file, or (b)
   get an explicit file_scope widening decision from the user/orchestrator before touching
   cross-extension agent files in this task. Flag this scope tension explicitly in the plan.
2. **Piece 2**: implement `session_liveness()` consumption in `cmd_check` (new third state,
   additive to the existing two lines) and in `cmd_acquire`'s held-lock overlap pass (at minimum
   upgrading the warning; consider escalating to refusal for a confirmed-live foreign session,
   as a planning-time decision). Key every lookup by `holder_session`, never by pid-equality to
   the caller.
3. **Piece 3**: extract `derive_union_file_scope()` from `cmd_session_register` and call it from
   both `cmd_session_register` and `cmd_session_heartbeat`.
4. **Absorbed (a)**: reorder `commands/orchestrate.md` to mint `batch_session_id` before the
   predispatch-review call and thread `--session-id` through.
5. **Absorbed (b)**: fix the message text at both named sites.
6. **Drop** the dead-session-registry-entries item from the implementation plan's scope; it is
   already correctly handled.
7. Fixture tests per ACCEPTANCE: extend `scripts/test-session-registry.sh` (two-live-sessions
   overlap case — likely the best home given it already exercises
   register/heartbeat/release/reap against fixture registry entries) and add a new test (or
   extend `scripts/test-task-lock-reap.sh`) for the stale-but-pid-alive `cmd_check` case. Both
   must demonstrably fail against the current, unmodified scripts before the fix lands, per the
   ACCEPTANCE bullet.
8. Shellcheck every touched script per `context/standards/shell-strict-mode.md` before closing
   out; `scripts/task-lock.sh` and `scripts/orchestrate-predispatch-review.sh` are both already
   large files under `set -euo pipefail` and should be checked as part of normal phase
   verification, not as an afterthought.

## Decisions

- Treat Piece 1 as a confirmed **design gap** (incomplete propagation of an already-correct
  mechanization), not a routing regression — established via live trace-log evidence plus direct
  multi-file code inspection, satisfying the ACCEPTANCE requirement that this question be
  answered in writing before any fix lands.
- Piece 2's liveness lookup is session_id-keyed (via the session registry), never pid-keyed
  against the caller's own pid — this is a hard correctness constraint carried forward from task
  165's absorbed incident, not a style preference.
- The dead-session-registry-entries item is resolved as "no action" — `/refresh` already reaps it
  correctly; this is a scope reduction relative to the dispatch's open-question framing.
- Piece 1's full remediation (editing non-core-extension agent files) likely exceeds this task's
  declared `file_scope`; the plan must make an explicit call on how to handle that rather than
  silently widening scope or silently dropping the cross-extension fix.

## Risks & Mitigations

- **Piece 1's true fix touches ~11 files outside this task's file_scope.** Mitigation: surface
  this explicitly in the plan (see Recommendation 1); do not let the implementation phase quietly
  widen file_scope without a recorded decision.
- **Piece 2's `cmd_acquire` behavior change (if escalated from WARN to refusal) changes acquire's
  observable refusal semantics for any caller currently relying on the stale-overlap WARN-and-
  proceed path.** Mitigation: the ACCEPTANCE criterion ("Existing consumers of task-lock.sh's
  output lines... keep working") bounds this — prefer additive output (new state/fields) over
  changing exit-code semantics of existing call sites unless the fixture test explicitly requires
  the refusal behavior.
- **PID recycling remains an inherent, unresolved limitation of every `kill -0`-based liveness
  check in this codebase** (both `session_liveness()` and the new Piece 2 consumption built on
  top of it). Not newly introduced here; should be tracked as a known limitation, not blocked on.
- **Task 51's substantive dependency** (relocates `specs/.orchestrator-multi-state-*.json` /
  `specs/.return-meta-multi-*.json`, and owns the same two files this task edits:
  `scripts/task-lock.sh`, `context/standards/orchestrator-runtime-files.md`) means this task's
  plan should sequence its own `task-lock.sh` edits defensively (small, additive diffs per the
  Piece 2/3 recommendations above) to minimize merge/rebase friction once 51 lands, rather than a
  large structural rewrite of the file.

## Context Extension Recommendations

- **Topic**: cross-agent coverage of the mechanized heartbeat.
- **Gap**: nothing in `context/patterns/task-lock.md` or `context/standards/` currently documents
  that the heartbeat mechanization's coverage is per-agent-file and must be checked/maintained
  per new domain agent, rather than being a repo-wide guarantee once `update-phase-status.sh` was
  fixed once.
- **Recommendation**: after Piece 1 is actually fixed (whichever scope it lands at), add a short
  subsection to `context/patterns/task-lock.md` (or a new standards note) stating explicitly which
  agent files call `update-phase-status.sh` as primary vs. which still use direct Edit, so a
  future new domain agent's author knows to follow the established pattern rather than
  reinventing direct Edit-tool phase mutation from scratch.

## Appendix

- Search queries / probes used: `grep -n "tl_path\|heartbeat\|_hb_trace"
  scripts/update-phase-status.sh`; `grep -rl "update-phase-status.sh"` and
  `grep -rl "old_string:.*Phase.*\[IN PROGRESS\]"` across every `agents/*.md` in every loaded
  extension; live repo probes against `~/Projects/BimodalLogic`
  (`.agent-logs/heartbeat-trace.log`, `specs/.sessions/*.json`, `git log --all --oneline | grep
  "task (696|649)"`); `grep -n "session_liveness\|cmd_check\|cmd_session_register\|
  cmd_session_heartbeat" scripts/task-lock.sh`; `grep -n "batch_session_id\|--session-id"
  commands/orchestrate.md scripts/orchestrate-predispatch-review.sh`; `grep -n "Batching is not
  yet supported" commands/orchestrate.md docs/architecture/orchestrate-state-machine.md`;
  `grep -n "session-reap" skills/skill-refresh/SKILL.md commands/refresh.md`.
- Key files read: `agent-system/extensions/core/scripts/update-phase-status.sh`,
  `scripts/task-lock.sh`, `scripts/command-gate-in.sh`, `commands/orchestrate.md`,
  `scripts/orchestrate-predispatch-review.sh`, `docs/architecture/orchestrate-state-machine.md`,
  `context/patterns/batch-orchestration-guardrails.md`, `agents/general-implementation-agent.md`,
  and the `agents/*-implementation-agent*.md` files of the lean, typst, latex, books, cslib, z3,
  python, rust, founder, neovim, nix, and email extensions.
