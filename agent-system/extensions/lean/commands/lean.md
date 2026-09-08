---
description: Manage Lean toolchain and Mathlib versions
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
argument-hint: "[check|upgrade|rollback|doctor] [--dry-run] [--version VERSION]"
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
| `doctor` | Probe the Comparator environment: binary presence + C3 `lean4export` version match |

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
# First non-flag argument is mode (check, upgrade, rollback, doctor)
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
- `doctor` -> **IMMEDIATELY CONTINUE** to STEP 3D (Doctor Mode)

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

### STEP 3D: Doctor Mode

**EXECUTE NOW**: Probe the Comparator environment. This mode only reports on the environment —
it does not install or fix anything. See
`context/project/lean4/tools/comparator-guide.md` for what a green Comparator result does and
does not certify.

1. **Resolve each binary**, reusing `lean-comparator-run.sh`'s exact override-var names and
   resolution order (override var first, `command -v` fallback; a set-but-non-executable override
   is a resolution FAILURE, not a silent fall-through to PATH):
   ```bash
   resolve_binary() {
     local override_var="$1" path_name="$2" override_val
     override_val="${!override_var:-}"
     if [ -n "$override_val" ]; then
       if [ -x "$override_val" ]; then
         echo "$override_val"
         return 0
       fi
       return 1
     fi
     command -v "$path_name" 2>/dev/null
   }
   ```

   | Binary | Override env var | Required |
   |--------|-------------------|----------|
   | `comparator` | `COMPARATOR_BIN` | yes |
   | `landrun` | `COMPARATOR_LANDRUN` | yes |
   | `lean4export` | `COMPARATOR_LEAN4EXPORT` | yes |
   | `nanoda_bin` | `COMPARATOR_NANODA` | no (only used with `--enable-nanoda`) |

2. **Check the C3 version-match constraint for `lean4export` only** — it must be built against
   the *target project's* Lean toolchain, not Comparator's own. `lean4export` has no
   `--version`/`--help` flag and real binaries observed are statically linked with no
   elan-toolchain path visible to `ldd`, so binary introspection is not used. Instead, walk up at
   most 5 parent directories from the resolved binary's realpath looking for a sibling
   `lean-toolchain` file, and diff its content against the target project's own `lean-toolchain`:
   ```bash
   find_lean_toolchain_upward() {
     local dir="$1" max_levels="$2" level=0
     while [ "$level" -le "$max_levels" ]; do
       if [ -f "$dir/lean-toolchain" ]; then
         echo "$dir/lean-toolchain"
         return 0
       fi
       [ "$dir" = "/" ] && break
       dir="$(dirname "$dir")"
       level=$((level + 1))
     done
     return 1
   }

   check_lean4export_version() {
     local lean4export_bin="$1" target_toolchain_file="$2"
     local bin_path resolved_dir found_file found_toolchain target_toolchain

     bin_path="$(readlink -f "$lean4export_bin")"
     resolved_dir="$(dirname "$bin_path")"
     found_file="$(find_lean_toolchain_upward "$resolved_dir" 5 || true)"

     if [ -z "$found_file" ]; then
       echo "UNKNOWN (cannot verify)"
       echo "  reason: no lean-toolchain found within 5 parent directories of $bin_path"
       echo "  remedy: confirm manually that lean4export at $bin_path was built against the target project's toolchain"
       return
     fi

     found_toolchain="$(tr -d '\n' < "$found_file")"

     if [ ! -f "$target_toolchain_file" ]; then
       echo "UNKNOWN (cannot verify)"
       echo "  reason: target project has no lean-toolchain file at $target_toolchain_file"
       return
     fi
     target_toolchain="$(tr -d '\n' < "$target_toolchain_file")"

     if [ "$found_toolchain" = "$target_toolchain" ]; then
       echo "matched"
       echo "  lean4export toolchain ($found_file): $found_toolchain"
       echo "  target project toolchain ($target_toolchain_file): $target_toolchain"
     else
       echo "mismatched"
       echo "  lean4export toolchain ($found_file): $found_toolchain"
       echo "  target project toolchain ($target_toolchain_file): $target_toolchain"
       echo "  remedy: confirm manually that lean4export at $bin_path was built against $target_toolchain, or install a matching lean4export and set COMPARATOR_LEAN4EXPORT"
     fi
   }
   ```
   **`UNKNOWN (cannot verify)` is never a pass.** Never report OK/pass/green for that outcome.

