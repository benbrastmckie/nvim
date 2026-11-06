#!/usr/bin/env bash
# gate-store-fixture-lib.sh - Builds a throwaway, path-mirrored copy of the gate source store
# (verify-deploy.sh + lib/ + lint/ + gate-registry.data) with one extra, synthetic gate id
# appended, for a test suite that must prove "registering a gate requires no suite edits"
# without ever touching the REAL scripts/gate-registry.data.
#
# WHY PATH-MIRRORED: verify-deploy.sh resolves ${_VD_SCRIPT_DIR}/gate-registry.data,
# ${_VD_SCRIPT_DIR}/lib/* and ${_VD_SCRIPT_DIR}/../.. (its own REPO_ROOT-style ancestor walk)
# relative to ITSELF, with no env-var override. Copying verify-deploy.sh into an arbitrary flat
# directory would leave those self-relative resolutions pointing nowhere sensible. Copying it
# into a tree shaped like the real one -- <dest_root>/agent-system/extensions/core/scripts/ --
# makes every one of those self-relative resolutions land on a plausible extensions root, with
# no production env-var seam and no change to verify-deploy.sh's own resolution logic.
#
# WHY THE THROWAWAY FUNCTION IS APPENDED TO THE COPIED lib/gate-registry-lib.sh: that library is
# sourced by verify-deploy.sh well before the gate-dispatch loop (`for _gate_id in
# $(gate_registry_ids); do ...`) ever runs. Appending the function there means it is DEFINED
# (and callable) long before dispatch reaches it -- bash function resolution is a call-time
# lookup, so the appended body may freely use say/pass/gate_selected, each already a live
# process-wide function by the time either script's own gate bodies run. This mirrors how a REAL
# gate is added (one gate-registry.data row plus one gateN_run function), without touching
# verify-deploy.sh's own text for the function body.
#
# A SECOND, TEXTUALLY IDENTICAL COPY is ALSO inserted directly into the copied verify-deploy.sh,
# immediately before its gate-dispatch loop. This is required because lint-gate-registry.sh's
# own Check A ("every invoke function is actually defined") greps verify-deploy.sh's text ONLY
# (by that lint's own design -- it never looks at any sourced lib), so a function defined solely
# in lib/gate-registry-lib.sh would not satisfy Check A run against the fixture's
# gate-registry.data. Rather than widen the lint script's own scope (out of this task's
# declared file_scope) or weaken the "cleanly" bar this builder's own callers verify against,
# the fixture carries both: the lib copy is what the dispatch loop actually calls (consistent
# with the rationale above), and the verify-deploy.sh copy is a second, inert, byte-identical
# definition whose only job is to satisfy Check A's static text search. Inserting it before the
# dispatch loop (rather than appending to the file's end) also keeps it syntactically reachable
# before any call, exactly like every real gateN_run already is.
#
# Deliberately does NOT copy tests/ (an 8+ MB tree) -- no caller of this builder needs any real
# suite file, only verify-deploy.sh + lib/ + lint/ + gate-registry.data.
#
# CONTRACT: never calls `exit` (returns 2 on a usage/missing-source error, matching every other
# function in this file family's degrade-safe posture). Sets no shell options on the caller.
#
# Usage: gate_store_fixture_build <dest_root> <extra_id> [gate_name]
#   <dest_root>   Directory to build the fixture store under (created if absent); the fixture's
#                 own path-mirrored tree lands at
#                 <dest_root>/agent-system/extensions/core/scripts/.
#   <extra_id>    The synthetic gate id to append (must never collide with a real registry id).
#   [gate_name]   Human-readable name for the row (default: "Throwaway fixture gate").
#
# Prints the absolute path of the copied verify-deploy.sh on success.

_GSF_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

gate_store_fixture_build() {
  local _gsf_dest_root="${1:-}" _gsf_extra_id="${2:-}" _gsf_name="${3:-Throwaway fixture gate}"
  local _gsf_core_dir _gsf_src_core _gsf_fn_block _gsf_marker

  _gsf_src_core="$_GSF_SELF_DIR"

  if [ -z "$_gsf_dest_root" ] || [ -z "$_gsf_extra_id" ]; then
    echo "ERROR: gate_store_fixture_build: usage: gate_store_fixture_build <dest_root> <extra_id> [gate_name]" >&2
    unset _gsf_dest_root _gsf_extra_id _gsf_name _gsf_core_dir _gsf_src_core _gsf_fn_block _gsf_marker
    return 2
  fi

  if [ ! -f "$_gsf_src_core/verify-deploy.sh" ] || [ ! -f "$_gsf_src_core/gate-registry.data" ] \
     || [ ! -d "$_gsf_src_core/lib" ] || [ ! -d "$_gsf_src_core/lint" ]; then
    echo "ERROR: gate_store_fixture_build: source core scripts tree incomplete at $_gsf_src_core" >&2
    unset _gsf_dest_root _gsf_extra_id _gsf_name _gsf_core_dir _gsf_src_core _gsf_fn_block _gsf_marker
    return 2
  fi

  _gsf_core_dir="$_gsf_dest_root/agent-system/extensions/core/scripts"
  mkdir -p "$_gsf_core_dir"

  cp "$_gsf_src_core/verify-deploy.sh" "$_gsf_core_dir/verify-deploy.sh"
  cp "$_gsf_src_core/gate-registry.data" "$_gsf_core_dir/gate-registry.data"
  cp -R "$_gsf_src_core/lib" "$_gsf_core_dir/lib"
  cp -R "$_gsf_src_core/lint" "$_gsf_core_dir/lint"
  chmod -R u+w "$_gsf_core_dir"

  # Append the one TAB-separated 9-field row for the extra id -- "-" placeholders for
  # dependencies/input_corpus, matching every other free-class, non-serialized, non-source-
  # store-requiring row in the real registry.
  printf '%s\t%s\t%s\t-\tfalse\t30\tfree\tfalse\t-\n' \
    "$_gsf_extra_id" "$_gsf_name" "gate${_gsf_extra_id}_run" \
    >> "$_gsf_core_dir/gate-registry.data"

  # The function body follows gate16_run's exact shape: gate_selected guard, CURRENT_GATE set,
  # header say, pass, trailing blank say.
  _gsf_fn_block="gate${_gsf_extra_id}_run() {
if gate_selected ${_gsf_extra_id}; then
say \"${_gsf_extra_id}. ${_gsf_name}\"
CURRENT_GATE=\"gate${_gsf_extra_id}\"
pass \"${_gsf_name} (fixture)\"
say \"\"
fi
}"

  {
    echo ""
    echo "$_gsf_fn_block"
  } >> "$_gsf_core_dir/lib/gate-registry-lib.sh"

  # Insert the same block, verbatim, into the copied verify-deploy.sh immediately before its
  # gate-dispatch loop -- see this file's header for why both copies exist.
  _gsf_marker='for _gate_id in $(gate_registry_ids); do'
  awk -v marker="$_gsf_marker" -v block="$_gsf_fn_block" '
    $0 == marker { print block; print "" }
    { print }
  ' "$_gsf_core_dir/verify-deploy.sh" > "$_gsf_core_dir/verify-deploy.sh.tmp"
  mv "$_gsf_core_dir/verify-deploy.sh.tmp" "$_gsf_core_dir/verify-deploy.sh"
  chmod u+w "$_gsf_core_dir/verify-deploy.sh"

  printf '%s\n' "$_gsf_core_dir/verify-deploy.sh"
  unset _gsf_dest_root _gsf_extra_id _gsf_name _gsf_core_dir _gsf_src_core _gsf_fn_block _gsf_marker
  return 0
}
