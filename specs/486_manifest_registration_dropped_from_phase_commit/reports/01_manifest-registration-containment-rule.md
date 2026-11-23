# Research Report: Task #486

**Task**: 486 - Stop a required extension manifest.json registration being dropped from a phase commit as a scope excursion
**Started**: 2026-11-22T00:00:00Z
**Completed**: 2026-11-22T00:00:00Z
**Effort**: ~2 hours (research)
**Dependencies**: Task 430, Task 446, Task 484, Task 494, Task 541 (all confirmed `[COMPLETED]`/archived)
**Sources/Inputs**: - Codebase (agent-system/extensions/core/scripts/git-commit-phase.sh, sync-manifest-scripts.sh, check-extension-docs.sh), specs/TODO.md, archived task summaries (430, 446), git history, specs/state.json
**Artifacts**: - specs/486_manifest_registration_dropped_from_phase_commit/reports/01_manifest-registration-containment-rule.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The script already carries three precedent "local, non-declared" widenings of its containment
  check (own-task-directory, engine-written-state allowlist, derived-output-prefix allowlist),
  all applied to a throwaway `file_scope_arr` copy that never touches the task's declared
  `file_scope` in `state.json`. Option (1) — implicitly admitting the touched extension's own
  `manifest.json` whenever the same phase's `files_touched` also touches that extension's
  `scripts/` tree — fits this exact precedent shape and does not widen the batch-admission
  conflict-detection input the dispatch worried about.
- Option (3) ("the general feedback mechanism subsumes this") is NOT supported by the evidence.
  Tasks 430 and 446 (both `[COMPLETED]`, archived) landed the `proposed_file_scope` deposit
  channel and a mechanical before/after follow-up-commit trigger, but task 446's own summary
  states explicitly that "landed... still requires that dedicated follow-up commit; it is never
  automatic on a later phase's ordinary commit." The mechanism makes recovery mechanical and
  visible; it does not eliminate the extra-commit cost this record's SEVERITY line is about.
  Closing this record under ruling (3) would misstate what landed.
- Option (2) ("pre-commit requirement... told so before the commit fires") targets a different
  failure mode than the one this record describes. The record's symptom is that the agent DID
  edit `manifest.json` (satisfying `test-manifest-scripts-sync.sh`'s pairing requirement) and the
  Containment Self-Check then drops that edit from the commit. A pre-commit nag about a *missing*
  edit would not fire in this scenario at all, and an equivalent check already exists
  post-hoc: `sync-manifest-scripts.sh --check` and `check-extension-docs.sh`'s Rule Q
  (`check_undeclared_scripts`), the latter run as `verify-deploy.sh` gate 3 ("Doc-lint"). Adding a
  second, narrower version of the same check inside `git-commit-phase.sh` would duplicate an
  already-existing, already-wired lint rather than close a gap.
- Recommended ruling: **Option (1)**, implemented as a fourth splice alongside the three that
  already exist, scoped narrowly (one extension's own `manifest.json`, triggered only when that
  same extension's `scripts/` tree is also in `files_touched` for the same phase).

## Context & Scope

This is a meta task whose edit target is the source store
(`agent-system/extensions/core/scripts/git-commit-phase.sh` and its test suite,
`agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`), never the deployed
`.claude/` tree. The task's own dependencies (430, 446, 484, 494, 541) are all confirmed
completed, so the three territory-edge records the original dispatch description named as
blocking/informing this decision have all already landed; this research re-derives their actual
landed shape rather than trusting the dispatch's forward-looking description of them, per the
dispatch's own "re-derive before editing, line numbers move" instruction.

The research question is narrowly: which of the three options in the dispatch's "THE ACTUAL OPEN
QUESTION" section should be implemented, and why — not how to implement it in detail (that is
the planning phase's job).

## Findings

### Codebase Patterns

**Current shape of `git-commit-phase.sh`'s Containment Self-Check** (verified at
`agent-system/extensions/core/scripts/git-commit-phase.sh`, non-empty-`file_scope_arr` guard
starting around line 655, current line numbers — re-derive again before editing):

The script already performs a **deployed-tree strip** (lines ~642-653, landed by task 446 PART
A) before three **local, non-declared widenings** of `file_scope_arr`, all inside the
`[ "${#file_scope_arr[@]}" -gt 0 ]` guard so the existing fail-open posture (skip the whole check
when no `file_scope` was declared) is unchanged:

1. **Own-task-directory member** (line ~667): `file_scope_arr+=("${task_dir}/")`.
2. **Engine-written-state allowlist** (lines ~679-691): sourced from
   `lib/engine-written-state-paths-lib.sh`, falling back to the hardcoded
   `("specs/TODO.md" "specs/state.json")` pair on a source failure.
3. **Derived-output-prefix widening** (lines ~705-715): sourced from
   `lib/derived-artifact-probe-lib.sh`'s `derived_probe_output_prefixes`, fails open (adds
   nothing) on any failure mode.

