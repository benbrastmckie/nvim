# Implementation Plan: Task #659

- **Task**: 659 - Never demote on an ignored-specs skip
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: Task 658 (completed) supplies `scripts/lib/specs-ignore-lib.sh`'s predicate and `git-commit-scoped.sh`'s V13 exit-code split (8/9); this plan builds on both and must not re-implement either
- **Research Inputs**: specs/659_never_demote_on_ignored_specs_skip/reports/01_never-demote-ignored-specs-skip.md
- **Artifacts**: plans/01_never-demote-ignored-specs-skip.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The headline demotion defect this task was filed for is already closed in the source store: the
exit-8/9 V13 arm and the `2|3|4|5`-only demotion gate both exist and were re-measured live during
planning. What remains open is the other half of the dispatch's goal — the skip currently leaves
**no durable trace at all** (only a transient stderr `NOTE:`), and the git-history readers have no
written, discoverable answer for a repository with no specs history. This plan therefore adds the
two recording channels the dispatch names (task-local `issue-record.sh` where a task context
exists, `events-append.sh` where none does), corrects one adjacent misleading "commit failed"
wording on the completion path, adds the required negative-control test pair, and lands a durable
per-reader answer register — without touching the working non-demotion exclusion.

### Research Integration

The research report's five load-bearing findings drive this plan directly and were each
re-verified at plan time against the live source store:

- The non-demotion exclusion is correct and documented — `scripts/orchestrate-cycle-postflight.sh`
  lines 2141-2155 (the `8|9)` NOTE arm) and lines 2163-2226 (the demotion gate, whose only
  demoting arm is `2|3|4|5`, with `*) : ;;` covering 1, 6, 8, 9 and any unrecognized code).
  **No phase in this plan edits that exclusion's logic.**
- The genuine gap is recording: `context/standards/git-staging-scope.md:1022` still states
  verbatim "No `issue-record.sh` entry is fired for this arm — these are not issues."
- A working per-task dedup precedent already exists in the same script
  (`partial_blocker_identity` / `partial_matched_entry_id`, lines 1545-1562: a hashed identity in
  `tags`, looked up in `issues.jsonl` before writing). Phase 1 reuses that exact shape.
- `issue-log.md`'s severity scale reserves `none` for `kind: "win"` (line 119), so a zero-cost
  `kind: issue` entry has no exact rung; `minor` is the closest and is used deliberately rather
  than widening a shared closed scale.
- Three of the six originally-named history readers issue no git read whatsoever, and two of the
  remaining three already degrade correctly. Their answers are **stated, not coded** (Phase 6).

### Carried-Figure Re-Validation (plan-time, 2026-11-19)

Every extracted premise line from the dispatch's Premise Re-Validation block, checked against
live state:

| Dispatch line | Verdict |
|---------------|---------|
| Source store is the edit target (`agent-system/extensions/core/**`) | **CONFIRMED.** `.claude-extensions.json` resolves core's `source_dir` to `/home/benjamin/.config/nvim/agent-system/extensions/core`. All edit targets below are source-store paths; redeploy is Phase 7. |
| GOAL: stop a completed task being recorded as partial | **PARTLY STALE.** The demotion-exclusion half is already implemented (see above). The "defined answer for an absent specs history" and "skip must leave a trace" halves are genuinely open and are what this plan delivers. |
| THE DEMOTION SITE, measured 2026-11-19: the demotion "fires on every completing dispatch" | **STALE as a present-tense claim.** The correction rewrites `completed` -> `partial` only for `commit_rc` in `2|3|4|5`; exit 8/9 reach a dedicated NOTE arm and the `*) : ;;` non-demoting catch-all. The symptom's description of the sapience-app observation remains an accurate account of the pre-658 behaviour. |
| HOW A SKIP IS REPORTED (visible, never silent, never status-bearing) | **CONFIRMED as the open gap.** Both V13 sites (`git-commit-scoped.sh:871/914/1358` and `orchestrate-cycle-postflight.sh:2151/2153`) only `echo` to stderr; nothing reads `ignored_dropped` to produce a durable record. |
| SHARED TERRITORY: task 501 also edits `orchestrate-cycle-postflight.sh` | **CONFIRMED and WIDER than stated.** Task 501's declared `file_scope` in `specs/state.json` is a complete superset of this plan's own scope (postflight + its suite + `git-staging-scope.md` + `git-commit-scoped.sh` + its suite). 501 is `not_started`, so no live contention exists now. The two must never be co-admitted into one batch. |
| MEASURED SCOPE CORRECTION's three remaining items | **CONFIRMED.** (1) `validate-state.sh` emits two explicit `log_warn` lines at 1529-1530 for an absent history — already a defined, non-silent WARN-level skip, not a silent zero, so no code change. (2) `dispatch-metrics.sh`'s churn split (lines 315-327) leaves pre-initialized zeros — zero is the honest answer, verdict only. (3) `init-specs.sh` is task 660's declared `file_scope`; untouched here. |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included and `specs/ROADMAP.md` is not read or written by this plan.

