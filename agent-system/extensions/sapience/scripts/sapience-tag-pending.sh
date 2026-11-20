#!/usr/bin/env bash
# sapience-tag-pending.sh - Injects a literal "[repo:<slug>]" tag into the `provenance` of every
# still-pending, resolvable record in ~/.sapience/pending_kos.jsonl.
#
# Mutates ONLY ~/.sapience/pending_kos.jsonl (never config.json, extracted.json, or any other
# vendor file). That file is a LEDGER_FILE in ~/.sapience/extract_local.py -- preserved rather
# than overwritten by `sapience update`, unlike the vendor's own CLIENT_FILES -- so an
# extension-owned script that touches only this one path stays durable across a vendor
# auto-update that would otherwise erase a hand-edited vendor client script.
#
# Required operational sequencing: `sapience sync` (stages new records into the ledger) ->
# this script, run with --write (tags the still-untagged records) -> `sapience review` (posts
# the now-tagged records to POST /ingest-kos). The tag MUST land between the second and third
# step: a record already posted can never be retagged, because the vault's KO surface offers
# create (/ingest-kos) and read (/v1/search, /v1/ko/subjects) only -- there is no update and no
# delete API, so a posted KO's provenance (tagged or not) is permanent.
#
# Usage: sapience-tag-pending.sh [--write] [--ledger PATH] [--config PATH]
#
#   (no flags)  Dry-run (the default): prints a per-project summary (project name, resolved
#               slug, records that would be tagged, records already tagged, records
#               unresolvable) and touches nothing. Exit 0 on a clean pass, including a
#               zero-change pass.
#   --write     Mutate the ledger: tag every still-untagged, resolvable record in place.
#   --ledger    Override the ledger path (default: ~/.sapience/pending_kos.jsonl). Test-only.
#   --config    Override the config path (default: ~/.sapience/config.json). Test-only.
#
# Slug resolution per record (identical in outcome to sapience-remember.sh's, so a tag this
# script writes is retrievable through the exact same sapience-retrieve.sh `source=` filter a
# live sapience-remember.sh write already is): look the record's `project` value up against
# ~/.sapience/config.json's `.capture.projects[]` by `.name` to get that entry's `.path_prefix`,
# resolve that path's git toplevel through resolve_checkout_toplevel() below (following a linked
# worktree to its PARENT CHECKOUT, exactly as the write and read paths already do), then take the
# basename of that toplevel. A record whose `project` is empty, has no matching
# `capture.projects[]` entry, or whose `path_prefix` is not inside a git repository is left
# untagged and counted as unresolvable -- never a fatal error for the whole pass.
#
# Idempotence and composition: a record whose existing `provenance` already contains the literal
# substring "[repo:" is left untouched (already tagged by some means). Otherwise, when
# `provenance` is absent or empty, it is set to "[repo:<slug>] session capture via
# sapience-tag-pending.sh"; when it already carries a non-empty value (e.g. a future vendor
# update starts setting one), " [repo:<slug>]" is APPENDED to it rather than clobbering it. Every
# other field is left byte-identical, in particular `_hash` (dedupe-load-bearing in
# extract_local.py's `_ko_hash()`) and `project` (review-display-load-bearing in
# `_group_summary()`), and the file keeps exactly one JSON object per line.
#
# Concurrency and durability: the whole load-mutate-rewrite cycle is wrapped in a blocking,
# exclusive `flock` on ~/.sapience/.ledger.lock -- the SAME lock name
# extract_local.py's `_ledger_lock` class takes by default (`name='ledger'` ->
# `QUEUE.parent / '.ledger.lock'`) -- so this script never races a concurrent `sapience
# sync`/`sapience review` the way extract_local.py's own header documents (Ari Sklar #8,
# 2026-09-19) that an un-locked load-update-rewrite once did. The rewritten ledger is written via
# <path>.tmp.$$ + mv with mode 0600, matching extract_local.py's `_write_atomic` conventions
# exactly (tmp-suffix-by-pid, then an atomic rename, then an owner-only mode).
#
# Exit codes: 0 on a clean pass (dry-run or --write, including zero-change). Non-zero with a
# message on stderr on an unreadable ledger, an unreadable/invalid config, or a failed atomic
# write. A per-record resolution failure is never fatal -- it is counted and reported instead.

set -euo pipefail

WRITE="false"
LEDGER=""
CONFIG=""

