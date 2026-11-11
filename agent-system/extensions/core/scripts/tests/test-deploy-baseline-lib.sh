#!/usr/bin/env bash
# test-deploy-baseline-lib.sh - Unit coverage for scripts/lib/deploy-baseline-lib.sh, the single
# shared home of the pre/post verify-deploy.sh --findings snapshot and new-findings set
# difference algorithm both command-gate-out.sh's rc==6 handler and orchestrate-cycle-plan.sh's
# inter-cycle redeploy checkpoint now source (see the header of the library itself, and
# context/patterns/batch-orchestration-guardrails.md's "### The Inter-Cycle Redeploy Checkpoint"
# subsection for the three-branch contract this library serves).
#
# Coverage:
#   deploy_findings_snapshot   -- exit 0 -> findings (or empty); exit 1 -> findings; exit 2 -> the
#                                  single synthesized sentinel line; a clean run (no FINDING lines)
#                                  must not abort the caller under set -e -o pipefail.
#   deploy_baseline_new_findings -- identical sets -> empty; superset -> exactly the added lines;
#                                  the documented pre-exit-0/post-exit-2 case -> non-empty (the
#                                  sentinel itself counts as a newly-introduced finding).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# library was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$CORE_DIR/lib/deploy-baseline-lib.sh"
GVEL_LIB="$CORE_DIR/lib/gate-verdict-extract-lib.sh"

if [[ ! -f "$LIB" ]]; then
  echo "ERROR: expected $LIB" >&2
  exit 2
fi
if [[ ! -f "$GVEL_LIB" ]]; then
  echo "ERROR: expected $GVEL_LIB" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$LIB"
# shellcheck source=/dev/null
source "$GVEL_LIB"

PASSED=0
FAILED=0

common_test_workdir_init

