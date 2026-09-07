---
name: skill-refresh
description: Manage Claude Code resources - terminate orphaned processes and clean up ~/.claude/ directory
allowed-tools: Bash, AskUserQuestion
---

# Refresh Skill (Direct Execution)

Direct execution skill for managing Claude Code resources. Performs two operations:
1. **Process cleanup**: Identify and terminate orphaned Claude Code processes
2. **Directory cleanup**: Clean up accumulated files in ~/.claude/

This skill executes inline without spawning a subagent.

## Execution

### Step 1: Parse Arguments

Extract flags from command input:
- `--dry-run`: Preview mode
- `--force`: Skip confirmation, use 8-hour default

```bash
# Parse from command input
dry_run=false
force=false
if [[ "$*" == *"--dry-run"* ]]; then
  dry_run=true
fi
if [[ "$*" == *"--force"* ]]; then
  force=true
fi
```

### Step 2: Run Process Cleanup

Execute process cleanup script, forwarding `--dry-run` through when set (reusing the `dry_run`
boolean already parsed in Step 1 -- no new argument parsing). This one invocation covers BOTH the
Claude-process pass and the separately-gated Lean LSP process-tree pass (see "Process Safety"
below); the script always runs both and reports/terminates each independently:

```bash
process_output=$(.claude/scripts/claude-refresh.sh $( [ "$force" = true ] && echo "--force" ) $( [ "$dry_run" = true ] && echo "--dry-run" ))
```

Store process cleanup output for display.

**Interactive confirmation** (only when neither `force` nor `dry_run` was set at invocation --
`--force` already terminates immediately with no prompt per the existing contract, and
`--dry-run` never terminates regardless): closes a pre-existing gap where this step stored
output but never actually prompted, despite this skill's frontmatter declaring `AskUserQuestion`
and the script's own header comment already assuming a prompt exists ("skill will prompt with
AskUserQuestion and re-run with --force if confirmed"). Check `process_output` for candidates
from either pass by testing for the absence of BOTH "No orphaned processes found." and "No idle
Lean LSP process trees found." -- if either line is absent (that pass found something), prompt
once with a single combined confirmation covering both passes:

```json
{
  "question": "Terminate the orphaned Claude processes and/or idle Lean LSP process trees found above?",
  "header": "Process Cleanup",
  "multiSelect": false,
  "options": [
    {
      "label": "Yes, terminate",
      "description": "Terminate every orphaned Claude process and idle Lean LSP process tree reported above"
    },
    {
      "label": "No, skip",
      "description": "Leave everything reported above running"
    }
  ]
}
```

If the user selects "Yes, terminate", re-run with `--force` and replace the stored output:

```bash
process_output=$(.claude/scripts/claude-refresh.sh --force)
```

If the user selects "No, skip" -- or if both "No orphaned processes found." and "No idle Lean
LSP process trees found." were already present in `process_output` -- skip this prompt entirely
and proceed to Step 3 with the already-stored `process_output`.

### Step 3: Clean Orphaned Postflight Markers

Clean any orphaned postflight coordination files from the specs directory. These files should normally be cleaned up by skills after postflight completes, but may be left behind if a process is interrupted.

```bash
echo ""
echo "=== Cleaning Orphaned Postflight Markers ==="
echo ""

# Find orphaned postflight markers (older than 1 hour)
orphaned_pending=$(find specs -maxdepth 3 -name ".postflight-pending" -mmin +60 -type f 2>/dev/null)
orphaned_guard=$(find specs -maxdepth 3 -name ".postflight-loop-guard" -mmin +60 -type f 2>/dev/null)

# Also check for legacy global markers
legacy_pending=""
legacy_guard=""
if [ -f "specs/.postflight-pending" ]; then
    legacy_pending="specs/.postflight-pending"
fi
if [ -f "specs/.postflight-loop-guard" ]; then
    legacy_guard="specs/.postflight-loop-guard"
fi

if [ -n "$orphaned_pending" ] || [ -n "$orphaned_guard" ] || [ -n "$legacy_pending" ] || [ -n "$legacy_guard" ]; then
    if [ "$dry_run" = true ]; then
        echo "Would delete the following orphaned markers:"
        [ -n "$orphaned_pending" ] && echo "$orphaned_pending"
        [ -n "$orphaned_guard" ] && echo "$orphaned_guard"
        [ -n "$legacy_pending" ] && echo "$legacy_pending"
        [ -n "$legacy_guard" ] && echo "$legacy_guard"
    else
        # Delete orphaned task-scoped markers
        find specs -maxdepth 3 -name ".postflight-pending" -mmin +60 -delete 2>/dev/null
        find specs -maxdepth 3 -name ".postflight-loop-guard" -mmin +60 -delete 2>/dev/null

        # Delete legacy global markers
        rm -f specs/.postflight-pending 2>/dev/null
        rm -f specs/.postflight-loop-guard 2>/dev/null

        echo "Cleaned orphaned postflight markers."
    fi
else
    echo "No orphaned postflight markers found."
fi
```