usage() {
  cat >&2 <<'USAGE'
Usage: sapience-tag-pending.sh [--write] [--ledger PATH] [--config PATH]

  (no flags)  Dry-run (default): print a per-project summary, touch nothing.
  --write     Mutate the ledger: tag every still-untagged, resolvable record in place.
  --ledger    Override the ledger path (default: ~/.sapience/pending_kos.jsonl). Test-only.
  --config    Override the config path (default: ~/.sapience/config.json). Test-only.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --write)
      WRITE="true"; shift ;;
    --ledger)
      [ "$#" -ge 2 ] || { echo "sapience-tag-pending.sh: --ledger requires a value" >&2; exit 1; }
      LEDGER="$2"; shift 2 ;;
    --config)
      [ "$#" -ge 2 ] || { echo "sapience-tag-pending.sh: --config requires a value" >&2; exit 1; }
      CONFIG="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "sapience-tag-pending.sh: unknown flag: $1" >&2
      usage
      exit 1 ;;
  esac
done

SAPIENCE_DIR="${HOME}/.sapience"
[ -z "$LEDGER" ] && LEDGER="${SAPIENCE_DIR}/pending_kos.jsonl"
[ -z "$CONFIG" ] && CONFIG="${SAPIENCE_DIR}/config.json"
LOCK_FILE="${SAPIENCE_DIR}/.ledger.lock"

if [ ! -f "$CONFIG" ]; then
  echo "sapience-tag-pending.sh: config not found: $CONFIG" >&2
  exit 1
fi
if ! jq -e . "$CONFIG" >/dev/null 2>&1; then
  echo "sapience-tag-pending.sh: config is not valid JSON: $CONFIG" >&2
  exit 1
fi

if [ ! -f "$LEDGER" ]; then
  echo "sapience-tag-pending.sh: ledger not found: $LEDGER" >&2
  exit 1
fi

