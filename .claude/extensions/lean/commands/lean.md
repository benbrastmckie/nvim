---
description: Manage Lean toolchain and Mathlib versions
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
argument-hint: [check|upgrade|rollback] [--dry-run] [--version VERSION]
---

# /lean Command

Manage Lean toolchain and Mathlib versions. Provides status display, interactive upgrades with backup, and rollback capability. Complements /lake (build management) with version management.

## Syntax

```
/lean [mode] [options]
```

## Modes

| Mode | Description |
|------|-------------|
| `check` (default) | Show current versions and available updates |
| `upgrade` | Interactively upgrade toolchain and Mathlib |
| `rollback` | Revert to a previous version from backup |

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--dry-run` | Preview changes without applying | false |
| `--version VERSION` | Target specific version for upgrade | (latest) |

## Execution

**EXECUTE NOW**: Follow these steps in sequence.

### STEP 1: Parse Arguments

**EXECUTE NOW**: Parse the command arguments to extract mode and flags.

```
# Default values
mode="check"
dry_run=false
target_version=""

# Parse from $ARGUMENTS
# First non-flag argument is mode (check, upgrade, rollback)
# --dry-run sets dry_run=true
# --version or --version=X sets target_version
```

**On success**: **IMMEDIATELY CONTINUE** to STEP 2.

---

### STEP 2: Route to Mode

Based on parsed mode:

- `check` -> **IMMEDIATELY CONTINUE** to STEP 3A (Check Mode)
- `upgrade` -> **IMMEDIATELY CONTINUE** to STEP 3B (Upgrade Mode)
- `rollback` -> **IMMEDIATELY CONTINUE** to STEP 3C (Rollback Mode)

---

### STEP 3A: Check Mode

**EXECUTE NOW**: Display current version status.

1. Read current toolchain:
   ```bash
   cat lean-toolchain 2>/dev/null || echo "Not found"
   ```

2. Read Mathlib version from lakefile.lean:
   ```bash
   grep -oP 'mathlib.*@\s*"\K[^"]+' lakefile.lean 2>/dev/null || echo "Not found"
   ```

3. List installed toolchains:
   ```bash
   elan show 2>/dev/null || echo "elan not available"
   ```

4. Check for backup files:
   ```bash
   ls -la .lean-version-backup/ 2>/dev/null || echo "No backups"
   ```

5. Display report:
   ```
   Lean Version Status
   ===================

   Current Configuration:
   - Toolchain: {toolchain_version}
   - Mathlib: {mathlib_version}

   Installed Toolchains:
   {elan_show_output}

   Backups Available:
   {backup_list or "None"}

   Tip: Run /lean upgrade to update to the latest version.
   ```

**STOP** - execution complete.

---

### STEP 3B: Upgrade Mode

**EXECUTE NOW**: Perform interactive upgrade.

1. **Read current state**:
   - Current toolchain from `lean-toolchain`
   - Current Mathlib from `lakefile.lean`

2. **If --dry-run flag set**:
   - Show what would change
   - Skip to dry-run report
   - **STOP**

3. **Create backup**:
   ```bash
   mkdir -p .lean-version-backup
   timestamp=$(date +%Y%m%d_%H%M%S)
   cp lean-toolchain ".lean-version-backup/lean-toolchain.$timestamp"
   cp lakefile.lean ".lean-version-backup/lakefile.lean.$timestamp"
   cp lake-manifest.json ".lean-version-backup/lake-manifest.json.$timestamp" 2>/dev/null
   ```

4. **Prompt for upgrade confirmation** via AskUserQuestion:
   ```json
   {
     "question": "Upgrade Lean toolchain and Mathlib?",
     "header": "Version Upgrade",
     "multiSelect": false,
     "options": [
       {"label": "Yes, upgrade to latest", "description": "Update toolchain and Mathlib to latest stable"},
       {"label": "No, keep current version", "description": "Cancel upgrade"}
     ]
   }
   ```

5. **If user confirms**:
   - Update `lean-toolchain` with target version
   - Update `lakefile.lean` Mathlib pin
   - Run `lake update`
   - Run `lake exe cache get`

6. **Report result**:
   ```
   Lean Upgrade Complete
   =====================

   Changes Applied:
   - Toolchain: {old} -> {new}
   - Mathlib: {old} -> {new}

   Post-upgrade commands executed:
   - lake update: {status}
   - lake exe cache get: {status}

   Backup saved to: .lean-version-backup/

   Next: Run /lake to verify the build passes.
   ```

**STOP** - execution complete.

---

### STEP 3C: Rollback Mode

**EXECUTE NOW**: Restore from backup.

1. **List available backups**:
   ```bash
   ls -t .lean-version-backup/lean-toolchain.* 2>/dev/null | head -5
   ```

2. **If no backups exist**:
   ```
   No backups available.
   Tip: Git can also restore previous versions:
     git checkout lean-toolchain lakefile.lean
   ```
   **STOP**

3. **Prompt for backup selection** via AskUserQuestion:
   - Show available backup timestamps
   - Let user select which to restore

4. **Restore selected backup**:
   - Copy backup files back to project root
   - Run `lake update`
   - Run `lake exe cache get`

5. **Report result**:
   ```
   Lean Rollback Complete
   ======================

   Restored from backup: {timestamp}

   Current Configuration:
   - Toolchain: {version}
   - Mathlib: {version}

   Post-rollback commands executed:
   - lake update: {status}
   - lake exe cache get: {status}

   Next: Run /lake to verify the build passes.
   ```

**STOP** - execution complete.

---

## Examples

### Check Current Versions

```bash
# Show current toolchain and Mathlib versions
/lean
/lean check
```

### Preview Upgrade

```bash
# See what would change without applying
/lean --dry-run upgrade
```

### Upgrade to Latest

```bash
# Interactively upgrade with confirmation
/lean upgrade
```

### Upgrade to Specific Version

```bash
# Upgrade to a specific version
/lean upgrade --version v4.28.0
```

### Rollback

```bash
# Restore previous version from backup
/lean rollback
```

## Output Examples

### Check Output

```
Lean Version Status
===================

