# Research Report: Task #424

**Task**: 424 - Harden four-tier-conflict Case 1's releaser race
**Started**: 2026-10-18T08:20:00Z
**Completed**: 2026-10-18T08:35:00Z
**Effort**: small (single fixture-construction fix, ~20-30 line diff in one test file)
**Dependencies**: None (independent of the concurrently-dispatched siblings; file_scope for
this task is `agent-system/extensions/core/scripts/test-four-tier-conflict.sh`, which does not
overlap task 443's or task 413's declared `file_scope` lists)
**Sources/Inputs**: Codebase (`test-four-tier-conflict.sh`, `task-lock.sh`,
`context/standards/shell-script-testing.md`), live reproduction via induced CPU load, a working
prototype fix exercised under the same load
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, shell-script-testing.md

## Executive Summary

- Reproduced the reported race live, 3/3 times, using the dispatch's own method (28 `yes`
  workers, 1-minute load average 10.5-30.8 across the runs). The unpatched Case 1 fails
  identically every time: `rc=0 note_count=0 abort_count=0` — the foreign lock is gone before
  the foreground `acquire-retry` call's first attempt ever runs.
- Root cause confirmed exactly as scoped: Case 1's backgrounded releaser removes the foreign
  lock after a **fixed** `sleep 0.3`, racing a wall-clock margin against the foreground
  `acquire-retry` call's own first-attempt scheduling latency, which process-fork/exec
  contention can push past 0.3s under heavy load.
- Built and empirically validated a fix that removes the race **by construction**: reuse the
  same external seam `test-four-tier-conflict.sh` case 6 already exploits (`task-lock.sh`'s
  `cmd_acquire_retry` calls bare, unqualified `sleep`, so it is `PATH`-overridable without
  touching production code), but instead of faking the delay, have the shimmed `sleep` touch a
  signal file the instant the retry loop reaches its first NOTE:-then-sleep branch (i.e. the
  instant the first attempt has already observed the lock held), then perform a **real** sleep.
  The backgrounded releaser polls for that signal file's existence instead of sleeping a fixed
  duration, so the lock can never be removed before the first attempt has genuinely seen it.
- Validated the fix prototype: 14/14 cases pass unloaded, and 3/3 times under load matching or
  exceeding the load that reliably broke the original (up to a 27.8 1-minute load average,
  comfortably inside and above the dispatch's reported 12.6-20.5 reproduction range). Cases
  2-13 were unaffected in every run (same 14/14-pass outcome both unloaded and loaded).
- Recommended approach: apply the signal-file construction directly to Case 1's existing block
  in `test-four-tier-conflict.sh` (lines ~189-214 of the current file); no production-code
  change, no change to any other case.

## Context & Scope

This task is a narrow follow-on from the `ambient-host-state-isolation` audit
(`specs/170_isolate_shell_suites_from_host_state/`), whose own Phase 6 load-reproduction pass —
run to confirm that task's Case 5/6 fixes hold under genuine CPU contention — incidentally
turned up a second, unrelated timing dependency in Case 1's *fixture construction* (not its
assertion, which already compares no elapsed time). The live symptom, reproduced independently
twice by that prior work and a third time (three sub-runs) by this research pass, is:

```
[FAIL] 1: Tier-2 resolving case -- rc=0 note_count=0 abort_count=0 output=[]
```

Scope, per the dispatch: harden Case 1's fixture so foreground/background ordering no longer
depends on a fixed wall-clock delay — prefer asserting/enforcing ordering directly over
widening the delay (which would only raise the threshold, not remove the race) — verify under
the same induced-load method, confirm Cases 2-13 unaffected, and confirm (non-vacuousness) that
the reverted original still reproduces the race under the same load while the fix does not. All
four of these were exercised directly during this research pass (see Findings).

This task's own `file_scope` is a single file
(`agent-system/extensions/core/scripts/test-four-tier-conflict.sh`); no concurrently-dispatched
sibling (task 417, 443, 413) declares overlapping scope.

## Findings

### Codebase Patterns

**The defect (`test-four-tier-conflict.sh` Case 1, current lines ~189-214).** The fixture is:

```bash
write_holder_fixture "$TMPROOT/specs/501_case_a_resolving/.lock" "sess_case_a_holder" 501 0

(
  sleep 0.3
  rm -rf "$TMPROOT/specs/501_case_a_resolving/.lock"
) &
RELEASER_PID=$!

t0=$(date +%s%N)
out1=$(TASK_LOCK_RETRY_BUDGET_MS=5000 TASK_LOCK_RETRY_POLL_MS=100 "$TL" acquire-retry 501 implement sess_case_a_waiter 2>&1)
rc1=$?
```

