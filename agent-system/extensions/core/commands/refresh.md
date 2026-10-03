---
description: Manage Claude Code resources - terminate orphaned processes and clean up files
allowed-tools: Bash, Read, Glob, AskUserQuestion
argument-hint: "[--dry-run] [--force]"
---

# /refresh Command

Comprehensive cleanup of Claude Code resources - terminate orphaned processes and clean up ~/.claude/ directory.

## Syntax

```
/refresh [--dry-run] [--force]
```

## Options

| Flag | Description |
|------|-------------|
| `--dry-run` | Preview every pass without making changes: process cleanup shows the same orphan report as the no-flag path, labeled with an explicit `[DRY RUN]` banner; the spec-directory sweeps (postflight markers, task locks, session-scoped orchestration files, session registry entries) and stale-backup-file cleanup list what they would delete; directory cleanup shows the 8-hour preview. |
| `--force` | Skip confirmation and execute immediately (the orphaned build-waiter pass, the age-threshold-only spec-directory sweeps, and stale-backup-file cleanup are all unaffected by this flag -- they already act unconditionally past their own threshold whenever `--dry-run` is not set; 8-hour default for directory cleanup) |
| (no flags) | Interactive mode with process cleanup and age threshold selection |

## What It Cleans

The single canonical list of every pass `/refresh` runs, each with its owning subsection below (a
thin pointer -- see that subsection for the full behavior, not restated here), its gate, whether
it is destructive, and whether the hourly `claude-refresh.timer` cadence reaches it. Only rows 1-5
(the five passes internal to `claude-refresh.sh`) are reached by that cadence; the remaining six
run only on explicit `/refresh` invocation. Row 5 is the only one of those five whose destructive
action is not gated by `--force`. This table agrees row-for-row on gate and destructiveness with
`skill-refresh/SKILL.md`'s own Pass Inventory table.

| # | Pass | Owning subsection | Gate | Destructive | Hourly cadence |
|---|------|--------------------|------|--------------|-----------------|
| 1 | Orphaned Claude processes | Process Cleanup / Process Protection | interactive-confirm (AskUserQuestion) / `--dry-run` preview / `--force` terminates immediately | Yes | Yes |
| 2 | Lean LSP process-tree reclamation | Process Protection | interactive-confirm (same combined prompt as row 1, using the shared CPU-delta idle + memory-floor cost gate) / `--dry-run` preview (also launches the notify-before-kill prompt for an eligible tree) / `--force` terminates only ELIGIBLE trees | Yes, but recoverable -- `lean-lsp-mcp` respawns a fresh tree automatically on next tool call | Yes |
| 3 | Zombie (unreaped-child) reporting | Process Protection | report-only-always (no `--force` branch exists) | No | Yes |
| 4 | MCP server fan-out reporting | Process Protection | report-only-always (never terminates or reconfigures) | No | Yes |
| 5 | Orphaned build-waiter poll loops | Orphaned Build Waiters | age-threshold-only (`BUILD_WAITER_REAP_MIN`, default 60 min; canonical-shape waiters also need a dead embedded writer PID or `BUILD_WAITER_CEILING_MIN`, default 240 min), no interactive confirmation, unaffected by `--force` | Yes -- the waiting shell only; the writer and its build are never signaled | Yes (report-only via `--dry-run`; reaping is `/refresh`-only) |
| 6 | Orphaned postflight markers | Orphaned Postflight Markers | age-threshold-only (60 min), no interactive confirmation | Yes | No (`/refresh`-only) |
| 7 | Stale task `.lock` dirs | Stale Task Locks | age-threshold-only (`TASK_LOCK_REAP_MIN`, default 120 min), no interactive confirmation | Yes | No (`/refresh`-only) |
| 8 | Stale session-scoped orchestration files | Stale Session-Scoped Orchestration Files | age-threshold-only (`ORCHESTRATOR_SESSION_REAP_MIN`, default 240 min), no interactive confirmation | Yes | No (`/refresh`-only) |
| 9 | Stale session registry entries | Stale Session Registry Entries | age-threshold-only (`SESSION_REGISTRY_REAP_MIN`, default 240 min), no interactive confirmation | Yes | No (`/refresh`-only) |
| 10 | Stale `.backup` files | Stale Backup Files | `--dry-run` preview / unconditional delete otherwise (no age threshold, no confirmation) | Yes | No (`/refresh`-only) |
| 11 | `~/.claude/` directory cleanup | Directory Cleanup | interactive-confirm (age-threshold selection) / `--dry-run` preview / `--force` immediate (8h default) | Yes -- protected filenames and the 1-hour safety margin (see "Safety" below) are exempted | No (`/refresh`-only) |

