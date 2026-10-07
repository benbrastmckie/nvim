# Implementation Plan: Task #361

- **Task**: 361 - Reclassify bare `git stash` as destructive on a shared working tree
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/361_reclassify_bare_git_stash_as_destructive/reports/01_reclassify-stash-destructive.md
- **Artifacts**: plans/01_reclassify-stash-destructive.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Bare, whole-tree `git stash` reverts the working tree. `rules/git-workflow.md` currently lists it
under **Not blocked** with the parenthetical rationale "(do not discard uncommitted changes)",
which is true for a solo tree and false under concurrent writers — a later `git stash pop` can be
refused by a sibling's intervening write, stranding the only copy of the changes inside a stash
entry. `hooks/guard-destructive-git.sh` faithfully implements the rule as written: it guards
`git stash drop`/`clear` (protecting an existing stash) and has no pattern for the tree-reverting
form. This plan corrects the rule first, then adds a guard detector implementing the corrected
rule under a new `DESTRUCTIVE_ACTION_CLASS`, wired into the *existing* snapshot-marker and
grant-consume escape hatches with no second mechanism invented. Definition of done: the eight
scope items each carry a recorded verdict and a landed change, a fixture demonstrated red
pre-change passes post-change, the deploy is regenerated, and the full gate set is green.

All edits land in the source store `agent-system/extensions/core/`. No file under
`agent-system/**` may carry a task-number reference (cite by filename, command, or concept).
No deployed `.claude/**` copy is hand-edited; the deploy is regenerated in the final phase.

### Research Integration

The research report confirmed every carried figure in the dispatch description and supplied four
findings this plan is built on:

1. **Anchors re-derived and confirmed** (independently re-confirmed while writing this plan):
   `rules/git-workflow.md` line 142 carries the defective `**Not blocked**` sentence;
   `hooks/guard-destructive-git.sh` line 427 is the `stash drop|clear` detector setting
   `DESTRUCTIVE_ACTION_CLASS="stash_drop"`; source-store and deployed guard are byte-identical
   (md5 `15f8ba3275f18ea83fb071fa41a0101e` both sides per the report) — a genuine coverage gap,
   not deploy staleness.
2. **The escape hatch generalizes for free on the hook side.** The guard's grant check (around
   line 453) and snapshot-marker check (around line 481) are both unconditional on the *value*
   of `DESTRUCTIVE_ACTION_CLASS`, so Item 5 needs zero new mechanism in the hook.
3. **But the class registry is split across two hand-maintained enumerations.**
   `scripts/lib/push-grant-lib.sh` line 73 (`PG_ACTION_CLASSES`) validates class membership
   and fails closed on an unregistered name; `hooks/please-grant.sh`'s `case "$TEXT"` block
   (the `ACTION_CLASS=` arms around lines 147-157, plus the accepted-forms error text) is a
   *second*, independent enumeration that `PG_ACTION_CLASSES` does not drive. Registering the
   class in only one leaves the grant route unusable while the snapshot route works — an
   asymmetry this plan closes in Phase 5 rather than leaving for a future agent to rediscover.
4. **The cleanest Item 6 fixture already exists as an inverted assertion.**
   `scripts/tests/test-guard-destructive-git.sh` line 194 currently asserts
   `assert_allowed_dirty "baseline: git stash (bare)" "git stash"`. Flipping it to
   `assert_blocked_dirty` *is* the red-before/green-after demonstration, with no new fixture
   machinery.

Recommended verdicts adopted from the report: class name `stash_revert` (Item 3);
pathspec-scoped `git stash push -- <path>` stays **permitted** (Item 7); `git stash pop` /
`git stash apply` stay **permitted** (Item 8). Rationale for each is recorded in Phase 1/2 text.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Correct the rule's premise first: bare `git stash` / `git stash push` leave the **Not blocked**
  list, and the rationale states the concurrent-writer hazard, not the solo-tree truth.
- Add a guard detector covering bare `git stash`, `git stash push`, the implicit-push spellings
  (no subcommand, `git stash -u`), and `-u` / `--include-untracked`, under a new
  `DESTRUCTIVE_ACTION_CLASS="stash_revert"`.
- Make the refusal name the non-destructive alternatives (`git show HEAD:<path>`,
  `git diff HEAD -- <path>`, a scratchpad copy) so a block is not a stall.
- Wire the new class into the existing snapshot-marker and grant-consume machinery on **both**
  wiring points (validation registry and `/please` mint grammar), inventing nothing new.
- Land a fixture demonstrated red pre-change and green post-change.
- Record an explicit, reasoned verdict for Item 7 (pathspec-scoped stash) and Item 8
  (`pop`/`apply`), in the rule and narrative text.
