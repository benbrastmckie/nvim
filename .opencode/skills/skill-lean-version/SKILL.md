---
name: skill-lean-version
description: Manage Lean toolchain and Mathlib versions with interactive upgrade workflow
allowed-tools: Read, Edit, Bash
---

# Lean Version Skill (Direct Execution)

Direct execution skill for managing Lean toolchain and Mathlib versions. Checks for updates, performs upgrades with interactive guidance, downloads Mathlib cache, verifies builds, and provides rollback support.

This skill executes inline without spawning a subagent.

## Context References

Load on-demand using @-references:

**Always Load**:
- `@lean-toolchain` - Current project toolchain version
- `@lakefile.lean` - Current Mathlib dependency version

**Load for Error Recovery**:
- `@.opencode/context/core/patterns/mcp-tool-recovery.md` - MCP error handling patterns

---

## Execution

### Step 1: Parse Arguments

Extract flags from command input:
- `--check`: Display version status (default)
- `--upgrade`: Interactive upgrade workflow
- `--rollback`: Restore from backup
- `--dry-run`: Preview changes without applying

```bash
# Parse from command input
mode="check"
dry_run=false

for arg in "$@"; do
  case "$arg" in
    --check) mode="check" ;;
    --upgrade) mode="upgrade" ;;
    --rollback) mode="rollback" ;;
    --dry-run) dry_run=true ;;
  esac
done
```

---

### Step 2: Version Discovery

Discover current and available versions.

#### 2A: Current Project State

Read current configuration:

```bash
# Read current toolchain version
if [ -f lean-toolchain ]; then
  current_toolchain=$(cat lean-toolchain | sed 's/leanprover\/lean4://')
else
  echo "Error: lean-toolchain file not found."
  echo "This command must be run from a Lean project root."
  exit 1
fi

# Read current Mathlib version from lakefile.lean
if [ -f lakefile.lean ]; then
  # Extract version from: require mathlib ... @ "version"
  current_mathlib=$(grep -A2 'require mathlib' lakefile.lean | grep '@' | grep -o '"[^"]*"' | tail -1 | tr -d '"')
  if [ -z "$current_mathlib" ]; then
    current_mathlib="(not found)"
  fi
else
  echo "Error: lakefile.lean file not found."
  echo "This command must be run from a Lean project root."
  exit 1
fi
```

#### 2B: Available Versions

Query Mathlib master toolchain (primary reference for compatible versions):

```bash
# Fetch latest Mathlib master toolchain
latest_toolchain=$(curl -s --max-time 10 \
  https://raw.githubusercontent.com/leanprover-community/mathlib4/master/lean-toolchain \
  2>/dev/null | sed 's/leanprover\/lean4://')

if [ -z "$latest_toolchain" ]; then
  network_available=false
  latest_toolchain="(unable to fetch)"
else
  network_available=true
fi
```

**Error handling**: If network fails, set `network_available=false` and continue with current versions only.

---

### Step 3: Check Mode (Default)

If `mode="check"`:

Display version status:

```
Lean Version Status
===================

Current Configuration:
  Toolchain: {current_toolchain}
  Mathlib:   {current_mathlib}

{if network_available:}
Available:
  Mathlib master: {latest_toolchain}

{if current_toolchain == latest_toolchain:}
Already up to date.
{else:}
Update available: {current_toolchain} -> {latest_toolchain}
Run /lean --upgrade to begin upgrade workflow.
{endif}

{else:}
Unable to check for updates (network unavailable).
{endif}
```

Exit after display.

---

### Step 4: Upgrade Mode

If `mode="upgrade"`:

#### 4A: Pre-flight Checks

```bash
# Check network availability
if [ "$network_available" = false ]; then
  echo "Error: Cannot upgrade - unable to fetch latest versions."
  echo "Check network connectivity and try again."
  exit 1
fi

# Check if already up to date
if [ "$current_toolchain" = "$latest_toolchain" ]; then
  echo "Already up to date: $current_toolchain"
  echo "No upgrade needed."
  exit 0
fi
```

#### 4B: Display Upgrade Analysis

```
Lean Version Upgrade
====================

Current:  {current_toolchain}
Target:   {latest_toolchain}

Upgrade will:
1. Update lean-toolchain to {latest_toolchain}
2. Update lakefile.lean Mathlib dependency
3. Clean build artifacts (lake-manifest.json, .lake/)
4. Regenerate dependencies (lake update -R)
5. Download Mathlib cache (lake exe cache get)
6. Verify build (lake build Logos)

Backup files will be created for rollback support.
```

#### 4C: User Confirmation

Prompt user for confirmation:

