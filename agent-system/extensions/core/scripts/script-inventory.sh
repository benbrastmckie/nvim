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
# PER-SCRIPT METRICS:
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
#   manifest_registered  boolean or JSON null. For a candidate under an extension's own
#                         `scripts/` tree: REUSES check-extension-docs.sh's Rule Q
#                         (`check_undeclared_scripts`) BY INVOCATION, never reimplemented --
#                         this probe shells out to the real check-extension-docs.sh with
#                         REPO_ROOT pointed at this probe's own `<root>`, and parses its
#                         "FAIL: script file on disk NOT in provides.scripts: scripts/<rel>"
#                         lines (grouped under that extension's own "[ext_name]" header line) to
#                         determine registration. A non-zero exit from check-extension-docs.sh is
#                         EXPECTED and parsed here, never treated as this probe's own failure.
#                         For a candidate under an extension's `hooks/` tree instead (Rule Q does
#                         not cover `hooks/` -- it only walks `scripts/`): this probe supplements
#                         with a small, independent membership check against that extension's own
#                         `provides.hooks` array (by basename), so a hook file is never
#                         misreported as "not registered" merely because Rule Q's jurisdiction
#                         stops at `scripts/`. Emitted as JSON `null` (never `false`) when
#                         check-extension-docs.sh cannot be found next to this probe at all, and
#                         for the (today nonexistent) case of a candidate under neither
#                         `scripts/` nor `hooks/`.
#   duplicate_blocks      integer: count of this script's normalized 10-line sliding windows that
#                         participate in a QUALIFYING duplicated block (see DUPLICATE-BLOCK
#                         DETECTION below).
#   duplicate_block_peers sorted array of other scripts sharing at least one qualifying window
#                         with this one.
#   score                 integer composite ranking score (see RANKED ORDERING below).
#   rank                  integer, 1-based, this script's position in the `ranking` array.
#
# DUPLICATE-BLOCK DETECTION (deliberately bounded, not a general clone-detection engine -- no
# precedent for one exists anywhere in this repo): each candidate's lines are normalized (blank
# lines and full-line comments, i.e. a line whose trimmed form starts with `#`, are dropped;
# surviving lines have internal whitespace runs collapsed to one space) and a FIXED 10-line
# sliding window is hashed (SHA-1) across the normalized sequence. A window hash QUALIFIES when it
# recurs 3+ times in total across the whole corpus OR spans 2+ distinct files -- i.e. real
# cross-script or heavily-repeated copy-paste, not an isolated coincidence. This is implemented as
# a single `python3` pass over the whole candidate set (sha1 hashing ~72k lines-of-windows one
# subprocess at a time in pure bash would run one `md5sum`/`sha1sum` invocation PER WINDOW -- tens
# of thousands of forks -- which is the slow path this script deliberately avoids). Sophistication
# (token-level normalization, near-duplicate fuzzy matching, cross-language awareness) is
# explicitly out of scope and left for a future, separately-scoped task if ever justified.
#
# RANKED ORDERING: `score = lines + (zero_caller_finding ? 500 : 0) + duplicate_blocks`.
# Rationale, stated plainly so a future reader can audit any target choice against it: raw line
# count is the PRIMARY signal and dominates by construction (the dispatch's own motivating
# example ranks scripts by size, and this corpus's largest script is ~1,200 lines ahead of its
# runner-up -- no number of findings should out-rank that gap). The two finding classes are
# therefore deliberately LOW-weighted modifiers, not competing primary signals: one point per
# duplicated-block window, and a flat 500-line-equivalent nudge for a zero-caller finding -- both
# small enough to break a near-tie between comparably-sized scripts without ever letting a
# finding alone outrank a script hundreds of lines larger. (An earlier draft weighted
# duplicate_blocks at x20, which let a 1,635-line script with 172 duplicate-window hits outrank
# the corpus's actual largest script purely on a structural-repetition artifact -- corrected
# here specifically so line count stays the dominant signal.) `ranking` is the array of candidate
# `path` strings sorted by this score descending, tie-broken ascending on `path` for a fully
# deterministic order; `rank` (1-based) is each script's position in that array, duplicated onto
# the per-script object for convenience.
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
#                 has_test, manifest_registered, duplicate_blocks) to stdout instead of the full
#                 JSON document, and exit non-zero when any script has zero_caller_finding ==
#                 true OR manifest_registered == false (the two declared finding classes -- a
#                 bare manifest-registration null, meaning the check was unavailable, never
#                 triggers this). Exits 0 otherwise. Mirrors measure-eager-context.sh's --check
#                 semantics (report-only, never writes a file).
#   -h, --help    Print this usage block and exit 0.
#
# Exit codes:
#   0 - success (JSON emitted on stdout in default mode; or --check found no declared finding)
#   1 - usage error (unknown flag, --root missing its argument, or --root does not exist), or
#       --check found at least one zero-caller or manifest-unregistered script
#   2 - required tool missing (jq, or python3 for duplicate-block detection)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,143p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required (duplicate-block detection) and not on PATH" >&2
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
    '{root: $root, generated_at: $generated_at, candidate_count: 0, scripts: [], ranking: [], summary: null}'
  exit 0
