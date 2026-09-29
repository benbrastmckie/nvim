#!/usr/bin/env bash
# test-lean-comparator-run.sh -- regression suite for lean-comparator-run.sh.
#
# Covers three distinct regression concerns:
#
# (1) Verdict classification (Cases V1-V11): each of the 8 named verdicts from the closed
# vocabulary, plus `timeout` and the internal `unclassified_failure` escape hatch, driven end to
# end through the real pipeline (real `git worktree`, real `systemd-run` on this host) against a
# stub `comparator` binary that emits canned stdout/stderr and a chosen exit code -- exercising
# classify_verdict() exactly as the wrapper's own runtime does, not by calling an extracted
# function in isolation.
#
# (2) comparator_unavailable / binary resolution (Cases U1-U4): each of the four resolvable
# binaries (comparator, landrun, lean4export, lake) missing in turn, asserting the message names
# both the missing binary and its override env var and that exit 69 is distinguishable from
# every rejection code.
#
# (3) Guard routing and sandbox invocation (Cases G1-G3): a stub guard's own logged argv proves
# `--no-share` is present and `--memory-bound` is absent (never by reading the source); the
# guard-absent-but-lake-present degradation prints a loud warning and still proceeds; usage
# errors exit 64.
#
# Anti-vacuous-test guard (Case AV1, carrying test-lean-sorry-census.sh's own discipline): a
# naive "exit code 1 means rejected, full stop" classifier is asserted to DISAGREE with this
# tool's classifier on the axiom_violation vs config_error fixtures -- both exit 1, so a
# vacuous suite that only checked exit codes could not tell them apart. This proves the
# classification is doing real work, not just forwarding Comparator's own exit code.
#
# Cases requiring the REAL `comparator`, `landrun`, or `lean4export` binaries (all three
# confirmed absent on this development host, per the task's own dispatch) are SKIPPED with an
# explicit report naming which acceptance criterion is thereby deferred -- never silently
# reported as a pass. See Case E1/E2.
#
# Follows the core shell-test convention (see test-lean-sorry-census.sh and
# core/scripts/tests/test-census-count.sh): pass()/fail()/info()/skip() helpers, PASSED/FAILED
# counters, mktemp -d workdir with a trap EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS (skips do not count as failures); 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../lean-comparator-run.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/comparator"

PASSED=0
FAILED=0
SKIPPED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }
skip() { echo "[SKIP] $1"; SKIPPED=$((SKIPPED + 1)); }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected lean-comparator-run.sh at $TOOL_SRC" >&2
  exit 1
fi

for dep in python3 git systemd-run timeout; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "ERROR: $dep is required by this suite and is not on PATH" >&2
    exit 1
  fi
done

