#!/usr/bin/env bash
# lint-test-harness-adoption.sh - Guard against the bare pass()/fail()/info() call-site
# fall-through defect class in this corpus's own shell test suites.
#
# WHY THIS EXISTS
# ----------------
# A test-harness migration tranche used a line-start-anchored call-site rename regex to move
# suites onto a shared helper trio. The regex missed `pass`/`fail`/`info` calls sitting inside
# case-statement arms (`success) pass "ok" ;;`) and single-line `if/then/fi` shapes, in 3 of 18
# migrated suites. Once each suite's own local `pass()`/`fail()` definitions were deleted as part
# of that same migration, the unrenamed calls fell through to whatever REAL binary named
# `pass`/`fail`/`info` happened to be on PATH (concretely: the UNIX password-store `pass` tool) --
# silently dropping assertion counts (one suite's reported PASSED count dropped from 28 to 5)
# rather than erroring loudly. `bash -n` cannot catch this (every call site is syntactically
# valid); only a before/after output diff surfaced it. This lint exists so the next migration
# tranche cannot reintroduce the same class without a gate failing first.
#
# TWO VALID SHAPES, PER context/standards/shell-script-testing.md and lib/common.sh's own header
# -----------------------------------------------------------------------------------------------
#   (a) The suite defines `pass()` / `fail()` / `info()` locally (the corpus's long-standing flat
#       convention, e.g. tests/test-script-inventory.sh) and calls those bare names.
#   (b) The suite sources `lib/common.sh` (the shared harness) and calls `common_test_pass` /
#       `common_test_fail` / `common_test_info` directly, per that file's own documented
#       "MUST NOT also define its own pass()/fail()/info()" rule.
# The violating shape this lint targets is neither: a bare call-site use of `pass`/`fail`/`info`
# with NO local definition of that same name AND NO sourcing of lib/common.sh anywhere in the
# file -- exactly the state 3 of 18 suites were left in mid-migration.
#
# DETECTION MODEL (line-oriented, deliberately bounded -- see KNOWN LIMITATION)
# ------------------------------------------------------------------------------
# Per candidate file, per name in {pass, fail, info}:
#   1. SKIP this name entirely if the file defines it locally: a line (ignoring leading
#      whitespace) shaped `[function ]<name>()` (with or without a space before the parens), or
#      the parens-less `function <name>` form.
#   2. SKIP this name entirely if the file sources the shared harness anywhere
#      (`source .../lib/common.sh` or POSIX dot-source `. .../lib/common.sh`) -- shape (b) above.
#   3. Otherwise, flag a VIOLATION at the first line matching a bare call-site use of <name> IN
#      COMMAND POSITION: the word immediately preceded (modulo whitespace) by a command-starting
#      token -- start of line, a command separator (`;`, `&`, `|`, `(`, `)`, `{`), or a shell
#      keyword (`then`, `do`, `else`, `elif`) -- and immediately followed by whitespace and an
#      argument-looking character (quote, `$`, alnum, `_`, or `-`). This shape alone is what fires
#      in a case-statement arm (`pattern) pass "msg" ;;`) and a single-line `if ... ; then
#      pass "msg"; fi` alike -- both precede the word with a command separator or keyword, which
#      is exactly what the line-start-anchored migration regex that caused the original incident
#      could not see. The command-position requirement is deliberate, not incidental: an early
#      draft of this lint matched the bare word anywhere followed by whitespace and an
#      argument-looking character, and false-positived on prose arguments containing the words
#      "pass"/"fail" as ordinary English inside a quoted test-case description (e.g. "...keyword
#      pass skipped..." and "...fail openalex answers..." in two pre-existing, unrelated
#      suites) -- in prose the word is preceded by another prose word, never by a command
#      separator or keyword, so requiring that prefix clears both false positives while still
#      catching every real call-site shape the motivating incident exhibited.
#      Full-line comments (stripped line starts with `#`) are excluded from this scan.
#
# KNOWN LIMITATION (stated plainly, matching this cluster's own convention rather than papering
# over it): this is a regex-only, line-oriented content lint, not a shell parser. It cannot see
# through a variable-indirected call, and a quoted prose argument that itself happens to both (a)
# contain one of these three words immediately preceded by a command-separator character or
# keyword, inside the quotes, and (b) be followed by another argument-looking character, could
# still false-positive in principle -- no regex-only lint can fully distinguish "inside a string
# literal" from "in command position" without a real shell parser. It also will not flag a suite
# calling a name that is accidentally shadowed by something other than a function (e.g. an
# alias). Treat a clean run as "the known bad shape is not present", never as "every test suite's
# pass/fail/info usage is provably safe".
#
# SCAN SCOPE: shell "test suite" files under agent-system/extensions/**, matching
# script-inventory.sh's own test-file classification exactly (so the two stay in lockstep): a
# `*.sh` file is in scope when it lives under a `tests/` directory anywhere in its path, OR its
# basename starts with the literal prefix `test-`.
#
# Usage: lint-test-harness-adoption.sh [--verbose] [--help] [path...]
#   With no path arguments, scans the default corpus described above. Path arguments (used by
#   this script's own test suite to exercise a synthetic fixture) replace the default corpus
#   entirely rather than adding to it, and are scanned as given regardless of the tests//test-*
#   classification (an explicit path is always scanned).
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
      echo "Usage: lint-test-harness-adoption.sh [--verbose] [--help] [path...]"
      echo ""
      echo "Fails if a shell test suite under agent-system/extensions/** calls bare pass/fail/info"
      echo "without either defining that name locally or sourcing lib/common.sh (which provides"
      echo "common_test_pass/common_test_fail/common_test_info instead). An unrenamed call site"
      echo "left in that state silently falls through to any real same-named binary on PATH"
      echo "(e.g. the UNIX password-store 'pass' tool) instead of erroring, dropping assertion"
      echo "counts with no visible failure."
      echo ""
      echo "Exit codes: 0 = no violations, 1 = violations found, 2 = environment/usage error"
      exit 0
      ;;
    *)
      EXPLICIT_PATHS+=("$1")
      shift
      ;;
  esac