### Process Cleanup

Identifies and terminates orphaned Claude Code processes (detached processes without a controlling terminal).

### Directory Cleanup

Cleans accumulated files in ~/.claude/:

| Directory | Contents |
|-----------|----------|
| projects/ | Session .jsonl files and subdirectories |
| debug/ | Debug output files |
| file-history/ | File version snapshots |
| todos/ | Todo list backups |
| session-env/ | Environment snapshots |
| telemetry/ | Usage telemetry data |
| shell-snapshots/ | Shell state |
| plugins/cache/ | Old plugin versions |
| cache/ | General cache |

### Orphaned Build Waiters

`/refresh` also reaps orphaned build-waiter poll loops via `claude-refresh.sh`'s fifth internal
pass. This pass exists because an ad-hoc, name-matching cleanup command searching for its own
poll-loop pattern matched its own command line and killed its own shell -- the same self-match
defect class the Process Protection predicates below already guard the Claude/Lean passes
against, now closed for this waiter shape too.

Two signature families are detected, matching `context/patterns/bounded-build-waiter.md`'s
canonical idiom and the legacy shape it replaces:

- **Family A (canonical)**: `timeout N bash -c 'while kill -0 "$1" ...; do sleep N; done' _
  "$pid"`. The embedded trailing PID is the writer being watched. A waiter in this family is a
  candidate once idle past `BUILD_WAITER_REAP_MIN` AND either its embedded writer PID is
  confirmed dead, or its age has passed `BUILD_WAITER_CEILING_MIN` -- a PID-reuse backstop for the
  case where a dead writer's PID has since been reassigned to an unrelated live process.
- **Family B (legacy/name-match)**: `until grep -q ...` sentinel polls and `until ! ps aux | grep
  -q ...` self-match polls -- the incident class this pass exists to reap. These carry no writer
  PID to check, so a waiter in this family is a candidate once idle past `BUILD_WAITER_REAP_MIN`
  alone.

**Self-exclusion is widened, not merely reused.** Every predicate this pass shares with the Claude
pass above (system-slice cgroup exclusion, invoking-UID ownership) is reused unmodified, but the
zero-query self-exclusion is widened from pid/ppid to pid, ppid, **process group**, and the
**full ancestor chain up to PID 1** -- all read from this pass's own single, frozen `ps -eo`
snapshot, with no second query. A reaper for a poll-loop idiom specifically must exclude any
caller that itself matches the shape being reaped, not just its own immediate pid/ppid. If this
pass's own row is missing from its snapshot, it fails closed: it prints one warning and reaps
nothing for that invocation, rather than guessing. Detection never uses a process-name-substring
search (a `ps | grep` shape) at any point -- only structured `ps -eo` columns -- which is what
makes this pass immune to the self-match defect it was written to close.

**Gate class: age-threshold-only, and unaffected by `--force`.** This is the first pass internal
to `claude-refresh.sh` whose destructive action is not gated by `$FORCE` at all: it reaps
whenever `--dry-run` is not set, exactly like the age-threshold-only spec-directory sweeps (rows
7-9 below), never via an interactive confirmation like rows 1-2. `$FORCE` is accepted by this
pass's implementation only for call-site symmetry with the other four internal passes and is
never branched on.

**Environment overrides**: `BUILD_WAITER_REAP_MIN` (idle-reclamation threshold in minutes,
default 60) and `BUILD_WAITER_CEILING_MIN` (the PID-reuse backstop ceiling in minutes, default
240). See `claude-refresh.sh --help`.

