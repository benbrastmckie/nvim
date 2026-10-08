# Task Lock Pattern

Canonical, single-source definition of the per-task concurrency lock used to prevent two
Claude Code sessions from silently clobbering the same shared working tree (the 427
failure: an uncommitted in-progress task wiped by a second session working the same task
number). Every consumer (gate scripts, `skill-orchestrate`,
`general-implementation-agent`) references this document and `.claude/scripts/task-lock.sh` by
path and never restates or reimplements the acquire/heartbeat/release/check logic inline.

**Related**: `.claude/scripts/task-lock.sh` (the implementation), `checkpoint-before-overflow.md`
(git checkpoint procedure this lock composes with), `file-footprint-overlap.md` (a DISTINCT
overlap-detection document; `acquire`'s cross-task check reuses its algorithm — see "Cross-Task
`file_scope` Overlap Check" below), `.claude/context/standards/git-staging-scope.md`.

## Scope

This lock is primarily **task-number-keyed**: it prevents two sessions from both working task N
at once. `acquire` ALSO detects and blocks two sessions working two DIFFERENT
tasks whose declared `file_scope` overlaps (directory-prefix containment, per
`file-footprint-overlap.md`) — see "Cross-Task `file_scope` Overlap Check" below. The two checks
compose: the task-number check and the cross-task `file_scope` check are independent gates
inside the same `acquire` call, and either one refusing is sufficient to refuse the acquire.

## Lockfile Schema

Location: `specs/{NNN}_{SLUG}/.lock/` — a directory, created via `mkdir` for POSIX-atomic
exclusive create (mkdir fails immediately if the directory already exists; there is no
check-then-create race window, unlike the codebase's usual `jq -n > file` write pattern used
for state.json and similar files).

Holder record: `specs/{NNN}_{SLUG}/.lock/holder.json`, written via the same tmp-file-rename
pattern as `manage-topics.sh` (`jq -n ... > holder.json.tmp && mv holder.json.tmp holder.json`)
so the JSON write itself is atomic-on-replace even though the initial directory creation is what
provides exclusivity:

```json
{
  "session_id": "sess_1736700000_a1b2c3",
  "task_number": 788,
  "operation": "plan",
  "acquired_at": "2026-07-04T18:07:17Z",
  "heartbeat_at": "2026-07-04T18:12:40Z",
  "command": "/plan 788",
  "pid": 261744,
  "pid_source": "ancestor-claude"
}
```

| Field | Type | Description |
|-------|------|--------------|
| `session_id` | string | The holding session's ID (`sess_{timestamp}_{hex}`) |
| `task_number` | integer | The locked task's number (unpadded) |
| `operation` | string | `research` \| `plan` \| `implement` \| `revise` \| `orchestrate` |
| `acquired_at` | string (ISO8601) | When the lock was first acquired (preserved across heartbeats and same-session re-acquires) |
| `heartbeat_at` | string (ISO8601) | Last refresh; staleness is computed from this field |
| `command` | string | The invoking command string, for diagnostics (may be empty) |
| `pid` | integer \| null | Resolved via `resolve_session_pid()` (same helper the session registry uses). `null` on a legacy holder written before this field existed, or when resolution failed -- treated everywhere as "no liveness information", never a hard failure. |
| `pid_source` | string | `ancestor-claude` \| `ppid` \| `self` \| `explicit` -- how `pid` was resolved. On `cmd_acquire`'s four write paths (fresh acquire, corrupt-holder recovery, same-session re-entry, stale override) this is FRESHLY resolved for the acquiring process; on `cmd_heartbeat`'s write path the value already on record is PRESERVED rather than re-resolved, because a heartbeat may fire from a different process than the acquirer (notably `update-phase-status.sh`'s mechanized per-phase-transition refresh -- see the "Session-Registry Reader Contract" and Consumers sections below). |

### Pid-Liveness Floor (Reap and Stale-Override)

Both `cmd_reap` and `cmd_acquire`'s stale-override branch refuse to act against a lock whose
recorded `pid` is confirmably alive (`kill -0 "$pid"` succeeds), even once the lock's
`heartbeat_at` has exceeded the relevant staleness threshold:

- **`reap`**: a stale-by-timestamp lock with a live holder pid is reported as
  `SKIP: ... (holder pid <pid> is alive; refusing to reap a live process's lock)` in both
  `--dry-run` and real modes, and is left in place rather than removed.
- **`acquire`'s stale-override**: a stale-by-timestamp lock with a live holder pid returns the
  same ABORT/exit-1 shape as the fresh-lock-held-by-another-session branch, naming the live pid
  and instructing manual override (`rm -rf`), instead of silently overriding it.

A live pid under a stale heartbeat most likely means the holder process is wedged or its
heartbeat mechanism is broken, not that it is gone -- automatic reap/override in that case would
let a second session or sweep silently act against a lock a live process still holds. A holder
with no `pid` field (legacy `holder.json`) or an unresolvable/non-numeric pid falls through
unchanged to the prior timestamp-only behavior on both paths.

## Why `mkdir`, Not `jq -n > file`

The codebase's prevailing atomic-write idiom (`manage-topics.sh`, `update-task-status.sh`) is
`jq ... > tmp && mv tmp target` — this is atomic **on replace** (the `mv` is atomic), but it is
NOT atomic **on creation**: two processes can both observe "file does not exist yet" and both
proceed to write, racing each other. That race is exactly the class of bug this lock exists to
close, so reusing that idiom for the lock's exclusivity primitive would be circular.

`mkdir "$lock_dir"` is POSIX-atomic exclusive create: the syscall itself fails with `EEXIST` if
the directory already exists, with no window between "check" and "create". This script uses
`mkdir` ONLY for the directory (the exclusivity gate); the `holder.json` content within an
already-held directory is still written with the familiar tmp-file-rename pattern, since at that
point only the lock's own holder is touching it.

## Stale Threshold

Tunable via `TASK_LOCK_STALE_MIN` (default 30, plan-sanctioned range 30-60 minutes). This
constant is **distinct from and much longer than** `git-snapshot.sh`'s unrelated 120-**second**
marker-freshness window — that window gates a single destructive-git-command exemption; this
threshold gates whether a lock is still meaningful for concurrency purposes over the timescale
of an entire `/research`/`/plan`/`/implement` invocation (which can run for many minutes).

## Contract: acquire / heartbeat / release / check / init-marker

All five subcommands are implemented exactly once in `.claude/scripts/task-lock.sh`. Call sites
NEVER reimplement lock logic inline (no ad hoc `mkdir .lock` elsewhere in the codebase). A sixth
task-number-lock-family subcommand, `reap`, is documented separately below in its own "Reap
Contract" section rather than as a subsection here, since its contract (threshold derivation,
two-band staleness model, archive-depth sweep) is substantial enough to warrant its own heading.

### `acquire <task_number> <operation> <session_id> [command]`

1. Resolve the task directory (`specs/{NNN}_{SLUG}/`) in three steps, tried in order: prefer
   `state.json`'s `project_name`; fall back to a filesystem glob if that path does not exist on
   disk; and, only if neither resolves anything, create the `state.json`-derived path together
   with its `reports/`, `plans/`, and `summaries/` subdirectories. The glob fallback itself never
   creates a directory, so a task number that is unknown to `state.json` and absent from disk
   still fails resolution cleanly rather than being conjured into existence.

   Create-if-missing is **opt-in and exclusive to `acquire`** — it is passed as a second,
   explicit argument that only `cmd_acquire` supplies. `heartbeat`, `release`, and `check` all
   resolve the task directory read-only and have zero filesystem side effects, including when
   invoked against a task that has no directory yet on disk (see the read-only clause repeated in
   each of their own sections below).
2. **(cross-task overlap check)** Acquire the `specs/.scope-lock/` global mutex (see "Cross-Task `file_scope`
   Overlap Check" below). On mutex timeout, print an error and exit **2** (fail closed — never
   fail open). Inside the mutex: run the cross-task `file_scope` overlap scan; a fresh
   overlapping foreign lock refuses here (exit 1) before the own-task `mkdir` is ever attempted.
3. `mkdir "$TASK_DIR/.lock"`.
   - **Success** (directory did not exist): write `holder.json`, exit 0. Fresh acquire.
4. **`mkdir` failure** (directory already exists): read the existing `holder.json` and branch
   on `session_id` FIRST, before ever considering staleness:
   - **Same `session_id`** (the CRITICAL, highest-impact case — see below): refresh
     `heartbeat_at` in place, preserve `acquired_at`, exit 0. Same-session re-entry NEVER
     self-blocks, regardless of staleness.
   - **Different `session_id`, fresh** (`heartbeat_at` within `TASK_LOCK_STALE_MIN`): refuse.
     Print the two-line `ABORT:` + remedy message (see below) to stderr, exit 1.
   - **Different `session_id`, stale** (`heartbeat_at` older than the threshold): print the
     visible override-and-warn message to stderr, overwrite `holder.json` for the new session,
     exit 0. Never a silent steal, never a permanent refusal.

The mutex (step 2) wraps BOTH the cross-task scan and the entire own-task mkdir/holder sequence
(steps 2-4), closing the scan-then-mkdir TOCTOU race between two concurrent acquires with
overlapping `file_scope`.

#### Cross-Task `file_scope` Overlap Check

In addition to the task-number check above, `acquire` scans every OTHER currently-held
`.lock/holder.json` under `specs/` for a `file_scope` overlap with the acquiring task's own
declared `file_scope`, using `file-footprint-overlap.md`'s directory-prefix algorithm exactly
(transcribed to jq in `scopes_overlap()`; not restated or forked). This is a repo-wide scan,
distinct from `file-footprint-overlap.md`'s own two batch-scoped callers (see that document's
Consumers section).

- **`file_scope` empty or absent** (either side): no protection, no scan effect, in either
  direction. `file_scope` is optional; a task without one is neither protected from nor
  protecting against overlap.
- **Same-session bypass**: a foreign lock held by the SAME literal `session_id` is skipped
  entirely, even if its `file_scope` overlaps. This mirrors the task-number check's same-session
  re-entry property. Multi-task dispatch batches share ONE bare `session_id` across every
  per-task `acquire` call (required by the "Register/acquire parity invariant" below), so a
  same-batch sibling's held lock IS bypassed by this rule — two tasks in the same batch are never
  enforced against each other by this check. That is not a hole: in-batch `file_scope` collisions
  are detected and deferred earlier, by the batch-admission pre-check
  (`orchestrate-batch-admit.sh`, invoked at Step 2.5 of each multi-task command with
  `defer_reason: file_scope_collision` and `collision_scope: in_batch`), before Step 3's acquire
  loop ever runs. See "Register/acquire parity invariant" under Consumers item 2 below for the
  session-id-sharing requirement this bypass depends on.
- **Fresh overlapping foreign lock**: refuse. Two-line `ABORT:` message names the other task
  number, its holding session, its heartbeat age, the stale threshold, and the overlapping path.
  Exit 1 — same exit code as the task-number refusal, no new exit-code class.
- **Stale overlapping foreign lock**: one-line `WARN:` to stderr; proceed with the acquire. The
  foreign lock is NEVER mutated by this check — it is read-only with respect to any lock
  directory other than the acquiring task's own.
