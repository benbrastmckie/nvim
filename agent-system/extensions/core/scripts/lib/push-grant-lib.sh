#!/usr/bin/env bash
# push-grant-lib.sh — single source of truth for the consent-gated git-push grant primitives.
#
# Sourced (never executed) by: hooks/please-grant.sh (the mint path), hooks/guard-git-push.sh
# (the push guard), scripts/git-push-granted.sh (the sanctioned wrapper), and
# hooks/guard-destructive-git.sh (the destructive-action grant check). There is exactly ONE
# implementation of mint/verify/consume so the security-critical logic is never duplicated.
#
# CONTRACT (mirrors scripts/lib/common.sh's own contract):
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior.
#   - Every path this library touches is CWD-RELATIVE (specs/.push-grant/...), deliberately NOT
#     anchored via SCRIPT_DIR/PROJECT_ROOT resolution. This mirrors guard-destructive-git.sh's
#     own documented rationale: a hook under test (fixture-driven, cwd set inside a throwaway
#     git repo) must operate on the FIXTURE's specs/ tree, not the real repo's. The one exception
#     is the HMAC key, which is intentionally OUTSIDE the repo (see below) and is therefore
#     resolved via XDG_STATE_HOME, not cwd.
#   - FAIL-CLOSED EVERYWHERE: every verification function returns non-zero ("no grant" / "not
#     authorized") on any missing field, unreadable file, bad HMAC, expired timestamp, mismatched
#     target, or undeterminable default branch. This is a deliberate DIVERGENCE from
#     git-commit-scoped.sh's mutex, which fails OPEN (proceeds unserialized) on lock-acquire
#     failure because the worst residual case there is a safe index.lock race. A push grant has
#     no such safe residual: an unverifiable grant must never be read as "grant present."
#   - The guarantee this library provides is grant PROVENANCE ("this was minted by a literal
#     human prompt submission"), NOT key confidentiality. A same-user shell process can read
#     anything a hook can read; the HMAC raises the bar against a model-authored forgery, it does
#     not make the grant store a secret. State this honestly wherever the guarantee is described.
#
# Grant file format (KEY=VALUE, one field per line, extending the .git-snapshot-marker
# precedent in scripts/git-snapshot.sh): VERSION, TIMESTAMP, ACTION_CLASS, REMOTE, REF, FORCE,
# HEAD_SHA, REQUEST_TEXT (base64 -- the one field with unconstrained free-text input, so it
# cannot inject a newline and desynchronize line-based parsing), MINT_SOURCE, then HMAC last.
# HMAC-SHA256 is computed with the key from pg_key_path() over every PRECEDING line verbatim
# (the file's own bytes before the HMAC line is appended) -- recomputed at verify time by
# `grep -v '^HMAC='` against the file directly, never via a command-substitution round trip,
# which would silently strip trailing newlines and desynchronize the digest.
#
# ACTION_CLASS vocabulary (PG_ACTION_CLASSES below) starts at push_branch|push_tag (Phase 2) and
# is extended by Phase 5 to add the destructive-guard classes (reset_hard, clean_fd,
# checkout_discard, restore_discard, stash_drop) -- this is the single place that list is
# defined; please-grant.sh's grammar and guard-destructive-git.sh's grant check both read it
# from here rather than re-declaring it.
#
# Key storage: ${XDG_STATE_HOME:-$HOME/.local/state}/claude-agent-system/push-grant.key, mode
# 0600, OUTSIDE the repo -- because .claude/ is wipe-and-regenerate disposable (see
# rules/source-store-deploy-boundary.md) and a key living there would need its own ignore rule
# in every consumer repo. PUSH_GRANT_KEY_PATH overrides this for test isolation (never used in
# production call sites); PUSH_GRANT_DIR overrides the grant directory for the same reason.
#
# Audit: every mint and every consume appends one event via scripts/events-append.sh through the
# non-fatal observable wrapper below (identical contract to hooks/events-log-lifecycle.sh's own
# helper) -- a missing/failing events-append.sh (e.g. a flat test fixture with no nested
# .claude/scripts/ tree, or a direct source-store invocation where events-append.sh's own
# deploy-root-guard would reject it) never blocks the grant operation itself. Tests that assert
# the audit record build a nested fixture (.claude/scripts/{events-append.sh,lib/common.sh,
# deploy-root-guard.sh}) the way scripts/tests/test-subagent-postflight-marker.sh already does,
# rather than relying on the flat single-hook fixture style.