**Hourly cadence**: reached in report-only form, same as rows 1-4 -- `claude-refresh.timer`'s
shipped `ExecStart` always passes `--dry-run`, so the unattended hourly run reports orphaned
build waiters to the systemd journal without reaping them. A live reap only happens on an
explicit `/refresh` (or direct `claude-refresh.sh`) invocation without `--dry-run`.

### Orphaned Postflight Markers

`/refresh` also cleans orphaned postflight coordination markers
(`.postflight-pending`/`.postflight-loop-guard`) from `specs/`. These files should normally be
removed by skills after postflight completes, but may be left behind if a process is
interrupted. The gate is age-threshold-only: any marker older than 60 minutes is deleted
unconditionally when `--dry-run` is not set, with no interactive confirmation at any age -- a
different gate class from the confirmation-gated process passes above.

This cleanup runs **only on explicit `/refresh` invocation**, never on the hourly systemd
cadence, which runs process cleanup only and does not sweep `specs/`.

### Stale Task Locks

`/refresh` also sweeps `specs/` (including `specs/archive/`) for stale task-number `.lock`
directories via `task-lock.sh reap`, reporting each one found (task number, session id,
operation, age in minutes) on both the dry-run and live paths. See
`.claude/context/patterns/task-lock.md`'s Reap Contract section for the full threshold
derivation.

This cleanup runs **only on explicit `/refresh` invocation** -- it is **not** on the hourly
systemd cadence. `claude-refresh.timer` invokes `claude-refresh.sh` (the process cleanup above)
only, not this skill's `specs/` sweep. An operator who assumes hourly reaping will misread a
surviving orphaned lock as a reaper bug rather than as this deliberate scoping choice: reap is a
lower-frequency, higher-consequence operation than process cleanup, and explicit invocation plus
a conservative threshold is the intended posture. Moving it onto the timer is a separable,
out-of-scope change.

**The hourly cadence itself is non-destructive.** `claude-refresh.timer`'s shipped `ExecStart`
invokes `claude-refresh.sh --dry-run`, not `--force` -- the unattended, no-confirmation hourly run
reports/logs found orphans to the systemd journal rather than terminating them. `--force` is a
deliberate, manual opt-in only (direct invocation, or a hand-edited unit); a matcher defect can no
longer be amplified into unattended hourly kills regardless of how correct the matcher looks at
review time.

### Stale Session-Scoped Orchestration Files

`/refresh` also sweeps the `specs/` root for stale session-scoped
`specs/.orchestration/.orchestrator-multi-state-{session_id}.json` and
`specs/.orchestration/.return-meta-multi-{session_id}.json` files via `reap-session-runtime-files.sh`, reporting
each one found (filename, embedded session id, age in minutes) on both the dry-run and live
paths. See `.claude/context/standards/orchestrator-runtime-files.md`'s Class Table for what these
files are and `reap-session-runtime-files.sh`'s own header for the `ORCHESTRATOR_SESSION_REAP_MIN`
threshold derivation (default 240 minutes — deliberately longer than the task-lock threshold
above, since a multi-task batch orchestration can legitimately run for many cycles). This sweep
is scoped to the two repo-level singletons directly under `specs/`; it does not recurse into
`specs/{NNN}_{SLUG}/`, whose per-task runtime files are already isolated by task directory.

Like the task-lock reap above, this cleanup runs **only on explicit `/refresh` invocation**, not
on the hourly systemd cadence -- and, like the task-lock section above, that hourly cadence is
itself non-destructive (`claude-refresh.timer` runs `claude-refresh.sh --dry-run`, reporting
rather than terminating; `--force` is a deliberate manual opt-in only).

### Stale Session Registry Entries

