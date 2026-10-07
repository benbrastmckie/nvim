#!/usr/bin/env bash
# test-validate-evidence-append-only.sh - Narrow, fixture-driven suite for
# hooks/validate-evidence-append-only.sh.
#
# Per context/standards/shell-script-testing.md: every fixture is its own git repo under a
# mktemp -d workdir, built fresh at suite start; nothing here depends on an external consuming
# repository. Class B strict mode (PASSED/FAILED-counter harness; reports every case, never
# aborts on the first failure), modeled on scripts/tests/test-books-gate.sh.
#
# This suite drives the REAL hook as a subprocess with a constructed PreToolUse JSON payload on
# stdin -- it never sources the hook to call its internals, and never reimplements its predicate.
#
# FORGERY PROBES. Per context/project/books/standards/forgery-probe-discipline.md, each predicate
# carries a probe that stubs it out (via a targeted `sed` substitution on a disposable copy of
# the real hook) and asserts the suite's own expectation then FAILS. See Phase 3's probes below.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../../hooks/validate-evidence-append-only.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [[ ! -x "$HOOK" ]]; then
  fail "prerequisite: $HOOK is not executable (or does not exist)"
  echo ""
  echo "$PASSED passed, $FAILED failed"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "test-validate-evidence-append-only.sh: jq is required to build fixture payloads" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ─── Fixture content ───────────────────────────────────────────────────────────────────────────
EVIDENCE_SEED=$'# Decision 1: Example\n\n- 2026-01-01: initial entry.\n- 2026-01-02: second entry.\n'
README_SEED=$'# book-convention-evidence\n\nMigration contract document.\n'

# ─── Fixture builders ──────────────────────────────────────────────────────────────────────────
# make_repo DIR -- a git repo with a committed 01-decision.md and README.md under
# books/book-convention-evidence/, author identity set locally so the commit succeeds anywhere.
make_repo() {
  local dir="$1"
  mkdir -p "${dir}/books/book-convention-evidence"
  printf '%s' "$EVIDENCE_SEED" > "${dir}/books/book-convention-evidence/01-decision.md"
  printf '%s' "$README_SEED" > "${dir}/books/book-convention-evidence/README.md"
  (cd "$dir" && git init -q \
    && git add -- books/book-convention-evidence/01-decision.md books/book-convention-evidence/README.md \
    && git -c user.email=test@example.com -c user.name=test commit -q -m "seed evidence")
}

# write_payload CWD FILE CONTENT -- a Write-shaped PreToolUse JSON payload.
write_payload() {
  jq -n --arg tn "Write" --arg cwd "$1" --arg fp "$2" --arg content "$3" \
    '{tool_name:$tn, cwd:$cwd, tool_input:{file_path:$fp, content:$content}}'
}

# edit_payload CWD FILE OLD NEW -- an Edit-shaped PreToolUse JSON payload.
edit_payload() {
  jq -n --arg tn "Edit" --arg cwd "$1" --arg fp "$2" --arg old "$3" --arg new "$4" \
    '{tool_name:$tn, cwd:$cwd, tool_input:{file_path:$fp, old_string:$old, new_string:$new}}'
}

# run_hook PAYLOAD [HOOK_PATH] -- drives the hook (or a stubbed copy) as a real subprocess.
# Sets RUN_EXIT and RUN_OUT (combined stdout+stderr) as globals.
run_hook() {
  local payload="$1" target="${2:-$HOOK}"
  RUN_OUT="$(printf '%s' "$payload" | bash "$target" 2>&1)"
  RUN_EXIT=$?
}

# assert_exit CASE_NAME EXPECTED_EXIT
assert_exit() {
  local name="$1" expected="$2"
  if [[ "$RUN_EXIT" -eq "$expected" ]]; then
    pass "${name}: exit code ${RUN_EXIT} (expected ${expected})"
  else
    fail "${name}: exit code ${RUN_EXIT}, expected ${expected}"
    info "  --- actual output ---"
    while IFS= read -r line; do info "  $line"; done <<< "$RUN_OUT"
  fi
}

# assert_contains CASE_NAME NEEDLE
assert_contains() {
  local name="$1" needle="$2"
  if printf '%s' "$RUN_OUT" | grep -qF "$needle"; then
    pass "${name}: output contains '${needle}'"
  else
    fail "${name}: output does NOT contain '${needle}'"
    info "  --- actual output ---"
    while IFS= read -r line; do info "  $line"; done <<< "$RUN_OUT"
  fi
}