PG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PG_SCRIPTS_DIR="$(cd "${PG_LIB_DIR}/.." && pwd)"
PG_EVENTS_APPEND="${PG_SCRIPTS_DIR}/events-append.sh"

# Sourced unconditionally (never executed) so common_session_id is always available to
# pg_session_id below, even from a hook (please-grant.sh, guard-git-push.sh) that has no
# session_id of its own and does not otherwise source lib/common.sh. This is the single-source
# session-ID generator every *.sh file must use -- see common.sh's own header; a second inline
# inline duplicate session-id generator here would trip test-common-lib.sh's single-source
# assertion (that lint greps for the literal pattern this comment deliberately avoids spelling).
# shellcheck source=./common.sh
source "${PG_LIB_DIR}/common.sh" 2>/dev/null || true

PG_EXPIRY_WINDOW="${PG_EXPIRY_WINDOW:-600}"
PG_ACTION_CLASSES="push_branch push_tag reset_hard clean_fd checkout_discard restore_discard stash_drop"

# --- Path resolution ---------------------------------------------------------------------

pg_grant_dir() {
  echo "${PUSH_GRANT_DIR:-specs/.push-grant}"
}

pg_key_path() {
  echo "${PUSH_GRANT_KEY_PATH:-${XDG_STATE_HOME:-$HOME/.local/state}/claude-agent-system/push-grant.key}"
}

# --- Key lifecycle -------------------------------------------------------------------------

# pg_key_mode_ok <path> -- 0 iff the file exists and its permission mode is exactly 600.
pg_key_mode_ok() {
  local key="$1" mode
  [ -f "$key" ] || return 1
  mode="$(stat -c '%a' "$key" 2>/dev/null)" || mode="$(stat -f '%Lp' "$key" 2>/dev/null)" || return 1
  [ "$mode" = "600" ]
}

# pg_key_ensure -- create the key directory (0700) and the key itself (0600, 32 random bytes
# hex-encoded) on first use. Refuses (returns non-zero) if the key already exists with a
# looser-than-0600 mode, rather than silently trusting or re-tightening it.
pg_key_ensure() {
  local key_path key_dir
  key_path="$(pg_key_path)"
  key_dir="$(dirname "$key_path")"
  mkdir -p "$key_dir" 2>/dev/null || return 1
  chmod 700 "$key_dir" 2>/dev/null || true
  if [ -f "$key_path" ]; then
    pg_key_mode_ok "$key_path"
    return $?
  fi
  local tmp
  tmp="$(mktemp "${key_dir}/.push-grant.key.XXXXXX" 2>/dev/null)" || return 1
  if ! od -An -N32 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  chmod 600 "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$key_path" 2>/dev/null || { rm -f "$tmp"; return 1; }
  return 0
}

# --- Grant directory lifecycle ---------------------------------------------------------------

# pg_dir_ensure -- create specs/.push-grant/ (0700) and a self-contained ".gitignore" (content
# "*") on first use, so the directory is self-ignoring in every consumer repo with no edit to
# any top-level .gitignore anywhere (root-files/.gitignore is itself deployed to .claude/
# .gitignore and only covers paths inside it -- verified during planning).
pg_dir_ensure() {
  local dir
  dir="$(pg_grant_dir)"
  mkdir -p "$dir" 2>/dev/null || return 1
  chmod 700 "$dir" 2>/dev/null || true
  if [ ! -f "${dir}/.gitignore" ]; then
    printf '*\n' > "${dir}/.gitignore" 2>/dev/null || return 1
  fi
  return 0
}

