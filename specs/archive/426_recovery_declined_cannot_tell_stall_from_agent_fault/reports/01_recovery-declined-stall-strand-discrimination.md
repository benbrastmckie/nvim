# Research Report: Task #426

**Task**: 426 - RECOVERY_DECLINED cannot tell stall from agent fault
**Started**: 2026-10-17T00:00:00Z
**Completed**: 2026-10-17T00:00:00Z
**Effort**: medium (one script, one test file, no new mechanism)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh,
issue-record.sh, system-defect-record.sh, dispatch-metrics.sh, dispatch-strand-probe.sh,
test-orchestrate-cycle-postflight.sh, agents/planner-agent.md, docs/architecture/handoff-schema.md,
context/patterns/system-defect-discrimination.md, context/patterns/infra-failure-discrimination.md)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, rules/source-store-deploy-boundary.md (source
store edit target: `agent-system/extensions/core/`, never `.claude/**`)

## Executive Summary

- DEFECT A is real and narrowly fixable without touching `stall_suspected`'s or
  `stranded_suspected`'s trigger expressions: both signals are already computed in this same
  script, just ~1080-1185 lines *after* the RECOVERY_DECLINED record is written. Hoisting the
  `dispatch-strand-probe.sh` capture and the commit-count check that feeds `stall_suspected`
  (verbatim logic, only moved earlier) to run *before* line 1006's absent-handoff branch makes
  both signals available at record time with no behavior change to their own values — the lock
  the strand probe reads is not released until the much-later WORK (j) block, and no variable
  the commit-count check depends on (`phase`, `have_outcome`, `dispatch_start_ts`, `TASK_DIR`)
  changes between the two points.
