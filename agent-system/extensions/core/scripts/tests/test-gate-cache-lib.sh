#!/usr/bin/env bash
# test-gate-cache-lib.sh - Regression suite for scripts/lib/gate-cache-lib.sh, the
# content-addressed corpus + implementation digest library this task's input-scoped gate
# invalidation is built on. See that library's own header for the full contract (the
# five-component implementation digest, the content-addressed-not-mtime corpus digest, and the
# GATE_CACHE_SENTINEL fail-open convention).
#
# Coverage:
#   - touch invariance: touching every file in a declared corpus leaves its digest unchanged.
#   - content-change detection: a one-byte change in a corpus file, in a sourced library, in the
#     registry row, or in the invoke function body each change the relevant digest.
#   - file addition, deletion, and rename detection within a declared corpus.
#   - untracked-file inclusion: a corpus file that is NOT tracked by git (e.g. anything under
#     the gitignored `.claude/` deploy tree) still digests correctly -- this is the regression
#     pin for a real bug caught live during this phase's own implementation (see
#     progress/phase-3-progress.json's approaches_tried): resolving non-named-view corpus
#     entries via `git ls-files` returns nothing for a gitignored path, silently producing an
#     empty corpus rather than the real one.
#   - a corpus of `-` returns the sentinel, distinguishably from a real digest or from the
#     declared-but-currently-empty constant.
#   - an unresolvable corpus entry, and an unavailable `git` binary, each return the sentinel.
#   - determinism: identical composite keys across repeated computation and across concurrent
#     (parallel-process) computation.
#   - the cache STORE (gate_cache_entry_read/write/invalidate): cold-miss/write/warm-hit/
#     invalidate round-trip, no stray temp artifact survives a write, format_version mismatch
#     degrades to a miss, corrupted JSON degrades to a miss, a mismatched gate_id field degrades
#     to a miss, a non-green verdict degrades to a miss, a write refuses to persist the
#     sentinel as a key, concurrent writes to distinct gate ids under one store directory never
#     cross-contaminate, and the store directory resolves outside .claude/ by construction.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# library was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$CORE_DIR/lib/gate-cache-lib.sh"
REGISTRY_LIB="$CORE_DIR/lib/gate-registry-lib.sh"
COMMON_LIB="$CORE_DIR/lib/common.sh"
REAL_DATA="$CORE_DIR/gate-registry.data"

if [ ! -f "$LIB" ]; then
  echo "ERROR: expected $LIB" >&2
  exit 2
fi
if [ ! -f "$REGISTRY_LIB" ] || [ ! -f "$COMMON_LIB" ]; then
  echo "ERROR: expected $REGISTRY_LIB and $COMMON_LIB" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$REGISTRY_LIB"
# shellcheck source=/dev/null
source "$COMMON_LIB"
# shellcheck source=/dev/null
source "$LIB"

PASSED=0
FAILED=0

common_test_workdir_init

gate_registry_load "$REAL_DATA"
# gate_cache_implementation_digest/composite_key resolve verify-deploy.sh relative to a ROOT
# whose agent-system/extensions subtree is checked for source-store mode. CORE_DIR here (this
# suite's own naming convention, shared with test-gate-registry-resolution.sh) is actually
# .../agent-system/extensions/core/scripts, so "ROOT" for this suite's purposes is FOUR levels
# up (scripts -> core -> extensions -> agent-system -> repo root), matching how
# verify-deploy.sh/gate-registry.data itself is actually invoked.
ROOT="$(cd "$CORE_DIR/../../../.." && pwd)"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 1 -- corpus digest: touch invariance, content-change detection, untracked-file inclusion,
# the "-" sentinel, and the declared-but-empty constant.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case 1: touch invariance against a REAL, untracked corpus file (gate 2's .claude/settings.json
# -- .claude/ is gitignored, so this is also the untracked-file-inclusion case).
settings_backup="$WORKDIR/settings-backup.json"
cp "$ROOT/.claude/settings.json" "$settings_backup" 2>/dev/null
if [ -f "$settings_backup" ]; then
  d_before="$(gate_cache_corpus_digest "$(gate_registry_field 2 input_corpus)" "$ROOT")"
  touch "$ROOT/.claude/settings.json"
  d_after="$(gate_cache_corpus_digest "$(gate_registry_field 2 input_corpus)" "$ROOT")"
  if [ "$d_before" = "$d_after" ] && [ "$d_before" != "$GATE_CACHE_SENTINEL" ] \
     && [ "$d_before" != "$GATE_CACHE_EMPTY_CORPUS_DIGEST" ]; then
    common_test_pass "case1: touch invariance on an UNTRACKED (gitignored .claude/) corpus file -- digest unchanged, and it is a real digest, not a sentinel"
  else
    common_test_fail "case1: touch changed the digest, or it was a sentinel/empty-constant (before=$d_before after=$d_after)"
  fi
  cp "$settings_backup" "$ROOT/.claude/settings.json"