WORKDIR="$(mktemp -d)"
cleanup() {
  [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] || return 0
  # Prune any worktree registrations this suite's repos accumulated before removing the tree.
  for repo in "$WORKDIR"/repo-*; do
    [ -d "$repo/.git" ] && git -C "$repo" worktree prune >/dev/null 2>&1
  done
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Shared fixture helpers
# ---------------------------------------------------------------------------

# make_repo <name> -- a throwaway git repo (lean-toolchain + Challenge.lean tracked) suitable as
# --project-root. Prints nothing; the repo lives at $WORKDIR/repo-<name>.
make_repo() {
  local name="$1"
  local dir="$WORKDIR/repo-$name"
  mkdir -p "$dir"
  ( cd "$dir" \
    && git init -q \
    && git config user.email test@test.com \
    && git config user.name test \
    && echo "leanprover/lean4:v4.99.0" > lean-toolchain \
    && printf 'theorem comm (n m : Nat) : n + m = m + n := sorry\n' > Challenge.lean \
    && git add lean-toolchain Challenge.lean \
    && git commit -qm initial )
}

# make_bin_dir <name> -- an empty directory to hold this case's stub binaries, prints its path.
make_bin_dir() {
  local name="$1"
  local dir="$WORKDIR/bin-$name"
  mkdir -p "$dir"
  echo "$dir"
}

# write_noop_stub <path> -- a stub that exits 0 immediately (used for lean4export, which this
# suite never exercises for real -- Comparator's own README-mandated internal calls to it are
# not reached by any stub `comparator` used here).
write_noop_stub() {
  cat > "$1" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$1"
}

# write_landrun_stub <path> -- a stub `landrun` that skips every flag argument up to and
# including the first "--", then EXECS the trailing command -- unlike write_noop_stub, this one
# must actually forward: since Phase 3's outer landrun hardening layer, lean-comparator-run.sh's
# own resolved LANDRUN_PATH wraps its ENTIRE sandboxed invocation (guard-or-lake-env plus
# Comparator itself), not merely a path Comparator's own internal build might invoke. A no-op
# stub here would silently swallow the whole wrapped command, exactly as it did before this
# helper existed (every V*/G* case regressed to an empty-output unclassified_failure).
write_landrun_stub() {
  cat > "$1" <<'EOF'
#!/usr/bin/env bash
args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  if [ "${args[$i]}" = "--" ]; then
    i=$((i+1))
    break
  fi
  i=$((i+1))
done
exec "${args[@]:$i}"
EOF
  chmod +x "$1"
}

# write_lake_stub <path> -- a stub `lake` that fails `exe cache get` loudly (as a real project
# with no cache target would) and, for `lake env <bin> <args...>`, EXECS the trailing command so
# a stub `comparator`'s own behavior (sleep, canned output, exit code) is actually observed.
write_lake_stub() {
  cat > "$1" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "exe" ] && [ "$2" = "cache" ]; then
  echo "no cache target" >&2
  exit 1
fi
if [ "$1" = "env" ]; then
  shift
  exec "$@"
fi
exit 0
EOF
  chmod +x "$1"
}

# make_lean_stub <bindir> -- writes a `lean` executable into <bindir> answering --print-prefix
# with a dedicated per-case toolchain-prefix directory (<bindir>.toolchain), and ensures
# <prefix>/bin exists so lean-comparator-run.sh's resolve_toolchain() directory-existence check
# passes. The cases below that use only this helper (not the dedicated PATH-ordering/elan-wrapper
# cases added separately) deliberately leave <prefix>/bin without its own `lake`: PATH resolution
# for `lake` then falls through to whatever the case's own ambient PATH already provides (the
# stub written by write_lake_stub, still resolvable via lean-comparator-run.sh's own
# sandbox_path, which always appends the ambient ${PATH} after the toolchain-bin/lake-dir/git
# prefix) -- Fix 1's PATH-ordering and elan-wrapper mechanics get their own dedicated coverage,
# not exercised incidentally by every pre-existing case here.
make_lean_stub() {
  local bindir="$1"
  local prefix="${bindir}.toolchain"
  mkdir -p "$prefix/bin"
  cat > "$bindir/lean" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "--print-prefix" ]; then
  echo "$prefix"
  exit 0
fi
exit 0
EOF
  chmod +x "$bindir/lean"
}

# write_comparator_stub <path> <stdout-text> <stderr-text> <exit-code> -- a stub `comparator`
# emitting canned text on each stream (via a quoted heredoc, so no shell-escaping of the text
# itself is ever needed) and exiting with the given code.
write_comparator_stub() {
  python3 - "$@" <<'PYEOF'
import sys
path, stdout_text, stderr_text, exit_code = sys.argv[1:5]
with open(path, "w") as f:
    f.write("#!/usr/bin/env bash\n")
    f.write("cat <<'CASE_STDOUT_EOF'\n")
    f.write(stdout_text)
    if not stdout_text.endswith("\n"):
        f.write("\n")
    f.write("CASE_STDOUT_EOF\n")
    f.write("cat <<'CASE_STDERR_EOF' >&2\n")
    f.write(stderr_text)
    if not stderr_text.endswith("\n"):
        f.write("\n")
    f.write("CASE_STDERR_EOF\n")
    f.write(f"exit {exit_code}\n")
import os
os.chmod(path, 0o755)
PYEOF
}