```
[Version Selection]
Select upgrade action:
  1. Upgrade to {latest_toolchain} - Update to Mathlib master toolchain
  2. Cancel - Abort upgrade, keep current versions
```

**If user selects "Cancel"**:
```
Upgrade cancelled.
Current versions unchanged.
```
Exit.

#### 4D: Create Backups

```bash
echo ""
echo "Creating backups..."
cp lean-toolchain lean-toolchain.backup
cp lakefile.lean lakefile.lean.backup
if [ -f lake-manifest.json ]; then
  cp lake-manifest.json lake-manifest.json.backup
fi
echo "Backups created: lean-toolchain.backup, lakefile.lean.backup"
```

#### 4E: Dry-Run Preview

If `dry_run=true`:

```
Dry Run Preview
===============

Would update:
- lean-toolchain: {current_toolchain} -> {latest_toolchain}
- lakefile.lean: Mathlib @ {current_mathlib} -> @ {latest_toolchain}

Would execute:
1. rm -rf lake-manifest.json .lake
2. lake update -R
3. lake exe cache get
4. lake build Logos

No changes made (dry run mode).
```

Exit.

#### 4F: Update Configuration Files

**Update lean-toolchain** using Edit tool:

```json
{
  "file_path": "lean-toolchain",
  "old_string": "leanprover/lean4:{current_toolchain}",
  "new_string": "leanprover/lean4:{latest_toolchain}"
}
```

**Update lakefile.lean** using Edit tool:

Find the Mathlib require statement and update the version:

```json
{
  "file_path": "lakefile.lean",
  "old_string": "@ \"{current_mathlib}\"",
  "new_string": "@ \"{latest_toolchain}\""
}
```

**Alternative pattern** (if version is on same line as require):

```json
{
  "file_path": "lakefile.lean",
  "old_string": "@ \"{current_mathlib}\"",
  "new_string": "@ \"{latest_toolchain}\""
}
```

#### 4G: Clean and Regenerate

```bash
echo ""
echo "Cleaning build artifacts..."
rm -rf lake-manifest.json .lake

echo "Regenerating manifest (this may take a moment)..."
lake update -R

echo ""
echo "Downloading Mathlib cache..."
cache_result=$(lake exe cache get 2>&1)
cache_exit_code=$?

if [ $cache_exit_code -ne 0 ]; then
  echo "Warning: Cache download encountered issues."
  echo "Build may take longer. Continuing..."
fi
```

**Cache download retry** (if first attempt fails):

```bash
if [ $cache_exit_code -ne 0 ]; then
  echo "Retrying cache download..."
  sleep 2
  lake exe cache get
fi
```

#### 4H: Verify Build

```bash
echo ""
echo "Verifying build..."
build_output=$(lake build Logos 2>&1)
build_exit_code=$?

echo "$build_output"
```

#### 4I: Report Results

**If build succeeds** (`build_exit_code == 0`):

```
Upgrade Complete
================

Successfully upgraded:
  {current_toolchain} -> {latest_toolchain}

Files modified:
- lean-toolchain
- lakefile.lean
- lake-manifest.json (regenerated)

Build verification: PASSED

Backup files saved (.backup extension).
Run /lean --rollback if you need to revert.
```

**If build fails** (`build_exit_code != 0`):

```
Upgrade Partial
===============

Files updated:
  {current_toolchain} -> {latest_toolchain}

Build verification: FAILED

Build errors detected. Options:
1. Run /lake to attempt automatic error repair
2. Run /lean --rollback to restore previous versions
3. Fix errors manually and run lake build

Backup files available for rollback.
```

---

### Step 5: Rollback Mode

If `mode="rollback"`:

#### 5A: Check Backups Exist

```bash
if [ ! -f lean-toolchain.backup ]; then
  echo "Error: No lean-toolchain.backup found."
  echo "Cannot rollback - no previous upgrade detected."
  echo ""
  echo "Alternative: Use git to restore previous versions:"
  echo "  git checkout lean-toolchain lakefile.lean"
  exit 1
fi

if [ ! -f lakefile.lean.backup ]; then
  echo "Error: No lakefile.lean.backup found."
  echo "Cannot rollback - backup incomplete."
  exit 1
fi
```

#### 5B: Display Rollback Info

```bash
backup_toolchain=$(cat lean-toolchain.backup | sed 's/leanprover\/lean4://')
current_toolchain=$(cat lean-toolchain | sed 's/leanprover\/lean4://')

echo "Rollback Information"
echo "===================="
echo ""
echo "Current:  $current_toolchain"
echo "Restore:  $backup_toolchain"
```

#### 5C: User Confirmation

Prompt user for confirmation:

```
[Rollback Confirmation]
Confirm rollback to previous versions?
  1. Yes, rollback - Restore backup files and rebuild
  2. Cancel - Keep current versions
```

