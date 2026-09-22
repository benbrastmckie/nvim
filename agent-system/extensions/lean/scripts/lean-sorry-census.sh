#!/usr/bin/env bash
# lean-sorry-census.sh -- shared Lean sorry census script
#
# Counts genuine code sorries in Lean 4 source files, correctly excluding
# comment/docstring/string-literal text. A `grep -rn "\bsorry\b" | grep -v ...`
# chain cannot do this correctly: Lean's `/- -/` block comments nest
# (`/- outer /- inner -/ still outer -/` is ONE comment), and nesting depth
# cannot be tracked by a fixed-depth regex/grep pipeline. This script instead
# runs a single-pass, depth-counting comment/string stripper (python3) that
# preserves newlines (so line numbers match the original file) before
# matching `(?<![.\w])sorry\b` on the stripped text.
#
# Handles:
#   - `--` line comments (stripped to end of line)
#   - nested `/- -/` and `/-- -/` block comments (depth-counted)
#   - `"..."` string literals with backslash escaping (interior masked with
#     spaces so a `sorry` appearing only as string *text*, e.g. inside a
#     display/eval string, is not counted as live proof debt -- it is not a
#     `sorry` term/tactic application)
#
# Usage:
#   lean-sorry-census.sh <dir-or-file> [<dir-or-file> ...] [--cross-check]
#
# Targets are almost never a literal directory name typed by hand: resolve them from the
# consuming repo first via lean-src-roots.sh (see that script's header for its own precedence
# and loud-failure contract), then pass its output through, guarded so its exit code is never
# swallowed by a bare `< <(...)` process substitution:
#
#   lean_roots_raw="$(bash .claude/scripts/lean-src-roots.sh)" || {
#     echo "lean-src-roots.sh failed (exit $?); aborting -- cannot census without real roots" >&2
#     exit 1
#   }
#   mapfile -t lean_roots <<< "$lean_roots_raw"
#   bash .claude/scripts/lean-sorry-census.sh "${lean_roots[@]}" --cross-check
#
# Examples:
#   bash .claude/scripts/lean-sorry-census.sh Cslib/
#   bash .claude/scripts/lean-sorry-census.sh Cslib/Foo.lean Cslib/Bar.lean
#
# Output (always):
#   sorry_count: N
#   sorry_inventory:
#   <file>:<line>:<statement>
#   ...
#
# Output (with --cross-check, additionally):
#   Runs `lake build` in the current directory and greps its output for
#   "declaration uses 'sorry'" warnings, an authoritative compiler-backed
#   signal (comment-immune by construction -- comments are discarded during
#   lexing before this warning is ever emitted). Reports both numbers and
#   flags any mismatch. Opt-in because `lake build` is slow; intended for use
#   at wrap-up/final-verification time when a build has already run.
#
#   The build is routed through the shared `lake-build-guard.sh` when both
#   `lake` and the guard are available (serialized against other concurrent
#   builds of the same project, with opt-in memory bounding), and degrades
#   gracefully to a plain `lake build` when either is unavailable -- this
#   command never hard-fails solely because the guard is not deployed.
#   `LEAN_SORRY_CENSUS_GUARD_BIN` overrides the guard binary path (default:
#   the sibling `lake-build-guard.sh` next to this script's own directory);
#   this exists primarily as a test seam, since the census script and the
#   guard ship from different source-store extensions and are only literal
#   siblings post-deploy.
#
# Exit codes: 0 on success (including sorry_count > 0 -- this is a census,
# not a pass/fail gate); 64 on usage error; 65 when a named target does not exist as a file or
# directory (a missing target is now a fatal error, not a warn-and-skip -- "scanned and clean"
# must never be indistinguishable from "scanned nothing" because a target silently vanished);
# 66 when every given target exists but together they hold zero `.lean` files.

set -uo pipefail

CROSS_CHECK=0
TARGETS=()

for arg in "$@"; do
  case "$arg" in
    --cross-check)
      CROSS_CHECK=1
      ;;
    *)
      TARGETS+=("$arg")
      ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Usage: lean-sorry-census.sh <dir-or-file> [<dir-or-file> ...] [--cross-check]" >&2
  exit 64
fi

# Collect .lean files from the targets (directories are scanned recursively). A target that does
# not exist is FATAL, not a warn-and-skip: a target that silently vanished (a stale path, a
# resolver misconfiguration, a typo) must never be indistinguishable from a target that exists
# and is merely clean.
LEAN_FILES=()
MISSING_TARGETS=()
for target in "${TARGETS[@]}"; do
  if [[ -d "$target" ]]; then
    while IFS= read -r -d '' f; do
      LEAN_FILES+=("$f")
    done < <(find "$target" -type f -name '*.lean' -print0)
  elif [[ -f "$target" ]]; then
    LEAN_FILES+=("$target")
  else
    MISSING_TARGETS+=("$target")
  fi
done

