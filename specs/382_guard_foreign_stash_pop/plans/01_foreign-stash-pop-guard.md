# Implementation Plan: Task #382

- **Task**: 382 - Refuse `git stash pop`/`apply` of a stash entry the session did not create
- **Status**: [NOT STARTED]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/382_guard_foreign_stash_pop/reports/01_foreign-stash-pop-guard.md`
- **Artifacts**: plans/01_foreign-stash-pop-guard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the wrong-identity stash hazard: an agent whose own `git stash push` saved nothing can
still run `git stash pop`, which succeeds and silently **drops** whatever foreign entry sits at
`stash@{0}` — a user's unrelated WIP, recoverable only via `git fsck`. The fix adds a
provenance ledger of stash commit shas this session actually created (recorded by diffing
`git stash list` across each Bash tool call, so `git-snapshot.sh`'s subprocess-invisible internal
stash is captured without special-casing it), and a new tree-state-blind predicate in
`guard-destructive-git.sh` that refuses `pop`/`apply` — bare or ref-naming — whose target sha is
not in that ledger, with `exit 2`, inspection guidance, and a `/please` grant escape hatch.
Done when the four acceptance fixtures pass, `git-snapshot.sh`'s rollback pop still passes, the
full gate set is green, and the deploy is refreshed.

### Research Integration

The research report settles the mechanism question the task description delegated to it, and
this plan adopts its four load-bearing conclusions: (1) ownership is established by **diffing
the stash-sha set across a whole Bash call**, never by pattern-matching `git stash push` command
text — text matching cannot see `git-snapshot.sh`'s internal `git stash push -u` /
`git stash create` + `store`, which is exactly the sanctioned flow that must keep working;
(2) the session key is Claude Code's native `session_id` from the hook payload, validated
`^[A-Za-z0-9_-]+$` before path use, with a per-session state file under the
`.claude/tmp/<purpose>-<session>` convention `detect-noop-bash.sh` already uses and a test-only
state-dir env override; (3) the "ask the user" fallback reuses the existing push-grant primitive
with a new action class `stash_pop_foreign` registered at the two documented wiring points;
(4) a missing/absent `session_id`, or an unreadable ledger, means **nothing is owned**
(fail-closed), diverging deliberately from `detect-noop-bash.sh`'s fail-open posture.

**One correction this plan makes to the report's placement advice.** The report proposes setting
`MATCHED=1` and feeding "the existing downstream flow unchanged". That flow is unreachable for
this hazard: `guard-destructive-git.sh:299-300` exits 0 whenever `git status --porcelain` is
empty, and the stash detector sits *after* that early exit. A foreign pop on a **clean** tree is
the most dangerous case — nothing conflicts, so the pop succeeds and the drop lands. The new
predicate must therefore be structured like the file's existing hazard-class-2 history-rewrite
predicate: tree-state-blind, placed **before** the clean-tree exemption, carrying its own grant
check and its own `exit 2`, with **no** snapshot-marker exemption (a snapshot of *our* tree does
nothing to make someone else's stash entry recoverable).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included.

## Goals & Non-Goals

**Goals**:
- `git stash pop` / `git stash apply` (bare, or naming `stash@{N}` / a sha) is refused with
  `exit 2` when the target entry's commit sha was not created by this session.
- A pop/apply of an entry this session created passes unchanged.
- `git-snapshot.sh`'s snapshot → rollback flow keeps working in both default and `--no-revert`
  modes, with no special-casing of that script anywhere in the guard.
- A human has an auditable one-shot override: `/please stash pop` / `/please stash apply` mints a
  `stash_pop_foreign` grant that the guard consumes once.
- `rules/git-workflow.md`'s "Not blocked" list and
  `context/standards/git-workflow-narrative.md`'s Item 8 verdict state the new, conditional rule.
- Fixture coverage for all three ACCEPTANCE sentences plus a fail-closed regression case.

**Non-Goals**:
- Widening ownership beyond one session (the cross-dispatch case is handled by the grant path —
  see Decisions).
- Redesigning `git-snapshot.sh`'s internal stash mechanism, or fixing the separate
  concurrent-writer `stash_revert` hazard the narrative doc already records as residual.
- Making `guard-destructive-git.sh`'s segment-splitting regexes quote-aware (a pre-existing,
  separately-scoped blind spot its own header documents).
- Any hand-edit under `.claude/**`: the source store
  (`agent-system/extensions/core/**`) is the sole edit target, redeployed at the end.

## Decisions

- **Session scope stays literal.** Ownership is keyed to one native `session_id`, exactly as the
  task description words it ("created by the same session"). A stash a `git-snapshot.sh` run
  created in an *earlier* dispatch therefore reads as foreign to a later dispatch attempting the
  documented recovery pop; that case is routed to the `/please stash pop` grant rather than
  widened into automatic ownership. Rejected alternative: deriving ownership from
  `git-snapshot.sh`'s own `git-snapshot-<task>-<ts>` stash-message convention — it would let any
  session pop any other task's snapshot entry, reintroducing a weaker form of the same
  wrong-identity hazard this task closes, in exchange for avoiding one grant prompt in a rare
  recovery path.
- **The pre-call snapshot is written by `guard-destructive-git.sh`, not by a second PreToolUse
  hook.** That hook already runs on every Bash call, so no new per-call process is added; a
  dedicated pre-hook would also have to carry a `--pre`/`--post` argument through the
  registration shape that `lint-hook-registration-paths.sh` gates.
- **Path/ownership logic lives in one shared library**
  (`scripts/lib/stash-provenance-lib.sh`), sourced by both the guard and the new PostToolUse
  hook, so the state-dir location, the env-override name, and the session-id validation cannot
  drift between the writer and the reader. This mirrors how the guard already sources
  `scripts/lib/push-grant-lib.sh` by a `$(dirname "${BASH_SOURCE[0]}")/../scripts/lib/...`
  relative path that resolves identically in source-store and deployed layouts.
- **An unresolvable target ref is not blocked** (falls through): git itself errors on a bad ref,
  and no silent data loss is possible.
- **No snapshot-marker exemption for this class.** The marker exempts hazards where a snapshot
  makes the loss recoverable; a foreign stash entry's loss is not covered by a snapshot of our
  own tree.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| False refusals of legitimate own-work pops (ledger not written: lib unreadable, no `session_id`, crash between pre and post) | M | M | Fail-closed is the intended direction; refusal message names `git stash show -p stash@{N}` for inspection and the `/please stash pop` grant, so the operator is never stuck. Phase 4 fixture asserts the no-`session_id` case refuses rather than silently allowing. |
| A sibling session creates a stash *inside* our call window and is recorded as ours | M | L | Accepted residual: the window is one tool call, and the fail-direction argument holds — a mis-recorded sha leaves us no worse than today's unconditional permit, never worse. Recorded in the narrative doc update (Phase 5). |
| Per-call `git stash list` cost on every Bash call | L | H | Same cost class as the guard's existing per-call `git status --porcelain`; `git stash list` is O(entries) and typically empty. |
| Guard regression blocks all agent git work in every consumer repo | H | L | Phase 3 declares `interface` tier with the four collaborator suites named and run; Phase 6 re-runs the full gate set; the existing 691-line fixture suite already covers every other detector in the file. |
| Deployed tree already stale for `core` (this dispatch's `<deploy-freshness-context>`) so a hand-check against `.claude/**` reads stale logic | M | M | All reads and edits target the source store; Phase 6 redeploys with the bounded-wait idiom before the final gate run. |
| `stash_pop_foreign` not registered in `PG_ACTION_CLASSES` when the guard first consumes it (`pg_grant_mint`/`verify` fail closed on an unregistered name) | M | M | Phase 2 (registration) is a wave-1 dependency of Phase 3 (consumption), explicit in the wave table. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4, 5 | 3 |
| 4 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Stash-provenance ledger (library, PostToolUse hook, registration, manifest) [NOT STARTED]

**Goal**: Record, per session, the commit shas of stash entries this session created — by
diffing `git stash list --format=%H` across each Bash tool call — and expose a single
ownership-query entry point for the guard to consume in Phase 3.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/lib/stash-provenance-lib.sh`, dependency-free
      (never sources `common.sh`), providing: `sp_session_valid <sid>` (the
      `^[A-Za-z0-9_-]+$` check, copied from `hooks/detect-noop-bash.sh:244`);
      `sp_state_dir` (`${STASH_PROVENANCE_STATE_DIR:-<lib dir>/../../tmp}`, mirroring
      `detect-noop-bash.sh:249`'s `NOOP_BASH_STATE_DIR` convention so tests never write into the
      source store's own `tmp/`); `sp_pre_file <sid>` / `sp_owned_file <sid>`
      (`stash-pre-<sid>` / `stash-owned-<sid>`); `sp_snapshot_pre <sid>` (write current
      `git stash list --format=%H`, best-effort, never fails the caller);
      `sp_record_new_owned <sid>` (append each current sha absent from the pre file, guarded by
      `grep -qxF`); `sp_is_owned <sid> <sha>` (`grep -qxF`, returns non-zero on any
      missing/unreadable file — fail-closed).
- [ ] Create `agent-system/extensions/core/hooks/record-stash-provenance.sh`: PostToolUse hook,
      reads stdin, extracts `.tool_name` and `.session_id`, no-ops unless `tool_name` is `Bash`
      and the session id validates, sources the lib by the
      `$(dirname "${BASH_SOURCE[0]}")/../scripts/lib/stash-provenance-lib.sh` relative path, calls
      `sp_record_new_owned`, emits `{}` on stdout. Header comment states the fail-closed
      divergence from `detect-noop-bash.sh`'s fail-open posture and why.
- [ ] Register the hook in `agent-system/extensions/core/merge-sources/settings-hooks.json`'s
      `hooks.PostToolUse` `"Bash"` matcher array, alongside the existing `detect-noop-bash.sh`
      entry and in the identical
      `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/record-stash-provenance.sh 2>/dev/null || echo '{}'`
      shape (the anchor shape `scripts/lint/lint-hook-registration-paths.sh` accepts).
- [ ] Add all three new files to `agent-system/extensions/core/manifest.json`:
      `lib/stash-provenance-lib.sh` to the scripts list (near `lib/push-grant-lib.sh`),
      `record-stash-provenance.sh` to the `hooks` list (alphabetically, after `please-grant.sh`),
      and `tests/test-record-stash-provenance.sh` to the tests list.
- [ ] Create `agent-system/extensions/core/scripts/tests/test-record-stash-provenance.sh`
      following the suite convention in `context/standards/shell-script-testing.md`
      (`pass()`/`fail()`/`info()`, integer counters, `mktemp -d` + `trap EXIT`, exit 0/1),
      asserting: a call that creates a new stash appends exactly one line; a call that creates
      none (including the "push saved nothing" shape) appends nothing; a missing/unreadable pre
      file records nothing new rather than claiming everything present; an invalid or absent
      `session_id` is a no-op; `sp_is_owned` returns non-zero for an unknown sha.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-stash-provenance.sh,test-manifest-scripts-sync.sh,test-lint-hook-registration-paths.sh,test-deploy-propagation.sh`
covers the new lib's exported functions through their only consumer in this phase plus the
registration-shape and manifest-declaration surfaces the three other suites own.

**Scope Hypothesis**: This phase asserts exactly three new files plus two registry edits
(`settings-hooks.json`, `manifest.json`), carried from the research report's recommendations 1-2
and re-derived at plan-authoring time by reading `merge-sources/settings-hooks.json`'s
`hooks.PostToolUse` array and `manifest.json`'s hooks/scripts/tests lists directly. Confirm at
implementation time by re-reading both registry files immediately before editing (a sibling task
may have touched `manifest.json`) and by `run-all.sh --only test-manifest-scripts-sync.sh` after.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/stash-provenance-lib.sh` - new: path resolution,
  session validation, pre-snapshot, diff-and-record, ownership query
- `agent-system/extensions/core/hooks/record-stash-provenance.sh` - new: PostToolUse Bash hook
- `agent-system/extensions/core/scripts/tests/test-record-stash-provenance.sh` - new: unit suite
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - register the new hook on the
  existing PostToolUse `Bash` matcher
- `agent-system/extensions/core/manifest.json` - declare the lib, hook, and test files

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-stash-provenance.sh,test-manifest-scripts-sync.sh,test-lint-hook-registration-paths.sh,test-deploy-propagation.sh`
  exits 0 (exit status checked, not only output inspected).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` reports no new findings for
  the two new scripts, and its own exit status is 0.
- `jq -e '.hooks.PostToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.command|test("record-stash-provenance"))' agent-system/extensions/core/merge-sources/settings-hooks.json`
  succeeds.

---

### Phase 2: Register the `stash_pop_foreign` grant class [NOT STARTED]

**Goal**: Make `stash_pop_foreign` a mintable, verifiable action class at both documented wiring
points, so Phase 3's guard can consume a grant and `/please stash pop` can mint one.

**Tasks**:
- [ ] Add `stash_pop_foreign` to `PG_ACTION_CLASSES` in
      `agent-system/extensions/core/scripts/lib/push-grant-lib.sh:78`.
- [ ] Add a destructive-form arm to `agent-system/extensions/core/hooks/please-grant.sh`'s
      `case "$TEXT"` block (lines ~151-170) accepting
      `"git stash pop"|"stash pop"|"git stash apply"|"stash apply"` and setting
      `ACTION_CLASS="stash_pop_foreign"`, mirroring the existing `stash_drop` / `stash_revert`
      arms exactly (the shared `REMOTE="local"` / `REF=<branch or HEAD>` / `FORCE="0"` sentinel
      block below the case already applies).
- [ ] Extend that file's accepted-forms error text (line ~186) with the new forms.
- [ ] Update `agent-system/extensions/core/commands/please.md`'s destructive-forms list (line
      ~57) to include `git stash pop`/`git stash apply`.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-please-grant.sh,test-guard-git-push.sh,test-guard-destructive-git.sh`
covers the mint path and both existing consumers of `PG_ACTION_CLASSES`, which are the complete
one-hop dependent set of the class-list string this phase edits.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - add the class name to
  `PG_ACTION_CLASSES`
- `agent-system/extensions/core/hooks/please-grant.sh` - new mint arm + accepted-forms text
- `agent-system/extensions/core/commands/please.md` - document the new accepted forms

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-please-grant.sh,test-guard-git-push.sh,test-guard-destructive-git.sh`
  exits 0.
- A direct mint/verify smoke in a throwaway fixture repo with `PUSH_GRANT_DIR` pointed at a temp
  dir: minting `stash_pop_foreign` succeeds and `pg_grant_verify` accepts it (confirming the name
  is no longer rejected by the fail-closed validation).

---

### Phase 3: Tree-state-blind foreign-pop predicate in `guard-destructive-git.sh` [NOT STARTED]

**Goal**: Refuse `git stash pop`/`apply` whose target sha is not session-owned, on a clean tree
exactly as on a dirty one, with a grant escape hatch and no snapshot-marker exemption.

**Tasks**:
- [ ] Add the pre-call snapshot: immediately after `COMMAND` extraction and **before** the
      empty-`COMMAND` early exit (`hooks/guard-destructive-git.sh:127-133`), read
      `.session_id` from `$INPUT`, and when it validates, source
      `scripts/lib/stash-provenance-lib.sh` and call `sp_snapshot_pre` — entirely best-effort
      (`|| true` posture; `set -euo pipefail` is in effect) so no failure can break the guard.
- [ ] Add a new hazard-class-3 predicate **before** the clean-tree early exit at line 299,
      structurally modelled on the hazard-class-2 history-rewrite predicate that already sits
      there: extract `git stash` segments from `$COMMAND_SCAN` with the file's established
      per-segment idiom, resolve the subcommand with the existing per-token walk (skipping
      flags, honouring `-h`/`--help` fall-through), and act only on `pop`/`apply`.
- [ ] For a `pop`/`apply` segment: pick the target ref as the first non-flag token after the
      subcommand (skipping `-q`/`--quiet`/`--index` and any other flag), defaulting to
      `stash@{0}` when none is given; resolve it with
      `git rev-parse --verify --quiet "<ref>^{commit}"`. Unresolvable → fall through unblocked.
      Resolvable and `sp_is_owned` → fall through unblocked. Resolvable and not owned → refuse.
- [ ] On refusal: run the grant check inline (source `scripts/lib/push-grant-lib.sh`,
      `pg_grant_consume "stash_pop_foreign" "local" "$GRANT_REF" "0" "guard-destructive-git.sh"`
      with the same `GRANT_REF` derivation the downstream block at lines 566-577 uses) and
      `exit 0` on a match; otherwise `exit 2` with its own stderr block naming: the hazard (this
      entry was created by another session or by the user, and `pop` drops it on success);
      `git stash show -p stash@{N}` to inspect first; `git fsck --unreachable` as the only
      recovery once an entry is dropped; and `/please stash pop` / `/please stash apply` as the
      sanctioned way to authorize it. State explicitly that no snapshot marker exempts this
      class and why.
- [ ] Update the file's top-of-file header (the two-hazard-class narrative at lines 2-18) to a
      three-class narrative, and the "Predicate-composition note" at lines 20-26 plus the grant
      block's own class enumeration at lines 557-564, so the class list and ordering stay
      accurate.
- [ ] In `scripts/tests/test-guard-destructive-git.sh`: add an optional third `session_id`
      parameter to `run_hook_in` (threaded into the `jq -n` payload as a top-level `session_id`
      only when non-empty, so all 60+ existing call sites keep working unchanged), and rewrite
      the two now-incorrect unconditional-allow assertions — `"stash_revert allow: git stash
      apply (recovery, not loss moment)"` (lines 208-209) and `"baseline: git stash pop"`
      (line 217) — into the new expected behavior, keeping the comment above them accurate about
      the Item 8 change.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-guard-destructive-git.sh,test-record-stash-provenance.sh,test-please-grant.sh,test-git-snapshot.sh`
is the complete enumerated dependent set of this one edited hook — its own 691-line fixture
suite plus the three collaborators it now sources, consumes a grant class from, and must not
break.

**Scope Hypothesis**: This phase asserts two edit sites in `guard-destructive-git.sh` (a
pre-snapshot before the line-127 empty-command exit, and a new predicate before the line-299
clean-tree exit) and exactly two now-wrong assertions in the test suite at lines 208-209 and
217 — line numbers re-derived at plan-authoring time by direct read, not carried. Confirm at
implementation time by re-reading both files immediately before editing (line numbers shift, and
a sibling task may have touched them) and by `grep -n "assert_allowed_dirty.*stash \(pop\|apply\)"`
returning exactly those two before the rewrite and nothing after.

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - pre-call snapshot; new
  tree-state-blind `pop`/`apply` ownership predicate with inline grant check and `exit 2`;
  header/class-enumeration updates
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` - `run_hook_in`
  gains an optional `session_id`; the two unconditional pop/apply allow assertions rewritten

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-guard-destructive-git.sh,test-record-stash-provenance.sh,test-please-grant.sh,test-git-snapshot.sh`
  exits 0.
- A clean-tree manual probe: in a fixture repo with a clean tree and one foreign stash entry,
  piping `{"session_id":"s1","tool_input":{"command":"git stash pop"}}` to the hook exits 2 —
  demonstrating the predicate is genuinely not behind the clean-tree exemption (the specific
  defect this phase's placement exists to avoid).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` exits 0 with no new
  findings for the edited hook.

---

### Phase 4: Acceptance fixtures [NOT STARTED]

**Goal**: Encode all three ACCEPTANCE sentences plus the fail-closed regression case as
fixtures, including a post-check that the foreign entry actually survives the refusal.

**Tasks**:
- [ ] **Owned pop passes**: in a fixture repo, with one `session_id` threaded through both calls,
      drive the hook for `git stash push -- tracked.txt` (a real non-empty diff), actually run
      that stash, invoke the provenance recorder as PostToolUse would, then drive the hook for
      `git stash pop` — expect exit 0.
- [ ] **Foreign pop/apply refused, in the exact incident shape**: seed the fixture with a
      pre-existing entry created outside the session machinery (`git -C "$repo" stash push -m
      preexisting`), then drive the hook for `git stash push -- tracked.txt` where that path is
      clean ("No local changes to save"), run the recorder, then drive the hook for
      `git stash pop` — expect exit 2. Add the same case for `git stash apply`, for
      `git stash pop stash@{0}`, and for a pop naming the entry's raw sha.
- [ ] **Refusal actually prevents the drop**: after the exit-2 assertion above, assert via
      `git stash list` that the pre-existing entry is still present — i.e. the refusal happened
      before the mutation, not after.
- [ ] **`git-snapshot.sh` rollback unaffected**: against a dirty fixture under a tracked
      `session_id`, run the real `scripts/git-snapshot.sh <task>` (not a stub — the point is its
      *internal*, subprocess-invisible stash push), run the recorder, then drive the hook for the
      exact `git stash pop <STASH_REF>` the script printed — expect exit 0. Repeat for
      `--no-revert` mode, whose `git stash create` + `store` primitive is a different code path.
- [ ] **Fail-closed regression**: the foreign-pop fixture with **no** `session_id` field in the
      payload at all (the shape every pre-existing case in the suite uses) — expect exit 2, so an
      absent session id can never read as "nothing to check against, so allow".
- [ ] **Grant escape hatch**: with a minted `stash_pop_foreign` grant
      (`PUSH_GRANT_DIR` pointed into the fixture), the foreign pop is allowed exactly once and
      the grant is consumed — mirroring the existing `stash_revert` grant pair in the same suite.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-guard-destructive-git.sh,test-git-snapshot.sh,test-record-stash-provenance.sh`
runs the edited suite together with the two suites whose scripts these fixtures drive as real
subprocesses, which is the full set of code this phase's additions touch.

**Scope Hypothesis**: This phase asserts that `git-snapshot.sh`'s printed recovery line is
`stash  -> git stash pop ${STASH_REF}` with `STASH_REF` parsed as `stash@{N}` from
`git stash list` (carried from `scripts/git-snapshot.sh:538` and `:501`, re-read at plan-authoring
time). Confirm at implementation time by capturing the script's actual stderr in the fixture and
parsing the ref out of it, rather than hard-coding `stash@{0}`.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` - the six fixture
  groups above, in a new clearly-labelled section

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-guard-destructive-git.sh,test-git-snapshot.sh,test-record-stash-provenance.sh`
  exits 0, and the new cases appear as `[PASS]` lines (not silently skipped).
- Each new BLOCK-expecting case is confirmed to fail against a stashed copy of the pre-Phase-3
  hook (a recorded RED set), so none of them passes vacuously.

---

### Phase 5: Documentation updates [NOT STARTED]

**Goal**: State the new conditional rule where the old unconditional one is documented, without
rewriting the still-correct sibling-conflict reasoning it sits beside.

**Tasks**:
- [ ] `agent-system/extensions/core/rules/git-workflow.md:140` — change the "Not blocked" list's
      `git stash pop`/`git stash apply` (permitted)" to the conditional form: permitted only for
      an entry this session created; a foreign entry is refused with `exit 2` and needs a
      `/please stash pop` grant. Add the new class to the enforcement sentence that already names
      `guard-destructive-git.sh`.
- [ ] `agent-system/extensions/core/context/standards/git-workflow-narrative.md` — add a new
      paragraph after the "Item 8 verdict, extended reasoning" paragraph (line ~140) stating the
      **wrong-identity** hazard (a pop with nothing of its own to apply still succeeds and still
      drops the top entry) and the evidence for it, leaving the existing safe-failure argument
      intact as the correct reasoning for the *sibling-conflict* hazard it was written against.
- [ ] Same file — update the "Known residual risk — `git-snapshot.sh`'s own internal stash"
      paragraph (line ~149) to record that the provenance mechanism resolves the
      subprocess-invisibility gap for session-scoped pop authorization specifically, while the
      concurrent-writer hazard that paragraph describes is unchanged and still open. Add the
      accepted in-window sibling-stash residual risk from this plan's risk table.
- [ ] `agent-system/extensions/core/context/standards/git-safety.md:158` — extend the
      destructive-class enumeration to include `stash_pop_foreign` and note its two structural
      differences from the rest of the family: tree-state-blind, and no snapshot-marker
      exemption.
- [ ] Confirm no file landing under `agent-system/**` references a task number
      (`rules/no-task-references-in-deliverables.md`): cite the incident by date and repository
      only.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for all three touched
markdown paths (no suite covers them), so per plan-format.md sub-case (b) the honest check is
`bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
together with the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/rules/git-workflow.md` - conditional "Not blocked" entry
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` - new
  wrong-identity paragraph; residual-risk paragraph updated
- `agent-system/extensions/core/context/standards/git-safety.md` - class enumeration extended

**Verification**:
- `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
  exits 0 (explicit `TARGET` named, never the bare no-argument form, which would SKIP both gates).
- Diff read-through confirming every changed hunk is prose and that the existing Item 8
  safe-failure argument is added to, not replaced.
- `bash .claude/scripts/check-task-references.sh` (or gate 4 above) reports no task-number
  reference in any touched `agent-system/**` file.

---

### Phase 6: Redeploy and full gate set [NOT STARTED]

**Goal**: Propagate the source-store changes into the deployed tree (also clearing this
dispatch's pre-existing `core`/`lean` staleness) and confirm the whole repository is green.

**Tasks**:
- [ ] Redeploy with the bounded-wait idiom: `timeout 540 bash .claude/scripts/deploy-headless.sh`
      invoked with the Bash tool's `timeout` parameter raised to 600000 (not its 120000ms
      default), per `context/patterns/external-process-wait.md` Rule 1.
- [ ] Confirm the deployed tree now carries the new hook, the new lib, and the new PostToolUse
      registration in `.claude/settings.json` — i.e. that the merge-source edit actually
      propagated, rather than inspecting only the source store.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`.
- [ ] Walk the three ACCEPTANCE sentences explicitly against the fixture results and record the
      outcome in the implementation summary.
- [ ] Record any issue or win encountered across the task via
      `bash .claude/scripts/issue-record.sh --task-dir <task_dir> --phase implement ...`.

**Timing**: 0.75 hours

**Depends on**: 4, 5

**Verification Tier**: full

**Files to modify**:
- (no source edits) deployed tree `.claude/**` is regenerated by `deploy-headless.sh`; never
  hand-patched

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set, no `--only-gate`
  filter and no `--skip-slow` (a narrowed or `--skip-slow` pass is not evidence the doc-sync pins
  hold).
- `jq -e '.hooks.PostToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.command|test("record-stash-provenance"))' .claude/settings.json`
  succeeds, and `.claude/hooks/record-stash-provenance.sh` plus
  `.claude/scripts/lib/stash-provenance-lib.sh` exist.
- A live end-to-end probe in a throwaway fixture (never this working tree): a foreign `git stash
  pop` is refused by the deployed hook with exit 2.

---

## Testing & Validation

- [ ] Pop/apply of a session-created entry passes (ACCEPTANCE 1).
- [ ] Pop/apply of a foreign entry is refused with exit 2, including the exact "push saved
      nothing, then pop" incident shape, bare and ref-naming and sha-naming forms (ACCEPTANCE 2).
- [ ] The refused foreign entry is still present in `git stash list` afterwards.
- [ ] `git-snapshot.sh` rollback flow unaffected, in both default and `--no-revert` modes
      (ACCEPTANCE 3).
- [ ] A payload with no `session_id` refuses rather than allowing (fail-closed).
- [ ] A minted `stash_pop_foreign` grant allows one foreign pop and is consumed.
- [ ] Every new BLOCK-expecting fixture is confirmed RED against the pre-change hook.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 after redeploy.
- [ ] No task-number reference in any file landing under `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/stash-provenance-lib.sh` (new)
- `agent-system/extensions/core/hooks/record-stash-provenance.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-record-stash-provenance.sh` (new)
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` (modified)
- `agent-system/extensions/core/hooks/please-grant.sh` (modified)
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` (modified)
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (modified)
- `agent-system/extensions/core/manifest.json` (modified)
- `agent-system/extensions/core/rules/git-workflow.md` (modified)
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` (modified)
- `agent-system/extensions/core/context/standards/git-safety.md` (modified)
- `agent-system/extensions/core/commands/please.md` (modified)
- Regenerated deployed tree under `.claude/**` (deploy artifact, never hand-edited)
- `specs/382_guard_foreign_stash_pop/summaries/01_*-summary.md` (implementation summary)

## Rollback/Contingency

Every phase is a separate scoped commit, so the cheapest rollback is `git revert` of the
offending commit followed by a redeploy — nothing here has a schema or state migration to undo.
Two failure modes have faster targeted mitigations:

- **The new predicate causes false refusals in practice**: comment out (or revert) only the
  new hazard-class-3 block in `guard-destructive-git.sh` and redeploy. The provenance ledger
  (Phase 1) is inert on its own — it records shas nobody reads — so it can stay.
- **The new PostToolUse hook misbehaves on every Bash call**: remove its single entry from
  `merge-sources/settings-hooks.json`'s `Bash` matcher and redeploy; the guard's pre-snapshot and
  ownership query both already fail closed on a missing ledger, which refuses pops rather than
  permitting them wrongly.

If uncommitted work must be discarded during recovery, take a snapshot first per
`context/contracts/recovery.md`'s rollback rung (including its out-of-scope override flag for the
deliberate whole-tree case) — never a bare precautionary `git-snapshot.sh {N}`.

**Concurrency note**: sibling tasks 379, 380, 381, 386, and 388 are dispatched this same cycle on
this shared working tree, and 386 declares `scripts/git-snapshot.sh` in its own `file_scope` —
the exact script Phase 4's fixtures drive as a real subprocess. Before editing or committing any
file: re-read it immediately beforehand, stage only this task's own hunks with an explicit file
list (never a directory or glob pathspec), never run `git-snapshot.sh` in its reverting default
mode, and treat an unexpected failure in a file outside this task's scope — `git-snapshot.sh`
above all — as possibly a sibling's in-flight edit. Stop and report a foreign commit or
uncommitted modification after confirming via `git log` that the work is not this task's own.