Current Configuration:
- Toolchain: leanprover/lean4:v4.27.0-rc1
- Mathlib: v4.27.0-rc1

Installed Toolchains:
  leanprover/lean4:v4.27.0-rc1 (active)
  leanprover/lean4:v4.22.0
  leanprover/lean4:v4.14.0

Backups Available:
- 20260226_103045 (lean-toolchain, lakefile.lean, lake-manifest.json)

Tip: Run /lean upgrade to update to the latest version.
```

### Upgrade Dry-Run Output

```
Lean Upgrade Preview (Dry Run)
==============================

Current -> Target:
- Toolchain: leanprover/lean4:v4.27.0-rc1 -> leanprover/lean4:v4.28.0
- Mathlib: v4.27.0-rc1 -> v4.28.0

Files that would be modified:
- lean-toolchain
- lakefile.lean

Commands that would run:
- lake update
- lake exe cache get

No changes made (dry run mode).
```

### Upgrade Success Output

```
Lean Upgrade Complete
=====================

Changes Applied:
- Toolchain: leanprover/lean4:v4.27.0-rc1 -> leanprover/lean4:v4.28.0
- Mathlib: v4.27.0-rc1 -> v4.28.0

Post-upgrade commands executed:
- lake update: success
- lake exe cache get: success (downloaded 1.2 GB)

Backup saved to: .lean-version-backup/

Next: Run /lake to verify the build passes.
```

## Safety

- Backups are created automatically before upgrades
- `--dry-run` previews all changes without modifying files
- Rollback available if upgrade causes issues
- Git provides additional recovery: `git checkout lean-toolchain lakefile.lean`

## Troubleshooting

### Network Timeout During Upgrade

If `lake update` or `lake exe cache get` fails:
1. Check network connectivity
2. Retry: `/lean upgrade`
3. Or rollback: `/lean rollback`

### Build Fails After Upgrade

1. Run `/lake` to see errors
2. If incompatible: `/lean rollback`
3. Try different version: `/lean upgrade --version v4.X.X`

### No Backups Available

If rollback needed but no `.lean-version-backup/`:
```bash
git checkout lean-toolchain lakefile.lean
lake update
lake exe cache get
```
