# Research Report: Task #440

**Task**: 440 - Fix file_scope glob containment predicate
**Started**: 2026-10-17T00:00:00Z
**Completed**: 2026-10-17T00:00:00Z
**Effort**: small (two ~10-line function edits plus test coverage)
**Dependencies**: None (task 425 checked and confirmed non-overlapping — see Decisions)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/git-commit-scoped.sh`,
  `agent-system/extensions/core/scripts/git-commit-phase.sh`,
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`,
  `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  `specs/state.json` (live `file_scope` declarations), `git log`
- A scratch reproduction of the proposed fix, run directly in bash
**Artifacts**:
- This report: `specs/440_fix_file_scope_glob_containment_predicate/reports/01_glob-containment-predicate-fix.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is confirmed exactly as described in the dispatch: both `is_contained_v10()`
  (`git-commit-scoped.sh`) and its ported twin `is_contained()` (`git-commit-phase.sh`) quote the
  file_scope entry variable inside a `case` pattern, which disables glob interpretation of any
  `*` characters the entry itself contains. A `/**`-suffixed entry therefore only matches a path
  that literally contains two asterisk characters — never a real file — so prefix-style
  containment for such entries never fires at either site.
- A minimal, scope-preserving fix is a single added branch per function: detect a literal
  trailing `/**` via parameter-expansion suffix-stripping (`"${entry_norm%/\*\*}"`, with the
  asterisks backslash-escaped so the expansion strips only a literal two-character suffix, not a
  glob), then test ordinary directory-prefix containment against the stripped base. Every other
  branch (exact match, the two existing ancestor-direction `case` tests) is left untouched, so
  non-`/**` entries behave identically to today.
- The fix was validated against nine cases in a bash scratch harness (direct child, deeply
  nested descendant, two same-prefix siblings that must NOT match, an unrelated sibling
  directory, both non-glob forms, and the bare directory itself) — all passed. See Findings for
  the harness and Recommendations for the exact diff.
- Task 425 (the sibling containment-predicate defect in `orchestrate-cycle-postflight.sh`) was
  checked per the dispatch's instruction: it is a separate root cause (a `jq` `startswith`
  prefix test over literal, non-glob paths) at a separate site with a disjoint `file_scope`, and
  the two fixes share no helper function. No `dependencies[]` edge is needed.
- `git-staging-scope.md` documents that `git-commit-phase.sh`'s own self-check (site 2) is
  "deliberately redundant, not load-bearing" once `git-commit-scoped.sh`'s V10 gate (site 3) is
  in place, because the phase wrapper always forwards `--task` into `git-commit-scoped.sh`. The
  `git-commit-scoped.sh` fix is therefore the load-bearing one; the `git-commit-phase.sh` fix
  closes the same hole at its own (redundant-but-real) layer, exactly as the dispatch requires
  for both sites.

## Context & Scope

Scope is exactly the dispatch's: fix the `/**`-suffix containment bug at both named sites without
widening containment for any entry that does not end in `/**`, and pair the fix with test
coverage proving the four required behaviors (direct child, deep descendant, sibling exclusion,
non-glob forms unchanged). This report also verifies the task-425 relationship the dispatch asks
to check before starting.

Out of scope (noted but not pursued further): a third live `file_scope` entry observed in
`specs/state.json`,
`agent-system/extensions/{present,formal,cslib,web,literature,lean,nvim,nix,epidemiology,books}/**`,
combines brace expansion with the `/**` suffix. Neither predicate ever evaluates shell
expansion on file_scope entries (nor should it — evaluating arbitrary task-authored strings as
shell glob/brace syntax would be a far larger hazard than the present bug), so that entry is,
and will remain after this fix, matched only as the single literal string it is — brace groups
are not expanded into multiple prefixes. This is a pre-existing, independent limitation; it is
flagged here as a candidate follow-up, not folded into this task's fix.

## Findings

### Codebase Patterns

**Root cause, site 1 — `git-commit-scoped.sh:520-539`** (`is_contained_v10`):

```bash
is_contained_v10() {
  local path="${1%/}" entry entry_norm
  for entry in "${containment_scope_arr[@]}"; do
    entry_norm="${entry%/}"
    [ "$path" = "$entry_norm" ] && return 0
    case "$path" in
      "$entry_norm"/*) return 0 ;;
    esac
    case "$entry_norm" in
      "$path"/*) return 0 ;;
    esac
  done
  return 1
}
```

