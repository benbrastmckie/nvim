# Implementation Plan: Task #700

- **Task**: 700 - Bind a push grant to the pushed ref
- **Status**: [COMPLETED]
- **Effort**: 2.75 hours
- **Dependencies**: None (independent successor; shares `hooks/please-grant.sh` with the
  `/merge`-removal successor, which is ordered after this record and must not be anticipated here)
- **Research Inputs**: specs/700_bind_push_grant_to_pushed_ref/reports/01_bind-grant-to-pushed-ref.md
- **Artifacts**: plans/01_bind-grant-to-pushed-ref.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A consent-gated push grant is bound, at mint time, to `git rev-parse HEAD`, and matched at
consume time against `git rev-parse HEAD` again. For a grant naming a ref that is not the
checked-out branch — the plumbing-built ref case — that binding is both too strict (any
unrelated commit on HEAD inside the expiry window kills the grant) and too loose (the named ref
can be rebuilt between the typed line and the push without the match noticing). This plan makes
`action_class = push_branch` resolve `refs/heads/${REF}`'s own commit at both the mint point and
the match point, which fixes the non-checked-out case and reproduces today's value byte-for-byte
for a checked-out branch, since a checked-out branch's `refs/heads/<name>` *is* what `HEAD`
resolves to. Done means: both binding sites resolve the named ref, the suite proves the three
behaviours the task's acceptance bar names, the one semantic distinction a future reader cannot
re-derive from the field name is written down, and a redeploy reports a clean verify.

### Research Integration

Integrated from `reports/01_bind-grant-to-pushed-ref.md`:

- The HEAD-binding lives at exactly two production call sites: the single `HEAD_SHA` assignment
  in `hooks/please-grant.sh`, and the single `head_sha` assignment in `pg_grant_find_match()` in
  `scripts/lib/push-grant-lib.sh`. `pg_grant_find_match` already receives `action_class` and
  `ref` as parameters, so no new parameter has to be plumbed through any caller.
- `hooks/guard-git-push.sh` and `scripts/git-push-granted.sh` are call-site spectators: both pass
  a bare ref string into `pg_grant_consume` and read no SHA themselves. Neither needs a code
  edit; their listing in the task's territory is explained by test coverage.
- No separate "is `REF` the checked-out branch" conditional is needed. Gating strictly on
  `action_class = push_branch` excludes `push_tag` (whose stored `REF` is the unresolvable
  pattern `refs/tags/*`) and the six destructive classes (whose `REF` is always the checked-out
  branch or the `HEAD` sentinel) by construction, as an allow-list rather than a drifting
  deny-list.
- Resolve via `git rev-parse --verify --quiet "refs/heads/${REF}"` with no second fallback form:
  plumbing-built refs already live under `refs/heads/` (`context/patterns/ref-plumbing-landing.md`),
  and an unresolvable `REF` must refuse to mint rather than fall back to another interpretation.
- Keep the on-disk grant field name `HEAD_SHA`. A rename ripples into the lib's write/verify
  functions, every grant-field assertion in `test-please-grant.sh`, and that suite's fixture
  literal, for a label-only change — and would make a suite failure attributable to the wrong
  cause. Adopted as written; see Decisions D2.
- `file_scope` does not need extending for a production code file; the report's own Context
  Extension Recommendation (one clarifying sentence in `context/standards/git-safety.md`) is
  taken up here as Phase 3 rather than left to a follow-up, since it is a single prose sentence
  about the semantics this record creates.

One plan-time finding extends the report; see Decisions D1.

### Premise Re-Validation

Every trigger-class line of the task description and every load-bearing figure in the research
report, re-measured at plan-authoring time against the live source store:

| Carried claim | Plan-time result |
|---|---|
| Source store is the edit target; resolve `source_dir` from `.claude-extensions.json` | Confirmed. `core` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core`; all five territory files exist there |
| Grant matched against `git rev-parse HEAD` at consume time, `scripts/lib/push-grant-lib.sh` near line 453 | Confirmed. `head_sha="$(git rev-parse HEAD 2>/dev/null)" || return 1` at line 453, compared at line 464 (`[ "$PG_F_HEAD_SHA" = "$head_sha" ] || continue`) |
| `hooks/please-grant.sh` records HEAD near line 211 | Confirmed. `HEAD_SHA="$(git rev-parse HEAD 2>/dev/null)" || HEAD_SHA=""` at line 211, guarded by `[ -n "$HEAD_SHA" ] || exit_ok` at 212 |
| `PG_EXPIRY_WINDOW` default 600 seconds; one grant at a time; default-branch force bar | Confirmed unchanged and untouched by this plan |
| `/please push <remote> <branch>` already names any branch, checked out or not | Confirmed: the grammar's captures are bare branch-name tokens with no `refs/` prefix |
| `/merge` minting branch is removed by the later successor; do not touch it here | Confirmed present in `please-grant.sh`; excluded from every phase below |
| Report: `please-grant.sh` 253 lines, `push-grant-lib.sh` 652, `test-please-grant.sh` 350, `test-guard-git-push.sh` 492, `guard-git-push.sh` 227 | All five confirmed exactly |
| Report: `scripts/git-push-granted.sh` 115 lines | **Off by one** — `wc -l` reports 114. Not load-bearing (the file needs no edit); recorded in the task's issue log for figure hygiene |
| Report: no document states the HEAD-binding as a claim needing correction | Confirmed. `git-safety.md:126` and `push-consent-relay.md:76` both say "commit SHA", general enough to stay true; neither becomes false |
| Report: no third production call site reads a SHA | Confirmed for production code. **A third binding exists in a test fixture** the report did not survey; see Decisions D1 |

## Goals & Non-Goals

**Goals**:

- A `push_branch` grant binds, at mint time, to the commit of the ref it names, and is matched at
  consume time against that same ref's current commit.
- A grant for the checked-out branch behaves exactly as it does today, with no behavioural delta
  observable by any existing suite case.
- The suite proves all three acceptance behaviours the task names: survival of an unrelated HEAD
  commit, refusal once the granted ref itself moves, and unchanged checked-out-branch behaviour.
- The `push_branch`-vs-every-other-class split in what `HEAD_SHA` holds is written down once,
  where a future reader of the grant mechanism will find it.

**Non-Goals**:

- A typed `/slice push <id>` minting path, or a batch grant. Neither is built here.
- Any change to who may mint a grant, to the grammar, to `PG_EXPIRY_WINDOW`, to the
  one-live-grant rule, or to the default-branch force bar.
- Removal of the `/merge` minting branch of `hooks/please-grant.sh`. That belongs to the
  `/merge`-removal successor, which is ordered after this record and edits the same file.
- Renaming the on-disk `HEAD_SHA` grant field (D2).
- Any code edit to `hooks/guard-git-push.sh` or `scripts/git-push-granted.sh`.
- Performing an actual push. Every case runs against fixture repositories
  (`rules/pr-prohibition.md`).

## Decisions

**D1 — the test fixture's own HEAD-binding is in scope, as a third site.**
`scripts/tests/test-guard-git-push.sh`'s `mint_grant_in` helper (line 89) mints every fixture
grant with `sha="$(git rev-parse HEAD)"`, calling `pg_grant_mint` directly rather than going
through the hook. The research report's call-site survey covered production code only, so this
site is new information at plan time. It matters because the helper is how every consume-side
case constructs its grant: a positive case for a non-checked-out ref is unwritable until the
helper mirrors the hook's resolution. Phase 2 therefore updates the helper to resolve
`refs/heads/<ref>` for `push_branch` and keep `HEAD` for every other class — the same one-line
shape as the production sites, so the fixture keeps modelling the real mint rather than a
divergent one.

**D2 — the on-disk field keeps the name `HEAD_SHA`.** Adopted from the report's recommendation,
recorded here because the opposite choice is reasonable and should be visibly considered rather
than look overlooked. The field still holds *a* commit SHA; what changes is which commit. A
rename is a label-only diff across the lib's write/verify path and every grant-field assertion in
`test-please-grant.sh`, and it would let a behavioural regression be misattributed to the rename.
The semantic the name no longer conveys is carried by the comments in Phase 1 and the sentence in
Phase 3 instead.

**D3 — one resolution form, no fallback.** `git rev-parse --verify --quiet "refs/heads/${REF}"`
only. No bare `"$REF"` second attempt, and no `--abbrev-ref` round trip. An unresolvable `REF`
refuses to mint (mint side) and refuses to match (consume side), which is the fail-closed
direction the grant mechanism already takes everywhere else.

**D4 — `context/standards/git-safety.md` gets the clarifying sentence; `push-consent-relay.md`
does not.** `git-safety.md:126` is the one place that enumerates what a grant binds, so the split
belongs in that existing sentence's paragraph. `push-consent-relay.md:76` says "bound to the
commit SHA ... at the moment of minting", which stays true verbatim under this change and would
gain nothing but a second place to drift.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A bare `git push` in detached HEAD derives `REF="HEAD"` in `guard-git-push.sh`, which the new resolution cannot resolve, so a grant that would have matched today is refused | L | L | Fail-closed and unreachable in practice: a `push_branch` grant with `REF=HEAD` can only be minted by a pathological typed line, and refusing it is the safe direction. Phase 2 asserts the refusal explicitly rather than leaving it undocumented |
| An intermediate state after Phase 1 but before Phase 2 in which fixture grants are HEAD-bound while production resolves the named ref | L | M | No regression is possible: every existing case's `REF` is the checked-out branch `feature-x`, for which both resolutions return the same SHA. The one existing non-checked-out case (`other-branch`, a negative) still refuses — fail-closed, by an unresolvable ref instead of a SHA mismatch. Phase 2 re-asserts that case's refusal so the reason is pinned, not assumed |
| A `REF` typo colliding with an unrelated existing local branch mints a grant bound to that branch's commit instead of failing loudly | L | L | No worse than today, where the same typo silently mints against `HEAD`. The grant still fails at consume time once the real push names a ref whose commit does not match, so the end-to-end fail-closed property holds — one step later |
| A future mint path supplies a full ref path (`refs/heads/foo`) and the concatenation becomes `refs/heads/refs/heads/foo` | M | L | Not reachable from the grammar this record touches, which only ever captures bare names. Phase 1's inline comment states the bare-name precondition at the resolution site, so whichever successor adds a mint path meets it there |
| The `/merge`-removal successor edits the same hook and lands after this record | M | M | Phase 1 confines its edit to the single `HEAD_SHA` assignment block, after all four mint-source branches have already set `ACTION_CLASS`. The `/merge` branch itself is untouched, so the later removal is a clean deletion with no conflict in this record's hunk |
| Sibling task dispatched this cycle touches `manifest.json`, `commands/slice.md`, `scripts/tests/suite-classification.data` | M | M | Disjoint from every path below. This plan adds no new file, so no manifest registration and no suite-classification row is owed. Re-read each file immediately before editing and stage only this task's own hunks, per the dispatch's concurrency note |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Resolve the pushed ref at both binding sites [COMPLETED]

**Goal**: A `push_branch` grant is bound at mint time, and matched at consume time, against the
commit of the ref it names; every other action class still uses `HEAD`.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/hooks/please-grant.sh` lines 205-215 immediately
      before editing (a sibling is live on this tree this cycle), confirming the single
      `HEAD_SHA="$(git rev-parse HEAD 2>/dev/null)"` assignment is still at line 211 and still
      sits after the `[ -n "$MINT_SOURCE" ] && ...` completeness guard. *(completed: confirmed
      unchanged at line 211)*
