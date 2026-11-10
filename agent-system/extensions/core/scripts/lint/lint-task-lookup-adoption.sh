#!/usr/bin/env bash
# lint-task-lookup-adoption.sh - Detect hand-rolled full-record task-lookup jq shapes across the
# source store, on executable surfaces only.
#
# Two canonical implementations already do this lookup:
#   - skill_validate_input() in scripts/skill-base.sh (skill layer; a skill's own bash block
#     calls it after `source .../skill-base.sh`; exports TASK_DATA, TASK_TYPE, TASK_STATUS,
#     PROJECT_NAME, PADDED_NUM, TASK_DIR, TASK_DIR_ABS; `exit 1` on not-found/terminal status).
#   - gate_in() in scripts/command-gate-in.sh (command layer; sourced with two positional args;
#     exports SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM; `return 1`
#     on failure; also does locking, session registration, and the deploy-freshness warning).
# They are NOT interchangeable -- different export sets, different exit-vs-return semantics -- so
# this lint targets the literal duplication of their shared *shape*, not a call to unify them.
#
# The class this lint prevents from regrowing: a fresh skill or command hand-rolling
#   jq '.active_projects[] | select(.project_number == $num)' specs/state.json
# instead of calling one of the two helpers above. Copy-pasting that line is easy; this lint
# fails loudly when the literal narrow shape reappears anywhere under agent-system/extensions/.
#
# KNOWN LIMITATION (stated plainly rather than papered over)
# ---------------------------------------------------------
# This is a regex-only, line-oriented content lint. It therefore CANNOT catch:
#   - A variable-indirected lookup, e.g. a filter assembled into `$FILTER` on one line and used
#     on another; nothing in the source text of either line names the literal shape.
#   - A lookup whose `select(...)` clause spans more than one physical line (the balanced-paren
#     scan below only walks the single line a match was found on).
#   - A lookup performed by a helper the lint has no reason to suspect, or by any non-.md/.sh
#     artifact.
# This lint is a guardrail against regression and recurrence of the literal anti-pattern text. It
# is NOT a proof of absence of every possible hand-rolled task lookup. Treat a clean run as "the
# known bad shape is not present", never as "every task lookup goes through a canonical helper".
#
# DETECTION MODEL
# ---------------
# Two layers, applied in order:
#
#   Layer 1 (structural, line shape): every line containing the broad candidate pattern
#     `.active_projects[] | select(.project_number ==` (the equality comparison both canonical
#     helpers use -- a select on `.project_number` that does something else, e.g. an `as $pn |
#     ... index ...` membership test across a candidate list, is a structurally different
#     operation and is not a candidate at all) is classified by what surrounds the
#     `select(...)` clause (balanced-paren scan on that single line). VIOLATION is the narrow
#     full-record lookup: the filter terminates right after `select(...)` with nothing
#     meaningful piped after it -- the exact shape both canonical helpers implement. Four
#     legitimate shapes are EXEMPT by construction, each with its own reason: deletion
#     (`del(...)` wraps the lookup), in-place mutation (`|=`, `+=`, or a bare `.field =`
#     assignment follows), existence/length check (`[...] | length`), and single-field/complex
#     read (any further pipe, or `(...).field`, follows). A `select(...)` clause left unclosed
#     on its line cannot be safely classified and is treated as EXEMPT (see KNOWN LIMITATION).
#
#   Layer 2 (file-level allowlist): a short, explicitly-reasoned list of files that legitimately
#     contain the narrow shape today -- the two canonical implementations, plus current
#     migration-pending offenders. Every entry carries its reason inline; there are no bare paths
#     on that list by design. The allowlist is expected to shrink as sites migrate; adding an
#     entry is a deliberate act, not the default response to a failing run.
#
# Scan scope: `*.sh` across each extension's `scripts/` tree (excluding `scripts/tests/*.sh` and
# `scripts/deprecated/*.sh` by directory), plus `*.md` scoped ONLY to `commands/`, `skills/`,
# `agents/` subdirectories. `docs/`, `context/`, `rules/` are out of scope by construction, never
# by an exclusion list -- illustrative prose in those directories is never a lint target.
#
# Usage: lint-task-lookup-adoption.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is scanned per the scope rules
#              above. Defaults to the resolved project root's source-store or deployed scan roots
#              (see root resolution below).
#   --verbose  Report every candidate line found, including exempt ones, tagged with the reason
#              each was exempted. Mirrors lint-state-writer-boundary.sh's --verbose semantics.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never
#              silent.
#
# Exit codes:
#   0 - No unexcluded violations found
#   1 - One or more unexcluded violations found (each printed as file:line plus the matched text)
#   2 - Script error (unresolvable project root, missing shared library, unreadable scan path)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