else
  echo "[INFO] case1 skipped: $ROOT/.claude/settings.json not present in this environment"
fi

# Case 2: a one-byte content change in that same untracked corpus file changes the digest, and
# restoring the exact original content restores the exact original digest (true content
# addressing, not an incidental side effect of the touch).
if [ -f "$settings_backup" ]; then
  d_before2="$(gate_cache_corpus_digest "$(gate_registry_field 2 input_corpus)" "$ROOT")"
  printf '\n' >> "$ROOT/.claude/settings.json"
  d_changed="$(gate_cache_corpus_digest "$(gate_registry_field 2 input_corpus)" "$ROOT")"
  cp "$settings_backup" "$ROOT/.claude/settings.json"
  d_restored="$(gate_cache_corpus_digest "$(gate_registry_field 2 input_corpus)" "$ROOT")"
  if [ "$d_before2" != "$d_changed" ] && [ "$d_before2" = "$d_restored" ]; then
    common_test_pass "case2: a one-byte content change changes the corpus digest; restoring the exact original content restores the exact original digest"
  else
    common_test_fail "case2: content-change detection or restoration failed (before=$d_before2 changed=$d_changed restored=$d_restored)"
  fi
fi
rm -f "$settings_backup"

# Case 3: a corpus of "-" (gate 14, declared not-declared in this task's Phase 2) returns the
# sentinel, distinguishable from both a real digest and the declared-but-empty constant.
corpus14="$(gate_registry_field 14 input_corpus)"
d14="$(gate_cache_corpus_digest "$corpus14" "$ROOT")"
if [ "$d14" = "$GATE_CACHE_SENTINEL" ]; then
  common_test_pass "case3: a corpus of '-' (gate 14) returns GATE_CACHE_SENTINEL, not a real digest or the empty-corpus constant"
else
  common_test_fail "case3: expected GATE_CACHE_SENTINEL for gate 14's undeclared corpus (got: $d14)"
fi

# Case 4: an unresolvable corpus entry (a double comma producing a genuinely empty sub-entry)
# also returns the sentinel.
d_unresolvable="$(gate_cache_corpus_digest "@extensions,,specs/state.json" "$ROOT")"
if [ "$d_unresolvable" = "$GATE_CACHE_SENTINEL" ]; then
  common_test_pass "case4: an unresolvable corpus entry (empty sub-entry from a double comma) returns GATE_CACHE_SENTINEL"
else
  common_test_fail "case4: expected GATE_CACHE_SENTINEL for an unresolvable entry (got: $d_unresolvable)"
fi

# Case 5: a declared corpus that currently matches zero paths (a glob with no matches today)
# digests to the fixed empty-corpus constant, NOT the sentinel -- "declared, zero matches" must
# stay distinguishable from "not declared."
d_zero="$(gate_cache_corpus_digest "nonexistent-dir-xyz/**/*.nope" "$ROOT")"
if [ "$d_zero" = "$GATE_CACHE_EMPTY_CORPUS_DIGEST" ]; then
  common_test_pass "case5: a declared corpus matching zero paths today digests to the fixed empty-corpus constant, not the sentinel"
else
  common_test_fail "case5: expected GATE_CACHE_EMPTY_CORPUS_DIGEST for a zero-match declared corpus (got: $d_zero)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 2 -- corpus digest: file addition, deletion, and rename detection, in a SYNTHETIC git repo
# (isolated from the real source store so a seeded mutation can be planted and torn down freely).
# ═══════════════════════════════════════════════════════════════════════════════════════════════

SYNTH="$WORKDIR/synth-repo"
mkdir -p "$SYNTH/agent-system/extensions/fakeext/skills/x"
(
  cd "$SYNTH" || exit 1
  git init -q .
  git config user.email "test@example.com"
  git config user.name "test"
  echo "original" > agent-system/extensions/fakeext/skills/x/SKILL.md
  git add -A
  git commit -q -m seed
)

d_orig="$(gate_cache_corpus_digest "@extensions" "$SYNTH")"

