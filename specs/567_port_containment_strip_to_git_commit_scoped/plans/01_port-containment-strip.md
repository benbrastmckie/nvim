# Implementation Plan: Task #567

- **Task**: 567 - Port git-commit-phase.sh's deployed-tree containment strip into git-commit-scoped.sh's V10 resolution block
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/567_port_containment_strip_to_git_commit_scoped/reports/01_port-containment-strip.md
- **Artifacts**: plans/01_port-containment-strip.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Site 2 (`git-commit-phase.sh`'s Containment Self-Check) already strips every `.claude`/`.claude/`/
`.claude/*` entry out of its `file_scope_arr` before testing containment; Site 3
(`git-commit-scoped.sh`'s V10 effective-scope resolution) still reads the same unstripped
`file_scope` straight from `specs/state.json`, so a path Site 2 admits is independently vetoed one
layer downstream. This plan ports the identical strip into Site 3 at the one structurally correct
splice point — after the raw `containment_scope_arr` population loop, strictly before the
non-emptiness guard that triggers the own-task-directory / engine-written-state / derived-output
widenings — then pins the new behaviour with a dedicated V10 regression case, restores the
end-to-end assertion that Case 26 was narrowed away from while Site 3 was unpatched, and records
the closure in the standards doc that currently names this residual as deliberately open.

### Research Integration

Key findings carried into the phases below:

- The edit targets are the **source-store** copies under
  `agent-system/extensions/core/` (resolved via `.claude-extensions.json`'s
  `extensions.core.source_dir`), never the `.claude/scripts/` deploy mirror
  (`rules/source-store-deploy-boundary.md`).
- The splice point in `git-commit-scoped.sh` is between the
  `done < <(echo "$file_scope_json" | jq -r '.[]' ...)` loop (currently ending at line 573) and the
  `if [ "${#containment_scope_arr[@]}" -gt 0 ]; then` guard (currently line 575). Placing the strip
  *inside* that guard would evaluate the guard against the unstripped array and let a
  strips-to-empty scope survive into the widening block — the exact failure mode the research
  report's Risks section names.
- `git-commit-scoped.sh` defines **no** `warn()` helper; every V9/V10/V13 warning there is an
  inline `echo "WARN: git-commit-scoped.sh ..." >&2`. Site 2's `warn "..."` call must be translated
  to that convention, not copied verbatim.
- A verbatim copy of Site 2's loop would also reference `file_scope_arr`, which does not exist in
  `git-commit-scoped.sh`; the loop target/source variable must be `containment_scope_arr`.
- The strip warns only — no `issue-record.sh` call — matching Site 2, because it filters the
  *scope definition*, not a candidate path tested against that scope.
- Both test suites resolve their fixture scripts from `SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."`, i.e. the
  source store, and `build_repo()` copies the real `git-commit-scoped.sh` rather than a stub. The
  Phase 1 edit is therefore exercised end to end by the existing suites with no fixture change.
- Scope-strip-only: the within-dispatch `proposed_file_scope_lookup` annotation mechanism is
  explicitly **not** ported, per both the dispatch description and the standards doc's own
  abandoned-union note.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, and `roadmap_flag` is not
set; no roadmap was consulted and no roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- Close Site 3 of the three documented containment sites: a `.claude`-prefixed `file_scope` entry
  is stripped at Site 3's V10 resolution exactly as it already is at Site 2, and a scope that
  strips to empty disables the V10 check (fails open) rather than surviving into the widening
  splices.
- Pin the new Site-3 behaviour directly with a dedicated V10 regression case in
  `test-git-commit-scoped.sh`.
- Restore `test-git-commit-phase.sh` Case 26's full end-to-end assertion, which was deliberately
  narrowed to Site-2-only behaviour while Site 3 was unpatched.
- Keep the Case 20 idempotence fixture green, unmodified, as the non-regression proof that the
  rejected admit-via-union design is not being reintroduced.
- Leave `context/standards/git-staging-scope.md` accurate: the deployed-tree strip is no longer
  site-2-only.

**Non-Goals**:
- Porting the within-dispatch `proposed_file_scope_lookup` / annotation mechanism to Site 3. It
  stays site-2-only, and the standards paragraph's claim about it stays true and stays written.
- Any change to `git-commit-phase.sh` itself — Site 2 already carries the strip.
- Any change to Case 20 in `test-git-commit-phase.sh`; it is re-run, never edited.
- Any edit under `.claude/**` (the deploy mirror). Redeploying the mirror is a separate,
  out-of-band operation and is not part of this task's verification path, because both suites
  resolve their fixture scripts from the source store.
- The summary table of mechanism x site x status that the research report floats as a follow-up
  context extension.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Strip spliced inside the `-gt 0` guard instead of before it | H | M | Phase 1's verification explicitly re-reads the edited region and confirms the strip's closing reassignment precedes the guard line; the Z19 case in Phase 2 fails loudly if a `.claude/`-only scope survives into the widening block |
| Verbatim paste leaves `file_scope_arr` / `warn()` references | H | M | Phase 1 names the required renames and the inline-echo convention as explicit tasks; a `bash -n` syntax check plus the suite run catch an undefined-function call at runtime |
| Case 26's restored assertion is written against Site 2's warning text rather than the end-to-end outcome | M | L | Phase 2 mirrors Case 18's existing assertion shape (`rc`, `git show --name-only`, absence of any drop warning) rather than inventing one |
| New Z19 case lands outside the `task-ref-ok` region and trips the task-reference lint on its `--task 999` literals | M | M | Phase 2 pins the insertion point between Z18's closing `fi` and the `# task-ref-ok:end` marker that currently closes the Z-series region |
| The standards doc edit deletes the still-true half of the paragraph | M | L | Phase 3's tasks state that only the deployed-tree-strip half is revised and the `proposed_file_scope_lookup` half is preserved verbatim |
| Doc path is outside the task's originally declared `file_scope` | M | M | It is declared in Phase 3's `Files to modify`, which `plan-file-scope-harvest.sh` unions into `file_scope` at this plan's postflight, before any implementation dispatch reads it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Port the deployed-tree strip into Site 3's V10 resolution [NOT STARTED]

**Goal**: `git-commit-scoped.sh`'s V10 effective-scope resolution strips every deployed-tree
`file_scope` entry before its non-emptiness guard runs, so a `.claude`-only declared scope
resolves to an empty `containment_scope_arr` and disables the V10 check entirely.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/git-commit-scoped.sh` lines 555-580 immediately
      before editing (a sibling task is dispatched this same cycle; see the Territory block).
- [ ] Insert the strip between the `done < <(echo "$file_scope_json" | jq -r '.[]' 2>/dev/null)`
      line and the `if [ "${#containment_scope_arr[@]}" -gt 0 ]; then` guard — a `for` loop over
      `containment_scope_arr` with a `case "$entry" in .claude|.claude/|.claude/*)` arm that drops
      the entry, an `*)` arm that keeps it, and a final reassignment of `containment_scope_arr` to
      the kept set.
- [ ] Emit one warning per stripped entry using this script's own convention —
      `echo "WARN: git-commit-scoped.sh: stripped deployed-tree file_scope entry '<entry>': ..." >&2`
      — naming `rules/source-store-deploy-boundary.md` and the `__WHOLE_TREE__` sentinel as Site 2's
      message does. Do **not** call `warn`; this script defines no such helper.
- [ ] Use loop variables that do not collide with the surrounding block's names (`s`, `ewp`, `dp`,
      `task_dir_entry`, `entry`); `entry` is already used by the later containment loop at line 632,
      so pick distinct, locally-scoped names.
- [ ] Add no `issue-record.sh` call — warn only, for parity with Site 2.
- [ ] Add a short comment above the strip stating the ordering invariant (strip, then test for
      emptiness) and naming Site 2 as the source of the ported mechanism.
- [ ] Run `bash -n agent-system/extensions/core/scripts/git-commit-scoped.sh`.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/git-commit-scoped.sh` covers this single-file, signature-preserving edit, selecting `test-claude-refresh-matcher.sh`, `test-commit-source-store-path.sh`, `test-generate-task-order.sh`, `test-git-commit-phase.sh`, `test-git-commit-scoped.sh`, `test-guard-destructive-git.sh`, `test-guard-git-push.sh`, `test-handoff-dispatch-identity.sh`, `test-lint-directory-pathspec-boundary.sh`, `test-lint-scoped-commit-boundary.sh`, `test-orchestrate-conclusion-aggregate.sh`, `test-orchestrate-conclusion-roadmap.sh`, `test-orchestrate-context-growth.sh`, `test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`, `test-orchestrate-record-decision.sh`, `test-orchestrate-recover-message-findings.sh`, `test-orchestrate-unwind-dispatch.sh` and `test-redeploy-checkpoint-promotion.sh`.

**Scope Hypothesis**: exactly one insertion point is needed, in one file, with no change to any
line outside the inserted block. Confirm at implementation time by diffing the file after the edit
and checking that the only changed hunk is the inserted strip, and that the
`if [ "${#containment_scope_arr[@]}" -gt 0 ]; then` guard line still follows it.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - insert the deployed-tree strip in the V10 resolution block, between the raw `containment_scope_arr` population loop and the non-emptiness guard

**Verification**:
- `bash -n` on the edited script exits 0.
- Re-reading the edited region shows the strip's closing `containment_scope_arr=(...)`
  reassignment on a line strictly above the `if [ "${#containment_scope_arr[@]}" -gt 0 ]; then`
  guard.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/git-commit-scoped.sh`
  reports green. One of the suites it selects, `test-orchestrate-conclusion-aggregate.sh`, is in
  the concurrently-dispatched sibling task's declared `file_scope`; a failure there is to be
  checked against `git log`/`git status` as a possible in-flight sibling edit before being treated
  as a regression from this phase.

---

### Phase 2: Pin Site 3 directly and restore Case 26's end-to-end assertion [NOT STARTED]

**Goal**: The new behaviour is asserted at both sites — a dedicated V10 case proves Site 3's check
is fully disabled by a strips-to-empty scope, and Case 26 asserts the full end-to-end commit
outcome it was narrowed away from.

**Tasks**:
- [ ] Add a new case `Z19` to `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`,
      inserted after Z18's closing `fi` (currently line 1932) and **before** the
      `# task-ref-ok:end` marker (currently line 1934), so its `--task 999` literals stay inside the
      existing Z-series exemption region.
- [ ] Build the Z19 fixture with `build_repo_with_scope 999 probe '[".claude/"]'`, dirty both
      `specs/999_probe/a.txt` and the sibling `specs/998_sibling/out.txt` that helper already seeds,
      and commit both with `--task 999`.
- [ ] Assert the Z9 "check fully disabled" shape: `rc=0`, `HEAD` advanced by one, **both** paths
      present in `git show --name-only`, and no `WARN: ... dropping out-of-scope pathspec` anywhere
      in the captured output. Including the sibling path is what proves the scope is fully
      disabled rather than merely still admitting the task directory.
- [ ] In `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`, replace Case 26's
      "Deliberately NOT asserted here" comment block (currently lines 1088-1097) with a statement
      that Site 3 now carries the same strip, and drop the stale reference to the out-of-scope
      residual and to an implementation summary.
- [ ] Extend Case 26's assertions, mirroring Case 18's existing style: `rc=0`, `src/a.txt` present
      in `git show --name-only`, and no `WARNING: ... dropping out-of-scope path` anywhere in
      `$out26`. Keep the two existing Site-2 assertions (no drop warning from this script's own
      Self-Check, empty `proposed_file_scope`) unchanged.
- [ ] Run the whole `test-git-commit-phase.sh` suite and confirm Case 20 passes **unmodified** —
      its fixture dirties `other/outside.txt`, not a `.claude/` path, so this change cannot reach
      it; a Case 20 failure would mean the strip leaked into the `proposed_file_scope` mechanism
      and must stop the phase.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` covers this test-only edit pair, selecting `test-claude-refresh-matcher.sh`, `test-commit-source-store-path.sh`, `test-generate-task-order.sh`, `test-git-commit-phase.sh`, `test-git-commit-scoped.sh`, `test-lint-scoped-commit-boundary.sh`, `test-milestone-ref-land.sh`, `test-orchestrate-record-decision.sh`, `test-orchestrate-unwind-dispatch.sh` and `test-task-reference-patterns-lib.sh`.

**Scope Hypothesis**: exactly two files change — one new case appended to the Z-series and one
existing case widened — and Case 20 needs no edit at all. Confirm by running the full
`test-git-commit-phase.sh` suite and observing Case 20 pass with no diff against its current text;
if Case 20 fails, stop and treat it as evidence the Phase 1 strip reached a mechanism it must not,
rather than editing Case 20 to accommodate it.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - add case Z19 pinning that a `.claude/`-only `file_scope` strips to empty and disables the V10 check end to end
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - restore Case 26's full end-to-end assertion and replace its now-stale "Site 2 only" comment block

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` passes, including the
  new Z19 case.
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` passes, including the
  widened Case 26 and the unmodified Case 20.
- A deliberate temporary revert of the Phase 1 strip makes Z19 fail (sanity check that the case
  actually pins Site 3, not something incidental); restore the strip immediately afterwards.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`
  reports green.

---

### Phase 3: Record the closure in git-staging-scope.md [NOT STARTED]

**Goal**: The standards doc stops describing the deployed-tree strip as a deliberately-open,
site-2-only residual, while keeping every still-true claim in the same paragraph intact.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/standards/git-staging-scope.md` lines 477-502
      immediately before editing.
- [ ] Revise the "A third asymmetry, deliberately left open" paragraph in place: retitle it so it
      no longer claims the deployed-tree strip is site-2-only, and state that the strip now runs at
      Site 3's V10 resolution as well, before that block's own non-emptiness guard.
- [ ] Preserve, unchanged in substance, the paragraph's second half: the read-only
      `proposed_file_scope_lookup` annotation remains site-2-only, is never unioned into
      `file_scope_arr`, and the admitting-union variant was built and rejected for regressing the
      idempotence fixture.
- [ ] Rewrite the follow-on paragraph that currently says "Neither of these two site-2 mechanisms
      is mirrored at site 3" and that a bare `.claude/` entry "is still read unstripped" at site 3,
      so it names only the lookup as unmirrored and drops the "future task to close" sentence.
- [ ] Check the "Named residuals, recorded explicitly rather than chased to parity in one pass"
      section (currently beginning line 624) and the "Three Containment sites, not one" section
      header paragraph (currently line 391) for any remaining cross-reference to this specific
      residual; update only if one is found.
- [ ] Do not add the mechanism x site x status summary table the research report floats — that is a
      recorded follow-up, not part of this task.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/standards/git-staging-scope.md` — the selector maps this doc to `test-git-commit-phase.sh` and `test-todo-move-pair-staging.sh`, the two suites that assert against this standard's content, which a plain `prose` diff read-through would not exercise.

**Scope Hypothesis**: the stale claim is confined to the two adjacent paragraphs at lines 477-502,
and no other passage in the file asserts the strip is site-2-only. Confirm at implementation time
with `grep -n "site-2-only\|unstripped\|deployed-tree strip" agent-system/extensions/core/context/standards/git-staging-scope.md`
after the edit and verifying every surviving hit is about the `proposed_file_scope` lookup, not the
strip.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - revise the third-asymmetry paragraph pair to record that the deployed-tree strip is now mirrored at Site 3, keeping the lookup half intact

**Verification**:
- `grep -n "site-2-only" agent-system/extensions/core/context/standards/git-staging-scope.md`
  returns only lookup-related hits.
- The `proposed_file_scope_lookup` sentences and the rejected-union parenthetical are still present
  and unchanged in substance.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/standards/git-staging-scope.md`
  reports green.

---

### Phase 4: Close out — scoped verification over the whole touched set [NOT STARTED]

**Goal**: Every path this task touched is verified together in one narrowed pass, and the complete
gate set is explicitly handed to the orchestration close rather than re-run per phase.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/verify-touched.sh` once over the full touched
      set: `agent-system/extensions/core/scripts/git-commit-scoped.sh`,
      `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`,
      `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`,
      `agent-system/extensions/core/context/standards/git-staging-scope.md` — one multi-path
      invocation, never four single-path runs unioned by hand.
- [ ] Confirm the run is green and that Case 20 and Case 26 both appear as passes in the
      `test-git-commit-phase.sh` output.
- [ ] Confirm `git status --short` shows no stray modifications outside this task's `file_scope`
      (a sibling task is live on this same working tree).
- [ ] Record the Site-3 closure, and the fact that only the `proposed_file_scope` lookup asymmetry
      remains, in the task's completion summary.
- [ ] Defer the complete gate set (`bash agent-system/extensions/core/scripts/verify-deploy.sh`) to
      the orchestration close; do not invoke the full battery as this phase's own criterion.

**Timing**: 0.4 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- none planned (verification and close-out only)

**Verification**:
- The single multi-path `verify-touched.sh` invocation above reports green over all four touched
  paths.
- `git status --short` shows no modification outside this task's declared `file_scope`.
- The complete gate set is explicitly deferred to the orchestration close, per
  `plan-format.md`'s batch-aware deferral rule; this phase runs no independent full battery.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` passes, including
      new case Z19.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` passes, including
      the widened Case 26 and the unmodified Case 20.
- [ ] Z19 fails when the Phase 1 strip is temporarily reverted (proves it pins Site 3).
- [ ] One multi-path `verify-touched.sh` run over all four touched paths is green.
- [ ] No `.claude/**` path was edited at any point.

## Artifacts & Outputs

- Patched `agent-system/extensions/core/scripts/git-commit-scoped.sh` carrying the Site-3
  deployed-tree strip.
- New regression case Z19 in `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`.
- Widened Case 26 in `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`.
- Revised third-asymmetry paragraph pair in
  `agent-system/extensions/core/context/standards/git-staging-scope.md`.
- A completion summary recording that Site 3 is closed and that the `proposed_file_scope` lookup
  asymmetry is the one remaining, deliberate site-2-only mechanism.

## Rollback/Contingency

Each phase is a single-concern edit committed on its own green sub-step, so reverting is a
per-commit `git revert` of that phase's commit — the strip (Phase 1), the test changes (Phase 2),
and the doc change (Phase 3) are independently revertible in that order. If Case 20 or any other
existing case fails after Phase 1, revert Phase 1's commit first and re-derive the splice point
rather than adjusting the failing case; a failing Case 20 specifically indicates the strip reached
the `proposed_file_scope` mechanism, which this task must not touch. No snapshot-and-rollback is
warranted for a change of this size; if one becomes necessary, use
`bash .claude/scripts/git-snapshot.sh 567` only as part of a genuine rollback, never as a routine
checkpoint.
