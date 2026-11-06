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
# PRECEDENCE: a `lakefile.toml` is authoritative whenever it exists. When no `lakefile.toml`
# exists, a `lakefile.lean` is authoritative instead, whenever IT exists (this is the second
# lakefile format Lake supports, and some projects -- e.g. this repo's own consuming project --
# use it instead of `lakefile.toml`). `LEAN_SRC_ROOTS` (a whitespace-separated list of paths,
# relative to the repo root unless already absolute) is consulted ONLY when NEITHER lakefile is
# found. If either lakefile exists, `LEAN_SRC_ROOTS` is ignored and a stderr notice says so --
# this keeps exactly one convention live at a time, never two competing ones.
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
# SOURCE OF TRUTH (lakefile.lean path): every `lean_lib NAME where ... ` declaration, found by a
# best-effort regex scan of the file -- NOT a real Lean parser, since lakefile.lean is arbitrary
# Lean/Lake DSL code and a full parse is out of scope here. Recognizes the common shape used
# throughout Lake projects: an optional `@[default_target]` attribute immediately above the
# declaration (consulted only when --default-targets is passed), and `srcDir := "..."` /
# `roots := #[\`A, \`B, ...]` fields inside the block, with Lake's own defaults (`srcDir` ".",
# `roots` `[NAME]`) applying where a field is absent -- mirroring the lakefile.toml reader's
# defaults above. `lean_exe` declarations are not treated as source roots (an executable's
# `root`/`srcDir` name its entry point, not a library source tree). The same two candidate forms
# (directory, and `.lean` single-file) are emitted and filtered to what exists on disk, exactly
# as for lakefile.toml. A lakefile.lean written in a sufficiently different style (no `lean_lib
# ... where` block at all, e.g. everything expressed via `Lake.Package.mkPackage` calls or a
# style this regex does not recognize) yields zero entries, which is the same loud
# "declares zero lean_lib entries" failure the lakefile.toml reader gives for an empty table --
# never a silent, by-construction-clean empty result.
#
# LOUD FAILURE (this is the load-bearing contract -- a missing or empty result must never look
# like a clean scan): this script exits non-zero and names, on stderr, every root path it tried,
# whenever ANY of the following hold:
#   - no lakefile.toml, no lakefile.lean, and no LEAN_SRC_ROOTS                       (exit 65)
#   - lakefile.toml exists but cannot be parsed (malformed TOML)                      (exit 66)
#   - python3 is unavailable to parse lakefile.toml or scan lakefile.lean             (exit 66)
#   - lakefile.toml (after any --default-targets filter) declares
#     zero [[lean_lib]] entries                                                       (exit 67)
#   - lakefile.lean's best-effort scan (after any --default-targets filter) finds
#     zero `lean_lib ... where` declarations                                          (exit 67)
#   - every candidate root path (from lakefile.toml, lakefile.lean, OR
#     LEAN_SRC_ROOTS) is missing on disk                                              (exit 68)
#   - every existing root path holds zero *.lean files                                (exit 69)
# A bad CLI argument is a usage error                                                  (exit 64)
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
# --lakefile PATH overrides the default lookup (lakefile.toml, then lakefile.lean, at the repo
# root) with an explicit path, parsed as TOML or as Lean DSL according to its own extension
# (".toml" or ".lean"); any other extension is a usage error.
#
# Output (on success, exit 0): one existing source-root path per line, relative to the repo root
# (as resolved by `git rev-parse --show-toplevel`, or the current directory when not in a git
# work tree).

set -uo pipefail

SCRIPT_NAME="lean-src-roots.sh"

print_help() {
  cat <<'EOF'
Usage: lean-src-roots.sh [--default-targets] [--lakefile PATH]

Resolve this repo's Lean source roots from lakefile.toml, or from lakefile.lean when no
lakefile.toml exists, or from LEAN_SRC_ROOTS when neither lakefile exists, and print one
existing root path per line, relative to the repo root. Exits non-zero and names every root it
tried when nothing resolves. See the header comment in this file for the full precedence,
resolution rule, and exit-code table.
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
LAKEFILE_TOML_DEFAULT="$REPO_ROOT/lakefile.toml"
LAKEFILE_LEAN_DEFAULT="$REPO_ROOT/lakefile.lean"

# LAKEFILE_KIND resolution -- see the header comment's PRECEDENCE paragraph. An explicit
# --lakefile override is dispatched by its own extension rather than by which default path
# exists, since the caller named it directly.
LAKEFILE_KIND=""
LAKEFILE=""
if [ -n "$LAKEFILE_OVERRIDE" ]; then
  case "$LAKEFILE_OVERRIDE" in
    *.toml)
      LAKEFILE_KIND="toml"
      LAKEFILE="$LAKEFILE_OVERRIDE"
      ;;
    *.lean)
      LAKEFILE_KIND="lean"
      LAKEFILE="$LAKEFILE_OVERRIDE"
      ;;
    *)
      echo "$SCRIPT_NAME: --lakefile PATH must end in '.toml' or '.lean' (got '$LAKEFILE_OVERRIDE')" >&2
      exit 64
      ;;
  esac
elif [ -f "$LAKEFILE_TOML_DEFAULT" ]; then
  LAKEFILE_KIND="toml"
  LAKEFILE="$LAKEFILE_TOML_DEFAULT"
