#!/usr/bin/env bash
# project-number-inuse.sh - Single source of truth for "a project_number is in use", the maximum
# ACTIVE project_number, the next free number, and a given number's location.
#
# Two consumers must agree on exactly one notion of "in use": scripts/state-write.sh's
# `--allocate-into` allocation prefix (which issues a number) and scripts/validate-state.sh's
# Check 12 (which flags a stale counter before an allocation can collide). Before this file
# existed each wrote its own copy of the bound as a jq expression kept aligned only by a header
# comment in each file naming the other as its sibling; this file removes the duplication by
# being the one place either expression is written down.
#
# Exports ONE thing, following lib/file-scope-overlap.sh's own shape for a jq-embedded consumer:
# `PNUM_INUSE_JQ_DEFS`, a string of jq `def` source text. A caller splices it into its own
# `jq -n`/`jq` program as an adjacent string literal (bash concatenates adjacent quoted strings,
# so `"$PNUM_INUSE_JQ_DEFS"'<rest of program>'` is one jq program) -- the same splicing shape
# orchestrate-batch-admit.sh already uses for `$FILE_SCOPE_OVERLAP_JQ_DEFS`. This file is never
# executed directly and provides no callable bash function, because both current consumers build
# jq programs rather than shelling out per comparison.
#
# The definitions below (see the heredoc) take the live state document as `.` and the sibling
# archive document as an explicit parameter named `$pnum_archive_doc` (an empty object `{}` when
# no sibling archive exists -- a caller with no archive on disk passes `{}` rather than omitting
# the parameter, since jq has no optional-parameter defaulting):
#
#   pnum_active_numbers            - active_projects[].project_number, numeric entries only
#   pnum_archive_numbers($pnum_archive_doc)
#                                   - the union of archived_projects / abandoned_projects /
#                                     completed_projects project_numbers from the archive doc,
#                                     numeric entries only
#   pnum_inuse_set($pnum_archive_doc)
#                                   - an object keyed by the number's STRING form, valued by the
#                                     array name it was found in (active_projects takes priority
#                                     when a number also appears in the archive, since active
#                                     entries are built into the object first and a later
#                                     duplicate key silently overwrites an earlier one under
#                                     `from_entries`). Being an object keyed by number is what
#                                     makes this a SET that tolerates the archive's real
#                                     cross-array duplicate project_numbers (24 measured on this
#                                     repository's own archive) without erroring: a duplicate key
#                                     collapses silently rather than raising.
#   pnum_active_max                - the maximum numeric active_projects[].project_number, or 0
#   pnum_next_free($pnum_archive_doc)
#                                   - the smallest integer strictly greater than pnum_active_max
#                                     whose string form is absent from pnum_inuse_set($pnum_archive_doc).
#                                     Deliberately NOT "smallest unused counting from 1" -- that
#                                     reading would recycle small numbers that predate every
#                                     active task and appear throughout committed history. This
#                                     is why the active max is the floor the search starts above,
#                                     not the archive-inclusive combined max the bound replaces.
#   pnum_location($n; $pnum_archive_doc)
#                                   - the array name holding $n in pnum_inuse_set($pnum_archive_doc),
#                                     or null when $n is not in use
#
# `specs/vault/**` is deliberately OUTSIDE every definition here: a vault operation renumbers
# active tasks down and resets the counter to recycle that number space on purpose, and counting
# a vaulted number here would make every post-vault state permanently unable to allocate. This
# mirrors the exclusion both consumers already documented before this file existed.
#
# CONTRACT (mirrors lib/common.sh's own contract, restated for this file specifically): sourcing
# this file sets no shell options and never calls `exit` -- it only assigns the one readonly
# string above. It leaks no state beyond that single, deliberate export (`PNUM_INUSE_JQ_DEFS` is
# the interface, not a leak). A miss (no sibling archive document available) is the caller's
# concern, handled by passing `{}` for `$pnum_archive_doc` -- this file itself has no failure
# mode, since it performs no I/O and runs no jq invocation of its own.
#
# FORBID LOCAL REDEFINITION: a consumer that sources this file MUST NOT write its own copy of any
# `pnum_*` definition -- there is no other copy; edit only here.
#
# The trailing `|| true` on the read below is required, not decorative: `read -d ''` reports a
# non-zero status when it hits the heredoc's EOF without ever seeing its NUL delimiter (there is
# none in ordinary text), even though the assignment itself succeeded in full. Under a caller's
# own `set -e` (state-write.sh sources this file under `set -euo pipefail`), that non-zero status
# would abort sourcing immediately -- `|| true` makes a plain `source`/`.` of this file safe under
# `-e` without requiring every consumer to wrap the source call in its own `if ! ...; then` guard.

# shellcheck disable=SC2034  # PNUM_INUSE_JQ_DEFS is the deliberate export this file exists to
# provide (see the header above) -- every consumer is an external script that splices it into
# its own jq program, so no reference to it appears inside this file itself.
read -r -d '' PNUM_INUSE_JQ_DEFS <<'JQDEFS' || true
def pnum_active_numbers:
  [.active_projects[]?.project_number] | map(select(type == "number"));

def pnum_archive_numbers($pnum_archive_doc):
  [
    ($pnum_archive_doc.archived_projects // [])[]?.project_number,
    ($pnum_archive_doc.abandoned_projects // [])[]?.project_number,
    ($pnum_archive_doc.completed_projects // [])[]?.project_number
  ] | map(select(type == "number"));

def pnum_inuse_set($pnum_archive_doc):
  (
    [pnum_active_numbers[] | {key: tostring, value: "active_projects"}]
    + [($pnum_archive_doc.archived_projects // [])[]? | select(.project_number | type == "number") | {key: (.project_number | tostring), value: "archived_projects"}]
    + [($pnum_archive_doc.abandoned_projects // [])[]? | select(.project_number | type == "number") | {key: (.project_number | tostring), value: "abandoned_projects"}]
    + [($pnum_archive_doc.completed_projects // [])[]? | select(.project_number | type == "number") | {key: (.project_number | tostring), value: "completed_projects"}]
  ) | from_entries;

def pnum_active_max:
  pnum_active_numbers | max // 0;

def pnum_next_free($pnum_archive_doc):
  pnum_inuse_set($pnum_archive_doc) as $pnum_set |
  pnum_active_max as $pnum_amax |
  first(range($pnum_amax + 1; infinite) | . as $pnum_cand | select(($pnum_set | has($pnum_cand | tostring)) | not));

def pnum_location($n; $pnum_archive_doc):
  pnum_inuse_set($pnum_archive_doc)[$n | tostring] // null;
JQDEFS
