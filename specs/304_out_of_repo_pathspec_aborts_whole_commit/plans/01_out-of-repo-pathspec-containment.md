# Implementation Plan: Task #304

- **Task**: 304 - Stop one out-of-repository pathspec entry from aborting staging for every valid
  path, and stop the live caller sinking the script's nonzero exits while the task still reports
  success
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: 184, 263, 273, 284, 285, 302 (serialization edges on
  `orchestrate-cycle-postflight.sh`; 302 is the one with live textual collision risk — see Risks)
- **Research Inputs**: specs/304_out_of_repo_pathspec_aborts_whole_commit/reports/01_out-of-repo-pathspec-containment.md
- **Artifacts**: plans/01_out-of-repo-pathspec-containment.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The fix lands as a new classification gate (**V9**) inside `git-commit-scoped.sh`'s own V2
drop pass: a positive pathspec whose resolved parent directory escapes `PROJECT_ROOT` is dropped
with a distinct loud `WARN:` and recorded in the existing `dropped_pathspecs` machinery, so the
single all-or-nothing `git add` never receives it and the remaining N valid paths commit normally.
A new exit code **6** ("a commit WAS created, and at least one pathspec was dropped as
out-of-repository") carries that violation out of stderr and into the one live caller actually
exposed to it, `orchestrate-cycle-postflight.sh`, which gains an explicit `$?` branch that records
a durable `issues.jsonl` entry and populates its own emitted-verdict `note` field instead of
collapsing every nonzero code through `|| echo WARN`. A new lint rule keeps future `.sh` callers
from re-introducing the sink, and two documentation edits settle the cross-repository-edit remit
question and the exit-code contract. The global non-blocking posture is not flipped.

### Research Integration

Research's rulings are adopted with three substantive departures, each argued below rather than
silently substituted:

Adopted as-is: fix site is candidate 1 only (D1); extend the existing `dropped_pathspecs`/V6
machinery rather than invent a parallel refusal gate (D3); decline a new cross-repository field and
instead state the remit in the format spec (D4); `orchestrate-unwind-dispatch.sh` needs no branch
because it passes only two fixed literals (D5); do not hand-edit ~50 prose snippets — add a lint
(D5); do not flip the global non-blocking policy (D6); drop-and-warn over loud refusal (D7).
Research's premise correction on task 277 (completed 2026-10-02 with the narrower V6 gate, so
Case 3 remains warn-and-drop and no ordering hazard exists) is accepted and this plan is built on
it.

**Departure 1 — the containment predicate must NOT resolve the pathspec's final component.**
Research's D2 proposes `realpath -m --relative-to="$PROJECT_ROOT" -- "$p"` on the pathspec itself.
Resolved empirically in a scratch repo during this planning pass: a leaf symlink inside the repo
whose target lies OUTSIDE the repo is a **legal** `git add` argument (`rc=0`, staged as a symlink),
while a path *through* a symlinked directory is fatal (`fatal: pathspec 'dirsym/target.txt' is
beyond a symbolic link`, rc=128). D2's leaf-resolving form classifies the legal leaf symlink as
out-of-repo and would drop it — a false-positive regression against current behavior. The
predicate therefore resolves the pathspec's **parent directory** and leaves the basename
untouched. Verified against 13 pathspec shapes (relative, `./`-prefixed, absolute-in-repo,
absolute-out-of-repo, trailing-slash directory, `..`-laundered, sibling-sharing-a-prefix
`<root>-backup`, nonexistent, leaf symlink, through-symlink): the parent-resolving form agrees
with `git add`'s own accept/reject verdict on every one.

**Departure 2 — a new exit code IS required, and research's D7 "both axes" claim does not hold
without it.** D5 argues no new code is needed because the out-of-repo drop folds into V6's exit 4.
But V6 fires only when `commit_exit` is nonzero. In the exact observed-damage shape (26 valid +
4 out-of-repo), the post-V9 outcome is exit **0** with a successful commit and four stderr WARNs —
so the caller-side branch D5 itself specifies never fires, and the violation reaches no durable
channel. That is D7's "surface the violation" axis traded away for precisely the motivating case.
Exit 6 is narrowly scoped (commit created AND ≥1 V9 drop), purely additive (the shape is
unreachable today, because today the whole `git add` dies instead), and leaves T13's rc=0
assertion for an unmatched partial drop untouched.

**Departure 3 — exit 6 is claimed here, so task 336's unfiled Containment follow-up is reserved
exit 7, not 6.** D5's last bullet reserves 6 for that follow-up. Both task 335's and task 336's
own records name THIS task as the owner of `git-commit-scoped.sh`'s exit-code contract, and 336's
follow-up specification explicitly leaves its own code "a new exit code, OR a deliberately and
explicitly reused one" open to its own research. Allocating 6 here and recording the 7 reservation
in `git-staging-scope.md` discharges that coordination constraint in the same direction, one slot
over.