- Regenerate the deploy and leave the full gate set green.

**Non-Goals**:
- Per-agent worktree isolation (ruled out; see `specs/decisions/worktree-isolation-removal-reaffirmation.md`).
- A second escape-hatch mechanism of any kind.
- Any change to the over-staging detectors (they exit 2 unconditionally with no snapshot
  exemption, by design) or to the concurrency-gated history-rewrite predicate.
- The agent-facing teaching material on non-destructive history reads, and the post-incident
  verification checklist — separate tasks with their own territory.
- Redesigning `scripts/git-snapshot.sh`'s own internal `git stash push -u` snapshot mechanism
  (recorded as a residual risk in Phase 2, not fixed here).
- Hand-editing any deployed `.claude/**` copy.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Over-permissive pathspec exemption: matching a bare `--` with no trailing path token re-opens the whole-tree hazard via a crafted command | H | M | Require at least one **non-flag token after** the `--` separator, using the `git add` detector's `read -ra` token-walk idiom (Phase 4); add a fixture for `git stash push --` with nothing after it, expecting blocked |
| Under-permissive detector blocks harmless read-only stash forms (`git stash list`, `git stash show`, `git stash --help`) | M | M | Detector positively confirms the first non-flag token is `push` or absent; explicitly exclude `list show pop apply branch drop clear create store` and carve out `-h`/`--help` (Phase 4); add allow-fixtures for each |
| Registering `stash_revert` in `PG_ACTION_CLASSES` only, leaving `/please` unable to mint it | M | H (easy to miss) | Phase 5 is a dedicated phase for the `please-grant.sh` mint grammar + accepted-forms text, with reciprocal cross-reference comments in both files so a future sixth class does not rediscover the split |
| Hook change is repo-wide: a regression false-positives on every agent Bash call | H | L | Verification Tier `full` on Phase 4 and Phase 6; the existing 650-line test suite is the regression net, and no existing case is removed — only line 194's expectation flips |
| `git-snapshot.sh`'s own default mode internally runs `git stash push -u`, carrying a narrower form of the same concurrency hazard | M | L | Out of scope per the non-goals; recorded explicitly as a known residual risk in `context/standards/git-workflow-narrative.md` (Phase 2) rather than silently absorbed. It is subprocess-invisible to the hook (same precedent as `git-commit-scoped.sh`), so the new detector will not block it |
| Rule's new rationale still invites the "`git stash` is fine, it's reversible" misreading | M | M | The amended text names the specific failure mode (a later `pop` refused by a sibling's write, changes stranded inside a stash entry), not a vague "risky under concurrency" |
| Editing a context file without regenerating `index-entries.json` line counts trips a deploy gate | L | M | Phase 2 runs `generate-context-line-counts.sh --write` as an explicit sub-step |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 2, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-derive Anchors, Confirm Byte-Identity, Amend the Rule [COMPLETED]

**Goal**: Correct the contract before touching any enforcement. Re-confirm every carried figure
against the live source store, confirm the source-store/deployed guard byte-identity, then move
bare `git stash` / `git stash push` out of the **Not blocked** list and rewrite its rationale to
state the concurrent-writer hazard. Record the Item 7 and Item 8 verdicts terse in the rule.