- DEFECT B and DEFECT C are both confirmed, one-line-each fixes: `--phase implement` is hardcoded
  at the RECOVERY_DECLINED `issue-record.sh` call (line 1057) when `$phase` (validated
  `research|plan|implement`) is already in scope; `--dispatch-seq "$handoff_dispatch_seq"` (line
  1059) is passed a variable that is structurally always empty in this arm (it is assigned at
  exactly one site, inside the handoff-PRESENT branch, and this arm is nested inside
  `if [ ! -f "$handoff_file" ]`). The correct value, `$expected_dispatch_seq`, is already in
  scope and already has a documented precedent fix at this same file's `dispatch-metrics.sh` call
  site (line ~1828: "deliberately NOT `$handoff_dispatch_seq`, which is empty on the recovery
  path").
- The dispatched-agent contract (`agents/planner-agent.md`'s Stage 0/Stage 7 terminal-write
  MUSTs) is **not** underspecified — it already states "write final metadata" as a MUST and
  explicitly forbids substituting a message-only return. The live symptom was a contract
  *violation*, not a contract *gap*; no doc edit to `planner-agent.md` is warranted by this
  investigation.
- A real, pre-existing test-harness gap blocks this task's own VERIFY items (1)/(2): the test
  sandbox (`test-orchestrate-cycle-postflight.sh`'s `setup_sandbox`) never copies
  `issue-record.sh` into its fixture tree, so every existing RECOVERY_DECLINED fixture's
  `issue-record.sh` call silently no-ops (caught by the pre-existing `|| echo "Note: ... failed
  (non-fatal)"` fallback) and no fixture today reads `issues.jsonl` content at all. Any
  phase/dispatch_seq assertion needs this gap closed first.

## Context & Scope

Investigated `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`'s absent-handoff
/ RECOVERY_DECLINED path (WORK (d), the `if [ ! -f "$handoff_file" ]` branch starting at line 1006,
case arm `STATUS_IN_PROGRESS|STATUS_NOT_SUCCESS|META_DISPATCH_SEQ_MISMATCH` at lines 1009-1065) and
its companion test file, per the dispatch's three named defects (A: no stall/strand consultation;
B: hardcoded `--phase implement`; C: always-empty `--dispatch-seq`). Consulted, without editing
incidentally, `docs/architecture/handoff-schema.md`'s Postflight Boundary section,
`context/patterns/infra-failure-discrimination.md`, `context/patterns/system-defect-discrimination.md`'s
`RECOVERY_DECLINED` row, and `agents/planner-agent.md`'s terminal-write contract. Source store is
the edit target for any follow-on plan/implementation — `agent-system/extensions/core/`, confirmed
identical (`diff` clean) to the currently-deployed `.claude/scripts/orchestrate-cycle-postflight.sh`
copy, and `.claude-extensions.json`'s `core.source_dir` resolves to
`/home/benjamin/.config/nvim/agent-system/extensions/core`.

## Findings

### Codebase Patterns

**Control-flow map of the absent-handoff branch** (all line numbers refer to
`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`):

| Line(s) | What happens |
|---|---|
| 729 | `have_outcome=false` (default) |
| ~880-887 | Handoff-PRESENT branch: `have_outcome=true` set here only |
| 663-664 | `handoff_dispatch_seq` assigned — **the only assignment site**, inside the handoff-present guard (`if [ -f "$handoff_file" ] && [ "$handoff_stale" != "true" ]`) |
| 888-986 | Handoff-ABSENT `else` branch: `orchestrate-recover-outcome.sh` called; `decline_reason`, `out_recovered_reported_status` computed. `have_outcome` stays `false` on every path that falls through to WORK (d) below |
| 1006 | `if [ ! -f "$handoff_file" ]` (always true here, since we are already inside the handoff-absent `else`) |
| 1009-1065 | RECOVERY_DECLINED case arm (`STATUS_IN_PROGRESS\|STATUS_NOT_SUCCESS\|META_DISPATCH_SEQ_MISMATCH`): builds `$recovery_declined_detail`, calls `system-defect-record.sh --defect-class RECOVERY_DECLINED --dispatched-agent "$agent_name"`, then `issue-record.sh --phase implement ... --dispatch-seq "$handoff_dispatch_seq"` (empty) |
| 2031-2045 | `strand_probe_verdict` captured — explicitly "EARLY capture, before WORK (j) releases the per-task lock" (its own header comment), i.e. this siting is driven *only* by the WORK (j) release, not by any dependency on code between line 1065 and here |
| 2053+ | WORK (j): multi-state update and per-task lock release (multi-task engine only) |
| 2154-2202 | `stall_suspected` computed: `{phase in (plan,implement)} AND have_outcome!=true AND dispatch_start_ts!="9999999999"` gates a `git log --since="@$dispatch_start_ts" -- "$TASK_DIR"` commit count; `>0` commits sets it true |
| 2204-2240 | `stranded_suspected` computed: `have_outcome!=true AND dispatch_start_ts!="9999999999" AND strand_probe_verdict=="stranded"` |
| 2305-2346 | Both final JSON emission arms (`user_decision_json != "null"` and the `else`) already carry `stall_suspected`/`stranded_suspected` unconditionally |

**Why hoisting is safe (no change to the two signals' own values on this path)**: every variable
`stall_suspected`'s and `stranded_suspected`'s trigger expressions read (`phase`, `have_outcome`,
`dispatch_start_ts`, `TASK_DIR`, `strand_probe_verdict`) is already fully resolved by line 1006 —
`phase` is parsed and validated at argument-parsing time (line ~359/410); `have_outcome` is `false`
on this path and nothing between lines 1006 and 2154 ever sets it `true` for a dispatch that
reaches WORK (d)'s RECOVERY_DECLINED arm; `dispatch_start_ts` is a CLI parameter, constant for the
whole invocation; `TASK_DIR` is resolved long before line 1006 (used already at line 963). The
`strand_probe_verdict` capture's own siting constraint is *only* "before WORK (j) releases the
lock" (line 2053+) — nothing requires it to run as late as line 2031; running it at (or just
before) line 1006 satisfies that constraint with room to spare. The live incident cited by this
task's dispatch was itself a `phase=plan` dispatch (a planner-agent run), which is squarely inside
`stall_suspected`'s existing `phase in (plan, implement)` gate — no widening of that gate is needed
to cover the cited case.

**The precedent fix for DEFECT C already exists in this same file.** The `dispatch-metrics.sh`
call site (around line 1828) uses `--dispatch-seq "$expected_dispatch_seq"` and documents exactly
the DEFECT C reasoning in its own comment: *"`--dispatch-seq`: `$expected_dispatch_seq`, this
cycle's own minted seq (always populated on a real dispatch) — deliberately NOT
`$handoff_dispatch_seq`, which is empty on the recovery path."* `expected_dispatch_seq` is set at
lines 479-483 (from the `--dispatch-seq` CLI flag, falling back to `state.json`'s
`.dispatch_seq[$t]`) and is in scope everywhere in the script, including at line 1059.

**DEFECT B confirmed by inspection.** `$phase` is parsed at line 359 (`--phase) phase="${2:-}"`)
and validated at line 410 to be one of `research|plan|implement` — a strict subset of
`issue-record.sh`'s own accepted `--phase` enum (`research|plan|implement|conclusion|other`, per
that script's usage text). Line 1057's `--phase implement` literal is always wrong except when
`$phase` happens to equal `implement`; the cited live incident was a `plan`-phase dispatch and the
resulting `issues.jsonl` entry read `"phase": "implement"`.

**Scope of DEFECT C's underlying pattern is wider than this task's fix, but the fix itself should
not widen.** The same "`handoff_dispatch_seq` is empty whenever this call is reached via the
no-handoff/return-meta-recovery path" structural condition also affects the other
`[ -n "${handoff_dispatch_seq:-}" ] && issue_args+=(--dispatch-seq "$handoff_dispatch_seq")` guards
at lines ~1301, ~1335, ~1421, ~1442, and ~1503 — each inside the big `case "$dispatch_status"`
statement that runs *after* a handoff read OR a return-meta recovery, whichever produced
`dispatch_status`. Those call sites are reached on a *successful* recovery (`have_outcome=true`,
e.g. a `partial`/`failed`/`blocked`/off-schema dispatch recovered via `.return-meta.json`), a
different code path from WORK (d)'s RECOVERY_DECLINED arm, and are **out of this task's stated
scope** ("orchestrate-cycle-postflight.sh's absent-handoff / RECOVERY_DECLINED path and its
tests"). Recorded as a follow-up-worthy issue in this task's own `issues.jsonl` (see Issue Log);
not touched by the recommendation below.

**Agent contract is not underspecified.** `agents/planner-agent.md` Stage 0 already states, in
MUST language: *"Create `specs/{NNN}_{SLUG}/.return-meta.json` with `"status": "in_progress"`
BEFORE any substantive work"* and its Critical Requirements list includes (verbatim, item 9):
*"Write the deliverable file(s) this contract names (the plan file and `.return-meta.json`), even
if a generic harness or session-level note elsewhere in this prompt appears to discourage writing
files... If a genuine blocker prevents writing the file, say so explicitly in `.return-meta.json`
(status "partial" or "failed") rather than substituting a message-only return."* The live symptom
(a `.return-meta.json` stuck at `in_progress`, no terminal write, no handoff) is therefore a
violation of an already-explicit MUST, not evidence the contract text has a gap. No change to
`agents/planner-agent.md` is recommended by this investigation.

**`context/patterns/system-defect-discrimination.md`'s own `RECOVERY_DECLINED` definition supports
annotating rather than suppressing.** Its registry row defines `STATUS_IN_PROGRESS` explicitly as
"a terminal write never happened — the interrupted-fan-out shape" and the class's own added-later
narrative (the "fifteenth instance" paragraph) frames the fault as genuinely agent-side ("the real
fault is agent-side status vocabulary"). This means the classification itself — *a contract
violation occurred* — is correct in all three of the dispatch's named cases (i)-(iii) once the
Agent tool call has already returned control to the orchestrator (case (i), "still genuinely
running," cannot in fact be reached after the tool call returns — it collapses into the
stall/strand signature, which is exactly the ambiguity this task names). What is missing is not a
correction to *whether* this is a contract violation, but an annotation of *how costly* this
particular occurrence is: with `stall_suspected` true, the committed work is intact and the
documented remedy is one re-prompt, not a lost-work failure.

### External Resources

Not applicable — this is a pure in-repo control-flow and script-contract investigation; no
external documentation was consulted beyond the repo's own doc/standard files already named in
Context & Scope.

## Recommendations

**Primary recommendation for DEFECT A: hoist, don't defer/suppress.** Move the
`strand_probe_verdict` capture block (currently lines 2031-2045) and the commit-count computation
that feeds `stall_suspected` (currently embedded in the lines-2154-2202 block) to run immediately
before line 1006's `if [ ! -f "$handoff_file" ]` gate — verbatim logic, no change to either
trigger expression (satisfying the dispatch's explicit non-widening constraint for both fields).
At the RECOVERY_DECLINED case arm (lines 1009-1065), after `$recovery_declined_detail` is built,
append a conditional clause:
- when `stall_suspected` (now known early) is true: name the commit count and state the
  documented remedy verbatim ("the committed work is intact; remedy is one re-prompt instructing
  the agent to close its turn in the foreground — do not charge this to failed_tasks");
- else when `stranded_suspected` is true: name the heartbeat-strand signature and the same
  one-re-prompt remedy;
- else (neither signal fired): leave the message as today, optionally noting no corroborating
  stall/strand signal was found (i.e., this occurrence is *not* evidence of recoverable,
  work-intact failure).

Carry both booleans into the `issue-record.sh` call as structured data via its existing
`--tags-json '{...}'` optional field (e.g. `{"stall_suspected": true, "stranded_suspected":
false}`), in addition to the prose clause above, so a future mechanical consumer (triage tooling,
`/distill --review`) can filter without parsing free text. Leave `--severity blocking` and the
`system-defect-record.sh` call unchanged in all cases: per the Findings above, the contract
violation itself is real and worth tracking at the agent/contract level regardless of
recoverability — the fix is a reader being able to **tell** the two readings apart within the one
record, not a reclassification of whether a defect occurred. (The dispatch names an alternative —
"defer/qualify the record until the signals are known" — which this report does not recommend:
deferring the `system-defect-record.sh` call would require either re-running it later from a
different code location with no analogous "lock-released" ordering constraint protecting it, or
buffering its arguments past WORK (j), adding real structural complexity to resolve what is, at
bottom, a wording/annotation problem.)

Both `strand_probe_verdict`/`stranded_suspected`/`stall_suspected` must still be computed (or their
already-hoisted values reused — no second computation needed) at their original emission site for
the final JSON output (lines 2305-2346), which already emits them unconditionally; moving the
computation earlier and simply *not* recomputing it later is sufficient and removes no existing
output field.

**DEFECT B fix**: replace line 1057's literal `--phase implement` with `--phase "$phase"`.

**DEFECT C fix**: replace line 1059's `[ -n "${handoff_dispatch_seq:-}" ] &&
issue_args+=(--dispatch-seq "$handoff_dispatch_seq")` with `[ -n "${expected_dispatch_seq:-}" ] &&
issue_args+=(--dispatch-seq "$expected_dispatch_seq")`, mirroring the `dispatch-metrics.sh` call
site's existing comment and usage verbatim. Scope this fix to the RECOVERY_DECLINED arm only, per
this task's stated scope — the sibling call sites sharing the same structural pattern are a
separate, out-of-scope follow-up (see Issue Log).

**Test-harness gap must be closed before VERIFY (1)/(2) are satisfiable.** Add `issue-record.sh`
to both of `test-orchestrate-cycle-postflight.sh`'s `.claude/scripts/` file-copy lists (the
top-of-file `require_file` loop and `setup_sandbox`'s `cp` loop) — no additional dependency copies
are needed, since `issue-record.sh` sources only `lib/common.sh`, `deploy-root-guard.sh`, and
`lib/task-lookup-lib.sh`, all three already present in the existing copy lists. Then add assertions
against `$WORKDIR/specs/{N}_candidate/issues.jsonl` (parsed with `jq`) in fixture (I) (the existing
`STATUS_IN_PROGRESS` fixture, phase=research) and a new variant at `phase=plan` or `phase=implement`
to pin DEFECT B's fix, plus a `dispatch_seq` equality assertion against the fixture's own
`--dispatch-seq` CLI argument to pin DEFECT C's fix.

## Decisions

- Scope the fix to the RECOVERY_DECLINED case arm only (lines 1009-1065); do not touch the other
  `handoff_dispatch_seq`-reading call sites that share the same latent pattern — out of this
  task's named scope, recorded as a follow-up issue instead.
- Do not edit `agents/planner-agent.md` or any other agent-contract file: the terminal-write
  contract is already explicit; the live symptom was a violation, not a specification gap.
- Recommend annotation (hoist + carry in message/`--tags-json`) over deferral/suppression of the
  `RECOVERY_DECLINED` record: the underlying classification (a contract violation occurred) stays
  correct and useful in all three cases named by the dispatch; what was missing is a reader's
  ability to see both readings (contract violation AND work-intact/recoverable) in one place.
- Treat `docs/architecture/handoff-schema.md`'s Postflight Boundary section and
  `context/patterns/infra-failure-discrimination.md` as already consistent with the recommended
  fix — neither requires editing. `context/patterns/system-defect-discrimination.md`'s
  `RECOVERY_DECLINED` row likewise needs no correction; it already documents the classification
  this report confirms is correct.

## Risks & Mitigations

- **Risk**: hoisting the `dispatch-strand-probe.sh` call earlier changes its relative position
  with respect to other diagnostic stderr output, potentially reordering log lines a human or
  tool greps in sequence. **Mitigation**: the probe is read-only and idempotent (unconditional
  today, "read-only, so a dry run reporting the true current lock/quiescence state is exactly
  correct"); calling it earlier changes only the stderr emission order, not any persisted state or
  computed value. No test in the existing suite asserts stderr line *ordering* across these two
  blocks (confirmed by grep — existing `stranded_suspected`/`stall_suspected` assertions check
  presence/value, not position).
- **Risk**: duplicating the commit-count git-log call (once early for the RECOVERY_DECLINED
  message, once more at the original site for the final JSON emission) could double the `git log`
  invocation cost per dispatch. **Mitigation**: compute once at the hoisted position and remove
  the later recomputation, reusing the same `stall_commit_count`/`stall_suspected` variables at
  the final-emission site — this is a relocation, not a duplication, and actually removes one
  invocation relative to naively adding a second check at the record site.
- **Risk**: a reader of the RECOVERY_DECLINED message/issue entry could misread "stall suspected,
  remedy is one re-prompt" as meaning *no defect occurred*. **Mitigation**: keep
  `system-defect-record.sh`'s unconditional recording and `--severity blocking` on the
  `issue-record.sh` entry in all cases (per Recommendations) — the annotation clarifies
  recoverability, it does not downgrade or suppress the underlying defect signal.

## Context Extension Recommendations

- **Topic**: `context/patterns/system-defect-discrimination.md`'s `RECOVERY_DECLINED` row.
- **Gap**: the row documents the classification but not that a same-cycle `stall_suspected`/
  `stranded_suspected` signal can and should be consulted at record time to annotate (not
  reclassify) the record's message/tags.
- **Recommendation**: once the hoist described above ships, add one sentence to that row (or a
  short adjacent note) stating that `RECOVERY_DECLINED`'s recording site also carries
  `stall_suspected`/`stranded_suspected` in its message and `issue-record.sh` `--tags-json` field
  when either fired at record time, so a future reader of this doc does not need to re-derive the
  ordering fix from the script's comments alone.

## Appendix

- Searches/greps used: `grep -n "RECOVERY_DECLINED\|stall_suspected\|stranded_suspected\|
  STATUS_IN_PROGRESS\|handoff_dispatch_seq\|expected_dispatch_seq\|issue-record.sh\|
  dispatch-strand-probe"` and targeted `sed -n` reads over
  `orchestrate-cycle-postflight.sh` (lines 1-60, 620-1070, 1270-1510, 1795-1840, 2000-2060,
  2140-2350); `grep -n "RECOVERY_DECLINED" ... context/patterns/system-defect-discrimination.md`;
  `grep -n "Postflight Boundary" -A 60 .../docs/architecture/handoff-schema.md`;
  `grep -n "terminal\|in_progress\|Stage 0\|MUST write\|return-meta" agents/planner-agent.md`;
  `grep -n "issue-record.sh\|dispatch-metrics.sh" scripts/tests/test-orchestrate-cycle-postflight.sh`
  (confirmed zero matches — neither script is currently copied into the test sandbox).
- `.claude-extensions.json` confirms `core.source_dir =
  /home/benjamin/.config/nvim/agent-system/extensions/core`; `diff` against the deployed
  `.claude/scripts/orchestrate-cycle-postflight.sh` copy showed no drift at research time.
- Issues/wins recorded to this task's own `issues.jsonl` during this phase: (1) a `minor`
  `orchestration defect` noting the wider `handoff_dispatch_seq`/`expected_dispatch_seq` pattern
  at the other case-arm call sites, out of scope for this task's fix; (2) a `costly` `coverage
  gap` noting `issue-record.sh`/`dispatch-metrics.sh` are not copied into the test sandbox today,
  which blocks this task's own VERIFY (1)/(2) until closed.
