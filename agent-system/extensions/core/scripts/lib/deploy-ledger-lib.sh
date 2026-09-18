#!/usr/bin/env bash
# deploy-ledger-lib.sh - Single home of the durable, cross-invocation redeploy ledger: a
# per-path and aggregate sha256 of the orchestrator-critical source-store paths, the verify
# outcome of the last deploy that touched them, a timestamp, and the batch task numbers that
# produced it. Modelled structurally on lib/deploy-baseline-lib.sh and lib/deploy-freshness-lib.sh:
# a header stating it is the single home of the algorithm, safe to source, sets no shell options
# a caller inherits, and exports nothing a caller must guess at.
#
# WHY THIS EXISTS (see context/patterns/batch-orchestration-guardrails.md's "The Inter-Cycle
# Redeploy Checkpoint" subsection, "Durable redeploy ledger" paragraph, for the full contract):
# the checkpoint's only pre-existing dedup, `deployed_critical_paths`, lives in the
# session-suffixed `specs/.orchestrator-multi-state-{session_id}.json`, which is fresh on every
# `/orchestrate` invocation. It is a correct WITHIN-invocation re-deploy suppressor, but it has no
# memory that lasts BETWEEN invocations, so a task that lands in `[IMPLEMENTING]` across separate
# `/orchestrate` runs re-triggers a full deploy+verify every single run, even when nothing in the
# source store changed since the last successful deploy. This library gives the checkpoint that
# missing cross-invocation memory via one durable, gitignored, machine-local file
# (`deploy_ledger_path`'s default: `specs/.orchestrator-deploy-ledger.json`).
#
# TWO skip rules, not one, because they cover two DIFFERENT failure modes:
#   - `skip_hash` (the ordinary case): the source-store content is byte-identical to the content
#     a skip-eligible deploy already verified, so redeploying again would verify the same tree.
#   - `skip_attributed` (the self-modifying-task case): a task whose OWN file_scope is the
#     orchestrator source store necessarily changes the hash on every cycle, by construction —
#     a content-hash skip can never fire for it. The attributed rule instead recognizes "the
#     deploy that just landed was mine": recent, made by a batch that shares a task number with
#     this one, and every critical path that changed since then is explained by this batch's own
#     `cycle_modified_files`. Shipping only the hash skip leaves this class hitting a full
#     redeploy on every single cycle, which is the exact defect this library closes.
# Both rules require POSITIVE ledger evidence (a valid, parseable ledger with a skip-eligible
# verify outcome). A missing, malformed, or CANNOTVERIFY ledger/hash-state is fail-safe toward
# "run" -- absence of evidence can never justify a skip. A `deploy_pending` batch task always
# forces `run`, so a skip can never starve the postflight completion-deploy gate's backstop.
#
# Exports FIVE functions and FOUR env-overridable constants:
#
#   deploy_ledger_path <project_root>
#     Prints the ledger file path: `${DEPLOY_LEDGER_FILE:-<project_root>/specs/.orchestrator-deploy-ledger.json}`.
#     Never touches disk.
#
#   deploy_ledger_hash_state <project_root> <critical_paths_file>
#     Prints compact JSON `{aggregate, paths:{<path>:<sha256|MISSING>}}` computed ONLY over the
#     `agent-system/extensions/core` scope root under <project_root> (the other two
#     `orchestrator-critical-paths.json` scope roots, `.claude` and `.opencode`, are deploy
#     mirrors, never the source of truth for this hash) -- see the plan's Decision 2. Every
#     `critical_paths[].path` entry in <critical_paths_file> is hashed with `sha256sum`; a
#     missing file hashes to the literal string `MISSING` rather than being dropped, so the
#     record stays comparable across invocations. `aggregate` is the sha256 of the sorted
#     "path hash" lines. Prints NOTHING and returns 2 (CANNOTVERIFY) when the scope root is
#     missing, `sha256sum` is not on PATH, or the critical-paths file cannot be read/parsed by
#     jq. Never aborts, never raises.
#
#   deploy_ledger_read <ledger_file>
#     Prints the ledger's JSON on stdout (schema `deploy-ledger-v1`, validated to carry
#     `aggregate`, `paths`, a NUMERIC `verified_at`, `verify_outcome`, and an ARRAY
#     `task_numbers`) and returns 0. Prints nothing and returns 1 on a missing, unreadable,
#     unparseable, or schema-invalid file -- fail-safe: missing/malformed ledger reads as "no
#     evidence", never as evidence of any particular state.
#
#   deploy_ledger_decide <ledger_json> <hash_state_json> <now_epoch> <cycle_modified_files_json> <task_numbers_json> <deploy_pending_bool>
#     Prints compact JSON `{decision: "skip_hash"|"skip_attributed"|"run", reason, age_sec,
#     changed_paths, attributing_tasks}`. <ledger_json> is the (possibly empty-string, meaning
#     "no ledger") output of deploy_ledger_read; <hash_state_json> is the (possibly empty-string,
#     meaning CANNOTVERIFY) output of deploy_ledger_hash_state; <deploy_pending_bool> is the
#     literal string "true" or "false". Implements Decisions 4-5 of the plan. The `⊆` check for
#     `skip_attributed` (every changed critical path covered by this batch's own
#     `cycle_modified_files`) sources `lib/file-scope-overlap.sh`'s `FILE_SCOPE_OVERLAP_JQ_DEFS`
#     -- the CALLER must have already sourced that file (exactly as
#     `scripts/orchestrate-cycle-plan.sh` already does, ahead of this library, for its own
#     matched-path computation). A caller that has not done so gets a safe `run` verdict, never a
#     jq crash: see the guard at the top of the function body. Each changed critical path (a bare
#     path like `scripts/foo.sh`) is expanded across ALL THREE `orchestrator-critical-paths.json`
#     scope roots (resolved relative to this library's own file location, so it works identically
#     whether sourced from the real `agent-system/extensions/core` tree or a test fixture's mirror
#     of it) before the overlap check, per the plan's Decision 4.
#
#   deploy_ledger_write <ledger_file> <hash_state_json> <verify_outcome> <task_numbers_json> <session_id> <cycle>
#     Atomically writes (tmp file in the same directory, then `mv`) a `deploy-ledger-v1` record
#     built from <hash_state_json>'s `aggregate`/`paths`, the given <verify_outcome>,
#     <task_numbers_json>, <session_id>, <cycle>, and a freshly-captured `verified_at` (epoch
#     seconds). `mkdir -p`s the parent directory first. Returns nonzero on ANY failure (missing
#     parent dir that cannot be created, unwritable file, invalid JSON args) -- the caller must
#     treat this as advisory (one stderr WARNING) and never fatal, per the plan's Decision 7.
#
# Constants (all env-overridable so tests and operators can shrink the windows):
#   DEPLOY_LEDGER_RECENT_SEC   - default 1800 (30 min). The `skip_attributed` recency window.
#   DEPLOY_LEDGER_MAX_AGE_SEC  - default 86400 (24h). The `skip_hash` max-age cap.
#   DEPLOY_LEDGER_SKIP         - unset/anything-but-"0" is normal operation; "0" forces every
#                                decision to `run`, an operational kill switch requiring no code
#                                revert (see the plan's Rollback/Contingency).
#   DEPLOY_LEDGER_ELIGIBLE_OUTCOMES - the skip-eligible verify_outcome vocabulary, space-
#                                separated: "clean pre_existing filtered". `deploy_failed` and
#                                `blocking` are deliberately NOT members -- they are negative
#                                records, written so an earlier clean record can never vouch for
#                                a tree a later failed/blocking deploy has since overwritten.
#
# Neither deploy_ledger_read nor deploy_ledger_decide nor deploy_ledger_hash_state ever aborts or
# raises: every failure mode collapses to "no evidence" (empty output, or a `run` decision),
# never to a crash and never to a false skip.

