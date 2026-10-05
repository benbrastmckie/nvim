#!/usr/bin/env bash
# PostToolUse hook: TWO checks on every Write/Edit-tool write of .orchestrator-handoff.json --
# (1) reject a handoff that lands outside a specs/{NNN}_{SLUG}/ task directory (the original,
# location check), and (2) reject a handoff that fails validate-handoff.sh's required-field
# checks (the content check, added so required-field compliance is unforgettable rather than
# resting on per-dispatch prose). The filename is retained deliberately despite now covering two
# checks: renaming would churn manifest.json, merge-sources/settings-hooks.json, this suite's own
# test file, and every doc citation, for no behavioral gain.
#
# WHY (location check): the handoff is the orchestrator's only channel for learning a dispatch's
# outcome. A handoff written to a bare filename resolves against the ambient working directory at
# Write-tool-call time and strands outside the task directory. The orchestrator then finds no
# handoff at the expected path — or worse, finds the PREVIOUS cycle's file still sitting there
# and reports its status as if it were this dispatch's result.
#
# WHY (content check): validate-handoff.sh was already correctly strict, but its one live
# invocation discarded the exit code and no other consumer read it — writers omitted required
# `blockers`/`summary` and a loud `HANDOFF VALIDATION FAILED` was printed and then dropped with no
# durable trace. This check makes the required-field gate unforgettable at write time, the same
# site and posture (exit 2 + system-defect-record.sh) as the pre-existing location check. See
# context/patterns/system-defect-discrimination.md's seventeenth-instance paragraph
# (`HANDOFF_VALIDATION_FAILED`) and docs/architecture/handoff-schema.md's wiring-status paragraph.
#
# COVERAGE LIMITATION — DELIBERATE, DO NOT "FIX" BY WIDENING THE MATCHER:
#   This hook reads tool_input.file_path, which only Write and Edit tool calls carry. It
#   therefore catches every agent-direct handoff write (the hard-mode wrap-up path — which is
#   the path that actually broke). It is STRUCTURALLY BLIND to handoff writes performed by
#   Bash redirection, e.g. a shell function writing via `jq -n ... > "$handoff_path"`: a Bash
#   tool_input carries the raw, UNEXPANDED command text, in which "$handoff_path" appears
#   verbatim; its resolved value is not present in the hook input and cannot be recovered by
#   any amount of pattern matching. Adding a Bash matcher would produce false confidence, not
#   coverage. The content check inherits this same blindness for a Bash-redirect write — the
#   write-time gate below never fires for it either. For that path, this hook's two checks are
#   both protected instead by (a) skill-base.sh building an absolute path from SKILL_REPO_ROOT
#   (location), and (b) the mechanism-agnostic stray-handoff sweep in
#   skills/skill-orchestrate/SKILL.md Stage 5 (location) plus the postflight handoff-present
#   read path's own `validate-handoff.sh` invocation and durable `HANDOFF_VALIDATION_FAILED`
#   record (content) — see scripts/orchestrate-cycle-postflight.sh, detecting site
#   `cycle-postflight-handoff-validation`. That postflight check is the mechanism-agnostic
#   backstop for the content check, exactly as Stage 5's sweep already is for the location check.
#
# Exit 2 (not advisory additionalContext): PostToolUse runs after the write, so this does not
# prevent the file from existing; it surfaces stderr to the model as an error so the stray is
# actually removed and rewritten, rather than silently ignored.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DEFECT_RECORD="$SCRIPT_DIR/../scripts/system-defect-record.sh"
VALIDATE_HANDOFF="$SCRIPT_DIR/../scripts/validate-handoff.sh"