**Correction to research's caller enumeration (conclusion unchanged).** Research names two live
script callers. A sweep of every non-test `.sh` naming `git-commit-scoped.sh` found a **third**:
`scripts/lib/redeploy-checkpoint-lib.sh` (sourced by `orchestrate-cycle-plan.sh`), which commits
`$STATE_FILE` plus `TODO.md` under the same `|| echo ... (non-blocking)` idiom. Like
`orchestrate-unwind-dispatch.sh` it passes only fixed literals and is never handed a
`modified_files` entry, so it is structurally unexposed to this defect and needs no branch —
but it does need an allowlist entry in Phase 5's lint, which research's two-caller enumeration
would have missed. `git-commit-phase.sh` already passes 0-5 through verbatim and is the in-repo
precedent for the Phase 4 branch shape.

**Residual this plan does NOT close, stated rather than glossed.** D5 also asks the caller to
"force the dispatch's resulting status to a non-terminal outcome" via the existing
`clamp_mode`/monotonic-max machinery. That is not implementable at this call site: `clamp_mode` is
consumed by WORK (f)'s status write at `orchestrate-cycle-postflight.sh:1137-1264`, roughly 560
lines BEFORE the commit at ~1824, and monotonic-max prevents a demotion by construction. Honoring
it would require either reordering WORK (f) and WORK (i) or introducing a post-hoc write out of the
terminal `completed` state — both larger than this task and both squarely inside the
non-blocking-policy change the dispatch says to recommend, not impose. Phase 4 therefore delivers
the visible-and-attributable half in full (a named `ERROR:`, a durable `issues.jsonl` entry the
conclusion stage aggregates, and the emitted `note`) and records the status-demotion half as a
named follow-up with its reason and its owner.

### Prior Plan Reference

No prior plan. This is round 1 for this task.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and `roadmap_flag` is absent, so no roadmap review
or update phases are added. `specs/ROADMAP.md` was consulted read-only for sequencing and records
this task at line 138 as `304 blocked:302`, with line 57 reading `/orchestrate 302, 347 # staging
lease + waiter hook; 302 unblocks 304`. That sequencing is honored as a serialization preference,
not a semantic blocker: task 302 is a different mechanism (over-broad `-- specs/` directory
pathspec) at different call sites, but it edits the same `orchestrate-cycle-postflight.sh` commit
call-site region this plan's Phase 4 touches. See Risks.

## Goals & Non-Goals

**Goals**:
- One out-of-repository pathspec entry no longer aborts staging for every valid entry in the same
  `git add`; the N valid paths are committed and the offending entry is named loudly.
- An absolute path that resolves INSIDE the repository continues to commit, unchanged.
- An in-repo leaf symlink whose target is outside the repository continues to commit, unchanged.
- The violation reaches a durable, operator-visible channel rather than stopping at stderr.
- `orchestrate-cycle-postflight.sh` stops collapsing every nonzero exit to success for its own
  control flow, without becoming able to abort a batch.
- A lint prevents a future `.sh` caller from re-introducing the exit-code sink.
- The cross-repository-edit remit and the exit-code contract are documented where a reader of
  either `git-staging-scope.md` or `return-metadata-file.md` will find them.

