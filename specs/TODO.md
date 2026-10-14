---
next_project_number: 407
---

# TODO

## Task Order

*Updated 2026-10-14. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,170,282,342,360,383,385,389,393,394,397,400,403,404,405,406 | -- | core-agent-system, extensions, literature, ... |
| 2 | 29,275,312,328,376,384,395,398 | 22,170,282,383,393,394,397 | core-agent-system, extensions, lean-extension, ... |
| 3 | 274,338,350,369,396,399 | 29,275,376,393,395,398 | core-agent-system, extensions, lean-extension, ... |
| 4 | 359,378,391 | 274,350,369 | core-agent-system, orchestrator, agent-system |
| 5 | 362,387,390,402 | 359,378,391,400 | orchestrator, agent-system |
| 6 | 313,401 | 328,387 | core-agent-system, agent-system |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state...
  └─ 328 [NOT STARTED] — Systematic top-to-bottom efficiency refactor of the shell...
    └─ 313 [NOT STARTED] — Advisory lint for hand-authored /orchestrate batch proposals...
282 [NOT STARTED] — Write-time PreToolUse hook blocking record-versioning...
360 [NOT STARTED] — Validate that every CARRIED-UNVERIFIED mark names a source,...
400 [NOT STARTED] — Task-number allocation can desynchronize silently: no...
406 [NOT STARTED] — SOURCE STORE IS THE EDIT TARGET:...
338 [NOT STARTED] — SOURCE STORE IS THE EDIT TARGET:...
359 [NOT STARTED] — Close the two measured curated-array coverage gaps in the...
369 [NOT STARTED] — Orphan sweep for deployed entries removed from the source...
376 [NOT STARTED] — Lean implementation agents mandate the...

### Extensions

342 [HOLD] — Refactor the books extension's context corpus against the...
383 [NOT STARTED] — Add a /reconcile command to the books extension: aggregate...
  └─ 384 [NOT STARTED] — Adjudicate whether a books reconciliation postflight...
29 [NOT STARTED] — Generate .mcp.json from extension manifests, then register...
350 [NOT STARTED] — Offer the owner the review path when a books task reaches a...

### Literature

404 [NOT STARTED] — Fix test-zotero-generate-export.sh hanging indefinitely and...

### Neovim

22 [NOT STARTED] — Freeze .opencode: silence fragment validation spam and record...

### Lean Extension

385 [NOT STARTED] — Define the sanctioned shape for a lean4-typed plan that...
397 [NOT STARTED] — Require a lean research report's recommended compiled...
  └─ 398 [NOT STARTED] — Record that a grep for dependents misses rw-site definitional...
    └─ 399 [NOT STARTED] — Record three measured lean4 gotchas: IO-forced timing...
396 [NOT STARTED] — Add two explicit guidance items to the lean implementation...

### Orchestrator

389 [RESEARCHING] — Fix test-verify-deploy-context-budget.sh's fixture so the...
393 [NOT STARTED] — Propagate the modified\_files repo-relative-paths constraint...
394 [NOT STARTED] — Specify and implement a file\_scope-based containment...
  └─ 395 [NOT STARTED] — Surface a failed per-cycle scoped commit into the DISPATCHED...
403 [NOT STARTED] — Share one verify-deploy gate run across an /orchestrate batch...
405 [NOT STARTED] — Detect a stranded dispatch from its own stale heartbeat...
274 [NOT STARTED] — Next-admissible-batch suggestion and...
  └─ 378 [NOT STARTED] — Resolve the reviser-agent handoff contract contradiction...
    └─ 387 [NOT STARTED] — Teach the batch admission gate that a whole-tree regeneration...
275 [RESEARCHING] — Per-repo orchestration queue: registered, live, archived on...
  └─ 274 [NOT STARTED] — Next-admissible-batch suggestion and... (see above)
312 [NOT STARTED] — Backlog reconciliation as a required task-creation component:...
402 [NOT STARTED] — Conclusion stage Step 4c allocates no task number and creates...

### Agent System

362 [NOT STARTED] — Teach the non-destructive history-read techniques at the...
390 [NOT STARTED] — Migrate seven mis-sited agent-system tasks out of...
391 [NOT STARTED] — Close the target\_root authoring hole that files agent-system...
  └─ 390 [NOT STARTED] — Migrate seven mis-sited agent-system tasks out of... (see above)
401 [NOT STARTED] — Two repositories file against one source store with no...

## Tasks

### 406. Mint hook dirties tree before precondition read
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/**` (never `.claude/**`), per `rules/source-store-deploy-boundary.md`. Resolution for this task was performed and recorded: `.claude-extensions.json` carries NO top-level `source_dir` key — `source_dir` is per-extension, nested in each `.extensions` entry. All three implicated files are owned by the `core` entry, whose `source_dir` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core`, confirmed to exist on disk with all three mirrored paths present.

A `UserPromptSubmit` mint hook writes to a tracked file before a command precondition reads it, so `/tag` can never pass its own clean-tree check

--- WHY ---

`skill-tag` Step 1 refuses on a dirty tree: `if [ -n "$(git status --porcelain)" ]` then exit 1 (`skills/skill-tag/SKILL.md:72`). The check is correct in itself. The defect is what runs before it.

`hooks/please-grant.sh` recognises four literal prompt prefixes and sets `MINT_SOURCE` for each: `/please` (line 61), `/merge` (65), `/tag` (68), `/pr` (71). For `/tag` it mints a `push_tag` grant via `pg_grant_mint` (`scripts/lib/push-grant-lib.sh:473`). `pg_grant_mint` then unconditionally appends a `push_grant_issued` audit record through `pg_events_append_observable` (line 480) to `scripts/events-append.sh`, which writes `specs/events.jsonl`.

`specs/events.jsonl` is a TRACKED file in at least one consumer repository (`~/Projects/Logos/Verification`). `UserPromptSubmit` hooks run BEFORE the command body. So typing `/tag --minor` dirties a tracked file, and then `/tag`'s own Step 1 reads that dirt and exits 1. The command cannot pass its own precondition in any repository that tracks `specs/events.jsonl`.

NO FLAG BYPASSES IT. `--force` skips only the confirmation prompt; `--skip-version-check` and `--skip-changelog-check` bypass only their own steps (flag table, `skills/skill-tag/SKILL.md:18-27`). There is no git-state escape hatch.

MEASURED EVIDENCE of a real failure, from the committed `specs/events.jsonl` in the Verification repository:

```
timestamp 2026-10-14T17:22:24.427Z
"message":"push grant issued: push_tag origin refs/tags/*"
"detail":{"mint_source":"tag","action_class":"push_tag","request_text":"/tag v0.2.0"}
```

A `/tag` invocation minted a grant that day; `git tag -l` still showed only `v0.1.0` afterwards. The `v0.2.0` alpha tag had to be created by hand with `git tag -a`, bypassing `skill-tag` entirely, to ship the release.

SECONDARY SYMPTOM, same root cause, in scope for the same fix: every push through `scripts/git-push-granted.sh` appends `push_grant_consumed`, so a push always leaves the tracked log dirty. Combined with Step 1's clean-tree rule and Step 2's `ahead == 0` rule, an operator satisfying both enters a loop: dirty tree, commit it, now 1 commit ahead of remote, push it, dirty again. Observed directly: it cost two extra commits in the Verification repository (`2aa1674a` and `2131a2a8`) purely to sweep the log.

--- SCOPE ---

1. FIX THE CLASS, not just `/tag`'s symptom: no mint hook may dirty the git tree ahead of a command precondition that reads tree state. The confirmed direction is to make the audit append deferred, buffered, or otherwise ordered after the command body, in `scripts/lib/push-grant-lib.sh` (and `scripts/events-append.sh` if the buffering needs a writer-side change), rather than only teaching `skill-tag` Step 1 to ignore one filename. Narrowing Step 1 was considered and is the fallback if the deferral proves infeasible; record which was adopted and why.
2. PRESERVE THE AUDIT GUARANTEE. The grant mechanism is a consent gate; its audit trail is the evidence that a human authorised a specific action. A fix MUST NOT silently drop `push_grant_issued` when the command body never runs, or the record of a minted-but-unused grant disappears — which is exactly the forensically interesting case. State explicitly what happens to the record of a grant that is minted and then abandoned, refused, or expired.
3. COVER the `push_grant_consumed` loop in the same pass, per the secondary symptom above. A fix that unblocks `/tag` but leaves the push/commit loop intact is incomplete.
4. VERIFY the blast radius rather than trusting this description: measured in-session, `skill-tag` is the ONLY skill carrying a `git status --porcelain` check (grepped across `.claude/skills/`; no `skill-merge` or `skill-pr` exists in the Verification deploy, and no `.claude/commands/*.md` carries one). `/merge`, `/pr` and `/please` mint identically but gate nothing on tree cleanliness, so they are unaffected today. Re-measure over the source store, since the deploy may lag it, and note that any future skill adding a clean-tree check inherits this bug — which is the argument for fixing the cause.
5. REGRESSION TEST pinning the behaviour: a `/tag` invocation in a repository that tracks `specs/events.jsonl` must reach Step 2 rather than exiting 1 at Step 1. `scripts/tests/test-please-grant.sh` and `scripts/tests/test-guard-git-push.sh` already reference these event types and are the natural homes.

--- CONSTRAINTS ---

- COORDINATE, do not duplicate: the existing task `sweep_task_support_file_tracked_or_ignored` (type meta, not_started) owns classifying every task-support file under `specs/` as tracked or ignored, and owns `scripts/lib/runtime-file-patterns.sh` plus `context/standards/orchestrator-runtime-files.md`. Measured in-session: `events.jsonl` appears NOWHERE in `orchestrator-runtime-files.md`'s per-file table, and the pattern generator ignores only its lock file (`runtime-file-patterns.sh:144`, `**/.events.lock`), not the log itself. So `specs/events.jsonl` is tracked by default rather than by any recorded ruling, and its classification is that task's business, NOT this one's. This task's `file_scope` deliberately EXCLUDES both of those files for that reason. Do not edit them; do not restate their ruling.
- Gitignoring `specs/events.jsonl` is NOT this task's fix. It was considered and set aside: it would make this symptom vanish without touching the class bug, it is a provenance policy change in each consuming repository rather than a system fix, and the Verification repository has been deliberately committing that log (see its commit `4fdfa7e0`, "specs: commit accumulated observer and evidence records"). If the sweep task later rules the log ephemeral, this fix still stands on its own for every future precondition-reading command.
- `/tag` is user-only. Any verification of the fixed path must be run by the owner, not by an agent; an agent may verify only the library and test-suite level.

--- ACCEPTANCE ---

- A mint on a `/tag`-shaped prompt leaves the git tree byte-identical, or `skill-tag` Step 1 passes in a repository that tracks `specs/events.jsonl`; whichever direction was adopted is recorded with its reason.
- The record of a minted-but-unconsumed grant is still recoverable, with the mechanism stated.
- The push-then-commit loop no longer requires a sweep commit per push.
- New regression cases pass in `scripts/tests/test-please-grant.sh` and/or `scripts/tests/test-guard-git-push.sh`.
- `scripts/lib/runtime-file-patterns.sh` and `context/standards/orchestrator-runtime-files.md` are unmodified by this task.

---

### 405. Detect stranded dispatch from stale heartbeat
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: Detect a stranded dispatch from its own stale heartbeat instead of only after a recorded failure

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree, which is a gitignored, disposable deploy artifact regenerated from the source store -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS via deploy-headless.sh. No task-number references and no record-versioning language in any file landing under agent-system/**; both are permitted in this description.

A dispatched agent can end its turn with a backgrounded command still pending. The command's parent shell dies, the process tree is reparented to init/systemd, and the notification the agent is waiting on can never fire. The agent then waits forever: its state still reads `running`, it writes no further artifact, and it produces no handoff and no return metadata. Nothing in the orchestration loop notices.

THREE INSTANCES MEASURED IN A SINGLE BATCH, two of them in different agent types:

1. A research dispatch's entire contribution was lost. Its last and only return text was the single sentence "Waiting for the Monitor notification that the fixture test has completed before finalizing the research report." It wrote no report, its .return-meta.json stayed at `in_progress`, and postflight classified it `failed` with report_missing=true. The dispatch had to be charged a failure and the task re-queued from scratch.

2. An implementation dispatch stranded with five of six phases committed. Phase 6 sat [IN PROGRESS] with no progress file ever written; last artifact write was 1h54m before detection. Its task lock's heartbeat_at was equally stale (1h53m), while the lock holder's own pid was still alive. Two verify-deploy.sh process trees it had launched were still running but reparented to `systemd --user`, detached from the session's claude process. System load had meanwhile fallen to 3.99 on 24 cores -- the machine was idle while the agent reported `running`. It was recovered only because a human noticed the quiet and re-prompted the agent by hand.

3. specs/ROADMAP.md already carries this as an unfiled observation, recorded against a general-implementation-agent -- so it is not specific to one agent type or one phase.

WHY THE EXISTING MACHINERY DOES NOT CATCH IT. The detection signal is already written and was already correct in instance 2: task-lock.sh maintains heartbeat_at, and its `check` subcommand already classifies precisely this condition as the third state `held-live` -- stale heartbeat, holder pid still alive -- documented in context/patterns/task-lock.md. What is missing is a consumer: nothing in the dispatch loop calls `check` against its own in-flight tasks mid-flight, and `reap` is explicit-invocation-only by design (never called from acquire/heartbeat/release/check). Worse, `held-live` currently reads as a reason NOT to act, because for lock-acquisition contention a live pid means the holder is healthy. For stall detection the same state means the opposite: a live pid with a two-hour-stale heartbeat is the signature of a stranded dispatch, not a healthy one. The same evidence supports opposite conclusions in the two contexts, and only the acquisition context has a reader.

The existing stall re-prompt path is not a substitute: it triggers off a postflight `failed` verdict, so reaching it costs the task a recorded failure first -- which is exactly what happened in instance 1, and what hand-recovery avoided in instance 2.

GOAL, two complementary halves.

(a) DETECTION. Give the orchestration loop a way to notice a stranded dispatch from the heartbeat it already has, before charging a failure. Decide and document how `held-live` is interpreted per context, since a live pid must not keep reading as healthy during in-flight dispatch monitoring the way it correctly does during lock acquisition. Reuse task-lock.sh's existing threshold constant and `check` exit codes rather than adding a parallel staleness notion.

(b) PREVENTION. context/patterns/external-process-wait.md Rule 1 already defines the bounded-wait idiom (background, then poll with `timeout ... while kill -0`, then re-read the log) that would have prevented all three instances. It is documented and unenforced. Agent contracts already have a lint precedent in the heartbeat contract lint, so extending that enforcement to the await-a-notification antipattern is the cheaper half.

Out of scope unless research shows otherwise: changing how notifications themselves are delivered, and reaping or killing orphaned process trees (an orphan that nothing reads is harmless and exits on its own; the harm is the agent waiting on it).

Verification must include a fixture reproducing the shape -- an agent-side wait on a signal that never arrives, with a live holder pid and a stale heartbeat -- and must prove detection fires WITHOUT the task first being charged a failed verdict. A test that only passes once a failure is recorded has reproduced the current behaviour, not the fix.

Severity: costly. It silently destroys whole dispatches rather than slowing them, it is agent-type-independent, and detection currently depends on a human noticing an absence of output.

---

### 404. Zotero export test hangs full gate
- **Effort**: small
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Fix test-zotero-generate-export.sh hanging indefinitely and breaking every full verify-deploy.sh run

agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh passes its first case and then stalls indefinitely instead of completing or failing. Because the suite is part of run-all.sh, it is reached by gate 8 of the complete verify-deploy.sh gate set, so it hangs every full-gate run in this repository.

EVIDENCE (two independent observations):
1. Reproduced in isolation with zero contention: `timeout 60 bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh` passes one case then stalls past the 60s timeout. Isolation rules out CPU contention as the cause.
2. Observed live in the process table during a concurrent batch: the suite ran for 24 minutes with a single child process, `agent-system/extensions/literature/scripts/zotero-generate-export.sh --orchestrator-mode true`, still alive and making no progress. The hang therefore sits in zotero-generate-export.sh under `--orchestrator-mode true`, not in the test harness's own control flow. Candidate causes worth checking first: a read from stdin with no redirect (an interactive prompt reached in a non-interactive context), or an unbounded wait on a Zotero API/socket call with no timeout.

REPO-WIDE CONSEQUENCE: every implementation plan whose final phase declares the criterion "verify-deploy.sh exits 0 -- the complete gate set" is unsatisfiable for reasons unrelated to that plan's own work, because the gate never terminates. This is worse than a failing gate: a FAIL is a readable result, whereas a hang forces every agent into either an open-ended wait or a documented exclusion. It also masks real breakage -- a genuine regression in the same gate is indistinguishable from this known hang in a run that never finishes.

GOAL: make the suite terminate deterministically. Give zotero-generate-export.sh a bounded wait and a non-interactive path under `--orchestrator-mode true` so it cannot block on stdin or on an unbounded network call, and give the test case its own timeout so a future regression of this shape fails loudly rather than hanging. Verification must prove the suite terminates with a definite pass or fail under a wall-clock bound, and that the bound is exercised (a deliberately-stalled fixture must make the new timeout fire rather than hang).

Severity: costly -- it is load-bearing for every task's final-phase verification criterion repo-wide.

---

### 403. Share one verify deploy gate run per batch
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: Share one verify-deploy gate run across an /orchestrate batch instead of one full run per task

Observed live during a 7-task /orchestrate batch in this repository. Every plan's final phase independently declared Verification Tier `full` with the criterion "verify-deploy.sh exits 0 -- the complete gate set", so four concurrently-dispatched implement phases each launched the complete ~104-suite run-all.sh battery.

Measured consequence: load average 39.91 on 24 cores (~1.7x oversubscribed), 18 concurrent run-all.sh/verify-deploy.sh processes, and literally duplicated suites in flight across sessions -- two copies each of test-verify-deploy-context-budget.sh (one at 14m30s elapsed), test-verify-deploy-gate-selection.sh, and test-context-reachability.sh. Individual gate runs stretched to 10-14+ minutes and appeared to hang.

Second-order harm, observed rather than hypothesized: one implementation agent, seeing its own run appear hung under the contention, ran `pkill -f "run-all.sh"` and killed other concurrent sessions' gate runs machine-wide (sandboxed fixtures under /tmp belonging to sibling sessions). The tooling is read-only so nothing was corrupted, but those sessions' verification was interrupted and had to be re-run. The contention is what made a broad pkill look reasonable to the agent in the first place.

The gate is also near-useless per-task under concurrency: because siblings' in-flight file_scope edits are visible to every other sibling's gate run, each run reports failures caused by other tasks. Two tasks in that batch had to close their final phase [COMPLETED WITH EXCLUSIONS] and write Reasoned Exclusions tables attributing failures to siblings -- which masks genuine new breakage, since a real regression would be indistinguishable from the known sibling noise in the same result.

GOAL: when /orchestrate dispatches a batch, the complete verify-deploy.sh gate set should run ONCE for the batch, after the last implement phase closes, rather than once per task inside each task's own final phase. Per-task final phases should fall back to a cheaper scoped tier (the existing `local`/`interface` tiers) and defer the full-set criterion to the shared batch-level run, whose result is attributed to the batch rather than to one arbitrary task.

Open questions for research/planning: whether a single-task invocation keeps today's behaviour unchanged; how the shared run's failures get attributed back to the responsible task's file_scope; and whether the plan-format `full` tier criterion wording needs a batch-aware variant so planner-agent stops authoring a per-task full-gate criterion it cannot meaningfully satisfy under concurrency.

---

### 402. Conclusion stage Step 4c allocates no task number and creates no task directories
- **Effort**: small
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 391, Task 400

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree, which is a gitignored, disposable deploy artifact regenerated from the source store -- see rules/source-store-deploy-boundary.md). Resolve source_dir from <project-root>/.claude-extensions.json and edit at the path mirroring the deployed one. REDEPLOY AFTERWARDS via deploy-headless.sh to RESULT=landed_verify_clean. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md) and no record-versioning language (rules/no-record-versioning-in-deliverables.md); both are permitted in this description and elsewhere in specs/**.

GOAL. Finish the task-creation pattern that context/contracts/conclusion-stage.md's Step 4c half-transcribes. The step claims to reuse skills/skill-spawn/SKILL.md's Stage 11 but copies only the row-append portion, so it allocates no task number and creates no task directories.

=== TWO DISTINCT OMISSIONS IN ONE STEP ===

Read context/contracts/conclusion-stage.md Step 4c ("Channel (c) execution: follow-up tasks as children", at line 297 as measured 2026-10-13) and compare it against skills/skill-spawn/SKILL.md Stage 11, the pattern it names as "already proven".

(i) IT DOES NOT ALLOCATE A TASK NUMBER AT ALL. "$new_task_num" is consumed twice -- in the state-write.sh call's --argjson num binding (line 324) and again in the manage-topics.sh set call (line 328) -- but it is NEVER BOUND anywhere in the step. The step contains no next_project_number read and no next_project_number write. skill-spawn Stage 11 does both: it reads next_num=$(jq -r '.next_project_number' specs/state.json), and after its inserts writes '.next_project_number = $next' with $((next_num + task_count)). Step 4c transcribed the insert and dropped both counter halves.

(ii) IT CREATES NO TASK DIRECTORIES. The step's git-commit-scoped.sh call stages "${new_task_dir_paths[@]}" (line 339), an array the step never populates and whose directories it never creates. The staged array is empty, so channel (c) produces task records with no directory on disk.

=== MEASURED CONSEQUENCE, CAUSAL CHAIN CLOSED ===

Verified in ~/Projects/BimodalLogic 2026-10-13:

Commit 9110a99fc, "orchestrate conclusion: channel (c) follow-up tasks", Tue 2026-10-13 17:08:54, inserted project_number 781 (phase5_hoist_kernel_neutral_decision) and 782 (phase7_verts_shape_d_decomposition).

- At 9110a99fc^: next_project_number = 781, max project_number = 780 -- the counter was CORRECT, pointing one past the max.
- At 9110a99fc: next_project_number = 781, max project_number = 782 -- UNCHANGED by the commit, and now pointing TWO BEHIND, at an already-used number.
- The commit staged specs/TODO.md and specs/state.json only. No task directories, confirming omission (ii); 781 and 782 have no spec directory on disk to this day.

Roughly 73 minutes later a conclusion-stage channel (b) dispatch allocated from that stale counter, received 781, and collided with the existing 781. Recovery was manual renumbering to 783 with the counter set to 784, landed in commit 1e0fe3b40 at 18:22:04.

NOTE WHAT COMMITTED HISTORY DOES AND DOES NOT SHOW, because it governs how this class can be audited: the duplicate NEVER APPEARS IN ANY COMMIT. Checked every commit from 9110a99fc to HEAD that touches specs/state.json -- the duplicate project_number set is empty at each one, because the collision lived only in the working tree and was repaired before the next commit. The only durable trace in history is the counter staleness itself, which IS visible at 9110a99fc and still at a69b7ffcf (18:04:40, next=781 against max=782). A post-hoc audit of commits can therefore find a stale counter but can never find the collisions it caused.

=== WHY A SERIALIZED ALLOCATOR ELSEWHERE DOES NOT CLOSE THIS ===

Omission (i) is NOT fixed by adding an allocate action to scripts/state-write.sh, and that distinction is the reason this record exists separately from the counter-staleness record. state-write.sh having a correct serialized allocator changes nothing here, because Step 4c WOULD NOT CALL IT -- the step has no allocation call of any kind, only an unbound variable. The step itself must be repaired.

Conversely, repairing Step 4c does not close the counter-staleness class either: six other paths re-implement read-then-increment in their own prose jq, and the read-then-write race between any two of them is untouched by fixing one step. The two records are complements, not substitutes.

=== SCOPE ===

Transcribe the missing halves of the pattern Step 4c already cites, so that channel (c) allocates its numbers and creates its directories. Both omissions are the same authoring failure -- half a cited pattern copied -- in one step of one file, with one fix, which is why they are filed together rather than split.

IF the counter-staleness record has by then settled on a central allocation mechanism, Step 4c must CALL that mechanism rather than hand-rolling a seventh copy of read-then-increment; that is what the dependency edge below is for. If it settled on something other than a central allocator, transcribe skill-spawn Stage 11's counter handling faithfully instead and say so.

ACCEPTANCE. Step 4c binds every variable it consumes. A channel (c) run allocates from the counter and advances it. It creates the task directories it stages, or stops staging an array it does not populate. Covered by a fixture test -- scripts/tests/test-orchestrate-conclusion-aggregate.sh exists (verified present 2026-10-13) and is uncontended by any non-terminal record; extend it, or name a new test in the plan.

=== DEPENDENCIES ===

dependencies: [391, 400].

EDGE ON 391 IS FOOTPRINT, AND IT IS THE ONLY TERRITORY EDGE NEEDED. Measured 2026-10-13: 391 agent_system_task_siting_and_target_root is the ONLY non-terminal record declaring context/contracts/conclusion-stage.md in its file_scope. 391's own dependency rationale states that 372 and 373 also declare that file, and they did -- but both are now [COMPLETED] and archived, so neither is a live claimant and no edge to either is possible or needed. Verify this before adding further edges rather than inheriting the stale list.
391 edits the same file for a DIFFERENT step: its root cause is Step 4b dispatching meta-builder-agent without resolving target_root. Same contract file, adjacent step, unrelated substance. The edge serializes the file, not the reasoning.

EDGE ON 400 IS SUBSTANTIVE. 400 task_number_allocation_staleness_undetected owns what correct allocation IS -- whether a stored counter, a derived max, or a serialized allocator in state-write.sh. Step 4c's repair must call whatever that record settles. Fixing this step first would add a seventh hand-rolled read-then-increment, which is precisely the proliferation 400 exists to end.

=== FILE SCOPE ===

Declared: context/contracts/conclusion-stage.md, scripts/tests/test-orchestrate-conclusion-aggregate.sh.

CONDITIONAL, ADD AT PLAN TIME: skills/skill-spawn/SKILL.md only if the repair factors the shared pattern out of it rather than transcribing from it (uncontended by any non-terminal record as measured 2026-10-13); scripts/state-write.sh only if 400's chosen mechanism needs extending for this caller (claimed by 400, which the edge above already serializes).

=== NOT IN SCOPE ===

No change to the conclusion stage's three-channel derivation contract, its per-channel approval gates, or its approval-ledger mechanics. No target_root resolution work in Step 4b -- that is 391. No validation or detection of a stale counter -- that is 400. No repair of the BimodalLogic incident data, already recovered and verified. No audit of the other five creating paths' own counter handling beyond citing them -- that is 400's territory.

---

### 401. Two repositories file against one source store with no cross-repo overlap or dependency visibility
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 387

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree, which is a gitignored, disposable deploy artifact regenerated from the source store -- see rules/source-store-deploy-boundary.md). Resolve source_dir from <project-root>/.claude-extensions.json and edit at the path mirroring the deployed one. REDEPLOY AFTERWARDS via deploy-headless.sh to RESULT=landed_verify_clean. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md) and no record-versioning language (rules/no-record-versioning-in-deliverables.md); both are permitted in this description and elsewhere in specs/**.

GOAL. Establish, with measured evidence, that the file_scope overlap gate and the dependencies[] graph are blind across repository boundaries while two repositories' task spaces file work against ONE shared source store -- and route the resulting scope question to the repository owner rather than deciding it here.

THIS RECORD'S PRIMARY DELIVERABLE IS AN ADJUDICATED DECISION, NOT A MECHANISM. Do not design a cross-repo gate before the escalation below is answered.

=== WHAT WAS OBSERVED (measured 2026-10-13) ===

An orchestrate conclusion-stage channel (a) dispatch running in ~/Projects/BimodalLogic wrote four Lean 4 context notes into the lean extension's source store in THIS repository, landed as commit f49576632 ("lean: record four Lean 4 measurement and syntax gotchas", 5 files changed, +105 lines). The four notes were derived from four issue-log entries in that repo's specs/716_sliced_certificate_liveat_nontermination/issues.jsonl.

Unknown to that dispatch, tasks 398 and 399 in THIS repo had been filed from the IDENTICAL four entries roughly an hour earlier, and both were still [NOT STARTED] when the dispatch ran:

- 399 lean4_context_three_measured_gotchas cites iss_1791886589088_do8mDR, iss_1791914943297_AoBxvm and iss_1791928136829_T0iDVg. Its declared file_scope includes context/project/lean4/domain/lean4-syntax.md -- which f49576632 edited (+27 lines).
- 398 lean_plan_scope_rw_site_unfolding cites iss_1791921588196_IcZKne. Its declared file_scope includes context/project/lean4/patterns/dependency-tracing.md -- which f49576632 edited (+18 lines).

All four entry ids were verified present in that issues.jsonl, with classes measurement, syntax, syntax and scope respectively, matching the four landed notes one-to-one.

So the same work was performed twice from one evidence base, inside the second filer's own declared file territory, while both records sat unstarted. Worse, 399's stated purpose was the SITING decision for those notes, and the dispatch made that decision unilaterally. Both descriptions have since been annotated with what landed (commit 4311617a2), which also marks 399's "measured absent" premise false.

=== WHY NO GATE CAUGHT IT ===

The pre-dispatch admission review, the file_scope overlap and collision gates, and the dependencies[] edges are ALL scoped to one repository's specs/state.json. Both task spaces file work against the SAME source store (agent-system/extensions/** in this repo), so two records in two repositories can claim the same source-store file with no edge between them and no overlap finding anywhere. All coordination across the two spaces is currently a manual read by whoever happens to notice.

Note the harder half, which no siting fix reaches: the colliding dispatch carried NO TASK RECORD OF ITS OWN in either repo's terms. It implemented directly from issue-log entries under channel (a). A gate keyed on task records cannot see such a dispatch at all. Any proposed remedy must say what it does about this case, or state explicitly that it does not cover it.

=== ESCALATION -- OWNER ADJUDICATION REQUIRED, DO NOT DECIDE THIS UNILATERALLY ===

Task 275 per_repo_orchestration_queue is [RESEARCHING] and carries an explicit marked ruling. Verbatim:

  "SCOPE -- RULED: PER-REPO. One queue per repository, living beside the existing session
  registry. No cross-repo global queue and no global-ready schema requirement: file_scope
  conflicts are inherently per-repo, so a global queue would carry no information the per-repo
  one lacks."

The incident above is a direct counterexample to that ruling's PREMISE, not merely to its conclusion: this file_scope conflict was NOT per-repo. Two repositories' task spaces collided on one shared source-store file tree, and a per-repo queue would have carried none of the information needed to see it.

THIS RECORD DOES NOT OVERTURN THAT RULING. It is marked DO NOT RE-OPEN and the call belongs to the repository owner. 275 is still in research, which makes this evidence timely rather than too late. What is owed here:

1. Put the counterexample to the owner as an explicit question, with the ruling quoted as above, and record the answer.
2. Do not design a cross-repo gate, a global queue, or a global-ready schema before that answer exists. If the owner upholds the per-repo ruling, record what the system does instead about cross-repo collisions -- including "nothing, accepted risk, detected manually" if that is the answer -- rather than leaving the question open a second time.
3. If the owner amends the ruling, 275 owns the queue's scope and the amendment belongs there as a dated amendment note, not as a silent redefinition here.

A pointer to this record has been appended to 275's description so its researcher encounters the escalation in place. NO DEPENDENCY EDGE was added in either direction, deliberately: making this record wait on 275 would delay the evidence past the research it is meant to inform, and making 275 wait on this would stall a live research task. The relationship is an adjudication, not an ordering, and there is no file_scope overlap between the two as declared today.

=== DELIMITATION FROM THE ADJACENT RECORDS -- READ BEFORE CONCLUDING THIS IS A DUPLICATE ===

Three records exist because of the same structural split. None covers this one:

- 391 agent_system_task_siting_and_target_root owns (i) the authoring hole that lets an agent-system task be FILED in the wrong repository, and (ii) the open convention question of how a cross-repo task should DECLARE its file_scope so its own repo's overlap gate can see it. Both concern a single record's siting and declaration. THIS record concerns two CORRECTLY-sited actors colliding: 398 and 399 are correctly filed here, and a BimodalLogic session editing this repo's source store is the system working as designed, since that repo's .claude/ tree is deployed from here. 391's candidate remedy (c) -- stop filing source-store tasks in deploy-only repos -- would NOT have prevented this incident, because nothing involved was mis-filed.
- 390 migrate_mis_sited_agent_system_tasks is the data migration for records already mis-sited. Not a gate.
- 275, above, rules the queue's scope per-repo.

390's own manifest staleness is itself a symptom of cross-repo coordination being manual, and is worth citing as such. Measured 2026-10-13: its entry for BimodalLogic #768 records the title "lean-challenge-snapshot swallows declarations and mishandles Unicode names" at 5781 chars, while that record is now retitled "lean-challenge-snapshot swallows declarations, mishandles Unicode names, and over-reads Goals prose" at 15938 chars. Its list has also grown from seven items to ten -- #772 and #774 were added by its own "THREE MORE LEAKED IN" amendment section, so they are NOT missing from it -- and two further BimodalLogic records now name agent-system/** paths in file_scope while appearing in no item of that list: #778 residue_index_modulus_convention_record [PLANNED] and #783 bounded_block_edit_index_and_assert [NOT STARTED]. Re-verify these counts before repeating them; they drift by the week, which is itself the point being made.

=== SCOPE ===

In scope: stating the counterexample durably; running the escalation to an answer; and recording the outcome in the overlap predicate's own contract, so the next author reading it learns what that predicate does and does not see across repositories. context/patterns/file-footprint-overlap.md already carries a Non-Goals section, which is where a cross-repo limitation belongs whichever way the ruling lands.

Fix direction beyond that is DELIBERATELY OPEN and gated on the escalation. Do not pre-commit to a mechanism.

ACCEPTANCE. The counterexample recorded with its four verifiable citations (f49576632, 4311617a2, the two task numbers, the four entry ids). 275's ruling quoted verbatim and the owner's answer recorded, whichever way it falls. The overlap predicate's Non-Goals section stating the cross-repo limitation in terms a future author can act on. If a mechanism is adopted, its treatment of the record-less channel (a) dispatch named explicitly.

=== FILE SCOPE ===

Declared: context/patterns/file-footprint-overlap.md, scripts/orchestrate-predispatch-review.sh (both under agent-system/extensions/core/).

dependencies: [387]. Both footprint and substantive. 387 whole_tree_regeneration_scope_claim already declares context/patterns/file-footprint-overlap.md AND scripts/lib/file-scope-overlap.sh in its own file_scope, and it is reworking what a scope CLAIM means to the overlap predicate. Two writers redefining that same contract concurrently is exactly the unordered overlap the batching guardrails forbid, and a cross-repo visibility statement should be written against the claim semantics 387 settles rather than against the ones it is replacing. 313 also claims file-footprint-overlap.md and already depends on 387, so this edge places all three in one order.

CONDITIONAL -- ADD AT PLAN TIME ONLY IF THE ESCALATION'S ANSWER REQUIRES A MECHANISM: scripts/lib/file-scope-overlap.sh (claimed by 387; the edge above already covers it), skills/skill-orchestrate/SKILL.md and scripts/task-lock.sh (both claimed by 275 -- adding either requires an edge on 275, which the escalation's answer must settle first), and scripts/orchestrate-batch-admit.sh (claimed by 387).

=== NOT IN SCOPE ===

No repair of 398's or 399's data -- already annotated by commit 4311617a2; what remains for them is the index-entries.json leg each still owes, which their own descriptions name. No migration of records between repositories -- that is 390. No change to task siting or to the file_scope declaration convention -- that is 391. No redesign of the conclusion stage's channel derivation or its approval gates.

=== A SECOND, INDEPENDENTLY MEASURABLE CONSEQUENCE OF THE SAME INCIDENT (2026-10-13) ===
Beyond the duplicated work, the cross-repo dispatch left this repo's own index metadata
inconsistent with the files it had just written, and nothing detected that either. Commit
f49576632 added a line to agent-system/extensions/lean/context/project/lean4/README.md (now 32
lines), while agent-system/extensions/lean/index-entries.json still records line_count 31 for
path project/lean4/README.md. Both values measured 2026-10-13.
This is the same blind spot seen from the other side: the two records that declare
index-entries.json and would have carried the index update -- 398 and 399 -- sat [NOT STARTED]
while an actor they could not see edited the indexed files.
DO NOT REPAIR THAT line_count HERE. index-entries.json currently carries another session's
pending working-tree edit, so touching it in passing would clobber uncommitted work; and the
repair itself belongs to the index-entries.json leg that 398 and 399 each still owe, named in
their own descriptions. It is cited here strictly as evidence for this record's thesis.

---

### 400. Task-number allocation can desynchronize silently: no serialized allocator and no staleness check
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 379

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree, which is a gitignored, disposable deploy artifact regenerated from the source store -- see rules/source-store-deploy-boundary.md). Resolve source_dir from <project-root>/.claude-extensions.json and edit at the path mirroring the deployed one. REDEPLOY AFTERWARDS via deploy-headless.sh to RESULT=landed_verify_clean. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md) and no record-versioning language (rules/no-record-versioning-in-deliverables.md); both are permitted in this description and elsewhere in specs/**.

GOAL. Make the task-number allocation counter impossible to desynchronize silently: an allocation must not be able to produce a duplicate project_number, and a counter that has fallen behind the numbers actually in use must be detectable before it is used.

=== WHAT WAS OBSERVED (measured 2026-10-13, BimodalLogic consumer repo) ===

specs/state.json carried next_project_number = 781 while project numbers 781 (phase5_hoist_kernel_neutral_decision) and 782 (phase7_verts_shape_d_decomposition) were BOTH already present in active_projects -- two [RESEARCHED] lean4 sub-phase records. The next task creation read 781, allocated it, and briefly produced a DUPLICATE project_number 781. Recovery was manual: the colliding record was renumbered to 783 and the counter set to 784, after which validate-state.sh reported no duplicates. Post-repair state verified 2026-10-13: next_project_number = 784, max active project_number = 783, zero duplicate project_number values.

The recovery depended entirely on the colliding writer noticing. A writer that did not check would have left two records permanently sharing one number.

This would hit ANY path that allocates a number against that state file, not only an orchestrated one.

=== MECHANISM -- DIAGNOSED AND CONFIRMED AT THE SOURCE, NOT HYPOTHESISED ===

An earlier reading guessed the counter advance was keyed on task-directory creation, because 781 and 782 have no spec directories on disk. THAT READING IS REFUTED -- do not go hunting for a directory-keyed counter step, there is none. The confirmed mechanism, each leg verified 2026-10-13:

(1) Both records were created by commit 9110a99fc in BimodalLogic, "orchestrate conclusion: channel (c) follow-up tasks". Its diff touches specs/state.json and specs/TODO.md only, appends two active_projects rows, and changes next_project_number NOT AT ALL.

(2) context/contracts/conclusion-stage.md's Step 4c is the path that produced it. Step 4c states it reuses "the task-creation pattern already proven in skills/skill-spawn/SKILL.md's Stage 11", but it transcribes only the row-append half of that pattern. Its state-write.sh call consumes "$new_task_num", and manage-topics.sh set consumes it again, yet new_task_num is NEVER BOUND anywhere in the step -- and the step contains no next_project_number read and no next_project_number write.

(3) The pattern Step 4c cites does both halves: skills/skill-spawn/SKILL.md reads next_num=$(jq -r '.next_project_number' specs/state.json), and after its inserts writes '.next_project_number = $next' with $((next_num + task_count)). Step 4c dropped exactly that second half.

(4) Why a dropped increment is unrecoverable rather than merely untidy: scripts/state-write.sh, the single mutex-guarded writer that every specs/state.json read-modify-write in this codebase is meant to go through, HAS NO CONCEPT OF next_project_number AT ALL (measured: zero occurrences in the script). Allocation is therefore not serialized by the mutex that serializes the write. Every creating path re-implements read-then-increment in its own prose jq -- commands/task.md, commands/review.md, skills/skill-spawn/SKILL.md, skills/skill-fix-it/SKILL.md, skills/skill-project-overview/SKILL.md, agents/meta-builder-agent.md, and conclusion-stage.md Step 4c -- so any one of them that forgets, and any two that interleave between the read and the write, desynchronizes the counter with nothing to catch it.

(5) The missing spec directories are a SECOND, SEPARATE symptom of the same step, not the cause: Step 4c's commit stages "${new_task_dir_paths[@]}", an array the step never populates either.

=== THE DETECTION GAP, VERIFIED AGAINST THE SCRIPT ===

Read scripts/validate-state.sh directly rather than trusting this summary. As measured 2026-10-13 it does NOT check the counter against the numbers in use:

- Check 2 (base mode) tests only that next_project_number is PRESENT as a top-level field.
- Check 3's KNOWN_TOP_LEVEL_FIELDS names it, which is a field-name allowlist, not a value check.
- Check D1 compares active_projects[].project_number values against each other for uniqueness -- and is --deep-ONLY, so a base-mode run does not catch even an existing duplicate.
- Nothing anywhere compares next_project_number against max(project_number). That is the gap: the duplicate was reportable only AFTER it existed, and only under --deep.

=== PRIOR EVIDENCE OF THE SAME CLASS, ALREADY RECORDED ELSEWHERE ===

This is not a single incident. Task 390's acceptance criteria already record TWO earlier occurrences -- but as procedural warnings to its own implementer, not as a defect anyone owns closing: "a hand-created task in BimodalLogic needed an explicit counter bump afterwards"; and the two records filing that migration read next_project_number as 387, were written as 387 and 388, and collided with 387/388/389 created by a concurrent writer in the window between the read and the write, with that write also clobbering the other writer's own correct counter bump. Both were renumbered to 390 and 391 in repair.

That second case is the read-then-write RACE. A per-caller fix cannot close it; only allocation under the same mutex as the write can.

=== SCOPE: FIX DIRECTION DELIBERATELY OPEN ===

Candidates, to be assessed on their merits rather than adopted by reflex: a validation check; an allocation that derives the number from the max in use instead of a stored counter; an allocate action inside state-write.sh so allocation happens under the mutex that already guards the write; a repair mode; or defense in depth. If more than one layer is adopted, say why each earns its place rather than stacking them all.

WHAT IS NOT OPEN:

1. An allocation must not be able to silently produce a duplicate project_number.
2. A counter that has fallen behind must be detectable BEFORE it is used, not only after a collision already exists.
3. Any check must be ARCHIVE-AWARE. Numbers also live in specs/archive/state.json, and a naive max over active rows alone can re-issue an archived number. Measured in this repo 2026-10-13: the archive's true max is 392, held in completed_projects (328 entries), while archived_projects' own max is only 267 -- so a check that reads one of those arrays and not the other computes the wrong bound. Active max is 399 against a counter of 400, so the two ranges happen not to collide today; they will as soon as the high active numbers are archived and the active max falls below the archive max.
4. Whatever is added must be covered by scripts/tests/test-validate-state.sh (verified present 2026-10-13).

=== RELATIONSHIP TO 379, AND WHY THESE ARE NOT ONE RECORD ===

dependencies: [379]. The edge is BOTH footprint and substantive -- do not drop it.

FOOTPRINT: 379's entire declared file_scope is scripts/validate-state.sh and scripts/tests/test-validate-state.sh -- the same two files this record must edit. An unordered overlap on one file is precisely what the batching guardrails exist to prevent, so this edge serializes the two rather than racing two writers on one script.

SUBSTANTIVE: requirement 3 above needs the validator to read specs/archive/state.json, and 379 is the record that teaches it the archive's shape, or gives it an explicit --archive mode. Landing an archive-aware counter check on top of that avoids hand-rolling a second archive reader -- note that --deep's D3 dependency check ALREADY reads the archive's terminal arrays ad hoc, which is itself the duplication 379 exists to settle.

NOT FOLDED INTO 379, deliberately. 379's invariant is "an archive insert must be validatable by the standard gate"; this record's invariant is "the allocation counter cannot silently go stale". Different root cause (an unserialized, per-caller allocation versus an unknown archive shape), different blast radius (every path that allocates a number, versus /task --abandon's archive insert), and this record's fix extends past validate-state.sh into the allocator itself. Folding would bury a cross-command allocation defect inside an archive-shape record.

=== FILE SCOPE ===

Declared: scripts/validate-state.sh, scripts/tests/test-validate-state.sh, scripts/state-write.sh (all under agent-system/extensions/core/).

CONDITIONAL -- NARROW OR ADD AT PLAN TIME: if the chosen remedy rewrites the per-caller allocation sites instead of centralizing them, then commands/task.md, commands/review.md, skills/skill-spawn/SKILL.md, skills/skill-fix-it/SKILL.md, skills/skill-project-overview/SKILL.md, agents/meta-builder-agent.md and context/contracts/conclusion-stage.md each join the scope. Check before adding them: conclusion-stage.md and agents/meta-builder-agent.md are claimed by 391 (itself already serialized behind 369, 372 and 373 for that file), and commands/review.md is claimed by 313. Adding either requires the corresponding dependency edge, not a bare exclusion. If a new allocator script lands, name it and its test in the plan; do not pre-commit to them here.

=== NOT IN SCOPE ===

No repair of the BimodalLogic incident data -- already recovered and verified. No change to the vault-operation renumbering in skills/skill-todo/ beyond whatever a chosen allocator forces. No fix to Step 4c's unpopulated new_task_dir_paths array -- that is the separate directory-creation symptom named above, now filed as 402 conclusion_stage_4c_drops_allocation_and_dirs, which owns both of Step 4c's omissions and carries a dependency edge on this record.

=== CAUSAL CHAIN CLOSED TO THE ORIGINATING COMMIT (verified 2026-10-13) ===
The staleness that caused this incident was introduced by commit 9110a99fc in BimodalLogic,
"orchestrate conclusion: channel (c) follow-up tasks", Tue 2026-10-13 17:08:54. Measured across
that commit: at 9110a99fc^ next_project_number was 781 against max 780 -- CORRECT, one past the
max; at 9110a99fc it was still 781 against max 782 -- unchanged by the commit, and now TWO BEHIND,
pointing at an already-used number. Roughly 73 minutes later a conclusion-stage channel (b)
dispatch allocated from that counter, received 781, and collided. Recovery landed in 1e0fe3b40 at
18:22:04 (renumber to 783, counter to 784).

WHAT COMMITTED HISTORY DOES AND DOES NOT SHOW -- this governs how the class can be audited and
strengthens requirement 2 above. The duplicate NEVER APPEARS IN ANY COMMIT: checked every commit
from 9110a99fc to HEAD touching specs/state.json, and the duplicate set is empty at each, because
the collision lived only in the working tree and was repaired before the next commit. The only
durable trace in history is the stale counter itself, visible at 9110a99fc and still at a69b7ffcf
(18:04:40, next=781 against max=782). So a post-hoc audit of commits can detect a stale counter but
can NEVER detect the collisions it caused -- which is exactly why detection must fire before
allocation rather than after.

ARCHIVE BOUND CONFIRMED INDEPENDENTLY: requirement 3's figures were re-measured from both arrays by
a second reader with the same result -- completed_projects max 392 across 328 entries,
archived_projects max 267 across 48. The error of reading one array and concluding 267 is the bound
has now been made twice by two readers, which is the concrete failure mode requirement 3 exists to
prevent.

STEP 4c ITSELF IS FILED SEPARATELY as 402 conclusion_stage_4c_drops_allocation_and_dirs, which owns
repairing the step's two omissions (an unbound $new_task_num, and an unpopulated
new_task_dir_paths). That record carries a dependency edge on this one because Step 4c's repair must
CALL whatever allocation mechanism this record settles instead of adding a seventh hand-rolled
read-then-increment. Note the converse, which bounds this record's own remedy: adding an allocate
action to state-write.sh does NOT fix Step 4c, because that step has no allocation call at all to
route through it.

---

### 399. Record three measured lean4 gotchas: IO-forced timing harnesses, docstring/set_option order, and shadowed decide
- **Effort**: small
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: Task 398

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/lean/** (never a deployed .claude/** tree
-- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS via deploy-headless.sh. No
task-number references in any file landing under agent-system/**
(rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere
in specs/**.

PROVENANCE. Three gotchas distilled from one lean4 orchestration run in ~/Projects/BimodalLogic,
all from specs/716_sliced_certificate_liveat_nontermination/issues.jsonl:
 - GOTCHA 1: iss_1791886589088_do8mDR (class measurement, severity COSTLY, phase research,
   dispatch_seq 5)
 - GOTCHA 2: iss_1791914943297_AoBxvm (class syntax, severity minor, phase implement,
   dispatch_seq 8)
 - GOTCHA 3: iss_1791928136829_T0iDVg (class syntax, severity minor, phase implement,
   dispatch_seq 8)

GOAL. Record three concrete, measured Lean 4 gotchas in the lean4 context so the next agent does not
re-pay for them. Each already has a verified fix; this record is about SITING and WORDING them so
they are reachable, not about rediscovering them.

MEASURED, AND THE REASON THIS RECORD EXISTS: all three are genuinely absent from the lean extension
today. A grep across agent-system/extensions/lean/ finds NO occurrence of any Lean timing primitive
(monoMsNow, monoNanosNow, elapsed), and context/project/lean4/domain/lean4-syntax.md contains NO
occurrence of 'set_option', 'maxHeartbeats' or 'decide'. Re-verify before planning.

=== GOTCHA 1 -- A LEAN TIMING HARNESS MUST FORCE THE VALUE THROUGH IO BEFORE READING THE CLOCK ===
What happened: the first timing harness bound the measured value with a pure 'let' and read the
clock before any IO forced it. Lean floated the computation past the second clock read, so EVERY
STAGE REPORTED 0 ms and five probe rounds chased phantom hangs. Fixed by emitting the value through
an IO write before reading the clock.

This is the costly one of the three, and the only one whose cost was paid in wasted probe rounds
rather than a single failed build. The guidance should state the mechanism (a pure let is not a
forcing point; the clock reads straddle nothing) and the fix (force through IO -- e.g. an IO write
of the value -- between the two clock reads), because an agent that knows only "add an IO write"
without the mechanism will omit it the moment the harness shape changes.

ALSO WORTH DECIDING, BUT DO NOT LET IT SWALLOW THIS RECORD: the deeper lesson may be that a
hand-rolled harness was the wrong instrument at all, since the lean-lsp MCP server exposes
lean_profile_proof for per-theorem tactic profiling. MEASURED: neither lean_profile_proof nor
lean_run_code appears anywhere in context/project/lean4/tools/mcp-tools-guide.md, so that guide is
behind the server's actual tool set. Note this, and decide whether a one-line "prefer
lean_profile_proof for proof-cost questions" pointer belongs alongside GOTCHA 1. A general
reconciliation of mcp-tools-guide.md against the live MCP tool set is a SEPARATE, larger piece of
work -- record it as a follow-up rather than absorbing it here.

=== GOTCHA 2 -- DOCSTRING AFTER set_option ... in, NOT BEFORE; AND THE LINTER WANTS A REASON ===
What happened: a build failed because a docstring placed BEFORE 'set_option maxRecDepth ... in /
set_option maxHeartbeats ... in' is a parse error -- "unexpected token set_option; expected lemma".
The set_options must come first. Additionally, Mathlib's maxHeartbeats style linter requires an
explanatory comment between the set_option line and the declaration. Fixed in one edit; chained
'set_option ... in' lines are otherwise fine.

Record all three parts: the ordering, the exact parse error text (so the next agent recognises it
from the build log rather than re-deriving it), and the linter's explanatory-comment requirement.
The "chained set_option ... in lines are otherwise fine" clause is worth keeping -- it forecloses
the wrong over-correction.

=== GOTCHA 3 -- `decide` CAN BE SHADOWED, AND `_root_.decide` IS NOT THE ESCAPE HATCH ===
What happened: a plan's recorded body used 'decide (p.1 = t)', which does not elaborate inside
FormalSystem.Metalogic.Decidability, because DecisionProcedure.lean defines its own
'decide (phi : Formula)' in that namespace, shadowing core Decidable.decide. '_root_.decide' is NOT
a valid identifier either -- core decide is Decidable.decide, exported. The fix used 'p.1 == t'
(BEq on the integer type): same Boolean test, no statement change.

The generalisable content is the pair: (i) an exported core name can be shadowed by a
same-named definition in the local namespace, and (ii) '_root_.foo' does not recover an EXPORTED
name, because the name's real home is its defining namespace. That second half is the part an agent
will otherwise get wrong twice. Keep the concrete FormalSystem example as the illustration, but
state the general rule -- this file lives in a shared source store deployed to repositories that do
not have a FormalSystem namespace at all.

=== SITING: ASSESS AND DECIDE, DO NOT ASSUME ===
Three gotchas of two different natures, and there is no existing gotchas file in the extension.
 (a) GOTCHAS 2 and 3 are syntax/elaboration and have an obvious home in
     context/project/lean4/domain/lean4-syntax.md, whose index entry already declares
     load_when.agents = ["lean-research-agent", "lean-implementation-agent"] -- i.e. it already
     reaches both agents that could trip these. Strong argument for putting them there.
 (b) GOTCHA 1 is measurement, not syntax, and does not belong in a syntax file.
     context/project/lean4/operations/long-builds.md is the nearest existing anchor but is a poor
     fit on inspection: it owns the EXTERNAL detach-and-guard contract for wall-clock build
     management, not in-Lean measurement harnesses. Forcing GOTCHA 1 in there would blur a file
     that currently has one clean responsibility.
 (c) A new context file under context/project/lean4/ for measurement gotchas. NOTE, in favour of
     feasibility: manifest.json's provides.context is DIRECTORY-level ("project/lean4",
     "contracts"), so a new file under that directory needs NO manifest change. It DOES need a new
     index-entries.json entry carrying path, line_count, load_when, domain, subdomain, summary and
     keywords -- match the shape of the existing entries exactly, and note that load_when's allowed
     keys are only agents, commands, task_types and always (core's check-extension-docs.sh Rule T
     rejects anything else).
 (d) One combined gotchas file for all three. Simplest to find; weakest cohesion.
Decide, and record why the rejected sitings were rejected. A split outcome -- (a) for two and (c)
for one -- is a perfectly acceptable answer and is the one the natures suggest.

=== WHAT IS OWED ===
- All three gotchas recorded with their MECHANISM and their verified FIX, not just the symptom.
- GOTCHA 2's exact parse-error text preserved verbatim, so it is greppable from a build log.
- GOTCHA 3 stated as a general rule about exported-name shadowing, with the concrete case as
  illustration -- not as a FormalSystem-specific note, since this source store deploys elsewhere.
- Siting decided per gotcha, with rejected options recorded.
- index-entries.json consistent afterwards: a new entry if a file was added, and a corrected
  line_count for every indexed file whose length changed.
- The mcp-tools-guide.md staleness either addressed by a one-line pointer or recorded as a
  follow-up, explicitly.

=== NOT IN SCOPE ===
No reconciliation of mcp-tools-guide.md against the full live MCP tool set (follow-up). No change to
long-builds.md's detach-and-guard contract. No change to the heartbeat or recursion-depth limits
themselves, nor any policy about when raising them is acceptable. No new scripts, hooks or linters:
this record adds context, not enforcement.

=== DEPENDENCY RATIONALE (ordering constraint, not a logical prerequisite -- do not drop the edge) ===
dependencies: [398]. This record and both siblings in the chain edit
agent-system/extensions/lean/index-entries.json, whose entries carry a recorded line_count that any
edit to an indexed file invalidates; this record may additionally ADD an entry there. The edge
serializes the writers on that one file rather than racing them. Nothing in this record's substance
waits on the siblings' conclusions.

=== FILE SCOPE ===
agent-system/extensions/lean/context/project/lean4/domain/lean4-syntax.md,
agent-system/extensions/lean/index-entries.json, plus any new context file created under
agent-system/extensions/lean/context/project/lean4/ should siting (c) be chosen. If
context/project/lean4/README.md indexes the new file, or a pointer lands in
context/project/lean4/tools/mcp-tools-guide.md, those join the scope -- WIDEN FILE SCOPE BEFORE THE
EDIT rather than writing outside it. NARROW AT PLAN TIME once siting is decided.


=== ALREADY LANDED IN THE SOURCE STORE -- RE-VERIFY BEFORE PLANNING (appended 2026-10-13) ===
All three gotchas are already committed, from the IDENTICAL three issue-log entries cited above.
Commit f49576632 ("lean: record four Lean 4 measurement and syntax gotchas") landed:
 - GOTCHA 1 (iss_1791886589088_do8mDR) in a NEW file,
   context/project/lean4/patterns/measurement-harness-strictness.md -- i.e. siting option (c) --
   registered in context/project/lean4/README.md.
 - GOTCHA 2 (iss_1791914943297_AoBxvm) as a "## Common Pitfalls" section in
   context/project/lean4/domain/lean4-syntax.md.
 - GOTCHA 3 (iss_1791928136829_T0iDVg) as a Pitfall callout under the existing decide entry in
   context/project/lean4/patterns/tactic-patterns.md -- a file NOT in this records file_scope.
THE "MEASURED" PREMISE ABOVE IS NO LONGER TRUE: lean4-syntax.md now DOES contain set_option,
maxHeartbeats and decide. Re-verify exactly as that paragraph already instructs rather than
trusting it. This record owned the SITING decision; that decision has been made as option (c).
What remains genuinely undone: the index-entries.json leg was NOT updated, and READMEs recorded
line_count there is now stale (claims 31, actual 32).

---

### 398. Record that a grep for dependents misses rw-site definitional unfolding, and make that guidance reachable at plan time
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: Task 397

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/lean/** (never a deployed .claude/** tree
-- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS via deploy-headless.sh. No
task-number references in any file landing under agent-system/**
(rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere
in specs/**.

PROVENANCE. Distilled from a lean4 orchestration run in ~/Projects/BimodalLogic:
specs/716_sliced_certificate_liveat_nontermination/issues.jsonl entry iss_1791921588196_IcZKne
(class scope, severity minor, phase implement, dispatch_seq 8).

GOAL. Record that a grep for dependents is not a blast-radius tracer -- it misses rw-site
definitional unfolding -- and make that guidance actually REACHABLE at plan time, which is where the
scope hypothesis it must correct is formed.

=== WHAT HAPPENED (verbatim substance of the cited entry) ===
A phase's blast radius was one file wider than the plan-time grep found. FixtureStable.lean carries
'rw [untlLive]'; after the definitional switch that unfolded to lfp' and made EUFix.lfp_induction
unify through lfp', hitting the 200000-heartbeat whnf timeout. FixtureStable.lean is NOT a direct
dependent of LiveFix.lean, so 'grep -rln PlusSlicedCertificate.LiveFix' did not surface it. The
complete repair set (3 sites in 2 files) was found only by a repo-wide grep over ALL TWELVE
definitional-unfold spellings. That last clause is the actual working recipe and is the most
valuable thing in this entry -- it belongs in the guidance as a concrete probe, not as a moral.

=== WHY THIS IS THE RIGHT HOME, AND WHAT IS ALREADY THERE ===
context/project/lean4/patterns/dependency-tracing.md is the natural target: it already exists for
exactly this genre of correction. Re-read before planning; structure is as of this record's
creation.
 - It opens with "## The Load-Bearing Caveat: `#print axioms` Is Not a Dependency Tracer" -- the
   same shape as this finding ("a grep for dependents is not a blast-radius tracer"). Prefer
   extending that framing over inventing a new one.
 - It carries "## Four Probe Shapes" (Shape 1 Forward Transitive Closure, Shape 2 Module-Index
   Variant, Shape 3 Whole-Environment Reverse-Dependency Scan, Shape 4 Import-Closure Check), then
   "## Two Operational Notes" and "## Usability Without the Originating Repository". The
   twelve-spelling repo-wide unfold grep is a natural fifth probe shape. If it is added as one, the
   section heading and any count in the prose must be updated together -- "Four Probe Shapes" with
   five shapes under it is the obvious way to get this wrong.
 - MEASURED: the file contains no occurrence of 'rw', 'unfold', 'whnf' or 'heartbeat'. This case is
   genuinely absent, not merely under-emphasised.

