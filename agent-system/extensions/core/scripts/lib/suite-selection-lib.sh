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
# This library's DEFAULT scripts tree is the one this file itself currently lives under (resolved
# from its own location two directories up: scripts/lib/THIS_FILE -> scripts/). That is
# agent-system/extensions/core/scripts when sourced from the source store, and .claude/scripts
# when sourced from a deploy (where every extension's scripts merge into one flat tree, so
# "core-only" and "the whole deployed tree" become the same population -- see run-all.sh header's
# own source-store/deployed dual-mode note for the general pattern this mirrors).
#
# A touched path naming a literal agent-system/extensions/<ext>/scripts/ segment is resolved
# against THAT extension's own scripts/ + scripts/tests/ instead -- but ONLY when two conditions
# both hold: this library is running from the source store (detected by the same marker run-all.sh
# itself already uses: <extensions-parent>/core/manifest.json exists -- derived once per call via
# the shared _ssl_extensions_parent helper, never a second detection idiom), AND that named
# extension's own scripts/ directory actually exists on disk. Failing either condition falls
# through unchanged to this library's own default tree above -- the fall-through is why a core
# path, a deployed-mode path (the marker never exists there, since a deploy has no per-extension
# source-store layout to find), and an unrecognized path shape all behave exactly as they did
# before this per-extension resolution existed. Resolution is scoped to the ONE extension the
# touched path itself names, never a corpus-wide search across every extension -- broadening the
# existing stratum (b) grep to scan every extension's suites would risk a coincidental
# cross-extension basename collision, which would be a behavior change for core paths too.
#
# `suite_selection_classify`'s suite-FILE lookup (not the touched-path mapping above) is widened
# the same way: a suite basename not found in this library's own two fixed locations is probed
# against every extension's own scripts/tests/ then scripts/ in turn, first match wins, but again
# only in source-store mode (the identical marker). This reaches every real non-core suite, not
# core's alone -- see RESOLUTION-ORDER CLASSIFICATION below for why this half is EXTENDED rather
# than staying core-only.
#
# Known limitation: a touched path given as a bare relative path with no
# agent-system/extensions/<ext>/scripts/ segment at all (e.g. a caller that already `cd`'d into an
# extension directory and passed a path relative to it, such as plain `scripts/foo.sh`) still
# resolves against this library's own default tree, never against the path's actual extension.
# This is a known gap, not a silent miss: such a path is never wrongly classified as unmappable,
# it simply does not benefit from the per-extension resolution this file otherwise provides.
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
# CLASSIFICATION RULING: this signal is EXTENDED to non-core suites, not left core-only. An
# earlier measurement claiming "0 of 19 non-core suites match the deployed-vs-source hazard" was
# itself an artifact of the suite-FILE lookup only ever checking this library's own default tree
# -- a non-core suite file could never be found at all, so every one of them fell through to the
# `source-only` not-found default, indistinguishable from a genuine absence of the hazard. Once
# the lookup was widened (see SCOPE above), a direct re-measurement across the real non-core
# corpus found the opposite: 9 of 29 non-core suites (5 `source-first`, 4 `deployed-first`) DO
# carry the hazard -- re-run this exact command to reproduce the figure against the live corpus
# (counts will drift as suites are added/removed; the command, not the number, is the durable
# anchor):
#   for d in agent-system/extensions/*/; do e="$(basename "$d")"; [ "$e" = core ] && continue
#     [ -d "${d}scripts" ] || continue
#     for f in "${d}scripts/tests"/test-*.sh "${d}scripts"/test-*.sh; do [ -e "$f" ] || continue
#       s="$(basename "$f")"; n="${s#test-}"; n="${n%.sh}"
#       suite_selection_classify "$s" "${n}.sh"
#     done
#   done | sort | uniq -c
# Lookup order for a non-core suite basename: this library's own two fixed locations first (so a
# core-adjacent basename collision resolves exactly as it always did), then every extension
# directory's own scripts/tests/ then scripts/ in turn, first match wins. First match wins safely
# because every suite basename is corpus-unique by the existing test-*.sh discovery convention
# (one real file per basename across the whole corpus), and the per-extension loop order is the
# stable `*/` glob order inherited from run-all.sh's own discovery loop.
#
# ─── PUBLIC API ──────────────────────────────────────────────────────────────────────────────
#   suite_selection_select PATH [PATH...]
#       Stdout: the sorted, de-duplicated UNION of resolved suite basenames across every given
#       path, one per line. An unmappable given path contributes
#       "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" as one more member of that union rather than
#       replacing it -- the sentinel is a FLOOR contributed by its own member, never a ceiling
#       imposed on the whole set. An all-unmappable set therefore still returns the sentinel
#       alone (every member contributes it, `sort -u` collapses the duplicates); a mixed set
#       returns the sentinel ALONGSIDE the real suite basenames the other paths resolved to; an
#       all-mappable set never produces the sentinel at all. A caller detects "no suite covers
#       this [remaining] path" by checking whether the output CONTAINS the sentinel, never by
#       checking output length -- `[ #out -eq 1 ] && [ out[0] = sentinel ]` is the PRE-FIX idiom
#       and under-detects a mixed set. Always returns 0.
#       Composing per-path invocations and unioning the results by hand is NOT equivalent to one
#       multi-path call over the same paths: the two agree when no given path is unmappable, and
#       can legitimately differ when one is, since only the multi-path union reflects every other
#       path's real coverage alongside that one path's sentinel contribution. Call this function
#       ONCE over the whole touched-path set; never once per path with the per-path sentinel
#       lines discarded and the rest unioned by hand.
#   suite_selection_unmapped PATH [PATH...]
#       Stdout: the subset of the given touched paths (verbatim, as given) that strata (a)+(b)
#       could not map, one per line. Empty output means none were unmapped. Always returns 0.
#   suite_selection_classify SUITE_BASENAME TOUCHED_BASENAME
#       Stdout: one of `source-only` / `source-first` / `deployed-first` for how SUITE_BASENAME
#       resolves TOUCHED_BASENAME. SUITE_BASENAME is resolved first against this library's own
#       fixed scripts tree (narrow then flat, exactly as every other function here), then, only
#       in source-store mode (the core/manifest.json marker), against every extension's own
#       scripts/tests/ then scripts/ in turn (first match wins) -- the same cross-extension reach
#       _ssl_roots_for_path gives the selection half. Always returns 0; emits `source-only` if the
#       suite file cannot be found anywhere or cannot be read.
#   suite_selection_select_annotated PATH [PATH...]
#       Convenience wrapper over the two functions above: the sentinel alone (as a bare line, no
#       classification) when every given path is unmappable; for a mixed set, that same bare
#       sentinel line PLUS one "SUITE_BASENAME|CLASSIFICATION" row per real selected suite
#       (classification computed against the first given touched path's basename each suite was
#       selected for); for an all-mappable set, purely classified rows with no sentinel line at
#       all.
#   suite_selection_known_classes / suite_selection_known_tags / suite_selection_known_cost_classes
#       Stdout: the closed vocabulary for the class/tag/cost-class axis, one value per line. A
#       caller validates an incoming selector token against these BEFORE calling the matching
#       `suite_selection_by_*` below, for the loud-refusal-on-unknown-value behavior.
#   suite_selection_by_class / suite_selection_by_tag / suite_selection_by_cost_class CLASS[,...]
#       Stdout: discovered-suite basenames matching ANY given value within that one axis, sorted
#       unique. See the "Declarative class / tag / cost-class selection" section further down for
#       the full derivation rule of each axis. Always returns 0; an unrecognized value simply
#       selects nothing.
#
# Usage:
#   source agent-system/extensions/core/scripts/lib/suite-selection-lib.sh
#   mapfile -t _resolved < <(suite_selection_select "$touched1" "$touched2")
#   _any_unmapped=0
#   _narrowed=()
#   for _r in "${_resolved[@]}"; do
#     if [ "$_r" = "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]; then
#       _any_unmapped=1
#       continue
#     fi
#     _narrowed+=("$_r")
#   done
#   if [ "$_any_unmapped" -eq 1 ]; then
#     # fall back to a full run-all.sh invocation (no --only) -- the conservative default
#     # whenever at least one touched path is unmappable. A caller that can tolerate leaving an
#     # unmapped path's own coverage unresolved may instead run --only over "${_narrowed[@]}"
#     # (the output with the sentinel token removed), as validate-artifact.sh's Tier
#     # Justification check does for its own advisory comparison -- never hand the literal
#     # sentinel string to --only.
#   else
#     run-all.sh --only "$(IFS=,; echo "${_narrowed[*]}")"
#   fi