VERBOSE=false
QUIET=false
SCAN_PATHS=()
lint_corpus_scan_parse_flags SCAN_PATHS VERBOSE QUIET -- "$@"

# ---------------------------------------------------------------------------
# Root resolution: dual-mode probe, reused rather than re-derived.
# ---------------------------------------------------------------------------
# common_repo_root <dir> 3 is correct for the DEPLOYED copy (.claude/scripts/lint/), but this
# script also runs directly from the source store (agent-system/extensions/core/scripts/lint/),
# where 3 levels up lands inside the extension rather than at the repo root. Resolve by walking
# up until a directory containing agent-system/extensions is found, falling back to the
# common_repo_root answer -- identical to lint-state-writer-boundary.sh's resolve_project_root().
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

    printf '%s\n' "$candidate"
    return 0
}

# scan_root_mode <root> -- echoes "source-store" or "deployed" for the given candidate scan
# root, by probing for core/manifest.json one level under <root>. Source-store layout nests
# each extension (core, cslib, ...) under <root>, each with its own manifest.json; deployed
# layout is flat (<root>/scripts, <root>/commands, <root>/skills, <root>/agents directly, no
# per-extension nesting, no manifest.json). Reused in spirit from
# tests/test-common-lib.sh's collect_session_id_offenders() dual-mode probe.
scan_root_mode() {
    local root="$1"
    if [[ -f "$root/core/manifest.json" ]]; then
        printf 'source-store\n'
    else
        printf 'deployed\n'
    fi
}

