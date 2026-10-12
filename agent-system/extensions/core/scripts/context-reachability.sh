#!/usr/bin/env bash
# context-reachability.sh - Standing, mechanical reachability/inventory probe over the context
# corpus under agent-system/extensions/**/context/**. Emits one JSON document on stdout; never
# writes any file itself and never sources, evals, or executes a candidate.
#
# WHY THIS EXISTS: defect-driven task intake surfaces only what BREAKS. An unreachable or
# redundant context file breaks nothing -- it just costs bytes, deploy time, and reader
# attention, so it stays invisible by construction and never self-corrects. This probe gives the
# corpus a standing, re-runnable, evidence-based reachability verdict so a removal or merge
# target is chosen by measurement, never by preference.
#
# SOURCE STORE ONLY: this script reads agent-system/extensions/** (the source store), never
# .claude/** (the disposable deploy artifact -- see .claude/rules/source-store-deploy-boundary.md).
# A caller that wants the deployed tree's view must pass --root at a path that resolves there
# explicitly; the default resolution below prefers the git toplevel, which is the source-store
# checkout in this repo.
#
# Follows the established convention of script-inventory.sh and measure-eager-context.sh:
# extensive header comment, `--root PATH` override, `--check` mode, `usage()` as a `sed`-extract
# of this header, `set -uo pipefail`, and small integer exit codes.
#
# ENUMERATION: `.md` files under `<root>/agent-system/extensions/*/context/**`, found via
# `git ls-files` when `<root>` is a git work tree (fast, respects .gitignore), else a `find`
# fallback so a non-git fixture (a test's `mktemp -d` workdir) still enumerates correctly.
# Candidates are sorted deterministically (plain lexicographic `sort`).
#
# THREE INDEPENDENT REFERENCE STYLES, computed as a NON-SHORT-CIRCUITING UNION (every candidate
# is checked against all three regardless of an earlier hit):
#
#   1. by filename -- a backticked or plain path naming the file's own basename, found via a
#      literal grep (`grep -rlF`) over the WHOLE source store (never restricted to outside
#      context/ -- a basename mention living inside another context/ file, e.g. a directory
#      README's tree listing, is a genuine reference and counts). This is the exact same
#      computation as `inbound_references` below (see that field's entry for why the two are
#      allowed to carry identical data: they answer different QUESTIONS from the same evidence).
#   2. by directory -- a reference to a CONTAINING DIRECTORY of the candidate, which reaches
#      every file beneath it. Checked against every contiguous SUFFIX of the candidate's
#      context-relative directory path (e.g. for .../context/project/founder/deck/contents/
#      closing/closing-standard.md: "closing/", "contents/closing/", "deck/contents/closing/",
#      "founder/deck/contents/closing/", "project/founder/deck/contents/closing/"), each tested
#      as a literal substring against referrers OUTSIDE context/ only (a directory reference is
#      an AGENT-PROSE convention; restricting the search to outside context/ is also what makes
#      this style's own regression fixture -- the present/founder template libraries -- a
#      meaningful proof rather than a tautology). A SUFFIX match deliberately tolerates whatever
#      PREFIX a referrer writes before it: founder's agent prose uses the quirky `.context/deck/
#      contents/` form (a dot-prefix convention, not unreachability) and the suffix
#      "deck/contents/" still matches inside it as a plain substring, with no special-casing
#      required.
#   3. via index -- the source store carries NO single merged index.json; style 3 enumerates the
#      22 separate per-extension `agent-system/extensions/*/index-entries.json` files itself and
#      resolves each entry's `path` against that SAME extension's own `context/` subtree. An
#      entry counts as a hit only when it carries a non-empty `load_when` (any of
#      `agents`/`task_types`/`commands` non-empty) or `always: true` -- an entry with an empty
#      load_when and no always flag is itself orphaned and resolves nothing at runtime.
#      `validate-index.sh` reads only the already-merged DEPLOYED index and answers a different
#      question (is this entry itself orphaned there); it is not reusable here.
#
# `reachable` is the boolean OR of the three. `reachable_styles` names every style that fired,
# in the fixed order [filename, directory, index] -- never short-circuited, so a file reachable
# by two styles reports both. A file reachable by ANY of the three is NOT dead, however unloved
# it looks.
#
# PER-FILE FIELDS:
#   path                           repo-root-relative path
#   bytes, lines                   `wc -c` / `wc -l`
#   extension                      owning extension directory name, parsed from the path
#   reachable_by_filename           boolean (style 1)
#   reachable_by_filename_paths     sorted distinct referrer paths for style 1
#   reachable_by_directory          boolean (style 2)
#   reachable_by_directory_paths    sorted distinct referrer paths for style 2
#   reachable_by_directory_matched  sorted distinct directory suffixes that matched
#   reachable_by_index              boolean (style 3)
#   reachable_by_index_paths        sorted distinct `index-entries.json` files that matched
#   reachable                       boolean OR of the three styles above
#   reachable_styles                array, fixed order [filename, directory, index], only fired ones
#   zero_reference_finding          boolean, true when `reachable` is false -- the probe's one
#                                    declared finding class
#   inbound_references              integer: distinct referencing files under the WHOLE source
#                                    store (excluding the candidate itself) whose content contains
#                                    the candidate's own basename as a literal substring --
#                                    counting referrers everywhere, INCLUDING other context/
#                                    files, so a single-referrer file that could be inlined is
#                                    visible. Identical in scope and computation to style 1
#                                    (`reachable_by_filename`); kept as a separately named field
#                                    because it answers a different question (inlining-candidate
#                                    census) than the OR-reachability verdict does, the same way
#                                    script-inventory.sh's `inbound_callers` is not itself framed
#                                    as a reachability style.
#   inbound_reference_paths         sorted distinct referrer paths for the above
#   eager                           boolean, or JSON null when the classifier is unavailable (see
#                                    EAGER/LAZY CLASSIFICATION below)
#
# METHOD WARNING, carried over verbatim from script-inventory.sh's own lesson:
# `inbound_references` (and every per-style referrer-path field above) is a TEXTUAL-REFERENCE
# count, not a call-graph or load-graph analysis. Grepping a basename or a directory suffix over
# source finds it inside comments, prose examples, and unrelated coincidental text exactly as
# readily as inside a real reference -- it is a conservative, cheap, OVER-counting proxy, never
# an under-count. A reader using any of these fields to justify removal or merger must open the
# listed referrer paths and confirm each is a genuine reference, not merely trust the integer.
#
# EAGER/LAZY CLASSIFICATION: reused BY INVOCATION from measure-eager-context.sh, never
# re-derived as a second, divergent heuristic. This probe shells out to
# `REPO_ROOT=<root> bash <script_dir>/measure-eager-context.sh --check`, parses its stable
# tab-delimited `CHANNEL LABEL PATH BYTES TOKENS_EST` rows, and treats a candidate whose path
# appears as an `at_import`-channel row's PATH as `eager: true`; every other candidate is
# `eager: false`. Emitted as JSON `null` (never `false`) for every candidate when
# measure-eager-context.sh cannot be found alongside this probe's own script directory at all,
# or when its invocation produces no parseable header row -- the same nullable-field pattern
# script-inventory.sh uses for `manifest_registered`. `summary.eager_count`/`summary.lazy_count`
# are likewise JSON null (not 0) under that same degraded condition, so a reader cannot mistake
# "classification unavailable" for "measured zero". Agreement with measure-eager-context.sh's
# own `at_import` subtotal is this probe's non-divergence contract: the two scripts must never
# disagree about what is eager.
#
# TELEMETRY CROSS-CHECK (static reachability only, never load-event confirmation): no telemetry
# tier in this repo records a context-file READ at file granularity today. specs/events.jsonl's
# `event_type` is an open, extensible string (lifecycle_stage / deviation / blocker / milestone /
# success / system_defect / ... observed in use) with no path-carrying tool-call event defined;
# the memory extension's history.jsonl is prompt-level, not file-level; transcript `.meta.json`
# sidecars are an unstructured, ~30-day replay window, not a queryable index. This probe's
# `reachable` verdict therefore answers "could this be loaded" (static reachability), never "has
# this been loaded" (observed use) -- a real limitation, not an oversight. Closing the gap would
# require a `PostToolUse` hook matched on `Read` (and the `Bash` forms that read a file, e.g.
# `cat`/`sed -n`), filtering paths under `agent-system/extensions/*/context/**` or
# `.claude/context/**`, appending an `event_type: "context_file_read"` row with the path in
# `detail` to events.jsonl -- the existing open `event_type`/`detail` schema accepts this without
# a schema change. Building that instrumentation is explicitly OUT OF SCOPE here.
#
# Degenerate case: when zero `.md` candidates are found under `<root>/agent-system/extensions/*/
# context/**`, `files` is emitted as an empty JSON array and `summary` as JSON `null` (never a
# crash, never a non-empty default) -- the same nullable-field pattern assess-repo-health.sh and
# script-inventory.sh use.
#
# Reproducibility: every field above is a pure function of `<root>`'s on-disk content and is
# therefore stable across runs. The one field that is NOT reproducible by design is the top-level
# `generated_at` timestamp; a reproducibility diff must exclude it.
#
# Usage:
#   context-reachability.sh [--root PATH] [--check] [-h|--help]
#
# Options:
#   --root PATH   Directory whose agent-system/extensions/**/context/** to probe. Default: the
#                 current git work tree's root (`git rev-parse --show-toplevel`), falling back to
#                 a script-relative guess (source-store `agent-system/extensions/core/scripts/`
#                 depth, matching this script's own deploy location) when the CWD is not inside a
#                 git work tree at all. Fixtures/tests should always pass --root explicitly.
#   --check       Print the per-file table (path, bytes, reachable, reachable_styles, eager,
#                 inbound_references) to stdout instead of the full JSON document, and exit
#                 non-zero when any file carries zero_reference_finding == true. Exits 0
#                 otherwise. Mirrors measure-eager-context.sh's/script-inventory.sh's --check
#                 semantics (report-only, never writes a file).
#   -h, --help    Print this usage block and exit 0.
#
# Exit codes:
#   0 - success (JSON emitted on stdout in default mode; or --check found no declared finding)
#   1 - usage error (unknown flag, --root missing its argument, or --root does not exist), or
#       --check found at least one zero_reference_finding
#   2 - required tool missing (jq)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,158p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
# Prints NUL-delimited repo-root-relative paths of .md files under
# agent-system/extensions/*/context/**, sorted lexicographically.
enumerate_candidates() {
  if [ ! -d "$EXT_ROOT" ]; then
    return 0
  fi
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Two patterns are required: git's "**" glob magic matches one or more intervening path
    # segments, never zero, so a file living DIRECTLY in an extension's context/ (e.g.
    # context/README.md, with no subdirectory) would be silently missed by the "**/*.md" form
    # alone.
    git -C "$ROOT" ls-files -z -- \
      'agent-system/extensions/*/context/*.md' \
      'agent-system/extensions/*/context/**/*.md' 2>/dev/null
  else
    find "$EXT_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | while IFS= read -r -d '' extdir; do
      [ -d "$extdir/context" ] || continue
      find "$extdir/context" -type f -name '*.md' -print0 2>/dev/null
    done | while IFS= read -r -d '' abs; do
      printf '%s\0' "${abs#"$ROOT"/}"
    done
  fi
}

