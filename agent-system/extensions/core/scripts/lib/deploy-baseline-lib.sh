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
# Exports FOUR functions:
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
#   deploy_baseline_confirm_new_findings <candidate_new> <confirm_snapshot>
#     Usage: deploy_baseline_confirm_new_findings "$new_findings" "$confirm_findings" (the second
#     argument is a FRESH deploy_findings_snapshot re-run taken after <candidate_new> was first
#     computed). Prints the `comm -12` intersection -- lines present in BOTH sets -- i.e. exactly
#     the candidate-new findings that REPRODUCED on the confirmation run. A candidate finding
#     absent from <confirm_snapshot> did not reproduce and is dropped: it was flaky (see
#     load-sensitive-test note below), never a real regression. This is a pure CONFIRMATION
#     step -- it never introduces a finding <candidate_new> did not already contain, so it can
#     only shrink the candidate set, never grow it.
#
#   deploy_baseline_unattributable_findings <findings> <modified_files_json>
#     Usage: deploy_baseline_unattributable_findings "$findings" "$modified_files_json" (the
#     second argument is a JSON array of repo-relative path strings, typically
#     `cycle_modified_files`). Prints the subset of <findings> that POSITIVELY names a concrete
#     identifier -- a token containing `/` or a token ending in `.sh`/`.md`/`.lua`/`.json` -- for
#     which NO identifier in the line matches (by basename) any entry in <modified_files_json>.
#     Deliberately FAIL-SAFE TOWARD ATTRIBUTABLE (i.e. toward still blocking/deferring): a finding
#     line that names NO identifier at all is NEVER printed by this function -- absence of an
#     identifier can never be used to prove a finding unrelated, only a positively-non-matching
#     identifier can. This is what stops the filter from degrading into a blanket disable: a
#     finding this function cannot positively clear stays in the blocking set.
#
#     SECOND ATTRIBUTION SIGNAL (governing sources). Basename equality alone is not sufficient:
#     some gates report a finding against a GENERATED or SYNTHETIC-PROBE path rather than against
#     the source file that governs it. Such a finding can never match a modified source by
#     basename, so the equality test above would confidently -- and wrongly -- clear it as
#     unrelated. This was observed live: a batch that modified `runtime-file-patterns.sh` to
#     declare a new ephemeral file class produced the gate finding
#     `specs/000_probe/.decisions.lock is NOT ignored`, whose only identifier is a synthetic probe
#     path; it was cleared as unrelated even though the batch had caused it. The
#     DEPLOY_BASELINE_GOVERNED_GLOBS / DEPLOY_BASELINE_GOVERNING_SOURCES map below closes that
#     hole: when an identifier in the line matches a governed glob AND the batch modified any of
#     that glob's governing sources, the finding is treated as attributable and stays in the
#     blocking set. The map is additive and declarative -- adding a gate whose findings name
#     derived paths means adding one entry, never editing the matching logic.
#
# Callers combine these as a two-stage filter on a candidate new-finding set: confirm first
# (drops flaky), then subtract this function's unattributable output from what confirmed (drops
# unrelated). Both filters are ADDITIVE and used ONLY by the multi-task inter-cycle checkpoint
# (orchestrate-cycle-plan.sh) -- command-gate-out.sh's rc==6 handler deliberately does NOT apply
# either filter: it gates a single task's own completion, with the operator present to judge a
# flake or an unrelated red gate by hand, so no confirmation re-run or attribution narrowing is
# warranted there. The checkpoint gates an entire batch with no operator present, which is what
# makes an automatic confirmation/attribution pipeline necessary rather than optional. This
# asymmetry is intentional -- see the "Scope of the new lib functions" note in the originating
# plan and the matching comment at each call site.
#
# Load-sensitivity motivation (why deploy_baseline_confirm_new_findings exists at all): the
# checkpoint that consumes these functions runs a full deploy plus the entire shell test suite
# immediately before taking its post-redeploy findings snapshot. That is itself enough ambient
# load to flake a load-sensitive test in that same suite (observed: test-lake-build-guard.sh,
# known load-sensitive per its own "pressured fixture" and the isolation commit in its history).
# A gate that just self-inflicted memory pressure cannot trust a single post-load snapshot to
# tell flaky from real; re-running once on a now-idle machine can.
#
# None of the four functions ever exits non-zero or raises on a normal (findings-bearing or
# empty) run; all `sort -u` their findings-text inputs/outputs so caller-side ordering never
# matters for any comparison.

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