pg_consumed_ledger_path() {
  echo "$(pg_grant_dir)/.consumed"
}

# pg_hmac_already_consumed <hmac> -- 0 (true) iff this exact HMAC value has already been
# recorded as consumed. This closes the gap that delete-on-use alone does NOT: deletion
# prevents a grant from being found via the normal directory glob, but it does nothing if the
# exact same bytes are ever written back to disk (e.g. a stray backup, a restore, a race) --
# the file would then be byte-identical to a legitimate unconsumed grant and would re-verify
# and re-match perfectly. The ledger is independent of the file's existence: once an HMAC has
# been consumed, it can never authorize again, no matter how the file reappears. A missing
# ledger is the normal starting state (nothing has ever been consumed yet) and correctly means
# "not consumed" -- this is not a fail-open gap, it is the correct empty-set answer.
pg_hmac_already_consumed() {
  local hmac="$1" ledger
  [ -n "$hmac" ] || return 1
  ledger="$(pg_consumed_ledger_path)"
  [ -f "$ledger" ] || return 1
  grep -qxF "$hmac" "$ledger" 2>/dev/null
}

# pg_hmac_record_consumed <hmac> -- appends <hmac> to the consumed ledger. Append-only,
# never truncated or rewritten; the ledger lives under specs/.push-grant/, already covered by
# that directory's self-ignoring ".gitignore" (content "*").
pg_hmac_record_consumed() {
  local hmac="$1" ledger
  [ -n "$hmac" ] || return 1
  pg_dir_ensure || return 1
  ledger="$(pg_consumed_ledger_path)"
  printf '%s\n' "$hmac" >> "$ledger" 2>/dev/null
}

pg_new_grant_path() {
  local dir ts rand
  dir="$(pg_grant_dir)"
  ts="$(date -u +%s)" || ts="0"
  rand="$(od -An -N4 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
  [ -n "$rand" ] || rand="${RANDOM}${RANDOM}"
  echo "${dir}/grant-${ts}-${rand}.kv"
}

# --- Default-branch determination ----------------------------------------------------------

# pg_default_branch <remote> -- echoes the determined default branch name and returns 0, or
# echoes nothing and returns 1 if it cannot be determined by either tier. Two tiers only
# (symbolic-ref, then init.defaultBranch config); the fail-closed treatment of an undetermined
# result (including the "literal set {master,main}" heuristic) lives in pg_is_default_branch
# below, which is the only consumer that needs it and is where the fail-closed direction is
# actually enforced.
pg_default_branch() {
  local remote="$1" ref
  ref="$(git symbolic-ref --short "refs/remotes/${remote}/HEAD" 2>/dev/null)" || ref=""
  if [ -n "$ref" ]; then
    echo "${ref#*/}"
    return 0
  fi
  ref="$(git config --get init.defaultBranch 2>/dev/null)" || ref=""
  if [ -n "$ref" ]; then
    echo "$ref"
    return 0
  fi
  return 1
}

# pg_is_default_branch <remote> <ref> -- 0 (true) iff ref is the determined default branch, OR
# the default branch could not be determined at all (fail-closed: an undetermined repo
# configuration must never let a force form slip through for lack of a resolvable name). When
# tiers 1/2 both fail, ref literally being "master" or "main" is also treated as true (the
# literal-set heuristic from the design) -- but note this is already subsumed by the
# unconditional fail-closed return immediately below it; it is named explicitly in comments for
# intuition even though the catch-all makes the distinction moot in code.
pg_is_default_branch() {
  local remote="$1" ref="$2" default
  if default="$(pg_default_branch "$remote")"; then
    [ "$ref" = "$default" ]
    return $?
  fi
  # Undetermined via both tiers -- fail closed unconditionally (subsumes the master/main
  # literal-set heuristic for any ref, not only those two names).
  return 0
}

# --- Categorical exclusions (checked BEFORE any grant lookup) -----------------------------

