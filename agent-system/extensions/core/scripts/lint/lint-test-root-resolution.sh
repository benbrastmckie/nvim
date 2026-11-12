#!/usr/bin/env bash
# lint-test-root-resolution.sh - Guard against the invocation-path-dependent fixed-depth
# repo-root/extensions-root parent walk defect class in this corpus's own shell test suites.
#
# WHY THIS EXISTS
# ----------------
# A test suite's own directory sits at a DIFFERENT depth below the repository root depending on
# which of its two copies is invoked: the source-store original
# (agent-system/extensions/core/scripts/[tests|lint]/...) and the deployed mirror
# (.claude/scripts/[tests|lint]/...), which is two directory levels SHALLOWER (it has no
# agent-system/extensions/core wrapper). A suite that resolves its own repo root (or extensions
# root) with an UNCONDITIONAL fixed-depth `cd "<N literal ../ segments>" && pwd` walk is correct
# from at most one of the two invocation paths and silently wrong from the other -- landing either
# outside the repository entirely, or on some unrelated ancestor directory. Three live instances
# of exactly this shape were found and migrated onto the canonical replacement
# (common_test_repo_root / common_test_ext_root in lib/common.sh) in the remedy that preceded this
# lint; a bounded measure-first sweep for that remedy additionally found two MORE instances nobody
# had named, and one of the five turned out to be masking a real defect once fixed. The class is
# demonstrably wider than any hand-assembled list, which is why this is a mechanical gate rather
# than another one-off sweep.
#
# CRITICAL DISTINCTION THIS LINT DEPENDS ON -- NOT EVERY FIXED-DEPTH WALK IS FORBIDDEN:
# ---------------------------------------------------------------------------------------
# A walk that only reaches the directory holding `scripts/`, `hooks/`, `context/`, etc. as
# siblings (the "extension-root boundary": `core/` in the source store, `.claude/` deployed) is
# SAFE and extremely common in this corpus -- that boundary sits at the SAME relative depth below
# a test suite's own directory in BOTH trees, because the deploy step flattens the per-extension
# `core/` wrapper into `.claude/` without changing anything below `scripts/`. A walk that reaches
# FURTHER than that boundary (toward `agent-system/extensions/` or the repository root) is UNSAFE,
# because that is exactly where the two trees diverge by two levels. This lint computes, per
# candidate file, the SAFE_LEVELS boundary from the file's own location under `scripts/` --
# 1 for a flat `scripts/*.sh` file, 2 for a `scripts/tests/*.sh` or `scripts/lint/*.sh` file -- and
# flags only a walk whose effective depth EXCEEDS that boundary. A naive "any walk of 2+ levels is
# forbidden" rule would misfire on real, correct suites (e.g. a `TREE_ROOT="$(cd
# "$SCRIPT_DIR/../.." && pwd)"` resolving the same extension-root boundary from scripts/tests/,
# confirmed safe and in live use) -- this lint exists specifically to NOT make that mistake.
#
# TWO VALID (SANCTIONED) GUARDED SHAPES, in addition to the canonical common_test_repo_root /
# common_test_ext_root replacement itself (which this lint never sees, since those are function
# calls, not a literal `cd ... && pwd` walk):
#   (a) First-attempt-then-fallback: the fixed-depth walk sits inside an enclosing
#       `if [[ -z "$VAR" ]]` (or `[ -z "$VAR" ]`) block, run only because an earlier resolution
#       attempt for that SAME variable already failed -- a `git rev-parse --show-toplevel` probe
#       is the common case, but an ancestor-directory-search loop guarded the same way is equally
#       sanctioned (both share the one semantic that matters: never unconditional). Detected by
#       this guard's own structural shape, not by which specific earlier attempt populated it.
#   (b) Validated candidate: the computed path is tested with `[ -d ... ]` / `[ -f ... ]` against
#       the SAME variable before being accepted, with a differently-shaped fallthrough on failure
#       (e.g. run-all.sh's own source-store/deployed mode detection) -- or, for a bare inline use
#       with no assignment at all, the identical literal is itself the direct subject of a
#       `[ -f ... ]` / `[ -d ... ]` test on the same line.
#
# DETECTION MODEL (two-pass, line-oriented, deliberately bounded -- see KNOWN LIMITATION)
# ------------------------------------------------------------------------------------------
# Per candidate file:
#   PASS 1 -- anchor-offset discovery: scan for the one recognized indirection idiom in this
#     corpus, `NAME="$(cd "$SCRIPT_DIR/.." && pwd)"` (exactly one `..` segment off $SCRIPT_DIR,
#     e.g. CORE_DIR). Record that NAME's own offset as 1 (SCRIPT_DIR itself is always offset 0,
#     implicitly). No other indirection idiom is tracked -- see KNOWN LIMITATION.
#   PASS 2 -- violation detection, three shapes, each anchored on $SCRIPT_DIR or a PASS-1-tracked
#     name, with effective depth = anchor's own offset + the literal `..` segment count in the
#     walk's own path expression:
#     (1) Single-line assignment: `TARGET="$(cd "$ANCHOR<segments>" ... && pwd ...)"`.
#     (2) Two-statement: a bare `cd "$ANCHOR<segments>"` line (no `&&`), with a `TARGET=$(pwd)`
#         (or backtick form) within the next 3 lines.
#     (3) Bare inline use: the same `$ANCHOR<segments>` literal, quoted, used directly as a
#         command/path argument with no separate assignment step (so guard (a) can never apply --
#         there is no TARGET variable for an enclosing `if [[ -z ... ]]` to name).
#   A line already handled by shape (1) or (2) is never also reported under shape (3).
#   For shapes (1)/(2), a candidate whose effective depth exceeds SAFE_LEVELS is suppressed (not
#   reported) when either guard above is found for the SAME target variable: guard (a) within the
#   5 lines immediately preceding the walk, guard (b) within the 8 lines following the
#   assignment. Shape (3) only ever gets guard (b)'s inline variant (the literal validated on the
#   SAME line); it is otherwise always reported when effective depth exceeds SAFE_LEVELS, unless
#   allowlisted.
#   Full-line comments (stripped line starts with `#`) are excluded from all three shapes.
#
# KNOWN LIMITATION (stated plainly, matching this cluster's own convention): this is a
# regex-only, line-oriented content lint, not a shell parser. Anchor-offset tracking is limited
# to $SCRIPT_DIR (offset 0) and the single `NAME="$(cd "$SCRIPT_DIR/.." && pwd)"` idiom (offset
# 1); a walk anchored on any OTHER already-resolved root-like variable (e.g. a validated
# `EXTENSIONS_ROOT` used as the base for a further walk) is not tracked and is silently not
# checked -- in every instance observed in this corpus, such a variable was itself produced by an
# already-guarded resolution and consumed only inside the branch that validated it, so this is a
# bounded, not unbounded, blind spot. Treat a clean run as "the known bad shape is not present",
# never as "every root computation in this suite is provably safe".
#
# SCAN SCOPE: shell "test suite" files, matching script-inventory.sh's own test-file
# classification exactly (so the two stay in lockstep): a `*.sh` file is in scope when it lives
# under a `tests/` directory anywhere in its path, OR its basename starts with the literal
# prefix `test-`.
#
# Usage: lint-test-root-resolution.sh [--verbose] [--help] [path...]
#   With no path arguments, scans the default corpus described above. Path arguments (used by
#   this script's own fixture suite) replace the default corpus entirely rather than adding to
#   it, and are scanned as given regardless of the tests//test-* classification.
#
# Exit codes:
#   0 - no violations found
#   1 - one or more violations found
#   2 - environment/usage error (scan root not found, unknown argument)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VERBOSE=false
EXPLICIT_PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: lint-test-root-resolution.sh [--verbose] [--help] [path...]"
      echo ""
      echo "Fails if a shell test suite computes its own repo root or extensions root with an"
      echo "unconditional fixed-depth parent walk (cd \"<N literal ../ segments>\" && pwd, its"
      echo "two-statement variant, or a bare inline use of the same literal), reaching PAST the"
      echo "extension-root boundary (core/ in the source store, .claude/ deployed) -- a depth"
      echo "that diverges by two levels between the source-store original and the deployed"
      echo "mirror. The canonical replacement is common_test_repo_root / common_test_ext_root in"
      echo "lib/common.sh. A git-first-guarded fallback or a validated-candidate-with-fallthrough"
      echo "stays unflagged; see this script's own header for the full detection model."
      echo ""
      echo "Exit codes: 0 = no violations, 1 = violations found, 2 = environment/usage error"
      exit 0
      ;;
    -*)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
    *)
      EXPLICIT_PATHS+=("$1")
      shift
      ;;
  esac
