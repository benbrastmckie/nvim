#!/usr/bin/env bash
# approve-guard.sh - The four independent /approve refusal predicates.
#
# Each subcommand below is its own named, non-zero-exiting check; no predicate is satisfiable
# by another's value. skill-approve runs all four before ever calling the component's own
# `--record`, and a non-zero exit from `--record` itself is propagated verbatim afterward and
# never retried through a different channel -- that re-check is the generating script's own
# backstop, not something this guard re-implements or reinterprets.
#
# Subcommands:
#   --check-freshness --classification FILE
#       Stale-review refusal. Compares the component_head approve-classify.sh captured in the
#       classification sidecar (itself captured verbatim from the review header, never a
#       recomputed Lean digest) against the CURRENT git HEAD of the repository this command
#       runs in. A moved HEAD means commits landed since the review was generated, so the
#       review may be stale -- cheap and coarse by design; approve.sh --record's own per-item
#       digest re-check is the fine-grained backstop this guard does not reimplement.
#   --check-surfaced --classification FILE --presented FILE
#       Unsurfaced-declaration-level-change refusal. Refuses when any classification item whose
#       class is declaration-level, or whose decl_added/decl_removed/decl_restated is non-empty,
#       is absent from the presented sidecar's own named discrepancies list.
#   --check-human --answer-file FILE
#       No-human-attached refusal. Refuses unless FILE carries both a non-empty `Question:` line
#       and a non-empty `Answer:` line. Satisfiable only by a real answer -- never by a flag, an
#       environment variable, or an assumption.
#   --check-labels --approver STRING --assisted-by STRING
#       Refuses when the approver string ends "(agent) <...>" (the owner must never be recorded
#       as the agent), or when the assisted-by string does NOT end "(agent) <...>" (the agent
#       must always be labeled as such) -- two independent predicates, matching the external
#       checker's own precedent (components/*/scripts/check-approvals.sh's check_by /
#       check_assisted_by) of independent predicates for independent facts.
#
# Exit codes: 0 pass, 1 refusal (named message on stderr), 2 usage/environment error.

set -uo pipefail

err() {
  echo "approve-guard.sh: $*" >&2
}

usage() {
  err "usage: approve-guard.sh --check-freshness --classification FILE"
  err "       approve-guard.sh --check-surfaced --classification FILE --presented FILE"
  err "       approve-guard.sh --check-human --answer-file FILE"
  err "       approve-guard.sh --check-labels --approver STRING --assisted-by STRING"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

mode="$1"
shift

if ! command -v jq >/dev/null 2>&1; then
  err "refused: jq is required and was not found on PATH."
  exit 2
fi

check_freshness() {
  local classification=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --classification) classification="${2:-}"; shift 2 ;;
      *) err "unrecognized argument: $1"; usage; return 2 ;;
    esac
  done
  if [[ -z "$classification" || ! -f "$classification" ]]; then
    err "refused: --classification FILE is required and must exist."
    return 2
  fi
  local recorded_head current_head
  recorded_head="$(jq -r '.component_head // "unknown"' "$classification")"
  current_head="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  if [[ "$recorded_head" == "unknown" || "$current_head" == "unknown" ]]; then
    err "refused (stale review): could not resolve component_head or the current git HEAD" \
        "to compare."
    return 1
  fi
  if [[ "$recorded_head" != "$current_head" ]]; then
    err "refused (stale review): the review was generated at tree '$recorded_head' but the" \
        "current tree is '$current_head' -- review again."
    return 1
  fi
  return 0
}

check_surfaced() {
  local classification="" presented=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --classification) classification="${2:-}"; shift 2 ;;
      --presented) presented="${2:-}"; shift 2 ;;
      *) err "unrecognized argument: $1"; usage; return 2 ;;
    esac
  done
  if [[ -z "$classification" || ! -f "$classification" ]]; then
    err "refused: --classification FILE is required and must exist."
    return 2
  fi
  if [[ -z "$presented" || ! -f "$presented" ]]; then
    err "refused: --presented FILE is required and must exist."
    return 2
  fi

  local needing_surface missing=0 id
  needing_surface="$(jq -r '
    .items[]
    | select(.class == "declaration-level"
             or (.decl_added | length) > 0
             or (.decl_removed | length) > 0
             or (.decl_restated | length) > 0)
    | .id
  ' "$classification")"

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if ! jq -e --arg id "$id" '.discrepancies // [] | index($id) != null' "$presented" >/dev/null; then
      err "refused (unsurfaced declaration-level change): item '$id' is declaration-level or" \
          "has a non-empty declaration delta, but is absent from the presented summary's" \
          "discrepancies list."
      missing=1
    fi
  done <<< "$needing_surface"

  [[ "$missing" -eq 0 ]]
}

check_human() {
  local answer_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --answer-file) answer_file="${2:-}"; shift 2 ;;
      *) err "unrecognized argument: $1"; usage; return 2 ;;
    esac
  done
  if [[ -z "$answer_file" || ! -f "$answer_file" ]]; then
    err "refused (no human attached): --answer-file is missing or does not exist -- an" \
        "autonomous dispatch must never answer this prompt on the owner's behalf."
    return 1
  fi
  local question answer
  question="$(grep -m1 '^Question:' "$answer_file" | sed 's/^Question:[[:space:]]*//')"
  answer="$(grep -m1 '^Answer:' "$answer_file" | sed 's/^Answer:[[:space:]]*//')"
  if [[ -z "$question" ]]; then
    err "refused (no human attached): '$answer_file' has no non-empty 'Question:' line."
    return 1
  fi
  if [[ -z "$answer" ]]; then
    err "refused (no human attached): '$answer_file' has no non-empty 'Answer:' line."
    return 1
  fi
  return 0
}

is_agent_labeled() {
  # True when the string ends "(agent) <...>" -- mirrors
  # components/*/scripts/check-approvals.sh's assisted_by_matches/check_by suffix convention.
  [[ "$1" =~ \(agent\)[[:space:]]*\<[^\>]*\>[[:space:]]*$ ]]
}

check_labels() {
  local approver="" assisted_by=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --approver) approver="${2:-}"; shift 2 ;;
      --assisted-by) assisted_by="${2:-}"; shift 2 ;;
      *) err "unrecognized argument: $1"; usage; return 2 ;;
    esac
  done
  if [[ -z "$approver" || -z "$assisted_by" ]]; then
    err "refused: both --approver STRING and --assisted-by STRING are required."
    return 2
  fi
  local bad=0
  if is_agent_labeled "$approver"; then
    err "refused (label pairing): approver '$approver' is labeled '(agent)' -- the owner must" \
        "never be recorded as the agent."
    bad=1
  fi
  if ! is_agent_labeled "$assisted_by"; then
    err "refused (label pairing): assisted-by '$assisted_by' is not labeled '(agent)' -- the" \
        "agent must always be labeled as such."
    bad=1
  fi
  [[ "$bad" -eq 0 ]]
}

case "$mode" in
  --check-freshness) check_freshness "$@"; exit $? ;;
  --check-surfaced) check_surfaced "$@"; exit $? ;;
  --check-human) check_human "$@"; exit $? ;;
  --check-labels) check_labels "$@"; exit $? ;;
  *)
    err "unrecognized subcommand: $mode"
    usage
    exit 2
    ;;
esac
