# Implementation Plan: Task #173

- **Task**: 173 - Guarantee lake-build-guard.sh writes a terminal record on every exit path and exposes the build verdict through a result subcommand
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None outstanding (bounded-build-waiter idiom task already COMPLETED)
- **Research Inputs**: specs/173_guard_terminal_record_every_exit/reports/01_guard-terminal-record-and-result.md
- **Artifacts**: plans/01_guard-terminal-record-result.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two coupled changes to one script and its test suite, both in the source store
(`agent-system/extensions/core/scripts/`), never `.claude/**`. First, `run_as_holder()` gains an
`EXIT`/`INT`/`TERM` trap that finalizes `<root>/.lake/build-guard.result` as `state=aborted`
whenever the normal `finalize_record()` call has not run, so a trappable kill never leaves
`state=in_flight` behind. Second, a new `result` subcommand exposes the recorded verdict through
the guard's own exit code (enumerated band, no text parsing), with `--expect-pid` /
`--expect-scope` ownership assertions, a `lake-build-guard: STATUS: exit_status=N` stderr line on
the holder path only, and explicit documentation of all four capture paths. Every phase adds its
own numbered test cases and a mutation check in the suite's existing style.

### Research Integration

- `decide_sharing()` already requires `state == complete` (condition 1), and `flock` releases on
  holder death for any reason including SIGKILL. The waiter/sharing path is therefore already
  correct for a dead holder; this plan does NOT change `decide_sharing()` or the lock-wait path
  (both are PRESERVE items). Phase 1 only adds a verification assertion that this stays true.
- `holder_pid` + `kill -0` is already documented as the liveness handle (header, `print_help()`,
  `context/patterns/bounded-build-waiter.md`); only cross-references to the new `aborted` state
  are added.
- Bash defers a trap until the current foreground child returns: the killed-holder test must
  kill the whole process group (`setsid` + `kill -TERM -- -$pgid`), not only the guard PID.
- SIGKILL is untrappable: documented as an accepted limitation; `result` covers it by detecting
  an orphaned `in_flight` record (lock free) rather than trusting the record alone.
- `STATUS:` line must be emitted after `run_lake_foreground()`'s `tee` captures close, so replay
  byte-equality (cases 1/3) is untouched.
- shellcheck is not on PATH in this environment; use
  `nix shell nixpkgs#shellcheck -c shellcheck ...` for the acceptance gate.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap consulted (no roadmap_path in dispatch).

## Decisions

These are planning judgment calls, recorded here so the implementer does not relitigate them.

1. **Aborted record shape.** Extend `finalize_record()` with an optional third `state` parameter
   (default `complete`) rather than a second writer, preserving its read-back of
   `start_epoch`/`pre_fingerprint`/`scope_key`. The trap writes `state=aborted`,
   `exit_status=<code>` where code is 130 for INT, 143 for TERM, and the shell's pending `$?`
   (forced non-zero; `1` if it was 0) for a bare EXIT, plus a new `abort_reason=INT|TERM|EXIT`
   field. `exit_status` is never left empty on a terminal record.
2. **Idempotency.** A global `_RECORD_FINALIZED=false` flag, set `true` immediately after the
   normal `finalize_record` call; the trap body is a no-op when it is `true`. After the normal
   finalize the trap is also cleared (`trap - EXIT INT TERM`). The INT/TERM handlers finalize,
   then `exit` with 130/143 so the process still terminates with the conventional signal code.
3. **`result` exit band** (enumerated, not passthrough, because a raw passthrough of `lake`'s
   code would collide with the meta-state codes). House style follows `cmd_status` (report on
   stdout, small dedicated codes), clear of 75-79:
   | Code | Meaning |
   |------|---------|
   | 0  | terminal `complete`, recorded `exit_status=0` (build passed) |
   | 20 | terminal `complete`, recorded `exit_status` non-zero (build failed; actual code on stdout) |
   | 21 | non-terminal: `in_flight` and the build lock is currently held (build still running) |
   | 22 | terminal `aborted` (trapped kill), OR orphaned: `in_flight` but the lock is free (holder died untrappably, e.g. SIGKILL) -- reported as `state=orphaned` on stdout |
   | 23 | no record present |
   | 24 | `--expect-pid` / `--expect-scope` mismatch (refusal, message on stderr) |
   | 77 / 78 | existing usage / no-project meanings, unchanged |
   Orphan detection reuses `cmd_status()`'s non-blocking `flock -n` probe on the lock file (no
   process-table scan; PID-reuse-safe). The `cmd_status()`-never-scans-the-process-table rule is
   preserved; `result` also does not scan it.