### Domain Plan-Authoring Gotchas

The deployed context index (`.claude/context/index.json`, 309 entries) was queried for a
`project/**` entry whose `load_when.task_types[]` contains `meta` and whose keywords/topics name
`plan-authoring`. **Zero hits** (the only such entry, `project/lean4/patterns/plan-authoring-gate-collisions.md`,
is scoped to `task_types: ["lean4"]`). This is the normal case for `meta`, not an error.

## Goals & Non-Goals

**Goals**:

- A V13 skip (exit 8 or 9) leaves a durable, discoverable record through the channel the dispatch
  names for that call site's context: `issue-record.sh` where a task context exists,
  `events-append.sh` where none does.
- That record is written at most once per `/orchestrate` invocation per task, not once per cycle,
  so a wholly-ignored-specs repository does not accumulate one entry per completing cycle.
- The record is never fatal, never status-bearing, and never routed to an automatic follow-up.
- Every git-history reader named by the dispatch has a written, discoverable answer for a
  repository with no specs history — coded where a change is needed, stated with a line citation
  where the existing behaviour is already correct.
- The dispatch's negative-control pair is automated: an authentic ignored-specs fixture completes
  with `completed` and no `STATUS DEMOTED`; the same fixture with a genuinely failing commit still
  demotes.

**Non-Goals**:

- Re-implementing, "hardening", or otherwise editing the non-demotion exclusion's own logic. It is
  correct; the only change to that arm is the addition of the recording call inside it.
- Widening `issue-log.md`'s closed severity scale, or promoting a new class into its 17-class seed
  enum. `class` is already open by design.
- Touching `scripts/init-specs.sh` (task 660's scope), `reconcile-task-status.sh`,
  `task-lock.sh`, or `lib/territory-contention-lib.sh` (no git read exists in any of the three).
- Changing `validate-state.sh` or `dispatch-metrics.sh` behaviour. Both already degrade correctly;
  their answers are stated, not coded.
- Any `git push`, PR, or `/merge` operation.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An unconditional record floods `issues.jsonl` — every completing cycle hits exit 8 in a wholly-ignored repo | M | H | Phase 1's dedup is mandatory, not optional: a session-keyed identity in `tags`, looked up in `issues.jsonl` before writing, mirroring lines 1545-1562's proven shape |
| The new record is mistaken downstream for a real defect needing follow-up | M | M | `--resolution fixed_inline`, no `--suggested-channel` (a missing hint is absorbed, never defaulted), and `--what-happened` text stating plainly that this is the repository's own configuration |
| Double-recording the same skip across two channels | L | M | `git-commit-scoped.sh`'s `events-append.sh` call fires only when `--task` is absent — exactly the callers that have no task context. The postflight caller passes `--task` (line 2111), so the two channels are structurally disjoint |
| `events-append.sh` resolves its own `PROJECT_ROOT` from `SCRIPT_DIR` (line 148), not from the committed repository | L | L | For every ordinary caller the two coincide. For the cross-repository caller (`commit-source-store-path.sh`) the event lands in the invoking repository's event log, which is the honest home for it; Phase 6 states this explicitly rather than adding a second root-resolution path |
| Phase 2's new call is unreachable in a fixture whose sandbox omits `events-append.sh` | M | M | The call must be best-effort and non-fatal (absent script, guard refusal, or nonzero exit can never change `git-commit-scoped.sh`'s own exit code); Phase 5's fixture builder copies `events-append.sh` and its hard dependencies into the fixture's `.claude/scripts/` |
| Total territory overlap with task 501 (superset `file_scope`) | H | L (501 is `not_started`) | Never co-admit 501 and 659 into one batch; re-read every edited file immediately before editing, and stage only this task's own hunks |
| `index-entries.json`'s `line_count` for a new or edited context file drifts, tripping `check-extension-docs.sh` (whose `INDEX_TRUTH_GATE_MODE` defaults to `hard`, not advisory) | M | M | Phase 6 hand-writes the new entry and declares the file; Phase 7's `deploy-headless.sh` default run performs the `generate-context-line-counts.sh` reconciliation (that generator refuses to run from the source-store `scripts/` directory and must be invoked from a deployed tree) |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4, 5 | 1 (phase 4), 2 (phase 5) |
| 3 | 6 | 1, 2, 3 |
| 4 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Record the skip at the postflight V13 arm [COMPLETED]

**Goal**: A V13 skip on a dispatch that has a task context writes exactly one durable
`issues.jsonl` entry per `/orchestrate` invocation, with the task's status and the verdict JSON
left exactly as they are today.