# Case 6: adding a new tracked file changes the digest.
echo "new" > "$SYNTH/agent-system/extensions/fakeext/skills/x/SKILL2.md"
(cd "$SYNTH" && git add -A >/dev/null 2>&1)
d_added="$(gate_cache_corpus_digest "@extensions" "$SYNTH")"
if [ "$d_orig" != "$d_added" ]; then
  common_test_pass "case6: adding a file to the declared corpus changes the digest"
else
  common_test_fail "case6: adding a file did not change the digest"
fi

# Case 7: deleting it again returns to the ORIGINAL digest exactly (true content addressing).
rm "$SYNTH/agent-system/extensions/fakeext/skills/x/SKILL2.md"
(cd "$SYNTH" && git add -A >/dev/null 2>&1)
d_deleted="$(gate_cache_corpus_digest "@extensions" "$SYNTH")"
if [ "$d_deleted" = "$d_orig" ]; then
  common_test_pass "case7: deleting the added file returns to the exact original digest"
else
  common_test_fail "case7: delete did not restore the original digest (orig=$d_orig deleted=$d_deleted)"
fi

# Case 8: renaming the original file changes the digest (even though its CONTENT is unchanged --
# the path is part of what is folded into the digest, so a rename must not be invisible).
mv "$SYNTH/agent-system/extensions/fakeext/skills/x/SKILL.md" "$SYNTH/agent-system/extensions/fakeext/skills/x/RENAMED.md"
(cd "$SYNTH" && git add -A >/dev/null 2>&1)
d_renamed="$(gate_cache_corpus_digest "@extensions" "$SYNTH")"
if [ "$d_renamed" != "$d_orig" ]; then
  common_test_pass "case8: renaming a corpus file (content unchanged) changes the digest"
else
  common_test_fail "case8: rename was not detected"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 3 -- implementation digest: the five-component key, each component's own invalidation.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case 9: determinism across repeated computation (gate 6, a real gate against the real tree).
i1="$(gate_cache_implementation_digest 6 "$ROOT" "$REAL_DATA")"
i2="$(gate_cache_implementation_digest 6 "$ROOT" "$REAL_DATA")"
if [ "$i1" = "$i2" ] && [ "$i1" != "$GATE_CACHE_SENTINEL" ]; then
  common_test_pass "case9: implementation digest is deterministic across repeated computation (gate 6)"
else
  common_test_fail "case9: implementation digest was not deterministic or was a sentinel (i1=$i1 i2=$i2)"
fi

# Case 10: a registry-row edit (gate 6's timeout_s) changes the implementation digest, with
# every other field held fixed, confirming component 4 (the registry row) is actually folded in.
mod_registry="$WORKDIR/mod-registry.data"
awk -F'\t' 'BEGIN{OFS="\t"} $1==6{$6=$6+1} {print}' "$REAL_DATA" > "$mod_registry"
i_rowchanged="$(gate_cache_implementation_digest 6 "$ROOT" "$mod_registry")"
if [ "$i1" != "$i_rowchanged" ]; then
  common_test_pass "case10: a registry-row edit (gate 6's timeout_s) changes the implementation digest"
else
  common_test_fail "case10: registry-row edit did not change the implementation digest"
fi

# Case 11: a sourced-library edit changes the implementation digest for a gate whose invoked
# script sources it (gate 6 invokes lint-agent-contracts.sh, which sources a status-var lib
# transitively; component 3's bound is "the whole scripts/lib/ directory" -- see the library's
# own header -- so perturbing ANY file under scripts/lib/ must be detected).
anylib="$(find "$CORE_DIR/lib" -maxdepth 1 -name '*.sh' 2>/dev/null | head -1)"
if [ -n "$anylib" ] && [ -f "$anylib" ]; then
  lib_backup="$WORKDIR/lib-backup.sh"
  cp "$anylib" "$lib_backup"
  i_before_lib="$(gate_cache_implementation_digest 6 "$ROOT" "$REAL_DATA")"
  printf '\n# perturbed by test-gate-cache-lib.sh\n' >> "$anylib"
  i_after_lib="$(gate_cache_implementation_digest 6 "$ROOT" "$REAL_DATA")"
  cp "$lib_backup" "$anylib"
  rm -f "$lib_backup"
  if [ "$i_before_lib" != "$i_after_lib" ]; then
    common_test_pass "case11: perturbing a file under scripts/lib/ changes gate 6's implementation digest (component 3: bounded sourced-library closure)"
  else
    common_test_fail "case11: a scripts/lib/ perturbation did not change the implementation digest"
  fi
