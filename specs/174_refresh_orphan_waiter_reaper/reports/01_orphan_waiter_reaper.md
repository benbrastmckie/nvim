# Research Report: Task #174

**Task**: 174 - Add a self-excluding orphaned-build-waiter reaper pass to /refresh
**Started**: 2026-09-21T00:00:00Z
**Completed**: 2026-09-21T00:00:00Z
**Effort**: medium
**Dependencies**: Task 172 (bounded-build-waiter.md contract, already merged)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/claude-refresh.sh`,
  `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh`,
  `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`,
  `agent-system/extensions/core/commands/refresh.md`,
  `agent-system/extensions/core/skills/skill-refresh/SKILL.md`,
  `agent-system/extensions/core/scripts/task-lock.sh`,
  `agent-system/extensions/core/scripts/reap-session-runtime-files.sh`,
  `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md`,
  `specs/TODO.md` (task 172 and 174 descriptions, including the additional-evidence addenda)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `claude-refresh.sh` already contains the exact architecture the dispatch asks to reuse: one
  atomic `ps -eo` snapshot per invocation (`take_snapshot()`), narrow comm/argv candidacy gates,
  defense-in-depth exclusions (`is_system_slice_cgroup`, `is_owned_by_current_uid`), a documented
  PID-liveness predicate pattern (`is_live_inhibitor_target`), zero-query self-exclusion
  (`pid == $$ || ppid == $$`), and a shared `terminate_pid()` escalation helper. The new pass
  should be a fifth candidacy/exclusion set layered on this same machinery, not a new script.
- `bounded-build-waiter.md` (from task 172) already names the reaper-facing contract explicitly:
  the canonical idiom `timeout N bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _
  "$pid"` is described in that file's own words as "the recognizable process signature a reaper
  can match against." The embedded `"$pid"` trailing argument is directly checkable with the same
  `kill -0` idiom `is_live_inhibitor_target` already uses for its `--pid=` extraction — this gives
  a **precise**, non-heuristic dead-writer test for waiters written in the new canonical shape.
- The **legacy/pre-172 shapes** that actually produced the 22 real orphans (`until grep -q
  "^EXIT=" log; do sleep N; done`, and the self-matching `ps aux | grep "[b]ash cmd"` loop) carry
  **no embedded writer PID in argv at all** — for these, PID-liveness is not extractable, and an
  age+idle-CPU threshold (mirroring `lean_row_is_idle` and rows 5-8's precedent) is the only
  available signal. This split matters: it is safe to treat "old and 0% CPU" as proof of orphan
  status for the legacy shapes (they structurally cannot self-terminate on writer death), but it
  is **not** safe as the sole test for the canonical shape, because a canonical waiter's outer
  `timeout N` is a build-*duration* budget that legitimate long builds can already run close to
  (task 172's own header notes `lake build` has no universal duration cap once its lock is
  acquired) — a live, correctly-behaving canonical waiter watching a genuinely slow build is also
  0% CPU and can be old. Recommendation: gate the canonical shape primarily on embedded-PID
  liveness (precise), and gate the legacy/name-match shapes on age+idle (the only signal
  available), with age as a secondary floor for the canonical shape too (never reap while the
  embedded PID is still alive).
- **Self-exclusion widening** (pid/ppid -> pid/ppid/pgid) requires either (a) adding a `pgid`
  column to `SNAPSHOT_PS_FIELDS` — a breaking change to the fixed-position `read` destructuring
  used at every call site and to the ~1046-line fixture file
  `test-claude-refresh-matcher.sh`, which encodes fake `ps` rows at fixed column counts — or (b) a
  small supplementary `ps -o pgid=` lookup, which (unlike `get_vmswap_kb()`'s reporting-only
  post-snapshot read) would be used to **gate** candidacy, a new category the script's own
  race-freedom argument does not yet cover. Both options are named for the plan to choose between;
  neither is free.
- **Gate-class recommendation**: implement the new pass as a **new pass function inside
  `claude-refresh.sh`** (reusing `take_snapshot()`, `terminate_pid()`, and the self-exclusion
  idiom, per the dispatch's explicit instruction), but give it **age-threshold-only** semantics
  independent of `$FORCE` — matching rows 5-8's "unconditional past threshold whenever
  `--dry-run` is not set" contract rather than rows 1-2's interactive-confirm contract. This is a
  deliberate deviation from how the other two `claude-refresh.sh`-internal passes (rows 1-2) gate
  their own destructive action, and must be stated as such, not silently blended in.
- **Hourly-cadence reachability**: because `claude-refresh.timer` invokes
  `claude-refresh.sh --dry-run` (see `refresh.md`'s existing "hourly cadence itself is
  non-destructive" language), placing the new pass inside `claude-refresh.sh` makes it
  hourly-cadence-**reachable in report-only form**, unlike its closest gate-class precedent (rows
  5-8, which are `/refresh`-only because they live in `specs/`-sweeping scripts skill-refresh
  calls directly, never inside `claude-refresh.sh`). This is a genuine, non-obvious divergence
  from the age-threshold-only precedent that both inventory tables must state explicitly, not
  silently inherit "No (`/refresh`-only)" from rows 5-8.

## Context & Scope

Task 174 asks for a new `/refresh` pass that reaps orphaned build-waiter poll loops — the process
class task 172's `bounded-build-waiter.md` contract defines and names as reaper-matchable — while
being correct-by-construction against the self-match defect that killed an operator's own shell
twice during manual cleanup (`pgrep -f 'until grep' | ... | kill` matched its own command line
because the search string it was pgrep-ing for was literally present in its own argv). The
dispatch names `claude-refresh.sh` as the architecture to reuse, not reinvent, and asks for four
concrete decisions: (1) the new pass's detection logic, (2) an explicit process-group extension to
self-exclusion, (3) an explicit gate-class decision with justification, and (4) an explicit
statement of hourly-cadence reachability. This report addresses all four as research findings and
a recommended design, leaving the actual code changes and both inventory-table edits to the plan
and implementation phases.

## Findings

### Codebase Patterns

**`claude-refresh.sh`'s existing four-pass architecture** (full read at
`agent-system/extensions/core/scripts/claude-refresh.sh`):

- `take_snapshot()` (lines ~560-570): one `ps -eo "$SNAPSHOT_PS_FIELDS" --no-headers` call per
  invocation. `SNAPSHOT_PS_FIELDS='pid,ppid,uid,tty,etimes,rss,comm,cgroup:200,args'` — a
  fixed-position field list; every consumer destructures it with
  `read pid ppid uid tty etimes rss comm cgroup args <<< "$line"`, relying on `read`'s
  "last variable slurps the remainder" behavior for `args`. Adding a field anywhere except
  immediately before `args` (or a fresh trailing field before `args`) breaks every existing
  `read` call site and the ~1046-line fixture file `test-claude-refresh-matcher.sh` that encodes
  synthetic rows at this exact column count.
- **Zero-query self-exclusion** (used identically in `run_claude_pass()` and
  `detect_lean_candidate_trees()`): `if [ "$pid" = "$$" ] || [ "$ppid" = "$$" ]; then continue;
  fi`. Known at parse time from the already-open `$$`/no second query — this is precisely the
  idiom the dispatch says the new pass must reuse and extend.
- **`is_live_inhibitor_target()`** (lines ~166-177): extracts a target PID from argv via
  `[[ "$args" =~ --pid=([0-9]+) ]]` and checks `_pid_is_alive "$target_pid"` (`kill -0`). This is
  the **direct precedent** for extracting an embedded PID from a candidate's own argv and testing
  its liveness — exactly the mechanism available for the canonical bounded-waiter idiom's trailing
  `"$pid"` argument (see Recommendations below). It is explicitly documented as "the one predicate
  that legitimately performs a live check" and is called out as safe specifically because it
  checks a **different** process than the candidate, not the candidate's own already-snapshotted
  liveness.
- **`run_lean_pass()`'s idle gate** (`lean_row_is_idle()`, lines ~326-342): `pcpu` truncated to
  its integer part must be `0`, AND `etimes >= threshold_seconds`
  (`LEAN_LSP_IDLE_THRESHOLD_MIN`, default 240 min). This is the closest existing precedent for an
  age+idle-CPU reap gate, and is the shape the dispatch's own reasoning ("0% CPU and provably
  unreapable") is modeled on.
- **`terminate_pid()`** (lines ~605-632): shared SIGTERM-then-SIGKILL escalation with a
  three-way return code (0 terminated, 1 failed, 2 already-gone), used by both existing
  destructive passes. The new pass should call this unchanged rather than reimplementing
  escalation.
- **`main()`** (lines ~1319-1353) runs all four passes unconditionally in fixed order
  (`run_claude_pass`, `run_lean_pass`, `run_zombie_pass`, `run_mcp_fanout_pass`), each independent
  and separately gated. A fifth pass slots into this same unconditional sequence.

**`bounded-build-waiter.md` (task 172's deliverable)** states the canonical idiom and explicitly
frames it as reaper-facing:

> "This idiom's shape (a captured `pid`, a `kill -0` loop, an outer `timeout`) is the recognizable
> process signature a reaper can match against when cleaning up stale waiters."

The canonical example is:
```bash
cmd >log 2>&1 & pid=$!
timeout 3000 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"
```
The rendered `ps -o args` line for the inner `bash -c` process will contain the literal substrings
`kill -0` and `sleep`, plus a trailing numeric token (the expanded `"$pid"` value, following the
`_` positional placeholder `bash -c` consumes as `$0`). `lake-build-guard.sh` is cited as prior
art already documenting `while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done` with an
explicit prohibition on `pgrep -f "lake-build-guard.sh build"` for the same self-match reason.

**The pre-172 (legacy) orphan shapes actually observed** (from task 172's TODO.md addenda, not
hypothetical):
1. `until grep -q "^EXIT=" log; do sleep N; done` — 22 instances aged 24-55 min at 0% CPU, watching
   one of two log files, produced when a wrapped command (`cmd > log 2>&1; echo "EXIT=$?" >>
   log`) was cancelled by lock contention before its `echo` ran. **No writer PID is present in this
   shape's argv at all** — only a log path and a grep pattern. There is no live-process check
   available; only the log file's own state (which this script's architecture does not currently
   inspect) or an age/idle proxy can identify these as unreapable.
2. `nohup timeout 3000 ... check.sh > log 2>&1 & disown; until ! ps aux | grep -q "[b]ash
   check.sh"; do sleep 8; done` — a self-matching name-based liveness poll (the `[b]` bracket trick
   only defeats `grep`'s own self-match, not the fact that the *waiting shell's own argv* contains
   the literal text it searches for). Recurred 5 times in one run, cleared only by manual
   intervention after ~13 minutes each time despite the gate having already finished. This shape
   also carries no extractable writer PID — the "self-match" is baked into its own design, which
   is exactly why `claude-refresh.sh`'s `is_claude_executable_comm` gate on `comm` (never argv
   substring) and this reaper's own self-exclusion matter here doubly: the new pass's own argv, if
   it ever needed to construct a `pgrep`-style search string, would itself risk the identical
   defect the dispatch opened with. `claude-refresh.sh`'s existing `ps -eo` snapshot approach
   (matching on structured columns, never shelling out to `pgrep -f` against a live string) already
   avoids this by construction, which is one more reason to build the new pass inside this script
   rather than as an ad-hoc `pgrep`/`kill` one-liner.

