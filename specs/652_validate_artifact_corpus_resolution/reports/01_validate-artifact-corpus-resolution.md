# Research Report: Task #652

**Task**: 652 - Validate artifact corpus resolution
**Started**: 2026-11-19T17:45:00Z
**Completed**: 2026-11-19T18:10:00Z
**Effort**: Medium (one script, one library read, one new test section; no new declaration surface)
**Dependencies**: Task 650 (touched-path verify entry / unmapped fallback) - COMPLETED; Task 564 (sentinel-dominated set semantics) - COMPLETED
**Sources/Inputs**: - Codebase read of `agent-system/extensions/core/scripts/validate-artifact.sh`, `scripts/lib/suite-selection-lib.sh`, `scripts/lib/suite-resolver-lib.sh`, `scripts/lib/verification-scope-lib.sh`, `context/standards/repo-level-declarations.md`, `scripts/tests/test-validate-artifact.sh`, `scripts/tests/test-verification-scope-lib.sh`, `scripts/tests/suite-classification.data`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The exact resolution site is a candidate-list block already present in `validate-artifact.sh`
  (lines ~353-376 of the source-store copy, byte-identical in the deployed copy): a one-element
  `_suite_selection_lib_candidates` array holding only `"$_validate_script_dir/lib/suite-selection-lib.sh"`.
  This is literally the single script-relative path the dispatch names, and the script already
  uses the "ordered candidate list, first found wins, loud exit 5 if none found" idiom elsewhere
  in the same function for `phase-heading-patterns.sh` and `plan-status-line.sh` — the deliverable
  asks to extend this *same* idiom with one more, declaration-driven entry, not invent a new one.
- `scripts/lib/suite-selection-lib.sh` resolves its own scripts-root/tests-dir purely from its own
  `${BASH_SOURCE[0]}` location (`_SSL_SCRIPTS_ROOT`/`_SSL_TESTS_DIR`, set once at source time, two
  directories up from itself). There is no parameter or environment override for this — the only
  way to re-root the *exact same, unmodified* selection engine at a different corpus is to source
  a *different on-disk copy* of the same file that happens to live inside that corpus's own tree.
  This is the mechanism the fix should use; it requires zero changes to `suite-selection-lib.sh`
  itself, satisfying the "no second corpus-discovery engine" hard constraint literally.