# === BEGIN sapience-worktree-checkout-resolution (byte-identical in every copy: this hook,
# verify-sapience-mcp.sh, sapience-retrieve.sh, sapience-remember.sh, and
# verify-sapience-context-scoping.sh -- test-sapience-mcp-registration.sh's lockstep case
# extracts this marker-delimited block from each copy and asserts they are all byte-identical).
# Resolves a directory (default: cwd) to its git toplevel, following a linked worktree to its
# PARENT CHECKOUT rather than the worktree itself. Echoes the toplevel path and returns 0, or
# returns 1 with no output when the directory is not inside a git repository at all.
#
# Detection: compare `git rev-parse --git-dir` against `--git-common-dir`. Equal (including
# both failing, on a non-git path) means "not a linked worktree -- behave exactly like a bare
# `git rev-parse --show-toplevel`". Unequal means "linked worktree -- the common dir's PARENT
# directory is the checkout". `--git-common-dir` returns a relative path at a checkout root but
# an absolute path from inside a worktree, so it is absolutized before its parent is taken.
resolve_checkout_toplevel() {
    local dir="${1:-.}" git_dir common_dir
    git_dir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null)" || return 1
    common_dir="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)" || return 1
    if [ "$git_dir" = "$common_dir" ]; then
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null
        return $?
    fi
    case "$common_dir" in
        /*) : ;;
        *) common_dir="$(cd "$dir" 2>/dev/null && pwd)/$common_dir" ;;
    esac
    (cd "$common_dir/.." 2>/dev/null && pwd)
}
# === END sapience-worktree-checkout-resolution ===

# --- Build the project -> slug map once per run. An entry whose path_prefix does not resolve to
# a git toplevel gets no map entry at all (not an error). Emitted as "name\tslug" lines. ---
build_project_slug_map() {
  local name path_prefix toplevel slug
  while IFS=$'\t' read -r name path_prefix; do
    [ -z "$name" ] && continue
    toplevel="$(resolve_checkout_toplevel "$path_prefix" 2>/dev/null)" || continue
    [ -z "$toplevel" ] && continue
    slug="$(basename "$toplevel")"
    [ -z "$slug" ] && continue
    printf '%s\t%s\n' "$name" "$slug"
  done < <(jq -r '.capture.projects // [] | .[] | [(.name // ""), (.path_prefix // "")] | @tsv' "$CONFIG" 2>/dev/null)
}

PROJECT_SLUG_MAP="$(build_project_slug_map)"

slug_for_project() {
  local project="$1" line
  [ -z "$project" ] && return 1
  while IFS=$'\t' read -r name slug; do
    if [ "$name" = "$project" ]; then
      printf '%s\n' "$slug"
      return 0
    fi
  done <<<"$PROJECT_SLUG_MAP"
  return 1
}

# --- Load-mutate-rewrite cycle. When --write is given, the WHOLE cycle below (read, mutate,
# rewrite) runs under the ledger's own blocking exclusive flock on ~/.sapience/.ledger.lock,
# taken BEFORE the ledger is read, so no concurrent `sapience sync`/`sapience review` can observe
# or produce a half-updated file and no lost-write race (the exact failure extract_local.py's
# header documents, Ari Sklar #8, 2026-09-19) can occur. A dry-run takes no lock: it never
# mutates the file, and the vendor's own atomic-replace write means a concurrent reader never
# observes a half-written ledger either way. ---
run_pass() {
  local tmp_out summary_tmp lock_fd_opened="false"
  tmp_out="$(mktemp 2>/dev/null)" || { echo "sapience-tag-pending.sh: mktemp failed" >&2; exit 1; }
  summary_tmp="$(mktemp 2>/dev/null)" || { echo "sapience-tag-pending.sh: mktemp failed" >&2; rm -f "$tmp_out"; exit 1; }
  trap 'rm -f "$tmp_out" "$summary_tmp"' RETURN

  : > "$tmp_out"

  if [ "$WRITE" = "true" ]; then
    exec 9>"$LOCK_FILE"
    flock -x 9
    lock_fd_opened="true"
  fi

  local line project provenance slug new_provenance
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    project="$(printf '%s' "$line" | jq -r '.project // ""' 2>/dev/null)" || project=""
    provenance="$(printf '%s' "$line" | jq -r '.provenance // ""' 2>/dev/null)" || provenance=""

    case "$provenance" in
      *'[repo:'*)
        # Already tagged by some means -- idempotent no-op, count it.
        printf '%s\t%s\t%s\n' "$project" "already_tagged" "" >> "$summary_tmp"
        printf '%s\n' "$line" >> "$tmp_out"
        continue
        ;;
    esac

    if ! slug="$(slug_for_project "$project")" || [ -z "$slug" ]; then
      printf '%s\t%s\t%s\n' "${project:-<none>}" "unresolvable" "" >> "$summary_tmp"
      printf '%s\n' "$line" >> "$tmp_out"
      continue
    fi

    if [ -z "$provenance" ]; then
      new_provenance="[repo:${slug}] session capture via sapience-tag-pending.sh"
    else
      new_provenance="${provenance} [repo:${slug}]"
    fi

    printf '%s\t%s\t%s\n' "$project" "tagged" "$slug" >> "$summary_tmp"

    if [ "$WRITE" = "true" ]; then
      printf '%s\n' "$line" | jq -c --arg p "$new_provenance" '.provenance = $p' 2>/dev/null >> "$tmp_out" || {
        echo "sapience-tag-pending.sh: failed to rewrite a record for project '${project}'" >&2
        exit 1
      }
    else
      printf '%s\n' "$line" >> "$tmp_out"
    fi
  done < "$LEDGER"

  # --- Per-project summary ---
  echo "sapience-tag-pending.sh: per-project summary (mode: $([ "$WRITE" = "true" ] && echo write || echo dry-run))"
  local proj
  for proj in $(cut -f1 "$summary_tmp" | sort -u); do
    local would_tag already resolved_slug unresolved
    would_tag="$(awk -F'\t' -v p="$proj" '$1==p && $2=="tagged"' "$summary_tmp" | wc -l | tr -d ' ')"
    already="$(awk -F'\t' -v p="$proj" '$1==p && $2=="already_tagged"' "$summary_tmp" | wc -l | tr -d ' ')"
    unresolved="$(awk -F'\t' -v p="$proj" '$1==p && $2=="unresolvable"' "$summary_tmp" | wc -l | tr -d ' ')"
    resolved_slug="$(awk -F'\t' -v p="$proj" '$1==p && $2=="tagged" {print $3; exit}' "$summary_tmp")"
    [ -z "$resolved_slug" ] && resolved_slug="-"
    printf '  project=%-20s slug=%-20s would_tag=%-6s already_tagged=%-6s unresolvable=%-6s\n' \
      "$proj" "$resolved_slug" "$would_tag" "$already" "$unresolved"
  done

  if [ "$WRITE" = "true" ]; then
    local write_tmp
    write_tmp="${LEDGER}.tmp.$$"
    cp "$tmp_out" "$write_tmp"
    chmod 0600 "$write_tmp"
    mv "$write_tmp" "$LEDGER"
  fi

  if [ "$lock_fd_opened" = "true" ]; then
    exec 9>&-
  fi
}

run_pass
exit 0