- [x] Replace that one assignment with a two-branch form: for `ACTION_CLASS = push_branch`,
      `git rev-parse --verify --quiet "refs/heads/${REF}"`, refusing via the existing `exit_ok`
      when it does not resolve; for every other class, the existing `git rev-parse HEAD` path
      unchanged. Keep the variable name `HEAD_SHA` (D2) so `pg_grant_mint`'s argument list and
      the echoed `SHORT_SHA` need no change. *(completed)*
- [x] Add one comment line at that site stating that the value is the named ref's own commit for
      `push_branch` and `HEAD` for every other class, and that `REF` is a bare branch name (not a
      full ref path) for every grammar form that can reach this branch. *(completed)*
- [x] Do not touch the `/merge` minting branch of this hook, nor any other mint-source branch.
      *(completed: confirmed untouched by re-reading lines 60-135)*
- [x] Re-read `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` lines 447-470, then
      replace the single `head_sha="$(git rev-parse HEAD 2>/dev/null)" || return 1` assignment in
      `pg_grant_find_match()` with the same two-branch form, gated on the already-in-scope
      `action_class` local and using the already-in-scope `ref` local. Keep the existing
      `[ -n "$head_sha" ] || return 1` fail-closed guard covering both branches, and leave the
      comparison at line 464 and the whole candidate loop untouched. *(completed)*