done

# ── Root resolution ──────────────────────────────────────────────────────────────────────────
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

# HARNESS_RE -- matches a line sourcing lib/common.sh, either keyword `source` or POSIX `.`.
HARNESS_RE='(^|[;&|[:space:]])(source|\.)[[:space:]]+.*lib/common\.sh'

# def_re NAME -- echoes the ERE matching a local definition of NAME: `[function ]NAME()` (with or
# without a space before the parens) or the parens-less `function NAME` form.
def_re() {
  local name="$1"
  printf '^[[:space:]]*(function[[:space:]]+)?%s[[:space:]]*\\([[:space:]]*\\)|^[[:space:]]*function[[:space:]]+%s([[:space:]]|$)' \
    "$name" "$name"
}

# call_re NAME -- echoes the ERE matching a bare call-site use of NAME in COMMAND POSITION: NAME
# immediately preceded (modulo whitespace) by a command-starting token -- start of line, a
# command separator (`;`, `&`, `|`, `(`, `)`, `{`), or a shell keyword (`then`, `do`, `else`,
# `elif`) -- and immediately followed by whitespace and an argument-looking character. The
# command-position prefix requirement is what keeps this from matching the bare word `pass` or
# `fail` sitting inside a quoted prose argument (e.g. a test-case description string like
# "keyword pass skipped" or "s2 fail openalex answers query") -- in prose, the word is preceded
# by another prose word, never by one of these command-starting tokens.
call_re() {
  local name="$1"
  printf '(^|[;&|(){]|\\bthen\\b|\\bdo\\b|\\belse\\b|\\belif\\b)[[:space:]]*%s\\b[[:space:]]+["'"'"'$A-Za-z0-9_-]' "$name"
}

# ── Known, narrowly-reasoned false-positive allowlist ───────────────────────────────────────────
# Keyed `<repo-relative-path>:<line-number>`, each entry DIRECTLY INSPECTED and confirmed to be
# prose inside a quoted log/description string, never a real call site. A regex-only,
# line-oriented lint (see the header's KNOWN LIMITATION) cannot distinguish a parenthesized
# English aside like "(pass --runtime for smoke test)" inside a log_info message from a real
# `(pass ...)` subshell call without tracking quotes. Adding an entry here is a deliberate,
# reasoned act taken only after direct inspection confirms the line is not a real call site --
# never the default response to a failing run.
declare -A ALLOWLIST=(
  ["agent-system/extensions/literature/scripts/test-lit-pipeline.sh:1288"]="log_info prose: '(pass --runtime for smoke test)' is an English aside describing a CLI flag, not a call to pass()"
)

is_allowlisted() {
  local relpath="$1" lineno="$2"
  [[ -n "${ALLOWLIST["${relpath}:${lineno}"]:-}" ]]
}

scan_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  FILES_SCANNED=$((FILES_SCANNED + 1))

  local relpath="$file"
  case "$file" in
    "$REPO_ROOT"/*) relpath="${file#"$REPO_ROOT"/}" ;;
  esac

  local sources_harness=false
  if grep -qE "$HARNESS_RE" "$file" 2>/dev/null; then
    sources_harness=true
  fi

  local name found_violation=false
  for name in pass fail info; do
    if grep -qE "$(def_re "$name")" "$file" 2>/dev/null; then
      continue
    fi
    if $sources_harness; then
      continue
    fi
    # Walk every call-site match in line order (not just the first) so an allowlisted false
    # positive earlier in the file never hides a real, unexempted violation later in the same
    # file.
    local call_matches match lineno
    call_matches="$(grep -nE "$(call_re "$name")" "$file" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#')"
    [[ -z "$call_matches" ]] && continue
    while IFS= read -r match; do
      [[ -z "$match" ]] && continue
      lineno="${match%%:*}"
      if is_allowlisted "$relpath" "$lineno"; then
        continue
      fi
      echo -e "${RED}[VIOLATION]${NC} $file:$lineno"
      echo "  Calls bare \`${name}\` with no local ${name}() definition in this file, and without"
      echo "  sourcing lib/common.sh (which provides common_test_${name} instead). If a future"
      echo "  edit removes an assumed-but-absent local ${name}() definition, this call silently"
      echo "  falls through to any real '${name}' binary on PATH instead of erroring, dropping"
      echo "  assertion counts with no visible failure. Define ${name}() locally, or source"
      echo "  lib/common.sh and call common_test_${name} directly."
      VIOLATIONS=$((VIOLATIONS + 1))
      found_violation=true
      break
    done <<< "$call_matches"
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
  echo -e "${GREEN}[PASS]${NC} lint-test-harness-adoption: 0 violation(s) across $FILES_SCANNED file(s)"
  exit 0
else
  echo -e "${RED}[FAIL]${NC} lint-test-harness-adoption: $VIOLATIONS violation(s) across $FILES_SCANNED file(s)"
  exit 1
fi
