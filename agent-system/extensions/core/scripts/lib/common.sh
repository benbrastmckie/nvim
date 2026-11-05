#!/usr/bin/env bash
# common.sh - Single source of truth for the repo-root-resolution, session-ID, timestamp,
# logging, and test-helper boilerplate previously duplicated across dozens of core scripts.
#
# Sourced (never executed) by scripts at multiple directory depths under
# agent-system/extensions/core/scripts/ (scripts/ itself, scripts/lib/, scripts/tests/,
# scripts/lint/) -- see context/standards/shell-strict-mode.md and the per-file consumer list
# below, updated as each migration phase lands.
#
# CONTRACT (mirrors scripts/lib/manifest-routing-lib.sh's own contract verbatim):
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior. A consumer's own
#     `set -euo pipefail` (or lack thereof) is completely unaffected by sourcing this file.
#   - Every internal variable is prefixed `_common_` and is explicitly unset before each function
#     returns (on top of already being `local`), so sourcing this file never leaks state into the
#     calling shell's environment.
#   - A miss is signalled by empty stdout (or a safe/inert default), never by a non-zero exit
#     status -- every function below always returns 0.
#   - Never calls `exit` -- a faulty resolution at worst leaves the caller with an empty string
#     or a no-op; this library only ever returns 0.
#
# FORBID LOCAL REDEFINITION: a consumer that sources this file MUST NOT define its own copy of
# any function this library provides (common_repo_root, common_session_id,
# common_timestamp_iso/_epoch/_date, common_log_error/_warn/_info, common_test_pass/_fail/_info,
# common_test_repo_root, common_test_resolve_candidate, common_test_workdir_init,
# common_shared_corpus_available, common_shared_corpus_files).
# A local redefinition silently shadows the shared implementation and defeats the single-source
# guarantee this library exists to provide. In particular, a test suite that sources this file
# MUST NOT also define its own `pass()`/`fail()`/`info()` -- call `common_test_pass`/
# `common_test_fail`/`common_test_info` directly at each call site instead of reimplementing the
# trio under the shorter names.
#
# SCRIPT_DIR bootstrap stays inline at each consumer -- it is required to locate this file itself
# (`source "${SCRIPT_DIR}/lib/common.sh"`) and is NOT a duplication this library removes. What
# this library replaces is everything that follows that bootstrap line.
#
# NON-GOALS (deliberate, see the task's plan Non-Goals section):
#   - common_log_error/_warn/_info are plain, side-effect-free emitters. They do NOT replace
#     validate-artifact.sh's counter-incrementing log_error, lint-routing-wiring.sh's
#     verbose-gated log_error, or lint-agent-contracts.sh's colorized/counter-incrementing
#     variant -- those are semantically divergent by design and mass-migrating them is out of
#     scope. Only sites whose semantics exactly match the plain trio here may migrate,
#     opportunistically.
#   - common_test_pass/_fail/_info are core-local, matching
#     context/standards/shell-script-testing.md's documented PASSED/FAILED trio exactly. A
#     sibling extension's own `t_pass`/`t_fail` style remains valid there and is not superseded.
#   - common_repo_root does not replace lint-agent-contracts.sh's deliberately different
#     `git rev-parse --show-toplevel` + `REPO_ROOT` env-override strategy; common_test_repo_root
#     (below) is the new, test-suite-scoped function that DOES try that strategy first, and is
#     the one to use from a new test suite.
#
# Usage (production script, repo-root + logging only):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/common.sh"
#   PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"     # scripts/ callers: 2 levels up
#   session_id="$(common_session_id)"
#   ts="$(common_timestamp_iso)"
#   common_log_info "starting up"
#
# Usage (a NEW test suite under scripts/tests/ -- the required structural model; see
# context/standards/shell-script-testing.md's "Required structural model for a new suite"
# section):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/../lib/common.sh"
#   REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"              # git-aware, 5-level fallback
#   SCRIPT_UNDER_TEST="$(common_test_resolve_candidate "some-script.sh" \
#     "$REPO_ROOT/.claude/scripts/some-script.sh" \
#     "$SCRIPT_DIR/../some-script.sh")" || exit 2
#   PASSED=0; FAILED=0
#   common_test_workdir_init                      # sets $WORKDIR + EXIT trap; call bare, never
#                                                  # via $(...) -- see the function's own header
#   common_test_pass "case description"                              # increments caller's PASSED
#   common_test_fail "case description"                              # increments caller's FAILED
#   common_test_info "diagnostic note"                                # uncounted
#
# .md consumers (commands/*.md, skills/*/SKILL.md): a bash block that needs a session ID uses
# the CWD-relative deployed-path idiom already used by 138+ .md files in this codebase --
#     source .claude/scripts/lib/common.sh
#     session_id="$(common_session_id)"
# executed from the repo root, never a source-store-relative path (a .md bash block has no
# SCRIPT_DIR of its own to bootstrap from). Preserve each site's existing variable name
# (session_id, batch_session_id, todo_session_id, ...) when migrating an inline generator to this
# idiom -- do not rename in passing. This is the single source-of-truth fix for the class of
# inline `sess_$(date +%s)_$(...)` generators formerly duplicated across command/skill Markdown.
# Illustrative-prose sites under context/, docs/, and rules/ are deliberately NOT migrated and
# are expected to keep showing the literal generator as documentation, not a live call site --
# see tests/test-common-lib.sh's collect_session_id_offenders, which scopes its .md scan to
# commands/skills/agents by construction rather than excluding prose paths by a growing deny-list.

