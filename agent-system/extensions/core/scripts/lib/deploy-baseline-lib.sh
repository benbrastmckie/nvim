#!/usr/bin/env bash
# deploy-baseline-lib.sh - Single home of the pre/post verify-deploy.sh --findings snapshot and
# the new-findings set-difference algorithm that decides whether a redeploy's post-deploy
# verify-deploy.sh outcome is a genuinely NEW failure or a pre-existing one the redeploy did not
# introduce. Modelled structurally on lib/deploy-freshness-lib.sh: a header stating it is the
# single home of the algorithm, safe to source, sets no shell options a caller inherits, and
# exports nothing a caller must guess at.
#
# This is the three-branch (a)/(b)/(c) contract documented in
# context/patterns/batch-orchestration-guardrails.md's "### The Inter-Cycle Redeploy Checkpoint"
# subsection:
#   (a) deploy-headless.sh exit 1 or 2 (the deploy did not land) -- unconditional refuse, no
#       baseline consultation. NOT implemented here; each caller keeps that branch inline since
#       it precedes any need for a findings snapshot at all.
#   (b) deploy landed (exit 0 or 3) AND the post-redeploy findings set contains at least one line
#       absent from the pre-redeploy findings set -- refuse (a genuinely new failure).
#   (c) deploy landed AND every post-redeploy finding was already present pre-redeploy -- proceed,
#       loudly, recording a baseline notice.
#
# Before this library existed, TWO call sites independently implemented this exact algorithm --
# command-gate-out.sh's rc==6 handler (correctly, including the exit-2 sentinel fold) and
# orchestrate-cycle-plan.sh's inter-cycle redeploy checkpoint (which never reached its own
# baseline-tolerance branch on deploy-headless.sh exit 3, and lacked the exit-2 sentinel fold
# entirely) -- and had drifted apart. Both now source this file instead of carrying their own
# copy, so they cannot drift apart again.
#
# Exports TWO functions:
#
#   deploy_findings_snapshot <verify_deploy_path> [extra verify-deploy.sh args...]
#     Runs `<verify_deploy_path> --findings --quiet [extra args]`. If that invocation exits 2
#     ("cannot run"), prints exactly one synthesized sentinel line:
#       FINDING gate0 [SENTINEL] verify-deploy could not run (exit 2)
#     Otherwise prints every `^FINDING ` line from its output, `sort -u`'d. Never aborts, never
#     propagates the invoked script's exit code to its own caller -- a snapshot is always
#     produced, even when empty.
#
#   deploy_baseline_new_findings <pre_findings> <post_findings>
#     Usage: deploy_baseline_new_findings "$pre" "$post"  (both arguments are newline-separated
#     findings text, typically the captured stdout of two deploy_findings_snapshot calls).
#     Prints the `comm -13` set difference -- lines present in <post_findings> but absent from
#     <pre_findings> -- i.e. exactly the newly-introduced findings. Prints nothing when the two
#     sets are identical or when <post_findings> is a subset of <pre_findings>.
#
# Neither function ever exits non-zero or raises on a normal (findings-bearing or empty) run;
# both `sort -u` their inputs/outputs so caller-side ordering never matters for the comparison.

# ─── deploy_findings_snapshot <verify_deploy_path> [extra args...] ─────────────────────────────
deploy_findings_snapshot() {
  local verify_deploy_path="$1"
  shift || true
  local rc=0
  local out
  out="$(bash "$verify_deploy_path" --findings --quiet "$@" 2>/dev/null)" || rc=$?
  if [ "$rc" -eq 2 ]; then
    echo "FINDING gate0 [SENTINEL] verify-deploy could not run (exit 2)"
  else
    # `|| true`: a clean verify-deploy run (no FINDING lines) makes `grep` return 1 (no match),
    # which -- under a caller's `set -e -o pipefail` (this function runs in the caller's own
    # shell, being sourced, not a subshell) -- would otherwise abort the CALLER's script the
    # moment it captures this function's output via `x=$(deploy_findings_snapshot ...)`. An
    # empty findings set is a normal, expected outcome here, never an error.
    printf '%s\n' "$out" | grep '^FINDING ' | sort -u || true
  fi
}

# ─── deploy_baseline_new_findings <pre_findings> <post_findings> ───────────────────────────────
deploy_baseline_new_findings() {
  local pre="$1"
  local post="$2"
  comm -13 \
    <(printf '%s\n' "$pre" | sort -u) \
    <(printf '%s\n' "$post" | sort -u)
}