# write_sleeping_comparator_stub <path> <seconds> -- a stub `comparator` that sleeps past any
# reasonable --timeout used in this suite.
write_sleeping_comparator_stub() {
  cat > "$1" <<EOF
#!/usr/bin/env bash
sleep "$2"
EOF
  chmod +x "$1"
}

# write_guard_stub <path> <argv-log-path> -- a stub lake-build-guard.sh that logs its full argv
# to <argv-log-path> (so a test can assert on the CAPTURED command line, never by reading the
# source) then execs the trailing command after the "--" separator, exactly like the real guard's
# `build ... -- env <comparator> config.json` shape.
write_guard_stub() {
  local path="$1" argv_log="$2"
  cat > "$path" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$argv_log"
args=("\$@")
i=0
while [ \$i -lt \${#args[@]} ]; do
  if [ "\${args[\$i]}" = "--" ]; then
    i=\$((i+1))
    break
  fi
  i=\$((i+1))
done
exec "\${args[@]:\$i}"
EOF
  chmod +x "$path"
}

# run_tool <bindir> <guard-bin> <repo> [extra args...] -- invokes lean-comparator-run.sh with the
# standard fixed arguments (Challenge/Solution/comm/no axioms) plus any extra args, resolving
# COMPARATOR_BIN/COMPARATOR_LANDRUN/COMPARATOR_LEAN4EXPORT from <bindir>. Captures combined
# stdout+stderr; the verdict record always goes to the tool's own stdout.
run_tool() {
  local bindir="$1" guard_bin="$2" repo="$3"
  shift 3
  PATH="$bindir:$PATH" \
    COMPARATOR_BIN="$bindir/comparator" \
    COMPARATOR_LANDRUN="$bindir/landrun" \
    COMPARATOR_LEAN4EXPORT="$bindir/lean4export" \
    LEAN_COMPARATOR_RUN_GUARD_BIN="$guard_bin" \
    bash "$TOOL_SRC" --project-root "$repo" --challenge-module Challenge \
      --solution-module Solution --theorems comm --permitted-axioms "" "$@" 2>&1
}

get_field() {
  # get_field <output> <field> -- extracts "field: value" from a key:value verdict record.
  echo "$1" | grep -E "^$2: " | head -1 | sed -E "s/^$2: //"
}

# ---------------------------------------------------------------------------
# Case U0: usage error (no arguments) -> exit 64
# ---------------------------------------------------------------------------

OUT_U0="$(bash "$TOOL_SRC" 2>&1)"
RC_U0=$?
if [ "$RC_U0" -eq 64 ]; then
  pass "Case U0 (no arguments): exit 64"
else
  fail "Case U0 (no arguments): expected exit 64, got $RC_U0"
fi

# ---------------------------------------------------------------------------
# Cases U1-U3: comparator_unavailable for each of comparator/landrun/lean4export missing
# ---------------------------------------------------------------------------

REPO_U="$WORKDIR/repo-u"
make_repo "u"
BIN_U="$(make_bin_dir u)"
write_landrun_stub "$BIN_U/landrun"
write_noop_stub "$BIN_U/lean4export"
write_lake_stub "$BIN_U/lake"
make_lean_stub "${BIN_U}"
write_comparator_stub "$BIN_U/comparator" "Your solution is okay!" "" 0

test_missing_binary() {
  # test_missing_binary <label> <env-var-to-break> <bin-name> -- sets exactly ONE of
  # COMPARATOR_BIN/COMPARATOR_LANDRUN/COMPARATOR_LEAN4EXPORT to a nonexistent path (the one named
  # by <env-var-to-break>) while leaving the other two at their good, resolvable values -- built
  # via explicit per-variable selection rather than a bare override, since a duplicate
  # `env VAR=bad ... VAR=good ...` assignment list would let the later (good) value win and
  # silently defeat the whole case.
  local label="$1" env_var="$2" bin_name="$3"
  local comparator_bin="$BIN_U/comparator" landrun_bin="$BIN_U/landrun" lean4export_bin="$BIN_U/lean4export"
  case "$env_var" in
    COMPARATOR_BIN) comparator_bin="/nonexistent-$bin_name" ;;
    COMPARATOR_LANDRUN) landrun_bin="/nonexistent-$bin_name" ;;
    COMPARATOR_LEAN4EXPORT) lean4export_bin="/nonexistent-$bin_name" ;;
    *) echo "test_missing_binary: unknown env_var '$env_var'" >&2; return 1 ;;
  esac
  local out rc
  out="$(PATH="$BIN_U:$PATH" \
    COMPARATOR_BIN="$comparator_bin" COMPARATOR_LANDRUN="$landrun_bin" \
    COMPARATOR_LEAN4EXPORT="$lean4export_bin" \
    LEAN_COMPARATOR_RUN_GUARD_BIN="$WORKDIR/no-such-guard.sh" \
    bash "$TOOL_SRC" --project-root "$REPO_U" --challenge-module Challenge \
      --solution-module Solution --theorems comm --permitted-axioms "" 2>&1)"
  rc=$?
  local verdict; verdict="$(get_field "$out" verdict)"
  if [ "$rc" -eq 69 ] && [ "$verdict" = "comparator_unavailable" ] && echo "$out" | grep -qF "$bin_name" && echo "$out" | grep -qF "$env_var"; then
    pass "$label: comparator_unavailable (exit 69), message names '$bin_name' and '$env_var'"
  else
    fail "$label: expected exit 69 / comparator_unavailable naming '$bin_name' and '$env_var'; got rc=$rc out=$out"
  fi
}