**Tasks**:
- [x] Re-derive, from `agent-system/extensions/core/`, the current line numbers for: the
      `**Not blocked**` sentence in `rules/git-workflow.md`; the `stash drop|clear` detector and
      `DESTRUCTIVE_ACTION_CLASS="stash_drop"` in `hooks/guard-destructive-git.sh`; the
      `PG_ACTION_CLASSES` assignment in `scripts/lib/push-grant-lib.sh`; the `ACTION_CLASS=` arms
      and accepted-forms error text in `hooks/please-grant.sh`; the bare-`git stash` and
      `git stash pop` assertions in `scripts/tests/test-guard-destructive-git.sh`. Report any
      divergence from the figures carried in this plan rather than absorbing it silently.
      *(completed: all figures confirmed at or near carried line numbers; accepted-forms text at
      line 171 vs. plan's carried 175, a trivial drift, no other divergence)*
- [x] Re-confirm byte-identity of `agent-system/extensions/core/hooks/guard-destructive-git.sh`
      and `.claude/hooks/guard-destructive-git.sh` (`diff` plus `md5sum` both sides). If they
      diverge, STOP and report — the premise that this is a coverage gap rather than deploy
      staleness no longer holds, and the plan's ordering assumptions need revisiting.
      *(completed: diff empty, md5 15f8ba3275f18ea83fb071fa41a0101e both sides — identical)*
- [x] In `rules/git-workflow.md`, add bare `git stash` / `git stash push` (including the
      implicit-push spellings and `-u` / `--include-untracked`) to the **Forbidden on a dirty
      tree** list, with a one-line effect statement: it reverts the working tree.
      *(completed)*
- [x] Rewrite the **Not blocked** sentence: remove bare `git stash` (push) from it, and replace
      the parenthetical "(do not discard uncommitted changes)" with language that states the
      concurrent-writer hazard for the removed form — a stash reverts the tree, and a later
      `git stash pop` can be refused ("local changes would be overwritten") because a sibling
      has since written the same path, at which point the changes exist only inside a stash
      entry requiring path-by-path extraction.
      *(completed)*
- [x] Record the **Item 7 verdict** in the **Not blocked** list, terse: `git stash push --
      <pathspec>` stays permitted — its blast radius is bounded to the named paths, the same
      shape as the already-permitted `git restore --staged <path>` and non-forced
      `checkout`/`switch`; blocking it would deny agents the one stash form that is both safe and
      useful under a shared tree, contradicting the territory-contract model already in use for
      concurrent dispatch.
      *(completed)*
- [x] Record the **Item 8 verdict** in the **Not blocked** list, terse and explicit rather than
      implicit: `git stash pop` / `git stash apply` stay permitted — the data-loss moment is the
      *push* (the tree revert), not the recovery step; a pop or apply that would overwrite local
      changes is refused by git itself and leaves the stash intact or leaves conflict markers,
      never a silent discard. This is the same safe-failure shape that keeps non-forced
      `checkout`/`switch` permitted.
      *(completed)*
- [x] Point the rule at `context/standards/git-workflow-narrative.md` for the full incident
      narrative, keeping the rule terse — mirroring the existing split the rule already uses for
      snapshot-mode detail and for the history-rewrite predicate.
      *(completed)*
- [x] Confirm no task-number reference was introduced (`bash .claude/scripts/check-task-references.sh`
      or equivalent targeted grep over the edited file).
      *(completed: 0 occurrences, PASS)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This plan carries these figures from the research report and from a
re-derivation performed while planning: `rules/git-workflow.md` line 142 (`**Not blocked**`),
`hooks/guard-destructive-git.sh` line 427 (`stash drop|clear`),
`scripts/lib/push-grant-lib.sh` line 73 (`PG_ACTION_CLASSES`), `hooks/please-grant.sh` lines
147-157 (`ACTION_CLASS=` arms) and line 175 (accepted-forms text),
`scripts/tests/test-guard-destructive-git.sh` lines 194-195 (the two stash allow-assertions),
and guard md5 `15f8ba3275f18ea83fb071fa41a0101e` on both sides. Every one is a hypothesis to
re-confirm with a fresh `grep -n` / `md5sum` at implementation time, not a fact; report
divergence.

**Files to modify**:
- `agent-system/extensions/core/rules/git-workflow.md` - move bare `git stash`/`git stash push`
  into the forbidden-on-dirty-tree list; rewrite the **Not blocked** rationale to the
  concurrent-writer hazard; record the Item 7 and Item 8 verdicts; point at the narrative

**Verification**:
- Diff read-through confirms every changed hunk is prose inside `rules/git-workflow.md` with no
  code or config surface.
- `grep -n "Not blocked" -A 6` on the edited file shows bare `git stash` / `git stash push`
  absent from the list, `git stash push -- <pathspec>` and `pop`/`apply` present with their
  recorded reasoning, and the parenthetical rewritten.
- `grep -n "stash" ` on the forbidden-on-dirty-tree list shows the new entry alongside
  `git stash drop` / `git stash clear`.
- Byte-identity check result recorded (identical, or divergence reported and the phase stopped).
- No task-number reference in the edited file.

---

### Phase 2: Narrative Incident Writeup and Residual Risk [COMPLETED]

**Goal**: Carry the full incident narrative, the two verdicts' extended reasoning, and the
known residual risk into `context/standards/git-workflow-narrative.md`, so the rule stays terse
and the story is recorded once in the place the rule already points to.

**Tasks**:
- [x] Add a section to `context/standards/git-workflow-narrative.md` following the shape of the
      existing `## No History Rewrites While Another Writer Is Live — Incident and Full Detail`
      section (around line 80) — a one-paragraph mechanism statement, then the measured incident,
      then the enforcement pointer. *(completed: new section titled "No Destructive Git on
      Uncommitted Work — Bare `git stash` Incident and Full Detail", inserted just before the
      History Rewrites section)*
- [x] Write the mechanism: under concurrent writers sharing one tree, `git stash` reverts the
      working tree; a later `git stash pop` can abort ("local changes would be overwritten")
      because a sibling has written the same path since; at that moment the changes are no longer
      recoverable in place and exist only inside a stash entry requiring path-by-path extraction.
      *(completed)*
- [x] Record the measured incident, with every figure re-derived or marked as a carried figure
      from the task record rather than asserted as an established count: two implementation
      agents in one batch of four tasks sharing one tree independently ran bare whole-tree
      `git stash` for the same legitimate purpose (isolating a pre-existing test failure from
      their own edit); both passed the guard correctly per the rule as written; one stash spanned
      a roughly 375-second build while siblings kept writing, so its pop aborted and applied
      nothing; roughly thirty files of pre-session uncommitted work (a freshly-deployed
      configuration tree plus its extension-state file) were reverted out of the tree, captured
      by no commit, surviving only inside a 53-file stash entry, with a second 3-file entry from
      the other agent. Note that sibling *commits* were unharmed throughout, which is why a
      commits-only verification pass cleared both incidents falsely — and that the
      verification-scope half of that finding is filed separately, not covered here.
      *(completed: all figures carried verbatim from the dispatch/plan, explicitly flagged as
      carried figures to re-confirm rather than established counts)*
- [x] Record the Item 7 and Item 8 verdicts' extended reasoning (bounded blast radius for the
      pathspec form; the push, not the pop, is the loss moment; git's own refuse-rather-than-
      discard behavior on a conflicting pop/apply). *(completed)*
