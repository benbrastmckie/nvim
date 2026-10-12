#!/usr/bin/env bash
# lint-scoped-commit-boundary.sh - Detect hand-rolled bare `git commit -m` call sites across the
# source store.
#
# scripts/git-commit-scoped.sh is the single sanctioned implementation of the scoped-commit
# contract for the dispatch pipeline: it stages and commits in one call with an explicit
# pathspec, serializing through the specs/.commit-lock/ mutex, and it auto-injects the canonical
# ephemeral-runtime-file exclusion set for task-directory pathspecs. A hand-rolled narrow `git
# add` followed by a BARE `git commit` (no trailing pathspec) commits the ENTIRE shared index,
# not just what was just staged, so a concurrently-dispatched agent's staged-but-uncommitted work
# gets swept into whichever agent committed next -- see git-commit-scoped.sh's own header for the
# full defect account.
#
# Converting the surviving hand-rolled call sites was a one-time migration (98 files). Keeping
# them converted is not: every new command file or skill is a fresh opportunity to copy-paste the
# old raw shape from a neighbouring file, exactly how the original defect spread in the first
# place. This lint is the guardrail against that regression -- it fails loudly when the literal
# anti-pattern text reappears anywhere under agent-system/extensions/.
#
# KNOWN LIMITATION (stated plainly rather than papered over)
# ---------------------------------------------------------
# This is a regex-only, line-oriented content lint. It matches the *literal shape* of the
# anti-pattern in the text of .md and .sh files. It therefore CANNOT catch:
#   - A variable-indirected commit, e.g. a site that shells out to a wrapper function whose own
#     body is never read by this lint.
#   - A `git commit` invoked without the literal `-m` flag (e.g. `git commit --file=...` or an
#     editor-driven commit) -- these are rare in this codebase's scripted call sites and outside
#     this lint's candidate pattern by design.
#   - A write assembled across more lines than the classifier reads (a message built into a
#     variable on one line, committed on a much later line with no trailing pathspec visible on
#     that later line's own text).
# This lint is a guardrail against regression and recurrence of the literal anti-pattern text. It
# is NOT a proof of absence of every possible hand-rolled commit. Treat a clean run as "the known
# bad shape is not present", never as "every commit call site goes through git-commit-scoped.sh".
#
# DETECTION MODEL
# ---------------
# Two layers, applied in order to every line matching the broad candidate pattern:
#
#   Layer 1 (structural, line shape): a candidate line is exempt-by-shape when it ends in a
#     trailing `-- <pathspec>` on the same line -- this is the sanctioned script's own internal
#     invocation shape (`git commit -m "$full_message" -- "${pathspecs[@]}"`), and mirrors
#     git-staging-scope.md's own stated rule that a commit lacking a trailing pathspec is a
#     Forbidden Operation. Everything else is a candidate violation.
#
#   Layer 2 (file-level allowlist): a short, explicitly-reasoned list of files that legitimately
#     contain the pattern text. Every entry carries its reason inline below; there are no bare
#     paths on that list by design.
#
# RULE 2: PIPED-INVOCATION DETECTION (no-pipe / exit-code observability)
# -------------------------------------------------------------------
# A caller that pipes a `git-commit-scoped.sh`/`git-commit-phase.sh` invocation into another
# command (e.g. `| tail -25`) without `set -o pipefail` in effect can no longer observe the
# script's real exit code -- bash's `A | B` yields B's exit status regardless of A's own code.
# This is exactly how a dedicated non-zero exit code (a silent-staging-drop diagnostic, or
# git-commit-phase.sh's own completeness-check failure) can be produced by the script yet never
# reach the caller at all. The originating incident this closes used such a pipe
# (`| tail -25`) at an ad hoc call site, not a documented template.
#
# ENUMERATION RESULT (recorded here, not assumed): a sweep of every `.md` and `.sh` file under
# `agent-system/extensions/` for a piped `git-commit-scoped.sh` invocation
# (`grep -rn "git-commit-scoped.sh" agent-system/extensions/ -A3 | grep -E "\| *(tail|head|grep)"`)
# found ZERO documented invocation templates piping the script through `tail`/`head`/`grep`. The
# incident's `| tail -25` was ad hoc at the call site, never inherited from any template in this
# source store. There was therefore nothing to clean up at the time this rule was added -- the
# rule exists to keep it that way, not to fix an existing violation.
#
# Detection: a line naming `git-commit-scoped.sh` or `git-commit-phase.sh` is a candidate when it
# also contains a single pipe character (`|`, not part of a `||` boolean-or) later on the same
# line. A candidate is exempt when its own FILE contains `set -o pipefail` anywhere (a
# file-level, not line-level, check -- see the limitation below). Reported separately from the
# bare-commit violations above, under its own heading.
#
# KNOWN LIMITATION (same honest register as the bare-commit rule's own limitation above): this is
# a regex-only, line-oriented, per-FILE content lint. It therefore CANNOT see a pipe assembled
# across more lines than the single matched line (a command built into a variable on one line,
# piped on a much later line with no visible pipe on the invocation line itself), and it cannot
# see a pipe routed through a wrapper function whose own body it never reads. The `set -o
# pipefail` check is file-wide, not scoped to the specific invocation's own enclosing function or
# subshell -- a file with `set -o pipefail` anywhere is treated as exempt everywhere in that file,
# which could under-report in the (currently unobserved) case of a subshell that locally disables
# it. A pipe inside a test assertion on captured output (e.g. `echo "$out" | grep -q ...`, as
# already appears legitimately throughout `test-git-commit-scoped.sh`) is NOT a candidate at all,
# because the pipe there does not touch the invocation line itself.
#
# RULE 3: EXIT-CODE SINK DETECTION (no bare `|| echo` / `|| true` swallowing git-commit-scoped.sh's
# / git-commit-phase.sh's real exit code)
# ----------------------------------------------------------------------------------------------
# git-commit-scoped.sh's own exit-code contract (0-6; see its header and
# context/standards/git-staging-scope.md's mirrored table) is useless to a caller that wraps the
# invocation as `cmd || echo "...(non-blocking)"`: bash's `A || B` yields B's exit status
# regardless of A's own code, so EVERY nonzero exit collapses to success for that caller's own
# control flow. This is exactly the second route by which "the task still reports success" despite
# a genuinely failed commit -- a new dedicated exit code in the script is necessary but not
# sufficient if every caller still sinks it. This rule keeps a FUTURE `.sh` caller from
# re-introducing that sink after the one caller actually exposed to it was fixed.
#
# ENUMERATION RESULT (recorded here, not assumed): a sweep of every executable, non-test `.sh`
# call site invoking `git-commit-scoped.sh` found exactly four
# (`grep -rln 'git-commit-scoped.sh' --include=*.sh agent-system/extensions/ | grep -v '/tests/'`,
# narrowed to actual invocations rather than mentions):
#   - `scripts/orchestrate-cycle-postflight.sh` -- the one call site actually exposed to an
#     out-of-repository `modified_files` entry. FIXED: captures `$?` into `commit_rc` and branches
#     per code. Not allowlisted below -- it is clean and this rule would not flag it.
#   - `scripts/orchestrate-unwind-dispatch.sh` -- passes only two fixed literals
#     (`specs/state.json specs/TODO.md`), never a `modified_files` entry. Allowlisted below.
#   - `scripts/lib/redeploy-checkpoint-lib.sh` -- passes only `$STATE_FILE` and `TODO.md`, same
#     reasoning. Allowlisted below.
#   - `scripts/orchestrator-postflight.sh` -- confirmed ORPHANED (zero live invocation sites
#     anywhere in this source store; every other hit on its own name is a doc mention or a
#     self-reference inside its own header). Allowlisted below.
#   `scripts/git-commit-phase.sh` already captures its own exit code explicitly
#   (`commit_exit=$?` under a `set +e`/`set -e` pair) and is not a candidate for this rule at all
#   -- it is the in-repo precedent this rule's own detection shape is modelled on.
#
# Detection, scoped deliberately NARROWLY to `.sh` files (never `.md` prose): a sweep confirmed
# the roughly 50 remaining references across documentation and prose skill/agent bodies are
# copied illustration, not executed code, so scanning them would only produce noise this rule's
# own allowlist would have to grow to suppress. A `.sh` line whose trimmed text starts with `bash`
# and names `git-commit-scoped.sh` or `git-commit-phase.sh` opens an INVOCATION BLOCK: that line
# plus every following line, for as long as each line (after trimming trailing whitespace) ends in
# a backslash continuation. The assembled block is a VIOLATION when it contains a bare
# `|| echo ...` or `|| true` and contains NEITHER an explicit `$?` capture, NOR an `rc=`-shaped
# variable assignment, NOR a `case` branch anywhere in the same block.
#
# KNOWN LIMITATION (same honest register as rules 1-2 above): this is a regex-only,
# line-oriented, per-INVOCATION-BLOCK content lint. It cannot see a capture or branch assembled
# through a wrapper function the block calls instead of inlining, nor a `$?`/`rc=` check placed
# on a line AFTER the block's own backslash-continuation chain ends (e.g. a lone `cmd` line with
# no trailing `\`, followed on the NEXT statement by `rc=$?`) -- a future caller using that
# two-statement shape would need its own allowlist entry with that reasoning, not a rule change.
# A clean run means "the known bad sink shape is not present in any `.sh` invocation", never
# "every `.sh` caller branches on every exit code".
#
# Usage: lint-scoped-commit-boundary.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is scanned recursively for
#              .md and .sh files. Defaults to $PROJECT_ROOT/agent-system/extensions (the source
#              store -- .claude/ is a disposable generated deploy artifact and is never the
#              correct place to fix a finding).
#   --verbose  Report every candidate line found, including exempt ones, tagged with the reason
#              each was exempted. Mirrors lint-state-writer-boundary.sh's --verbose semantics.
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

