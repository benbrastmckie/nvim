#!/usr/bin/env bash
# suite-selection-lib.sh - Single source of truth for the touched-source-path -> test-suite-
# basename mapping behind run-all.sh's --only SUITE[,SUITE,...] flag (see that script's own
# header for --only itself; this library is a separate, independently sourced piece that
# COMPOSES with --only rather than being called from inside it -- a caller resolves suite names
# here first, then passes them to `run-all.sh --only <resolved list>`).
#
# Sourced (never executed) -- modelled structurally on scripts/lib/manifest-routing-lib.sh:
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior.
#   - Never calls `exit` -- every function below always returns 0.
#   - Every internal variable/function is prefixed `_ssl_` and is explicitly unset before each
#     function returns (on top of already being `local`), so sourcing this file never leaks
#     state into the calling shell's environment. The small number of externally-facing names
#     (the `suite_selection_*` functions and the `SUITE_SELECTION_FULL_SWEEP_SENTINEL` constant)
#     are deliberately NOT unset -- they are this library's public contract.
#
# ─── HONESTY CONSTRAINT (read before treating a selected run as proof of anything) ─────────────
# A selected-subset pass is NOT evidence that doc-sync pins hold. This is the same accepted
# trade-off verify-deploy.sh's --skip-slow already carries for Gate 8's own reduced coverage
# (recorded in specs/ROADMAP.md's Settled decision 15) -- selection narrows WHICH suites run for
# cost reasons, which is exactly the kind of coverage reduction that decision already rules a
# selected/skipped pass must never be presented as equivalent to a full run. Selection is also a
# STRICTLY SEPARATE axis from tests/known-failures.txt (Settled decision 13: that manifest is
# advisory and never changes which suites run, only how a failure is annotated) -- do not conflate
# the two mechanisms.
#
# ─── WHY `script-inventory.sh`'s `has_test` IS NOT REUSED HERE ─────────────────────────────────
# script-inventory.sh's has_test() resolves test candidates against each CANDIDATE's OWN
# enclosing directory (e.g. `lib/tests/test-X.sh`, `lint/tests/test-X.sh`) -- a path shape this
# corpus never actually uses. Every suite in this corpus lives at exactly one of two FIXED
# locations relative to the scripts root: `scripts/tests/test-*.sh` (narrow) or flat
# `scripts/test-*.sh` -- the same two locations run-all.sh itself scans. Reusing has_test
# verbatim would therefore structurally under-report lib/ and lint/ coverage. This is a pointer
# caveat only; fixing has_test's directory-resolution bug is a separately-scoped standing task's
# ground, not this library's job.
#
# ─── SCOPE ───────────────────────────────────────────────────────────────────────────────────
# This library maps touched paths against ONE scripts tree: the one this file itself currently
# lives under (resolved from its own location two directories up: scripts/lib/THIS_FILE ->
# scripts/). That is agent-system/extensions/core/scripts when sourced from the source store, and
# .claude/scripts when sourced from a deploy (where every extension's scripts merge into one flat
# tree, so "core-only" and "the whole deployed tree" become the same population -- see run-all.sh
# header's own source-store/deployed dual-mode note for the general pattern this mirrors).
# Extending the mapping to reason about a SOURCE-STORE path belonging to a different extension
# while still un-deployed is explicitly out of scope (0 of 19 non-core suites were found to match
# the deployed-vs-source hazard this library also classifies -- a core-only phenomenon today).
#
# ─── MAPPING STRATA (in order; first hit wins per path) ─────────────────────────────────────────
#   (a) Strict basename pairing: NAME.sh -> test-NAME.sh (covers lint/lint-*.sh and flat
#       scripts/*.sh, including lib/ files already named NAME-lib.sh), PLUS the corpus's lib/
#       suffix variant for a lib/ file NOT already ending in "-lib.sh": NAME.sh ->
#       test-NAME-lib.sh (e.g. lib/common.sh -> tests/test-common-lib.sh).
#   (b) Grep-based reference lookup: every suite (narrow or flat) that textually references the
#       touched basename, many-to-one allowed (e.g. lib/task-lookup-lib.sh is referenced by two
#       dozen suites).
#   (c) Zero hits in (a) and (b): the touched path is UNMAPPABLE. A single unmappable path
#       escalates the WHOLE multi-path call to the full-sweep sentinel (fail-safe direction) --
#       never a silent empty/zero-suite selection. This is the dangerous case a caller must never
#       be allowed to read as green.
#   (0, ahead of (a)) Self-identity: if the touched path's own basename already names a
#       discovered suite (it IS a test-*.sh file), that suite selects itself directly.
#
# ─── RESOLUTION-ORDER CLASSIFICATION (advisory, never selection-blocking) ───────────────────────
# A naive basename mapping can select a suite whose SUBJECT-under-test actually resolves to the
# deployed .claude/ copy rather than the source-store copy being edited -- selecting such a suite
# is not proof the source edit is covered. suite_selection_classify() flags this per
# suite/basename pair as one of `source-only` / `source-first` / `deployed-first`, using the same
# textual signal already established for the corpus-wide deployed-preferring ratio
# (`grep -l '$REPO_ROOT/.claude'`): a suite with no `.claude` reference to the touched basename at
# all is `source-only`; one where the touched basename's first textual occurrence is on a line
# also mentioning `.claude` is `deployed-first`; one where the basename occurs earlier on a
# non-`.claude` line (and only later, if at all, alongside `.claude`) is `source-first`. This is a
# heuristic over suite SOURCE TEXT, not a semantic trace of runtime path resolution -- it is
# deliberately conservative (defaults to `deployed-first` whenever both occur with the deployed
# reference not provably later) and is surfaced for a human/caller to weigh, never used to drop a
# suite from selection.
#
# ─── PUBLIC API ──────────────────────────────────────────────────────────────────────────────
#   suite_selection_select PATH [PATH...]
#       Stdout: either the single line "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" (any touched path
#       unmappable), or the sorted, de-duplicated UNION of resolved suite basenames across every
#       given path, one per line. Always returns 0.
#   suite_selection_unmapped PATH [PATH...]
#       Stdout: the subset of the given touched paths (verbatim, as given) that strata (a)+(b)
#       could not map, one per line. Empty output means none were unmapped. Always returns 0.
#   suite_selection_classify SUITE_BASENAME TOUCHED_BASENAME
#       Stdout: one of `source-only` / `source-first` / `deployed-first` for how SUITE_BASENAME
#       (a suite file, resolved against this library's scripts tree) resolves TOUCHED_BASENAME.
#       Always returns 0; emits `source-only` if the suite file cannot be found or read.
#   suite_selection_select_annotated PATH [PATH...]
#       Convenience wrapper over the two functions above: either the sentinel alone, or one
#       "SUITE_BASENAME|CLASSIFICATION" row per selected suite (classification computed against
#       the first given touched path's basename each suite was selected for).
#
# Usage:
#   source agent-system/extensions/core/scripts/lib/suite-selection-lib.sh
#   mapfile -t _resolved < <(suite_selection_select "$touched1" "$touched2")
#   if [ "${#_resolved[@]}" -eq 1 ] && [ "${_resolved[0]}" = "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]; then
#     # fall back to a full run-all.sh invocation (no --only)
#   else
#     run-all.sh --only "$(IFS=,; echo "${_resolved[*]}")"
#   fi