# pg_categorical_excluded <action_class> <remote> <ref> <force> <is_mirror> <is_all> \
#   <is_tags_flag> <is_prune> <is_delete> <refspec_count>
# <force> is one of: 0 (no force), lease (--force-with-lease), bare (bare --force/-f).
# The boolean flags (5th-9th args) are "1"/"0", pre-parsed by the caller (guard-git-push.sh's
# argv scan); this library does not re-parse argv itself. <refspec_count> defaults to 1.
# Echoes the exclusion reason and returns 0 if excluded; echoes nothing and returns 1 otherwise.
pg_categorical_excluded() {
  local action_class="$1" remote="$2" ref="$3" force="$4"
  local is_mirror="${5:-0}" is_all="${6:-0}" is_tags_flag="${7:-0}" is_prune="${8:-0}"
  local is_delete="${9:-0}" refspec_count="${10:-1}"

  if [ "$force" = "bare" ]; then
    echo "bare --force/-f is never grant-authorizable, on any ref"
    return 0
  fi
  if [ "$force" = "lease" ]; then
    if pg_is_default_branch "$remote" "$ref"; then
      echo "any force form (including --force-with-lease) on the default branch is never grant-authorizable"
      return 0
    fi
  fi
  if [ "$is_mirror" = "1" ]; then
    echo "--mirror is never grant-authorizable"
    return 0
  fi
  if [ "$is_all" = "1" ]; then
    echo "--all is never grant-authorizable"
    return 0
  fi
  if [ "$is_tags_flag" = "1" ]; then
    echo "--tags is never grant-authorizable"
    return 0
  fi
  if [ "$is_prune" = "1" ]; then
    echo "--prune is never grant-authorizable"
    return 0
  fi
  if [ "$is_delete" = "1" ]; then
    echo "a deletion refspec (--delete) is never grant-authorizable"
    return 0
  fi
  case "$ref" in
    :*)
      echo "a deletion refspec (empty-source :ref form) is never grant-authorizable"
      return 0
      ;;
  esac
  case "$refspec_count" in
    ''|*[!0-9]*) ;;
    *)
      if [ "$refspec_count" -gt 1 ]; then
        echo "a push with more than one refspec is never grant-authorizable"
        return 0
      fi
      ;;
  esac
  echo ""
  return 1
}

# --- Grant mint / verify / match / consume ---------------------------------------------------

# pg_grant_write <action_class> <remote> <ref> <force> <head_sha> <request_text> <mint_source>
# Low-level: writes exactly one new grant file and echoes its path on success. <force> here is
# the GRANTED force value, always one of 0|lease (bare force is never mintable -- the caller
# must have already refused via pg_categorical_excluded before calling this).
pg_grant_write() {
  local action_class="$1" remote="$2" ref="$3" force="$4" head_sha="$5" request_text="$6" mint_source="$7"
  pg_dir_ensure || return 1
  pg_key_ensure || return 1
  local key_path grant_path tmp ts reqb64
  key_path="$(pg_key_path)"
  grant_path="$(pg_new_grant_path)"
  tmp="$(mktemp "${grant_path}.XXXXXX" 2>/dev/null)" || return 1
  ts="$(date -u +%s)" || { rm -f "$tmp"; return 1; }
  reqb64="$(printf '%s' "$request_text" | base64 2>/dev/null | tr -d '\n')"
  {
    printf 'VERSION=1\n'
    printf 'TIMESTAMP=%s\n' "$ts"
    printf 'ACTION_CLASS=%s\n' "$action_class"
    printf 'REMOTE=%s\n' "$remote"
    printf 'REF=%s\n' "$ref"
    printf 'FORCE=%s\n' "$force"
    printf 'HEAD_SHA=%s\n' "$head_sha"
    printf 'REQUEST_TEXT=%s\n' "$reqb64"
    printf 'MINT_SOURCE=%s\n' "$mint_source"
  } > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  local key_content hmac
  key_content="$(cat "$key_path" 2>/dev/null)" || { rm -f "$tmp"; return 1; }
  hmac="$(openssl dgst -sha256 -hmac "$key_content" "$tmp" 2>/dev/null | awk '{print $NF}')"
  [ -n "$hmac" ] || { rm -f "$tmp"; return 1; }
  printf 'HMAC=%s\n' "$hmac" >> "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$grant_path" 2>/dev/null || { rm -f "$tmp"; return 1; }
  echo "$grant_path"
  return 0
}