test_missing_binary "Case U1 (comparator missing)" COMPARATOR_BIN comparator
test_missing_binary "Case U2 (landrun missing)" COMPARATOR_LANDRUN landrun
test_missing_binary "Case U3 (lean4export missing)" COMPARATOR_LEAN4EXPORT lean4export

# Case U4: lake truly absent (isolated PATH, real 'true'/'false'/'grep' resolved via `type -P`
# rather than `command -v` -- a plain builtin name with no path would otherwise produce a
# self-referential symlink).
ISOBIN_U4="$(make_bin_dir u4-isolated)"
for tool in bash env cat echo grep find sort mkdir rm chmod dirname cut tail head wc date sed awk stat sleep python3 printf true false timeout git systemd-run mktemp rmdir cp basename pwd tr paste readlink; do
  toolpath="$(type -P "$tool" 2>/dev/null || true)"
  if [ -n "$toolpath" ] && [ ! -e "$ISOBIN_U4/$tool" ]; then
    ln -sf "$toolpath" "$ISOBIN_U4/$tool"
  fi
done
ln -sf "$BIN_U/comparator" "$ISOBIN_U4/comparator"
ln -sf "$BIN_U/landrun" "$ISOBIN_U4/landrun"
ln -sf "$BIN_U/lean4export" "$ISOBIN_U4/lean4export"
# resolve_toolchain() runs (and needs a working `lean --print-prefix`) BEFORE run_sandboxed()'s
# own lake-absence check, so this isolated PATH needs a `lean` stub too, even though this case is
# about `lake` being absent, not `lean`.
make_lean_stub "${ISOBIN_U4}"

OUT_U4="$(PATH="$ISOBIN_U4" COMPARATOR_BIN="$ISOBIN_U4/comparator" COMPARATOR_LANDRUN="$ISOBIN_U4/landrun" \
  COMPARATOR_LEAN4EXPORT="$ISOBIN_U4/lean4export" \
  LEAN_COMPARATOR_RUN_GUARD_BIN="$WORKDIR/no-such-guard.sh" \
  bash "$TOOL_SRC" --project-root "$REPO_U" --challenge-module Challenge \
    --solution-module Solution --theorems comm --permitted-axioms "" 2>&1)"
RC_U4=$?
VERDICT_U4="$(get_field "$OUT_U4" verdict)"
if [ "$RC_U4" -eq 69 ] && [ "$VERDICT_U4" = "comparator_unavailable" ] && echo "$OUT_U4" | grep -qF "lake"; then
  pass "Case U4 (lake absent, guard absent): comparator_unavailable (exit 69), message names lake"
else
  fail "Case U4 (lake absent, guard absent): expected exit 69 / comparator_unavailable naming lake; got rc=$RC_U4 out=$OUT_U4"
