#!/usr/bin/env bash
# return-meta-status-vocabulary.sh - Single source of truth for the canonical .return-meta.json
# STATUS vocabulary (the field consumed by orchestrate-recover-outcome.sh, validate-return-meta.sh,
# and lint-agent-contracts.sh's Check E) -- a different, narrower enum than the task-level
# vocabulary below.
#
# ─── THE TRAP THIS FILE EXISTS TO AVOID ────────────────────────────────────────────────────────
# scripts/lib/status-vocabulary.sh is the 13-value TASK-LEVEL enum for
# specs/state.json `.active_projects[].status` (not_started, researching, researched, planning,
# planned, implementing, pr_ready, completed, blocked, abandoned, partial, expanded, hold). It contains
# "completed" AS A VALID MEMBER, by design -- a task legitimately reaches state.json status
# "completed". Sourcing THAT file for .return-meta.json purposes is the exact defect this library
# exists to prevent: it would yield a lint/validator that ACCEPTS "status": "completed" in a
# .return-meta.json file, which is precisely the value context/formats/return-metadata-file.md
# forbids ("Never use 'completed' - it triggers Claude stop behavior"). The two vocabularies look
# similar by name and share several member strings (researched, planned, implemented, partial,
# blocked) but are NOT the same enum and MUST NOT be conflated or cross-sourced.
#
# context/formats/return-metadata-file.md's status table is the prose source of truth for the
# vocabulary below; this file is its sole executable anchor, extracted verbatim from
# validate-return-meta.sh (the array at :175, the forbidden-value message at :183) and
# orchestrate-recover-outcome.sh (the 3-value success subset at :242) so all three consumers --
# plus lint-agent-contracts.sh's Check E -- read one definition instead of four private copies.
#
# Modeled on scripts/lib/phase-heading-patterns.sh's "one sourced shared library, many consumers"
# shape: source-able from either the deployed (.claude/scripts/lib/) or source-store
# (agent-system/extensions/core/scripts/lib/) copy, no side effects at source time (defines
# functions/variables only; does not execute anything).
#
# Usage: `source` this file, then:
#   - Use $RETURN_META_STATUS_VALUES (bash array) directly for iteration/membership loops.
#   - Call `is_return_meta_status <value>` to validate a candidate status string.
#   - Use $RETURN_META_SUCCESS_STATUSES (bash array), or call
#     `is_return_meta_success_status <value>` for the success-outcome subset
#     orchestrate-recover-outcome.sh's `case "$status"` arm consumes.
#   - Use $RETURN_META_FORBIDDEN_STATUS and $RETURN_META_FORBIDDEN_STATUS_MESSAGE for the
#     "completed" rejection, worded byte-identically to validate-return-meta.sh's existing message
#     so no consumer re-words it independently.

# ─── Closed .return-meta.json status enum (8 values) ───────────────────────────────────────────
# Copied verbatim from validate-return-meta.sh:175 -- not re-derived. Order preserved so a manual
# diff between the two is trivial.
RETURN_META_STATUS_VALUES=(
  "in_progress"
  "researched"
  "planned"
  "implemented"
  "needs_research"
  "partial"
  "failed"
  "blocked"
)

# ─── Forbidden value ────────────────────────────────────────────────────────────────────────────
# "completed" is deliberately NOT a member of RETURN_META_STATUS_VALUES above. It IS a legitimate
# member of the unrelated task-level scripts/lib/status-vocabulary.sh enum -- see the file header
# trap warning. The message text is copied verbatim from validate-return-meta.sh:183.
RETURN_META_FORBIDDEN_STATUS="completed"
RETURN_META_FORBIDDEN_STATUS_MESSAGE="status value is 'completed', which is explicitly forbidden (triggers Claude stop behavior) -- use 'implemented' instead"

# ─── Success-outcome subset (3 values) ─────────────────────────────────────────────────────────
# Copied verbatim from orchestrate-recover-outcome.sh:242's success case arm. This is a
# DELIBERATE SUBSET of RETURN_META_STATUS_VALUES above, not a second independent vocabulary --
# see the deferred follow-up recorded in that script's success arm about whether it should widen
# to admit intentional extension-local terminal vocabularies (consulted, converted, assembled).
RETURN_META_SUCCESS_STATUSES=(
  "researched"
  "planned"
  "implemented"
)

# ─── is_return_meta_status <value> ─────────────────────────────────────────────────────────────
# Returns 0 (true) iff <value> is exactly one of the eight closed enum values, 1 (false)
# otherwise. Never partial-matches.
is_return_meta_status() {
  local candidate="$1" v
  for v in "${RETURN_META_STATUS_VALUES[@]}"; do
    [[ "$candidate" == "$v" ]] && return 0
  done
  return 1
}

# ─── is_return_meta_success_status <value> ─────────────────────────────────────────────────────
# Returns 0 (true) iff <value> is one of the 3-value success subset, 1 (false) otherwise
# (including for a value that is a member of RETURN_META_STATUS_VALUES but not the success
# subset, e.g. "partial" or "blocked").
is_return_meta_success_status() {
  local candidate="$1" v
  for v in "${RETURN_META_SUCCESS_STATUSES[@]}"; do
    [[ "$candidate" == "$v" ]] && return 0
  done
  return 1
}