### Step 4: Reap Stale Task Locks

Sweep `specs/` for stale task-number `.lock` directories (see `context/patterns/task-lock.md`'s
Reap Contract section for the full threshold reasoning) and report every one found. This is a
distinct cleanup target from Step 3's postflight markers, added alongside it rather than merged
into it. Reuses the `dry_run` boolean already parsed in Step 1 -- no new argument parsing.

```bash
echo ""
echo "=== Reaping Stale Task Locks ==="
echo ""

if [ "$dry_run" = true ]; then
    .claude/scripts/task-lock.sh reap --dry-run
else
    .claude/scripts/task-lock.sh reap
fi
```

The per-lock detail (task number, session id, operation, age) is produced by `task-lock.sh`
itself; echo its output verbatim rather than summarizing it away, matching the reap subcommand's
own per-item reporting contract.

### Step 4.5: Reap Stale Session-Scoped Orchestration Files

Sweep `specs/` for stale session-scoped `specs/.orchestrator-multi-state-{session_id}.json` and
`specs/.return-meta-multi-{session_id}.json` files (see
`context/standards/orchestrator-runtime-files.md`'s Class Table) and report every one found. This
is a distinct cleanup target from Step 4's task-lock reap — session-scoping the two repo-level
batch-orchestration singletons trades collision risk for unbounded litter if an abandoned batch's
file is never swept, so this step exists to bound that litter. Uses the `X.5` numbering
deliberately so Steps 5-7 below keep their existing numbers and no cross-reference to them in
`refresh.md` needs to change. Reuses the `dry_run` boolean already parsed in Step 1.

```bash
echo ""
echo "=== Reaping Stale Session-Scoped Orchestration Files ==="
echo ""

if [ "$dry_run" = true ]; then
    .claude/scripts/reap-session-runtime-files.sh --dry-run
else
    .claude/scripts/reap-session-runtime-files.sh
fi
```

The per-file detail (filename, embedded session id, age in minutes) is produced by
`reap-session-runtime-files.sh` itself; echo its output verbatim rather than summarizing it away,
matching Step 4's own "echo verbatim" instruction. This cleanup runs only on explicit `/refresh`
invocation, not on the hourly systemd cadence.

### Step 4.6: Reap Stale Session Registry Entries

Sweep `specs/.sessions/` for stale in-flight orchestration session registry entries (see
`context/patterns/task-lock.md`'s Session-Registry CLI section) and report every one found. This
is a distinct cleanup target from Step 4's task-lock reap and Step 4.5's session-scoped
orchestration-file reap — the session registry (`specs/.sessions/{session_id}.json`) is a
separate, additive mechanism produced by `task-lock.sh session-register`/`session-heartbeat`, not
one of the two files Step 4.5 sweeps. Uses the `X.6` numbering deliberately so Steps 5-7 keep
their existing numbers and no cross-reference to them in `refresh.md` needs to change. Reuses the
`dry_run` boolean already parsed in Step 1 — the same `--dry-run` passthrough branch structure as
Step 4.5.

```bash
echo ""
echo "=== Reaping Stale Session Registry Entries ==="
echo ""

if [ "$dry_run" = true ]; then
    .claude/scripts/task-lock.sh session-reap --dry-run
else
    .claude/scripts/task-lock.sh session-reap
fi
```

The per-entry detail (session id, command, task numbers, age, reap reason) is produced by
`task-lock.sh session-reap` itself; echo its output verbatim rather than summarizing it away,
matching Step 4 and Step 4.5's own "echo verbatim" instruction. This cleanup runs only on
explicit `/refresh` invocation, never on the hourly `claude-refresh.timer` cadence, which runs
process cleanup only and does not sweep `specs/`.

### Step 5: Clean Stale Backup Files

Scan for and remove any `.backup` files left over from the deprecated backup mechanism in `.claude/`:

```bash
echo ""
echo "=== Cleaning Stale Backup Files ==="
echo ""

# Find .backup files in .claude/ directory
backup_files=$(find .claude/ -name "*.backup" -type f 2>/dev/null)

if [ -n "$backup_files" ]; then
    backup_count=$(echo "$backup_files" | wc -l)
    if [ "$dry_run" = true ]; then
        echo "Would delete $backup_count .backup file(s):"
        echo "$backup_files"
    else
        echo "$backup_files" | xargs rm -f
        echo "Deleted $backup_count stale .backup file(s)."
    fi
else
    echo "No stale .backup files found."
fi
```

### Step 6: Run Directory Survey

Show current directory status without cleaning yet:

```bash
.claude/scripts/claude-cleanup.sh
```

This displays:
- Current ~/.claude/ directory size
- Breakdown by directory
- Space that can be reclaimed

### Step 7: Execute Based on Mode

#### Dry-Run Mode

If `--dry-run` is set:

```bash
echo ""
echo "=== DRY RUN MODE ==="
echo "Showing 8-hour cleanup preview..."
echo ""
.claude/scripts/claude-cleanup.sh --dry-run --age 8
```

Exit after showing preview.

#### Force Mode

If `--force` is set:

```bash
echo ""
echo "=== EXECUTING CLEANUP (8-hour default) ==="
echo ""
.claude/scripts/claude-cleanup.sh --force --age 8
```

Show results and exit.

#### Interactive Mode (Default)

If neither flag is set:

1. Check if cleanup candidates exist (claude-cleanup.sh exits with code 1 if candidates found)

2. If no candidates, display message and exit:
```
No cleanup candidates found within default thresholds.
All files are either protected or recently modified.
```

3. If candidates exist, prompt user for age selection:

```json
{
  "question": "Select cleanup age threshold:",
  "header": "Age Threshold",
  "multiSelect": false,
  "options": [
    {
      "label": "8 hours (default)",
      "description": "Remove files older than 8 hours - aggressive cleanup"
    },
    {
      "label": "2 days",
      "description": "Remove files older than 2 days - conservative cleanup"
    },
    {
      "label": "Clean slate",
      "description": "Remove everything except safety margin (1 hour)"
    }
  ]
}
```

4. Map user selection to age parameter:
   - "8 hours (default)" → `--age 8`
   - "2 days" → `--age 48`
   - "Clean slate" → `--age 0`

5. Execute cleanup with selected age:

```bash
case "$selection" in
  "8 hours (default)")
    .claude/scripts/claude-cleanup.sh --force --age 8
    ;;
  "2 days")
    .claude/scripts/claude-cleanup.sh --force --age 48
    ;;
  "Clean slate")
    .claude/scripts/claude-cleanup.sh --force --age 0
    ;;
esac
```

6. Display cleanup results

---

## Example Execution Flows

### Interactive Flow

```bash
# User runs: /refresh

# Output:
Claude Code Refresh
===================

No orphaned processes found.
All 3 Claude processes are active sessions.

---

Claude Code Directory Cleanup
=============================

Target: ~/.claude/

Current total size: 7.3 GB

Scanning directories...

Directory                   Total    Cleanable    Files
----------                -------   ----------    -----
projects/                  7.0 GB       6.5 GB      980
debug/                   151.0 MB     140.0 MB      650
...

TOTAL                      7.3 GB       6.7 GB     5577

Space that can be reclaimed: 6.7 GB

# Prompt appears:
[Age Threshold]
Select cleanup age threshold:
  1. 8 hours (default) - Remove files older than 8 hours
  2. 2 days - Remove files older than 2 days
  3. Clean slate - Remove everything except safety margin

# User selects option 1

# Cleanup executes:
Cleanup Complete
================
Deleted: 5577 files
Failed:  0 files
Space reclaimed: 6.7 GB

New total size: 600.0 MB
```

### Dry-Run Flow

```bash
# User runs: /refresh --dry-run

# Process cleanup half, forwarding --dry-run through to claude-refresh.sh:
Claude Code Refresh
===================

[DRY RUN] Preview only -- no processes will be terminated.

Found 2 orphaned processes using 1.2 MB:
...
Total memory that can be reclaimed: 1.2 MB

# Directory cleanup half -- shows survey, then:
=== DRY RUN MODE ===
Showing 8-hour cleanup preview...

Would delete: 5577 files
Would reclaim: 6.7 GB

Dry Run Summary
===============
No changes made.
```

### Force Flow

```bash
# User runs: /refresh --force

# Shows survey, then immediately:
=== EXECUTING CLEANUP (8-hour default) ===

Cleanup Complete
================
Deleted: 5577 files
Space reclaimed: 6.7 GB
```

---

## Safety Measures

### Protected Files (Never Deleted)

- `sessions-index.json` (in each project directory)
- `settings.json`
- `.credentials.json`
- `history.jsonl`

### Safety Margin

Files modified within the last hour are **never deleted**, regardless of age threshold.

### Process Safety

`claude-refresh.sh` identifies orphans from a single atomic process snapshot, applying four
independently-testable predicates rather than an argv-substring match or an ancestor-only
process-tree walk (an ancestor walk cannot reach a sibling, such as the invoking session's own
sleep inhibitor, and re-querying a transient PID from an earlier snapshot is a race -- see the
script's own header comment for the full rationale):

- **Executable-identity match**: a candidate must match a narrow allow-list on its executable
  name (`comm`), never on a substring anywhere in its argv. This is what keeps a system daemon
  that merely mentions "claude" in one of its own arguments from ever being considered a
  candidate at all.
- **System-slice cgroup exclusion**: a candidate under `/system.slice/` is never selected,
  regardless of anything else.
- **Invoking-UID ownership**: a candidate not owned by the invoking user's UID is excluded.
- **Inhibitor-target liveness**: a candidate holding a `systemd-inhibit ... tail --pid=<N>`
  sleep-inhibitor is excluded when the process it protects (`<N>`, a DIFFERENT process than the
  candidate) is still alive -- this is what correctly protects a live session's own inhibitor
  and any other live session's inhibitor on the machine, not just the invoker's own.
- **Zero-query self-exclusion**: a candidate whose pid or ppid equals the script's own pid is
  skipped, known at parse time with no second query and no race window.

`TTY == "?"` (no controlling terminal) remains a necessary-but-not-sufficient signal -- it is
true of every systemd-managed process by construction, so it is combined with the predicates
above, never used alone as the sole discriminator.

This design deliberately trades recall for safety: a leaked process this allow-list fails to
recognize survives (false negative), which is strictly preferable to ever terminating a live
system daemon or another live session's process (false positive).

- **Lean LSP process-tree pass (separately gated)**: a second, independent detection+termination
  pass identifies orphaned `lake serve` -> `lean --server` -> `lean --worker` process trees
  spawned by `lean-lsp-mcp` (which has no idle timeout or LRU eviction of its own). It takes its
  own `ps -C lake,lean` snapshot, uses its own comm+argv predicate set (`comm` alone cannot
  distinguish the three Lean process forms -- the distinction lives in `args`), and reuses
  `is_system_slice_cgroup`/`is_owned_by_current_uid` unmodified as defense-in-depth. A tree is a
  reclamation candidate only if **every** member (root, server, and all workers) is idle:
  near-zero CPU and elapsed time at/beyond a configurable threshold (see below). Termination is
  strictly ordered workers -> server -> `lake serve` root, so a signaled parent never orphans its
  children into PID 1. Deliberately, this pass does **not** use the `TTY == "?"` signal at all --
  live verification showed `lake serve`/`lean --server` retain a non-`?` controlling tty
  inherited from their spawning pty even once fully orphaned, so tty cannot discriminate here.
  Reclaiming a tree is fully recoverable: `lean-lsp-mcp` respawns a fresh one automatically on the
  next tool call, at the cost of a rebuild.
- **`LEAN_LSP_IDLE_THRESHOLD_MIN`**: the Lean pass's idle-reclamation threshold, in minutes
  (default: 240, matching this repo's existing reap-threshold precedent). Deliberately
  conservative -- a single observed 13-hour-idle data point motivated this pass, but the default
  is set well below that to reclaim well before it while still avoiding reclaiming a tree the
  user is about to reuse. Override via the environment variable for a different posture; see
  `--help`.

---

## Error Handling

### Scripts Not Found

If scripts don't exist:
```
Error: Cleanup scripts not found at .claude/scripts/
Please ensure claude-refresh.sh and claude-cleanup.sh are installed.
```

### Permission Denied

If kill/delete fails due to permissions:
```
Warning: Some operations failed due to insufficient permissions.
Failed files: 5
Successfully deleted: 5572 files
```

### No ~/.claude/ Directory

If directory doesn't exist:
```
Error: ~/.claude/ directory not found.
Nothing to clean up.
```