fi

# ---------------------------------------------------------------------------
# Cases G1-G3: guard routing and sandbox invocation
# ---------------------------------------------------------------------------

REPO_G="$WORKDIR/repo-g"
make_repo "g"
BIN_G="$(make_bin_dir g)"
write_landrun_stub "$BIN_G/landrun"
write_noop_stub "$BIN_G/lean4export"
write_lake_stub "$BIN_G/lake"
make_lean_stub "${BIN_G}"
write_comparator_stub "$BIN_G/comparator" "Your solution is okay!" "" 0

# Case G1: guard present -- assert --no-share present and --memory-bound absent in the CAPTURED
# argv (never by reading the source).
GUARD_ARGV_LOG="$WORKDIR/guard-argv.log"
GUARD_G1="$WORKDIR/guard-g1.sh"
write_guard_stub "$GUARD_G1" "$GUARD_ARGV_LOG"
OUT_G1="$(run_tool "$BIN_G" "$GUARD_G1" "$REPO_G")"
if [ -f "$GUARD_ARGV_LOG" ] && grep -q -- "--no-share" "$GUARD_ARGV_LOG" && ! grep -q -- "--memory-bound" "$GUARD_ARGV_LOG"; then
  pass "Case G1 (guard routing): captured argv contains --no-share and omits --memory-bound"
else
  fail "Case G1 (guard routing): expected --no-share present / --memory-bound absent in captured argv; got: $(cat "$GUARD_ARGV_LOG" 2>/dev/null || echo '(no log)')"
fi

# Case G2: guard absent, lake present -- a loud warning is printed and the run still proceeds
# (verdict is still correctly classified).
OUT_G2="$(run_tool "$BIN_G" "$WORKDIR/no-such-guard.sh" "$REPO_G")"
VERDICT_G2="$(get_field "$OUT_G2" verdict)"
if echo "$OUT_G2" | grep -qF "WARNING: lake-build-guard.sh not found" && [ "$VERDICT_G2" = "verified" ]; then
  pass "Case G2 (guard absent, lake present): loud warning printed, run still proceeds to a verdict"
else
  fail "Case G2 (guard absent, lake present): expected warning + verdict=verified; got: $OUT_G2"
fi

# Case G3: timeout -- a stub comparator that outlives --timeout yields verdict=timeout, exit 70.
BIN_G3="$(make_bin_dir g3)"
write_landrun_stub "$BIN_G3/landrun"
write_noop_stub "$BIN_G3/lean4export"
write_lake_stub "$BIN_G3/lake"
make_lean_stub "${BIN_G3}"
write_sleeping_comparator_stub "$BIN_G3/comparator" 20
GUARD_G3="$WORKDIR/guard-g3.sh"
write_guard_stub "$GUARD_G3" "$WORKDIR/guard-argv-g3.log"
OUT_G3="$(PATH="$BIN_G3:$PATH" COMPARATOR_BIN="$BIN_G3/comparator" COMPARATOR_LANDRUN="$BIN_G3/landrun" \
  COMPARATOR_LEAN4EXPORT="$BIN_G3/lean4export" LEAN_COMPARATOR_RUN_GUARD_BIN="$GUARD_G3" \
  bash "$TOOL_SRC" --project-root "$REPO_G" --challenge-module Challenge --solution-module Solution \
    --theorems comm --permitted-axioms "" --timeout 3 2>&1)"
RC_G3=$?
VERDICT_G3="$(get_field "$OUT_G3" verdict)"
if [ "$VERDICT_G3" = "timeout" ] && [ "$RC_G3" -eq 70 ]; then
  pass "Case G3 (timeout): verdict=timeout, exit 70"
else
  fail "Case G3 (timeout): expected verdict=timeout / exit 70; got verdict=$VERDICT_G3 rc=$RC_G3"
fi

# ---------------------------------------------------------------------------
# Cases V1-V11: verdict classification, one per category (plus timeout, covered as G3 above)
# ---------------------------------------------------------------------------

