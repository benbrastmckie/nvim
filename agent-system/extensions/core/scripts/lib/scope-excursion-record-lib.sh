# scope-excursion-record-lib.sh - Single home of the batched "scope excursion" issue-record
# call shape: one non-fatal issue-record.sh call per DROP EVENT, carrying every dropped path
# through the --tags-json seam, rather than one call per dropped path. Modelled structurally on
# scripts/lib/engine-written-state-paths-lib.sh and scripts/lib/derived-artifact-probe-lib.sh:
# sourced, never executed; sets no shell options a caller inherits; never calls `exit`; always
# returns 0, including on every tolerated failure below; internal names prefixed and unset
# before return.
#
# Consequence this library exists to fix: a phase that legitimately touches many out-of-scope
# paths in one drop event previously wrote one near-identical "scope excursion" row per path,
# drowning the class's aggregate signal. This library gives both Containment emitters one call
# site that writes exactly one row per drop event, with the full dropped-path set recoverable
# from that row's `tags.dropped_paths` -- never a bounded sample, per issue-log.md's
# no-suppression posture.
#
# `--kind issue`, `--class "scope excursion"`, and `--severity minor` are hardcoded inside the
# function below: the class literal has exactly one non-test home in the scripts tree, which is
# what makes a repo-wide single-emitter guard a one-line assertion rather than a parser. This
# library changes how a drop is RECORDED; it never changes whether a drop happens, what gets
# dropped, or the drop-and-warn posture.
#
# One exported function:
#
#   scope_excursion_record_emit <script_dir> <task_number> <what_happened> <first_seen> \
#     <last_seen> [<extra_arg> ...] -- <dropped_path> [<dropped_path> ...]
#
#     <script_dir>      Directory holding issue-record.sh, resolved by the CALLER from its own
#                        SCRIPT_DIR (the same resolution both callers already use for every
#                        other sibling script/library).
#     <task_number>      Passed through verbatim as issue-record.sh's `--task`.
#     <what_happened>    Caller-built free-prose sentence; this library appends nothing to it
#                         except, in the jq-absent fallback below, the inline path listing.
#     <first_seen>        ISO 8601 UTC timestamp of the first drop in this event.
#     <last_seen>         ISO 8601 UTC timestamp of the last drop in this event.
#     <extra_arg> ...     Zero or more additional issue-record.sh arguments the two call sites
#                         differ on (e.g. `--phase implement`), passed through verbatim before
#                         the literal `--` separator. Empty at a call site that has none.
#     `--`                 Mandatory separator between <extra_arg>... and the dropped-path list,
#                         since both are variable-length.
#     <dropped_path> ...  Every path dropped by this one drop event, in drop order. Must be
#                         non-empty -- the caller guards on a non-empty accumulator before
#                         calling, mirroring both emitters' own existing non-empty guards.
#
#   Builds `{"dropped_paths": [...], "occurrence": {"count": N, "first_seen": ..., "last_seen":
#   ...}}` via jq and passes it through issue-record.sh's existing `--tags-json` flag, which
#   already validates `tags` only as `type == "object"` -- no change to issue-record.sh itself.
#   When jq is unavailable (the scratch repos in both suites have none), falls back to a single
#   call with no `--tags-json`, every dropped path listed inline in <what_happened> instead --
#   fewer rows, never fewer paths; the no-suppression posture is never violated by this
#   fallback.
#
#   Tolerates issue-record.sh being absent (returns 0 immediately, a silent no-op -- the
#   scratch repos in both suites have no such script) and tolerates a non-zero result from
#   issue-record.sh itself (a recording failure can never fail a commit). Always returns 0.
#
# Consumers (each MUST source this file and call scope_excursion_record_emit, never re-hand-copy
# the call-construction logic a second time):
#   - scripts/git-commit-phase.sh (the Phase-Commit Containment Self-Check's post-loop emission)
#   - scripts/git-commit-scoped.sh (V10's post-loop emission)

# scope_excursion_record_emit <script_dir> <task_number> <what_happened> <first_seen> \
#   <last_seen> [<extra_arg> ...] -- <dropped_path> [<dropped_path> ...]
# Always returns 0.
scope_excursion_record_emit() {
  local _ser_script_dir="$1"
  local _ser_task_number="$2"
  local _ser_what_happened="$3"
  local _ser_first_seen="$4"
  local _ser_last_seen="$5"
  shift 5

  local _ser_extra_args=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    _ser_extra_args+=("$1")
    shift
  done
  # Consume the mandatory "--" separator, if present (tolerate a caller that omitted it with no
  # extra args and nothing left to shift past).
  if [ "$#" -gt 0 ] && [ "$1" = "--" ]; then
    shift
  fi
  local _ser_dropped_paths=("$@")

  if [ "${#_ser_dropped_paths[@]}" -eq 0 ]; then
    unset _ser_script_dir _ser_task_number _ser_what_happened _ser_first_seen _ser_last_seen \
      _ser_extra_args _ser_dropped_paths
    return 0
  fi

  if [ ! -f "${_ser_script_dir}/issue-record.sh" ]; then
    # Silent no-op: both suites' scratch repos have no issue-record.sh at all. Matches both
    # emitters' pre-existing tolerance exactly (their `bash ".../issue-record.sh" ... || true`
    # forms already tolerate an absent target the same way).
    unset _ser_script_dir _ser_task_number _ser_what_happened _ser_first_seen _ser_last_seen \
      _ser_extra_args _ser_dropped_paths
    return 0
  fi

  local _ser_tags_json=""
  if command -v jq >/dev/null 2>&1; then
    _ser_tags_json="$(jq -n \
      --arg first_seen "$_ser_first_seen" \
      --arg last_seen "$_ser_last_seen" \
      --argjson count "${#_ser_dropped_paths[@]}" \
      --args '{dropped_paths: $ARGS.positional, occurrence: {count: $count, first_seen: $first_seen, last_seen: $last_seen}}' \
      "${_ser_dropped_paths[@]}" 2>/dev/null)"
  fi

  # Single call site, single class literal: whichever branch below ran, exactly one
  # `--class "scope excursion"` token exists in this file -- the repo-wide single-emitter guard
  # (test-scope-excursion-record-lib.sh's own repo-wide case) is a one-line assertion against
  # this file specifically because the literal is never duplicated across branches here.
  local _ser_tags_args=()
  if [ -n "$_ser_tags_json" ]; then
    _ser_tags_args=(--tags-json "$_ser_tags_json")
  else
    # jq-absent (or jq-failed) fallback: no --tags-json, every dropped path listed inline in
    # what_happened instead -- fewer rows, never fewer paths. The no-suppression posture is
    # preserved by inlining the full list, never a bounded sample.
    _ser_what_happened="${_ser_what_happened} Dropped paths: ${_ser_dropped_paths[*]}"
  fi
  bash "${_ser_script_dir}/issue-record.sh" --task "$_ser_task_number" --kind issue \
    --class "scope excursion" --severity minor \
    --what-happened "$_ser_what_happened" \
    "${_ser_tags_args[@]}" \
    "${_ser_extra_args[@]}" \
    >/dev/null 2>&1 || true

  unset _ser_script_dir _ser_task_number _ser_what_happened _ser_first_seen _ser_last_seen \
    _ser_extra_args _ser_dropped_paths _ser_tags_json _ser_tags_args
  return 0
}