- [x] Record the known residual risk explicitly: `scripts/git-snapshot.sh`'s own default mode
      internally runs `git stash push -u` as its snapshot primitive, so the sanctioned snapshot
      helper carries a narrower form of the same concurrency hazard (a recovery pop from that
      internal stash could itself be refused under a sibling's intervening write). It is
      subprocess-invisible to the hook — the same invisibility precedent the guard's header
      already documents for `git-commit-scoped.sh`'s internal git calls — so the new detector
      neither blocks nor needs to exempt it. Flagged for a future task if it recurs; deliberately
      not fixed here. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` and
      confirm the `standards/git-workflow-narrative.md` entry in `index-entries.json` picks up the
      new line count. *(completed: ran with REPO_ROOT override per the script's own deliberate
      source-store-invocation bypass; core narrative entry corrected 150 -> 214; re-check reports
      0 mismatch)*
- [x] Confirm no task-number reference was introduced in either edited file. *(completed:
      check-task-references.sh clean on both)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` - new section with
  the mechanism, the measured incident, the Item 7/8 extended reasoning, and the residual risk
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` for the narrative
  entry (via `generate-context-line-counts.sh --write`, never hand-edited)

**Verification**:
- Diff read-through confirms all narrative changes are prose; the `index-entries.json` change is
  a generated `line_count` only (no hand-authored field).
- The new section's heading follows the existing `## {Rule Name} — {Qualifier}` convention used by
  the other sections in the file.
- The rule's pointer from Phase 1 resolves to the new section by name.
- `generate-context-line-counts.sh` re-run (without `--write`) reports no remaining mismatch.
- No task-number reference in either edited file.

---

### Phase 3: Red Fixture — Flip and Extend the Guard Test Suite [COMPLETED]

**Goal**: Land the Item 6 fixture and *demonstrate* it failing against the unmodified guard,
rather than merely asserting it would. The suite is red at the end of this phase, by design.

**Tasks**:
- [x] Capture a pre-change baseline: run
      `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` and record
      the pass/fail tally, so the post-change comparison in Phase 4 is against a measured
      baseline rather than an assumed one. *(completed: 77 passed, 0 failed)*
- [x] Flip the bare-stash assertion (carried as line 194) from
      `assert_allowed_dirty "baseline: git stash (bare)" "git stash"` to `assert_blocked_dirty`,
      and update its label so it no longer reads as a "safe-form allow case". Move it into the
      "one true positive per destructive detector" group alongside the existing
      `git stash drop` / `git stash clear` cases. *(completed)*
- [x] Leave the `git stash pop` assertion (carried as line 195) as `assert_allowed_dirty`,
      unchanged, per the Item 8 verdict. *(completed: unchanged)*
- [x] Add new `assert_blocked_dirty` cases: `git stash push`, `git stash -u`,
      `git stash --include-untracked`, `git stash push -u`, `git stash push --include-untracked`,
      and `git stash push --` (separator with no trailing path token — must block, per the
      over-permissive-exemption risk). *(completed)*
- [x] Add new `assert_allowed_dirty` cases: `git stash push -- foo.txt`,
      `git stash push -u -- foo.txt bar.txt` (Item 7 exemption); `git stash apply` (parity with
      the existing `pop` case, currently untested); `git stash list`, `git stash show`, and
      `git stash --help` (read-only / help forms must not be caught by the new detector).
      *(completed)*
- [x] Re-run the suite and demonstrate the pre-change failure: the newly-flipped and newly-added
      block-expecting cases fail against the unmodified guard. Record the exact failing case
      names and the tally delta against the baseline — this recorded output is the evidence
      Item 6 requires. *(completed: 82 passed, 7 failed — all 7 failures are the new/flipped
      stash_revert block-expecting cases ("expected exit 2, got exit=0"); full output archived at
      specs/361_reclassify_bare_git_stash_as_destructive/progress/phase3-red-run.log)*
- [x] Confirm no task-number reference was introduced. *(completed: clean)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the bare-stash assertion sits at line 194 and the
`pop` assertion at line 195 of `scripts/tests/test-guard-destructive-git.sh`, and that
`assert_blocked_dirty` / `assert_allowed_dirty` are the suite's existing helper names. Re-confirm
all three with `grep -n "stash\|assert_blocked_dirty()" ` before editing; the helper names and
line numbers are leads, not facts.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` - flip the bare-stash
  expectation; add the blocked cases (push, implicit-push, `-u`/`--include-untracked`, empty
  separator) and the allowed cases (pathspec-scoped, `apply`, `list`/`show`/`--help`)

**Verification**:
- Single-file scope: the suite is the only file touched, and it is run directly (no build
  surface).
- `bash scripts/tests/test-guard-destructive-git.sh` output captured twice — baseline before the
  edit and after — with the delta showing exactly the newly-added/flipped block-expecting cases
  failing and no previously-passing case regressing.
- The failing-case names recorded verbatim in the phase's progress notes as the Item 6 red
  evidence.
- No existing assertion removed; `git diff --stat` on the suite shows additions plus the single
  flipped line.

---

### Phase 4: Guard Detector, New Action Class, and Refusal Message [NOT STARTED]

**Goal**: Implement the corrected rule in `hooks/guard-destructive-git.sh` under a new
`DESTRUCTIVE_ACTION_CLASS="stash_revert"`, register the class for grant validation, and make the
refusal name the non-destructive alternatives. The Phase 3 fixture turns green here.

**Tasks**:
- [ ] Add a `stash_revert` detector to the existing `MATCHED=0` chain (anywhere among the
      detectors; order among mutually-exclusive detectors does not matter). Follow the per-segment
      idiom already used by the `clean -f -d` and forced-`checkout`/`switch` blocks for segment
      extraction, and the directory/glob `git add` detector's `read -ra` token-walk for the
      token-level tests — do not invent a new style and do not write a full tokenizer.
- [ ] Extract same-command segments with the established pattern
      `grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+stash[^;&|]*'` against `$COMMAND_SCAN`
      (already quote/comment-stripped up front, so free-text commit messages cannot
      false-positive).
- [ ] Per segment, strip the leading separator and `git stash`, then walk tokens with `read -ra`:
      skip flag tokens (leading `-`), and decide on the first non-flag token —
      - absent (bare, including the `-u` / `--include-untracked` / `-k` / `-m <msg>` flag-only
        forms) -> **block**;
      - `push` -> inspect for a `--` separator **followed by at least one non-flag token**;
        present -> allow (Item 7); absent, or `--` with nothing after it -> **block**;
      - any of `list show pop apply branch drop clear create store` -> fall through (not this
        detector's business; `drop`/`clear` remain the existing `stash_drop` detector's);
      - `-h` / `--help` anywhere in the segment -> fall through (help output touches nothing).
- [ ] On a block, set `MATCHED=1`, `DESTRUCTIVE_ACTION_CLASS="stash_revert"`, and a `REASON`
      naming the effect, e.g. "bare/whole-tree `git stash` reverts the working tree; under
      concurrent writers a later `git stash pop` can be refused, stranding the changes inside a
      stash entry".
- [ ] Register the class: append `stash_revert` to `PG_ACTION_CLASSES` in
      `scripts/lib/push-grant-lib.sh` (carried as line 73). Without this, `pg_grant_consume`
      fails closed for the new class even if a grant is minted.
- [ ] Add a class-conditional block to the refusal output (the `echo ... >&2` block at the end of
      the hook, carried as lines 505-513), fired when `DESTRUCTIVE_ACTION_CLASS="stash_revert"`,
      naming all three alternatives verbatim: `git show HEAD:<path>` (read the committed version
      without touching the tree), `git diff HEAD -- <path>` (read the uncommitted diff without
      touching the tree), and copying the file(s) of interest to a scratchpad location before
      proceeding. Keep the existing shared `git-snapshot.sh` / `/please` guidance intact for all
      classes.
- [ ] Update the hook's own header comment list of guarded commands (carried around line 38,
      which currently names `git stash drop / git stash clear`) and the class enumerations in the
      comments around lines 25 and 460 so `stash_revert` appears alongside the existing five
      destructive classes.
