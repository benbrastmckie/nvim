#!/usr/bin/env bash
# test-sapience-tag-pending.sh - Regression suite for sapience-tag-pending.sh: per-record
# [repo:<slug>] provenance tagging of ~/.sapience/pending_kos.jsonl.
#
# Every case runs against a synthetic fixture HOME containing its own .sapience/config.json and
# .sapience/pending_kos.jsonl, plus throwaway `git init` repositories -- no case reads or writes
# the operator's real ~/.sapience/. The script under test is invoked with `env HOME=<fixture>`
# and, where the fixture ledger/config live outside $HOME/.sapience, via its --ledger/--config
# test-only overrides.
#
# Cases:
#   (a) A record whose `project` maps to a resolvable path gets `[repo:<basename-of-toplevel>]`.
#   (b) An entry whose `name` deliberately differs from `basename(path_prefix)` resolves to the
#       BASENAME, not the name -- proving the lookup goes through `path_prefix`.
#   (c) A record originating from a linked worktree resolves to the parent checkout's basename.
#   (d) A record whose `project` has no `capture.projects` entry, and one whose `path_prefix` is
#       not a git repo, are both left untagged and the pass still exits 0.
#   (e) Re-running --write on an already-tagged ledger is a no-op (byte-identical file).
#   (f) A record with a pre-existing non-empty `provenance` has the tag appended, not clobbered.
#   (g) `_hash` and `project` are unchanged on every record and the line count is preserved.
#   (h) The default (no-flag) run leaves the fixture ledger byte-identical.
#   (i) No `pending_kos.jsonl.tmp.*` file survives a successful `--write`.
#   (j) The written file's mode is 0600.
#
# Follows the core shell-test convention: common_test_pass/_fail/_info from lib/common.sh,
# PASSED/FAILED integer counters, a mktemp -d workdir with a trap EXIT cleanup,
# common_test_resolve_subject/common_test_declare_subject source-store-first resolution.
#
# Bootstrap note: this suite lives under the sapience extension but needs core's shared
# lib/common.sh. Post-deploy, every extension's scripts/tests/ and scripts/lib/ are flattened
# into one shared .claude/scripts/ tree; pre-deploy, in a source-store-only checkout, it falls
# back to core's own scripts/lib/common.sh directly.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/../../../core/scripts/lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../../../core/scripts/lib/common.sh"
else
  echo "ERROR: test-sapience-tag-pending.sh cannot locate lib/common.sh at any candidate path" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$COMMON_SH"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "sapience-tag-pending.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/sapience-tag-pending.sh" \
  "$SCRIPT_DIR/../sapience-tag-pending.sh")" || exit 2
common_test_declare_subject "$SCRIPT_UNDER_TEST"

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
# shellcheck disable=SC2329  # invoked indirectly via `trap cleanup EXIT`
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- make_repo <dir> -- a throwaway git repo at <dir> with one empty commit. ---
make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "test"
  git -C "$dir" commit -q --allow-empty -m seed
}

# --- build_fixture -- a fresh <scratch>/.sapience/{config.json,pending_kos.jsonl} pair. Echoes
# the scratch (fixture HOME) root. Caller populates config.json and pending_kos.jsonl itself. ---
build_fixture() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.sapience"
  echo "$scratch"
}

# --- run_tag <fixture_home> [args...] -- invokes the script under test with HOME isolated to
# the given fixture. ---
run_tag() {
  local fixture="$1"; shift
  env HOME="$fixture" bash "$SCRIPT_UNDER_TEST" "$@"
}

# =====================================================================================
# Case (a): a record whose `project` maps to a resolvable path gets [repo:<basename>].
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  make_repo "$FIXTURE/repoA"
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/repoA", "name": "projA", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "projA", "_hash": "h1"}
EOF
  run_tag "$FIXTURE" --write >/dev/null 2>&1
  prov="$(jq -r '.provenance // ""' "$FIXTURE/.sapience/pending_kos.jsonl")"
  expected_slug="$(basename "$FIXTURE/repoA")"
  if [ "$prov" = "[repo:${expected_slug}] session capture via sapience-tag-pending.sh" ]; then
    common_test_pass "(a) resolvable project gets [repo:<basename>]"
  else
    common_test_fail "(a) resolvable project gets [repo:<basename>]" "provenance=$prov"
  fi
}