DEPLOY_LEDGER_RECENT_SEC="${DEPLOY_LEDGER_RECENT_SEC:-1800}"
DEPLOY_LEDGER_MAX_AGE_SEC="${DEPLOY_LEDGER_MAX_AGE_SEC:-86400}"
DEPLOY_LEDGER_SKIP="${DEPLOY_LEDGER_SKIP:-1}"
DEPLOY_LEDGER_ELIGIBLE_OUTCOMES="${DEPLOY_LEDGER_ELIGIBLE_OUTCOMES:-clean pre_existing filtered}"

# ─── deploy_ledger_path <project_root> ──────────────────────────────────────────────────────────
deploy_ledger_path() {
  local project_root="$1"
  printf '%s\n' "${DEPLOY_LEDGER_FILE:-${project_root}/specs/.orchestrator-deploy-ledger.json}"
}

# ─── deploy_ledger_hash_state <project_root> <critical_paths_file> ─────────────────────────────
deploy_ledger_hash_state() {
  local project_root="$1"
  local critical_paths_file="$2"
  local scope_root="${project_root}/agent-system/extensions/core"

  [ -d "$scope_root" ] || return 2
  command -v sha256sum >/dev/null 2>&1 || return 2
  [ -f "$critical_paths_file" ] || return 2

  local paths_list
  paths_list="$(jq -r '.critical_paths[].path' "$critical_paths_file" 2>/dev/null)" || return 2
  [ -n "$paths_list" ] || return 2

  local lines="" path abspath h
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    abspath="${scope_root}/${path}"
    if [ -f "$abspath" ]; then
      h="$(sha256sum "$abspath" 2>/dev/null | awk '{print $1}')"
      [ -n "$h" ] || h="MISSING"
    else
      h="MISSING"
    fi
    lines="${lines}${path} ${h}"$'\n'
  done <<< "$paths_list"

  local sorted_lines aggregate
  sorted_lines="$(printf '%s' "$lines" | sort)"
  aggregate="$(printf '%s' "$sorted_lines" | sha256sum 2>/dev/null | awk '{print $1}')"
  [ -n "$aggregate" ] || return 2

  jq -n -c --arg agg "$aggregate" --arg lines "$sorted_lines" '
    ($lines | rtrimstr("\n")) as $trimmed |
    ( if ($trimmed | length) == 0 then [] else ($trimmed | split("\n")) end ) as $rowlines |
    ( [ $rowlines[] | select(length > 0) | split(" ") | select(length == 2) ] ) as $rows |
    { aggregate: $agg, paths: (reduce $rows[] as $r ({}; . + {($r[0]): $r[1]})) }
  ' 2>/dev/null || return 2
}