REPO_V="$WORKDIR/repo-v"
make_repo "v"
BIN_V="$(make_bin_dir v)"
write_landrun_stub "$BIN_V/landrun"
write_noop_stub "$BIN_V/lean4export"
write_lake_stub "$BIN_V/lake"
make_lean_stub "${BIN_V}"
GUARD_V="$WORKDIR/guard-v.sh"
write_guard_stub "$GUARD_V" "$WORKDIR/guard-argv-v.log"

# LAST_CASE_OUTPUT communicates the captured tool output back to the caller as a global,
# rather than via the function's own stdout -- run_verdict_case's pass()/fail() announcements
# also go to stdout via plain echo, and command-substituting the function's stdout (to capture
# the tool output for a later assertion, as Cases V5/V6 need for the anti-vacuous check) would
# silently swallow those announcements along with it.
LAST_CASE_OUTPUT=""

run_verdict_case() {
  # run_verdict_case <label> <expected-verdict> <expected-exit> <stdout> <stderr> <exit-code> [extra tool args...]
  local label="$1" expected_verdict="$2" expected_exit="$3" stdout_text="$4" stderr_text="$5" comparator_exit="$6"
  shift 6
  write_comparator_stub "$BIN_V/comparator" "$stdout_text" "$stderr_text" "$comparator_exit"
  local out rc verdict
  out="$(run_tool "$BIN_V" "$GUARD_V" "$REPO_V" "$@")"
  rc=$?
  verdict="$(get_field "$out" verdict)"
  if [ "$verdict" = "$expected_verdict" ] && [ "$rc" -eq "$expected_exit" ]; then
    pass "$label: verdict=$expected_verdict, exit=$expected_exit"
  else
    fail "$label: expected verdict=$expected_verdict/exit=$expected_exit; got verdict=$verdict/exit=$rc (output: $out)"
  fi
  LAST_CASE_OUTPUT="$out"
}

run_verdict_case "Case V1 (verified)" verified 0 \
  "Your solution is okay!" "" 0

run_verdict_case "Case V2 (definition_hole_needs_human)" definition_hole_needs_human 68 \
  "Your solution is okay!" "" 0 --definitions foo

run_verdict_case "Case V3 (kernel_rejected, default)" kernel_rejected 67 \
  "Lean default kernel rejects the solution" "uncaught exception: some kernel error" 1

run_verdict_case "Case V4 (kernel_rejected, external)" kernel_rejected 67 \
  "nanoda kernel rejected the solution" "uncaught exception: nanoda exited with 1" 1

run_verdict_case "Case V5 (axiom_violation)" axiom_violation 66 \
  "" "uncaught exception: Illegal axiom detected: 'Classical.choice'" 1
OUT_V5="$LAST_CASE_OUTPUT"

run_verdict_case "Case V6 (config_error)" config_error 71 \
  "" "uncaught exception: Const not found in challenge: 'MyTheorem'" 1
OUT_V6="$LAST_CASE_OUTPUT"

run_verdict_case "Case V7 (statement_mismatch, statement)" statement_mismatch 65 \
  "" "uncaught exception: Challenge and solution theorem statement do not match: 'comm'" 1

run_verdict_case "Case V8 (statement_mismatch, kind)" statement_mismatch 65 \
  "" "uncaught exception: Challenge and solution constant kind don't match: 'comm'" 1

run_verdict_case "Case V9 (statement_mismatch, const_closure)" statement_mismatch 65 \
  "" "uncaught exception: Const does not match between challenge and target 'comm'" 1

run_verdict_case "Case V10 (unclassified_failure)" unclassified_failure 72 \
  "" "uncaught exception: something totally new and unrecognised" 1

# Case V11: reason_detail is preserved losslessly for the statement_mismatch fold.
write_comparator_stub "$BIN_V/comparator" "" "uncaught exception: Challenge and solution constant kind don't match: 'comm'" 1
OUT_V11="$(run_tool "$BIN_V" "$GUARD_V" "$REPO_V")"
REASON_V11="$(get_field "$OUT_V11" reason_detail)"
if [ "$REASON_V11" = "kind" ]; then
  pass "Case V11 (reason_detail preserved): reason_detail=kind for the kind-mismatch string"