# Consumers (updated as each migration phase lands):
#   Session-ID generation (common_session_id), migrated in Phase 3:
#     scripts/command-gate-in.sh, scripts/manage-topics.sh,
#     scripts/orchestrate-predispatch-review.sh, scripts/reconcile-artifacts.sh,
#     scripts/skill-base.sh (two call sites), scripts/validate-state.sh (the --fix session-id
#     assignment), plus two now-quarantined scripts under scripts/deprecated/ (archive-task,
#     vault-operation) whose source still calls this function even though neither has a live
#     caller of its own.
#   command-gate-in.sh and skill-base.sh set no shell options at all (they are sourced into a
#   caller's shell); sourcing common.sh is confirmed not to change that (see
#   tests/test-common-lib.sh's $-/`set -o` assertions, exercised directly against both files).
#   Root-resolution (common_repo_root), migrated in Phase 4:
#     scripts/errors-append.sh, scripts/events-append.sh,
#     scripts/events-query.sh, scripts/export-to-markdown.sh, scripts/generate-task-order.sh,
#     scripts/generate-todo.sh, scripts/git-commit-scoped.sh, scripts/install-extension.sh,
#     scripts/lint/lint-postflight-boundary.sh,
#     scripts/literature-retrieve.sh, scripts/manage-topics.sh, scripts/memory-harvest.sh,
#     scripts/memory-retrieve.sh, scripts/orchestrate-batch-admit.sh,
#     scripts/orchestrate-cycle-plan.sh, scripts/orchestrate-predispatch-review.sh,
#     scripts/orchestrate-triage-classify.sh, scripts/reap-session-runtime-files.sh,
#     scripts/reconcile-artifacts.sh, scripts/reconcile-task-status.sh,
#     scripts/state-write.sh, scripts/task-lock.sh, scripts/uninstall-extension.sh,
#     scripts/update-task-status.sh, scripts/validate-context-budgets.sh,
#     scripts/validate-wiring.sh, and their test suites
#     (scripts/test-conflict-predicate.sh, scripts/test-four-tier-conflict.sh,
#     scripts/test-session-registry.sh, scripts/test-session-runtime-files.sh,
#     scripts/test-state-write-concurrency.sh, scripts/test-state-write-regen-timing.sh,
#     scripts/test-task-lock-reap.sh, scripts/tests/test-errors-append.sh,
#     scripts/tests/test-git-commit-scoped.sh, scripts/tests/test-orchestrate-triage-classify.sh),
#     plus three now-quarantined scripts under scripts/deprecated/ (archive-task, roadmap-sync,
#     vault-operation) whose source still calls this function even though none has a live caller
#     of its own.
#     Residual (not migrated, explicitly bounded per the phase's Scope Hypothesis): the
#     depth-2/3 cohort not listed above, and lint-agent-contracts.sh's and (since the source-store
#     root-resolution repair that fixed its `agent-system/extensions`-relative bug) the contract
#     compliance lint's deliberately different `git rev-parse --show-toplevel` +
#     REPO_ROOT-override strategy, left untouched by design.
#   UTC timestamp formatting (common_timestamp_iso / common_timestamp_epoch), migrated
#   opportunistically in Phase 4 within files already touched for root-resolution:
#     scripts/task-lock.sh (iso_now/now_epoch wrappers), scripts/update-task-status.sh (two
#     inline call sites). Parsing sites (BSD `date -u -j -f` / GNU `date -u -d`) are out of the
#     extracted set and left untouched, per the plan's Non-Goals.
#   Test-suite boilerplate (common_test_repo_root / common_test_resolve_candidate /
#   common_test_workdir_init): extracted to give the git-aware repo-root probe, the deploy-tree-
#   first/source-store-fallback script lookup, and the mktemp-plus-teardown pair each exactly one
#   definition, alongside the pre-existing common_test_pass/_fail/_info trio these three join. Not
#   yet consumed by any suite's call sites -- self-tested via tests/test-common-lib.sh pending a
#   tranched migration that moves existing suites' open-coded copies onto these three plus the
#   pre-existing trio, deleting each suite's own local definitions in the same pass.

