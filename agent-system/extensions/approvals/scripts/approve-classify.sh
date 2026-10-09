#!/usr/bin/env bash
# approve-classify.sh - Turn a generated /approve review file into a classification JSON.
#
# Reads a review file produced by a component's `approve.sh --review` (the grammar: a fenced
# `## Decisions` block of `no  selection  ...` / `no  spec  MODULE  ...` lines, one
# `## Evidence: <item>` section per item, each carrying one of exactly four `diff_since`
# sentinel shapes) and emits a JSON array on stdout, one record per item:
#   {id, evidence_kind, decl_added, decl_removed, decl_restated, class, recommendation,
#    confidence}
#
# Confidence vocabulary and the declaration-delta/mechanical-bar definitions are
# context/project/approvals/standards/confidence-vocabulary.md; this script is that ruling's
# only mechanical implementation.
#
# RECOMMENDATION DESIGN NOTE: this script only ever emits "approve" (class mechanical) or
# "read-full-text" (class declaration-level or needs-full-text). "decline" stays a valid value
# in the vocabulary -- skill-approve's owner-facing AskUserQuestion options include it -- but
# this classifier never emits it automatically: declining is the owner's judgment call, not a
# mechanical inference this script has any basis to make for them.
#
# Fails loud (exit 1, offending heading named on stderr) on: a missing `## Decisions` heading,
# a `## Decisions` line that matches neither recognized form, a missing `## Notes` heading, or
# a missing `## Evidence: <item>` section for a Decisions item. Never guesses and never treats
# an unrecognized item as mechanical.
#
# Usage: approve-classify.sh REVIEW_FILE
# Exit codes: 0 success (JSON on stdout), 1 malformed review (named heading on stderr),
#             2 usage/environment error.

set -uo pipefail

err() {
  echo "approve-classify.sh: $*" >&2
}

