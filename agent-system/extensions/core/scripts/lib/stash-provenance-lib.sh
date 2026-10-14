#!/usr/bin/env bash
# stash-provenance-lib.sh — single source of truth for recording, per Claude Code session,
# which `git stash` entries THIS session actually created, so guard-destructive-git.sh can
# refuse a `pop`/`apply` of a FOREIGN entry (one it did not create) rather than letting it
# succeed and silently drop someone else's work.
#
# Sourced (never executed) by: hooks/record-stash-provenance.sh (the PostToolUse writer) and
# hooks/guard-destructive-git.sh (the pre-call snapshot writer and the ownership-query reader).
# There is exactly one implementation of the snapshot/diff/query primitives so the state-dir
# location, the session-id validation, and the file-naming convention cannot drift between the
# writer and the reader.
#
# MECHANISM: ownership is established by DIFFING the set of stash commit shas
# (`git stash list --format=%H`) across one whole Bash tool call -- never by pattern-matching the
# command text of `git stash push`. Text matching cannot see `git-snapshot.sh`'s own internal
# `git stash push -u` (default mode) or `git stash create` + `git stash store` (--no-revert
# mode), both of which are subprocess-invisible to any hook that only observes
# tool_input.command -- and both of which are exactly the sanctioned flow that must keep working
# (see rules/source-store-deploy-boundary.md's sibling rationale in guard-destructive-git.sh's
# own header for the general subprocess-invisibility precedent). A pre-call snapshot
# (sp_snapshot_pre, written by guard-destructive-git.sh's PreToolUse invocation, BEFORE the
# command runs) plus a post-call diff (sp_record_new_owned, written by
# record-stash-provenance.sh's PostToolUse invocation, AFTER the command runs) correctly
# attributes every NEW stash sha that appeared during the call to this session, regardless of
# which git subcommand actually created it.
#
# SESSION SCOPE IS LITERAL: ownership is keyed to Claude Code's own native per-session
# `session_id` (from the hook payload's `.session_id` field), never to an agent-system `sess_*`
# identity. A stash created in an earlier dispatch (a different native session) therefore reads
# as foreign to a later one -- deliberate, see the plan's Decisions section; the recovery path
# for that case is the `/please stash pop` grant, not widened automatic ownership.
#
# FAIL-CLOSED, DIVERGING FROM detect-noop-bash.sh's FAIL-OPEN POSTURE: sp_is_owned returns
# non-zero (not owned) on ANY missing/unreadable/absent state -- an invalid or absent
# session_id, a missing owned-file, an unreadable owned-file. detect-noop-bash.sh is advisory
# only (it can never block a call), so it fails open by design; this library backs a REFUSAL
# decision, where "I don't know" must mean "treat as foreign," never "treat as mine."
#
# CONTRACT (mirrors push-grant-lib.sh's and common.sh's own contract):
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior.
#   - Dependency-free: never sources common.sh or any other library. Both call sites
#     (guard-destructive-git.sh, a `set -euo pipefail` PreToolUse hook; and
#     record-stash-provenance.sh, a PostToolUse hook with its own error handling) source this
#     file directly, so it must not impose or assume a particular caller shell-option posture.
#   - Every function is best-effort and never raises: a failure to snapshot or record is
#     swallowed by the caller (`|| true`), never allowed to break the hook it is sourced into.
#   - CWD-RELATIVE by default (sp_state_dir falls back to a path relative to THIS library's own
#     location, not the caller's cwd, unlike push-grant-lib.sh's specs/-relative convention --
#     see sp_state_dir's own comment for why). STASH_PROVENANCE_STATE_DIR overrides it for test
#     isolation, following the NOOP_BASH_STATE_DIR precedent in hooks/detect-noop-bash.sh:249 so
#     tests never write into the source store's own tmp/ directory.
#
# State file shapes (one pair per session_id, both plain newline-delimited text):
#   stash-pre-<sid>   -- the full `git stash list --format=%H` output captured by
#                        sp_snapshot_pre, i.e. the shas that existed BEFORE this Bash call.
#   stash-owned-<sid> -- one line per stash commit sha this session has ever created, across
#                        every Bash call in its lifetime (append-only, deduplicated).

# sp_session_valid <sid>
# The `^[A-Za-z0-9_-]+$` safe-filename check, copied verbatim from
# hooks/detect-noop-bash.sh:244's SESSION_ID validation -- the same character class, for the
# same reason (a session id touches a path below and must never contain `/`, `..`, or anything
# else that could escape the state directory).
sp_session_valid() {
  local sid="$1"
  [[ "$sid" =~ ^[A-Za-z0-9_-]+$ ]]
}