done

# ── Root resolution (this lint practices what it polices: git-first, fixed-depth fallback) ────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

EXTENSIONS_ROOT="$REPO_ROOT/agent-system/extensions"

VIOLATIONS=0
FILES_SCANNED=0

log_info() { $VERBOSE && echo "[INFO] $1" || true; }

# ── Known, narrowly-reasoned allowlist ──────────────────────────────────────────────────────────
# Keyed `<repo-relative-path>:<line-number>`. An entry here is a deliberate, inspected,
# per-instance act -- never the default response to a failing run. See this script's own header:
# this suite's sole assertion is a crash net (asserting that no registered gate itself crashes),
# which is insensitive to the fixture's own correctness by design, so a wrong computed root here
# cannot change the suite's verdict either way. The walk is also anchored on CORE_DIR (an
# already-offset variable), not bare $SCRIPT_DIR, so it cannot be mechanically discriminated from
# the genuinely dangerous shape by any regex this lint could write.
declare -A ALLOWLIST=(
  ["agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection-crash-net.sh:51"]="crash-net suite: insensitive to fixture root correctness by design; CORE_DIR-anchored, not mechanically discriminable from the forbidden shape"
)

is_allowlisted() {
  local relpath="$1" lineno="$2"
  [[ -n "${ALLOWLIST["${relpath}:${lineno}"]:-}" ]]
}