**Tasks**:

- [x] Re-read `scripts/orchestrate-cycle-postflight.sh` lines 2141-2160 (the `8|9)` arm) and lines
      1540-1600 (the dedup precedent) immediately before editing. *(completed)*
- [x] Inside the existing `8|9)` arm, after its two `echo ... NOTE:` lines and before the arm's
      `;;`, add the recording block. Keep both `NOTE:` lines byte-identical — the stderr surface
      is additive, never replaced. *(completed)*
- [x] Compute a dedup identity that is stable across every cycle of one invocation and distinct
      per repository-configuration shape: `sha256sum` of `"${session_id}|v13-skip|${commit_rc}"`,
      truncated to 16 hex characters exactly as line 1547 does, stored under a dedicated
      `tags` key (`tags.v13_skip_identity`) via `--tags-json`. *(completed)*
- [x] Look the identity up in `"$TASK_DIR/issues.jsonl"` before writing, with
      `jq -r 'select((.tags.v13_skip_identity // "") == $id) | .entry_id' ... | tail -n 1`.
      **Do not filter on `.resolution == "open"`** — this entry is written with
      `--resolution fixed_inline`, so an `open`-filtered lookup would never match its own prior
      write and the dedup would silently never fire. *(completed)*
- [x] On a match, print one diagnostic line naming the matched `entry_id` and skip the write
      (mirroring line 1562's wording shape). On no match, invoke `issue-record.sh` with:
      `--task-dir "$TASK_DIR"`, `--kind issue`, `--class "repository configuration"`,
      `--severity minor`, `--phase "$phase"`, `--resolution fixed_inline`, `--session "$session_id"`,
      the `--dispatch-seq` flag when `dispatch_seq_flag` is non-empty, the `--tags-json` identity,
      and **no** `--suggested-channel`. *(completed)*
- [x] Write `--what-happened` text that names the exit code, the task, and that this is the
      target repository's own `.gitignore` configuration rather than a defect — reusing the
      existing `NOTE:` prose so the two surfaces cannot drift into disagreement. *(completed)*
- [x] Record, as a comment immediately above the call, why `--severity minor` is used although
      the skip costs nothing: `issue-log.md`'s `none` rung is reserved for `kind: "win"` entries,
      and recording a routine repository-configuration fact as a win would be a worse fit than
      rounding the severity down to the lowest issue rung. *(completed)*
- [x] Use the documented non-fatal invocation form (`>/dev/null 2>&1 || echo "Note: issue
      recording failed (non-fatal)" >&2`) so a recording failure can never fail the dispatch. *(completed)*
- [x] Confirm by reading the diff that nothing outside the `8|9)` arm changed — in particular that
      the `case "$commit_rc" in 2|3|4|5)` demotion gate and `commit_attribution_note` are
      untouched. *(completed: confirmed via git diff --stat / hunk count = 1)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_lib.sh`'s own selection for this touched path is the
covering check — `test-orchestrate-cycle-postflight.sh` (which drives the real call graph for
this script in a real-git sandbox) plus `test-corroborate-phase-counts.sh`,
`test-deploy-baseline-lib.sh`, `test-force-phases.sh`, `test-gate-out-derived-staleness.sh`,
`test-git-commit-scoped.sh`, `test-handoff-dispatch-identity.sh`,
`test-handoff-reader-parity.sh`, `test-lint-deliberate-break-residue.sh`,
`test-lint-json-channel-discipline.sh`, `test-orchestrate-context-growth.sh`,
`test-orchestrate-cycle-plan.sh`, `test-orchestrate-recover-message-findings.sh`,
`test-run-task-observers.sh`, `test-sapience-mcp-registration.sh`,
`test-skill-base-lifecycle.sh`, `test-stall-reprompt-wiring.sh`.

**Scope Hypothesis**: the edit is confined to one `case` arm at lines 2141-2155 and adds no new
collaborator beyond `issue-record.sh`, which this script already invokes at two other sites.
Confirm at implementation time by re-reading those lines before editing and by checking the diff
touches exactly one hunk.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - add the deduped
  `issue-record.sh` call inside the existing `8|9)` arm; change nothing else

**Verification**:

- [x] `bash -n` and `shellcheck` on the edited script report no new finding. *(completed)*
- [x] `bash scripts/tests/run-all.sh --only <the selected set named in the Tier Justification>`
      exits 0, with the existing cases 980/981/985/986 still green (the postflight suite's
      source-store byte-identity checksum assertion must also still pass). Derive the `--only`
      list from `suite_selection_select` for this phase's touched path rather than hand-picking
      it, and check the command's exit status. *(completed: 17 passed, 0 failed)*
- [x] `git diff` on the file shows exactly one added hunk, inside the `8|9)` arm. *(completed: confirmed, 1 hunk)*

---

### Phase 2: Record the no-task-context skip from git-commit-scoped.sh [COMPLETED]

**Goal**: A V13 drop in a caller that supplies no `--task` leaves a durable `specs/events.jsonl`
line, so the roadmap-regeneration commit and the other task-context-free callers stop swallowing
the skip into an undifferentiated warning.

**Tasks**:

- [x] Re-read `scripts/git-commit-scoped.sh` lines 740-770 (the `ignored_dropped` ledger and the
      guarded `source` of `specs-ignore-lib.sh`), 906-915 (the exit-8 gate), and 1350-1359 (the
      exit-9 gate) immediately before editing. *(completed)*
- [x] Add one shared, local helper (defined once near the `ignored_dropped` ledger) that emits the
      event: it fires only when `contention_task_number` is empty (no `--task`), and invokes
      `${SCRIPT_DIR}/events-append.sh` with `--event-type ignored_pathspec_skip`,
      `--category deviation`, `--session "$session_id"`, a one-line `--message` naming the exit
      code and that this is the repository's own ignore configuration, and a `--detail-json`
      carrying the exit code and the dropped paths. *(completed: `v13_record_skip_event`)*
- [x] Use `--category deviation` and never `blocker`: `events-append.sh` promotes only a `blocker`
      line to the cross-repo central log, and a benign repository-configuration fact must never
      reach it. Record this reason as a comment at the call site. *(completed)*
- [x] Make the call unconditionally best-effort: redirect its stdout, swallow its exit code, and
      guard on the script existing, so an absent `events-append.sh`, a `deploy-root-guard.sh`
      refusal, or any nonzero exit leaves `git-commit-scoped.sh`'s own exit code and stdout
      contract (exits 0-9, the commit summary on stdout) byte-identical. *(completed)*
- [x] Call the helper immediately before `exit 8` (line 915) and immediately before `exit 9`
      (line 1359), after each site's existing `NOTE:` echo. Keep both `NOTE:` lines unchanged.
      *(completed)*
- [x] Extend the header's exit-code commentary for 8 and 9 with one sentence each stating that a
      no-`--task` invocation also appends an `events.jsonl` deviation line, and that a
      `--task`-bearing invocation deliberately does not (its caller owns the task-local record).
      *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_lib.sh`'s own selection for this touched path is the