if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
    DEFAULT_SCAN="$PROJECT_ROOT/agent-system/extensions"
    if [[ ! -d "$DEFAULT_SCAN" ]]; then
        echo "ERROR: default scan root not found: $DEFAULT_SCAN" >&2
        echo "       Pass explicit path arguments, or run from a checkout containing the source store." >&2
        exit 2
    fi
    SCAN_PATHS=("$DEFAULT_SCAN")
fi

# ---------------------------------------------------------------------------
# Candidate pattern
# ---------------------------------------------------------------------------
# Deliberately broad -- it over-matches, and the classifier below narrows. Matches the literal
# `git commit -m` anti-pattern text, the same measurement grep used throughout the migration this
# lint guards.
CANDIDATE_PATTERN='git commit -m'

# ---------------------------------------------------------------------------
# Layer 2: file-level allowlist
# ---------------------------------------------------------------------------
# Repo-relative paths. Every entry states WHY it is exempt -- a bare path list would rot into an
# unauditable suppression file. This is the exemption set finalized in Phase 10 of the migration
# task, re-confirmed against the live tree, not assumed.
EXCLUDED_FILES=(
    # The sanctioned implementation itself. Its own internal invocation line is also structurally
    # exempt (ends in `-- "${pathspecs[@]}"`); listed here too, mirroring
    # lint-state-writer-boundary.sh's self-reference-exemption precedent.
    "agent-system/extensions/core/scripts/git-commit-scoped.sh"

    # This lint and its fixture test both contain the anti-pattern text by necessity -- one as the
    # detection pattern, the other as deliberate dirty fixtures. Without these two entries the
    # lint fails on itself.
    "agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh"
    "agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh"

    # Deliberate whole-tree WIP snapshot on a scratch branch (`--branch` mode), immediately
    # followed by checkout back to the original branch. Outside the dispatch/commit pipeline
    # git-staging-scope.md governs -- the entire point is to snapshot everything, not a task
    # scope.
    "agent-system/extensions/core/scripts/git-snapshot.sh"

    # String-literal test fixtures for guard-destructive-git.sh's parser, asserting the hook
    # correctly allows/parses a `git commit -m "..."` containing quoted mentions of other git
    # subcommands. No commit is ever executed; this is the hook's own test suite.
    "agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh"

    # A comment illustrating a quote-stripping parser edge case (`git commit -m "fix -a bug"`) --
    # prose, not executable.
    "agent-system/extensions/core/hooks/guard-destructive-git.sh"

    # Already self-disclaims its inline example blocks as "illustrative of the overall staging
    # shape only -- it is NOT the sanctioned implementation" and dedicates a full section to
    # naming git-commit-scoped.sh as canonical.
    "agent-system/extensions/core/context/standards/git-staging-scope.md"

    # One-time human bootstrap step (`git init && git add . && git commit -m "Initial commit"`)
    # run by the user in their terminal BEFORE the agent system -- and therefore
    # git-commit-scoped.sh -- exists in the project. Outside the scoped-commit contract's scope.
    "agent-system/extensions/core/docs/guides/user-installation.md"

    # Both sites run inside $CSLIB_DIR, a SEPARATE git repository from the agent-system working
    # tree, and are deliberate whole-tree `git add -A` captures of arbitrary feature-branch
    # changes as part of the push/PR flow (review-feedback commit and the shared pre-push commit
    # step) -- not task-directory-scoped commits. Reasoning documented inline in the file.
    "agent-system/extensions/cslib/commands/pr.md"

    # Runs inside $LITERATURE_DIR, a separate content-only git repo with no agent-system deployed
    # in it -- .claude/scripts/git-commit-scoped.sh does not exist there to invoke. The pathspec
    # set is already correctly targeted (not a whole-tree add). Relocated from
    # skill-literature/SKILL.md's own "Mode: Import Pipeline" section to this extracted file per
    # context/patterns/mode-gated-section-loading.md; the allowlist entry moves with the content.
    "agent-system/extensions/literature/context/project/literature/patterns/literature-import-pipeline-mode.md"

    # Generic NixOS system-administration guidance for the user's own flake-managed config repo --
    # not a task-scoped dispatch-pipeline commit, and the target repo may not even have the agent
    # system deployed.
    "agent-system/extensions/nix/context/project/nix/tools/nixos-rebuild-guide.md"

    # RULE 3 allowlist (exit-code sink): three callers deliberately left on a bare `|| echo`
    # idiom, each with its reason inline rather than fixed, per this rule's own header.
    #
    # Passes only two fixed, caller-constructed literals (specs/state.json specs/TODO.md), never
    # a modified_files entry -- structurally unexposed to the out-of-repository defect class this
    # escalation guards against, so the existing non-blocking wording is the correct shape here.
    "agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh"

    # Same reasoning: passes only $STATE_FILE and TODO.md, never a modified_files entry.
    "agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh"

    # Confirmed ORPHANED -- a sweep of every .sh/.md file in this source store found zero live
    # invocation sites naming this script; every other hit on its own name is a doc mention or a
    # self-reference inside its own header. Not a reachable caller at all.
    "agent-system/extensions/core/scripts/orchestrator-postflight.sh"
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
# Echoes "VIOLATION" or "EXEMPT: <reason>".
classify_line() {
    local text="$1"

    # Compliant shape: the sanctioned script's own invocation line ends in a trailing
    # `-- <pathspec>...` on the same line, mirroring git-staging-scope.md's own stated rule that a
    # commit lacking a trailing pathspec is a Forbidden Operation.
    if [[ "$text" =~ --[[:space:]]+[^[:space:]] ]]; then
        printf 'EXEMPT: ends in a trailing -- <pathspec> (compliant shape)\n'
        return 0
    fi

    printf 'VIOLATION\n'
    return 0
}

# ---------------------------------------------------------------------------
# Collect files to scan
# ---------------------------------------------------------------------------
FILES=()
for scan_path in "${SCAN_PATHS[@]}"; do
    if [[ -d "$scan_path" ]]; then
        while IFS= read -r found; do
            FILES+=("$found")
        done < <(find "$scan_path" -type f \( -name '*.md' -o -name '*.sh' \) 2>/dev/null | sort)
    elif [[ -f "$scan_path" ]]; then
        FILES+=("$scan_path")
    else
        echo "ERROR: scan path not found: $scan_path" >&2
        exit 2
    fi
done

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------
VIOLATIONS=0
FILES_CHECKED=0
FILES_WITH_VIOLATIONS=0
EXEMPTED=0

$QUIET || {
    echo "Checking scoped-commit boundary compliance..."
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
    matches="$(grep -nF "$CANDIDATE_PATTERN" "$file" 2>/dev/null || true)"
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

# ---------------------------------------------------------------------------
# Rule 2 scan: piped git-commit-scoped.sh / git-commit-phase.sh invocations (see header)
# ---------------------------------------------------------------------------
# A candidate line names one of the two scripts AND carries a single pipe character (not part of
# a `||` boolean-or) later on the same line. To keep this a high-precision, line-oriented check
# rather than a prose-matching one, a line is skipped entirely (never even a candidate) when,
# after trimming leading whitespace, it starts with `|` (a markdown table row -- this lint's own
# scan roots include many `.md` files whose documentation tables legitimately mention both script
# names and contain unrelated `|` column separators) or `#` (a comment, never an executed
# invocation).
PIPE_SCRIPT_PATTERN='git-commit-scoped\.sh|git-commit-phase\.sh'

# Echoes "VIOLATION" or "EXEMPT: <reason>" for one already-matched candidate line.
classify_pipe_line() {
    local text="$1" file_has_pipefail="$2"

    # Strip `||` occurrences first so a boolean-or never counts as the piping character below.
    local stripped="${text//||/}"
    if [[ "$stripped" != *'|'* ]]; then
        printf 'EXEMPT: no single pipe character on this line (boolean-or only, or none)\n'
        return 0
    fi

    if $file_has_pipefail; then
        printf 'EXEMPT: set -o pipefail is in effect in this file\n'
        return 0
    fi

    printf 'VIOLATION\n'
    return 0
}

PIPE_VIOLATIONS=0
PIPE_FILES_WITH_VIOLATIONS=0
PIPE_EXEMPTED=0

for file in "${FILES[@]}"; do
    file_excluded=false
    if is_excluded_file "$file"; then
        file_excluded=true
    fi

    pipe_matches=""
    pipe_matches="$(grep -nE "$PIPE_SCRIPT_PATTERN" "$file" 2>/dev/null || true)"
    [[ -z "$pipe_matches" ]] && continue

    file_has_pipefail=false
    if grep -qF 'set -o pipefail' "$file" 2>/dev/null; then
        file_has_pipefail=true
    fi

    file_pipe_violations=0
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        lineno="${match%%:*}"
        text="${match#*:}"
        text="${text#"${text%%[![:space:]]*}"}"

        # Skip entirely: markdown table rows and comments are never candidates (see header).
        case "$text" in
            '|'*|'#'*)
                continue
                ;;
        esac

        if $file_excluded; then
            ((PIPE_EXEMPTED++)) || true
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: file-level allowlist entry | $text"
            continue
        fi

        verdict="$(classify_pipe_line "$text" "$file_has_pipefail")"
        if [[ "$verdict" == "VIOLATION" ]]; then
            echo -e "${RED}[PIPE-VIOLATION]${NC} $file:$lineno: $text"
            ((file_pipe_violations++)) || true
            ((PIPE_VIOLATIONS++)) || true
        else
            ((PIPE_EXEMPTED++)) || true
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: ${verdict#EXEMPT: } | $text"
        fi
    done <<< "$pipe_matches"

    if [[ $file_pipe_violations -gt 0 ]]; then
        ((PIPE_FILES_WITH_VIOLATIONS++)) || true
    fi
done

# ---------------------------------------------------------------------------
# Rule 3 scan: exit-code sink (see header) -- .sh files only
# ---------------------------------------------------------------------------
SINK_SCRIPT_PATTERN='git-commit-scoped\.sh|git-commit-phase\.sh'

# join_invocation_block <file> <start_lineno>: echoes the text of lines starting at
# <start_lineno>, continuing to join subsequent lines for as long as each line (after trimming
# trailing whitespace) ends in a backslash continuation. Stops after the first line that does
# NOT end in `\` (inclusive of that line).
join_invocation_block() {
    local file="$1" start="$2"
    awk -v start="$start" '
        NR < start { next }
        {
            print
            line = $0
            sub(/[ \t]+$/, "", line)
            if (substr(line, length(line), 1) != "\\") { exit }
        }
    ' "$file"
}

# Echoes "VIOLATION" or "EXEMPT: <reason>" for one already-assembled invocation block.
classify_sink_block() {
    local block="$1"

    if [[ "$block" == *'$?'* ]]; then
        printf 'EXEMPT: captures $? explicitly\n'
        return 0
    fi
    if [[ "$block" =~ [A-Za-z0-9_]*rc[A-Za-z0-9_]*= ]]; then
        printf 'EXEMPT: assigns an rc-shaped variable\n'
        return 0
    fi
    if [[ "$block" == *'case '* ]]; then
        printf 'EXEMPT: branches via a case statement\n'
        return 0
    fi

    # Strip `||` boolean-or markers naming echo/true with nothing else distinguishing the shape
    # from a real `||` sink test.
    if [[ "$block" =~ \|\|[[:space:]]*(echo|true)([[:space:]]|\") ]]; then
        printf 'VIOLATION\n'
        return 0
    fi

    printf 'EXEMPT: no bare || echo / || true sink detected in this block\n'
    return 0
}

SINK_VIOLATIONS=0
SINK_FILES_WITH_VIOLATIONS=0
SINK_EXEMPTED=0

for file in "${FILES[@]}"; do
    case "$file" in
        *.sh) ;;
        *) continue ;;
    esac

    file_excluded=false
    if is_excluded_file "$file"; then
        file_excluded=true
    fi

    sink_starts=""
    sink_starts="$(grep -nE "$SINK_SCRIPT_PATTERN" "$file" 2>/dev/null | awk -F: '{print $1}' || true)"
    [[ -z "$sink_starts" ]] && continue

    file_sink_violations=0
    while IFS= read -r lineno; do
        [[ -z "$lineno" ]] && continue
        line_text="$(sed -n "${lineno}p" "$file")"
        trimmed="${line_text#"${line_text%%[![:space:]]*}"}"

        # Only a line whose trimmed text actually STARTS an invocation (begins with `bash`) opens
        # a block -- a bare mention naming the script elsewhere on the line (a comment, a doc
        # cross-reference inside a .sh file's own header prose) is not a candidate at all.
        case "$trimmed" in
            bash\ *) ;;
            \#*) continue ;;
            *) continue ;;
        esac

        if $file_excluded; then
            ((SINK_EXEMPTED++)) || true
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: file-level allowlist entry | $trimmed"
            continue
        fi

        block="$(join_invocation_block "$file" "$lineno")"
        verdict="$(classify_sink_block "$block")"
        if [[ "$verdict" == "VIOLATION" ]]; then
            echo -e "${RED}[SINK-VIOLATION]${NC} $file:$lineno: $trimmed"
            ((file_sink_violations++)) || true
            ((SINK_VIOLATIONS++)) || true
        else
            ((SINK_EXEMPTED++)) || true
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: ${verdict#EXEMPT: } | $trimmed"
        fi
    done <<< "$sink_starts"

    if [[ $file_sink_violations -gt 0 ]]; then
        ((SINK_FILES_WITH_VIOLATIONS++)) || true
    fi
done

TOTAL_VIOLATIONS=$((VIOLATIONS + PIPE_VIOLATIONS + SINK_VIOLATIONS))

if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Scoped-Commit Boundary Check Summary"
        echo "================================"
        echo "Files checked: $FILES_CHECKED"
        echo "Candidate lines exempted (bare-commit rule): $EXEMPTED"
        echo "Candidate lines exempted (piped-invocation rule): $PIPE_EXEMPTED"
        echo "Candidate blocks exempted (exit-code sink rule): $SINK_EXEMPTED"
        echo "Total violations: 0"
        echo -e "${GREEN}No hand-rolled bare git-commit call sites, piped phase-commit invocations, or exit-code sinks found.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Scoped-Commit Boundary Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Files with bare-commit violations: $FILES_WITH_VIOLATIONS"
echo "Files with piped-invocation violations: $PIPE_FILES_WITH_VIOLATIONS"
echo "Files with exit-code sink violations: $SINK_FILES_WITH_VIOLATIONS"
echo "Candidate lines exempted (bare-commit rule): $EXEMPTED"
echo "Candidate lines exempted (piped-invocation rule): $PIPE_EXEMPTED"
echo "Candidate blocks exempted (exit-code sink rule): $SINK_EXEMPTED"
echo "Bare-commit violations: $VIOLATIONS"
echo "Piped-invocation violations: $PIPE_VIOLATIONS"
echo "Exit-code sink violations: $SINK_VIOLATIONS"
echo "Total violations: $TOTAL_VIOLATIONS"
[[ $VIOLATIONS -gt 0 ]] && echo -e "${RED}Found $VIOLATIONS hand-rolled bare git-commit call site(s). See above for details.${NC}"
[[ $PIPE_VIOLATIONS -gt 0 ]] && echo -e "${RED}Found $PIPE_VIOLATIONS piped phase-commit invocation(s) that hide the real exit code. See above for details.${NC}"
[[ $SINK_VIOLATIONS -gt 0 ]] && echo -e "${RED}Found $SINK_VIOLATIONS exit-code sink invocation(s) that swallow a nonzero exit via a bare || echo / || true. See above for details.${NC}"
echo ""
echo "Fix (bare-commit): route the commit through scripts/git-commit-scoped.sh (see its header for the contract)."
echo "Fix (piped invocation): remove the pipe, or add 'set -o pipefail' to the file so the real exit code propagates."
echo "Fix (exit-code sink): capture \$? explicitly (an rc=\$? assignment or a case \"\$rc\" in branch) instead of a bare || echo / || true, or add a reasoned allowlist entry if the caller only ever passes fixed literals."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