- [ ] Do **not** add any new exemption path: the existing grant check and snapshot-marker check
      are already unconditional on the class value, so Item 5 needs no hook-side mechanism.
- [ ] Re-run `bash scripts/tests/test-guard-destructive-git.sh`: the Phase 3 red cases now pass
      and no previously-passing case regresses. Record the green tally against the Phase 3
      baseline — this is the second half of the Item 6 evidence.
- [ ] Sanity-check the detector against the guarded-forms list by hand on a scratch dirty repo:
      `git stash`, `git stash -u`, `git stash push`, `git stash push -- one.txt`,
      `git stash list`, `git stash pop`.
- [ ] Confirm no task-number reference was introduced in any edited file.

**Timing**: 1.25 hours

**Depends on**: 1, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the detector chain spans roughly lines 372-447, the
refusal block roughly lines 505-513, `PG_ACTION_CLASSES` line 73, and header/comment class
enumerations around lines 25, 38, and 460. Re-derive each with `grep -n` before editing. Also
asserted: three files changed in this phase and no fourth — confirm with `git status --short`
that nothing outside the declared set was touched.

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - new `stash_revert` per-segment
  detector in the `MATCHED` chain; class-conditional refusal lines naming the three alternatives;
  header and inline class-enumeration comments updated
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - append `stash_revert` to
  `PG_ACTION_CLASSES`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` fully green,
  with the tally compared explicitly against the Phase 3 red baseline.
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set for this repository — run in
  the foreground with output captured. Source-store-ahead-of-deploy drift findings for the files
  this phase edits are expected until Phase 6 regenerates the deploy; every other finding must be
  either absent or demonstrated pre-existing (not attributable to this phase).
- `bash -n` plus `shellcheck` clean on both edited shell files.
- Manual scratch-repo spot-check of the six representative command forms listed in the tasks,
  each exiting as the rule now specifies.
- The refusal output for a blocked bare `git stash` observed to contain `git show HEAD:`,
  `git diff HEAD --`, and the scratchpad-copy guidance.
- No task-number reference in any edited file.

---

### Phase 5: Complete the Escape-Hatch Wiring — `/please` Mint Grammar [NOT STARTED]

**Goal**: Make the existing grant route as usable for `stash_revert` as for the other five
destructive classes, closing the split-registry asymmetry rather than leaving the class
reachable only via the snapshot-marker route. No second mechanism is added — this is wiring the
new class into the one that exists.

**Tasks**:
- [ ] Add an arm to `hooks/please-grant.sh`'s destructive-class `case "$TEXT"` block (carried as
      lines 144-168) recognizing a stash-grant request (`git stash`, `stash`, `git stash push`,
      `stash push` and the obvious variants), setting `DESTRUCTIVE_MATCHED=1` and
      `ACTION_CLASS="stash_revert"`, and using the same fixed sentinel pattern the other
      destructive arms use (`REMOTE="local"`, `REF=<current branch or HEAD>`, `FORCE="0"`) — do
      not invent a second grant schema.
- [ ] Extend the user-facing accepted-forms error text (carried as line 175) so it names the new
      form; without this, an operator attempting the grant gets "could not parse" with no clue
      that the class exists.
- [ ] Add reciprocal one-line cross-reference comments: in `scripts/lib/push-grant-lib.sh` near
      `PG_ACTION_CLASSES` (whose header currently claims to be "the single place that list is
      defined" — true for *validation*, not for *mintability*), point at `hooks/please-grant.sh`'s
      `case` grammar as the second place a new class must be registered; and in
      `hooks/please-grant.sh` near the `case` block, point back at `PG_ACTION_CLASSES`. A future
      sixth class should find both wiring points from either file.
- [ ] Add a grant-check test pair for the new class to
      `scripts/tests/test-guard-destructive-git.sh`, mirroring the existing `reset_hard` pair
      (carried as lines 583-603): `mint_destructive_grant_in <repo> stash_revert`, confirm
      `git stash` is allowed once and `grant_count_in` drops to 0, then re-dirty the tree and
      confirm a second bare `git stash` is blocked exactly as before.
- [ ] Confirm the asymmetry the suite already protects still holds: a `stash_revert` grant must
      **not** exempt over-staging (the over-staging detectors exit 2 before the grant check is
      reachable). Re-run the existing over-staging-with-grant case to confirm no regression.
- [ ] Re-run the full guard test suite; green.
- [ ] Confirm no task-number reference was introduced in any edited file.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/hooks/please-grant.sh` - new `stash_revert` mint arm; extended
  accepted-forms error text; cross-reference comment pointing at `PG_ACTION_CLASSES`
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - cross-reference comment pointing
  at the `please-grant.sh` mint grammar as the second registration point
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` - grant-check pair
  for `stash_revert` (mint/consume-once, then blocked-again)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` green, including
  the new grant pair and the unchanged over-staging-with-grant asymmetry case.