_SSL_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_SSL_SCRIPTS_ROOT="$(cd "${_SSL_SELF_DIR}/.." 2>/dev/null && pwd)"
_SSL_TESTS_DIR="${_SSL_SCRIPTS_ROOT}/tests"
unset _SSL_SELF_DIR

# The full-sweep sentinel: a value that can never collide with a real suite basename (every real
# suite basename matches test-*.sh; this does not).
SUITE_SELECTION_FULL_SWEEP_SENTINEL="__FULL_SWEEP__"

# _ssl_extensions_parent -- stdout: the agent-system/extensions/ parent directory, but ONLY when
# this library is running from the source store -- detected by the same marker check
# tests/run-all.sh's own source-store/deployed dual-mode note already uses
# (<parent>/core/manifest.json). Empty output (no line at all) in deployed mode, where that
# marker never exists because every extension's scripts merge into one flat tree. Internal; not
# part of the public API. Shared by _ssl_roots_for_path below and by
# suite_selection_classify's cross-extension suite-file lookup, so the marker check is written
# exactly once.
_ssl_extensions_parent() {
  local _ssl_parent
  _ssl_parent="$(cd "${_SSL_SCRIPTS_ROOT}/../.." 2>/dev/null && pwd)"
  if [ -n "${_ssl_parent}" ] && [ -f "${_ssl_parent}/core/manifest.json" ]; then
    printf '%s\n' "${_ssl_parent}"
  fi
  unset _ssl_parent
  return 0
}