_SSL_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_SSL_SCRIPTS_ROOT="$(cd "${_SSL_SELF_DIR}/.." 2>/dev/null && pwd)"
_SSL_TESTS_DIR="${_SSL_SCRIPTS_ROOT}/tests"
unset _SSL_SELF_DIR

# The full-sweep sentinel: a value that can never collide with a real suite basename (every real
# suite basename matches test-*.sh; this does not).
SUITE_SELECTION_FULL_SWEEP_SENTINEL="__FULL_SWEEP__"

# _ssl_discovered_basenames -- stdout: every discovered suite basename (narrow + flat), one per
# line, unsorted. Mirrors run-all.sh's own two-location discovery exactly (tests/test-*.sh plus
# flat test-*.sh), scoped to this library's own scripts root.
_ssl_discovered_basenames() {
  local _ssl_f
  if [ -d "${_SSL_TESTS_DIR}" ]; then
    for _ssl_f in "${_SSL_TESTS_DIR}"/test-*.sh; do
      [ -e "${_ssl_f}" ] || continue
      basename "${_ssl_f}"
    done
  fi
  if [ -d "${_SSL_SCRIPTS_ROOT}" ]; then
    for _ssl_f in "${_SSL_SCRIPTS_ROOT}"/test-*.sh; do
      [ -e "${_ssl_f}" ] || continue
      basename "${_ssl_f}"
    done
  fi
  unset _ssl_f
  return 0
}