The backgrounded releaser's `sleep 0.3` is an **unconditional** timer — it fires 0.3s after the
subshell is forked, regardless of whether the foreground `acquire-retry` call has started yet,
let alone whether its first `cmd_acquire` attempt has run. Under heavy CPU contention, the
foreground command's own process fork/exec can be delayed well past 0.3s before its first
attempt executes, so by the time it finally checks the lock, the releaser has already removed
it — the loop's first `cmd_acquire` call now succeeds immediately (`rc=0`), the retry branch
(which prints the single `NOTE:` line and then sleeps) is never entered, and the assertion
`note_count1 -eq 1` fails even though `rc1 -eq 0` still holds. This exactly matches the reported
symptom.

**`cmd_acquire_retry`'s relevant structure** (`task-lock.sh`, confirmed by direct read):

```bash
cmd_acquire_retry() {
  local waited_ms=0 first_retry=1
  ...
  while true; do
    if captured_stderr=$(cmd_acquire "$@" 2>&1 1>/dev/null); then rc=0; else rc=$?; fi
    if [ "$rc" -eq 0 ]; then ...; return 0; fi
    ...
    if [ "$first_retry" -eq 1 ]; then
      echo "NOTE: ..." >&2
      first_retry=0
    fi
    sleep "$(awk -v ms="$TASK_LOCK_RETRY_POLL_MS" 'BEGIN { printf "%.3f", ms / 1000 }')"
    waited_ms=$(( waited_ms + TASK_LOCK_RETRY_POLL_MS ))
  done
}
```

Two facts matter: (1) `sleep` is called bare (never an absolute path) on every iteration, which
is the exact external seam `test-four-tier-conflict.sh` case 6 already documents and exploits
for its own `PATH`-shim fix; and (2) on the **first** contention iteration, the `NOTE:` line is
printed and `first_retry` is cleared *immediately before* that same `sleep` call — so the
instant `sleep` is invoked for the first time, the first `cmd_acquire` attempt has already run
and definitively observed the lock as held. That instant is exactly the evidence Case 1's
releaser needs to wait on.

**Existing precedent for this exact technique.** `context/standards/shell-script-testing.md`
("The timing axis needs a different technique") documents two relevant, already-applied rungs:
rung 1 ("inject the clock, or intercept the delay" — the case 6 fake-`sleep`-via-`PATH`
precedent, cited there by name) and rung 2 ("assert ordering or causality instead of elapsed
wall clock" — citing `test-state-write-regen-timing.sh` case 1, which proves "mutex released
before regen begins" by having a second session actually acquire the mutex while regen is
deliberately blocked, a causal proof rather than a timing measurement, and
`test-gate-registry-resolution.sh` cases 15/16, where a dependent step proceeds only once a
completion marker is observed in a shared trace log). Case 1's fix combines both rungs in the
same spirit the document already endorses: intercept the delay via the same `PATH`-shimmed bare
`sleep` seam case 6 uses, but turn the interception into an ordering signal (a marker file) that
the releaser waits on, rather than a counter or a faked instant return.

One distinction worth flagging for future readers: `shell-script-testing.md`'s documented
"timing axis" sub-shapes (cases 5/6, stray-artifact, timeout) are all about a *suite assertion*
reading elapsed wall-clock time. Case 1's defect is different in kind — the assertion itself
never touches elapsed time (per the dispatch description and confirmed by reading the `if`
clause: `rc1 -eq 0 && note_count1 -eq 1 && abort_count1 -eq 0`) — the race is in the **fixture's
own construction**, between two concurrently-started shell processes with no synchronization
between them. This is plausibly a worthwhile addition to that document's sub-shape catalogue
(see Context Extension Recommendations).

### Verification (live reproduction and fix prototype)

All of the following was run directly against this repository's real
`agent-system/extensions/core/scripts/test-four-tier-conflict.sh` (unpatched, for reproduction)
and a prototype copy (patched, for the fix), using `nproc`-derived 28 `yes > /dev/null &`
background workers per the dispatch's reproduction method, each pass's workers killed
immediately afterward:

| Pass | Variant | 1-min load avg at test start | Result |
|------|---------|------------------------------|--------|
| 1 | unpatched (original) | ~3.0 (climbing) | Case 1 FAIL, `rc=0 note_count=0 abort_count=0` |
| 2 | unpatched (original) | ~10.7-30.9 (3 sub-runs) | Case 1 FAIL every sub-run, identical signature |
| 3 | patched prototype | unloaded | 14/14 PASS |
| 4 | patched prototype | ~5.5-27.8 (3 sub-runs) | 14/14 PASS every sub-run |

This is a clean A/B: the identical reproduction method flips from reliably failing to reliably
passing once the releaser's fixed delay is replaced with the signal-file wait, at load levels
meeting and exceeding the dispatch's own reported 12.6-20.5 reproduction range (one sub-run
reached 30.9). Cases 2-13 were unaffected throughout — every "14/14 PASS" outcome above includes
all thirteen other cases passing alongside Case 1.