# _ssl_roots_for_path PATH -- stdout: exactly two lines, the scripts root then the tests
# directory that PATH's strata should be resolved against. When PATH names a literal
# agent-system/extensions/<ext>/scripts/ path segment, this library is running from the source
# store (per _ssl_extensions_parent above), and <ext>'s own scripts/ directory actually exists,
# emits that extension's own two roots (<parent>/<ext>/scripts and
# <parent>/<ext>/scripts/tests). In every other case -- a core path, deployed mode (where the
# marker never exists), an unrecognized path shape, or a named extension that does not actually
# have a scripts/ directory -- falls through unchanged to this library's own fixed
# _SSL_SCRIPTS_ROOT / _SSL_TESTS_DIR, exactly as every caller already resolved before this
# function existed. This is the one place the touched-path argument's directory structure (not
# just its basename) is consulted. Internal; not part of the public API.
_ssl_roots_for_path() {
  local _ssl_path="$1"
  local _ssl_parent _ssl_rest _ssl_ext _ssl_ext_scripts
  local _ssl_out_scripts="${_SSL_SCRIPTS_ROOT}"
  local _ssl_out_tests="${_SSL_TESTS_DIR}"

  _ssl_parent="$(_ssl_extensions_parent)"
  if [ -n "${_ssl_parent}" ]; then
    case "${_ssl_path}" in
      *agent-system/extensions/*/scripts/*)
        _ssl_rest="${_ssl_path#*agent-system/extensions/}"
        _ssl_ext="${_ssl_rest%%/scripts/*}"
        _ssl_ext_scripts="${_ssl_parent}/${_ssl_ext}/scripts"
        if [ -d "${_ssl_ext_scripts}" ]; then
          _ssl_out_scripts="${_ssl_ext_scripts}"
          _ssl_out_tests="${_ssl_ext_scripts}/tests"
        fi
        ;;
    esac
  fi

  printf '%s\n%s\n' "${_ssl_out_scripts}" "${_ssl_out_tests}"
  unset _ssl_path _ssl_parent _ssl_rest _ssl_ext _ssl_ext_scripts _ssl_out_scripts _ssl_out_tests
  return 0
}

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
# de-duplicated. Empty output means UNMAPPABLE (strata a+b both missed). Resolves all three
# strata against the root pair _ssl_roots_for_path derives for PATH -- that extension's own
# scripts/ + scripts/tests/ for a recognized non-core source-store path, this library's own
# fixed roots for everything else (a core path, deployed mode, or an unrecognized path shape).
# Internal; not part of the public API.
_ssl_resolve_one() {
  local _ssl_path="$1"
  local _ssl_base _ssl_noext _ssl_hit _ssl_cand1 _ssl_cand2 _ssl_f
  local _ssl_scripts_root _ssl_tests_dir
  local -a _ssl_hits=() _ssl_roots=()

  mapfile -t _ssl_roots < <(_ssl_roots_for_path "${_ssl_path}")
  _ssl_scripts_root="${_ssl_roots[0]:-${_SSL_SCRIPTS_ROOT}}"
  _ssl_tests_dir="${_ssl_roots[1]:-${_SSL_TESTS_DIR}}"

  _ssl_base="$(basename "${_ssl_path}")"
  _ssl_noext="${_ssl_base%.sh}"

  # Stratum 0: self-identity -- the touched path IS already a discovered suite.
  if [ -f "${_ssl_tests_dir}/${_ssl_base}" ] || [ -f "${_ssl_scripts_root}/${_ssl_base}" ]; then
    case "${_ssl_base}" in
      test-*.sh) _ssl_hits+=("${_ssl_base}") ;;
    esac
  fi

  # Stratum (a): strict basename pairing, plus the lib/ "-lib.sh" suffix variant.
  _ssl_cand1="test-${_ssl_base}"
  _ssl_cand2="test-${_ssl_noext}-lib.sh"
  if [ -f "${_ssl_tests_dir}/${_ssl_cand1}" ]; then
    _ssl_hits+=("${_ssl_cand1}")
  fi
  if [ -f "${_ssl_scripts_root}/${_ssl_cand1}" ]; then
    _ssl_hits+=("${_ssl_cand1}")
  fi
  if [ "${_ssl_cand2}" != "${_ssl_cand1}" ] && [ -f "${_ssl_tests_dir}/${_ssl_cand2}" ]; then
    _ssl_hits+=("${_ssl_cand2}")
  fi

  # Stratum (b): grep-based reference lookup, every suite that textually references the touched
  # basename. Many-to-one allowed.
  if [ -d "${_ssl_tests_dir}" ]; then
    while IFS= read -r _ssl_f; do
      [ -n "${_ssl_f}" ] || continue
      _ssl_hits+=("$(basename "${_ssl_f}")")
    done < <(grep -l -F -- "${_ssl_base}" "${_ssl_tests_dir}"/test-*.sh 2>/dev/null)
  fi
  if [ -d "${_ssl_scripts_root}" ]; then
    while IFS= read -r _ssl_f; do
      [ -n "${_ssl_f}" ] || continue
      _ssl_hits+=("$(basename "${_ssl_f}")")
    done < <(grep -l -F -- "${_ssl_base}" "${_ssl_scripts_root}"/test-*.sh 2>/dev/null)
  fi

  if [ "${#_ssl_hits[@]}" -gt 0 ]; then
    printf '%s\n' "${_ssl_hits[@]}" | sort -u
  fi

  unset _ssl_path _ssl_base _ssl_noext _ssl_hit _ssl_cand1 _ssl_cand2 _ssl_f _ssl_hits
  unset _ssl_scripts_root _ssl_tests_dir _ssl_roots
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
      # Compositional accumulation: an unmappable path contributes the sentinel as one more
      # member of the running union rather than short-circuiting the whole call -- the sentinel
      # is a floor contributed by its own member, never a ceiling imposed on the set. Continue
      # resolving the remaining paths so their real suites are not discarded.
      _ssl_all+=("${SUITE_SELECTION_FULL_SWEEP_SENTINEL}")
      continue
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
  local _ssl_suite_path _ssl_first_touch _ssl_first_deployed _ssl_parent _ssl_ext_dir

  _ssl_suite_path=""
  if [ -f "${_SSL_TESTS_DIR}/${_ssl_suite_base}" ]; then
    _ssl_suite_path="${_SSL_TESTS_DIR}/${_ssl_suite_base}"
  elif [ -f "${_SSL_SCRIPTS_ROOT}/${_ssl_suite_base}" ]; then
    _ssl_suite_path="${_SSL_SCRIPTS_ROOT}/${_ssl_suite_base}"
  else
    # Neither of this library's own two fixed locations has the suite file -- probe every
    # extension's own scripts/tests/ then scripts/ (same per-extension loop shape run-all.sh's
    # own source-store discovery uses), but ONLY when running from the source store (the
    # core/manifest.json marker, shared with _ssl_roots_for_path via _ssl_extensions_parent).
    # First match wins; suite basenames are corpus-unique by the existing test-*.sh discovery
    # convention. In deployed mode the marker never exists, so this loop never runs there --
    # the two fixed-location probes above already cover the whole merged flat tree.
    _ssl_parent="$(_ssl_extensions_parent)"
    if [ -n "${_ssl_parent}" ]; then
      for _ssl_ext_dir in "${_ssl_parent}"/*/; do
        [ -d "${_ssl_ext_dir}scripts" ] || continue
        if [ -f "${_ssl_ext_dir}scripts/tests/${_ssl_suite_base}" ]; then
          _ssl_suite_path="${_ssl_ext_dir}scripts/tests/${_ssl_suite_base}"
          break
        elif [ -f "${_ssl_ext_dir}scripts/${_ssl_suite_base}" ]; then
          _ssl_suite_path="${_ssl_ext_dir}scripts/${_ssl_suite_base}"
          break
        fi
      done
    fi
  fi

  if [ -z "${_ssl_suite_path}" ] || [ ! -r "${_ssl_suite_path}" ]; then
    echo "source-only"
    unset _ssl_suite_base _ssl_touched_base _ssl_suite_path _ssl_first_touch _ssl_first_deployed _ssl_parent _ssl_ext_dir
    return 0
  fi

  if ! grep -q -F -- "${_ssl_touched_base}" "${_ssl_suite_path}" 2>/dev/null; then
    echo "source-only"
    unset _ssl_suite_base _ssl_touched_base _ssl_suite_path _ssl_first_touch _ssl_first_deployed _ssl_parent _ssl_ext_dir
    return 0
  fi

  # shellcheck disable=SC2016
  if ! grep -q -E '\$REPO_ROOT/\.claude|/\.claude/' "${_ssl_suite_path}" 2>/dev/null; then
    echo "source-only"
    unset _ssl_suite_base _ssl_touched_base _ssl_suite_path _ssl_first_touch _ssl_first_deployed _ssl_parent _ssl_ext_dir
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

  unset _ssl_suite_base _ssl_touched_base _ssl_suite_path _ssl_first_touch _ssl_first_deployed _ssl_parent _ssl_ext_dir
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
    if [ "${_ssl_line}" = "${SUITE_SELECTION_FULL_SWEEP_SENTINEL}" ]; then
      # Mixed set: carry the sentinel through as a bare, unclassified line -- it is not a real
      # suite file, so classifying it against suite_selection_classify would be nonsensical.
      # The real suites' rows below are never dropped on its account.
      echo "${_ssl_line}"
      continue
    fi
    _ssl_class="$(suite_selection_classify "${_ssl_line}" "${_ssl_first_base}")"
    echo "${_ssl_line}|${_ssl_class}"
  done

  unset _ssl_args _ssl_first_base _ssl_line _ssl_class _ssl_selected
  return 0
}