`"$entry_norm"` is fully quoted inside the `case "$path" in ...)` pattern. Quoting a variable
inside a case pattern makes its *expanded value* literal text — any `*`/`?`/`[` characters the
value itself contains are matched character-for-character, not interpreted as glob wildcards.
For `entry_norm = "agent-system/extensions/core/**"`, the resulting pattern is the literal
string `agent-system/extensions/core/**` followed by the *unquoted* `/*` suffix already in the
source — i.e. the full required match is the literal substring `core/**/` (two literal asterisk
characters) followed by anything. No real path contains that substring, so this branch can never
fire for a `/**` entry. The symmetric branch (`case "$entry_norm" in "$path"/*)`) is unaffected
by this specific bug for the common cases tested below (see Decisions) because the glob-capable
side of that comparison is `$path`, not `$entry_norm`.

**Root cause, site 2 — `git-commit-phase.sh:244-255`** (`is_contained`, the "ported twin"
referenced in the dispatch, inside the "Phase-Commit Containment Self-Check" block):

```bash
is_contained() {
  local path="$1" entry
  for entry in "${file_scope_arr[@]}"; do
    [ "$path" = "$entry" ] && return 0
    case "$path" in
      "$entry"/*) return 0 ;;
    esac
    case "$entry" in
      "$path"/*) return 0 ;;
    esac
  done
  return 1
}
```

Identical bug, identical mechanism (`"$entry"` quoted on the pattern side), minus this site's own
trailing-slash normalization (this twin never strips a trailing `/`, a pre-existing difference
from site 1 that is out of scope for this fix).

**Live corroboration beyond the dispatch's own three sources**: `jq -r '.active_projects[] |
select(.file_scope != null) | .file_scope[]' specs/state.json | grep '\*\*'` currently returns
six live entries ending in `/**` (`agent-system/extensions/books/agents/**`,
`.../books/context/project/books/**`, `.../books/skills/**`, `agent-system/extensions/core/**`,
`agent-system/extensions/founder/**`, and the brace-expansion entry noted above) — this is not a
one-off convention, it is the standing idiom for declaring "this whole subtree" in a task's
`file_scope`, and every one of them is silently inert against both predicates today.

**Three-sites framing already documented**: `git-staging-scope.md`'s "Three Containment sites,
not one" section records that once `git-commit-scoped.sh`'s V10 gate landed (task 394), it
structurally subsumes `git-commit-phase.sh`'s own self-check for every caller that already
forwards `--task` — which `git-commit-phase.sh` always does. That section states explicitly:
"Site 2's self-check is consequently deliberately redundant, not load-bearing, going forward... but
the durable guarantee... now rests on site 3, not site 2." This means the `git-commit-scoped.sh`
fix is the one that actually stops files from being dropped from commits; the `git-commit-phase.sh`
fix closes the same hole at a layer that is redundant-by-design but still independently active
(it runs its own warning + `issue-record.sh` call on a drop) — exactly matching why the dispatch
requires both sites fixed, not just the load-bearing one.

**No shared helper function exists.** `grep` for `is_contained`, `_contains_path`, or
`path_contained` across `agent-system/extensions/core/scripts/lib/*.sh` returns nothing — both
`is_contained_v10` and `is_contained` are self-contained, independently copy-pasted ("ported, not
reinvented," per each function's own header comment) rather than calling into a shared library.
This is a deliberate existing pattern, not an oversight to fix here.

**Test coverage gap confirmed.** `grep -n 'contain\|glob\|/\*\*'` over both test files turns up
zero existing cases exercising a `/**`-suffixed `file_scope` entry in either test suite. The
richest existing coverage is `test-git-commit-scoped.sh`'s `Z1`-`Z10` block (V10-specific, using
a `build_repo_with_scope` helper) and `test-git-commit-phase.sh`'s Case 7/8 pair (containment-port
fixture / fail-open-on-missing-file_scope). Both give a ready-made harness shape for the new
cases this task's plan should add.

### External Resources

Not applicable — this is a pure bash/shell predicate-logic defect local to this repository; no
external library or documentation bears on it.

### Proposed Fix (validated)

The fix adds exactly one new branch per function: strip a literal trailing `/**` via bash
parameter-expansion suffix removal with the asterisks backslash-escaped (`${var%/\*\*}` strips
only the two-character literal suffix `/**`, never an arbitrary glob), and when that suffix was
present, test ordinary prefix/exact containment against the stripped base using the SAME
quoted-pattern idiom already in use elsewhere in each function (so no new quoting risk is
introduced for arbitrary entry content).

**Site 1 — `git-commit-scoped.sh`, replacing the current `is_contained_v10` body:**