# _ssl_resolve_one PATH -- stdout: resolved suite basenames for ONE touched path, one per line,
# de-duplicated. Empty output means UNMAPPABLE (strata a+b both missed). Internal; not part of
# the public API.
_ssl_resolve_one() {
  local _ssl_path="$1"
  local _ssl_base _ssl_noext _ssl_hit _ssl_cand1 _ssl_cand2 _ssl_f
  local -a _ssl_hits=()

  _ssl_base="$(basename "${_ssl_path}")"
  _ssl_noext="${_ssl_base%.sh}"

  # Stratum 0: self-identity -- the touched path IS already a discovered suite.
  if [ -f "${_SSL_TESTS_DIR}/${_ssl_base}" ] || [ -f "${_SSL_SCRIPTS_ROOT}/${_ssl_base}" ]; then
    case "${_ssl_base}" in
      test-*.sh) _ssl_hits+=("${_ssl_base}") ;;
    esac
  fi

  # Stratum (a): strict basename pairing, plus the lib/ "-lib.sh" suffix variant.
  _ssl_cand1="test-${_ssl_base}"
  _ssl_cand2="test-${_ssl_noext}-lib.sh"
  if [ -f "${_SSL_TESTS_DIR}/${_ssl_cand1}" ]; then
    _ssl_hits+=("${_ssl_cand1}")
  fi
  if [ -f "${_SSL_SCRIPTS_ROOT}/${_ssl_cand1}" ]; then
    _ssl_hits+=("${_ssl_cand1}")
  fi
  if [ "${_ssl_cand2}" != "${_ssl_cand1}" ] && [ -f "${_SSL_TESTS_DIR}/${_ssl_cand2}" ]; then
    _ssl_hits+=("${_ssl_cand2}")
  fi

  # Stratum (b): grep-based reference lookup, every suite that textually references the touched
  # basename. Many-to-one allowed.
  if [ -d "${_SSL_TESTS_DIR}" ]; then
    while IFS= read -r _ssl_f; do
      [ -n "${_ssl_f}" ] || continue
      _ssl_hits+=("$(basename "${_ssl_f}")")
    done < <(grep -l -F -- "${_ssl_base}" "${_SSL_TESTS_DIR}"/test-*.sh 2>/dev/null)
  fi
  if [ -d "${_SSL_SCRIPTS_ROOT}" ]; then
    while IFS= read -r _ssl_f; do
      [ -n "${_ssl_f}" ] || continue
      _ssl_hits+=("$(basename "${_ssl_f}")")
    done < <(grep -l -F -- "${_ssl_base}" "${_SSL_SCRIPTS_ROOT}"/test-*.sh 2>/dev/null)
  fi

  if [ "${#_ssl_hits[@]}" -gt 0 ]; then
    printf '%s\n' "${_ssl_hits[@]}" | sort -u
  fi

  unset _ssl_path _ssl_base _ssl_noext _ssl_hit _ssl_cand1 _ssl_cand2 _ssl_f _ssl_hits
  return 0
}

# suite_selection_select PATH [PATH...] -- see PUBLIC API header above.
suite_selection_select() {
  local -a _ssl_args=("$@")
  local _ssl_p _ssl_resolved
  local -a _ssl_all=()

  for _ssl_p in "${_ssl_args[@]}"; do
    _ssl_resolved="$(_ssl_resolve_one "${_ssl_p}")"
    if [ -z "${_ssl_resolved}" ]; then
      echo "${SUITE_SELECTION_FULL_SWEEP_SENTINEL}"
      unset _ssl_args _ssl_p _ssl_resolved _ssl_all
      return 0
    fi
    while IFS= read -r _ssl_resolved; do
      [ -n "${_ssl_resolved}" ] && _ssl_all+=("${_ssl_resolved}")
    done <<< "${_ssl_resolved}"
  done

  if [ "${#_ssl_all[@]}" -gt 0 ]; then
    printf '%s\n' "${_ssl_all[@]}" | sort -u
  fi

  unset _ssl_args _ssl_p _ssl_resolved _ssl_all
  return 0
}

# suite_selection_unmapped PATH [PATH...] -- see PUBLIC API header above.
suite_selection_unmapped() {
  local -a _ssl_args=("$@")
  local _ssl_p _ssl_resolved

  for _ssl_p in "${_ssl_args[@]}"; do
    _ssl_resolved="$(_ssl_resolve_one "${_ssl_p}")"
    if [ -z "${_ssl_resolved}" ]; then
      echo "${_ssl_p}"
    fi
  done

  unset _ssl_args _ssl_p _ssl_resolved
  return 0
}