- `bash -n` plus `shellcheck` clean on both edited shell files.
- A direct `pg_grant_mint stash_revert local <ref> 0 <sha> ...` call succeeds (proving the
  `PG_ACTION_CLASSES` registration from Phase 4 took effect) and a mint for an unregistered
  sentinel name still fails closed.
- `grep -n "stash_revert" ` across the source store shows the class present in exactly the
  expected places: the guard detector, `PG_ACTION_CLASSES`, the `please-grant.sh` arm, and the
  tests — no stray occurrence.
- No task-number reference in any edited file.

---

### Phase 6: Redeploy and Final Gate Set [NOT STARTED]

**Goal**: Regenerate the deploy from the source store (never a hand-edit of `.claude/**`) and
leave the full gate set green, with every acceptance criterion checked off against evidence.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (default non-destructive
      resync mode; no `--wipe`) to regenerate `.claude/` from the source store.
- [ ] Confirm the deployed copies now match the source store: `diff` plus `md5sum` on
      `hooks/guard-destructive-git.sh`, `hooks/please-grant.sh`, `scripts/lib/push-grant-lib.sh`,
      `rules/git-workflow.md`, `context/standards/git-workflow-narrative.md`, and
      `scripts/tests/test-guard-destructive-git.sh`, source-store side vs. `.claude/` side.