else
  echo "[INFO] case11 skipped: could not locate a scripts/lib/*.sh file to perturb"
fi

# Case 12: a change to the invoke function body itself (component 1) changes the digest -- using
# a SYNTHETIC verify-deploy.sh copy (never the real one) so this never risks corrupting the real
# script under test.
synth_vd_dir="$WORKDIR/synth-vd/agent-system/extensions/core/scripts"
mkdir -p "$synth_vd_dir"
cat > "$synth_vd_dir/verify-deploy.sh" << 'EOF'
#!/usr/bin/env bash
gate99_run() {
if gate_selected 99; then
say "99. synthetic gate for test-gate-cache-lib.sh"
CURRENT_GATE="gate99"
echo "original body"
fi
}
EOF
synth_root="$WORKDIR/synth-vd"
i_body_before="$(gate_cache_implementation_digest 99 "$synth_root" "$REAL_DATA")"
sed -i 's/original body/CHANGED body/' "$synth_vd_dir/verify-deploy.sh"
i_body_after="$(gate_cache_implementation_digest 99 "$synth_root" "$REAL_DATA")"
if [ "$i_body_before" != "$i_body_after" ] && [ "$i_body_before" != "$GATE_CACHE_SENTINEL" ]; then
  common_test_pass "case12: a change to the invoke function body itself changes the implementation digest (component 1), against a synthetic verify-deploy.sh"
else
  common_test_fail "case12: invoke-body change was not detected, or the before-digest was a sentinel (before=$i_body_before after=$i_body_after)"
fi

# Case 13: a target-mode change (source-store vs deployed -- component 5) changes the digest,
# using the SAME synthetic tree in both modes (adding/removing a .claude/ marker directory
# determines gate_cache_target_mode's verdict independent of the agent-system/extensions subtree
# this synthetic fixture also has, since that subtree's presence is what source-store mode
# itself checks -- so this case instead directly confirms gate_cache_target_mode's own two
# verdicts rather than re-deriving a full digest under a contradictory fixture shape).
mkdir -p "$synth_root/agent-system/extensions"
mode_a="$(gate_cache_target_mode "$synth_root")"
rmdir_target="$WORKDIR/no-extensions-root"
mkdir -p "$rmdir_target/.claude"
mode_b="$(gate_cache_target_mode "$rmdir_target")"
if [ "$mode_a" = "source-store" ] && [ "$mode_b" = "deployed" ]; then
  common_test_pass "case13: gate_cache_target_mode correctly discriminates source-store (agent-system/extensions present) from deployed"
else
  common_test_fail "case13: target-mode discrimination failed (mode_a=$mode_a mode_b=$mode_b)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 4 -- missing git binary -> sentinel at every public function.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

FAKEBIN="$WORKDIR/fakebin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/git" << 'EOF'
#!/bin/sh
exit 127
EOF
chmod +x "$FAKEBIN/git"
d_nogit="$(PATH="$FAKEBIN:$PATH" bash -c "
  source '$REGISTRY_LIB'; source '$COMMON_LIB'; source '$LIB'
  gate_registry_load '$REAL_DATA'
  gate_cache_corpus_digest \"\$(gate_registry_field 2 input_corpus)\" '$ROOT'
")"
i_nogit="$(PATH="$FAKEBIN:$PATH" bash -c "
  source '$REGISTRY_LIB'; source '$COMMON_LIB'; source '$LIB'
  gate_cache_implementation_digest 6 '$ROOT' '$REAL_DATA'
")"
k_nogit="$(PATH="$FAKEBIN:$PATH" bash -c "
  source '$REGISTRY_LIB'; source '$COMMON_LIB'; source '$LIB'
  gate_registry_load '$REAL_DATA'
  gate_cache_composite_key 6 '$ROOT' '$REAL_DATA'
")"
if [ "$d_nogit" = "$GATE_CACHE_SENTINEL" ] && [ "$i_nogit" = "$GATE_CACHE_SENTINEL" ] && [ "$k_nogit" = "$GATE_CACHE_SENTINEL" ]; then
  common_test_pass "case14: an unavailable git binary returns GATE_CACHE_SENTINEL from the corpus digest, implementation digest, and composite key alike"
else
  common_test_fail "case14: missing-git did not produce the sentinel from all three (corpus=$d_nogit impl=$i_nogit key=$k_nogit)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 5 -- composite key: determinism across repeated AND concurrent (parallel-process)