# ─── Declarative class / tag / cost-class selection (Phase 14, run-all.sh's --class/--tag/
# --cost-class) ─────────────────────────────────────────────────────────────────────────────────
# A SECOND, independent selection mode, orthogonal to the touched-path mapping above: instead of
# resolving a source edit to the suites that cover it, these select directly from declarative
# classification data this corpus already has, with ZERO new per-suite authoring:
#   class       tests/suite-classification.data's own `class` column (unit/integration).
#   tag         mechanically derived, never hand-authored: every invoked-tool token already named
#               by an integration-class suite's own `reason` column (e.g.
#               "invokes:deploy-headless.sh,verify-deploy.sh" -> tags "deploy-headless",
#               "verify-deploy"), PLUS the fixed tag "lint" for every discovered test-lint-*.sh
#               suite. A suite with neither source present simply carries zero tags.
#   cost-class  tests/suite-cost-hints.txt's advisory wall_ms column, bucketed at the fixed
#               thresholds below. A suite absent from that (optional) file is bucket "unknown" --
#               never silently folded into "free".
#
# Each axis exposes a KNOWN-VOCABULARY function (the closed set of values a caller -- run-all.sh
# -- must validate an incoming --class/--tag/--cost-class token against BEFORE calling the
# matching selector, mirroring --only's own "a partially-valid list must refuse loudly, not
# silently run a subset" discipline) and a SELECTOR function (the union of basenames matching ANY
# given value within that one axis). Neither validates its own input and neither ever exits --
# same contract as every function above; an unrecognized value simply selects nothing.