- [ ] Run the guard test suite from the deployed path as well as the source-store path, confirming
      both resolve the hook correctly and both pass.
- [ ] Run `timeout 3000 bash .claude/scripts/verify-deploy.sh` in the foreground with output
      captured to a log. Triage every finding into: fixed by this task, pre-existing and
      demonstrated so (last-touch evidence from `git log` for the implicated file), or
      attributable to this task and therefore blocking.
- [ ] Walk the acceptance list and record evidence for each item: the **Not blocked** list no
      longer carries bare `git stash`/`push` and its rationale states the concurrent-writer
      hazard; the guard blocks bare, `push`, implicit-push, and `-u`/`--include-untracked` forms
      under `stash_revert`; the refusal names all three alternatives; the new class is exempted by
      the existing snapshot-marker and grant machinery with no second mechanism; the fixture was
      demonstrated red pre-change (Phase 3 output) and green post-change (Phase 4 output); Items
      7 and 8 each carry a recorded verdict and reasoning; the byte-identity re-confirmation from
      Phase 1 is recorded.
- [ ] Run the repo-wide task-reference lint (`bash .claude/scripts/check-task-references.sh`) and
      confirm zero findings attributable to this task's files.

**Timing**: 1 hour

**Depends on**: 2, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts six files were modified across Phases 1-5 and that the
deploy-drift set is exactly those six. Confirm with `git status --short` and with the per-file
`diff` list above; a seventh modified file means scope crept and must be explained, not absorbed.

**Files to modify**:
- `.claude/**` - regenerated wholesale by `deploy-headless.sh`; never hand-edited

**Verification**:
- `timeout 3000 bash .claude/scripts/verify-deploy.sh` — the complete gate set this repository
  aggregates — completes with no finding attributable to this task; every remaining finding is
  demonstrated pre-existing with last-touch evidence.
- `bash .claude/scripts/tests/test-guard-destructive-git.sh` and the source-store-path invocation
  both green.
