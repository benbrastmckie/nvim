#!/usr/bin/env bash
# lean-src-roots.sh -- resolve the Lean source roots for THIS repo, so no taught snippet has to
# hardcode a literal directory name that only happens to be correct in one consuming repo.
#
# WHY THIS EXISTS: a taught verification snippet that names a literal source root (historically
# `Theories/`) scans NOTHING and reports a clean result BY CONSTRUCTION in any repo where that
# literal does not exist -- a verification instrument that cannot report failure. This script is
# the single place that derives the real roots, so every snippet calls it instead of each
# embedding its own path guess.
#
# PRECEDENCE: `lakefile.toml` is authoritative whenever it exists. `LEAN_SRC_ROOTS` (a
# whitespace-separated list of paths, relative to the repo root unless already absolute) is
# consulted ONLY when no `lakefile.toml` is found (for example a repo with only a
# `lakefile.lean`). If a `lakefile.toml` exists, `LEAN_SRC_ROOTS` is ignored and a stderr notice
# says so -- this keeps exactly one convention live at a time, never two competing ones.
#
# SOURCE OF TRUTH (lakefile.toml path): every `[[lean_lib]]` entry, by default (pass
# --default-targets to restrict to the package's declared `defaultTargets`). Lake's own defaults
# apply where a field is absent: `srcDir` defaults to "." and `roots` defaults to `[name]`. For
# each resolved root module, this script emits BOTH candidate forms and keeps whichever exist on
# disk: `<srcDir>/<Root-with-dots-as-slashes>/` (a directory of submodules) and
# `<srcDir>/<Root-with-dots-as-slashes>.lean` (a single "import-all" file). A `globs` entry of the
# form `Foo.+` or `Foo.*` is mapped to the same directory candidate as root `Foo` (best-effort);
# any other glob form is treated as a bare root name too, with a stderr note that it is
# unsupported and may not resolve correctly.
#
# LOUD FAILURE (this is the load-bearing contract -- a missing or empty result must never look
# like a clean scan): this script exits non-zero and names, on stderr, every root path it tried,
# whenever ANY of the following hold:
#   - no lakefile.toml and no LEAN_SRC_ROOTS                      (exit 65)
#   - lakefile.toml exists but cannot be parsed (malformed TOML)  (exit 66)
#   - python3 is unavailable to parse lakefile.toml               (exit 66)
#   - lakefile.toml (after any --default-targets filter) declares
#     zero [[lean_lib]] entries                                   (exit 67)
#   - every candidate root path (from lakefile.toml OR from
#     LEAN_SRC_ROOTS) is missing on disk                          (exit 68)
#   - every existing root path holds zero *.lean files            (exit 69)
# A bad CLI argument is a usage error                              (exit 64)
#
# TAUGHT CONSUMPTION SHAPE -- callers MUST capture the exit code directly off the command
# substitution, never off a `mapfile < <(...)` process substitution (which discards it):
#
#   lean_roots_raw="$(bash .claude/scripts/lean-src-roots.sh)" || {
#     echo "lean-src-roots.sh failed (exit $?); aborting -- cannot verify without real source roots" >&2
#     exit 1
#   }
#   mapfile -t lean_roots <<< "$lean_roots_raw"
#
# Usage:
#   lean-src-roots.sh [--default-targets] [--lakefile PATH]
#
# Output (on success, exit 0): one existing source-root path per line, relative to the repo root
# (as resolved by `git rev-parse --show-toplevel`, or the current directory when not in a git
# work tree).

set -uo pipefail

SCRIPT_NAME="lean-src-roots.sh"

print_help() {
  cat <<'EOF'
Usage: lean-src-roots.sh [--default-targets] [--lakefile PATH]

Resolve this repo's Lean source roots from lakefile.toml (or LEAN_SRC_ROOTS when no
lakefile.toml exists) and print one existing root path per line, relative to the repo root.
Exits non-zero and names every root it tried when nothing resolves. See the header comment in
this file for the full precedence, resolution rule, and exit-code table.
EOF
}