# common_repo_root <script_dir> <levels> -- echoes the resolved repo root, walking <levels>
# directories up from <script_dir> and canonicalizing via `cd && pwd`. Serves scripts/ callers
# (levels=2), scripts/lib/, scripts/tests/, and scripts/lint/ callers (levels=3 each). Echoes
# empty string (never a non-zero exit) if <script_dir> is empty or the resolved path does not
# exist.
common_repo_root() {
  local _common_dir="${1:-}"
  local _common_levels="${2:-2}"
  local _common_path _common_i _common_result

  _common_result=""
  if [ -n "$_common_dir" ]; then
    _common_path="$_common_dir"
    _common_i=0
    while [ "$_common_i" -lt "$_common_levels" ]; do
      _common_path="${_common_path}/.."
      _common_i=$((_common_i + 1))
    done
    _common_result="$(cd "$_common_path" 2>/dev/null && pwd)"
  fi

  echo "$_common_result"
  unset _common_dir _common_levels _common_path _common_i _common_result
  return 0
}

# common_session_id -- echoes a new session ID of the form sess_<unix_epoch>_<6hex>. Uses the
# newline-stripping `tr -d ' \n'` form (strictly safer than, and a superset of, the plain
# `tr -d ' '` form used at most existing call sites) -- see plan Phase 3 for the migration that
# closes command-gate-in.sh's live trailing-newline divergence.
common_session_id() {
  local _common_rand

  _common_rand="$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
  echo "sess_$(date +%s)_${_common_rand}"
  unset _common_rand
  return 0
}

# common_orchestration_id -- echoes a new orchestration ID of the form orch_<unix_epoch>_<6hex>.
# Modeled byte-for-byte on common_session_id() above (same od/urandom technique, same
# newline-stripping `tr -d ' \n'` form). Distinct from common_session_id(): one session can cover
# several task numbers in several batches, so an orchestration-level identity needs its own
# primary key, minted by task-lock.sh's queue-register subcommand (never threaded through
# dispatch contexts) and resolved by session_id thereafter -- see
# context/patterns/task-lock.md's Orchestration-Queue CLI section for the full contract.
common_orchestration_id() {
  local _common_rand

  _common_rand="$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
  echo "orch_$(date +%s)_${_common_rand}"
  unset _common_rand
  return 0
}

# common_timestamp_iso -- echoes the current UTC time as YYYY-MM-DDTHH:MM:SSZ (the 19-site
# dominant form across the codebase).
common_timestamp_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
  return 0
}

# common_timestamp_epoch -- echoes the current UTC time as a Unix epoch integer.
common_timestamp_epoch() {
  date -u +%s
  return 0
}

# common_timestamp_date -- echoes the current UTC date as YYYY-MM-DD.
common_timestamp_date() {
  date -u +%Y-%m-%d
  return 0
}