if [[ $# -ne 1 ]]; then
  err "usage: approve-classify.sh REVIEW_FILE"
  exit 2
fi

review_file="$1"
if [[ ! -f "$review_file" ]]; then
  err "refused: review file '$review_file' does not exist."
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  err "refused: jq is required and was not found on PATH."
  exit 2
fi

if ! grep -q '^## Notes' "$review_file"; then
  err "malformed review: no '## Notes' heading found in '$review_file'."
  exit 1
fi

if ! grep -q '^## Decisions' "$review_file"; then
  err "malformed review: no '## Decisions' heading found in '$review_file'."
  exit 1
fi

# Extract the fenced block immediately following "## Decisions" (the first ``` after it opens
# the block, the next ``` closes it).
decisions_block="$(awk '
  /^## Decisions/ { want=1; next }
  want && /^```/ { if (infence) { exit } else { infence=1; next } }
  want && infence { print }
' "$review_file")"

if [[ -z "$decisions_block" ]]; then
  err "malformed review: '## Decisions' heading found but its fenced block is empty or absent."
  exit 1
fi

item_ids=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ "$line" =~ ^no[[:space:]]+selection[[:space:]]+candidates_sha256= ]]; then
    item_ids+=("selection")
  elif [[ "$line" =~ ^no[[:space:]]+spec[[:space:]]+([^[:space:]]+)[[:space:]]+spec_digest= ]]; then
    item_ids+=("${BASH_REMATCH[1]}")
  else
    err "malformed review: '## Decisions' line matches neither recognized form: '$line'"
    exit 1
  fi
done <<< "$decisions_block"

if [[ ${#item_ids[@]} -eq 0 ]]; then
  err "malformed review: '## Decisions' fenced block contains no recognized item line."
  exit 1
fi

is_boilerplate_line() {
  local l="$1"
  l="${l#"${l%%[![:space:]]*}"}"  # ltrim
  [[ -z "$l" ]] && return 0
  [[ "$l" == --* ]] && return 0
  [[ "$l" == /-* ]] && return 0
  [[ "$l" == -/* ]] && return 0
  [[ "$l" == \** ]] && return 0
  [[ "$l" == @\[*\] ]] && return 0
  return 1
}

DECL_RE='^(noncomputable[[:space:]]+)?(private[[:space:]]+)?(protected[[:space:]]+)?(theorem|lemma|def|abbrev|axiom|structure|instance|class|inductive|opaque|example)[[:space:]]+([A-Za-z_][A-Za-z0-9_.'"'"']*)'

records=()

for id in "${item_ids[@]}"; do
  heading_pat="## Evidence: ${id}"
  if ! grep -qxF "$heading_pat" "$review_file"; then
    err "malformed review: no '## Evidence: ${id}' section found for Decisions item '${id}'."
    exit 1
  fi

  section="$(awk -v h="$heading_pat" '
    $0 == h { want=1; next }
    want && /^## / { exit }
    want { print }
  ' "$review_file")"

  evidence_kind=""
  if grep -qF "(never approved: review the full text)" <<< "$section"; then
    evidence_kind="never-approved"
  elif grep -qF "(the last approval is not committed;" <<< "$section"; then
    evidence_kind="uncommitted-approval"
  elif grep -qF "(no diff is available since commit" <<< "$section"; then
    evidence_kind="identical"
  elif grep -qF '```diff' <<< "$section"; then
    evidence_kind="diff"
  else
    err "malformed review: '## Evidence: ${id}' section matches none of the four known" \
        "diff_since sentinel shapes."
    exit 1
  fi

  decl_added=()
  decl_removed=()
  decl_restated=()
  all_boilerplate=1

  if [[ "$evidence_kind" == "diff" ]]; then
    diff_body="$(awk '
      /^```diff/ { want=1; next }
      want && /^```/ { exit }
      want { print }
    ' <<< "$section")"

    added_names=()
    removed_names=()

    while IFS= read -r dline; do
      case "$dline" in
        +++*|---*) continue ;;
        +*)
          content="${dline#+}"
          if ! is_boilerplate_line "$content"; then
            all_boilerplate=0
          fi
          if [[ "$content" =~ $DECL_RE ]]; then
            added_names+=("${BASH_REMATCH[5]}")
          fi
          ;;
        -*)
          content="${dline#-}"
          if ! is_boilerplate_line "$content"; then
            all_boilerplate=0
          fi
          if [[ "$content" =~ $DECL_RE ]]; then
            removed_names+=("${BASH_REMATCH[5]}")
          fi
          ;;
        *)
          : # context line, diff metadata (@@, diff --git, index ...) -- not classified
          ;;
      esac
    done <<< "$diff_body"

    # restated = present in both added and removed; added/removed are the set differences.
    for n in "${added_names[@]:-}"; do
      [[ -z "$n" ]] && continue
      found=0
      for m in "${removed_names[@]:-}"; do
        [[ "$n" == "$m" ]] && { found=1; break; }
      done
      if [[ "$found" -eq 1 ]]; then
        decl_restated+=("$n")
      else
        decl_added+=("$n")
      fi
    done
    for n in "${removed_names[@]:-}"; do
      [[ -z "$n" ]] && continue
      found=0
      for m in "${added_names[@]:-}"; do
        [[ "$n" == "$m" ]] && { found=1; break; }
      done
      [[ "$found" -eq 0 ]] && decl_removed+=("$n")
    done
  fi

  decl_empty=1
  [[ ${#decl_added[@]} -gt 0 || ${#decl_removed[@]} -gt 0 || ${#decl_restated[@]} -gt 0 ]] && decl_empty=0

  class=""
  confidence=""
  recommendation=""

  if [[ "$evidence_kind" == "identical" ]]; then
    class="mechanical"
    confidence="MEASURED"
    recommendation="approve"
  elif [[ "$evidence_kind" == "never-approved" || "$evidence_kind" == "uncommitted-approval" ]]; then
    class="needs-full-text"
    confidence="INFERENCE"
    recommendation="read-full-text"
  elif [[ "$evidence_kind" == "diff" && "$decl_empty" -eq 1 && "$all_boilerplate" -eq 1 ]]; then
    class="mechanical"
    confidence="INFERENCE"
    recommendation="approve"
  else
    # Includes: evidence_kind == diff with a non-empty declaration delta (MEASURED), and any
    # unrecognized/mixed diff content (never classified as mechanical).
    class="declaration-level"
    recommendation="read-full-text"
    if [[ "$decl_empty" -eq 0 ]]; then
      confidence="MEASURED"
    else
      confidence="INFERENCE"
    fi
  fi

  rec_json="$(jq -nc \
    --arg id "$id" \
    --arg evidence_kind "$evidence_kind" \
    --arg class "$class" \
    --arg recommendation "$recommendation" \
    --arg confidence "$confidence" \
    --argjson decl_added "$(printf '%s\n' "${decl_added[@]:-}" | jq -R 'select(length > 0)' | jq -sc '.')" \
    --argjson decl_removed "$(printf '%s\n' "${decl_removed[@]:-}" | jq -R 'select(length > 0)' | jq -sc '.')" \
    --argjson decl_restated "$(printf '%s\n' "${decl_restated[@]:-}" | jq -R 'select(length > 0)' | jq -sc '.')" \
    '{id: $id, evidence_kind: $evidence_kind, decl_added: $decl_added, decl_removed: $decl_removed, decl_restated: $decl_restated, class: $class, recommendation: $recommendation, confidence: $confidence}')"

  records+=("$rec_json")
done

printf '%s\n' "${records[@]}" | jq -sc '.'
