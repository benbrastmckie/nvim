#!/usr/bin/env bash
# state-writer-boundary-patterns-lib.sh - Single source of truth for the Python/interpreter
# re-serialization channel of the state-writer boundary rule.
#
# Exports the candidate pattern limb and classification predicate consumed by BOTH the
# content lint (scripts/lint/lint-state-writer-boundary.sh, gate 12) and the write-time guard
# hook (hooks/validate-no-python-state-write.sh). Neither consumer defines the open()-on-
# state.json detection regex or its write-mode predicate locally -- this is the ONLY place they
# are defined, mirroring scripts/lib/task-reference-patterns.sh's dual-consumer structure.
#
# This library covers ONLY the Python-shaped channel: a `json.dump`/`json.dumps`/`json.load`
# write path routed through a write-capable `open()` call whose path literal names a state.json
# target (live, archive, or vault-root). The jq-shaped channel (hand-rolled `jq ... > tmp && mv`)
# remains lint-state-writer-boundary.sh's own, pre-existing, byte-unchanged CANDIDATE_PATTERN
# limbs and classify_line branches; this library does not touch them.
#
# Why key on open() + mode rather than a bare json.dump/json.dumps/json.load token: the research
# behind this library measured that an open()+state.json+write-mode predicate produces ZERO new
# candidate matches anywhere in the live source store beyond this library and the lint itself,
# whereas a bare json.dump/json.dumps token would false-positive on every legitimate JSON writer
# in the tree (the literature extension's manifest/result-envelope writers among them) and
# require a large new allowlist. Keying on the write target rather than the serialization call
# keeps the predicate narrow without sacrificing coverage: `json.dump`'s own write happens
# through an already-open file object, so the file object's own open() call -- not the dump
# call -- is the only site in the source text that can name the target path at all.
#
# Why mode-based, not ensure_ascii-based: the hazard this rule guards against has two
# independent halves -- (1) an unsynchronized, non-mutex-guarded read-modify-write racing other
# writers, and (2) a default-ensure_ascii round-trip re-escaping every non-ASCII byte in the
# file into a whole-file diff. Gating only on `ensure_ascii=False`'s absence would catch half (2)
# and silently bless half (1) (an `ensure_ascii=False` write is still an unsynchronized
# read-modify-write that bypasses state-write.sh's mutex, staging, and validation steps). This
# library's predicate fires on a write-capable open() mode regardless of ensure_ascii, by design.
#
# Why `r+` counts as write-capable: the in-place rewrite idiom (`open(path, "r+")` ->
# `json.load` -> `seek(0)` -> `json.dump`) backs both the read and the write through one open()
# call. A predicate that exempted `r+` as "just a read mode" would miss that idiom entirely.
#
# Usage: `source` this file, then:
#   - Append `$STATE_WRITER_PY_CANDIDATE_LIMB` as one more alternation limb on a lint's existing
#     CANDIDATE_PATTERN (grep -E), so lines carrying a Python open()-on-state.json call are
#     surfaced as candidates alongside the jq-shaped limbs.
#   - Call `state_writer_py_classify_line <line-of-text>` on each candidate line. It echoes
#     exactly one of:
#       "VIOLATION"                                    -- write-capable open() on a state.json target
#       "EXEMPT: <reason>"                              -- read-only open(), or no state.json literal
#                                                          inside the open() call's own argument list
#     mirroring lint-state-writer-boundary.sh's own classify_line verdict vocabulary so a caller
#     can treat the two functions' return values identically.

# ─── Candidate pattern limb ─────────────────────────────────────────────────────────────────
# Matches an `open(` call whose argument list (up to the first unmatched close paren after it)
# contains a `state.json` literal, regardless of path prefix (specs/, specs/archive/, or a
# vault-root `${vault_path}/state.json`-shaped f-string) -- the same bare substring test the
# jq-shaped limbs already rely on for archive/vault coverage. This limb is deliberately broad
# (it does not itself check the write mode); state_writer_py_classify_line below narrows.
# shellcheck disable=SC2034  # Exported public contract: consumed by lint-state-writer-boundary.sh
# and validate-no-python-state-write.sh (both source this file), not locally unused.
STATE_WRITER_PY_CANDIDATE_LIMB='open\([^)]*state\.json'

# ─── Write-capable mode predicate ───────────────────────────────────────────────────────────
# A quoted mode literal counts as write-capable iff it is one of: w, a, r+, w+, a+, x. A bare
# (no-mode, defaults to 'r') or an explicit plain 'r' open() is read-only and exempt. The
# alternation below deliberately cannot match a lone 'r' (r\+ requires the literal plus sign),
# so "open(path, 'r')" and "open(path)" both fall through to the EXEMPT branch below.
_STATE_WRITER_PY_WRITE_MODE_ERE="['\"](r\\+|w\\+?|a\\+?|x)['\"]"

# state_writer_py_classify_line <line-of-text>
#
# Narrows a line already known to match $STATE_WRITER_PY_CANDIDATE_LIMB. Extracts the first
# open(...) call's own argument list via a simple non-nested slice (shortest-match up to "open("
# then up to the first ")"), which is sufficient for every open() shape observed in the source
# store (including an f-string path argument, whose `{...}` interpolation contains no literal
# ')'). An open() call whose own arguments contain a literal ')' is outside this predicate's
# structural model -- the same class of limitation the existing lint's bare-`mv`-source
# extraction already accepts, stated here rather than silently inherited.
state_writer_py_classify_line() {
    local text="$1"
    local open_args

    open_args="${text#*open(}"
    open_args="${open_args%%)*}"

    if [[ ! "$open_args" =~ state\.json ]]; then
        printf 'EXEMPT: no state.json literal inside the open() call argument list\n'
        return 0
    fi

    if [[ "$open_args" =~ $_STATE_WRITER_PY_WRITE_MODE_ERE ]]; then
        printf 'VIOLATION\n'
        return 0
    fi

    printf 'EXEMPT: read-only open() (no write-capable mode token)\n'
    return 0
}
