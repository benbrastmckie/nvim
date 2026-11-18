#!/usr/bin/env bash
# unmapped-fallback-lib.sh - Replaces "unmapped means run everything now" with a per-path
# classified, never-silent outcome for whatever scripts/lib/suite-resolver-lib.sh's
# `suite_resolver_resolve` leaves `UNRESOLVED`:
#
#   (a) NO-SUITE-BY-CLASS -- the path's class cannot change any suite's own PASS/FAIL, but one or
#       more named LINT suites genuinely read it as part of their own corpus-wide or
#       registry-driven scan (scripts/tests/suite-selection-noclass.data).
#   (b) already resolved by an explicit map row -- handled upstream by suite-resolver-lib.sh;
#       this library never sees a path that reached (b), so it has no case for it here.
#   (c) OWED, NOT PAID -- a path matching neither (a) nor (b): runs a small DECLARED cheap
#       fallback set NOW (selected through `run-all.sh --cost-class free`, never a hand-written
#       suite list -- see UNMAPPED_FALLBACK_COST_CLASS below, the only sanctioned selecting
#       invocation) and writes a durable "full sweep owed" record that only a later complete,
#       unnarrowed batch-gate run discharges. Owed is never forgiven: a row is appended, never
#       deleted, and the only mutation ever applied to an existing row is the discharge stamp
#       (scripts/orchestrate-batch-gate.sh).
#
# Sourced (never executed) -- same discipline as suite-selection-lib.sh / suite-resolver-lib.sh:
# no shell options set, no `exit` ever called, internal names prefixed `_umf_`.
#
# THE SANCTIONED FALLBACK-SET SELECTING INVOCATION (never a hand-written suite list):
#   bash <run-all.sh> --cost-class "${UNMAPPED_FALLBACK_COST_CLASS:-free}" --jobs auto --timings FILE
# `scripts/verify-touched.sh` is the caller that actually runs this; this library exposes the
# cost-class value (and nothing more) via `unmapped_fallback_cost_class` so the entry point and
# this library can never drift on which class is "the" fallback set.
#
# THE OWED RECORD (plain, inspectable JSONL; append-only except for the discharge stamp):
#   <task_dir>/records/full-sweep-owed.jsonl, one JSON object per line:
#     {"path": "...", "reason": "...", "session_id": "...", "dispatch_seq": N,
#      "recorded_ts": "<ISO8601>", "discharged_ts": null}
# `scripts/orchestrate-batch-gate.sh` stamps `discharged_ts` on every OPEN row (discharged_ts ==
# null) for a task after that invocation's complete, unnarrowed `verify-deploy.sh` run succeeds.
# A batch-gate run that did not happen, or failed, discharges nothing -- rows stay open and are
# reported as such by any later reader.
#
# Consumers:
#   - scripts/verify-touched.sh (the entry point; the sole writer of owed rows via this library)
#   - scripts/orchestrate-batch-gate.sh (the sole discharger of owed rows; reads/stamps the file
#     directly rather than through this library, since discharge is a batch-level, cross-task
#     concern this per-task library does not own)

UNMAPPED_FALLBACK_COST_CLASS="${UNMAPPED_FALLBACK_COST_CLASS:-free}"

_UMF_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_UMF_DEFAULT_NOCLASS_DATA="${_UMF_SELF_DIR}/../tests/suite-selection-noclass.data"

# unmapped_fallback_cost_class -- stdout: the declared --cost-class value the OWED fallback set
# is selected through. A thin accessor so no caller hand-codes the env-var-with-default idiom
# more than once.
unmapped_fallback_cost_class() {
  printf '%s\n' "${UNMAPPED_FALLBACK_COST_CLASS}"
  return 0
}

# _umf_noclass_lookup <noclass_file> <path> -- stdout: comma-separated lint basenames from the
# FIRST matching row of <noclass_file>, or nothing when no row matches or the file is absent.
# Internal; not part of the public API.
_umf_noclass_lookup() {
  local _umf_file="$1"
  local _umf_path="$2"
  local _umf_glob _umf_lints _umf_reason

  [ -f "${_umf_file}" ] || return 0

  while IFS=$'\t' read -r _umf_glob _umf_lints _umf_reason; do
    case "${_umf_glob}" in
      ""|"#"*) continue ;;
    esac
    # shellcheck disable=SC2053
    if [[ "${_umf_path}" == ${_umf_glob} ]]; then
      printf '%s\n' "${_umf_lints}"
      unset _umf_file _umf_path _umf_glob _umf_lints _umf_reason
      return 0
    fi
  done < "${_umf_file}"

  unset _umf_file _umf_path _umf_glob _umf_lints _umf_reason
  return 0
}

