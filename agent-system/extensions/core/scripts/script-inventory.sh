#!/usr/bin/env bash
# script-inventory.sh - Standing, mechanical inventory probe over the non-test shell-script
# corpus under agent-system/extensions/**. Emits one JSON document on stdout; never writes any
# file itself and never sources, evals, or executes a candidate script (grep/wc/jq only).
#
# WHY THIS EXISTS: tasks that touch this script corpus are filed by hand from defects hit live
# during /orchestrate runs -- that intake surfaces only what BROKE. Needless complexity,
# duplicated logic, and poor division of labor never break anything, so they stay invisible by
# construction and never self-correct. This probe gives the corpus a standing, re-runnable,
# evidence-based ranking so a decomposition target is chosen by measurement, not by preference.
#
# SOURCE STORE ONLY: this script reads agent-system/extensions/** (the source store), never
# .claude/** (the disposable deploy artifact -- see .claude/rules/source-store-deploy-boundary.md).
# A caller that wants the deployed tree's view must pass --root at a path that resolves there
# explicitly; the default resolution below prefers the git toplevel, which is the source-store
# checkout in this repo.
#
# Follows the established convention of assess-repo-health.sh and measure-eager-context.sh:
# extensive header comment, `--root PATH` override, `--check` mode, `usage()` as a `sed`-extract
# of this header, `set -uo pipefail`, and small integer exit codes.
#
# ENUMERATION: non-test `*.sh` files under `<root>/agent-system/extensions/**`, found via
# `git ls-files` when `<root>` is a git work tree (fast, respects .gitignore, matches how
# assess-repo-health.sh and census-count.sh already enumerate), else a `find` fallback excluding
# `.git/` so a non-git fixture (a test's `mktemp -d` workdir) still enumerates correctly. A path
# is excluded as a "test" file when: (a) it lives under a `tests/` directory anywhere in its
# path, or (b) its basename starts with the literal prefix `test-`. Candidates are sorted
# deterministically (plain lexicographic `sort`) so output ordering never depends on filesystem
# iteration order or git-index order.
#
# PER-SCRIPT METRICS (Phase 1 of this probe; manifest-registration, duplicate-block detection,
# and ranked ordering are added by a later Phase 2 pass over this same file):
#   path                 repo-root-relative path (e.g. "agent-system/extensions/core/scripts/x.sh")
#   lines                `wc -l` of the file
#   bytes                `wc -c` of the file
#   inbound_callers      integer: count of DISTINCT files under `<root>/agent-system/extensions/**`
#                         (excluding the candidate itself) whose content contains the candidate's
#                         own basename as a literal substring (`grep -rlF`). This spans skills,
#                         agents, commands, manifests, hooks, docs, and other scripts -- anything
#                         under the source store -- exactly as the motivating task describes.
#   inbound_caller_paths  sorted array of those distinct referencing paths (repo-root-relative).
#   zero_caller_finding   boolean, true when inbound_callers == 0 -- a script with zero textual
#                         references is a finding in itself (an undeclared entry point, a dead
#                         file, or a legitimate standalone utility that must be dispositioned
#                         individually, never waved through as an aggregate).
#   has_test             boolean: true when either `tests/test-<basename>` or the flat
#                         `test-<basename>` exists alongside the candidate's own `scripts/`
#                         directory (the convention this corpus already uses in most, not all,
#                         cases -- see the CAVEAT below).
#   test_paths           sorted array of the (zero, one, or two) paired test paths that exist.
#
# METHOD WARNING, HONORED DELIBERATELY (the motivating task's own lesson): `inbound_callers` is a
# TEXTUAL-REFERENCE count, not a call-graph analysis. Grepping a basename over source finds it
# inside comments, heredocs, and fixture string literals exactly as readily as inside real
# invocations -- it is a conservative, cheap, OVER-counting proxy, never an under-count. A
# reader using this field to justify deletion must open the listed `inbound_caller_paths` and
# confirm each is a genuine call site, not merely trust the integer.
#
# CAVEAT on has_test: pairing is by FILENAME CONVENTION ONLY (`test-<basename>` against the
# candidate's own basename). This corpus does not follow that convention uniformly -- for example
# `lib/common.sh` is covered by `tests/test-common-lib.sh`, not `tests/test-common.sh` -- so this
# field UNDER-REPORTS real coverage for any script whose test file does not follow the exact
# `test-<basename>` shape. `has_test: false` is therefore a prompt to check by hand, not proof of
# an untested script.
#
# Degenerate case: when zero non-test `*.sh` candidates are found under `<root>`, `scripts` is
# emitted as an empty JSON array and `summary` as JSON `null` (never a crash, never a non-empty
# default) -- the same nullable-field pattern `assess-repo-health.sh` uses for `build_errors`.
#
# Reproducibility: every field above is a pure function of `<root>`'s on-disk content and is
# therefore stable across runs. The one field that is NOT reproducible by design is the top-level
# `generated_at` timestamp; a reproducibility diff must exclude it (see
# tests/test-script-inventory.sh's reproducibility case for the exact `jq` filter).
#
# Usage:
#   script-inventory.sh [--root PATH] [--check] [-h|--help]
#
# Options:
#   --root PATH   Directory whose agent-system/extensions/** to probe. Default: the current git
#                 work tree's root (`git rev-parse --show-toplevel`), falling back to a
#                 script-relative guess (source-store `agent-system/extensions/core/scripts/`
#                 depth, matching this script's own deploy location) when the CWD is not inside a
#                 git work tree at all. Fixtures/tests should always pass --root explicitly.
#   --check       Print the per-script table (one line per script: path, lines, callers,
#                 has_test) to stdout instead of the full JSON document, and exit non-zero when
#                 any script has zero_caller_finding == true. Exits 0 otherwise. Mirrors
#                 measure-eager-context.sh's --check semantics (report-only, never writes a file).
#   -h, --help    Print this usage block and exit 0.
#
# Exit codes:
#   0 - success (JSON emitted on stdout in default mode; or --check found no zero-caller script)
#   1 - usage error (unknown flag, --root missing its argument, or --root does not exist), or
#       --check found at least one zero-caller script
#   2 - required tool missing (jq)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,96p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