# ─── deploy_baseline_confirm_new_findings <candidate_new> <confirm_snapshot> ───────────────────
deploy_baseline_confirm_new_findings() {
  local candidate_new="$1"
  local confirm_snapshot="$2"
  # `comm -12`: lines common to both -- the candidate findings that reproduced on the
  # confirmation snapshot. A candidate absent from confirm_snapshot (flaky) is silently excluded
  # from the intersection; comm's own "not blank" behavior on an all-empty candidate_new input
  # (a caller error, since this is only ever called with a non-empty candidate) is not specially
  # guarded here -- see the header note that callers gate this call on non-empty candidate_new.
  comm -12 \
    <(printf '%s\n' "$candidate_new" | sort -u) \
    <(printf '%s\n' "$confirm_snapshot" | sort -u)
}

# ─── Governing-source map ───────────────────────────────────────────────────────────────────────
# Index i's glob and its governing-source list describe the SAME rule. The glob is matched (as a
# bash `case` pattern) against each punctuation-stripped identifier token in a finding line; the
# governing-source list is space-separated BASENAMES compared against the batch's modified files.
# A match on both halves makes the finding attributable. See the "SECOND ATTRIBUTION SIGNAL"
# paragraph in this file's header for why basename equality alone is insufficient.
declare -a DEPLOY_BASELINE_GOVERNED_GLOBS=(
  '*/000_probe/*'
  '*.lock'
  '*.gitignore'
)
declare -a DEPLOY_BASELINE_GOVERNING_SOURCES=(
  'runtime-file-patterns.sh init-specs.sh orchestrator-runtime-files.md check-runtime-file-tracking.sh'
  'runtime-file-patterns.sh init-specs.sh orchestrator-runtime-files.md check-runtime-file-tracking.sh'
  'runtime-file-patterns.sh init-specs.sh orchestrator-runtime-files.md check-runtime-file-tracking.sh'
)

# ─── deploy_baseline_unattributable_findings <findings> <modified_files_json> ──────────────────
deploy_baseline_unattributable_findings() {
  local findings="$1"
  local modified_files_json="$2"
  local mod_basenames
  # `2>/dev/null || true`: a malformed/empty modified_files_json must never abort the caller --
  # it degrades to "no modified files", under which every identifier-bearing finding is reported
  # unattributable (the fail-safe-toward-blocking direction still holds: an identifier-free
  # finding is STILL never reported, regardless of modified_files_json's shape).
  mod_basenames="$(printf '%s' "$modified_files_json" | jq -r '(. // [])[]?' 2>/dev/null | xargs -r -n1 basename 2>/dev/null)" || true

  local line word token has_ident matched_local gi gsrc
  printf '%s\n' "$findings" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    has_ident=0
    matched_local=0
    for word in $line; do
      # Strip common surrounding punctuation (parens, brackets, colons, commas, trailing
      # periods) so a token embedded in prose (e.g. "(test-lake-build-guard.sh)," or
      # "gate8:") still matches its bare path/basename form.
      token="$(printf '%s' "$word" | sed -e 's/^[][(),:;]*//' -e 's/[][(),:;]*$//' -e 's/\.$//')"
      case "$token" in
        */*|*.sh|*.md|*.lua|*.json)
          has_ident=1
          if [ -n "$mod_basenames" ] && printf '%s\n' "$mod_basenames" | grep -qxF "$(basename "$token")"; then
            matched_local=1
          fi
          # Second signal: a derived/probe path the batch cannot match by basename, but whose
          # governing source the batch DID modify, is attributable. See the header's "SECOND
          # ATTRIBUTION SIGNAL" paragraph.
          if [ "$matched_local" -eq 0 ] && [ -n "$mod_basenames" ]; then
            for gi in "${!DEPLOY_BASELINE_GOVERNED_GLOBS[@]}"; do
              # shellcheck disable=SC2254
              case "$token" in
                ${DEPLOY_BASELINE_GOVERNED_GLOBS[$gi]})
                  for gsrc in ${DEPLOY_BASELINE_GOVERNING_SOURCES[$gi]}; do
                    if printf '%s\n' "$mod_basenames" | grep -qxF "$gsrc"; then
                      matched_local=1
                      break
                    fi
                  done
                  ;;
              esac
              [ "$matched_local" -eq 1 ] && break
            done
          fi
          ;;
      esac
    done
    if [ "$has_ident" -eq 1 ] && [ "$matched_local" -eq 0 ]; then
      printf '%s\n' "$line"
    fi
  done
}
