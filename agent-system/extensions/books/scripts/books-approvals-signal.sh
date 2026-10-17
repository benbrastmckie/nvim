#!/usr/bin/env bash
# books-approvals-signal.sh -- READ-ONLY recognizer. Reads a captured component-gate run's
# output and recognizes one specific failure mode: the approvals stage failing because approval
# records are absent or stale (a person needs to approve something), distinguished from every
# other way that stage -- or the gate as a whole -- can go red.
#
# Signature source and rulings: see
# context/project/books/domain/approvals-detection.md (read 2026-10-17 from
# /home/benjamin/Projects/Logos/Verification/components/framed_channel/{check.sh,
# check-approvals.sh}). This script implements that document's D1-D5 rulings; it does not
# restate the reasoning, only the predicate and the emitted shape.
#
# READ-ONLY, BY DESIGN -- asserted here so a later editor sees the constraint at the point of
# temptation, not only in the context record:
#   - This script WRITES NOTHING to any path. It only reads its --gate-output file and prints
#     at most one JSON object to stdout.
#   - This script INVOKES NOTHING: not `approve.sh`, not `/approve`, not `check-approvals.sh`,
#     not `check.sh`, not `full-gate.sh`, not any gate. It never shells out to anything other
#     than the plain POSIX text utilities (grep/sed/cat) used to read its own input file.
#   - This script NEVER calls `AskUserQuestion` (it is not reachable from a script context at
#     all, but the constraint is stated here for the same reason).
#   - This script NEVER reads `.decisions.json`. A recorded decline or defer must never be
#     treated as evidence the approval requirement is satisfied -- see
#     `domain/approvals-detection.md`'s "never-suppress" MUST NOT block. Not reading that file
#     at all is how this script keeps that promise structurally rather than by discipline alone.
#
# Usage:
#   books-approvals-signal.sh --gate-output FILE --component NAME [--task N] [--gate-exit N]
#                              [--root DIR]
#
#   --gate-output FILE  Path to a file holding the captured combined stdout+stderr of a
#                        component gate run (or a direct check-approvals.sh invocation). Required.
#   --component NAME    The component name, used only in the emitted question/option text.
#                        Required.
#   --task N             Optional task number; when given, appears in the "enter review now"
#                        option's relayed command line.
#   --gate-exit N         Optional, informational only. The predicate below NEVER keys on this
#                        value -- see domain/approvals-detection.md's "exit 1 alone is not the
#                        signal" paragraph. Accepted only so a caller can pass it through for
#                        logging; it has no effect on the recognizer's own decision.
#   --root DIR            Optional. Repository root to resolve the deployed `/approve` surface
#                        probe against (Step 2.5's fallback). Defaults to `git rev-parse
#                        --show-toplevel`, then the current working directory. Primarily for
#                        this script's own fixture suite.
#
# Exit codes:
#   0 - an approval-need signal was recognized; the JSON object is on stdout.
#   1 - no approval-need signal (the normal outcome for a green gate, or any other kind of red).
#   2 - usage error, or --gate-output does not exist or is not readable.
#
# No interactive prompts. No network. No build. No write to any path.

set -euo pipefail

gate_output=""
component=""
task_number=""
gate_exit=""
root_arg=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --gate-output)
      [ "$#" -ge 2 ] || { echo "books-approvals-signal.sh: --gate-output requires a path" >&2; exit 2; }
      gate_output="$2"; shift 2 ;;
    --component)
      [ "$#" -ge 2 ] || { echo "books-approvals-signal.sh: --component requires a name" >&2; exit 2; }
      component="$2"; shift 2 ;;
    --task)
      [ "$#" -ge 2 ] || { echo "books-approvals-signal.sh: --task requires a number" >&2; exit 2; }
      task_number="$2"; shift 2 ;;
    --gate-exit)
      [ "$#" -ge 2 ] || { echo "books-approvals-signal.sh: --gate-exit requires a number" >&2; exit 2; }
      # shellcheck disable=SC2034  # accepted for passthrough/logging only; never read (see header)
      gate_exit="$2"; shift 2 ;;
    --root)
      [ "$#" -ge 2 ] || { echo "books-approvals-signal.sh: --root requires a directory" >&2; exit 2; }
      root_arg="$2"; shift 2 ;;
    -h|--help)
      sed -n '/^# Usage:/,/^# No interactive prompts/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "books-approvals-signal.sh: unknown argument: $1" >&2
      exit 2 ;;
  esac
done

if [ -z "$gate_output" ] || [ -z "$component" ]; then
  echo "books-approvals-signal.sh: --gate-output and --component are both required" >&2
  exit 2
fi
if [ ! -f "$gate_output" ] || [ ! -r "$gate_output" ]; then
  echo "books-approvals-signal.sh: --gate-output file does not exist or is not readable: $gate_output" >&2
  exit 2
fi

# ─── Resolve the repository root (for the /approve-surface probe only) ────────────────────────
if [ -n "$root_arg" ]; then
  repo_root="$(cd "$root_arg" 2>/dev/null && pwd)" || repo_root="$root_arg"
elif repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  :
else
  repo_root="$(pwd)"
fi

output_text="$(cat "$gate_output")"