DEFAULT_TARGETS_ONLY=0
LAKEFILE_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --default-targets)
      DEFAULT_TARGETS_ONLY=1
      shift
      ;;
    --lakefile)
      if [ $# -lt 2 ]; then
        echo "$SCRIPT_NAME: --lakefile requires a PATH argument" >&2
        exit 64
      fi
      LAKEFILE_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "$SCRIPT_NAME: unknown argument: $1" >&2
      print_help >&2
      exit 64
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LAKEFILE="${LAKEFILE_OVERRIDE:-$REPO_ROOT/lakefile.toml}"

# TRIED_PATHS accumulates every candidate this run considered, so a failure message can name all
# of them rather than just the last one checked.
TRIED_PATHS=()
EXISTING_ROOTS=()

add_candidate() {
  # add_candidate <path-relative-to-repo-root> -- records the candidate as tried, and if it
  # exists on disk (as a directory or a file), records it as an existing root too. Deduplicates
  # against both arrays.
  local rel="$1"
  local already
  for already in "${TRIED_PATHS[@]:-}"; do
    [ "$already" = "$rel" ] && return 0
  done
  TRIED_PATHS+=("$rel")
  if [ -d "$REPO_ROOT/$rel" ] || [ -f "$REPO_ROOT/$rel" ]; then
    EXISTING_ROOTS+=("$rel")
  fi
}

if [ -f "$LAKEFILE" ]; then
  SOURCE_DESC="lakefile.toml at '$LAKEFILE'"
  if [ -n "${LEAN_SRC_ROOTS:-}" ]; then
    echo "$SCRIPT_NAME: lakefile.toml found at '$LAKEFILE'; ignoring LEAN_SRC_ROOTS (lakefile.toml takes precedence, see header)" >&2
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: python3 is required to parse '$LAKEFILE' and is not on PATH" >&2
    exit 66
  fi

  CANDIDATES_TSV="$(python3 - "$LAKEFILE" "$DEFAULT_TARGETS_ONLY" <<'PYEOF'
import re
import sys
import tomllib

lakefile_path, default_targets_only = sys.argv[1], sys.argv[2] == "1"

try:
    with open(lakefile_path, "rb") as fh:
        cfg = tomllib.load(fh)
except OSError as e:
    print(f"lean-src-roots.sh: cannot read {lakefile_path}: {e}", file=sys.stderr)
    raise SystemExit(66)
except tomllib.TOMLDecodeError as e:
    print(f"lean-src-roots.sh: cannot parse {lakefile_path} as TOML: {e}", file=sys.stderr)
    raise SystemExit(66)

libs = cfg.get("lean_lib", [])
default_targets = set(cfg.get("defaultTargets", []))

if default_targets_only:
    libs = [lib for lib in libs if lib.get("name") in default_targets]

if not libs:
    scope = "declared defaultTargets" if default_targets_only else "[[lean_lib]] entries"
    print(f"lean-src-roots.sh: {lakefile_path} declares zero {scope}", file=sys.stderr)
    raise SystemExit(67)

glob_re = re.compile(r'^(.*)\.[+*]$')
for lib in libs:
    name = lib["name"]
    src_dir = lib.get("srcDir", ".")
    roots = lib.get("roots", [name])
    for root in roots:
        print(f"{src_dir}\t{root}")
    for glob in lib.get("globs", []):
        m = glob_re.match(glob)
        if m:
            print(f"{src_dir}\t{m.group(1)}")
        else:
            print(f"lean-src-roots.sh: unsupported globs form '{glob}' in lib '{name}'; "
                  f"treating it as a bare root name, best-effort", file=sys.stderr)
            print(f"{src_dir}\t{glob}")
PYEOF
  )"
  PY_EXIT=$?
  if [ $PY_EXIT -ne 0 ]; then
    exit $PY_EXIT
  fi

  while IFS=$'\t' read -r src_dir root; do
    [ -z "$root" ] && continue
    module_path="${root//./\/}"
    if [ "$src_dir" = "." ] || [ -z "$src_dir" ]; then
      base="$module_path"
    else
      base="$src_dir/$module_path"
    fi
    add_candidate "$base"
    add_candidate "$base.lean"
  done <<< "$CANDIDATES_TSV"
else
  SOURCE_DESC="LEAN_SRC_ROOTS"
  if [ -z "${LEAN_SRC_ROOTS:-}" ]; then
    echo "$SCRIPT_NAME: no lakefile.toml at '$LAKEFILE' and LEAN_SRC_ROOTS is unset; cannot resolve Lean source roots" >&2
    exit 65
  fi
  for token in $LEAN_SRC_ROOTS; do
    add_candidate "$token"
  done
fi

if [ ${#EXISTING_ROOTS[@]} -eq 0 ]; then
  {
    echo "$SCRIPT_NAME: no existing source root found (source: $SOURCE_DESC). Tried:"
    printf '  %s\n' "${TRIED_PATHS[@]}"
  } >&2
  exit 68
fi

LEAN_FILE_COUNT=0
for root in "${EXISTING_ROOTS[@]}"; do
  if [ -d "$REPO_ROOT/$root" ]; then
    count="$(find "$REPO_ROOT/$root" -type f -name '*.lean' | wc -l)"
    LEAN_FILE_COUNT=$((LEAN_FILE_COUNT + count))
  elif [ -f "$REPO_ROOT/$root" ] && [[ "$root" == *.lean ]]; then
    LEAN_FILE_COUNT=$((LEAN_FILE_COUNT + 1))
  fi
done

if [ "$LEAN_FILE_COUNT" -eq 0 ]; then
  {
    echo "$SCRIPT_NAME: resolved root(s) exist but contain zero .lean files (source: $SOURCE_DESC). Roots checked:"
    printf '  %s\n' "${EXISTING_ROOTS[@]}"
  } >&2
  exit 69
fi

printf '%s\n' "${EXISTING_ROOTS[@]}"