# ─── Case 1: in-place modification of a non-trailing committed line via Edit -> exit 2 ─────────
info "Case 1: in-place modification of an existing committed line via Edit"
repo1="${WORKDIR}/case1-modify"
make_repo "$repo1"
run_hook "$(edit_payload "$repo1" "books/book-convention-evidence/01-decision.md" \
  "- 2026-01-01: initial entry." "- 2026-01-01: INITIAL ENTRY CHANGED.")"
assert_exit "case1-modify-refused" 2
case1_out="$RUN_OUT"

# ─── Case 2: the refusal's stderr carries all three required facts + the companion gate name ──
info "Case 2: the Case 1 refusal message carries all three facts and names the companion gate"
RUN_OUT="$case1_out"
assert_contains "case2-fact-append-only" "append-only"
assert_contains "case2-fact-monotonic" "MONOTONIC"
assert_contains "case2-fact-remedy" "history rewrite"
assert_contains "case2-fact-instruction" "Append a new, dated entry"
assert_contains "case2-companion-gate-named" "check-evidence-append-only.sh"

# ─── Case 3: deletion of an existing committed line via Write -> exit 2 ───────────────────────
info "Case 3: deletion of an existing committed line via Write"
repo3="${WORKDIR}/case3-delete"
make_repo "$repo3"
del_content=$'# Decision 1: Example\n\n- 2026-01-01: initial entry.\n'
run_hook "$(write_payload "$repo3" "books/book-convention-evidence/01-decision.md" "$del_content")"
assert_exit "case3-delete-refused" 2

# ─── Case 4: a pure append via Write -> exit 0 ─────────────────────────────────────────────────
info "Case 4: a pure append via Write"
repo4="${WORKDIR}/case4-write-append"
make_repo "$repo4"
append_content="${EVIDENCE_SEED}- 2026-01-03: third entry."$'\n'
run_hook "$(write_payload "$repo4" "books/book-convention-evidence/01-decision.md" "$append_content")"
assert_exit "case4-write-append-allowed" 0

# ─── Case 5: a pure append via Edit -> exit 0 ──────────────────────────────────────────────────
info "Case 5: a pure append via Edit"
repo5="${WORKDIR}/case5-edit-append"
make_repo "$repo5"
old5=$'- 2026-01-02: second entry.\n'
new5="${old5}- 2026-01-03: third entry."$'\n'
run_hook "$(edit_payload "$repo5" "books/book-convention-evidence/01-decision.md" "$old5" "$new5")"
assert_exit "case5-edit-append-allowed" 0

# ─── Case 6: creation of a new NN-*.md that does not exist on disk -> exit 0 ───────────────────
info "Case 6: creation of a new NN-*.md"
repo6="${WORKDIR}/case6-create"
make_repo "$repo6"
run_hook "$(write_payload "$repo6" "books/book-convention-evidence/02-newfile.md" "# Decision 2"$'\n')"
assert_exit "case6-create-allowed" 0

# ─── Case 7: Edit to README.md in the same directory -> exit 0 ────────────────────────────────
info "Case 7: Edit to README.md"
repo7="${WORKDIR}/case7-readme"
make_repo "$repo7"
run_hook "$(edit_payload "$repo7" "books/book-convention-evidence/README.md" \
  "# book-convention-evidence" "# book-convention-evidence CHANGED")"
assert_exit "case7-readme-allowed" 0

# ─── Case 8: a path outside the evidence directory -> exit 0 ──────────────────────────────────
info "Case 8: a path outside the evidence directory"
repo8="${WORKDIR}/case8-outside"
make_repo "$repo8"
mkdir -p "${repo8}/other"
printf 'original\n' > "${repo8}/other/file.md"
run_hook "$(edit_payload "$repo8" "other/file.md" "original" "CHANGED")"
assert_exit "case8-outside-allowed" 0

# ─── Case 9 / 10: Ruling 2 -- the uncommitted tail is free, the floor is not ───────────────────
info "Case 9/10: Ruling 2 -- trailing uncommitted entry is editable, the floor beneath it is not"
repo9="${WORKDIR}/case9-ruling2"
make_repo "$repo9"
printf -- '- 2026-01-03: draft entyr\n' >> "${repo9}/books/book-convention-evidence/01-decision.md"

# Case 9: an in-place (non-append) correction confined to the uncommitted tail -> exit 0.
run_hook "$(edit_payload "$repo9" "books/book-convention-evidence/01-decision.md" \
  "- 2026-01-03: draft entyr"$'\n' "- 2026-01-03: draft entry"$'\n')"