# ─── Stage-attribution corroboration (never required; absence never suppresses a match) ───────
# A direct check-approvals.sh invocation never prints this line (only check.sh does, as the
# LAST stage's own failure summary), so its absence is expected and must not suppress a
# recognized signal below.
stage_attributed=false
if printf '%s' "$output_text" | grep -qF 'check.sh: FAIL at the final stage, approvals; every earlier stage passed'; then
  stage_attributed=true
fi

# ─── The six recognized absent-or-stale families (D2) ──────────────────────────────────────────
# Fixed substrings where the real message has no placeholder; `.*` only where the real message
# names a variable file/module/digest. Matched against the WHOLE captured text (not line by
# line), since a real capture may wrap or interleave with other output.
recognized_families=()
if printf '%s' "$output_text" | grep -qE '\[FAIL\] approvals: .* does not exist\. No selection or specification has been approved\.'; then
  recognized_families+=("1: approvals file absent")
fi
if printf '%s' "$output_text" | grep -qF '[FAIL] approvals: no selection record (the selection has not been approved)'; then
  recognized_families+=("2: no selection record")
fi
if printf '%s' "$output_text" | grep -qF '[FAIL] approvals: the selection is stale: the Rust changed since it was approved (source_sha256 recorded'; then
  recognized_families+=("3: selection stale (Rust changed)")
fi
if printf '%s' "$output_text" | grep -qF '[FAIL] approvals: the selection is stale: the candidate set changed since it was approved (candidates_sha256 recorded'; then
  recognized_families+=("4: selection stale (candidate set changed)")
fi
if printf '%s' "$output_text" | grep -qE '\[FAIL\] approvals: the specification .* is stale: it changed since it was approved \(spec_digest recorded'; then
  recognized_families+=("5: specification stale")
fi
if printf '%s' "$output_text" | grep -qE '\[FAIL\] approvals: no specification record for .* \(its current spec_digest is .*\): it has not been approved'; then
  recognized_families+=("6: no specification record")
fi

# ─── The excluded families (D2) -- detected ONLY for the mixed-red honesty clause ──────────────
# Never contributes to recognition on its own. When a recognized family above ALSO matched, an
# excluded-family hit adds one clause to `question` rather than being silently dropped.
excluded_hit=false
excluded_patterns=(
  'approvals:.*(by|approver|confirmed_via|assisted_by)[^"]*record[^"]* is malformed'
  'is both selected and declined'
  'is listed more than once'
  'is neither selected nor declined'
  'is selected or declined but is not an in-subset candidate'
  'selected, but no registered statement is about it'
  'specified .* but not selected'
  'declined .* has an empty reason'
  'names .*, which is not a Challenge module'
  'SpecCheck reports no digest for it'
  'the approvals file does not have the recorded shape'
  'spec-check\.sh failed'
  'was approved by an agent \(.*\), and --require-person is set'
)
for pat in "${excluded_patterns[@]}"; do
  if printf '%s' "$output_text" | grep -qE "$pat"; then
    excluded_hit=true
    break
  fi
done

# ─── No recognized family: exit 1, nothing on stdout ───────────────────────────────────────────
if [ "${#recognized_families[@]}" -eq 0 ]; then
  exit 1
fi

# ─── Probe for the deployed /approve surface (Step 2.5's bounded fallback) ─────────────────────
approve_deployed=false
if [ -f "${repo_root}/.claude/commands/approve.md" ] || [ -f "${repo_root}/.claude/scripts/approve-paths.sh" ]; then
  approve_deployed=true
fi

task_suffix=""
[ -n "$task_number" ] && task_suffix=" --task ${task_number}"

if [ "$approve_deployed" = true ]; then
  option1="Enter review now — run /approve ${component}${task_suffix} yourself in your next turn"
else
  option1="Enter review now — run components/${component}/approve.sh --review (then approve.sh --record) yourself in your next turn, since /approve is not deployed in this repository"
fi
option2="Defer — ask again on the next run that hits this red"
option3="Decline — leave ${component}'s approval records as-is; the gate leg stays red"

families_joined=$(printf '%s; ' "${recognized_families[@]}")
families_joined="${families_joined%; }"

question="${component}'s approval records are absent or stale (${families_joined}) -- a person needs to approve before this gate leg can go green."
if [ -n "$task_number" ]; then
  question="${question} (task ${task_number})"
fi
if [ "$excluded_hit" = true ]; then
  question="${question} Other approvals failures are also present in this run; reviewing alone will not turn the gate leg green."
fi
if [ "$stage_attributed" = true ]; then
  question="${question} (corroborated by check.sh's own final-stage attribution line)"
fi

# ─── Emit the single user_decision-shaped JSON object; exit 0 ─────────────────────────────────
json_string() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN{printf "\""} {printf "%s", $0} END{printf "\""}'
}

{
  printf '{\n'
  printf '  "question": %s,\n' "$(json_string "$question")"
  printf '  "options": [%s, %s, %s],\n' "$(json_string "$option1")" "$(json_string "$option2")" "$(json_string "$option3")"
  printf '  "recommended": %s,\n' "$(json_string "$option2")"
  printf '  "blocking": false\n'
  printf '}\n'
}

exit 0