- Per-file `diff`/`md5sum` confirms zero source-store/deploy drift for all six edited files.
- `check-task-references.sh` reports no finding in any file this task touched.
- The acceptance checklist above is recorded item-by-item with its evidence in the phase notes.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` — captured
      three times: Phase 3 baseline (pre-change, with the new cases failing), Phase 4 (green),
      Phase 5 (green with the grant pair). The Phase 3 -> Phase 4 delta is the Item 6 evidence.
- [ ] Blocked forms, each confirmed `exit 2` on a dirty tree: `git stash`, `git stash -u`,
      `git stash --include-untracked`, `git stash push`, `git stash push -u`,
      `git stash push --include-untracked`, `git stash push --` (empty separator).
- [ ] Allowed forms, each confirmed `exit 0` on a dirty tree: `git stash push -- foo.txt`,
      `git stash push -u -- foo.txt bar.txt`, `git stash pop`, `git stash apply`,
      `git stash list`, `git stash show`, `git stash --help`.
- [ ] Still-blocked pre-existing forms (no regression): `git stash drop`, `git stash clear`
      (under the unchanged `stash_drop` class).
- [ ] Escape hatches, for the new class only: a fresh `.git-snapshot-marker` exempts a bare
      `git stash` once; a minted `stash_revert` grant exempts it once and is consumed; a second
      attempt blocks.
- [ ] Asymmetry preserved: a `stash_revert` grant does **not** exempt over-staging
      (`git add -A` still exits 2).
- [ ] Refusal text for a blocked bare `git stash` contains `git show HEAD:`, `git diff HEAD --`,
      and the scratchpad-copy guidance.
- [ ] `bash -n` and `shellcheck` clean on `guard-destructive-git.sh`, `please-grant.sh`,
      `push-grant-lib.sh`, and the test suite.
- [ ] `timeout 3000 bash .claude/scripts/verify-deploy.sh` green (or every finding demonstrated
      pre-existing / not attributable).
- [ ] `check-task-references.sh` clean for every file this task touched.
- [ ] Source-store/deploy byte-identity for all six edited files after the Phase 6 redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/rules/git-workflow.md` — bare `git stash`/`push` reclassified as
  forbidden on a dirty tree; rationale corrected to the concurrent-writer hazard; Item 7 and
  Item 8 verdicts recorded.
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` — incident writeup,
  extended verdict reasoning, and the `git-snapshot.sh` internal-stash residual risk.
- `agent-system/extensions/core/index-entries.json` — regenerated narrative `line_count`.
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` — `stash_revert` per-segment
  detector, class-conditional refusal naming the three alternatives, updated header/class comments.
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` — `stash_revert` appended to
  `PG_ACTION_CLASSES`; cross-reference comment to the mint grammar.
- `agent-system/extensions/core/hooks/please-grant.sh` — `stash_revert` mint arm, extended
  accepted-forms text, cross-reference comment to `PG_ACTION_CLASSES`.
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` — flipped bare-stash
  expectation, new blocked/allowed cases, `stash_revert` grant pair.
- Regenerated `.claude/**` deploy tree (produced by `deploy-headless.sh`, not hand-edited).
- Recorded Phase 3 red / Phase 4 green test output as the Item 6 demonstration evidence.

## Rollback/Contingency

Each phase commits on its own green sub-steps, so the cheapest rollback is a scoped
`git revert` of this task's commits in reverse order — the hook change (Phase 4/5) first, since
it is the only change with repo-wide blast radius: a false-positive in the new detector would
block every agent's `git stash`-shaped command, and reverting that one commit restores the prior
guard behavior immediately while the rule and narrative text stay corrected (an undocumented
divergence in the safe direction: the rule is stricter than the enforcement, which is exactly the
pre-task state).

If a working-tree rollback of uncommitted work is genuinely required mid-phase, use the
snapshot-then-rollback recipe in `context/contracts/recovery.md`'s rollback rung for the exact
invocation shape, including its out-of-scope override flag — not a bare precautionary
`git-snapshot.sh` call. For an ordinary defensive checkpoint before the Phase 4 hook edit, use
`bash .claude/scripts/git-snapshot.sh <task-number> --no-revert`, which is durable without
reverting the tree (see `context/patterns/checkpoint-before-overflow.md`).

Note the self-referential hazard: this task's own Phase 4 change blocks bare `git stash`, and
`git-snapshot.sh`'s default mode uses `git stash push -u` internally. That internal call is
subprocess-invisible to the hook and therefore unaffected — but an implementer who reaches for a
bare `git stash` by hand after Phase 4 lands will be blocked by their own change. Use
`git show HEAD:<path>` / `git diff HEAD -- <path>` / a scratchpad copy instead, which is precisely
the guidance the new refusal message exists to give.

If the Phase 1 byte-identity check fails, stop before any edit: the coverage-gap premise no
longer holds and the ordering assumptions need revisiting with the user rather than working
around a possibly-stale deploy.
