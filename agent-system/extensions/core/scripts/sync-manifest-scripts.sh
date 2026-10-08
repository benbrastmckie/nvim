#!/usr/bin/env bash
# sync-manifest-scripts.sh - Derive each extension's `provides.scripts` array from its own
# tracked `scripts/` tree, the same way `generate-context-line-counts.sh` derives `line_count`
# from `wc -l`: a `--check`/`--write` repair pair over SOURCE-STORE manifests only.
#
# WHY THIS EXISTS: a new `scripts/tests/test-*.sh` requires a hand-written entry in its
# extension's `manifest.json` `provides.scripts` array. `run-all.sh` discovers test suites by
# glob and needs no such entry, so authors reasonably (and wrongly) expect `provides.scripts` to
# behave like `index-entries.json`'s wholesale-directory convention. It does not: a missing entry
# produces no authoring-time signal at all, and `check-extension-docs.sh`'s Rule Q
# (check_undeclared_scripts) only catches it on a disk-driven lint run. This script removes the
# authoring burden entirely: one command derives the array from disk, the same category of fix
# `generate-context-line-counts.sh --write` already is for `line_count`.
#
# CURATION: re-derived at authoring time (not assumed) across all 9 extensions with a `scripts/`
# tree -- `comm -23`/`comm -13` over `git ls-files <ext>/scripts` vs. `jq '.provides.scripts[]?'`
# returns empty in BOTH directions for every one of them (core 225/225, literature 54/54, lean
# 36/36, books 7/7, memory 4/4, typst 4/4, nix 2/2, email 1/1, nvim 1/1). `provides.scripts` is
# NOT curated today, so deriving it is safe. A "declared but absent on disk" entry found in the
# future is still only REPORTED, never auto-removed -- deleting a declaration is a deploy-
# affecting judgement call this script does not make for the operator (see Risk 1 in this task's
# plan).
#
# WHY THE SOURCE STORE, NEVER THE DEPLOYED MANIFEST: `.claude/extensions/*/manifest.json` is a
# disposable deploy artifact regenerated from `agent-system/extensions/*/manifest.json` on every
# redeploy (see `.claude/rules/source-store-deploy-boundary.md`). A fix written only to the
# deployed copy would be silently discarded on the next redeploy. This script therefore reads
# and (in --write mode) rewrites ONLY the source `agent-system/extensions/<ext>/manifest.json`
# files.
#
# Usage:
#   bash sync-manifest-scripts.sh [--check]   (default) report only, write nothing, exit nonzero
#                                              if any gap exists in either direction
#   bash sync-manifest-scripts.sh --write     insert each missing (on-disk, not declared) entry
#                                              into that manifest's provides.scripts array
#
# MATCHING: full relative path under scripts/ (not basename), `deprecated/*` excluded -- mirrors
# Rule Q (check_undeclared_scripts in check-extension-docs.sh) exactly, so a file this script
# calls "missing" is precisely a file Rule Q would fail() on, and a file this script calls
# "clean" is precisely a file Rule Q would not. An extension with no `scripts/` directory at all
# is skipped entirely, matching Rule Q's own `[[ -d "$ext_path/scripts" ]] || return 0` guard.
#
# --write MECHANICS: a SURGICAL, line-oriented rewrite of the `provides.scripts` array block
# only -- never a whole-document `jq` round-trip. Two of the 21 extension manifests
# (`books`, `rust`) are not `jq --indent 2` canonical elsewhere in the file (an unrelated compact
# array on a different key); round-tripping the whole document through jq would reformat those
# unrelated arrays too, defeating "only provides.scripts changed" diff review. Each missing entry
# is inserted at its locally alphabetical position among the EXISTING entries (first existing
# entry that sorts after it; end of array if none) -- existing entries are reproduced verbatim,
# including their original ordering (which is not always itself alphabetical in this codebase:
# some extensions interleave a script with its own test rather than sorting strictly), so this
# script never resorts or otherwise touches a pre-existing line. The one exception: if a missing
# entry is appended after what was previously the array's last entry, that previously-last line's
# trailing comma is added (it is no longer last) -- this is the only case where an existing line's
# text changes at all.

