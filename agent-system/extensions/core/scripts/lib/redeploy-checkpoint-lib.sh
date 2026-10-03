#!/usr/bin/env bash
# redeploy-checkpoint-lib.sh - The post-deploy reconcile pass, extracted verbatim from
# orchestrate-cycle-plan.sh's orchestrate_cycle_plan_main() (Phase 6 of the script-corpus
# decomposition task).
#
# DECLARED FALLBACK TAKEN, NOT THE WHOLE REGION: this task's plan named the inter-cycle redeploy
# checkpoint's full ~479-line region (budget-guard comment through the post-deploy reconcile
# pass) as the primary Phase 6 target, with a declared fallback -- extracting only the leaf
# "Post-deploy reconcile pass" sub-region (~107 lines) alone -- "if the enumerated closed-over-
# local set makes the whole region unsafe to move in one run". That is exactly what happened
# here, for a reason specific to THIS region and not present in Phases 4/5's extractions:
#
# scripts/tests/test-lint-deploy-caller-wrap.sh enforces, by name, that deploy-headless.sh has
# EXACTLY TWO genuine automated callers in the whole corpus -- orchestrate-cycle-plan.sh and
# command-gate-out.sh -- and that EACH of those two files wraps ALL of its own logic in one
# function invoked as that file's own last physical statement (the "SELF-OVERWRITE HAZARD"
# pattern: deploy-headless.sh can regenerate the very file calling it, so bash must have already
# read/parsed the ENTIRE remaining script, including the invocation line, before that call
# executes -- see orchestrate-cycle-plan.sh's own header for the full mechanism). A first attempt
# at this phase moved the ENTIRE 479-line region -- including the "(k, part 2) Inter-cycle
# redeploy checkpoint" sub-region's own `bash "$SCRIPT_DIR/deploy-headless.sh" --skip-verify` call
# -- into this lib, sourced early and called from inside orchestrate_cycle_plan_main(). That
# passed every other gate (byte-identical --dry-run diff, test-orchestrate-cycle-plan.sh,
# run-all.sh) but correctly failed test-lint-deploy-caller-wrap.sh: the genuine-caller census now
# found THREE files (this lib included), and this lib -- a `source`d library, not a
# directly-executed script -- has no "last physical statement" of its own to wrap around in the
# same shape the lint checks for.
#
# Per this repo's own rule (never weaken a test to make a refactor pass -- the SCOPE DISCIPLINE
# section of this task's own plan says so explicitly), that first attempt was reverted rather than
# patching the lint's hardcoded two-file expectation to special-case a third shape. The
# `deploy-headless.sh` call itself -- the ONLY line in the whole 479-line region actually subject
# to this hazard -- was left INLINE in orchestrate-cycle-plan.sh, still protected by that file's
# existing wrap. Only the leaf "Post-deploy reconcile pass" sub-region below was moved: it calls
# `reconcile-task-status.sh` and `git-commit-scoped.sh`, NEITHER of which the lint's own
# classification pass recognizes as a deploy-headless.sh caller (confirmed: grepping this lib for
# "deploy-headless" matches nothing) -- so moving it introduces no analogous hazard and no lint
# regression.
#
# EXTRACTION METHOD for what WAS moved: identical to scripts/lib/territory-contention-lib.sh
# (Phase 4) and scripts/lib/task-classification-lib.sh (Phase 5) -- verbatim relocation, relying
# on bash's dynamic (call-stack) `local` scoping, confirmed safe by direct grep: this leaf, like
# the region it was cut from, contains ZERO `local`/`declare` statements, ZERO nested function
# definitions, and ZERO bare `return` statements. `post_deploy_reconcile_json` (read here, set by
# the inline checkpoint code immediately before this function is called) and `dry_run`,
# `cycle_count`, `session_id`, `SCRIPT_DIR`, `STATE_FILE` (all plain top-level script globals) are
# therefore reachable exactly as before, just via a function call instead of inline execution.
#
# `source` this file from orchestrate-cycle-plan.sh alongside the other early lib sources.