# =====================================================================================
# Case (b): an entry whose `name` differs from basename(path_prefix) resolves to the BASENAME.
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  make_repo "$FIXTURE/realdirname"
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/realdirname", "name": "totallydifferentname", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "totallydifferentname", "_hash": "h1"}
EOF
  run_tag "$FIXTURE" --write >/dev/null 2>&1
  prov="$(jq -r '.provenance // ""' "$FIXTURE/.sapience/pending_kos.jsonl")"
  if [[ "$prov" == *"[repo:realdirname]"* ]] && [[ "$prov" != *"totallydifferentname"* ]]; then
    common_test_pass "(b) resolution uses basename(path_prefix), not the config's own 'name'"
  else
    common_test_fail "(b) resolution uses basename(path_prefix), not the config's own 'name'" "provenance=$prov"
  fi
}

# =====================================================================================
# Case (c): a record from a linked worktree resolves to the PARENT CHECKOUT's basename.
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  make_repo "$FIXTURE/checkout"
  git -C "$FIXTURE/checkout" worktree add -q "$FIXTURE/wt" -b wtbranch >/dev/null 2>&1
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/wt", "name": "wtproj", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "wtproj", "_hash": "h1"}
EOF
  run_tag "$FIXTURE" --write >/dev/null 2>&1
  prov="$(jq -r '.provenance // ""' "$FIXTURE/.sapience/pending_kos.jsonl")"
  checkout_base="$(basename "$FIXTURE/checkout")"
  if [[ "$prov" == *"[repo:${checkout_base}]"* ]]; then
    common_test_pass "(c) a linked-worktree record resolves to the parent checkout's basename"
  else
    common_test_fail "(c) a linked-worktree record resolves to the parent checkout's basename" "provenance=$prov"
  fi
}

# =====================================================================================
# Case (d): no capture.projects entry, and a non-git path_prefix, are both left untagged;
# the pass still exits 0.
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  mkdir -p "$FIXTURE/notagit"
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/notagit", "name": "projC", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "noentry", "_hash": "h1"}
{"subject": "s2", "predicate": "p", "object_value": "v2", "project": "projC", "_hash": "h2"}
EOF
  out="$(run_tag "$FIXTURE" --write 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(d) unresolvable records (no entry / non-git path_prefix): exit 0"
  else
    common_test_fail "(d) unresolvable records (no entry / non-git path_prefix): exit 0" "rc=$rc out=$out"
  fi
  prov1="$(sed -n '1p' "$FIXTURE/.sapience/pending_kos.jsonl" | jq -r '.provenance // ""')"
  prov2="$(sed -n '2p' "$FIXTURE/.sapience/pending_kos.jsonl" | jq -r '.provenance // ""')"
  if [ -z "$prov1" ] && [ -z "$prov2" ]; then
    common_test_pass "(d) both records left untagged (no map entry; path_prefix not a git repo)"
  else
    common_test_fail "(d) both records left untagged (no map entry; path_prefix not a git repo)" "prov1=$prov1 prov2=$prov2"
  fi
}

# =====================================================================================
# Case (e): re-running --write on an already-tagged ledger is a no-op (byte-identical file).
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  make_repo "$FIXTURE/repoE"
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/repoE", "name": "projE", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "projE", "_hash": "h1"}
EOF
  run_tag "$FIXTURE" --write >/dev/null 2>&1
  cp "$FIXTURE/.sapience/pending_kos.jsonl" "$TOP_WORKDIR/after_first_write.jsonl"
  run_tag "$FIXTURE" --write >/dev/null 2>&1
  if cmp -s "$FIXTURE/.sapience/pending_kos.jsonl" "$TOP_WORKDIR/after_first_write.jsonl"; then
    common_test_pass "(e) re-running --write on an already-tagged ledger is byte-identical (idempotent)"
  else
    common_test_fail "(e) re-running --write on an already-tagged ledger is byte-identical (idempotent)"
  fi
}

# =====================================================================================
# Case (f): a record with a pre-existing non-empty provenance has the tag APPENDED, not
# clobbered.
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  make_repo "$FIXTURE/repoF"
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/repoF", "name": "projF", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "projF", "_hash": "h1", "provenance": "a vendor-authored note"}
EOF
  run_tag "$FIXTURE" --write >/dev/null 2>&1
  prov="$(jq -r '.provenance // ""' "$FIXTURE/.sapience/pending_kos.jsonl")"
  slug="$(basename "$FIXTURE/repoF")"
  if [ "$prov" = "a vendor-authored note [repo:${slug}]" ]; then
    common_test_pass "(f) a pre-existing non-empty provenance has the tag appended, not clobbered"
  else
    common_test_fail "(f) a pre-existing non-empty provenance has the tag appended, not clobbered" "provenance=$prov"
  fi
}