SUITE_SELECTION_COST_FREE_MS=2000
SUITE_SELECTION_COST_MODERATE_MS=30000

# suite_selection_known_classes -- stdout: every class value present anywhere in
# tests/suite-classification.data, one per line, sorted unique. Empty when the file is
# absent/unreadable (the correct fail-safe: no declarative data exists to select against).
suite_selection_known_classes() {
  local _ssl_file="${_SSL_TESTS_DIR}/suite-classification.data"
  [ -r "${_ssl_file}" ] || return 0
  awk -F'\t' '!/^#/ && NF>=2 {print $2}' "${_ssl_file}" 2>/dev/null | sort -u
  unset _ssl_file
  return 0
}

# suite_selection_by_class CLASS[,CLASS...] -- stdout: discovered-suite basenames whose
# suite-classification.data row's class matches ANY given value, sorted unique. A value the file
# never declares simply matches nothing -- validate against suite_selection_known_classes first
# for the loud-refusal behavior.
suite_selection_by_class() {
  local _ssl_file="${_SSL_TESTS_DIR}/suite-classification.data"
  local _ssl_wanted="$1"
  [ -r "${_ssl_file}" ] || return 0
  awk -F'\t' -v wanted=",${_ssl_wanted}," \
    '!/^#/ && NF>=2 { if (index(wanted, "," $2 ",") > 0) print $1 }' \
    "${_ssl_file}" 2>/dev/null | sort -u
  unset _ssl_file _ssl_wanted
  return 0
}

