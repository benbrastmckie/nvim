---
description: Manage Lean toolchain and Mathlib versions
---

# /lean Command

Manage Lean toolchain and Mathlib versions. Check for updates, perform upgrades with automatic cache download, verify builds, and rollback if needed.

## Usage

```bash
/lean                    # Check version status (default)
/lean --check           # Explicitly check versions
/lean --upgrade         # Interactive upgrade to latest
/lean --upgrade --dry-run  # Preview upgrade without changes
/lean --rollback        # Restore previous versions
```

## Workflow

### STEP 1: Preflight

1. Generate session ID: `sess_{timestamp}_{random}`
2. Validate project structure:
   - Check `lean-toolchain` exists
   - Check `lakefile.lean` exists
3. Parse arguments to determine mode

### STEP 2: Version Discovery

Read current configuration:
```bash
current_toolchain=$(cat lean-toolchain | sed 's/leanprover\/lean4://')
current_mathlib=$(grep -A2 'require mathlib' lakefile.lean | grep '@' | grep -o '"[^"]*"' | tr -d '"')
```

Fetch latest available (if network available):
```bash
latest_toolchain=$(curl -s https://raw.githubusercontent.com/leanprover-community/mathlib4/master/lean-toolchain | sed 's/leanprover\/lean4://')
```

### STEP 3: Execute Mode

Route to `skill-lean-version`:

```
@.opencode/skills/skill-lean-version/SKILL.md
```

#### Check Mode (Default)

Display version status:
```
Lean Version Status
===================

Current Configuration:
  Toolchain: v4.27.0-rc1
  Mathlib:   v4.27.0-rc1

Available:
  Mathlib master: v4.29.0-rc2

Update available: v4.27.0-rc1 -> v4.29.0-rc2
Run /lean --upgrade to begin upgrade workflow.
```

#### Upgrade Mode

Interactive upgrade workflow:
1. Display upgrade analysis
2. Prompt for confirmation
3. Create backups (`.backup` extension)
4. Update configuration files
5. Clean build artifacts
6. Run `lake update -R`
7. Download Mathlib cache
8. Verify build

#### Rollback Mode

Restore from backups:
1. Verify backups exist
2. Display rollback info
3. Prompt for confirmation
4. Restore backup files
5. Clean and regenerate
6. Verify build

### STEP 4: Report Results

**Check mode**:
```
Lean Version Status
===================

Current Configuration:
  Toolchain: v4.27.0-rc1
  Mathlib:   v4.27.0-rc1

Already up to date.
```

**Upgrade success**:
```
Upgrade Complete
================

Successfully upgraded:
  v4.27.0-rc1 -> v4.29.0-rc2

Files modified:
- lean-toolchain
- lakefile.lean
- lake-manifest.json (regenerated)

Build verification: PASSED

Backup files saved (.backup extension).
Run /lean --rollback if you need to revert.
```

**Upgrade with build issues**:
```
Upgrade Partial
===============

Files updated:
  v4.27.0-rc1 -> v4.29.0-rc2

Build verification: FAILED

Build errors detected. Options:
1. Run /lake to attempt automatic error repair
2. Run /lean --rollback to restore previous versions
3. Fix errors manually and run lake build

Backup files available for rollback.
```

**Rollback success**:
```
Rollback Complete
=================

Restored to: v4.27.0-rc1

Build verification: PASSED

Previous configuration restored successfully.
```

### STEP 5: Postflight

1. Log version operation results
2. Optionally commit if changes were made:
   ```
   lean: upgrade toolchain v4.27.0-rc1 -> v4.29.0-rc2

   Session: {session_id}

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```

## Modes

| Mode | Flag | Description |
|------|------|-------------|
| Check | `--check` (default) | Display current and available versions |
| Upgrade | `--upgrade` | Interactive upgrade to Mathlib master |
| Rollback | `--rollback` | Restore from backup files |

## Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Preview changes without applying (upgrade mode only) |

## Version Sources

| Source | URL | Purpose |
|--------|-----|---------|
| Mathlib master | `github.com/leanprover-community/mathlib4/master/lean-toolchain` | Latest stable Mathlib-compatible toolchain |

## Examples

### Check Current Versions
```
/lean

Lean Version Status
===================

Current Configuration:
  Toolchain: v4.27.0-rc1
  Mathlib:   v4.27.0-rc1

Available:
  Mathlib master: v4.29.0-rc2

Update available: v4.27.0-rc1 -> v4.29.0-rc2
Run /lean --upgrade to begin upgrade workflow.
```

### Preview Upgrade
```
/lean --upgrade --dry-run

Lean Version Upgrade
====================

Current:  v4.27.0-rc1
Target:   v4.29.0-rc2

Upgrade will:
1. Update lean-toolchain to v4.29.0-rc2
2. Update lakefile.lean Mathlib dependency
3. Clean build artifacts
4. Regenerate dependencies
5. Download Mathlib cache
6. Verify build

Dry Run Preview
===============

Would update:
- lean-toolchain: v4.27.0-rc1 -> v4.29.0-rc2
- lakefile.lean: Mathlib @ v4.27.0-rc1 -> @ v4.29.0-rc2

No changes made (dry run mode).
```

### Perform Upgrade
```
/lean --upgrade

[Version Selection]
Select upgrade action:
  1. Upgrade to v4.29.0-rc2
  2. Cancel

> 1

Creating backups...
Cleaning build artifacts...
Regenerating manifest...
Downloading Mathlib cache...
Verifying build...

Upgrade Complete
================

Successfully upgraded:
  v4.27.0-rc1 -> v4.29.0-rc2

Build verification: PASSED
```

### Rollback After Issues
```
/lean --rollback

Rollback Information
====================

Current:  v4.29.0-rc2
Restore:  v4.27.0-rc1

[Rollback Confirmation]
Confirm rollback to previous versions?
  1. Yes, rollback
  2. Cancel

> 1

Restoring backups...
Regenerating manifest...
Verifying build...

Rollback Complete
=================

Restored to: v4.27.0-rc1

Build verification: PASSED
```

## Safety

### Backup Files
Created before any modification:
- `lean-toolchain.backup`
- `lakefile.lean.backup`
- `lake-manifest.json.backup` (if exists)

### User Confirmation
All modifications require explicit confirmation.

### Build Verification
Every upgrade/rollback ends with build verification.

### Git Recovery
Alternative recovery via git:
```bash
git checkout lean-toolchain lakefile.lean
```

## Error Handling

| Scenario | Response |
|----------|----------|
| Network unavailable | Check mode shows current versions only; upgrade aborts |
| Project files missing | Abort with "run from project root" suggestion |
| Cache download fails | Warn and continue (build takes longer) |
| Build fails after upgrade | Suggest /lake, /lean --rollback, or manual fix |
| No backup files | Suggest git checkout as alternative |

## Related Commands

- `/lake` - Build with automatic error repair
- `/implement` - Work on specific task implementations
- `/task` - Create and manage tasks