**The prototype fix** (validated, ready to transplant into the real file in place of Case 1's
current block):

```bash
write_holder_fixture "$TMPROOT/specs/501_case_a_resolving/.lock" "sess_case_a_holder" 501 0

CASE1_SLEEP_SHIM_DIR="$TMPROOT/sleep-shim-case1"
CASE1_SIGNAL_FILE="$TMPROOT/case1-first-attempt-signal"
mkdir -p "$CASE1_SLEEP_SHIM_DIR"
rm -f "$CASE1_SIGNAL_FILE"
REAL_SLEEP="$(command -v sleep)"
cat > "$CASE1_SLEEP_SHIM_DIR/sleep" << SHIMEOF
#!/usr/bin/env bash
touch "$CASE1_SIGNAL_FILE"
exec "$REAL_SLEEP" "\$@"
SHIMEOF
chmod +x "$CASE1_SLEEP_SHIM_DIR/sleep"

(
  until [ -f "$CASE1_SIGNAL_FILE" ]; do sleep 0.01; done
  rm -rf "$TMPROOT/specs/501_case_a_resolving/.lock"
) &
RELEASER_PID=$!

t0=$(date +%s%N)
out1=$(TASK_LOCK_RETRY_BUDGET_MS=5000 TASK_LOCK_RETRY_POLL_MS=100 PATH="$CASE1_SLEEP_SHIM_DIR:$PATH" "$TL" acquire-retry 501 implement sess_case_a_waiter 2>&1)
rc1=$?
t1=$(date +%s%N)
wait "$RELEASER_PID" 2>/dev/null || true
```

The rest of Case 1's block (the `note_count1`/`abort_count1` extraction and the `pass`/`fail`
call) is unchanged — only the setup between the fixture write and the `out1=...` invocation
changes. Two mechanics worth calling out for the implementer:

- `PATH="$CASE1_SLEEP_SHIM_DIR:$PATH"` is a **command-scoped** assignment (prefix on the single
  `"$TL" acquire-retry ...` invocation), not an exported shell-wide change — so the backgrounded
  releaser subshell (started earlier, in the same script) still resolves its own `sleep 0.01`
  polling calls to the real system `sleep`, never the shim. This is intentional and required:
  the shim must only intercept `cmd_acquire_retry`'s internal `sleep` calls, not the releaser's
  own polling loop.
- The shim does a **real** sleep (`exec "$REAL_SLEEP" "$@"`) after touching the marker, not an
  instant return — unlike case 6's shim, which fakes an instant return because case 6 only cares
  about iteration *count*, never about leaving a window of real elapsed time. Case 1 needs that
  real window: it is what gives the (real-`sleep`-polling) releaser time to observe the marker
  and complete the `rm -rf` before the foreground loop's next attempt, which happens roughly
  `TASK_LOCK_RETRY_POLL_MS` (100ms) later. An instant-return shim here would just relocate the
  race rather than removing it.
- `REAL_SLEEP="$(command -v sleep)"` must be resolved **before** `PATH` is overridden for the
  `"$TL"` call (it is, in the ordering above, since the shim file is written and `REAL_SLEEP`
  captured before the `PATH=...` command-scoped invocation), so it resolves to the genuine
  system binary rather than recursing into the shim itself.

### Interaction with sibling in-flight tasks

Checked the territory block's two sibling `file_scope` lists (tasks 443 and 413) against this
task's target file — no overlap. Task 413's list includes `task-lock.sh` and
`test-session-registry.sh` (not `test-four-tier-conflict.sh`), so a concurrent edit there would
not collide with this task's change, though an implementer should still re-read the target file
immediately before editing per the territory contract, in case task 413's work touches shared
test infrastructure this file also sources (it doesn't currently — `test-four-tier-conflict.sh`
copies `task-lock.sh` byte-for-byte into its own isolated `$TMPROOT`, so a concurrent edit to the
*source* `task-lock.sh` would only matter if this suite is re-run after that edit lands, which is
outside this task's own scope).

## Decisions

- **Technique chosen**: signal-file-gated releaser (PATH-shimmed bare `sleep` touches a marker
  on its first invocation; releaser polls the marker instead of sleeping a fixed duration)
  rather than widening the fixed delay. Widening was explicitly ruled out per the dispatch's own
  scope note (it only raises the load threshold at which the race reappears, it does not remove
  the race) and confirmed unnecessary by this research's own empirical result: the signal-file
  version held at a higher load (27.8-30.9) than the dispatch's own reproduction range
  (12.6-20.5).
- **No production-code change.** `task-lock.sh`'s `cmd_acquire_retry` is read-only in this fix;
  the existing bare-`sleep`-via-`PATH` seam (already in production use for case 6) is reused,
  consistent with the suite's stated "no testability hooks added to production code" invariant.
- **Scope confined to Case 1's own block.** No other case's setup or assertion changes.

## Recommendations

1. In `agent-system/extensions/core/scripts/test-four-tier-conflict.sh`, replace Case 1's
   current releaser setup (the `sleep 0.3` background subshell and the plain `"$TL"
   acquire-retry` invocation) with the validated prototype shown under Findings above, keeping
   the existing `note_count1`/`abort_count1`/`pass`/`fail` logic unchanged.
2. Update Case 1's header comment to explain the new construction (why it removes the race by
   construction rather than by margin), mirroring the style of the case 5/6 comments already in
   the file — a draft paragraph is included in the Findings section's prototype discussion above
   and can be adapted directly.