- **Mutex fail-closed**: if the `specs/.scope-lock/` mutex cannot be acquired within its bounded
  retry window, exit 2 (the existing usage/task-not-found exit-code class) rather than silently
  skipping the scan.

`acquire`'s signature and its three possible exit codes (0/1/2) are unchanged by this check —
only the internal `cmd_acquire` logic gained a scan step, so every existing and future caller
inherits the behavior with zero call-site edits.

### `acquire-retry <task_number> <operation> <session_id> [command]`

Tier 2 (bounded retry) of the four-tier conflict-response ladder (see "Four-Tier Conflict
Response" below). A bounded wait-and-retry WRAPPER around `acquire`, never a modification of it —
`cmd_acquire`'s own body is byte-for-byte unchanged by this subcommand's existence.

- **Exit codes**: identical in meaning to plain `acquire` (0 = acquired, 1 = refused after the
  retry budget, 2 = error). Callers that already branch on `acquire`'s exit code need no changes
  beyond the subcommand name.
- **Budget constants**: `TASK_LOCK_RETRY_BUDGET_MS` (default 15000ms) and
  `TASK_LOCK_RETRY_POLL_MS` (default 500ms), both overridable via environment variable. Sized on
  the `.scope-lock`/`.commit-lock` mutex-acquire budgets (seconds-scale), deliberately unrelated
  to `TASK_LOCK_STALE_MIN` (30 minutes by default) — the two constants measure different
  quantities (how long a fresh contending acquire should wait, versus how long a lock holder's
  heartbeat may go quiet before its lock is considered stale) and must never be derived from one
  another.
- **Never retries exit 2**: an error (`.scope-lock` mutex timeout, `resolve_task_dir` failure, a
  `write_holder` failure) surfaces immediately on the first occurrence. Retrying an error
  condition would just burn the wait budget on a problem bounded retry cannot fix.
- **Every attempt is a full fresh `cmd_acquire` entry**: each retry iteration calls `cmd_acquire`
  from scratch — its own `acquire_scope_mutex` acquire-and-release, its own cross-task overlap
  scan, its own session-registry contention pass. The mutex is therefore acquired and released
  ONCE PER ATTEMPT, never held across the whole wait window — this is what makes it safe to add
  retry here at all (see the next bullet) and what preserves all three same-session re-entry
  exclusions under retry (the same-session branch returns 0 on the FIRST attempt every time, so
  the retry loop body is never entered for a same-session re-acquire).
- **Why the retry loop is OUTSIDE `cmd_acquire`, never inside it**: `cmd_acquire` acquires the
  process-global `specs/.scope-lock/` mutex at entry (`acquire_scope_mutex` +
  `trap 'release_scope_mutex' RETURN`) and holds it for its ENTIRE body, including its ABORT
  branches. A retry loop placed inside `cmd_acquire` would hold that mutex across the whole wait
  window, blocking every other task's acquire system-wide, and would itself be reclaimed by a
  competing waiter after `SCOPE_MUTEX_STALE_SEC` (10 seconds). `acquire-retry` is instead an
  outer loop that calls the full, unmodified `cmd_acquire` afresh per attempt.
- **On the first retry only**, emit a single visible `NOTE:` line (modeled on
  `scripts/git-commit-scoped.sh`'s `index.lock` contention `NOTE:`) stating that the lock is held
  by another session and that a bounded retry is in progress — never one line per attempt.
- **On budget exhaustion**, emit the LAST attempt's captured ABORT text verbatim and refuse (exit
  1) — this is the Tier-2 → Tier-3 handoff: whichever of the three ABORT variants fired reaches
  the caller with every field intact and unmodified, byte-identical to what a plain `acquire`
  call would have emitted for the same fixture.

### `heartbeat <task_number> <session_id>`

Refresh `heartbeat_at` in place if the lock is held by the SAME session. If the lock is
missing, or held by a different session, this is a **no-op with a stderr warning** — heartbeat
never blocks or errors the caller; it is a best-effort refresh at existing checkpoints (the
`/orchestrate` cycle loop, `/implement` phase transitions), not a gate. Task-directory resolution
here is strictly read-only: `heartbeat` never creates a directory, even against a task that
`state.json` names but that has no directory on disk yet.

### `release <task_number> <session_id>`

Owner-verified before removal: compares the caller's `session_id` against `.lock/holder.json`'s
recorded `session_id` and removes `.lock/` only on a match (or when `.lock/` or `holder.json` is
already absent). On mismatch, `release` WARNs loudly on stderr naming both the given and current
holder session, does NOT remove the lock directory, and still returns `0` — mirroring
`scope-release`'s token-mismatch handling (see "Scope-Mutex CLI" below): release is best-effort
and must never fail a caller's cleanup path, so a mismatch degrades to "not released, logged
loudly" rather than a forced removal or a hard error. Idempotent: releasing an already-absent
lock is success, not an error. Success, partial, and failed skill outcomes ALL release — release
is not conditioned on the operation's own success, only on gate-out having run. Task-directory
resolution here is strictly read-only: `release` never creates a directory, even against a task
that `state.json` names but that has no directory on disk yet.

All current callers (`command-gate-out.sh`, the multi-task batch loops in `commands/implement.md`,
`commands/plan.md`, `commands/research.md`, and `skills/skill-orchestrate/SKILL.md`) pass the
identical `session_id` expression used at their matching `acquire` call, so the ownership check
introduces no behavior change for any existing caller -- it only guards against a future caller
passing a mismatched identifier.

### `check <task_number>`

Diagnostic-only: prints the holder + staleness and exits with a code encoding
free / held-fresh / held-stale (see the script's own header comment for the exact exit-code
table; `check`'s exit codes are intentionally distinct from `acquire`/`heartbeat`/`release`'s,
since `check` is a query, not a gate). Task-directory resolution here is strictly read-only:
`check` never creates a directory, even against a task that `state.json` names but that has no
directory on disk yet.

### `never_heartbeated`: the Acquired-Equals-Heartbeat Fingerprint

Both `check`'s held-fresh/held-stale output lines and `reap`'s `would reap:`/`reaped:`/`SKIP:`
lines carry an appended `never_heartbeated=<true|false|unknown>` field
(`unknown` only from `reap`'s missing/unparseable-holder.json fallback branch, which has no
`acquired_at` to compare). It is computed as `acquired_at == heartbeat_at` and is a **distinct**
diagnostic from staleness itself:

- A **fresh, never-heartbeated** lock (`never_heartbeated=true` on a `held-fresh` line) is
  ordinary and not a problem -- the lock was acquired a moment ago and no heartbeat call has had
  a chance to fire yet.
- A **stale, never-heartbeated** lock (`never_heartbeated=true` on a `held-stale` line, or on a
  `reap` line past the reap threshold) is the exact defect class this fingerprint exists to make
  legible: the holder's heartbeat mechanism never fired even once, as distinct from "heartbeated
  normally for a while, then the holder process went quiet" (`never_heartbeated=false`).

The line PREFIX (`held-fresh`/`held-stale`/`would reap:`/`reaped:`/`SKIP:`) and every exit code
are unchanged -- this is an appended field only. The consumers that read `check`'s output today
(`reconcile-task-status.sh`, `orchestrate-cycle-plan.sh`) capture the whole line as an
opaque string for logging/exit-code branching and never do an exact whole-line equality match,
so the appended field is safe for both without any consumer-side change.

### `init-marker <file_path>` (stdin = JSON content)

A generic, atomic-on-creation primitive for marker/state files elsewhere in the codebase that
use a TOCTOU-prone "check-then-create" `if [ -f X ]; then resume; else jq -n ... > X; fi` shape.
It is **file-granularity and composes independently of the task-number `.lock/`
directory documented above** — it is not a second locking mechanism, does not replace
`acquire`/`release`, and never reads, calls, or modifies `cmd_acquire`, `write_holder`, or
`.lock/`.

1. `mkdir "${file_path}.init"` as the atomic per-file exclusivity claim (POSIX-atomic, same
   `mkdir`-for-exclusivity idiom as `.lock/` above, but a distinct directory).
2. **`mkdir` success**: read the JSON payload from stdin, write it to `"${file_path}.tmp"`,
   guard against empty output (mirrors `write_holder`'s `[ ! -s ]` check), `mv` to `"$file_path"`
   (atomic replace), `rmdir "${file_path}.init"`, exit 0 — caller treats this as a fresh start.
3. **`mkdir` failure, valid target**: if `$file_path` exists and is valid JSON (`jq empty`),
   exit 1 — caller resumes from the existing file instead of clobbering it.
4. **`mkdir` failure, orphaned claim**: if the target is still absent or corrupt after a bounded
   recheck (a short poll window that distinguishes an actively-racing writer — expected under
   concurrency — from a claim abandoned by a crashed initializer), print a `WARN:` to stderr,
   `rmdir` the stale `.init` claim, and retry the claim once. If the retry also fails, exit 2.
   Self-heal is never silent and never permanent.
5. Usage/write errors exit 2.

Exit codes: `0` = created (fresh), `1` = already exists (resume from it), `2` = usage/write-error
or unresolved orphaned claim after one retry.

## Heartbeat Coverage Is Per-Caller, Not Repo-Wide

**Verdict (settled before any Piece 1 fix landed): a design gap, not a routing regression.**
The per-task heartbeat mechanism is correct and fully wired -- it lives in
`heartbeat_after_phase_transition()` inside `scripts/update-phase-status.sh` (invoked once, before
either the "Phase N not found" exit or the idempotency early-exit, so every real phase transition
reaches it), and it traces every branch including every no-op class. A plain repo-wide grep for
the literal text `task-lock.sh heartbeat` misses this call site because the script path is held
in the shell variable `$tl_path`, resolved at runtime from two candidate paths -- the call reads
`bash "$tl_path" heartbeat "$task_number" "$hb_sid"`, not a literal filename. An implementer who
trusts that grep and concludes the mechanism is missing will build a redundant second one
alongside an already-correct first one. **Do not build a second mechanism.** The actual gap is
narrower and sits one layer up: the mechanism fires only when `update-phase-status.sh` is
invoked at all, and most domain implementation agents' own prose never calls it.

### The equivalent probe (re-derivable by a future reader)

`heartbeat_after_phase_transition()` traces every branch it can take -- `ok`, every `noop:*`
reason (`no-holder`, `unparseable-holder`, `session-mismatch`, `no-lock`, `unknown`), and every
`error:*` reason (`task-lock-unresolved`, `exit-<rc>`) -- to
`${repo_root}/.agent-logs/heartbeat-trace.log`. Because the function's own no-op branches are
themselves traced, a task with committed phase-completion commits and **zero** trace lines for
that task number proves the function was never ENTERED, not that a no-op branch silently
absorbed the calls -- a no-op still writes a line. The corroborating check: `noop:session-mismatch`
exists in the classifier but appeared **zero** times in this repo's own trace log at
implementation time (`grep -c "noop:session-mismatch" .agent-logs/heartbeat-trace.log` -> `0`
against 4304 total lines: 4287 `ok`, 15 `noop:no-entry`, 2 `noop:no-holder`), confirming the
no-op paths are not the explanation for any task showing zero lines -- only non-invocation is.
Re-run the same `grep -c` against `.agent-logs/heartbeat-trace.log` in any repo to re-derive this
verdict independently.

### The re-derived adoption inventory

`scripts/lint/lint-agent-contracts.sh`'s Check G already carries the authoritative, curated list
of phase-heading-owning agents (`OWNERSHIP_IN_SCOPE_RELATIVE_PATHS`, 14 files -- the set of agent
contracts instructed to edit `### Phase N: ... [MARKER]` headings). Reproduce command (verbatim):

```bash
cd agent-system/extensions && for rel in "${OWNERSHIP_IN_SCOPE_RELATIVE_PATHS[@]}"; do
  printf '%s %s\n' "$(grep -c update-phase-status.sh "$rel" 2>/dev/null || echo 0)" "$rel"
done
```

Measured at implementation time: **14 for `core/agents/general-implementation-agent.md`, 0 for
all other 13.** Confirmed hypothesis: 13 of the 14 phase-heading-owning agents never invoke the
mechanized heartbeat, so a task routed to any of those 13 agents gets zero heartbeat coverage
for its entire implementation phase regardless of how many phase transitions it completes.

### Secondary, independently-real finding: heartbeat is reachable only via a phase transition

Even for the one agent that does call `update-phase-status.sh`, the heartbeat fires only AT a
phase-status transition. A task sitting in one long-running phase between transitions emits
nothing in between. This is real and worth closing regardless of the answer above, and is closed
by a **dispatch-boundary** pulse (see the dispatch-start/dispatch-end call sites documented
below) rather than a time-based timer, which would need its own scheduling mechanism this
codebase does not otherwise have.

### `_hb_trace` verdicts are written and consumed by nothing today

Every `_hb_trace` call appends a line to `.agent-logs/heartbeat-trace.log`, but nothing reads
that log at decision time today -- it is diagnostic-only. Recorded here as a known gap; no
action is taken on it in this task.

### Two scope reductions recorded during this task (verified, not assumed)

1. **Dead session-registry entries need no change.** `skills/skill-refresh/SKILL.md` and
   `commands/refresh.md` already call `task-lock.sh session-reap` on explicit `/refresh`
   invocation (`session-reap` is deliberately explicit-invocation-only -- see "Never Implicit"
   above). Stale entries observed in `specs/.sessions/` mean `/refresh` has not been run
   recently, not that the reap path is unwired. The PID-recycling hazard (a reused pid reading a
   leaked entry as live) is an inherent limitation of any `kill -0`-based liveness signal,
   recorded here as a known limitation rather than an action item for this task.
2. **`scripts/orchestrate-predispatch-review.sh` needs no change.** It already fully implements
   `--session-id` (parses the flag, gates on `session_id_explicit`, threads it into the
   batch-admit subprocess). Absorbed defect (a)'s entire remedy is an ordering fix in
   `commands/orchestrate.md` alone: mint `batch_session_id` before the predispatch-review call
   and pass `--session-id "$batch_session_id"` into it. See the Consumers section below for the
   dispatch-start/dispatch-end pulse sites and `commands/orchestrate.md`'s corrected mint
   ordering.

## Reap Contract

A SEVENTH task-number-lock-family subcommand (alongside `acquire`/`heartbeat`/`release`/`check`/
`init-marker` above), added to convert the accumulating "foreign lock is stale" `WARN:` lines
`acquire`'s cross-task overlap check already emits (see "Cross-Task `file_scope` Overlap Check"
above) from a permanently-repeating, easy-to-ignore signal into a one-time, actionable, reported
cleanup event.

### `reap [--dry-run]`

**Signature**: no required arguments; the sole optional flag is `--dry-run`. Any other argument
is a usage error.

**What it does**: sweeps every task-number `.lock` directory under `specs/` — including
`specs/archive/` — for staleness against `TASK_LOCK_REAP_MIN` (see "Threshold Derivation"
below), and either reports what it would remove (`--dry-run`) or removes it and reports what it
removed (no flag). Every qualifying lock is reported per-item: task number, session id,
operation, and age in minutes. This is deliberately richer than `/refresh`'s pre-existing
postflight-marker sweep, which shows per-item paths in dry-run mode only and collapses to a
generic one-line count after an actual delete — reap's dry-run and live paths both name every
lock individually.

**Dedicated sweep, not `find_held_locks()`**: reap walks
`find "$PROJECT_ROOT/specs" -mindepth 2 -maxdepth 3 -type d -name ".lock"` directly. It
deliberately does NOT call `find_held_locks()` (used internally by `acquire`'s cross-task scan),
because that helper's `-mindepth 2 -maxdepth 2` structurally cannot see
`specs/archive/{NNN}_{slug}/.lock`, which sits one level deeper. See "Two Depths, Deliberately
Different" below for why `find_held_locks()` itself is left unmodified rather than widened to
match.

**Staleness determination, per lock**:
- Valid `holder.json`: age is computed from `heartbeat_at` via the existing `age_minutes()`
  helper (the same GNU/BSD-portable `date` parsing `check` and `acquire` already use — reap
  reuses it rather than reimplementing).
- Missing or unparseable `holder.json` (e.g. an interrupted acquire caught between its `mkdir`
  and its `holder.json` write): age falls back to the `.lock` directory's own filesystem mtime.
  This is reaped only if the mtime age ALSO exceeds the threshold; otherwise it is reported via a
  `SKIP:` line (path, mtime age, and the reason) and left in place — never silently ignored, and
  never removed on a bare "holder.json looked wrong" signal alone. A normal, valid-holder lock
  whose age is within the threshold produces NO output line at all — it is not reap-relevant, and
  reap's output would otherwise fill up with routine non-events on every invocation.

**Output format**:
```
reaped: {lock_dir} task={task_number} session={session_id} operation={operation} age_min={age}
would reap: {lock_dir} task={task_number} session={session_id} operation={operation} age_min={age}
SKIP: {lock_dir} age_min={age} (below {threshold}min reap threshold) (missing/unparseable holder.json; age is the .lock directory's own mtime)
```
followed by a trailing summary line (`reaped N of M lock(s) (threshold Tmin)`,
`would reap N of M lock(s) (threshold Tmin)`, or `no stale locks found (M lock(s) scanned,
threshold Tmin)` when nothing qualified).

**Exit codes**: `0` always, whether or not anything qualified for reaping — reap reports, it
never fails on "nothing to do". `2` on a usage error (an unrecognized argument).

**Never implicit (CONSTRAINT 1)**: `reap` is reachable ONLY via this explicit subcommand. It is
never called from `cmd_acquire`, `cmd_heartbeat`, `cmd_release`, or `cmd_check` — those four
functions are entirely unmodified by this feature except for the additive top-of-file usage
comment. The "never touch the foreign lock" comment inside `cmd_acquire`'s cross-task overlap
scan (see "Cross-Task `file_scope` Overlap Check" above) governs ONLY that scan's read-only
inspection of a FOREIGN task's lock — it says nothing about, and does not conflict with, the
pre-existing same-task stale-override branch inside `cmd_acquire` (documented in the `acquire`
contract above), which legitimately overwrites the ACQUIRING task's own lock. Reap composes with
neither: it is a wholly separate, explicitly-invoked code path from both.

### Threshold Derivation

`TASK_LOCK_REAP_MIN`, default 120 minutes, derived as `TASK_LOCK_STALE_MIN * 4` when not set
directly (so it stays proportionate if a caller raises the base threshold — this proportional
movement is INTENTIONAL, not a bug, and is called out in a code comment at the constant's
declaration so it is not mistaken for one in review).

**Why checkpoint-based reasoning, not a timer interval**: heartbeat refresh in this codebase is
checkpoint-based, not timer-based. `skill-orchestrate` heartbeats once per state-machine cycle;
the implementation agent (`general-implementation-agent`) heartbeats once per phase transition
(see the Phase Checkpoint Protocol in that agent's own definition). A single dispatch — one
long-running phase, or one orchestrate cycle waiting on a slow subagent — can therefore run
unheartbeated for an extended stretch without that stretch indicating anything is actually wrong.
`TASK_LOCK_STALE_MIN` (30-60 min) is already the point at which the system lets a COMPETING
same-task `acquire` steal the lock — an optimistic, single-acquirer-facing threshold. Reap is a
strictly more consequential operation: it runs unattended (no waiting acquirer to catch a false
positive) and is meant to be the FINAL word that a lock is dead, not merely eligible for
override. It therefore sits at a firm multiple above the override threshold, not equal to it.

**CONSTRAINT 5, answered explicitly — the point at which a stale heartbeat stops being
ambiguous**: there are two distinct bands, not one:
- **Override-eligible band**: `heartbeat_at` age past `TASK_LOCK_STALE_MIN` (30-60 min). A
  competing `acquire` for the SAME task number may steal the lock here (see the `acquire`
  contract's "Different `session_id`, stale" branch above) — but this is a live, single-waiter
  decision made at the moment a specific competing session actually wants the lock. It is NOT
  reap-eligible: no unattended sweep should treat this band as "dead" on its own, since the
  original holder may simply be mid-phase with no checkpoint due yet.
- **Reap-eligible band**: `heartbeat_at` (or directory mtime, for a corrupt-holder lock) age past
  `TASK_LOCK_REAP_MIN` (120 min at defaults). Only past this point does an unattended, no-waiter
  process treat the lock as unambiguously dead. This asymmetry — two thresholds, not one — is
  intentional: the override band answers "should THIS competing acquirer be allowed to proceed
  right now", while the reap band answers "should ANY unattended process conclude this lock will
  never be heartbeated again". Collapsing them to one threshold would either make override too
  aggressive (stealing a lock from a session that is merely between checkpoints) or make reap too
  timid (never actually converting the accumulating warning into cleanup).

**Calibration evidence** (durable characteristics, not task numbers — see
`no-task-references-in-deliverables.md`): the two heartbeat ages that originally produced the
repeating `acquire` cross-task overlap `WARN:` lines this feature exists to resolve were on the
order of several hundred minutes past `TASK_LOCK_STALE_MIN`. Separately, three genuinely orphaned
locks under archived task directories — the durable signature being an archived task directory
(no active `file_scope`, no plausible live dispatch) holding a `.lock` at all — were observed at
roughly 430, 17,500, and 18,700 minutes of heartbeat age. Every one of these five data points
clears the 120-minute default by more than 3.5x, which is the empirical basis for treating 120
minutes as a safely conservative reap-eligible floor rather than an arbitrary round number.

### Two Depths, Deliberately Different

`reap`'s sweep uses `-maxdepth 3` (reaching `specs/{NNN}_{slug}/.lock` at depth 2 AND
`specs/archive/{NNN}_{slug}/.lock` at depth 3); `find_held_locks()` (used internally by
`acquire`'s cross-task overlap scan) stays at `-maxdepth 2` and is left byte-identical by this
feature. This is intentional, not an oversight the reaper corrected: an archived task has no
active `file_scope` to overlap with a live `acquire`'s cross-task scan, so widening
`find_held_locks()` to reach the archive would add scan work on every `acquire` call for zero
signal. Reap's own concern — finding every stale lock anywhere under `specs/`, regardless of
whether the owning task is still active — is a genuinely different question from `acquire`'s
concern — finding every OTHER currently-relevant lock a live acquire might conflict with — and
the two functions' depths are allowed to diverge because the questions themselves diverge.

### Correction to This Feature's Originating Constraint

The feature that became `reap` was originally specified to honor "the holder-declared staleness
window written into the lock directory." **No such field exists on the task-number lock.**
Verified directly against `write_holder()` and the schema documented above: `holder.json`
contains exactly `session_id`, `task_number`, `operation`, `acquired_at`, `heartbeat_at`,
`command` — nothing else, and specifically no per-lock staleness value.

The two NAMED mutexes documented above (`.scope-lock`, `.commit-lock`) ARE genuinely
holder-declared in the literal sense — see their respective "Holder-Declared Staleness"
subsections: the successful acquirer writes its own chosen `stale_sec` into the mutex directory,
and every later waiter reads THAT file rather than applying its own default. This is the most
plausible source of the original wording: the pattern is real in this codebase, just not on the
mechanism the constraint named.

**Resolution**: `reap` derives its threshold from `TASK_LOCK_REAP_MIN`, itself proportionally
derived from `TASK_LOCK_STALE_MIN` — the SAME constant every other task-number-lock caller
(`acquire`, `check`) already reads fresh at call time. This preserves the constraint's actual
intent (one shared window every participant honors, not a threshold a fresh caller invents for
itself) through the mechanism that genuinely exists, rather than inventing a `stale_sec` /
`reap_after` field on `holder.json` that would fork the task-number lock's schema away from its
canonical spec to satisfy wording that was mistaken about the code's current state. That
invented field is explicitly out of scope — see the Non-Goals list this document's plan carried.

## Scope-Mutex CLI: `scope-acquire` / `scope-release`

This is a DISTINCT, orthogonal primitive from the task-number `.lock/` mechanism documented
above — it does not lock a task, it locks a critical section of `specs/state.json` writes that
may span MULTIPLE process invocations (e.g. an outer script bracketing several inner scripts'
state.json read-modify-write calls). It reuses `specs/.scope-lock/`, the same global mutex
`acquire`'s cross-task `file_scope` overlap scan already uses internally (see "Cross-Task
`file_scope` Overlap Check" above) — `scope-acquire`/`scope-release` simply expose that existing
internal primitive (`acquire_scope_mutex`/`release_scope_mutex`) as a standalone CLI surface,
rather than introducing a new script or a new lock directory.

A sibling primitive, `commit-acquire`/`commit-release`, serializes a DIFFERENT critical section
(the git add + git commit pair around scoped commits) through a DIFFERENT mutex directory,
`specs/.commit-lock/` — see "Commit-Mutex CLI: `commit-acquire` / `commit-release`" below for the
full contract. Both CLIs share the same underlying `acquire_named_mutex`/`release_named_mutex`
implementation (parameterized by mutex directory name) but are otherwise fully independent:
holding one never blocks or interacts with the other.

### `scope-acquire <session_id> [stale_sec]`

Acquires `specs/.scope-lock/`, writes an owner token (`session_id:pid:epoch`) to
`specs/.scope-lock/owner`, and prints that token on stdout. Exit `0` on success. On contention,
waits out the same bounded retry window `acquire`'s internal mutex use already relies on; on
timeout, exits `2` with a diagnostic naming the current holder (read from `owner`) — fail closed,
never fail open.

### `scope-release <token>`

Releases `specs/.scope-lock/` if, and only if, `<token>` matches the current
`specs/.scope-lock/owner` token. Always exits `0` — release is best-effort and must never fail a
caller's cleanup path. A mismatch (or a release against an already-absent mutex) is a loud,
non-fatal `WARN:` on stderr, never a silent no-op and never a forced removal.

**Caller requirement — install an EXIT trap immediately after a successful `scope-acquire`.**
Unlike `acquire`'s task-number lock (whose exclusivity lives and dies within a single function
call), `scope-acquire`'s mutex is meant to outlive the acquiring call and be released by a later,
separate `scope-release` invocation — so `scope-acquire` deliberately does not install any trap
of its own. This means the CALLER is responsible for guaranteeing release on every exit path
(normal completion, an early `return`/`exit`, or a `set -e` abort partway through the critical
section): install `trap 'bash .claude/scripts/task-lock.sh scope-release "$token"' EXIT`
immediately after a successful acquire, and explicitly release-and-clear-the-trap at the natural
end of the critical section so the mutex is not held for the remainder of the script's
unserialized tail. A script that already has its own EXIT trap for other cleanup (e.g.
`orchestrator-postflight.sh`'s Stage 7-8a bracket) may instead extend that trap to also call
release, provided the release call itself is idempotent against being invoked twice (guard it
behind an "did I acquire and not yet release" flag) — both approaches are used by this
primitive's reference consumers below. `scripts/state-write.sh` is the canonical example of the
first approach (a fresh, dedicated EXIT trap installed immediately after acquire); see its own
header comment.

### Reentrancy: `SCOPE_MUTEX_HELD` Is the Sanctioned Way to Nest

The `specs/.scope-lock/` mutex is **NOT reentrant**. A process that already holds it — or is
running as a guest inside an outer holder's critical section — MUST NOT attempt a second
`scope-acquire`: the `mkdir` underneath would simply fail, and the process would wait out the
full contention window before warning and proceeding unserialized (best case), or deadlock if the
inner acquire happens inside the SAME process/call chain that already holds the mutex (worst
case, and the reason this guard exists at all). The sanctioned pattern for a script that may run
either standalone or nested inside an outer holder's critical section: the outer holder exports
`SCOPE_MUTEX_HELD=1` before invoking the inner script (environment variables propagate to child
processes, so this requires no separate lock-accounting mechanism); the inner script checks for
that variable and skips BOTH `scope-acquire` and `scope-release` entirely when it is already set,
logging a brief note that an outer holder owns the section. `.claude/scripts/update-task-status.sh`
and `.claude/scripts/orchestrator-postflight.sh` are the reference implementation of this pattern
(see "Consumers" below): postflight's Stage 7 shells out to `update-task-status.sh`, which would
otherwise attempt its own nested acquire on every single postflight run.

### Holder-Declared Staleness

Unlike `acquire`'s internal use of `acquire_scope_mutex` (which always relies on the default
`SCOPE_MUTEX_STALE_SEC` of 10 seconds, appropriate for a fast scan-then-mkdir sequence),
`scope-acquire` accepts an optional `stale_sec` argument for callers whose critical section is
knowingly longer-running. Staleness is **holder-declared, not waiter-declared**: the successful
acquirer writes its own chosen `stale_sec` into `specs/.scope-lock/stale_sec` alongside
`claimed_at`, and EVERY waiter — including a waiter carrying a different or default `stale_sec`
of its own — reads that file when deciding whether to reclaim the mutex as stale. This is
deliberate: if staleness were evaluated by the waiter against its own constant instead, a
short-window waiter could reclaim a still-live, longer-running holder's mutex out from under it,
producing two simultaneous live holders — the exact lost-update this primitive exists to prevent,
now harder to diagnose because it would appear as a `mkdir` succeeding cleanly rather than as a
refusal. When no `stale_sec` is passed (or an unparseable one is), the default
`SCOPE_MUTEX_STALE_SEC` (10) governs, which is why `acquire`'s pre-existing internal call site
(which passes no argument) is unaffected by this change.

### Owner-Token-Verified Release

Because `scope-acquire` and `scope-release` are separate process invocations (unlike
`acquire_scope_mutex`'s task-number-lock use, which acquires and releases within a single
function's lifetime), an unconditional `rm -rf` on release would be unsafe: if the holder was
stale-reclaimed by a waiter and a NEW holder acquired in the interim, the original holder's
release would delete the new holder's mutex out from under it. `scope-acquire` writes the owner
token described above; `scope-release <token>` compares its argument against that file and only
removes the mutex on an exact match, as described above.

### Consumers

- `.claude/scripts/state-write.sh` is the single mutex-guarded `specs/state.json` writer every
  other writer in this codebase now calls through (see its own header comment for the full
  acquire -> mktemp -> jq transform -> jq empty validate -> mv -> optional in-mutex TODO.md
  regen -> release sequence). It acquires and releases the scope mutex itself on every
  invocation, fail-CLOSED on a timeout (an `ABORT:`-prefixed exit rather than proceeding
  unserialized), and skips acquire/release entirely (guest mode) when `SCOPE_MUTEX_HELD` is
  already set by an outer holder.
- `.claude/scripts/update-task-status.sh` no longer brackets its own mutex directly — its single
  `specs/state.json` write (plus TODO.md regen, via `state-write.sh --regen-todo`) delegates
  entirely to `state-write.sh` above, inheriting guest mode transparently when invoked as a
  child of an outer holder (e.g. `orchestrator-postflight.sh`'s Stage 7).
- `.claude/scripts/orchestrator-postflight.sh` acquires the mutex immediately before its Stage 7
  (update task status), with a generous, holder-declared `stale_sec` sized to the measured
  worst-case wall-clock time of Stages 7 through 8a; exports `SCOPE_MUTEX_HELD=1` so every write
  in Stages 7-8 (each now a `state-write.sh` call) inherits the guard above instead of
  self-deadlocking; and releases explicitly at the close of Stage 8a (TODO.md regeneration). On
  a bracket-acquire timeout, `SCOPE_MUTEX_HELD` is left unexported and each write stage instead
  falls through to `state-write.sh`'s own independent fail-closed acquire -- graceful
  degradation rather than the fail-open "proceed unserialized" this script used to log. The TTS
  notification, git commit, and cleanup stages that follow run OUTSIDE the mutex — see
  `.claude/context/standards/git-staging-scope.md`'s state-write hazard note for why the boundary
  stops there.

### State-Write Convention

Every `specs/state.json` writer in this codebase is a call to `scripts/state-write.sh`. There is
no other sanctioned way to write `specs/state.json`, `specs/archive/state.json`, or a vault-root
`state.json`: not a hand-rolled `jq ... > tmp && mv` sequence, not a `python3
json.load`/`json.dump` in-place write, and not a direct `acquire_scope_mutex` call from a new
script. A new writer should call `state-write.sh` with its jq filter and any `--arg`/`--argjson`
bindings, exactly as the existing consumers above do, rather than reimplementing the acquire ->
mktemp -> transform -> validate -> mv -> release sequence inline. This closes two independent
corruption channels that used to exist in this codebase: (1) most writers never acquired the
`.scope-lock` mutex at all, and the two that did failed OPEN on a timeout (proceeded unserialized
rather than refusing); (2) several writers staged through a FIXED, shared temp path
(`specs/tmp/state.json`, or the literal `specs/state.json.tmp`) with an unconditional `rm -f`
EXIT trap, so one process's normal exit could delete another concurrent process's in-flight
staging file regardless of any mutex work. `state-write.sh` closes both: fail-closed mutex
acquisition, and a private per-process `mktemp` staging path with an EXIT trap scoped to that
process's own file only. See `scripts/test-state-write-concurrency.sh` for the isolated-temp-root
suite proving both properties (no-lost-update, staging-file isolation) plus fail-closed-acquire,
guest-mode-reentrancy, cross-target single-mutex serialization, `--init` fresh-create semantics,
and the `--regen-todo`/`--init` usage refusals below.

**`--state-file` and `--init`: archive and vault targets are covered too.** `state-write.sh`
takes an optional `--state-file <path>` (default `specs/state.json`, so every pre-existing caller
is unchanged) and an `--init` flag for fresh-create targets that have no existing file to
transform. Both `specs/archive/state.json` and vault-root `state.json` writers in
`commands/task.md`, `commands/todo.md`, `skills/skill-todo/SKILL.md`, and the (now-quarantined,
under `scripts/deprecated/`) archive-task and vault-operation scripts now route through these two
flags rather than hand-rolling their own `jq ... > tmp && mv` or `jq -n ... > file` sequences.

- **Single mutex, not per-file (D2)**: `--state-file` parameterizes only the internal
  `STATE_FILE` target -- the `specs/.scope-lock` mutex acquired via `task-lock.sh
  scope-acquire`/`scope-release` stays single and unparameterized across every target, archive
  and vault included. This is a deliberate choice, not an oversight: `commands/task.md`'s recover
  flow does an archive removal immediately followed by a live-state insert in the same logical
  operation, and its abandon flow does the mirror image (live-state extract, archive add,
  live-state remove). Under per-file locks, two concurrent sessions doing opposite operations
  could acquire in opposite order and deadlock (classic ABBA). A single lock name makes every
  acquire/release pair sequential and never nested regardless of target, so the deadlock is
  impossible by construction. The cost -- archive/vault writers serializing against live-state
  writers -- is negligible: these are rare, human/agent-paced operations that already serialize
  against each other in practice.
- **`--init` semantics (D3)**: skips the "target must already exist" precondition and runs `jq -n
  "${JQ_ARGS[@]}" "$JQ_FILTER"` (null input) instead of transforming an existing file --
  `--arg`/`--argjson` passthrough is unchanged. It overwrites an existing target, but never
  silently: a named stderr note ("Note: --init is replacing an existing <path>") is emitted first.
  `--init` REFUSES to run (exit 1) against the default live path -- either with no `--state-file`
  at all, or with a `--state-file` that `realpath -m`-normalizes to the same path as the default
  -- as a cheap, loud guard against a filter typo destroying live task state. `--init` is for
  archive and vault targets only.
- **`--regen-todo` refusal (D4)**: `generate-todo.sh` regenerates `specs/TODO.md` from
  `specs/state.json` unconditionally, so running it after an archive or vault write would render
  a view of a file that was not the one just written. `--regen-todo` together with a
  `--state-file` that does not `realpath -m`-normalize to the default path is a hard usage error
  (exit 1), naming both paths; `--init` combined with `--regen-todo` is likewise a hard usage
  error (unreachable given the default-path refusal above, but asserted explicitly so the
  combination can never become reachable through a later edit alone). Path comparison is always
  `realpath -m`-normalized, never a raw string compare, so `./specs/state.json`,
  `specs/state.json`, and an absolute `$PROJECT_ROOT/specs/state.json` all correctly compare
  equal to the default.

**Known residual surface (re-measured for this section; the numbers below are a point-in-time
grep result, not a permanent fact -- re-run the same searches before trusting them again):**

- Every `specs/state.json` writer in `agent-system/extensions/core/**` now routes through
  `state-write.sh`. The 11 skill files this note previously listed as still carrying hand-rolled
  write blocks (the three base lifecycle skills -- `skill-project-overview`,
  `skill-reviser`, `skill-spawn`, `skill-status-sync`, `skill-todo`, and core's own three
  standalone hard-mode research/plan/implement skills -- all six of these since deleted outright,
  not merely fixed) each show zero hand-rolled hits today and the survivors call
  `state-write.sh` instead -- that claim was stale; a separate, already-completed effort had
  closed it before this section's own `--state-file`/`--init` work began. `commands/task.md` and
  `commands/todo.md` likewise carry zero hand-rolled `specs/state.json` or
  `specs/archive/state.json` write sites now (re-measured via
  `grep -rnE 'state\.json[^ ]* *> *[^ ]*(tmp|\.tmp)|(tmp|state\.json\.tmp)[^|]*&&[^|]*mv[^|]*state\.json'
  --include='*.md' --include='*.sh' agent-system/extensions/core/`, restricted to matches outside
  `state-write.sh` itself, `specs/reviews/state.json`, and non-`specs/state.json` illustrative
  fixtures).
- `specs/archive/state.json` and vault-root targets are now covered via `--state-file`, and
  fresh-creates via `--init` (see above); the two previously-orphaned (now-quarantined,
  under `scripts/deprecated/`) archive-task and vault-operation scripts are converted as well,
  including the vault-operation script's two former live-`specs/state.json` writes that carried
  zero mutex protection at all.
- The remaining surface is the non-core extension domains -- re-measured at 115 hand-rolled
  `specs/state.json` write sites across 50 files under `agent-system/extensions/` outside
  `core/` (`cslib`, `epidemiology`, `founder`, `lean`, `present`, `web`) via the same grep pattern
  above -- plus `commands/review.md`'s `specs/reviews/state.json` (a genuinely different state
  file, 3 sites: one fresh-create and two `tmp && mv` transforms), now mechanically convertible
  via `--state-file` and left as named follow-up. Neither is a silently-accepted gap: both are
  named here and in the task that did this re-measurement.

### Relationship to the Task-Number Lock

As the "Related Documentation" cross-reference below already notes, the task-number `.lock/`
mechanism "does not change checkpoint behavior" — it only adds cross-session exclusivity around a
single task's working tree. The scope mutex documented in this section is a genuinely distinct,
orthogonal primitive: it protects the SHARED `specs/state.json` (and, transitively,
`specs/TODO.md`) write path that every task's postflight touches, regardless of which
task-number lock — if any — is held at the time. A session can hold its own task-number lock
while contending with another session for the scope mutex, and vice versa: the two mechanisms
compose independently, and neither substitutes for the other.

## Commit-Mutex CLI: `commit-acquire` / `commit-release`

A sibling standalone CLI to the Scope-Mutex CLI above, serializing a DIFFERENT critical section
through a DIFFERENT mutex directory: the `git add` + `git commit` pair around a scoped commit
(`specs/.commit-lock/`, versus the scope mutex's `specs/.scope-lock/` and the state.json
read-modify-write window it protects). `scripts/git-commit-scoped.sh` is the sole intended caller
— it is the single sanctioned implementation of scoped, serialized commits described in
`context/standards/git-staging-scope.md`'s "Commit-Level Path Scoping and Cross-Process
Serialization" section, and every commit site in the dispatch pipeline invokes it rather than
acquiring this mutex directly.

### Why a Distinct Mutex Directory, Not a Reuse of `.scope-lock`

The decisive reason is a reentrancy-flag collision, not merely call-frequency (though frequency
differs by an order of magnitude too: per-objective commits vs. per-postflight state writes,
which would make every state write queue behind unrelated commits under `MAX_TASKS=8` if the two
were coupled). `SCOPE_MUTEX_HELD=1` is a single global env flag meaning "an outer holder already
owns *the* scope mutex," and `update-task-status.sh`'s `acquire_state_mutex` skips its own
acquire when it sees that flag. If commit serialization shared `specs/.scope-lock/`, a commit
executed inside any window where `SCOPE_MUTEX_HELD` is already exported would either (a) honor
the flag and run **unserialized** — silently defeating the fix — or (b) ignore it and attempt a
nested acquire on a documented **non-reentrant** mutex. Two independent critical sections need two
independent held-flags, and two held-flags require two mutex directories regardless of frequency.

Reusing `.scope-lock` for commits would also **invert a deliberate, documented invariant**:
`orchestrator-postflight.sh` explicitly releases the scope mutex *before* Stage 9 (git commit),
and `git-staging-scope.md`'s "State-Write Serialization and Honest Commit Messages" section states
that Stage 9 stays outside the state-write mutex. Reusing `.scope-lock` for commits would make
Stage 9 acquire the exact mutex those documents say it must not — silently replacing a stated
invariant with its negation. A distinct mutex (`.commit-lock`) lets both statements stay true
simultaneously: Stage 9 is outside the **state-write** mutex and inside the **commit** mutex.

### `commit-acquire <session_id> [stale_sec]`

Acquires `specs/.commit-lock/`, writes an owner token (`session_id:pid:epoch`) to
`specs/.commit-lock/owner`, and prints that token on stdout. Exit `0` on success. On contention,
waits out a **15-second** acquire budget — three times the scope mutex's 5 seconds, sized for
`MAX_TASKS=8` concurrent committers rather than a single fast scan-then-mkdir sequence — then
exits `2` with a diagnostic naming the current holder (read from `owner`).

Unlike the scope mutex's fail-CLOSED contract, `git-commit-scoped.sh` (the sole intended caller)
treats a `commit-acquire` timeout as **fail-OPEN**: it logs a loud warning and proceeds with the
commit unserialized rather than aborting. This is safe specifically because the commit is still
path-scoped — the worst case on fail-open is the safe `index.lock` race (one commit fails, retried
once, or simply fails non-blockingly), never commit misattribution. This is now the ONLY
deliberately fail-open mutex acquisition remaining in this family: every `specs/state.json`
writer routes through `scripts/state-write.sh`, which is uniformly fail-CLOSED (see
"State-Write Convention" below) — the scope mutex no longer has a fail-open wrapper of its own
to mirror (the former `update-task-status.sh` `acquire_state_mutex` wrapper this sentence used
to reference has been deleted; see `scripts/state-write.sh`'s header comment for the fail-closed
replacement).

### `commit-release <token>`

Releases `specs/.commit-lock/` if, and only if, `<token>` matches the current
`specs/.commit-lock/owner` token — identical owner-token-verified contract to `scope-release`
(see above). Always exits `0`; a mismatch is a loud, non-fatal `WARN:` on stderr, never a silent
no-op and never a forced removal.

### `COMMIT_MUTEX_HELD`: the Distinct Reentrancy Flag

Exported by `git-commit-scoped.sh` immediately after a successful `commit-acquire`, and checked
before attempting one — a script that already holds `.commit-lock` (or is running as a guest
inside an outer holder's critical section) skips its own acquire/release when it sees
`COMMIT_MUTEX_HELD=1` already set. This is the commit-mutex mirror of `SCOPE_MUTEX_HELD`
documented above, and the two flags are never interchangeable — see "Why a Distinct Mutex
Directory" above for the collision this independence prevents.

### Holder-Declared Staleness

`COMMIT_MUTEX_STALE_SEC=30`, declared by the acquiring process into
`specs/.commit-lock/stale_sec` exactly as the scope mutex declares its own staleness window (see
"Holder-Declared Staleness" above) — every waiter, regardless of its own default, honors the
holder's declared window. 30 seconds is generous against measured sub-second commits but short
enough to reclaim a genuinely stuck holder.

### Consumers

- `scripts/git-commit-scoped.sh` — the sole intended caller. Acquires immediately before its
  `git add` + optional honest-index-rows scan + `git commit` sequence, releases via an `EXIT`
  trap so no code path leaks the mutex.

## Session-Registry CLI: `session-register` / `session-heartbeat` / `session-release` / `session-reap`

A THIRD standalone CLI family, alongside the Scope-Mutex CLI and Commit-Mutex CLI above, but
serving a genuinely different purpose from either: it is not a mutex at all. It records which
orchestration **sessions** (not tasks, not critical sections) are actually in flight, at
`specs/.sessions/{session_id}.json`. Ships as four additive subcommands on this same
`task-lock.sh`, reusing `write_holder`'s tmp-file-`mv` atomicity pattern (as `write_session_entry`),
`iso_now`/`now_epoch`/`age_minutes`, `get_file_scope`, and `cmd_reap`'s report-then-delete shape —
no new script, no new mutex directory.

### Session-Registry Reader Contract

The registry now has exactly ONE reader SHAPE: `session-list` (below), a read-only, no-mutation
NDJSON enumeration. This section previously stated a "no reader exists" non-goal; that statement
is no longer true and would leave this document self-contradicted if left standing —
`session-list` was added specifically to give the conflict-detection predicate (see
`context/patterns/file-footprint-overlap.md`'s "Session-Registry application" bullet and "Three
Contention Inputs" section) a live signal over which sessions are actually in flight.

`session-list` itself carries NO exclusion logic of its own — it computes and reports
`live`/`liveness_reason` per entry (via `session_liveness()`, the SAME two-signal computation
`session-reap` uses, factored into a shared function so both consumers see an identical
liveness verdict) and nothing more. Every CONSUMER of `session-list`'s NDJSON applies its OWN
exclusion rules on top:

- **`task-lock.sh`'s own `cmd_acquire`** calls `cmd_session_list` directly (same process, no
  subprocess) and evaluates `session_contention()` (from `lib/file-scope-overlap.sh`) against it,
  applying D4's three exclusions (self-session-id, liveness, per-covered-task-number
  dependency-edge) from the acquiring task's perspective.
- **`orchestrate-batch-admit.sh`** subprocess-calls `task-lock.sh session-list` once (only when
  `--session-id` is supplied — see that script's D6 degradation contract) and evaluates the SAME
  `session_contention()` from each candidate's perspective.

Both consumers apply the identical shared exclusion logic (`session_contention()`,
`edge_connected_nums()`) rather than each deriving its own — this is the same "single physical
implementation, spliced by every consumer" shape the base overlap predicate already uses. Neither
consumer mutates the registry; `session-list` and its callers are read-only end to end. A future
THIRD reader must still add its own freshness/ownership judgment (whether `live == true` matters
to it, how it treats `corrupt`/`undeterminable`) rather than assuming `session-list`'s bare output
already encodes the right policy for every use case — `live`/`liveness_reason` are DATA, not a
pre-baked admission decision.

### `session-list`

Read-only enumeration of `specs/.sessions/*.json` — a bounded, dedicated-directory glob, never a
repo-wide scan. No `--dry-run` flag (nothing here is ever deleted). Emits one compact NDJSON line
per entry: every raw entry field verbatim, plus computed `live` (bool) and `liveness_reason`
(string) from `session_liveness()`. `live` is derived uniformly as `liveness_reason NOT IN
{dead-pid, stale-heartbeat}` — true for `pid-alive`, `dead-pid-within-grace`, `corrupt`, AND
`undeterminable`, matching D4's "`live == true`, `corrupt`, and undeterminable-liveness entries DO
contend" language exactly.
A corrupt/unparseable entry is emitted with `liveness_reason: "corrupt"`, `live: true`, and empty
`file_scope`/`task_numbers` (nothing can be safely read from it) — never silently dropped from the
stream.

### Entry Schema

```json
{
  "session_id": "sess_1736700000_a1b2c3",
  "pid": 261744,
  "pid_source": "ancestor-claude",
  "command": "/implement 944",
  "task_numbers": [944],
  "file_scope": ["agent-system/extensions/core/scripts/task-lock.sh"],
  "started_at": "2026-07-04T18:07:17Z",
  "heartbeat_at": "2026-07-04T18:12:40Z"
}
```

| Field | Type | Description |
|-------|------|--------------|
| `session_id` | string | The registering session's ID (`sess_{timestamp}_{hex}`) |
| `pid` | integer | Resolved via `resolve_session_pid()` (see below) |
| `pid_source` | string | `ancestor-claude` \| `ppid` \| `self` \| `explicit` — how `pid` was resolved |
| `command` | string | The invoking command string, for diagnostics |
| `task_numbers` | array of integers | Every task this session covers (one for a single-task session, N for a batch) |
| `file_scope` | array of strings | The deduplicated UNION of every task's declared `file_scope`, computed internally by `session-register` |
| `started_at` | string (ISO8601) | When the session was first registered (preserved across heartbeats and re-registrations) |
| `heartbeat_at` | string (ISO8601) | Last refresh; staleness is computed from this field |

### Why No `mkdir` Exclusivity Gate

Unlike the task-number `.lock/` mechanism above, `session-register` writes ONLY its own
globally-unique-id'd file (`specs/.sessions/{session_id}.json` — `session_id` is generated fresh
per session by the caller, so no two sessions ever contend for the same target path). There is
therefore no cross-session exclusivity to protect: `write_session_entry()`'s tmp-file-`mv`
atomicity alone is sufficient to guarantee a concurrent `session-reap` sweep never observes a
half-written entry. Adopting `init-marker`'s claim-and-recheck pattern here would add exclusivity
machinery for a race that cannot occur.

### `resolve_session_pid()`

The recorded `pid` is NOT `$$` inside `task-lock.sh` — `$$` there is this short-lived helper
script's own pid, not the long-lived session process, which would make every registered entry
look instantly dead. `resolve_session_pid()` instead performs a bounded ancestor walk (at most 10
hops, stopping at pid 1) from `$$` upward, looking for a process whose command name contains
`claude`. Fallback order: `ancestor-claude` (the walk found one) -> `ppid` (walk exhausted, fall
back to the immediate parent) -> `self` (even `ppid` unavailable). An explicit `--pid N` argument
to `session-register` overrides the walk entirely and records `pid_source=explicit`.

### `session-register <session_id> <command> <task_numbers_csv> [--pid N]`

Upsert semantics: if an entry for this `session_id` already exists and parses, `started_at` is
preserved and `heartbeat_at` is refreshed — mirroring `acquire`'s same-session re-entry safety
property. `file_scope` is computed internally as the deduplicated UNION across every task number
in `task_numbers_csv`, calling the existing `get_file_scope` once per task and merging with
`jq -s 'add | unique'` — callers never construct the union themselves. Creates
`specs/.sessions/` with `mkdir -p` if absent (creation is confined to `session-register`, mirroring
`resolve_task_dir`'s `create_mode` confinement to `cmd_acquire`).

### `session-heartbeat <session_id>`

Refreshes `heartbeat_at` only, via the same tmp-mv write. Mirrors `heartbeat`'s contract exactly:
a missing or unparseable entry is a stderr `WARN:` and exit 0 — `session-heartbeat` never blocks
the caller, matching `heartbeat`'s own "best-effort refresh at existing checkpoints, not a gate"
character.

### `session-release <session_id>`

`rm -f` the entry; idempotent, always exit 0, mirroring `release`.

### `session_liveness()`: the shared two-signal computation

Both `session-reap` and `session-list` (and, transitively, `session_contention()`'s D4 liveness
exclusion) consume ONE shared bash function, `session_liveness()`, rather than each computing the
two-signal staleness rule independently. Given an entry file path, it prints `"<age_minutes>
<liveness_reason>"`, where `liveness_reason` is one of:

- **`corrupt`** — entry file is missing/unparseable JSON. `age` falls back to the file's own
  mtime. Checked FIRST and short-circuits the other five — an unparseable entry's `pid`/
  `heartbeat_at` fields cannot be trusted at all.
- **`dead-pid`** — `pid` is a parseable integer, `kill -0 $pid` FAILS, AND `age` exceeds
  `SESSION_REGISTRY_DEAD_PID_MIN`.
- **`dead-pid-within-grace`** — `pid` is a parseable integer, `kill -0 $pid` FAILS (pid
  confirmably gone), and `age` does NOT exceed `SESSION_REGISTRY_DEAD_PID_MIN` — the grace floor
  holds the verdict at `live: true`, but the reason no longer claims the process is alive.
- **`stale-heartbeat`** — not `dead-pid`, and `age` exceeds `SESSION_REGISTRY_REAP_MIN`.
  "pid alive" is NEVER treated as proof of liveness on its own; this band is always the fallback
  regardless of pid state.
- **`pid-alive`** — not `dead-pid`, not `dead-pid-within-grace`, not `stale-heartbeat`, and `pid`
  is a parseable integer for which `kill -0` succeeded.
- **`undeterminable`** — not `dead-pid`, not `dead-pid-within-grace`, not `stale-heartbeat`, and
  `pid` is empty/non-numeric (liveness cannot be confirmed either way from the pid signal alone).

`pid-alive`, `dead-pid-within-grace`, and `undeterminable` are states `session-reap` alone never
needed to distinguish (all three simply mean "do not reap") — they exist because
`session-list`/`session_contention()` need a liveness verdict for EVERY entry, not just
reap-worthy ones.

### `session-reap [--dry-run]`

Mirrors `reap`'s report-then-delete shape and its "skip corrupt/unreadable entry rather than
silently ignore" discipline, now expressed via `session_liveness()` above rather than computed
inline. **Two-signal staleness**, evaluated in this order:

1. **`dead-pid`**: `kill -0 "$pid" 2>/dev/null` FAILS (the pid is confirmably gone — the same
   idiom already used by `claude-refresh.sh`) AND `heartbeat_at` age exceeds
   `SESSION_REGISTRY_DEAD_PID_MIN`. Reap with reason `dead-pid`.
2. **`stale-heartbeat`**: otherwise (the pid is alive, liveness is undeterminable — e.g. `pid` is
   missing or non-numeric — or the pid is confirmably dead but still within the
   `SESSION_REGISTRY_DEAD_PID_MIN` grace floor), fall through to `heartbeat_at` age exceeding
   `SESSION_REGISTRY_REAP_MIN`. Reap with reason `stale-heartbeat`.

**`kill -0` succeeding is NEVER treated as proof of liveness** — it only prevents the dead-pid
shortcut from firing; the stale-heartbeat band is always the eventual fallback, exactly as `kill
-0` is a same-host-only signal (cross-host liveness is an explicit Non-Goal — see the plan's
Non-Goals list). An entry with a missing/unparseable body falls back to the file's own mtime,
exactly as `reap` falls back to the `.lock` directory mtime, and is reported via a `SKIP:` or
`reaped:`/`would reap:` line rather than silently ignored. Always exits 0.

### Threshold Constants

- `SESSION_REGISTRY_REAP_MIN` (default 240 minutes / 4 hours) — deliberately NOT derived from
  `TASK_LOCK_REAP_MIN`, for the same reason `ORCHESTRATOR_SESSION_REAP_MIN`
  (`reap-session-runtime-files.sh`) is not: a batch orchestration session can legitimately run far
  longer than any single task's lock window (up to `MAX_CYCLES_MT = min(task_count * 5, 25)`
  cycles). Matches `ORCHESTRATOR_SESSION_REAP_MIN`'s own default, since both bound the same class
  of "batch session, not single task" runtime.
- `SESSION_REGISTRY_DEAD_PID_MIN` (default 10 minutes) — the floor below which the dead-pid
  shortcut never fires. `resolve_session_pid()`'s ancestor walk can, in principle, resolve to the
  wrong pid (a misresolved or since-reused pid); this floor guards against that: even a bogus pid
  can only ever shorten the wait down to this floor, never reap a genuinely live, recently
  heartbeated session. This is what makes a `ppid`/`self` `pid_source` fallback an acceptable
  outcome rather than a safety hole.

### Never Implicit

`session-reap` is reachable ONLY via this explicit subcommand — never called from
`session-register`, `session-heartbeat`, or `session-release`, mirroring `reap`'s own "never
implicit" contract for the task-number lock family.

## Four-Tier Conflict Response

When two sessions' work collides — the same task number, or two different tasks whose
`file_scope` overlaps — the system responds through exactly four tiers, in strict priority order.
Each tier is tried only after the one before it has been exhausted or found structurally
inapplicable; the ladder never skips a tier that IS reachable for the calling context.

| Tier | Name | Mechanism | Where it lives |
|------|------|-----------|-----------------|
| 1 | Auto-sequence | Re-sequence the colliding work into a later pass/cycle with no user interaction at all | `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (cross-cycle, `/orchestrate` only); `commands/research.md`/`plan.md`/`implement.md` Step 2.5 → Step 3.5 (bounded two-pass, plain multi-task commands) |
| 2 | Bounded retry | Wait up to a short, seconds-scale budget, polling for the lock to release, before falling through | `task-lock.sh acquire-retry` (see the Contract section above) |
| 3 | Warn | ABORT with a two-line refusal message naming the holder/collision and the remedy; the caller must re-run manually | `cmd_acquire`'s three ABORT variants (see "The ABORT Refusal Message" below) — unchanged, wrapped by Tier 2 |
| 4 | Ask | Present the user an interactive choice (wait longer / skip / print the manual override) | The shared block in "Tier 4: The Ask Flow" below, wired into the three single-task command paths |

**Which tiers are structurally inapplicable where:**

- **Tier 1 has no meaning for a single-task invocation run in isolation** — auto-sequencing
  presupposes another task's work that the SAME invocation will itself finish (an in-batch
  collision, or a later `/orchestrate` cycle). A solo `/research 42` has no batch or cycle to
  re-sequence into, so Tier 1 is simply never reached for it — Tier 2 is the first tier a
  single-task invocation's collision can hit.
- **Tier 4 has no meaning under `orchestrator_mode: true`** — no human is available to answer an
  `AskUserQuestion` prompt during autonomous `/orchestrate` dispatch, so the warn tier (Tier 3) is
  the autonomous terminus; see "Tier 4: The Ask Flow"'s `orchestrator_mode` branch and its
  "Deliberately Not Wired" subsection for the full reachability contract.
- **Tiers 2 and 3 are universal** — every `acquire`/`acquire-retry` call site, single-task or
  multi-task, autonomous or interactive, passes through the bounded retry and (on exhaustion) the
  warn tier; only Tiers 1 and 4 are context-gated.

## The ABORT Refusal Message

Modeled on the established two-line `ABORT:` + remedy shape already used by
`command-gate-in.sh`'s terminal-status guard and `guard-destructive-git.sh`'s blocked-command
message:

```
ABORT: Task {N} is locked by session {holder_session} (heartbeat {age} min ago; stale threshold {threshold} min).
  Wait for the lock to go stale, or override manually: rm -rf "{lock_dir}"
```

Naming the holding session, the heartbeat age, the threshold, and the manual `rm -rf` remedy in
one place means a blocked caller always has an actionable next step without needing to inspect
`holder.json` by hand.

The cross-task `file_scope` overlap ABORT follows the same two-line shape, naming the
OTHER task instead of a same-numbered holder, plus the overlapping path:

```
ABORT: Task {N}'s file_scope overlaps task {other_task}'s file_scope at "{overlap_path}" and task {other_task} is locked by session {other_session} (heartbeat {age} min ago; stale threshold {threshold} min).
  Wait for task {other_task}'s lock to go stale, or coordinate with that session before retrying.
```

## Tier 4: The Ask Flow (`orchestrator_mode`-Gated)

The last-resort tier of the four-tier conflict-response ladder (auto-sequence, bounded retry,
warn, ask — see this document's "Four-Tier Conflict Response" section above for the full ladder).
Reachable ONLY where a human actually exists to answer: a direct single-task `/research`,
`/plan`, or `/implement` invocation whose CHECKPOINT 1 GATE IN step (`command-gate-in.sh`) has
just failed the acquire-retry call (Tier 2 exhausted, Tier 3's ABORT text already emitted). This
is the SINGLE canonical Tier-4 block; `commands/research.md`, `commands/plan.md`, and
`commands/implement.md` all reference it by pointer immediately after their `source
.claude/scripts/command-gate-in.sh` failure branch rather than restating it — the same
single-source-of-truth shape `context/patterns/lit-stage4a-flow.md` established for `--lit`'s
Stage 4a, and this block's `orchestrator_mode` branch is modeled directly on that document's
`AUTONOMOUS_GLOBAL` case.

**Why Tier 4 cannot live in `command-gate-in.sh`**: `command-gate-in.sh` is a bash script, and
`AskUserQuestion` is a tool call available only to the agent executing a command's markdown
instructions — a bash script has no way to invoke it. `command-gate-in.sh` therefore keeps
returning 1 exactly as it does today when `acquire-retry` refuses; the ask tier is layered on top
of that failure by the SOURCING COMMAND's own markdown, never inside the sourced script.

### Preconditions (variables the sourcing command already has in scope)

- The captured stderr from the failed `command-gate-in.sh` call — this already carries every
  field the Tier-3 ABORT message names (holding session or, for the cross-task variants, the
  colliding task, overlapping path, and either heartbeat age or session liveness reason).
- `orchestrator_mode` — value of the `orchestrator_mode` field from the delegation context this
  command instance received (present when dispatched by `/orchestrate` or `/orchestrate --hard`;
  absent/unset for a direct invocation). Default to `"false"` when unset, exactly as
  `lit-stage4a-flow.md` does for its own `orchestrator_mode` precondition.

### Branch on `orchestrator_mode`

**`orchestrator_mode == "true"` (autonomous — `/orchestrate` dispatching a single-task
sub-operation)**: **MUST NOT** call `AskUserQuestion` — no human is available to prompt. The warn
tier (Tier 3) is the autonomous terminus. Emit a distinctly-prefixed notice and defer/skip the
task for this invocation, exactly as `lit-stage4a-flow.md`'s `AUTONOMOUS_GLOBAL` branch emits
`[lit:auto]` instead of prompting:

```
echo "[conflict:auto] Task acquire refused after the bounded retry budget; autonomous context (orchestrator_mode=true) — no human available to ask, so the warn tier (Tier 3) is the terminus for this invocation. Deferring/skipping this task rather than prompting." >&2
```

**`orchestrator_mode != "true"` (interactive — a direct `/research`, `/plan`, or `/implement`
invocation)**: present the real question via `AskUserQuestion`.

### The Interactive Question

Surface the SAME fields the Tier-3 ABORT text already carries — never re-derive them, quote the
captured stderr's holding-session-or-colliding-task identity, overlapping path (cross-task
variants only), and heartbeat age or session liveness reason — plus exactly three choices:

1. **Wait longer** — run ONE additional bounded retry budget (`task-lock.sh acquire-retry` again,
   same budget/poll constants as Tier 2). This is a deliberate, user-authorized SECOND bounded
   wait, distinct from Tier 2's own automatic first attempt; it is never automatic and never
   repeats beyond this one extra round without the user choosing it again.
2. **Skip this task this invocation** — the user declines to wait; the command reports this task
   as skipped/refused and exits its single-task flow, exactly as an unanswered Tier-3 ABORT does
   today.
3. **Override manually** — print the EXACT remedy the Tier-3 ABORT text already names
   (`rm -rf "{lock_dir}"` for the own-task variant; the equivalent coordinate-with-that-session
   guidance for the cross-task variants, which have no lock of their own to remove). This tool
   **NEVER** performs the removal on the user's behalf — it only prints the command for the user
   to run themselves, identically to how the ABORT message has always presented it as manual
   guidance, never an automated action.

### Non-Silence Invariant

Every branch above either asks the user a real question (interactive) or emits a visibly-logged
`[conflict:auto]` notice explaining why it did not ask (autonomous). No branch silently retries
forever, silently overrides the lock, and no branch silently skips without a logged reason —
mirroring `lit-stage4a-flow.md`'s own Non-Silence Invariant for `--lit`.

### Deliberately Not Wired

`/orchestrate`, `/revise`, and `/task` do NOT reference this Tier-4 block. This is a recorded
decision, not an omission:

- **`/orchestrate`** has zero synchronous confirmation gates by design — its entire purpose is
  autonomous, unattended lifecycle progression, so it always runs with `orchestrator_mode: true`
  for every dispatch it makes, which structurally routes any conflict it hits to this same
  block's autonomous branch anyway (see `context/patterns/lit-stage4a-flow.md`'s
  `orchestrator_mode` Dual-Consumer Note, which documents the identical `orchestrator_mode: true`
  propagation contract this Tier-4 gate reuses). Wiring the interactive branch into
  `/orchestrate` would add dead code no execution path can ever reach.
- **`/revise`** and **`/task`** are not conflict-response entry points: `/revise`'s documented
  contract is "works regardless of task status" and it is exempt from the terminal-status guard
  entirely (see `command-gate-in.sh`'s `operation != "revise"` branch); `/task`'s `expand` and
  `abandon` operations source `command-gate-in.sh` for its session/task-lookup machinery but do
  not represent conflict-prone, potentially-long-running work the way research/plan/implement
  dispatches do. Neither command's failure mode benefits from a wait/skip/override menu the way a
  blocked research, plan, or implementation dispatch does.

## Same-Session Re-Entry: The Critical Safety Property

This is the **highest-impact risk** in this lock's design: a bug in the
session-identity check would block ALL task work system-wide, since `command-gate-in.sh` is
sourced by SIX command files: `/research`, `/plan`, `/implement`, `/revise`, `/orchestrate`, and
`/task` (twice — its `expand` and `abandon` operations). This count is verifiable by
`grep -rn 'source .claude/scripts/command-gate-in.sh' agent-system/extensions/core/commands/` and
must not be trusted as frozen — re-derive it rather than citing this prose if a future command
gains a new `command-gate-in.sh` call site. The session-identity branch is checked FIRST,
unconditionally, before any staleness computation
— a session re-acquiring its own lock (e.g. `/research 42` immediately followed by `/plan 42` in
the same conversation) always succeeds. This property has a dedicated functional test and should never be weakened by future edits.

## Consumers (Six Distinct Wiring Paths)

1. **Single-task gate scripts**: `command-gate-in.sh` (acquire after the terminal-status guard)
   and `command-gate-out.sh` (unconditional release) — covers `/research`, `/plan`,
   `/implement`, `/revise`, `/orchestrate`'s own single-task CHECKPOINT 1/2, and `/task`'s
   `expand` and `abandon` operations (see the Same-Session Re-Entry section above for the full
   six-site sourcing list and its grep-verifiable count).
2. **Multi-task/wave dispatch**: `skill-orchestrate/SKILL.md` Stage MT (per-task
   acquire/release inside each wave dispatch) and `implement.md` Step 3 (per-task
   acquire/release in the multi-task loop) — these paths bypass the gate scripts entirely and
   need their own acquire/release bracketing. Heartbeat refresh is wired at two distinct layers:
   a CYCLE-layer refresh at existing natural checkpoints (`skill-orchestrate/SKILL.md`'s Stage 3
   cycle loop, alongside the existing `.orchestrator-loop-guard` refresh — covering both effort
   modes in this one engine now that the formerly-separate hard-mode engine's own mirrored
   Stage 3 write was merged in and deleted) for research/plan cycles which have no phase
   transitions of their own to hook; and a PHASE-layer refresh that is now MECHANIZED INSIDE
   `update-phase-status.sh` itself, firing at every phase transition of every caller (including
   `agents/general-implementation-agent.md`'s Stage 4D, which every implement-dispatch target —
   base or hard-mode, core or extension — follows the same shape of) with `session_id` derived
   from the task's own `.lock/holder.json` — no per-caller wiring or argument threading required.
   `skill-orchestrate` dispatches `general-implementation-agent` directly — there is no skill-layer
   wrapper needing its own phase-transition point — and the agent already inherits the mechanized
   refresh (see item 5 below, which states this same fact). Because create-if-missing
   lives inside `acquire` itself (see the `acquire` contract above), both of these
   gate-bypassing consumers dispatch tasks whose directory does not exist yet without any change
   of their own — the fix is entirely internal to `cmd_acquire`/`resolve_task_dir`.

   **Register/acquire parity invariant**: the `session_id` argument a wave-dispatch consumer
   passes to `acquire`/`release`/`heartbeat` for a given task MUST be byte-identical to the
   `session_id` the same batch already passed to `session-register` (see item 5 below and the
   "Session-Registry Reader Contract" section above), because the session-registry contention
   pass's self-exclusion (D4) is an exact string match on `session_id`, not a prefix or
   substring match. A per-task-suffixed variant (for example `${session_id}_${task_num}`) makes
   the batch's own union-`file_scope` registration read as a foreign live session, and every lock
   acquire in the batch is refused against its own registration. A new multi-task lock consumer
   MUST reuse the exact bare `session_id` string across its `session-register` call and every
   `acquire`/`release`/`heartbeat` call it makes on behalf of that same batch. See the
   "Same-session bypass" bullet under "Cross-Task `file_scope` Overlap Check" above for why this
   same-bare-id sharing does not create an in-batch overlap hole: same-batch siblings ARE bypassed
   by that check, but in-batch `file_scope` collisions are already excluded earlier by the
   batch-admission pre-check.
3. **`init-marker` call sites** (file-granularity, independent of the two paths above):
   `skill-orchestrate/SKILL.md` Stage 2, covering both effort modes in this one engine —
   `.orchestrator-loop-guard` creation unconditionally, plus `.orchestrator-churn-state.json`
   creation when `hard_mode` is true (formerly a separate hard-mode engine's own Stage 2, since
   merged in and deleted).
4. **`reap` call site** (see the "Reap Contract" section above): `skill-refresh/SKILL.md`'s
   "Reap Stale Task Locks" step is the SOLE caller — reap is explicit-invocation-only, so it has
   exactly one wiring path rather than the acquire/release-style multiple entry points above.
   This consumer is NOT on the hourly systemd cadence: `claude-refresh.timer` invokes
   `claude-refresh.sh` (process cleanup only), not this skill's `specs/` sweep, so reap only runs
   when `/refresh` is invoked explicitly (see `commands/refresh.md`'s "Stale Task Locks" section
   for the same scoping note from the caller's side).
5. **Session-registry call sites** (see the "Session-Registry CLI" section above — register/
   heartbeat/release across the gate scripts, the three commands' batch steps, the orchestrate
   stages, and the implementer's per-phase checkpoint):
   - `command-gate-in.sh` (register, adjacent to the task-lock acquire) /
     `command-gate-out.sh` (release, adjacent to the task-lock release) — single-task sessions.
   - `commands/research.md`, `commands/plan.md`, `commands/implement.md` Step 2 (register under
     the bare, unsuffixed `batch_session_id`) / Step 4 (or Step 4/5 boundary) (release) —
     multi-task command batches.
   - `skill-orchestrate/SKILL.md` Stage MT-1 (register, adjacent to `mt_state_file`
     initialization) / Stage MT-5 (release, alongside the `mt_state_file` remove/preserve
     handling) — the `/orchestrate` multi-task batch path. Single-task `/orchestrate` needs no
     separate wiring: its CHECKPOINT 1/2 already routes through the gate scripts above.
   - Heartbeat refresh is wired at existing checkpoints only, never a new one:
     `skill-orchestrate/SKILL.md`'s Stage 3 cycle loop (single-task, both effort modes — the
     formerly-separate hard-mode engine's own mirrored Stage 3 write was merged in and deleted)
     and Stage MT-3 step 1 status refresh (multi-task batch), and
     the phase-layer refresh MECHANIZED INSIDE `update-phase-status.sh` itself — fired at every
     phase transition of every caller, `agents/general-implementation-agent.md`'s Stage 4D
     included, with `session_id` derived from the task's own `.lock/holder.json` rather than
     threaded as an argument (`skill-orchestrate` dispatches `general-implementation-agent`
     directly — there is no skill-layer wrapper needing its own phase-transition point — and the
     agent inherits the mechanized refresh for free).
   - `session-reap` is explicit-invocation-only, wired into `skill-refresh/SKILL.md` Step 4.6,
     mirroring `reap`'s own wiring shape (item 4 above).
6. **`session-list` reader call sites** (see the "Session-Registry Reader Contract" section
   above — the registry's write-side call sites in item 5 are all writers; this item is the
   read-side, added by the conflict-detection convergence):
   - `task-lock.sh`'s own `cmd_acquire` calls `cmd_session_list` in-process (no subprocess) as
     part of its cross-task `file_scope` overlap check (see that section above), immediately
     after the existing held-lock pass, inside the same `acquire_scope_mutex` critical section.
   - `orchestrate-batch-admit.sh` subprocess-calls `task-lock.sh session-list` once per
     invocation, ONLY when its own caller supplies `--session-id` (see that script's D6
     degradation contract for the omitted case) — wired into `commands/research.md`,
     `commands/plan.md`, `commands/implement.md`'s new batch-admission pre-check step, and into
     `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5's per-cycle admission call.

Every `.lock/`-based path calls the SAME `task-lock.sh` subcommands — never reimplemented inline —
so the wiring paths cannot drift from each other's semantics.

## Non-Goals (Deferred Follow-Ups)

- ~~**`file_scope`-granular cross-task locking**: blocking `/implement 99` while `/implement 42`
  holds a lock when their `file_scope` arrays overlap (reusing `file-footprint-overlap.md`'s
  algorithm)~~ — CLOSED by the cross-task `file_scope` overlap check (see "Cross-Task
  `file_scope` Overlap Check" above), which scans every held `.lock` across all task directories
  at acquire time via `find_held_locks`/`get_file_scope`/`scopes_overlap`, guarded by the
  `specs/.scope-lock/` mutex. This document's task-number lock and
  `file-footprint-overlap.md`'s directory-prefix overlap algorithm remain two DISTINCT
  mechanisms — acquire now composes both rather than merging them into one.
- ~~Atomic creation of `.orchestrator-loop-guard` was missing an exclusivity guard~~ — CLOSED by
  the `init-marker` subcommand (see the Contract section above), which both
  `.orchestrator-loop-guard` creation sites (and `.orchestrator-churn-state.json`'s) now call.

## Related Documentation

- `.claude/scripts/task-lock.sh` — the implementation (acquire/heartbeat/release/check/reap/
  init-marker, plus the scope-mutex, commit-mutex, and session-registry CLIs documented above)
- `.claude/scripts/test-task-lock-reap.sh` — isolated-temp-root test suite proving the "Reap
  Contract" section's behavior (fresh-not-reaped, stale-reaped-and-reported, dry-run removes
  nothing, acquire/check/heartbeat/release never implicitly reap, corrupt-holder skip-vs-reap,
  and the depth-3 archive case)
- `.claude/scripts/test-session-registry.sh` — isolated-temp-root test suite proving the
  "Session-Registry CLI" section's behavior (required-field write, `file_scope` union,
  re-register preserves `started_at`, heartbeat-on-missing-entry never blocks, release
  idempotence, dry-run removes nothing, the dead-pid/`SESSION_REGISTRY_DEAD_PID_MIN` floor guard,
  the `SESSION_REGISTRY_REAP_MIN` stale-heartbeat band, and corrupt-entry mtime fallback)
- `.claude/context/standards/orchestrator-runtime-files.md` — the Class Table row for
  `specs/.sessions/{session_id}.json` (ephemeral, gitignored, no reader) and the repo-root
  `/.gitignore` coverage point this session-registry storage directory relies on
- `.claude/skills/skill-refresh/SKILL.md` — the sole `reap` call site ("Reap Stale Task Locks"
  step)
- `.claude/commands/refresh.md` — the "Stale Task Locks" section documenting `reap` from the
  `/refresh` command's own perspective, including the not-on-the-hourly-timer scoping note
- `.claude/scripts/git-commit-scoped.sh` — the sole intended caller of `commit-acquire`/
  `commit-release`; the single sanctioned implementation of scoped, serialized commits
- `.claude/context/standards/git-staging-scope.md` — "Commit-Level Path Scoping and Cross-Process
  Serialization" section documents the same contract from the caller's perspective
- `.claude/scripts/command-gate-in.sh` / `command-gate-out.sh` — single-task wiring
- `.claude/skills/skill-orchestrate/SKILL.md` — multi-task/wave wiring + heartbeat +
  `.orchestrator-loop-guard` (both effort modes) and `.orchestrator-churn-state.json`
  (hard mode only) `init-marker` call sites
- `.claude/commands/implement.md` — multi-task Step 3 wiring
- `.claude/agents/general-implementation-agent.md` — phase-transition heartbeat (Stage 4D)
- `checkpoint-before-overflow.md` — the git checkpoint procedure this lock composes with (a
  session holding the lock still checkpoints/commits exactly as before; the lock only adds
  cross-session exclusivity, it does not change checkpoint behavior)
- `file-footprint-overlap.md` — the directory-prefix overlap algorithm `acquire`'s cross-task
  `file_scope` check reuses by reference; still a distinct document from this one —
  this file owns the lock contract, that file owns the overlap rule