# suite_selection_classify SUITE_BASENAME TOUCHED_BASENAME -- see PUBLIC API header above.
suite_selection_classify() {
  local _ssl_suite_base="$1"
  local _ssl_touched_base="$2"
  local _ssl_suite_path _ssl_first_touch _ssl_first_deployed

  _ssl_suite_path=""
  if [ -f "${_SSL_TESTS_DIR}/${_ssl_suite_base}" ]; then
    _ssl_suite_path="${_SSL_TESTS_DIR}/${_ssl_suite_base}"
  elif [ -f "${_SSL_SCRIPTS_ROOT}/${_ssl_suite_base}" ]; then
    _ssl_suite_path="${_SSL_SCRIPTS_ROOT}/${_ssl_suite_base}"
  fi

  if [ -z "${_ssl_suite_path}" ] || [ ! -r "${_ssl_suite_path}" ]; then
    echo "source-only"
    unset _ssl_suite_base _ssl_touched_base _ssl_suite_path _ssl_first_touch _ssl_first_deployed
    return 0
  fi

  if ! grep -q -F -- "${_ssl_touched_base}" "${_ssl_suite_path}" 2>/dev/null; then
    echo "source-only"
    unset _ssl_suite_base _ssl_touched_base _ssl_suite_path _ssl_first_touch _ssl_first_deployed
    return 0
  fi

  # shellcheck disable=SC2016
  if ! grep -q -E '\$REPO_ROOT/\.claude|/\.claude/' "${_ssl_suite_path}" 2>/dev/null; then
    echo "source-only"
    unset _ssl_suite_base _ssl_touched_base _ssl_suite_path _ssl_first_touch _ssl_first_deployed
    return 0
  fi

  # Pure-comment lines (first non-blank character is '#') are excluded from both scans -- a
  # header comment that merely mentions the touched basename in prose (e.g. a suite's own
  # "Fixture-driven regression suite for X.sh" opening line) must not be mistaken for the suite's
  # actual subject-resolution code.
  _ssl_first_touch="$(grep -n -F -- "${_ssl_touched_base}" "${_ssl_suite_path}" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' | head -1 | cut -d: -f1)"
  # shellcheck disable=SC2016
  _ssl_first_deployed="$(grep -n -E '\$REPO_ROOT/\.claude|/\.claude/' "${_ssl_suite_path}" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' | head -1 | cut -d: -f1)"

  if [ -z "${_ssl_first_touch}" ] && [ -z "${_ssl_first_deployed}" ]; then
    # Every occurrence of both the touched basename and a '.claude' reference was comment-only --
    # no real code evidence either way.
    echo "source-only"
  elif [ -n "${_ssl_first_touch}" ] && [ -n "${_ssl_first_deployed}" ] && [ "${_ssl_first_touch}" -lt "${_ssl_first_deployed}" ]; then
    echo "source-first"
  else
    echo "deployed-first"
  fi

  unset _ssl_suite_base _ssl_touched_base _ssl_suite_path _ssl_first_touch _ssl_first_deployed
  return 0
}

# suite_selection_select_annotated PATH [PATH...] -- see PUBLIC API header above.
suite_selection_select_annotated() {
  local -a _ssl_args=("$@")
  local _ssl_first_base _ssl_line _ssl_class
  local -a _ssl_selected=()

  _ssl_first_base="$(basename "${_ssl_args[0]:-}")"

  while IFS= read -r _ssl_line; do
    [ -n "${_ssl_line}" ] && _ssl_selected+=("${_ssl_line}")
  done < <(suite_selection_select "${_ssl_args[@]}")

  if [ "${#_ssl_selected[@]}" -eq 1 ] && [ "${_ssl_selected[0]}" = "${SUITE_SELECTION_FULL_SWEEP_SENTINEL}" ]; then
    echo "${SUITE_SELECTION_FULL_SWEEP_SENTINEL}"
    unset _ssl_args _ssl_first_base _ssl_line _ssl_class _ssl_selected
    return 0
  fi

  for _ssl_line in "${_ssl_selected[@]}"; do
    _ssl_class="$(suite_selection_classify "${_ssl_line}" "${_ssl_first_base}")"
    echo "${_ssl_line}|${_ssl_class}"
  done

  unset _ssl_args _ssl_first_base _ssl_line _ssl_class _ssl_selected
  return 0
}
