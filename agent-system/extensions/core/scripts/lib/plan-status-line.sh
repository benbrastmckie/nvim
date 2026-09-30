#!/usr/bin/env bash
# plan-status-line.sh - Single source of truth for plan-level `- **Status**:` grammar
# classification.
#
# The sibling implementation this file must agree with is `update-plan-status.sh`, which
# implements the identical classification inline (lines ~90-118 as of this writing) as part of
# its idempotent stamp operation. This library extracts that classification logic into a
# read-only, sourceable form so `validate-artifact.sh` can enforce the same grammar without a
# third independent copy of the regex. Refactoring `update-plan-status.sh` itself onto this
# library is deliberately DEFERRED follow-up work, out of this task's scope boundary (it belongs
# to `update-plan-status.sh`'s own file_scope); `scripts/tests/test-validate-artifact.sh`'s
# cross-script conformance guard is the mechanism that catches the two ever drifting apart in the
# meantime.
#
# Accept-trailing-text policy: a plan-level Status line may carry arbitrary trailing text after
# the closing `]` (e.g. a resume annotation such as
# `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)`) -- that text is well-formed and
# preserved verbatim by `update-plan-status.sh`'s stamp. Text BETWEEN the `- **Status**: ` prefix
# and the opening `[`, or a missing bracket pair entirely, is malformed. See
# `context/formats/plan-format.md`'s "Plan-level vs. phase-level markers" subsection for the full
# policy this file enforces.
#
# Usage: `source` this file, then call `plan_status_classify FILE`. Prints one line to stdout:
#   OK <line_number>              -- conforming (trailing text, if any, is not reported)
#   M1                            -- no `^- **Status**:` line found anywhere in FILE
#   M2 <line_number> <content>    -- prefix present, no `[...]` bracket pair anywhere on the line
#   M3 <line_number> <content>    -- bracket pair present, but text intrudes between the prefix
#                                     and the opening bracket
# Never exits non-zero on a malformed classification -- the caller decides how to react. Returns
# 1 only on a usage error (missing/unreadable FILE argument).

plan_status_classify() {
  local file="$1"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo "plan_status_classify: usage: plan_status_classify FILE (FILE not found: '$file')" >&2
    return 1
  fi

  local line_number
  line_number=$(grep -n '^- \*\*Status\*\*:' "$file" 2>/dev/null | head -1 | cut -d: -f1)

  if [ -z "$line_number" ]; then
    echo "M1"
    return 0
  fi

  local line
  line=$(sed -n "${line_number}p" "$file")

  if [[ "$line" =~ ^-\ \*\*Status\*\*:\ \[[^]]*\] ]]; then
    echo "OK $line_number"
  elif [[ "$line" =~ \[[^]]*\] ]]; then
    # M3: a bracket pair exists on the line, but text intrudes between the prefix and the
    # opening bracket (e.g. "- **Status**: see [NOTE]").
    echo "M3 $line_number $line"
  else
    # M2: prefix present, but no [...] bracket pair anywhere on the line.
    echo "M2 $line_number $line"
  fi
  return 0
}

# plan_status_log_error CLASSIFICATION_OUTPUT: given one line of plan_status_classify's stdout,
# emit the shape-specific diagnostic this library's callers should surface, in the SAME wording
# `update-plan-status.sh` uses for its own diagnostics (so an operator sees the same language
# from both layers). Callers wire the return value into their own log_error/log_warn as
# appropriate; this function only composes the message text.
plan_status_error_message() {
  local classification="$1"
  local shape
  shape="${classification%% *}"
  case "$shape" in
    M1)
      echo "plan-level Status line not found (expected: - **Status**: [STATUS])"
      ;;
    M2)
      echo "plan-level Status line has no [STATUS] bracket pair"
      ;;
    M3)
      echo "plan-level Status line has unexpected text between the prefix and the bracket"
      ;;
    OK)
      echo ""
      ;;
    *)
      echo "plan-level Status line classification error (unrecognized shape: $shape)"
      ;;
  esac
}