assert_exit "case9-uncommitted-tail-edit-allowed" 0

# Case 10 (companion): the same shape of edit, but old_string spans back into a committed line
# -- refused, proving the allow above genuinely binds the HEAD baseline rather than the on-disk
# content.
old10=$'- 2026-01-02: second entry.\n- 2026-01-03: draft entyr\n'
new10=$'- 2026-01-02: SECOND ENTRY CHANGED.\n- 2026-01-03: draft entyr\n'
run_hook "$(edit_payload "$repo9" "books/book-convention-evidence/01-decision.md" "$old10" "$new10")"
assert_exit "case10-reaching-into-committed-line-refused" 2

# ─── Case 11: Ruling 2 fallback -- not a git checkout -> the stricter on-disk prefix test ──────
info "Case 11: Ruling 2 fallback -- no git checkout, on-disk prefix test (stricter, not fail-open)"
repo11="${WORKDIR}/case11-no-git"
mkdir -p "${repo11}/books/book-convention-evidence"
printf '%s' "$EVIDENCE_SEED" > "${repo11}/books/book-convention-evidence/01-decision.md"
mod_content=$'# Decision 1: Example\n\n- 2026-01-01: INITIAL ENTRY CHANGED.\n- 2026-01-02: second entry.\n'
run_hook "$(write_payload "$repo11" "books/book-convention-evidence/01-decision.md" "$mod_content")"
assert_exit "case11-non-git-fallback-refused" 2

# ─── Forgery probes ───────────────────────────────────────────────────────────────────────────
# Each probe copies the REAL hook into the workdir and stubs exactly one predicate via a targeted
# `sed` substitution, then drives the stubbed copy with the same payload a real case above used.
# Per context/project/books/standards/forgery-probe-discipline.md.
info "Forgery probes: each predicate, stubbed, must break its own case"

# stub_hook SED_EXPR OUT_PATH -- writes a stubbed copy and asserts the substitution actually
# changed something, so a probe cannot pass by silently failing to stub anything.
stub_hook() {
  local sed_expr="$1" out="$2"
  sed "$sed_expr" "$HOOK" > "$out"
  chmod +x "$out"
  if cmp -s "$HOOK" "$out"; then
    fail "stub-applied ($out): sed substitution did not change the copy -- probe is inert"
  else
    pass "stub-applied ($out): sed substitution changed the copy"
  fi
}

# probe_expect_broken NAME ACTUAL EXPECTED_FROM_REAL_CASE
#   PASSES when the stubbed run does NOT reproduce the real case's expectation.
probe_expect_broken() {
  local name="$1" actual="$2" real="$3"
  if [[ "$actual" == "$real" ]]; then
    fail "${name}: the stubbed predicate still produced '${real}' -- the case does not actually bind the predicate"
  else
    pass "${name}: stubbing the predicate breaks the case (got '${actual}', real case expects '${real}')"
  fi
}

# Probe A -- the modification/refusal predicate. Stub the terminal `exit 2` to `exit 0`, so
# nothing is ever refused. Case 1 (modification via Edit) expects exit 2; it must not any more.
stubA="${WORKDIR}/stub-modification-predicate.sh"
stub_hook 's/^exit 2$/exit 0/' "$stubA"
run_hook "$(edit_payload "$repo1" "books/book-convention-evidence/01-decision.md" \
  "- 2026-01-01: initial entry." "- 2026-01-01: INITIAL ENTRY CHANGED.")" "$stubA"
probe_expect_broken "probeA-modification-predicate" "$RUN_EXIT" "2"

# Probe B -- the scope-match predicate (the complementary admit half: a refusal-only probe suite
# cannot distinguish a correct refusal from a predicate that refuses everything). Stub the scope
# case so the first arm matches every path. Case 8 (outside the evidence directory) expects
# exit 0; with scope forced to match, the real predicate now runs against it and refuses.
stubB="${WORKDIR}/stub-scope-match.sh"
stub_hook 's#\*/books/book-convention-evidence/\[0-9\]\[0-9\]-\*\.md) : ;;#*) : ;;#' "$stubB"
run_hook "$(edit_payload "$repo8" "other/file.md" "original" "CHANGED")" "$stubB"
probe_expect_broken "probeB-scope-match-predicate" "$RUN_EXIT" "0"