# common_log_error / common_log_warn / common_log_info -- plain, side-effect-free emitters.
# Errors and warnings go to stderr; info goes to stdout. No counters, no color, no verbose
# gating -- see the NON-GOALS note above for why the several counter-incrementing/verbose-gated
# variants elsewhere are deliberately NOT replaced by these.
common_log_error() {
  echo "ERROR: $1" >&2
  return 0
}

common_log_warn() {
  echo "WARNING: $1" >&2
  return 0
}

common_log_info() {
  echo "INFO: $1"
  return 0
}

# common_test_pass / common_test_fail / common_test_info -- the shell-script-testing.md trio,
# operating on the CALLER's PASSED/FAILED integer counters (these functions are sourced into the
# caller's shell, not run in a subshell, so incrementing an unprefixed global here reaches the
# caller directly -- the caller must declare `PASSED=0` / `FAILED=0` before use, matching every
# existing suite's own convention). common_test_info is diagnostic-only and does not count.
#
# common_test_fail's optional $2 is a verbatim diagnostic-detail payload (e.g. a captured diff or
# command output) echoed on its own line after the [FAIL] line -- folded in during the Harness
# Migration Tranche B phase to absorb four suites' pre-existing `fail() { ...; [ -n "${2:-}" ] &&
# echo "$2"; }` local override verbatim, so migrating them loses no diagnostic output.
common_test_pass() {
  echo "[PASS] $1"
  PASSED=$((${PASSED:-0} + 1))
  return 0
}

common_test_fail() {
  echo "[FAIL] $1"
  FAILED=$((${FAILED:-0} + 1))
  [ -n "${2:-}" ] && echo "$2"
  return 0
}

common_test_info() {
  echo "[INFO] $1"
  return 0
}

# common_test_repo_root <script_dir> [<fallback_levels>] -- echoes the resolved repo root,
# trying the depth-independent `git rev-parse --show-toplevel` first and falling back to
# common_repo_root's fixed-depth walk (default 5, the scripts/tests/ depth shared by all 121
# core suites) only when <script_dir> is not inside a git work tree. This is the git-aware
# variant 64/121 core suites hand-rolled inline (each one open-coding the same two-step probe)
# before this extraction; common_repo_root itself stays fixed-depth-only and untouched, since it
# already has ~20 production-script call sites whose behavior outside a git checkout must not
# change. Echoes empty string (never a non-zero exit) on total failure, matching
# common_repo_root's own safe-default contract.
common_test_repo_root() {
  local _common_dir="${1:-}"
  local _common_levels="${2:-5}"
  local _common_result=""

  if [ -n "$_common_dir" ]; then
    _common_result="$(cd "$_common_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)"
    if [ -z "$_common_result" ]; then
      _common_result="$(common_repo_root "$_common_dir" "$_common_levels")"
    fi
  fi

  echo "$_common_result"
  unset _common_dir _common_levels _common_result
  return 0
}

# common_test_resolve_candidate <desc> <candidate> [<candidate>...] -- echoes the first
# <candidate> that exists as a regular file and returns 0; if none exist, prints an "ERROR: ...
# not found at any of:" listing (one candidate per line) to stderr and returns 1. This is the
# deploy-tree-first / source-store-fallback script-under-test lookup 22/121 core suites
# hand-rolled inline as a local `resolve_candidate` function before this extraction. Never calls
# `exit` -- the caller decides what a miss means for its own exit-code convention (every existing
# caller does `... || exit 2`, the documented environment-error code).
common_test_resolve_candidate() {
  local _common_desc="$1"; shift
  local _common_candidate

  for _common_candidate in "$@"; do
    if [ -f "$_common_candidate" ]; then
      printf '%s\n' "$_common_candidate"
      unset _common_desc _common_candidate
      return 0
    fi
  done

  echo "ERROR: $_common_desc not found at any of:" >&2
  for _common_candidate in "$@"; do
    echo "  $_common_candidate" >&2
  done
  unset _common_desc _common_candidate
  return 1
}

