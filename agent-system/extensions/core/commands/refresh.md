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
| `--dry-run` | Preview both process and directory cleanup without making changes. Process cleanup shows the same orphan report as the no-flag path, labeled with an explicit `[DRY RUN]` banner; directory cleanup shows the 8-hour preview. |
| `--force` | Skip confirmation and execute immediately (8-hour default for directory cleanup) |
| (no flags) | Interactive mode with process cleanup and age threshold selection |

## What It Cleans

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
`specs/.orchestrator-multi-state-{session_id}.json` and
`specs/.return-meta-multi-{session_id}.json` files via `reap-session-runtime-files.sh`, reporting
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
  pass identifies orphaned `lake serve` -> `lean --server` -> `lean --worker` process trees
  spawned by `lean-lsp-mcp` (which has no idle timeout or LRU eviction of its own). It takes its
  own `ps -C lake,lean` snapshot, uses its own comm+argv predicates (`comm` alone cannot
  distinguish the three Lean process forms), and reuses the system-slice/UID exclusions above
  unmodified as defense-in-depth. A tree is a candidate only if every member (root, server, all
  workers) is idle -- near-zero CPU and elapsed time at/beyond a configurable threshold.
  Termination is strictly ordered workers -> server -> `lake serve` root, so a signaled parent
  never orphans its children into PID 1. This pass deliberately does **not** use the `TTY == "?"`
  signal -- live verification showed `lake serve`/`lean --server` retain a non-`?` controlling
  tty inherited from their spawning pty even once fully orphaned. Reclaiming a tree is fully
  recoverable: `lean-lsp-mcp` respawns a fresh one automatically on the next tool call.
- **`LEAN_LSP_IDLE_THRESHOLD_MIN`**: the Lean pass's idle-reclamation threshold in minutes
  (default: 240, matching this repo's existing reap-threshold precedent, deliberately
  conservative). Override via the environment variable; see `claude-refresh.sh --help`.
- **Unreaped-child (zombie) reporting pass (report-only)**: a third, independently-gated pass
  detects `<defunct>` (zombie) child processes by `stat` state and reports them grouped by
  parent, with each child's age. It never terminates anything under any flag combination -- there
  is no recoverability question because there is no action taken: a zombie can only be reaped by
  its own parent calling `wait()`, never by an external signal, so this pass exists purely to
  surface the symptom (a parent daemon leaking zombies over time) for a human to act on.
- **MCP server fan-out reporting pass (report-only)**: a fourth, independently-gated pass reports
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