fi

# All scratch files created below are collected here and removed on exit -- all are created
# under the SYSTEM temp directory (mktemp's default), never under $ROOT, preserving the
# no-side-effects-on-the-probed-tree contract the test suite asserts.
declare -a TMP_FILES=()
trap 'rm -f "${TMP_FILES[@]}"' EXIT

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

# ── manifest_registered precomputation: one check-extension-docs.sh invocation, parsed once ────
# See the header's manifest_registered entry for the full rationale (Rule Q reuse for scripts/,
# a small supplementary provides.hooks membership check for hooks/).
CHECK_EXT_DOCS="$SCRIPT_DIR/check-extension-docs.sh"
MANIFEST_CHECK_AVAILABLE=0
declare -A UNREGISTERED_SCRIPT=()
if [ -f "$CHECK_EXT_DOCS" ]; then
  MANIFEST_CHECK_AVAILABLE=1
  current_ext=""
  while IFS= read -r line; do
    case "$line" in
      \[*\])
        current_ext="${line#\[}"
        current_ext="${current_ext%\]}"
        ;;
      *"FAIL: script file on disk NOT in provides.scripts: scripts/"*)
        rel_under_scripts="${line##*FAIL: script file on disk NOT in provides.scripts: scripts/}"
        UNREGISTERED_SCRIPT["${current_ext}|${rel_under_scripts}"]=1
        ;;
    esac
  done < <(REPO_ROOT="$ROOT" bash "$CHECK_EXT_DOCS" --quiet 2>&1 || true)
fi

# ── Duplicate-block precomputation: one python3 pass over the whole candidate set ──────────────
# See the header's DUPLICATE-BLOCK DETECTION entry for the full algorithm and rationale.
DUP_TMP="$(mktemp)"
TMP_FILES+=("$DUP_TMP")
python3 - "$ROOT" 10 3 2 "${CANDIDATES[@]}" > "$DUP_TMP" <<'PYEOF'
import sys, hashlib, json, os

root = sys.argv[1]
window = int(sys.argv[2])
min_occ = int(sys.argv[3])
min_files = int(sys.argv[4])
rels = sys.argv[5:]

def normalize_line(line):
    s = line.strip()
    if not s or s.startswith('#'):
        return None
    return ' '.join(s.split())

file_lines = {}
for rel in rels:
    abspath = os.path.join(root, rel)
    try:
        with open(abspath, 'r', errors='replace') as fh:
            raw = fh.readlines()
    except OSError:
        raw = []
    norm = [normalize_line(l) for l in raw]
    file_lines[rel] = [l for l in norm if l is not None]

hash_info = {}
file_window_hashes = {}
for rel, lines in file_lines.items():
    hashes = []
    n = len(lines)
    if n >= window:
        for i in range(n - window + 1):
            chunk = '\n'.join(lines[i:i + window])
            h = hashlib.sha1(chunk.encode('utf-8')).hexdigest()
            hashes.append(h)
            info = hash_info.setdefault(h, {"count": 0, "files": set()})
            info["count"] += 1
            info["files"].add(rel)
    file_window_hashes[rel] = hashes

qualifying = {
    h for h, info in hash_info.items()
    if info["count"] >= min_occ or len(info["files"]) >= min_files
}

result = {}
for rel in rels:
    hashes = file_window_hashes.get(rel, [])
    dup_count = sum(1 for h in hashes if h in qualifying)
    peers = set()
    for h in hashes:
        if h in qualifying:
            peers.update(hash_info[h]["files"])
    peers.discard(rel)
    result[rel] = {
        "duplicate_blocks": dup_count,
        "duplicate_block_peers": sorted(peers),
    }

print(json.dumps(result))
PYEOF

declare -A DUP_COUNT=()
declare -A DUP_PEERS_JSON=()
while IFS=$'\t' read -r dup_rel dup_cnt dup_peers_json; do
  [ -n "$dup_rel" ] || continue
  DUP_COUNT["$dup_rel"]="$dup_cnt"
  DUP_PEERS_JSON["$dup_rel"]="$dup_peers_json"
done < <(jq -r 'to_entries[] | [.key, .value.duplicate_blocks, (.value.duplicate_block_peers | tojson)] | @tsv' "$DUP_TMP")