# ---------------------------------------------------------------------------
# Scan-scope collection
# ---------------------------------------------------------------------------
# collect_scan_files <root> <mode> -- echoes the newline-separated, deduplicated list of files
# in scope for a single scan root: *.sh across each extension's scripts/ tree (excluding
# scripts/tests/ and scripts/deprecated/ by directory), plus *.md scoped only to commands/,
# skills/, agents/. In source-store mode <root> is the extensions directory (each immediate
# subdirectory is one extension); in deployed mode <root> IS the flat scripts/commands/skills/
# agents/ parent directly (no per-extension nesting).
collect_scan_files() {
    local _root="$1"
    local _mode="$2"
    local _ext_dir _sub

    if [[ "$_mode" == "source-store" ]]; then
        for _ext_dir in "$_root"/*/; do
            [[ -d "$_ext_dir" ]] || continue
            if [[ -d "${_ext_dir}scripts" ]]; then
                find "${_ext_dir}scripts" -type f -name '*.sh' \
                    -not -path "${_ext_dir}scripts/tests/*" \
                    -not -path "${_ext_dir}scripts/deprecated/*" \
                    2>/dev/null
            fi
            for _sub in commands skills agents; do
                [[ -d "${_ext_dir}${_sub}" ]] || continue
                find "${_ext_dir}${_sub}" -type f -name '*.md' 2>/dev/null
            done
        done
    else
        if [[ -d "$_root/scripts" ]]; then
            find "$_root/scripts" -type f -name '*.sh' \
                -not -path "$_root/scripts/tests/*" \
                -not -path "$_root/scripts/deprecated/*" \
                2>/dev/null
        fi
        for _sub in commands skills agents; do
            [[ -d "$_root/$_sub" ]] || continue
            find "$_root/$_sub" -type f -name '*.md' 2>/dev/null
        done
    fi
    unset _root _mode _ext_dir _sub
    return 0
}

FILES=()

if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
    REPO_ROOT_CANDIDATE="$(resolve_project_root)"
    if [[ -d "$REPO_ROOT_CANDIDATE/agent-system/extensions" ]]; then
        SCAN_MODE="source-store"
        PROJECT_ROOT="$REPO_ROOT_CANDIDATE/agent-system/extensions"
    else
        # No source store found anywhere up the tree from SCRIPT_DIR: this is a deploy-only
        # checkout. The deploy root is two levels up from scripts/lint/ (scripts/lint ->
        # scripts -> deploy root), where commands/, skills/, agents/, scripts/ live directly.
        SCAN_MODE="deployed"
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd || printf '%s' "$REPO_ROOT_CANDIDATE")"
    fi

    if [[ ! -d "$PROJECT_ROOT" ]]; then
        echo "ERROR: default scan root not found: $PROJECT_ROOT" >&2
        echo "       Pass explicit path arguments, or run from a checkout containing the source store." >&2
        exit 2
    fi
    if [[ "$SCAN_MODE" == "source-store" ]] && [[ "$REPO_ROOT_CANDIDATE" == "${GATE_SHARED_CORPUS_ROOT:-}" ]] && common_shared_corpus_available; then
        # Phase 9 ("Shared Corpus Enumeration"): reuse verify-deploy.sh's single whole-tree
        # enumeration instead of this lint's own per-extension `find` loop (collect_scan_files).
        # Only engaged in source-store mode AND when this lint's own root resolution
        # (REPO_ROOT_CANDIDATE) agrees with the shared corpus's root -- any divergence (deployed
        # mode, or a resolution mismatch) falls through to collect_scan_files below unchanged,
        # preserving standalone invocability exactly.
        #
        # Reproducing collect_scan_files's scope requires more than a glob can express, because
        # `*` in `[[ == ]]`/case matching spans directory separators freely: a naive
        # 'agent-system/extensions/*/agents/*.md' pattern also matches a deeply-nested,
        # unrelated "agents" directory several levels down (confirmed live:
        # lean/context/project/lean4/agents/*.md, which is NOT the per-extension top-level
        # agents/ dir collect_scan_files scans). So the first coarse filter below
        # (common_shared_corpus_files, broad extension-agnostic patterns) is followed by an
        # EXACT per-candidate structural check: strip the "agent-system/extensions/" prefix,
        # take exactly the first path segment as the extension name, and require what follows
        # to be precisely "scripts/<anything>.sh" (minus tests/deprecated) or exactly one of
        # "commands/<anything>.md", "skills/<anything>.md", "agents/<anything>.md" -- i.e. the
        # sub-directory must be the SECOND segment, not merely present somewhere later in the
        # path. This is the same scope collect_scan_files enforces via `"${_ext_dir}${_sub}"`
        # (a fixed, one-level join), just re-derived from a flat corpus line instead of a
        # per-extension find root.
        while IFS= read -r -d '' found; do
            _tla_rel="${found#"$GATE_SHARED_CORPUS_ROOT"/agent-system/extensions/}"
            [[ "$_tla_rel" == "$found" ]] && continue
            _tla_ext="${_tla_rel%%/*}"
            _tla_remainder="${_tla_rel#"$_tla_ext"/}"
            case "$_tla_remainder" in
                scripts/tests/*|scripts/deprecated/*) continue ;;
                scripts/*.sh|commands/*.md|skills/*.md|agents/*.md) FILES+=("$found") ;;
            esac
        done < <(common_shared_corpus_files \
                    'agent-system/extensions/*/scripts/*.sh' \
                    'agent-system/extensions/*/commands/*.md' \
                    'agent-system/extensions/*/skills/*.md' \
                    'agent-system/extensions/*/agents/*.md' \
                 | sort -z)
        unset _tla_rel _tla_ext _tla_remainder
    else
        while IFS= read -r found; do
            [[ -n "$found" ]] && FILES+=("$found")
        done < <(collect_scan_files "$PROJECT_ROOT" "$SCAN_MODE" | sort -u)
    fi
else
    # Explicit paths: each directory argument is treated as its own scan root -- its mode is
    # probed independently (this is what lets Phase 4's fixtures exercise both layouts), and
    # the same scope rules apply (.sh whole-tree minus tests/deprecated, .md scoped to
    # commands/skills/agents). A file argument is scanned directly, bypassing scope rules
    # (explicit intent overrides scope-by-construction), matching lint-state-writer-boundary.sh.
    # PROJECT_ROOT for allowlist relative-path purposes is the first directory root seen; a
    # multi-root invocation with allowlist expectations is not a supported combination.
    PROJECT_ROOT=""
    for scan_path in "${SCAN_PATHS[@]}"; do
        if [[ -d "$scan_path" ]]; then
            scan_path="$(cd "$scan_path" && pwd)"
            [[ -z "$PROJECT_ROOT" ]] && PROJECT_ROOT="$scan_path"
            path_mode="$(scan_root_mode "$scan_path")"
            while IFS= read -r found; do
                [[ -n "$found" ]] && FILES+=("$found")
            done < <(collect_scan_files "$scan_path" "$path_mode" | sort -u)
        elif [[ -f "$scan_path" ]]; then
            FILES+=("$scan_path")
        else
            echo "ERROR: scan path not found: $scan_path" >&2
            exit 2
        fi
    done
fi

# ---------------------------------------------------------------------------
# Layer 2: file-level allowlist
# ---------------------------------------------------------------------------
# Repo-relative paths (relative to PROJECT_ROOT, which is the source-store root or the deployed
# .claude/ root depending on SCAN_MODE). Every entry states WHY it is exempt -- a bare path list
# would rot into an unauditable suppression file. THIS LIST IS EXPECTED TO SHRINK: a new entry
# requires a stated reason, and adding one is a deliberate act, not the default response to a
# failing run.
EXCLUDED_FILES=(
    # --- Canonical implementations, exempt by definition ---------------------------------------
    # Defines skill_validate_input(); its own body IS the narrow full-record lookup shape.
    "core/scripts/skill-base.sh"
    # Defines gate_in(); its own body IS the narrow full-record lookup shape. A live re-measure
    # at lint-authoring time found exactly ONE narrow-pattern occurrence in this file (line 64,
    # gate_in's own lookup) -- contradicting an earlier research note about a second lookup
    # needing inspection, which does not reproduce against the current tree.
    "core/scripts/command-gate-in.sh"

    # --- scripts/ offenders (pending migration or per-site judgment) -------------------------
    "core/scripts/reconcile-task-status.sh"

    # --- agents/ offenders: an agent-definition file's own inline verification snippet, not a
    # runtime skill/command bash block sourcing skill-base.sh or command-gate-in.sh -------------
    "core/agents/meta-builder-agent.md"

    # --- commands/ offenders: carry additional distinct lookups for multi-task/recover/sync/
    # expand paths that intentionally do not source command-gate-in.sh for those paths (per-site
    # disposition deferred to a future migration pass) ----------------------------------------
    "core/commands/orchestrate.md"
    "core/commands/spawn.md"
    "core/commands/task.md"
    "epidemiology/commands/epi.md"
    "founder/commands/analyze.md"
    "founder/commands/consult.md"
    "founder/commands/deck.md"
    "founder/commands/finance.md"
    "founder/commands/legal.md"
    "founder/commands/market.md"
    "founder/commands/meeting.md"
    "founder/commands/project.md"
    "founder/commands/sheet.md"
    "founder/commands/strategy.md"
    "present/commands/budget.md"
    "present/commands/funds.md"
    "present/commands/grant.md"
    "present/commands/slides.md"
    "present/commands/timeline.md"

    # --- skills/ offenders: pending lifecycle SKILL.md migration, deferred pending the
    # core-collapse sequencing decision (see context/patterns/adoption-lint-conventions.md) ----
    # The three base lifecycle skills that used to be listed here have been deleted; their
    # entries are removed rather than left dangling.
    "core/skills/skill-orchestrate/SKILL.md"
    "core/skills/skill-reviser/SKILL.md"
    "core/skills/skill-status-sync/SKILL.md"
    "cslib/skills/skill-cslib-vet/SKILL.md"
    "epidemiology/skills/skill-epi-implement/SKILL.md"
    "epidemiology/skills/skill-epi-research/SKILL.md"
    "formal/skills/skill-logic-research/SKILL.md"
    "founder/skills/skill-analyze/SKILL.md"
    "founder/skills/skill-consult/SKILL.md"
    "founder/skills/skill-deck-research/SKILL.md"
    "founder/skills/skill-finance/SKILL.md"
    "founder/skills/skill-financial-analysis/SKILL.md"
    "founder/skills/skill-founder-spreadsheet/SKILL.md"
    "founder/skills/skill-legal/SKILL.md"
    "founder/skills/skill-market/SKILL.md"
    "founder/skills/skill-meeting/SKILL.md"
    "founder/skills/skill-project/SKILL.md"
    "founder/skills/skill-strategy/SKILL.md"
    "lean/skills/skill-lean-implementation/SKILL.md"
    "lean/skills/skill-lean-research/SKILL.md"
    "present/skills/skill-budget/SKILL.md"
    "present/skills/skill-funds/SKILL.md"
    "present/skills/skill-grant/SKILL.md"
    "present/skills/skill-slide-critic/SKILL.md"
    "present/skills/skill-slide-planning/SKILL.md"
    "present/skills/skill-slides/SKILL.md"
    "present/skills/skill-timeline/SKILL.md"

    # This lint and its fixture test both contain the anti-pattern text by necessity -- one as
    # the detection pattern in comments/examples, the other as deliberate dirty fixtures.
    "core/scripts/lint/lint-task-lookup-adoption.sh"
    "core/scripts/tests/test-lint-task-lookup-adoption.sh"
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
# Candidate pattern
# ---------------------------------------------------------------------------
# Requires the equality comparison (== $num / == 1 / == ($num | tonumber)) that both canonical
# helpers use. A select(...) on .project_number that does something else entirely -- e.g. an
# `as $pn | (...)  index...` membership test across a candidate list -- is a structurally
# different operation (batch filtering, not a single-record equality lookup) and is not a
# candidate for this lint at all, rather than a shape to classify and exempt.
CANDIDATE_PATTERN='\.active_projects\[\][[:space:]]*\|[[:space:]]*select\(\.project_number[[:space:]]*=='

# ---------------------------------------------------------------------------
# Layer 1: structural classification of a single candidate line
# ---------------------------------------------------------------------------
# Echoes "VIOLATION" or "EXEMPT: <reason>".
classify_line() {
    local text="$1"
    local anchor_re='\.active_projects\[\][[:space:]]*\|[[:space:]]*select\('

    if [[ ! "$text" =~ $anchor_re ]]; then
        printf 'EXEMPT: no active_projects select() lookup on this line\n'
        return 0
    fi
    local match="${BASH_REMATCH[0]}"

    # before_active: everything before the FIRST ".active_projects[]" on the line -- used to
    # detect del(...) wrapping and [...] bracketing, both of which precede the lookup itself.
    local before_active="${text%%".active_projects[]"*}"

    # start: index of the character just after the open paren of "select(" (where the balanced
    # scan begins at depth 1, since that open paren is already consumed).
    local prefix="${text%%"$match"*}${match}"
    local start=${#prefix}

    # Balanced-paren scan on this single line to find select(...)'s own matching close paren.
    local depth=1
    local i=$start
    local len=${#text}
    local ch
    while [[ $i -lt $len && $depth -gt 0 ]]; do
        ch="${text:$i:1}"
        if [[ "$ch" == "(" ]]; then
            depth=$((depth + 1))
        elif [[ "$ch" == ")" ]]; then
            depth=$((depth - 1))
        fi
        i=$((i + 1))
    done

    if [[ $depth -ne 0 ]]; then
        printf 'EXEMPT: select(...) not closed on this line (multi-line filter, cannot classify)\n'
        return 0
    fi

    local after="${text:$i}"

    # Deletion: del(...) wraps the whole lookup.
    if [[ "$before_active" =~ del\([[:space:]]*$ ]]; then
        printf 'EXEMPT: deletion (del(...) wraps the lookup)\n'
        return 0
    fi

    # Existence/length check: the lookup is inside [...] and the line continues "] | length".
    if [[ "$before_active" =~ \[$ ]] && [[ "$after" =~ ^\][[:space:]]*\|[[:space:]]*length ]]; then
        printf 'EXEMPT: existence/length check ([...] | length)\n'
        return 0
    fi

    # In-place mutation: select(...) is grouped in an extra paren, immediately followed by |=
    # or += (both are in-place update operators; += is jq sugar for |= . + {...}).
    if [[ "$after" =~ ^\)[[:space:]]*(\|=|\+=) ]]; then
        printf 'EXEMPT: in-place mutation (|= or += assignment follows the lookup)\n'
        return 0
    fi

    # In-place mutation: select(...) grouped, followed by a bare field assignment (.field =),
    # not a field comparison (==). Requires the "=" to be followed by whitespace/end-of-line/
    # quote rather than another "=", so it is not confused with a `==` comparison.
    if [[ "$after" =~ ^\)\.[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*[\'\"]?[[:space:]]*$ ]]; then
        printf 'EXEMPT: in-place mutation (field assignment follows the lookup)\n'
        return 0
    fi

    # Single-field/complex read: select(...) grouped, followed directly by a field accessor,
    # e.g. (select(...)).artifacts -- jq's paren-then-dot field-access sugar.
    if [[ "$after" =~ ^\)\.[A-Za-z_] ]]; then
        printf 'EXEMPT: single-field read ((...).field follows the lookup)\n'
        return 0
    fi

    # Single-field/complex read: select(...) piped into anything further -- a field accessor
    # (| .field), a parenthesized boolean/derived expression (| (...)), or any other
    # continuation. Any further pipe means the output is no longer the raw matched record
    # verbatim, so it is not the narrow full-record shape regardless of what the pipe leads to.
    if [[ "$after" =~ ^[[:space:]]*\| ]]; then
        printf 'EXEMPT: single-field/complex read (piped to a further expression)\n'
        return 0
    fi

    # Narrow full-record lookup: none of the legitimate shapes matched. The filter terminates
    # after select(...) with nothing meaningful piped after it -- the exact shape both
    # skill_validate_input() and gate_in() implement.
    printf 'VIOLATION\n'
    return 0
}

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------
VIOLATIONS=0
CANDIDATES=0
FILES_CHECKED=0
FILES_WITH_VIOLATIONS=0
EXEMPTED=0

$QUIET || {
    echo "Checking task-lookup adoption boundary compliance..."
    if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
        echo "Scan root: $PROJECT_ROOT (mode: $SCAN_MODE)"
    else
        echo "Scan paths: ${SCAN_PATHS[*]}"
    fi
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
        text="${text#"${text%%[![:space:]]*}"}"
        ((CANDIDATES++)) || true

        if $file_excluded; then
            ((EXEMPTED++)) || true
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: file-level allowlist entry | $text"
            continue
        fi

        verdict="$(classify_line "$text")"
        if [[ "$verdict" == "VIOLATION" ]]; then
            echo -e "${RED}[VIOLATION]${NC} $file:$lineno: $text"
            ((file_violations++)) || true
            ((VIOLATIONS++)) || true
        else
            ((EXEMPTED++)) || true
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: ${verdict#EXEMPT: } | $text"
        fi
    done <<< "$matches"

    if [[ $file_violations -gt 0 ]]; then
        ((FILES_WITH_VIOLATIONS++)) || true
    fi
done

if [[ $VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Task-Lookup Adoption Check Summary"
        echo "================================"
        echo "Files checked: $FILES_CHECKED"
        echo "Candidate lines scanned: $CANDIDATES"
        echo "Candidate lines exempted: $EXEMPTED"
        echo "Total violations: 0"
        echo -e "${GREEN}No unexcused hand-rolled task-lookup shapes found.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Task-Lookup Adoption Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Files with violations: $FILES_WITH_VIOLATIONS"
echo "Candidate lines scanned: $CANDIDATES"
echo "Candidate lines exempted: $EXEMPTED"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS hand-rolled task-lookup shape(s). See above for details.${NC}"
echo ""
echo "Fix: route the lookup through skill_validate_input() (skill layer) or gate_in() (command"
echo "layer) -- see this script's header for the contract each exports."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