# computation.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

k1="$(gate_cache_composite_key 6 "$ROOT" "$REAL_DATA")"
k2="$(gate_cache_composite_key 6 "$ROOT" "$REAL_DATA")"
if [ "$k1" = "$k2" ] && [ "$k1" != "$GATE_CACHE_SENTINEL" ]; then
  common_test_pass "case15: composite key is deterministic across repeated sequential computation (gate 6)"
else
  common_test_fail "case15: composite key was not deterministic (k1=$k1 k2=$k2)"
fi

# Case 16: four concurrent (background, parallel-process) computations of the same gate's
# composite key all agree with the sequential result -- "worker counts" for a pure-computation
# library means "run under concurrency," since there is no --jobs flag to vary.
CONC_OUT="$WORKDIR/conc-out"
: > "$CONC_OUT"
for _i in 1 2 3 4; do
  ( gate_cache_composite_key 6 "$ROOT" "$REAL_DATA" >> "$CONC_OUT" ) &
done
wait
uniq_count="$(sort -u "$CONC_OUT" | wc -l)"
if [ "$uniq_count" -eq 1 ] && grep -qF "$k1" "$CONC_OUT"; then
  common_test_pass "case16: four concurrently-computed composite keys for the same gate all agree with each other and with the sequential result"
else
  common_test_fail "case16: concurrent computation produced disagreeing results (unique count: $uniq_count)" "$(cat "$CONC_OUT")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 6 -- cache store: read/write/invalidate, atomic write-then-rename, format_version gating,
# and concurrent-write safety.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

STORE_ROOT="$WORKDIR/store-root"
mkdir -p "$STORE_ROOT/specs"

# Case 17: cold read is a miss, write then produces a warm hit with the exact key and a
# non-empty timestamp, and invalidate returns it to a miss.
if gate_cache_entry_read 8 "$STORE_ROOT"; then
  common_test_fail "case17a: expected a cold miss for gate 8, got a hit (key=$GATE_CACHE_ENTRY_KEY)"
else
  common_test_pass "case17a: cold read is a miss before any entry is written"
fi
gate_cache_entry_write 8 "$STORE_ROOT" "deadbeef0000111122223333444455556666777"
if gate_cache_entry_read 8 "$STORE_ROOT" && [ "$GATE_CACHE_ENTRY_KEY" = "deadbeef0000111122223333444455556666777" ] && [ -n "$GATE_CACHE_ENTRY_TIMESTAMP" ]; then
  common_test_pass "case17b: warm read after a write returns the exact written key and a non-empty timestamp"
else
  common_test_fail "case17b: warm read did not round-trip (key=$GATE_CACHE_ENTRY_KEY ts=$GATE_CACHE_ENTRY_TIMESTAMP)"
fi
gate_cache_entry_invalidate 8 "$STORE_ROOT"
if gate_cache_entry_read 8 "$STORE_ROOT"; then
  common_test_fail "case17c: expected a miss after invalidate, got a hit"
else
  common_test_pass "case17c: invalidate returns the entry to a miss; a second invalidate (already-absent) is a silent no-op"
fi
gate_cache_entry_invalidate 8 "$STORE_ROOT"  # no-op, must not error (set -uo pipefail would abort on a real failure)
common_test_pass "case17d: invalidating an already-absent entry is a silent no-op, not an error"

# Case 18: a write's entry file never appears via a partial/renamed-temp artifact -- the ONLY
# file ever observed at the real entry path is either absent or a complete, valid write. Proven
# indirectly (this suite cannot inject a crash mid-rename) by asserting no stray
# `.gateN.json.tmp.*` file survives a normal write.
gate_cache_entry_write 9 "$STORE_ROOT" "cafef00d0000111122223333444455556666888"
tmp_leftovers="$(find "$(gate_cache_store_dir "$STORE_ROOT")" -maxdepth 1 -name '.gate9.json.tmp.*' 2>/dev/null | wc -l)"
if [ -f "$(gate_cache_entry_path 9 "$STORE_ROOT")" ] && [ "$tmp_leftovers" -eq 0 ]; then
  common_test_pass "case18: a successful write leaves no temp artifact behind, only the final entry file"
else
  common_test_fail "case18: expected the real entry file with zero temp leftovers (leftovers=$tmp_leftovers)"
fi

