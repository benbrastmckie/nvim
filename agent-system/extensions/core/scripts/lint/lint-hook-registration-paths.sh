#!/usr/bin/env bash
# lint-hook-registration-paths.sh - Gate four independent defect classes in Claude Code hook
# registrations across the source store: a CWD-relative invoked-script path, a copy-paste
# registration template teaching that same defect in source-store markdown, a registration
# reachable only through install-once root-files/settings.json and by no fragment surface, and a
# registration invoking a source-store script that does not exist.
#
# WHY THIS EXISTS
# ----------------
# The upstream path-shape fix settled every hook registration's command to the shape
# `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` -- absolute, resolved from the session's
# CLAUDE_PROJECT_DIR environment variable rather than the shell's drifted current working
# directory. A CWD-relative path (`bash .claude/hooks/x.sh`, or worse, one that does not even
# mention `.claude/` at all, such as `bash scripts/claude-ready-signal.sh`) resolves against
# whatever directory the session's shell happens to be in when the hook fires, silently fails
# when that directory is not the repo root, and is swallowed by the hook's own
# `2>/dev/null || echo '{}'` suppression -- so the failure has NO visible symptom. This lint is
# the guardrail against that defect (and three structurally related ones) ever reappearing.
#
# EXIT-CODE CONTRACT
# -------------------
#   0 - No violations found in any of the four checks.
#   1 - One or more violations found (printed as file:line plus the offending text/reason).
#   2 - Script error (unresolvable project root, missing shared library, unreadable scan path).
#
# FAIL-CLOSED vs. FAIL-OPEN -- A DELIBERATE POLARITY CONTRAST, NOT AN INCONSISTENCY
# -----------------------------------------------------------------------------------
# This script fails CLOSED on a missing or broken shared library (exit 2, immediately, before
# any check runs) -- a broken DEPLOY GATE must never silently pass a bad deploy. This is the
# OPPOSITE polarity from the write-time hook convention used elsewhere in this codebase, where a
# hook fails OPEN (e.g. `... 2>/dev/null || echo '{}'`) so that a broken guard can never block
# every single tool-use write. Both polarities are correct for their own role; do NOT "correct"
# one to match the other. A future reader who sees this script exit 2 on a missing library and
# assumes that is a bug, because "hooks fail open around here", has mis-generalized the
# convention -- this script is a deploy gate, not a write-time hook.
#
# ACCEPTED ANCHORS (the accept condition for an invoked script path)
# --------------------------------------------------------------------
# An invoked script path is ACCEPTED when it is:
#   - "$CLAUDE_PROJECT_DIR"-prefixed (the canonical, settled shape), OR
#   - `/`-absolute, OR
#   - `~/`-prefixed (a deliberate THIRD anchor -- see D1 below).
# Everything else is a VIOLATION, regardless of which directory it names. `.claude/` is one
# instance of the defect (the historically common one), never the defect's DEFINITION: a relative
# path with no `.claude/` in it at all (e.g. `scripts/claude-ready-signal.sh`) is just as much a
# violation as `.claude/hooks/x.sh`, because both resolve against the session's drifted shell cwd.
#
# D1 -- `~/` is accepted as a third anchor, deliberately. It is demonstrably cwd-independent (it
# resolves through $HOME, never through the session's shell cwd), and it is already in correct,
# intentional use at nvim/context/project/neovim/guides/neovim-integration.md line 34, which
# references a real script intentionally OUTSIDE `.claude/` entirely
# (~/.config/nvim/scripts/claude-ready-signal.sh). Flagging it would be a false positive on a
# correct line.
#
# D2 -- A `~/`-anchored path is ALSO exempt from the existence check (Check D). It names a
# user-supplied, externally-provided script that may legitimately not exist anywhere under this
# repo's source store; failing it for that would punish a correct, deliberate reference.
#
# D3 -- `.sh` files are NEVER a scan surface. This lint's scan surface is settings JSON files
# (root-files/settings.json, every settings-hooks.json / settings-fragment.json) plus source-store
# markdown. This is BY SCAN SCOPE, not by a classifier heuristic -- it is what makes an explicit
# direct invocation under an established `cd` (e.g. core/scripts/tests/test-please-grant.sh:
# `( cd "$repo" && ... | bash .claude/hooks/please-grant.sh )`) pass: that line lives in a `.sh`
# file, which this lint never opens at all. If the scan surface is ever widened to `.sh` files,
# the fixture suite's passing case for exactly this shape will go red -- do not widen the scan
# surface without first re-examining that case.
#
# D4 -- This lint's fragment-coverage identity notion (Check C) is DELIBERATELY BROADER than
# merge.lua's own `hook_identity()`, which recognizes only a `.claude/hooks/NAME.sh`-shaped path.
# This lint's identity covers ANY invoked script path (so `scripts/NAME.sh` is a first-class
# identity too, matching the line-118 defect class -- see D5/criterion-11 below). `merge.lua` is
# outside this lint's file_scope; the divergence is accepted and recorded here, not reconciled.
# Do NOT port `hook_identity()`'s `hooks/`-anchored pattern into this lint.
#
# D5 -- Fragment-coverage identity key: (normalized invoked script path, event name, hook type).
# Normalization strips a leading `"$CLAUDE_PROJECT_DIR"/.claude/`, `.claude/`, or bare `/` anchor
# and keeps the remaining directory-qualified path exactly as written -- so `scripts/foo.sh` is
# compared as readily as `hooks/foo.sh`.
#
# D6 -- `root-files/settings.local.json` is OUT OF SCOPE for every check in this lint (a prior
# ruling, carried forward unchanged here): a permission matcher matches literal command TEXT
# presented by a tool call and is never itself resolved against a CWD, so it does not share this
# defect class at all. This lint's scan-surface enumeration below never names
# settings.local.json; this is enforced by construction (the surface list is built from exact
# filenames: root-files/settings.json, settings-hooks.json, settings-fragment.json -- never
# settings.local.json), not by a runtime exclusion check.
#
# THE FOUR CHECKS
# ----------------
#   Check A (path shape, settings surfaces): every `"command"` key's invoked script path, across
#     root-files/settings.json and every settings-hooks.json / settings-fragment.json under the
#     extensions root, must satisfy the accepted-anchor condition above. Handles both the direct
#     registration shape and a registration nested inside a `bash -c '...'` wrapper, by finding the
#     innermost invoked `*.sh` token rather than the outer `bash -c` itself. A `"command"` line
#     whose extracted text contains no `*.sh` invocation at all (an inline shell snippet, or an
#     MCP server's `"command": "npx"` under `mcpServers`) is not a script registration and is never
#     reported, in any form -- see the KNOWN FALSE-POSITIVE RISKS note below.
#   Check B (path shape, markdown registration templates): the identical key-anchored extraction
#     and classifier Check A uses, applied inside fenced ` ```json ` blocks in source-store
#     markdown that look like a hook-registration template (a `"type": "command"` key present
#     somewhere in the same fenced block). A defective string in markdown PROSE, outside any fenced
#     JSON block, is never flagged.
#   Check C (fragment coverage): every hook registration present in root-files/settings.json must
#     also be present, under the D5 identity, in the union of every fragment surface
#     (merge-sources/settings-hooks.json plus every extension's settings-hooks.json /
#     settings-fragment.json). Both-surfaces and fragment-only are CORRECT and pass; only
#     root-files-only is a violation, because root-files is install-once (loader.lua's
#     INSTALL_ONCE_ROOT_FILES) and unreachable by any later resync in an already-deployed repo.
#   Check D (script existence): every invoked script path that is source-store-resolvable (i.e.
#     every accepted- or violation-shaped path except a `~/`-anchored one, per D2) must resolve to
#     an actual file under some agent-system/extensions/*/<normalized-path> in the source store.
#
# KNOWN FALSE-POSITIVE RISKS, closed by construction
# -----------------------------------------------------
#   - root-files/settings.json's own `_comment` field quotes the correct
#     `"$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` form in PROSE, as a convention reminder. Every
#     check below is anchored on a literal `"command"` JSON KEY, never on bare path text in the
#     file -- a whole-file text grep for `.claude/hooks/` would pick the `_comment` field up as a
#     phantom registration; this lint never does that.
#   - memory/settings-fragment.json's `"mcpServers"."obsidian-memory"."command": "npx"` is an MCP
#     server command, not a hook registration. It is excluded not by walking only `.hooks` (though
#     Check C/D's jq-based inventory does exactly that) but, for the line-oriented checks A/B, by
#     the simpler and equally sufficient fact that "npx" never yields an extracted `*.sh` token.
#
# KNOWN LIMITATION (stated plainly, not papered over)
# -------------------------------------------------------
# This is a structural, line/JSON-oriented content lint over a fixed, enumerated scan surface. It
# cannot catch a hook registration added through some entirely different surface this lint does
# not enumerate, or a path assembled at runtime via shell indirection that no static text scan can
# see. Treat a clean run as "the known defect shapes are not present in the known surfaces", never
# as "every hook registration anywhere is correct."
#
# Usage: lint-hook-registration-paths.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is scanned recursively for the
#              settings-surface and markdown filenames below. A single explicit file argument is
#              classified by its own path shape (root-files/settings.json, settings-hooks.json,
#              settings-fragment.json, or *.md); any other file (notably a `.sh` file, per D3) is
#              silently not scanned. Defaults to $PROJECT_ROOT/agent-system/extensions.
#   --verbose  Report every candidate line found, including accepted anchors (tagged [OK]) and
#              file-level allowlist exemptions (tagged [EXEMPT] with the reason), and list every
#              markdown file scanned. A line with no script invocation at all is never reported,
#              verbose or not -- it was never a candidate in the first place.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never silent.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=false
QUIET=false
SCAN_PATHS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quiet|-q)
            QUIET=true
            shift
            ;;
        *)
            SCAN_PATHS+=("$1")
            shift
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
    echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/common.sh" >&2
    exit 2
