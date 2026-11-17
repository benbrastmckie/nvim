# Research Report: Task #604

**Task**: 604 - Fixture dependency declaration drift lint
**Started**: 2026-11-17T00:00:00Z
**Completed**: 2026-11-17T00:00:00Z
**Effort**: medium (one new lint script, one gate-registry row, one gate30_run function, no SUT/suite semantics changed)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/tests/*.sh, scripts/lint/*.sh, scripts/gate-registry.data, scripts/verify-deploy.sh, context/standards/shell-script-testing.md, docs/reference/utility-scripts-inventory.md), git history (3 historical repair commits)
**Artifacts**: specs/604_fixture_dependency_declaration_drift_lint/reports/01_fixture-dependency-drift-lint.md
**Standards**: report-format.md, subagent-return.md, shell-script-testing.md

## Executive Summary

- The drift class is real, mechanically detectable, and already has three confirmed historical
  instances (commits `d3e45535e`, `1c10b01f7`, `4c96ccb4f`), all the same shape: a fixture suite
  copies `state-write.sh` into its sandbox, `state-write.sh` unconditionally `source`s
  `lib/project-number-inuse.sh`, and the suite's own declared copy-list omitted that one library
  until hand-repaired.
- A **single extraction procedure** — not two separate parsers for the two declared shapes —
  resolves both: pull every literal filename argument out of every `require_file`/`cp` call AND
  every array-element consumed by a `for ... in "${ARR[@]}"` loop feeding either call, regardless
  of what the array is named or whether an array exists at all. This naturally unifies Shape 1
  (named array) and Shape 2 (open-coded, `test-orchestrate-predispatch-review.sh`).
- The true population subject to this drift is **larger than the dispatch's illustrative count**:
  8 suites declare a named array consumed by both a require/existence loop and a `cp`-into-sandbox
  loop (not 3), and at least 7 more declare the open-coded parallel-pair shape with their own
  `cp`-into-sandbox lines. `test-stall-reprompt-wiring.sh` is correctly OUT of population — its
  `require_file` calls name doc/skill files, not `scripts/lib/*.sh` dependencies, and it has no
  sandbox-copy loop at all.
- Recommended siting: **join `gate-registry.data`** (route (a)), not a standalone utility script
  (route (b)) — see Decisions below for the full ruling and precedent trail.
- A static scan must distinguish MANDATORY `source`/`.` references (would abort/fail the copied
  script if absent) from three **documented OPTIONAL** shapes already live in this corpus,
  or the lint will false-positive on `file-scope-overlap.sh`/`deploy-freshness-lib.sh`'s
  deliberate degrade-safe guards. This is the single hardest part of the detector and is detailed
  under Recommendations.

## Context & Scope

Researched: the exact declaration shapes used by the four suites named in the dispatch
(`test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`,
`test-orchestrate-unwind-dispatch.sh`, `test-orchestrate-predispatch-review.sh`); the full
`scripts/tests/*.sh` corpus for the true population of suites exhibiting either shape; the
`source`/`.` dependency shapes actually used by every script those suites copy
(`state-write.sh`, `task-lock.sh`, `update-task-status.sh`, `orchestrate-predispatch-review.sh`,
and their `lib/*.sh` dependencies), including the three OPTIONAL/degrade-safe guard idioms that a
naive detector would misclassify as missing-dependency violations; the existing `scripts/lint/`
family's two closest analogues (`lint-subject-resolution-declaration.sh`,
`lint-test-root-resolution.sh`) as structural and registration templates; `gate-registry.data`'s
schema and the two most recently added gates' `timeout_s`/`cost_class`/`input_corpus` values as
budget precedent; and `docs/reference/utility-scripts-inventory.md`'s inclusion convention for
gate-registered lints (older vs. newer gates diverge — see Decisions).

Out of scope (per dispatch Non-Goals): changing any suite's pass/fail semantics or any existing
gate's verdict; converting the curated lists to a runtime-derived mechanism; the
`known-failures.txt` roster-staleness check (a separate, dependent task).

## Findings

### Codebase Patterns

**Confirmed historical instances of the exact drift class** (git log, not reconstructed):

| Suite | Commit | Pre-repair `REQUIRED_LIBS`/declared set |
|---|---|---|
| `test-postflight-deploy-gate.sh` | `d3e45535e` | `common.sh phase-heading-patterns.sh status-vocabulary.sh file-scope-overlap.sh task-lookup-lib.sh` — missing `project-number-inuse.sh` |
| `test-redeploy-checkpoint-promotion.sh` | `1c10b01f7` | same omission |
| `test-orchestrate-predispatch-review.sh` | `4c96ccb4f` | same omission (Shape 2, open-coded) |

In every case the proximate cause is identical: `state-write.sh` (already in the suite's declared
copy set) unconditionally does `source "${SCRIPT_DIR}/lib/project-number-inuse.sh"`
(`scripts/state-write.sh:214`) — a dependency of a *copied* script, not of the suite's own
subject-under-test, which is exactly why a hand-maintained list drifts: the list's author tracks
the SUT's own needs, not every transitive `source` inside every helper the SUT happens to need.

**True population is wider than the dispatch's illustrative enumeration.** The dispatch's
"Measured population context" section (8 `require_file` users, 88/90 `scripts/lib/` referencers)
reproduces almost exactly against the live tree (90 vs. 88 — within noise of the two intervening
commits the dispatch itself names). But "3 suites declare [a named array] today" undercounts the
Shape-1 population; a structural grep for the array-name family actually used
(`REQUIRED_LIBS`/`REQUIRED_SCRIPTS`/`REQUIRED_LIB_SCRIPTS`/`REQUIRED_CORE_SCRIPTS`) finds **8**:
the 3 named in the dispatch plus `test-git-commit-phase.sh`, `test-orchestrate-batch-admit.sh`,
`test-update-task-status.sh`, `test-git-commit-scoped.sh`, `test-commit-source-store-path.sh`.
All 8 also contain a `cp ... .claude/scripts` sandbox-copy line, confirming all 8 are genuine
fixture-copy suites in the same risk class, not merely array-declaring. (These 5 extras use ONE
combined `REQUIRED_SCRIPTS` array holding both top-level-script and `lib/`-prefixed entries,
rather than two separate arrays — a third sub-variant of Shape 1 the detector's extraction must
not special-case away.)

Similarly, the Shape-2 (open-coded) population is wider than the dispatch's single named example:
of the 8 `require_file`-calling suites, 7 also contain `cp ...lib/...` sandbox-copy lines
(`test-handoff-dispatch-identity.sh`, `test-orchestrate-cycle-plan.sh`,
`test-orchestrate-context-growth.sh`, `test-orchestrate-churn.sh`,
`test-orchestrate-predispatch-review.sh`, `test-orchestrate-cycle-postflight.sh`,
`test-orchestrate-recover-message-findings.sh`). The eighth, `test-stall-reprompt-wiring.sh`, is
correctly OUT of population: its three `require_file` targets are `SKILL.md`, a state-machine
doc, and a postflight script — not `scripts/lib/*.sh` dependencies — and it has zero
`cp ...lib/...` lines. This is the exact discriminator the dispatch's "do not assume the
array-declaring three are the population" warning is pointing at, and it generalizes past arrays
to the open-coded shape too: the predicate must test for the *behavior* (declares, then copies,
scripts/lib dependencies into a sandbox), never for a specific array name or the presence of
`require_file` alone.

**Unified extraction handles both shapes with one procedure.** Rather than writing a
Shape-1-specific array-walker and a Shape-2-specific line-scanner, one regex pass over each
candidate suite file can collect the declared/copied set uniformly:
- every literal path argument to a `require_file "..."` call,
- every literal path argument to a `cp "..." "..."` line whose destination matches a sandbox
  root (`$WORKDIR/.claude/scripts`, `$root/.claude/scripts`, or equivalent),
- every element of any array literal (`NAME=( ... )`, any name) that is later consumed by a
  `for f in "${NAME[@]}"` loop whose body contains a `require_file` or `cp` call.

This treats "named array, consumed twice" and "open-coded parallel pair" as the same underlying
fact — a set of filenames this suite asserts it needs — without caring which syntactic form
produced that set. `test-postflight-deploy-gate.sh`'s SUT/co-tested-library files (`UTS_SRC`,
`FRESHNESS_LIB_SRC`, copied via direct `cp "$VAR" "$dest"` lines, never through `REQUIRED_LIBS`)
must also be captured — the declared set is not "the named array's contents," it is "everything
this suite's setup actually copies into the sandbox," which is the set that matters for the
runtime failure the dispatch describes.

**The mandatory-vs-optional classification is the hard part, and gets it wrong without care.**
`update-task-status.sh` (a script every repaired suite copies) sources libraries through at
least three distinct shapes with different missing-file semantics, confirmed by reading the
source directly:
1. **Unconditional, hard-fail** (`PHASE_LIB`/`VOCAB_LIB`, `update-task-status.sh:225-272`): a
   `*_CANDIDATES=(...)` array, a search loop, and an explicit `exit 5` when nothing is found,
   followed by an unconditional `. "$PHASE_LIB"`. **MANDATORY** — absence crashes the script.
2. **Unconditional, degrade-safe guard** (`_RR_LIB`, `update-task-status.sh:213-215`; identical
   idiom in `task-lock.sh`): the single-line `[ -f "$_RR_LIB" ] && . "$_RR_LIB"`, documented in
   `context/patterns/regeneration-is-manual-only.md`'s "Redeploy-Remedy Emission Sites"
   subsection (Decision 1(c)) — a missing file silently falls back to a no-op. **OPTIONAL** —
   must never be reported as missing.
3. **Unconditional-shape, soft pass-through** (`OVERLAP_LIB`/`DEPLOY_FRESHNESS_LIB` inside the
   same function, `update-task-status.sh:941-991`): the IDENTICAL `*_CANDIDATES=(...)` + search
   loop syntax as case 1, but the empty-result branch only logs `"...inconclusive, passing
   through"` and continues — no `exit`. **OPTIONAL**, and syntactically indistinguishable from
   case 1 without inspecting the empty-branch body for an `exit <nonzero>` vs. a log-and-continue.
4. **Lazy, fail-closed-on-first-use** (`ensure_file_scope_overlap_lib` in `task-lock.sh:255-264`):
   a function wrapping `if ! . "$PATH" 2>/dev/null; then ... return 2; fi`, invoked only from the
   one CLI subcommand that needs it. Statically MANDATORY-if-reached, but static analysis cannot
   tell whether a given suite's scenarios reach that subcommand. All three repaired suites
   already declare `file-scope-overlap.sh` regardless (confirmed in their current
   `REQUIRED_LIBS`/`REQUIRED_LIB_SCRIPTS`), so this shape did not, in fact, drive any of the
   measured repairs — but a future suite that newly exercises `task-lock.sh acquire` without
   declaring this library would hit the identical class of runtime failure this task exists to
   catch at lint time, and a detector that only recognizes shapes 1-3 would miss it.

A detector that flags case 2 or case 3 as "missing" is a false positive the first time it runs
against the live corpus (`_RR_LIB` is deliberately absent from every suite's declared list; it is
absent from all three repaired suites' `REQUIRED_LIBS` today). A detector that only recognizes
case 1's exact `exit 5` shape and nothing else would, by construction, already satisfy this
task's stated regression bar (`project-number-inuse.sh` is sourced unconditionally with no guard
at all, `state-write.sh:214` — the simplest possible shape), but would be measurably narrower
than the corpus's actual mandatory-dependency vocabulary and should not be presented as
exhaustive.

**Dependency closure is depth-1 in the measured corpus today.** None of
`common.sh`/`phase-heading-patterns.sh`/`status-vocabulary.sh`/`file-scope-overlap.sh`/
`task-lookup-lib.sh`/`project-number-inuse.sh` itself sources anything further (checked directly:
zero `source`/`.` lines in any of the six). A depth-1 scan of each copied top-level script
suffices for the full, measured, zero-additional-drift population the dispatch's audit found.
Recommend implementing transitive closure anyway (cheap, and `lib/*.sh` files gaining their own
dependency is a plausible future change this lint should survive without a re-design), but the
report flags that today's corpus does not exercise that generality.

### External Resources

Not applicable — this is a purely internal, codebase-local detection problem with no external
library or API surface; no web research was performed.

## Recommendations

**Detection algorithm** (one script, `scripts/lint/lint-fixture-dependency-declaration.sh`,
matching the naming convention of its 23 siblings in `scripts/lint/`):

1. **Corpus**: `agent-system/extensions/core/scripts/tests/*.sh` (flat, non-recursive — same
   corpus and the same `find`-not-shared-corpus-reuse rationale `lint-subject-resolution-
   declaration.sh` documents for itself: the shared-corpus `[[ == ]]` glob match spans directory
   separators and would silently widen the scan).
2. **Suite selection predicate** (per-file, both required): (a) the file declares at least one
   `require_file "<path>/lib/<name>.sh"` call OR a `*_LIBS=(...)`/`*_SCRIPTS=(...)`-shaped array
   whose elements are consumed by such a call; AND (b) the file contains at least one `cp` line
   whose destination resolves under a sandbox root (`$WORKDIR/.claude/scripts` or
   `$root/.claude/scripts` — both literal forms are live in the corpus). A file satisfying (a)
   without (b) (confirmed example: `test-stall-reprompt-wiring.sh`) is out of scope — it is
   declaring non-`scripts/lib` prerequisites, not building a dependency-complete sandbox.
3. **Declared/copied-set extraction** (unified across both shapes — see Findings): union of every
   literal `require_file`/`cp` argument, every array element consumed by a `require_file`/`cp`
   loop regardless of array name, and every direct `cp "$VAR" "$dest"` line (captures the
   SUT/co-tested-library files copied outside any named array, as in
   `test-postflight-deploy-gate.sh`'s `UTS_SRC`/`FRESHNESS_LIB_SRC`).
4. **Mandatory-dependency extraction**, per copied script (resolve each copied-set entry to its
   real on-disk path under `agent-system/extensions/core/scripts/`, then scan ITS text): classify
   each `lib/<name>.sh` literal occurrence as MANDATORY or OPTIONAL per the four shapes in
   Findings — in order of narrowing false-positive risk: (i) bare `source "..."`/`. "..."` with no
   enclosing `[ -f ... ] &&` on the same line → MANDATORY; (ii) single-line
   `[ -f "$VAR" ] && . "$VAR"` idiom → OPTIONAL, never reported; (iii) a `*_CANDIDATES=(...)`
   array + search loop → inspect the `if [[ -z "$VAR" ]]; then ... fi` body: an `exit <nonzero>`
   → MANDATORY, a log-and-continue with no exit → OPTIONAL; (iv) `if ! . "$PATH" ...; then ...
   exit/return <nonzero>; fi` → MANDATORY. Recurse into each MANDATORY dependency found (depth-1
   suffices for today's measured corpus; implement as a closure, not a single pass, for
   forward-compatibility — see Findings).
5. **Verdict**: for each selected suite, any MANDATORY dependency of any copied script that is not
   itself in the suite's own declared/copied set is one `[VIOLATION]` line naming the suite, the
   copied script that needs it, and the missing library — matching the `[VIOLATION]`/`[PASS]`
   output convention and `--verbose`/exit-code contract (`0`/`1`/`2`) every sibling lint in
   `scripts/lint/` already uses, so `verify_deploy_extract_verdict_lines '[VIOLATION]' ...`
   requires no new consumer-side code.
6. **State this lint's own known limitation explicitly in its header**, matching the convention
   every cited sibling (`lint-subject-resolution-declaration.sh`, `lint-test-root-resolution.sh`)
   states for itself: a regex/text-level classifier of shapes (i)-(iv), not a shell parser; a
   dependency reached only through a shape this lint does not recognize (a fifth guard idiom
   introduced later, or a variable-indirected `source "$(resolve_lib foo)"`) is a bounded blind
   spot, not a soundness claim.

**Regression fixture obligation** (the one the dispatch names as owed): seed the new suite
(`test-lint-fixture-dependency-declaration.sh`) with the exact pre-repair text of all three
historical commits (`d3e45535e^`, `1c10b01f7^`, `4c96ccb4f^` — i.e. `git show <commit>^:<path>`),
asserting the detector flags `project-number-inuse.sh` missing for each, and a fourth
post-repair/current-text case per suite asserting clean. This is directly checkable now (the
commits exist and are quoted above) without waiting for implementation to rediscover them.

## Decisions

- **Siting: route (a), join `gate-registry.data`.** Two already-registered gates scan this
  identical corpus for an identical class of problem — `gate27` (`lint-subject-resolution-
  declaration.sh`, scope `agent-system/extensions/core/scripts/tests/*.sh`, `timeout_s=30`,
  `cost_class=free`) and `gate29` (`lint-test-root-resolution.sh`, same scope plus sibling
  extensions, `timeout_s=30`, `cost_class=free`). A static text scan over the same ~150-file,
  mostly-small corpus is the same order of cost as either, so `timeout_s=30`/`cost_class=free`
  fits the same budget with no new evidence needed to justify it. Route (b) (standalone,
  hand-run-only utility) would not satisfy the dispatch's own stated goal — "report this drift
  BEFORE a run hits it" requires the check to run on every deploy-verification pass, not only
  when an operator remembers to invoke it by hand; a hand-run-only script is exactly the kind of
  check that would itself drift out of use. **Implementation must re-read `gate-registry.data`
  immediately before editing** (per this dispatch's own Territory section: #584 and #601 are
  concurrent siblings this cycle that may also append a new gate row) and take whatever id is
  contiguous with the then-current max — do not hardcode "gate 30" as a commitment; id 30 is
  this report's best estimate against the corpus state at research time (current max is 29), not
  a reservation.
- **No `docs/reference/utility-scripts-inventory.md` entry.** The two most recently added
  gate-registered lints (`gate27`, `gate29`) have no entry in that inventory at all; only the
  OLDER gates (`gate6`, `gate7`, `gate11`) do, and `gate11`'s entry explicitly states "Wired as a
  verify-deploy.sh gate; not automated beyond that" — i.e. the convention has already shifted
  toward NOT duplicate-documenting a gate-registered lint there, with `gate-registry.data` and
  the script's own header as the sole registration record. Follow the newer precedent (27, 29),
  not the older one (6, 7, 11): no inventory entry for this lint.
- **`gate30_run` function body**: a verbatim structural copy of `gate27_run`/`gate29_run`
  (`scripts/verify-deploy.sh:2289-2362`) — the `[SKIP]` branch for a non-source-store `$TARGET`,
  the `fail` branch for a missing lint script, the `pass`/`fail` + `FINDINGS_LIST` population on
  `[VIOLATION]` lines. No new verify-deploy.sh mechanism is required.

## Risks & Mitigations

- **False positives from the OPTIONAL shapes** (Findings #4) are the dominant implementation
  risk, not the two declared shapes themselves. Mitigation: the detector's own test suite must
  include a positive case proving `_RR_LIB`'s absence from every suite's declared list is NOT
  reported, alongside the three positive missing-dependency cases — a clean run on the live
  corpus today is the cheapest, free regression anchor available (every current suite already
  passes; a detector that newly flags any of them on first run is wrong, not newly rigorous).
- **Shared `gate-registry.data`/`shell-script-testing.md` file territory** with concurrent
  siblings #584, #601 (gate row) and #511, #523, plus this proposal's own sibling roster task
  (`shell-script-testing.md`) — both named in this dispatch's Territory section. Mitigation:
  re-read each file immediately before editing (standing territory discipline), stage only this
  task's own hunks, and treat the gate id as computed-at-edit-time, never pre-committed (see
  Decisions).
- **Suite-selection predicate under-reach**: a future suite could copy `scripts/lib/*.sh` files
  into a sandbox via a mechanism this lint's predicate does not recognize (e.g. a symlink loop, or
  the shared lent-fixture overlay — `common_test_fixture_overlay`, `shell-script-testing.md`'s
  "The shared deployed-tree fixture" section — which is itself already dependency-complete by
  construction and correctly OUT of this lint's scope, but a hybrid suite partially using the
  shared fixture and partially hand-copying could confuse the predicate). No such hybrid exists
  in the measured corpus today; flag as a documented blind spot in the script's header rather
  than engineering for an unobserved case.

## Context Extension Recommendations

- **Topic**: the two fixture-dependency-declaration shapes (named array, open-coded parallel
  pair) and the mandatory-vs-optional `source`/`.` guard taxonomy (Findings, four shapes).
  **Gap**: `context/standards/shell-script-testing.md`'s "Required structural model for a new
  suite" section (line 62) documents the `mktemp`/trap/pass-fail-counter shape but has no
  subsection naming the dependency-declaration convention or its drift risk at all — this task
  is the first place either gets written down. **Recommendation**: add a subsection there (titled
  e.g. "Dependency declaration completeness") summarizing the two shapes, the degrade-safe-guard
  exemption, and pointing at the new lint by name — the natural home for a future suite author to
  learn the convention before writing suite #9 or #16 in either shape. This file is shared
  territory with #511/#523/this proposal's sibling roster task per this dispatch's own Territory
  section, so sequence the edit rather than landing it unilaterally.

## Appendix

- Search queries/commands used: `grep -n "REQUIRED_LIBS\|REQUIRED_SCRIPTS\|require_file\|setup_sandbox\|^cp " scripts/tests/*.sh`; `grep -lE '^\s*(REQUIRED_LIBS|REQUIRED_SCRIPTS|REQUIRED_LIB_SCRIPTS|REQUIRED_CORE_SCRIPTS)=\(' *.sh`; `grep -l "require_file " *.sh`; `grep -l "scripts/lib/" *.sh`; `git log --oneline --all -- <suite path>`; `git show <commit>^:<path> | grep REQUIRED_LIBS`; `grep -n "^source \|^\. " scripts/*.sh scripts/lib/*.sh`.
- Files read in full or substantially: `scripts/tests/test-postflight-deploy-gate.sh`,
  `scripts/tests/test-orchestrate-predispatch-review.sh`, `scripts/tests/test-orchestrate-unwind-
  dispatch.sh`, `scripts/lint/lint-subject-resolution-declaration.sh`,
  `scripts/lint/lint-test-root-resolution.sh`, `scripts/lint/lint-gate-registry.sh`,
  `scripts/gate-registry.data`, `scripts/verify-deploy.sh` (gates 27-29 and their registration
  block), `scripts/update-task-status.sh` (lines 205-995, all library-resolution shapes),
  `scripts/task-lock.sh` (lines 226-264), `scripts/state-write.sh` (lines 205-220),
  `docs/reference/utility-scripts-inventory.md`, `context/standards/shell-script-testing.md`
  (section headings).
- Historical commits cited: `d3e45535e`, `1c10b01f7`, `4c96ccb4f` (the three measured repairs),
  confirmed via `git show <sha>^:<path>` against the current working tree.