# Parse file path from stdin (PostToolUse hook input), with env-var fallback.
CC_SESSION_ID=""
CWD=""
if [ -t 0 ]; then
  FILE=$(printf '%s' "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null) || true
else
  INPUT=$(cat) || true
  FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || true
  if [ -z "$FILE" ]; then
    FILE=$(printf '%s' "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null) || true
  fi
  CC_SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || CC_SESSION_ID=""
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || CWD=""
fi

# Early exit for empty path (~1ms on the overwhelming majority of Write/Edit calls).
if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# EXACT basename match only — never a substring or glob. A file merely *containing* the string
# (say, a doc or a test fixture named handoff-example.json) is none of this hook's business.
if [ "$(basename "$FILE")" != ".orchestrator-handoff.json" ]; then
  echo '{}'
  exit 0
fi

# Allowed shapes, absolute or relative ({NNN} is 3 or more digits):
#   specs/{NNN}_{SLUG}/.orchestrator-handoff.json      (Claude Code tasks)
#   specs/OC_{NNN}_{SLUG}/.orchestrator-handoff.json   (OpenCode tasks)
if printf '%s' "$FILE" | grep -Eq '(^|/)specs/(OC_)?[0-9]{3,}_[^/]+/\.orchestrator-handoff\.json$'; then
  # ── Content check: required-field compliance, against the just-written file ─────────────────
  # Fail safe by construction: an unresolvable validator, or an unreadable/absent $FILE, is NOT
  # an error here -- it exits 0 silently, exactly like the location allow-branch above. This is
  # what keeps every synthetic, non-existent-path fixture in this hook's own test suite passing;
  # see that suite's run_hook helper, which never creates the file it names.
  if [ ! -f "$VALIDATE_HANDOFF" ] || [ ! -r "$VALIDATE_HANDOFF" ] \
     || [ ! -f "$FILE" ] || [ ! -r "$FILE" ]; then
    echo '{}'
    exit 0
  fi

  hv_output=$(bash "$VALIDATE_HANDOFF" "$FILE" 2>&1) || hv_exit=$?
  hv_exit="${hv_exit:-0}"

  if [ "$hv_exit" -eq 0 ]; then
    # PASS, including pass-with-warnings -- preserve the hook's JSON-channel discipline.
    echo '{}'
    exit 0
  fi

  hv_fail_fields=$(printf '%s\n' "$hv_output" | sed -E 's/\x1b\[[0-9;]*m//g' \
    | grep -E '^\[FAIL\]' | sed -E 's/^\[FAIL\] //')

  cat >&2 << BANNEREOF
HANDOFF VALIDATION FAILED (write-time gate): $FILE

validate-handoff.sh rejected this write. Required-field violations:
$hv_fail_fields

'summary' must be a non-empty 2-4 sentence string. 'blockers' must be a JSON array ('[]' is
normal and expected for a clean return -- it is NOT the same as omitting the field).

Remediate now, in this order:
  1. Do NOT delete the file.
  2. Re-write it at the SAME path with the missing/malformed field(s) corrected.
  3. If you are genuinely unsure what belongs in a field, consult
     docs/architecture/handoff-schema.md before guessing.
BANNEREOF

  bash "$SYSTEM_DEFECT_RECORD" \
    --defect-class HANDOFF_VALIDATION_FAILED \
    --detecting-site "hooks/validate-handoff-location.sh" \
    --message "handoff at $FILE failed validate-handoff.sh's required-field checks" \
    --attributed-path "unresolved:hooks/validate-handoff-location.sh" \
    --extra-detail-json "$(jq -c -n --arg f "$FILE" --arg fails "$hv_fail_fields" \
      '{file: $f, failing_fields: ($fails | split("\n") | map(select(length > 0)))}' 2>/dev/null || echo '{}')" \
    ${CC_SESSION_ID:+--cc-session-id "$CC_SESSION_ID"} \
    ${CWD:+--cwd "$CWD"} \
    >/dev/null 2>&1 || echo "Note: system-defect recording failed (non-fatal)" >&2
  exit 2
fi

cat >&2 << EOF
MISPLACED ORCHESTRATOR HANDOFF: $FILE

.orchestrator-handoff.json must be written INSIDE its own task directory:
  specs/{NNN}_{SLUG}/.orchestrator-handoff.json

A handoff written anywhere else is invisible to the orchestrator, which will then either
report a missing handoff or — worse — read the previous cycle's leftover file and report its
status as this dispatch's result.

Remediate now, in this order:
  1. Delete the file you just wrote at $FILE.
  2. Re-write it at the ABSOLUTE path supplied in your delegation context as 'handoff_path'
     (or '{task_dir}/.orchestrator-handoff.json' using the absolute 'task_dir').
  3. If neither field is present in your delegation context, do NOT guess a path — say so
     explicitly in your final message so the orchestrator can detect the gap.

Never write a bare '.orchestrator-handoff.json' filename: it resolves against whatever the
ambient working directory happens to be when the Write tool runs.
EOF

# Deliverable 2(c): record this detection. Per D4, no writer identity is available at this
# PostToolUse hook — the misplaced handoff is under specs/**, not a source-store file — so this
# is EXPECTED to be a log-only outcome (Signal B attribution unresolvable), not a bug. The
# placeholder below deliberately fails Signal B resolution rather than guessing an attribution.
bash "$SYSTEM_DEFECT_RECORD" \
  --defect-class HANDOFF_MISLOCATED \
  --detecting-site "hooks/validate-handoff-location.sh" \
  --message "misplaced orchestrator handoff detected: $FILE" \
  --attributed-path "unresolved:hooks/validate-handoff-location.sh" \
  --extra-detail-json "$(jq -c -n --arg f "$FILE" '{misplaced_path: $f}' 2>/dev/null || echo '{}')" \
  ${CC_SESSION_ID:+--cc-session-id "$CC_SESSION_ID"} \
  ${CWD:+--cwd "$CWD"} \
  >/dev/null 2>&1 || echo "Note: system-defect recording failed (non-fatal)" >&2
exit 2