3. **Report all four binaries plus the version verdict**:
   ```bash
   echo "Comparator Environment Doctor"
   echo "=============================="
   echo ""

   for pair in "comparator:COMPARATOR_BIN" "landrun:COMPARATOR_LANDRUN" "lean4export:COMPARATOR_LEAN4EXPORT"; do
     name="${pair%%:*}"
     var="${pair##*:}"
     path="$(resolve_binary "$var" "$name" || true)"
     if [ -n "$path" ]; then
       echo "$name: present ($(readlink -f "$path")) [override: $var]"
     else
       echo "$name: MISSING [override: $var]"
     fi
   done

   nanoda_path="$(resolve_binary COMPARATOR_NANODA nanoda_bin || true)"
   if [ -n "$nanoda_path" ]; then
     echo "nanoda_bin: present ($(readlink -f "$nanoda_path")) [override: COMPARATOR_NANODA] (optional)"
   else
     echo "nanoda_bin: not found [override: COMPARATOR_NANODA] (optional)"
   fi

   echo ""
   echo "lean4export version check (C3):"
   lean4export_path="$(resolve_binary COMPARATOR_LEAN4EXPORT lean4export || true)"
   if [ -z "$lean4export_path" ]; then
     echo "  not applicable — lean4export is absent"
   else
     check_lean4export_version "$lean4export_path" "lean-toolchain" | sed 's/^/  /'
   fi
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

### Doctor

```bash
# Probe the Comparator environment (binaries + C3 version match)
/lean doctor
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

### Doctor Output

All three acceptance states, shown as the doctor would report them (state C, present-but-mismatched, is the one that matters most — see `context/project/lean4/tools/comparator-guide.md`):

**State: all present, `lean4export` version matched**
```
Comparator Environment Doctor
==============================

comparator: present (/home/user/.nix-profile/bin/comparator) [override: COMPARATOR_BIN]
landrun: present (/home/user/.nix-profile/bin/landrun) [override: COMPARATOR_LANDRUN]
lean4export: present (/home/user/checkout/.lake/build/bin/lean4export) [override: COMPARATOR_LEAN4EXPORT]
nanoda_bin: not found [override: COMPARATOR_NANODA] (optional)

lean4export version check (C3):
  matched
    lean4export toolchain (/home/user/checkout/lean-toolchain): leanprover/lean4:v4.27.0-rc1
    target project toolchain (lean-toolchain): leanprover/lean4:v4.27.0-rc1
```

**State: a binary missing**
```
Comparator Environment Doctor
==============================

comparator: present (/home/user/.nix-profile/bin/comparator) [override: COMPARATOR_BIN]
landrun: present (/home/user/.nix-profile/bin/landrun) [override: COMPARATOR_LANDRUN]
lean4export: MISSING [override: COMPARATOR_LEAN4EXPORT]
nanoda_bin: not found [override: COMPARATOR_NANODA] (optional)

lean4export version check (C3):
  not applicable — lean4export is absent
```

**State: present but mismatched — the state that matters**
```
Comparator Environment Doctor
==============================

comparator: present (/home/user/.nix-profile/bin/comparator) [override: COMPARATOR_BIN]
landrun: present (/home/user/.nix-profile/bin/landrun) [override: COMPARATOR_LANDRUN]
lean4export: present (/home/user/other-checkout/.lake/build/bin/lean4export) [override: COMPARATOR_LEAN4EXPORT]
nanoda_bin: not found [override: COMPARATOR_NANODA] (optional)

lean4export version check (C3):
  mismatched
    lean4export toolchain (/home/user/other-checkout/lean-toolchain): leanprover/lean4:v4.34.0-rc2
    target project toolchain (lean-toolchain): leanprover/lean4:v4.27.0-rc1
    remedy: confirm manually that lean4export at /home/user/other-checkout/.lake/build/bin/lean4export was built against leanprover/lean4:v4.27.0-rc1, or install a matching lean4export and set COMPARATOR_LEAN4EXPORT
```

A fourth outcome, `UNKNOWN (cannot verify)` (no `lean-toolchain` discoverable within the 5-level
walk-up bound), is never rendered as a pass — see `comparator-guide.md`'s version-coupling
section.

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