- [x] Add the same one-line clarification to the grant-file-format header comment near line 29 of
      the lib, where the `HEAD_SHA` field is described. *(completed)*
- [x] Confirm by reading that no other line in either file reads `HEAD` for a grant SHA.
      *(completed: grep of rev-parse/HEAD across both files confirms only the two edited sites
      and the unrelated /merge|/pr REF derivation at line 86/181, which never reads a grant SHA)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/hooks/please-grant.sh agent-system/extensions/core/scripts/lib/push-grant-lib.sh` covers this edit's one-hop dependent set, since the selector maps these two paths to `test-deploy-propagation.sh`, `test-guard-destructive-git.sh`, `test-guard-git-push.sh`, `test-lint-hook-registration-paths.sh`, `test-orchestrate-build-dispatch.sh`, `test-please-grant.sh`, and `test-record-stash-provenance.sh` — every consumer of `pg_grant_consume`, including the destructive-guard path this plan must prove it did not disturb.

**Scope Hypothesis**: Exactly two production hunks (one per file), each replacing one assignment,
plus two comment lines; `hooks/guard-git-push.sh` and `scripts/git-push-granted.sh` need no code
change at all. Confirm by grepping both files for `rev-parse` and for `HEAD` before concluding
the edit is complete: if either excluded file turns out to read a grant SHA itself, stop and
report rather than widening this phase — that would contradict the territory the research
established. No task in this phase requires editing either excluded file.

**Files to modify**:
- `agent-system/extensions/core/hooks/please-grant.sh` - replace the single `HEAD_SHA`
  assignment with the `push_branch`-gated `refs/heads/${REF}` resolution; add one clarifying
  comment
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - the same substitution inside
  pg_grant_find_match(); extend the grant-file-format header comment

**Verification**:
- The selector-named suites above run green via the one `verify-touched.sh` invocation in the
  Tier Justification, executed from the source-store repository root.
- `bash -n` parses both edited files.
- A read-back of each hunk confirms the `push_branch` gate is an equality test against that one
  literal (an allow-list), not a negated list of other classes.

---

### Phase 2: Suite cases for the ref-bound grant [COMPLETED]

**Goal**: The suite proves the three behaviours the acceptance bar names, and the fixture's own
mint helper models the real mint rather than a divergent HEAD-bound one.

**Tasks**:
- [x] In `scripts/tests/test-guard-git-push.sh`, update the `mint_grant_in` helper (line 89) so
      that for `push_branch` it binds to `git rev-parse refs/heads/<ref>` and for every other
      class it keeps `git rev-parse HEAD`, mirroring Phase 1's production shape (D1). Update the
      helper's own header comment, which currently states the grant is "bound to that repo's
      current HEAD". *(completed: mint_grant_in now mints nothing at all when the ref does not
      resolve, mirroring please-grant.sh's own fail-closed refusal)*
- [x] Extend `make_push_fixture` (or add a sibling helper beside it) so a fixture can carry a
      second branch that is **not** checked out, built the way a plumbing-landed ref is — advance
      `refs/heads/<name>` without a checkout — while `feature-x` stays the checked-out branch.
      *(completed: added sibling helpers `make_plumbing_branch` / `advance_plumbing_branch`,
      using `commit-tree` + `update-ref`, never a checkout)*
- [x] Consume-side case: a `push_branch` grant for the non-checked-out ref survives an unrelated
      commit on the checked-out branch inside the expiry window — the guard authorizes the push
      and the grant is consumed. *(completed; empirically confirmed against the pre-fix
      production code via a scratch copy that this case fails pre-fix (exit 2) and passes
      post-fix (exit 0) -- a genuine discriminator)*
- [x] Consume-side case: the same grant is refused once the granted ref itself moves after mint.
      *(completed; empirically confirmed this case is satisfied by BOTH pre-fix and post-fix
      code -- pre-fix refuses every non-checked-out-ref grant unconditionally (too strict), so
      this case is a forward-looking regression pin for the fixed behaviour rather than an
      old-vs-new discriminator; recorded in issues.jsonl rather than mis-described*)
- [x] Consume-side regression case: a grant for the checked-out branch is still killed by a
      commit on HEAD inside the window, exactly as today. *(completed: the pre-existing "HEAD
      moved since mint" case already exercises this identically under the new code, since
      refs/heads/feature-x IS what HEAD resolves to while checked out; annotated in place)*
- [x] Consume-side case: a `push_branch` grant whose ref does not resolve under `refs/heads/` is
      refused (fail-closed), pinning the refusal reason for the existing `other-branch` negative
      case and for the detached-HEAD `REF=HEAD` derivation named in Risks. *(completed: added a
      dedicated REF=HEAD case here, plus annotated the existing "other-branch" case; the
      detached-HEAD risk is pinned more directly by the production-level please-grant.sh mint
      case below, since no push_branch grant naming REF=HEAD can ever be minted in the first
      place)*
- [x] In `scripts/tests/test-please-grant.sh`, mint-side case: `/please push origin <other>` for
      an existing non-checked-out branch mints exactly one grant whose `HEAD_SHA` equals that
      branch's commit and differs from `HEAD` — reusing the existing `field_in` /
      `grant_files_in` helpers and the `assert_mint_fields` convention. *(completed, using the
      fixture's existing "master" branch, advanced past by an extra commit on feature-x so the
      two commits provably differ; empirically confirmed discriminating against the pre-fix
      please-grant.sh)*
- [x] Mint-side case: `/please push origin <nonexistent>` mints nothing. *(completed;
      empirically confirmed discriminating -- pre-fix please-grant.sh minted a grant for a
      nonexistent branch, post-fix refuses)*
- [x] Mint-side regression case: a grant for the checked-out branch still binds to `HEAD`.
      *(completed)*
- [x] Run both suites directly and confirm every pre-existing case still passes, with no
      assertion rewritten to accommodate the new behaviour. *(completed: 50/50 in
      test-guard-git-push.sh (47 pre-existing + 3 new), 32/32 in test-please-grant.sh (28
      pre-existing + 4 new, including a bonus production-level pin for the pathological
      "/please push HEAD to origin" typed line, empirically confirmed discriminating); zero
      pre-existing assertions altered)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/test-please-grant.sh agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` is the covering check, since the selector maps these two paths to exactly `test-guard-git-push.sh`, `test-please-grant.sh`, and `test-record-stash-provenance.sh`, and a suite file has no dependents of its own beyond the runner.