# safe_levels_for <file_dir> -- echoes the number of levels a walk may ascend from <file_dir>
# before it crosses the extension-root boundary (1 for a flat scripts/ file, 2 for a
# scripts/tests/ or scripts/lint/ file, etc.). See header's CRITICAL DISTINCTION section.
safe_levels_for() {
  local dir="$1"
  case "$dir" in
    */scripts)
      echo 1
      ;;
    */scripts/*)
      local rel="${dir#*/scripts/}"
      local IFS='/'
      local -a parts
      read -r -a parts <<< "$rel"
      echo $(( ${#parts[@]} + 1 ))
      ;;
    *)
      echo 1
      ;;
  esac
}

# count_levels <dotdot_chain> -- echoes the number of ".." segments in a chain made purely of
# '.' and '/' characters (e.g. "/../../../.." -> 4).
count_levels() {
  local chain="$1"
  local stripped="${chain//\//}"
  echo $(( ${#stripped} / 2 ))
}

ANCHOR_RE='\$(SCRIPT_DIR|CORE_DIR)'

scan_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  FILES_SCANNED=$((FILES_SCANNED + 1))

  local relpath="$file"
  case "$file" in
    "$REPO_ROOT"/*) relpath="${file#"$REPO_ROOT"/}" ;;
  esac

  local filedir
  filedir="$(cd "$(dirname "$file")" && pwd)"
  local safe_levels
  safe_levels="$(safe_levels_for "$filedir")"

  local -a lines=()
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done < "$file"
  local n_lines=${#lines[@]}

  # ── Heredoc-body exclusion ───────────────────────────────────────────────────────────────────
  # A line inside a `<<[-]TOKEN ... TOKEN` heredoc body is DATA being written out (most often a
  # synthetic fixture under this very lint's own test suite, which necessarily embeds literal
  # example text shaped exactly like the forbidden walk), never live code in the file doing the
  # scanning -- skip the whole body, both shapes (quoted and unquoted delimiter), to avoid
  # scanning a fixture suite's own fixture text as if it were a real violation in that suite
  # itself. KNOWN LIMITATION: this also skips an unquoted heredoc's body, which IS live,
  # variable-expanding code in principle -- no instance of a root-resolution walk written inside
  # an unquoted heredoc exists in this corpus today, so this is a bounded, not unbounded, blind
  # spot, consistent with this lint's other line-oriented limitations.
  local -A in_heredoc=()
  local hd_terminator="" hd_active=false
  for ((i = 0; i < n_lines; i++)); do
    local hl="${lines[$i]}"
    if $hd_active; then
      in_heredoc["$i"]=1
      if [[ "$hl" =~ ^[[:space:]]*${hd_terminator}[[:space:]]*$ ]]; then
        hd_active=false
        hd_terminator=""
      fi
      continue
    fi
    if [[ "$hl" =~ \<\<-?[[:space:]]*[\'\"]?([A-Za-z_][A-Za-z0-9_]*)[\'\"]? ]]; then
      hd_terminator="${BASH_REMATCH[1]}"
      hd_active=true
    fi
  done

  # ── PASS 1: anchor-offset discovery (the single recognized CORE_DIR idiom) ──────────────────
  local -A anchor_offset=()
  local i
  for ((i = 0; i < n_lines; i++)); do
    [[ -n "${in_heredoc[$i]:-}" ]] && continue
    local l="${lines[$i]}"
    [[ "$l" =~ ^[[:space:]]*# ]] && continue
    if [[ "$l" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=\"\$\(cd[[:space:]]+\"\$SCRIPT_DIR/\.\.\"[[:space:]]*\&\&[[:space:]]*pwd[^\)]*\)\" ]]; then
      anchor_offset["${BASH_REMATCH[1]}"]=1
    fi
  done

  # ── PASS 2: violation detection ──────────────────────────────────────────────────────────────
  local -A reported_lines=()
  local found_violation=false

  # has_enclosing_if_guard <target> <idx> -- true when one of the (up to) 5 lines immediately
  # preceding <idx> opens an `if [[ -z "$<target>" ]]` / `if [ -z "$<target>" ]` guard -- the
  # structural signature shared by a git-first fallback (REPO_ROOT="$(git ... rev-parse
  # --show-toplevel ...)"; if [[ -z "$REPO_ROOT" ]]; then <fixed-depth walk>; fi) AND an
  # ancestor-directory-search fallback (a loop populating the same variable, then an identical
  # if-guarded fixed-depth walk of last resort). Deliberately guard-SOURCE-agnostic: what makes
  # either shape safe is that the walk runs ONLY when some earlier resolution attempt already
  # failed, not which specific attempt that was.
  has_enclosing_if_guard() {
    local target="$1" idx="$2"
    local start=$(( idx - 5 ))
    (( start < 0 )) && start=0
    local w_i
    for ((w_i = start; w_i < idx; w_i++)); do
      if [[ "${lines[$w_i]}" =~ if[[:space:]]*\[\[?[[:space:]]+-z[[:space:]]+\"\$\{?${target}\}? ]]; then
        return 0
      fi
    done
    return 1
  }

  report_violation() {
    local lineno="$1" target="$2" effective="$3"
    reported_lines["$lineno"]=1
    if is_allowlisted "$relpath" "$lineno"; then
      log_info "allowlisted: $relpath:$lineno (${ALLOWLIST["${relpath}:${lineno}"]})"
      return 0
    fi
    echo -e "${RED}[VIOLATION]${NC} $file:$lineno"
    echo "  Unconditional fixed-depth walk assigns/uses '${target}' at effective depth"
    echo "  ${effective}, exceeding this file's safe extension-root boundary (${safe_levels})."
    echo "  Reaches toward agent-system/extensions/ or the repository root -- a depth that"
    echo "  diverges by two levels between the source-store original and the deployed mirror."
    echo "  Replace with common_test_repo_root / common_test_ext_root (lib/common.sh), or add a"
    echo "  git-first fallback / validated-candidate guard if a fixed walk is genuinely required."
    VIOLATIONS=$((VIOLATIONS + 1))
    found_violation=true
  }

  for ((i = 0; i < n_lines; i++)); do
    [[ -n "${in_heredoc[$i]:-}" ]] && continue
    local l="${lines[$i]}"
    local lineno=$((i + 1))
    [[ "$l" =~ ^[[:space:]]*# ]] && continue
    [[ -n "${reported_lines[$lineno]:-}" ]] && continue

    # Shape 1: single-line cd+pwd assignment.
    if [[ "$l" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=\"\$\(cd[[:space:]]+\"${ANCHOR_RE}([./]+)\"[^\)]*\&\&[[:space:]]*pwd[^\)]*\)\" ]]; then
      local target="${BASH_REMATCH[1]}" anchor="${BASH_REMATCH[2]}" chain="${BASH_REMATCH[3]}"
      local n2 effective
      n2="$(count_levels "$chain")"
      effective=$(( ${anchor_offset[$anchor]:-0} + n2 ))
      reported_lines["$lineno"]=1
      if (( effective > safe_levels )); then
        # Guard (a): this walk sits inside an enclosing `if [[ -z "$TARGET" ]]` fallback block --
        # a git-first OR an ancestor-search-first resolution, either way run only after an
        # earlier attempt already failed.
        local guarded=false
        if has_enclosing_if_guard "$target" "$i"; then
          guarded=true
        fi
        # Guard (b): validated candidate for the SAME target, within the next 8 lines.
        if ! $guarded; then
          local k end=$(( i + 8 ))
          (( end >= n_lines )) && end=$(( n_lines - 1 ))
          for ((k = i; k <= end; k++)); do
            local vl="${lines[$k]}"
            if [[ "$vl" =~ \[[[:space:]]+-[df][[:space:]]+\"\$\{?${target}\}? ]]; then
              guarded=true
              break
            fi
          done
        fi
        if ! $guarded; then
          report_violation "$lineno" "$target" "$effective"
        else
          log_info "OK (guarded): $relpath:$lineno ($target, effective depth $effective)"
        fi
      fi
      continue
    fi

    # Shape 2: two-statement cd ...; TARGET=$(pwd) (or backtick form).
    if [[ "$l" =~ ^[[:space:]]*cd[[:space:]]+\"${ANCHOR_RE}([./]+)\"[[:space:]]*\;?[[:space:]]*$ ]]; then
      local anchor2="${BASH_REMATCH[1]}" chain2="${BASH_REMATCH[2]}"
      local n2b effective2
      n2b="$(count_levels "$chain2")"
      effective2=$(( ${anchor_offset[$anchor2]:-0} + n2b ))
      reported_lines["$lineno"]=1
      if (( effective2 > safe_levels )); then
        local target2="" m end2=$(( i + 3 ))
        (( end2 >= n_lines )) && end2=$(( n_lines - 1 ))
        local m
        for ((m = i + 1; m <= end2; m++)); do
          local pl="${lines[$m]}"
          if [[ "$pl" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=\$\(pwd\)[[:space:]]*$ ]] || \
             [[ "$pl" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=\`pwd\`[[:space:]]*$ ]]; then
            target2="${BASH_REMATCH[1]}"
            reported_lines["$((m + 1))"]=1
            break
          fi
        done
        if [[ -n "$target2" ]]; then
          local guarded2=false
          if has_enclosing_if_guard "$target2" "$i"; then
            guarded2=true
          fi
          if ! $guarded2; then
            local k2 vend=$(( i + 10 ))
            (( vend >= n_lines )) && vend=$(( n_lines - 1 ))
            for ((k2 = i; k2 <= vend; k2++)); do
              local vl2="${lines[$k2]}"
              if [[ "$vl2" =~ \[[[:space:]]+-[df][[:space:]]+\"\$\{?${target2}\}? ]]; then
                guarded2=true
                break
              fi
            done
          fi
          if ! $guarded2; then
            report_violation "$lineno" "$target2 (two-statement cd/pwd)" "$effective2"
          else
            log_info "OK (guarded): $relpath:$lineno ($target2, two-statement, effective depth $effective2)"
          fi
        fi
      fi
      continue
    fi

    # Shape 3: bare inline use (no assignment at all -- never guardable by a nearby check on a
    # TARGET variable, since there is none). Exception: the literal itself can still be validated
    # INLINE, on this same line, when it is the direct subject of a `[ -f ... ]` / `[ -d ... ]`
    # test (e.g. `elif [ -f "$SCRIPT_DIR/../../../core/scripts/lib/common.sh" ]; then`) -- that is
    # the bare-literal analogue of the validated-candidate shape, just without an intervening
    # assignment, and is sanctioned the same way.
    if [[ "$l" =~ \"${ANCHOR_RE}([./]+) ]]; then
      local anchor3="${BASH_REMATCH[1]}" chain3="${BASH_REMATCH[2]}"
      local same_line_validated=false
      if [[ "$l" =~ \[[[:space:]]+-[df][[:space:]] ]]; then
        same_line_validated=true
      fi
      # "Assign now, validated moments ago" -- the identical literal was just the subject of a
      # `[ -f ... ]` / `[ -d ... ]` test one of the last 3 lines (the `elif [ -f "<cand>" ]; then`
      # / `VAR="<cand>"` idiom): extract this line's full quoted literal and look for it, as an
      # exact substring, inside a bracket-test on a recent preceding line.
      local validated_recently=false
      if ! $same_line_validated && [[ "$l" =~ \"(\$${anchor3}[^\"]*)\" ]]; then
        local full_literal="${BASH_REMATCH[1]}"
        local back start_b=$(( i - 3 ))
        (( start_b < 0 )) && start_b=0
        for ((back = start_b; back < i; back++)); do
          local bl="${lines[$back]}"
          if [[ "$bl" == *"$full_literal"* ]] && [[ "$bl" =~ \[[[:space:]]+-[df][[:space:]] ]]; then
            validated_recently=true
            break
          fi
        done
      fi
      # "Assign now, validated shortly after" -- this line is a plain `VAR="<literal>"`
      # assignment whose TARGET is tested via `[ -f "$VAR" ]` / `[ -d "$VAR" ]` within the next
      # 8 lines (guard (b)'s own assign-first shape, e.g. GUARD_CANDIDATE_SOURCE below).
      local validated_soon=false
      if ! $same_line_validated && ! $validated_recently && \
         [[ "$l" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=\"\$${anchor3}[./][^\"]*\"[[:space:]]*$ ]]; then
        local target3="${BASH_REMATCH[1]}"
        local fwd end3=$(( i + 8 ))
        (( end3 >= n_lines )) && end3=$(( n_lines - 1 ))
        for ((fwd = i + 1; fwd <= end3; fwd++)); do
          if [[ "${lines[$fwd]}" =~ \[[[:space:]]+-[df][[:space:]]+\"\$\{?${target3}\}? ]]; then
            validated_soon=true
            break
          fi
        done
      fi
      if ! $same_line_validated && ! $validated_recently && ! $validated_soon; then
        local n3 effective3
        n3="$(count_levels "$chain3")"
        effective3=$(( ${anchor_offset[$anchor3]:-0} + n3 ))
        if (( effective3 > safe_levels )); then
          report_violation "$lineno" "\$${anchor3}${chain3} (bare inline use)" "$effective3"
        fi
      fi
    fi
  done

  if ! $found_violation; then
    log_info "OK: $file"
  fi
}

if [[ ${#EXPLICIT_PATHS[@]} -gt 0 ]]; then
  for p in "${EXPLICIT_PATHS[@]}"; do
    scan_file "$p"
  done
else
  if [[ ! -d "$EXTENSIONS_ROOT" ]]; then
    echo "ERROR: extensions root not found at $EXTENSIONS_ROOT" >&2
    exit 2
  fi
  while IFS= read -r f; do
    scan_file "$f"
  done < <(find "$EXTENSIONS_ROOT" -type f -name '*.sh' \( -path '*/tests/*' -o -name 'test-*' \) 2>/dev/null | sort)
fi

echo ""
if [[ "$VIOLATIONS" -eq 0 ]]; then
  echo -e "${GREEN}[PASS]${NC} lint-test-root-resolution: 0 violation(s) across $FILES_SCANNED file(s)"
  exit 0
else
  echo -e "${RED}[FAIL]${NC} lint-test-root-resolution: $VIOLATIONS violation(s) across $FILES_SCANNED file(s)"
  exit 1
fi