declare -a CANDIDATES=()
while IFS= read -r -d '' rel; do
  [ -e "$ROOT/$rel" ] || continue
  CANDIDATES+=("$rel")
done < <(enumerate_candidates)

if [ "${#CANDIDATES[@]}" -gt 0 ]; then
  mapfile -t CANDIDATES < <(printf '%s\n' "${CANDIDATES[@]}" | sort -u)
fi

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  if [ "$CHECK_MODE" -eq 1 ]; then
    echo "context-reachability: 0 candidates under $EXT_ROOT"
    exit 0
  fi
  jq -n --arg root "$ROOT" --arg generated_at "$generated_at" \
    '{root: $root, generated_at: $generated_at, candidate_count: 0, files: [], summary: null}'
  exit 0
fi

# All scratch files created below are collected here and removed on exit -- all are created
# under the SYSTEM temp directory (mktemp's default), never under $ROOT, preserving the
# no-side-effects-on-the-probed-tree contract the test suite asserts.
declare -a TMP_FILES=()
trap 'rm -f "${TMP_FILES[@]}"' EXIT

# to_json_array ARG... -- prints a compact JSON array of its arguments as strings, or "[]" when
# called with zero arguments.
to_json_array() {
  if [ "$#" -eq 0 ]; then
    printf '[]'
    return
  fi
  printf '%s\n' "$@" | jq -R -s -c 'split("\n") | map(select(length > 0))'
}