```bash
is_contained_v10() {
  local path="${1%/}" entry entry_norm entry_base
  for entry in "${containment_scope_arr[@]}"; do
    entry_norm="${entry%/}"
    [ "$path" = "$entry_norm" ] && return 0
    entry_base="${entry_norm%/\*\*}"
    if [ "$entry_base" != "$entry_norm" ]; then
      # entry_norm ends in a literal "/**" -- deep-glob prefix: contains the base directory's
      # direct children and every deeper descendant, nothing outside it.
      case "$path" in
        "$entry_base"|"$entry_base"/*) return 0 ;;
      esac
    fi
    case "$path" in
      "$entry_norm"/*) return 0 ;;
    esac
    case "$entry_norm" in
      "$path"/*) return 0 ;;
    esac
  done
  return 1
}
```

**Site 2 — `git-commit-phase.sh`, replacing the current `is_contained` body** (keeping this
site's existing no-trailing-slash-normalization as-is, since that is a separate, pre-existing,
out-of-scope difference from site 1):

```bash
is_contained() {
  local path="$1" entry entry_base
  for entry in "${file_scope_arr[@]}"; do
    [ "$path" = "$entry" ] && return 0
    entry_base="${entry%/\*\*}"
    if [ "$entry_base" != "$entry" ]; then
      case "$path" in
        "$entry_base"|"$entry_base"/*) return 0 ;;
      esac
    fi
    case "$path" in
      "$entry"/*) return 0 ;;
    esac
    case "$entry" in
      "$path"/*) return 0 ;;
    esac
  done
  return 1
}
```

**Validation harness (bash, run directly, not committed anywhere):**

```bash
containment_scope_arr=("agent-system/extensions/core/**" "specs/TODO.md" "specs/state.json" "agent-system/extensions/nix")
# ... (the is_contained_v10 body above) ...
```

Nine probes were run against this harness and all passed:

| Path probed | Expectation | Result |
|---|---|---|
| `agent-system/extensions/core/manifest.json` (direct child) | contained | PASS |
| `agent-system/extensions/core/scripts/lib/foo.sh` (deep descendant) | contained | PASS |
| `agent-system/extensions/core-other/x.sh` (same-prefix sibling, no slash boundary) | NOT contained | PASS |
| `agent-system/extensions/coreX/x.sh` (same-prefix sibling) | NOT contained | PASS |
| `agent-system/extensions/lean/x.lean` (unrelated sibling dir) | NOT contained | PASS |
| `specs/TODO.md` (exact non-glob entry) | contained | PASS |
| `specs/state.json` (exact non-glob entry) | contained | PASS |
| `agent-system/extensions/nix` (non-glob dir entry, bare) | contained | PASS |
| `agent-system/extensions/nix/sub/file.nix` (non-glob dir entry, nested) | contained | PASS |

The same-prefix-sibling cases (`core-other`, `coreX`) are the critical non-widening proof the
dispatch calls for: `entry_base` is compared with an exact match or a `/`-bounded prefix match,
so a path that merely shares a textual prefix with the base directory — but is not actually
inside it — is correctly rejected.

## Decisions

- **Both sites get the identical special-case branch**, inserted immediately after the existing
  exact-match test and before the two existing `case` branches, rather than refactoring either
  function to call a new shared library helper. This preserves each site's own "ported, not
  reinvented" header comment and its independent fail-open posture; extracting a shared helper
  is a larger, separately-scoped refactor this task's narrow fix does not need.
