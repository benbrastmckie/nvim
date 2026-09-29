#!/usr/bin/env bash
# file-scope-overlap.sh - Single source of truth for the directory-prefix file_scope overlap
# predicate.
#
# Canonical prose definition: context/patterns/file-footprint-overlap.md. This file transcribes
# that document's algorithm EXACTLY ONCE and is the only place the algorithm's logic is written
# down as code -- every consumer sources this file (or, for the jq-embedded consumer, splices
# $FILE_SCOPE_OVERLAP_JQ_DEFS into its own jq -n program) rather than re-deriving or restating the
# rule locally.
#
# Exports TWO things, for two different consumption shapes:
#
#   (a) scopes_overlap() - a callable bash function, for a caller (scripts/task-lock.sh) that
#       shells out to jq once per pairwise comparison.
#   (b) FILE_SCOPE_OVERLAP_JQ_DEFS - a variable holding raw jq `def` source text, for a caller
#       (scripts/orchestrate-batch-admit.sh) that embeds the algorithm inside one larger,
#       single-pass `jq -n --slurpfile` program and cannot shell out per comparison.
#
# FILE_SCOPE_OVERLAP_JQ_DEFS is assigned via a QUOTED heredoc (`<<'JQDEFS'`) so bash performs NO
# parameter/command expansion on its body -- the jq source (full of literal `"`, `+`, and `|`
# characters) is stored verbatim, with zero escaping cost to either this file or its splicing
# callers. See the plan's D1 decision record for why this `.sh`-lib-with-embedded-jq-defs shape
# was chosen over a standalone `.jq` file.

# ─── norm / scopes_overlap_first / self_mod_match (jq) ─────────────────────────────────────────
# Consumed by BOTH scopes_overlap() below (spliced directly into its own jq -n program) and by
# orchestrate-batch-admit.sh (splices this text into its larger program). Do not edit either
# consumer's copy of this logic -- there is no other copy; edit only here.
read -r -d '' FILE_SCOPE_OVERLAP_JQ_DEFS <<'JQDEFS'
# --- norm: path normalization per file-footprint-overlap.md's "Path Normalization" section ---
def norm: rtrimstr("/");

# --- is_glob_entry: true iff a declared file_scope entry string contains a glob metacharacter
# (`*`, `?`, or `[`). Same character class as this codebase's two existing BASH transcriptions of
# this same test -- path_covered_by_scope() below (`case "$entry" in *[*?\[]*) ...`) and
# orchestrate-cycle-plan.sh's _sibling_territory_classify_entry() (`case "$path" in *[*?\[]*)
# echo "glob" ...`) -- so all three forms cannot silently diverge on what counts as glob-shaped.
# A glob entry is invisible to the symmetric Overlap predicate above (scopes_overlap_first) BY
# DESIGN -- see context/patterns/file-footprint-overlap.md's Non-Goals section, which excludes
# glob matching from Overlap deliberately. It is NOT invisible to the separate Containment
# predicate (path_covered_by_scope() below, consumed by git-snapshot.sh), which already matches
# globs correctly via bash's own `case` glob semantics. This def exists so Check 11
# (validate-state.sh) and Class G (orchestrate-predispatch-review.sh) can both warn on the
# Overlap-blind-spot consequence without transcribing a fourth copy of the character class.
def is_glob_entry: test("[*?\\[]");