# suite_selection_known_tags -- stdout: every tag value currently derivable across the discovered
# corpus (see this section's header for the derivation rule), one per line, sorted unique. Never
# hand-authored, so this always reflects the LIVE corpus, not a stale snapshot.
suite_selection_known_tags() {
  local _ssl_file="${_SSL_TESTS_DIR}/suite-classification.data"
  local _ssl_base _ssl_class _ssl_reason _ssl_tok _ssl_f
  local -a _ssl_tags=()

  if [ -r "${_ssl_file}" ]; then
    while IFS=$'\t' read -r _ssl_base _ssl_class _ssl_reason; do
      case "${_ssl_base}" in \#*|"") continue ;; esac
      [ "${_ssl_class}" = "integration" ] || continue
      _ssl_reason="${_ssl_reason#invokes:}"
      _ssl_reason="${_ssl_reason%% *}"
      while IFS= read -r _ssl_tok; do
        [ -n "${_ssl_tok}" ] && _ssl_tags+=("${_ssl_tok%.sh}")
      done < <(printf '%s\n' "${_ssl_reason}" | tr ',' '\n')
    done < "${_ssl_file}"
  fi

  if [ -d "${_SSL_TESTS_DIR}" ]; then
    for _ssl_f in "${_SSL_TESTS_DIR}"/test-lint-*.sh; do
      if [ -e "${_ssl_f}" ]; then
        _ssl_tags+=("lint")
        break
      fi
    done
  fi

  if [ "${#_ssl_tags[@]}" -gt 0 ]; then
    printf '%s\n' "${_ssl_tags[@]}" | sort -u
  fi

  unset _ssl_file _ssl_base _ssl_class _ssl_reason _ssl_tok _ssl_f _ssl_tags
  return 0
}