**Scope Hypothesis**: Nine new or amended cases across two suites (six consume-side in
`test-guard-git-push.sh`, three mint-side in `test-please-grant.sh`), plus one helper amendment
and one fixture extension — and **no new suite file**, therefore no `manifest.json` registration
and no `scripts/tests/suite-classification.data` row, both of which a sibling task owns this
cycle. Confirm by checking, before closing the phase, that `git status --short` shows no
modification to either of those two files; if a new suite file turns out to be genuinely needed,
stop and report the territory collision rather than editing a sibling's file. No task in this
phase requires touching either excluded file.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` - resolve the named ref in
  the mint_grant_in helper; add the non-checked-out fixture branch and the four consume-side cases
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` - add the three mint-side
  binding cases

**Verification**:
- The three selector-named suites run green via the one `verify-touched.sh` invocation above.
- Each new case is run once with Phase 1's edit reverted in a scratch copy (or reasoned through
  against the pre-edit source) to confirm it would have FAILED before the fix — a case that
  passes either way proves nothing about this record's change.
- Case count in each suite's final tally increases by exactly the number of cases added, with no
  pre-existing case removed or weakened.

---

### Phase 3: Document the push_branch/HEAD split [COMPLETED]

**Goal**: The one semantic a future reader cannot re-derive from the field name — which commit
`HEAD_SHA` holds, for which action class — is stated once in the standard that enumerates what a
grant binds.