# --- scopes_overlap_first: the overlap predicate itself, per file-footprint-overlap.md's
# "Overlap Rule" section (exact match, or either side a directory-prefix ancestor of the other).
# Returns the first overlapping path FROM other_scope (the "foreign" side, matching
# task-lock.sh's historical scopes_overlap() call convention scopes_overlap "$own" "$other") on
# a hit, or jq `empty` (not `null`) when no pair overlaps -- callers that bind this via `as`
# inside an array comprehension rely on `empty` to contribute zero elements, not one null one.
def scopes_overlap_first(own_scope; other_scope):
  (own_scope // []) as $sa | (other_scope // []) as $sb |
  [ $sa[] as $pa | $sb[] as $pb |
    ($pa|norm) as $na | ($pb|norm) as $nb |
    select($na == $nb or ($nb | startswith($na + "/")) or ($na | startswith($nb + "/"))) |
    $pb
  ] | first // empty;

# --- self_mod_match: a further application of the SAME overlap predicate above -- the
# candidate's own file_scope compared against a static declared list of orchestrator-critical
# paths, rather than against another task's file_scope. Not a new matching rule; only what the
# candidate is compared against differs. Returns the first matching {path, label} entry, in the
# critical-path data file's declared order.
def self_mod_match($cscope; $crit):
  ($cscope // []) as $sa |
  [ $sa[] as $pa | $crit[] as $ce |
    ($pa|norm) as $na | ($ce.path|norm) as $nb |
    select($na == $nb or ($na | startswith($nb + "/")) or ($nb | startswith($na + "/"))) |
    $ce
  ] | first;
  # NOTE: deliberately `first` (never `first // empty`) -- unlike scopes_overlap_first above,
  # the result of this def is bound via `as $sm_hit |` OUTSIDE any array comprehension in every
  # known caller. An `empty` result there would make the ENTIRE per-candidate pipeline produce
  # zero output (the `as` construct binds by iterating its generator; a generator that yields
  # nothing means the downstream pipe never runs at all), silently dropping that candidate's
  # verdict from stdout. Returning `null` on no-match instead lets `$sm_hit != null` downstream
  # evaluate to `false` exactly once, as intended.

# --- Session-registry contention (D4) -- input 2 of the three bounded contention inputs. This
# is the ONLY input carrying its own precomputed, unioned file_scope, independent of any single
# task's state.json entry: held locks (input 1) carry no file_scope of their own (holder.json has
# none -- the other side's scope is always re-fetched from state.json), and non-terminal
# state.json tasks (input 3) carry ONE task's own declared scope, not a union across everything a
# session is concurrently touching. See context/patterns/file-footprint-overlap.md for the full
# three-input asymmetry statement. ---

# --- edge_connected_nums: task numbers connected to $cnum by a dependencies[] edge in EITHER
# direction, using the identical two-clause predicate the existing collision-scan comparison_set
# construction uses (candidate depends on it, OR it depends on candidate) -- a factoring of that
# existing rule, not a new one. Excludes $cnum itself.
def edge_connected_nums($cnum; $all):
  ( [$all[] | select(.project_number == $cnum) | (.dependencies // [])] | first // []) as $c_deps |
  [
    $all[] | . as $t |
    select(
      ($t.project_number != $cnum) and
      (
        ($c_deps | index($t.project_number)) != null
        or
        (($t.dependencies // []) | index($cnum)) != null
      )
    ) | $t.project_number
  ];

# --- session_contention: D4's three exclusions, in order, then scopes_overlap_first against the
# surviving sessions' own file_scope. Sessions are visited in ASCENDING session_id string order;
# first hit wins, no exhaustive collection -- matching this predicate's existing first-match-wins
# convention. Returns {session_id, covered_task_number, overlapping_path, liveness_reason} on a
# hit, or jq `null` (never `empty`) on no-hit -- same reason as self_mod_match above: this is
# bound via `as` outside an array comprehension by every known caller.
#   $cscope  - the candidate's own (normalized-on-comparison) file_scope array.
#   $cnum    - the candidate's own task number.
#   $own_sid - the CALLER's own session_id (batch-admit's --session-id, or cmd_acquire's
#              acquiring session_id) -- D4 exclusion 1 excludes this session from contending
#              against itself. Pass "" (or any value no session will ever carry) to disable
#              self-exclusion; D6's degradation path instead passes an EMPTY $sessions array so
#              this def is never reached at all when identity is unknown.
#   $all     - active_projects array (for edge_connected_nums's dependency lookup).
#   $sessions - session-list's NDJSON array (session_id, task_numbers, file_scope, live,
#              liveness_reason per entry).
def session_contention($cscope; $cnum; $own_sid; $all; $sessions):
  edge_connected_nums($cnum; $all) as $edge_nums |
  (
    [
      [$sessions[]] | sort_by(.session_id) | .[] as $sess |
      # D4 exclusion 1: self-exclusion by session id.
      select($sess.session_id != $own_sid) |
      # D4 exclusion 2: liveness. `live` is already computed uniformly by session-list as
      # NOT IN {dead-pid, stale-heartbeat} -- true for pid-alive, corrupt, AND undeterminable,
      # matching "live == true, corrupt, and undeterminable-liveness entries DO contend" exactly.
      select($sess.live == true) |
      # D4 exclusion 3: dependency-edge, evaluated per covered task number. The session is
      # excluded iff EVERY covered task number is either $cnum itself or edge-connected to it;
      # it contends iff at least one covered task number is neither.
      (($sess.task_numbers // [])
        | map(. as $tn | select($tn != $cnum and (($edge_nums | index($tn)) == null)))
      ) as $surviving_nums |
      select(($surviving_nums | length) > 0) |
      ($surviving_nums | min) as $covered_num |
      scopes_overlap_first($cscope; ($sess.file_scope // [])) as $ov_path |
      select($ov_path != null and $ov_path != "") |
      {session_id: $sess.session_id, covered_task_number: $covered_num,
       overlapping_path: $ov_path, liveness_reason: $sess.liveness_reason}
    ] | first
  );
  # `[ ... ] | first` (list comprehension, then .[0]) -- the SAME idiom scopes_overlap_first and
  # self_mod_match above both use, and for the same reason: `generator | first` (without the
  # enclosing `[...]`) pipes EACH of the generator's outputs through `.[0]` individually (an
  # error on a non-array output) and produces ZERO outputs -- never a `null` fallback -- when the
  # generator itself produces zero outputs. `[...] | first` always yields exactly one value
  # (the first match, or `null` for an empty array), matching this def's "return null, never
  # empty, on no-hit" contract from a single evaluation.
JQDEFS

# ─── scopes_overlap: bash-callable wrapper, today's exact signature and return convention ──────
# Usage: scopes_overlap "$scope_a_json" "$scope_b_json"
# scope_a_json / scope_b_json are compact JSON arrays of path strings. Prints the first
# overlapping path FROM scope_b (the "foreign" side, per cmd_acquire's call convention
# scopes_overlap "$own_scope" "$other_scope") on stdout when an overlap is found; prints nothing
# otherwise. Callers use `[ -n "$out" ]` as the boolean test and reuse the printed path in
# ABORT/WARN messages. Implemented by splicing FILE_SCOPE_OVERLAP_JQ_DEFS into a `jq -n` program
# rather than restating the algorithm -- this function is a thin bash-calling-convention shim
# over scopes_overlap_first(), nothing more.
scopes_overlap() {
  local scope_a="$1" scope_b="$2"
  local prog="${FILE_SCOPE_OVERLAP_JQ_DEFS}
scopes_overlap_first(\$a; \$b)"
  jq -n -r --argjson a "$scope_a" --argjson b "$scope_b" "$prog" 2>/dev/null
}

# ─── path_covered_by_scope: one-directional containment predicate (ADDITIVE, sibling function) ─
# Usage: path_covered_by_scope "$path" "$scope_entry_1" ["$scope_entry_2" ...]
# Answers a DIFFERENT question from scopes_overlap() above: is one concrete path P covered by a
# declared file_scope (an array of entries), rather than whether two scopes-as-sets overlap. Per
# context/patterns/file-footprint-overlap.md's "Containment vs. Overlap" section, P is covered by
# entry S when P == S, or P starts with S + "/", or (containment-only extension) S is a glob
# pattern that matches P under ordinary bash pattern matching. Pure bash -- no jq, no subshell
# per call -- since this predicate has exactly one string-comparison consumer (git-snapshot.sh's
# per-dirty-path classification loop) and does not need jq's array/JSON handling that
# scopes_overlap()'s callers (task-lock.sh, orchestrate-batch-admit.sh) already have in hand.
# Returns 0 (covered) as soon as any entry matches; 1 (not covered) if none do, including when
# no scope entries are passed at all.
path_covered_by_scope() {
  local path="$1"
  shift
  local norm_path="${path%/}"
  local entry norm_entry

  for entry in "$@"; do
    norm_entry="${entry%/}"

    # Clause 1: exact match.
    if [ "$norm_path" = "$norm_entry" ]; then
      return 0
    fi

    # Clause 2: norm_entry is a directory-prefix ancestor of norm_path.
    case "$norm_path" in
      "$norm_entry"/*)
        return 0
        ;;
    esac

    # Clause 3 (containment-only extension): norm_entry is a glob pattern that matches
    # norm_path. Only attempted when norm_entry actually contains a glob metacharacter, so an
    # ordinary literal entry never risks an accidental pattern-matching interpretation.
    case "$norm_entry" in
      *[\*\?\[]*)
        if [[ "$norm_path" == $norm_entry ]]; then
          return 0
        fi
        ;;
    esac
  done

  return 1
}