4. **`--expect-scope` syntax.** `result [--dir DIR] [--verbose] [--expect-pid PID]
   [--expect-scope] [-- LAKE ARGS...]`: when `--expect-scope` is present the post-`--` vector is
   hashed with the existing `compute_scope_key()` and compared to the record's `scope_key`.
   Mismatch checks run before verdict mapping, so a sibling's verdict is never reported.
5. **STATUS line.** Emitted on stderr in `run_as_holder()` after `finalize_record`, and in the
   unserialized no-flock path of `cmd_build()` after `run_lake_foreground`; never on the REPLAY
   branch (the REPLAY marker already carries the recorded status there).

## Goals & Non-Goals

**Goals**:
- A holder terminated by INT/TERM (or any non-SIGKILL shell exit) leaves a terminal record.
- A caller obtains a finished build's pass/fail from `result`'s exit code, with no pipeline.
- A caller can prove the record is its own (`--expect-pid`, `--expect-scope`).
- All four capture paths and the `result` mode documented in header and `--help`.
- Suite green, with new numbered cases and mutation checks; shellcheck clean.

**Non-Goals**:
- Changing `decide_sharing()`'s five-condition staleness policy or the sharing decision.
- A second concurrency mechanism; parsing `lake`'s output; SIGKILL trapping (impossible).
- Consumer-side contract edits (lean4 agents/context) -- separate dependent work.
- Any edit under `.claude/**` or outside the task's file_scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Trap clobbers a legitimately complete record on normal exit | H | M | `_RECORD_FINALIZED` flag + trap clear; mutation check disabling the flag must turn an existing passthrough case (2 or 17) RED |
| Killed-holder test hangs or flakes due to deferred trap | M | H | Launch via `setsid`, kill the process group, bound every wait with a hard timeout and `kill -0` on the captured PID (bounded-build-waiter idiom); never `pgrep -f` |
| STATUS line leaks into capture files, breaking replay byte-equality | H | L | Emit only after `run_lake_foreground` returns; new case asserts capture files contain no `STATUS:` and replay output is byte-identical |
| `set -e`/`set -u` interaction inside trap handler (unset vars, failing grep) | M | M | Handler uses `|| true` guards and `${var:-}` defaults; test with the killed-holder case |
| Exit code 20-24 collides with a future mode | L | L | Document the band in the EXIT CODES block beside status 10 / preflight 11 |
| shellcheck unavailable | M | M | `nix shell nixpkgs#shellcheck -c shellcheck`; if nix fetch fails, record it explicitly as unmet rather than claim clean |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

All phases edit the same two files, so they are serialized (no parallel waves).

### Phase 1: Trap-driven terminal record in run_as_holder [COMPLETED]

**Goal**: No trappable exit path out of `run_as_holder()` leaves `state=in_flight`.

**Tasks**:
- [x] Add optional `state` parameter to `finalize_record()` (default `complete`) and an optional
      `abort_reason` field written only for non-complete states. *(completed)*
- [x] Add `_RECORD_FINALIZED` global and an `_abort_record_trap` handler (per Decisions 1-2);
      install `trap ... EXIT`, `INT`, `TERM` immediately after `write_inflight_record`; set the
      flag and clear the traps after the normal `finalize_record`. *(completed)*
- [x] Header: update staleness condition 1 wording to name `aborted` alongside `in_flight` as
      never-shared (policy itself unchanged); add a short "TERMINAL RECORD GUARANTEE" note
      covering the trap, the process-group delivery nuance, and the SIGKILL limitation pointing
      at `holder_pid` + `kill -0` and at `result`'s orphan detection. *(completed)*