# =====================================================================================
# Case (g): _hash and project are unchanged on every record and the line count is preserved.
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  make_repo "$FIXTURE/repoG"
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/repoG", "name": "projG", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "projG", "_hash": "h1"}
{"subject": "s2", "predicate": "p", "object_value": "v2", "project": "projG", "_hash": "h2"}
{"subject": "s3", "predicate": "p", "object_value": "v3", "project": "unmapped", "_hash": "h3"}
EOF
  cp "$FIXTURE/.sapience/pending_kos.jsonl" "$TOP_WORKDIR/before_g.jsonl"
  run_tag "$FIXTURE" --write >/dev/null 2>&1
  lines_before="$(wc -l < "$TOP_WORKDIR/before_g.jsonl")"
  lines_after="$(wc -l < "$FIXTURE/.sapience/pending_kos.jsonl")"
  hashes_ok="true"
  projects_ok="true"
  i=1
  while [ "$i" -le "$lines_before" ]; do
    hb="$(sed -n "${i}p" "$TOP_WORKDIR/before_g.jsonl" | jq -r '._hash')"
    ha="$(sed -n "${i}p" "$FIXTURE/.sapience/pending_kos.jsonl" | jq -r '._hash')"
    pb="$(sed -n "${i}p" "$TOP_WORKDIR/before_g.jsonl" | jq -r '.project')"
    pa="$(sed -n "${i}p" "$FIXTURE/.sapience/pending_kos.jsonl" | jq -r '.project')"
    [ "$hb" = "$ha" ] || hashes_ok="false"
    [ "$pb" = "$pa" ] || projects_ok="false"
    i=$((i + 1))
  done
  if [ "$lines_before" = "$lines_after" ]; then
    common_test_pass "(g) line count preserved"
  else
    common_test_fail "(g) line count preserved" "before=$lines_before after=$lines_after"
  fi
  if [ "$hashes_ok" = "true" ]; then
    common_test_pass "(g) _hash unchanged on every record"
  else
    common_test_fail "(g) _hash unchanged on every record"
  fi
  if [ "$projects_ok" = "true" ]; then
    common_test_pass "(g) project unchanged on every record"
  else
    common_test_fail "(g) project unchanged on every record"
  fi
}

# =====================================================================================
# Case (h): the default (no-flag) run leaves the fixture ledger byte-identical.
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  make_repo "$FIXTURE/repoH"
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/repoH", "name": "projH", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "projH", "_hash": "h1"}
EOF
  cp "$FIXTURE/.sapience/pending_kos.jsonl" "$TOP_WORKDIR/before_h.jsonl"
  out="$(run_tag "$FIXTURE" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(h) default (no-flag) run exits 0"
  else
    common_test_fail "(h) default (no-flag) run exits 0" "rc=$rc out=$out"
  fi
  if cmp -s "$FIXTURE/.sapience/pending_kos.jsonl" "$TOP_WORKDIR/before_h.jsonl"; then
    common_test_pass "(h) default (no-flag) run leaves the fixture ledger byte-identical"
  else
    common_test_fail "(h) default (no-flag) run leaves the fixture ledger byte-identical"
  fi
}

# =====================================================================================
# Case (i): no pending_kos.jsonl.tmp.* file survives a successful --write.
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  make_repo "$FIXTURE/repoI"
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/repoI", "name": "projI", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "projI", "_hash": "h1"}
EOF
  run_tag "$FIXTURE" --write >/dev/null 2>&1
  leftover="$(find "$FIXTURE/.sapience" -maxdepth 1 -name 'pending_kos.jsonl.tmp.*' 2>/dev/null)"
  if [ -z "$leftover" ]; then
    common_test_pass "(i) no pending_kos.jsonl.tmp.* file survives a successful --write"
  else
    common_test_fail "(i) no pending_kos.jsonl.tmp.* file survives a successful --write" "found: $leftover"
  fi
}

# =====================================================================================
# Case (j): the written file's mode is 0600.
# =====================================================================================
{
  FIXTURE="$(build_fixture)"
  make_repo "$FIXTURE/repoJ"
  cat > "$FIXTURE/.sapience/config.json" <<EOF
{"capture": {"projects": [{"path_prefix": "$FIXTURE/repoJ", "name": "projJ", "enabled": true}]}}
EOF
  cat > "$FIXTURE/.sapience/pending_kos.jsonl" <<'EOF'
{"subject": "s1", "predicate": "p", "object_value": "v1", "project": "projJ", "_hash": "h1"}
EOF
  chmod 0644 "$FIXTURE/.sapience/pending_kos.jsonl"
  run_tag "$FIXTURE" --write >/dev/null 2>&1
  mode="$(stat -c '%a' "$FIXTURE/.sapience/pending_kos.jsonl" 2>/dev/null)"
  if [ "$mode" = "600" ]; then
    common_test_pass "(j) the written file's mode is 0600"
  else
    common_test_fail "(j) the written file's mode is 0600" "mode=$mode"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