- **The escape mechanism is parameter-expansion suffix-stripping with escaped asterisks
  (`${var%/\*\*}`), not a `case` pattern.** A `case` pattern could also express "ends with
  literal `/**`" via selective quoting (`*"/**"`), but the parameter-expansion form reads more
  directly as "strip this literal suffix, see if anything was stripped" and keeps the new branch
  visually distinct from the two pre-existing `case` branches it sits beside.
- **Task 425 is independent — no `dependencies[]` edge needed.** Confirmed by reading
  `orchestrate-cycle-postflight.sh`'s own excursion check (`WORK (h)`, around line 1599): it is
  implemented entirely in `jq`, via `startswith($f)` against literal (non-glob) `file_scope`
  entries — a different language, different file, different bug class (no glob syntax is ever
  involved; `jq`'s `startswith` has no quoting-disables-globbing failure mode at all). Task 425's
  declared `file_scope` (`orchestrate-cycle-postflight.sh` and its own test file) does not
  overlap this task's two files, and neither predicate calls into the other or into any shared
  library function. The two tasks are same-*family* (containment-predicate correctness) but
  genuinely disjoint in site, language, and root cause, exactly as the dispatch's own
  "RELATIONSHIP TO EXISTING WORK" section anticipated as the likely outcome of checking.
- **The brace-expansion `file_scope` entry found in `specs/state.json` is out of scope.** Fixing
  it would mean evaluating a task-authored string as shell brace-expansion syntax, which these
  predicates deliberately never do (for good reason — unconstrained shell expansion of
  arbitrary stored strings is a correctness and safety hazard well beyond this task's fix). Noted
  as a candidate follow-up in Context Extension Recommendations, not pursued here.

## Recommendations

1. **Apply the two function-body replacements above** at `git-commit-scoped.sh:526-539`
   (`is_contained_v10`) and `git-commit-phase.sh:244-255` (`is_contained`), in the source store
   (`agent-system/extensions/core/scripts/...`), never under the deployed `.claude/**` tree.
2. **Add new test cases to both existing suites**, modeled on the harness patterns already in
   place:
   - In `test-git-commit-scoped.sh`'s `Z`-series (using `build_repo_with_scope`), add cases
     proving: a `/**` entry contains a direct child; contains a deeply nested descendant; does
     NOT contain a same-prefix sibling (e.g. `core` vs `core-other`); and a plain non-glob entry
     continues to behave exactly as the existing `Z1`-`Z10` cases already prove.
   - In `test-git-commit-phase.sh`'s numbered `Case` series (alongside Case 7/8), add an
     analogous `/**`-entry case using the same `write_progress` / `files_touched` fixture
     mechanics Case 7 already establishes.
3. **Redeploy after landing the source-store fix** via `deploy-headless.sh`, per the dispatch's
   own instruction, so the deployed `.claude/**` copies pick up the fix (and the three identical
   checks the `git-staging-scope.md` doc's "Three Containment sites" table enumerates all move
   together).
4. **No `dependencies[]` edge against task 425** — proceed independently; see Decisions.
5. Reference `git-staging-scope.md`'s existing "Three Containment sites, not one" section when
   writing the plan's rationale — it already documents exactly why fixing site 1
   (`git-commit-scoped.sh`) is the load-bearing change and site 2 (`git-commit-phase.sh`) closes a
   deliberately-redundant-but-real second layer; the plan does not need to re-derive this.

## Risks & Mitigations

- **Risk**: an overly clever single-regex rewrite of the whole predicate could accidentally
  widen containment for non-`/**` entries (e.g. treating a bare trailing `*` the same as `/**`,
  or matching a same-prefix sibling). **Mitigation**: the validated fix adds one narrowly-scoped
  new branch guarded by an exact-suffix-stripped check (`entry_base != entry_norm`), and leaves
  every existing branch completely untouched — the nine-case validation above specifically
  includes same-prefix-sibling negatives to catch this class of regression before it lands.
- **Risk**: fixing only one site (forgetting the "ported twin") would leave `git-commit-phase.sh`
  silently redundant-but-broken, continuing to emit spurious `scope excursion` issue-log entries
  and drop-warnings for files that are in fact in scope, even though `git-commit-scoped.sh`'s own
  (now-fixed) V10 gate would still correctly land them. **Mitigation**: both sites are fixed in
  this task per the dispatch's explicit scope; the plan should treat the two edits as a single
  atomic phase (or verify both before any commit) rather than landing one without the other.
- **Risk**: the brace-expansion `file_scope` entry in live `state.json` could tempt an
  implementer into expanding scope to "fix globs generally." **Mitigation**: explicitly called
  out as out of scope above and in Context Extension Recommendations below; the dispatch's own
  non-widening constraint argues for the narrowest fix that satisfies the four required test
  behaviors, not a general glob engine.

## Context Extension Recommendations

- **Topic**: brace-expansion `file_scope` entries (e.g.
  `agent-system/extensions/{a,b,c}/**`) are declared live in `specs/state.json` today but are not,
  and will not be after this fix, expanded by either containment predicate.
- **Gap**: no existing context file documents that `file_scope` entries are matched as literal
  strings (plus the now-sanctioned `/**` suffix) and that shell brace/glob expansion is never
  evaluated against them.
- **Recommendation**: a short addition to `git-staging-scope.md` (or a new standards note)
  stating the exact supported `file_scope` entry grammar (exact path; directory ancestor without
  trailing glob; directory-with-`/**` deep-glob) would prevent a future task author from relying
  on brace expansion or other glob forms that silently never match.

## Appendix

- Search queries / commands used: `jq` queries against `.claude-extensions.json` and
  `specs/state.json`; `grep -n` across both target scripts and both test files for
  `is_contained`, `contain`, `glob`, `/\*\*`; `git log --oneline -- git-commit-scoped.sh` and a
  `git log --all --grep` sweep for any prior fix attempt (none found); a standalone bash
  validation script exercising the proposed fix against nine cases (all passed).
- References: `agent-system/extensions/core/context/standards/git-staging-scope.md` ("Three
  Containment sites, not one" section); `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`
  (`build_repo_with_scope`, `Z1`-`Z10`); `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`
  (Case 7/8).
