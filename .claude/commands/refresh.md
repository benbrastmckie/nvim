---
description: Manage Claude Code resources - terminate orphaned processes and clean up files
allowed-tools: Bash, Read, Glob, AskUserQuestion
argument-hint: [--dry-run] [--force]
model: opus
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
| `--dry-run` | Preview both process and directory cleanup without making changes |
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

- Only targets processes without a controlling terminal (TTY = "?")
- Never kills active Claude Code sessions
- Excludes current process tree

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