set -euo pipefail

# Same REPO_ROOT-bypass pattern as generate-context-line-counts.sh and check-extension-docs.sh:
# the deploy-root-guard only fires when REPO_ROOT is unset, so a deliberate source-store
# invocation (REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh)
# works without tripping the guard.
[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 1
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "ERROR: $EXT_DIR does not exist" >&2
  exit 1
fi

MODE="check"
case "${1:-}" in
  --write) MODE="write" ;;
  --check | "") MODE="check" ;;
  *)
    echo "Usage: $(basename "$0") [--check|--write]" >&2
    exit 2
    ;;
esac

info() { echo "  $*"; }
fail() { echo "  FAIL: $*"; }

TOTAL_MISSING=0
TOTAL_ABSENT=0
TOTAL_WRITTEN=0

# _sync_rewrite_scripts_array <manifest_path> <missing_entries_file>
#
# Surgical rewrite of exactly one manifest's `provides.scripts` array: inserts every line from
# <missing_entries_file> (one bare path per line, no quotes) into the array at its locally
# alphabetical position, leaving every other line of the file byte-identical.
_sync_rewrite_scripts_array() {
  local manifest="$1"
  local missing_file="$2"
  local tmp_out
  tmp_out="$(mktemp)"
  awk -v missing_file="$missing_file" '
    BEGIN {
      nmiss = 0
      while ((getline line < missing_file) > 0) {
        if (line != "") { nmiss++; miss[nmiss] = line }
      }
      close(missing_file)
      # insertion-sort the missing entries ascending
      for (i = 2; i <= nmiss; i++) {
        key = miss[i]; j = i - 1
        while (j >= 1 && miss[j] > key) { miss[j+1] = miss[j]; j-- }
        miss[j+1] = key
      }
      found_key = 0
      in_scripts = 0
      nbody = 0
    }
    {
      if (!found_key && $0 ~ /"scripts"[ \t]*:/) {
        found_key = 1
        if ($0 ~ /\[[ \t]*\]/) {
          # Inline empty array on one line, e.g. "scripts": [],  -- rewrite as a multi-line
          # array holding exactly the missing entries (sorted), nothing else existed before.
          indent = $0
          sub(/[^ \t].*$/, "", indent)
          bodyindent = indent "  "
          pre = $0; sub(/\[.*$/, "[", pre)
          post_suffix = $0; sub(/^.*\]/, "", post_suffix)
          post = indent "]" post_suffix
          print pre
          for (i = 1; i <= nmiss; i++) {
            sep = (i < nmiss) ? "," : ""
            print bodyindent "\"" miss[i] "\"" sep
          }
          print post
          next
        } else if ($0 ~ /\[[ \t]*$/) {
          print $0
          in_scripts = 1
          next
        }
      }
      if (in_scripts) {
        if ($0 ~ /^[ \t]*\][ \t]*,?[ \t]*$/) {
          # Closing-bracket line: flush the merged body. Existing entries are reproduced
          # verbatim and in their ORIGINAL order (never resorted); each missing entry is
          # inserted immediately before the first existing entry that sorts after it (always
          # followed by something, so it always gets a trailing comma). Any missing entries
          # that sort after every existing entry are appended at the very end, after the loop --
          # the ONLY case that touches an existing line text at all: the previously-last
          # existing entry gains a trailing comma, since it is no longer last.
          if (nbody == 0) {
            body_indent = $0
            sub(/[^ \t].*$/, "", body_indent)
            body_indent = body_indent "  "
          }
          mi = 1
          for (i = 1; i <= nbody; i++) {
            while (mi <= nmiss && miss[mi] <= body_val[i]) {
              print body_indent "\"" miss[mi] "\","
              mi++
            }
            if (i == nbody && mi <= nmiss) {
              line = body_line[i]
              if (line !~ /,[ \t]*$/) {
                sub(/[ \t]*$/, "", line)
                line = line ","
              }
              print line
            } else {
              print body_line[i]
            }
          }
          while (mi <= nmiss) {
            sep = (mi < nmiss) ? "," : ""
            print body_indent "\"" miss[mi] "\"" sep
            mi++
          }
          print $0
          in_scripts = 0
          next
        } else {
          line = $0
          if (nbody == 0) {
            body_indent = $0
            sub(/[^ \t].*$/, "", body_indent)
          }
          val = $0
          sub(/^[ \t]*"/, "", val)
          sub(/".*$/, "", val)
          nbody++
          body_val[nbody] = val
          body_line[nbody] = line
          next
        }
      }
      print $0
    }
  ' "$manifest" > "$tmp_out"
  mv "$tmp_out" "$manifest"
}

for ext_path in "$EXT_DIR"/*/; do
  ext_path_norm="${ext_path%/}"
  ext_name="$(basename "$ext_path_norm")"
  [[ -d "$ext_path_norm/scripts" ]] || continue
  manifest="$ext_path_norm/manifest.json"
  [[ -f "$manifest" ]] || continue

  ext_rel="${ext_path_norm#"$REPO_ROOT"/}"

  disk_list="$(mktemp)"
  declared_list="$(mktemp)"
  missing_list="$(mktemp)"
  absent_list="$(mktemp)"

  while IFS= read -r script_file; do
    [[ -f "$REPO_ROOT/$script_file" ]] || continue
    rel_path="${script_file#"$ext_rel"/scripts/}"
    case "$rel_path" in
      deprecated/*) continue ;;
    esac
    printf '%s\n' "$rel_path"
  done < <(git -C "$REPO_ROOT" ls-files "$ext_path_norm/scripts" | sort) > "$disk_list"

  jq -r '.provides.scripts[]?' "$manifest" | sort > "$declared_list"

  comm -23 "$disk_list" "$declared_list" > "$missing_list"
  comm -13 "$disk_list" "$declared_list" > "$absent_list"

  ext_missing=$(grep -c . "$missing_list" || true)
  ext_absent=$(grep -c . "$absent_list" || true)

  if [[ "$ext_missing" -gt 0 ]]; then
    TOTAL_MISSING=$((TOTAL_MISSING + ext_missing))
    while IFS= read -r m; do
      fail "$ext_name: script file on disk NOT in provides.scripts: scripts/$m"
    done < "$missing_list"
  fi
  if [[ "$ext_absent" -gt 0 ]]; then
    TOTAL_ABSENT=$((TOTAL_ABSENT + ext_absent))
    while IFS= read -r a; do
      info "$ext_name: provides.scripts declares 'scripts/$a' but no such file is tracked on disk (reported only -- never auto-removed; may be a deliberate curation entry)"
    done < "$absent_list"
  fi

  if [[ "$MODE" == "write" && "$ext_missing" -gt 0 ]]; then
    _sync_rewrite_scripts_array "$manifest" "$missing_list"
    TOTAL_WRITTEN=$((TOTAL_WRITTEN + ext_missing))
    echo "$ext_name: wrote $ext_missing missing entry/entries into provides.scripts"
  fi

  disk_count=$(wc -l < "$disk_list" | tr -d ' ')
  declared_count=$(wc -l < "$declared_list" | tr -d ' ')
  echo "$ext_name: $disk_count on disk, $declared_count declared, $ext_missing missing, $ext_absent absent"

  rm -f "$disk_list" "$declared_list" "$missing_list" "$absent_list"
done

echo ""
echo "=== Summary ($MODE mode) ==="
echo "Missing (on disk, not declared): $TOTAL_MISSING"
echo "Absent (declared, not on disk): $TOTAL_ABSENT"
if [[ "$MODE" == "write" ]]; then
  echo "Written: $TOTAL_WRITTEN"
fi

if [[ "$MODE" == "check" ]]; then
  if [[ $((TOTAL_MISSING + TOTAL_ABSENT)) -gt 0 ]]; then
    echo ""
    echo "CHECK FAILED: provides.scripts gap(s) found (run with --write to add missing entries; absent entries are reported only, never auto-removed)"
    exit 1
  else
    echo ""
    echo "CHECK PASSED: provides.scripts matches scripts/ tree exactly for every extension"
    exit 0
  fi
else
  exit 0
fi
