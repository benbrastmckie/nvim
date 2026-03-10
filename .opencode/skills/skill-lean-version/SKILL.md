---
name: skill-lean-version
description: Manage Lean toolchain and Mathlib versions with backup, upgrade, and rollback support
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Lean Version Management Skill (Direct Execution)

Direct execution skill for managing Lean toolchain and Mathlib versions. Provides check, upgrade, rollback, and dry-run modes. Creates backups before upgrades and supports interactive user confirmation.

This skill executes inline without spawning a subagent.

## Execution

### Step 1: Parse Arguments

Extract mode and flags:
- First non-flag argument: Mode (`check`, `upgrade`, `rollback`) - default: `check`
- `--dry-run`: Preview mode
- `--version VERSION`: Target version for upgrade

```bash
mode="check"
dry_run=false
target_version=""

for arg in "$@"; do
  case "$arg" in
    check|upgrade|rollback) mode="$arg" ;;
    --dry-run) dry_run=true ;;
    --version=*) target_version="${arg#*=}" ;;
  esac
done
```

---

### Step 2: Read Current State

```bash
# Read current toolchain
if [ -f "lean-toolchain" ]; then
  current_toolchain=$(cat lean-toolchain | tr -d '\n')
else
  current_toolchain="not found"
fi

# Read current Mathlib version from lakefile.lean
if [ -f "lakefile.lean" ]; then
  current_mathlib=$(grep -oP 'mathlib.*@\s*"\K[^"]+' lakefile.lean 2>/dev/null || echo "not found")
else
  current_mathlib="not found"
fi
```

---

### Step 3: Route by Mode

- **check** -> Display current version status
- **upgrade** -> Perform interactive upgrade with backup
- **rollback** -> Restore from a previous backup

---

## Check Mode

Display current version status:

```
Lean Version Status
===================

Current Configuration:
- Toolchain: {current_toolchain}
- Mathlib: {current_mathlib}

Installed Toolchains:
{elan_status}

Backups Available:
{backup_list}
```

---

## Upgrade Mode

### Create Backup

```bash
mkdir -p .lean-version-backup
timestamp=$(date +%Y%m%d_%H%M%S)
cp lean-toolchain ".lean-version-backup/lean-toolchain.$timestamp"
cp lakefile.lean ".lean-version-backup/lakefile.lean.$timestamp"
```

### Apply Changes

```bash
echo "$new_toolchain" > lean-toolchain
sed -i "s|@ \"v[0-9.]*\(-rc[0-9]*\)\?\"|@ \"$new_mathlib\"|g" lakefile.lean
```

### Post-Upgrade

```bash
lake update
lake exe cache get
```

---

## Rollback Mode

### List Backups

```bash
timestamps=$(ls .lean-version-backup/lean-toolchain.* 2>/dev/null | \
  sed 's|.*/lean-toolchain\.||' | sort -r | head -5)
```

### Restore

```bash
cp ".lean-version-backup/lean-toolchain.$selected_timestamp" lean-toolchain
cp ".lean-version-backup/lakefile.lean.$selected_timestamp" lakefile.lean
lake update
lake exe cache get
```

---

## Safety Measures

### Backup Before Changes
- Always create timestamped backup before upgrade
- Backup includes: `lean-toolchain`, `lakefile.lean`, `lake-manifest.json`
- Location: `.lean-version-backup/`
- Retention: Keep 3 most recent

### Dry-Run Support
- `--dry-run` previews all changes without applying

### User Confirmation
- Upgrade mode requires explicit confirmation via AskUserQuestion