- [x] New case 23: killed holder -- fresh fixture, `FAKE_LAKE_SLEEP` long, launch guard under
      `setsid` in background, wait (bounded) until record shows `state=in_flight`, `kill -TERM
      -- -$pgid`, bounded-wait for guard PID exit via `kill -0`; assert record `state=aborted`,
      non-empty `exit_status`, `abort_reason=TERM`. *(completed: holder_pid read from the record
      itself, not bash's "$!", used as the pgid handle for kill -TERM)*
- [x] New case 24: after case 23's kill, a second `build` on the same root does not block
      (completes well under its `--timeout`) and runs a real build (fake-lake invocation count
      increments; no REPLAY marker) -- proves aborted is not shared and the lock is free. *(completed)*
- [x] Mutation G: neutralize the trap install line via `sed` on a scratch copy; case 23's
      assertion must go RED (record stays `in_flight`). *(completed)*
- [x] Mutation H: neutralize the `_RECORD_FINALIZED=true` guard; an ordinary exit-code
      passthrough build must now end with `state=aborted` (proves idempotency guard load-bearing).
      *(completed: also corrupts the guard's own exit code to 1, per the bare-EXIT branch's
      never-leave-exit_status-zero rule -- test asserts rc=1, state=aborted)*
- [x] Update the suite header's pass-count sentence and mutation-reasoning notes. *(completed)*

**Timing**: 1.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - trap, finalize_record param, header notes
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - cases 23-24, mutations G-H

**Verification**:
- `bash -n` on both files; `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` all PASS, 0 FAILED.
- `git diff` confirms `decide_sharing()` and the `flock -w` waiter block are byte-unchanged.

---

### Phase 2: `result` subcommand and exit band [NOT STARTED]

**Goal**: A finished build's verdict is reachable from the guard's exit code.

**Tasks**:
- [ ] Add `result` to `main()`'s mode dispatch and option parsing (`--dir`, `--verbose`; reject
      build-only options with 77, following existing unknown-option handling).
- [ ] Implement `cmd_result()`: read `state`, `exit_status`, `holder_pid`, `start_epoch`,
      `end_epoch`, `scope_key`, `abort_reason` via `get_record_field()`; print `key=value`
      lines on stdout plus absolute `result_path`, `stdout_path`, `stderr_path`, `log_path`
      (from `init_guard_paths()`); map to the Decision 3 band. Orphan detection via non-blocking
      `flock -n` on the lock file, reported as `state=orphaned`.
- [ ] New cases 25-29: `result` against no record (23), hand-written `in_flight` with lock held
      by a background `flock` holder (21), `in_flight` with lock free (22, `state=orphaned`),
      real passing build (0), real failing build via fake-lake exit override (20, stdout shows
      the real code), aborted record from a phase-1-style kill or hand-written `state=aborted`
      (22). Each on a fresh fixture.
- [ ] Mutation I: force `cmd_result` to always return 0; the terminal-nonzero case must go RED.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Fake lake in the suite already supports a configurable exit code (used by
case 2/17). Confirm by reading the fixture's fake-lake script before writing case 28; if absent,
add an env-driven exit override to the fixture only (inside the test file).

**Files to modify**:
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - `cmd_result`, `main()` dispatch
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - cases 25-29, mutation I

**Verification**:
- Suite all PASS; manual `result` run against a fixture shows the four absolute paths.

---

### Phase 3: `--expect-pid` / `--expect-scope` ownership assertions [NOT STARTED]

**Goal**: A caller can refuse a sibling's verdict under concurrency.

**Tasks**:
- [ ] Parse `--expect-pid PID` (validate numeric, else 77) and `--expect-scope` with the
      post-`--` vector in `result` mode (`--expect-scope` without any vector is a 77 usage error).
- [ ] In `cmd_result()`, before verdict mapping: compare recorded `holder_pid` / recorded
      `scope_key` vs `compute_scope_key "${expect_args[@]}"`; on mismatch print
      `lake-build-guard: result: record belongs to holder pid X / scope Y, not the expected ...`
      to stderr and exit 24; with no record, 23 still wins.
- [ ] New cases 30-32: `--expect-pid` mismatch -> 24 (and no verdict lines on stdout);
      `--expect-scope -- build Foo` against a record built with `build` -> 24; matching
      `--expect-scope -- build` against that record -> 0.