fi
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# Root resolution -- identical strategy to lint-state-writer-boundary.sh and
# lint-directory-pathspec-boundary.sh: common_repo_root <dir> 3 is correct for the DEPLOYED copy
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

    printf '%s\n' "$candidate"
    return 0
}

PROJECT_ROOT="$(resolve_project_root)"

if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
    DEFAULT_SCAN="$PROJECT_ROOT/agent-system/extensions"
    if [[ ! -d "$DEFAULT_SCAN" ]]; then
        echo "ERROR: default scan root not found: $DEFAULT_SCAN" >&2
        echo "       Pass explicit path arguments, or run from a checkout containing the source store." >&2
        exit 2
    fi
    SCAN_PATHS=("$DEFAULT_SCAN")
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required (Check C/D inventory) and not on PATH" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Markdown file-level allowlist (Check B, Layer 2) -- seeded empty
# ---------------------------------------------------------------------------
# No source-store markdown currently needs an entry here: every `.md` file that carries a hook
# registration template is clean. Any future entry MUST carry its reason inline -- a bare path
# list rots into an unauditable suppression file. Mirrors lint-state-writer-boundary.sh's
# EXCLUDED_FILES convention.
MARKDOWN_ALLOWLIST=(
    # Seeded empty by design. Example of the required shape, left as a comment so a future
    # entry copies the convention rather than inventing a bare path:
    #   "agent-system/extensions/<ext>/context/path/to/file.md"  # reason: <why this file
    #   legitimately needs to show the defective shape, e.g. documenting the anti-pattern itself>
)