if [[ ${#MISSING_TARGETS[@]} -gt 0 ]]; then
  echo "lean-sorry-census.sh: target(s) do not exist as a file or directory:" >&2
  printf '  %s\n' "${MISSING_TARGETS[@]}" >&2
  exit 65
fi

if [[ ${#LEAN_FILES[@]} -eq 0 ]]; then
  echo "lean-sorry-census.sh: target(s) exist but contain zero .lean files -- refusing to report a clean census over nothing scanned. Targets:" >&2
  printf '  %s\n' "${TARGETS[@]}" >&2
  exit 66
fi

strip_and_scan() {
  python3 - "$@" <<'PYEOF'
import sys, re

def strip_lean_comments(text: str) -> str:
    """Depth-counting Lean comment/string stripper. Single pass, O(n).
    Preserves newlines so grep-style line numbers on the output match the
    original file. String interiors are masked with spaces (not preserved
    verbatim) so a bare 'sorry' token appearing only as string text is not
    later matched by the (?<![.\\w])sorry\\b scan -- it is not a sorry term/tactic.
    """
    out, i, n, depth, in_str = [], 0, len(text), 0, False
    while i < n:
        c = text[i]
        if depth == 0 and not in_str:
            if text[i:i + 2] == "--":              # line comment
                j = text.find("\n", i)
                i = n if j == -1 else j
                continue
            if text[i:i + 2] == "/-":              # enter block comment (handles /-- too)
                depth, i = 1, i + 2
                continue
            if c == '"':
                in_str = True
                out.append(c)
                i += 1
                continue
            out.append(c)
            i += 1
        elif in_str:
            if c == "\\" and i + 1 < n:             # skip escaped char, masked
                out.append(" ")
                out.append(" ")
                i += 2
                continue
            if c == '"':
                out.append(c)
                in_str = False
                i += 1
                continue
            out.append("\n" if c == "\n" else " ")  # mask string interior
            i += 1
        else:                                       # inside block comment, depth >= 1
            if text[i:i + 2] == "/-":
                depth += 1
                i += 2
                continue
            if text[i:i + 2] == "-/":
                depth -= 1
                i += 2
                continue
            if c == "\n":
                out.append("\n")                     # preserve line numbers
            i += 1
    return "".join(out)


sorry_re = re.compile(r'(?<![.\w])sorry\b')
total = 0
inventory = []
for path in sys.argv[1:]:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError as e:
        print(f"Warning: could not read {path}: {e}", file=sys.stderr)
        continue
    stripped = strip_lean_comments(text)
    original_lines = text.split("\n")
    stripped_lines = stripped.split("\n")
    for lineno, line in enumerate(stripped_lines, start=1):
        if sorry_re.search(line):
            total += 1
            statement = original_lines[lineno - 1].strip() if lineno - 1 < len(original_lines) else ""
            inventory.append((path, lineno, statement))

print(f"sorry_count: {total}")
print("sorry_inventory:")
for path, lineno, statement in inventory:
    print(f"{path}:{lineno}:{statement}")
PYEOF
}

CENSUS_OUTPUT="$(strip_and_scan "${LEAN_FILES[@]}")"
echo "$CENSUS_OUTPUT"

STRIPPER_COUNT="$(echo "$CENSUS_OUTPUT" | grep -oE '^sorry_count: [0-9]+' | grep -oE '[0-9]+')"

if [[ $CROSS_CHECK -eq 1 ]]; then
  echo ""
  echo "--- Cross-check: lake build ---"
  # GUARD_BIN is resolved once, above the three-way branch below. Flat deploy topology: this
  # script and lake-build-guard.sh ship from different source-store extensions but land as
  # literal siblings in .claude/scripts/ post-deploy, so a dirname-relative lookup is correct
  # post-deploy and wrong when this script is run from the source store directly -- hence the
  # overridable env-var test seam (mirrors the guard's own LAKE_BUILD_GUARD_LAKE_BIN precedent).
  GUARD_BIN="${LEAN_SORRY_CENSUS_GUARD_BIN:-$(dirname "${BASH_SOURCE[0]:-$0}")/lake-build-guard.sh}"
  if ! command -v lake >/dev/null 2>&1; then
    echo "cross_check: unavailable (lake not found in PATH)"
  else
    GUARDED=0
    if [[ -x "$GUARD_BIN" ]]; then
      GUARDED=1
      # --quiet --collect is the guard's own problem, not this call site's: run_lake_foreground
      # already passes them to systemd-run and marks them MANDATORY (not cosmetic), precisely so
      # systemd's status chatter cannot corrupt this combined 2>&1 capture. Do not re-pass or
      # second-guess them here. An explicit "-- build" is passed (not left to a guard-side
      # default) so the forwarded lake_args array is never empty (a set -u hazard inside the
      # guard) and today's exact `lake build` semantics are preserved. --dir/--memory-bound/
      # --defer-on-pressure/--no-share are deliberately NOT passed: this call site defaults to
      # $PWD like today's undirected invocation, and memory bounding stays opt-in/off here
      # because the census is a verification read-out whose value is a correct count -- an
      # aborted or deferred build would silently under-count rather than fail loudly. On the
      # guard's memory-pressure warn-and-proceed path, one extra stderr line lands inside this
      # capture; harmless, since the "declaration uses 'sorry'" grep below is substring-based,
      # but a future reader diffing raw census output should not be surprised by it.
      BUILD_OUTPUT="$("$GUARD_BIN" build -- build 2>&1)"
    else
      BUILD_OUTPUT="$(lake build 2>&1)"
    fi
    BUILD_STATUS=$?
    COMPILER_COUNT="$(echo "$BUILD_OUTPUT" | grep -c "declaration uses 'sorry'")"
    echo "compiler_sorry_count: $COMPILER_COUNT"
    echo "stripper_sorry_count: $STRIPPER_COUNT"
    if [[ "$COMPILER_COUNT" == "$STRIPPER_COUNT" ]]; then
      echo "cross_check: MATCH"
    else
      echo "cross_check: MISMATCH (stripper=$STRIPPER_COUNT, compiler=$COMPILER_COUNT)"
    fi
    if [[ $BUILD_STATUS -ne 0 ]]; then
      if [[ $GUARDED -eq 1 ]]; then
        echo "Warning: guarded lake build exited non-zero ($BUILD_STATUS); compiler_sorry_count may be incomplete" >&2
      else
        echo "Warning: lake build exited non-zero ($BUILD_STATUS); compiler_sorry_count may be incomplete" >&2
      fi
    fi
  fi
fi