# ─── deploy_ledger_read <ledger_file> ───────────────────────────────────────────────────────────
deploy_ledger_read() {
  local ledger_file="$1"
  [ -f "$ledger_file" ] || return 1
  local json
  json="$(jq -c '.' "$ledger_file" 2>/dev/null)" || return 1
  [ -n "$json" ] && [ "$json" != "null" ] || return 1
  printf '%s' "$json" | jq -e '
    (.aggregate != null) and
    (.paths != null and (.paths | type) == "object") and
    (.verified_at != null and (.verified_at | type) == "number") and
    (.verify_outcome != null) and
    (.task_numbers != null and (.task_numbers | type) == "array")
  ' >/dev/null 2>&1 || return 1
  printf '%s\n' "$json"
}

# ─── deploy_ledger_decide <ledger_json> <hash_state_json> <now_epoch> <cycle_modified_files_json> <task_numbers_json> <deploy_pending_bool> ──
deploy_ledger_decide() {
  local ledger_json="$1"
  local hash_state_json="$2"
  local now_epoch="$3"
  local cycle_modified_files_json="$4"
  local task_numbers_json="$5"
  local deploy_pending_bool="$6"

  if [ "$deploy_pending_bool" = "true" ]; then
    jq -n -c '{decision:"run", reason:"deploy_pending override: at least one batch task refused completion pending a fresh deploy", age_sec:0, changed_paths:[], attributing_tasks:[]}'
    return 0
  fi
  if [ "$DEPLOY_LEDGER_SKIP" = "0" ]; then
    jq -n -c '{decision:"run", reason:"DEPLOY_LEDGER_SKIP=0 (operator kill switch)", age_sec:0, changed_paths:[], attributing_tasks:[]}'
    return 0
  fi
  if [ -z "$ledger_json" ] || [ "$ledger_json" = "null" ]; then
    jq -n -c '{decision:"run", reason:"no ledger evidence (missing, malformed, or unreadable)", age_sec:0, changed_paths:[], attributing_tasks:[]}'
    return 0
  fi

  local jqdefs="${FILE_SCOPE_OVERLAP_JQ_DEFS:-}"
  if [ -z "$jqdefs" ]; then
    jq -n -c '{decision:"run", reason:"file-scope-overlap.sh not sourced by caller; cannot evaluate attributed-skip coverage", age_sec:0, changed_paths:[], attributing_tasks:[]}'
    return 0
  fi

  local hs="$hash_state_json"
  [ -n "$hs" ] || hs="null"

  local lib_dir crit_file scope_roots_json
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  crit_file="${lib_dir}/../../context/reference/orchestrator-critical-paths.json"
  if [ -f "$crit_file" ]; then
    scope_roots_json="$(jq -c '.scope_roots // []' "$crit_file" 2>/dev/null)" || scope_roots_json='[]'
  else
    scope_roots_json='[]'
  fi

  local eligible_json
  eligible_json="$(printf '%s\n' $DEPLOY_LEDGER_ELIGIBLE_OUTCOMES | jq -R . | jq -s -c .)"

  jq -n -c \
    --argjson ledger "$ledger_json" \
    --argjson hash_state "$hs" \
    --argjson now "$now_epoch" \
    --argjson mods "${cycle_modified_files_json:-[]}" \
    --argjson tasks "${task_numbers_json:-[]}" \
    --argjson eligible "$eligible_json" \
    --argjson recent_sec "$DEPLOY_LEDGER_RECENT_SEC" \
    --argjson max_age_sec "$DEPLOY_LEDGER_MAX_AGE_SEC" \
    --argjson roots "$scope_roots_json" \
    "$jqdefs"'
    def path_covered($cpath; $roots; $mods):
      ( [ $roots[] | scopes_overlap_first([. + "/" + $cpath]; $mods) ] | length ) > 0;

    ($now - ($ledger.verified_at // 0)) as $age |
    ( ($eligible | index($ledger.verify_outcome)) != null ) as $outcome_ok |
    ( ($ledger.aggregate // "__none__") ) as $ledger_agg |
    ( (($hash_state // {}).aggregate // "__unavailable__") ) as $cur_agg |
    ( $cur_agg != "__unavailable__" and $cur_agg == $ledger_agg ) as $same_hash |
    ( ($ledger.paths // {}) ) as $lp |
    ( (($hash_state // {}).paths // {}) ) as $cp |
    ( [ ($lp | keys)[], ($cp | keys)[] ] | unique ) as $all_paths |
    ( [ $all_paths[] | select( ($lp[.] // "__missing__") != ($cp[.] // "__missing__") ) ] ) as $changed |
    ( [ ($ledger.task_numbers // [])[] as $lt | ($tasks // [])[] as $tt | select($lt == $tt) | $lt ] | unique ) as $attributing |
    ( ($attributing | length) > 0 ) as $shared_task |
    ( [ $changed[] | select(path_covered(.; $roots; $mods) | not) ] ) as $uncovered |
    ( ($uncovered | length) == 0 ) as $all_covered |
    if ($outcome_ok and $same_hash and ($age <= $max_age_sec)) then
      { decision: "skip_hash",
        reason: ("aggregate hash unchanged vs. ledger; deploy age " + ($age|tostring) + "s within max-age cap " + ($max_age_sec|tostring) + "s (outcome: " + $ledger.verify_outcome + ")"),
        age_sec: $age, changed_paths: $changed, attributing_tasks: [] }
    elif ($outcome_ok and ($age <= $recent_sec) and $shared_task and $all_covered) then
      { decision: "skip_attributed",
        reason: ("deploy age " + ($age|tostring) + "s within recency window " + ($recent_sec|tostring) + "s; attributed to shared task(s) " + ($attributing|tostring) + "; every changed critical path covered by this cycle own modified files"),
        age_sec: $age, changed_paths: $changed, attributing_tasks: $attributing }
    else
      { decision: "run",
        reason: (
          if ($outcome_ok | not) then "ledger verify_outcome not skip-eligible: " + (($ledger.verify_outcome // "null"))
          elif ($shared_task | not) and (($changed|length) > 0) then "no shared task number between ledger (" + ($ledger.task_numbers|tostring) + ") and this batch (" + ($tasks|tostring) + ")"
          elif (($changed|length) > 0) and ($all_covered | not) then "at least one changed critical path is not covered by this cycle own modified files: " + ($uncovered|tostring)
          elif ($age > $recent_sec) and ($age <= $max_age_sec) and (($changed|length) > 0) then "hash changed and deploy age " + ($age|tostring) + "s exceeds recency window " + ($recent_sec|tostring) + "s"
          else "hash changed (or ledger unavailable) and deploy age " + ($age|tostring) + "s exceeds max-age cap " + ($max_age_sec|tostring) + "s"
          end
        ),
        age_sec: $age, changed_paths: $changed, attributing_tasks: $attributing }
    end
  ' 2>/dev/null || jq -n -c '{decision:"run", reason:"deploy_ledger_decide: jq evaluation failed (CANNOTVERIFY)", age_sec:0, changed_paths:[], attributing_tasks:[]}'
}

# ─── deploy_ledger_write <ledger_file> <hash_state_json> <verify_outcome> <task_numbers_json> <session_id> <cycle> ──
deploy_ledger_write() {
  local ledger_file="$1"
  local hash_state_json="$2"
  local verify_outcome="$3"
  local task_numbers_json="$4"
  local session_id="$5"
  local cycle="$6"

  local dir
  dir="$(dirname "$ledger_file")"
  mkdir -p "$dir" 2>/dev/null || return 1

  local now payload
  now="$(date +%s)"
  payload="$(jq -n -c \
    --argjson hs "${hash_state_json:-null}" \
    --arg outcome "$verify_outcome" \
    --argjson tasks "${task_numbers_json:-[]}" \
    --arg session "$session_id" \
    --argjson cycle "${cycle:-0}" \
    --argjson now "$now" \
    '{
      schema: "deploy-ledger-v1",
      aggregate: (($hs // {}).aggregate // null),
      paths: (($hs // {}).paths // {}),
      verified_at: $now,
      verify_outcome: $outcome,
      task_numbers: ($tasks // []),
      session_id: $session,
      cycle: $cycle
    }' 2>/dev/null)" || return 1
  [ -n "$payload" ] || return 1

  local tmp="${ledger_file}.tmp.$$"
  printf '%s\n' "$payload" > "$tmp" 2>/dev/null || return 1
  mv -f "$tmp" "$ledger_file" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  return 0
}