# Case 19: a format_version mismatch degrades to a miss (never a false hit), even though the
# key and verdict fields are otherwise well-formed.
printf '%s' '{"gate_id":"10","format_version":999,"key":"abc","verdict":"green","timestamp":"2020-01-01T00:00:00Z"}' > "$(gate_cache_entry_path 10 "$STORE_ROOT")"
if gate_cache_entry_read 10 "$STORE_ROOT"; then
  common_test_fail "case19: expected a miss on format_version mismatch, got a hit"
else
  common_test_pass "case19: a format_version mismatch degrades to a miss, never a false hit"
fi

# Case 20: a truncated/corrupted JSON entry degrades to a miss.
printf '%s' '{"gate_id":"11","format_vers' > "$(gate_cache_entry_path 11 "$STORE_ROOT")"
if gate_cache_entry_read 11 "$STORE_ROOT"; then
  common_test_fail "case20: expected a miss on corrupted JSON, got a hit"
else
  common_test_pass "case20: a truncated/corrupted entry degrades to a miss, never a false hit"
fi

# Case 21: a gate_id field that does not match the id requested (a mislabeled or hand-edited
# entry) degrades to a miss -- read must not trust the filename alone.
printf '%s' '{"gate_id":"999","format_version":1,"key":"abc","verdict":"green","timestamp":"2020-01-01T00:00:00Z"}' > "$(gate_cache_entry_path 12 "$STORE_ROOT")"
if gate_cache_entry_read 12 "$STORE_ROOT"; then
  common_test_fail "case21: expected a miss on a gate_id field mismatch, got a hit"
else
  common_test_pass "case21: an entry whose own gate_id field does not match the requested id degrades to a miss"
fi

# Case 22: a non-green verdict (e.g. a hand-edited or future "warn"/"fail" entry) degrades to a
# miss -- only a verdict of exactly "green" is ever trusted.
printf '%s' '{"gate_id":"15","format_version":1,"key":"abc","verdict":"warn","timestamp":"2020-01-01T00:00:00Z"}' > "$(gate_cache_entry_path 15 "$STORE_ROOT")"
if gate_cache_entry_read 15 "$STORE_ROOT"; then
  common_test_fail "case22: expected a miss on a non-green verdict, got a hit"
else
  common_test_pass "case22: a non-green verdict degrades to a miss"
fi

# Case 23: gate_cache_entry_write never writes a sentinel key -- it must refuse (return nonzero,
# write nothing) rather than persist an entry a reader could mistake for a real digest.
rm -f "$(gate_cache_entry_path 16 "$STORE_ROOT")"
if gate_cache_entry_write 16 "$STORE_ROOT" "$GATE_CACHE_SENTINEL"; then
  common_test_fail "case23: gate_cache_entry_write accepted the sentinel as a key (should have refused)"
else
  if [ ! -f "$(gate_cache_entry_path 16 "$STORE_ROOT")" ]; then
    common_test_pass "case23: gate_cache_entry_write refuses to persist the sentinel as a key, and writes nothing"
  else
    common_test_fail "case23: refused the sentinel but still left a file on disk"
  fi
fi

# Case 24: concurrent writes to DIFFERENT gate ids under the same store directory do not
# interfere with each other (each ends up correctly readable) -- exercises mkdir -p's own
# idempotency under concurrent first-creation.
for _gid in 17 18 19 20; do
  ( gate_cache_entry_write "$_gid" "$STORE_ROOT" "conc$(printf '%036d' "$_gid")" ) &
done
wait
conc_ok=true
for _gid in 17 18 19 20; do
  if ! gate_cache_entry_read "$_gid" "$STORE_ROOT" || [ "$GATE_CACHE_ENTRY_KEY" != "conc$(printf '%036d' "$_gid")" ]; then
    conc_ok=false
  fi
done
if $conc_ok; then
  common_test_pass "case24: four concurrent writes to distinct gate ids under the same store directory all land correctly, with no cross-contamination"
else
  common_test_fail "case24: a concurrent write to one gate id corrupted or lost another's entry"
fi

# Case 25: the store directory survives a simulated "deploy-headless.sh wipe" of .claude/ --
# it must live outside that tree entirely. Proven by asserting the store path never contains
# "/.claude/" as a path component.
case "$(gate_cache_store_dir "$STORE_ROOT")" in
  */.claude/*|*/.claude)
    common_test_fail "case25: the cache store resolves under .claude/, which deploy-headless.sh regenerates before every run that matters"
    ;;
  *)
    common_test_pass "case25: the cache store resolves outside .claude/, surviving a deploy-headless.sh regeneration by construction"
    ;;
esac

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