All three are applied to the in-script `file_scope_arr` variable only — never written back to
`specs/state.json`'s own declared `file_scope`, and never consulted by anything outside this
one script's `is_contained()` closure (defined at line ~720). This is the structural precedent
Option (1) would extend: a fourth splice, same shape, same non-declared/local scope, admitting
exactly one additional derived path (the touched extension's own `manifest.json`) under a
narrow trigger condition (that same extension's own `scripts/` tree is also touched in
`files_touched` this phase).

`context/standards/git-staging-scope.md`'s "Three Containment sites, not one" section documents
that `file_scope_arr` widenings at this site are already understood as a *local commit-surface
concern*, distinct from the task's own declared `file_scope` (which remains what the batch
admission gate's conflict-detection reads). This directly weighs against the dispatch's own
listed downside for Option (1) ("it widens declared territory without review, and `file_scope`
is also the batch admission gate's conflict-detection input") — that downside applies to
widening `specs/state.json`'s declared array, which none of the three existing splices (nor an
Option-(1) implementation following their shape) ever does.

**`is_contained()`'s matching semantics** (lines ~720-750): exact match, directory/glob
ancestor in either direction, or a literal trailing-`/**` suffix's base-directory prefix test,
with the already-closed trailing-slash normalization (`while [ "${entry%/}" != "$entry" ]`
loop, lines ~730-732) still in place exactly as the dispatch's "WHAT IS ALREADY FIXED" section
states.

**The structurally-derivable obligation itself** is enforced by
`agent-system/extensions/core/scripts/sync-manifest-scripts.sh` (landed by task 355,
`acff9f4f0`, extended by task 441 and task 555) and by `check-extension-docs.sh`'s Rule Q
(`check_undeclared_scripts`, line ~585). Both share one matching rule, stated in
`sync-manifest-scripts.sh`'s own header: "full relative path under `scripts/` (not basename),
`deprecated/*` excluded." This settles the scope of Option (1)'s trigger condition precisely:
it should fire for ANY path under `agent-system/extensions/<ext>/scripts/**` except
`agent-system/extensions/<ext>/scripts/deprecated/**`, not only `scripts/lib/` (the dispatch's
illustrative example was narrower than the actual enforced obligation).

Critically, Rule Q is wired into `verify-deploy.sh` gate 3 ("Doc-lint
(`check-extension-docs.sh --quiet`)"), which runs **after** a redeploy — i.e., after the phase
commit this record is about has already happened. It is a real, already-existing safety net for
the case where an agent never edits `manifest.json` at all, but it cannot prevent or repair a
same-phase commit that correctly made the edit and then had it dropped by the Containment
Self-Check before `git-commit-scoped.sh` ever ran. This is the evidence that Option (2) targets a
different failure mode than the one this record's LIVE SYMPTOM describes, and that a
pre-commit duplicate of Rule Q would not close this record's actual gap.

### Landed shape of the two territory-edge tasks (re-derived, not assumed)

- **Task 430** (`feed_undeclared_implement_paths_into_file_scope`, archived,
  `specs/archive/430_feed_undeclared_implement_paths_into_file_scope/`): landed
  `propose_file_scope_addition()` inside `git-commit-phase.sh`'s drop branch, depositing every
  dropped path into the task's own `.return-meta.json` `proposed_file_scope` array
  (additive, idempotent, `flock`-guarded, fail-open), and widened the existing
  `--file-scope-add` consumer chain (`update-task-status.sh`, `skill-base.sh`) from
  `{research, plan}` to `{research, plan, implement}` so the deposit auto-merges into the task's
  declared `file_scope` by the next postflight. This is the mechanism now visible in the current
  script as the "Within-dispatch `proposed_file_scope` lookup" block.
- **Task 446** (`close_the_plan_to_file_scope_reconciliation_gap`, archived,
  `specs/archive/446_close_the_plan_to_file_scope_reconciliation_gap/`): landed the
  deployed-tree strip (PART A) and a read-only `proposed_file_scope_lookup` that only
  *annotates* a repeat drop's warning text (PART B) — explicitly **not** an admitting union,
  because a union was built and rejected in Phase 4 (it regressed `git-commit-scoped.sh`'s own,
  separate, unpatched V10 containment guard, which this record's dispatch's HARD CONSTRAINTS also
  forbid touching here). Task 446's own summary states the resulting limitation in its own words:
  "though landing a within-dispatch-recorded drop still requires that dedicated follow-up
  commit; it is never automatic on a later phase's ordinary commit."
- **Task 484** (`collapse_perpath_scope_excursion_issue_rows_into_o`, completed,
  `specs/484_collapse_perpath_scope_excursion_issue_rows_into_o/`): landed the collapsed
  `scope_excursion_record_emit` call visible in the current script (lines ~766-810), one
  `issue-record.sh` row per drop event rather than per dropped path. Notably, task 484's own
  Phase 1 commit (`b3d393507`) itself registered its own new
  `scripts/lib/scope-excursion-record-lib.sh` in `manifest.json` in the SAME commit — this is a
  live, very recent instance of exactly the obligation this record is about, landing cleanly only
  because that phase's declared `file_scope` happened to include `manifest.json` explicitly
  (visible in the commit diff), not because any general mechanism caught it.

Net effect: the general "declaration-staleness feedback mechanism" the dispatch's Option (3)
names has landed, but it is a **mechanical recovery trigger**, not a **first-drop prevention**.
It converts "an agent might silently miss a `WARNING:` line" into "an agent is mechanically
pointed at a before/after `proposed_file_scope` diff and told to fire a follow-up commit" — but
the follow-up commit itself is still required, still separate, and still the exact cost this
record's SEVERITY line ("costly... RECURRING -- three separate firings within one task") is
about. Ruling (3) as literally written in the dispatch ("subsumes this case once it lands") is
not supported: it has landed, and does not subsume the cost.

### External Resources

Not applicable — this is a pure in-repository shell-script/control-flow question with no
external library or API surface.

## Recommendations

**Rule to implement: Option (1), scoped exactly to the enforced obligation.**

Add a fourth local splice to `file_scope_arr`, same non-declared/non-written-back shape as the
three existing ones (own-task-directory, engine-written-state, derived-output-prefix), placed
alongside them inside the same non-empty guard:

- Trigger: `files_touched` (the phase's own derived stage list, before the Containment loop
  filters it) contains at least one path matching
  `agent-system/extensions/<ext>/scripts/**` for some extension name `<ext>`, excluding
  `agent-system/extensions/<ext>/scripts/deprecated/**` (mirroring `sync-manifest-scripts.sh`'s
  own matching rule exactly, so the widening's trigger condition and the test that actually
  enforces the pairing agree on what counts).
- Effect: for every such `<ext>` discovered, admit
  `agent-system/extensions/<ext>/manifest.json` into `file_scope_arr` for this containment check
  only.
- Derivation is a pure string operation on each `files_touched` entry (segment immediately after
  `extensions/`), no filesystem or git lookup needed — matching the dispatch's own framing of
  this as "a STRUCTURALLY DERIVABLE obligation."
- This does not widen `specs/state.json`'s declared `file_scope`, and therefore does not touch
  the batch-admission conflict-detection input the dispatch's Option (1) paragraph raised as a
  concern — the concern applies to the declared array, not to this script's local
  `file_scope_arr` copy, exactly as the three precedent splices already establish.
- A genuinely out-of-territory path (an unrelated extension's `manifest.json`, or any path
  outside `scripts/` for the touched extension) is untouched by this rule and still drops exactly
  as today, preserving the HARD CONSTRAINT "Do NOT weaken the containment predicate for a genuine
  excursion."
- Fail-open behavior is unaffected: the rule only ever *adds* entries derived from
  `files_touched` paths that are themselves already present; it never introduces a new failure
  mode and never makes the check fatal.

Record the ruling explicitly in the implementation (a header comment at the new splice site,
following this script's own convention of documenting the "why" inline) so a future reader does
not re-litigate Option (2)/(3) without reading why they were rejected here.

## Decisions

- **Option (3) rejected**: the general feedback mechanism (tasks 430 + 446) has landed but does
  not subsume this record's cost — it mechanizes recovery, it does not prevent the first drop or
  eliminate the follow-up-commit cost. Closing this record under ruling (3) would misstate what
  landed, contradicting task 446's own summary.
- **Option (2) rejected as the primary mechanism**: it targets a different failure mode (agent
  never edits `manifest.json` at all) than this record's LIVE SYMPTOM (the edit was made and then
  dropped by containment). An equivalent check already exists and is already wired
  post-redeploy (`sync-manifest-scripts.sh --check` / `check-extension-docs.sh` Rule Q via
  `verify-deploy.sh` gate 3); duplicating it pre-commit inside `git-commit-phase.sh` would not
  close this record's actual gap and would add a second, narrower copy of an existing lint.
- **Option (1) selected**, scoped to the exact matching rule `sync-manifest-scripts.sh` already
  uses (full path under `scripts/`, `deprecated/*` excluded) rather than the dispatch's narrower
  illustrative example (`scripts/lib/` only), so the widening's trigger condition agrees with the
  obligation actually enforced by the test the dispatch cites.
- Implemented as a local `file_scope_arr` splice, following the exact structural precedent of
  the three splices already present, rather than as a new allowlist library — the derivation is
  a one-line string operation on already-in-hand `files_touched` entries with no external
  dependency, so a new `lib/*.sh` file is not warranted the way it was for the
  engine-written-state and derived-output-prefix allowlists (whose source-of-truth genuinely
  lives in a shared library consulted by multiple Containment sites).

## Risks & Mitigations

- **Risk**: the new splice could be read by a future maintainer as license to widen
  `file_scope_arr` by arbitrary structural inference, eroding the containment predicate's
  intent. **Mitigation**: document the splice inline (as the three existing ones already are)
  with an explicit statement that it is local-only, never written back to `state.json`, and
  scoped to exactly one derived path per touched extension.
- **Risk**: a phase that touches `agent-system/extensions/<ext>/scripts/**` incidentally (e.g. a
  pure test-fixture edit under `scripts/tests/`) would also implicitly admit that extension's
  `manifest.json`, even though no new `provides.scripts` registration is actually owed for a
  test-only edit. **Mitigation**: this is intentionally over-inclusive but safe — the splice
  only ever admits one specific, already-known path (`manifest.json`), never a glob or directory,
  and admitting it when not strictly needed has no containment-weakening effect, since the path
  still has to genuinely appear in `files_touched` (i.e., the agent genuinely edited it) to ever
  be staged. Narrowing the trigger to add-vs-modify-vs-remove distinctions would require git
  plumbing this script does not otherwise use at this call site and is not needed for
  correctness.
- **Risk**: the VERIFY section's fixture (a) asks for a case covering a phase that "adds a new
  script under an extension plus that extension's manifest.json" — a planner/implementer must
  make sure the fixture also exercises the `deprecated/*` exclusion and a cross-extension
  negative case (phase touches extension A's scripts but not extension A's manifest; a
  different, untouched extension B's manifest must still drop). **Mitigation**: carry this
  forward explicitly into the plan's VERIFY/fixture list rather than leaving it implicit.

## Context Extension Recommendations

- **Topic**: `context/standards/git-staging-scope.md`'s "Three Containment sites, not one"
  section currently documents the deployed-tree strip and the three existing local widenings at
  Site 2, but does not yet describe this fourth, extension-manifest-aware splice.
- **Gap**: once implemented, a future reader diagnosing a `manifest.json` drop (or lack thereof)
  has no durable pointer explaining why `manifest.json` specifically is treated differently from
  any other undeclared path at this site.
- **Recommendation**: the implementation phase should add a short paragraph to that section
  (or a cross-reference to this record's rationale) documenting the fourth splice, its trigger
  condition, and the explicit rejection of Options (2) and (3) recorded above, so the next
  similar-shaped request is answered by documentation rather than by re-deriving this research.

## Appendix

- Search queries / commands used: `grep -n "is_contained\|file_scope"` over
  `git-commit-phase.sh`; `git log --oneline --all | grep "task 430:\|task 446:\|task 484:\|task
  494:\|task 541:"`; `jq` queries over `specs/state.json` and `.claude-extensions.json`;
  direct reads of `specs/archive/430_.../summaries/01_implement-phase-scope-feedback-summary.md`
  and `specs/archive/446_.../summaries/01_close-plan-file-scope-gap-summary.md`;
  `git show --stat` on task 484's phase commits to confirm its own live
  manifest-registration-in-same-commit instance; `grep -n "check_undeclared_scripts\|Rule Q"`
  over `check-extension-docs.sh`; `grep -n "check-extension-docs.sh"` over `verify-deploy.sh`.
- References: `agent-system/extensions/core/scripts/git-commit-phase.sh`,
  `agent-system/extensions/core/scripts/sync-manifest-scripts.sh`,
  `agent-system/extensions/core/scripts/check-extension-docs.sh`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`,
  `specs/archive/430_feed_undeclared_implement_paths_into_file_scope/`,
  `specs/archive/446_close_the_plan_to_file_scope_reconciliation_gap/`,
  `specs/484_collapse_perpath_scope_excursion_issue_rows_into_o/`.