is_md_allowlisted() {
    local file="$1"
    local rel="${file#"$PROJECT_ROOT"/}"
    local entry
    for entry in "${MARKDOWN_ALLOWLIST[@]}"; do
        [[ -z "$entry" ]] && continue
        [[ "$rel" == "$entry" ]] && return 0
        [[ "$file" == */"$entry" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Shared extraction + classification (Checks A, B, C, D all call these)
# ---------------------------------------------------------------------------

# extract_invoked_script TEXT
# Scans TEXT (a raw "command" JSON-string value, with its original backslash-escaping intact, OR
# an already jq-unescaped command string -- both shapes are handled) for a `bash <path>.sh`
# invocation. Finds the INNERMOST such invocation (the last one encountered), so a `bash -c '...'`
# wrapper around an inner `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` invocation yields the
# inner path, never the literal `-c` flag. A `bash -c` body that invokes no `*.sh` at all (e.g. an
# inline permissionDecision echo) yields the empty string -- such a line is not a script
# registration at all, by this lint's own definition, and callers must treat an empty result as
# "nothing to check", never as a violation.
#
# Uses `read -ra` rather than an unquoted `for word in $text` loop specifically to avoid bash
# pathname (glob) expansion on tokens like `*"state.json"*` that appear verbatim in several of
# these command strings -- `read -a` splits on IFS without ever performing glob expansion.
extract_invoked_script() {
    local text="$1"
    local -a words
    read -ra words <<< "$text"
    local i found=""
    for ((i = 0; i < ${#words[@]}; i++)); do
        local w="${words[$i]}"
        local wclean="${w#\"}"
        wclean="${wclean%\"}"
        if [[ "$wclean" == "bash" || "$wclean" == */bash ]]; then
            if (( i + 1 < ${#words[@]} )); then
                local nxt="${words[$((i + 1))]}"
                if [[ "$nxt" == "-c"* ]]; then
                    continue
                fi
                local stripped="${nxt//\\\"/}"
                stripped="${stripped//\"/}"
                if [[ "$stripped" == *.sh ]]; then
                    found="$stripped"
                fi
            fi
        fi
    done
    printf '%s\n' "$found"
}

# classify_anchor PATH -- echoes ACCEPT or VIOLATION per the accepted-anchor condition above.
classify_anchor() {
    local p="$1"
    if [[ "$p" == '$CLAUDE_PROJECT_DIR'/* ]]; then
        printf 'ACCEPT\n'
    elif [[ "$p" == /* ]]; then
        printf 'ACCEPT\n'
    elif [[ "$p" == "~/"* ]]; then
        printf 'ACCEPT\n'
    else
        printf 'VIOLATION\n'
    fi
}

# normalize_identity PATH (D5) -- strips one of the recognized anchor prefixes and returns the
# remaining directory-qualified path, unchanged otherwise (including an unrecognized-anchor
# violation path, which still needs an identity for Check C/D to compare against).
normalize_identity() {
    local p="$1"
    p="${p#\$CLAUDE_PROJECT_DIR/.claude/}"
    p="${p#.claude/}"
    p="${p#/}"
    printf '%s\n' "$p"
}

# check_exists NORMALIZED_PATH -- true if NORMALIZED_PATH resolves to a real file under some
# agent-system/extensions/*/ in the source store (hooks are spread across each extension's own
# hooks/ directory, not only core/hooks/; the same is true of scripts/).
check_exists() {
    local norm="$1"
    local match
    for match in "$PROJECT_ROOT"/agent-system/extensions/*/"$norm"; do
        [[ -f "$match" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Collect scan surfaces
# ---------------------------------------------------------------------------
# Settings surfaces, classified into ROOT_FILES_GROUP (root-files/settings.json only -- the
# install-once surface) and FRAGMENT_GROUP (every settings-hooks.json / settings-fragment.json --
# the resync-reachable surfaces). settings.local.json is excluded by construction: neither
# filename pattern below ever matches it (D6).
ROOT_FILES_GROUP=()
FRAGMENT_GROUP=()
MARKDOWN_FILES=()

classify_settings_file() {
    local f="$1"
    case "$f" in
        */root-files/settings.json)
            ROOT_FILES_GROUP+=("$f")
            ;;
        */settings-hooks.json|*/settings-fragment.json)
            FRAGMENT_GROUP+=("$f")
            ;;
    esac
}

for scan_path in "${SCAN_PATHS[@]}"; do
    if [[ -d "$scan_path" ]]; then
        while IFS= read -r found; do
            classify_settings_file "$found"
        done < <(find "$scan_path" -type f -name '*.json' \
                    \( -name 'settings.json' -o -name 'settings-hooks.json' -o -name 'settings-fragment.json' \) \
                    2>/dev/null | sort)
        while IFS= read -r found; do
            MARKDOWN_FILES+=("$found")
        done < <(find "$scan_path" -type f -name '*.md' 2>/dev/null | sort)
    elif [[ -f "$scan_path" ]]; then
        case "$scan_path" in
            *.md)
                MARKDOWN_FILES+=("$scan_path")
                ;;
            *.json)
                classify_settings_file "$scan_path"
                ;;
            *)
                # D3: a .sh file (or anything else) passed explicitly is simply not scanned.
                ;;
        esac
    else
        echo "ERROR: scan path not found: $scan_path" >&2
        exit 2
    fi
done

SETTINGS_FILES=("${ROOT_FILES_GROUP[@]}" "${FRAGMENT_GROUP[@]}")

VIOLATIONS=0
CANDIDATES_SEEN=0
ACCEPTED_SEEN=0
EXEMPTED_SEEN=0

$QUIET || {
    echo "Checking hook-registration path and fragment-coverage compliance..."
    echo "Scan roots: ${SCAN_PATHS[*]}"
    echo ""
}

# ---------------------------------------------------------------------------
# Check A -- path shape in settings surfaces
# ---------------------------------------------------------------------------
for file in "${SETTINGS_FILES[@]}"; do
    [[ -z "$file" ]] && continue
    matches="$(grep -nE '"command"[[:space:]]*:' "$file" 2>/dev/null || true)"
    [[ -z "$matches" ]] && continue
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        lineno="${match%%:*}"
        text="${match#*:}"
        text="${text#"${text%%[![:space:]]*}"}"

        sh_path="$(extract_invoked_script "$text")"
        [[ -z "$sh_path" ]] && continue
        ((CANDIDATES_SEEN++)) || true

        verdict="$(classify_anchor "$sh_path")"
        if [[ "$verdict" == "VIOLATION" ]]; then
            echo -e "${RED}[VIOLATION]${NC} $file:$lineno: $text"
            ((VIOLATIONS++)) || true
        else
            ((ACCEPTED_SEEN++)) || true
            $VERBOSE && echo -e "${GREEN}[OK]${NC} $file:$lineno: $sh_path"
        fi
    done <<< "$matches"
done

# ---------------------------------------------------------------------------
# Check B -- path shape in markdown registration templates
# ---------------------------------------------------------------------------
for file in "${MARKDOWN_FILES[@]}"; do
    [[ -z "$file" ]] && continue
    $VERBOSE && echo -e "[SCAN] $file"

    if is_md_allowlisted "$file"; then
        $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file: file-level allowlist entry"
        ((EXEMPTED_SEEN++)) || true
        continue
    fi

    in_block=false
    has_type_command=false
    declare -a block_lines=()
    declare -a block_linenos=()
    lineno=0

    flush_block() {
        $has_type_command || return 0
        local idx
        for idx in "${!block_lines[@]}"; do
            local bline="${block_lines[$idx]}"
            [[ "$bline" =~ \"command\"[[:space:]]*: ]] || continue
            local blineno="${block_linenos[$idx]}"
            local sh_path
            sh_path="$(extract_invoked_script "$bline")"
            [[ -z "$sh_path" ]] && continue
            ((CANDIDATES_SEEN++)) || true
            local verdict
            verdict="$(classify_anchor "$sh_path")"
            if [[ "$verdict" == "VIOLATION" ]]; then
                echo -e "${RED}[VIOLATION]${NC} $file:$blineno: $bline"
                ((VIOLATIONS++)) || true
            else
                ((ACCEPTED_SEEN++)) || true
                $VERBOSE && echo -e "${GREEN}[OK]${NC} $file:$blineno: $sh_path"
            fi
        done
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((lineno++)) || true
        if ! $in_block; then
            if [[ "$line" =~ ^[[:space:]]*\`\`\`json[[:space:]]*$ ]]; then
                in_block=true
                has_type_command=false
                block_lines=()
                block_linenos=()
            fi
            continue
        fi
        if [[ "$line" =~ ^[[:space:]]*\`\`\`[[:space:]]*$ ]]; then
            flush_block
            in_block=false
            continue
        fi
        if [[ "$line" =~ \"type\"[[:space:]]*:[[:space:]]*\"command\" ]]; then
            has_type_command=true
        fi
        block_lines+=("$line")
        block_linenos+=("$lineno")
    done < "$file"
    # Unclosed fence at EOF: nothing to flush (malformed markdown, not this lint's concern).
done

# ---------------------------------------------------------------------------
# Checks C + D -- fragment coverage and script existence (jq-based registration inventory)
# ---------------------------------------------------------------------------
declare -A ROOT_IDS
declare -A FRAG_IDS

collect_identities() {
    # Usage: collect_identities <array-name> <file...>
    local -n _target="$1"
    shift
    local f
    for f in "$@"; do
        [[ -z "$f" || ! -f "$f" ]] && continue
        local event type command sh_path norm key
        while IFS=$'\t' read -r event type command; do
            [[ -z "$command" ]] && continue
            sh_path="$(extract_invoked_script "$command")"
            [[ -z "$sh_path" ]] && continue
            [[ "$sh_path" == "~/"* ]] && continue
            norm="$(normalize_identity "$sh_path")"
            key="${norm}|${event}|${type}"
            _target["$key"]="$f"
        done < <(jq -r '(.hooks // {}) | to_entries[] | .key as $event | (.value // [])[] | ((.hooks // [])[] // {}) | [$event, (.type // ""), (.command // "")] | @tsv' "$f" 2>/dev/null)
    done
}

collect_identities ROOT_IDS "${ROOT_FILES_GROUP[@]}"
collect_identities FRAG_IDS "${FRAGMENT_GROUP[@]}"

for key in "${!ROOT_IDS[@]}"; do
    if [[ -z "${FRAG_IDS[$key]+x}" ]]; then
        norm="${key%%|*}"
        name="${norm##*/}"
        f="${ROOT_IDS[$key]}"
        lineno="$(grep -nF -- "$name" "$f" 2>/dev/null | head -1 | cut -d: -f1)"
        echo -e "${RED}[VIOLATION]${NC} $f:${lineno:-?}: hook script '$name' (identity: $norm) is registered in root-files/settings.json but is absent from every fragment surface -- add it to agent-system/extensions/core/merge-sources/settings-hooks.json"
        ((VIOLATIONS++)) || true
    fi
done

# Check D: existence, over every settings surface's full registration inventory (both groups).
for file in "${SETTINGS_FILES[@]}"; do
    [[ -z "$file" ]] && continue
    while IFS=$'\t' read -r event type command; do
        [[ -z "$command" ]] && continue
        sh_path="$(extract_invoked_script "$command")"
        [[ -z "$sh_path" ]] && continue
        [[ "$sh_path" == "~/"* ]] && continue
        norm="$(normalize_identity "$sh_path")"
        if ! check_exists "$norm"; then
            name="${norm##*/}"
            lineno="$(grep -nF -- "$name" "$file" 2>/dev/null | head -1 | cut -d: -f1)"
            echo -e "${RED}[VIOLATION]${NC} $file:${lineno:-?}: invoked script does not exist anywhere in the source store: $norm"
            ((VIOLATIONS++)) || true
        fi
    done < <(jq -r '(.hooks // {}) | to_entries[] | .key as $event | (.value // [])[] | ((.hooks // [])[] // {}) | [$event, (.type // ""), (.command // "")] | @tsv' "$file" 2>/dev/null)
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ $VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Hook Registration Path + Fragment-Coverage Check Summary"
        echo "================================"
        echo "Settings surfaces checked: ${#SETTINGS_FILES[@]}"
        echo "Markdown files checked: ${#MARKDOWN_FILES[@]}"
        echo "Candidates accepted: $ACCEPTED_SEEN"
        echo "Candidates exempted: $EXEMPTED_SEEN"
        echo "Total violations: 0"
        echo -e "${GREEN}No CWD-relative, fragment-unreachable, or dead hook registrations found.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Hook Registration Path + Fragment-Coverage Check Summary"
echo "================================"
echo "Settings surfaces checked: ${#SETTINGS_FILES[@]}"
echo "Markdown files checked: ${#MARKDOWN_FILES[@]}"
echo "Candidates accepted: $ACCEPTED_SEEN"
echo "Candidates exempted: $EXEMPTED_SEEN"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS hook-registration violation(s). See above for details.${NC}"
echo ""
echo "Fix: use bash \"\$CLAUDE_PROJECT_DIR\"/.claude/hooks/x.sh (or an absolute / ~/-anchored path)."
echo "     A fragment-coverage violation: add the registration to the named fragment file."
echo "     A dead-script violation: fix the path, or remove the registration."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