**Existing "What It Cleans" / "Pass Inventory" tables** (must stay row-for-row identical on gate
and destructiveness, per both files' own header text):
- `agent-system/extensions/core/commands/refresh.md`: 10-row table, rows 1-4 =
  `claude-refresh.sh`-internal (hourly-cadence-reachable), rows 5-10 = `/refresh`-only skill-level
  sweeps. Rows 5-8 share the exact gate-class language the dispatch points to as precedent:
  "age-threshold-only (`{ENV_VAR}`, default {N} min), no interactive confirmation" — and all are
  marked "No (`/refresh`-only)" for hourly cadence.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md`: identical 10-row table (same
  wording, "Owning Step / Section" column instead of "Owning subsection"). Both files state they
  must agree row-for-row; a new row 11 (or inserted row 5, renumbering the rest) must be added to
  **both** in the same commit.
- Precedent env-var naming for age thresholds: `TASK_LOCK_REAP_MIN` (120 min, task-lock.sh),
  `ORCHESTRATOR_SESSION_REAP_MIN` (240 min, reap-session-runtime-files.sh),
  `SESSION_REGISTRY_REAP_MIN` (240 min, task-lock.sh session-reap), `LEAN_LSP_IDLE_THRESHOLD_MIN`
  (240 min, claude-refresh.sh's own Lean pass). A new `BUILD_WAITER_REAP_MIN`-style variable
  would fit this exact naming convention.

### External Resources

No external (non-codebase) research was needed — this is a self-contained architectural
extension of an existing, well-documented local script and an existing local contract file
(`bounded-build-waiter.md`), both already read in full above.

### Recommendations

**1. Detection (candidacy) — two independently-recognized signature families, not one:**

- **Family A (canonical, post-172 idiom)**: comm `bash` (the inner `bash -c` process spawned by
  `timeout N bash -c '...'`), argv containing both `kill -0` and `sleep` substrings. Extract the
  trailing numeric token from argv as the embedded writer PID (mirroring
  `is_live_inhibitor_target`'s `--pid=([0-9]+)` extraction, adapted to a positional trailing
  argument instead of a flag). This family's dead-writer test is **precise**: `! kill -0
  "$embedded_pid"`.
- **Family B (legacy/pre-172 and name-match shapes)**: argv containing a loop keyword
  (`until`/`while`) combined with `grep -q` or a self-referential `ps aux | grep` construct, and
  no extractable writer PID. This family's dead-writer test can only be an **age+idle-CPU**
  heuristic (etimes past a threshold, pcpu integer-truncated to 0), mirroring
  `lean_row_is_idle()` exactly.

Do not collapse these into one undifferentiated "waiter" match — they need different dead-writer
tests, and conflating them either weakens Family A's precision (falling back to the riskier
age-only test where a precise one exists) or wrongly assumes Family B is checkable by PID (it is
not, structurally).

**2. Dead-or-absent-writer semantics**: "dead" = a precise PID-liveness failure (Family A) or an
age+idle threshold breach (Family B, and as a secondary floor for Family A — never reap a
Family-A row whose embedded PID is still alive, regardless of age). "Absent" = a Family-A-shaped
row whose trailing argv token does not parse as a PID at all (malformed/truncated argv); treat
this conservatively as **not a reap candidate** (exclude, do not reap) rather than assuming
absence implies death — this mirrors the MCP fan-out pass's three-way ternary precedent (`in use`
/ `no evidence of use` / `no use signal available`, where the third state is never conflated with
the second) applied to a destructive rather than reporting-only pass, so the conservative
direction (exclude on ambiguity) is the correct one here, unlike the reporting pass where a
`report as ambiguous` outcome carries no risk.

**3. Self-exclusion widening (pid/ppid -> pid/ppid/pgid)**: name the concrete implementation cost
rather than assuming it is free. Two options, either acceptable, neither cost-free:
   - **(a) Widen `SNAPSHOT_PS_FIELDS`** to add a `pgid` column (placed immediately before `args`,
     since `args` slurps the remainder and any field before it must be a fixed single token).
     Requires updating every existing `read ... <<< "$line"` destructuring call site in this
     script (currently one, in `run_claude_pass()`) plus retrofitting the ~1046-line
     `test-claude-refresh-matcher.sh` fixture file's synthetic `ps` rows to the new column count.
     This is the race-free option (single atomic snapshot, no second query) but the higher-touch
     one.
   - **(b) A supplementary `ps -o pgid= -p $$` lookup**, computed once, compared against a
     candidate's own `pgid` obtained via a second small `ps` call. Lower-touch, but this would be
     the **first** post-snapshot live check in this script used to **gate** candidacy (every
     existing post-snapshot read — `get_vmswap_kb()` — is explicitly reporting-only per the
     script's own header invariant ruling). This needs its own documented ruling analogous to that
     one before being added, not a silent exception.
   Recommendation: (a) is more consistent with the script's stated single-snapshot race-freedom
   philosophy; (b) is cheaper to land. The plan should pick one explicitly rather than defaulting
   silently.

**4. Placement and gate class**: implement as a new `run_build_waiter_pass()` function inside
`claude-refresh.sh`, called unconditionally from `main()` alongside the existing four (reusing
`take_snapshot()` — a fresh call using the same `SNAPSHOT_PS_FIELDS`/fixed-position parsing, the
same pattern `run_lean_pass()` already follows for its own independent snapshot rather than
literally sharing one in-memory snapshot variable across passes — and `terminate_pid()`
unchanged). Give it **age-threshold-only** semantics independent of `$FORCE`, mirroring rows 5-8's
documented contract ("unconditional past threshold whenever `--dry-run` is not set... unaffected
by `--force`") rather than rows 1-2's interactive-confirm contract that the other two
`claude-refresh.sh`-internal passes use. This is a deliberate, stated divergence: it is the first
pass *inside* `claude-refresh.sh` whose destructive action is not gated by `$FORCE`, and both
inventory tables must say so explicitly (not merely copy rows 5-8's gate text without noting the
placement difference).

**5. Hourly-cadence reachability — state explicitly, do not let it default silently**: because
`claude-refresh.timer` runs `claude-refresh.sh --dry-run` (see `refresh.md`'s existing "hourly
cadence itself is non-destructive" paragraph), placing this pass inside `claude-refresh.sh` means
the **reporting** half of the new pass **is** reached hourly (an idle build-waiter would show up
in the systemd journal every hour once past threshold, even though nothing is terminated until an
explicit `/refresh` or `/refresh --force` run). This is a genuine divergence from rows 5-8 (which
are never reached by the hourly cadence at all, because they live in scripts skill-refresh calls
directly rather than inside `claude-refresh.sh`). Both inventory tables' new row must record
"Yes (report-only via `--dry-run`; reaping is `/refresh`-only)" rather than copying rows 5-8's
flat "No" or rows 1-2's flat "Yes."

## Decisions

- The new pass lives inside `claude-refresh.sh` as a fifth pass, reusing `take_snapshot()` and
  `terminate_pid()`, per the dispatch's explicit "reuse its architecture" instruction.
- Two independently-gated candidacy families (canonical PID-checkable vs. legacy/name-match
  age-only) rather than one undifferentiated match, because their dead-writer tests are not
  interchangeable and conflating them would either weaken precision where it is available or
  wrongly assume precision where it is not.
- Self-exclusion extends to the reaper's own process group in addition to pid/ppid, per the
  dispatch's explicit instruction; the plan must choose between the snapshot-widening (a) and
  supplementary-lookup (b) implementation paths named above rather than picking one implicitly.
- Gate class: age-threshold-only, independent of `$FORCE`, matching rows 5-8's semantics rather
  than rows 1-2's — an explicit, named deviation from how the other two internal passes gate their
  own destructive action.
- Hourly-cadence reachability: report-only reachable via the hourly `--dry-run` timer invocation;
  actual reaping remains `/refresh`-only (no flag or `--force`), exactly like rows 5-8's
  destructive action.

## Risks & Mitigations

- **Risk**: age+idle-CPU alone is not a safe sole gate for the canonical (Family A) shape, because
  a legitimately long-running build's waiter is also 0% CPU and can be old — `lake build` carries
  no universal duration cap once its lock is acquired (only the *lock-wait* budget is bounded, per
  `long-builds.md`), so a build genuinely running for hours would make its waiter's outer
  `timeout N` (commonly 1800-3000s in today's examples, but not a hard ceiling anyone enforces)
  irrelevant to how long the *waiter* itself has been idle-polling. **Mitigation**: gate Family A
  primarily on precise embedded-PID liveness; use age only as a secondary floor (never reap while
  the embedded PID is alive, regardless of age).
- **Risk**: PID reuse — if the embedded target PID from a Family-A waiter is reused by an
  unrelated process after the original writer exits, `kill -0` on it reports alive even though the
  original writer is long gone, and the waiter never resolves. **Mitigation**: named as a known,
  accepted residual risk (the same class of caveat `claude-refresh.sh`'s own VmSwap-read ruling
  already accepts for a different read), not something this pass can fully close; the age-based
  secondary floor (once past a generous threshold, reap even a live-per-`kill -0` embedded PID)
  is the only backstop, and should be set conservatively high (e.g. matching the
  240-minute precedent already used by `LEAN_LSP_IDLE_THRESHOLD_MIN` /
  `ORCHESTRATOR_SESSION_REAP_MIN`, well above any observed legitimate build duration) to avoid
  false positives while still bounding the worst case.
- **Risk**: widening `SNAPSHOT_PS_FIELDS` for pgid breaks every existing fixed-position `read` and
  the large `test-claude-refresh-matcher.sh` fixture file if done carelessly (e.g. inserted in the
  middle rather than immediately before `args`). **Mitigation**: named explicitly above as
  Option (a)'s cost; the plan should budget for a fixture-file pass, not treat it as a one-line
  change.
- **Risk**: a self-match reintroduced via a careless implementation (e.g. the new pass's own
  detection logic shelling out to `pgrep -f` against a literal string containing `kill -0` or
  `sleep`, echoing the exact defect this task exists to fix). **Mitigation**: build detection
  entirely from the structured `ps -eo` snapshot's `comm`/`args` columns already in memory (as
  every existing pass does), never from a second `pgrep`/`ps aux | grep` invocation — this is
  already this script's universal convention and should not be broken for the new pass.

## Context Extension Recommendations

- **Topic**: process-signature reaping using an embedded liveness-checkable PID (the
  `is_live_inhibitor_target` / bounded-waiter-idiom pattern).
- **Gap**: `bounded-build-waiter.md` states the canonical idiom is reaper-matchable but does not
  itself describe how to extract and check the embedded PID from a rendered `ps args` line — that
  detail currently only exists implicitly in `is_live_inhibitor_target`'s `--pid=` flag-extraction
  precedent, which uses a different argv shape (a flag, not a trailing positional token).
- **Recommendation**: once this task's implementation lands, consider a short addendum to
  `bounded-build-waiter.md`'s "Conforming Examples" section (or a new context pattern file) naming
  the concrete argv-parsing approach a reaper uses to extract the trailing PID, so future waiter
  authors and future reaper authors share one documented extraction convention rather than each
  reinventing a regex. Not created now — this is a documentation follow-up, not part of this
  task's scope per the dispatch.

## Appendix

- Files read in full: `claude-refresh.sh` (1358 lines), `bounded-build-waiter.md` (121 lines),
  `refresh.md` (332 lines, "What It Cleans" section in full).
- Files read in part: `skill-refresh/SKILL.md` (Pass Inventory table and header), `task-lock.sh`
  (reap threshold), `reap-session-runtime-files.sh` (reap threshold), `long-builds.md`
  (timeout/lock-wait distinction), `specs/TODO.md` (task 172 and 174 full descriptions, including
  the 2026-09-17 and 2026-09-21 addenda evidence blocks).
- Searches run: `grep -rn "until grep"` (located the two prior evidence blocks and the pattern
  file); `find -iname '*bounded-build-waiter*'`; `find -iname 'test-claude-refresh*'` (confirmed
  fixture-file scope/size); `grep -rn "TASK_LOCK_REAP_MIN\|ORCHESTRATOR_SESSION_REAP_MIN\|SESSION_REGISTRY_REAP_MIN"`
  (confirmed existing env-var naming precedent).