# ── Per-candidate metrics ──────────────────────────────────────────────────────────────────────
ANY_ZERO_CALLER=0
ANY_UNREGISTERED=0
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

  # manifest_registered: category-aware (scripts/ via Rule Q reuse above; hooks/ via a direct
  # provides.hooks membership check, since Rule Q's jurisdiction stops at scripts/).
  manifest_registered="null"
  case "$rel" in
    agent-system/extensions/*/scripts/*)
      ext_name="${rel#agent-system/extensions/}"
      ext_name="${ext_name%%/*}"
      rel_in_scripts="${rel#agent-system/extensions/"$ext_name"/scripts/}"
      if [ "$MANIFEST_CHECK_AVAILABLE" -eq 1 ]; then
        if [ -n "${UNREGISTERED_SCRIPT["${ext_name}|${rel_in_scripts}"]+x}" ]; then
          manifest_registered="false"
        else
          manifest_registered="true"
        fi
      fi
      ;;
    agent-system/extensions/*/hooks/*)
      ext_name="${rel#agent-system/extensions/}"
      ext_name="${ext_name%%/*}"
      manifest_path="$ROOT/agent-system/extensions/$ext_name/manifest.json"
      if [ -f "$manifest_path" ] && jq -e --arg h "$base" \
          '(.provides.hooks // [])[] | select(. == $h)' "$manifest_path" >/dev/null 2>&1; then
        manifest_registered="true"
      else
        manifest_registered="false"
      fi
      ;;
  esac
  if [ "$manifest_registered" = "false" ]; then
    ANY_UNREGISTERED=1
  fi

  duplicate_blocks="${DUP_COUNT[$rel]:-0}"
  duplicate_block_peers_json="${DUP_PEERS_JSON[$rel]:-[]}"

  script_json="$(jq -n \
    --arg path "$rel" \
    --argjson lines "$lines" \
    --argjson bytes "$bytes" \
    --argjson inbound_callers "$inbound_callers" \
    --argjson inbound_caller_paths "$callers_json" \
    --argjson zero_caller_finding "$zero_caller_finding" \
    --argjson has_test "$has_test" \
    --argjson test_paths "$test_paths_json" \
    --argjson manifest_registered "$manifest_registered" \
    --argjson duplicate_blocks "$duplicate_blocks" \
    --argjson duplicate_block_peers "$duplicate_block_peers_json" \
    '{
      path: $path,
      lines: $lines,
      bytes: $bytes,
      inbound_callers: $inbound_callers,
      inbound_caller_paths: $inbound_caller_paths,
      zero_caller_finding: $zero_caller_finding,
      has_test: $has_test,
      test_paths: $test_paths,
      manifest_registered: $manifest_registered,
      duplicate_blocks: $duplicate_blocks,
      duplicate_block_peers: $duplicate_block_peers
    }')"

  SCRIPT_JSON_PARTS+=("$script_json")
  unset callers test_paths
done

if [ "$CHECK_MODE" -eq 1 ]; then
  for part in "${SCRIPT_JSON_PARTS[@]}"; do
    printf '%s\n' "$part" | jq -r '[.path, .lines, .inbound_callers, .has_test, .manifest_registered, .duplicate_blocks] | @tsv'
  done
  if [ "$ANY_ZERO_CALLER" -eq 1 ] || [ "$ANY_UNREGISTERED" -eq 1 ]; then
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
TMP_FILES+=("$SCRIPTS_TMP")
printf '%s\n' "${SCRIPT_JSON_PARTS[@]}" | jq -s '.' > "$SCRIPTS_TMP"

jq -n \
  --arg root "$ROOT" \
  --arg generated_at "$generated_at" \
  --argjson candidate_count "${#CANDIDATES[@]}" \
  --slurpfile scripts_wrap "$SCRIPTS_TMP" \
  '
  def score: .lines + (if .zero_caller_finding then 500 else 0 end) + (.duplicate_blocks // 0);
  ($scripts_wrap[0] | map(. + {score: score})) as $scored
  | ($scored | sort_by([-.score, .path]) | to_entries | map(.value + {rank: (.key + 1)})) as $ranked
  | {
    root: $root,
    generated_at: $generated_at,
    candidate_count: $candidate_count,
    scripts: $ranked,
    ranking: [$ranked[].path],
    summary: {
      total_lines: ([$ranked[].lines] | add),
      total_bytes: ([$ranked[].bytes] | add),
      zero_caller_count: ([$ranked[] | select(.zero_caller_finding == true)] | length),
      untested_count: ([$ranked[] | select(.has_test == false)] | length),
      unregistered_count: ([$ranked[] | select(.manifest_registered == false)] | length),
      duplicate_block_script_count: ([$ranked[] | select(.duplicate_blocks > 0)] | length)
    }
  }'
