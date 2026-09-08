---
name: skill-lean-version
description: Manage Lean toolchain and Mathlib versions with backup, upgrade, and rollback support
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Lean Version Management Skill (Direct Execution)

Direct execution skill for managing Lean toolchain and Mathlib versions. Provides check, upgrade, rollback, doctor, and dry-run modes. Creates backups before upgrades and supports interactive user confirmation.

This skill executes inline without spawning a subagent.

## Execution

### Step 1: Parse Arguments

Extract mode and flags:
- First non-flag argument: Mode (`check`, `upgrade`, `rollback`, `doctor`) - default: `check`
- `--dry-run`: Preview mode
- `--version VERSION`: Target version for upgrade

```bash
mode="check"
dry_run=false
target_version=""

for arg in "$@"; do
  case "$arg" in
    check|upgrade|rollback|doctor) mode="$arg" ;;
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
- **doctor** -> Probe Comparator environment (binary presence + C3 lean4export version match)

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

## Doctor Mode

Probe the Comparator environment: report presence of the four Comparator binaries (reusing the
exact override env-var names from `scripts/lean-comparator-run.sh`'s `resolve_binary()`) and
check the C3 version-coupling constraint for `lean4export` — that it was built against the
*target project's* Lean toolchain, not Comparator's own. See
`context/project/lean4/tools/comparator-guide.md` for what a green Comparator result does and
does not certify; this mode only reports on the environment, it does not fix it.

### Binary Resolution

Reuses `lean-comparator-run.sh`'s exact override-var names and resolution order (override var
first, `command -v` fallback; a set-but-non-executable override is a resolution FAILURE, not a
silent fall-through to PATH):

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

### C3 Version-Match Check (lean4export only)

`lean4export` has no `--version`/`--help` flag, and real Comparator binaries observed on this
host are statically linked with no elan-toolchain path visible to `ldd` — binary introspection
does not work as a mechanism. The one technique that survives is a **bounded (5-level) directory
walk-up** from the resolved binary's realpath, looking for a sibling `lean-toolchain` file,
diffed against the target project's own `lean-toolchain`:

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

**`UNKNOWN (cannot verify)` is never a pass.** It means no `lean-toolchain` could be found within
the walk-up bound (or the target project itself has none) — not that lean4export is confirmed
compatible. Never report OK/pass/green for this outcome.

### Doctor Report

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