- [ ] Mutation J: neutralize the scope comparison; case 31 must go RED.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - option parsing, assertion block
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - cases 30-32, mutation J

**Verification**:
- Suite all PASS.

---

### Phase 4: STATUS line and documentation [NOT STARTED]

**Goal**: Belt-and-braces status token in piped output; every capture path and mode documented.

**Tasks**:
- [ ] Emit `lake-build-guard: STATUS: exit_status=$rc` on stderr in `run_as_holder()` after
      finalize, and in the no-flock unserialized path; not on the REPLAY branch.
- [ ] Header: name `.lake/build-guard.result`, `.lake/build-guard.stdout`,
      `.lake/build-guard.stderr`, and the log path in the non-goals/state-files text; add the
      `result` row to USAGE and a `result` band to EXIT CODES; add a single "READING THE
      VERDICT" paragraph stating a consumer MUST use `result` or an un-piped `$?`, never a
      pipeline's last stage; document the STATUS line under the REPLAY/marker conventions.
- [ ] `print_help()`: same four paths, `result` usage line with `--expect-pid`/`--expect-scope`,
      the exit band, the MUST-read-verdict rule.
- [ ] New case 33: fresh build stderr contains exactly one `lake-build-guard: STATUS:
      exit_status=0`; capture files contain no `STATUS:`; a subsequent replay's stdout is
      byte-identical to the original capture and its stderr has no `STATUS:` line (cases 1/3
      still pass unchanged).
- [ ] New case 34 (case-21 style): `--help` greps for all four paths, the `result` mode,
      `--expect-pid`, `--expect-scope`, and the never-a-pipeline rule.
- [ ] Mutation K: remove the STATUS emission; case 33 must go RED.
- [ ] Update suite header counts and the by-inspection mutation-reasoning list for cases 23-34.

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - STATUS emission, header, print_help
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - cases 33-34, mutation K

**Verification**:
- Suite all PASS; `lake-build-guard.sh --help` visually names all four paths and `result`.

---

### Phase 5: Final gate [NOT STARTED]

**Goal**: Acceptance criteria met on the final tree.

**Tasks**:
- [ ] Run full suite; record PASS/FAIL counts.
- [ ] `nix shell nixpkgs#shellcheck -c shellcheck` on both files; fix all findings (or record
      explicitly if shellcheck cannot be obtained -- never claim clean without running it).
- [ ] `bash .claude/scripts/check-task-references.sh` (or the source-store equivalent) on both
      files: no task-number references.
- [ ] Confirm `git diff --stat` touches only the two file_scope paths and nothing under `.claude/**`.
- [ ] Acceptance demo: build a failing fixture, then `lake-build-guard.sh result --dir FIXTURE;
      echo $?` returns 20 with no pipeline.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- (fixes only, if the gate surfaces findings) the two file_scope files

**Verification**:
- All acceptance criteria below checked.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` passes (existing 29 + new cases/mutations)
- [ ] shellcheck clean on both files
- [ ] `--help` names all four capture paths and the `result` mode
- [ ] A finished build's pass/fail is readable from `result`'s exit code with no text parsing and no pipeline
- [ ] Killed (TERM) holder leaves `state=aborted`; a later build does not block and does not share it
- [ ] `decide_sharing()`, the 75-79 band, exit 77 allowlist behavior, REPLAY marker, and `--timeout` semantics unchanged

## Artifacts & Outputs

- Modified `agent-system/extensions/core/scripts/lake-build-guard.sh`
- Modified `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`
- `specs/173_guard_terminal_record_every_exit/summaries/01_guard-terminal-record-result-summary.md` (at implementation end)

## Rollback/Contingency

Each phase is committed separately (`task 173 phase {P}: ...`), so a failing phase is reverted
with `git revert` of that phase's commit. If the trap approach proves unreliable under `set -e`
in phase 1, fall back to wrapping the body in a subshell-free `finalize-on-return` helper plus
INT/TERM-only traps, keeping the same `state=aborted` record contract so phases 2-4 are
unaffected. For a genuine whole-tree rollback use `git-snapshot.sh 173` per
`context/contracts/recovery.md`; defensive mid-phase checkpoints use `--no-revert` only.