# Probe C -- the HEAD-baseline lookup. Stub it to return the current on-disk content (collapsing
# FLOOR and DISK, so TAIL is always empty). Case 9 (free edit confined to the uncommitted tail)
# expects exit 0; it must not any more, proving Case 9 genuinely binds the HEAD baseline rather
# than the on-disk content.
stubC="${WORKDIR}/stub-head-baseline.sh"
# Single-quoted deliberately: this is a literal sed expression passed through to the stub_hook
# helper, not a string meant to expand in this shell.
# shellcheck disable=SC2016
stub_hook 's#git -C "\$REPO_ROOT" show "HEAD:\$RELPATH" 2>/dev/null#cat "\$ABS_FILE" 2>/dev/null#' "$stubC"
run_hook "$(edit_payload "$repo9" "books/book-convention-evidence/01-decision.md" \
  "- 2026-01-03: draft entyr"$'\n' "- 2026-01-03: draft entry"$'\n')" "$stubC"
probe_expect_broken "probeC-head-baseline-predicate" "$RUN_EXIT" "0"

# ─── Fail-open case 1: dependency presence (jq absent from PATH) ──────────────────────────────
info "Fail-open case 1: jq absent from PATH"
COREUTILS_DIR="$(dirname "$(command -v cat)")"
if PATH="$COREUTILS_DIR" command -v jq >/dev/null 2>&1; then
  info "skipping: jq is reachable even from a coreutils-only PATH on this machine (environment-specific)"
else
  repoFO1="${WORKDIR}/fail-open-1"
  make_repo "$repoFO1"
  payloadFO1="$(edit_payload "$repoFO1" "books/book-convention-evidence/01-decision.md" \
    "- 2026-01-01: initial entry." "- 2026-01-01: INITIAL ENTRY CHANGED.")"
  RUN_OUT="$(printf '%s' "$payloadFO1" | PATH="$COREUTILS_DIR" bash "$HOOK" 2>&1)"
  RUN_EXIT=$?
  assert_exit "fail-open-1-jq-absent" 0
  assert_contains "fail-open-1-warning" "WARNING"
  assert_contains "fail-open-1-names-jq" "jq"
fi

# ─── Fail-open case 2: payload usability (malformed stdin, separate guard from case 1) ────────
info "Fail-open case 2: malformed (non-JSON) stdin"
RUN_OUT="$(printf 'not json at all' | bash "$HOOK" 2>&1)"
RUN_EXIT=$?
assert_exit "fail-open-2-malformed-json" 0
assert_contains "fail-open-2-warning" "WARNING"
assert_contains "fail-open-2-distinct-guard" "guard 2"

# ─── Buried-long-line case ─────────────────────────────────────────────────────────────────────
# Reproduces the measured incident's own shape: a single-string substitution buried inside one
# multi-thousand-character line. A line-oriented implementation (diff, newline-splitting) could
# pass every case above while missing this one; the hook deliberately contains no line-length
# handling of its own -- this is a regression guard against a future line-splitting rewrite.
info "Buried-long-line case: a modification embedded mid-line in an 8000+ character line"
pad4000() { printf '%*s' 4000 '' | tr ' ' 'x'; }
LONGPAD="$(pad4000)"
LONGLINE="prefix-before-marker-${LONGPAD}-ARCHIVAL-MARKER-DistSysAeneas-${LONGPAD}-suffix-after-marker"
info "  constructed line length: ${#LONGLINE} characters"
repoLL="${WORKDIR}/buried-long-line"
mkdir -p "${repoLL}/books/book-convention-evidence"
BURIED_SEED="# Decision 1: Buried
${LONGLINE}
"
printf '%s' "$BURIED_SEED" > "${repoLL}/books/book-convention-evidence/01-buried.md"
(cd "$repoLL" && git init -q \
  && git add -- books/book-convention-evidence/01-buried.md \
  && git -c user.email=test@example.com -c user.name=test commit -q -m "seed buried-line evidence")

# Buried modification: byte-identical except the embedded marker string -> exit 2.
mod_buried="${BURIED_SEED/DistSysAeneas/DistsysAeneas}"
run_hook "$(write_payload "$repoLL" "books/book-convention-evidence/01-buried.md" "$mod_buried")"
assert_exit "buried-line-modification-refused" 2

# Companion admit: the long line untouched, a new entry appended -> exit 0.
append_buried="${BURIED_SEED}- 2026-01-03: new entry."$'\n'
run_hook "$(write_payload "$repoLL" "books/book-convention-evidence/01-buried.md" "$append_buried")"
assert_exit "buried-line-append-allowed" 0

echo ""
echo "$PASSED passed, $FAILED failed"
[[ "$FAILED" -eq 0 ]] || exit 1