covering check — `test-git-commit-scoped.sh` (whose AA1-AA7 cases exercise the V13 gates end to
end against authentic ignored-specs fixtures) plus `test-claude-refresh-matcher.sh`,
`test-commit-source-store-path.sh`, `test-generate-task-order.sh`, `test-git-commit-phase.sh`,
`test-guard-destructive-git.sh`, `test-guard-git-push.sh`, `test-handoff-dispatch-identity.sh`,
`test-lint-directory-pathspec-boundary.sh`, `test-lint-scoped-commit-boundary.sh`,
`test-orchestrate-conclusion-aggregate.sh`, `test-orchestrate-conclusion-roadmap.sh`,
`test-orchestrate-context-growth.sh`, `test-orchestrate-cycle-plan.sh`,
`test-orchestrate-cycle-postflight.sh`, `test-orchestrate-record-decision.sh`,
`test-orchestrate-recover-message-findings.sh`, `test-orchestrate-unwind-dispatch.sh`,
`test-redeploy-checkpoint-promotion.sh`.

**Scope Hypothesis**: exactly two `exit` sites (lines 915 and 1359) plus one helper definition and
one header-comment edit; no change to the `ignored_dropped` ledger's contents or to any other exit
code's path. Confirm by re-reading those lines and checking the diff hunk count.

**Files to modify**:

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - add the `--task`-absent-gated
  `events-append.sh` helper and call it at the two V13 exit sites; extend the header's 8/9 notes

**Verification**:

- [x] `bash -n` and `shellcheck` report no new finding. *(completed)*
- [x] `bash scripts/tests/run-all.sh --only <the selected set named in the Tier Justification>`
      exits 0 with AA1-AA7 still green. Derive the `--only` list from `suite_selection_select`
      for this phase's touched path rather than hand-picking it. *(completed: 19 passed, 0 failed)*
- [x] A direct probe confirms the gate's direction: the same authentic all-ignored fixture invoked
      WITHOUT `--task` appends one `specs/events.jsonl` line and still exits 8, and invoked WITH
      `--task` appends none and still exits 8. *(completed: verified manually in an isolated sandbox fixture)*

---

### Phase 3: Stop the post-deploy reconcile commit reporting a V13 skip as a commit failure [COMPLETED]

**Goal**: The redeploy-checkpoint promotion commit — a `specs/state.json` + `TODO.md` bookkeeping
commit that runs on this repository's own completion path — describes a V13 skip as what it is
instead of printing "commit failed".

**Tasks**:

- [x] Re-read `scripts/lib/redeploy-checkpoint-lib.sh` lines 275-295 immediately before editing. *(completed)*
- [x] Capture the invocation's exit code explicitly instead of relying on the `|| echo` idiom's
      collapse, and branch: exit 0 unchanged; exit 8 or 9 print a `NOTE:`-level line naming the
      code and stating that the repository's own specs tree is wholly or partly gitignored, that
      the `completed` status is already on disk, and that this is the repository's configuration
      rather than a commit failure; every other nonzero code keeps today's warning wording
      verbatim. *(completed)*
- [x] Add no recording call here. This call site passes `--task`, so Phase 2's event channel is
      deliberately gated off, and adding a second dedup implementation for one adjacent surface is
      out of proportion. Phase 6 records this as a named residual. *(completed: no recording call added)*
- [x] Confirm the lib still returns the same value to its caller on every path — this edit changes
      wording and nothing else. *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_lib.sh`'s own selection for this touched path is the
covering check — `test-redeploy-checkpoint-promotion.sh` (which covers this lib's promotion path
directly) plus `test-force-phases.sh`, `test-orchestrate-cycle-plan.sh`,
`test-orchestrate-unwind-dispatch.sh`.

**Scope Hypothesis**: the edit is confined to the promotion commit's invocation at lines 275-295,
changing wording only and leaving the lib's return value identical on every path. Confirm by
re-reading those lines before editing and by diffing the non-8/9 warning text.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` - classify exit 8/9 at the
  promotion commit with a `NOTE:`-level wording; preserve every other code's wording verbatim

**Verification**:

- [x] `bash -n` and `shellcheck` report no new finding. *(completed)*
- [x] `bash scripts/tests/run-all.sh --only <the selected set named in the Tier Justification>`
      exits 0. *(completed: 4 passed, 0 failed)*
- [x] `git diff` shows the non-8/9 warning text unchanged, character for character. *(completed: confirmed byte-identical)*

---

### Phase 4: Negative-control test pair for the postflight arm [COMPLETED]

**Goal**: The dispatch's required pair is automated in the postflight suite: an authentic
ignored-specs fixture completes with `completed`, no `STATUS DEMOTED`, and a recorded skip; the
same fixture with a genuinely failing commit still demotes.

**Tasks**:

- [x] Re-read `scripts/tests/test-orchestrate-cycle-postflight.sh` lines 66-145 (`setup_sandbox`,
      `commit_fixture`) and 4047-4075 (`write_case98x_fixture`, `stub_git_commit_scoped`) before
      editing. *(completed)*