- `scripts/lib/verification-scope-lib.sh already exposes `verification_scope_project_suite_roots
  <repo_root>` exactly as the dispatch states — confirmed present and deployed
  (`.claude/scripts/lib/verification-scope-lib.sh`, byte-identical region to the source store).
  Task 650 and Task 564 (both `[COMPLETED]`) are this record's two filed dependencies and both
  are satisfied: Task 564 landed `suite_selection_select`'s compositional (non-collapsing) sentinel
  semantics, which the Tier-Justification block's comments already reference live
  ("`suite_selection_select` is now compositional (see `lib/suite-selection-lib.sh`'s PUBLIC API
  header)") — confirming Task 564 changed the *library*, not `validate-artifact.sh`'s consumption
  of it, so the resolution site this record targets was not rewritten out from under it.
- `validate-artifact.sh` already has a reusable repo-root-resolution helper pair,
  `_cgs_find_repo_root`/`_cgs_resolve_repo_root` (walks up from the artifact's own directory,
  falls back to `$(pwd)`, looks for `.claude-extensions.json`), used today only for
  `coupled_generated_surfaces`. The dispatch's own "do not add a second declaration surface"
  constraint extends naturally to "do not add a second repo-root-resolution mechanism either" —
  this record's corpus lookup should reuse the same `_cgs_repo_root` value already computed once
  per run, not add a second `.claude-extensions.json` walk.
- Recommended approach (see Recommendations): derive, for each declared
  `verification_scope_project_suite_roots` entry `R`, the candidate library path
  `<repo_root>/$(dirname "R")/lib/suite-selection-lib.sh` and prepend it to the existing
  `_suite_selection_lib_candidates` array, ahead of today's single deployed-tree entry. First
  candidate that exists on disk is sourced (today's "first found wins" rule, unchanged); the
  already-sourced file self-resolves its own `_SSL_SCRIPTS_ROOT`/`_SSL_TESTS_DIR` relative to
  *its own* location, so no further plumbing is needed once the right file is chosen. Record,
  alongside the chosen path, a short corpus-descriptor string for deliverable 2's warning-text
  requirement, and a separate one-time advisory warning when a declared root yields no resolvable
  library file (deliverable 4's "declared-but-absent" case).

## Context & Scope

This is a `research` dispatch (phase=research) for an already-planned, already-dependency-cleared
meta task: resolve `validate-artifact.sh`'s advisory Tier-Justification measurement corpus against
the repository under validation's own declared suite tree, rather than unconditionally against the
deployed `.claude/scripts/lib/suite-selection-lib.sh` corpus. The task description already supplies
the "RE-DERIVE BEFORE EDITING" pointers, the four deliverables, the hard constraints, and the
DONE WHEN criteria verbatim; this report's job is to verify each pointer against the live source
tree (figures and line numbers do move, as the dispatch warns), confirm the two filed
dependencies are genuinely satisfied, and work out a concrete, minimal-footprint resolution design
that an implementation phase can execute without re-deriving the mechanics from scratch.

Scope is bounded to the source-store copy of `validate-artifact.sh` (edit target per
`rules/source-store-deploy-boundary.md`) and its own `scripts/tests/test-validate-artifact.sh`
suite. No other script is in scope; the Territory Edges section of the dispatch already rules out
edges to the several other claimants of these same two files (batch-worthy, not sequencing
hazards).

## Findings

### Codebase Patterns

**Resolution site (deliverable 1's target).** `validate-artifact.sh`'s `plan`-type branch sources
three sibling libraries via the *identical* lazy, `${BASH_SOURCE[0]}`-relative, ordered-candidate-
list, loud-exit-5-on-miss idiom: `phase-heading-patterns.sh`, `plan-status-line.sh`, and
`suite-selection-lib.sh`. Only the third of these currently has a single-element candidate array:

```
_suite_selection_lib_candidates=(
  "$_validate_script_dir/lib/suite-selection-lib.sh"
)
```

immediately followed by the standard "for candidate in array; if -f; break; else exit 5" loop. This
is confirmed to be the ONLY site in the script that sources `suite-selection-lib.sh` — no other
scan in the file shares it (the Tier-Justification block at the end of the `plan` branch is the
sole consumer of the `suite_selection_select` function this sourcing makes available).

**Why the corpus can't be re-rooted by parameter.** `suite-selection-lib.sh` fixes
`_SSL_SCRIPTS_ROOT`/`_SSL_TESTS_DIR` once, at source time, from its own `${BASH_SOURCE[0]}`
location (two directories up: `lib/THIS_FILE` -> `scripts/`, then `scripts/tests`). These two
variables are internal (`_SSL_`-prefixed, explicitly *not* part of the library's stated public
contract, which is only the `suite_selection_*` functions and the
`SUITE_SELECTION_FULL_SWEEP_SENTINEL` constant). There is no function argument, environment
variable, or other published knob that re-roots an *already-sourced* copy of this library at a
different tree. The library's own per-extension re-rooting logic
(`_ssl_extensions_parent`/`_ssl_roots_for_path`) is a *narrower*, already-shipped mechanism that
only fires for a touched path literally containing an `agent-system/extensions/<ext>/scripts/`
segment, detected via a source-store marker (`<extensions-parent>/core/manifest.json`) — it does
not apply to a consumer repository's own project-owned suite tree (e.g. `sf1-engine`'s copied
battery), which carries no such marker and is not shaped as an "extension".

**The only non-invasive re-rooting mechanism is "source a different copy of the same file".**
Because the library computes its roots from its own `${BASH_SOURCE[0]}`, sourcing a *second,
separate on-disk copy* of `suite-selection-lib.sh` that happens to live inside the declared corpus
tree re-roots the exact same, unmodified selection logic at that corpus — zero new
discovery/resolution code, zero change to the library itself. This only works when the declared
corpus tree is laid out the same way the agent-system's own `scripts/` tree is (a `lib/` directory
containing `suite-selection-lib.sh`, sibling to a `tests/` directory holding `test-*.sh` files) —
which is exactly what the dispatch's own ORIGIN example describes: sf1-engine's battery is "a copy
of an upstream reference snapshot", i.e. a full mirror of `agent-system/extensions/core/scripts/`,
not an independently-shaped test corpus. The reserved-field schema note in
`repo-level-declarations.md` ("`project_suite_roots` ... a non-shell test corpus, for example")
confirms the field is deliberately *not* required to be shell/suite-selection-lib-shaped in
general — so a declared root that does NOT carry a sibling `lib/suite-selection-lib.sh` must
degrade gracefully (deliverable 4's third case), never be treated as an error.

**Existing declaration reader, confirmed present and deployed.**
`scripts/lib/verification-scope-lib.sh`'s `verification_scope_project_suite_roots <repo_root>`
(source lines 131-145) reads `<repo_root>/.claude-extensions.json`'s
`verification_scope.project_suite_roots` array, printing one repo-root-relative entry per line,
and defaults to empty output on every absence/malformed case (no file, no `jq`, absent key, wrong
type, non-string member) — never aborting, per the library's own stated fail-open discipline (it
sets no shell options and never calls `exit`). Confirmed byte-identical between the source store
and `.claude/scripts/lib/verification-scope-lib.sh` (already redeployed). `validate-artifact.sh`
does not currently source this library at all (`grep` for `verification-scope-lib` or
`verification_scope_` in the script returns nothing) — it will need to be added as a new sourced
sibling, but as a *fail-soft* source (matching the existing `source-store-path-lib.sh` precedent
at line 327, `. "$_validate_script_dir/lib/source-store-path-lib.sh" 2>/dev/null || true`, guarded
afterward by `command -v verification_scope_project_suite_roots` before use) rather than the loud
exit-5 idiom used for the three *required* libraries — because `verification_scope` is itself an
optional, fail-open declaration surface by design, and this check must stay advisory regardless of
whether the library is even present.

**Repo-root resolution is already solved once per run, for a different declaration.** The
`coupled_generated_surfaces` check (deliverable-adjacent, same script) already resolves "the
repository under validation" via `_cgs_find_repo_root`/`_cgs_resolve_repo_root`: walk up from
`dirname "$artifact_path"` looking for `.claude-extensions.json`, falling back to `$(pwd)` if
nothing is found walking from the artifact's own directory. This resolution happens exactly once
per run (line ~511, `_cgs_repo_root="$(_cgs_resolve_repo_root "$(dirname "$artifact_path")")"`),
*after* the candidate-list sourcing block for `suite-selection-lib.sh` (lines ~353-376) in current
file order. Reusing `_cgs_repo_root` for the new corpus-candidate lookup (rather than resolving the
repo root a second, independent time) is the natural "no second declaration surface" reading of
the hard constraint, but requires moving the repo-root *computation* (not the helper function
definitions, which can stay where they are) ahead of the `suite-selection-lib.sh` candidate-list
block in file order — a small, mechanical reordering, not a redesign.

**Composition precedent exists but solves a different axis.** `scripts/lib/suite-resolver-lib.sh`
is the dispatch's named precedent for "composing a declared backend with the default one,
including its conformance check and its union/replace composition rule" — confirmed read in full.
It composes by *resolver COMMAND* (`verification_scope.resolver.command`, invoked as a subprocess
with paths on stdin, SELECT/UNRESOLVED output contract, union/replace per
`verification_scope.resolver.compose`). This is architecturally the right pattern to study for "how
this codebase already composes a declared backend with a default one", but it is not the
mechanism this task should reuse verbatim: `resolver.command` composes an arbitrary *resolution
command*, while this task composes a *choice of which suite-selection-lib.sh copy (hence which
scripts-root corpus) to source* — a candidate-LIST ordering (first found wins), not a
command-invocation UNION. The dispatch's own hard constraint ("verification_scope is the
declaration point and suite-selection-lib.sh remains the default backend") reads as: reuse the
*declaration point* (`verification_scope`, via its existing reader), not the *resolver-command
composition machinery*, which answers an orthogonal question (touched-path -> suite mapping
BACKEND choice) from the one this task answers (which CORPUS the *existing, unchanged*
basename-mapping backend walks).

**Test harness precedent for the new coverage.** `scripts/tests/test-validate-artifact.sh` already
has a complete Tier-Justification fixture family (`make_tj_fixture`, `TJ_REAL_SUITE_PATH`,
`TJ_REAL_SUITE_NAMES` computed live via `suite_selection_select` sourced from
`$SCRIPT_DIR/../lib/suite-selection-lib.sh`, i.e. the *source-store* sibling, deliberately not
deploy-tree-first, "because the Tier Justification fixtures below need to compute their EXPECTED
answer from the exact same scripts-root `suite_selection_select` will resolve against inside
`$VALIDATE_SRC`"). Five existing cases cover: positive (claim matches), negative/fabrication,
sentinel-true-positive, sentinel-false-positive/unmapped, and mixed-set honest-suitelist. The
suite already resolves the subject script in two separate modes, `$VALIDATE` (deploy-tree-first)
and `$VALIDATE_SRC` (source-store), selecting whichever mode matches a given check's redeploy
status — this script is confirmed classified `integration` in `suite-classification.data`
(`test-validate-artifact.sh	integration	invokes:deploy-headless.sh,verify-deploy.sh,run-all.sh`),
matching deliverable 4's own description and requiring no new classification-data edit.
`test-verification-scope-lib.sh`'s own `plant_scope` fixture builder (writes a scratch
`.claude-extensions.json` under a `mktemp -d` root) is the direct precedent for how the new
declared/undeclared/declared-but-absent cases should plant their own scratch repo roots: a fixture
root needs (a) a `.claude-extensions.json` declaring `verification_scope.project_suite_roots`, (b)
a nested mirror (`<declared_root's dirname>/lib/suite-selection-lib.sh` plus the declared root
itself holding `test-*.sh` files) for the "declared" case, and (c) the fixture plan file placed
*inside* that scratch tree (so `_cgs_resolve_repo_root "$(dirname "$artifact_path")"` actually
finds it) rather than validated from outside it.