`/refresh` also sweeps `specs/.sessions/` for stale in-flight orchestration session registry
entries via `task-lock.sh session-reap`, reporting each one found (session id, command, task
numbers, age in minutes, reap reason) on both the dry-run and live paths. This is a distinct
cleanup target from the two sweeps above: the session registry
(`specs/.sessions/{session_id}.json`) is a separate, additive mechanism produced by
`task-lock.sh session-register`/`session-heartbeat`, not one of the files the orchestration-file
sweep above cleans. See `.claude/context/patterns/task-lock.md`'s Session-Registry CLI section
for the full threshold derivation (`SESSION_REGISTRY_REAP_MIN`, default 240 minutes).

Like the two sweeps above, this cleanup runs **only on explicit `/refresh` invocation**, never on
the hourly `claude-refresh.timer` cadence, which runs process cleanup only and does not sweep
`specs/`.

### Stale Backup Files

`/refresh` also scans `.claude/` for `.backup` files left over from a deprecated backup mechanism
and removes them: `--dry-run` lists what would be deleted, and any other invocation deletes them
immediately -- there is no age threshold and no interactive confirmation gating this pass, unlike
every other file-cleanup pass above.

This cleanup runs **only on explicit `/refresh` invocation**, never on the hourly systemd cadence.

## Interactive Mode

When run without flags, `/refresh` operates in interactive mode:

1. **Process cleanup**: Shows orphaned processes and prompts for confirmation
2. **Directory cleanup**: Shows cleanup candidates and prompts for age threshold:
   - **8 hours (default)** - Remove files older than 8 hours
   - **2 days** - Remove files older than 2 days (conservative)
   - **Clean slate** - Remove everything except safety margin

## Execution

Invoke skill-refresh with the provided arguments:

```
skill: skill-refresh
args: {flags from command}
```

The skill executes both cleanup types sequentially:
1. Process cleanup (using claude-refresh.sh)
2. Directory cleanup (using claude-cleanup.sh)

## Safety

### Protected Files (Never Deleted)

- `sessions-index.json` - System file in each project directory
- `settings.json` - User settings
- `.credentials.json` - Authentication credentials
- `history.jsonl` - User command history

### Safety Margin

Files modified within the last hour are **never deleted**, regardless of age threshold.

### Process Protection

`claude-refresh.sh` identifies orphans from a single atomic process snapshot, using four
independently-testable predicates rather than an argv-substring match or an ancestor-only
process-tree walk (an ancestor walk cannot reach a sibling, such as the invoking session's own
sleep inhibitor, and re-querying a transient PID from an earlier snapshot is a race):

- **Executable-identity match**: a candidate must match a narrow allow-list on its executable
  name (`comm`), never on a substring anywhere in its argv -- this is what keeps a system daemon
  that merely mentions "claude" in one of its own arguments from ever being a candidate.
- **System-slice cgroup exclusion**: a candidate under `/system.slice/` is never selected.
- **Invoking-UID ownership**: a candidate not owned by the invoking user's UID is excluded.
- **Inhibitor-target liveness**: a candidate holding a `systemd-inhibit ... tail --pid=<N>`
  sleep-inhibitor is excluded when the process it protects is still alive -- correctly
  protecting any live session's inhibitor on the machine, not just the invoker's own.
- **Zero-query self-exclusion**: a candidate whose pid or ppid equals the script's own pid is
  skipped, with no second query and no race window.

`TTY == "?"` (no controlling terminal) remains a necessary-but-not-sufficient signal, combined
with the predicates above rather than used alone. This design deliberately trades recall for
safety: a leaked process this allow-list fails to recognize survives, which is strictly
preferable to ever terminating a live system daemon or another live session's process.