run_post_deploy_reconcile_pass() {
# ── Post-deploy reconcile pass ───────────────────────────────────────────────────────────────
# Makes the checkpoint's own "convergence is deferred to the next cycle" promise real: promote
# every task THIS cycle's checkpoint just deploy-unblocked (post_deploy_reconcile_json, set
# above inside exactly the three clean-success branches -- never on branch (a) deploy failure or
# branch (b) blocking findings) by replaying reconcile-task-status.sh -- the same tool an
# operator otherwise has to run by hand -- BEFORE this cycle's own (a) Status refresh loop and
# dispatch derivation run. Landing this here means current_statuses[$t] already reflects the
# promotion and is_terminal_status() naturally excludes the task from Move 2's dispatch batch --
# no new triage-layer skip logic is needed, and no second, byte-identical `implement` dispatch is
# ever derived for a task whose work was already done and committed.
#
# Placement: strictly inside this already-serialized checkpoint window, after the deploy's
# success is confirmed above and before Move 2 (elsewhere in this script) issues any dispatch --
# the one point in the whole cycle with no dispatch in flight (see this block's own CONCURRENCY
# POSTURE comment). This inherits the existing serialization rather than introducing a new lock.
#
# `dry_run == true` skips the loop entirely, matching this checkpoint's own non-mutating posture
# under --dry-run. A non-zero reconcile-task-status.sh exit (e.g. the postflight completion-
# deploy gate itself refusing again, or the phase-accounting backstop) is NON-FATAL here: warn,
# record, and move on to the next task -- a failed self-heal attempt must never take down the
# rest of the batch loop.
#
# Ledger-and-commit obligation (every `promoted` outcome below MUST do both):
#   (a) Append the task number to `.completed_tasks`. skill-orchestrate/SKILL.md's Move 4 derives
#       BOTH the `### Succeeded` table AND the `.dispatch/` cleanup set from this one array -- a
#       promotion that skips the append completes correctly in `specs/state.json` but is
#       invisible to the batch's own reporting and cleanup.
#   (b) Commit its own `specs/state.json` + `specs/TODO.md` transition via
#       `git-commit-scoped.sh`. This loop runs strictly before Move 2 issues this cycle's own
#       dispatch batch, and the all-terminal check further down can `emit_and_exit` this SAME
#       invocation with no intervening dispatch -- so there is no guaranteed later postflight to
#       commit this transition. Skipping the commit here risks the durable git record
#       contradicting `specs/state.json` (the record reads "orchestration paused" from a prior
#       cycle while the state says `completed`).
#   A future promotion branch added to this loop (a new `_pdr_outcome` value, or a second
#   `-> completed` pattern) MUST perform both (a) and (b), not just the state mutation.
#
# This commit's own concurrency safety rides the SAME "no dispatch in flight" placement
# invariant the CONCURRENCY POSTURE comment above (this file's redeploy-checkpoint trigger
# predicate) already establishes for this whole checkpoint window -- a future mover of this loop
# out of that window must preserve the invariant or re-derive an equivalent one before this
# commit call can stay safe.
if [ "$dry_run" != "true" ] && [ "$post_deploy_reconcile_json" != "[]" ]; then
  for _pdr_t in $(echo "$post_deploy_reconcile_json" | jq -r '.[]' 2>/dev/null || true); do
    [ -n "$_pdr_t" ] || continue
    _pdr_rc=0
    _pdr_out="$(bash "$SCRIPT_DIR/reconcile-task-status.sh" "$_pdr_t" "$session_id" 2>&1)" || _pdr_rc=$?
    if [ "$_pdr_rc" -ne 0 ]; then
      _pdr_outcome="refused"
    elif printf '%s' "$_pdr_out" | grep -q "promoted .* -> completed"; then
      _pdr_outcome="promoted"
    else
      _pdr_outcome="no-op"
    fi
    echo "[orchestrate] REDEPLOY CHECKPOINT: post-deploy reconcile for task #${_pdr_t} — ${_pdr_outcome}" >&2
    mt_set --argjson entry "$(jq -n -c --argjson c "$cycle_count" --argjson t "$_pdr_t" --arg o "$_pdr_outcome" --argjson rc "$_pdr_rc" '{cycle:$c, task:$t, outcome:$o, exit_code:$rc}')" \
      '.post_deploy_reconcile_notices += [$entry]'
    if [ "$_pdr_outcome" = "promoted" ]; then
      # Batch-ledger reflection: a promotion via this self-heal path must land in
      # `.completed_tasks` exactly as an ordinary postflight-driven completion does
      # (orchestrate-cycle-postflight.sh's own identical `.completed_tasks = ((.completed_tasks
      # // []) + [$t] | unique)` idiom) -- this is the array skill-orchestrate/SKILL.md's Move 4
      # derives BOTH its `### Succeeded` table and its `.dispatch/` cleanup set from. Without
      # this, a reconcile-promoted task completes correctly in specs/state.json but is invisible
      # to the batch's own reporting. Gated on `_pdr_outcome = "promoted"` only -- never fires
      # for `refused`/`no-op`, nor for the `-> researched`/`-> planned` promotions the `grep -q
      # "promoted .* -> completed"` check above already excludes.
      mt_set --argjson t "$_pdr_t" '.completed_tasks = ((.completed_tasks // []) + [$t] | unique)'
      # This promotion's own scoped commit -- obligation (b) from this block's header comment
      # above. Safe here only because of this loop's "no dispatch in flight" placement, the same
      # invariant the CONCURRENCY POSTURE comment (above, this file's redeploy-checkpoint trigger
      # predicate) establishes for the whole checkpoint window. This is the LAST point this cycle
      # can commit the transition: the all-terminal check further down can emit_and_exit this
      # SAME invocation with no intervening dispatch and therefore no intervening postflight to
      # commit it for us. Without this, `specs/state.json` reads `completed` while the durable
      # git record still says "orchestration paused" from whichever cycle's postflight ran last
      # -- a committed record that CONTRADICTS the state it is supposed to reflect.
      #
      # Explicit two-entry pathspec only (never a directory/glob pathspec, per
      # context/standards/git-staging-scope.md): reconcile-task-status.sh's own link_artifact
      # writes ONLY $STATE_FILE and regenerates TODO.md via generate-todo.sh -- the task
      # directory's own deliverable was already committed by the earlier "orchestration paused"
      # commit, so it has nothing left to stage here.
      #
      # No per-call-site `>&2`: git-commit-scoped.sh prints its own commit summary to stdout,
      # but the entry-point `exec 3>&1 1>&2` redirect (near the top of this script) already
      # routes fd 1 to the diagnostic stream structurally, same as every other call site in this
      # file. A non-zero exit is NON-BLOCKING, matching this block's own existing REDEPLOY
      # CHECKPOINT WARNING idiom and every other commit-failure path in this codebase: the
      # `completed` status is already on disk (reconcile-task-status.sh's write above already
      # landed it), simply left uncommitted for a later cycle's own commit to pick up.
      bash "$SCRIPT_DIR/git-commit-scoped.sh" \
        --message "task ${_pdr_t}: complete implementation (post-deploy reconcile)" \
        --session "$session_id" \
        --task "$_pdr_t" \
        -- "$STATE_FILE" "$(dirname "$STATE_FILE")/TODO.md" \
        || echo "[orchestrate] REDEPLOY CHECKPOINT WARNING: commit failed for task #${_pdr_t}'s post-deploy reconcile promotion (non-blocking) -- the 'completed' status is on disk but left uncommitted for a later commit to pick up." >&2
    fi
  done
  mt_save
fi

# Reset for the cycle now starting — the future postflight composer accumulates fresh entries
# during THIS cycle's own dispatch, to be consulted by the NEXT invocation of this script.
mt_set '.cycle_modified_files = []'
mt_save
}