elif [ -f "$LAKEFILE_LEAN_DEFAULT" ]; then
  LAKEFILE_KIND="lean"
  LAKEFILE="$LAKEFILE_LEAN_DEFAULT"
else
  LAKEFILE_KIND="none"
fi

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

if [ "$LAKEFILE_KIND" = "toml" ] || [ "$LAKEFILE_KIND" = "lean" ]; then
  if [ -n "${LEAN_SRC_ROOTS:-}" ]; then
    echo "$SCRIPT_NAME: $(basename "$LAKEFILE") found at '$LAKEFILE'; ignoring LEAN_SRC_ROOTS ($(basename "$LAKEFILE") takes precedence, see header)" >&2
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: python3 is required to parse '$LAKEFILE' and is not on PATH" >&2
    exit 66
  fi
fi

if [ "$LAKEFILE_KIND" = "toml" ]; then
  SOURCE_DESC="lakefile.toml at '$LAKEFILE'"

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

elif [ "$LAKEFILE_KIND" = "lean" ]; then
  SOURCE_DESC="lakefile.lean at '$LAKEFILE'"

  CANDIDATES_TSV="$(python3 - "$LAKEFILE" "$DEFAULT_TARGETS_ONLY" <<'PYEOF'
import re
import sys

lakefile_path, default_targets_only = sys.argv[1], sys.argv[2] == "1"

try:
    with open(lakefile_path, "r", encoding="utf-8") as fh:
        raw_text = fh.read()
except OSError as e:
    print(f"lean-src-roots.sh: cannot read {lakefile_path}: {e}", file=sys.stderr)
    raise SystemExit(66)

# Strip `--` line comments (to end of line) before scanning, so a commented-out example
# declaration -- e.g. this project's own lakefile.lean carries a commented-out
# `-- lean_lib BoneyardRef where` block documenting a removed library -- is never mistaken for
# a live one. Best-effort only: a `--` occurring inside a string literal (not used for any path
# in a lean_lib block in practice) would be mis-stripped too; block comments (`/- ... -/`) are
# not stripped at all. Both are accepted limitations of the same kind already documented for the
# `globs` best-effort handling above.
text = "\n".join(line.split("--", 1)[0] for line in raw_text.splitlines())

# Best-effort Lean/Lake DSL scan -- NOT a real Lean parser. Recognizes the common
# `lean_lib NAME where ...` declaration shape, with an optional `@[default_target]` attribute
# immediately above it. See the header comment's "SOURCE OF TRUTH (lakefile.lean path)"
# paragraph for the full rationale and the degrade-to-zero-entries behaviour on an unrecognized
# style.
decl_re = re.compile(
    r'(?P<attr>@\[default_target\]\s*\n\s*)?'
    r'lean_lib\s+(?P<name>\S+)\s+where\b'
)
# A top-level declaration keyword marks the end of the preceding lean_lib's field block.
top_level_re = re.compile(
    r'^[ \t]*(?:@\[[^\]]*\]\s*\n[ \t]*)?(?:lean_lib|lean_exe|package|require)\b',
    re.MULTILINE,
)

matches = list(decl_re.finditer(text))
if not matches:
    print(f"lean-src-roots.sh: {lakefile_path} declares zero lean_lib entries "
          f"(best-effort Lean DSL scan found no 'lean_lib ... where' declaration)",
          file=sys.stderr)
    raise SystemExit(67)

libs = []
for m in matches:
    is_default = m.group("attr") is not None
    name = m.group("name").lstrip('`')
    block_start = m.end()
    block_end = len(text)
    for tm in top_level_re.finditer(text, block_start):
        block_end = tm.start()
        break
    libs.append((name, is_default, text[block_start:block_end]))

if default_targets_only:
    libs = [lib for lib in libs if lib[1]]

if not libs:
    scope = "lean_lib entries marked @[default_target]" if default_targets_only else "lean_lib entries"
    print(f"lean-src-roots.sh: {lakefile_path} declares zero {scope}", file=sys.stderr)
    raise SystemExit(67)

src_dir_re = re.compile(r'srcDir\s*:=\s*"([^"]*)"')
roots_re = re.compile(r'roots\s*:=\s*#\[([^\]]*)\]', re.DOTALL)
ident_re = re.compile(r'`([A-Za-z_][A-Za-z0-9_.]*)')

for name, _is_default, block in libs:
    src_m = src_dir_re.search(block)
    src_dir = src_m.group(1) if src_m else "."

    roots_m = roots_re.search(block)
    roots = ident_re.findall(roots_m.group(1)) if roots_m else []
    if not roots:
        roots = [name]

    for root in roots:
        print(f"{src_dir}\t{root}")
PYEOF
  )"
  PY_EXIT=$?
  if [ $PY_EXIT -ne 0 ]; then
    exit $PY_EXIT
  fi

else
  SOURCE_DESC="LEAN_SRC_ROOTS"
  if [ -z "${LEAN_SRC_ROOTS:-}" ]; then
    echo "$SCRIPT_NAME: no lakefile.toml or lakefile.lean at '$REPO_ROOT' and LEAN_SRC_ROOTS is unset; cannot resolve Lean source roots" >&2
    exit 65
  fi
  CANDIDATES_TSV=""
  for token in $LEAN_SRC_ROOTS; do
    add_candidate "$token"
  done
fi

if [ "$LAKEFILE_KIND" = "toml" ] || [ "$LAKEFILE_KIND" = "lean" ]; then
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