- **Lean LSP process-tree pass (separately gated)**: a second, independent detection+termination
  pass identifies `lake serve` -> `lean --server` -> `lean --worker` process trees spawned by
  `lean-lsp-mcp` (which has no idle timeout or LRU eviction of its own). It takes its own
  `ps -C lake,lean` snapshot, uses its own comm+argv predicates (`comm` alone cannot distinguish
  the three Lean process forms), and reuses the system-slice/UID exclusions above unmodified as
  defense-in-depth. Detection itself is unconditional: every live, non-excluded tree is detected
  regardless of idleness; a tree is **eligible** for reclamation (reporting and, under `--force`,
  termination) only when BOTH gates below pass. Termination is strictly ordered
  workers -> server -> `lake serve` root, so a signaled parent never orphans its children into
  PID 1. Reclaiming a tree is fully recoverable: `lean-lsp-mcp` respawns a fresh one automatically
  on the next tool call.
  - **Idleness gate**: a CPU-delta state machine (`~/.local/state/claude-refresh/lean-trees.json`,
    keyed by root pid + `/proc/PID/stat` starttime) tracks each tree's summed `utime+stime`
    across runs. Unchanged cputime since the last run accrues idle time; any increase resets the
    idle clock to zero. This replaces an earlier `pcpu`/`etimes`-based gate that misjudged a
    long-lived, actively-used tree as idle (`ps pcpu` is lifetime cputime/elapsed, not a decaying
    average, so a tree busy early and idle since reads a near-zero `pcpu` indefinitely).
  - **Memory-floor cost gate**: reclaimable memory (see the PSS accounting note below) must also
    be at/above `LEAN_LSP_MEM_FLOOR_MB` (default 1024, i.e. 1 GB). An idle tree below the floor is
    reported as `idle, cheap, kept`, never terminated even under `--force` -- an idle tree that
    costs nothing is left alone; only one that costs real memory is worth the cost of a rebuild.
  - **PSS-based reclaimable accounting**: both this pass and the Claude-process pass above report
    reclaimable memory from `/proc/PID/smaps_rollup` (`Pss_Anon + SwapPss` per process), not a
    plain `RSS + VmSwap` sum -- the latter double-counts shared mmapped pages (e.g. a large shared
    Mathlib `.olean` mapping) once per worker that maps them. Shared file-backed pages
    (`Pss_File`) are reported separately as "shared cache, not counted" rather than folded into
    the reclaimable figure, since the kernel can already evict that page cache without killing
    anything. When `smaps_rollup` is unreadable or missing a required field, the figure falls back
    to `RSS + VmSwap` and is labeled approximate (a visible `~` prefix).
  - This pass deliberately does **not** use the `TTY == "?"` signal -- live verification showed
    `lake serve`/`lean --server` retain a non-`?` controlling tty inherited from their spawning
    pty even once fully orphaned.
- **`LEAN_LSP_IDLE_THRESHOLD_MIN`**: the Lean pass's idle-reclamation threshold in minutes
  (default: 240, matching this repo's existing reap-threshold precedent, deliberately
  conservative). Override via the environment variable; see `claude-refresh.sh --help`.
- **`LEAN_LSP_MEM_FLOOR_MB`**: the memory-floor cost gate in MB (default: 1024). Override via the
  environment variable.