# ── Per-candidate cheap fields (Phase 1) ───────────────────────────────────────────────────────
declare -a FILE_JSON_PARTS=()

for rel in "${CANDIDATES[@]}"; do
  abs="$ROOT/$rel"
  lines="$(wc -l < "$abs" | tr -d ' ')"
  bytes="$(wc -c < "$abs" | tr -d ' ')"

  # extension: owning extension directory name, parsed from
  # agent-system/extensions/<extension>/context/...
  ext_rel="${rel#agent-system/extensions/}"
  extension="${ext_rel%%/*}"

  file_json="$(jq -n \
    --arg path "$rel" \
    --argjson lines "$lines" \
    --argjson bytes "$bytes" \
    --arg extension "$extension" \
    '{
      path: $path,
      lines: $lines,
      bytes: $bytes,
      extension: $extension
    }')"

  FILE_JSON_PARTS+=("$file_json")
done

if [ "$CHECK_MODE" -eq 1 ]; then
  for part in "${FILE_JSON_PARTS[@]}"; do
    printf '%s\n' "$part" | jq -r '[.path, .bytes, .extension] | @tsv'
  done
  exit 0
fi

FILES_TMP="$(mktemp)"
TMP_FILES+=("$FILES_TMP")
printf '%s\n' "${FILE_JSON_PARTS[@]}" | jq -s '.' > "$FILES_TMP"

jq -n \
  --arg root "$ROOT" \
  --arg generated_at "$generated_at" \
  --argjson candidate_count "${#CANDIDATES[@]}" \
  --slurpfile files_wrap "$FILES_TMP" \
  '
  ($files_wrap[0]) as $files
  | {
    root: $root,
    generated_at: $generated_at,
    candidate_count: $candidate_count,
    files: $files,
    summary: {
      total_bytes: ([$files[].bytes] | add)
    }
  }'