# sp_state_dir
# Echoes the state directory. Defaults to `<this lib's dir>/../../tmp` (i.e.
# `agent-system/extensions/core/tmp` in source-store mode, `.claude/tmp` in deployed mode --
# mirroring detect-noop-bash.sh:249's NOOP_BASH_STATE_DIR convention exactly, one directory
# component shallower since this library lives in scripts/lib/ rather than hooks/ directly:
# scripts/lib/../.. is scripts/lib -> scripts -> core, so the literal relative spelling used
# below is "../../tmp" from scripts/lib/, landing at core/tmp -- the same tmp/ directory
# detect-noop-bash.sh's hooks/../tmp also resolves to, since hooks/ and scripts/ are siblings).
# STASH_PROVENANCE_STATE_DIR overrides this for test isolation, so tests never write into the
# source store's own on-disk (and un-gitignored) tmp/ directory.
sp_state_dir() {
  if [ -n "${STASH_PROVENANCE_STATE_DIR:-}" ]; then
    echo "${STASH_PROVENANCE_STATE_DIR}"
    return 0
  fi
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "${lib_dir}/../../tmp"
}

# sp_pre_file <sid> / sp_owned_file <sid> -- echo the per-session state file paths.
sp_pre_file() {
  echo "$(sp_state_dir)/stash-pre-${1}"
}

sp_owned_file() {
  echo "$(sp_state_dir)/stash-owned-${1}"
}

# sp_snapshot_pre <sid>
# Writes the current `git stash list --format=%H` output (one sha per line, oldest-to-newest as
# git itself orders it) to the session's pre-file, OVERWRITING any previous content -- each Bash
# call gets a fresh pre-snapshot, taken immediately before that call's command runs. Best-effort:
# an invalid session id, a non-git cwd, or an unwritable state dir all degrade to "did nothing,"
# never a failure the caller must handle. Returns 0 unconditionally (the caller's `|| true`
# posture is a belt-and-suspenders second line of defense, not the only one).
sp_snapshot_pre() {
  local sid="$1"
  sp_session_valid "$sid" || return 0
  local dir pre_file tmp
  dir="$(sp_state_dir)"
  mkdir -p "$dir" 2>/dev/null || return 0
  pre_file="$(sp_pre_file "$sid")"
  tmp="${pre_file}.tmp.$$"
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git stash list --format=%H 2>/dev/null > "$tmp" || true
  else
    : > "$tmp" 2>/dev/null || true
  fi
  mv -f "$tmp" "$pre_file" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
  return 0
}

# sp_record_new_owned <sid>
# Diffs the CURRENT `git stash list --format=%H` output against the session's pre-file (written
# by sp_snapshot_pre at the START of this same Bash call) and appends every sha present now but
# absent from the pre-file to the session's owned-file, guarded by `grep -qxF` so an owned-file
# is never grown with a duplicate. A call that created no new stash entry (including the
# documented "push saved nothing" shape) therefore appends nothing. A missing or unreadable
# pre-file is treated as "everything currently present was already there" (i.e. nothing new is
# recorded) rather than "nothing was there, so everything present is new" -- the latter would
# wrongly grant ownership of every PRE-EXISTING foreign entry the very first time any session
# ever calls this function. Best-effort throughout; always returns 0.
sp_record_new_owned() {
  local sid="$1"
  sp_session_valid "$sid" || return 0
  local dir pre_file owned_file current_shas pre_shas sha
  dir="$(sp_state_dir)"
  mkdir -p "$dir" 2>/dev/null || return 0
  pre_file="$(sp_pre_file "$sid")"
  owned_file="$(sp_owned_file "$sid")"

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    return 0
  fi

  current_shas="$(git stash list --format=%H 2>/dev/null)" || current_shas=""
  [ -n "$current_shas" ] || return 0

  if [ ! -f "$pre_file" ] || [ ! -r "$pre_file" ]; then
    # No readable pre-snapshot for this call: per the header comment above, record nothing new
    # rather than guessing every currently-present sha is ours.
    return 0
  fi
  pre_shas="$(cat "$pre_file" 2>/dev/null)" || pre_shas=""

  while IFS= read -r sha; do
    [ -z "$sha" ] && continue
    if ! printf '%s\n' "$pre_shas" | grep -qxF "$sha" 2>/dev/null; then
      if [ ! -f "$owned_file" ] || ! grep -qxF "$sha" "$owned_file" 2>/dev/null; then
        printf '%s\n' "$sha" >> "$owned_file" 2>/dev/null || true
      fi
    fi
  done <<< "$current_shas"

  return 0
}

# sp_is_owned <sid> <sha>
# Returns 0 (owned) iff <sid> validates AND <sha> is non-empty AND the session's owned-file
# exists, is readable, and contains that exact sha as a whole line. Returns non-zero (NOT
# owned -- fail-closed) on any missing/unreadable file, any invalid/absent session id, or any
# empty sha. This is the single ownership-query entry point guard-destructive-git.sh's Phase 3
# predicate consumes.
sp_is_owned() {
  local sid="$1" sha="$2" owned_file
  sp_session_valid "$sid" || return 1
  [ -n "$sha" ] || return 1
  owned_file="$(sp_owned_file "$sid")"
  [ -f "$owned_file" ] && [ -r "$owned_file" ] || return 1
  grep -qxF "$sha" "$owned_file" 2>/dev/null
}
