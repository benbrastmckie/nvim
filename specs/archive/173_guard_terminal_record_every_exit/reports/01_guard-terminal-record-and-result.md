# Research Report: Task #173

**Task**: 173 - Guarantee lake-build-guard.sh writes a terminal record on every exit path and exposes the build verdict through a result subcommand
**Started**: 2026-09-21T23:53:23Z
**Completed**: 2026-09-21T23:57:45Z
**Effort**: 3-4 hours (per task entry)
**Dependencies**: Task 172 (bounded-build-waiter idiom) - COMPLETED
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/lake-build-guard.sh` and its test suite), `context/patterns/bounded-build-waiter.md`, `context/standards/shell-script-testing.md`, TODO.md task 173/172/221 entries, bash signal-handling semantics, live baseline test run
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The guard writes a structured on-disk record (`<root>/.lake/build-guard.result`) via
  `write_inflight_record()` / `finalize_record()`, but `finalize_record()` is reached ONLY on the
  normal return path out of `run_as_holder()`. There is no `trap`, so a killed/cancelled/
  superseded holder leaves the record permanently at `state=in_flight` naming a dead
  `holder_pid`.
- Critically, this defect does **not** currently break the guard's own lock-contention or
  sharing logic: `flock` releases automatically on process exit (documented in the file header),
  so a waiter blocked in `flock -w "$timeout" "$lock_fd"` is unblocked as soon as a dead holder's
  fd closes — regardless of record state. `decide_sharing()` already requires `state == complete`
  (condition 1), so an `in_flight` record is never shared today (case 6 in the existing suite
  already proves this for a hand-crafted dead-PID record). The genuinely unguarded consumer is
  anything that reads the record's `state` field DIRECTLY as its own termination signal — the
  future `result` subcommand (absorbed task 220 material, see below) being the primary intended
  consumer, plus any hand-rolled script that greps the result file instead of using the
  already-documented `kill -0 "$holder_pid"` idiom.
- `holder_pid` is ALREADY documented as the liveness handle in two places: the guard's own header
  ("WAITING ON AN IN-FLIGHT GUARDED BUILD") and `print_help()`, and independently in
  `context/patterns/bounded-build-waiter.md`'s "Conforming Examples" section, which cites this
  exact `while kill -0 "$holder_pid"; do sleep 1; done` idiom as prior art. The dispatch's request
  to "confirm holder_pid is documented as the liveness handle" is therefore already satisfied;
  the remaining work is making the on-disk *state* field equally trustworthy for a consumer that
  does not want to do its own liveness polling (i.e., the `result` subcommand).
- Recommended fix shape: an `EXIT`/`INT`/`TERM` trap installed around `run_as_holder()`'s body
  that finalizes the record with a new, distinguishable terminal state (e.g. `state=aborted`)
  when the normal `finalize_record()` call has not already run — guarded by an idempotency flag
  so the trap never clobbers a legitimately-completed record. SIGKILL is fundamentally
  untrappable and must be documented as an accepted, honest limitation (mirroring the guard's
  existing 75-79/lake-exit-code collision disclosure style), with `holder_pid` + `kill -0`
  remaining the belt-and-braces fallback for that case.
- A significant bash signal-delivery subtlety affects both the fix and its test: bash defers
  trap execution until the current *foreground* command returns. Killing only the top-level
  guard PID (not its process group) while the wrapped `lake` process is still running will not
  fire the trap until that child eventually exits on its own. The fix, its test, and its
  documentation all need to account for this — see Risks & Mitigations.
- The dispatch's description embeds a second, absorbed feature (former task 220): a `result`
  subcommand, `--expect-pid`/`--expect-scope` assertions, a stable `STATUS:` stderr line, and
  documentation/test updates so a caller can obtain a finished build's pass/fail from the guard's
  exit code alone, with no text scraping. This is additive on top of the trap fix (the `result`
  subcommand's exit-code design explicitly needs the new terminal-abort state this task
  introduces) and both halves should land together, in the source store only
  (`agent-system/extensions/core/scripts/lake-build-guard.sh` and its
  `scripts/tests/test-lake-build-guard.sh`), never in `.claude/**`.

## Context & Scope

Task 173 combines two dispatch-text sections written at different times:

1. The original text: make the terminal-record defect (no trap on `run_as_holder()`) impossible,
   so any correctly-written waiter can always drain.
2. An "ABSORBED 2026-09-17 from former task 220" section: add a `result` subcommand and related
   assertion/documentation/test work so a *finished* build's verdict is reachable from the
   guard's own exit code, closing a real incident where `lake-build-guard.sh build ... | tail -60`
   reported `tail`'s exit code instead of the guard's, causing a broken build to be relayed as
   green.

Both sections target the same two files
(`agent-system/extensions/core/scripts/lake-build-guard.sh` and
`agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`) and are explicitly
dependent — item (a) of the absorbed section says the `result` exit-code design must account for
"whatever terminal-abort state the dependency task introduces," i.e. the state this task's own
trap fix adds. Task 172 (bounded-build-waiter idiom), the sole listed dependency, is already
COMPLETED; its `context/patterns/bounded-build-waiter.md` deliverable is read below and is
directly relevant (it already documents `holder_pid`+`kill -0` as this guard's own prior-art
conforming example).

A related but explicitly out-of-scope task exists in the same TODO.md file (line ~127, the
"BOUNDARY WITH OTHER OPEN WORK" task, consumer-side, editing `lean4.md` /
`lean-implementation-agent.md` / `long-builds.md`): it MUST NOT touch
`lake-build-guard.sh` or its test suite, and this task must not restate its consumer-side
exit-code-capture contract. This report does not duplicate that material.

## Findings

### Codebase Patterns

**Current record lifecycle** (`lake-build-guard.sh`):
- `write_inflight_record()` (lines 362-376): writes `state=in_flight`, `holder_pid=$$`,
  `start_epoch`, empty `end_epoch`/`post_fingerprint`/`exit_status`, `scope_key`, `lake_bin`,
  `log_path`.
- `finalize_record()` (lines 378-396): rewrites the SAME file with `state=complete`, the real
  `end_epoch`, `post_fingerprint`, and `exit_status`. It re-reads `start_epoch`/
  `pre_fingerprint`/`scope_key` from the existing (in-flight) record via `get_record_field()`
  rather than threading them as parameters — any replacement/wrapping finalizer must preserve
  this read-back, or those fields will go blank in a trap-driven finalize too.
- `run_as_holder()` (lines 661-676) is the ONLY caller of both functions, in strict sequence,
  with no `trap` anywhere in the file (confirmed via full read; the word "trap" does not appear
  in the script's current 906 lines). If `run_lake_foreground()` (called between them) never
  returns control back to `run_as_holder()` -- because the whole process was signalled and
  bash exited outright -- `finalize_record()` is skipped entirely and the record is stuck at
  `state=in_flight` forever, with `end_epoch=`/`exit_status=` empty and `holder_pid` naming a now
  -dead PID.
- `decide_sharing()` (lines 401-431) already requires `state == complete` as condition 1 before
  anything else is checked. An `in_flight` record — dead holder or not — is therefore NEVER
  shared today. This is directly exercised by the suite's existing case 6 (a hand-written
  `in_flight` record naming PID `999999`): a real build runs instead of a false share. **This
  means the "waiter/sharing path in cmd_build" the dispatch asks to guard is already correctly
  guarded for the sharing decision** — the gap is specifically the on-disk `state` field never
  reaching a terminal value for a killed holder, which matters to a direct-record consumer
  (the future `result` subcommand), not to `decide_sharing()` itself.
- `cmd_status()` (lines 520-542) never trusts the record for its in-flight determination either
  — it does a non-blocking `flock -n "$fd"` on the LOCK file itself and only reads `holder_pid`
  from the record afterward, purely for the human-readable report line. Because flock state (not
  record state) drives the decision, a dead holder's stale `in_flight` record cannot make
  `cmd_status()` falsely report a build in flight (the lock would already be free).
- `cmd_build()`'s waiter path (lines 723-729) blocks on `flock -w "$timeout" "$lock_fd"`, not on
  the record. Per the header comment (lines 118-121, restated at line 505-506): "`flock` releases
  automatically on process exit, so the lock itself becomes acquirable with no PID bookkeeping
  required." This was independently confirmed by design inspection: `exec {lock_fd}<>"$LOCK_PATH"`
  opens the fd in the guard's own process; the open file description (and therefore the flock
  held on it) is released by the kernel the instant every fd referencing it closes, which happens
  automatically when the holder process terminates for ANY reason, including `SIGKILL`. This is
  advisory-locking (`flock(2)`) semantics, not something the script has to implement itself.

**Existing test suite** (`test-lake-build-guard.sh`, 22 numbered cases / 23 case-level passes +
6 mutation checks, currently 29/29 green, confirmed by a live baseline run in this session):
covers case 6 (abandoned in_flight record never shared), cases 14-16 (Defect A subcommand
validation), cases 18-19 (Defect B scope-keyed sharing), case 20 (REPLAY marker), case 21
(`--help` documents `kill -0`/`pgrep`), case 22 + mutation F (positive-direction memory-pressure
detection). None of the existing cases exercise an ACTUAL kill of a live holder process — case 6
constructs the "dead holder" record by hand rather than by killing a real subprocess. The task's
own acceptance criteria explicitly call for a genuine killed-holder case, which is new coverage,
not a variant of an existing one.

**House style precedents to follow for the new work**:
- Detect-only mode shape: `cmd_status()` is 0 (silent, nothing detected) / 10 (report on stdout).
  `cmd_preflight()` is 0 (silent) / 11 (report on stderr). The dispatch's item (a) explicitly asks
  the new `result` mode to "follow the existing house style for a detect-only mode... rather than
  inventing a new one."
- Stderr message prefix: every guard-emitted message uses the literal prefix
  `lake-build-guard:` (e.g. `lake-build-guard: REPLAY:`, `lake-build-guard: --verbose:`). The
  dispatch's item (c) explicitly names this convention for the new `STATUS:` line
  (`lake-build-guard: STATUS: exit_status=N`).
- Record I/O: `get_record_field()` reads via `grep "^${field}=" | tail -n1 | cut -d= -f2-` — never
  sources the record file. Any new read path (`result`, `--expect-pid`, `--expect-scope`) should
  reuse this helper rather than inventing a parallel reader.
- Scope key: `compute_scope_key()` already hashes a NUL-separated join of the lake argument
  vector. The dispatch's item (b) `--expect-scope` should reuse this exact function against the
  caller's OWN argument vector (passed after `--`, mirroring `build`'s own `-- LAKE ARGS...`
  convention) rather than re-deriving scope some other way.
- Reserved exit-code bands already committed: build mode 75-79 (with an explicit, honestly-
  documented caveat that `lake` itself could theoretically also exit in that range); status 0/10;
  preflight 0/11. A new `result` band must not collide with 75-79, and per the file's own
  precedent for such collisions, any residual ambiguity should be disclosed in a comment rather
  than silently assumed away.
- Mutation-testing convention (from `test-lake-build-guard.sh`'s own header and
  `context/standards/shell-script-testing.md`): a `sed`-based scratch mutant that disables the
  new fix, proving the corresponding new test case actually goes RED against it — required for
  "regex-shaped fixes" per the standard, and this suite already does this consistently (mutations
  A-F). The new trap-based fix and the new `result`/`--expect-*` logic should each get a
  corresponding mutation check, following mutations B/C/D's function-shadowing trick
  (`sed 's/^some_func() {/some_func() { return 0; } ; _disabled_some_func() {/'`).
- Loud-skip / fresh-fixture-per-case discipline (documented in the suite's own header, lines
  15-25): every case must build its own fresh fixture root; the guard's result-sharing cache
  means reusing a fixture across cases would let a later case silently test the cache instead of
  its own intended behavior. Any new case reusing `build_fixture()` must follow this.

### External Resources / Bash Signal Semantics

- **`trap` and `EXIT`/`INT`/`TERM`**: `trap CMD EXIT` fires on ANY shell exit, whether via a
  normal fall-through, an explicit `exit`, or a signal — making it the natural mechanism for
  "finalize on any way out of `run_as_holder()`," exactly as the dispatch's fix-direction
  suggests. `INT`/`TERM` traps additionally let the handler run BEFORE the shell's default
  signal-triggered termination.
- **Deferred trap execution (a real hazard for the test and the fix)**: per bash's documented
  signal-handling behavior, when bash is blocked waiting for a *foreground* command to complete
  and receives a signal for which a trap is set, **the trap does not run until that foreground
  command itself returns**. `run_lake_foreground()` runs `"${cmd[@]}"` (the real/fake `lake`
  invocation) as the shell's own foreground child. If a test (or a real caller) sends `SIGTERM`
  only to the top-level guard PID while the wrapped `lake` process keeps running, the trap will
  NOT fire promptly — it fires only after `lake` eventually exits on its own, which could be
  never. In the realistic incident this task is closing (Ctrl-C, session teardown, or a
  superseding session's cancellation), the signal is normally delivered to the whole foreground
  process group or cgroup at once, so the wrapped `lake` child dies at (approximately) the same
  moment, `wait()` returns quickly, and the deferred trap then runs promptly. This detail must
  inform both the implementation (documenting that group/session-level cancellation, not a
  targeted single-PID kill, is what the trap promptly catches) and the new test (which must kill
  the whole process group — e.g. via `setsid`+`kill -TERM -$pgid`, or by separately signalling
  both the guard PID and its `lake` child — not just the top-level PID, or the assertion will be
  flaky/slow rather than a clean, fast kill-mid-build case).
- **`SIGKILL` is fundamentally untrappable.** No shell-level trap can intercept it. This is a
  hard, well-known POSIX/Linux limitation, not a gap in this script's design. It must be
  documented as an accepted limitation (the same "documented honestly" style the file already
  uses for the 75-79/lake-exit-code collision), with `holder_pid`+`kill -0` remaining the
  authoritative fallback liveness check for exactly this case — which is already correct today
  and needs no change.
- **`flock(2)` release-on-close semantics**: an open file description's flock is released when
  the last file descriptor referencing it closes, across all processes — not tied to any
  explicit unlock call. This is why `exec {lock_fd}<>"$LOCK_PATH"` in the guard's own process,
  combined with a `flock -n "$lock_fd"` from a subprocess sharing that fd via `fork()`, correctly
  keeps the lock held for the guard script's own lifetime and releases it automatically the
  instant that script's process dies for any reason, including `SIGKILL` — independently
  confirming the header's own claim and this report's Codebase Patterns finding above.

### Recommendations

**Part 1 — terminal record on every exit (original dispatch text)**:
1. Introduce a new, distinguishable non-`complete` terminal state (e.g. `state=aborted`) written
   only by a trap-driven finalize, never by the normal path. Extending `finalize_record()` to
   accept a `state` parameter (defaulting call sites to `"complete"`) is a minimal, low-risk
   shape that reuses its existing field-preservation logic (re-reading `start_epoch`/
   `pre_fingerprint`/`scope_key`) rather than duplicating it in a second function.
2. Install the trap immediately after (or wrapping) `write_inflight_record()` inside
   `run_as_holder()`, covering `EXIT INT TERM`, and clear/no-op it right after the normal
   `finalize_record()` call succeeds — an idempotency guard (a local/global flag, or checking
   the record's current `state` before the trap acts) is required so the trap never overwrites a
   legitimately `complete` record on ordinary exit.
3. Choose a reserved `exit_status` value (or leave it distinguishable purely via `state=aborted`
   vs `state=complete`, without needing a fake numeric code) for the aborted case — this is a
   decision the plan should make explicitly, because the absorbed `result`-subcommand work
   (below) needs to expose it distinctly.
4. Document the new state in the header's staleness-policy section (condition 1 currently reads
   "An `in_flight` record with no matching `complete` state means its holder died before
   finishing — an ABANDONED LOCK... such a record is NEVER shared" — this should be updated to
   name `aborted` explicitly alongside `in_flight` as non-shareable, keeping the "NEVER shared"
   guarantee intact for both).
5. Explicitly document the `SIGKILL` limitation and the process-group signal-delivery nuance
   found above, pointing back at the pre-existing `holder_pid`+`kill -0` idiom (header,
   `print_help()`, and `context/patterns/bounded-build-waiter.md`'s "Conforming Examples") as the
   durable, unconditional fallback liveness check that already covers the case a trap cannot.
6. New test case: a genuinely killed holder (long `FAKE_LAKE_SLEEP`, kill the process group
   mid-build, e.g. via `setsid`-launched guard + `kill -TERM -$pgid`), asserting (a) the record
   reaches a terminal, non-`in_flight` state promptly, and (b) a subsequent guard invocation over
   the same root does not block waiting on the dead holder (flock already guarantees this; the
   new assertion is that it stays true after this change) and does not treat the aborted record
   as shareable. A companion mutation check (remove/disable the trap, e.g. via the suite's
   established function-shadowing trick or by neutralizing the `trap` line via `sed`) should
   prove the new case is not vacuously green.

**Part 2 — `result` subcommand and verdict exposure (absorbed task 220 text)**:
1. Add `result [--dir DIR] [--verbose]` following the `status`/`preflight` mode dispatch shape in
   `main()`. Read all documented fields (`state`, `exit_status`, `holder_pid`, `start_epoch`,
   `end_epoch`, `scope_key`) via `get_record_field()`, plus report the four absolute capture
   paths (`RESULT_PATH`, `STDOUT_CAPTURE_PATH`, `STDERR_CAPTURE_PATH`, `LOG_PATH`) which are
   already computed in `init_guard_paths()`.
2. Exit-code design: reserve at minimum four outcomes — no record present; non-terminal
   (`in_flight`); terminal-zero; terminal-nonzero. Two sound options surfaced by this research,
   to be decided at plan time:
   (a) small dedicated sentinel codes for the two meta-states (no-record, non-terminal) in an
   unclaimed range (following `status`'s 0/10 and `preflight`'s 0/11 precedent, e.g. 20/21, well
   clear of 75-79), with the two terminal cases passing the RECORDED `exit_status` straight
   through as the guard's own exit code — directly satisfying "the build's own verdict is carried
   by the guard's exit code" with no separate flag needed for the common case; or
   (b) a fully enumerated small band mirroring build mode's reserved-band style. Either way, the
   new `aborted` state from Part 1 needs an explicit placement in this scheme — the dispatch's
   own phrasing ("non-terminal... plus whatever terminal-abort state the dependency task
   introduces") suggests it should be exposed as its own distinguishable outcome rather than
   silently folded into "terminal-nonzero," since it did not come from `lake`'s own exit at all.
3. `--expect-pid PID` / `--expect-scope -- LAKE ARGS...`: read the recorded `holder_pid` /
   compute `compute_scope_key()` over the given argument vector and compare against the record's
   `scope_key`; refuse loudly (a dedicated exit code, not one of the pass-through terminal codes)
   on mismatch, so a caller can prove the record describes its OWN build under concurrency.
4. `STATUS:` line: emit `lake-build-guard: STATUS: exit_status=N` on the holder path (inside
   `run_as_holder()`/`cmd_build()`, on the branch that actually ran a build), NOT on the REPLAY
   branch — case 1/3's byte-equality assertions on replayed stdout/stderr must stay intact, and
   `cmd_build()`'s existing REPLAY branch (lines 739-759) already carefully avoids adding
   guard-emitted bytes to the replayed streams; the new STATUS line must preserve that separation
   (i.e., it can appear on stderr alongside the build's own captured stderr without corrupting
   the captured/replayable bytes, since `run_lake_foreground()`'s `tee` captures only the wrapped
   command's own stdout/stderr streams, not anything the surrounding shell echoes afterward —
   this needs to be verified precisely at implementation time by checking where in the call chain
   the STATUS line is emitted relative to the `tee` redirections closing).
5. Documentation: name all four capture paths and the `result` mode in both `print_help()` and
   the file header's USAGE/EXIT CODES blocks; state once, in one place, that a consumer MUST use
   `result` or an un-piped `$?` and never a pipeline's last stage.
6. Test cases per the dispatch's item (e): `result` against no record / in_flight / terminal-zero
   / terminal-nonzero (and, per Part 1, terminal-aborted); `--expect-pid`/`--expect-scope`
   mismatch refusal; STATUS line present on a fresh build, absent-or-harmless on replay; a
   case-21-style `--help` grep for the four newly documented paths and the `result` mode.

## Decisions

- Treat this as ONE combined implementation spanning both dispatch-text sections (trap-based
  terminal record + `result` subcommand), since the `result` subcommand's own exit-code design
  is explicitly dependent on the new terminal-abort state — sequencing them as two independent,
  unordered efforts would leave `result`'s design underspecified.
- The "waiter/sharing path in cmd_build treats an in_flight record whose holder_pid is dead as
  stale" requirement is ALREADY satisfied by `decide_sharing()`'s existing `state == complete`
  gate and by `flock`'s own release-on-exit semantics; no code change to `decide_sharing()` or
  the lock-wait path itself is indicated by this research. The plan should verify this rather
  than assume a change is needed there, and should scope the fix to the record-finalization path
  and the new `result` consumer instead.
- `holder_pid`-as-liveness-handle is already documented in three places (guard header,
  `print_help()`, `bounded-build-waiter.md`); no new documentation of that specific fact is
  required, only cross-referencing the new `aborted` state alongside it where the header
  discusses non-shareable states.

## Risks & Mitigations

- **Risk**: A test that kills only the top-level guard PID (not its process group) will either
  hang until the fake `lake` process's `FAKE_LAKE_SLEEP` elapses naturally, or flake depending on
  timing, because bash defers trap execution until the current foreground command returns.
  **Mitigation**: launch the guard invocation via `setsid` (or capture and separately signal the
  wrapped `lake` child) so the test can kill the whole process group at once, mirroring how a
  real cancellation (Ctrl-C, session teardown, systemd scope kill) actually propagates.
- **Risk**: An idempotency bug in the trap (finalizing an already-`complete` record, clobbering
  the real `exit_status` with an aborted sentinel on the ordinary success path) would break
  existing cases 1-3, 17-20 (which all assert exact `exit_status`/byte-identical output on
  ordinary builds). **Mitigation**: guard the trap body on the record's current `state` (or an
  explicit flag set only after the normal `finalize_record()` call completes), and add a
  dedicated mutation check that disables the idempotency guard, confirming an existing case (not
  just the new one) goes RED.
- **Risk**: `SIGKILL` cannot be caught, so a caller that sends `-9` will still leave the record
  stuck at `in_flight` regardless of this fix. **Mitigation**: document this explicitly as an
  accepted limitation (matching the file's existing honesty about the 75-79/lake-exit-code
  band collision), and make sure the plan's acceptance criteria do not implicitly promise
  SIGKILL coverage — the dispatch's own examples ("killed, cancelled, or superseded") are
  satisfied by TERM/INT/normal-EXIT coverage plus the pre-existing `holder_pid` fallback.
  "Superseded" in particular refers to the flock-timeout/no-share paths, which never touch
  `run_as_holder()` for the losing session at all and are unaffected by this change.
  Confirming this scope boundary in the plan avoids over-promising in the acceptance test suite.
- **Risk**: Emitting the new `STATUS:` line in the wrong place in the call chain could leak into
  the captured stdout/stderr files used for REPLAY, breaking the existing byte-equality
  assertions (cases 1, 3) on a later replay of that same result. **Mitigation**: emit it after
  `run_lake_foreground()` returns (i.e., after the `tee` capture files are already finalized),
  the same way the existing REPLAY marker is emitted outside of `replay_shared_result()`'s own
  byte-for-byte cat calls, and add an explicit case verifying replayed bytes are unaffected.
- **Risk**: shellcheck was not available in this sandboxed research environment (`which
  shellcheck` returned nothing), so shellcheck-clean status could not be verified here; the
  ACCEPTANCE criterion requires it. **Mitigation**: the implementation/verification phase must
  run shellcheck in an environment where it is installed (or note if the project's CI/pre-commit
  path already covers this script) before declaring the acceptance criterion met.

## Context Extension Recommendations

- None. This is a `meta` task whose deliverable is entirely within
  `agent-system/extensions/core/scripts/lake-build-guard.sh` and its own test suite;
  `bounded-build-waiter.md` already documents the cross-cutting liveness-handle pattern this task
  depends on, and no additional context file gap was identified.

## Appendix

- Searches/reads performed: full read of `lake-build-guard.sh` (906 lines) and
  `test-lake-build-guard.sh` (846 lines); read of `context/patterns/bounded-build-waiter.md`;
  read of `context/standards/shell-script-testing.md` (first ~100 lines, location/helper/fixture
  conventions); `grep -rn shellcheck` across `agent-system/extensions/core/scripts/`; live
  baseline run of `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`
  (29/29 PASS, 0 FAILED, confirmed before any change); `jq`/`grep` lookups against
  `specs/state.json` and `specs/TODO.md` for task 173's, 172's, and the related boundary task's
  full text; `which shellcheck` (not found in this environment).
- No web search was performed; this is a pure codebase/shell-semantics research task with no
  external library or API surface beyond documented bash/flock(2) signal and locking behavior,
  which is well-established and was reasoned through directly rather than fetched.