**Non-Goals**:
- Re-documenting the `modified_files` repo-relative constraint (already stated three times; the
  dispatch's PREMISE CORRECTION settles this).
- Propagating that constraint to the 9 silent implementation agents (the root-cause remediation;
  a separately filed follow-up, named in Phase 6).
- Adding a JSON schema for `.return-meta.json`.
- Flipping the global non-blocking-commit policy, or making any commit failure fatal.
- Editing `scripts/orchestrate-unwind-dispatch.sh` or `scripts/lib/redeploy-checkpoint-lib.sh`
  beyond a lint allowlist entry (both pass fixed literals only).
- Editing `scripts/orchestrator-postflight.sh` (confirmed orphaned, zero live invocation sites).
- Implementing task 336's `file_scope`-Containment chokepoint (reserved exit 7; its own task).
- Any edit to `agent-system/extensions/core/scripts/verify-deploy.sh` — it is currently
  uncommitted-modified by concurrent sibling work and is outside this task's scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Task 302 lands in `orchestrate-cycle-postflight.sh`'s commit call-site region first (ROADMAP sequences it ahead of this task) | M | M | Re-read the call site immediately before editing in Phase 4; stage only this task's own hunks; if 302 has landed, adapt to its shape rather than reverting it. Attribute any unexpected failure in that file to the sibling before assuming a self-inflicted regression. |
| The V9 predicate false-positives on an unusual in-repo symlink or bind-mount arrangement | H | L | Resolve `PROJECT_ROOT` through the SAME `realpath -m` call as the pathspec's parent (never compare a raw root against a resolved path); do not resolve the pathspec's final component; T16 pins the leaf-symlink case explicitly. |
| A careless V9 insertion disturbs V2 Case 2 (already-staged deletions), which shares the all-or-nothing `git add` reasoning | H | L | V9 is a guard ahead of Case 1 only; Case 2's branch text is not touched. T8/T9/T10 plus the W-series rename cases are re-run unchanged as the regression set, and Phase 2 does not close until they are green. |
| Exit 6 is misread by a caller as a failure that should halt | M | L | Documented in both the script header and `git-staging-scope.md` as "commit CREATED, paths dropped" — strictly observability. Phase 4's branch is non-fatal by construction and never touches `verdict`/`halt`. |
| The new lint's first run fails on existing `|| echo` call sites | M | M | Phase 5 runs AFTER Phase 4 fixes the one genuinely exposed caller, and adds explicitly-reasoned allowlist entries for the two fixed-literal callers plus the orphan. The lint's own both-polarity fixture test proves it would still catch a regression. |
| Two of this plan's files are outside the task's declared `file_scope`, so tasks 335/336's excursion filter would drop them from the per-cycle commit | M | M | `scripts/lint/lint-scoped-commit-boundary.sh` and `scripts/tests/test-lint-scoped-commit-boundary.sh` are declared in Phase 5's `Files to modify`, which `plan-file-scope-harvest.sh` reads to expand `file_scope`. Confirm the expansion landed (`jq` the task's `file_scope`) before Phase 5's commit, or the lint work is silently left uncommitted. |
| `verify-deploy.sh` / `deploy-headless.sh` auto-background and strand the dispatch | H | M | Every invocation in this plan carries the bounded-wait idiom verbatim: Bash tool `timeout` parameter `600000` AND an inner `timeout 540`, stdout+stderr redirected to a file and grepped. Never `run_in_background`, never a harness-notification wait. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 4 |
| 5 | 6 | 3, 5 |

Phases within the same wave can execute in parallel. Phase 6 depends transitively on every other
phase (6 -> 3 -> 2 -> 1 and 6 -> 5 -> 4 -> 2 -> 1), which is what makes its `full` gate meaningful.

---

### Phase 1: Red regression cases for the out-of-repository class [NOT STARTED]

**Goal**: Add the cases that pin the new behavior and prove, before any production edit exists,
that they FAIL against the current script — the non-vacuity evidence ACCEPTANCE item 2 demands.

**Tasks**:
- [ ] Add a `build_repo_with_outside_tree` helper to `test-git-commit-scoped.sh`, modelled on the
      existing `build_repo`: a scratch repo plus a sibling `outside/` directory holding a real file,
      both under the same `TOP_WORKDIR`. Reuse `run_commit` unchanged.
- [ ] **T14** — the core case. One absolute path into the sibling `outside/` tree mixed with three
      valid repo-relative paths. Assert: exit **6**; `git log` gained exactly one commit; all three
      valid paths are present in `git show --name-only` (assert on committed CONTENT, per ACCEPTANCE
      item 2, never exit code alone); stderr names the offending path and the word
      `out-of-repository`.
- [ ] **T15** — ACCEPTANCE item 4. An ABSOLUTE path that resolves INSIDE the repo
      (`"$repo/specs/999_probe/file.txt"`) commits exactly as today: exit 0, HEAD +1, the path in
      `git show --name-only`, no drop WARN.
- [ ] **T16** — the leaf-symlink dimension (Departure 1). An in-repo symlink whose target lies
      outside the repo is named as a positive pathspec: exit 0, HEAD +1, the symlink path present in
      the commit, NOT dropped. This case is what distinguishes the parent-resolving predicate from
      a leaf-resolving one; a leaf-resolving implementation fails it.
- [ ] **T17** — a path THROUGH an in-repo symlinked directory (`dirsym/target.txt`, which bare
      `git add` rejects with `fatal: ... is beyond a symbolic link`) is dropped as out-of-repository
      rather than aborting the call: exit 6, HEAD +1, the valid sibling path committed.
- [ ] **T18** — the degenerate case. EVERY positive pathspec is out-of-repository: the existing V3
      post-filter refusal fires (exit **2**, no `git add`, no commit, `git log` unchanged), matching
      T11's precedent for the all-dropped shape. Pins that V9 does not invent a second refusal path.
- [ ] Run the suite and record the pre-fix result in the phase's progress notes: T14/T17/T18 must
      FAIL (and T15/T16 PASS, since they encode unchanged behavior). A T14 that passes pre-fix is
      vacuous and must be rewritten before Phase 2 begins.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to one test file with no production surface, and its
covering check is `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh,test-git-commit-phase.sh,test-lint-scoped-commit-boundary.sh,test-orchestrate-unwind-dispatch.sh,test-claude-refresh-matcher.sh` — the exact set `suite_selection_select` resolves for this path.

**Scope Hypothesis**: Five new cases (T14-T18) plus one new fixture helper, and the next free
T-number is 14 (carried from the research report's recommendation 5, which named T14/T15;
re-derived at plan-authoring time by grepping the suite's own case comments — the highest existing
T-number is T13, alongside independent X1-X8 and W1-W4 series). Confirm at implementation time by
re-grepping `^# T[0-9]` before choosing numbers, in case a sibling task added a case.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - add
  `build_repo_with_outside_tree` helper and cases T14-T18

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` runs to completion
  and reports T14/T17/T18 as FAILED against the unmodified script, T15/T16 as PASSED, and T1-T13 /
  X1-X8 / W1-W4 all still PASSED.
- The recorded pre-fix failure output is captured in the phase's progress file as the non-vacuity
  evidence.

---

### Phase 2: V9 repository-containment classification and exit code 6 [NOT STARTED]

**Goal**: Land the gate. An out-of-repository positive pathspec is classified, dropped, and
reported, and a commit that survived with ≥1 such drop exits 6.

**Tasks**:
- [ ] Immediately before V2's Case 1 test (`scripts/git-commit-scoped.sh:408`), inside the
      non-`:(exclude)` arm of the classification loop, add the **Case 1b / V9** guard. Resolve the
      repository root once, before the loop, through the same canonicalizer used for the pathspec:
      `root_resolved="$(realpath -m -- "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")"`.
      Per pathspec, resolve only its PARENT:
      `p_dir_rel="$(realpath -m --relative-to="$root_resolved" -- "$(dirname -- "$p")" 2>/dev/null)" || p_dir_rel=""`
      and classify out-of-repository when `p_dir_rel` is empty, exactly `..`, or begins `../`.
      Do NOT resolve the pathspec's final component (Departure 1; T16 is the pin).
- [ ] On a V9 hit: append to BOTH `dropped_pathspecs` (so the existing V6 gate still refuses the
      all-dropped-and-nothing-committed shape as exit 4) and a new `out_of_repo_dropped` array
      (so the exit-6 decision can distinguish this class from Case 3). Add the path to NEITHER
      `add_pathspecs` NOR `filtered_pathspecs`.
- [ ] Emit a WARN textually distinct from Case 3's, naming both the path and the reason, so a
      reader of stderr can tell "never existed" from "exists, but in the wrong repository":
      `WARN: git-commit-scoped.sh dropping out-of-repository pathspec '${p}' (resolves outside ${root_resolved}); this path will NOT be part of the commit.`
- [ ] Add the exit-6 decision at the bottom of the script, AFTER the existing V8 exit-5 branch so
      V8's integrity failure keeps precedence:
      `if [ "${#out_of_repo_dropped[@]}" -gt 0 ] && [ "$commit_exit" -eq 0 ]; then exit 6; fi`,
      placed immediately before the final `exit "$commit_exit"`. Guard every array expansion behind
      its own `${#...[@]}` test, since the script runs under `set -u`.
- [ ] Update the script's own header: add a `V9` entry to the Safety-gates block (sited after V8)
      stating the predicate, the parent-resolution rule and WHY the leaf is deliberately not
      resolved; add `6` to the Exit-codes table; and extend exit `4`'s prose to note that
      `dropped_pathspecs` now carries two drop reasons.
- [ ] Re-run the suite: T14/T17/T18 flip to PASS, T15/T16 stay PASS, and T1-T13 / X1-X8 / W1-W4
      remain PASS unchanged.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The change is confined to one script with no externally visible signature
change (one additive exit code, documented), and its covering check is the full 15-suite set
`suite_selection_select` resolves for `scripts/git-commit-scoped.sh`: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh,test-git-commit-phase.sh,test-guard-destructive-git.sh,test-guard-git-push.sh,test-handoff-dispatch-identity.sh,test-lint-directory-pathspec-boundary.sh,test-lint-scoped-commit-boundary.sh,test-orchestrate-conclusion-aggregate.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-redeploy-checkpoint-promotion.sh,test-claude-refresh-matcher.sh`.

**Scope Hypothesis**: The V2 classification loop sits at `scripts/git-commit-scoped.sh:400-434`
and Case 1's predicate at line 408 (re-derived by grep at plan-authoring time; the research report
carried "around line 408" and this plan confirms it). The file is 769 lines. Confirm both figures
by re-reading the loop immediately before editing — the script has grown with V5/V7/V8 and a
sibling task may shift it again.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - V9 guard in the V2 loop, the
  `out_of_repo_dropped` array, the exit-6 decision, and the header gate/exit-code documentation

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` exits 0 with every
  case PASS (ACCEPTANCE items 1-4 and the item-3 regression set).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` reports no new finding for
  this file.
- A hand-run reproduction in a scratch repo confirms the before/after asymmetry: pre-fix, a mixed
  list aborts the whole `git add` (`fatal: ... is outside repository`, zero paths staged);
  post-fix, the valid paths are in `HEAD` and exit is 6.

---

### Phase 3: Standards and format-spec updates [NOT STARTED]

**Goal**: Record the V9 gate, the extended exit-code contract and the exit-7 reservation where a
reader of the standard will find them, and settle the cross-repository-edit remit question
(ACCEPTANCE item 5).

**Tasks**:
- [ ] In `context/standards/git-staging-scope.md`'s "Exit-Code Contract and Safety Gates": add a
      `6` row to the exit-code table ("A commit WAS created, and at least one positive pathspec was
      dropped as out-of-repository (V9). Observability, not a refusal — the valid paths are
      committed."); add a `7` row marked **RESERVED** for task 336's unfiled
      `file_scope`-Containment follow-up, naming that reservation explicitly so the two pieces of
      work cannot independently claim the same slot (Departure 3); and add the `V9` gate-label
      paragraph in the same voice as V6/V8, stating the parent-resolution predicate and why the
      final component is deliberately left unresolved.
- [ ] In the same file, amend the "Recorded caller-escalation residual" paragraph: it currently
      states that no caller branches on the exit code. After Phase 4 that is no longer true for
      `orchestrate-cycle-postflight.sh`. State the current position — which caller branches, on
      which codes, and which callers are deliberately left on `|| echo` because they pass fixed
      literals only (`orchestrate-unwind-dispatch.sh`, `lib/redeploy-checkpoint-lib.sh`) — and
      name the lint from Phase 5 as the mechanism keeping it that way. Describe the current design
      only; do not narrate the paragraph's own revision history.
- [ ] In `context/formats/return-metadata-file.md`'s `### modified_files (optional)` "Path form"
      paragraph, immediately after "Absolute paths are not permitted.", add the remit sentence:
      a file edited outside this repository (e.g. an agent-system source-store edit made while
      dispatched against a consumer repo) is explicitly outside `modified_files`'s remit — do not
      list it there; report it in `completion_summary` or an `issues.jsonl` entry
      (`issue-record.sh --class "cross-repo edit"`) instead, so an operator can commit it by hand
      in its own repository.
- [ ] In the same paragraph, correct the consumer attribution: it names only
      `orchestrator-postflight.sh` (confirmed orphaned, zero live invocation sites). Name
      `orchestrate-cycle-postflight.sh`, the live batch-engine consumer, as well. This is the
      one-line accuracy fix the dispatch already scopes in.
- [ ] Mirror the remit sentence into the "Field constraints" restated block in the same section,
      which exists precisely so an agent reading only that block cannot get the constraints wrong.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: Both files are pure markdown with zero compile or elaboration surface, and
the covering checks are the two mapped suites plus the source-store doc gates:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-todo-move-pair-staging.sh,test-validate-return-meta.sh`
and `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` (explicit TARGET, never the bare no-argument form, which would resolve to a consumer root and SKIP both gates).

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - exit-code rows 6 and
  7-reserved, the V9 gate label, and the revised caller-escalation residual
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - cross-repo remit
  sentence (twice: field spec and restated constraints) and the live-consumer accuracy fix

**Verification**:
- Diff read-through confirms every changed hunk lies inside prose, and that the documented exit
  table matches `git-commit-scoped.sh`'s own header table exactly (compare the two side by side —
  the standard's table is a mirror and must not drift).
- The two mapped suites and gates 3-4 pass under the invocations named in the Tier Justification.
- `bash .claude/scripts/validate-artifact.sh` is not applicable (neither file is a task artifact).

---

### Phase 4: Exit-code branch at the one live exposed caller [NOT STARTED]

**Goal**: Stop `orchestrate-cycle-postflight.sh` collapsing every nonzero exit to success, and
route the failure into a durable, operator-visible channel — without making anything fatal and
without touching `verdict` or `halt`.

**Tasks**:
- [ ] Re-read `orchestrate-cycle-postflight.sh`'s commit call site (currently ~1824) immediately
      before editing — task 302 and five other live tasks contend on this file.
- [ ] Replace the trailing `|| echo "... WARNING: commit failed ... (non-blocking)"` with an
      explicit return-code capture, following `git-commit-phase.sh`'s own `case "$rc" in` shape
      (the in-repo precedent, landed by task 336): `commit_rc=0; bash ... || commit_rc=$?`.
- [ ] Classify, and record the policy inline as a comment with its reason:
      `0` — clean, no output change. `1` — benign; keep today's non-blocking wording verbatim
      ("nothing to commit" is indistinguishable from a benign no-op by design and MUST stay
      non-fatal). `2|3|4|5|6` — a loud, named, attributable `ERROR:` naming the task number, the
      exit code, and that code's meaning from the contract, plus the remedy (the work is on disk,
      uncommitted; commit it by hand or let a later cycle's commit pick it up).
- [ ] On `2|3|4|5|6`, fire ONE `issue-record.sh` call — the durable channel
      `orchestrate-conclusion-aggregate.sh` already reads, which is what makes the violation
      genuinely attributable rather than stderr-only: `--kind issue --class "orchestration defect"
      --severity costly --phase "$phase" --resolution open --suggested-channel fix_now`, with the
      exit code and the commit message in `--what-happened`, and `--dispatch-seq` when known.
      Wrap it `>/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2`, matching
      every other `issue-record.sh` call site in this file.
- [ ] Populate the emitted verdict JSON's `note` field (today hard-wired to `""` in both `jq -n`
      branches) with the same attribution string. Keep BOTH branches in sync — the
      `user_decision`-present branch and the ordinary branch each build `note` separately.
- [ ] Do NOT change `verdict`, `halt`, `infra_exempt_cycle`, or any status write. Add a comment
      recording why: `verdict` is resolved ~270 lines before this call site and the status write
      ~560 lines before it, so a demotion here would require reordering WORK (f)/(i) or writing
      out of a terminal `completed` — the named follow-up, not this change (see the plan's
      Research Integration residual).
- [ ] Add a regression case to `test-orchestrate-cycle-postflight.sh` (next free `Case 9xx`;
      highest existing is 973). Overwrite the sandbox's copied
      `$WORKDIR/.claude/scripts/git-commit-scoped.sh` with a stub that `exit 6`, run the SUT LIVE
      (not `--dry-run` — the commit branch is `is_live`-gated), and assert: the named `ERROR:`
      appears on stderr with the exit code in it, `.note` in the emitted JSON is non-empty, and
      `.verdict` is UNCHANGED from what the same fixture produces with a stub that exits 0.
      That last assertion is the discriminating half — it proves the branch is observability, not
      a control-flow change.
- [ ] Add a second sub-case with a stub that `exit 1` and assert NO `ERROR:` and an empty `.note`,
      pinning that the benign no-op path is untouched.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The change is confined to one script plus its own suite, populating an
existing emitted field rather than altering the stdout JSON's shape, and its covering check is the
13-suite set `suite_selection_select` resolves for this path: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-corroborate-phase-counts.sh,test-deploy-baseline-lib.sh,test-force-phases.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-lint-json-channel-discipline.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-recover-message-findings.sh,test-run-task-observers.sh,test-skill-base-lifecycle.sh,test-stall-reprompt-wiring.sh`.

**Scope Hypothesis**: The call site is at `orchestrate-cycle-postflight.sh:1824`, verdict
resolution at ~1551, the WORK (f) status write at ~1264, and the final `jq -n` emit at ~2030-2075
with `note` hard-wired `""` in both branches; `test-orchestrate-cycle-postflight.sh`'s highest
existing case number is 973. All five figures were re-derived by grep at plan-authoring time
rather than carried. Re-confirm by grep before editing: six live tasks contend on this file and
any of them may shift every line number here.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - `$?` capture, the
  per-code classification branch, the `issue-record.sh` call, and `note` population in both
  `jq -n` branches
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - the
  stubbed-exit-code regression case and its benign exit-1 sub-case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` exits 0
  with the new cases PASS and every pre-existing case PASS.
- `bash agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` passes (this
  script's single-JSON-line stdout contract must survive the `note` change).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` reports no new finding.
- Confirm by inspection that no code path added here can change `verdict`, `halt`, or any status
  write — the HARD CONSTRAINT that a commit problem must never strand the batch.

---

### Phase 5: Lint rule against re-introducing the exit-code sink [NOT STARTED]

**Goal**: Keep the exit-code branch from eroding: a future executable `.sh` caller that pipes
`git-commit-scoped.sh` into a bare `|| echo` without capturing `$?` fails a numbered gate.

**Tasks**:
- [ ] Add **RULE 3** to `scripts/lint/lint-scoped-commit-boundary.sh`, alongside its existing
      RULE 2 (piped-invocation / exit-code observability) — the same lint, the same allowlist
      mechanism, the same Gate 17 wiring, rather than a new sibling script.
- [ ] Detection, scoped deliberately narrowly: a line in a **`.sh`** file (never a `.md` prose
      snippet — the dispatch's explicit preference, and research confirmed the ~50 snippets are
      documentation, not executed code) that invokes `git-commit-scoped.sh` or
      `git-commit-phase.sh` and whose invocation terminates in `|| echo` / `|| true` with no `$?`
      capture, no `rc=` assignment, and no `case` branch within the invocation's own continued-line
      block.
- [ ] Record the enumeration result in the lint's header, in the same voice RULE 2 uses — the
      sweep performed at plan time found exactly four non-test `.sh` call sites:
      `orchestrate-cycle-postflight.sh` (fixed in Phase 4), `orchestrate-unwind-dispatch.sh` and
      `lib/redeploy-checkpoint-lib.sh` (fixed literals only, allowlisted with that reason inline),
      and `orchestrator-postflight.sh` (confirmed orphan, allowlisted with that reason inline).
      `git-commit-phase.sh` already passes 0-5 through verbatim and is not a candidate.
- [ ] Add those three allowlist entries, each with its reason inline — the lint's own stated
      convention is that there are no bare paths on that list.
- [ ] State the limitation plainly in the header, matching the file's existing KNOWN LIMITATION
      voice: this is a regex-only, line-oriented content lint and cannot catch an indirection
      through a wrapper function or a capture assembled across more lines than the classifier
      reads. A clean run means "the known bad shape is not present", never "every caller branches".
- [ ] Add a both-polarity fixture pair to `scripts/tests/test-lint-scoped-commit-boundary.sh`,
      following that suite's existing fixture model: a violating fixture (bare `|| echo` sink) the
      lint must FLAG, and a conforming fixture (`rc=$?` plus a `case` branch) it must PASS. The
      negative half is what proves the rule is not vacuous.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: The edit is confined to one lint script plus its own fixture suite, and its
covering check is the exact pair `suite_selection_select` resolves for both paths: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-scoped-commit-boundary.sh,test-lint-directory-pathspec-boundary.sh`.

**Scope Hypothesis**: Four non-test `.sh` call sites of `git-commit-scoped.sh` outside the script
itself and its own libraries, of which three need allowlist entries and one was fixed in Phase 4.
Derived at plan time via `grep -rn 'git-commit-scoped.sh' --include=*.sh agent-system/extensions/`
filtered of `/tests/` and `lint/`. Re-run that grep at implementation time and reconcile: a count
that has grown means a new caller landed and must be triaged (branch it, or allowlist it with a
reason), never silently allowlisted to make the lint green.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` - RULE 3, its three
  reasoned allowlist entries, the enumeration record, and the limitation statement
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` - both-polarity
  fixture pair for RULE 3

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` exits 0
  with both new fixtures PASS and every pre-existing case PASS.
- `REPO_ROOT=/home/benjamin/.config/nvim bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose`
  exits 0 against the real source store (Gate 17's own invocation shape).
- Confirm `file_scope` expansion landed for the two new paths before committing:
  `jq -r '.active_projects[] | select(.project_number==304) | .file_scope' specs/state.json`
  lists both lint paths. If it does not, the excursion filter will drop them from the per-cycle
  commit and this phase's work is silently left uncommitted.

---

### Phase 6: Full gate, deploy verification, and follow-up filing [NOT STARTED]

**Goal**: Prove the whole change green against the complete gate set, confirm the deployed tree
matches the source store, and file the two follow-ups rather than leaving them to be rediscovered.

**Tasks**:
- [ ] Run the complete shell suite. **Bounded-wait idiom, mandatory**: Bash tool `timeout`
      parameter `600000`, inner `timeout 540`, output to a file, then grep the file:
      `timeout 540 bash agent-system/extensions/core/scripts/tests/run-all.sh > /tmp/claude-1000/.../run-all.log 2>&1; echo "rc=$?"; grep -E '^(Results|FAIL|\[FAIL\])' /tmp/.../run-all.log | tail -40`.
      Never `run_in_background`; never await a harness notification for this.
- [ ] Run the full deploy verification under the same idiom:
      `timeout 540 bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim > /tmp/.../verify.log 2>&1; echo "rc=$?"; grep -E 'FAIL|WARN|^[0-9]+\.' /tmp/.../verify.log | tail -60`.
- [ ] If a redeploy is needed to sync `.claude/` with the source store, run `deploy-headless.sh`
      under the identical bounded-wait idiom, then re-run `verify-deploy.sh` the same way.
- [ ] `agent-system/extensions/core/scripts/verify-deploy.sh` is currently uncommitted-modified by
      concurrent sibling work and is OUTSIDE this task's scope. If a gate failure traces to it,
      attribute it to that sibling in the summary and do not edit it; check `git log` and
      `git diff` on that file before concluding the failure is this task's own.
- [ ] File follow-up (a): propagate the `modified_files` repo-relative constraint to the 9
      implementation agents that never mention the field — the root-cause remediation the dispatch
      names, to be triaged with that severity rather than as documentation tidying.
- [ ] File follow-up (b): task 336's unfiled `file_scope`-Containment chokepoint specification
      (`specs/archive/336_phase_commit_staging_has_no_scope_check/evidence/03_followup-mechanical-check.md`),
      noting that exit **7** is now reserved for it in `git-staging-scope.md` and that it must read
      this task's landed exit-code table before proposing any change to `git-commit-scoped.sh`.
- [ ] File follow-up (c): the status-demotion residual — surfacing a failed per-cycle commit into
      the task's own STATUS (not merely its issue log), which requires reordering
      `orchestrate-cycle-postflight.sh`'s WORK (f)/WORK (i) or a sanctioned write out of a terminal
      `completed`. Record that this plan deliberately delivered the visible-and-attributable half
      only, and why.
- [ ] Write the implementation summary, stating explicitly: the predicate chosen (ACCEPTANCE item
      4), the silent-vs-loud ruling and that both axes are met (item 7), the cross-repo ruling
      (item 5), the non-blocking-policy ruling and that it was recommended not imposed (item 6),
      and the one residual above.

**Timing**: 1 hour

**Depends on**: 3, 5

**Verification Tier**: full

**Scope Hypothesis**: "9 implementation agents never mention `modified_files`" is a figure CARRIED
from this task's own dispatch description (which reports 4 of 13 agents under
`agent-system/extensions/*/agents/` mentioning the field) and is NOT re-derived in this plan.
Treat it as `CARRIED-UNVERIFIED` and re-derive it when filing follow-up (a):
`grep -l 'modified_files' agent-system/extensions/*/agents/*implementation-agent.md` against the
full agent inventory. File the follow-up against the re-derived count, never the carried one.

**Files to modify**:
- `specs/304_out_of_repo_pathspec_aborts_whole_commit/summaries/01_out-of-repo-pathspec-containment-summary.md`
  - implementation summary
- `specs/304_out_of_repo_pathspec_aborts_whole_commit/plans/01_out-of-repo-pathspec-containment.md`
  - phase status markers
- `specs/state.json`, `specs/TODO.md` - via `update-task-status.sh` only, never edited by hand

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (source-store path
  `agent-system/extensions/core/scripts/verify-deploy.sh`, with the explicit TARGET
  `/home/benjamin/.config/nvim`) passes in full — the complete gate set it aggregates, including
  Gate 8's shell-suite battery and Gate 17's scoped-commit boundary lint. No `--skip-slow`, no
  `--only-gate` narrowing: this is the final gate and neither mechanism is evidence for it.
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` and
  `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` both
  exit 0 (ACCEPTANCE item 8).
- All three follow-ups exist as filed tasks, each with its evidence path.

---

## Testing & Validation

- [ ] ACCEPTANCE 1: a list with one out-of-repository absolute path plus N valid repo-relative
      paths commits the N paths and names the offending entry loudly (T14, content-asserted).
- [ ] ACCEPTANCE 2: T14/T17/T18 are recorded as FAILING against the pre-fix script, so they cannot
      pass vacuously, and assert on committed CONTENT rather than exit code alone.
- [ ] ACCEPTANCE 3: `:(exclude)` entries, V2 Case 2 already-staged deletions, V2 Case 3 genuinely
      unmatched paths and the V3 exclude-only refusal are all unchanged — T1-T13, X1-X8 and W1-W4
      re-run green, with Case 2 (T8/T9) and the renames (T10, W-series) checked explicitly.
- [ ] ACCEPTANCE 4: an absolute path resolving INSIDE the repository still commits (T15), and the
      chosen predicate is stated explicitly in the script header, in `git-staging-scope.md` and in
      this plan — parent-directory resolution via `realpath -m --relative-to`, final component
      deliberately unresolved, with T16 pinning the leaf-symlink case that distinguishes the two.
- [ ] ACCEPTANCE 5: the cross-repository-edit question is ruled on — no new field; the format spec
      states the remit and names `completion_summary` / `issues.jsonl` as the reporting channel.
- [ ] ACCEPTANCE 6: the non-blocking-policy question is ruled on with reasoning — recommended, not
      imposed; nothing becomes fatal; the one residual is named with its owner.
- [ ] ACCEPTANCE 7: both axes are met — the valid work commits AND the violation reaches a durable
      operator-visible channel (`issues.jsonl` via the Phase 4 branch, aggregated by
      `orchestrate-conclusion-aggregate.sh`), not stderr alone.
- [ ] ACCEPTANCE 8: `bash scripts/tests/test-git-commit-scoped.sh` and `scripts/verify-deploy.sh`
      both pass in full.
- [ ] HARD CONSTRAINT: no code path added by this plan can abort a batch or strand an
      orchestration mid-run; `verdict`, `halt` and every status write are untouched.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — V9 gate, exit 6
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — T14-T18
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — exit-code branch
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — regression case
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — V9 label, exit 6, exit 7 reserved
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — cross-repo remit, consumer accuracy fix
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` — RULE 3
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` — RULE 3 fixtures
- `specs/304_out_of_repo_pathspec_aborts_whole_commit/summaries/01_out-of-repo-pathspec-containment-summary.md`
- Three filed follow-up tasks (producer propagation; 336's Containment chokepoint; the
  status-demotion residual)

## Rollback/Contingency

Every phase is independently revertible and separately committed, and no phase changes a
pre-existing exit code or status transition — the two additions (V9's drop, exit 6) are reachable
only in a shape that today fails fatally, so reverting any single phase restores exactly the
prior behavior.

- Phase 2 regression (a false-positive drop of a legitimate path): revert that phase's commit.
  The V9 guard is one self-contained branch plus one exit decision; nothing else in the script
  depends on either. T15/T16 are the detectors, and both run in Phase 1 before Phase 2 exists.
- Phase 4 regression (a batch disturbed by the new branch): revert that phase's commit. The branch
  only adds output and an issue record; the `|| echo` fallback it replaces is restored verbatim.
- Phase 5 regression (the lint fails the gate on a legitimate caller): add the reasoned allowlist
  entry, or revert that phase. Gate 17 is non-fatal to the work already committed.
- Before any rollback that would discard uncommitted work, take a non-reverting checkpoint first:
  `bash .claude/scripts/git-snapshot.sh 304 --no-revert`. Never the bare reverting form as a
  routine checkpoint — the shared working tree carries concurrent sibling work.