else
  fail "Case V11 (reason_detail preserved): expected reason_detail=kind; got '$REASON_V11'"
fi

# ---------------------------------------------------------------------------
# Case AV1: anti-vacuous-test guard -- a naive "exit code 1 = rejected, full stop" classifier
# cannot distinguish axiom_violation from config_error (both exit 1); this tool's classifier
# must. Proves the classification is doing real work, not merely forwarding Comparator's exit
# code.
# ---------------------------------------------------------------------------

VERDICT_AV_AXIOM="$(get_field "$OUT_V5" verdict)"
VERDICT_AV_CONFIG="$(get_field "$OUT_V6" verdict)"
naive_classify() { echo "rejected"; }  # a naive classifier: every non-zero exit is just "rejected"
NAIVE_AXIOM="$(naive_classify)"
NAIVE_CONFIG="$(naive_classify)"
if [ "$VERDICT_AV_AXIOM" != "$VERDICT_AV_CONFIG" ] && [ "$NAIVE_AXIOM" = "$NAIVE_CONFIG" ]; then
  pass "Case AV1 (anti-vacuous): tool distinguishes axiom_violation ($VERDICT_AV_AXIOM) from config_error ($VERDICT_AV_CONFIG) on two exit-1 fixtures a naive classifier ($NAIVE_AXIOM) cannot tell apart"
else
  fail "Case AV1 (anti-vacuous): expected tool to distinguish axiom_violation/config_error while a naive exit-code-only classifier could not; got tool=[$VERDICT_AV_AXIOM,$VERDICT_AV_CONFIG] naive=[$NAIVE_AXIOM,$NAIVE_CONFIG]"
fi

# ---------------------------------------------------------------------------
# Mutation check: deliberately breaking one classifier arm (a fresh copy of the tool with the
# axiom_violation string typo'd) must make the corresponding case FAIL, proving this suite's own
# assertions are not vacuously true regardless of the tool's behavior.
# ---------------------------------------------------------------------------

MUTATED_TOOL="$WORKDIR/lean-comparator-run-mutated.sh"
sed 's/Illegal axiom detected/Illegal axiom NEVERMATCHES/' "$TOOL_SRC" > "$MUTATED_TOOL"
chmod +x "$MUTATED_TOOL"
write_comparator_stub "$BIN_V/comparator" "" "uncaught exception: Illegal axiom detected: 'Classical.choice'" 1
OUT_MUTATED="$(PATH="$BIN_V:$PATH" COMPARATOR_BIN="$BIN_V/comparator" COMPARATOR_LANDRUN="$BIN_V/landrun" \
  COMPARATOR_LEAN4EXPORT="$BIN_V/lean4export" LEAN_COMPARATOR_RUN_GUARD_BIN="$GUARD_V" \
  bash "$MUTATED_TOOL" --project-root "$REPO_V" --challenge-module Challenge --solution-module Solution \
    --theorems comm --permitted-axioms "" 2>&1)"
VERDICT_MUTATED="$(get_field "$OUT_MUTATED" verdict)"
if [ "$VERDICT_MUTATED" != "axiom_violation" ]; then
  pass "Mutation check: breaking the axiom_violation string match no longer yields axiom_violation (got '$VERDICT_MUTATED') -- Case V5's assertion is not vacuous"
else
  fail "Mutation check: mutated tool still reported axiom_violation -- Case V5's assertion would pass even against a broken classifier"
fi

# ---------------------------------------------------------------------------
# Cases E1-E2: skip-with-explicit-report for anything requiring the REAL comparator/lean4export
# binaries (confirmed absent on this development host). Never silently reported as a pass.
# ---------------------------------------------------------------------------