# unmapped_fallback_record_owed <task_dir> <path> <reason> <session_id> <dispatch_seq>
# Idempotent append to <task_dir>/records/full-sweep-owed.jsonl: a re-run that re-classifies the
# SAME path while an OPEN (discharged_ts == null) row for it already exists is a no-op -- never a
# duplicate, never a delete. Creates the records/ directory and the file if either is absent.
# Fails open (prints a warning, returns 0) if `jq` is unavailable, rather than blocking
# classification over a logging mechanism.
unmapped_fallback_record_owed() {
  local _umfr_task_dir="${1:?unmapped_fallback_record_owed: task_dir required}"
  local _umfr_path="${2:?unmapped_fallback_record_owed: path required}"
  local _umfr_reason="${3:-owed: no map row, no class row}"
  local _umfr_session_id="${4:-}"
  local _umfr_dispatch_seq="${5:-}"
  local _umfr_records_dir="${_umfr_task_dir}/records"
  local _umfr_records_file="${_umfr_records_dir}/full-sweep-owed.jsonl"

  if ! command -v jq >/dev/null 2>&1; then
    echo "unmapped_fallback_record_owed: WARNING -- jq not found; owed record for '${_umfr_path}' NOT written (classification itself is unaffected)." >&2
    return 0
  fi

  mkdir -p "${_umfr_records_dir}" 2>/dev/null

  if [ -f "${_umfr_records_file}" ]; then
    local _umfr_open_count
    _umfr_open_count="$(jq -s --arg p "${_umfr_path}" \
      '[.[] | select(.discharged_ts == null and .path == $p)] | length' \
      "${_umfr_records_file}" 2>/dev/null)"
    case "${_umfr_open_count}" in ''|*[!0-9]*) _umfr_open_count=0 ;; esac
    if [ "${_umfr_open_count}" -gt 0 ]; then
      # An OPEN row for this exact path already exists -- never duplicate, never delete.
      return 0
    fi
  fi

  local _umfr_ts
  _umfr_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local _umfr_row
  _umfr_row="$(jq -n -c \
    --arg path "${_umfr_path}" \
    --arg reason "${_umfr_reason}" \
    --arg session_id "${_umfr_session_id}" \
    --arg dispatch_seq "${_umfr_dispatch_seq}" \
    --arg ts "${_umfr_ts}" \
    '{path: $path, reason: $reason, session_id: $session_id,
      dispatch_seq: ($dispatch_seq | tonumber? // null),
      recorded_ts: $ts, discharged_ts: null}')"
  printf '%s\n' "${_umfr_row}" >> "${_umfr_records_file}"
  return 0
}

# unmapped_fallback_classify <task_dir> <session_id> <dispatch_seq> PATH [PATH...]
# For each PATH (normally the UNRESOLVED set from suite_resolver_resolve), prints exactly one
# line:
#   NO-SUITE-BY-CLASS <path>	<comma-separated lints>
#   OWED <path>	<reason>
# and, for every OWED path, appends (idempotently) an owed-record row via
# unmapped_fallback_record_owed above. Never silent: every input path produces exactly one output
# line. Always returns 0 (classification itself cannot fail; a jq-absent owed-record write
# degrades to a warning, not a block -- see unmapped_fallback_record_owed).
unmapped_fallback_classify() {
  local _umfc_task_dir="${1:?unmapped_fallback_classify: task_dir required}"
  local _umfc_session_id="${2:-}"
  local _umfc_dispatch_seq="${3:-}"
  shift 3
  if [ "$#" -eq 0 ]; then
    return 0
  fi
  local -a _umfc_paths=("$@")
  local _umfc_p _umfc_lints _umfc_noclass_file

  _umfc_noclass_file="${UNMAPPED_FALLBACK_NOCLASS_DATA:-${_UMF_DEFAULT_NOCLASS_DATA}}"

  for _umfc_p in "${_umfc_paths[@]}"; do
    _umfc_lints="$(_umf_noclass_lookup "${_umfc_noclass_file}" "${_umfc_p}")"
    if [ -n "${_umfc_lints}" ]; then
      printf 'NO-SUITE-BY-CLASS\t%s\t%s\n' "${_umfc_p}" "${_umfc_lints}"
    else
      printf 'OWED\t%s\t%s\n' "${_umfc_p}" "owed: no map row (suite-selection-map.data) and no class row (suite-selection-noclass.data); falls back to the --cost-class ${UNMAPPED_FALLBACK_COST_CLASS} set now"
      unmapped_fallback_record_owed "${_umfc_task_dir}" "${_umfc_p}" \
        "no map row and no class row; ran the --cost-class ${UNMAPPED_FALLBACK_COST_CLASS} fallback set" \
        "${_umfc_session_id}" "${_umfc_dispatch_seq}"
    fi
  done

  unset _umfc_task_dir _umfc_session_id _umfc_dispatch_seq _umfc_paths _umfc_p _umfc_lints _umfc_noclass_file
  return 0
}