- **Notify-before-kill prompt path**: on the non-`--force` path (including the hourly
  `--dry-run` timer run), an eligible tree triggers a detached `systemd-run --user` transient
  unit running `notify-send` with a single `-A default=Kill` action (chosen because this user's
  notification daemon, mako, has no dmenu-style action launcher and invokes the default action on
  left-click) and `-t 0` (never auto-expires). Left-clicking (Kill) re-invokes
  `claude-refresh.sh --lean-tree=<pid>:<starttime> --force`, which re-verifies the tree's
  identity, idleness, and floor eligibility from scratch before terminating -- anything that
  changed (the tree became active again, was already gone, or dropped below the floor) is logged
  and skipped, never force-terminated on stale information. Dismissing, right-clicking, letting
  the notification expire, or any outcome other than the default action records a
  `LEAN_LSP_SNOOZE_MIN`-minute (default 240, i.e. 4h) snooze, deduplicated so a tree is prompted
  at most once per snooze window. Missing `notify-send`, `systemd-run` (or a user session lacking
  cgroup delegation), or a DBus session bus degrades to a logged line only -- never a kill, never
  silence. The interactive `AskUserQuestion` prompt (row 2's interactive-confirm gate) uses this
  same cost gate and the same reclaimable/idle numbers; this is a second, independent channel, not
  a replacement for it.
- **`--lean-tree=<pid>:<starttime>`**: a separate, explicit early-return invocation mode (not one
  of the five numbered passes) that re-verifies and, with `--force`, terminates ONE specific Lean
  tree by root pid and `/proc/PID/stat` starttime. Without `--force` it previews only. This is the
  entry point the notify-before-kill prompt path re-invokes on a Kill outcome; see
  `claude-refresh.sh --help` for the full flag reference.
- **Orphaned build-waiter poll-loop pass (self-excluding, age-threshold-only)**: a third,
  independently-gated pass reaps orphaned build-waiter poll loops -- see the "Orphaned Build
  Waiters" section above for the two detected signature families, the widened self-exclusion
  (pid, ppid, process group, and the full ancestor chain of the reaper's own pid), and the
  fail-closed behavior when the reaper's own row is missing from its snapshot. Unlike every other
  pass in this list, its destructive action is gated purely by age, never by `--force`.
- **Unreaped-child (zombie) reporting pass (report-only)**: a fourth, independently-gated pass
  detects `<defunct>` (zombie) child processes by `stat` state and reports them grouped by
  parent, with each child's age. It never terminates anything under any flag combination -- there
  is no recoverability question because there is no action taken: a zombie can only be reaped by
  its own parent calling `wait()`, never by an external signal, so this pass exists purely to
  surface the symptom (a parent daemon leaking zombies over time) for a human to act on.
- **MCP server fan-out reporting pass (report-only)**: a fifth, independently-gated pass reports
  live per-session process/memory fan-out for every MCP server registered in user scope
  (`~/.claude.json`'s `mcpServers`) -- every session inherits every user-scope server
  unconditionally, so this cost is real and unavoidable, not a bug. It flags a server showing no
  live evidence of use with a conditional scoping advisory (never a directive) suggesting
  project-scoped `.mcp.json` registration where the server is genuinely repo-local, and names the
  one-time workspace-trust approval as the real cost of that move -- never a subagent-access
  barrier. Like the zombie pass, it never terminates or reconfigures anything.

## Examples

### Interactive Cleanup (Recommended)

```bash
# Show status, prompt for process cleanup, then prompt for age selection
/refresh
```

### Preview Mode

```bash
# Show what would be cleaned without making changes
/refresh --dry-run
```

### Automated Cleanup

```bash
# Skip prompts, clean with 8-hour default
/refresh --force
```

## Output

### Survey Output

```
Claude Code Refresh
===================

No orphaned processes found.
All 3 Claude processes are active sessions.

---

Claude Code Directory Cleanup
=============================

Target: ~/.claude/

Current total size: 7.3 GB

Age threshold: 8 hours
Safety margin: 1 hour (files modified within last hour are preserved)

Scanning directories...

Directory                   Total    Cleanable    Files
----------                -------   ----------    -----
projects/                  7.0 GB       6.5 GB      980
debug/                   151.0 MB     140.0 MB      650
file-history/             56.0 MB      50.0 MB     3100
todos/                      23 KB        20 KB      600
session-env/                  0 B            -        -
telemetry/                 1.5 MB       1.5 MB       11
shell-snapshots/           271 KB       250 KB      220
plugins/cache/              2.4 MB       2.0 MB       15
cache/                      70 KB        70 KB        1

TOTAL                      7.3 GB       6.7 GB     5577

Space that can be reclaimed: 6.7 GB
```

### After Cleanup

```
Cleanup Complete
================
Deleted: 5577 files
Failed:  0 files
Space reclaimed: 6.7 GB

New total size: 600.0 MB
```

### Dry Run

```
Dry Run Summary
===============
Would delete: 5577 files
Would reclaim: 6.7 GB
```

## Troubleshooting

### No cleanup candidates found

All files are either protected or within the selected age threshold. This is normal for a recently-used system.

### Permission denied

Some processes may require elevated permissions to terminate. Run as root if needed, or manually kill specific processes.

### Large cleanup size

If ~/.claude/ is very large (>5GB), consider starting with the "2 days" option to preserve recent work, then progressively clean older files.