if command -v comparator >/dev/null 2>&1 && command -v lean4export >/dev/null 2>&1; then
  # If a future environment provisions these, exercise the real fixtures end to end.
  for fixture in simple_match def_hole_axiom_issue statement_weakened; do
    fdir="$FIXTURES_DIR/$fixture"
    expected_verdict="$(python3 -c "import json; print(json.load(open('$fdir/test.json'))['lean_comparator_run_verdict'])")"
    challenge_module="$(python3 -c "import json; print(json.load(open('$fdir/config.json'))['challenge_module'])")"
    solution_module="$(python3 -c "import json; print(json.load(open('$fdir/config.json'))['solution_module'])")"
    theorem_names="$(python3 -c "import json; print(','.join(json.load(open('$fdir/config.json'))['theorem_names']))")"
    permitted_axioms="$(python3 -c "import json; print(','.join(json.load(open('$fdir/config.json'))['permitted_axioms']))")"
    FREPO="$WORKDIR/repo-e-$fixture"
    mkdir -p "$FREPO"
    ( cd "$FREPO" && git init -q && git config user.email t@t.com && git config user.name t \
      && cp "$fdir/Challenge.lean" "$fdir/Solution.lean" . \
      && printf 'leanprover/lean4:v4.99.0\n' > lean-toolchain \
      && git add -A && git commit -qm initial )
    OUT_E="$(COMPARATOR_LANDRUN="$FIXTURES_DIR/fake-landrun.sh" \
      bash "$TOOL_SRC" --project-root "$FREPO" --challenge-module "$challenge_module" \
        --solution-module "$solution_module" --theorems "$theorem_names" \
        --permitted-axioms "$permitted_axioms" 2>&1)"
    ACTUAL_VERDICT="$(get_field "$OUT_E" verdict)"
    if [ "$ACTUAL_VERDICT" = "$expected_verdict" ]; then
      pass "Case E ($fixture, real comparator): verdict=$expected_verdict"
    else
      fail "Case E ($fixture, real comparator): expected verdict=$expected_verdict; got $ACTUAL_VERDICT"
    fi
  done
else
  skip "Case E1 (real end-to-end verified/statement_mismatch/axiom_violation demonstration against simple_match/statement_weakened/def_hole_axiom_issue): DEFERRED -- real 'comparator' and/or 'lean4export' binaries are not present on this host. This defers the dispatch's acceptance criteria requiring demonstration 'on real files' via the genuine upstream binary (as opposed to the stub comparator used in Cases V1-V11 above, which exercises this wrapper's OWN classify_verdict() logic faithfully but not Comparator's real build/export/kernel-replay pipeline). Provisioning is tracked by a sibling ~/.dotfiles/ task outside this repository; re-run this suite once 'comparator' and 'lean4export' are on PATH to convert this into a real pass."
fi

if command -v landrun >/dev/null 2>&1; then
  info "Real 'landrun' is present on PATH -- fake-landrun.sh substitution in Case E above was not exercised as a substitute this run."
else
  skip "Case E2 (real landrun sandboxing): DEFERRED -- real 'landrun' is not present on this host; fake-landrun.sh (vendored in fixtures/comparator/) is used as the development substitute wherever this suite invokes Comparator for real, per the dispatch's own guidance. Real sandboxing behavior (address-family restriction, filesystem confinement) is therefore NOT exercised by this suite on this host."
fi

# ---------------------------------------------------------------------------
# Sibling-suite regression check: this suite must not break test-lean-sorry-census.sh, which
# shares lake-build-guard.sh resolution conventions.
# ---------------------------------------------------------------------------

SORRY_CENSUS_TEST="$SCRIPT_DIR/test-lean-sorry-census.sh"
if [ -f "$SORRY_CENSUS_TEST" ]; then
  if bash "$SORRY_CENSUS_TEST" >/tmp/lean-comparator-run-sibling-check.$$.log 2>&1; then
    pass "Sibling-suite regression check: test-lean-sorry-census.sh still exits 0"
  else
    fail "Sibling-suite regression check: test-lean-sorry-census.sh no longer exits 0 (see /tmp/lean-comparator-run-sibling-check.$$.log)"
  fi
  rm -f "/tmp/lean-comparator-run-sibling-check.$$.log"
else
  info "test-lean-sorry-census.sh not found at $SORRY_CENSUS_TEST -- skipping sibling-suite regression check (not a failure; the sibling script may not be deployed in this checkout)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

info "Passed: $PASSED, Failed: $FAILED, Skipped: $SKIPPED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