# pg_grant_verify <path> -- verifies one grant file's structure and HMAC, and on success sets
# the PG_F_* globals (VERSION, TIMESTAMP, ACTION_CLASS, REMOTE, REF, FORCE, HEAD_SHA,
# REQUEST_TEXT, MINT_SOURCE). Returns non-zero -- "no grant" -- on ANY problem: missing/unreadable
# file, a required field appearing zero or more-than-one times, a non-0600 key, an unreadable
# key, an HMAC mismatch, an unknown ACTION_CLASS, a VERSION other than 1, a non-numeric
# TIMESTAMP, or a FORCE value outside {0, lease}.
pg_grant_verify() {
  local path="$1"
  PG_F_VERSION="" PG_F_TIMESTAMP="" PG_F_ACTION_CLASS="" PG_F_REMOTE="" PG_F_REF=""
  PG_F_FORCE="" PG_F_HEAD_SHA="" PG_F_REQUEST_TEXT="" PG_F_MINT_SOURCE="" PG_F_HMAC=""

  [ -n "$path" ] && [ -f "$path" ] && [ -r "$path" ] || return 1

  local field n
  for field in VERSION TIMESTAMP ACTION_CLASS REMOTE REF FORCE HEAD_SHA REQUEST_TEXT MINT_SOURCE HMAC; do
    n="$(grep -c "^${field}=" "$path" 2>/dev/null)" || n="0"
    [ "$n" = "1" ] || return 1
  done

  local key_path key_content
  key_path="$(pg_key_path)"
  pg_key_mode_ok "$key_path" || return 1
  key_content="$(cat "$key_path" 2>/dev/null)" || return 1
  [ -n "$key_content" ] || return 1

  local body_tmp computed claimed
  body_tmp="$(mktemp 2>/dev/null)" || return 1
  grep -v '^HMAC=' "$path" > "$body_tmp" 2>/dev/null || { rm -f "$body_tmp"; return 1; }
  computed="$(openssl dgst -sha256 -hmac "$key_content" "$body_tmp" 2>/dev/null | awk '{print $NF}')"
  rm -f "$body_tmp"
  [ -n "$computed" ] || return 1
  claimed="$(grep -m1 '^HMAC=' "$path" 2>/dev/null | cut -d= -f2-)"
  [ "$computed" = "$claimed" ] || return 1

  local version ts ac remote ref force sha reqtext mint
  version="$(grep -m1 '^VERSION=' "$path" | cut -d= -f2-)"
  ts="$(grep -m1 '^TIMESTAMP=' "$path" | cut -d= -f2-)"
  ac="$(grep -m1 '^ACTION_CLASS=' "$path" | cut -d= -f2-)"
  remote="$(grep -m1 '^REMOTE=' "$path" | cut -d= -f2-)"
  ref="$(grep -m1 '^REF=' "$path" | cut -d= -f2-)"
  force="$(grep -m1 '^FORCE=' "$path" | cut -d= -f2-)"
  sha="$(grep -m1 '^HEAD_SHA=' "$path" | cut -d= -f2-)"
  reqtext="$(grep -m1 '^REQUEST_TEXT=' "$path" | cut -d= -f2-)"
  mint="$(grep -m1 '^MINT_SOURCE=' "$path" | cut -d= -f2-)"

  [ "$version" = "1" ] || return 1
  case "$ts" in ''|*[!0-9]*) return 1 ;; esac
  case " ${PG_ACTION_CLASSES} " in *" ${ac} "*) ;; *) return 1 ;; esac
  [ -n "$remote" ] || return 1
  [ -n "$ref" ] || return 1
  case "$force" in 0|lease) ;; *) return 1 ;; esac
  [ -n "$sha" ] || return 1
  [ -n "$mint" ] || return 1

  PG_F_VERSION="$version"
  PG_F_TIMESTAMP="$ts"
  PG_F_ACTION_CLASS="$ac"
  PG_F_REMOTE="$remote"
  PG_F_REF="$ref"
  PG_F_FORCE="$force"
  PG_F_HEAD_SHA="$sha"
  PG_F_REQUEST_TEXT="$reqtext"
  PG_F_MINT_SOURCE="$mint"
  PG_F_HMAC="$claimed"
  return 0
}