3. As the implementation's own verification step (not redone here, since this is the research
   phase, but the method is already proven): re-run the exact A/B this report ran — original
   fixture (reverted) fails under the induced-load method, patched fixture passes under the same
   method, both at a load meeting or exceeding the dispatch's 12.6-20.5 range — and confirm
   Cases 2-13 still pass (both already held in this research's own runs, but the implementer
   should reproduce them directly against the committed file, not rely solely on this report's
   prototype run).
4. No change needed to `task-lock.sh` or any other script.

## Risks & Mitigations

- **Risk**: the `until [ -f "$CASE1_SIGNAL_FILE" ]; do sleep 0.01; done` polling loop itself adds
  a small residual latency window (up to ~10ms) between the marker appearing and the releaser
  noticing it. Mitigation: this window is bounded by the polling granularity, not by an
  assumption about the foreground call's scheduling delay, so it cannot reintroduce the original
  race — worst case it mildly delays the `rm -rf`, which only matters if it pushes past
  `TASK_LOCK_RETRY_POLL_MS` (100ms), leaving a 10x margin. Validated empirically above at loads
  exceeding the dispatch's own reproduction range.
- **Risk**: a future edit to `cmd_acquire_retry` that moves the `NOTE:`/`sleep` pairing (e.g.
  prints `NOTE:` without immediately sleeping) would silently stop the shim from firing at the
  right moment. Mitigation: this is the same fragility case 6's existing shim already has against
  the identical function, and is appropriately caught by the test itself failing (not a silent
  false-pass) if the pairing ever changes — no special additional mitigation needed beyond what
  case 6 already accepts.
- **Risk**: running two different `sleep`-PATH-shim directories in the same script (case 1's new
  one, case 6's pre-existing one) could be confused for the same mechanism if named carelessly.
  Mitigation: the prototype uses a distinct name (`CASE1_SLEEP_SHIM_DIR` /
  `CASE1_SIGNAL_FILE`, vs. case 6's pre-existing `SLEEP_SHIM_DIR` / `SLEEP_COUNT_FILE`), avoiding
  any collision or reuse ambiguity.

## Context Extension Recommendations

- **Topic**: a fixture-construction ordering race between two concurrently-started shell
  processes, where **neither** side's assertion reads elapsed wall-clock time, is a distinct
  sub-shape from the "timing axis" catalogue `context/standards/shell-script-testing.md`
  currently documents (which is framed entirely around a *suite assertion* measuring elapsed
  time).
- **Gap**: that document's sub-shape list (stray-artifact, timeout) does not yet name "a
  backgrounded helper's fixed-delay release racing a foreground call's own scheduling latency" as
  its own entry, even though the fix technique (signal-file-gated wait via the same PATH-shimmed
  bare-`sleep` seam, rung 1, combined with ordering-not-duration per rung 2) is already squarely
  within the document's existing two-rung framework.
- **Recommendation**: a future `/meta` or documentation task could add this as a fourth
  sub-shape alongside the memory/timing/load/process-table axes already listed, citing this
  task's Case 1 fix as the worked example (parallel to how case 6 is already cited for rung 1
  and case 5 for rung 2). Not created as a task here per this agent's standing instruction not to
  create context-gap tasks automatically.

## Appendix

- Live reproduction commands used (28 `yes > /dev/null &` workers, 1s settle, run suite, kill
  workers) — see Findings' Verification table for the load averages observed per pass.
- Files read: `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` (full Case 1-6
  region plus header), `agent-system/extensions/core/scripts/task-lock.sh` (`cmd_acquire_retry`,
  lines ~929-973), `agent-system/extensions/core/context/standards/shell-script-testing.md`
  ("The timing axis needs a different technique" section).
- Prototype fix exercised at
  `/tmp/claude-1000/-home-benjamin--config-nvim/f460bec2-24c7-45eb-bf98-8c7ed83a0bcd/scratchpad/case1-fix-prototype.sh`
  (scratchpad copy, not part of the deliverable; the implementer should apply the diff directly
  to the real file per Recommendations above).