**If user cancels**: Exit.

#### 5D: Execute Rollback

```bash
echo ""
echo "Restoring backups..."
cp lean-toolchain.backup lean-toolchain
cp lakefile.lean.backup lakefile.lean

echo "Cleaning build artifacts..."
rm -rf lake-manifest.json .lake

echo "Regenerating manifest..."
lake update -R

echo ""
echo "Downloading cache..."
lake exe cache get

echo ""
echo "Verifying build..."
build_output=$(lake build Logos 2>&1)
build_exit_code=$?

echo "$build_output"
```

#### 5E: Report Results

**If build succeeds**:

```
Rollback Complete
=================

Restored to: {backup_toolchain}

Build verification: PASSED

Previous configuration restored successfully.
Backup files retained for reference.
```

**If build fails**:

```
Rollback Complete
=================

Restored to: {backup_toolchain}

Build verification: FAILED

Build issues remain after rollback.
Consider running /lake for automatic error repair.
```

---

## Error Handling

### Network Failure

If unable to fetch latest versions:
- In check mode: Show current versions, note "Unable to check for updates"
- In upgrade mode: Abort with error, suggest checking connectivity

### File Not Found

If lean-toolchain or lakefile.lean missing:
- Abort with error
- Suggest running from Lean project root

### Cache Download Failure

If `lake exe cache get` fails:
- Retry once after 2-second delay
- If still fails, warn user and continue
- Build will take longer but should succeed

### Build Failure After Upgrade

If `lake build Logos` fails after upgrade:
- Display build errors
- Suggest three recovery paths:
  1. Run /lake for automatic repair
  2. Run /lean --rollback
  3. Manual fixes

### Backup Not Found

If rollback requested but no backups:
- Abort with error
- Suggest git checkout as alternative

---

## Example Execution Flows

### Check Mode (Default)

```bash
# User runs: /lean

# Output:
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

### Successful Upgrade

```bash
# User runs: /lean --upgrade

# Output:
Lean Version Upgrade
====================

Current:  v4.27.0-rc1
Target:   v4.29.0-rc2

Upgrade will:
1. Update lean-toolchain to v4.29.0-rc2
2. Update lakefile.lean Mathlib dependency
3. Clean build artifacts (lake-manifest.json, .lake/)
4. Regenerate dependencies (lake update -R)
5. Download Mathlib cache (lake exe cache get)
6. Verify build (lake build Logos)

Backup files will be created for rollback support.

# Prompt appears:
[Version Selection]
Select upgrade action:
  1. Upgrade to v4.29.0-rc2 - Update to Mathlib master toolchain
  2. Cancel - Abort upgrade, keep current versions

# User selects option 1

Creating backups...
Backups created: lean-toolchain.backup, lakefile.lean.backup

Cleaning build artifacts...
Regenerating manifest (this may take a moment)...
Downloading Mathlib cache...
Verifying build...

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

### Dry Run

```bash
# User runs: /lean --upgrade --dry-run

# Shows analysis, prompts for confirmation, then:
Dry Run Preview
===============

Would update:
- lean-toolchain: v4.27.0-rc1 -> v4.29.0-rc2
- lakefile.lean: Mathlib @ v4.27.0-rc1 -> @ v4.29.0-rc2

Would execute:
1. rm -rf lake-manifest.json .lake
2. lake update -R
3. lake exe cache get
4. lake build Logos

No changes made (dry run mode).
```

### Rollback After Failed Upgrade

```bash
# User runs: /lean --rollback

# Output:
Rollback Information
====================

Current:  v4.29.0-rc2
Restore:  v4.27.0-rc1

# Prompt appears:
[Rollback Confirmation]
Confirm rollback to previous versions?
  1. Yes, rollback - Restore backup files and rebuild
  2. Cancel - Keep current versions

# User selects option 1

Restoring backups...
Cleaning build artifacts...
Regenerating manifest...
Downloading cache...
Verifying build...

Rollback Complete
=================

Restored to: v4.27.0-rc1

Build verification: PASSED

Previous configuration restored successfully.
```

---

## Safety Measures

### Configuration Backup

Before any modification:
- `lean-toolchain` -> `lean-toolchain.backup`
- `lakefile.lean` -> `lakefile.lean.backup`
- `lake-manifest.json` -> `lake-manifest.json.backup` (if exists)

### User Confirmation

All modifications require explicit user confirmation.

### Dry-Run Mode

Preview all changes with `--dry-run` before applying.

### Git Safety

Git provides additional recovery:
```bash
git checkout lean-toolchain lakefile.lean
```

### Build Verification

Every upgrade/rollback ends with build verification to ensure project integrity.