### External Resources

Not applicable — this is a self-contained shell/JSON mechanism with no external library or API
surface; all research was codebase-internal, per the Research Strategy Decision Tree's priority
order (local codebase first, and in this case exclusively, since the task is entirely about this
repository's own existing declaration/resolution machinery).

## Recommendations

1. **Deliverable 1 (ordered candidate list).** Prepend, not replace: before computing
   `_suite_selection_lib_candidates`, (a) hoist the `_cgs_repo_root` computation (reusing the
   existing `_cgs_find_repo_root`/`_cgs_resolve_repo_root` helper functions, unchanged) to run
   *before* the `suite-selection-lib.sh` candidate-list block, (b) fail-soft source
   `verification-scope-lib.sh` from `"$_validate_script_dir/lib/verification-scope-lib.sh"`
   (fixed sibling path, not root-dependent — same tree `suite-selection-lib.sh` and
   `suite-resolver-lib.sh` already live in), guarded with `command -v
   verification_scope_project_suite_roots` before use, (c) for each line printed by
   `verification_scope_project_suite_roots "$_cgs_repo_root"` (in declared order), compute
   `"$_cgs_repo_root/$(dirname "$line")/lib/suite-selection-lib.sh"` and append it to
   `_suite_selection_lib_candidates` ahead of today's single deployed-tree entry, (d) leave the
   existing "first `-f` match wins, else exit 5" loop completely unchanged. A repository declaring
   nothing (`verification_scope_project_suite_roots` prints nothing) leaves the candidate array
   exactly as it is today — byte-for-byte unaffected, satisfying the fail-open requirement
   literally via the existing loop rather than a new branch.

2. **Deliverable 2 (name the corpus).** Capture, at the moment the winning candidate is chosen
   (inside or immediately after the existing for-loop), a short descriptor string — e.g. the
   winning candidate's path, with a one-word tag distinguishing "declared project suite root" from
   "deployed tree (fallback)". Append this descriptor, parenthesized, to the four existing
   `log_warn` call sites inside the Tier-Justification block (the two sentinel-claim branches and
   the two suitelist-claim branches) — a pure string-append, since every existing test assertion
   only checks for the substring `"Tier Justification"`, never the full message, so this is
   additive and non-breaking to every existing fixture. Example shape: `... -- fabricated claim
   (corpus: declared project suite root 'extensions/core/scripts/tests', resolved via
   extensions/core/scripts/lib/suite-selection-lib.sh)` vs. `... (corpus: deployed tree,
   .claude/scripts/lib/suite-selection-lib.sh)`.

3. **Deliverable 2, continued — the declared-but-absent case needs its own ONE-TIME warning**,
   distinct from the per-phase attribution above: when `verification_scope_project_suite_roots`
   returns at least one entry but *none* of the derived candidate paths exist on disk (so the
   script falls through to today's single deployed-tree entry), emit one `log_warn` once, outside
   the per-phase loop, naming the declared root(s) that failed to resolve and the fallback corpus
   now in use for every phase's Tier-Justification measurement this run. This satisfies deliverable
   4's third test case ("degrades to the fallback with a named warning rather than a hard
   failure") and keeps the loud failure mode reserved for the genuinely-unrecoverable case (no
   candidate at all resolves, library truly missing), matching the existing exit-5 contract on the
   final, always-present deployed-tree candidate.

4. **Deliverable 3 (stay advisory).** No change needed to the exit-code contract: both new code
   paths (library sourcing via `command -v`/fail-soft, and the warning emission) use the script's
   existing `log_warn` (never `log_error`), so the Tier-Justification check's existing
   non-blocking posture is mechanically preserved without any extra guard.

5. **Deliverable 4 (test coverage), three cases, each as a `make_tj_fixture`-style addition to
   `test-validate-artifact.sh`**:
   - *Declared, resolvable*: build a scratch root (`mktemp -d`) containing
     `.claude-extensions.json` with `verification_scope.project_suite_roots` pointing at a planted
     `extensions/core/scripts/tests` directory, with a sibling planted
     `extensions/core/scripts/lib/suite-selection-lib.sh` (a real copy or symlink of the library)
     and a planted `test-*.sh` suite file inside `tests/`. Place the fixture plan file *inside*
     that scratch root (e.g. `<root>/specs/x/plans/plan.md`) so `_cgs_resolve_repo_root` finds it.
     Compute the fixture's expected suite name by sourcing the *planted* copy of
     `suite-selection-lib.sh` (never the repository's own `$SCRIPT_DIR/../lib/suite-selection-lib.sh`
     sibling used by the existing cases) against a path mapped only inside the scratch corpus, then
     assert the resulting Tier-Justification warning/pass matches that scratch corpus's own
     resolution and that the corpus descriptor names the declared root, not the deployed tree.
   - *Undeclared*: no `.claude-extensions.json` at all (or one without `verification_scope`) —
     reuse the existing `make_tj_fixture` cases verbatim; assert byte-identical output to today
     (this is effectively a regression guard that the new candidate-list logic changes nothing when
     nothing is declared, rather than a new behavior to assert).
   - *Declared but absent*: `.claude-extensions.json` declares a `project_suite_roots` entry whose
     derived candidate library path does not exist on disk. Assert (a) the Tier-Justification
     warning/pass outcome matches the undeclared case exactly (fallback corpus, unchanged
     resolution), and (b) exactly one additional named warning appears identifying the declared,
     unresolvable root and the fallback corpus now in use.
   No change to `suite-classification.data` is needed — the whole suite file is already classified
   `integration` (confirmed), and these are additions to that same file, not a new suite.

## Decisions

- Re-root the Tier-Justification corpus by sourcing a *different on-disk copy* of the unmodified
  `suite-selection-lib.sh`, selected via an extended ordered candidate list — not by adding a
  root-override parameter/environment variable to the library itself, and not by reaching into the
  library's internal `_SSL_SCRIPTS_ROOT`/`_SSL_TESTS_DIR` variables from `validate-artifact.sh`.
  This keeps the selection *engine* genuinely singular (hard constraint) and treats the library as
  a black box from its caller's side, at the cost of only working when a declared project suite
  root is laid out as a `lib/`+`tests/` mirror of the agent-system's own scripts tree — judged
  acceptable because the dispatch's own ORIGIN example (sf1-engine) is exactly that shape, and a
  non-mirrored declared root degrades to the existing fallback with a named warning rather than
  misbehaving.
- Reuse `_cgs_repo_root` (via the existing `_cgs_find_repo_root`/`_cgs_resolve_repo_root` helpers)
  for the new corpus lookup rather than adding a second `.claude-extensions.json`-walking
  resolution — requires hoisting the repo-root *computation* ahead of the `suite-selection-lib.sh`
  candidate-list block in file order; the helper function *definitions* can stay where they are.
- Source `verification-scope-lib.sh` fail-soft (`2>/dev/null || true`, `command -v`-guarded),
  matching the existing `source-store-path-lib.sh` precedent, rather than the loud exit-5 idiom
  used for the three libraries this check genuinely cannot run without — because
  `verification_scope` itself is an optional, fail-open declaration surface and this entire check
  stays advisory regardless of whether the reader is available.
- Distinguish two warning shapes: a per-phase, per-existing-log_warn-site corpus-attribution suffix
  (deliverable 2's "every advisory warning names the corpus"), and a separate one-time, run-level
  warning for the declared-but-unresolvable case (deliverable 4's third test case) — these answer
  different questions (which corpus was THIS finding measured against? vs. did a declaration fail
  to resolve at all?) and should not be collapsed into one message.
- `suite-resolver-lib.sh`'s union/replace resolver-command composition is read as the architectural
  precedent for "a declaration composes with a default backend" in this codebase, but is NOT the
  mechanism to reuse directly: it composes resolution COMMANDS, this task composes a choice of
  WHICH CORPUS the one, unchanged, basename-mapping backend consults.

## Risks & Mitigations

- **Risk**: a declared `project_suite_roots` entry that is not laid out as a `lib/`+`tests/`
  mirror (the schema's own "non-shell test corpus, for example" generality) silently yields no
  candidate and falls through to the deployed tree, which is correct per the fail-open mandate but
  could be mistaken for a bug if undocumented. **Mitigation**: the declared-but-absent warning
  (Recommendation 3) covers exactly this case — a reader sees the fallback was used and why, never
  a silent, unexplained measurement against the wrong corpus.
- **Risk**: reordering the `_cgs_repo_root` computation ahead of the `suite-selection-lib.sh`
  candidate-list block could be mis-implemented as duplicating the resolution instead of hoisting
  it, leaving two independent repo-root walks that could disagree if `.claude-extensions.json` is
  edited mid-run (not realistic within one script invocation, but worth stating). **Mitigation**:
  the implementation phase should compute `_cgs_repo_root` exactly once, before both consumers
  (suite-selection-lib.sh candidate derivation and the existing `coupled_generated_surfaces`
  lookup), and have both read the same variable — a one-line move, not a second call site.
  (Verification Tier/Scope Hypothesis note for the implementing plan phase: this is a same-file,
  no-external-dependency reorder with an existing, already-passing test suite to catch any
  regression — Tier `unit`/`fast`, not `full`.)
  <!-- carried-figure-ok: Tier framing is this report's own first-pass judgment for the plan
  author's convenience, not a verified corpus measurement; the implementing plan must still run
  its own Tier Justification measurement rather than treat this parenthetical as authoritative. -->
- **Risk**: the existing TJ fixtures compute their expected suite names by sourcing
  `$SCRIPT_DIR/../lib/suite-selection-lib.sh` (the repository's OWN source-store sibling) — if a
  new declared-root test case reused that same `SUITE_SELECTION_LIB` variable for its "expected"
  computation instead of sourcing the *planted scratch copy*, the fixture would assert against the
  wrong corpus's answer (exactly the class of bug this whole task fixes, recreated inside its own
  test). **Mitigation**: explicitly called out in Recommendation 5's first bullet — the new
  declared-root case must source the planted copy for its expected-value computation, not the
  existing `SUITE_SELECTION_LIB` variable.
- **Risk**: appending a corpus descriptor to the four existing `log_warn` lines could be read as
  changing the *contract* of those warnings. **Mitigation**: confirmed via direct read of every
  existing assertion in `test-validate-artifact.sh`'s TJ section that all five current cases match
  only on the `"Tier Justification"` substring (via `grep -qF`/`grep -cF`), never the full message
  — a pure suffix append is non-breaking to every existing assertion.

## Context Extension Recommendations

- **Topic**: `verification_scope.project_suite_roots` consumption by `validate-artifact.sh`'s
  Tier-Justification check.
- **Gap**: `context/standards/repo-level-declarations.md`'s "Decisions Settled" section currently
  documents only `closing_gate`'s resolution; it does not yet record that
  `project_suite_roots` has a second consumer beyond `verify-touched.sh`/`suite-resolver-lib.sh`/
  `report-suite-coverage.sh` (as listed in that file's own "One object, one key" paragraph) —
  namely `validate-artifact.sh`'s advisory corpus resolution, once this task's implementation
  phase lands it.
- **Recommendation**: the implementing plan's own phase that edits
  `repo-level-declarations.md` (if any) — or, if no such edit is otherwise planned, a follow-up
  doc-sync phase — should add `validate-artifact.sh` to that consumer list and record the
  `lib/`+`tests/`-mirror-shape convention this corpus resolution relies on, since the field's own
  schema text ("a non-shell test corpus, for example") does not currently say anything about that
  convention and a future declarer could otherwise reasonably assume any directory shape works
  for every consumer.

## Appendix

- Search queries / commands used: `grep -n "suite-selection-lib\|suite_selection\|_validate_script_dir\|SCRIPT_DIR" .../validate-artifact.sh`; direct `Read` of
  `validate-artifact.sh` lines 280-410 and 500-560 and 740-900; direct `Read` of
  `suite-selection-lib.sh` lines 1-80, 190-345; direct `Read` of `suite-resolver-lib.sh` in full;
  `grep -n "project_suite_roots" -B5 -A40 repo-level-declarations.md`; `grep -n ... state.json/
  TODO.md` to confirm Task 650 and Task 564 are `[COMPLETED]`; `diff` of the source-store vs.
  deployed `validate-artifact.sh` region 350-380 (confirmed byte-identical, so the deployed tree is
  not stale relative to the edit target for this region); `ls` of `.claude/scripts/lib/
  {verification-scope,suite-selection,suite-resolver}-lib.sh` (confirmed all three deployed).
- References: `agent-system/extensions/core/scripts/validate-artifact.sh`,
  `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`,
  `agent-system/extensions/core/scripts/lib/suite-resolver-lib.sh`,
  `agent-system/extensions/core/scripts/lib/verification-scope-lib.sh`,
  `agent-system/extensions/core/context/standards/repo-level-declarations.md`,
  `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`,
  `agent-system/extensions/core/scripts/tests/test-verification-scope-lib.sh`,
  `agent-system/extensions/core/scripts/tests/suite-classification.data`.