# pg_grant_fresh <timestamp> -- 0 iff 0 <= (now - timestamp) <= PG_EXPIRY_WINDOW. A future-dated
# timestamp (negative age) fails, same shape as guard-destructive-git.sh's 120s marker check.
pg_grant_fresh() {
  local ts="$1" now age
  case "$ts" in ''|*[!0-9]*) return 1 ;; esac
  now="$(date -u +%s)" || return 1
  age=$(( now - ts ))
  [ "$age" -ge 0 ] && [ "$age" -le "$PG_EXPIRY_WINDOW" ]
}

# pg_grant_find_match <action_class> <remote> <ref> <force> -- picks the newest verifying,
# fresh, matching grant. Sets PG_MATCH_PATH and the PG_F_* globals (via the winning
# pg_grant_verify call) on success. For action_class=push_tag, the stored REF field is the
# literal pattern "refs/tags/*" and matches any single tag ref (the tag does not exist yet when
# /tag is typed).
pg_grant_find_match() {
  local action_class="$1" remote="$2" ref="$3" force="$4"
  PG_MATCH_PATH=""
  local dir head_sha best_ts best_path f
  dir="$(pg_grant_dir)"
  [ -d "$dir" ] || return 1
  head_sha="$(git rev-parse HEAD 2>/dev/null)" || return 1
  best_ts=-1
  best_path=""
  for f in "$dir"/grant-*.kv; do
    [ -e "$f" ] || continue
    pg_grant_verify "$f" || continue
    pg_hmac_already_consumed "$PG_F_HMAC" && continue
    pg_grant_fresh "$PG_F_TIMESTAMP" || continue
    [ "$PG_F_ACTION_CLASS" = "$action_class" ] || continue
    [ "$PG_F_REMOTE" = "$remote" ] || continue
    [ "$PG_F_FORCE" = "$force" ] || continue
    [ "$PG_F_HEAD_SHA" = "$head_sha" ] || continue
    if [ "$action_class" = "push_tag" ]; then
      case "$ref" in refs/tags/*) ;; *) continue ;; esac
      [ "$PG_F_REF" = "refs/tags/*" ] || continue
    else
      [ "$PG_F_REF" = "$ref" ] || continue
    fi
    if [ "$PG_F_TIMESTAMP" -gt "$best_ts" ]; then
      best_ts="$PG_F_TIMESTAMP"
      best_path="$f"
    fi
  done
  [ -n "$best_path" ] || return 1
  # Re-verify the winner so PG_F_* reflects the picked grant, not whichever candidate was
  # checked last by the loop above.
  pg_grant_verify "$best_path" || return 1
  PG_MATCH_PATH="$best_path"
  return 0
}

# pg_session_id -- a best-effort session id for audit events when the caller has none handy
# (e.g. a UserPromptSubmit hook, which has no agent-system sess_* identity of its own).
# common_session_id (sourced from lib/common.sh above) is the single sanctioned generator --
# this function never duplicates its pattern inline.
pg_session_id() {
  if command -v common_session_id >/dev/null 2>&1; then
    common_session_id
    return
  fi
  echo "sess_unavailable"
}

# pg_events_append_observable <events-append.sh args...> -- non-fatal wrapper, identical
# contract to hooks/events-log-lifecycle.sh's own helper of the same shape. ALWAYS returns 0.
pg_events_append_observable() {
  if [ -z "${PG_EVENTS_APPEND:-}" ] || [ ! -x "$PG_EVENTS_APPEND" ]; then
    echo "[push-grant-lib] WARNING: events-append.sh not available at '${PG_EVENTS_APPEND:-<unset>}' -- audit event NOT recorded (non-blocking)" >&2
    return 0
  fi
  if ! "$PG_EVENTS_APPEND" "$@" >/dev/null 2>&1; then
    echo "[push-grant-lib] WARNING: events-append.sh failed -- audit event NOT recorded (non-blocking)" >&2
  fi
  return 0
}

# pg_grant_mint <action_class> <remote> <ref> <force> <head_sha> <request_text> <mint_source>
# Writes a grant and appends a push_grant_issued audit event; echoes the grant path on success.
pg_grant_mint() {
  local action_class="$1" remote="$2" ref="$3" force="$4" head_sha="$5" request_text="$6" mint_source="$7"
  local grant_path detail
  grant_path="$(pg_grant_write "$action_class" "$remote" "$ref" "$force" "$head_sha" "$request_text" "$mint_source")" || return 1
  detail="$(jq -c -n --arg remote "$remote" --arg ref "$ref" --arg sha "$head_sha" --arg force "$force" \
    --arg mint_source "$mint_source" --arg action_class "$action_class" --arg request "$request_text" \
    '{remote:$remote, ref:$ref, sha:$sha, force:$force, mint_source:$mint_source, action_class:$action_class, request_text:$request}' 2>/dev/null)" || detail='{}'
  pg_events_append_observable --event-type push_grant_issued --category milestone \
    --session "$(pg_session_id)" --message "push grant issued: ${action_class} ${remote} ${ref}" \
    --detail-json "$detail"
  echo "$grant_path"
  return 0
}

# pg_grant_consume <action_class> <remote> <ref> <force> <consumer> -- finds, deletes
# (delete-on-use), and audits a matching grant. <consumer> names the caller (e.g.
# "guard-git-push.sh" or "git-push-granted.sh") for the audit record. Returns non-zero with NO
# audit event when no matching grant exists -- "no grant" must never be observably distinct
# from "grant consumed" in the audit trail.
pg_grant_consume() {
  local action_class="$1" remote="$2" ref="$3" force="$4" consumer="$5"
  pg_grant_find_match "$action_class" "$remote" "$ref" "$force" || return 1
  local consumed_path="$PG_MATCH_PATH" mint_source="$PG_F_MINT_SOURCE" sha="$PG_F_HEAD_SHA" consumed_hmac="$PG_F_HMAC"
  pg_hmac_record_consumed "$consumed_hmac" || true
  rm -f "$consumed_path" 2>/dev/null || true
  local detail
  detail="$(jq -c -n --arg remote "$remote" --arg ref "$ref" --arg sha "$sha" --arg force "$force" \
    --arg mint_source "$mint_source" --arg action_class "$action_class" --arg consumer "$consumer" \
    '{remote:$remote, ref:$ref, sha:$sha, force:$force, mint_source:$mint_source, action_class:$action_class, consumer:$consumer}' 2>/dev/null)" || detail='{}'
  pg_events_append_observable --event-type push_grant_consumed --category success \
    --session "$(pg_session_id)" --message "push grant consumed: ${action_class} ${remote} ${ref}" \
    --detail-json "$detail"
  return 0
}

# pg_grant_revoke -- deletes every live grant file (used by the wrapper's --revoke and by the
# mint hook before minting a new one, so at most one grant is ever live).
pg_grant_revoke() {
  local dir f
  dir="$(pg_grant_dir)"
  [ -d "$dir" ] || return 0
  for f in "$dir"/grant-*.kv; do
    [ -e "$f" ] && rm -f "$f" 2>/dev/null
  done
  return 0
}