write_fake_verify() {
  # Usage: write_fake_verify <path> <exit_code> <findings_lines...>
  local path="$1" rc="$2"; shift 2
  {
    echo '#!/usr/bin/env bash'
    for line in "$@"; do
      printf 'echo %q\n' "$line"
    done
    echo "exit $rc"
  } > "$path"
  chmod +x "$path"
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# deploy_findings_snapshot
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case 1: exit 0, no FINDING lines (the ordinary clean case) -- must be empty AND must not abort
# the calling shell under set -e -o pipefail (this is the exact bug class this suite pins: a
# `grep` with zero matches, uncaught, would otherwise kill the caller's script).
VERIFY_CLEAN="$WORKDIR/verify-clean.sh"
write_fake_verify "$VERIFY_CLEAN" 0 "[verify-deploy] PASS -- 14 check(s), 0 failure(s)"
# shellcheck disable=SC1090  # $LIB is resolved at runtime (source-store vs deployed path); not a constant shellcheck can follow.
case_1_out="$( (set -euo pipefail; source "$LIB"; deploy_findings_snapshot "$VERIFY_CLEAN") )"
case_1_result="$?"
if [ "$case_1_result" = "0" ] && [ -z "$case_1_out" ]; then
  common_test_pass "deploy_findings_snapshot: exit-0 clean run does not abort under set -e -o pipefail, and returns empty"
else
  common_test_fail "deploy_findings_snapshot: exit-0 clean run (result=$case_1_result, out='$case_1_out')"
fi

# Case 2: exit 1 with FINDING lines -- returned sorted and deduplicated.
VERIFY_FAIL="$WORKDIR/verify-fail.sh"
write_fake_verify "$VERIFY_FAIL" 1 \
  "FINDING gate3 something wrong" \
  "FINDING gate1 something else wrong" \
  "FINDING gate3 something wrong"
out2="$(deploy_findings_snapshot "$VERIFY_FAIL")"
expected2="$(printf 'FINDING gate1 something else wrong\nFINDING gate3 something wrong')"
if [ "$out2" = "$expected2" ]; then
  common_test_pass "deploy_findings_snapshot: exit-1 findings returned sorted and deduplicated"
else
  common_test_fail "deploy_findings_snapshot: exit-1 findings mismatch (got: '$out2')"
fi

# Case 3: exit 2 ("cannot run") -- folded into the single sentinel line, regardless of whatever
# prose the fake script printed (never treated as ordinary FINDING lines).
VERIFY_CANNOT_RUN="$WORKDIR/verify-cannotrun.sh"
write_fake_verify "$VERIFY_CANNOT_RUN" 2 "some unrelated prose, no FINDING prefix"
out3="$(deploy_findings_snapshot "$VERIFY_CANNOT_RUN")"
if [ "$out3" = "FINDING gate0 [SENTINEL] verify-deploy could not run (exit 2)" ]; then
  common_test_pass "deploy_findings_snapshot: exit-2 folds to the single sentinel line"
else
  common_test_fail "deploy_findings_snapshot: exit-2 sentinel mismatch (got: '$out3')"
fi

# Case 3b ("Attestation Integrity"): --skip-unchanged must never reach the invoked
# verify-deploy.sh from a findings snapshot -- a skip here could remove a gate's findings from
# exactly one side of a pre/post baseline comparison (fact 3 in the plan's own Research
# Integration section). The fake script below PROVES the flag never arrives: it inspects its own
# argv and reports a FINDING if (and only if) it sees --skip-unchanged, so any leak is directly
# observable, and any other argument passes through unaffected (confirmed via --only-gate 10,
# which must still reach the script).
VERIFY_FLAG_PROBE="$WORKDIR/verify-flag-probe.sh"
cat > "$VERIFY_FLAG_PROBE" << 'EOF'
#!/usr/bin/env bash
saw_flag=false
saw_only_gate=false
for a in "$@"; do
  [ "$a" = "--skip-unchanged" ] && saw_flag=true
  [ "$a" = "--only-gate" ] && saw_only_gate=true
done
if $saw_flag; then
  echo "FINDING gate0 the fake verify-deploy received --skip-unchanged"
  exit 1
fi
if ! $saw_only_gate; then
  echo "FINDING gate0 the fake verify-deploy did not receive --only-gate (other args were dropped too)"
  exit 1
fi
exit 0
EOF
chmod +x "$VERIFY_FLAG_PROBE"
out3b="$(deploy_findings_snapshot "$VERIFY_FLAG_PROBE" --skip-unchanged --only-gate 10)"
if [ -z "$out3b" ]; then
  common_test_pass "deploy_findings_snapshot: --skip-unchanged is filtered out of the passthrough; other args (--only-gate 10) still reach the invoked script unaffected"
else
  common_test_fail "deploy_findings_snapshot: --skip-unchanged passthrough rejection failed (out='$out3b')"
fi

# Case 3c: even with a "warm cache" present, a findings snapshot runs the FULL gate set --
# demonstrated by a fake script that would take the cached-skip (clean, no findings) branch ONLY
# if it both sees --skip-unchanged AND finds a warm-cache marker file; since
# deploy_findings_snapshot strips the flag unconditionally, the script must always fall through
# to the full-run branch, which reports a real finding. This is a deterministic proxy for "the
# cache was genuinely warm and the flag was genuinely requested, yet the snapshot still saw the
# full-run result" -- the required property, without depending on real gate pass/fail state or
# live cache contents.
WARM_MARKER="$WORKDIR/warm.marker"
touch "$WARM_MARKER"
VERIFY_WARM_CACHE_SIM="$WORKDIR/verify-warm-cache-sim.sh"
cat > "$VERIFY_WARM_CACHE_SIM" << EOF
#!/usr/bin/env bash
saw_flag=false
for a in "\$@"; do
  [ "\$a" = "--skip-unchanged" ] && saw_flag=true
done
if \$saw_flag && [ -f "$WARM_MARKER" ]; then
  exit 0
fi
echo "FINDING gate7 a real finding only visible on the full-run branch"
exit 1
EOF
chmod +x "$VERIFY_WARM_CACHE_SIM"
out3c="$(deploy_findings_snapshot "$VERIFY_WARM_CACHE_SIM" --skip-unchanged --only-gate 7)"
if [ "$out3c" = "FINDING gate7 a real finding only visible on the full-run branch" ]; then
  common_test_pass "deploy_findings_snapshot: runs the full gate set even with a warm cache present and --skip-unchanged requested"
else
  common_test_fail "deploy_findings_snapshot: expected the full-run finding despite the warm-cache marker (out='$out3c')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# deploy_baseline_new_findings
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case 4: identical sets -> empty.
pre4="FINDING gate1 a
FINDING gate2 b"
post4="FINDING gate1 a
FINDING gate2 b"
new4="$(deploy_baseline_new_findings "$pre4" "$post4")"
if [ -z "$new4" ]; then
  common_test_pass "deploy_baseline_new_findings: identical sets produce empty diff"
else
  common_test_fail "deploy_baseline_new_findings: identical sets produced '$new4' (expected empty)"
fi

# Case 5: superset -> exactly the added line(s).
pre5="FINDING gate1 a"
post5="FINDING gate1 a
FINDING gate2 b"
new5="$(deploy_baseline_new_findings "$pre5" "$post5")"
if [ "$new5" = "FINDING gate2 b" ]; then
  common_test_pass "deploy_baseline_new_findings: superset returns exactly the added line"
else
  common_test_fail "deploy_baseline_new_findings: superset mismatch (got: '$new5')"
fi

# Case 6: the documented pre-exit-0/post-exit-2 case -- pre has no sentinel, post does -> the
# sentinel itself is a new finding, non-empty diff (this is what makes the checkpoint's branch
# (b) fire on a redeploy that succeeded yet cannot be verified at all).
pre6=""
post6="FINDING gate0 [SENTINEL] verify-deploy could not run (exit 2)"
new6="$(deploy_baseline_new_findings "$pre6" "$post6")"
if [ "$new6" = "FINDING gate0 [SENTINEL] verify-deploy could not run (exit 2)" ]; then
  common_test_pass "deploy_baseline_new_findings: pre-clean/post-cannot-run makes the sentinel a new finding (non-empty)"
else
  common_test_fail "deploy_baseline_new_findings: pre-exit-0/post-exit-2 case mismatch (got: '$new6')"
fi

# Case 7: empty/empty -> empty (both sides clean).
new7="$(deploy_baseline_new_findings "" "")"
if [ -z "$new7" ]; then
  common_test_pass "deploy_baseline_new_findings: empty/empty produces empty diff"
else
  common_test_fail "deploy_baseline_new_findings: empty/empty produced '$new7' (expected empty)"
fi

# ─── Cases 8-11: the governing-source attribution signal ────────────────────────────────────────
# Regression for a live defect: a batch that modified `runtime-file-patterns.sh` to declare a new
# ephemeral file class produced the gate finding `specs/000_probe/.decisions.lock is NOT ignored`.
# Its only identifier is a SYNTHETIC PROBE PATH, which can never match a modified source by
# basename, so the attribution filter cleared it as unrelated and the batch proceeded over a real
# defect it had itself caused. The DEPLOY_BASELINE_GOVERNED_GLOBS map must now attribute it.

# Case 8 (regression): probe-path finding + a modified governing source -> ATTRIBUTABLE, i.e. the
# function must NOT print it (printing means "cleared as unrelated").
f8='FINDING gate14 specs/000_probe/.decisions.lock is NOT ignored (ephemeral class must be gitignored)'
mods8='["agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh","agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh"]'
out8="$(deploy_baseline_unattributable_findings "$f8" "$mods8")"
if [ -z "$out8" ]; then
  common_test_pass "deploy_baseline_unattributable_findings: probe-path finding is attributed via its governing source (stays blocking)"
else
  common_test_fail "deploy_baseline_unattributable_findings: probe-path finding wrongly cleared as unrelated (got: '$out8')"
fi

# Case 9 (no over-attribution): a genuinely unrelated finding must still be cleared, so the new
# signal cannot degrade into a blanket "attribute everything" that would cause false defers.
f9='FINDING gate7 scripts/tests/test-lake-build-guard.sh timed out'
mods9='["agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh"]'
out9="$(deploy_baseline_unattributable_findings "$f9" "$mods9")"
if [ "$out9" = "$f9" ]; then
  common_test_pass "deploy_baseline_unattributable_findings: an unrelated finding is still cleared despite a governing source being modified"
else
  common_test_fail "deploy_baseline_unattributable_findings: over-attributed an unrelated finding (got: '$out9')"
fi

# Case 10 (signal requires BOTH halves): the same probe-path finding, but the batch touched no
# governing source -> still cleared as unrelated.
f10='FINDING gate14 specs/000_probe/.decisions.lock is NOT ignored'
mods10='["lua/neotex/core/options.lua"]'
out10="$(deploy_baseline_unattributable_findings "$f10" "$mods10")"
if [ "$out10" = "$f10" ]; then
  common_test_pass "deploy_baseline_unattributable_findings: governed glob alone does not attribute without a modified governing source"
else
  common_test_fail "deploy_baseline_unattributable_findings: attributed a governed path with no governing source modified (got: '$out10')"
fi

# Case 11 (map integrity): the two halves of the governing-source map are indexed in lockstep.
if [ "${#DEPLOY_BASELINE_GOVERNED_GLOBS[@]}" -eq "${#DEPLOY_BASELINE_GOVERNING_SOURCES[@]}" ] \
   && [ "${#DEPLOY_BASELINE_GOVERNED_GLOBS[@]}" -gt 0 ]; then
  common_test_pass "governing-source map: both arrays have ${#DEPLOY_BASELINE_GOVERNED_GLOBS[@]} entries (1:1 by construction)"
else
  common_test_fail "governing-source map: array lengths diverge (${#DEPLOY_BASELINE_GOVERNED_GLOBS[@]} globs vs ${#DEPLOY_BASELINE_GOVERNING_SOURCES[@]} source lists)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# deploy_baseline_self_attributable_findings -- the NARROWING counterpart added for the
# self-attribution screen (see this file's header, "DELIBERATE FAIL-SAFE ASYMMETRY").
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# The exact Rule Q finding text from check-extension-docs.sh's check_undeclared_scripts, the
# regression scenario this suite exists to pin.
RULEQ_LINE='FINDING gate3 [core] FAIL: script file on disk NOT in provides.scripts: scripts/tests/test-X.sh'

# Case 12: a matching own-file -> reported (attributable).
mods12='["agent-system/extensions/core/scripts/tests/test-X.sh"]'
out12="$(deploy_baseline_self_attributable_findings "$RULEQ_LINE" "$mods12")"
if [ "$out12" = "$RULEQ_LINE" ]; then
  common_test_pass "deploy_baseline_self_attributable_findings: Rule Q line with a matching own-file is reported"
else
  common_test_fail "deploy_baseline_self_attributable_findings: matching own-file case mismatch (got: '$out12')"
fi

# Case 13: a non-matching own-file -> not reported.
mods13='["lua/neotex/core/options.lua"]'
out13="$(deploy_baseline_self_attributable_findings "$RULEQ_LINE" "$mods13")"
if [ -z "$out13" ]; then
  common_test_pass "deploy_baseline_self_attributable_findings: Rule Q line with a non-matching own-file is NOT reported"
else
  common_test_fail "deploy_baseline_self_attributable_findings: non-matching own-file wrongly reported (got: '$out13')"
fi

# Case 14: an identifier-free line -> never reported, under either modified_files shape.
f14='FINDING gate9 something generic with no path or filename at all'
out14a="$(deploy_baseline_self_attributable_findings "$f14" "$mods12")"
out14b="$(deploy_baseline_self_attributable_findings "$f14" '[]')"
if [ -z "$out14a" ] && [ -z "$out14b" ]; then
  common_test_pass "deploy_baseline_self_attributable_findings: an identifier-free line is never reported, under either modified_files shape"
else
  common_test_fail "deploy_baseline_self_attributable_findings: identifier-free line wrongly reported (got: '$out14a' / '$out14b')"
fi

# Case 15: empty/malformed modified_files_json degrades without aborting the caller under
# set -e -o pipefail (the same hazard class deploy_findings_snapshot's own header documents).
# shellcheck disable=SC1090  # $LIB is resolved at runtime (source-store vs deployed path); not a constant shellcheck can follow.
out15a="$( (set -euo pipefail; source "$LIB"; deploy_baseline_self_attributable_findings "$RULEQ_LINE" "") )"
rc15a=$?
# shellcheck disable=SC1090  # $LIB is resolved at runtime (source-store vs deployed path); not a constant shellcheck can follow.
out15b="$( (set -euo pipefail; source "$LIB"; deploy_baseline_self_attributable_findings "$RULEQ_LINE" "not valid json") )"
rc15b=$?
if [ "$rc15a" -eq 0 ] && [ -z "$out15a" ] && [ "$rc15b" -eq 0 ] && [ -z "$out15b" ]; then
  common_test_pass "deploy_baseline_self_attributable_findings: empty/malformed modified_files_json degrades to empty without aborting the caller"
else
  common_test_fail "deploy_baseline_self_attributable_findings: malformed-input case mismatch (rc15a=$rc15a out15a='$out15a' rc15b=$rc15b out15b='$out15b')"
fi

# Case 16 (polarity pair): the matching-own-file line is reported by exactly ONE of the two
# functions -- never both, never neither.
attr16="$(deploy_baseline_self_attributable_findings "$RULEQ_LINE" "$mods12")"
unattr16="$(deploy_baseline_unattributable_findings "$RULEQ_LINE" "$mods12")"
if [ -n "$attr16" ] && [ -z "$unattr16" ]; then
  common_test_pass "polarity pair: the matching-own-file line is reported by self_attributable and NOT by unattributable"
else
  common_test_fail "polarity pair mismatch: self_attributable='$attr16' unattributable='$unattr16' (expected exactly one non-empty)"
fi
# And the mirror: a non-matching own-file line is reported by unattributable and NOT by
# self_attributable (the existing Case 9 scenario, re-asserted from the other polarity).
attr16b="$(deploy_baseline_self_attributable_findings "$f9" "$mods9")"
unattr16b="$(deploy_baseline_unattributable_findings "$f9" "$mods9")"
if [ -z "$attr16b" ] && [ -n "$unattr16b" ]; then
  common_test_pass "polarity pair: an unrelated finding is reported by unattributable and NOT by self_attributable"
else
  common_test_fail "polarity pair mismatch (unrelated finding): self_attributable='$attr16b' unattributable='$unattr16b'"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# verify_deploy_extract_verdict_lines (scripts/lib/gate-verdict-extract-lib.sh) -- the anchored,
# SGR-stripping consumer-side extraction helper that replaces all 14 of verify-deploy.sh's
# previously-unanchored `grep -F '[FAIL]'` / `grep -F '[VIOLATION]'` sites. Pins the three
# regression shapes from the live batch-gate incident this helper fixes, plus the SGR case that
# proves the fix is safe to apply uniformly across colored and uncolored producers alike. See
# context/standards/shell-script-testing.md's "Verdict-line extraction contract" section.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case 17: a genuine line-initial `[FAIL] <path>` row IS selected (run-all.sh's own shape).
out17="$(verify_deploy_extract_verdict_lines '[FAIL]' $'[run-all] [RUN]  foo\n[FAIL] /path/test-real.sh\n[run-all] 3 passed, 1 failed')"
if [ "$out17" = "/path/test-real.sh" ]; then
  common_test_pass "verify_deploy_extract_verdict_lines: line-initial [FAIL] <path> row is selected"
else
  common_test_fail "verify_deploy_extract_verdict_lines: line-initial [FAIL] row mismatch (got: '$out17')"
fi

# Case 18 (the measured false positive): a [PASS] narration line whose own message text quotes
# the anchor token is NOT selected.
out18="$(verify_deploy_extract_verdict_lines '[FAIL]' '[PASS] case3: exactly one [FAIL] line for commands/orchestrate.md under hard mode')"
if [ -z "$out18" ]; then
  common_test_pass "verify_deploy_extract_verdict_lines: a [PASS] line quoting [FAIL] in its message is NOT selected"
else
  common_test_fail "verify_deploy_extract_verdict_lines: [PASS]-quoting-[FAIL] line wrongly selected (got: '$out18')"
fi

# Case 19 (the measured false positive): an indented, fixture-internal [FAIL] line emitted by a
# suite's OWN inner output (not run-all.sh's verdict on that suite) is NOT selected.
out19="$(verify_deploy_extract_verdict_lines '[FAIL]' '    [FAIL] baseline fixture is not clean (rc=1, ...)')"
if [ -z "$out19" ]; then
  common_test_pass "verify_deploy_extract_verdict_lines: an indented fixture-internal [FAIL] line is NOT selected"
else
  common_test_fail "verify_deploy_extract_verdict_lines: indented fixture-internal line wrongly selected (got: '$out19')"
fi

# Case 20 (why a bare anchor alone is unsafe): an SGR-colored verdict row -- as 12 of the 14 real
# producers emit with no TTY/NO_COLOR guard -- IS selected once SGR is stripped first.
sgr_fail=$'\x1b[31m[FAIL]\x1b[0m lint-lifecycle-status-var: 3 violation(s) across 10 file(s)'
out20="$(verify_deploy_extract_verdict_lines '[FAIL]' "$sgr_fail")"
if [ "$out20" = "lint-lifecycle-status-var: 3 violation(s) across 10 file(s)" ]; then
  common_test_pass "verify_deploy_extract_verdict_lines: an SGR-prefixed [FAIL] row is selected after stripping"
else
  common_test_fail "verify_deploy_extract_verdict_lines: SGR-prefixed [FAIL] row mismatch (got: '$out20')"
fi

# Case 21: the same four shapes, but with the [VIOLATION] token (the other anchor family used by
# 9 of the 14 call sites) -- confirms the anchor token travels as an explicit parameter rather
# than being hardcoded to [FAIL] internally.
sgr_violation=$'\x1b[31m[VIOLATION]\x1b[0m file.sh:12: bare shared-directory pathspec'
out21a="$(verify_deploy_extract_verdict_lines '[VIOLATION]' "$sgr_violation")"
out21b="$(verify_deploy_extract_verdict_lines '[VIOLATION]' '[PASS] exactly one [VIOLATION] line expected')"
if [ "$out21a" = "file.sh:12: bare shared-directory pathspec" ] && [ -z "$out21b" ]; then
  common_test_pass "verify_deploy_extract_verdict_lines: [VIOLATION] anchor token behaves identically (SGR-selected, PASS-noise-rejected)"
else
  common_test_fail "verify_deploy_extract_verdict_lines: [VIOLATION] anchor mismatch (got: '$out21a' / '$out21b')"
fi

# Case 22: multi-line input preserves relative order and selects only the anchored subset,
# combining the line-initial, PASS-noise, fixture-internal, and SGR shapes in one capture (the
# realistic shape of a real run-all.sh --quiet output after a failing run).
mixed_output=$'[run-all] [RUN]  test-a.sh\n[run-all] [PASS] test-a.sh\n[run-all] [RUN]  test-b.sh\n[PASS] case3: exactly one [FAIL] line for X\n    [FAIL] baseline fixture is not clean\n[FAIL] test-b.sh\n[run-all] 1 passed, 1 failed, 0 skipped, 2 total'
out22="$(verify_deploy_extract_verdict_lines '[FAIL]' "$mixed_output")"
if [ "$out22" = "test-b.sh" ]; then
  common_test_pass "verify_deploy_extract_verdict_lines: a realistic mixed-shape capture selects exactly the one true verdict row"
else
  common_test_fail "verify_deploy_extract_verdict_lines: mixed-shape capture mismatch (got: '$out22')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 23 (per-site pinning): every one of verify-deploy.sh's 13 Phase-2-migrated producer
# scripts still emits its verdict row in the exact shape
# verify_deploy_extract_verdict_lines() depends on -- either SGR-colored
# (`echo -e "${RED}[TOKEN]${NC} ..."`, 12 of 13 producers) or genuinely line-initial and uncolored
# (`echo "[VIOLATION] ..."`, lint-shellcheck.sh alone). A producer that silently changes this
# shape (e.g. drops color, or indents its own verdict row) would desync from the anchored
# extraction contract without any corpus-level test noticing on a clean corpus -- this case pins
# the PRODUCER'S OWN SOURCE CODE, not merely a captured sample output, so drift is caught at the
# producer regardless of whether the live corpus currently has anything to report.
declare -a SITE_PRODUCERS=(
  "gate6:lint/lint-agent-contracts.sh:FAIL:colored"
  "gate7:lint/lint-routing-wiring.sh:FAIL:colored"
  "gate9:lint/lint-postflight-boundary.sh:VIOLATION:colored"
  "gate10:validate-state.sh:FAIL:colored"
  "gate11:lint/lint-contract-compliance.sh:FAIL:colored"
  "gate12:lint/lint-state-writer-boundary.sh:VIOLATION:colored"
  "gate15:lint/lint-lifecycle-status-var.sh:VIOLATION:colored"
  "gate17:lint/lint-scoped-commit-boundary.sh:VIOLATION:colored"
  "gate18:lint/lint-task-lookup-adoption.sh:VIOLATION:colored"
  "gate19:lint/lint-branch-gated-sections.sh:VIOLATION:colored"
  "gate21:lint/lint-hook-registration-paths.sh:VIOLATION:colored"
  "gate22:lint/lint-shellcheck.sh:VIOLATION:uncolored"
  "gate23:lint/lint-directory-pathspec-boundary.sh:VIOLATION:colored"
)
site_mismatch=0
site_mismatch_detail=""
for entry in "${SITE_PRODUCERS[@]}"; do
  IFS=':' read -r gate relpath token shape <<< "$entry"
  producer_path="$CORE_DIR/$relpath"
  if [ ! -f "$producer_path" ]; then
    site_mismatch=$((site_mismatch + 1))
    site_mismatch_detail="${site_mismatch_detail}${gate}:${relpath} MISSING; "
    continue
  fi
  if [ "$shape" = "colored" ]; then
    # shellcheck disable=SC2016  # intentionally literal grep pattern, not a shell expansion
    if ! grep -qE 'echo -e "\$\{RED\}\['"$token"'\]\$\{NC\}' "$producer_path"; then
      site_mismatch=$((site_mismatch + 1))
      site_mismatch_detail="${site_mismatch_detail}${gate}:${relpath} expected colored [$token] emission not found; "
    fi
  else
    if ! grep -qE "echo \"\[$token\] " "$producer_path"; then
      site_mismatch=$((site_mismatch + 1))
      site_mismatch_detail="${site_mismatch_detail}${gate}:${relpath} expected uncolored line-initial [$token] emission not found; "
    fi
  fi
  # Regardless of shape, confirm the shared helper selects a representative row built in that
  # producer's own declared shape -- the actual mechanism-level guarantee this case exists for.
  if [ "$shape" = "colored" ]; then
    sample=$'\x1b[31m['"$token"$']\x1b[0m sample message for '"$gate"
  else
    sample="[$token] sample message for $gate"
  fi
  sample_out="$(verify_deploy_extract_verdict_lines "[$token]" "$sample")"
  if [ "$sample_out" != "sample message for $gate" ]; then
    site_mismatch=$((site_mismatch + 1))
    site_mismatch_detail="${site_mismatch_detail}${gate}:${relpath} helper did not select its own-shape sample (got: '$sample_out'); "
  fi
done
if [ "$site_mismatch" -eq 0 ]; then
  common_test_pass "per-site pinning: all 13 Phase-2-migrated producers still match the emission shape verify_deploy_extract_verdict_lines depends on"
else
  common_test_fail "per-site pinning: $site_mismatch producer(s) drifted from the expected emission shape" "$site_mismatch_detail"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# --skip-unchanged fail-open classes, at the REAL verify-deploy.sh interface (not the library
# function level -- gate-cache-lib.sh's own test suite already covers these three classes as
# direct function calls). A stale, absent, unreadable, or ambiguous cache must degrade to a full
# run, never a false pass. Driven against an ISOLATED scratch target (its own specs/.gate-cache/,
# never the live repo's) with a symlinked agent-system/ so gate_cache_implementation_digest can
# resolve verify-deploy.sh/gate-registry.data/scripts/lib -- gate 1 ("Event-store and error-store
# files") is used throughout: cheap, free-cost, and its corpus is nine literal paths easy to
# stand up in a scratch .claude/ tree.
VERIFY_DEPLOY_REAL="$CORE_DIR/verify-deploy.sh"
if [ -f "$VERIFY_DEPLOY_REAL" ]; then
  VD_SCRATCH="$WORKDIR/vd-scratch"
  mkdir -p "$VD_SCRATCH/.claude/scripts" "$VD_SCRATCH/.claude/hooks" \
    "$VD_SCRATCH/.claude/context/schemas" "$VD_SCRATCH/.claude/context/formats"
  for relf in scripts/events-append.sh scripts/events-query.sh hooks/events-log-artifact.sh \
    hooks/events-log-lifecycle.sh context/schemas/events-schema.json \
    context/formats/events-format.md scripts/errors-append.sh \
    context/schemas/errors-schema.json context/formats/errors-format.md; do
    echo "x" > "$VD_SCRATCH/.claude/$relf"
  done
  # The real repository root is resolved via common_test_repo_root (git rev-parse
  # --show-toplevel first, fixed-depth fallback only outside a git work tree), so this is
  # correct whether this suite runs from the source store or from its deployed copy. It is
  # symlinked in so the scratch target's own implementation-digest component resolves against
  # the REAL verify-deploy.sh/gate-registry.data/scripts/lib, while its CORPUS (the .claude/
  # tree above) stays entirely scratch-local and isolated.
  VD_REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
  if [ -z "$VD_REPO_ROOT" ]; then
    echo "ERROR: could not resolve repository root from $SCRIPT_DIR" >&2
    exit 2
  fi
  ln -s "$VD_REPO_ROOT/agent-system" "$VD_SCRATCH/agent-system"
  mkdir -p "$VD_SCRATCH/specs/.gate-cache"

  vd_full_run_check() {
    # Usage: vd_full_run_check <label> -- runs gate 1 against VD_SCRATCH and asserts a FULL run
    # (all 9 [PASS] lines present, no [SKIP-CACHED], exit 0) -- the fail-open signature.
    local label="$1" out rc
    out="$(bash "$VERIFY_DEPLOY_REAL" --skip-unchanged --only-gate 1 "$VD_SCRATCH" 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ] && ! grep -q 'SKIP-CACHED' <<< "$out" \
      && [ "$(grep -c '\[PASS\]' <<< "$out")" -eq 9 ]; then
      common_test_pass "$label: degrades to a full run (9/9 [PASS], no [SKIP-CACHED], exit 0)"
    else
      common_test_fail "$label: expected a full run with exit 0 and no [SKIP-CACHED] (rc=$rc):
$out"
    fi
  }

  # Warm the scratch cache once with a genuinely matching entry, confirming the harness itself
  # behaves as expected (a real cache hit DOES skip) before exercising the three corruption
  # classes against it -- this is the control, not one of the three fail-open cases.
  bash "$VERIFY_DEPLOY_REAL" --skip-unchanged --only-gate 1 "$VD_SCRATCH" > /dev/null 2>&1
  vd_control_out="$(bash "$VERIFY_DEPLOY_REAL" --skip-unchanged --only-gate 1 "$VD_SCRATCH" 2>&1)"
  if grep -q 'SKIP-CACHED' <<< "$vd_control_out"; then
    common_test_pass "control: a genuinely matching warm-cache entry DOES skip gate 1 (SKIP-CACHED), confirming the harness itself is wired correctly"
  else
    common_test_fail "control: a genuinely matching warm-cache entry was expected to skip gate 1 but did not:
$vd_control_out"
  fi
  VD_CACHE_FILE="$VD_SCRATCH/specs/.gate-cache/gate1.json"
  VD_REAL_KEY="$(jq -r '.key' "$VD_CACHE_FILE" 2>/dev/null)"

  # Class 1: an unreadable store entry (permission-denied) degrades to a full run.
  chmod 000 "$VD_CACHE_FILE"
  vd_full_run_check "unreadable cache entry"
  chmod 644 "$VD_CACHE_FILE"

  # Class 2: a sentinel-valued key (never legitimately written -- gate_cache_entry_write refuses
  # to persist the sentinel, per test-gate-cache-lib.sh's own case23) never matches a real,
  # resolvable computed key, so it degrades to a full run rather than a crash or a false hit.
  printf '{"gate_id":"1","format_version":1,"key":"CANNOT_COMPUTE","verdict":"green","timestamp":"2026-10-16T00:00:00Z"}\n' > "$VD_CACHE_FILE"
  vd_full_run_check "sentinel-valued cache key"

  # Class 3: a format_version mismatch (e.g. a stale entry from a prior cache-format revision)
  # degrades to a full run rather than being misread under the current schema.
  printf '{"gate_id":"1","format_version":0,"key":"%s","verdict":"green","timestamp":"2026-10-16T00:00:00Z"}\n' "$VD_REAL_KEY" > "$VD_CACHE_FILE"
  vd_full_run_check "format_version mismatch"

  rm -rf "$VD_SCRATCH"
else
  common_test_fail "skip-unchanged interface fail-open cases: expected $VERIFY_DEPLOY_REAL"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