# suite_selection_by_tag TAG[,TAG...] -- stdout: discovered-suite basenames carrying ANY given
# tag, sorted unique. A value this library cannot currently derive simply matches nothing --
# validate against suite_selection_known_tags first for the loud-refusal behavior.
suite_selection_by_tag() {
  local _ssl_file="${_SSL_TESTS_DIR}/suite-classification.data"
  local -a _ssl_wanted_arr=()
  local _ssl_w _ssl_base _ssl_class _ssl_reason _ssl_tok _ssl_f
  local -a _ssl_hits=()

  IFS=',' read -r -a _ssl_wanted_arr <<< "$1"

  if [ -r "${_ssl_file}" ]; then
    while IFS=$'\t' read -r _ssl_base _ssl_class _ssl_reason; do
      case "${_ssl_base}" in \#*|"") continue ;; esac
      [ "${_ssl_class}" = "integration" ] || continue
      _ssl_reason="${_ssl_reason#invokes:}"
      _ssl_reason="${_ssl_reason%% *}"
      while IFS= read -r _ssl_tok; do
        [ -n "${_ssl_tok}" ] || continue
        _ssl_tok="${_ssl_tok%.sh}"
        for _ssl_w in "${_ssl_wanted_arr[@]}"; do
          [ "${_ssl_tok}" = "${_ssl_w}" ] && _ssl_hits+=("${_ssl_base}")
        done
      done < <(printf '%s\n' "${_ssl_reason}" | tr ',' '\n')
    done < "${_ssl_file}"
  fi

  for _ssl_w in "${_ssl_wanted_arr[@]}"; do
    if [ "${_ssl_w}" = "lint" ] && [ -d "${_SSL_TESTS_DIR}" ]; then
      for _ssl_f in "${_SSL_TESTS_DIR}"/test-lint-*.sh; do
        [ -e "${_ssl_f}" ] && _ssl_hits+=("$(basename "${_ssl_f}")")
      done
    fi
  done

  if [ "${#_ssl_hits[@]}" -gt 0 ]; then
    printf '%s\n' "${_ssl_hits[@]}" | sort -u
  fi

  unset _ssl_file _ssl_wanted_arr _ssl_w _ssl_base _ssl_class _ssl_reason _ssl_tok _ssl_f _ssl_hits
  return 0
}

# suite_selection_known_cost_classes -- stdout: the fixed, closed bucket-name vocabulary, one per
# line (free, moderate, slow, unknown). Unlike known_classes/known_tags this is NOT derived from
# any file -- the bucket NAMES are fixed; per-suite bucket MEMBERSHIP is what the hints file
# drives (see suite_selection_by_cost_class).
suite_selection_known_cost_classes() {
  printf '%s\n' free moderate slow unknown
  return 0
}

# suite_selection_by_cost_class CLASS[,CLASS...] -- stdout: discovered-suite basenames whose
# tests/suite-cost-hints.txt wall_ms bucket matches ANY given value, sorted unique. Thresholds:
# < SUITE_SELECTION_COST_FREE_MS -> free; < SUITE_SELECTION_COST_MODERATE_MS -> moderate;
# otherwise slow. A suite absent from the (advisory, optional) hints file is bucket "unknown" --
# never silently folded into "free". An unrecognized wanted value simply matches nothing.
suite_selection_by_cost_class() {
  local _ssl_file="${_SSL_TESTS_DIR}/suite-cost-hints.txt"
  local -a _ssl_wanted_arr=()
  local _ssl_w _ssl_base _ssl_ms _ssl_bucket
  local -a _ssl_hits=()
  local -A _ssl_hinted=()

  IFS=',' read -r -a _ssl_wanted_arr <<< "$1"

  if [ -r "${_ssl_file}" ]; then
    while IFS=',' read -r _ssl_base _ssl_ms; do
      [ -n "${_ssl_base}" ] || continue
      case "${_ssl_base}" in \#*) continue ;; esac
      _ssl_hinted["${_ssl_base}"]=1
      if [ "${_ssl_ms}" -lt "${SUITE_SELECTION_COST_FREE_MS}" ] 2>/dev/null; then
        _ssl_bucket="free"
      elif [ "${_ssl_ms}" -lt "${SUITE_SELECTION_COST_MODERATE_MS}" ] 2>/dev/null; then
        _ssl_bucket="moderate"
      else
        _ssl_bucket="slow"
      fi
      for _ssl_w in "${_ssl_wanted_arr[@]}"; do
        [ "${_ssl_w}" = "${_ssl_bucket}" ] && _ssl_hits+=("${_ssl_base}")
      done
    done < "${_ssl_file}"
  fi

  for _ssl_w in "${_ssl_wanted_arr[@]}"; do
    if [ "${_ssl_w}" = "unknown" ]; then
      while IFS= read -r _ssl_base; do
        [ -n "${_ssl_base}" ] || continue
        [ -n "${_ssl_hinted[${_ssl_base}]:-}" ] || _ssl_hits+=("${_ssl_base}")
      done < <(_ssl_discovered_basenames)
    fi
  done

  if [ "${#_ssl_hits[@]}" -gt 0 ]; then
    printf '%s\n' "${_ssl_hits[@]}" | sort -u
  fi

  unset _ssl_file _ssl_wanted_arr _ssl_w _ssl_base _ssl_ms _ssl_bucket _ssl_hits _ssl_hinted
  return 0
}