ROOT=""
CHECK_MODE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      ROOT="${2:-}"
      if [ -z "$ROOT" ]; then
        echo "ERROR: --root requires a PATH argument" >&2
        exit 1
      fi
      shift 2
      ;;
    --check)
      CHECK_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and not on PATH" >&2
  exit 2
fi

# ── Resolve default --root when not given explicitly ──────────────────────────────────────────
if [ -z "$ROOT" ]; then
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$git_root" ]; then
    ROOT="$git_root"
  else
    candidate_source_store="$(cd "$SCRIPT_DIR/../../../.." 2>/dev/null && pwd || true)"
    ROOT=""
    if [ -n "$candidate_source_store" ] && { [ -d "$candidate_source_store/.git" ] || [ -d "$candidate_source_store/specs" ]; }; then
      ROOT="$candidate_source_store"
    fi
    if [ -z "$ROOT" ]; then
      ROOT="$(pwd)"
    fi
  fi
fi

if [ ! -d "$ROOT" ]; then
  echo "ERROR: --root path does not exist or is not a directory: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

EXT_ROOT="$ROOT/agent-system/extensions"

# ── Enumeration ─────────────────────────────────────────────────────────────────────────────────
# Prints NUL-delimited repo-root-relative paths of non-test *.sh files under
# agent-system/extensions/**, sorted lexicographically.
enumerate_candidates() {
  local rel
  if [ ! -d "$EXT_ROOT" ]; then
    return 0
  fi
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" ls-files -z -- 'agent-system/extensions/**/*.sh' 2>/dev/null
  else
    find "$EXT_ROOT" -type f -name '*.sh' -print0 2>/dev/null | while IFS= read -r -d '' abs; do
      printf '%s\0' "${abs#"$ROOT"/}"
    done
  fi
}

