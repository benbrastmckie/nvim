#!/usr/bin/env bash
# lint-verdict-extraction-anchoring.sh - Detect a verdict-token extraction site that bypasses
# the anchored, SGR-stripping helper `verify_deploy_extract_verdict_lines`
# (lib/gate-verdict-extract-lib.sh).
#
# WHY THIS EXISTS
# ----------------
# context/standards/shell-script-testing.md's "Verdict-line extraction contract
# (producer/consumer)" section states the rule: a gate that folds a producer script's output
# into FINDING rows must extract the producer's verdict lines through
# `verify_deploy_extract_verdict_lines`, never by hand-rolling a `grep` against the raw captured
# output. That rule was, until this lint existed, defended only by prose. Two distinct bad shapes
# were both measured live against real gate output before the helper was introduced:
#   - UNANCHORED: `grep -F '[FAIL]'` / `grep -F '[VIOLATION]'` matches the literal token ANYWHERE
#     in a line, so a narration line that merely quotes the token in its own message text (or a
#     producer's own nested/indented fixture-internal output) is folded into a FINDING row.
#   - NAIVE-ANCHOR, SGR-BLIND: `grep -E '^\[FAIL\]'` / `grep -E '^\[VIOLATION\]'` looks like a
#     hardening fix over the unanchored form, but most producers in this corpus emit their
#     verdict row as `echo -e "${RED}[FAIL]${NC} ..."` with no TTY/NO_COLOR guard, so the row
#     begins with an ANSI SGR escape sequence rather than the literal token. A naive line-start
#     anchor REJECTS every one of those rows, silently converting a real gate into a zero-finding
#     gate -- the more dangerous shape of the two, because it reads as a correctness improvement.
# `verify_deploy_extract_verdict_lines` fixes both: it strips SGR sequences first, then anchors
# on "<token><single space>" at the (post-strip) line start. This lint is the guardrail against
# a future author reintroducing either bad shape instead of calling that helper.
#
# DETECTION MODEL
# ----------------
# Two layers, applied in order to every line matching the broad candidate pattern (a `grep -F`
# or `grep -E` call whose quoted pattern argument contains a bracketed `FAIL` or `VIOLATION`
# token):
#
#   Layer 1 (structural, line shape):
#     - A candidate line whose first non-whitespace character is `#` is EXEMPT -- a commented-out
#       grep never executes. This is what exempts gate-verdict-extract-lib.sh's own explanatory
#       header prose (which quotes both bad shapes to describe the defect they replace) and
#       lint-json-channel-discipline.sh's comment describing the "already filtered through
#       grep -F '[FAIL]'" shape, on principle rather than by per-file name.
#     - Otherwise, the quoted pattern argument's first character decides the verdict: if it is
#       `^`, the line is the NAIVE-ANCHOR, SGR-BLIND shape; otherwise it is the UNANCHORED shape.
#       Both are VIOLATIONs, reported with visibly different remedy text.
#
#   Layer 2 (file-level allowlist): a short, explicitly-reasoned list of files that legitimately
#     contain the executable bad shape in their own source. Every entry states its reason inline.
#
# KNOWN LIMITATION (stated plainly rather than papered over)
# ------------------------------------------------------------
# This is a regex-only, line-oriented content lint. It CANNOT catch a variable-indirected
# extraction (a pattern or token assembled into a variable before being passed to `grep`) or one
# assembled across more than one line (a pattern built on one line and applied via a stored
# command on another). It is a guardrail against the recurrence of the two literal bad shapes
# named above, not a proof that every extraction site in the corpus is helper-routed.
#
# SCAN CORPUS
# -----------
# Deliberately narrow, not the whole source store: `scripts/verify-deploy.sh`,
# `scripts/lib/gate-verdict-extract-lib.sh`, and `scripts/lint/*.sh`. This is the contract's own
# stated scope ("a gate that folds a producer script's output into FINDING rows") -- widening the
# corpus to the whole tree would false-positive on ordinary test-assertion lines that have
# nothing to do with this contract.
#
# Usage: lint-verdict-extraction-anchoring.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is scanned recursively for
#              .sh files. Defaults to the narrow corpus named above, resolved under the source
#              store -- never `agent-system/extensions` as a whole.
#   --verbose  Report every candidate line found, including exempt ones, tagged with the reason
#              each was exempted.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never
#              silent.
#
# Exit codes:
#   0 - No unexcluded hits found
#   1 - One or more unexcluded hits found (each printed as file:line plus the matched text)
#   2 - Script error (unresolvable project root, missing shared library, unreadable scan path)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=false
QUIET=false
SCAN_PATHS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
    echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/common.sh" >&2
    exit 2