**Tasks**:
- [x] Re-read the paragraph containing `context/standards/git-safety.md` line 126 ("... branch/tag,
      commit SHA, and force-or-not ...") immediately before editing. *(completed)*
- [x] Add one sentence to that existing paragraph — not a new section — stating that for a
      `push_branch` grant the bound SHA is the named ref's own commit, and that for every other
      action class it is `HEAD`'s. *(completed)*
- [x] Write it as a statement of the current design only: no "previously", no "no longer", no
      task-number reference (`rules/no-record-versioning-in-deliverables.md`,
      `rules/no-task-references-in-deliverables.md`). *(completed: confirmed by re-reading the
      added sentence)*
- [x] Leave `context/standards/push-consent-relay.md` untouched (D4); confirm by re-reading its
      line 76 that the sentence there remains true as written. *(completed: confirmed untouched
      and still accurate)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The selector returns `__FULL_SWEEP__` as its entire output for this one
markdown path, so no suite covers it and the covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(the repository root holding both a deployed `.claude/` tree and the `agent-system/extensions`
source store, as that script's `TARGET_REPO` contract requires) alongside the `prose` row's diff
read-through.

**Scope Hypothesis**: One sentence in one existing paragraph of one file, with
`push-consent-relay.md` deliberately excluded. Confirm the target paragraph still enumerates what
a grant binds before editing; if that enumeration has moved or been rewritten, place the sentence
wherever the enumeration now lives and say so in the phase notes rather than inventing a new
section. No task in this phase requires editing the excluded file.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-safety.md` - one clarifying sentence added
  to the existing grant-binding paragraph

**Verification**:
- Diff read-through confirms every changed hunk lies inside prose, adds no page-level version
  label, and carries no task-number reference. *(confirmed)*
- The gate subset named in the Tier Justification runs green (both gates must report a real
  check, not SKIP — a zero-check-under-filter result does not attest to anything).
  *(Gate 4 (task-reference lint) ran clean. Gate 3 (doc-lint) reported 4 pre-redeploy-drift
  failures -- a plan-ordering collision, not a defect in this phase's edit: "deployed script
  content drift" for every source-store file Phases 1-2 touched, plus an index-entries.json
  line_count mismatch for git-safety.md that `generate-context-line-counts.sh --write` itself
  refuses to fix from the source store (it requires a deployed scripts/ tree -- the same
  machinery `deploy-headless.sh` runs automatically before every deploy). Content correctness
  was confirmed by diff read-through instead; gate 3/4 is re-run, and expected green, as part of
  Phase 4's own redeploy+verify criterion below. Recorded in issues.jsonl.)*

---

### Phase 4: Redeploy and verify [COMPLETED]

**Goal**: The source-store change is live in the deployed tree and the deploy reports a clean
verify.

**Tasks**:
- [x] Confirm Phases 1-3 are committed and the working tree holds no partial hunk of this task's
      own work. *(completed)*
- [x] Run the redeploy with the bounded-wait idiom — `timeout 540 bash
      .claude/scripts/deploy-headless.sh`, Bash tool timeout `600000`
      (`context/patterns/external-process-wait.md` Rule 1). Never an unbounded wait, and never a
      `git-snapshot.sh` call in its reverting default mode (a sibling is live on this tree).
      *(completed)*
- [x] Read the deploy's verify output and confirm it reports clean; if a gate fails, fix forward
      in the source store and redeploy rather than reverting (`rules/error-handling.md`).
      *(completed: first redeploy attempt failed gate 22 (shellcheck SC1083) on an unquoted
      `HEAD^{tree}` in Phase 2's `make_plumbing_branch` helper; fixed forward in a scoped commit
      and redeployed. Gate 3/4 (the Phase 3 collision) resolved automatically as expected.
      Second redeploy: PASS -- 41 checks, 0 failures)*
- [x] Confirm the deployed `.claude/hooks/please-grant.sh` and
      `.claude/scripts/lib/push-grant-lib.sh` carry the Phase 1 hunks, so the live hook path — not
      only the source store — has the fix. *(completed: byte-identical diff confirmed for both
      files, plus the two test files and git-safety.md)*
- [x] Run the scoped touched-path check over this task's own touched paths, and record in the
      phase notes that the complete gate set is deferred to the orchestration close rather than
      independently run here. *(completed: `verify-touched.sh` over all five touched paths ->
      98/98 passed, 0 failed, 7 suites selected + 1 OWED-fallback full free-cost-class battery
      for the prose touched path. The complete `verify-deploy.sh` gate set is deferred to this
      multi-task batch's orchestration close per the dispatch's Batch Gate Deferral directive)*

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase introduces no source edit of its own — the two real paths listed
below are re-read for deployment confirmation, not modified, and the whole-tree claim is the
deploy's own. Confirm by checking that `git status --short` shows no new modification under
`agent-system/**` attributable to this phase; if a gate failure forces a fix-forward edit here,
that edit is a real new hunk and must be committed and verified as such rather than folded
silently into the deploy step.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, an
  implicit scope claim over the entire deployed tree
- `agent-system/extensions/core/hooks/please-grant.sh` - no new edit; re-read to confirm the
  deployed copy matches
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - no new edit; re-read to confirm
  the deployed copy matches

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes inside its bound and reports a
  clean verify.
- Scoped touched-path check:
  `bash .claude/scripts/verify-touched.sh` over this task's touched paths runs green.
- Under `/orchestrate`, the complete gate set
  (`bash .claude/scripts/verify-deploy.sh`) is **deferred to the orchestration close**
  (`context/contracts/batch-gate-stage.md`) and is explicitly not invoked as this phase's own
  independent full battery. Run standalone, outside an orchestration with no close to defer to,
  this phase runs that complete set directly.

## Testing & Validation

- [ ] A `push_branch` grant for a non-checked-out ref survives an unrelated commit on the
      checked-out branch inside the expiry window.
- [ ] The same grant is refused once the granted ref itself moves.
- [ ] A grant for the checked-out branch behaves exactly as before, including still being killed
      by a commit on HEAD inside the window.
- [ ] A `push_branch` grant whose ref does not resolve under `refs/heads/` is refused at both mint
      and consume.
- [ ] `push_tag` and the six destructive classes are provably unaffected — the destructive-guard
      and tag cases in the selector-named suites run green with no assertion amended.
- [ ] No push is performed by an agent; every case runs against fixture repositories
      (`rules/pr-prohibition.md`).
- [ ] `deploy-headless.sh` reports a clean verify.

## Artifacts & Outputs

- `agent-system/extensions/core/hooks/please-grant.sh` — ref-bound mint for `push_branch`.
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` — ref-bound match for
  `push_branch`, plus the grant-file-format comment.
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` — ref-resolving mint helper,
  non-checked-out fixture branch, four consume-side cases.
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` — three mint-side binding
  cases.
- `agent-system/extensions/core/context/standards/git-safety.md` — one clarifying sentence.
- A regenerated `.claude/` deploy tree.
- `specs/700_bind_push_grant_to_pushed_ref/summaries/01_bind-grant-to-pushed-ref-summary.md` at
  completion.

## Rollback/Contingency

Each phase is one commit, and the whole change is five small hunks across five files, so the
contingency is a forward revert of the named commits followed by a redeploy — not a working-tree
discard, which is barred while a sibling is live on this tree
(`rules/git-workflow.md`, "No Destructive Git on Uncommitted Work"). If an intentional rollback
of uncommitted work becomes genuinely necessary, take a durable checkpoint first with
`bash .claude/scripts/git-snapshot.sh 700 --no-revert`; the reverting default form is barred
under this cycle's concurrency.

If Phase 1 lands and Phase 2 cannot be completed, the state is safe to leave: every existing case
is green, and the non-checked-out path is strictly better than before (bound to the right commit
rather than the wrong one) but unproven by the suite. Mark Phase 2 `[PARTIAL]` rather than
reverting Phase 1. If the deploy in Phase 4 fails verify, fix forward in the source store and
redeploy; never discard uncommitted changes to reach a passing verify.