declare -a CANDIDATES=()
while IFS= read -r -d '' rel; do
  case "$rel" in
    */tests/*) continue ;;
  esac
  base="$(basename "$rel")"
  case "$base" in
    test-*) continue ;;
  esac
  [ -e "$ROOT/$rel" ] || continue
  CANDIDATES+=("$rel")
done < <(enumerate_candidates)

if [ "${#CANDIDATES[@]}" -gt 0 ]; then
  mapfile -t CANDIDATES < <(printf '%s\n' "${CANDIDATES[@]}" | sort)
fi

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  if [ "$CHECK_MODE" -eq 1 ]; then
    echo "script-inventory: 0 candidates under $EXT_ROOT"
    exit 0
  fi
  jq -n --arg root "$ROOT" --arg generated_at "$generated_at" \
    '{root: $root, generated_at: $generated_at, candidate_count: 0, scripts: [], summary: null}'
  exit 0
fi

# to_json_array ARG... -- prints a compact JSON array of its arguments as strings, or "[]" when
# called with zero arguments. Used instead of jq's --args/$ARGS.positional mechanism because that
# mechanism requires the filter string to be jq's single positional program argument, which
# cannot be interleaved with a second, differently-sized positional list (callers vs test_paths)
# in the same invocation.
to_json_array() {
  if [ "$#" -eq 0 ]; then
    printf '[]'
    return
  fi
  printf '%s\n' "$@" | jq -R -s -c 'split("\n") | map(select(length > 0))'
}

# ── Per-candidate metrics ──────────────────────────────────────────────────────────────────────
ANY_ZERO_CALLER=0
declare -a SCRIPT_JSON_PARTS=()

for rel in "${CANDIDATES[@]}"; do
  abs="$ROOT/$rel"
  lines="$(wc -l < "$abs" | tr -d ' ')"
  bytes="$(wc -c < "$abs" | tr -d ' ')"
  base="$(basename "$rel")"
  dir="$(dirname "$rel")"

  # inbound_callers: distinct referencing files under agent-system/extensions/** (excluding the
  # candidate itself) whose content contains this script's own basename as a literal substring.
  declare -a callers=()
  while IFS= read -r -d '' caller_abs; do
    caller_rel="${caller_abs#"$ROOT"/}"
    [ "$caller_rel" = "$rel" ] && continue
    callers+=("$caller_rel")
  done < <(grep -rlFZ -- "$base" "$EXT_ROOT" 2>/dev/null)
  inbound_callers="${#callers[@]}"
  if [ "$inbound_callers" -gt 0 ]; then
    mapfile -t callers < <(printf '%s\n' "${callers[@]}" | sort)
  fi
  zero_caller_finding="false"
  if [ "$inbound_callers" -eq 0 ]; then
    zero_caller_finding="true"
    ANY_ZERO_CALLER=1
  fi

  # has_test: pairing by filename convention against tests/test-<basename> and flat
  # test-<basename>, both resolved relative to the candidate's own directory tree root
  # (its enclosing scripts/ directory), matching the corpus's existing (non-uniform) convention.
  declare -a test_paths=()
  nested_test="$dir/tests/test-$base"
  flat_test="$dir/test-$base"
  [ -f "$ROOT/$nested_test" ] && test_paths+=("$nested_test")
  [ -f "$ROOT/$flat_test" ] && test_paths+=("$flat_test")
  has_test="false"
  if [ "${#test_paths[@]}" -gt 0 ]; then
    has_test="true"
    mapfile -t test_paths < <(printf '%s\n' "${test_paths[@]}" | sort)
  fi

  callers_json="$(to_json_array "${callers[@]}")"
  test_paths_json="$(to_json_array "${test_paths[@]}")"

  script_json="$(jq -n \
    --arg path "$rel" \
    --argjson lines "$lines" \
    --argjson bytes "$bytes" \
    --argjson inbound_callers "$inbound_callers" \
    --argjson inbound_caller_paths "$callers_json" \
    --argjson zero_caller_finding "$zero_caller_finding" \
    --argjson has_test "$has_test" \
    --argjson test_paths "$test_paths_json" \
    '{
      path: $path,
      lines: $lines,
      bytes: $bytes,
      inbound_callers: $inbound_callers,
      inbound_caller_paths: $inbound_caller_paths,
      zero_caller_finding: $zero_caller_finding,
      has_test: $has_test,
      test_paths: $test_paths
    }')"

  SCRIPT_JSON_PARTS+=("$script_json")
  unset callers test_paths
done

if [ "$CHECK_MODE" -eq 1 ]; then
  for part in "${SCRIPT_JSON_PARTS[@]}"; do
    printf '%s\n' "$part" | jq -r '[.path, .lines, .inbound_callers, .has_test] | @tsv'
  done
  if [ "$ANY_ZERO_CALLER" -eq 1 ]; then
    exit 1
  fi
  exit 0
fi

# The full per-script array can exceed the exec argv size limit (ARGV_MAX) once a few hundred
# scripts each carry a caller-path array -- passing it via --argjson (a command-line argument)
# fails with "Argument list too long" at this scale. Route it through a scratch file consumed via
# --slurpfile instead, which jq reads itself rather than receiving on argv. The scratch file is
# created under the system temp directory, never under $ROOT, so this remains side-effect-free
# with respect to the probed tree (the no-side-effects contract this suite tests).
SCRIPTS_TMP="$(mktemp)"
trap 'rm -f "$SCRIPTS_TMP"' EXIT
printf '%s\n' "${SCRIPT_JSON_PARTS[@]}" | jq -s '.' > "$SCRIPTS_TMP"

jq -n \
  --arg root "$ROOT" \
  --arg generated_at "$generated_at" \
  --argjson candidate_count "${#CANDIDATES[@]}" \
  --slurpfile scripts_wrap "$SCRIPTS_TMP" \
  '
  ($scripts_wrap[0]) as $scripts
  | {
    root: $root,
    generated_at: $generated_at,
    candidate_count: $candidate_count,
    scripts: $scripts,
    summary: {
      total_lines: ([$scripts[].lines] | add),
      total_bytes: ([$scripts[].bytes] | add),
      zero_caller_count: ([$scripts[] | select(.zero_caller_finding == true)] | length),
      untested_count: ([$scripts[] | select(.has_test == false)] | length)
    }
  }'
