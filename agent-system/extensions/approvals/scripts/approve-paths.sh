#!/usr/bin/env bash
# approve-paths.sh - Resolve a /approve component and compute its keyed artifact path.
#
# Implements the ruling in
# context/project/approvals/standards/approval-artifact-convention.md: every persisted review
# lives under specs/certificates/<component>/ in the CONSUMER repository, keyed by a stem
# (task-{N} or adhoc-{DATE}) plus a two-digit, non-colliding instance number. This script is the
# single place that stem/path computation happens; skill-approve calls it rather than
# re-deriving the convention inline.
#
# Usage:
#   approve-paths.sh --component NAME [--task N | --date YYYYMMDD] --emit-paths
#       Resolve components/NAME/approve.sh, compute the keyed stem (task-{N}-{II} when --task
#       is given, adhoc-{DATE}-{II} otherwise; --date defaults to today and exists only so
#       tests can inject a fixed date), create specs/certificates/NAME/ (mkdir -p), and print
#       three paths, one per line: the review path, the .classification.json sidecar path, and
#       the .presented.json sidecar path.
#   approve-paths.sh --component NAME --instance-of STEM
#       Print the next two-digit instance number for the given raw stem (e.g. "task-{N}" or
#       "adhoc-{DATE}"), computed as one more than the count of existing
#       specs/certificates/NAME/STEM-*.md review files. Standalone, for tests.
#   approve-paths.sh --component NAME --out ANYTHING
#       Always refused: the review location is this command's own business, never the caller's.
#
# Exit codes: 0 success, 1 refusal (named message on stderr), 2 environment/usage error.

set -uo pipefail

err() {
  echo "approve-paths.sh: $*" >&2
}

usage() {
  err "usage: approve-paths.sh --component NAME [--task N | --date YYYYMMDD] --emit-paths"
  err "       approve-paths.sh --component NAME --instance-of STEM"
}

component=""
task_number=""
date_override=""
instance_of_stem=""
emit_paths=0
out_arg_seen=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --component)
      component="${2:-}"
      shift 2
      ;;
    --task)
      task_number="${2:-}"
      shift 2
      ;;
    --date)
      date_override="${2:-}"
      shift 2
      ;;
    --instance-of)
      instance_of_stem="${2:-}"
      shift 2
      ;;
    --emit-paths)
      emit_paths=1
      shift
      ;;
    --out)
      out_arg_seen=1
      shift 2 2>/dev/null || shift
      ;;
    *)
      err "unrecognized argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ "$out_arg_seen" -eq 1 ]]; then
  err "refused: --out is not accepted. The review location is this command's own business," \
      "never the caller's -- see approval-artifact-convention.md."
  exit 1
fi

if [[ -z "$component" ]]; then
  err "refused: --component NAME is required."
  usage
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$repo_root" ]]; then
  err "refused: not inside a git repository (git rev-parse --show-toplevel failed)."
  exit 2
fi

component_dir="$repo_root/components/$component"
component_script="$component_dir/approve.sh"

if [[ ! -d "$component_dir" ]]; then
  err "refused: no such component -- '$component_dir' does not exist."
  exit 1
fi

if [[ ! -f "$component_script" ]]; then
  err "refused: component '$component' has no approve.sh -- '$component_script' does not exist."
  exit 1
fi

certs_dir="$repo_root/specs/certificates/$component"

# compute_instance DIR STEM -> prints the next two-digit instance number on stdout, or
# refuses (exit 1) rather than wrapping past 99.
compute_instance() {
  local dir="$1" stem="$2"
  local count=0
  if [[ -d "$dir" ]]; then
    local f
    for f in "$dir"/"$stem"-*.md; do
      [[ -e "$f" ]] || continue
      # Only review files themselves ever match STEM-II.md; the sidecars
      # (STEM-II.classification.json / STEM-II.presented.json) never match this *.md glob.
      count=$((count + 1))
    done
  fi
  local next=$((count + 1))
  if [[ "$next" -gt 99 ]]; then
    err "refused: stem '$stem' already has 99 instances in '$dir' -- refusing to wrap."
    return 1
  fi
  printf '%02d\n' "$next"
}

if [[ -n "$instance_of_stem" ]]; then
  instance="$(compute_instance "$certs_dir" "$instance_of_stem")" || exit 1
  echo "$instance"
  exit 0
fi

if [[ "$emit_paths" -eq 1 ]]; then
  if [[ -n "$task_number" ]]; then
    stem="task-${task_number}"
  else
    date_val="${date_override:-$(date -u +%Y%m%d)}"
    stem="adhoc-${date_val}"
  fi

  instance="$(compute_instance "$certs_dir" "$stem")" || exit 1
  full_stem="${stem}-${instance}"

  mkdir -p "$certs_dir"

  review_path="$certs_dir/${full_stem}.md"
  classification_path="$certs_dir/${full_stem}.classification.json"
  presented_path="$certs_dir/${full_stem}.presented.json"

  echo "$review_path"
  echo "$classification_path"
  echo "$presented_path"
  exit 0
fi

err "refused: nothing to do -- pass --emit-paths or --instance-of STEM."
usage
exit 2