fi
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"
if [[ ! -f "${SCRIPT_DIR}/../lib/lint-corpus-scan-lib.sh" ]]; then
    echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/lint-corpus-scan-lib.sh" >&2
    exit 2
fi
# shellcheck source=../lib/lint-corpus-scan-lib.sh
source "${SCRIPT_DIR}/../lib/lint-corpus-scan-lib.sh"

lint_corpus_scan_parse_flags SCAN_PATHS VERBOSE QUIET -- "$@" || exit 2

# Root resolution. common_repo_root <dir> 3 is correct for the DEPLOYED copy
# (.claude/scripts/lint/), but this script also runs directly from the source store
# (agent-system/extensions/core/scripts/lint/), where 3 levels up lands inside the extension
# rather than at the repo root. Resolve by walking up until a directory containing
# agent-system/extensions is found, falling back to the common_repo_root answer.
resolve_project_root() {
    local candidate
    candidate="$(common_repo_root "$SCRIPT_DIR" 3)"
    if [[ -n "$candidate" && -d "$candidate/agent-system/extensions" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    local dir="$SCRIPT_DIR"
    local i=0
    while [[ $i -lt 8 ]]; do
        dir="$(cd "$dir/.." 2>/dev/null && pwd)" || break
        [[ -z "$dir" || "$dir" == "/" ]] && break
        if [[ -d "$dir/agent-system/extensions" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi
        i=$((i + 1))
    done

    # No source store located (e.g. a deploy-only checkout). The common_repo_root answer is still
    # the best available root for relative-path reporting; explicit scan paths remain usable.
    printf '%s\n' "$candidate"
    return 0
}

PROJECT_ROOT="$(resolve_project_root)"
CORE_SCRIPTS="$PROJECT_ROOT/agent-system/extensions/core/scripts"

if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
    if [[ ! -d "$CORE_SCRIPTS" ]]; then
        echo "ERROR: default scan root not found: $CORE_SCRIPTS" >&2
        echo "       Pass explicit path arguments, or run from a checkout containing the source store." >&2
        exit 2
    fi
    SCAN_PATHS=(
        "$CORE_SCRIPTS/verify-deploy.sh"
        "$CORE_SCRIPTS/lib/gate-verdict-extract-lib.sh"
        "$CORE_SCRIPTS/lint"
    )
fi

# ---------------------------------------------------------------------------
# Candidate pattern
# ---------------------------------------------------------------------------
# Deliberately broad -- it over-matches (it does not yet distinguish the two bad shapes from each
# other, nor from a comment line), and classify_line narrows below. Matches a `grep` call with a
# -F or -E flag (possibly combined with other short flags) whose quoted pattern argument contains
# a bracketed FAIL or VIOLATION token, with an optional leading `^` and optional escaping
# backslashes around the brackets (covering both `'[FAIL]'` and `'^\[FAIL\]'` shapes).
_dq='"'
_sq="'"
QUOTE_CLASS="[${_dq}${_sq}]"
CANDIDATE_PATTERN='grep[[:space:]]+-[A-Za-z]*[EF][A-Za-z]*[[:space:]]+'"$QUOTE_CLASS"'\^?\\?\[(FAIL|VIOLATION)\\?\]'

# ---------------------------------------------------------------------------
# Layer 2: file-level allowlist
# ---------------------------------------------------------------------------
# Repo-relative paths. Every entry states WHY it is exempt. The comment-line exemption in Layer 1
# already covers gate-verdict-extract-lib.sh's own header prose and
# lint-json-channel-discipline.sh's comment (see this file's own header above) -- neither needs a
# Layer 2 entry. This lint's own source is the one exception: its candidate-pattern and remedy-
# message literals sit in executable assignment/string lines, not comments, so Layer 1 alone
# would self-flag.
EXCLUDED_FILES=(
    # This lint's own source necessarily contains the literal bad-shape tokens in its candidate
    # pattern and remedy-message strings (executable lines, not comments) -- without this entry
    # it fails on itself.
    "agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh"
)

is_excluded_file() {
    local file="$1"
    local rel="${file#"$PROJECT_ROOT"/}"
    local entry
    for entry in "${EXCLUDED_FILES[@]}"; do
        [[ "$rel" == "$entry" ]] && return 0
        [[ "$file" == */"$entry" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Layer 1: structural classification of a single candidate line
# ---------------------------------------------------------------------------
# Echoes one of: "VIOLATION (unanchored)", "VIOLATION (naive-anchor, SGR-blind)",
# "EXEMPT: <reason>".
EXTRACT_ARG_RE='grep[[:space:]]+-[A-Za-z]*[EF][A-Za-z]*[[:space:]]+'"$QUOTE_CLASS"'([^'"${_dq}${_sq}"']*)'"$QUOTE_CLASS"

classify_line() {
    local text="$1"

    # Comment line -- never executes. Covers gate-verdict-extract-lib.sh's explanatory header and
    # lint-json-channel-discipline.sh's comment on principle, not by file name.
    local trimmed="${text#"${text%%[![:space:]]*}"}"
    if [[ "$trimmed" == \#* ]]; then
        printf 'EXEMPT: comment line\n'
        return 0
    fi

    if [[ "$text" =~ $EXTRACT_ARG_RE ]]; then
        local arg="${BASH_REMATCH[1]}"
        if [[ "$arg" == '^'* ]]; then
            printf 'VIOLATION (naive-anchor, SGR-blind)\n'
        else
            printf 'VIOLATION (unanchored)\n'
        fi
        return 0
    fi

    printf 'EXEMPT: no anchored-extraction shape\n'
    return 0
}

# ---------------------------------------------------------------------------
# Collect files to scan
# ---------------------------------------------------------------------------
FILES=()
lint_corpus_scan_collect_files FILES "" '*.sh' -- "${SCAN_PATHS[@]}" || exit 2

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------
VIOLATIONS=0
FILES_CHECKED=0
FILES_WITH_VIOLATIONS=0
EXEMPTED=0

$QUIET || {
    echo "Checking verdict-extraction anchoring compliance..."
    echo "Scan roots: ${SCAN_PATHS[*]}"
    echo ""
}

for file in "${FILES[@]}"; do
    ((FILES_CHECKED++)) || true

    file_excluded=false
    if is_excluded_file "$file"; then
        file_excluded=true
    fi

    matches=""
    matches="$(grep -nE "$CANDIDATE_PATTERN" "$file" 2>/dev/null || true)"
    [[ -z "$matches" ]] && continue

    file_violations=0
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        lineno="${match%%:*}"
        text="${match#*:}"
        # Trim leading whitespace for readable reporting.
        text="${text#"${text%%[![:space:]]*}"}"

        if $file_excluded; then
            ((EXEMPTED++)) || true
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: file-level allowlist entry | $text"
            continue
        fi

        verdict="$(classify_line "$text")"
        case "$verdict" in
            "VIOLATION (unanchored)")
                echo -e "${RED}[VIOLATION]${NC} $file:$lineno: unanchored verdict-token extraction -- route this through verify_deploy_extract_verdict_lines (lib/gate-verdict-extract-lib.sh) instead of a bare grep against the raw captured output: $text"
                ((file_violations++)) || true
                ((VIOLATIONS++)) || true
                ;;
            "VIOLATION (naive-anchor, SGR-blind)")
                echo -e "${RED}[VIOLATION]${NC} $file:$lineno: naive line-start-anchored extraction is SGR-blind -- most producers in this corpus emit their verdict row with a leading ANSI color escape, so this anchor silently rejects every colored row; strip SGR first via verify_deploy_extract_verdict_lines (lib/gate-verdict-extract-lib.sh), do not anchor directly on the raw captured output: $text"
                ((file_violations++)) || true
                ((VIOLATIONS++)) || true
                ;;
            *)
                ((EXEMPTED++)) || true
                $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: ${verdict#EXEMPT: } | $text"
                ;;
        esac
    done <<< "$matches"

    if [[ $file_violations -gt 0 ]]; then
        ((FILES_WITH_VIOLATIONS++)) || true
    fi
done

if [[ $VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Verdict-Extraction Anchoring Check Summary"
        echo "================================"
        echo "Files checked: $FILES_CHECKED"
        echo "Candidate lines exempted: $EXEMPTED"
        echo "Total violations: 0"
        echo -e "${GREEN}No unanchored or SGR-blind verdict-extraction sites found.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Verdict-Extraction Anchoring Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Files with violations: $FILES_WITH_VIOLATIONS"
echo "Candidate lines exempted: $EXEMPTED"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS unanchored or SGR-blind verdict-extraction site(s). See above for details.${NC}"
echo ""
echo "Fix: route the extraction through verify_deploy_extract_verdict_lines (see"
echo "scripts/lib/gate-verdict-extract-lib.sh's header for the contract and"
echo "context/standards/shell-script-testing.md's verdict-line extraction contract section)."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