- [x] Add a fixture helper that makes the sandbox's specs tree genuinely gitignored: write
      `$WORKDIR/.gitignore` containing `specs/`, commit the `.gitignore` itself (the existing
      `commit_fixture` stages `specs/`, which an ignored tree refuses — the new helper must commit
      `.gitignore` on its own rather than depending on that helper's chain), then build the
      ordinary `write_case98x_fixture` state for the candidate. *(completed: `make_specs_ignored`;
      additionally had to add `specs-ignore-lib.sh` to `setup_sandbox`'s own copy list, which this
      task's fixture is the first to need for an un-stubbed run — without it `specs_ignore_lib_available`
      stays empty and the real script falls through to V7 instead of V13; not called out explicitly
      by this task list but required for the authentic case to work at all)*
- [x] Case 987 (authentic, no stub): the real `git-commit-scoped.sh` copied into the sandbox hits
      V13 and exits 8. Assert: `persisted_status` is `completed`; no `STATUS DEMOTED` line on
      stderr; the handoff's `blockers[]` stays empty; the verdict JSON's `note` is empty; a `NOTE:`
      line naming exit 8 is present; and `issues.jsonl` carries exactly one entry whose
      `tags.v13_skip_identity` is set. *(completed)*
- [x] Case 987b (dedup): re-run the SUT on the same fixture within the same session id and assert
      `issues.jsonl` still carries exactly one such entry, and that the duplicate-skip diagnostic
      line appears on stderr. *(completed)*
- [x] Case 988 (partial-ignore shape, stubbed exit 9 via the existing `stub_git_commit_scoped`
      helper): assert the same non-demotion set as 987 plus one recorded entry. Use the stub here
      because the authentic partial-ignore shape needs a negation-bearing `.gitignore` the
      postflight's own `stage_paths` derivation does not control. *(completed)*
- [x] Case 989 (the negative control's other half): the SAME authentic ignored-specs fixture, with
      `stub_git_commit_scoped 3`, must still demote — assert `persisted_status` is `partial`,
      `verdict` is `defer`, a `STATUS DEMOTED` line naming the candidate appears, and the handoff
      gained a blocker with `continuation_path` null. This is what proves the exception was
      narrowed and not removed. *(completed)*
- [x] Insert the new block after the existing case-986 `# task-ref-ok:end` marker (line 4316) and
      before the 990/991/992 derived-staleness block, and wrap it in its own
      `# task-ref-ok:begin ... # task-ref-ok:end` markers with the same category-6-adjacent
      justification the neighbouring blocks carry (the fixture numbers appear in asserted stderr
      text). *(completed)*
- [x] Keep every assertion's failure message naming the observed value, matching the suite's
      established `common_test_pass`/`common_test_fail` style. *(completed)*

**Timing**: 1 hour 15 minutes

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_lib.sh`'s own selection for this touched path is the
covering check — `test-orchestrate-cycle-postflight.sh` (the deliverable itself) plus
`test-corroborate-phase-counts.sh`, `test-handoff-dispatch-identity.sh`,
`test-lint-deliberate-break-residue.sh`, `test-orchestrate-context-growth.sh`,
`test-orchestrate-cycle-plan.sh`, `test-orchestrate-recover-message-findings.sh`,
`test-stall-reprompt-wiring.sh`.

**Scope Hypothesis**: four new cases (987, 987b, 988, 989) inserted at one point in one file, with
one new fixture helper; no existing case's assertions change. Confirm by checking that the suite's
pre-existing pass count is unchanged and only the new cases add to the total.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - add the
  ignored-specs fixture helper and cases 987/987b/988/989

**Verification**:

- [x] `bash scripts/tests/run-all.sh --only <the selected set named in the Tier Justification>`
      exits 0, with the new cases reported and every pre-existing case still green. *(completed:
      run directly first — 340 passed, 0 failed, including 987/987b/988/989 — full `--only` suite
      set run below)*
- [x] Discriminating check: temporarily revert Phase 1's recording block and confirm cases 987/988
      FAIL on the missing `issues.jsonl` entry while 989 still passes — then restore it. This
      proves the new assertions are not vacuous. *(completed: 987, 987b, and 988 FAILED on the
      missing entry; 989 still PASSED; block restored, `git diff` confirms byte-identical to the
      committed Phase 1 state)*

---

### Phase 5: Event-channel coverage in the git-commit-scoped suite [NOT STARTED]

**Goal**: Phase 2's gate direction is pinned by test, in both directions, against authentic
ignored-specs fixtures.

**Tasks**:

- [ ] Re-read `scripts/tests/test-git-commit-scoped.sh` lines 2139-2290 (the AA fixture builder,
      AA2's all-ignored case and AA3's partial-ignore case) and the `run_commit` helper at lines
      171-175 before editing.
- [ ] Extend the AA fixture builder so the fixture repository's `.claude/scripts/` also carries
      `events-append.sh` and its hard dependencies (`lib/common.sh`, `deploy-root-guard.sh`, and
      whatever `events-append.sh` sources for its central-log promotion), so the real script runs
      inside the fixture and resolves `PROJECT_ROOT` to the fixture repository rather than this
      repository.
- [ ] Case AA8: the all-ignored fixture invoked WITHOUT `--task` still exits 8, and the fixture's
      own `specs/events.jsonl` gains exactly one line whose `event_type` is the new value and
      whose `category` is `deviation`. Assert the category explicitly — this is the assertion that
      keeps a future edit from promoting the line to `blocker` and into the central log.
- [ ] Case AA9 (the negative half): the same fixture invoked WITH `--task` still exits 8 and
      appends NO `specs/events.jsonl` line, proving the channel split is structural and that the
      postflight caller cannot double-record.
- [ ] Case AA10: the partial-ignore fixture without `--task` still exits 9, its trackable siblings
      still land in HEAD (verified via `git show`, as AA3 already does, not by exit code alone),
      and one event line is appended.
- [ ] Assert in at least one case that this repository's own `specs/events.jsonl` was NOT written
      by the suite — the fixture-containment guard for a script that resolves its own store from
      `SCRIPT_DIR`.

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_lib.sh`'s own selection for this touched path is the
covering check — `test-git-commit-scoped.sh` (the deliverable itself) plus
`test-claude-refresh-matcher.sh`, `test-commit-source-store-path.sh`,
`test-generate-task-order.sh`, `test-git-commit-phase.sh`,
`test-lint-scoped-commit-boundary.sh`, `test-orchestrate-record-decision.sh`,
`test-orchestrate-unwind-dispatch.sh`.

**Scope Hypothesis**: three new cases plus a fixture-builder extension in one file; AA1-AA7 keep
their current assertions. Confirm by checking AA1-AA7's pass lines are unchanged.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - extend the AA fixture
  builder and add cases AA8/AA9/AA10

**Verification**:

- [ ] `bash scripts/tests/run-all.sh --only <the selected set named in the Tier Justification>`
      exits 0 with AA1-AA7 green.
- [ ] `git status --short` after the suite run shows no modification to this repository's own
      `specs/events.jsonl`.

---

### Phase 6: The durable stated-answer register and the V13 recording contract [NOT STARTED]

**Goal**: Every history reader the dispatch names has a written, discoverable answer for an absent
specs history, and the one documented sentence that contradicts the new recording behaviour states
the implemented contract instead.

**Tasks**:

- [ ] Create `context/standards/absent-specs-git-history.md` holding, for each reader, the stated
      answer with a file-and-line citation: `validate-state.sh`'s `--deep` artifact-loss check
      (two `log_warn` skips, lines 1529-1530 — a defined WARN-level skip, no change);
      `dispatch-metrics.sh`'s churn split (pre-initialized zeros, lines 315-327 — zero is the
      honest answer for an untracked specs tree, and the parallel `outside_specs` figure still
      reports real deliverable churn); `git-commit-scoped.sh`'s `--honest-index-rows` addendum
      (an unreadable `HEAD:specs/state.json` suppresses the addendum rather than erroring);
      `reconcile-task-status.sh`, `task-lock.sh` and `lib/territory-contention-lib.sh` (measured:
      no git-history read exists in any of the three — the only `git log` text in the third is
      prose inside an agent-facing advisory note).
- [ ] In the same file, state the recording contract the implementation now carries: the two
      channels and their gate (`issue-record.sh` where a task context exists;
      `events-append.sh`, `--category deviation`, where `--task` is absent), the chosen `class`
      literal, why `--severity minor` is used, the per-invocation dedup key, and the hard
      properties (never fatal, never status-bearing, never auto-routed to a follow-up).
- [ ] In the same file, name the residuals honestly: `git-commit-phase.sh` and
      `lib/redeploy-checkpoint-lib.sh` both pass `--task` and own no task-local record, so a V13
      skip at either site is visible on stderr (Phase 3 makes the second one's wording accurate)
      but durable only through the conclusion stage's reading of the dispatch that wrapped it; and
      `events-append.sh` resolves its store from `SCRIPT_DIR`, so a cross-repository commit's event
      lands in the invoking repository's log.
- [ ] Correct `context/standards/git-staging-scope.md`'s V13 treatment paragraph in place: replace
      the sentence "No `issue-record.sh` entry is fired for this arm — these are not issues."
      (line 1022; locate it by grepping for `these are not issues` if the line number has moved)
      with the narrower implemented claim — the arm records the skip as evidence through the
      channel its call site's context allows, deduped per invocation, never as a failure and never
      status-bearing — and add a pointer to the new standard. **If that sentence is genuinely
      absent**, do not invent a supersession: state the current V13 recording contract in that
      paragraph and note the absence in the phase's own verification output.
- [ ] State the current design only. No "previously", "no longer", "supersedes", or draft-history
      framing anywhere under `agent-system/**`, and no task-number references in either file.
- [ ] Add the new file's entry to `index-entries.json` (`entries[]`, with `path`, `domain: core`,
      `subdomain: standards`, `summary`, `keywords`, `topics`, and a `load_when` block), modelled
      on the existing `standards/git-staging-scope.md` entry's shape.

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Tier Justification**: a non-final `full` because `suite_selection_select` resolves this phase's
touched paths to `__FULL_SWEEP__` plus `test-context-reachability.sh`, `test-deploy-orphans.sh`,
`test-git-commit-phase.sh`, `test-index-entries-schema.sh`,
`test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`,
`test-roadmap-command-registration.sh`, `test-todo-move-pair-staging.sh` — the new context
markdown file maps to no suite at all (the honest sentinel case), and the cross-cutting surface no
cheaper tier covers is the context index truth gate (`check-extension-docs.sh`, whose
`INDEX_TRUTH_GATE_MODE` defaults to `hard`) together with context reachability and the
deploy-orphan check.

**Scope Hypothesis**: one new context file, one in-place sentence correction in
`git-staging-scope.md`, and one new `index-entries.json` entry. The `line_count` field for the new
entry cannot be hand-computed reliably and is reconciled by Phase 7's redeploy; confirm at
implementation time that `git-staging-scope.md`'s own `line_count` is also re-reconciled there if
the correction changes its line total.

**Files to modify**:

- `agent-system/extensions/core/context/standards/absent-specs-git-history.md` - new: the
  per-reader stated answers, the recording contract, and the named residuals
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - correct the V13
  treatment paragraph's recording sentence in place and point to the new standard
- `agent-system/extensions/core/index-entries.json` - register the new context file (coupled
  generated surface: its `line_count` values are derived from the two files above and are
  reconciled by Phase 7's deploy run, which is not commit-blocking)

**Verification**:

- [ ] `bash scripts/lint/check-record-versioning.sh` (or the repo-wide equivalent) reports no
      finding on either file.
- [ ] `bash scripts/check-task-references.sh` reports no finding on either file.
- [ ] `jq -e '.entries | map(select(.path == "standards/absent-specs-git-history.md")) | length == 1'
      index-entries.json` succeeds.
- [ ] `grep -n "these are not issues" context/standards/git-staging-scope.md` returns nothing, and
      the paragraph's new text names both channels.
- [ ] `bash scripts/tests/run-all.sh --only <the selected set named in the Tier Justification>`
      exits 0, and `bash .claude/scripts/check-extension-docs.sh` exits 0 against the deployed
      tree (run after Phase 7's deploy if the index `line_count` reconciliation has not yet
      happened; a pre-reconciliation drift here is expected and is not a Phase 6 failure).

---

### Phase 7: Redeploy, reconcile, and close [NOT STARTED]

**Goal**: The source-store changes are live in the deployed tree, the derived index figures are
reconciled, and the completion claim rests on a check actually run.

**Tasks**:

- [ ] Run `bash .claude/scripts/deploy-headless.sh` from the project root (its default mode also
      performs the `generate-context-line-counts.sh` reconciliation, which refuses to run from the
      source-store `scripts/` directory).
- [ ] Confirm the deployed copies of all six edited/created files match the source store, and that
      `index-entries.json`'s `line_count` values for both touched context files are now
      self-consistent.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and confirm no gate regressed.
- [ ] Run the scoped touched-path check for this task's own surfaces:
      `bash scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-git-commit-scoped.sh,test-specs-ignore-lib.sh,test-redeploy-checkpoint-promotion.sh`.
- [ ] Defer the complete gate set to the orchestration close (Move 4). Under `/orchestrate` this
      phase does NOT invoke the full battery itself; the complete set is owed once per
      orchestration invocation and is discharged there. A standalone, non-orchestrated run of this
      plan instead runs the complete set directly here.
- [ ] Record in the implementation summary the stated no-change verdicts for
      `validate-state.sh`, `dispatch-metrics.sh`, `reconcile-task-status.sh`, `task-lock.sh`, and
      `lib/territory-contention-lib.sh`, pointing at the new standard as their durable carrier.

**Timing**: 30 minutes

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase runs `deploy-headless.sh`, which regenerates the entire deployed
  tree
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciliation performed by the
  deploy run's own generator pass

**Verification**:

- [ ] `deploy-headless.sh` exits 0 and reports the expected files updated.
- [ ] `verify-deploy.sh` exits 0.
- [ ] The scoped touched-path suite selection above passes.
- [ ] The complete gate set is explicitly deferred to the orchestration close (or, standalone, run
      here and reported).

## Testing & Validation

- [ ] An authentic ignored-specs fixture drives a completing dispatch to `completed` with no
      `STATUS DEMOTED` notice (Phase 4, case 987).
- [ ] The same fixture with a genuinely failing commit still demotes to `partial` with a blocker
      and `verdict: defer` (Phase 4, case 989) — the negative control's other half.
- [ ] The skip is durably recorded, exactly once per invocation (Phase 4, cases 987 and 987b).
- [ ] The no-task-context channel fires only when `--task` is absent, with `category: deviation`
      (Phase 5, cases AA8/AA9/AA10).
- [ ] A tracked-specs repository's postflight behaviour is unchanged: cases 980/981/985/986 and
      AA1-AA7 all stay green throughout.
- [ ] Every history reader named by the dispatch has a stated answer with a line citation in
      `context/standards/absent-specs-git-history.md` (Phase 6).
- [ ] `verify-deploy.sh` passes after the redeploy (Phase 7).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (edited)
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (edited)
- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` (edited)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (edited)
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (edited)
- `agent-system/extensions/core/context/standards/absent-specs-git-history.md` (new)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (edited)
- `agent-system/extensions/core/index-entries.json` (edited)
- The regenerated deployed `.claude/**` tree (disposable, produced by Phase 7's deploy)
- `specs/659_never_demote_on_ignored_specs_skip/summaries/01_*-summary.md` (implementation summary)

## Rollback/Contingency

Every phase is a small, independent edit to one file, and each lands as its own commit, so a
revert is per-phase (`git revert <sha>`) with no cross-phase coupling to unwind. If a phase's
verification fails mid-way, the correct move is to leave the prior phases' commits in place and
mark this plan's remaining phases `[NOT STARTED]` — none of Phases 1-3 depends on another, and
Phases 4-6 are additive. Before any rollback that would discard uncommitted work, take a
`bash .claude/scripts/git-snapshot.sh 659 --no-revert` checkpoint first; use the default
(reverting) form only in a genuine rollback. If Phase 7's redeploy produces an unexpected
deployed-tree diff, re-run `deploy-headless.sh` after reverting the offending source-store commit
rather than hand-editing anything under `.claude/**`.