=== THE LOAD-BEARING SECOND HALF: REACHABILITY AT PLAN TIME ===
Adding the caveat to that file is NOT sufficient, and a plan that stops there has not discharged
this record. The finding is about a PLAN-TIME scope hypothesis, and it is not established that the
planning agent ever sees this file.

MEASURED, in the lean extension's own wiring (re-verify, do not trust these as still current):
 - manifest.json routing_agents.plan.lean4 = "planner-agent" -- the CORE planner, not a lean-owned
   agent. routing_agents_hard has NO plan key at all, so hard-mode lean4 plans route to the same
   core planner.
 - index-entries.json's entry for project/lean4/patterns/dependency-tracing.md declares
   load_when.agents = ["lean-implementation-agent"] -- implementation only -- and
   load_when.task_types = ["lean4"].
 - Across all 41 entries in that file, NOT ONE names a planner agent in load_when.agents.

WHAT IS NOT ESTABLISHED, AND MUST BE DETERMINED FIRST: load_when's allowed keys are agents,
commands, task_types and always (enforced by core's check-extension-docs.sh Rule T), and agents and
task_types are INDEPENDENT match axes. So a lean4-typed task could plausibly discover this file via
task_types even though no entry names a planner. Which axis actually governs discovery at plan
dispatch is the open question. Note that context loading in this system is agent-driven -- agents
query index.json on demand rather than being fed by a mechanical injector (there is no runtime
injection script in core/scripts; the context-* scripts there are validators and reachability
auditors, not resolvers). So the answer likely lives in planner-agent's own instructions and in how
index.json is queried, not in a selector script. ESTABLISH THIS BY READING, then choose the remedy.

Candidate remedies, to assess on their merits once the above is settled:
 (a) Add the planning agent to load_when.agents on this entry. Narrowest, if the agents axis is
     what governs.
 (b) Rely on the task_types axis and instead fix whatever prevents the planner from querying it.
     Broader, and fixes the whole class rather than one file -- but may be out of this record's
     scope; if so, record it as a follow-up rather than half-doing it.
 (c) Put a short plan-time pointer wherever the planner demonstrably does read, pointing AT
     dependency-tracing.md rather than restating it.
 (d) Conclude the planner already reaches it and the real gap was that the file lacked the rw case.
     A legitimate outcome -- but only if established by reading, not assumed by convenience.

=== WHAT IS OWED ===
- The rw-site definitional-unfold case is recorded in dependency-tracing.md, with the
  twelve-spelling repo-wide grep as a concrete probe rather than an exhortation.
- Section headings and any probe counts in that file remain internally consistent after the edit.
- The plan-time reachability question is SETTLED BY READING and the chosen remedy stated, or
  explicitly recorded as out of scope with a reason -- not left implicit.
- Rejected candidate remedies recorded with the reason.

=== NOT IN SCOPE ===
No change to the four existing probe shapes' mechanics. No change to the core planner-agent's own
contract beyond a pointer, should (c) be chosen -- a restructuring of plan-stage context discovery
for all extensions is a far larger piece of work and must be recorded as a follow-up rather than
absorbed here. No heartbeat-limit or build-timeout policy change.

=== DEPENDENCY RATIONALE (ordering constraint, not a logical prerequisite -- do not drop the edge) ===
dependencies: [397]. Both records edit agent-system/extensions/lean/index-entries.json, whose
entries carry a recorded line_count that any edit to an indexed file invalidates. The edge
serializes the two writers on that one file rather than racing them. Nothing in this record's
substance waits on the other's conclusions.

=== FILE SCOPE ===
agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md,
agent-system/extensions/lean/index-entries.json. If remedy (c) is chosen, the file carrying the
plan-time pointer joins the scope; WIDEN FILE SCOPE BEFORE THE EDIT rather than writing outside it.


=== ALREADY LANDED IN THE SOURCE STORE -- RE-VERIFY BEFORE PLANNING (appended 2026-10-13) ===
The substance of this record is already committed. Commit f49576632 ("lean: record four Lean 4
measurement and syntax gotchas") added a "## Grep-Based Blast Radius: Cover Unfold Spellings, Not
Just Importers" section to context/project/lean4/patterns/dependency-tracing.md -- this records own
declared file -- derived from the IDENTICAL issue-log entry iss_1791921588196_IcZKne. It was
produced by an orchestrate conclusion-stage channel (a) dispatch running in ~/Projects/BimodalLogic,
which has no visibility into this task space: no dependency edge and no file_scope overlap gate
spans the two repositories, so the duplication was not detectable at dispatch time.
READ dependency-tracing.md BEFORE PLANNING. What remains genuinely undone: the
agent-system/extensions/lean/index-entries.json leg was NOT updated.

---

### 397. Require a lean research report's recommended compiled artifact to be compile-verified before it is recommended
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/lean/** (never a deployed .claude/** tree
-- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS via deploy-headless.sh. No
task-number references in any file landing under agent-system/**
(rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere
in specs/**.

PROVENANCE. Distilled from a lean4 orchestration run in ~/Projects/BimodalLogic:
specs/716_sliced_certificate_liveat_nontermination/issues.jsonl entry iss_1791910769494_DQ3Vjd
(class research-gap, severity COSTLY, phase plan, dispatch_seq 7). This is the costly one of the
five findings that run produced, and the only one warranting a contract change with teeth.

GOAL. Make a lean research report's primary recommendation executable as written, by requiring that
a recommended compiled artifact be compile-verified BEFORE it is recommended -- rather than leaving
the first mechanical check to plan time, where correcting it costs a full plan-time round.

=== WHAT HAPPENED (verbatim substance of the cited entry) ===
A research report's recommendation 1 was "land certA as the C36 Tier-2 inventory row". Plan-time
mechanical check found it not executable as written: C36b's c36Sliced interest expression requires a
formula of the claimed kind to occur in G.slab t w, and certA's slice labelling carried only
'atom p', so c36Sliced evaluates FALSE for snce, stab and imp alike -- verified by compiled #eval
against the built library. The row would have failed the gate. The plan therefore had to carry a
slab-carrying variant of certA plus a decision gate rather than the report's bare "add the row"
step. The defect was caught, but only one phase downstream, at the cost of a full plan-time
correction round.

=== WHY THE CURRENT CONTRACT DOES NOT CATCH IT ===
Re-verify each of these before planning; they are as of this record's creation and will drift.

(1) agents/lean-research-agent.md already carries exactly the right KIND of clause under
    "## Research Constraints for Lean Tasks" -- the "### Zero-Debt Policy Compliance" subsection,
    with explicit FORBIDDEN Recommendations and REQUIRED Approach lists. That is the structural
    precedent for a contract with teeth on what this agent may recommend. There is no comparable
    clause requiring that a recommendation be mechanically checked.
(2) The report template in the same file emits recommendations under a bare "### Recommendations"
    heading whose only guidance is "{Implementation approaches, including whether a sorry-free path
    exists}". context/project/lean4/agents/lean-research-flow.md's Stage 5 template has the same
    bare "## Recommendations" section. Neither asks for evidence.
(3) NO TOOL-GRANT CHANGE IS NEEDED, and this is load-bearing for feasibility: that agent already
    holds the means to run the check. Its "### Build Tools" and "### Lean MCP Tools (via lean-lsp
    server)" sections already grant lake build plus lean_run_code, lean_verify, lean_multi_attempt
    and lean_build. The gap is contractual, not capability.
(4) THE PRECEDENT TO EXTEND, NOT INVENT: that same report template already contains a
    "## Tactic Survey Results" table with a Result column carrying measured success/fail values,
    produced under the existing "### Tactic Discovery Survey Protocol". So "a recommendation backed
    by a compiled result recorded in the report" is already an established shape in this agent's
    output. Prefer extending that shape over introducing a parallel mechanism.

=== THE HARD PART: SCOPING THE TRIGGER (assess and decide, do not assume) ===
A naive reading -- "compile-check every recommendation" -- is ruinous and must be rejected: a report
routinely cites dozens of Mathlib declarations it has no business building. The trigger must be
narrow enough to be honest and cheap. The cited failure has a specific shape: the report recommended
LANDING a concrete artifact whose acceptance is decided by a COMPILED PREDICATE over that artifact
(the inventory-row gate). Candidate triggers to evaluate on their merits:

 (a) Recommendation names a concrete artifact to be added/landed AND an existing compiled gate,
     predicate, #eval or decision procedure determines whether it is accepted. Narrowest; keys on
     exactly the measured failure mode.
 (b) Any recommendation whose correctness is decidable by a bounded mechanical check the agent can
     already run. Broader; risks unbounded reading of "bounded".
 (c) Only the report's PRIMARY recommendation, whatever its shape, must carry a mechanical result.
     Cheapest to state and to audit; may miss a non-primary recommendation with the same defect.
Decide which, say why the others were rejected, and state the trigger in terms an agent can apply
without judgement calls.

=== ALSO TO DECIDE ===
- WHAT THE AGENT DOES WHEN THE CHECK FAILS. The cited case is instructive: the right outcome was not
  silence but a DIFFERENT recommendation (a slab-carrying variant plus a decision gate). So the
  clause should require reporting the negative result and revising the recommendation, not merely
  suppressing it. Note the structural parallel to the Zero-Debt section's item 3, which already
  handles "no acceptable approach found" by requiring the finding be documented and the task marked
  [BLOCKED] for review rather than papered over.
- WHERE THE RESULT IS RECORDED so the planner can see it. A recommendation whose check passed and a
  recommendation that was never checked must not be indistinguishable in the report.
- WHETHER THE GATE IS ALWAYS-ON OR HARD-MODE-ONLY. agents/lean-research-hard-agent.md and
  context/contracts/reference-grounding.md (the H3 reference-grounding contract) already impose
  stronger evidence duties in hard mode. Decide whether this clause belongs in the always-on
  research contract or only in the hard variant, and keep the two agent files from contradicting
  each other either way. Weigh that the cited entry records a COSTLY outcome, which argues for
  always-on.
- WHETHER lean-research-flow.md IS THE PRIMARY EDIT TARGET. It is the shared flow; if the clause
  lands only in the agent files they will drift from it.

=== WHAT IS OWED ===
- A stated, narrowly-scoped trigger for when a recommended artifact must be compile-verified before
  it is recommended, applicable without judgement calls.
- A stated obligation on the failing case: report the negative result and revise the recommendation.
- The report template carries the mechanical result where the planner will see it, distinguishably
  from an unchecked recommendation.
- The always-on vs hard-mode-only question decided and recorded, with the two agent files and the
  shared flow left mutually consistent.
- Rejected candidate triggers recorded with the reason.

=== NOT IN SCOPE ===
No change to the Zero-Debt Policy, the Literature Extraction Protocol, or the Tactic Discovery
Survey Protocol beyond extending the survey's evidence shape if that is the chosen mechanism. No
change to the research agent's tool grant (point 3 above: it already suffices). No change to the
implementation-side guidance -- that is the sibling record #396's territory, which revises
phase-commit and plan-splice guidance in the three implementation-side files and does not overlap
this record's file scope. No new scripts or hooks.

=== FILE SCOPE ===
agent-system/extensions/lean/agents/lean-research-agent.md,
agent-system/extensions/lean/agents/lean-research-hard-agent.md,
agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md,
agent-system/extensions/lean/index-entries.json (the research-flow file is indexed there with a
recorded line_count that any edit invalidates). NARROW AT PLAN TIME: if the clause lands always-on
only, the hard-agent file may drop out. The two sibling records in this chain also declare
index-entries.json; see their DEPENDENCY RATIONALE.

---

### 396. Lean phase commit full build and plan anchor
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: Task 376

**Description**: Add two explicit guidance items to the lean implementation agent guidance in the lean extension source store, both distilled from task 762's implementation (provenance: specs/762_hit_presented_general_row/issues.jsonl entries iss_1791860085296_Yr2gXO and iss_1791862806295_NnFCBA, both severity minor, phase implement, dispatch_seq 3).

ITEM 1 -- A phase commit is gated on the FULL library build, not a module-scoped build.
What happened (iss_1791860085296_Yr2gXO): a module-scoped build of Periodic.lean passed while the full library build failed, because the newly introduced `dualStructure` clashed with `WeakCanonical.dualStructure` in GroupModel/MonoDiscrete.lean -- the same construction under the same name in another module. A scoped build cannot see cross-module name clashes or downstream breakage; only the full `lake build` can. Guidance to add: the phase commit is gated on a full `lake build` of the whole library, not on `lake build Module.Name`.

CRITICAL -- this REVISES guidance that currently says the opposite, in three places; it is not a pure addition. Re-read each before planning, line numbers are as of this task's creation and will drift:
  (a) agents/lean-implementation-agent.md -- the MUST DO list item "Prefer `lake build Module.Name` for phase-end verification -- scoped is less work, not ..." (~L738) and the following item scoping full `lake build` to "final verification only" (~L740); the MUST NOT list item stating "scoped `lake build Module.Name` is acceptable for phase-end; only full `lake build` is mandatory at the final stage" (~L754-755); and the per-phase commit section "For each phase in the implementation plan, commit after completing it" (~L672-690).
  (b) agents/lean-implementation-hard-agent.md -- the inline comment "Scoped build for current module -- less work, not categorically safe" (~L238), the phase-commit git-commit-scoped.sh call that follows (~L272), and the MUST DO item "Run full lake build before returning implemented status" (~L779).
  (c) context/project/lean4/agents/lean-implementation-flow.md -- section "Phase-End Verification" and the note "Per-step verification uses `lean_goal` + `lean_verify`. Phase-end uses `lake build Module.Name`. Only this final stage requires full `lake build`." (~L107-128). This file is the shared flow both agents reference, so it is the primary edit target; the two agent files must not be left contradicting it.

Preserve the orthogonal constraint these files already carry and that this change must not weaken: every `lake build` runs DETACHED via `Bash(run_in_background: true)` routed through the build guard, never as a plain foreground Bash call (see context/project/lean4/operations/long-builds.md). Gating the phase commit on a full build makes the detached-build requirement MORE load-bearing, not less -- a full build is slower than a scoped one. Any added guidance should name the cost explicitly so the tradeoff is a recorded decision rather than an accident.

ITEM 2 -- A plan-file section edit anchors on the heading's own LINE, searching forward from the section start.
What happened (iss_1791862806295_NnFCBA): a plan-file section splice used the bare string '## Lean Challenge Statements' as its end anchor; that same string also occurs in the Goals prose earlier in the file, so the splice matched the earlier occurrence and duplicated 752 lines (commit 83085ed7e). Recovery required `git show` against the prior commit and a re-apply with an anchor searched forward from the phase heading (commit f0ef67f81). Guidance to add: a section edit anchors on a LINE that begins with the heading markers (e.g. a line starting `## ` or `### `), and searches FORWARD from the target section's start -- never on a bare substring that may recur in prose elsewhere in the file.

Natural homes, alongside the plan-file write-authority guidance these files already carry:
  (a) agents/lean-implementation-agent.md -- near the Edit-tool phase-marker instructions (~L120-125) and/or the MUST NOT item delimiting plan-file write authority to "`### Phase N: ... [MARKER]` headings and `- [ ]` checklist items" (~L780).
  (b) agents/lean-implementation-hard-agent.md -- near the "Mark Phase In Progress" / "Mark Phase Complete" steps (~L210, ~L253) and the corresponding write-authority MUST NOT item (~L805).
  (c) context/project/lean4/agents/lean-implementation-flow.md -- the phase-marker update steps (~L81, ~L117).

Consider whether ITEM 2 is lean-specific at all: the failure mode is generic to any agent that splices sections of a markdown plan file. If a shared home in the core extension is the better target, that is an acceptable outcome of planning -- but then the lean files should point at it rather than restate it, and file_scope must be widened before the edit (do not silently write outside file_scope).

BOUNDARY: all edits land in the SOURCE STORE under agent-system/extensions/, never in a deployed .claude/** tree (see rules/source-store-deploy-boundary.md). The deployed copies in consumer repos are regenerated from these sources.

---

### 395. Surface failed per cycle commit into task status
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 394

**Description**: Surface a failed per-cycle scoped commit into the DISPATCHED TASK's own status (not merely its issues.jsonl entry) when git-commit-scoped.sh exits a loud, attributable code (2/3/4/5/6) at orchestrate-cycle-postflight.sh's WORK (i) commit call site.

Task 304 added the exit-code branch, a named ERROR on stderr, an issue-record.sh entry, and the emitted verdict JSON's own note field -- but deliberately left verdict/halt/every status write untouched. Reason, recorded so this task does not re-derive it: verdict is resolved (~line 1551 at task 304's implementation time) and WORK (f)'s status write already lands (~line 1264) HUNDREDS OF LINES before WORK (i)'s commit call (~line 1835) in orchestrate-cycle-postflight.sh, and the monotonic-max machinery that governs status transitions prevents a later demotion by construction.

SCOPE: close this residual via either (a) reordering WORK (f) and WORK (i) so the commit's own outcome is known before the status write commits, or (b) a sanctioned, narrowly-scoped write out of a terminal completed state when -- and only when -- the per-cycle commit for THAT SAME dispatch window demonstrably failed. If a task's commit genuinely failed, the honest outcome is [PARTIAL] with a named blocker, never [COMPLETED] -- this is the HARD CONSTRAINT task 304's own dispatch named but explicitly scoped out as a larger design change belonging to other work on these files. Re-read orchestrate-cycle-postflight.sh's current structure before planning either option; six-plus live tasks contend on this file and line numbers will have moved.

---

### 394. File scope containment chokepoint for scoped commit
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: Specify and implement a file_scope-based containment chokepoint for git-commit-scoped.sh / git-commit-phase.sh.

Task 304's V9 gate drops a pathspec whose resolved parent lies OUTSIDE THE REPOSITORY -- it says nothing about a pathspec that is inside the repository but outside the DISPATCHING TASK's own declared file_scope. That narrower containment question is the original, still-unimplemented specification left by an earlier task: specs/archive/336_phase_commit_staging_has_no_scope_check/evidence/03_followup-mechanical-check.md. Read that evidence file first; it is the authoritative starting point, not this description.

Exception code 7 is RESERVED for this follow-up in context/standards/git-staging-scope.md's exit-code table (reserved by task 304) -- read that table before proposing any new exit code; 0-6 are already claimed by other gates. Decide: a genuinely new exit code, or a deliberately and explicitly reused one -- the archived evidence file leaves this open to this task's own research, and it is still open.

Also read task 304's own landed exit-code table and V9 gate (git-commit-scoped.sh's header) before proposing any change to that script -- both tasks' records name task 304 as the one that landed the current exit-code contract this task must extend, not contradict.

---

### 393. Propagate modified files constraint to silent agents
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: Propagate the modified_files repo-relative-paths constraint (context/formats/return-metadata-file.md) to the implementation agents that never mention the field.

Re-derived 2026-10-12 via `grep -L 'modified_files' agent-system/extensions/*/agents/*implementation-agent.md` (superseding an earlier carried count of 9 of 13): 10 of 14 implementation agents never mention the field at all -- books, cslib, pr-review (cslib), latex, lean, python, rust, typst, web, z3. Only general-implementation-agent.md, email, nix, and neovim document the constraint. Re-run that grep at implementation time; the list may have grown or shrunk since this was filed.

This is the ROOT CAUSE of the incident task 304 contained (an absolute out-of-repository path in modified_files aborting a whole scoped commit): the producing agent that emitted the offending entries was never shown the constraint its own definition omits. Task 304 added a drop-and-warn containment gate (V9) in git-commit-scoped.sh plus a caller-side exit-code branch, so a violation is no longer destructive -- but the field will keep carrying violations until every producer is told the rule.

SCOPE: add the repo-relative-paths constraint (mirroring general-implementation-agent.md's existing wording -- Path form, Granularity, Empty behavior) to each of the 10 silent agents' own Critical Requirements / contract sections. Verify each agent still emits a well-formed modified_files field afterward (its own test fixtures if any exist, or a manual dry run).

---

### 391. Close the target_root authoring hole that files agent-system tasks into the wrong repository
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 369, Task 372, Task 373

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree
-- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS via deploy-headless.sh. No
task-number references in any file landing under agent-system/**
(rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere
in specs/**.

GOAL. Close the authoring hole that let agent-system tasks be created in the wrong repository
without tripping anything, and settle the adjacent open question of how a cross-repo task should
declare its file_scope.

=== DEPENDENCY RATIONALE (user ruling, load-bearing -- do not drop the edge) ===
dependencies: [372, 373]. Both of those records already declare
agent-system/extensions/core/context/contracts/conclusion-stage.md in their own file_scope, and
this record must edit that same file. The edge serializes this record after them rather than
racing a third concurrent writer on one file. It is an ordering constraint, not a logical
prerequisite -- nothing in this record's substance waits on their conclusions.

=== ROOT CAUSE, AS DIAGNOSED 2026-10-11 ===
/meta is global-by-default. commands/meta.md's "Target Resolution" section resolves GLOBAL_ROOT and
threads it end-to-end as target_root, with --local the only opt-out. But the orchestrate conclusion
stage's channel (b) does NOT go through /meta: context/contracts/conclusion-stage.md's Step 4b
dispatches meta-builder-agent DIRECTLY via the Agent tool. Verified by reading that step -- it
gates on orchestrate-conclusion-aggregate.sh --check-approval, then dispatches the agent with
collected_answers.confirmed: true and the assembled change request, and says nothing about
target_root. That path never resolves it, so the agent defaults to the session's working directory
and files agent-system tasks into whatever repository /orchestrate happened to be running in.

That is exactly how four agent-system records came to sit in ~/Projects/BimodalLogic (the
lake-build-guard, lean-challenge-snapshot, plan-format and postflight-issue-entry records, now
being relocated by the sibling migration record). Nothing caught it because
context/standards/source-store-deploy-boundary-narrative.md governs only where EDITS land and
explicitly EXEMPTS specs/** from its scope -- so no rule checked the task's own siting. Any other
caller that dispatches meta-builder-agent directly has the same hole; enumerate them rather than
assuming Step 4b is the only one.

=== CANDIDATE REMEDIES -- ASSESS AND DECIDE, DO NOT ASSUME THE ANSWER ===
These are candidates to be evaluated on their merits, not a predetermined plan. Note that defense in
depth may warrant adopting more than one; if so, say why each layer earns its place rather than
stacking all three reflexively.

(a) TEACH STEP 4b TO RESOLVE target_root and pass it in its dispatch body, the way
    skills/skill-meta/SKILL.md's Section 4 already does. Narrowest fix; closes the known instance
    and nothing else.

(b) MAKE meta-builder-agent ITSELF RESOLVE GLOBAL_ROOT rather than trusting the working directory.
    The durable fix, since it protects every caller including ones not yet written. Note that
    skill-meta's own Section 4 already acknowledges this gap: it records that the
    path-qualification instruction "is carried by the prompt today" and that making it durable in
    agents/meta-builder-agent.md is a dependent follow-up. THIS RECORD IS THAT FOLLOW-UP. Weigh the
    interaction with --local: whatever this agent resolves must not override an explicit local-mode
    target handed down by skill-meta.

(c) A STANDING RULE ON WHICH REPOSITORY AN AGENT-SYSTEM TASK IS FILED IN at creation time, closing
    the specs/** exemption blind spot. Decide where it lands -- rules/source-store-deploy-boundary.md
    and/or context/standards/source-store-deploy-boundary-narrative.md -- and note that the
    narrative's existing specs/** exemption exists for a reason (task artifacts legitimately live
    outside the source store), so the rule must distinguish "a task's artifacts may live in
    specs/**" from "a task whose edit target is the source store must be filed in the repo that
    owns it". Do not simply delete the exemption.

=== ALSO IN SCOPE: HOW SHOULD A CROSS-REPO TASK DECLARE ITS file_scope? ===
READ THIS SECTION'S FRAMING CAREFULLY. An earlier reading of the six mis-sited BimodalLogic records
treated their .claude/** file_scope entries as an unchallenged authoring defect. THAT READING WAS
WRONG and is corrected here, so that no implementer goes hunting for an authoring gap that does not
exist. What remains is a genuine, narrower, unsettled convention question.

MEASURED 2026-10-11. Six BimodalLogic records declare a deployed .claude/** path in file_scope:
#752 and #753 name .claude/** paths only; #767, #768, #769 and #770 each name BOTH a .claude/**
path and its agent-system/** source counterpart. But all six also carry an explicit
"SOURCE-STORE BOUNDARY" paragraph which resolves source_dir from .claude-extensions.json, names the
agent-system/** path as the edit target, requires a redeploy via deploy-headless.sh with
RESULT=landed_verify_clean, and states in terms that the .claude/** paths "are declared only so the
admission overlap gate can see the collision surface; they are NOT the edit target." The convention
is deliberate, uniformly applied across all six, and correctly reasoned for its own repository: the
overlap gate there runs over a tree in which the deployed paths are the only ones that exist, so
declaring the source path alone would make the record invisible to that gate.

So there is NO "passed unchallenged" authoring slip to fix, and rules/source-store-deploy-boundary.md
-- a target-path rule about where writes land -- is arguably not violated by a declaration made for
gate visibility rather than for editing. THE OPEN QUESTION IS WHETHER THAT CONVENTION IS RIGHT, and
it is open because this repo's own comparable records answer it the other way: the
roadmap-generator, conclusion-report-block and null-resolution records here all declare
source-store paths ONLY, with no deploy-path entry of any kind. Two coherent conventions coexist
across the two repositories with nothing adjudicating between them.

DECIDE AND RECORD, rather than normalising by reflex:
- Is a deploy-path file_scope entry declared purely for overlap-gate visibility legitimate, or does
  it overload a field whose contract is "files this task edits"?
- If legitimate, does the overlap gate need a way to distinguish an edit target from a declared
  collision surface -- a second field, a marker, or a documented convention -- so the two readings
  are not conflated?
- If not legitimate, what makes a source-store-targeting task visible to the deploy repo's overlap
  gate instead, given that the real reason the convention arose does not disappear?
- Does the answer change for a task filed in the repo that OWNS the source store (where
  agent-system/** is a real local path) versus one filed in a deploy-only repo?
Whichever way this lands, say so in the file_scope contract itself so the next author is not
choosing between two undocumented conventions. Note that if remedy (c) succeeds, source-store
tasks stop being filed in deploy-only repos at all, which may dissolve the question rather than
answer it -- if so, record that as the resolution.

=== WHAT IS OWED ===
- Channel (b)'s dispatch path can no longer file an agent-system task into an arbitrary repository,
  by whichever remedy is chosen.
- Every direct dispatcher of meta-builder-agent is enumerated, and each is either fixed or recorded
  as not needing the fix.
- skill-meta Section 4's acknowledged "carried by the prompt today" gap is either discharged or
  explicitly re-recorded with a reason it remains open.
- The deploy-path-in-file_scope convention question is settled in writing, in the file_scope
  contract, or recorded as dissolved by remedy (c).
- Whichever remedies are adopted, the reasoning for rejecting the others is recorded.

=== NOT IN SCOPE ===
No change to the conclusion stage's three-channel derivation contract, its per-channel approval
gates, or its approval-ledger mechanics beyond what target_root resolution forces. No repair of the
six BimodalLogic records' own file_scope data -- that is the sibling migration record, which strips
their deploy-path entries as a consequence of relocation and explicitly defers the convention
question to here. No new migration tooling. No change to /meta's existing --local semantics beyond
ensuring a chosen remedy does not break them.

=== FILE SCOPE ===
agent-system/extensions/core/context/contracts/conclusion-stage.md,
agent-system/extensions/core/agents/meta-builder-agent.md,
agent-system/extensions/core/commands/meta.md, plus whichever rule/standard file the standing rule
lands in (agent-system/extensions/core/rules/source-store-deploy-boundary.md and/or
agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md). If the
file_scope convention question is settled in writing, the file carrying that contract joins the
scope. The final subset depends on which remedies are adopted; NARROW IT AT PLAN TIME. Note the
overlap with two sibling records on conclusion-stage.md, which the declared dependency edge
serializes.

---

### 390. Migrate seven mis-sited agent-system tasks out of BimodalLogic and retire one duplicated upstream
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 391

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree
-- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS via deploy-headless.sh. No
task-number references in any file landing under agent-system/**
(rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere
in specs/**.

GOAL. Move seven task records out of ~/Projects/BimodalLogic/specs/ into this repo's own task space,
because their work targets the source store at ~/.config/nvim/agent-system/** and therefore cannot
be performed or committed from the repository they currently sit in. Then verify-and-abandon one
further BimodalLogic record that duplicates a record here, after transplanting the two things it
holds that the absorbing record does not.

=== WHY THESE RECORDS CANNOT STAY WHERE THEY ARE ===
Each of the seven names a source-store file as its edit target, and each says so itself: all seven
carry an explicit "SOURCE-STORE BOUNDARY" paragraph resolving source_dir from
<project-root>/.claude-extensions.json and naming the mirroring agent-system/** path as the real
edit target. Those paths resolve ONLY under ~/.config/nvim/. The directory agent-system/ does not
exist in BimodalLogic at all -- that repo carries only a deployed .claude/ tree plus a
.claude-extensions.json whose source_dir points back here
(/home/benjamin/.config/nvim/agent-system/extensions/core, with a sibling lean entry). A dispatch
picking up any of these records inside BimodalLogic can read nothing it is meant to edit and can
commit nothing it does manage to write.

=== THE SEVEN TO MOVE (all [NOT STARTED] in BimodalLogic; renumber from this repo's counter) ===
1. BimodalLogic #767 lake_build_guard_stale_replay_env_lean_file -- "lake-build-guard replays stale
   result for env lean FILE"; description 6319 chars; cites iss_1791710205724_8rTs68. Owning
   extension: core.
2. BimodalLogic #768 lean_challenge_snapshot_chunk_and_unicode_defects -- retitled and extended
   2026-10-13 to "fix THREE independent defects in lean-challenge-snapshot.sh", the third being
   the Goals-parser strictness defect, folded in rather than filed separately; 15938 chars, not
   the 5781 this entry recorded when written; cites iss_1791710205702_yQf0sD for defects (a) and
   (b) plus iss_1791911576304_KNI2OT for defect (c). Owning extension: LEAN, not core -- its
   source store is /home/benjamin/.config/nvim/agent-system/extensions/lean. It is the only one of
   the seven that is not a core-extension record; do not rewrite its scope to a core path.
   MIGRATION HAZARD: part of defect (c) is ALREADY LANDED and COMMITTED in the lean source store
   (42c23f442 -- the list-item Goals range anchor and the reserved-keyword denylist, suite 16/16
   green). The record carries its own "ALREADY-LANDED, UNCOMMITTED SOURCE-STORE WORK" section
   warning an implementer off duplicating or clobbering that work; the section must survive
   migration intact, and its "uncommitted" wording now needs correcting to "committed". Re-read
   the live record rather than this entry: its title and length have already drifted once.
3. BimodalLogic #769 plan_format_blocked_gate_and_status_ownership -- "plan-format: blocked decision
   gates and plan-level Status ownership"; 6701 chars; cites iss_1791710205747_08BVlu (Provision 1)
   and iss_1791711120761_z8uj5G (Provision 2). Owning extension: core.
4. BimodalLogic #770 postflight_detail_free_blocking_partial_issue_entry -- "postflight writes
   detail-free blocking issue entry on partial returns"; 10094 chars. Owning extension: core.
5. BimodalLogic #730 formal_logic_implement_routing_lean_capable_agent -- file_scope is EMPTY,
   title is null; 3144 chars.
6. BimodalLogic #741 agent_system_context_extensions_cslib_survey -- file_scope is EMPTY, title is
   null; 6715 chars; carries dependencies: [736].
7. BimodalLogic #752 roadmap_integration_regenerate_silent_abort -- file_scope names
   .claude/scripts/roadmap-integration.sh and specs/ROADMAP.md; title is null; 2911 chars. See the
   dedicated subsection below: this record is NOT covered by the completed
   roadmap_generator_stage_layout_and_silent_abort record here, and its opening premise is stale in
   a way the implementer must handle.

=== #752 IN PARTICULAR -- MIGRATE, DO NOT ABANDON (settled after full re-reading of its text) ===
An earlier reading of this record treated it as already fixed by this repo's completed
roadmap_generator_stage_layout_and_silent_abort. That reading was WRONG and is corrected here.

#752's own text carries a "BEHAVIOR UPDATE (observed after a `core` redeploy brought
.claude/scripts/roadmap-integration.sh up to the source store)" paragraph stating that its original
silent-abort premise "no longer reproduces as stated" -- but that a NARROWER defect remains live:
- --regenerate now exits 0 (not 1) and DOES write, but emits its only diagnostic to stderr as an
  HTML comment marker rather than a named message, so a caller still cannot distinguish outcomes
  from the message channel.
- It appends a `**Coverage appendix (uncovered tasks)**` fenced block into specs/ROADMAP.md -- a
  file whose own header declares it authored-and-not-generated -- while NOT assembling the
  `## Open work` / `## Next` layout and not touching the authored Stage prose. That is a
  half-application to an authored layout.
- The underlying authored-only-versus-teach-the-layout decision the record asks for is explicitly
  UNCHANGED and still unsettled.

Corroborated live in BimodalLogic on 2026-10-11: --regenerate exited 0 and emitted exactly
`<!-- roadmap-generation mode=regenerate tasks=62 topics=11 runs=21 pruned=0 retained=9 -->` on
stderr with nothing on stdout. NOTE the counts differ from the marker quoted inside #752's own text
(`tasks=52 topics=10 runs=20`) -- the task and topic totals simply grew between the two
observations. It is the SHAPE that corroborates (exit 0, marker-only on stderr, nothing on stdout),
not the numbers; do not treat either number set as a fixture.

A check of this repo's own records found no successor covering the residual: nothing here matches on
authored-only or authored-and-not-generated language. Abandoning #752 would therefore drop a live,
unsettled decision on the floor with nothing upstream picking it up.

CARRY THIS CAVEAT INTO THE MIGRATED RECORD: the exit-1/zero-output framing in #752's OPENING
paragraph predates the redeploy and must be re-verified against the live script before implementing.
The record says this of itself; preserve that instruction rather than silently rewriting the opening
to match the newer observation.

#752'S TWO SCOPE ENTRIES NEED DIFFERENT TREATMENT -- do not rewrite them uniformly. Its current
file_scope is .claude/scripts/roadmap-integration.sh plus specs/ROADMAP.md.
- The script entry rewrites to the source-store path
  agent-system/extensions/core/scripts/roadmap-integration.sh (owning extension: core). Check
  whether the record's residual also touches context/formats/roadmap-format.md, the generation
  contract the completed roadmap-generator record here updated to describe the stage-based layout
  -- an authored-only ruling would contradict that contract and would have to amend it.
- The specs/ROADMAP.md entry does NOT survive the move as written, and this is a cross-repo hazard
  of exactly the shape criterion (3) describes for the iss_* citations. Read from this repo,
  specs/ROADMAP.md resolves to THIS repo's roadmap. The file the record is actually about -- the
  authored, Stage-based document whose header declares it authored-and-not-generated, and into
  which --regenerate appends its Coverage appendix -- is BimodalLogic's
  /home/benjamin/Projects/BimodalLogic/specs/ROADMAP.md. That file is the REGRESSION FIXTURE, not
  an edit target, and the migrated record must say so in those terms with the path repo-qualified.
  Decide whether a fixture belongs in file_scope at all: it is not a file the task edits, and the
  completed roadmap-generator record here treated BimodalLogic's roadmap as a read-only fixture
  without declaring it in scope at all. Prefer that precedent unless there is a reason not to.

=== ACCEPTANCE CRITERIA ===

(1) RENUMBERING, NOT COPYING. The two repositories keep independent numbering spaces. Allocate each
migrated record from this repo's next_project_number and advance that counter correctly afterwards.
Do NOT assume a helper advances it for you, and do NOT trust a counter value read earlier in the
same session. MEASURED THIS SESSION, TWICE: a hand-created task in BimodalLogic needed an explicit
counter bump afterwards; and the two records filing this migration work read next_project_number as
387, were written as 387 and 388, and collided with 387/388/389 created by a concurrent writer in
the window between the read and the write -- the write also clobbered that writer's own correct
counter bump. Both were renumbered to 390 and 391 in repair. Re-read the counter immediately before
writing, re-check for duplicate project_number values immediately after, and verify the counter's
post-migration value explicitly.

(2) DESCRIPTIONS PRESERVED VERBATIM, including every iss_* citation id. The five descriptions in the
5-10k character range carry measured evidence (line numbers, reproduction commands, enumerated
sub-faults) that is the entire value of the record; paraphrasing destroys it. The one permitted
addition is a note recording how criterion (3) was discharged.

(3) CITATIONS MUST STAY RESOLVABLE CROSS-REPO. All four iss_* ids were confirmed present in
/home/benjamin/Projects/BimodalLogic/specs/760_ladder_model_cell_stabilization_lemma/issues.jsonl
and nowhere else outside that repo's own TODO.md and state.json. Read from inside this repo, a bare
specs/760_... path resolves to the wrong repo or to nothing. DECIDE AND APPLY one approach --
repo-qualified absolute path, a copied evidence excerpt carried into the migrated description, or
another -- and state in the migrated records which approach was used. Do not leave a bare relative
path standing.

(4) TERMINAL DISPOSITION FOR THE VACATED BimodalLogic ENTRIES, each with a durable pointer to where
the work went. Choose between ABANDONED and EXPANDED deliberately and record the reasoning rather
than defaulting. POINTER HAZARD: rules/no-task-references-in-deliverables.md permits task numbers
only under specs/**, and cross-repo numbers are especially unstable under vault renumbering, so a
bare "moved to #NNN" pointer may not survive -- pair any number with a durable anchor (the
project_name slug, the named source-store file, the iss_* id).

(5) GIT-TRACKABILITY OF THE VACATED DIRECTORIES -- measured, not assumed. Checked 2026-10-11:
BimodalLogic #730, #741 and #752 have NO task directory on disk at all; #753, #767, #768, #769 and
#770 each have a directory containing ZERO files (#753 holds four empty subdirectories, the other
four hold one each). An all-empty task directory is not git-trackable -- a commit was refused this
session for exactly that reason. Re-check each directory's actual population at implementation time
rather than trusting this snapshot, and omit any empty directory from the commit path list.

(6) DERIVE A file_scope FOR THE TWO RECORDS THAT HAVE NONE. BimodalLogic #730 and #741 both declare
file_scope: []. An absent file_scope is itself a defect the pre-dispatch review flags (Class F), so
migrating them unchanged would carry that defect across. Derive a scope from each description's
named files before writing the migrated record.

(7) REWRITE EACH file_scope TO SOURCE-STORE PATHS ONLY, AND UNDERSTAND WHY. This is NOT a defect
repair -- do not approach it as one. Measured 2026-10-11: #752, #753 and all four of #767-#770
declare their deployed .claude/** path DELIBERATELY, each with an explicit paragraph stating that
the .claude/** paths "are declared only so the admission overlap gate can see the collision
surface; they are NOT the edit target." That convention is coherent in BimodalLogic, where the
overlap gate runs over a tree in which the deployed paths are the only ones that exist -- declaring
the source path alone would make the record invisible to that repo's gate.

The declarations must still be stripped, because that rationale does NOT survive the move: this
repo's overlap gate runs over this repo's tree, where agent-system/** is the real path and
.claude/** is this repo's OWN deploy tree, unrelated to BimodalLogic's. A carried-over .claude/**
declaration would name a path that exists here but is not the one the record touches. Strip it as a
consequence of migration, not as a correction of an authoring error.

HOUSE STYLE, OBSERVED RATHER THAN ASSUMED: this repo's own comparable records
(roadmap_generator_stage_layout_and_silent_abort, conclusion_stage_report_block_and_caller_split,
null_resolution_entries_unreachable_by_conclusion_stage) declare source-store paths ONLY, with no
deploy-path entry of any kind. Match that. Whether the BimodalLogic convention of declaring the
deploy path for gate visibility is the better one is a live open question, and it belongs to the
sibling record agent_system_task_siting_and_target_root -- do not settle it here.

(8) RESOLVE #741'S DANGLING DEPENDENCY EDGE. BimodalLogic #741 carries dependencies: [736], and
BimodalLogic #736 is no longer in that repo's active_projects -- it was completed and archived (its
own description text survives in sibling records as "omega-automata survey (task 736, completed)").
A number from the source repo's space is meaningless in this repo's space regardless. Decide
explicitly whether the edge is already satisfied and can be dropped, or must be re-pointed at a
record here, and record which.

(9) SUPPLY TITLES WHERE THEY ARE NULL. BimodalLogic #730, #741 and #752 all have title: null.
Derive a title for each migrated record from its description rather than carrying the null across.

=== ALSO OWED: TRANSPLANT-THEN-ABANDON BimodalLogic #753 ===
BimodalLogic #753 conclusion_stage_drops_null_resolution_entries duplicates this repo's
null_resolution_entries_unreachable_by_conclusion_stage, which is already [planned] and further
along. The duplication is genuine and deep: both analyse the identical defect down to line level
across the same four files -- issue-record.sh's optional --resolution and its
`if [ -n "$resolution_arg" ]` guard, issue-log.md's "no (nullable)" row with an empty notes column,
orchestrate-conclusion-aggregate.sh's filter coercing null to "", and conclusion-stage.md's Filter
Predicate leaving null unaddressed. Both were also found in the BimodalLogic repo, the absorbing
record on 2026-10-08. ABANDONING #753 IS CORRECT.

But #753 holds two things the absorbing record does NOT, and they must not be lost. BEFORE marking
#753 abandoned, amend the absorbing record's description to absorb both:

(i) INDEPENDENT CORROBORATION FROM A DIFFERENT RUN. #753 records
    specs/749_c_bound_half_model_a_presentation_size/issues.jsonl: 11 entries, every one
    resolution: null and suggested_channel: null; the aggregator returned proposals 0 / wins 4 /
    unknown_classes 6; of the 11, 7 were kind: "issue" and all were dropped -- six at
    severity: minor (classes stale-citation, plan-deviation, plan-gap, plan-gap, plan-gap,
    build-failure) and one at severity: costly (class plan-deviation). The absorbing record's own
    evidence is a DIFFERENT run (six dropped entries from an /orchestrate 739,740 --lit --fable
    run). A second independent reproduction, including one entry at costly severity, strengthens the
    case materially -- and #753 notes that option (b) alone would have pushed 7 entries from ONE
    task into classification, which is a proposal-volume datum the absorbing record's remedy choice
    should weigh. CARRY #753'S OWN CAVEAT ACROSS TOO: it says to re-derive these counts from the
    live log rather than trusting them, as they are a snapshot.

(ii) A LIVE DISAGREEMENT, NOT MERELY EXTRA EVIDENCE. On suggested_channel being null, the two
     records reach OPPOSITE conclusions. The absorbing record states that suggested_channel "does
     NOT have the same shape, and is benign", because the aggregator's
     `suggested_channel_hints: (map(.suggested_channel) | map(select(. != null)) | unique)` filters
     nulls harmlessly, and it files this under sub-questions already answered. #753's "ALSO IN
     SCOPE" paragraph instead asks whether a null hint is acceptable at all or whether the writer
     should require one, observing that the Hint-Versus-Decision Rule "treats that field as a hint
     the orchestrator may override visibly, which presumes a hint exists", and says the answer must
     be recorded in the same place as the resolution decision. That is a real open question the
     absorbing record currently treats as settled. Surface it there as open rather than discarding
     it with #753.

#753's abandonment note must point at the absorbing record as the record that took the work, using
a durable anchor per the criterion (4) pointer hazard. IF AMENDING THE ABSORBING RECORD IS NOT
POSSIBLE for any reason encountered, do NOT abandon #753 -- report it and leave it open.

=== MECHANISM: A ONE-SHOT DOCUMENTED PROCEDURE, NOT A REUSABLE SCRIPT ===
USER RULING, settled 2026-10-11, DO NOT RE-LITIGATE. Cross-repo task migration has happened once.
Building a general-purpose migration script now would be speculative generality against an unproven
need. Write the procedure to
agent-system/extensions/core/context/patterns/cross-repo-task-migration.md in the source store and
perform this migration by following it. Do NOT build a migrate-task script.

=== FILE SCOPE LIMITATION, STATED EXPLICITLY ===
The declared file_scope names context/patterns/cross-repo-task-migration.md (the procedure document
this record writes) plus this repo's specs/state.json and specs/TODO.md. It CANNOT cover the other
half of the work: this record also mutates
/home/benjamin/Projects/BimodalLogic/specs/state.json and that repo's specs/TODO.md, which lie
outside this repository entirely and are therefore invisible to any local file_scope overlap check.
That is a real blindness, not an exemption -- a concurrent dispatch touching BimodalLogic's task
state will not be detected as colliding with this one. Serialize manually if that risk is live.

A SECOND, NARROWER OVERLAP: the #753 transplant edits the description of this repo's
null_resolution_entries_unreachable_by_conclusion_stage record. That is a specs/state.json mutation
already covered by the declared scope, but it touches another record's row while that record is
[planned] and dispatchable. Check its status before amending, and do not amend it mid-dispatch.

=== NOT IN SCOPE -- STAYS IN BimodalLogic ===
Its completed records #731, #754 and #755 (archival record, no migration value) and #771
task_reference_lint_debt_boneyard_tests, whose actual debt -- 198 unexempted task-number citations
under Boneyard/ and Tests/BimodalTest -- is genuinely local to that repository.

=== ACCEPTANCE SUMMARY ===
- Seven records exist in this repo's specs/ with verbatim descriptions, resolvable citations,
  source-store-only file_scope values, non-null titles, and a resolved dependency edge on the
  cslib-survey record.
- next_project_number here is correct and verified after the allocation, with no duplicate
  project_number values.
- Eight BimodalLogic records (the seven moved plus #753) carry a terminal status with a durable
  pointer, or are reported as still-open with the failed verification or blocked transplant named.
- The null-resolution record here carries #753's second reproduction and its open suggested_channel
  question.
- context/patterns/cross-repo-task-migration.md documents the procedure actually followed.

=== THREE MORE LEAKED IN AFTER THIS RECORD WAS WRITTEN -- ADD THEM TO THE SEVEN ===
Appended 2026-10-12 after a user ruling in BimodalLogic that agent-system tasks must exist only in
this repo. All three post-date this record's own creation (2026-10-11T17:51:06Z), so the list above
was complete when written and is now short by three. They migrate on identical grounds: each names
a source-store or deployed-tree path as its edit target, and neither path is editable from the
repository the record sits in.

8. BimodalLogic #772 jq_rewrite_reserializes_json_record_files -- created 2026-10-12T00:03:28Z;
   description 10015 chars; dependencies []. file_scope names
   agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md,
   agent-system/extensions/core/index-entries.json and
   agent-system/extensions/core/merge-sources/claudemd.md alongside the deployed .claude/ mirror.
   Owning extension: core. Note it touches index-entries.json and a merge source, so its migration
   must not drop the regenerate/redeploy step those two imply.
9. BimodalLogic #774 refuted_predicted_reason_recording -- created 2026-10-12T05:22:05Z; 8293
   chars; dependencies []. file_scope names only DEPLOYED paths
   (.claude/context/formats/plan-format.md, .claude/context/contracts/phase-closure.md,
   .claude/context/formats/issue-log.md) and no agent-system/** mirror, so unlike the seven above
   it does not carry its own source-store paths and the implementer must resolve each to its
   core-extension mirror when rewriting the scope. Owning extension: core. Its plan-format.md and
   issue-log.md surfaces overlap items 3 and 8 and the transplant target below -- sequence, do not
   parallelise.
10. BimodalLogic #777 phase_commit_drops_own_plan_artifact -- created 2026-10-12T16:27:31Z; 17896
   chars; dependencies []. file_scope names
   agent-system/extensions/core/scripts/git-commit-phase.sh, its test suite and
   context/standards/git-staging-scope.md. Owning extension: core. TWO THINGS THE IMPLEMENTER MUST
   HANDLE. First, it carries an appended "ADJACENT OBSERVATION" section about an out-of-repo
   staging failure and the detached provenance it left behind; that subject overlaps this repo's
   own out_of_repo_pathspec_aborts_whole_commit record, which is already [IMPLEMENTING], so check
   that overlap before migrating and do not transplant the section blindly. Second, its body states
   an honest one-occurrence recurrence bound for the own-task-dir false-positive class and the
   appended section explicitly preserves that bound; a migration must not merge the two and
   falsify it.

=== WHY THE COUNT WILL KEEP DRIFTING UNTIL THE SITING RECORD LANDS ===
Item 10 was created by an orchestrate conclusion-stage channel (b) dispatch in BimodalLogic, which
is precisely the authoring path the siting-and-target-root record diagnoses as never resolving
target_root: that step dispatches meta-builder-agent directly rather than through /meta, so the
agent defaults to the session's working directory. That record is still [NOT STARTED] and carries a
serializing dependency edge, so the hole remains open and this list is stale-by-construction, not
merely incomplete. Sequencing consequence, recorded as a recommendation and not a decision: landing
the siting record first stops the inflow, after which this migration runs once against a list that
stays fixed; running this migration first leaves it to be re-run for every task the open hole
produces in the interim. The ruling on that order belongs to the user.

=== A FOURTH LEAKED IN, AND ONE THAT ONLY LOOKS LIKE IT DID (appended 2026-10-13) ===
Both assessed against this record's own criterion above -- that a dispatch picking the record up
in BimodalLogic "can read nothing it is meant to edit" -- rather than on the presence of an
agent-system path alone. One qualifies; one was proposed as an eleventh item and is refused here,
with the measurement that refuses it.

11. BimodalLogic #783 bounded_block_edit_index_and_assert -- created 2026-10-14T01:21:12Z; 17405
    chars; dependencies [772]. file_scope names
    agent-system/extensions/core/context/patterns/bounded-block-edit.md,
    agent-system/extensions/core/index-entries.json,
    agent-system/extensions/core/merge-sources/claudemd.md and
    agent-system/extensions/core/agents/general-implementation-agent.md, each paired with its
    deployed .claude/ mirror. Owning extension: core. Qualifies on identical grounds to items
    8-10: every edit target is a source-store path and none resolves from the repository it sits
    in. THE EDGE IS THE HAZARD HERE. Its dependency on #772 is item 8 of this list, so that edge
    is intra-repo today and survives migration ONLY if both records move together; migrating
    either alone breaks it silently. #783's own siting is undecided by design -- it branches on
    whether #772 extends the jq-escaping file or creates a new sibling pattern file -- so the two
    must be sequenced in that order, never parallelised.

NOT A MIGRATION CANDIDATE, DESPITE APPEARANCES: BimodalLogic #778
residue_index_modulus_convention_record [PLANNED], created 2026-10-12T22:10:50Z, 1087 chars.
MEASURED 2026-10-13: of its twelve file_scope entries, NINE resolve only in BimodalLogic and each
was confirmed to exist there (FormalSystem/Metalogic/Decidability/RaySummary/LadderModel.lean and
RaySummary/README.md, FormalSystem/Metalogic/README.md, FormalSystem/README.md, README.md,
docs/theorem-index.md, scripts/check-evidence-probes.sh,
specs/evidence/seam-gluing-ray-product/ladder-residue-index-refutation.lean and
typst/generated/status.typ). Only three point at the lean source store. Migrating it would leave
three quarters of its scope unresolvable -- this record's own defect, inverted. It is a
SPLIT-SCOPE record, a class migration cannot repair in either direction, and it belongs with the
records that stay rather than on this list.

TWO SCOPE-HYGIENE DEFECTS IN #778, recorded where they were found and NOT this record's to fix:
its file_scope carries the literal unresolved placeholder
"<lean source_dir>/context/project/lean4/domain/ladder-counter-observables.md" AND an absolute
path under /home/benjamin/.config/nvim/ naming the SAME file, plus a second placeholder
"<lean source_dir>/index-entries.json". A placeholder-shaped entry is invisible to the file_scope
overlap gate -- the pre-dispatch review reports that shape as a Class G finding -- so neither
entry protects that file from a concurrent writer, and the duplicate pair makes the scope read as
two files where there is one.

---

### 389. Verify deploy context budget fixture missing git add
- **Effort**: small
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None
- **Parent**: Task 371

**Description**: Fix test-verify-deploy-context-budget.sh's fixture so the full verify-deploy gate set can pass.

The fixture runs `git init` on a scratch directory but never `git add`, so Gate 22 discovers files via `git ls-files` against an empty index, finds zero .sh files, and exits 2. That fails Gate 8 (run-all.sh), which fails the complete verify-deploy.sh gate set at 1 of 36.

Repo-wide consequence: every implementation plan whose final phase declares the criterion "verify-deploy.sh exits 0 -- the complete gate set, not --skip-slow" is currently UNMEETABLE for reasons unrelated to that plan's own work. Two tasks in the originating batch had to close their final phase as [COMPLETED WITH EXCLUSIONS] and write a Reasoned Exclusions record attributing this single failure as pre-existing. That is the correct handling, but it masks real failures: a genuine new breakage in the same gate would be indistinguishable from this known one in a 1-of-36 result.

The --skip-slow deploy path is clean at 35/35, so only the full set is affected.

Severity: minor in isolation, but it is load-bearing for every future task's final-phase verification criterion. Citation: 371 : iss_1791597799615_hKfFjt. Independently corroborated by the orchestrator's own baseline comparison during the originating run: pre=1 post=1 new=0.

---

### 388. Prune next body flag misparse drops active task
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None
- **Parent**: Task 371
- **Research**: [388_prune_next_body_flag_misparse_drops_active_task/reports/01_prune_next_body_flag_misparse.md]
- **Plan**: [388_prune_next_body_flag_misparse_drops_active_task/plans/01_prune-next-body-flag-misparse.md]
- **Summary**: [388_prune_next_body_flag_misparse_drops_active_task/summaries/01_prune-next-body-flag-misparse-summary.md]

**Description**: Fix prune_next_body() mis-parsing a Run line when a CLI flag precedes the rationale comment.

Found during read-only verification of roadmap-integration.sh --prune against the live stage-based specs/ROADMAP.md in ~/Projects/BimodalLogic. PRE-EXISTING defect, shared and unmodified by the task that found it, and it affects BOTH the classic and stage layouts identically.

Defect: when a Run line's task list is followed by a CLI flag before the rationale comment -- e.g. `/orchestrate 716,714 --hard   # rationale` -- prune_next_body()'s whitespace-based parse mishandles the flag token and wrongly drops an ACTIVE task as if it were terminal. Silent: no error, no warning, exit 0. The consequence is content loss from the roadmap (an active task disappears from the Run order), which is the same failure class as the silent-overwrite risk that motivated the originating work.

Severity: costly. Citation: 371 : iss_1791594170949_tEAVNS.

Scope note: the originating task deliberately did NOT fix this -- it is in a shared function outside that task's declared file_scope, and fixing it there would have been an unreviewed widening. Verification must cover both layouts and at least: a flagged Run line with a comment, a flagged line without a comment, an unflagged line with a comment, and multiple flags.

---

### 387. Teach the batch admission gate that a whole-tree regeneration phase is an implicit scope claim over the entire deployed tree
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 378

**Description**: SOURCE STORE IS THE EDIT TARGET: resolve `source_dir` from <project-root>/.claude-extensions.json and edit at the path mirroring the deployed one (never hand-author under a deployed .claude/** tree, which is a gitignored, disposable deploy artifact regenerated from the source store -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md).

SCOPE: `extensions/core/scripts/orchestrate-batch-admit.sh`, `extensions/core/scripts/orchestrate-cycle-plan.sh`, and (only if the chosen design requires it) `extensions/core/scripts/lib/file-scope-overlap.sh`, `extensions/core/context/patterns/file-footprint-overlap.md`, `extensions/core/docs/architecture/orchestrate-state-machine.md`.

CHANNEL JUDGMENT: the contributing issues.jsonl entries carried `suggested_channel` hints of `fix_now` and `agent_system`. The orchestrator chose `agent_system` because this is a change to the admission gate's hazard model, not a one-file fix.

=====================================================================
PART A (primary) -- whole-tree regeneration is an undeclarable scope claim
=====================================================================

THE DEFECT, observed live (not hypothetical). The batch admission gate
(`orchestrate-batch-admit.sh`) detects co-dispatch hazards by intersecting the DECLARED
`file_scope` sets of candidate tasks (the shared predicate in `lib/file-scope-overlap.sh`:
`norm`, `scopes_overlap_first`, exact match or either path a directory-prefix of the other).
But `deploy-headless.sh` regenerates the ENTIRE deployed `.claude/` tree unconditionally from
current filesystem state. Two tasks whose plans each end in a "redeploy + full gate" phase are
therefore mutually exclusive in practice while being perfectly disjoint on paper.

That is exactly what happened. Tasks 371 and 372 had STRICTLY DISJOINT `file_scope` -- which is
precisely why the gate co-dispatched them into the same wave -- yet both plans ended in a
redeploy phase. No scope intersection can ever express this hazard, because the whole-tree
claim is not written in any task's `file_scope` at all. The gate's existing `self_modifying`
branch is the nearest relative but does not cover it: that branch keys on the candidate's OWN
declared `file_scope` naming a path on a fixed declared critical-path list, so it still cannot
see a claim that appears only in the plan's phase content.

OBSERVED CONSEQUENCES this run:
- Task 372's Phase 4 had to self-block: running the required `deploy-headless.sh` would have
  swept sibling task 371's live, uncommitted, unverified in-progress edits into the deployed
  tree. The implementing agent caught this ONLY by reading `git status` at phase entry -- there
  was no gate, no warning, and nothing in its plan predicted it.
- Earlier, task 372's Phase 2 gate run failed doc-lint on two files OUTSIDE its own declared
  scope, caused by 371's already-committed-but-not-yet-redeployed work.
- Task 372 landed [PARTIAL] 3/4 as a direct result, which in turn kept sibling task 373
  deferred behind it for the rest of the run.

CITATIONS (task : entry_id) -- verifiable in each task's issues.jsonl:
- 371 : iss_1791598089947_3K8mO2  (costly; postflight completion write refused by the
  completion-deploy gate because the deployed tree was stale)
- 372 : iss_1791594146426_x2i4ct  (BLOCKING; Phase 4 refusing to deploy over 371's uncommitted
  edits)
- 372 : iss_1791593439801_hh8mKq  (minor; Phase 2 gate failing on out-of-scope
  deployed-vs-source drift caused by 371)
- 372 : iss_1791592323041_eKI7VY  (minor; territory collision recorded at plan time)

GOAL. A plan phase that invokes whole-tree regeneration should be treated as an implicit scope
claim over the entire deployed tree, so that two such tasks SERIALIZE even when their declared
`file_scope` sets are disjoint.

DESIGN DIRECTION -- the task DECIDES among these, it does not presume one:
  (1) Detect the claim from the plan's own phase content at admission time (grep the plan
      artifact for the regeneration invocation). Cheapest to adopt, but content-sniffing a
      deliverable is a new kind of input for this gate and is fragile to rewording.
  (2) A dedicated declaration a plan can carry (an explicit "claims whole deployed tree" field
      or a reserved `file_scope` sentinel). Honest and greppable, but needs planner-agent
      cooperation and a migration story for plans already written.
  (3) A deploy-level mutual-exclusion lock as a cheaper backstop -- serialize at the moment of
      deployment rather than at admission. Does not prevent the wasted wave or the
      out-of-scope gate failure, but is the smallest change and composes with (1) or (2).
Evaluate at minimum: whether the chosen mechanism ALSO explains the Phase 2 out-of-scope
doc-lint failure (a stale-deploy read hazard, not just a concurrent-write hazard), and whether
serializing is the right remedy versus deferring the second task with an existing defer_reason.

ACCEPTANCE. (a) Two tasks with disjoint `file_scope` whose plans both contain a whole-tree
regeneration phase do not get co-dispatched into the same wave, demonstrated by a fixture.
(b) The verdict carries a named, machine-readable reason distinguishable from
`file_scope_collision` (or a documented justification for reusing it). (c) No regression in the
existing admit/defer branches -- `self_modifying`, `file_scope_collision`, `session_active`,
`absent_file_scope`, and the `idle_overlap_advisory` all keep their current semantics and their
documented output fields. (d) The gate's fail-open posture is preserved: an unknown task,
terminal status, or missing plan artifact must still admit, never error.

=====================================================================
PART B (same root area, found while executing the orchestration conclusion stage)
=====================================================================

`orchestrate-cycle-plan.sh`'s PLAN CACHE REPLAY is keyed on `dispatch_seq_counter` ALONE. The
script's own comment at the cache-write site states this explicitly as decision (D3): no other
component is mixed into the key. The replay check fires whenever the freshly-read counter still
equals the value the cache was written at, and replays the cached plan verbatim.

OBSERVED LIVE: `--force-phases implement 372` returned the cached "needs human" blocked row and
dispatched nothing. The forcing flag was silently ignored -- it is not part of the cache key, so
it cannot invalidate a replay. This defeats the documented purpose of the forcing flags as the
human's override lever: there was no way to break out of the cached state from the command line.

MECHANICAL LEAD TO CONFIRM FIRST (do not implement against it unverified). The cache is written
only when a composition built >=1 `dispatch` row OR >=1 `aux_dispatch` row, and `plan_cache` is
cleared in exactly one place: `orchestrate-cycle-postflight.sh`. The aux-dispatch path DOES mint
and advance `dispatch_seq_counter` before the cache write, keying the cache at the post-advance
value. So a composition pairing an aux_dispatch row with a blocked row for the main task caches
at counter=N; if that aux dispatch does not itself run `orchestrate-cycle-postflight.sh`, then
nothing ever advances the counter past N and nothing ever clears the cache -- making the entry
replayable indefinitely. An aux blocker dispatch for 372 did occur in this run, which fits the
observed signature. Research must verify whether aux dispatches reach cycle-postflight before
treating this as the cause; the user-visible defect in the first paragraph stands either way.

GOAL. A forcing flag must be able to break out of a cache replay. Candidate directions to decide
among: include the canonicalized `--force-phases` value in the cache key; bypass the replay
whenever any forcing flag is present on the invocation; or ensure every cache-writing path has a
guaranteed clearing counterpart. Note that `--no-plan-cache` already exists as an escape hatch
but is documented as test-suite-only and is not the human's documented override lever.

ACCEPTANCE. (a) An invocation carrying a `--force-phases` argument different from the one the
cached composition was built with does not replay that cache. (b) The cache still suppresses the
redundant re-composition it was built for -- the no-charge benefit is not thrown away to fix
this. (c) The script's stdout contract (single-line JSON, both modes) is unchanged. (d) The
cache-write/cache-clear pairing is stated in the script's own header comment, so a future
reader can check it without re-deriving it.

ADJACENCY NOTE: Parts A and B touch two different scripts with no shared lines; they are
batched into one task because they are one root area (the orchestrator's co-dispatch and cycle
composition machinery) and were found in one investigation. If research concludes they are
better separated, say so and split rather than forcing them into one plan.

---

### 386. Give every git-snapshot.sh --no-revert failure path a reason on stderr instead of a silent exit 1
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [386_silent_exit_in_no_revert_snapshot/reports/01_silent-exit-no-revert.md]
- **Plan**: [386_silent_exit_in_no_revert_snapshot/plans/01_silent-exit-no-revert.md]
- **Summary**: [386_silent_exit_in_no_revert_snapshot/summaries/01_silent-exit-no-revert-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: resolve `source_dir` from <project-root>/.claude-extensions.json and edit at the path mirroring the deployed one (never hand-author under a deployed .claude/** tree, which is a gitignored, disposable deploy artifact regenerated from the source store -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md).

SCOPE: `extensions/core/scripts/git-snapshot.sh`.

EVIDENCE (re-verified and reproduced 2026-10-10; originating report task 757, issues.jsonl
entry_id iss_1791676618861_f0BPTT, class tooling, severity minor, suggested_channel agent_system).

Observed: `git-snapshot.sh --no-revert 757` exited 1 after printing only its mode line
("git-snapshot.sh: --no-revert mode -- the working tree will NOT be modified."), with no reason
line on stderr. The working tree was not modified and the dispatch proceeded without a snapshot.

THE ORIGINAL REPORT'S CONJECTURED CAUSE IS WRONG -- DO NOT IMPLEMENT AGAINST IT. The report
guessed that other sessions' dirty `specs/**` files outside the invoking task's declared
`file_scope` triggered the refusal. They cannot have: the out-of-scope refusal guard is wrapped in
`if [ "$MODE" != "no-revert" ] && [ "$ALLOW_OUT_OF_SCOPE" -ne 1 ]`, i.e. skipped entirely for
`--no-revert` by design (decision D2 in the script's own comments: it reverts nothing, so it has
nothing to destroy). No `file_scope` classification runs in this mode at all. Consequently the
secondary question the report raised -- whether refusing is correct behaviour for a mode that
modifies nothing -- is moot: the mode already tolerates foreign dirt. Nothing about the
out-of-scope guard needs changing.

ACTUAL MECHANISM (reproduced). The script runs under `set -euo pipefail` (line 115 at time of
writing). The mode line is printed, and the `--no-revert` branch then performs three unguarded
command substitutions whose failure aborts the script silently with the failing command's status,
with the reason already discarded by a `2>/dev/null` redirect:
  - `STASH_SHA=$(git stash create "..." 2>/dev/null)`
  - `UNTRACKED_LIST=$(git ls-files --others --exclude-standard 2>/dev/null)`
  - `STASH_REF=$(git stash list | head -1 | cut -d: -f1)` (under `pipefail`, a SIGPIPE'd
    `git stash list` yields 141, so this one aborts with a status other than 1)
Every explicit `exit 1` inside that same branch DOES print a reason; it is only these
substitutions that are silent. A minimal reproduction of the exact observed signature -- mode line,
then nothing, then exit 1 -- is: hold `.git/index.lock` (as a concurrent git process in the same
repository does) and run the `set -euo pipefail` + `STASH_SHA=$(git stash create 2>/dev/null)`
pair; `git stash create` fails with status 1, its stderr is discarded, and `set -e` aborts. Several
sessions were active in the same repository at the time of the incident, which makes index.lock
contention a sufficient and plausible real cause -- and explains why the reporter correctly
correlated "other sessions were busy" with the failure while misattributing the mechanism.
Verified NOT a cause: a tracked-clean, untracked-only dirty tree, where `git stash create` prints
nothing and exits 0; that empty-output case is already handled by the existing
`if [ -n "$STASH_SHA" ]` check.

GOAL. Every failure path reachable in `--no-revert` mode emits a reason on stderr before exiting.
A defensive checkpoint that refuses without saying why trains callers to ignore it. At minimum:
capture each of the three substitutions' status explicitly rather than letting `set -e` abort on
them, stop discarding the underlying git stderr (or re-report it), and emit a named reason plus the
exit status. Research should also sweep for the same unguarded-substitution shape in the script's
other modes and in sibling scripts, and should decide whether a `git stash create` failure in
`--no-revert` mode is fatal at all or should degrade to a patch-only snapshot with a loud warning,
given that the `.patch` file is documented as the primary durable record and is already computed
before this point.

ACCEPTANCE. (a) A fixture that makes `git stash create` fail (e.g. a held `.git/index.lock`) shows
a named reason on stderr and a documented exit status, not silence. (b) No command substitution in
the `--no-revert` branch can abort the script without a reason line. (c) The success path's stdout
report stays byte-compatible for its documented consumers (checkpoint-before-overflow.md and the
agent handoff steps), since the script's own comments pin that contract. (d) The out-of-scope guard
remains skipped for `--no-revert`.

ADJACENCY (coordination note, not a dependency): an existing not-started task covers refusing
`git stash pop`/`apply` of a foreign stash entry in guard-destructive-git.sh and requires
git-snapshot.sh's sanctioned flow to keep working. That task edits the guard hook and
git-workflow.md, not this script, so the file territories do not overlap; whoever implements
second should re-read the other's changes.

---

### 385. Define the sanctioned shape for a lean4-typed plan that commits to no theorem, and make lean-challenge-snapshot.sh distinguish it from a malformed one
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: resolve `source_dir` from <project-root>/.claude-extensions.json and edit at the path mirroring the deployed one (never hand-author under a deployed .claude/** tree, which is a gitignored, disposable deploy artifact regenerated from the source store -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md).

SCOPE SPANS TWO EXTENSIONS: `extensions/core/context/formats/plan-format.md` and
`extensions/lean/scripts/lean-challenge-snapshot.sh` (+ its design record
`extensions/lean/context/project/lean4/domain/challenge-snapshot.md`).

EVIDENCE (re-verified 2026-10-10 against the source store; originating report task 757,
issues.jsonl entry_id iss_1791673989121_pKYeau, class specification_gap, severity minor).

A lean4-typed plan that proves nothing has no sanctioned shape, and both available shapes fail
identically:

1. `plan-format.md` gates the section two ways, and neither admits the zero-theorem case. Its
   numbered-section list says "**Lean Challenge Statements** (lean/lean4 plans only) - under
   `## Lean Challenge Statements`, present only when the plan's `task_type` is `lean`/`lean4`",
   and the `## Lean Challenge Statements (format, lean/lean4 plans only)` section repeats
   "Present only when the plan's `task_type` is `lean`/`lean4`". Neither states what a lean4 plan
   with zero Lean goals should do. A repo-wide search of plan-format.md and
   challenge-snapshot.md for a zero-goal / no-theorem-deliverable / inapplicable clause returns
   nothing.

2. `lean-challenge-snapshot.sh` fails on both shapes with the SAME code. Section present but
   carrying zero ```lean fenced blocks is `extract_r1` status 2, which the main resolution block
   turns into a bare `exit 71`. Section absent entirely is `extract_r1` status 1, which falls
   through to the R2 git-baseline fallback; the subsequent `if [ ! -s "$GOALS_FILE" ]` guard then
   emits "ERROR: no identifiers found under **Goals**: ... nothing to snapshot." and also
   `exit 71`. The script's own header documents 71 as "Config error", so a deliberate
   no-theorem-deliverable plan is indistinguishable from a malformed one.

The originating plan worked around this by omitting the section entirely, recording the reason in
its Decisions, and marking `--compare` inapplicable to that task.

GOAL. Decide and document the sanctioned shape for a lean/lean4-typed plan with no theorem
deliverable, and make `lean-challenge-snapshot.sh` agree with whatever is decided, so that such a
plan is mechanically distinguishable from a malformed one. The shape itself is this task's design
question and is deliberately NOT pre-decided here: an explicit "omit the section and record why in
Decisions" clause in plan-format.md plus a distinct non-71 (possibly zero) exit for the
zero-identifier case is one candidate; an explicit opt-out marker the script recognizes is
another; research picks the mechanism. Whatever is chosen must also settle what `--compare` and
the Comparator flow do for such a plan, and must keep the existing malformed-section detection
(present-but-empty R1 section) a hard, loud failure -- the two cases must not collapse back into
one code.

ACCEPTANCE. (a) plan-format.md states the sanctioned shape for a lean/lean4 plan with zero Lean
goals, at the `## Lean Challenge Statements` section. (b) A fixture lean4 plan carrying zero Lean
goals in the sanctioned shape runs through lean-challenge-snapshot.sh with an outcome that is
distinguishable from exit 71, and the outcome is documented in the script's own exit-code header
and in challenge-snapshot.md's "Exit-Code Vocabulary" section. (c) A fixture lean4 plan with a
present-but-empty `## Lean Challenge Statements` section still fails loudly. (d) The identifier-set
cross-validation behaviour for ordinary lean4 plans is unchanged.

---

### 384. Adjudicate whether a books reconciliation postflight lifecycle hook is warranted, and add it only if the ruling is yes
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 383

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/books/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md).

GOAL. Rule on whether a lifecycle postflight hook is warranted for books reconciliation, and add one only if the ruling is yes. A reasoned NO, recorded so the question is not re-litigated, is an acceptable and complete outcome for this task.

VERIFIED STARTING FACTS (2026-10-10).
- agent-system/extensions/books/manifest.json has NO top-level `hooks` block at all today. It carries only provides.hooks (validate-evidence-append-only.sh, which is a file-copy target, NOT a lifecycle hook) and an `observers` block (books-observe). The two are distinct mechanisms and must not be conflated.
- The lean extension's hooks/ directory contains only lean-lsp-register-project.sh -- the sole in-repo lifecycle-hook precedent available to model against.
- The lifecycle hook schema (preflight, context_injection, verification, postflight stages, dispatched by skill-base.sh) is documented in docs/guides/creating-extensions.md#lifecycle-hooks.
- The books extension already has an advisory, non-blocking telemetry path: books-observe (scripts/books-observe.sh) writes one OBSERVATION record per books-topic task to specs/{NNN}_{SLUG}/book.observation.json, per context/project/books/standards/observation-record.md.
- The reconciliation probes themselves are books/tool/docs-stage.sh --json and books/tool/book-health.sh --json, both strictly read-only, stdout-only and build-free.

ADJUDICATION CRITERIA to settle during research.
- Does a postflight reconciliation hook add signal the books-observe observer does not already capture? If the observation record can carry the drift signals instead, the hook is redundant.
- Must such a hook stay advisory/non-blocking (the observers posture), or could it block? A blocking postflight gate over a whole-graph drift probe risks failing postflight on pre-existing drift wholly unrelated to the task that triggered it.
- Does it duplicate what an explicit on-demand /reconcile invocation already gives the user?
- Cost: a postflight hook runs on every books-topic task completion. Both probes are build-free but not free.

SCOPE. If the ruling is YES: add the top-level `hooks` block to agent-system/extensions/books/manifest.json, add the hook script under agent-system/extensions/books/hooks/, and document the stage and its posture in agent-system/extensions/books/merge-sources/claudemd.md. If the ruling is NO: record the ruling and its reasoning in merge-sources/claudemd.md (or the book convention record, whichever the research argues is the durable home) and change nothing else.

SERIALIZATION. This task is sequenced after the /reconcile command task: both edit agent-system/extensions/books/manifest.json, and the hook ruling depends on the command surface existing first.

ACCEPTANCE. A written ruling with reasoning grounded in the verified facts above. If YES, deploy succeeds and the hook fires at books postflight without blocking on pre-existing drift.

---

### 383. Add a /reconcile command to the books extension: aggregate docs-stage.sh and book-health.sh --json drift into one report, then propose follow-up tasks
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/books/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md).

GOAL. Add a /reconcile command to the books extension that aggregates the two as-built read-only reconciliation probes into a single report, then interactively proposes follow-up tasks for the drift it finds.

VERIFIED STARTING FACTS (2026-10-10).
- agent-system/extensions/books/commands/ contains exactly book.md, books.md, certify.md -- there is no reconcile.md.
- agent-system/extensions/books/skills/ contains skill-books-build, skill-books-certify, skill-books-implementation, skill-books-implementation-hard, skill-books-research, skill-books-research-hard, skill-books-review -- there is no reconcile skill.
- books/tool/book-health.sh header states: "READ-ONLY, STDOUT-ONLY, BUILD-FREE. This script writes nothing anywhere -- no file, no certificate, no evidence log -- and triggers no build, no certifier run and no docs-stage.sh invocation." It implements the twelve enumerated signals of the book convention's Decision 17 clause 10, and has a --json mode.
- books/tool/docs-stage.sh header states its report "is stdout, NEVER committed -- the same posture as typst/scripts/chapter-drift.sh --json", implementing Decision 17 clauses 6 and 8. It also has a --json mode.
- The design record that defines reconciliation is Decision 17 in the book convention. That record predates the 2026-10-08 books relocation and still cites docs/book-convention.md; the live location is books/convention.md.

CONFIRMED BEHAVIOR DECISION (settled with the user at creation time; do not re-litigate). /reconcile reads `books/tool/docs-stage.sh --json` and `books/tool/book-health.sh --json`, aggregates their output into one reconciliation report, and then interactively proposes follow-up tasks for the drift it finds -- the same shape /books --revise and /fix-it already use. It is NOT a pure read-only passthrough (that role is already filled by /certify), and it does NOT write a committed reconciled record. Both underlying tools are strictly read-only/stdout-only and MUST stay that way: /reconcile adds no write path to either, and must trigger no build and no certifier run.

SCOPE.
1. Author agent-system/extensions/books/commands/reconcile.md per the command-definition conventions in docs/guides/creating-commands.md, modeled on the existing books.md two-mode (--review / --revise) command shape.
2. Author agent-system/extensions/books/skills/skill-books-reconcile/SKILL.md as a direct-execution skill. No new agent: skill-books-review is the in-extension precedent for an interactive, direct-execution review-and-propose skill.
3. Register both the command and the skill in agent-system/extensions/books/manifest.json (provides.commands, provides.skills).
4. Add the command row to the Commands table and the skill row to the Skill-Agent Mapping table in agent-system/extensions/books/merge-sources/claudemd.md.

ACCEPTANCE. Deploy succeeds; /reconcile appears in the generated CLAUDE.md Commands table and the skill is listed by the harness; a run against a book with known drift produces one aggregated report plus an interactive task proposal; neither underlying tool writes any file during the run.

---

### 382. Refuse git stash pop/apply of a stash entry the session did not create
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [382_guard_foreign_stash_pop/reports/01_foreign-stash-pop-guard.md]
- **Plan**: [382_guard_foreign_stash_pop/plans/01_foreign-stash-pop-guard.md]
- **Summary**: [382_guard_foreign_stash_pop/summaries/01_foreign-stash-pop-guard-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md).

EVIDENCE (consumer repo ~/Projects/Logos/Verification, 2026-10-09). While diagnosing a test failure, an implementation agent ran `git stash push -- <path>` (which saved nothing: 'No local changes to save') and then `git stash pop`. With nothing of its own on the stack, the pop applied and DROPPED stash@{0}, an unrelated pre-existing user WIP entry from another task. Net tree effect happened to be zero, but the user's stash entry was removed from the list (recoverable only via git fsck). guard-destructive-git.sh already blocks bare `git stash`/`stash push` under concurrency and `stash drop`/`clear`, but explicitly permits `stash pop`/`apply` (git-workflow.md 'Not blocked').

GOAL. guard-destructive-git.sh (or the equivalent PreToolUse hook) refuses `git stash pop` and `git stash apply` -- bare or naming an entry -- unless the target entry was created by the same session (e.g. the guard records the stash commit sha whenever the session's own `git stash push` succeeds, and checks the target's sha against that record; research picks the mechanism). Refusal is exit 2 with guidance (`git stash show -p stash@{N}` to inspect; ask the user before applying a foreign entry). git-snapshot.sh's sanctioned snapshot/rollback flow must keep working. Update git-workflow.md's 'Not blocked' list and its narrative doc accordingly.

ACCEPTANCE. A fixture test: pop of a session-created entry passes; pop/apply of a foreign entry (including the 'push saved nothing, then pop' shape) is refused with exit 2; git-snapshot.sh rollback flow unaffected.

---

### 381. Catch stale derived artifacts at implement postflight and never let containment leave HEAD inconsistent
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None
- **Research**: [381_implement_postflight_derived_artifact_staleness/reports/01_postflight-derived-artifact-staleness.md]
- **Plan**: [381_implement_postflight_derived_artifact_staleness/plans/01_postflight-derived-artifact-staleness.md]
- **Summary**: [381_implement_postflight_derived_artifact_staleness/summaries/01_postflight-derived-artifact-staleness-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md).

EVIDENCE (an /orchestrate run in the consumer repo ~/Projects/Logos/Verification, 2026-10-09). An implementation dispatch fixed shellcheck findings in files that are certificate-identity inputs of TWO components there (components/framed_channel/check.sh; components/distsys/check.sh and scripts/lib/books-stage.sh) but ran only framed_channel's gate. That gate regenerated four framed_channel certificate files, which orchestrate-cycle-postflight.sh's file_scope containment then dropped as 'EXCURSION DROPPED' (drop-and-warn, advisory only), so the phase commit carried a changed check.sh while the committed digests.txt still named its old hash -- HEAD inconsistent. The distsys certificate was never regenerated at all. Both surfaced only through a manual local CI replay afterwards; on the remote they would have cost billed CI runs.

GOAL. (1) A repository-extensible postflight probe: the CONSUMER repo declares, in a documented place (e.g. a key in .claude-extensions.json or a project-overview/manifest field -- research decides), one or more build-free staleness commands (in that repo: every component's certificate-identity.sh --check). The implement phase runs them after the agent's last commit; a non-zero result fails the phase (or forces the declared regeneration) instead of reporting implemented. Generic: the agent system never hard-codes any repo's component list, and a repo that declares nothing behaves as today. (2) Containment must never leave HEAD inconsistent: regenerated files under a touched component's declared derived-output directory are either treated as in-scope derived output and committed with the change that caused them, or the phase fails loudly -- never silently dropped while the cause is committed.

ACCEPTANCE. A fixture reproducing this run's shape (an identity input of two components changed, only one gate run, regenerated certificate outside file_scope) ends the phase red or with every affected certificate committed; a repo declaring no probe is unaffected (regression fixture); docs name the declaration point.

---

### 380. Warn that archival un-tracks evidence-gate targets under the moved task directory
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [380_archival_silently_untracks_evidence_gate_targets/reports/01_warning-already-present.md]
- **Plan**: [380_archival_silently_untracks_evidence_gate_targets/plans/01_verify-archival-warning-present.md]
- **Summary**: [380_archival_silently_untracks_evidence_gate_targets/summaries/01_verify-archival-warning-present-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per rules/source-store-deploy-boundary.md.

Add a warning beside the archival mv stating that moving a task directory into the gitignored specs/archive/ un-tracks anything under it which an external gate or document references, so a producer knows to re-point or force-track before archiving.

--- WHAT WAS OBSERVED ---

Observed during a live /orchestrate run in the BimodalLogic consumer repo on 2026-10-09.

agent-system/extensions/core/context/patterns/task-abandon-mode.md (around lines 58-65) moves a task directory into specs/archive/ with mv. /todo archival does the same -- verified 2026-10-09 in agent-system/extensions/core/skills/skill-todo/SKILL.md, which carries the identical mv at its "Move directory from specs/ to specs/archive/" step and again in its vault path.

specs/archive/ is gitignored, so any evidence-gate entry pointing into a live task directory becomes UNTRACKED the day that task is archived. The failure is SILENT and ASYMMETRIC: the gate still passes locally for anyone holding the file on disk, and fails in CI from a clean checkout.

--- EVIDENCE FROM BimodalLogic ---

Two gate-referenced files were tracked under their live task paths, deleted from the index by archive commit 70321e938, then re-pointed at the ignored specs/archive/ paths by e8cfcd868. That consumer repo's gate tests file presence only, so it reported PASS on all 28 probes during the observing run while CI would fail from a plain checkout.

--- SCOPE, AND THE BOUNDARY MATTERS ---

IN SCOPE (the agent-system half): a warning beside the mv in task-abandon-mode.md, and beside the matching mv in skill-todo/SKILL.md, stating that archival un-tracks anything under the moved directory which an external gate or document references, so a producer knows to re-point or force-track before archiving.

OUT OF SCOPE (the repo-side half): a tracked-ness check in the BimodalLogic consumer repo's own scripts/check-evidence-probes.sh. That is ALREADY FILED in that repo as its own task and must not be duplicated here. task-abandon-mode.md was deliberately left out of that repo-side task's file_scope precisely because its real edit target is this out-of-repo source store, which a repo-relative file_scope entry cannot express.

--- CROSS-REFERENCE (PROSE ONLY -- NO dependencies[] EDGE, DELIBERATELY) ---

Task 338 (sweep_task_support_file_tracked_or_ignored) is ADJACENT, not the same defect. 338 classifies producer-written support files under specs/ as tracked or ignored, and its own item 4 invites coordination over untracked task directories.

It is NOT this defect: 338 concerns the gitignore enumeration for files a producer writes; this concerns a lifecycle operation invalidating external references. 338's file_scope does not reach task-abandon-mode.md. Named here so whoever takes either one coordinates instead of duplicating.

--- NEAREST MISSES, CHECKED AND REJECTED ---

Checked /home/benjamin/.config/nvim/specs/state.json by project_name and by description text: this defect is not filed.

- 338 sweep_task_support_file_tracked_or_ignored (not_started) -- REJECTED as a duplicate for the reasons stated under CROSS-REFERENCE above; cross-referenced rather than merged.

---

### 379. Make specs/archive/state.json validatable by validate-state.sh
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [379_validate_state_cannot_validate_archive_state/reports/01_archive-state-validation-gate.md]
- **Plan**: [379_validate_state_cannot_validate_archive_state/plans/01_archive-mode-validation.md]
- **Summary**: [379_validate_state_cannot_validate_archive_state/summaries/01_archive-mode-validation-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per rules/source-store-deploy-boundary.md.

Make an archive insert validatable by the standard gate: validate-state.sh cannot validate specs/archive/state.json at all, so /task --abandon's archive insert has no validation gate.

--- WHAT WAS OBSERVED ---

Observed during a live /orchestrate run in the BimodalLogic consumer repo on 2026-10-09. validate-state.sh assumes an .active_projects array that specs/archive/state.json does not carry, so it cannot validate the archive file.

VERIFIED NOT A REGRESSION: it fails identically against the pre-run HEAD copy of the archive.

--- CONSEQUENCE ---

The archive insert performed by /task --abandon has no standard validation gate. While closing one task as subsumed in BimodalLogic, the implementer had to fall back to targeted jq to confirm the archive insert had landed.

--- SCOPE ---

The fix DIRECTION IS DELIBERATELY LEFT OPEN to the implementer -- teach the script the archive's shape, or give it an explicit --archive mode. What is NOT open is the requirement:

1. An archive insert must be validatable by the standard gate.
2. A silent inability to validate is the defect, regardless of which shape is chosen. Whichever direction is taken must not leave the archive file in a state where the gate neither validates it nor says it cannot.
3. Extend the existing test at agent-system/extensions/core/scripts/tests/test-validate-state.sh (verified present 2026-10-09) to cover the archive shape.

--- NEAREST MISSES, CHECKED AND REJECTED ---

Checked /home/benjamin/.config/nvim/specs/state.json by project_name and by description text: this defect is not filed.

- 303 validate_state_cwd_relative_default_resolution (completed) -- REJECTED: concerns cwd resolution of the default state path, not the archive file's shape.

---

### 378. Resolve the reviser-agent handoff contract contradiction between skill-orchestrate and orchestrate-cycle-plan.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 274

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per rules/source-store-deploy-boundary.md.

Resolve the contradiction over whether a reviser-agent plan dispatch is contractually required to write .orchestrator-handoff.json: skill-orchestrate/SKILL.md and orchestrate-cycle-plan.sh currently state different things, and cycle postflight flags the resulting gap as UNEXPECTED.

--- WHAT WAS OBSERVED ---

Observed during a live /orchestrate run in the BimodalLogic consumer repo on 2026-10-09. orchestrate-cycle-postflight.sh queued defect_class=HANDOFF_STALE_OR_ABSENT with attributed_path=agent-system/extensions/core/skills/skill-orchestrate/SKILL.md and detecting_site=skill-orchestrate/SKILL.md:cycle-postflight-stale-handoff, logging verbatim:

  "RECOVERY: no handoff written for this plan dispatch -- this is UNEXPECTED: the plan phase's writer is contractually required to write .orchestrator-handoff.json on every orchestrator_mode: true dispatch."

Recovery from .return-meta.json succeeded (status=planned recovered); no task status was mutated and nothing was lost. The durable record is in BimodalLogic's specs/events.jsonl.

--- EVIDENCE ---

Session sess_1791577470_f6dff1, dispatch_seq 5, agent reviser-agent, forced plan round via --force-phases plan.

DISCRIMINATING FACT: the immediately preceding plan dispatch in the SAME session (dispatch_seq 4, planner-agent) DID write a valid handoff -- postflight logged HANDOFF VALIDATION PASSED with 11 checks, 0 warnings, 0 failures. The gap is therefore specific to reviser-agent, not to the plan phase in general.

--- ROOT-CAUSE HYPOTHESIS (STATED AS A HYPOTHESIS TO VERIFY, NOT A SETTLED DIAGNOSIS) ---

skill-orchestrate/SKILL.md's Skill-to-Agent Mapping table lists "Plan revision (blocker) | reviser-agent | Fresh context; orchestrator_mode: false", and its Move 2 documents an aux_dispatch[] row as carrying NO handoff_path key at all. But orchestrate-cycle-plan.sh emits reviser-agent as a dispatch[] row for a forced plan round, and Move 2's dispatch[] code path sets orchestrator_mode: true and passes handoff_path.

IF that holds, one agent is reachable by two call paths with contradictory handoff expectations, and postflight flags a missing handoff for a dispatch whose agent may never have been instructed to write one. Verify this against agents/reviser-agent.md and BOTH call paths before acting on it; it has not been confirmed.

--- SCOPE ---

1. Verify the hypothesis against agents/reviser-agent.md and both call paths (the aux_dispatch[] path and orchestrate-cycle-plan.sh's forced-plan dispatch[] path) before choosing a direction.
2. The two candidate fixes have materially different blast radii, and this record deliberately does NOT presuppose one. State which files each direction touches before choosing:
   (a) Make reviser-agent write a handoff on an orchestrator_mode: true dispatch.
   (b) Stop classifying a forced-plan reviser row as a handoff-writing dispatch.
3. If the contract text lives in docs/architecture/handoff-schema.md, the fix must land there too, so all three statements (skill, script, schema doc) agree.

--- NEAREST MISSES, CHECKED AND REJECTED ---

Checked /home/benjamin/.config/nvim/specs/state.json by project_name and by description text: this defect is not filed.

- 370 handoff_schema_reaches_dispatched_agent (completed) -- REJECTED: concerns the handoff SCHEMA reaching the agent via docs plus lint-agent-contracts.sh, not a writer failing to emit the file at all.

---

### 376. Lean implementation agents mandate the detach-then-await-notification path core forbids, stranding dispatches mid-phase
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 393

**Description**: # Proposed task: lean implementation agents mandate the detach-then-await path core forbids

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/** (never a deployed .claude/** tree).
REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/**.

## GOAL

The lean extension's implementation agents instruct an agent to background a local gate/build and
then wait for a harness completion notification. That is exactly the path
core/agents/general-implementation-agent.md forbids, and it strands implement dispatches
mid-phase. Remove the contradiction without discarding lean's underlying livelock protection.

## SCOPE DECISION (settled at task creation; do not re-litigate)

SCOPE IS THE LEAN EXTENSION ONLY, PLUS A NAMED SUCCESSOR. Fix the lean agent definitions and
settle the wording ruling here. The cross-extension duplication audit is DELIBERATELY OUT OF
SCOPE for this task and must be carried out by a named successor task created as part of this
task's own wrap-up -- not folded in, and not left unrecorded. Rationale: this keeps the task to
roughly one agent run, and the "should the mandate be inherited from one place instead of
restated per-extension" question is a genuine design ruling that deserves its own record rather
than being decided in passing while fixing lean.

NO DEPENDENCY EDGE ON THE ADJACENT SUBAGENT-WAIT TASK. Cross-reference it in the description so
both rulings use consistent wording, but declare `dependencies: []`. Rationale: that task's own
hazard is explicitly unestablished (its one piece of apparent evidence was a retracted
misdiagnosis), whereas this task's stranding is measured; blocking the measured fix behind the
unestablished one inverts the evidence. Neither task blocks the other.

## MEASURED INCIDENT (2026-10-09, BimodalLogic repo, session sess_1791529054_4455fa)

An /orchestrate implement dispatch (task 733, task_type lean4, dispatch_seq 4, agent
lean-implementation-agent, model fable) committed phases 1 and 2, then backgrounded the local
evidence-probe gate (`bash scripts/check-evidence-probes.sh`, a 25-probe sweep), reported:

  "The baseline gate is about halfway through (12 of 25 probes passed so far). I'll wait for its
   completion notification before editing the script"

and went idle permanently. Observed end state:
- Phase 3 (wire one WIRED entry + table row into scripts/check-evidence-probes.sh) never done:
  `grep -c backward-dual-mirror-fixture scripts/check-evidence-probes.sh` returned 0.
- .return-meta.json left at status "in_progress", with null dispatch_seq, null phases_completed,
  null phases_total.
- No .orchestrator-handoff.json written.
- The agent resumed and finished ONLY after the orchestrator sent an explicit SendMessage
  re-prompt on the same dispatch_seq. Nothing else would have resumed it.

Phases 1-2 were durably committed (5604c4df4, 343fb473c), so the loss was phase 3 plus the
terminal metadata, not the whole dispatch.

## THE CONTRADICTION (verifiable by reading two files in the source store)

extensions/core/agents/general-implementation-agent.md
- :188 "MUST NOT use `Bash(run_in_background: true)` or arm a `Monitor` to watch a local
  verification, gate, build, or test process from within this dispatched subagent".
- :205 "MUST NOT end the turn on an unresolved local background wait. Detaching a local command
  and then stopping to wait for a harness completion notification hands the dispatch back
  unfinished with no handoff and no `.return-meta.json`."
- :182 whenever a local gate is backgrounded at all, use bounded-build-waiter.md's canonical
  idiom VERBATIM (captured `pid=$!`, `kill -0` liveness loop, outer `timeout N`) all inside ONE
  Bash call that does not return control until the wait resolves -- because that shape "never
  surfaces a 'wait for a notification' choice point, so there is no point at which the turn could
  end mid-wait".
- :196 MUST prefer plain foreground `timeout N cmd` when the command plausibly fits the Bash
  ceiling.
- :199-204 states the ruling: backgrounding a local gate is not itself unsafe; the unsafe thing is
  the harness-asynchronous detach-then-await-notification path, because nothing automatically
  re-enters a turn that has already ended.

extensions/lean/agents/lean-implementation-agent.md
- :337 "Run this via `Bash(run_in_background: true)` -- a foreground call can livelock past the
  tool's own timeout on a long build ... and wait for the harness's completion notification before
  recording the result."  <-- instructs the forbidden wait explicitly
- Same detach-then-await instruction recurs at :30, :70, :741, :768.
- MUST NOT #13 (~:767) forbids running a `lake build` as a plain foreground Bash call outright,
  so the agent cannot take core's preferred foreground form for builds.

Net effect: a lean dispatch is instructed onto the unresumable path AND barred from the form core
prefers. The agent complied with its own definition. This is a CONTRACT defect, not an
agent-behaviour defect.

Also matched a grep for run_in_background/bounded-build-waiter and MUST be checked rather than
assumed clean: extensions/lean/agents/lean-implementation-hard-agent.md,
lean-research-agent.md, lean-research-hard-agent.md.

## BE HONEST ABOUT WHAT IS AND IS NOT ESTABLISHED

ESTABLISHED: the textual contradiction (read the two files); the stranding with its exact symptom
signature (in_progress return-meta, absent handoff, missing phase-3 edit); that an inbound message
was the only thing that resumed it.

NOT ESTABLISHED: whether lean's underlying livelock concern is still real at current timeouts.
long-builds.md's rationale (a killed build caches no .olean, so retries restart at the same module
and livelock) may well be sound. DO NOT resolve this by deleting lean's detachment rule without
testing that claim. The likely correct fix is to KEEP detachment and replace only the WAIT step
with bounded-build-waiter.md's single-Bash-call idiom, preserving livelock protection while
removing the turn-ending choice point.

## ALSO SETTLE

- The cross-extension duplication is SCOPED OUT per the decision above, but must not go
  unrecorded. ~18 other *-implementation-agent.md files (books, cslib, z3, latex, nvim, python,
  nix, typst, web, rust, email, pr-review) matched the same grep and may each carry a divergent
  copy of the wait rule. This task's wrap-up MUST create a named successor task to audit them and
  to rule on whether the mandate should be inherited from one place rather than restated
  per-extension. Record the grep evidence for that successor rather than making it re-derive it.
  A per-file fix that leaves the duplication intact will drift again -- which is exactly why the
  successor is an obligation here, not an optional nicety.
- The gate in the measured incident was NOT a lake build -- it was a probe-sweep shell script.
  lean's rule is written about `lake build` specifically and the agent generalized it to any long
  local gate. Whatever wording lands must say explicitly which processes it governs.
- Whether lake-build-guard.sh should itself expose a blocking foreground mode, so the correct
  idiom is the path of least resistance rather than something each agent hand-assembles.
- The deployed .claude/ trees for core and lean were reported STALE relative to the source store
  during the measured run (skill-base WARN, extensions: core lean). Determine whether the stale
  deployed copy differed in this wording, since that changes whether a redeploy alone would have
  prevented the incident.

## EXPLICIT NON-GOALS

DO NOT widen stall_suspected's trigger predicate. That non-widening is a recorded prior ruling and
this task produces no evidence bearing on it. Note separately that orchestrator-side postflight
never got a chance to flag this because the dispatch never returned at all; if any detector work is
proposed, argue it on its own merits and keep it out of stall_suspected.

## BACKLOG RECONCILIATION (checked 2026-10-09 against the 30 open tasks in ~/.config/nvim specs/state.json)

No open task covers this.
- 354 [PLANNED] "Rule on whether the local-gate backgrounding prohibition must also cover waiting
  on a dispatched subagent" is the nearest neighbour and is explicitly a DIFFERENT case: it
  concerns awaiting a dispatched SUBAGENT, states the local-gate case was already settled by task
  343, and records that the one incident which looked like evidence for it was a RETRACTED
  misdiagnosis. This task is the local-gate case actually recurring, in a different extension,
  with a confirmed stranding and a quotable contradiction -- new evidence 354 does not have.
  Per the SCOPE DECISION above, NO dependency edge is declared (`dependencies: []`); 354 is
  cross-referenced for wording consistency only. They are not the same task.
- 359 is scoped by its own argument to exactly two curated-array gaps on two files for the
  twenty-three RESEARCH agents and should not absorb this.
- 347 (PreToolUse hook blocking self-matching process-name waiters) is a different defect class.

## FILE SCOPE

Expected: extensions/lean/agents/lean-implementation-agent.md and the three other lean agent files
named above; possibly extensions/lean/context/project/lean4/operations/long-builds.md;
possibly core/scripts/lake-build-guard.sh. Confirm and SET file_scope AT PLAN TIME.

## ACCEPTANCE

- No lean agent definition instructs an agent to end its turn awaiting a harness notification for
  a local gate or build, and none is left unable to comply with core's preference.
- The fix is demonstrated against a real artifact -- a composed dispatch file, a lint run, or a
  replayed gate invocation -- not asserted in prose.
- If lean's livelock rationale is upheld, the retained detachment is paired with the bounded
  single-call wait idiom, and the guard invocation implementing it is shown working.
- A named successor task exists for the cross-extension duplication audit, carrying this task's
  grep evidence forward. (Fixing the other extensions inside this task is OUT OF SCOPE.)
- Redeployed if any deployed file changed, and the stale-tree question answered.

---

### 369. Orphan sweep for deployed entries removed from the source store: the deploy adds and changes but cannot delete
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 29, Task 365

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/ and lua/neotex/plugins/ai/ (never
.claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. The extension deploy can ADD and CHANGE but cannot DELETE. A merge-target entry removed
from the source store survives indefinitely in every already-deployed repo, because the merge
path only visits entries the fragments still provide and install-once files are never recopied.
Close that gap for hook registrations, and state the invariant where a future editor will meet it.

LIVE INSTANCE, observed 2026-10-07 in this repo's own deployed .claude/settings.json line 21:

    "command": "bash scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'"

The source-store registration was deleted (root-files/settings.json is clean, verified). The
deployed copy still carries it, and no resync can remove it: the fragment merge only adds or
replaces entries it visits; install-once never recopies settings.json; and because the entry was
never in a fragment, unmerge_settings has no tracked record of it either. It is an orphan. It
invokes a script that exists nowhere, failing silently behind its own `2>/dev/null || echo '{}'`,
which is why it went unnoticed. Severity is low -- a silent no-op, not a disabled guard -- but the
CLASS is not low: the same mechanism would silently retain a registration that had become actively
wrong.

PRECEDENT TO EXTEND, not invent. merge.lua already solves exactly this shape for a different
merge target: `remove_orphaned_index_entries(index_path, valid_prefixes, context_dir)` at
merge.lua:755, documented at :746 and :689 as "cleaning orphaned entries that bypass tracked
append/remove". Hook registrations have no counterpart. Follow that function's structure and
call-siting rather than designing a new mechanism.

SCOPE:
  - An orphan sweep for hook registrations: on load/resync, remove a `.claude/hooks/*.sh` (or
    other source-store-resolvable script) registration from the target settings file when no
    loaded extension's fragment or root-files surface still provides it.
  - Reconcile the identity notion with the lint's. The hook-path lint task's research recorded a
    DOCUMENTED DIVERGENCE: that lint keys fragment-coverage on any invoked script path, while
    merge.lua's hook_identity() recognizes only paths under `hooks/`. The divergence was accepted
    in that task's scope, not resolved. Resolve it here, in ONE place both consume, so a later
    reader cannot find two different answers to "is this the same registration".
  - MUST NOT remove a hand-written hook. The existing custom-hook carve-out (a command not
    recognizable as a source-store hook invocation is never matched, moved or deduped) governs the
    sweep too: an unrecognized command is left strictly alone, never swept as an orphan. This is
    the single most dangerous possible regression in this task -- a sweep that over-reaches
    silently deletes a user's own hook registration.
  - State the invariant in the source-store/deploy-boundary documentation: the deploy adds and
    changes but does not delete, which merge targets now sweep orphans and which do not, and the
    by-hand repair for a deploy predating a sweep (`rm .claude/settings.json` then reload --
    install-once copies fresh only when the target is ABSENT; `deploy-headless.sh --wipe` restores
    its own snapshot as the merge base and reintroduces the staleness).

REGRESSION SAFETY is a first-class requirement, not a closing check:
  - Measure the affected deploys BEFORE and AFTER: registration count, per-event duplicate count,
    and that `env` and `permissions` survive byte-identical. A settings file is not "fine" because
    it parses.
  - Verify against a REAL stale deploy, never only a synthetic fixture. A fixture reconstructed
    from memory cannot carry the shapes a field file actually has.
  - Anchor detection on the `"command"` JSON key, not a text grep. A naive `.claude/hooks/` grep
    matches root-files/settings.json's own `_comment` field -- a false-positive hazard already
    found by the lint task's research.
  - Run the pre-existing extension/merge specs, not only new ones, and treat a newly red
    pre-existing test as a regression this task caused.

NON-GOALS (owned elsewhere; do not absorb, and do not edit their files):
  - Script and test corpus duplication, dead code and slow tests -- the standing probe-consumer
    task owns these as one systemic item, per the settled decision that a systemic cost is filed
    once against a probe's output rather than as a stream of point defects.
  - Context-corpus reachability and dead/overlapping context files -- owned by the reachability
    probe task.
  - Neovim repo hygiene (stale init.lua.backup, project-overview.md regeneration, README link) --
    owned by the repo-hygiene task.
  - Task support files tracked-or-ignored -- owned by the support-file sweep task.
  - Missing `desc` fields on keymap.set calls -- owned by the keymap documentation task.
  Removal propagation is this task's only subject; the generic word "cruft" must not be used to
  pull any of the above in.

ACCEPTANCE CRITERIA:
  1. A registration present in the deployed target but provided by no loaded extension's fragment
     or root-files surface is removed by an ordinary load/resync, demonstrated against the live
     line-21 instance above (or a faithful copy of that file if it has since been repaired).
  2. A hand-written hook command not recognizable as a source-store hook invocation survives a
     sweep untouched, with a dedicated regression test.
  3. The identity notion is defined in exactly one place, consumed by both the sweep and the
     hook-path lint; a test asserts the two agree on a path outside `hooks/`.
  4. Before/after measurements are reported for every affected deploy: registration count, zero
     per-event duplicates, and `env`/`permissions` byte-identical.
  5. The pre-existing extension/merge specs still pass; any newly red pre-existing test is treated
     as caused by this task.
  6. The source-store/deploy-boundary documentation states the add/change-but-not-delete invariant,
     names which merge targets sweep orphans, and records the by-hand repair for an older deploy.

---

### 362. Teach the non-destructive history-read techniques at the point of use, so an implementation agent inspecting past file state never reverts a shared working tree
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 356, Task 359

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md): cite by filename, command or concept. Task numbers are permitted in this description and elsewhere in specs/**.

GOAL. Teach the non-destructive history-read techniques AT THE POINT OF USE, so an implementation agent that needs to inspect historical file state reaches for a read-only technique instead of reverting a shared working tree.

=== WHY THIS IS A MISSING-INSTRUCTION SIGNAL, NOT TWO COINCIDENCES ===

2026-10-07, Logos/Verification, one /orchestrate batch of four tasks sharing one working tree. TWO implementation agents INDEPENDENTLY reached for the same wrong tool (bare whole-tree `git stash`) for the same CORRECT need: isolating a pre-existing test failure from their own edit. Independent convergence on one wrong tool by two agents is a missing-instruction signal.

THE RIGHT TECHNIQUES ALREADY EXIST AND WERE USED ELSEWHERE IN THE SAME BATCH -- which is what proves the gap is discoverability, not capability:
  - One planner used a DETACHED WORKTREE for a read-only historical inspection, successfully.
  - One implementation agent recovered its OWN lost edit safely, via a read-only `git show <stash-ref>:path` extraction.
Nothing teaches either technique where an IMPLEMENTATION AGENT would look. The knowledge was in the system and still did not reach the two agents who needed it.

RE-DERIVE THESE BEFORE RELYING ON THEM. The two-agent count, the detached-worktree planner instance, and the `git show <stash-ref>:path` recovery instance are carried figures in this description. Re-confirm them and report any divergence.

=== DECIDED CONTEXT -- DO NOT REOPEN ===

The user has ruled OUT per-agent worktree isolation for parallel dispatch, consistent with the existing decision record specs/decisions/worktree-isolation-removal-reaffirmation.md and the confirmed re-argued verdict recorded in the measured-co-scheduling-signal task's NON-GOALS. PARALLEL DISPATCHES WILL CONTINUE TO SHARE ONE WORKING TREE AS A DELIBERATE CHOICE.

Therefore the only defences against cross-task interference are:
  (a) declared file_scope disjointness at admission,
  (b) dependencies[] edges for ordering,
  (c) AGENT-SIDE DISCIPLINE about tree-wide operations.
THIS TASK SUPPLIES (c). Do NOT propose, re-rule on, or defer a question about worktree isolation. A deliverable that reopens it is out of scope.

=== SCOPE ===

Author a SHORT shared-worktree discipline section stating:
  - Read history with `git show HEAD:path` or `git show <ref>:path`; read differences with `git diff HEAD -- path`.
  - Copy to a scratchpad for experiments that need a mutable file.
  - NEVER `git stash`, `git checkout -- <path>`, or `git restore <path>` on a shared tree -- these revert the tree out from under concurrent writers.
It must be REACHABLE FROM THE IMPLEMENTATION AGENT DEFINITIONS, not merely filed somewhere correct. A section nobody's context path reaches is the same failure this task exists to fix.

DETACHED WORKTREE: it MAY be mentioned, but it MUST be explicitly labelled a READ-ONLY INSPECTION TECHNIQUE and never an isolation strategy, so no reader can take it as reopening the settled question above.

KEEP IT SHORT. A section, not a framework. Prefer amending `context/standards/git-safety.md` (which already owns "git as the safety mechanism") over creating a new document; survey it and `context/standards/git-workflow-narrative.md` before deciding, and record the rejected placement.

=== OVERLAP GUARD (MANDATORY) AND THE DEPENDENCY CHOICE MADE HERE ===

STAY OFF the territory of two open tasks:
  - The no-op-spin / single-writer-discipline task for shared fixture trees. Do not touch its wait-pattern documents or its no-op detection hook.
  - The bounded-wait propagation task, which is CURRENTLY IMPLEMENTING and is propagating the bounded-wait contract to FOURTEEN implementation agent definitions -- the very files this task must add a pointer to.

THE CHOICE: this task DECLARES A DEPENDENCY on the bounded-wait propagation task (dependencies: [356]) rather than confining itself to the shared standards file. Reasoning: the scope requires reachability FROM the implementation agent definitions, and the confine-only alternative would leave the new section orphaned, since the in-flight propagation pass cannot carry a pointer to a document that does not yet exist when it runs. Serializing behind it gets both the shared section AND a live pointer, with no concurrent edit to the fourteen definitions. The declared file_scope reflects this: it names the shared standards file plus the agent definitions, and the dependency edge is what makes that safe.

=== EXPLICIT NON-GOALS ===

- Do NOT propose, revisit, or defer per-agent worktree isolation (see DECIDED CONTEXT).
- Do NOT modify the guard hook or the git-workflow rule -- that is the stash-reclassification task's territory.
- Do NOT author the post-incident verification checklist -- separate task.
- Do NOT edit the wait-pattern documents or no-op hook owned by the single-writer-discipline task.
- Do NOT duplicate the bounded-wait contract text; this section covers tree-wide git operations only.
- Do NOT hand-edit any deployed `.claude/**` copy.

=== ACCEPTANCE ===

- A shared-worktree discipline section exists, naming the read-only techniques and the three forbidden tree-reverting commands.
- It is reachable from the implementation agent definitions via a live pointer, and that reachability is demonstrated (a cited path from an agent definition to the section), not merely asserted.
- The detached-worktree mention, if present, is explicitly labelled read-only inspection and not isolation.
- The deliverable is a section, not a new framework; net document count increase is zero or one, with the placement decision recorded.
- No edits land on the no-op-spin task's files, and no edit to the fourteen agent definitions occurs before the bounded-wait propagation task completes.
- Nothing in the deliverable proposes or defers worktree isolation.
- No task-number references in any deliverable outside specs/**.

---

### 360. Validate that every CARRIED-UNVERIFIED mark names a source, as an advisory-only well-formedness check
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 358

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere in specs/**.

GOAL. report-format.md's "## Carried-Figure Discipline" section now requires that a figure or mechanical claim carried from another record be re-derived at authoring time or marked inline as `{figure} [CARRIED-UNVERIFIED: {source path}]`, with the source MANDATORILY named. The mark is today a pure authoring-side obligation: nothing checks that a mark exists where one is owed, and nothing checks that a mark which does exist actually names a source. report-format.md's own "**Enforcement level**" paragraph records the source-naming validation as a named future item, deliberately not built. Build that narrow piece.

=== SCOPE: THE NARROW CHECK ONLY ===

Check exactly this: every `[CARRIED-UNVERIFIED:` occurrence in a report or plan artifact is followed by a non-empty source designator before the closing bracket. That is a well-formedness check on a fixed literal token the contract itself defines -- greppable, unambiguous, and with no natural-language judgment in it.

=== DO NOT REBUILD THE DETECTOR THAT ALREADY FAILED ITS GATE ===

This is the critical constraint. A DIFFERENT and much more ambitious check -- a general detector for carried-figure contradictions, specifically the assert-absence-of-a-mandated-literal shape -- was specified, measured, and REJECTED on evidence. Its decision gate failed all three pre-stated criteria (measured 2026-10-07, recorded in that task's progress/phase-4-progress.json):

  RECALL:      the specified ERE missed the one known positive, because markdown bold (`**not**`) splits the trigger phrase "does not contain". It flagged an unrelated non-contradictory duplicate instead.
  PRECISION:   0 of a 12-file hand-inspected sample of flagged files were genuine; all were ordinary prose quoting a short literal (a filename, a command name, a common word) more than once.
  BOUNDEDNESS: 92 files flagged across a 2711-file corpus, against a 5-flag threshold -- "an advisory nobody can triage is noise, not a check".

That rejection stands and is not this task's business to revisit. The reasoned-infeasibility finding plus the reviewer prompt already in report-format.md are the complete answer for the general case. This task builds ONLY the source-naming well-formedness check, which is a different shape entirely: a literal token's syntax, not a semantic contradiction.

HEED THE RECALL FAILURE MODE ANYWAY. The reason that detector missed its known positive -- markdown inline formatting interrupting a matched phrase -- applies to this check too, because a mark may be written inside emphasis, inside a table cell, or wrapped across lines. Test those shapes deliberately rather than assuming a naive pattern holds.

=== ALSO SETTLE ===

- Whether the check belongs in validate-artifact.sh (which already has an advisory-first precedent in its Verification Tier check) or elsewhere. Follow the existing advisory-first convention: ship as log_warn-only, document the promotion criterion, and state explicitly that promotion to blocking is NOT part of this change.
- Whether a mark whose named source does not RESOLVE (a path that does not exist) should warn too, or whether that over-reaches into the territory the failed gate occupied. Rule on it; do not silently pick one.
- Whether the complementary obligation -- a mark is OWED where a figure was carried without re-derivation -- is detectable at all. The strong prior is NO, for the same reasons the general detector failed. If that is the conclusion, record it as a reasoned exclusion rather than leaving the question open, and say so in report-format.md's Enforcement-level paragraph.

=== NON-GOALS ===

- No general contradiction detection. No re-litigating the rejected gate.
- No new documents: extend validate-artifact.sh and, if the Enforcement-level paragraph needs updating to describe what shipped, report-format.md.
- Do not change the contract's substance in report-format.md -- the trigger classes, the mark syntax and the reviewer prompt are settled. Only the enforcement-level description may change, and only to match what actually ships.

=== ACCEPTANCE ===

- A mark missing its source designator produces a named advisory; a well-formed mark produces none.
- Exit codes unchanged in default mode: an advisory must not fail an artifact.
- Fixtures cover the plain shape, a mark inside markdown emphasis, a mark inside a table cell, and a line-wrapped mark -- the recall failure mode that sank the rejected detector is tested, not assumed away.
- Run against the real corpus: report the flag count. If it exceeds a triageable handful, say so and treat that as a finding about the corpus rather than shipping an untriageable advisory.
- The does-the-source-resolve question and the is-a-mark-owed question are each ruled on in writing.
- validate-artifact.sh stays shellcheck clean per context/standards/shell-strict-mode.md. Redeployed.

---

### 359. Close the two measured curated-array coverage gaps in the agent-contract lint: normalize the books agents Check C/G bullets, and rule on bounded-wait scope for the twenty-three research agents
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 350, Task 356

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere in specs/**.

GOAL. lint-agent-contracts.sh asserts contract-bullet coverage against CURATED path arrays, one per check. Two gaps in those arrays are now measured, not suspected. Close both, and in doing so rule on whether the curated-array shape is the right mechanism at all or whether it structurally invites this drift.

Both gaps are the same mechanism on the same two scripts (lint-agent-contracts.sh and its test file), which is why they are one task rather than two: splitting them would force a serializing dependency between two tasks editing the same two files, for no gain.

=== GAP 1: THE BOOKS AGENTS ARE ABSENT FROM CHECK C AND CHECK G ===

MEASURED 2026-10-07 by direct re-derivation against the lint's own expected text (the fragment lines it greps for), not carried from a prior record:

  books/agents/books-implementation-agent.md       C=MISS G=MISS
  books/agents/books-implementation-hard-agent.md  C=MISS G=MISS

Neither file appears in Check C's IN_SCOPE_RELATIVE_PATHS (32 lines) nor Check G's OWNERSHIP_IN_SCOPE_RELATIVE_PATHS (16 lines). Both DO appear in the newly added Check H's BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS and both PASS it.

A PRIOR RECORD STATES THIS GAP INCORRECTLY. The bounded-wait propagation task's summary records this as a pure curated-list omission, asserting both files "carry the no-task-references bullet (confirmed by direct grep)". That assertion does not survive re-derivation and the correction changes the fix:

  - books-implementation-agent.md item 6 carries the canonical Check C wording but LINE-WRAPPED across two lines ("-- see\n   `.claude/rules/...`"). The lint greps a single line with grep -qF, so a wrapped bullet cannot match however correct its prose.
  - books-implementation-hard-agent.md item 7 is an ABBREVIATED PARAPHRASE ("Reference task numbers in files outside `specs/**`") missing both the ("task N", "tasks N-M") parenthetical and the rule cross-reference.
  - Check G's bullet is absent from both as a bullet. books-implementation-agent.md discusses `**Status**:` ownership in prose (around lines 100-101 and 126-127) but not as the canonical MUST-NOT line.

CONSEQUENCE: adding the two paths to the C and G arrays WITHOUT first normalizing the bullet text makes the lint FAIL. Normalize first, then register. Do not trust the prior summary's framing; the measurement above is the baseline.

RULE ON THE LINE-WRAP CASE SPECIFICALLY. A single-line grep -qF against a hand-wrapped markdown bullet is brittle by construction: a correct contract fails the check purely on line breaks. Decide whether the checks should normalize whitespace before comparing (making wrapped-but-correct bullets pass) or whether the fragment bullets must be held unwrapped by convention. Whichever is chosen, state it where a future bullet author will see it, and pin it with a fixture.

=== GAP 2: ALL TWENTY-THREE RESEARCH AGENTS LACK THE BOUNDED-WAIT BULLET PAIR ===

MEASURED 2026-10-07 across every *research*agent*.md in the source store, against the two canonical fragment lines Check H greps: covered=0, missing=23.

  books/agents/books-research-agent.md, books/agents/books-research-hard-agent.md,
  core/agents/general-research-agent.md, cslib/agents/cslib-research-agent.md,
  cslib/agents/cslib-research-hard-agent.md, cslib/agents/pr-review-research-agent.md,
  epidemiology/agents/epi-research-agent.md, formal/agents/formal-research-agent.md,
  formal/agents/logic-research-agent.md, formal/agents/math-research-agent.md,
  formal/agents/physics-research-agent.md, founder/agents/deck-research-agent.md,
  latex/agents/latex-research-agent.md, lean/agents/lean-research-agent.md,
  lean/agents/lean-research-hard-agent.md, nix/agents/nix-research-agent.md,
  nvim/agents/neovim-research-agent.md, present/agents/slides-research-agent.md,
  python/agents/python-research-agent.md, rust/agents/rust-research-agent.md,
  typst/agents/typst-research-agent.md, web/agents/web-research-agent.md,
  z3/agents/z3-research-agent.md

The bounded-wait propagation task deliberately scoped research agents OUT, recording the reason in the fragment itself: its measured evidence and acceptance surface were implementation-agent-only. It recommended this follow-up reusing the identical mechanism. Two specifics it recorded and this task must honour or refute:

  - general-research-agent.md already carries the REMOTE-wait half of the discipline but not the local-build half -- the same partial-coverage shape that motivated the original propagation.
  - The Lean research agents' run_in_background hits are a SEPARATE SANCTIONED build-guard path, not instances of the defect. Do not count them as coverage and do not break them.

DO NOT ASSUME ALL 23 ARE IN SCOPE. The bullet forbids backgrounding a LOCAL verification/gate/build/test process. A research agent with no Bash access, or one that never runs a local build, is not exposed and a bullet it cannot violate is noise. Determine which subset genuinely holds the exposure (frontmatter tool grants plus actual local-build invocation), and record the excluded files WITH THEIR REASON the way the implementation-agent fragment already records its own exclusions. An evidenced "fewer than 23 are in scope" is a complete and preferred outcome; a blanket 23-file propagation justified only by the file-name glob is not.

=== ALSO SETTLE ===

- Whether the curated-array mechanism should remain hand-maintained at all. Three checks now carry three independently drifting arrays, and this task exists because two of them drifted. Consider deriving the in-scope set from a frontmatter field or a declared capability, with the curated array reduced to an explicit exclusion list carrying per-file reasons. Weigh this against the established reason the arrays are curated: the three originally-covered implementation agents are legitimate differently-worded exclusions that a glob would false-fail. If curation must stay, add a check that FAILS when an agent file matching the shape is in none of in-scope, exclusions, or a recorded rationale -- so the next drift is caught rather than discovered.
- Whether Check C's and Check G's arrays have further absentees beyond the two books files. Both gaps here were found incidentally; neither array has been swept deliberately. Sweep both and report the full result, even if the answer is "no others".

=== NON-GOALS ===

- Do not edit general-implementation-agent.md (its text is the canonical source, reused verbatim, and other open tasks claim it).
- No new documents: extend the existing bounded-build-waiter.md fragment and the existing contract fragments.
- No consumer-repo work.

=== ACCEPTANCE ===

- lint-agent-contracts.sh exits 0 with the books files registered in Check C and Check G, their bullets normalized to text the lint actually matches.
- The line-wrap brittleness is ruled on explicitly, the ruling is recorded where a bullet author will see it, and a fixture pins it.
- The in-scope research-agent subset is determined by measurement, every exclusion carries a recorded reason, and the Lean sanctioned build-guard path is confirmed unbroken.
- A deliberate-removal demonstration on one real file of each newly covered class: lint FAILS by name, restoration returns it to exit 0.
- Both curated arrays swept for further absentees, with the full result reported.
- test-lint-agent-contracts.sh extended and green; shellcheck clean per context/standards/shell-strict-mode.md.
- check-task-references.sh clean on every changed agent-system/** path. Redeployed.

---

### 350. Offer owner review when approval needed
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 349, Task 393, Task 395

**Description**: Offer the owner the review path when a books task reaches a point that needs an approval, instead of requiring the owner to know to run /approve

--- WHY ---

Today nothing detects that an approval is required, and nothing surfaces the option. The owner has
to already know that an approval is outstanding and already know that /approve exists in order to
reach it.

On 2026-10-07 nineteen specifications needed re-approval after a namespace move. The agent prepared
the entire review --- it had everything needed --- but the owner had to DISCOVER the need
independently and then DRIVE the command by hand. The information was not missing; it was thrown
away. The approval need is visible to the dispatched agent at the exact moment it hits the component
gate's approvals stage, and at that moment it is discarded as a bare stage failure.

This task closes that gap: at the moment the need becomes visible, offer the owner the review path.

This task lives in the agent-system source store (agent-system/extensions/ in THIS repository),
never in a consumer repository's .claude/ tree, which is a regenerated deploy artifact.

--- THE DESIGN CONSTRAINT THAT BOUNDS THIS TASK (already measured --- do not redesign around it) ---

skill-orchestrate ALREADY HAS THE NEEDED PLUMBING. The full path exists and is exercised:

  - A dispatched agent returns `verdict: ask_user` carrying a `user_decision`.
  - skill-orchestrate's Move 3 accumulates that `user_decision` into the multi-state file's
    `pending_ask_user[]`.
  - Move 4 relays every pending entry as a BATCHED AskUserQuestion in the ROOT SESSION --- which is
    the only place AskUserQuestion is reachable --- and records the answer via
    `orchestrate-record-decision.sh`.

This path was exercised LIVE on 2026-10-07: a blocking `user_decision` about a foreign
`OOMPolicy=continue` edit was raised by a dispatched agent, relayed through Move 4, answered by the
owner, and discharged within a single orchestration run.

Therefore this task MUST REUSE that relay and MUST NOT build parallel interaction machinery. There
is no second prompting channel to invent, no new root-session escape hatch to design, no new state
file. This is a DETECTION-AND-OFFER SURFACE over existing plumbing --- nothing more.

--- SCOPE ---

(1) DETECTION. How a books agent recognises that an approval is required, and emits a `user_decision`
    rather than reporting a bare stage failure. The signal is the component gate's APPROVALS STAGE
    FAILING ON ABSENT-OR-STALE RECORDS --- that specific failure mode, distinguished from other ways
    the gate can go red, is what means "a person needs to approve something" rather than "something
    is broken".

    RULE on where this belongs: in the books AGENT DEFINITIONS (the agent recognises the condition
    at the point it runs the gate and shapes its own return), in the POSTFLIGHT CLASSIFICATION (the
    orchestrator recognises the condition from the returned stage results), or BOTH. Record the
    ruling WITH ITS REASON --- the reason is the durable part; a later reader must be able to see why
    the chosen seam was chosen and not merely which one it was.

(2) THE OFFERED OPTIONS AND THEIR SEMANTICS. Three options: ENTER REVIEW NOW, DEFER, DECLINE.

    DECLINING MUST NEVER silently self-approve and MUST NEVER downgrade the approval requirement.
    Declining leaves the records absent-or-stale and leaves the gate leg RED. That is the HONEST
    outcome and it is the required one: the owner chose not to approve right now, which is not the
    same as the approval not being needed. Any implementation in which declining turns the leg green,
    suppresses the requirement, weakens it to a warning, or marks it waived is wrong.

    Defer's semantics must be stated too: the need survives the deferral and is raised again on a
    later run rather than being consumed by the deferral.

(3) THE NO-HUMAN CASE. An autonomous dispatch with NO HUMAN ATTACHED must STOP AND REPORT rather
    than answer on the owner's behalf. It does not pick a default, does not auto-defer silently, and
    does not auto-decline as a convenience.

    This MIRRORS the refusal cases the /approve command task already owns (the no-human-attached
    refusal among them), and it MUST BE CONSISTENT WITH THEM --- the same condition must produce the
    same behaviour on both surfaces. Read that task's refusal cases and match them; do not write a
    second, divergent rule for the same situation.

(4) HAND-OFF TO /approve. What the ACCEPTED option actually does: it must REACH the /approve command
    defined by the companion in-repository task `add_approve_command_owner_labeled_approvals`,
    passing the COMPONENT and the SCOPE, and must NOT REIMPLEMENT ANY PART OF THE REVIEW. No diff
    classification, no summary contract, no artifact writing, no recording --- all of that is
    /approve's, reached by invocation and not by duplication.

--- OUT OF SCOPE ---

- The /approve command ITSELF, and its artifact path, summary contract and step-through approval
  UX. The companion task `add_approve_command_owner_labeled_approvals` owns ALL of it. This task
  calls that command; it does not shape it.
- `approve.sh` and `check-approvals.sh`. The Logos/Verification task
  `owner_labeled_agent_assisted_approvals` owns those (cited by slug, because task numbers do not
  carry across repositories).
- Any approval POLICY question about which specifications deserve scrutiny. This task decides when
  to OFFER, never what is worth approving.

--- KEEP IT MODEST ---

This is DETECTION and an OFFER over existing plumbing. If the work appears to require new
interaction machinery --- a new prompting channel, a new state file, a new root-session relay, a
second AskUserQuestion path --- that is a SIGNAL THE DESIGN DRIFTED from the measured constraint
above, not a signal that more machinery is needed. Stop and re-read the constraint section.

--- ACCEPTANCE ---

- A books dispatch that hits an absent-or-stale approvals leg emits a `user_decision` that reaches
  Move 4's batched relay (demonstrated, not asserted).
- The three options --- enter review now, defer, decline --- exist with the stated semantics, and
  DECLINING IS SHOWN BY TEST to leave the approval requirement intact: records still absent-or-stale,
  gate leg still red, nothing waived or downgraded.
- The no-human path STOPS AND REPORTS, with a test, and never self-answers.
- The accepted path INVOKES /approve with the component and the scope rather than duplicating any
  review logic.
- The ruling in (1) --- agent definitions, postflight classification, or both --- is recorded
  together with its reason.

---

### 342. Refactor the books extension's context corpus against the settled convention: role-scoped loading, agent-set review, version-pinned files
- **Effort**: 2-3 days
- **Status**: [HOLD]
- **Held**: 2026-10-05
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 340, Task 341, Task 346
- **Research**: [342_refactor_books_context_corpus_role_scoped/reports/01_seed-books-context-engineering.md]

**Description**: SOURCE STORE IS THE EDIT TARGET (agent-system/extensions/books/..., never .claude/**). `.claude/` is a
gitignored, disposable deploy artifact regenerated from the source store; a file hand-authored there
is silently wiped by the next deploy. See rules/source-store-deploy-boundary.md.

No task-number references in any file written into the source store
(rules/no-task-references-in-deliverables.md). Cite durable anchors -- filenames, section headings,
decision numbers -- instead. Task numbers are permitted in this description and in specs/**.

== PROSE PRECONDITION (not a dependency edge) ==

This task refactors against the SETTLED record, not the one in flight. Before it runs, the consuming
repository ~/Projects/Logos/Verification must have landed its alpha review of the book convention WITH
THE VERSION STAMPED. If the review has not landed, this task waits -- refactoring the corpus against a
record still being revised buys a second refactor.

== GOAL ==

The books context corpus is 21 files, about 4,450 lines, WRITTEN BEFORE THE SPLIT AND BEFORE THE ALPHA
REVIEW. Review it against the settled record and refactor it so each books agent loads EXACTLY THE CONTEXT
ITS JOB NEEDS, with the AGENT SET ITSELF reviewed and EVERY FILE PINNED to the convention version.

== THE MEASURED STARTING POINT ==

  - `index-entries.json` (538 lines, 21 entries): only `project/books/README.md` and
    `patterns/signal-tagging.md` carry `load_when.task_types: ["books"]` -- AND NO REAL CONSUMING-REPO TASK
    CARRIES TYPE `books` (measured: fourteen books-topic tasks are `lean4`, two `general`, one `typst`).
    The other 19 entries are on-demand with empty `task_types`. NOTHING IS KEYED BY ROLE.
  - Corpus line counts: `README.md` 88; `domain/` known-gap-register 275, layer-vocabulary-and-matrix 230,
    book-toml-v2 187, certificate-ledger-and-records 275, identity-and-versioning 237,
    status-and-trust-vocabularies 163, gate-tiers 194; `patterns/` authoring-workflow 213,
    warning-driven-convergence 174, gate-collision-ledger 198, signal-tagging 204, books-review-submode 219,
    books-revise-submode 288; `standards/` metadata-split 180, forgery-probe-discipline 171,
    reconciliation-contract 231, observation-record 249; `tools/` tooling-inventory 213,
    typst-template-contract 244, certify-guide 214.
  - FIVE domain files restate Decisions 2, 3, 7, 8, 9, 11 and 12, which after the split are SINGLE FILES OF
    70 TO 330 LINES WITH STABLE ANCHORS. Before the split, restating Decision 7 saved an agent from
    ingesting a 359 KB file; after it, that decision is a short file at a stable path, so the
    restatement's REMAINING value is only whatever it ADDS.
  - FOUR agents split by LIFECYCLE PHASE (research 188, research-hard 295, implementation 294,
    implementation-hard 285 lines), NOT BY JOB.

== THE FIVE JOBS, MEASURED ==

| Job | Files needed today | Lines |
|---|---|---|
| Author a book | layer-vocabulary-and-matrix, metadata-split, book-toml-v2, authoring-workflow, warning-driven-convergence, rules/books.md | ~1,050 |
| Certify / diagnose | gate-tiers, gate-collision-ledger, certify-guide, tooling-inventory, forgery-probe-discipline | ~990 |
| Document a book | typst-template-contract, reconciliation-contract, status-and-trust-vocabularies | ~640 |
| Maintain the record | the record-editing guardrail rule and maintenance pointer, identity-and-versioning, known-gap-register | ~580 |
| Review / revise the convention | observation-record, signal-tagging, books-review-submode, books-revise-submode | ~960 |

Nothing in the extension selects by job. A research dispatch that reads the corpus README is pointed at all
of it.

== FIVE DELIVERABLES ==

(1) A PER-FILE REVIEW TABLE, all 21 files: what it RESTATES, what it ADDS BEYOND THE DECISION FILE MEASURED
IN LINES, which job needs it, and a disposition -- KEEP / TRIM TO THE DELTA / MERGE / RETIRE INTO THE RECORD
/ SPLIT BY ROLE. "Lines that are not in the decision file" is a measurement, not a judgement; make it.

(2) A LOADING MATRIX for the five jobs, giving each agent and skill an EAGER SET and an ON-DEMAND SET,
expressed in `index-entries.json` `load_when` keys and in each agent's context references, with a
PER-DISPATCH EAGER BUDGET MEASURED BEFORE AND AFTER.

(3) THE AGENT-SET RULING: which jobs need their own agent and which are served by EXISTING agents given a
role-specific context slice -- including whether the existing typst and planner agents already cover
documenting and planning -- with the frontmatter and routing-table changes that implement it.

(4) A `- **Reviewed against convention version**:` HEADER ON EVERY CORPUS FILE, matching the extension pin,
plus THE RULE THAT A BUMP OBLIGES RE-REVIEW of every file whose header is BELOW the pin. This turns "update
all the parts" from a search into a list.

(5) Registration (`README.md`, `EXTENSION.md`, `index-entries.json`, `manifest.json`), the gate suite green,
and A STATED MEASUREMENT THAT NO DISPATCH KIND'S EAGER CONTEXT GREW.

== BINDING PREFERENCES AND PROTECTED FILES ==

PREFER TRIMMING TO THE DELTA over retiring a file, unless the delta is empty. PREFER A ROLE-SPECIFIC
CONTEXT SLICE over a new agent, unless the slice would exceed the budget for an existing agent's other jobs.

These carry MEASURED FAILURE MODES THE RECORD DOES NOT HAVE and MUST SURVIVE: `gate-collision-ledger`
(the six gate collisions), `forgery-probe-discipline`, `warning-driven-convergence` (the `book_requires`
loop), and `certify-guide` (the certifier's economical operation) -- along with the `Books.+` glob failure
and the `certificate/` directory discovery corruption these files record.

Deleting the corpus and pointing agents at the record directly was considered; it is REJECTED AS AN
ASSUMPTION and must instead be MEASURED per file, precisely because of those failure modes.

== OWNER GATE ==

The owner looks at THE LOADING MATRIX DURING PLANNING, BEFORE the rewrite. Role separation is a design
choice, not a mechanical consequence of the measurements.

== SCOPE BOUNDARY ==

NO change to the record. NO change to `/books` sub-mode SEMANTICS beyond their context references. NO
repo-side files. Applying the same loading-matrix method to the lean4 and typst corpora is a possible later
task, NOT this one.

== ACCEPTANCE ==

The review table covers all 21 files with measured deltas and a disposition each; the loading matrix names
an eager and on-demand set per job with before/after budgets; the agent-set ruling is recorded with reasons;
every corpus file carries the version header and the bump rule is stated; the four protected files survive;
no dispatch kind's eager context grew, stated as a measurement. Gate: `verify-deploy.sh`,
`check-extension-docs.sh`, `check-task-references.sh`, and the books test suites.

== DEPENDENCIES ==

Depends on the books-extension split-retarget task (the retargeted anchors and the version pin every corpus
header must match) and on the record-editing guardrails task (the rule and maintenance pointer that the
"maintain the record" job's eager set loads).

Seed report: specs/342_refactor_books_context_corpus_role_scoped/reports/01_seed-books-context-engineering.md

---

### 338. Sweep task support file tracked or ignored
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 275

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per rules/source-store-deploy-boundary.md.

Sweep every task-support file a producer writes under specs/ and classify each as tracked or ignored, so support artifacts stop dirtying the git tree for no reason

--- WHY ---

context/standards/orchestrator-runtime-files.md defines a two-class split (Ephemeral/gitignored vs. Durable provenance/tracked) and scripts/lib/runtime-file-patterns.sh renders the ephemeral half into each repo's specs/.gitignore. The split is sound. The ENUMERATION is not: it was grown file-by-file as each defect surfaced, never swept, so whole artifact families a producer writes today appear in neither class. The consequence is support files showing permanently in `git status` for no reason, which trains a reader to ignore the residue channel entirely.

MEASURED 2026-10-04 across the two consumer repos (~/.config/nvim and ~/Projects/Logos/Verification):

1. `progress/phase-N-progress.json` -- ZERO mentions in the standard, ZERO in runtime-file-patterns.sh, yet roughly 2,000 such files are TRACKED in nvim's history (391 `phase-1-progress.json`, 382 `phase-2`, 367 `phase-3`, 339 `phase-4`, 276 `phase-5`, 196 `phase-6`, 121 `phase-7`, 60 `phase-8`, and more), plus ~580 in Verification. This is the dominant volume in the whole question and is entirely unpoliced. By its own description it is crash-recovery scratch, which would put it in the ephemeral class -- but it is committed thousands of times over. Settle it.
2. `.blocker-research.json` -- ZERO mentions in the standard, ZERO in the lib, yet FOUR live scripts write or read it (orchestrate-build-aux-dispatch.sh, orchestrate-cycle-plan.sh, orchestrate-cycle-postflight.sh, lib/territory-contention-lib.sh) and three docs describe it. One instance (specs/187_prove_crc8_detection_and_record_limit/) has sat untracked and unignored in Verification across multiple sessions, reported as residue by every run's own end-of-batch check.
3. `tools/` under a task directory -- ZERO mentions in either. A task wrote specs/193_improve_docs_presentation/tools/{reflow.py,before-after.md,gates-after.txt} and the postflight's own excursion advisory listed them as out-of-scope writes.
4. Whole UNTRACKED TASK DIRECTORIES: `specs/335_gate_modified_files_excursion_at_staging/` is untracked in nvim right now because its producer never staged it. Adjacent to the existing vacated-source-never-staged task; coordinate rather than duplicate.

Already correctly covered, as evidence the mechanism works when a name is in it: metrics.jsonl, issues.jsonl, and the 42-pattern enumeration the lib already renders.

--- SCOPE ---

1. ENUMERATE, by grep over the source store rather than from this list, every file and directory any producer writes under `specs/` -- dot-prefixed and plain alike, per-task and specs/-root alike. The deliverable is the inventory itself: producer, reader, lifetime, current git disposition (tracked / ignored / neither).
2. CLASSIFY each against the two-class split, applying the standard's own freshness-gate test: a file a resume/read site trusts with NO freshness check is ephemeral, because a stale git-restored copy would silently corrupt live state. A per-dispatch audit trail a later reader needs is durable provenance.
3. RULE EXPLICITLY on the `progress/` family. It is the one case where the current behaviour (thousands of tracked files) and the likely correct class (scratch) disagree at scale, so it needs a stated decision with its reason, not a quiet pattern addition. If it becomes ignored, say what happens to the thousands already in history -- leaving them tracked while ignoring new ones is a legitimate answer, but it must be the recorded answer rather than an accident.
4. APPLY: add every ephemeral name to runtime-file-patterns.sh's enumeration (the canonical generator; specs/.gitignore is rendered from it by init-specs.sh and must never be hand-edited), and for every durable name confirm its producer actually stages and commits it rather than leaving it untracked.
5. RECORD the result in context/standards/orchestrator-runtime-files.md's per-file table, including any artifact deliberately left in neither class -- that document already carries two such carve-outs (the deploy ledger, and the stray-handoff/stale-guard trio), so a third is permitted but must be argued, not implied by omission.
6. Leave a CHECK so the enumeration cannot silently fall behind again: the recurring failure mode is a new producer writing a new artifact name with nothing noticing it belongs in neither class.

--- CONSTRAINTS ---

- Do not collapse the bare-vs-suffixed `.return-meta.json` distinction. The standard states explicitly that it must never be collapsed: bare `.return-meta.json` is tracked durable provenance, `.return-meta-*.json` is ignored.
- `.orchestrator-handoff.json` and `.return-meta.json` stay tracked. The managed block's own comment names them as deliberate exclusions from the ephemeral class.
- Verify every claim in the WHY section by grep before acting on it; the counts above were measured on one day in two repos and are a starting point, not the inventory.

---

### 328. Systematic script and test corpus efficiency
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 170, Task 303, Task 304, Task 318, Task 322, Task 366

**Description**: Systematic top-to-bottom efficiency refactor of the shell script AND test corpus under agent-system/extensions/**, driven by script-inventory.sh's ranked output rather than by hand-filed point defects. Supersedes and folds in tasks 307, 308 and 270. Depends on 170, 318, 322, 304, 303.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/** (never .claude/**, a disposable deploy artifact).

== MOTIVATION: A GAP IN THE INTAKE MECHANISM ==

Tasks touching this corpus are filed by hand from defects hit live during /orchestrate runs. That intake only ever surfaces what BROKE. Needless complexity, duplicated logic, poor division of labor and slow tests never break anything -- they only cost -- so they are invisible to the filing process by construction and will not self-correct. Task 250 closed half this gap by BUILDING the standing probe (scripts/script-inventory.sh) but spent its decomposition budget on a single file (orchestrate-cycle-plan.sh, 3026->2597 lines, 14.2%). This task is the standing consumer of that probe's output, across the whole corpus, including the test corpus.

== MEASURED 2026-10-03 via scripts/script-inventory.sh (RE-MEASURE BEFORE ACTING) ==

Corpus: 197 non-test *.sh files, 72,761 lines, 3,472,506 bytes. Separately: 85 test suites under core/scripts/tests/.

Duplication: 52 of 197 scripts carry duplicate blocks. Verified clusters:

  (1) THE FIVE-LINT CLUSTER -- the clearest extract-a-lib target in the corpus. All five report peers=4, i.e. all are mutual near-copies:
      - lint/lint-task-lookup-adoption.sh        551L, 107 dup blocks
      - lint/lint-branch-gated-sections.sh       398L,  78 dup blocks
      - lint/lint-directory-pathspec-boundary.sh 369L,  67 dup blocks
      - lint/lint-state-writer-boundary.sh       348L,  97 dup blocks
      - lint/lint-scoped-commit-boundary.sh      346L,  92 dup blocks
      Hand-verified independently of the metric: 115-132 shared non-blank, non-comment lines per pair (comm -12 on sorted unique lines, comments and blanks stripped) -- roughly a third of each file is a shared skeleton, DESPITE each already sourcing two libs. ~2,012 lines total.

  (2) install-extension.sh (299L) / uninstall-extension.sh (237L): mutual pair, 33 dup blocks each.
  (3) typst/scripts/chapter-quality-check.sh (754L) / typst-element-lint.sh (372L): mutual pair, 44 dup blocks each.
  (4) literature/scripts/literature-search.sh: 1,635L with 172 dup blocks and peers=0 -- i.e. SELF-internal repetition inside one file, a different defect class from the cross-file clusters above.

Test-coverage constraint (binds the whole task): 157 of 197 scripts have no paired test, and 50 of those exceed 300 lines. A large untested script cannot be safely refactored, so characterization tests must precede any edit to one. This is why 170 is a dependency rather than a sibling.

Test-corpus runtime: verify-deploy.sh Gate 8 measured at 117.9s of a ~2.8min total run -- the dominant gate. Cause is volume and process-spawn/IO, not compute: 85 suites, each a separate bash process, many shelling out further. Task 265 already added run-all.sh --jobs (capped at JOBS_CAP=4, deliberately below nproc because pooled suites contend) and --skip-slow. Remaining headroom is the 4x cap and per-suite startup cost, NOT more parallelism.

== TWO PROBE METRICS THAT MUST NOT BE TRUSTED AT FACE VALUE ==

  - zero_caller_count = 0 does NOT mean there is no dead code. Task 250's own summary records that a script's own manifest.json entry counts as an inbound caller, so inbound_callers over-counts by design and the field found nothing. Dead-code detection is UNSOLVED and this task must not treat 0 as an answer; devise a real reachability test (note task 251 is solving the analogous problem for the CONTEXT corpus -- borrow its method, do not duplicate it; file_scopes are disjoint so the two run in parallel).
  - has_test is a filename-convention check only. claude-refresh.sh reports has_test=false although task 217 just grew its matcher suite to 163 assertions, because the file is named test-claude-refresh-matcher.sh. So 157 overstates the true coverage gap. Re-derive real coverage before using it to gate anything.

== FOLDED-IN TASKS (supersede and close these three; their file_scopes merge into this task) ==

  - 307 (/todo: consolidate the duplicated skill-todo implementation, wire roadmap pruning, cut the per-task jq and subprocess fan-out). Files: commands/todo.md, skills/skill-todo/SKILL.md, manifest.json, context/architecture/system-overview.md, context/patterns/context-protective-lead.md, scripts/memory-harvest.sh. NOTE: task 322 is a verified REGRESSION fix on todo.md and skill-todo/SKILL.md and MUST land first -- do not refactor those two files before 322 closes.
  - 308 (/review: wire roadmap regeneration, collapse the redundant jq and generate-todo passes). Files: commands/review.md.
  - 270 (re-runnable null-safety audit of jq mutation sites across core scripts, then decide whether a shared guard idiom belongs in scripts/lib/). Files: scripts/check-jq-null-safety.sh, scripts/tests/test-check-jq-null-safety.sh, scripts/orchestrate-build-dispatch.sh, scripts/lib/, docs/reference/utility-scripts-inventory.md. This is the same shape as the rest of the task -- a shared idiom extracted into lib/ -- so it belongs here rather than standing alone.

Each folded task's own substance is to be delivered, not dropped: closing them is a consolidation, not a descope.

== DEPENDENCIES AND WHY EACH GENUINELY BLOCKS ==

  - 170 (audit and isolate shell test suites from ambient host state, record the convention): owns context/standards/shell-script-testing.md, the convention this task must refactor the test corpus AGAINST, plus eight state/timing-sensitive suites and task-lock.sh. Refactoring tests before the convention exists would be rework.
  - 318 (wire lint-directory-pathspec-boundary.sh into verify-deploy.sh as a numbered gate): that script is one of the five IN the duplication cluster above. Extracting its skeleton while it is still unwired churns verify-deploy gate numbering twice.
  - 322 (/todo directory-move staging gap, a verified regression): owns commands/todo.md and skill-todo/SKILL.md -- the exact two files folded-in task 307 owns. Direct file collision; the defect fix lands before the refactor of the same files.
  - 304 (one out-of-repository pathspec entry aborts staging for every valid path; callers sink nonzero exits while the task reports success): owns git-commit-scoped.sh, orchestrate-cycle-postflight.sh, orchestrate-unwind-dispatch.sh and both test-git-commit-scoped.sh / test-orchestrate-cycle-postflight.sh. Every incremental refactor commit in this task rides on that staging and exit-code contract; refactoring on top of a known-broken one would mask failures.
  - 303 (validate-state.sh resolves its omitted-argument default against CWD instead of the repo being validated): small, and a defect fix on a script+test pair this task's test work would otherwise touch mid-flight.

== SCOPE: TOP TO BOTTOM, BOTH CORPORA ==

Both halves are in scope, and the test corpus is a first-class target rather than only a safety net:
  (a) The 197 non-test scripts: de-duplicate the verified clusters into scripts/lib/, remove what is genuinely unneeded (after solving reachability honestly), and improve division of labor on the probe's top-ranked files.
  (b) The 85 test suites: cut per-suite startup cost and the Gate 8 117.9s figure, consolidate the duplicated test scaffolding, and close real coverage gaps on the 50 large untested scripts -- all WITHOUT reducing assertion coverage or functionality.

== HARD CONSTRAINTS ==

  - NO reduction in coverage or functionality. Behaviour preservation must be demonstrated per change, not asserted: prefer byte-identical output diffs against a pre-captured baseline (the technique task 250 used successfully on orchestrate-cycle-plan.sh --dry-run), and never weaken or delete a test to make a refactor pass. Task 250 hit exactly this and correctly REVERTED rather than weaken test-lint-deploy-caller-wrap.sh's two-genuine-caller invariant; it then took its own declared fallback and reported 14.2% against a ~29% target honestly. Do the same.
  - Characterization tests FIRST for any script that is large and genuinely untested.
  - Incremental: one cluster or one file per phase, full suite green and committed before the next starts.
  - Re-measure with script-inventory.sh at the start; the 2026-10-03 figures above are a snapshot, and the probe's own output is the authoritative input.
  - Note task 250's deferred follow-up: it left roughly half the redeploy-checkpoint region inline in orchestrate-cycle-plan.sh (the 479-line move broke test-lint-deploy-caller-wrap.sh's invariant), and separately flagged that deploy-headless.sh's --skip-verify defers run-all.sh so ~40 deploy-tree-first suites are not exercised against a freshly-redeployed tree. Both are in scope here.
RE-MEASURED 2026-10-05 (nvim/, batch session sess_1791222088_1f4b0c) -- two corrections to the
test-corpus runtime figures above, both of which strengthen the case:

  - The corpus is larger than the 85 recorded above, in two ways the phrase "85 suites under
    core/scripts/tests/" conflates. That directory itself now holds 89 `test-*.sh` files. But
    run-all.sh does not run only that directory: one invocation was observed starting 111+ suites
    spanning core, typst, literature and other extensions before it was stopped. Establish the
    true count from run-all.sh's own discovery pass, not from `ls` of one directory -- the
    efficiency target is whatever that pass actually runs.
  - The 117.9s Gate 8 figure is a PARALLEL measurement and must not be read as the corpus's
    runtime. verify-deploy.sh requests run-all.sh's opt-in `--jobs` (capped at JOBS_CAP=4);
    run-all.sh's own default is `--jobs 1`. A bare sequential run reached only ~53 of 111+ suites
    after ~330s without concluding -- roughly 4-5x the recorded figure. run-all.sh additionally
    forces `--jobs` to 1 whenever it is reached from inside another run-all.sh suite, so the
    sequential path is reachable even when a caller asked for parallelism.

WHY THAT ASYMMETRY IS ITSELF IN SCOPE HERE: the fast path is opt-in and the slow path is the
default, so every caller who does not know to pass `--jobs` -- including an agent that types the
obvious command during a dispatch -- pays the 4-5x. Consider whether the default should invert
(parallel by default, `--jobs 1` to opt out), a division-of-labor question of exactly the kind this
task owns. The nesting rule above is the one real constraint on inverting it.

OBSERVED CONSEQUENCE: in that batch Gate 8 could not conclude within a dispatch's practical budget
and was closed as a documented Reasoned Exclusion rather than enforced. Task 170 carries the full
write-up of that failure mode; it is recorded here because the runtime half of the cause is this
task's to fix.

---

### 313. Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md phase blocks
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 306, Task 328, Task 344, Task 387

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). No task numbers in deliverable files outside specs/**.

GOAL. Add an ADVISORY lint that validates hand-authored /orchestrate batch proposals written into specs/ROADMAP.md phase blocks, so an under-inclusive batch is caught at authoring time instead of only at dispatch -- or never.

=== THE OBSERVED FAILURE (real, not hypothetical) ===
An agent hand-edited a ROADMAP.md phase batch and REMOVED a task from it because that task depended on another task already in the batch. That reasoning is wrong: /orchestrate performs dependency-aware wave dispatch, so an intra-batch dependency edge merely sequences the two tasks into successive waves. The two tasks also declared overlapping file_scope (three files under one component's certificate/ directory), which under the dominance rule makes batching them MANDATORY rather than optional. Nothing caught either error, because the proposed batch existed only as prose in a markdown file. The user corrected it by hand.

=== RULING ON THE SCOPE-NOTE OBJECTION (settled; do not re-litigate) ===
context/patterns/batch-orchestration-guardrails.md's scope note "Territory is a human judgment, not a machine derivation" does NOT forbid this lint. Its own first sentence draws the line: "This document's admission layers (below) derive collisions mechanically from `file_scope`; the selection criterion here is different". The note excludes machine derivation as a SELECTION input. A lint that reads a batch a human already typed and mechanically compares declared file_scope is an admission-layer act, which that same sentence sanctions.

Corroboration: docs/architecture/batch-admit-schema.md's `idle_overlap_advisory` (v5) ALREADY emits finding (a)'s fact at dispatch time -- it names a cross_batch overlapping task that is not in the batch, with `overlapping_path` and a remedy string. This lint is therefore the AUTHORING-TIME ANALOGUE of a mechanism that already ships. The gap it closes is WHEN the signal arrives, not whether the fact is derivable. Scope the novelty claim accordingly.

=== FINDINGS TO IMPLEMENT (all ADVISORY, never blocking) ===
(a) TERRITORY UNDER-INCLUSION -- the primary and only mandatory-defect finding. A non-terminal task whose declared file_scope overlaps an in-batch task but which is ABSENT from the batch. Rule 1 (shared file territory) is unconditional and does not depend on topic cohesion; this is the one case where an omitted task is a real defect.
(c) The batch exceeds MAX_TASKS=8 (commands/orchestrate.md:232; contract at docs/architecture/orchestrate-state-machine.md's "Batch Size Cap").
(d) The batch cites a task number that is terminal or does not exist in state.json.
(e) DECLARATIVE, and arguably the actual fix: when the batch block is specified in the format contract, state plainly that a batch MAY contain intra-batch dependency edges, that such edges sequence tasks into successive waves rather than disqualifying them, and that a dependent's presence or absence is the author's judgment. The failure above was an author's false BELIEF; a lint can only catch its symptom, so the declarative sentence carries real weight. This is a pointer plus one sentence -- NOT new doctrine. The guardrails document already classifies an unmet predecessor as an ORDERING CONSTRAINT in its Gate Catalogue; cite that rather than re-explaining it.

ALL findings are ADVISORY. They fail the Blocking-vs-Advisory criterion's condition 2: a prose markdown file is never dispatched, so an under-inclusive batch causes no silent concurrent write -- the real admission gate still fires at dispatch time regardless.

=== FINDING (b) WAS CONSIDERED AND DELIBERATELY REJECTED -- DO NOT RE-PROPOSE ===
A proposed finding (b) would have reported "a non-terminal dependent of an in-batch prerequisite that is absent from the batch" as rule-3 under-inclusion. It is dropped ENTIRELY, including its weaker informational variant, for two reasons:
1. It overstates the guardrails document on that document's own terms. In its worked example the dependent C joins as a topic-cohesive OPTIONAL add whose edge means it "cannot dispatch usefully apart from the same invocation" -- a width/fill preference under rule 3, not an unconditional mandate like rule 1's territory requirement. As a defect finding it would assert a rule that does not exist.
2. Even as information it would fire on nearly every batch, given a dense dependency graph and a cap of 8, and it would push batches to grow transitively against that cap. Noise on a never-actionable signal is precisely what trains operators to ignore advisories, degrading finding (a), which IS actionable.
The aim is to ALLOW intra-batch dependency edges where they make sense -- never to mandate pulling dependents in. A dependency edge must simply never be grounds for EXCLUDING a task from a batch. Finding (e) carries that positive half declaratively.

=== HARD CONSTRAINT: THIS IS A VALIDATOR, NEVER A PROPOSER ===
The lint validates a batch a human already wrote. It must NEVER author, suggest, or rank a batch. Machine-derived batch SELECTION is the territory of the next-admissible-batch suggestion task (topic orchestrator), which is gated behind several prerequisites precisely because it is the harder, riskier mechanism. Copy that task's binding constraint as precedent: a second copy of an admission predicate drifts from the real one, and a suggestion the real script then refuses is worse than no suggestion at all.

=== REUSE, DO NOT REBUILD ===
- SPLICE $FILE_SCOPE_OVERLAP_JQ_DEFS from scripts/lib/file-scope-overlap.sh (the `norm` / `scopes_overlap_first` / `edge_connected_nums` defs). NEVER fork, restate, or re-derive the overlap algorithm. Note that scopes_overlap_first is deliberately glob-free and symmetric; do not "improve" it locally.
- ADD this lint to the Consumers list in context/patterns/file-footprint-overlap.md, which names that algorithm's callers. That list currently says three active callers; this becomes a new one.
- REUSE generate-task-order.sh's compute_waves (Kahn's algorithm) for any wave reasoning. Do NOT modify generate-task-order.sh -- it is in another task's file_scope, and consuming rather than modifying is what keeps this task free of a dependency on it.
- RESPECT the truncation precedence rule in the guardrails document: a cap-driven trim to 8 can never split a territory-mandatory group off the end. Finding (c) must not recommend a trim that violates this.

=== OPEN RESEARCH QUESTION: WHICH SEAM ===
Research must settle the call site. Note first that verify-deploy.sh, through which all ten existing scripts/lint/*.sh are wired, is the WRONG seam here: it validates the source store and deploy, whereas this lint reads a CONSUMER repo's specs/ROADMAP.md against that repo's specs/state.json. The precedent does not transfer, which is why a roadmap-touching command is the only seam.
  SEAM A: a new mode on scripts/roadmap-integration.sh, which the /review rewiring already invokes. This may need no commands/review.md edit at all, dissolving the territory overlap noted below -- but it enters the roadmap-generation task's territory.
  SEAM B: a standalone scripts/lint/lint-roadmap-batch-proposals.sh called explicitly from commands/review.md, following the naming and test/manifest-registration precedent of the ten existing lint scripts.
LEAN: seam B for the script itself, with the call site decided in research. If seam A wins, narrow file_scope accordingly and say so.

=== EMPIRICAL FINDING THE ROADMAP-GENERATION TASK NEEDS ===
The batch-block convention is DIVERGENT ACROSS REPOSITORIES, so a lint written to one shape silently no-ops on the other:
  - The consumer repo uses a literal `**Run**:` marker followed by a fenced block containing `/orchestrate 120,121,...`.
  - The global agent-system repo uses NO such marker: it uses a `## Call N -- <description>` header followed by a bare fenced block that may contain SEVERAL `/orchestrate ...` lines, i.e. several distinct batches under one header.
This matters beyond this task: the roadmap-generation task's own description asserts that the live file uses a `**Run**` line, which is true only in the consumer repo. That task should reconcile the two shapes into one specified grammar before this lint can parse anything. This is FLAGGED HERE DELIBERATELY rather than by silently editing that task's description. Confirm the divergence still holds at research time; the two files drift.

=== DEPENDENCIES ===
- On the roadmap-generation task (hard, substantive): there is no parseable grammar to lint until the batch block is specified as a structure element in context/formats/roadmap-format.md, which today specifies only phase headers, checkboxes, status tables, priority markers and completion annotations -- it is 65 lines with zero occurrences of "Run". That task already owns both roadmap-format.md and roadmap-integration.sh and already has the batch-block spec in its scope, so DO NOT duplicate that work here; consume it.
- On the /review rewiring task (hard, footprint-corroborated): it rewrites the /review Step 2.5 call site this lint would hook. Landing this first would simply be overwritten. The edge is deliberately kept EXPLICIT alongside the roadmap-generation edge even though the latter is transitively implied through it, per the standing documented-redundant-edge convention: the two edges record different facts (grammar availability vs. call-site ordering) and a redundant edge costs only a wave.
- NOT a dependency, but note the absent-file_scope admission-posture task: it rules whether an absent file_scope is admission-relevant. For this lint an absent file_scope simply means "no evidence of overlap", so finding (a) cannot fire on it. Adopt the softer posture and RECORD in the script header which absent-scope posture was assumed, so the ruling can be reconciled later. Do not hold this task on it.

=== CROSS-REPO TERRITORY CONSTRAINT (not expressible as an edge) ===
A consumer repository has its own in-flight task that ALSO edits the /review command, to add a Book health section. That is a different repository's task number, so it CANNOT be expressed as a dependencies[] edge on this task. Whoever implements this MUST check for concurrent /review-command work in consumer repos before editing commands/review.md. Choosing seam A would avoid this hazard entirely.

=== ACCEPTANCE ===
- A fixture ROADMAP batch that omits a task whose file_scope overlaps an in-batch task produces finding (a); the real failure case above is reproduced as that fixture and the lint flags it.
- A fixture in which the only omitted task is a DEPENDENT with no territory overlap produces NO finding, demonstrating (b) is genuinely absent.
- Findings (c) and (d) each have a fixture.
- No copy of the overlap predicate exists anywhere in the new code: the lint splices scripts/lib/file-scope-overlap.sh.
- context/patterns/file-footprint-overlap.md's Consumers list names this lint.
- Every finding is advisory: the lint's exit code is unaffected by findings, and this is stated in its header.
- Registered in manifest.json with a scripts/tests/test-*.sh companion, matching the existing lint-script convention.
- shellcheck clean per context/standards/shell-strict-mode.md.

---

### 312. Backlog reconciliation as a required task-creation component: compare every proposed task against the open backlog before it is written
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 165, Task 282, Task 300, Task 344

**Description**: SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/` (never `.claude/**`, a disposable deploy artifact -- see `rules/source-store-deploy-boundary.md`).

## Goal

No task may be created without first being compared against the open backlog, so that a genuinely new task is created, an existing task is revised or widened, a dependency edge is added, or a `file_scope` is narrowed -- whichever the comparison warrants. Today no creation surface does this, and the standard does not require it.

## The motivating incident (live, this session, not hypothetical)

Three tasks (309, 310, 311) were created from a research report without any comparison against the open backlog. Outcome on inspection:
- Task 310 was a near-total duplicate of open task 272, whose goal statement is almost verbatim identical and which is better scoped (it additionally carries `task-lock.md`, `orchestrator-runtime-files.md`, `test-session-registry.sh`, `test-conflict-predicate.sh` and a heartbeat-never-fires diagnosis). 310 was abandoned and its two unique items folded into 272.
- Task 309 was a strict subset of open task 302's `file_scope` and named the same three line numbers. Resolved by narrowing 302 to drop those three paths and ordering 302 behind 309.
- Task 311 was genuinely new (no open task mentions `BUILD_HEAVY` or build weight) -- so the mechanism must be able to return "genuinely new", not merely flag suspicion.

Only 311 of the three survived creation unchanged. That is the failure rate this task exists to eliminate.

## The precise gap

`docs/reference/standards/multi-task-creation-standard.md` already has Component 4a, "File Footprint Capture and Overlap Detection (Automatic)". Its step 2 reads: apply the overlap check "to every unordered pair of proposed tasks **in the current batch**". The scan scope is the creation batch only. Nothing compares a proposed task against the non-terminal tasks already in `specs/state.json`.

This is corroborated by the predicate's own doc: `context/patterns/file-footprint-overlap.md` describes an "O(n^2) pairwise scan over the items in a single batch (task-creation batch...)" and its Non-Goals section states it holds "No opinion on scan scope... each caller chooses its own scan scope, and this document is not extended" for it. So the PREDICATE is sound and reusable; the missing thing is a caller that applies it against the backlog. Do not rework the predicate.

A second, independent gap: **file overlap alone is insufficient.** Tasks 310 and 272 shared exactly ONE path (`scripts/task-lock.sh`) yet were near-total duplicates in intent. A purely mechanical footprint pass would have added a serializing dependency edge and declared success, never surfacing the duplication. So the mechanism needs two passes, and the second cannot be a footprint comparison.

A third gap, from the standard's own Current Compliance Status table: `/review` and `/errors` do not perform even the existing in-batch Component 4a check ("No" in the Footprint Overlap column). Any new requirement must account for surfaces that do not yet satisfy the old one.

## Required outcomes

1. A new REQUIRED component in `multi-task-creation-standard.md` (sequenced after the existing 4a, before Component 7's user confirmation) specifying backlog reconciliation: its inputs, its two passes, its verdict vocabulary, and its non-silence obligation. Update the Current Compliance Status table to carry the new component as a column, honestly marking each surface's state.
2. A single shared implementation, `scripts/audit-open-tasks.sh`, that every creation surface calls rather than each re-implementing. It must take proposed task(s) and return, per proposal, a structured verdict drawn from a fixed vocabulary -- at minimum: genuinely new; duplicate-of-N; subset-of-N; superset-of-N; overlaps-N-add-edge; narrow-N. It must reuse the existing overlap predicate for the mechanical pass rather than forking it.
3. The semantic/intent pass, which must catch the 310-vs-272 class (near-identical goal, almost no shared paths). Title/description/topic similarity is the obvious approach; the task must rule on the method and state its false-negative posture explicitly.
4. Enforcement, so this cannot be skipped by a surface that forgets to call it. `hooks/validate-task-creation-audit.sh` is declared in `file_scope` as the candidate site.

## The central design question -- research must RULE on this, not assume it

Two enforcement designs, with the trade-off already measured:

(a) **One hook at the state-write boundary.** A new task appearing in `state.json` without a recorded audit is refused. Uniform across every creation surface -- present and future -- and the user has explicitly stated that uniformity and avoiding needless complexity are the governing values here. COST: registering the hook requires `agent-system/extensions/core/manifest.json` and `agent-system/extensions/core/root-files/settings.json`, which are owned by open tasks 263, 280, 281, 282 and 307 -- five serializing dependency edges.

(b) **Per-surface wiring.** Each creation surface calls the shared script: `agents/meta-builder-agent.md`, `commands/task.md`, `skills/skill-fix-it/SKILL.md`, `skills/skill-spawn/SKILL.md`, `commands/review.md`, `commands/errors.md`. COST: six wirings that a seventh future surface can silently omit, and serializing edges against open tasks 44, 300, 302, 308 and 309 -- with 44 itself transitively blocked behind 87/149/210.

Both cost roughly five edges, so edge count does not decide it; uniformity versus blocking depth does. **Neither option's registration or wiring paths are declared in this task's `file_scope` yet, deliberately** -- that would prejudge the ruling. Once research rules, add the chosen option's paths to `file_scope` at that point (via the research phase's `proposed_file_scope` mechanism) and accept the serializing edges then.

## Why the three declared dependencies are functional, not merely serializing

- **#300** (AskUserQuestion unreachability in dispatched subagents): the audit's verdicts need a human ruling, and `/meta`'s creator is a dispatched subagent where that gate is unreachable. 300 resolves exactly this. Without it, a reconciliation that must ask "is this a duplicate of 272?" has nowhere to ask from.
- **#165** (posture for an absent `file_scope`): a backlog comparison keyed on `file_scope` is blind to any task that declares none. 165 settles whether an absent `file_scope` is admission-relevant, which determines whether the mechanical pass can be trusted or must degrade loudly.
- **#282** (write-time PreToolUse hook registered bare so `exit 2` survives): establishes the registration pattern a blocking hook needs. Load-bearing only if design (a) is chosen, but the hook file is in this task's declared scope.

## Explicit non-goals

- Do NOT rework the overlap predicate in `file-footprint-overlap.md`. It is sound and deliberately scope-agnostic.
- Do NOT rework the admission-time layers (the three/five-input model in `batch-orchestration-guardrails.md`). This task is about CREATION time; admission time already works and is a different scan scope.
- Do NOT auto-abandon, auto-merge or auto-rewrite any existing task. Every reconciliation verdict beyond adding a dependency edge is surfaced for a human ruling. Silent mutation of a task a human wrote is a worse failure than the duplication this fixes.

## Acceptance

A task-creation attempt that duplicates, subsumes or is subsumed by an open task cannot complete without the verdict being surfaced; the 309/310/311 incident above is reproducible as a regression fixture and yields the three correct verdicts (309 subset-of-302, 310 duplicate-of-272, 311 genuinely-new).

---

### 282. Write-time PreToolUse hook blocking record-versioning language, registered bare so exit 2 survives
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 280, Task 281, Task 364

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Build the write-time enforcement consumer for the record-versioning rule: a PreToolUse hook
that blocks a Write/Edit introducing forbidden record-version language into a deliverable, driven
ENTIRELY by the shared pattern library, plus its fixture test and its settings.json registration.

DELIVERABLES:
(1) hooks/validate-no-record-versioning.sh -- modeled on hooks/validate-no-task-references.sh, whose
    header records three non-obvious contracts this hook must inherit verbatim:
      - BLOCK VIA EXIT CODE 2 + a stderr message, NOT via `permissionDecision: deny`, which is
        documented-buggy for allow-listed Write/Edit tool calls (settings.json carries bare
        "Write"/"Edit" permissions.allow entries; upstream issues #4669, #13214, #18312).
      - FAIL OPEN (exit 0, with a WARNING on stderr) if the shared library is missing OR fails to
        source. The sibling guards BOTH cases explicitly, because under `set -e` an unguarded `.`
        failure would abort before reaching the fallthrough. A broken guard must never block every
        write in the repo.
      - Resolve the library relative to the hook's own directory via BASH_SOURCE, so resolution is
        independent of the tool's cwd.
(2) hooks/... registration in root-files/settings.json, appended to the existing PreToolUse
    "Write|Edit" matcher block that already carries validate-no-task-references.sh. REGISTER IT BARE
    -- no `2>/dev/null || echo '{}'` wrapper. That wrapper converts exit 2 into exit 0 and silently
    disables the block; the sibling's header calls this out as a specific trap, and the PostToolUse
    entries in the same file DO use that wrapper, so the contrast is easy to get wrong by copying the
    wrong neighbor.
(3) scripts/tests/test-validate-no-record-versioning.sh -- fixture test modeled on
    scripts/tests/test-validate-no-task-references.sh.

=== THE ADVISORY TIER AT WRITE TIME -- RESOLVE THIS EXPLICITLY ===
A hook has only two outcomes (block or allow), so the taxonomy's advisory tier has no direct
write-time expression. Decide and RECORD the posture rather than leaving it implicit: the default
recommendation is that the hook blocks on BLOCKING-tier findings only and stays SILENT on advisory
ones, leaving advisory surfacing to the repo-wide lint. A hook that printed advisory noise on every
Write would train users to ignore it. If research concludes advisory findings warrant a
non-blocking stderr note instead, say so in the hook header and in the taxonomy's Enforcement
section, and keep the two documents consistent.

=== DEPENDENCY NOTE ===
Edges on both prior tasks. On the rule/taxonomy/library task: substantive -- there is no library to
source and no tier to honor until it exists. On the lint task: partly substantive, partly footprint.
Substantive because the lint is where the discriminator gets its first real-corpus exercise, and a
write-time blocker inheriting an unvalidated discriminator would block legitimate writes across the
repo -- the highest-cost failure mode in this batch. Footprint because both touch manifest.json.

=== WIRING ===
  - manifest.json: add the hook to provides.hooks and the test to the tests list (the sibling's
    entries are the `validate-no-task-references.sh` and `tests/test-validate-no-task-references.sh`
    lines).

ACCEPTANCE. Hook shellcheck clean per context/standards/shell-strict-mode.md. Fixture test covers:
blocking finding denied with exit 2 and an actionable stderr message naming the rule; a specs/**
path allowed; an advisory-only finding allowed; marker-exempted content allowed; and a
deliberately-broken/absent library failing OPEN with exit 0. settings.json registration verified
bare (grep the deployed-form command string for the absence of `|| echo` on this entry). After
registration, confirm an ordinary Write to a docs/ file carrying only durable-axis version language
(a toolchain pin, a schema filename, a CI cache key) is NOT blocked -- a false positive here is
worse than no hook. No task-number references in deliverables outside specs/**.

---

### 275. Per-repo orchestration queue: registered, live, archived on finish, and consumed by admission
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 170, Task 272

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Register orchestrations in a per-repo queue whose metadata stays current, archive them when
they finish, and expose the queue as an admission input so a new orchestration runs when it does
not conflict and is refused with named alternatives when it does.

=== SEMANTICS -- RULED, DO NOT RE-OPEN ===
REGISTRY PLUS IMMEDIATE REFUSAL. The queue is a live record of in-flight orchestrations plus an
archive of finished ones. A conflicting new orchestration is REFUSED IMMEDIATELY, with the conflict
named and alternatives suggested. There is NO WAITING QUEUE, NO SCHEDULER, NO AUTO-START and NO
UNATTENDED EXECUTION. Do not design enqueue-and-wake machinery. "Queue" here means the registry and
its archive, not a work queue that something drains.

SCOPE -- RULED: PER-REPO. One queue per repository, living beside the existing session registry. No
cross-repo global queue and no global-ready schema requirement: file_scope conflicts are inherently
per-repo, so a global queue would carry no information the per-repo one lacks.

=== WHAT THIS OWNS ===
The record schema; the lifecycle states registered -> running -> finished -> archived; keeping the
record's metadata current while an orchestration runs; archiving on completion; and exposing the
queue as an admission input.

This task TAKES OVER PIECE 4 OF TASK 272 IN FULL: per-orchestration identity distinct from
`session_id`, so two batches in two sessions of one repo keep separate
metadata/artifacts/return-meta rather than a single shared in-flight record. That piece has been
removed from 272's scope and lives here.

=== VERIFIED GROUNDING IN THE SOURCE STORE ===
(1) THERE IS NO ORCHESTRATION-LEVEL RECORD TODAY, AND NO HISTORY WHATSOEVER. task-lock.sh's
    `cmd_session_release` is a bare `rm -f "$sessions_dir/${session_id}.json"` -- a finished
    session's entry is DELETED, not archived. Nothing anywhere records that an orchestration ever
    ran. The archive half of this task is therefore genuinely new construction, unlike the live
    half.
(2) NO `orchestration_id` CONCEPT EXISTS anywhere in scripts/, context/, skills/ or commands/
    (measured: zero occurrences). The unit of identity today is `session_id`, and ONE SESSION CAN
    COVER SEVERAL TASK NUMBERS -- observed live, a single session covering 696, 701, 703, 704, 649
    and 650 in one repo. That many-to-one relation is exactly why an orchestration-level id is
    needed and why `session_id` cannot serve as one.
(3) BUILD ON THE EXISTING SESSION REGISTRY, DO NOT REPLACE IT. specs/.sessions/{session_id}.json
    with session-register / session-heartbeat / session-release / session-reap / session-list is
    the substrate.
(4) REUSE THE EXISTING LIVENESS VOCABULARY -- DO NOT TRANSCRIBE A SECOND COPY. `session_liveness()`
    already computes six reasons: `corrupt`, `dead-pid`, `dead-pid-within-grace`, `stale-heartbeat`,
    `pid-alive`, `undeterminable`, governed by two thresholds
    (SESSION_REGISTRY_DEAD_PID_MIN, SESSION_REGISTRY_REAP_MIN) in a documented evaluation order
    (dead-pid tested first). Its own header records that it was factored out precisely so
    cmd_session_list and session_contention() consume the IDENTICAL verdict rather than a second
    transcription. A queue entry's liveness must consume that verdict for the same reason.
(5) ARCHIVAL LOCATION MUST BE SETTLED WITH TASK 51, which relocates the per-session runtime files
    out of the specs root and owns scripts/reap-session-runtime-files.sh,
    context/standards/orchestrator-runtime-files.md and scripts/check-runtime-file-tracking.sh.
    Task 51's own text warns against creating a fourth orphaned naming generation -- an
    independently-chosen archive path here would be exactly that. ALSO check how skills/skill-todo/
    archives tasks, so orchestration archival follows the established convention rather than
    inventing a new one.

=== DEPENDENCY NOTES ===
Edge on 272 is SUBSTANTIVE, not footprint: a queue whose metadata silently stops updating is worse
than no queue at all, so the zero-heartbeat defect (272's piece 1) must be diagnosed before this
queue relies on heartbeat-driven currency. Edge on 51 is substantive too: it relocates the runtime
files this queue lives among and owns the relevant standard. Both droppable per the standing
convention if either stalls -- but if 272 is dropped, record what currency guarantee the queue
assumes in its absence.

file_scope OVERLAP IS DELIBERATE: this task shares scripts/task-lock.sh,
scripts/command-gate-in.sh and context/patterns/task-lock.md with 272. The dependency edge on 272
serializes that overlap rather than leaving it to chance.

NEW SCRIPTS: add a queue script and its test under scripts/ if research concludes one is warranted.
Name them in the plan; do not pre-commit to them here.

ACCEPTANCE. A record schema with its lifecycle states documented to the standard of the existing
session-registry contract in context/patterns/task-lock.md; finished orchestrations demonstrably
archived rather than rm -f'd, at a location agreed with task 51's relocation; queue-entry liveness
shown to consume `session_liveness()`'s verdict rather than recomputing it; the queue readable as an
admission input; a fixture test covering registered -> running -> finished -> archived and the
refusal path. Shellcheck clean per context/standards/shell-strict-mode.md. No task-number references
in deliverables outside specs/**.

=== CROSS-REPO COUNTEREXAMPLE TO THE PER-REPO SCOPE RULING -- ESCALATION PENDING (2026-10-13) ===
The "SCOPE -- RULED: PER-REPO" paragraph above rests on the premise that "file_scope conflicts are
inherently per-repo". A measured incident contradicts that premise: an orchestrate conclusion-stage
channel (a) dispatch running in ~/Projects/BimodalLogic edited this repo's lean-extension source
store (commit f49576632) inside the declared file territory of tasks 398 and 399 here, while both
sat [NOT STARTED], having been filed from the identical four issue-log entries about an hour
earlier. Two repositories' task spaces collided on one shared source-store file tree, with no
dependency edge and no overlap finding possible between them.
The ruling is NOT re-opened here and remains the repository owner's call. Task 401
cross_repo_source_store_gate_blindness carries the evidence and owns running that question to an
owner decision. Consult it before concluding this record's research, and if the ruling is amended,
the amendment belongs in this record as a dated amendment note. No dependency edge was added in
either direction, deliberately -- see 401 for the reasoning.

---

### 274. Next-admissible-batch suggestion and alternatives-on-conflict, both computed by invoking the real admission script
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 165, Task 272, Task 273, Task 275, Task 344

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. The orchestration concludes by suggesting the next most natural batch of tasks to run after
clearing context, computed from the dependency DAG PLUS file_scope disjointness -- i.e. a batch that
scripts/orchestrate-batch-admit.sh would ACTUALLY ADMIT together, so the user can open a fresh
session and run it directly.

=== TWO MODES, ONE PREDICATE ===
MODE A -- NEXT-BATCH AT CONCLUSION (the original scope above): at the end of an orchestration,
suggest the next most natural batch to run after clearing context.

MODE B -- ALTERNATIVES ON CONFLICT (added): when an orchestration is REFUSED for conflicting with
an in-flight one, suggest nearby task sets that could run in parallel instead. Same predicate as
mode A, DIFFERENT TRIGGER -- refusal time rather than conclusion time. Alternatives are drawn from
the orchestration queue (task 275), which is why this task depends on it.

WHAT THE ADMISSION SCRIPT DOES AND DOES NOT GIVE YOU. scripts/orchestrate-batch-admit.sh emits a
PER-CANDIDATE verdict and, for an idle overlapping task, an `idle_overlap_advisory` naming the
colliding task, its status, the overlapping path and the collision scope. It has NO NOTION OF
ALTERNATIVES: it answers "may this candidate set run?", never "what else could run instead?".
The alternatives search is therefore a NEW CALLER-SIDE LOOP over candidate sets, NOT a change to
the script's verdict schema. Do not extend the schema to carry alternatives.

BINDING CONSTRAINT ON HOW THE SUGGESTION IS COMPUTED. The predicate must be established by ACTUALLY
INVOKING scripts/orchestrate-batch-admit.sh over candidate sets and reading its v5 verdicts --
never by re-implementing, approximating, or duplicating its logic. A second copy of the admission
predicate would drift from the real one, and a suggestion the real script then refuses is worse
than no suggestion at all. Respect the existing verdict schema and its consumers
(scripts/orchestrate-predispatch-review.sh is one) rather than extending the schema.

DEPENDENCY NOTES.
- Edge on task 275 (hard, substantive): mode B's alternatives are drawn from the orchestration
  queue, so there is nothing to draw from until 275 exists.
- The existing edge on task 272 is now TRANSITIVELY REDUNDANT, since 275 itself depends on 272.
  It is left in place deliberately -- a redundant edge is harmless and costs only a wave, whereas
  removing it would obscure why live registry scope matters to this task. Do not "clean it up".
- Edge on task 272 (hard, substantive): the suggestion is only trustworthy if the session
  registry's file_scope is LIVE rather than frozen at register time, and if a live-but-stale lock
  is visible as held. Computing a "safe next batch" against a stale registry snapshot produces
  confidently wrong suggestions -- worse than offering none.
- Edge on task 273 (hard): this suggestion is rendered by 273's conclusion stage, and both tasks
  edit skills/skill-orchestrate/SKILL.md, so the edge is footprint-corroborated as well as logical.
- Edge on task 165 (hard, substantive): 165 rules on whether an ABSENT file_scope is
  admission-relevant. That ruling directly changes which batches this task would suggest -- today a
  task with no declared scope is indistinguishable from one that provably collides with nothing, so
  a suggester built before the ruling would confidently propose batches the post-ruling script
  refuses. 165 also owns orchestrate-batch-admit.sh, this task's primary input. Per the standing
  convention, DROP THE EDGE rather than hold this task if 165 stalls -- but if it is dropped, record
  which absent-file_scope posture the suggester assumed.

ACCEPTANCE. A suggested batch is verified by running the real admission script over it and showing
every member admitted; a fixture where two candidates collide on file_scope demonstrably does NOT
appear as a joint suggestion; no copy of the admission predicate exists anywhere in the new code;
shellcheck clean per context/standards/shell-strict-mode.md. No task-number references in
deliverables outside specs/**.

=== EDGE-PROPOSING STEP (ADDED) ===
The disjointness criterion above (a file_scope-colliding pair must not appear as a JOINT
suggestion) stays correct and is UNCHANGED by this addition: without a serializing
dependencies[] edge, a colliding pair would share a wave and write concurrently, so admission
correctly refuses it. The defect this closes is narrower: today the suggester has NO
EDGE-PROPOSING STEP, so it silently WITHHOLDS exactly the pairs
batch-orchestration-guardrails.md's dominance rule (rule 1) makes mandatory, instead of
proposing the edge that would make them admissible as a sequence. When two otherwise-suggestible
candidates collide on file_scope, PROPOSE the serializing edge via `update-task-status.sh
--depends-on-add` (direction per that flag's own stated rule) and THEN suggest the pair as a
SEQUENCE -- never silently drop the pair from the suggestion with no further action. This adds
a step before giving up on a colliding pair; it does not weaken, bypass, or relax the
disjointness check itself, which continues to govern whether a pair may appear as an unordered
JOINT suggestion.

---

### 170. Audit and isolate shell test suites from ambient host state (memory and timing axes), and record the convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 206, Task 215, Task 250, Task 251, Task 366

**Description**: Audit all shell test suites in the source store for assertions whose outcome depends on ambient host state, isolate each at the script-under-test's own documented env seams (or, where no seam is possible, by a technique appropriate to the axis), and record the isolation convention in `context/standards/shell-script-testing.md` so future suites inherit it by default.

=== TWO CONFIRMED INSTANCES -- THE DEFECT CLASS IS NOT A SINGLE-SUITE ANOMALY ===

Both were observed live. They sit on DIFFERENT axes and need DIFFERENT remedies.

--- INSTANCE A (memory axis) -- `test-lake-build-guard.sh`, cases 1, 3, 11 ---

Failed because `lake-build-guard.sh` read the REAL `/proc/pressure/memory` and `/proc/meminfo`,
and the host was swapping at 57% of SwapTotal -- over the guard's own
`SWAP_USED_RATIO_THRESHOLD=50`. Cases 1 and 3 assert byte-identical transparency on the guard's
clean path; case 11 asserts preflight exits 0 when the PSI path is unavailable. All three pass on
an idle machine and fail on a busy one -- and a busy machine is exactly what a multi-task
`/orchestrate` batch produces.

ALREADY FIXED -- DO NOT REDO. Commit `878043472` isolates this suite suite-wide by redirecting
`LAKE_BUILD_GUARD_PSI_PATH` and `LAKE_BUILD_GUARD_MEMINFO_PATH` to clean fixture files in the
suite's own mktemp workdir, via the script's documented env seams. Verified 27/27 pass and
verified non-vacuous. This suite is the EXEMPLAR the audit generalizes from, not work to repeat.
The separate positive-direction case for it is tracked as its own prerequisite task (this task
depends on it) -- do not duplicate that either.

--- INSTANCE B (timing axis) -- `test-four-tier-conflict.sh`, case 6 "budget-bound" ---

CONFIRMED AFFECTED, NOT YET FIXED. This one is the task's primary unsolved exemplar.

Evidence, all observed live:
  - Pre-fix full `run-all.sh`: this suite PASSED (only `test-lake-build-guard.sh` failed).
  - Post-fix full `run-all.sh`: this suite FAILED with
      `6: budget-bound -- rc=1 elapsed_ms=2989 budget_ms=1000`
  - Immediate ISOLATED re-run of the same suite: PASSED, with
      `6: budget-bound -- exhaustion elapsed 1752ms within [1000ms, 2000ms)`

Commit `878043472` touched exactly one file (`test-lake-build-guard.sh`), so it cannot have
caused this. The discriminating fact is the isolated re-run passing. The assertion at
`test-four-tier-conflict.sh:294` is a wall-clock window:

    [ "$rc6" -eq 1 ] && [ "$elapsed6_ms" -ge "$BUDGET_MS" ] && [ "$elapsed6_ms" -lt $(( BUDGET_MS * 2 )) ]

with `BUDGET_MS=1000`. The window `[1000ms, 2000ms)` holds on an unloaded machine and breaks under
concurrent load. Same "outcome determined by ambient host state" shape as instance A, on the
timing axis instead of the memory axis.

ADJACENT, SAME SUITE, LIKELY SAME DEFECT: case 5 (`test-four-tier-conflict.sh:271`) asserts
`elapsed5_ms -lt 500` as a proxy for "the retry loop was never entered". That is the same
wall-clock-as-proxy shape and is expected to flake under load for the same reason; triage it
alongside case 6 rather than treating case 6 as isolated. Case 1 also reports elapsed wall
clock -- check whether it merely reports or actually asserts on it.

--- WHAT THE SECOND INSTANCE CHANGES ABOUT SCOPING ---

1. The audit premise is confirmed empirically, not speculative.
2. The timing axis is genuinely represented, so the audit MUST cover wall-clock windows and
   elapsed-time proxies, not only `/proc` reads.
3. The shell-test-suite gate is currently FLAKY, not simply red: `run-all.sh` has now failed
   twice in a row for two DIFFERENT single-suite reasons. Acceptance is set accordingly below.

=== BLAST RADIUS (why this warrants a dedicated audit, not a one-off patch) ===

A single suite failure fails `verify-deploy.sh`'s shell-test-suite gate (1 of 30 checks), which
fails `deploy-headless.sh`, which makes `skill-orchestrate`'s inter-cycle redeploy checkpoint
defer an ENTIRE orchestrate batch. One host-coupled assertion in one suite stalls unrelated work.
The defect class is load-bearing on throughput, not merely on test hygiene. A flaky gate is worse
than a red one: it defers batches nondeterministically and trains readers to re-run rather than
diagnose.

=== THE DEFECT CLASS TO HUNT ===

Any assertion whose outcome depends on ambient host state:
  - memory (`/proc/meminfo`, `/proc/pressure/memory`, swap usage, `free`)          [instance A]
  - wall-clock timing (elapsed-time windows, `sleep`-dependent ordering,
    `date +%s` / `%N` deltas, `SECONDS`, `timeout` values tuned to a fast machine)  [instance B]
  - load / CPU count (`/proc/loadavg`, `nproc`, `getconf`, `uptime`)
  - network reachability (`curl`, `wget`, `ping`, DNS, any live API)
  - free disk (`df`)
  - the process table (`pgrep`, `ps`, PID reuse, pre-existing processes matching a pattern)
  - anything else read from the live host rather than from a fixture

=== SURVEY ALREADY PERFORMED (starting point, NOT the answer) ===

72 files match `test*.sh` under `agent-system/extensions/**`. A keyword grep over the signals
above flagged 25. Ordered by raw hit count:

  13  core/scripts/test-four-tier-conflict.sh               (INSTANCE B -- confirmed affected)
  12  core/scripts/tests/test-lake-build-guard.sh           (INSTANCE A -- already isolated)
   6  literature/scripts/test-lit-pipeline.sh
   6  core/scripts/tests/test-validate-state.sh
   6  core/scripts/tests/test-claude-refresh-matcher.sh
   4  core/scripts/test-state-write-concurrency.sh
   3  literature/scripts/tests/test-literature-convert.sh
   3  lean/scripts/tests/test-lean-comparator-run.sh
   3  core/scripts/tests/test-loop-guard-budget-override.sh
   2  literature/scripts/tests/test-literature-discover-tier3.sh
   2  core/scripts/tests/test-subagent-postflight-marker.sh
   2  core/scripts/tests/test-lint-branch-gated-sections.sh
   2  core/scripts/tests/test-handoff-dispatch-identity.sh
   2  core/scripts/test-state-write-regen-timing.sh
   2  core/scripts/test-session-registry.sh
   2  core/scripts/test-conflict-predicate.sh
   1  each: core/scripts/test-task-lock-reap.sh, core/scripts/test-session-runtime-files.sh,
          core/scripts/tests/{test-validate-return-meta,test-status-vocabulary,
          test-skill-base-lifecycle,test-phase-heartbeat,test-phase-heading-patterns,
          test-guard-destructive-git,test-common-lib}.sh

Both confirmed instances rank first and second, which is mild evidence the ranking carries signal
-- but RAW HIT COUNT IS NOT SEVERITY, and this list is neither sound nor complete:
  - FALSE POSITIVES ARE EXPECTED. A `sleep` inside a concurrency suite that deliberately
    exercises lock contention may be legitimate; `pgrep` inside a suite whose subject IS process
    matching (`test-claude-refresh-matcher.sh`, `test-task-lock-reap.sh`) may be exercising the
    real behavior under test. Triage each hit; do not mechanically "fix" every match.
  - FALSE NEGATIVES ARE LIKELY. The grep cannot see host coupling entering through a library the
    suite sources, through the script under test rather than the suite itself (exactly how
    instance A arrived), or through a helper that shells out. Read the scripts under test, not
    only the suites. Suites absent from this list are NOT thereby cleared.
  - Names containing `timing`, `concurrency`, `heartbeat`, `budget`, `reap`, or `staleness` are
    prior-suspect on the timing axis regardless of hit count.

=== REQUIRED APPROACH -- SEAM-FIRST, BUT DO NOT PRESUME THE SEAM REMEDY TRANSFERS ===

For state READ FROM A FILE OR COMMAND (the memory/`proc`/disk/network/process axes), instance A's
remedy is the model:
  1. Identify the script-under-test's OWN documented env seam (`lake-build-guard.sh` provides
     `LAKE_BUILD_GUARD_PSI_PATH` / `LAKE_BUILD_GUARD_MEMINFO_PATH`). Prefer an existing seam.
  2. If none exists, adding one to the script under test is in scope -- but it must be a genuine,
     documented override point with a real-host default, NEVER a test-only branch or an
     "if running under test" conditional.
  3. Point the seam at a fixture authored into the suite's own mktemp workdir, per the existing
     fixture convention in `context/standards/shell-script-testing.md` (heredoc-authored, fresh
     per case where staleness would otherwise mask behavior, never resolved against the live tree).

For WALL-CLOCK TIMING (instance B), THE SEAM REMEDY MAY NOT APPLY AT ALL. There may be nothing to
redirect: the quantity is elapsed real time, not a readable input. Do not force the memory-case
technique onto it. Evaluate at least these, per assertion, and justify the choice:
  - Inject the clock -- give the script under test a seam for its time source so the suite can
    drive elapsed time deterministically. Strongest option where feasible.
  - Assert ORDERING or CAUSALITY instead of elapsed wall clock -- e.g. for case 6, that the retry
    loop terminated on budget exhaustion rather than on a lock acquisition, and for case 5, that
    the retry loop was never entered at all. Both are the property the elapsed-time window is
    only a PROXY for; asserting the property directly removes the host coupling without weakening
    anything. Prefer this where the underlying property is observable (a counter, a log line, a
    return path).
  - Widen the window to generous-but-still-bounded ONLY as a last resort, and only when the
    widened bound still falsifies the failure mode the assertion exists to catch (for case 6:
    "nowhere near a minutes-scale wait"). A bound that no longer discriminates is a deleted test.
    This option requires explicit justification in the summary naming what it still catches.

NON-VACUOUSNESS CHECK PER ISOLATED SUITE, MANDATORY on every axis. After isolating, demonstrate
the logic under test is still genuinely exercised -- typically by driving the opposite direction
with a fixture or condition that SHOULD trip the behavior and confirming it does. An isolation
that makes a suite assert nothing is worse than the host coupling it replaced. Record each check.

=== CONSTRAINTS ===

- All edits target `agent-system/extensions/**` ONLY. Never hand-author anything under
  `.claude/**`; that tree is a disposable deploy artifact regenerated from source
  (see `.claude/rules/source-store-deploy-boundary.md`).
- NEVER weaken, raise, or bypass a guard threshold, loosen an assertion into vacuity, or mark a
  case skipped to make a suite pass. Isolate the INPUT; do not relax the ASSERTION. The
  last-resort window-widening above is a bounded, justified exception on the timing axis only --
  it is NOT licence to relax thresholds generally, and never applies to a guard's own constants.
- Where a suite legitimately depends on real host state and cannot be isolated, use the loud-skip
  discipline already documented in `shell-script-testing.md` rather than a silent skip, and
  justify the exemption in the summary.

=== DELIVERABLE: THE CONVENTION ===

Extend `agent-system/extensions/core/context/standards/shell-script-testing.md` (127 lines;
existing sections: Location rule, Helper-naming convention, Fixture convention including "Never
resolve a path against the live tree", Loud-skip discipline, Mutation checks for regex-shaped
fixes, Registration, Related). Add an ambient-host-state isolation section that:
  - names the defect class and why it is load-bearing (the deploy-gate blast radius above),
    citing both confirmed instances as the worked examples -- one per axis;
  - states the seam-first rule for readable-input axes, and the bar for adding a new seam;
  - states separately that the timing axis needs a different technique, with the
    inject-clock / assert-causality / bounded-widening ladder and the rule that elapsed wall
    clock must not be used as a proxy for a property that is directly observable;
  - requires the per-suite non-vacuousness check;
  - forbids threshold relaxation as a remedy;
  - cross-references the existing Fixture convention and Loud-skip discipline sections rather
    than restating them.
Place it so it composes with, not duplicates, what is already there.

=== ACCEPTANCE ===

- Every one of the 72 suites has been triaged, with a recorded verdict: affected-and-isolated,
  false-positive-with-reason, or legitimately-host-dependent-and-loud-skipped.
- Instance B (`test-four-tier-conflict.sh` cases 6 and 5) is fixed, with the chosen technique
  justified against the ladder above.
- Each isolated suite carries a demonstrated non-vacuousness check.
- REPEATED-RUN ACCEPTANCE, NOT A SINGLE GREEN RUN. "run-all.sh passes once" is too weak: the gate
  has already failed twice consecutively for two different single-suite reasons, and instance B
  passes in isolation while failing in a full run. Require instead:
    (a) `run-all.sh` green across multiple consecutive runs (at least 3);
    (b) at least one of those runs under DELIBERATE concurrent load -- both memory pressure above
        the lake guard's own threshold and CPU/IO contention sufficient to have reproduced the
        case 6 failure, verified by first confirming the load reproduces the ORIGINAL failures on
        a pre-fix checkout;
    (c) full-run and isolated-run results agreeing for every suite -- a suite that passes alone
        but fails in the batch is still affected.
  Record the load-generation method used so the check is reproducible.


=== SCOPE NARROWED 2026-09-22 (eighth-pass phase 0) ===
The three whole-directory file_scope entries (core/scripts/tests/, lean/scripts/tests/, literature/scripts/) were removed: they deferred 207, 217, 223 and 244 in the dry run and drew two validate-state.sh coarse-scope warnings spanning 11 tasks. The named test-*.sh files, task-lock.sh and shell-script-testing.md stay. Research MUST name the specific suites the audit will edit and ADD them to file_scope before the implement dispatch (the convention the 224 narrowing followed on 2026-09-17). ORDERING: after 51 (task-lock.sh, test-session-runtime-files.sh) and 129 (test-session-runtime-files.sh, test-lake-build-guard.sh), recorded as dependency edges.

=== DEPENDENCY ADDED 2026-09-22 (new suites enter the triage set) ===
Two newly created tasks each add a standing repo-health probe WITH ITS OWN TEST SUITE (test-script-inventory.sh and test-context-reachability.sh). This task's acceptance criterion is that EVERY suite has a recorded triage verdict, so the audit must run after those suites exist or it certifies a set it no longer covers. Dependency edges recorded accordingly; the survey count above ("72 files match test*.sh") is the 2026-09-22 figure and MUST be re-derived at research time rather than trusted -- the corpus grows.

=== EVIDENCE ADDENDUM (2026-09-22, observed live) ===

INSTANCE A IS NOT CLOSED BY THE EXISTING FIX -- the defect class is still live post-878043472.

During an /orchestrate implement dispatch, a full `run-all.sh` over the SOURCE STORE copy
reported `test-lake-build-guard.sh` FAILING. An isolated re-run of the same suite immediately
afterwards, on the same machine and same commit, reported `Passed: 47  Failed: 0`.

This is the SAME discriminating shape already recorded for Instance B
(`test-four-tier-conflict.sh` case 6): fails inside a loaded full-suite run, passes in
isolation. It confirms that the env-seam redirection in 878043472 (LAKE_BUILD_GUARD_PSI_PATH /
LAKE_BUILD_GUARD_MEMINFO_PATH to fixture files) did NOT make the suite fully load-independent --
some assertion in it still reads ambient state, or is timing-sensitive, on an axis the fixture
redirection does not cover.

IMPLICATION FOR THIS TASK'S SCOPE: the "ALREADY FIXED -- DO NOT REDO" note above should be read
as "the memory axis was isolated", NOT as "this suite is now load-independent". The audit must
re-examine this suite rather than treating it purely as the exemplar to generalize from.
Determining WHICH case fails under load is the first concrete step -- the full-suite run does
not name it, so the failing case must be captured by re-running under induced load with
per-case output retained.

Contemporaneous context that plausibly supplied the load: the same run-all.sh invocation took
~40 minutes of wall clock with concurrent agent activity on the machine.

=== ROSTER ADDENDUM (2026-10-04, measured) — A SECOND DEFECT CLASS SHARES THIS GATE ===

Measured roster, from a full `run-all.sh` on a committed tree:
`103 passed, 6 failed (2 expected, 4 NEW), 2 skipped, 111 total`. The suite corpus is now 111,
not the 72 recorded above — re-derive it at research time as this task already instructs.

This task's acceptance requires `run-all.sh` green across at least 3 consecutive runs with
full-run and isolated-run agreement for every suite. That is currently unreachable, and NOT
because of ambient-host-state coupling. A SECOND, DISTINCT defect class is red on the same gate:
**sandbox-fixture incompleteness** — a suite's hardcoded copy-list omits a collaborator the real
script-under-test invokes, so the first real invocation dies with a 127 that surfaces as an
unrelated assertion mismatch much later. This is the same mechanism `known-failures.txt`'s own
header records as having produced three earlier phantom failures via a missing
`lib/return-meta-status-vocabulary.sh`.

DO NOT TRIAGE THESE AS AMBIENT-HOST-STATE. They are load-INdependent and reproduce identically in
isolation. Misfiling them as instance-A/instance-B-class would corrupt this task's triage verdicts.

Current roster, with what is already established about each:

  test-orchestrate-cycle-plan.sh        (NEW) — 335 passed, 14 failed. Fixture gap PARTLY FIXED
      already: `generate-task-order.sh` and `update-plan-status.sh` (transitive collaborators of
      the real `generate-todo.sh`/`update-task-status.sh` the Group 28 block copies) were added to
      its copy-list, which removed the 127 cascade. The 14 remaining failures are Group 28/29 and
      are a REAL product question, not a fixture gap: Group 28 expects an IDENTICAL DISPATCH HALT
      to fire on cycle 2 and it does not; Arms B/C/D expect the same halt and the streak-freeze
      notice. Needs its own verdict: either the halt mechanism is broken or the expectations are
      stale. This is the single largest block of red in the corpus.
  test-orchestrate-build-aux-dispatch.sh (NEW) — 17 passed, 1 failed. `plan-revision`'s model
      resolves to empty where the suite expects `opus`. Established: `reviser-agent.md` really does
      carry `model: opus` in its own frontmatter, and task 331's change to
      `lib/manifest-routing-lib.sh` was purely additive (107 insertions, 0 deletions), so neither
      the agent file nor that change explains it. Root cause undetermined.
  test-detect-noop-bash.sh              (NEW) — root cause undetermined. Note its subject
      (`hooks/detect-noop-bash.sh`) writes the per-session `tmp/noop-bash-count-*` marker whose
      orphan-detector exclusion was added separately; check whether the suite and that exclusion
      now disagree.
  test-lint-deploy-caller-wrap.sh       (NEW) — root cause undetermined. Its reported finding is
      about `orchestrate-cycle-plan.sh` not being "wrapped to true EOF" in a self-test scratch
      copy, which smells like a scratch-copy construction artifact rather than a product defect.
  test-gate-out-repair-reporting.sh     (EXPECTED, real-defect, needs-owner)
  test-lint-json-channel-discipline.sh  (EXPECTED, real-defect, needs-owner)

The two EXPECTED rows carry `needs-owner`, and `known-failures.txt`'s own header states that a
`needs-owner` row is a known gap rather than an accepted steady state, requiring a follow-up to
either fix or formally accept each. Since this task's acceptance is a green gate, give each of
the two an explicit verdict here rather than leaving them to a further task.

ALREADY FIXED — DO NOT REDO (all verified, all committed):
  - `test-verify-deploy-context-budget.sh` resolved `REPO_ROOT` by a fixed four-hop `..` walk,
    correct from the source store but overshooting to `$HOME` from the deployed tree that
    `run-all.sh` actually uses. It exited 2 on a path that never exists, so Gate 20 was entirely
    unexercised. Replaced with upward marker discovery; the suite is now 15 passed, 0 failed and
    its `known-failures.txt` row is REMOVED. That row's recorded reason was a mis-diagnosis
    (it blamed `skill-orchestrate/SKILL.md` being over ceiling; the file measures 19,921 B against
    a 20,000 B ceiling and gate20 reports zero findings) — treat other recorded reasons in that
    file as unverified until re-measured.
  - The root `.gitignore` had drifted five canonical ephemeral-class patterns behind
    `scripts/lib/runtime-file-patterns.sh`; the context-budget fixture copied that root file, so
    gate14 failed inside the fixture. Both the drift and the fixture's dependence on a
    hand-maintained file are fixed (it now appends `runtime_ignore_block()` from the single source
    of truth, as `test-deploy-orphans.sh` already did).
  - `tmp/noop-bash-count-*` is now an `is_runtime_artifact` exclusion with a planted-canary
    regression, removing a flaky whole-tree orphan finding.

METHOD NOTE for the fixture-completeness class: the reliable detection is to enumerate every
`${SCRIPT_DIR}/<name>.sh` invocation in each REAL script a suite copies into its sandbox, then
diff that set against the suite's copy-list. That is mechanical and worth doing corpus-wide; a
lint for it would prevent the class recurring, and is a better deliverable than fixing the
current instances one at a time.
=== THIRD INSTANCE, AND A NEW FAILURE MODE THE BLAST-RADIUS PARAGRAPH DOES NOT COVER (measured 2026-10-05, nvim/, batch session sess_1791222088_1f4b0c) ===

A bare sequential `bash agent-system/extensions/core/scripts/tests/run-all.sh` on an otherwise
idle checkout produced FOUR failing suites. Three are already in this task's own file_scope -- a
third independent confirmation of the audit premise:

  - test-gate-out-repair-reporting.sh        (in file_scope)
  - test-lint-json-channel-discipline.sh     (in file_scope)
  - test-orchestrate-cycle-plan.sh           (in file_scope)
  - test-orchestrate-recover-outcome.sh      (ADDED to file_scope by this revision)

Caveat to carry into triage rather than assume away: the checkout carried an uncommitted
source-store modification to scripts/orchestrate-cycle-plan.sh from a concurrent session, a
plausible honest cause for test-orchestrate-cycle-plan.sh specifically. Re-measure on a clean
tree before attributing that one to host coupling.

THE NEW FAILURE MODE: the blast-radius paragraph above describes a flaky Gate 8 DEFERRING an
orchestrate batch. This batch exhibited a worse, quieter outcome -- Gate 8 was EXCLUDED rather
than enforced. In task 341's implement dispatch the agent could not get run-all.sh to conclude (a
570s foreground attempt and a backgrounded run both failed to reach a summary line), so it closed
the phase [COMPLETED WITH EXCLUSIONS] with an evidence-bearing Reasoned Exclusion for Gate 8, and
the task completed green. That is correct under the exclusion contract, which is exactly why it is
dangerous: a gate that cannot finish inside a dispatch's practical budget stops being a gate and
becomes a line in an exclusions table, with no red signal anywhere. A flaky gate trains readers to
re-run; an unfinishable one trains them to exclude.

RUNTIME MEASUREMENT BEHIND THAT EXCLUSION (the timing axis this task owns): core/scripts/tests/
holds 89 `test-*.sh` files, but run-all.sh does not run only that directory -- one invocation was
observed starting 111+ suites across core, typst, literature and others. A bare sequential run had
reached only ~53 reported results after ~330s and still had not concluded when stopped past ~450s.
Gate 8's recorded 117.9s is a PARALLEL figure: verify-deploy.sh requests run-all.sh's opt-in
`--jobs` (capped at JOBS_CAP=4), whereas run-all.sh's own default is `--jobs 1`. Any timeout tuned
to the former fails against the latter. Note also run-all.sh's rule that `--jobs` is forced to 1
when it is reached from inside another run-all.sh suite, which makes the sequential path reachable
even when a caller asked for parallelism.

---

### 29. Generate .mcp.json from extension manifests, then register obsidian-memory through it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 22

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions. This is deploy-engine (lua merge-path) and manifest-surface work for extension MCP registration, unrelated to the orchestrate-engine collapse; the consolidation audit confirmed no overlap with the routing ladder it carries forward. Original description follows.Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-22 from former task 30 (register_obsidian_memory_mcp_server); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions, alongside its prerequisite (the .mcp.json generation mechanism). Unrelated to the orchestrate-engine collapse. Original description follows.Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope.

CURRENT STATE: memory/settings-fragment.json carries a dead `mcpServers` block declaring obsidian-memory (npx -y @anthropic-ai/obsidian-claude-code-mcp@latest, with env OBSIDIAN_WS_PORT). It registers nothing, because settings files are not a registration surface. The memory extension IS loaded in this repository, so unlike the five retired servers this one is wanted and should be made to work.

WORK: move the declaration to the new merge target so it lands in .mcp.json, with an explicit "type": "stdio". Then determine the server's ACTUAL tool names and add matching permission grants to the fragment, applying the grant-at-registration-scope rule. Do NOT guess the tool names and do NOT copy them from any existing documentation: enumerate them empirically by starting the server and issuing a tools/list request. This system has already shipped documentation instructing agents to call MCP tools that never existed, and a naming mismatch between a declared server name and its granted mcp__<name>__* prefix has already been found in another extension -- verify both the server name and every tool name against the running server.

RUNTIME PREREQUISITE, DO NOT PAPER OVER: this server needs OBSIDIAN_WS_PORT set and a running Obsidian instance with the companion plugin. If that prerequisite cannot be satisfied in this environment, wire the declaration correctly, document the prerequisite plainly in the memory extension README, and report the tool-name enumeration as NOT VERIFIED rather than inventing plausible names. A truthful 'could not verify' is the correct outcome here; a fabricated tool list is not.

VERIFICATION: .mcp.json contains the entry after a fixture deploy; `jq empty` on both edited files; doc-lint passes for the memory extension; every granted mcp__ tool name either matches a name observed from the running server or is explicitly marked unverified with the reason. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Freeze .opencode: silence fragment validation spam and record the frozen-mirror policy
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: neovim
- **Dependencies**: None

**Description**: === STATUS REPAIRED 2026-09-22 (eighth-pass phase 0): researching -> not_started. No specs/022_* directory, no artifacts and no dispatch record exist in the live tree or the archive; the status was left by a dispatch that never wrote anything (last touched 2026-09-01). It deferred tasks 29 and 45 in every dry run via merge.lua. Nothing else changed. ===

=== REVISED 2026-09-01 (backlog streamline: .opencode declared FROZEN) ===
POLICY SETTLED BY USER DECISION: .opencode/ is FROZEN -- not maintained, not generated, not deleted. No sync mechanism will be built (the sibling sync-mechanism task is abandoned with a pointer here); the tree is preserved intact for possible future refactoring, exactly as this task's binding constraint already required. This settles the reframed design question below ("SHOULD opencode-agents.json fragments reference a per-project deploy tree at all?"): under a frozen mirror, no path corrections are owed and defect class (1) breakage is expected and tolerated -- the fix is to stop the noise and record the policy, not to repair paths that will drift again.

REVISED SCOPE, absorbing the narrowed remainder of the abandoned sync-mechanism task:
1. SILENCE THE SPAM (original core): gate or suppress the ~60-notification validation spam on <leader>al reload (emitter: M.generate_opencode_json / validate_opencode_fragment in lua/neotex/plugins/ai/shared/extensions/merge.lua). Under the frozen policy, missing {file:} deploy targets are an EXPECTED state; the validator must not shout about them on every reload. Prefer gating generation/validation behind the frozen policy (skip, or a single-line summary) over deleting the mechanism -- the binding constraint that no opencode fragment, validator function, or .opencode/ file is deleted still holds.
2. FIX THE ONE FAKE-TOOL LINE (from the absorbed task): .opencode/extensions/web/agents/web-implementation-agent.md still teaches browser_verify_text_visible as a real tool; the source store explicitly retracts it. A frozen mirror may drift, but it must not actively teach a nonexistent tool. One-line fix, editing .opencode/** directly (it has no source-store counterpart; the source-store/deploy-boundary rule does not apply to this tree).
3. RECORD THE POLICY where the next person will look (e.g. a note in .opencode/ and/or the extensions docs): the tree is frozen, unmaintained, drift-expected, and preserved for future refactoring.
ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker produces no validation-failure spam; the fake tool name no longer appears as usable guidance in .opencode/; the frozen policy is written down; nothing under .opencode/ is deleted.
=== ORIGINAL DESCRIPTION FOLLOWS ===
=== REVISED 2026-08-24 (refactor survey) ===
SUBSTANTIALLY OVERTAKEN, and the remaining half got worse. Re-verified today:
- Defect class (3) is FIXED. merge.lua:1002-1041 now degrades per-agent-key, reports every missing key rather than only the first, and no longer discards a whole fragment. Close it out; do not re-fix.
- Defect class (2) MOVED rather than got fixed. The archived path-fix work changed the lean fragment to reference .claude/agents/lean-research-agent.md instead of .claude/extensions/lean/agents/... -- but that path does not exist either.
- Defect class (1) is WORSE: 30 of 34 {file:} refs across all fragments now point at nonexistent files (was 16 of 18). Only nvim and nix resolve, because those are the extensions loaded in this repo -- which is itself the clue.
REFRAME around the one live question rather than patching paths again: SHOULD opencode-agents.json fragments reference a per-project deploy tree at all? Every {file:} ref is per-repo-deploy-dependent by construction, so any path fix is correct only for the extension set of whichever repo it was fixed in. That is why class (1) keeps regrowing. Answer the design question first; the path corrections fall out of it.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Silence and correct opencode-agents.json fragment validation spam on extension reload.

SYMPTOM (observed live): reloading .claude/ via <leader>al from a project with an
opencode.json.managed marker emits ~60 WARN notifications of the form "Extension 'X'
opencode-agents.json validation failed: Agent 'Y' references missing file: Z. Skipping
fragment." before "Resynced 12 extension(s)".

EMITTER: M.generate_opencode_json in lua/neotex/plugins/ai/shared/extensions/merge.lua
(vim.notify at ~line 994), gated on an opencode.json.managed marker check (~line 931), with
per-fragment validation by M.validate_opencode_fragment (~line 887), which resolves each agent
prompt's {file:PATH} against project_dir.

THREE DISTINCT DEFECT CLASSES (measured against a live project, not assumed):

(1) MISSING DEPLOY TARGETS -- 16 of 18 {file:} refs across python (2), present (5), nix (2),
and filetypes (7) point at .opencode/agent/subagents/*-agent.md files that were never
deployed. The .opencode/agent/subagents/ directory DOES exist and holds 15 agent files
(core, lean, latex, typst, math, logic, physics, formal, meta-builder, planner,
code-reviewer), but none for those four extensions. So this is a partial-deploy gap, not a
wholly absent tree.

(2) LEAN WRONG-PATH BUG (independent of any opencode policy decision) --
agent-system/extensions/lean/opencode-agents.json is the ONLY fragment using a .claude/ path
shape. It references .claude/extensions/lean/agents/lean-research-agent.md and
.claude/extensions/lean/agents/lean-implementation-agent.md, neither of which exists anywhere,
while the CORRECT files .opencode/agent/subagents/lean-research-agent.md and
.opencode/agent/subagents/lean-implementation-agent.md ALREADY EXIST on disk. This is a plain
mis-pathed reference, fixable on its own merits regardless of what is decided about opencode.

(3) NOTIFICATION SPAM AND SIMULTANEOUS UNDER-REPORTING -- the same 5 messages repeat ~12 times
because generation runs once per resynced extension rather than once per reload. Separately,
validate_opencode_fragment iterates with pairs() and returns on the FIRST missing ref, so only
one broken ref per extension is ever named, and WHICH one varies nondeterministically between
runs (python alternates python-research/python-implementation; filetypes alternates
scrape/filetypes-spreadsheet). The true breakage (18 refs) is therefore both over-announced in
aggregate and under-reported per message.

BINDING CONSTRAINT (from the user): .opencode/ is NOT currently used and may be excluded from
scope, BUT the fix MUST NOT damage or delete .opencode/ infrastructure. The opencode-agents.json
fragments, the validator function, the managed-marker gating, and the existing .opencode/ tree
must all survive intact so .opencode/ can be refactored in the future. Prefer suppressing or
gating the noise over removing the mechanism.

ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker
produces no validation-failure spam; the lean fragment's two refs resolve to real files;
whatever gating approach is chosen is documented; and no opencode fragment, no validator
function, and no .opencode/ file is deleted.

SOURCE-STORE RULE (binding): edit lua/** for the Lua emitter and agent-system/extensions/** for
the JSON fragments; never edit .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 45 (global_update_extension_repo_registry); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carried topic core-agent-system, but its real scope (the <leader>al extension picker's 'Global Update' action) is nvim-config Lua UI code at lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**, NOT agent-system/extensions/** -- it is unrelated to the orchestrate-engine collapse. Re-topiced to neovim; file_scope backfilled from description evidence (was previously empty). Original description follows.\n\nImplement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded extensions in this nvim repo; add a 'Global Update' entry (similar to 'Reload All') that reloads all extensions already loaded in each registered repo, reporting any failures in a message and otherwise success as a count of the total

=== ABSORBED 2026-09-22 from former task 202 (Make the picker's [Reload All] and [Regenerate] entries honest and self-documenting, and rule on their redundancy); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Fix the <leader>al picker's [Reload All] / [Regenerate] entries: a factually wrong one-line description, an absent Command Details preview for both, and an undecided redundancy question.

EDIT TARGET: lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**. This is nvim-config Lua UI code, NOT agent-system/extensions/**; nothing here touches the deployed .claude/ tree.

=== VERIFIED CURRENT BEHAVIOUR (read from source, not inferred) ===

The two entries are DIFFERENT operations, and both act on the CURRENT REPO ONLY (cwd):

[Reload All] (picker/init.lua:159-286) opens a vim.ui.select submenu with four choices --
"Reload All", "Unload All", "Step Through", "Cancel". The "Reload All" choice calls
exts.resync_all(), whose own doc comment at shared/extensions/init.lua:895-898 states: "Never
unloads: each extension is re-loaded in place via manager.load(..., {force = true}), so there is
no destructive intermediate 'everything unloaded' state." It force-resyncs every CURRENTLY LOADED
extension in Kahn's-algorithm dependency order. Non-destructive. No confirmation prompt.
("Step Through" is currently a no-op that just reopens the picker.)

[Regenerate] (picker/init.lua:110-156) calls exts.wipe({project_dir = vim.fn.getcwd()}), which
runs vim.fn.delete(target_dir, "rf") at shared/extensions/init.lua:1253 -- snapshot ->
rm -rf base_dir -> regenerate from the surviving project-root extension manifest -> restore
settings.local.json and .syncprotect-listed paths -> clear staging. Destructive. Confirmation
required.

=== DEFECT 1: THE [Reload All] ONE-LINER DESCRIBES [Regenerate], NOT ITSELF ===

display/entries.lua:980-982 renders [Reload All] with the trailing text:

    "Wipe and reload all loaded extensions"

It does not wipe. resync_all never unloads and never deletes. The word "Wipe" belongs to
[Regenerate], whose own one-liner at entries.lua:995-997 ("Wipe and rebuild from the extension
manifest") is accurate. So the picker currently presents two adjacent entries whose visible
descriptions both begin "Wipe and ...", one of which is false -- which is precisely the confusion
that motivated this task: an operator reaching for a rebuild picked [Reload All] on the strength
of that line.

Note the contradiction is already internal to the codebase: display/previewer.lua:129-130
describes the same entry correctly as "Force-resyncs every currently loaded extension in
dependency order (non-destructive)." Two descriptions of one entry disagree.

=== DEFECT 2: NEITHER ENTRY HAS A Command Details PREVIEW ===

Both entries are created with entry_type = "special" plus a boolean flag (is_reload_all,
is_regenerate) at entries.lua:974-999. The previewer's define_preview dispatch chain
(previewer.lua:628-661) branches on is_heading, is_help, and then eleven entry_type values --
skill, hook_event, lib, script, test, template, doc, command, extension, agent, root_file. There
is NO branch for is_reload_all, is_regenerate, or entry_type == "special". Both therefore fall to
the terminal else at previewer.lua:658-659, which writes the single line "Unknown entry type"
into the "Command Details" pane.

So the pane is not blank -- it renders a developer-facing error string for two entries that are
working as designed. The real documentation for both operations exists, but it is buried inside
preview_help (previewer.lua:129-135), reachable only by selecting the separate [Keyboard
Shortcuts] entry.

DECIDE, do not assume: whether to add a dedicated preview_special branch keyed on the two boolean
flags, or to give special entries a shared preview keyed on entry_type == "special" that reads a
per-entry description field. Either way, the terminal else branch should stop being reachable for
entries the picker itself ships -- consider whether "Unknown entry type" is the right fallback at
all, or whether it should name the offending entry so the next gap is diagnosable.

=== DEFECT 3: THE REDUNDANCY QUESTION, UNDECIDED ===

There is genuine partial overlap: [Regenerate]'s wipe-and-rebuild reloads the same extension set
[Reload All] resyncs, so it subsumes the OUTCOME while differing in method, risk, and guarantees.
Whether that justifies two entries is a real design call, not an obvious yes or no. Weigh at
least: (a) keep both, with corrected descriptions that make the destructive/non-destructive
distinction the FIRST thing each line says; (b) collapse [Regenerate] into the [Reload All]
submenu as a fourth, confirmation-gated choice alongside Unload All, giving one entry point for
all bulk extension operations; (c) keep both but rename them so neither reads as a synonym of the
other. Record the ruling and its reasoning.

While deciding (b), note the [Reload All] submenu already contains a dead choice: "Step Through"
(init.lua:180-185) does nothing but reopen the picker. Decide its disposition too -- implement or
remove; do not leave a menu item that silently no-ops.

=== A CORRECTION TO THE OPERATOR'S MENTAL MODEL, WORTH RECORDING IN THE PREVIEW TEXT ===

[Regenerate] is sometimes remembered as "run Reload All across every repo that has loaded the
agent system, preserving each repo's own loaded extension set". It does NOT do that, and never
has -- it is single-repo, scoped to vim.fn.getcwd(), exactly like [Reload All].

That cross-repo capability is a DIFFERENT, already-filed, not-yet-started piece of work: the
task titled "Implement <leader>al repo registration and 'Global Update' action" describes
registering repos that <leader>al loads extensions into, and adding a 'Global Update' entry
"similar to 'Reload All'" that reloads all extensions already loaded in each registered repo.
Coordinate with it rather than implementing cross-repo behaviour here; this task's job is to make
the two EXISTING single-repo entries honest and self-documenting. Whichever of the two lands
second should make sure all three entries read as a coherent set.

=== ACCEPTANCE ===

- [Reload All]'s visible one-liner no longer claims it wipes, and states its non-destructive
  force-resync nature; [Regenerate]'s continues to state its destructive nature. The two lines are
  distinguishable at a glance.
- Selecting either entry renders real content in the "Command Details" pane -- what it does, what
  it touches, whether it is destructive, whether it prompts -- and "Unknown entry type" is no
  longer reachable for any entry the picker ships.
- The entries.lua one-liner and the previewer text for a given entry agree with each other and
  with the implementation; a check or comment records that they must be kept in sync.
- The redundancy ruling is recorded with reasoning, and "Step Through" is either implemented or
  removed.
- Verified by opening <leader>al and selecting each entry, not by reading the diff alone.