# common_test_workdir_init -- creates a `mktemp -d` scratch directory, assigns it to the
# CALLER's WORKDIR variable, and installs a `trap 'rm -rf "$WORKDIR"' EXIT` on the caller's
# shell (this function runs in the caller's shell, not a subshell, so the trap and the global
# assignment both land where the caller needs them). This is the mktemp-plus-teardown pair
# 115/121 core suites hand-rolled inline before this extraction.
#
# MUST be called as a bare statement, never as `WORKDIR="$(common_test_workdir_init)"` --
# command substitution runs the function in its OWN subshell, and that subshell exits (firing
# the EXIT trap this function just installed, deleting the directory) the instant the function
# returns, before the outer assignment ever sees it. Read the global `$WORKDIR` after calling.
# Never calls `exit`.
common_test_workdir_init() {
  WORKDIR="$(mktemp -d)"
  trap 'rm -rf "$WORKDIR"' EXIT
  return 0
}

# common_shared_corpus_available -- returns 0 (true) iff a usable master corpus is present in
# this process's environment: GATE_SHARED_CORPUS_FILE and GATE_SHARED_CORPUS_ROOT are both set
# and the corpus file is readable. verify-deploy.sh's gate loop is the one producer (via
# gate-registry-lib.sh's gate_registry_shared_corpus_build, see that function's own header),
# exporting both variables once per invocation before running any gate; a lint invoked any other
# way (standalone, from a fixture test, or as a nested call with no verify-deploy.sh ancestor)
# simply never sees them set, so this returns 1 and the caller takes its own pre-existing
# enumeration path -- never a behavior change for that caller. A caller MUST check this (or let
# common_shared_corpus_files's own internal check degrade it to empty output) before trusting
# GATE_SHARED_CORPUS_ROOT as a valid absolute path.
common_shared_corpus_available() {
  [ -n "${GATE_SHARED_CORPUS_FILE:-}" ] || return 1
  [ -n "${GATE_SHARED_CORPUS_ROOT:-}" ] || return 1
  [ -r "$GATE_SHARED_CORPUS_FILE" ] || return 1
  return 0
}

# common_shared_corpus_files <include-pattern> [<include-pattern>...] -- filters the master
# corpus (NUL-delimited paths relative to $GATE_SHARED_CORPUS_ROOT, as produced by
# gate_registry_shared_corpus_build) to entries whose repo-relative path matches ANY of the
# given glob pattern(s), and echoes each surviving entry as an ABSOLUTE path (prefixed with
# "$GATE_SHARED_CORPUS_ROOT/"), NUL-delimited, in the corpus's own order (git ls-files order,
# already lexicographic -- a caller that needs sorted output pipes through `sort -z` itself,
# matching its own pre-existing `find ... | sort` convention).
#
# Pattern matching is ordinary `[[ str == pattern ]]` globbing, NOT find's `-name` single-path-
# segment semantics: `*` spans directory separators freely, so a multi-segment pattern like
# 'agent-system/extensions/*/scripts/*.sh' is a legal recursive match (it matches both
# .../core/scripts/foo.sh AND .../core/scripts/tests/foo.sh -- exclude the latter in a second,
# caller-side pass if the original `find -not -path` semantics excluded it, exactly as
# lint-task-lookup-adoption.sh's shared-corpus branch does for scripts/tests/ and
# scripts/deprecated/).
#
# Degrades to silent empty output (never an error, never a non-zero exit) when
# GATE_SHARED_CORPUS_FILE/_ROOT are unset or the corpus file is unreadable -- a caller that omits
# the common_shared_corpus_available precondition check still gets a safe empty result rather
# than a crash, though every current consumer calls the precondition check first so it can take
# its OWN fallback enumeration path on a miss instead of silently scanning nothing.
common_shared_corpus_files() {
  common_shared_corpus_available || return 0
  local _common_rel _common_pat _common_matched
  while IFS= read -r -d '' _common_rel; do
    _common_matched=false
    for _common_pat in "$@"; do
      # shellcheck disable=SC2053 # intentional unquoted RHS: pattern match, not literal compare
      if [[ "$_common_rel" == $_common_pat ]]; then
        _common_matched=true
        break
      fi
    done
    if $_common_matched; then
      printf '%s\0' "$GATE_SHARED_CORPUS_ROOT/$_common_rel"
    fi
  done < "$GATE_SHARED_CORPUS_FILE"
  unset _common_rel _common_pat _common_matched
  return 0
}
