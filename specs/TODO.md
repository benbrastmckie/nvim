---
next_project_number: 356
---

# TODO

## Task Order

*Updated 2026-10-07. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,251,271,272,280,284,295,296,299,302,306,311,318,319,336,338,342,345,347,349,351 | -- | core-agent-system, extensions, neovim, ... |
| 2 | 29,170,273,275,281,303,335,344,350,352,354,355 | 22,251,271,272,280,284,311,345,349,351 | core-agent-system, extensions, orchestrator |
| 3 | 274,282,304,353 | 273,275,281,284,302,344,352 | core-agent-system, extensions, orchestrator |
| 4 | 312,328 | 170,282,303,304,318,344 | core-agent-system, orchestrator |
| 5 | 313 | 306,328,344 | core-agent-system |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

251 [NOT STARTED] — Context-corpus reachability probe (filename, directory,...
  └─ 170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state...
    └─ 328 [NOT STARTED] — Systematic top-to-bottom efficiency refactor of the shell...
      └─ 313 [NOT STARTED] — Advisory lint for hand-authored /orchestrate batch proposals...
280 [NOT STARTED] — Forbid record-versioning language in deliverables: the rule,...
  └─ 281 [NOT STARTED] — Repo-wide record-versioning lint with a blocking/advisory...
    └─ 282 [NOT STARTED] — Write-time PreToolUse hook blocking record-versioning...
284 [NOT STARTED] — Exempt a task’s own directory from the postflight filescope...
  └─ 335 [NOT STARTED] — Promote the modifiedfiles-vs-filescope excursion advisory...
306 [NOT STARTED] — Make ROADMAP.md a generated artifact: extend the format into...
  └─ 313 [NOT STARTED] — Advisory lint for hand-authored /orchestrate batch proposals... (see above)
318 [NOT STARTED] — Wire lint-directory-pathspec-boundary.sh into...
  └─ 328 [NOT STARTED] — Systematic top-to-bottom efficiency refactor of the shell... (see above)
336 [PLANNED] — Rule on the in-dispatch phase-commit staging surface: fifteen...
338 [NOT STARTED] — SOURCE STORE IS THE EDIT TARGET:...
352 [NOT STARTED] — Fix validate-artifact.sh's SKILLVALIDATEFIXES counters, which...
354 [NOT STARTED] — Rule on whether the local-gate backgrounding prohibition must...

### Extensions

342 [HOLD] — Refactor the books extension's context corpus against the...
349 [NOT STARTED] — Add an /approve command to the agent system so a...
  └─ 350 [NOT STARTED] — Offer the owner the review path when a books task reaches a...
29 [NOT STARTED] — Generate .mcp.json from extension manifests, then register...
353 [NOT STARTED] — Resolve the two red typst lint suites:...

### Neovim

22 [NOT STARTED] — Freeze .opencode: silence fragment validation spam and record...
295 [NOT STARTED] — Add desc field to 44 keymap.set calls missing documentation
296 [NOT STARTED] — Repo hygiene: remove stale init.lua.backup, regenerate...

### Orchestrator

271 [NOT STARTED] — Finish the parenttask edge: declare it in the schema,...
  └─ 273 [NOT STARTED] — Three-channel orchestration conclusion stage with per-channel...
    └─ 274 [NOT STARTED] — Next-admissible-batch suggestion and...
    └─ 304 [NOT STARTED] — Stop one out-of-repository pathspec entry from aborting...
  └─ 303 [NOT STARTED] — Make validate-state.sh resolve its omitted-argument...
272 [NOT STARTED] — Honest session liveness for concurrent same-repo batches:...
  └─ 275 [NOT STARTED] — Per-repo orchestration queue: registered, live, archived on...
    └─ 274 [NOT STARTED] — Next-admissible-batch suggestion and... (see above)
299 [NOT STARTED] — Guarantee detection of in-place plan revision concurrent with...
302 [NOT STARTED] — Pass --task at commit-staging sites to engage the...
  └─ 304 [NOT STARTED] — Stop one out-of-repository pathspec entry from aborting... (see above)
311 [NOT STARTED] — Replace static build-heavy family membership with a measured...
  └─ 344 [NOT STARTED] — Carry the batching-by-default doctrine to the point of use,...
    └─ 274 [NOT STARTED] — Next-admissible-batch suggestion and... (see above)
    └─ 312 [NOT STARTED] — Backlog reconciliation as a required task-creation component:...
319 [NOT STARTED] — Surface cross-task claim invalidation when a research...
345 [NOT STARTED] — Make the no-op spin that two existing wait documents and an...
347 [NOT STARTED] — PreToolUse Bash hook blocking self-matching process-name...
351 [NOT STARTED] — Repair the IDENTICAL DISPATCH HALT mechanism in...
  └─ 355 [NOT STARTED] — Close the gap that lets a new test script reach COMPLETED...

## Tasks

### 355. Close the gap that lets a new test script reach COMPLETED without its manifest.json provides.scripts registration
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 351

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere in specs/**.

GOAL. Adding a new scripts/tests/test-*.sh requires a hand-written entry in its extension's manifest.json provides.scripts array. Nothing surfaces that requirement at authoring time, and -- more seriously -- a task can reach COMPLETED with the entry missing, leaving check-extension-docs.sh failing for everyone afterwards. Make the requirement either automatic or caught before completion.

PROVENANCE. Observed twice in one batch on 2026-10-06, which is what makes it a pattern rather than a slip.
  - Task 300 hit it and self-corrected: check-extension-docs.sh failed on its first redeploy, the implementer diagnosed the missing line, added it, and recorded it as an unanticipated plan deviation plus a memory candidate. Its own note records the asymmetry that caused the surprise: index-entries.json uses a wholesale-directory convention, so authors reasonably expect manifest.json to behave the same way, and it does not.
  - Task 343 hit it and did NOT self-correct. Its new test-stall-reprompt-wiring.sh landed unregistered and the task was marked COMPLETED. check-extension-docs.sh then failed with exit 1 on every deploy: 'FAIL: script file on disk NOT in provides.scripts: scripts/tests/test-stall-reprompt-wiring.sh'. Task 300's implementer observed it, correctly logged it as a foreign defect, and correctly left it alone as outside its own file_scope. It was fixed afterwards by hand with the one missing line, verified green, and committed separately.

=== WHY TASK 343 ESCAPED AND TASK 300 DID NOT ===

This is the part worth investigating, because the difference is the actual defect.

Task 300 redeployed DURING its implementation, so check-extension-docs.sh ran against its own new file and failed loudly while the agent was still working.

Task 343's postflight was REFUSED by the completion-deploy gate (exit 6: modified_files overlap agent-system/extensions/** and the deploy is stale). That refusal is correct and by design -- the task stayed at implementing and the next cycle's Inter-Cycle Redeploy Checkpoint deployed and auto-reconciled it to COMPLETED. But the reconcile path evidently did not re-run, or did not fail on, the check that would have caught the missing registration. The deploy itself reported RESULT=landed_verify_skipped with verification SUPPRESSED by --skip-verify, and the checkpoint's own independent snapshot compared pre/post finding COUNTS (pre=11 post=2 new=0) rather than gating on this specific failure.

SO THE SUSPECTED MECHANISM IS: a task whose completion arrives via the post-deploy reconcile path gets less verification than one that redeploys mid-implementation. CONFIRM OR REFUTE THIS BEFORE FIXING -- if it is right, the gap is wider than the manifest case and affects any check that only runs at deploy-verify time.

=== THE THREE CANDIDATE FIXES, NOT MUTUALLY EXCLUSIVE ===

(a) MAKE IT AUTOMATIC. Have the manifest's script list derive from the directory contents the way index-entries.json already does, or add a --write repair mode (generate-context-line-counts.sh --write is the in-repo precedent for exactly this shape). This removes the authoring burden entirely and is the most durable fix. Weigh it against whatever reason the explicit list exists -- find out whether provides.scripts is deliberately curated (e.g. it controls what gets deployed) before flattening it, because if it is, (a) is wrong.

(b) CATCH IT AT COMPLETION. Ensure the post-deploy reconcile path runs the same check a mid-implementation redeploy does, so a missing registration blocks completion rather than surfacing to the next person. This is the narrower fix and addresses the escape rather than the authoring burden.

(c) DOCUMENT THE ASYMMETRY. At minimum, state in the extension-authoring guidance that a new scripts/tests/test-*.sh needs an explicit provides.scripts line and that this differs from index-entries.json's directory convention. Cheapest, least durable; acceptable only alongside (a) or (b), not instead of them.

=== ALSO SETTLE ===

- Whether other provides.* arrays (agents, skills, commands, context) have the same escape. A new agent file or skill is at least as likely to be added as a test script.
- Whether the pre/post finding-COUNT comparison in the redeploy checkpoint is the right gate shape at all. It passed a batch that introduced a brand-new hard failure, because the count happened to drop from 11 to 2 for unrelated reasons. A count-based comparison cannot distinguish 'fixed nine old problems' from 'introduced a new one while fixing ten' -- consider whether it should compare finding IDENTITIES rather than counts. This may be the most consequential finding in this task; do not skip it because the manifest case is easier.

=== ACCEPTANCE ===

- The report confirms or refutes the suspected mechanism (reconcile path verifies less than mid-implementation redeploy), with evidence.
- A missing provides.scripts registration can no longer reach COMPLETED undetected -- by automation, by a completion-time check, or both.
- A fixture pins whichever mechanism is chosen: adding an unregistered test script must fail the chosen gate.
- The report states whether the other provides.* arrays share the escape, and whether the redeploy checkpoint's count-based comparison should become identity-based.
- Redeployed. Shellcheck clean per context/standards/shell-strict-mode.md.

---

### 354. Rule on whether the local-gate backgrounding prohibition must also cover waiting on a dispatched subagent
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 345

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere in specs/**.

GOAL. Decide whether general-implementation-agent.md's Local Long-Running Command Discipline needs to cover a third case it currently does not name: an agent that dispatches a subagent and then waits on it. Implement the ruling, or record the reasoned decision not to.

PROVENANCE. Explicitly deferred by task 343's implementation on 2026-10-06. That task made the local-gate mandate mechanism-mandating and added a three-way deadline fork, and its implementer confirmed by diff that it kept the mandate scoped exactly as its plan specified -- 'a local verification, gate, build, or test process' -- with no mention of subagent or fork dispatch waits anywhere. It flagged the gap as a real one belonging to a distinct defect class and declined to widen scope silently. This task is that follow-up.

=== THE QUESTION ===

general-implementation-agent.md now carries two sibling prohibitions:
  - the CI/remote case (pre-existing)
  - the LOCAL GATE case (added by task 343): backgrounding a local gate stays permitted but only via bounded-build-waiter.md's single foreground-blocking idiom; Bash(run_in_background: true) and arming a Monitor are forbidden for a local gate.

NEITHER COVERS DISPATCHING A SUBAGENT AND WAITING ON IT. A dispatched subagent is not a local gate (it is not a verification, build or test process on this host) and not the CI case. So the mandate is silent on it.

=== IS THERE ACTUALLY A HAZARD? BE HONEST ABOUT THE EVIDENCE ===

DO NOT TREAT THE FOLLOWING AS A CONFIRMED STRANDING. During the same run, a research dispatch was initially misdiagnosed by the orchestrator as stranded for 17+ minutes on a backgrounded fork probe. That diagnosis was WRONG and was retracted: file mtimes showed the agent was actively rewriting its report throughout the window, and the orchestrator had been waiting on a handoff file that the research phase never writes in any mode. The agent finished normally. postflight's stall_suspected returned false, correctly, because there was no stall.

WHAT DID HAPPEN, AND IS A REAL MEASURED FINDING, IS DIFFERENT: a loosely-scoped subagent_type:'fork' probe inherited its parent's entire task mandate and autonomously completed a whole research deliverable -- report, metadata, issue-log entries, and a premature 'complete' message to the orchestrator -- instead of returning the single probe result it was asked for. That is a fork PROMPT-SCOPING hazard and it belongs to a different task, which already addressed it with a capped addendum to core/docs/fork-patterns.md.

SO THE HONEST STARTING POSITION IS: the gap in the mandate's wording is real and verifiable by reading the file. Whether it corresponds to an actual stranding hazard is NOT established, and the one incident that looked like evidence for it was a misdiagnosis. Establish whether the hazard is real before writing a prohibition for it. A prohibition justified by a retracted observation would be worse than the gap.

=== ARGUMENTS BOTH WAYS, TO BE WEIGHED NOT ASSUMED ===

FOR EXTENDING THE MANDATE: a dispatched subagent is unbounded from the caller's point of view in exactly the way a backgrounded local gate is -- the caller has no deadline, no result, and no way to distinguish 'still working' from 'never returning'. The three-way deadline fork task 343 added (writer-alive, writer-dead-with-result, enumerated exclusion) would apply almost verbatim.

AGAINST: dispatching a subagent and awaiting its result is the normal, intended delegation primitive. A blanket prohibition would forbid ordinary nested delegation, which no other rule forbids and which several skills rely on. The failure mode is also differently shaped: a subagent reports back through its own channel, so 'waiting' is not the same operation as polling a log file.

A MIDDLE RULING IS AVAILABLE AND MAY BE THE RIGHT ONE: permit awaiting a dispatched subagent, but require the same bounded discipline -- an explicit deadline and a defined action on reaching it -- rather than an open-ended wait. That extends the discipline without forbidding delegation.

=== ALSO SETTLE ===

- Whether the correct home is general-implementation-agent.md's own mandate, bounded-build-waiter.md's idiom, or a separate note. If the ruling is 'no change', say so and record it where a future reader will find it rather than leaving the file silent.
- Whether an orchestrator-side detector is even possible for this shape. Note that stall_suspected's trigger is deliberately NOT widened -- task 343 recorded that non-widening as an explicit ruling, on the grounds that a stale dispatch_seq cannot distinguish an abandoned wrap-up from an instantly-dead dispatch. Do not reopen that without new evidence.
- The correct probe for 'is this agent alive or stranded' is worth documenting as a side-benefit, since the orchestrator got it wrong in the originating incident: artifact mtimes and live child processes discriminate; absence of a handoff file does not, because the research phase never writes one.

=== ACCEPTANCE ===

- A recorded ruling, either implemented or reasoned-declined, naming which of the three positions above was taken and why.
- If the mandate is extended, the wording distinguishes awaiting a delegated subagent from backgrounding a local gate, and does not forbid ordinary nested delegation.
- The 'how to tell a working agent from a stranded one' probe guidance is documented somewhere discoverable, with the handoff-absence false signal named explicitly.
- No change to stall_suspected's trigger predicate unless new evidence is produced and stated.
- Redeployed if any deployed file changed.

---

### 353. Resolve the two red typst lint suites: chapter-quality-check.sh's stderr-into-JSON corruption, and typst-element-lint.sh's presence-versus-density check overlap
- **Status**: [NOT STARTED]
- **Task Type**: typst
- **Topic**: extensions
- **Dependencies**: Task 352

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/typst/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere in specs/**.

GOAL. Two independent red suites in the typst extension. They are batched into one task because they share an extension and a redeploy, and touch DISJOINT scripts -- there is no territory conflict between them and no dependency edge is needed. Item B requires a design ruling and should not be rushed to match item A's mechanical shape.

PROVENANCE. Item A was already registered in agent-system/extensions/core/scripts/tests/known-failures.txt as a real-defect row with owner=needs-owner. Item B was found on 2026-10-06 by a full run-all.sh sweep, verified red against a clean fully-committed tree, and registered at that time with owner=needs-owner. That file's header states a needs-owner row is a known gap rather than an accepted steady state. This task is the owner of both rows.

=== ITEM A: chapter-quality-check.sh CORRUPTS ITS OWN JSON INPUT ===

SUITE: test-lint-json-channel-discipline.sh -- 10 of 12 assertions pass, 2 fail, against the real corpus.

THE DEFECT. agent-system/extensions/typst/scripts/chapter-quality-check.sh captures a collaborator process's output with `2>&1` and then consumes that captured stream as JSON/NDJSON. Merging stderr into stdout means any diagnostic, warning or progress line the collaborator writes to stderr is spliced into the payload, so the parse either fails or -- worse -- silently mis-parses. The suite reports 1 live VIOLATION against the real corpus, so this is reachable today, not theoretical.

THIS IS A MECHANICAL FIX with a clear direction: separate the channels. Capture stdout alone for the payload and route stderr somewhere it can still be seen (a file, or passed through to the caller's stderr) rather than discarding it. Do NOT fix this by discarding stderr -- that trades a corruption bug for a silent-diagnostic bug, which is the same class of defect the books observer work was about.

ALSO SETTLE FOR ITEM A: whether any sibling script in the typst extension uses the same `2>&1`-then-parse-as-JSON shape. The suite is named for channel discipline generally, so sweep for the pattern and report siblings even if you leave them unchanged.

=== ITEM B: WHICH CHECK OWNS 'SOME REMARKS, ZERO THEOREMS'? (needs a ruling, not a patch) ===

SUITE: test-typst-element-lint.sh -- 36 of 37 assertions pass, 1 fails: 'case-h2 (2 remarks / 0 theorems, floor holds): output unexpectedly contains [WARN]'.

BOTH CHECKS ARE BEHAVING AS DOCUMENTED, WHICH IS WHY THIS NEEDS A DECISION RATHER THAN A BUGFIX. typst-element-lint.sh emits three warning kinds, distinguished internally as `items`, `density` and `presence`:
  - CHECK 3 (density) warns when #remark occurrences exceed theorem-family elements, guarded by DENSITY_FLOOR=3. Its own header rationale states the floor exists 'so a file with few remarks and zero theorem-family elements does not warn merely because the ratio is undefined/trivial.'
  - CHECK 4 (presence) warns when a file has zero theorem-family elements and is outside the introduction/appendix-/glossary exemption class. Its message is explicitly advisory and says 'not necessarily wrong (a genuinely narrative file may legitimately have none)'.

Fixture case-h2 is '2 remarks / 0 theorem-family elements'. The test's stated intent is that this shape is SILENT because the density floor of 3 is not met. Check 3 is indeed silent. Check 4 then warns anyway, and the assertion -- which forbids any [WARN] at all -- fails.

SO THE TENSION IS REAL: check 3's floor was deliberately designed to keep exactly this shape quiet, and check 4 overrides that intent from a different direction. At least three defensible resolutions exist, and the right one is not obvious:
  (i) the assertion is too broad -- narrow it to forbid only the density warning, accepting that presence legitimately fires here. Note the two messages are hard to discriminate by rendered text (both contain the string 'theorem-family'), so this likely needs a machine-readable discriminator rather than a substring match.
  (ii) check 4 should not fire on a file that contains SOME semantic elements (remarks) -- i.e. presence should mean 'no semantic vocabulary at all', not 'no theorem-family vocabulary'.
  (iii) the fixture is wrong and case-h2 should carry a theorem so it isolates the density floor as intended, with a separate fixture covering the presence case.

Rule on which, record why, and only then change the assertion, the check, or the fixture. Do not change more than one of the three without saying so. Consider whether semantic-element-usage.md (the doc whose stated signal check 3 encodes) constrains the answer.

=== ACCEPTANCE ===

- test-lint-json-channel-discipline.sh passes 12/12, with stdout and stderr separated and stderr still observable (not discarded).
- test-typst-element-lint.sh passes 37/37, with the chosen resolution for item B recorded and justified in the report.
- The report names whether the `2>&1`-then-parse shape appears in any sibling typst script.
- Both known-failures.txt rows (test-lint-json-channel-discipline.sh, test-typst-element-lint.sh) are REMOVED once their suites are green.
- Redeployed. Shellcheck clean per context/standards/shell-strict-mode.md.

---

### 352. Fix validate-artifact.sh's `SKILL_VALIDATE_FIXES` counters, which neither accumulate across multi-file aggregation nor reset between calls
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 351

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere in specs/**.

GOAL. validate-artifact.sh's repair-reporting globals are wrong in two opposite directions at once: they fail to accumulate when they should, and they persist when they should be cleared. Fix both, and pin each with a fixture.

PROVENANCE. Already registered in agent-system/extensions/core/scripts/tests/known-failures.txt as a real-defect row with owner=needs-owner. That file's own header states a needs-owner row is a known gap rather than an accepted steady state, and that a follow-up task should be spawned to fix or formally accept each one. This task is that owner. Re-confirmed red on 2026-10-06: 18 of 19 assertions pass, 1 fails.

=== THE DEFECT ===

SUITE: agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh.

TWO DISTINCT FAULTS IN THE SAME PAIR OF GLOBALS, SKILL_VALIDATE_FIXES and SKILL_VALIDATE_FIXED_FILES:

(1) NO ACCUMULATION ACROSS MULTI-FILE AGGREGATION. When validate-artifact.sh processes more than one file in a single invocation, the counters reflect only part of the work. The known-failures row records the observed shape as 'fixes=0 errors=1' where a repair did occur -- so a caller reading the counters to decide whether to report a repair sees nothing.

(2) NO RESET BETWEEN CALLS. Stale values from a previous invocation are visible to the next one, detected across calls. Because these are shell globals in a sourced library rather than locals, a second call in the same shell inherits the first call's state.

The two faults mask each other in opposite directions, which is why a single-file, single-call test passes: under-reporting within a call and over-reporting across calls can cancel out in exactly the cheap test shape that exists today.

=== WHY IT MATTERS ===

These counters drive gate-out repair REPORTING. An under-count means a genuine auto-repair is performed and then not reported, so an operator reviewing a gate-out believes the artifact was clean when it was actually fixed in place. An over-count means a repair is reported that this invocation did not perform, which is worse: it attributes a change to the wrong call. Both failure modes corrupt the audit trail rather than breaking a build, which is why neither has surfaced as an obvious outage.

Note the scope claim in the known-failures row is narrower than the suite name suggests: confirm by reading whether the defect lives in validate-artifact.sh alone or also in skill-base.sh / command-gate-out.sh, which a concurrent full-gate sweep named as the suite's subjects-under-test. Establish the real boundary before editing.

=== ALSO SETTLE ===

- Whether these should remain shell globals at all. If a caller needs per-invocation repair facts, an explicit reset at entry plus accumulation at each repair site is the minimum; returning the values rather than exporting them would remove the cross-call hazard structurally. Prefer the structural fix and state why if you do not take it.
- Whether any other sourced-library global in the same file has the same reset-at-entry gap. A single missing reset is usually a pattern, not an isolated slip -- sweep for siblings and report what you find even if you do not change them.
- Whether the existing suite's cases 4 and 6 assert the right thing. They currently detect the bug, so they are not stale; confirm they would still fail against a partial fix that addressed only one of the two directions.

=== ACCEPTANCE ===

- test-gate-out-repair-reporting.sh passes 19/19.
- A fixture pins the multi-file accumulation case: N files repaired in one invocation reports N, not a partial count.
- A separate fixture pins the cross-call reset case: a second invocation in the same shell reports only its own repairs.
- The report names whether the defect was confined to validate-artifact.sh or extended to skill-base.sh / command-gate-out.sh, with evidence.
- known-failures.txt's test-gate-out-repair-reporting.sh row is REMOVED once the suite is green.
- Redeployed. Shellcheck clean per context/standards/shell-strict-mode.md.

---

### 351. Repair the IDENTICAL DISPATCH HALT mechanism in orchestrate-cycle-plan.sh, which is implemented but never fires
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md); they are permitted in this description and elsewhere in specs/**.

GOAL. The IDENTICAL DISPATCH HALT safety mechanism is present in orchestrate-cycle-plan.sh but does not trigger. Find out why and repair it, or -- if the behaviour the tests assert is no longer the intended design -- rule on that explicitly and correct the tests and the architecture doc instead.

PROVENANCE. Found on 2026-10-06 by a full run-all.sh sweep during an unrelated implementation dispatch. The suite was NOT registered in known-failures.txt at the time; it has since been registered with owner=needs-owner, and this task is that owner.

=== THE DEFECT ===

SUITE: agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh -- 335 of 349 assertions pass, 14 fail. All 14 failures are in Group 28 and Group 29 (arms B, C and D), and all concern the same mechanism.

THE MECHANISM IS PRESENT, NOT MISSING. The phrase IDENTICAL DISPATCH HALT appears in orchestrate-cycle-plan.sh (10 occurrences), in the suite (6), and in docs/architecture/orchestrate-state-machine.md. `git log -S'IDENTICAL DISPATCH HALT'` shows it landed on the script with the commit 'task 259 phase 2: halt the run for a task after N=2 consecutive identical dispatches', and Group 29's reproduction tests were added later by 'task 266 phase 5'. So this is a FUNCTIONAL REGRESSION in live code, not a test written ahead of an unimplemented feature. Establish when it stopped firing -- git bisect over the suite is the obvious tool.

OBSERVED BEHAVIOUR ON A SECOND IDENTICAL DISPATCH. Every one of these should be prevented by the halt and is not:
  - the dispatch is issued anyway (dispatch[] carries the row; blocked[] is empty)
  - no blocked[] row and no reason text is produced
  - the expected stderr notice never appears; instead the ordinary 'OK: task NNNN state.json already at ...' line is emitted
  - the composed .dispatch/N.md file is NOT backed out and still exists
  - the task lock is still held after what should have been a halt back-out
  - the durable dispatch_seq_counter advances (expected to stay at 1, observed 2)
  - cycle_counts advances (expected to stay at 1, observed 2)
  - a third cycle does not keep the candidate excluded either

Arm C additionally expects a streak-freeze notice that never appears, and Arm D expects the halt with no deploy_pending marker present.

VERIFIED INDEPENDENT OF THE CONCURRENT WORKING-TREE CHANGE. At discovery time orchestrate-cycle-plan.sh carried an uncommitted, foreign, in-flight fix to the H1 marker/handoff-mismatch block (replacing the `x=$(grep -c ... || echo 0)` idiom, which emits two lines, with `x=$(grep -c ...) || x=0`). That change touches a different code path from the halt and does not explain these failures. Do not assume it is still uncommitted when this task is picked up -- re-check, and if it is still pending, resolve its ownership before editing the same file.

=== WHY IT MATTERS ===

The halt is the guard against an orchestrate run burning its cycle budget re-dispatching the same unchanged work. With it inert, a task that makes no progress consumes cycles silently until MAX_CYCLES, and the per-task loop guard, the dispatch_seq counter and the task lock are all left in states the design says they should never reach. The seven distinct back-out steps listed above failing together suggests one early guard or predicate short-circuiting, not seven separate bugs.

=== ALSO SETTLE ===

- Whether the halt's trigger predicate, its back-out block, or the call site that should invoke it is the broken part. Name which, with evidence.
- Whether docs/architecture/orchestrate-state-machine.md's description of the halt still matches the intended design. It was touched recently by the IDENTICAL-DISPATCH-HALT non-conflation note; confirm that note did not change the contract the tests assert.
- Whether the suite's Group 28/29 fixtures still construct a genuinely identical dispatch. If the definition of 'identical' legitimately changed, the fixtures may be stale rather than the script broken -- rule on this before changing either.

=== ACCEPTANCE ===

- test-orchestrate-cycle-plan.sh passes 349/349, or any remaining failure is a reasoned, evidenced exclusion naming why the asserted behaviour is no longer intended.
- The root cause is named in the report: which predicate or call site failed, and when it regressed.
- A regression fixture pins the specific failure mode found, so the halt cannot silently go inert again.
- known-failures.txt's test-orchestrate-cycle-plan.sh row is REMOVED if the suite goes green, or its reason and owner are updated if a reasoned exclusion remains.
- Redeployed. Shellcheck clean per context/standards/shell-strict-mode.md.

---

### 350. Offer owner review when approval needed
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 349

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

### 349. Add approve command owner labeled approvals
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 300

**Description**: Add an /approve command to the agent system so a specification approval is given by answering one interactive question instead of a terminal round-trip

--- WHY ---

Approving specifications currently costs the owner a context switch out of the agent session into a terminal, because approve.sh's person path reads its confirmation from /dev/tty and an agent has no controlling terminal. On 2026-10-07 that friction was hit directly: nineteen specifications needed re-approval after the namespace move, the agent prepared the entire review but could not complete it, and the work was finished only by the owner instructing that an agent record them instead. The owner's stated preference is a command in the agent system that raises an interactive question and records the answer.

This task lives in the agent-system source store (agent-system/extensions/ in THIS repository), never in a consumer repository's .claude/ tree, which is a regenerated deploy artifact.

--- CROSS-REPOSITORY PREREQUISITE ---

The approval mechanism this command drives lives in the Logos/Verification repository, in the task
named `owner_labeled_agent_assisted_approvals` (cited by slug, because task numbers do not carry
across repositories --- this repository's own number 233 is an unrelated archived task). Until that
task lands there is no honest value for this command to write. Check its status in
~/Projects/Logos/Verification/specs/state.json before dispatching.

--- DEPENDS ON THE OWNER-LABELED CONFIRMATION CHANNEL ---

The repository owner ruled 2026-10-07 that approvals are **agent-assisted but owner-labeled**: the person who answers the prompt is the approver of record, and the agent is recorded as an assistant. The companion repository task implements that --- a `by: person` record reachable without a controlling terminal, with the agent named in an `assisted_by` field and the confirmation channel distinguished from the terminal one.

This command must record the OWNER as the approver and itself as the assistant. Until the companion task lands there is no honest value to write, because today's `by: agent` attributes the judgement to the wrong party. Do NOT ship this command recording itself as the approver.

--- SETTLED CONSTRAINT: AskUserQuestion IS NOT REACHABLE FROM A DISPATCHED SUBAGENT ---

This is no longer an open prerequisite. The in-repository investigation named
`askuserquestion_unreachable_in_subagents` is COMPLETE and the finding is SETTLED: `AskUserQuestion`
is NOT reachable from a dispatched subagent on this harness --- the tool is categorically withheld
from every `Agent`-tool dispatch of a named `subagent_type`.

Therefore, as a decided constraint rather than something to re-measure: **/approve MUST be a
direct-execution skill run in the root session, never a dispatched agent.** If any part of this
command's flow is delegated to a subagent, the prompt the command exists to raise cannot be raised
at all. Build against this constraint; do not re-litigate it, and do not design around an assumed
inheritance of the tool into subagents.

The dependency on that investigation is retained in dependencies[] because it is SATISFIED, not
because it is still pending.

--- SCOPE ---

In scope.
(1) Decide where the command lives and record the reason. The books extension already owns /certify and /book, which makes it the nearest existing home, but the books extension's own charter explicitly disclaims component certificates and owns the book metadata layer instead -- so a new small extension may be the correct answer rather than the convenient one. Rule on it before writing files.
(2) The command itself, which records the owner as approver and never itself. Flow: run the component's approve.sh --review for the requested scope; read the generated review; classify its diff the way a reviewer needs rather than dumping it -- separate the mechanical churn (metadata attributes, licence headers, blank lines, pure requalification) from anything that changes a declaration, and check at declaration level whether any claim was added, removed or restated; present that summary through AskUserQuestion; mark the decisions block from the answer; record with the owner as approver and this command as `assisted_by`, putting the question and the answer verbatim into the review file's Notes (which the companion task makes a precondition of writing the record at all).
(3) Per-item granularity. AskUserQuestion takes at most four options per question, so a nineteen-item cycle cannot be one option per item. Decide the shape: a single bulk approve/decline with an escape to per-item, or batching by module family. Record the choice; do not let the tool's option cap silently become a design.
(4) The refusal cases. The command must refuse to record when the review is stale against the tree, when the classification found a declaration-level change the summary did not surface to the person, and when AskUserQuestion is unavailable --- whether because no human is attached, or because of the settled subagent-reachability limit above. An autonomous dispatch must never answer this prompt on the owner's behalf. That last one is the whole point of the command and needs a test, not a comment.
(5) Generalisation. The command should take the component as an argument rather than hardcoding framed_channel, since the approval mechanism is per-component and other components may grow one.
(6) The review is a PERSISTED artifact, not a $TMPDIR throwaway. The generated review is a research-report-grade artifact the owner may reread, diff against a later cycle, or open while answering --- so it must live at a predictable, tracked path, not in a temp directory that vanishes with the shell. It lives under `specs/certificates/` in the CONSUMER repository (the repository being approved, e.g. Logos/Verification), because that is where the thing being approved lives. It must be keyed by BOTH task number AND instance number, because multiple approval cycles per task are expected and a later cycle must not overwrite the record of an earlier one.

    This task must RULE on that naming convention, and the ruling MUST explicitly cover the NO-TASK
    case. The live instance --- re-approving the nineteen stale framed_channel specifications --- has
    no task in state.json at all, so a task-number-only scheme cannot express it. A scheme that
    silently degrades (empty segment, literal "000", a collision between two taskless cycles) is not
    an answer. Record the no-task key explicitly; the no-task case MUST NOT be settled by accident
    as a side effect of whatever shape the task-keyed case happens to take.

    Note also that `specs/.gitignore` in the consumer repository is a MANAGED BLOCK --- it is
    regenerated, and broad patterns in it can swallow new subdirectories. `specs/certificates/`
    must therefore be DELIBERATELY TRACKED (an explicit negation or an explicit tracked-path entry
    in the managed block, decided and recorded), never left to be silently ignored.
(7) A SUMMARY CONTRACT for what the owner actually sees. Scope item (2) says "classify the diff", which has no notion of a recommendation or of how sure the agent is --- that gap is what this item closes. The summary presented to the owner must carry:
      - only the most essential points, not the full classified diff (the full artifact is at the
        path from (6) for anyone who wants it);
      - every discrepancy called out EXPLICITLY rather than averaged into a verdict --- if two
        specifications disagree, or a record disagrees with the tree, the owner is told so by name;
      - a RECOMMENDATION per item or per batch, and every recommendation carries a CONFIDENCE LEVEL.

    Rule on the confidence vocabulary, and keep it MECHANICAL rather than impressionistic --- a
    confidence level the agent assigns by feel is worse than none, because it launders a guess as a
    measurement. This repository already draws exactly the distinction needed: the
    measured-versus-INFERENCE evidence tiering used in books/lean/BookCert/Depends.lean and recorded
    as Decision 9 of docs/book-convention.md. FOLLOW THAT EXISTING PRECEDENT --- derive the
    confidence vocabulary from it and cite it --- rather than inventing a parallel scale that the
    repository then has to keep reconciled with it.
(8) STEP-THROUGH approval UX. The owner walks the items ONE AT A TIME rather than being handed a
    wall of nineteen. At ANY point in that walk, two escapes are available:
      - Escape 1: talk it over conversationally with the agent --- drop out of the structured prompt
        into ordinary discussion of the item at hand, then resume the walk.
      - Escape 2: open the artifact files DIRECTLY in the explorer and read them unmediated. This is
        precisely WHY the artifact must be persisted at a predictable path per (6); a $TMPDIR review
        makes this escape impossible.

    This item MUST BE RECONCILED with scope item (3), which weighs bulk-approve against per-item
    against AskUserQuestion's four-option cap. (3) and (8) are about the same interaction and MUST
    NOT be left to contradict each other: the ruling must be one coherent design covering both the
    option cap and the step-through walk with its escapes --- state how a step-through walk is
    expressed within the four-option-per-question limit, and how each escape is offered without
    consuming the options the decision itself needs.

Out of scope. Changing approve.sh or check-approvals.sh, which the companion repository task owns. Any approval policy question about which specifications deserve scrutiny.

CLOSED QUESTION --- do not reopen: the companion Verification task
`owner_labeled_agent_assisted_approvals` needs NO CHANGE for any of items (6), (7) or (8). The
review file's LOCATION is the CALLER's `--out` argument; it is not approve.sh's concern. The
persisted-artifact path, its naming convention, the summary contract and the step-through UX are
therefore entirely this task's business, decided on this side of the boundary and passed to
approve.sh as an argument. A later dispatch must not go add a path, a naming scheme or a summary
format to approve.sh on the theory that the companion task is implicated. It is not.

--- WHAT MUST NOT BE BUILT ---

A path that lets an agent approve without a person answering. The command's reason for existing is to make a person's decision cheap to give, not to make it optional. If AskUserQuestion cannot be reached, the command stops and reports; it does not fall back to recording as an agent.

--- ACCEPTANCE ---

- The placement ruling is recorded with its reason before any file is written.
- /approve <component> [--core-only|--aeneas] runs the review, presents a classified summary, asks the owner, and records the approval OWNER-LABELED with the agent as `assisted_by` and the question and answer in Notes.
- The command is implemented as a direct-execution skill in the root session; no part of the prompting flow is reached through a dispatched subagent.
- No path exists by which this command records itself as the approver.
- The per-item-granularity choice is recorded, and the AskUserQuestion option cap is handled deliberately rather than by truncation.
- Each refusal case has a test: stale review, unsurfaced declaration-level change, and no human attached.
- A dry-run or equivalent shows the full flow without recording.
- The review artifact is written under `specs/certificates/` in the consumer repository at a path keyed by task number AND instance number; a second approval cycle for the same task does not overwrite the first; the naming ruling is recorded and states the NO-TASK key explicitly.
- `specs/certificates/` is deliberately tracked against the managed `specs/.gitignore` block, and that decision is recorded.
- The owner-facing summary shows only essential points, names every discrepancy explicitly, and attaches a recommendation with a confidence level to each item or batch; the confidence vocabulary is derived from and cites the measured-versus-INFERENCE precedent (BookCert/Depends.lean, book-convention Decision 9).
- A single coherent interaction ruling covers BOTH the option cap of (3) and the step-through walk with both escapes of (8), with no contradiction between them; the conversational escape and the open-the-files escape are each reachable at any point in the walk.

---

### 347. PreToolUse Bash hook blocking self-matching process-name waiters, registered bare so exit 2 survives
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md). No task-number references in any
file landing under agent-system/** (rules/no-task-references-in-deliverables.md): cite by
filename, command or concept. Task numbers are permitted in this description and elsewhere in
specs/**.

GOAL. Turn bounded-build-waiter.md's Rule 2 ("never use ps | grep, pgrep -f, or any
process-name-matching test") into a BLOCKING PreToolUse Bash hook, plus its fixture test and its
settings.json registration. The rule already exists and already failed to bind. This task adds
teeth, NOT prose.

THE TASK FAILS IF ITS PRIMARY DELIVERABLE IS A NEW OR AMENDED PATTERN DOCUMENT.

=== MEASURED INCIDENT (do not re-derive; re-confirm only) ===

2026-10-06, Logos/Verification consumer repo, a dispatched lean-implementation-agent wrote this
twice:

  until ! pgrep -f 'distsys/check.sh' >/dev/null 2>&1; do sleep 20; done

pgrep -f matches full command lines, and the watcher's own `bash -c` argv contains the literal
pattern. pgrep excludes only ITSELF, not its parent shell -- so each watcher matched itself, and
with two running they also matched each other. One spun for 17 minutes on a gate process that had
already exited. Verified empirically at the time: `pgrep -af 'distsys/check.sh'` returned 6
matches, of which 2 were the watchers themselves. The orchestrator killed both by hand.

=== WHY DOCUMENTATION IS NOT THE FIX (verified in the source store during task creation) ===

Every one of these was live and reachable when the agent wrote the banned command:

(1) context/patterns/bounded-build-waiter.md line 35 documents this VERBATIM as Symptom 3, "The
    name-match self-match", and its worked example is itself a check.sh gate script.
(2) The same file's Rule 2 (lines 60-63) forbids `ps | grep`, `pgrep -f`, and "any
    process-name-matching test" by name, and explains the self-match mechanism.
(3) Its Rule 4 (line 68) is "One waiter per log."
(4) Its canonical idiom (line 74) is exactly the kill -0 form.
(5) extensions/lean/agents/lean-implementation-agent.md CITES that file.

So the prohibition was in the dispatched agent's own reference chain and it wrote the banned
command anyway. Documentation-as-prohibition has demonstrably failed for this command shape.

CORROBORATION THAT IT RECURS: bounded-build-waiter.md records three repositories hitting this in
three different shapes (one of them "roughly 13 minutes across five recurrences until an operator
killed the waiter by hand"). scripts/claude-refresh.sh already carries a reaper pass
(run_build_waiter_pass, line 1763) with a dedicated "Family B (legacy/name-match)" classifier at
line 1578 naming `until ! ps aux | grep` explicitly. CLEANUP tooling for this exact failure
already exists; PREVENTION does not. This task builds the prevention.

=== DELIVERABLES ===

(1) hooks/<name>.sh -- a PreToolUse hook, matcher "Bash", that BLOCKS a command conjoining a
    wait-loop construct with a name-matching liveness test.

    STRUCTURAL MODEL -- READ THIS CAREFULLY, THE OBVIOUS PRECEDENT IS THE WRONG ONE.
    The originating request named hooks/detect-noop-bash.sh as the model. That is correct for the
    MOTIVATION (a documented prohibition turned into a hook) and WRONG for the MECHANISM: that
    hook is PostToolUse, advisory-only, and exits 0 unconditionally, so copying it would produce
    a hook that cannot block anything. The MECHANISM precedent is hooks/guard-destructive-git.sh
    -- PreToolUse, matcher "Bash", blocks via exit code 2 + a stderr message, registered BARE,
    fails open. Its header (lines 26-31, and line 112) records why exit 2 + stderr and NOT
    `permissionDecision: deny`: deny is documented-buggy for allow-listed tool calls. Inherit
    that contract verbatim, and inherit FAIL OPEN as well -- any internal error must ALLOW the
    command, because a broken guard that blocks every Bash call in the repo is a worse outcome
    than no guard.

    NOTE, A LIVE DEMONSTRATION OF THE TARGET CONVENTION: during the creation of this task, an
    ordinary scratchpad write was blocked by hooks/validate-no-task-references.sh with exit 2
    plus an actionable stderr message naming the rule and offering the exemption path. That is
    precisely the enforcement shape this hook should follow -- a working, observed example of the
    convention rather than a described one. Read that hook alongside guard-destructive-git.sh.

    SHAPES THAT MUST BLOCK:
      - until ! pgrep -f ... ; do sleep ... ; done   (and the while/positive-test variant)
      - while pgrep -f ... ; do sleep ... ; done
      - until ! ps aux | grep ... ; do ... done
      - until ! ps -ef | grep ... ; do ... done
      - the [b]racket variant of the above. bounded-build-waiter.md is explicit that the bracket
        trick does NOT fix the self-match: it stops GREP matching itself, not the parent shell.
        A hook that treats the bracket form as safe reproduces the exact bug it exists to stop.

    REUSE THE ALREADY-VALIDATED PATTERN INVENTORY: claude-refresh.sh's Family B classifier
    (scripts/claude-refresh.sh, roughly lines 1578-1643) already enumerates these argv shapes and
    has been exercised against real process tables. Derive the hook's matcher from that inventory
    rather than inventing fresh regexes. RULE IN-TASK on whether the shapes belong in a shared
    library sourced by both consumers -- the validate-no-task-references.sh /
    scripts/lib/task-reference-patterns.sh split is the established precedent for a shared pattern
    library with two consumers. If a shared library is rejected, say why, and ensure the two
    inventories cannot silently drift apart.

    LOW FALSE-POSITIVE DESIGN IS A FIRM REQUIREMENT. The narrow CONJUNCTION (loop construct AND
    name-match liveness test) is what makes this mechanically safe to block. A bare `pgrep`, a
    bare `ps aux | grep`, or a name-match in a one-shot conditional OUTSIDE a wait loop MUST stay
    legal -- those are legitimate diagnostic uses and the orchestrator's own tooling performs
    them. A false positive here is worse than no hook.

    REJECTION MESSAGE must be actionable and must carry the canonical idiom INLINE, not merely a
    pointer to it:
      cmd >log 2>&1 & pid=$!
      timeout N bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"
    It should also name bounded-build-waiter.md's Rule 2 and the self-match mechanism in one
    line, so the blocked agent learns WHY and not merely THAT.

(2) scripts/tests/test-<name>.sh -- fixture test following
    context/standards/shell-script-testing.md and modeled on
    scripts/tests/test-detect-noop-bash.sh, which drives its hook as a real subprocess with a
    jq -n --arg-built payload and asserts on both stdout and exit code. Required cases: each
    blocking shape above (INCLUDING the bracket variant) rejected with exit 2 and a stderr
    message carrying the kill -0 idiom; a bare `pgrep` allowed; a bare `ps aux | grep` allowed;
    a one-shot `if pgrep -f ...; then` outside a loop allowed; the canonical kill -0 waiter
    allowed; and a malformed or absent-dependency case failing OPEN with exit 0.

(3) Registration. REGISTER IT BARE -- no `2>/dev/null || echo '{}'` wrapper. That wrapper
    converts exit 2 into exit 0 and silently disables the block. The PostToolUse entries in the
    same settings files DO use that wrapper, so copying the wrong neighbor is an easy and silent
    failure.

    TWO REGISTRATION SURFACES EXIST AND THEY DISAGREE. RESOLVING THIS IS REQUIRED WORK, NOT AN
    OBSERVATION TO NOTE IN PASSING:
      - root-files/settings.json PreToolUse matchers: ["Write", "Bash", "Write|Edit",
        "Bash|Write|Edit"]
      - merge-sources/settings-hooks.json PreToolUse matchers: ["Write|Edit", "Bash",
        "Bash|Write|Edit"]  (no "Write" block)
    The DEPLOYED consumer repo's .claude/settings.json PreToolUse matcher list is
    ["Write", "Bash", "Write|Edit", "Bash|Write|Edit"] -- it matches root-files/settings.json
    exactly, while merge-sources/settings-hooks.json is a partial duplicate omitting one block.
    Both files carry duplicate copies of the guard-destructive-git.sh and
    validate-no-task-references.sh entries. Treat the root-files match as EVIDENCE of which
    surface governs, but CONFIRM rather than assume. Register in the governing surface, rule
    explicitly on whether the other surface needs the same entry to stay consistent, then VERIFY
    BY DEPLOYING and grepping the resulting .claude/settings.json for the entry in bare form
    (absence of `|| echo` on this entry). A hook registered in the non-governing file never fires
    -- the same class of silent failure as the wrapper trap above, and it would leave this task
    looking complete while changing nothing.

(4) manifest.json wiring: add the hook to provides.hooks and the test to the tests list (the
    detect-noop-bash.sh entries at lines 298 and 213 are the pattern to follow).

=== THE RULE 4 SECOND LEG -- ASSESS, THEN RULE EXPLICITLY ===

bounded-build-waiter.md Rule 4 is "one waiter per log". Assess whether a second waiter on a
log or PID that already has one is CHEAPLY detectable at PreToolUse time, and either implement it
with a staleness bound or SCOPE IT OUT EXPLICITLY WITH A STATED REASON. Hand-waving it is not an
acceptable outcome; this is a ruling the task owes, not an optional extra.

Inputs to that assessment, already established during task creation:
  - Per-session state at PreToolUse is mechanically feasible: detect-noop-bash.sh already keeps a
    per-session counter under a session-scoped directory (its NOOP_BASH_STATE_DIR / .claude/tmp
    precedent), so a state file keyed by session plus log path is available.
  - THE HARD PROBLEM IS LIFECYCLE, NOT STORAGE: a PreToolUse hook observes waiter STARTS and
    never waiter EXITS. A naive "this log already has a waiter" record therefore goes stale
    immediately and would falsely reject legitimate SEQUENTIAL waits on the same log -- a false
    positive, which this task treats as worse than no hook.
  - Weigh a timestamped record expiring after a bounded interval against simply declining the
    leg. If the conclusion is that Rule 4 is enforceable only at reap time rather than write
    time, RECORD THAT -- it is a legitimate and useful finding, and claude-refresh.sh's reaper is
    where that enforcement already lives.

=== BOUNDARY AGAINST ADJACENT IN-FLIGHT TASKS (NON-NEGOTIABLE) ===

Two neighbors own adjacent failure modes of the SAME wait. The split is BY COMMAND SHAPE and must
not blur:

  THIS TASK owns the SELF-MATCH shape: a wait loop whose liveness test matches a process by NAME
  (pgrep -f, ps | grep), which can match the waiter itself and therefore never resolves.
  bounded-build-waiter.md Symptom 3.

  Task 345 ("Make the no-op spin ... structurally unreachable", [not_started], topic orchestrator)
  owns the NO-OP FILLER shape: `echo idle`, bare `true`, and repeated cat/grep of a log issued
  solely to test for completion. Its file_scope declares
  context/patterns/bounded-build-waiter.md, context/patterns/external-process-wait.md,
  hooks/detect-noop-bash.sh and scripts/tests/test-detect-noop-bash.sh.

  THE COLLISION RISK TO AVOID: task 345's Branch A contemplates "a mechanism with teeth (a
  blocking gate...)" as its possible fix. If both tasks independently build a blocking Bash gate,
  they must be DIFFERENT gates over DISJOINT command shapes, or one must consume the other's.
  This task's gate matches ONLY the loop-plus-name-match conjunction and MUST NOT classify a
  no-op filler command (`echo idle`, bare `true`) at all -- that is 345's territory. Conversely,
  do NOT wait on 345: a self-match waiter and a no-op spin are independently reachable defects.

  Task 343 ("Bound an implementation agent's wait on a backgrounded process", [researching]) owns
  the PARKING shape: the agent backgrounds a job, waits on a notification that never arrives, and
  goes idle. Also disjoint -- that is an ABSENT waiter, not a self-matching one. Do not classify
  it here.

DELIBERATE SCOPE EXCLUSION: context/patterns/bounded-build-waiter.md is NOT in this task's
file_scope, even though the hook enforces its Rule 2. Declaring it would create a serializing
overlap with task 345, and no edit to it is needed -- the hook's rejection message carries the
idiom and the rule name inline. If implementation concludes a cross-reference line in that
document is genuinely required, add the entry AT THAT POINT via
scripts/update-task-status.sh --file-scope-add and accept the resulting edge. That is the
sanctioned mid-run re-scope path, not a workaround.

=== DECLARED FILE_SCOPE OVERLAP, UN-SEQUENCED BY DECISION ===

root-files/settings.json and manifest.json are both declared by task 282 ("Write-time PreToolUse
hook blocking record-versioning language, registered bare so exit 2 survives", [not_started],
itself behind tasks 280 and 281). manifest.json is additionally declared by tasks 280, 281 and
313.

NO DEPENDENCY EDGE WAS CREATED. This is a decision ratified by the repository owner, not an
oversight, and it follows the sanctioned un-sequenced-overlap precedent recorded in task 343's
description. The regions are disjoint: task 282 appends to the PreToolUse "Write|Edit" matcher
block, this task appends to the PreToolUse "Bash" block, and both manifest.json edits append
adjacent list entries that rebase trivially. Serializing this prevention hook behind a three-task
chain (280 -> 281 -> 282) was judged the worse trade for a defect that has ALREADY required
manual operator intervention more than once.

CONSEQUENCE THE NEXT READER MUST KNOW: scripts/orchestrate-batch-admit.sh scans every non-terminal
task in specs/state.json, so it WILL detect a cross_batch overlap on these two files and may defer
this task if it is co-scheduled with 280, 281, 282 or 313. Dispatch this task alone, or alongside
tasks whose file_scope excludes those two files. If two land close together, the later one
rebases.

NOTABLY, task 282 is the closest sibling in SHAPE as well as in footprint -- a bare-registered
PreToolUse hook blocking via exit 2 with a fail-open guard and a fixture test. Whichever lands
first establishes the house pattern the other should FOLLOW rather than re-derive. Check whether
it has landed before designing from scratch.

=== EXPLICIT NON-GOALS ===

- Do NOT add a new context/pattern document, and do not restate Rule 2 in new prose. A sixth
  restatement of a rule four agents already cite would change nothing. THIS IS THE TASK'S CENTRAL
  CONSTRAINT, not a stylistic preference.
- Do NOT weaken or relax any existing rule in bounded-build-waiter.md.
- Do NOT change claude-refresh.sh's reaper behavior. Its Family B classifier is an INPUT to this
  task (a validated pattern inventory to reuse), not a target. Cleanup and prevention are separate
  layers and both should exist.
- Do NOT broaden the hook to no-op filler commands (task 345's territory) or to absent-waiter
  parking (task 343's).
- Do NOT fix the consumer repo's gate script or its runtime. Record consumer-repo consequences as
  recommendations only.

=== ACCEPTANCE ===

- The hook blocks all four bad shapes INCLUDING the [b]racket variant, each with exit 2 and a
  stderr message carrying the kill -0 canonical idiom inline.
- A bare pgrep, a bare ps | grep, a one-shot name-match conditional outside a loop, and the
  canonical kill -0 waiter are ALL allowed. Demonstrated by fixture, not asserted in prose.
- The hook fails OPEN on any internal error, proven by a fixture.
- Registration is verified BARE in the DEPLOYED .claude/settings.json (grep for absence of
  `|| echo` on this entry), and the governing-surface question between root-files/settings.json
  and merge-sources/settings-hooks.json is ANSWERED and RECORDED, with the hook confirmed to
  actually fire after deploy.
- The Rule 4 one-waiter-per-log leg is either implemented with a staleness bound or scoped out
  with a stated reason grounded in the PreToolUse start-but-never-exit lifecycle limitation.
- The pattern-inventory relationship to claude-refresh.sh's Family B classifier is settled
  (shared library, or a recorded reason not to) with no silent-drift path left open.
- Shellcheck clean per context/standards/shell-strict-mode.md.
- Net pattern-document count does not increase.
- No task-number references in any deliverable outside specs/**.


=== CORRECTION (2026-10-06, verified mechanically; supersedes the registration-surface reasoning above) ===
REGISTER IN merge-sources/settings-hooks.json, NOT root-files/settings.json. The earlier reasoning
("the deployed .claude/settings.json matches root-files/settings.json exactly, so root-files
governs") drew the wrong inference from a correct observation. Two independent confirmations:
  (1) scripts/verify-deploy.sh, in its own NOT-registered remediation string, says verbatim:
      "add it to merge-sources/settings-hooks.json, not root-files/settings.json".
  (2) lua/neotex/plugins/ai/shared/extensions/loader.lua marks settings.json in
      INSTALL_ONCE_ROOT_FILES -- "copied only when no project copy exists yet, never overwritten
      on subsequent loads/reloads" (so a hand-edited project settings file survives reloads).
CONSEQUENCE: a registration placed in root-files/settings.json reaches ONLY a fresh install and can
never be delivered into an already-deployed repo. The deployed tree matches root-files because that
is what was copied at first install, not because root-files is the update path. Registering there
would leave this task looking complete while the hook never fires -- precisely the silent
half-deployment failure this task exists to prevent.
Also: the PreToolUse matcher string must be EXACTLY "Bash". deep_merge dedupes per exact
string-equal matcher, so any other spelling creates a second live registration that the add-only
merge can never remove.
file_scope updated accordingly: merge-sources/settings-hooks.json replaces root-files/settings.json.

---

### 346. Reconcile the books observer RUN-record field reads with book-evidence-run-v1, and rule on fail-loud versus silent degradation
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [346_reconcile_books_observe_run_record_field_reads/reports/01_reconcile-run-field-reads.md]
- **Plan**: [346_reconcile_books_observe_run_record_field_reads/plans/01_reconcile-run-field-reads.md]
- **Summary**: [346_reconcile_books_observe_run_record_field_reads/summaries/01_reconcile-run-field-reads-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/books/scripts/books-observe.sh (never a deployed .claude/** tree -- see rules/source-store-deploy-boundary.md). REDEPLOY AFTERWARDS, otherwise the consumer repo keeps running the old copy. No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md). Task numbers are permitted in this description and elsewhere in specs/**.

GOAL. The books observer reads the shared RUN log with field names that do not exist in the normative schema. Reconcile the reads, and rule on whether the observer should fail loud instead of degrading silently -- because the silent degradation is what hid this for as long as it did.

PROVENANCE. Recorded as follow-on (c) in the consumer repo's task 175 plan phase 7, and found independently at plan time as that same plan's Risk R-K. Re-confirmed live during task creation on 2026-10-06.

=== THE DEFECT, VERIFIED FIELD BY FIELD ===

READER: agent-system/extensions/books/scripts/books-observe.sh, the single `jq -c -s` aggregation in its PROBE-DEPENDENT GROUPS block (around lines 408-448), which reads specs/books-evidence/runs.jsonl.

NORMATIVE SCHEMA: the consumer repo's books/schema/book-evidence-run-v1.md "Fields" table. The log's real on-disk keys were read directly during task creation and match that table exactly:

  schema, timestamp, convention_version, host_fingerprint, tier, target, wall_seconds,
  peak_rss_bytes, exit_status, terminating_signal, outcome_class, export_count,
  module_count, refusal_count, warning_count, caller_context{task, phase}

Every mismatch below was confirmed against both the schema document and the 23 live lines now in the consumer repo's specs/books-evidence/runs.jsonl.

MISMATCH 1 -- THE TASK FILTER, AND IT IS THE FATAL ONE. The script passes `--argjson task "$task_number"`, producing a JSON NUMBER, and filters `select((.caller_context.task // null) == $task)`. The schema types `caller_context.task` as "string or null", and the live records carry `{"task":"175","phase":"implement"}` -- the string "175". In jq, `"175" == 175` is false. THE FILTER THEREFORE MATCHES ZERO RECORDS ON EVERY RUN. `$mine` is always empty, `mine_count` is always "0", and the entire `if [ "$mine_count" != "0" ] ... fi` body is skipped. This single defect alone suppresses every RUN-derived group unconditionally, independent of all the mismatches below -- so the field-name errors have never even been reached, and fixing only them would change nothing observable.

MISMATCH 2 -- `.outcome` DOES NOT EXIST; THE SCHEMA FIELD IS `outcome_class`. Read in two places: the per-tier `outcomes: (group_by(.outcome) | ...)` rollup, and the vacuous-pass filter. The schema's vocabulary is the four values pass / fail / vacuous-pass / indeterminate, each with a stated discriminating rule in the schema's "The `outcome_class` vocabulary" section.

MISMATCH 3 -- `.duration_seconds` DOES NOT EXIST; THE SCHEMA FIELD IS `wall_seconds`. Read in the per-tier `total_seconds` sum.

MISMATCH 4 -- `.certifier_class` DOES NOT EXIST AT ALL. The `certifier_outcome_classes` rollup reads `select(.tier == "certify") | .certifier_class`. `tier == "certify"` is correct and is a real schema value; `certifier_class` is not a schema field under any name. The certify-tier-only fields the schema actually defines are the four COUNTS export_count, module_count, refusal_count, warning_count. Decide what `certifier_outcome_classes` should now mean: most likely `outcome_class` restricted to `tier == "certify"`, which is what the group's name already suggests.

MISMATCH 5 -- `.refusal`, `.warning` AND `.detail` DO NOT EXIST. The script collects `refusals: [...select(.tier == "certify" and (.refusal // null) != null) | .refusal]` and `warnings: [...select((.warning // null) != null) | .warning]`, and the vacuous entries carry `detail: (.detail // "")`. The schema has refusal_count and warning_count -- INTEGER COUNTS, certify-tier only, null elsewhere -- and no per-item refusal or warning text anywhere, and no `detail` field. These reads can never yield anything. Rule on whether the OBSERVATION record's `certifier_outcomes` group becomes count-based (which is what the RUN log can actually support) or whether the per-item text it wants must come from a different source. Do not invent a field in the RUN schema to satisfy the reader: the schema is binding and its append-only, sole-writer discipline is a deliberate design commitment.

MISMATCH 6 -- `.vacuous` DOES NOT EXIST, AND THE SENTINEL VALUE IS WRONG TWICE OVER. The filter is `select((.vacuous // false) == true or .outcome == "pass_vacuous")`. There is no `vacuous` boolean in the schema; the correct expression is `outcome_class == "vacuous-pass"`. Note the literal in the script is `pass_vacuous` -- wrong field name AND wrong token order AND wrong separator. The schema's own discriminator for this class is a zero-count input field (e.g. `module_count: 0` for certify), not merely a zero exit code; preserve that distinction when rewriting the filter.

=== WHY THIS MATTERS MORE THAN A NORMAL READER BUG ===

The observer DEGRADES rather than fails. Its documented contract is advisory and non-blocking, and each probe-dependent group is "strictly present-or-absent". So instead of erroring, it writes an OBSERVATION record with the RUN-derived groups absent or empty. EVERY OBSERVATION RECORD IT HAS EVER WRITTEN FOR A BOOKS-TOPIC TASK IS THEREFORE SILENTLY WRONG RATHER THAN HONESTLY ABSENT: a reader cannot distinguish "this task ran no verification tiers" from "the reader could not parse the log". The schema is binding; the observer is advisory; that asymmetry is exactly what let the mismatch persist unnoticed through task 175's plan-time risk register and into live operation.

NOW REACHABLE, WHICH IS WHY IT IS WORTH FIXING NOW: the consumer repo's books/tool/evidence-run.sh landed as the sole writer of runs.jsonl, so the log is actually being written -- 23 lines already -- and the mismatch has live consequences instead of theoretical ones.

=== RULE ON: FAIL-LOUD VERSUS SILENT DEGRADATION (a first-class item, not an afterthought) ===

The silent degradation is the reason this defect survived. Rule explicitly on each, and do not conflate them:

(a) A MISSING OR UNREADABLE LOG is a legitimate absent case -- the probe genuinely has nothing to report. Keep degrading. This case must stay silent.

(b) A LOG THAT EXISTS AND PARSES BUT WHOSE RECORDS CARRY `schema` VALUES THE READER DOES NOT KNOW, or that yields zero matches where the task demonstrably ran tiers, IS A READER DEFECT MASQUERADING AS AN ABSENT CASE. Candidate mechanisms, choose and justify: check each record's own `schema` field (the schema's first row fixes it at "book-evidence-run-v1" and its "Versioning" posture makes this the sanctioned compatibility hook) and emit a loud warning to stderr on an unrecognized value; or record an explicit "unreadable" marker in the OBSERVATION record distinct from "absent", so a reader can tell the two apart. Whatever is chosen must NOT make the observer blocking -- its non-blocking contract stays intact; loud and non-blocking are compatible.

(c) THE TYPE MISMATCH OF MISMATCH 1 IS THE WORKED INSTANCE for whichever mechanism is chosen: a numeric-versus-string filter miss produced a perfect, permanent, totally silent zero. If the chosen mechanism would not have caught it, it is the wrong mechanism.

=== ALSO SETTLE ===

- Whether the fix normalizes the task identifier to a string at the filter (`--arg` rather than `--argjson`, or an explicit `tostring`) or compares both forms defensively. Prefer the schema-faithful form -- the schema says string -- and state why, rather than adding a permissive comparison that would hide a future writer-side regression.
- Whether agent-system/extensions/books/context/project/books/standards/observation-record.md needs amending, which it does if any RUN-derived group's shape changes (mismatches 4, 5 and 6 all plausibly change one). Declared in file_scope for that reason; leave it untouched if the shapes end up unchanged.
- agent-system/extensions/books/scripts/tests/test-books-observe.sh is the existing harness. The absence of a fixture that feeds a schema-conformant runs.jsonl line and asserts the RUN-derived groups are POPULATED is itself part of this defect: a test that only ever exercised the absent path cannot catch any of the six mismatches.

=== ACCEPTANCE ===

- All six mismatches are corrected against book-evidence-run-v1's Fields table, with mismatch 1's string-versus-number filter fixed schema-faithfully.
- A fixture in test-books-observe.sh feeds at least one schema-conformant runs.jsonl line, including the `caller_context.task` string form, and asserts the RUN-derived groups are POPULATED -- not merely that the script exits 0. A regression fixture pins the numeric-filter case so mismatch 1 cannot silently return.
- The fail-loud ruling is implemented, with case (a) still silent, case (b) loud, and the observer still non-blocking.
- A fixture proves the chosen loud path actually fires on an unrecognized `schema` value or its chosen equivalent, and that it does NOT fire for a legitimately absent log.
- observation-record.md matches the record the script now writes.
- Redeployed, and verified against the consumer repo's live 23-line log: a books-topic task's OBSERVATION record shows populated RUN-derived fields rather than "absent".
- Shellcheck clean per context/standards/shell-strict-mode.md. No task-number references in any deliverable outside specs/**.

=== GLOB-HIDDEN TERRITORY OVERLAP, DELIBERATELY UNSEQUENCED (read before co-scheduling) ===

This task declares agent-system/extensions/books/context/project/books/standards/observation-record.md. Task 342 ("Refactor the books extension's context corpus against the settled convention") declares the GLOB agent-system/extensions/books/context/project/books/**, which contains that path. validate-state.sh reports that glob as "invisible to overlap-based collision detection", and orchestrate-predispatch-review.sh will likewise not see it -- so NO automatic collision warning will fire for this pair, and its absence is not evidence of disjointness.

NO DEPENDENCY EDGE WAS CREATED, BY DECISION RATHER THAN OVERSIGHT. Task 342 is on [hold] behind a condition no task can satisfy: its own hold reason records that the dependency half is already met (tasks 340 and 341 both completed 2026-10-05) and the sole remaining blocker is the consuming repository's convention version line moving from 0.1.0-pre to 0.1.0. An edge would park this small, self-contained reader fix behind a version stamp. This is exactly the owner-blocked carve-out, and it is recorded here rather than left as a bare omission.

CONSEQUENCE THE NEXT READER MUST KNOW: if task 342's hold is lifted while this task is still open, the two WILL both write under context/project/books/ with no machine-visible warning. Whichever lands second rebases. The regions differ -- this task edits observation-record.md's RUN-derived group shapes only, while 342 restructures role-scoped loading and agent-set review across the whole corpus -- so a rebase is expected to be mechanical, but it must be performed deliberately rather than discovered.

---

### 345. Make the no-op spin that two existing wait documents and an advisory hook already forbid structurally unreachable, and rule on single-writer discipline for shared fixture trees
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 343

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md): cite by filename, command or concept. Task numbers are permitted in this description and elsewhere in specs/**.

GOAL. A dispatched agent that must wait on a long-running local job currently has a reachable default of manufacturing no-op turns. Two pattern documents and one advisory hook ALREADY forbid exactly that, and all three were live and reachable when it happened anyway. This task must establish WHY they did not bind and place the contract where it does, and must additionally rule on single-writer discipline for shared fixture trees. IT MUST NOT ADD A FOURTH DOCUMENT RESTATING THE RULE.

=== MEASURED INCIDENT (do not re-derive; re-confirm only) ===

Session sess_1791314559_3863b0, 2026-10-06, the Logos/Verification consumer repo, task 175 implement dispatch, lean-implementation-agent, 693 tool uses / ~60 min.

The agent launched its certify test suite as a backgrounded shell job:

  bash books/tests/certify/run.sh > /tmp/claude-1000/suite3.log 2>&1 &

(~9.5 min wall) and then repeatedly issued no-op Bash calls -- `echo idle` returning `idle` -- to burn turns until the log showed an exit line. The user observed a stream of `Bash(echo idle)` rows and reported the agent was "constantly polling". The agent confirmed it unprompted in its own wrap-up: "I burned a large part of this dispatch on `echo idle` polling instead of letting background completions wake me, and earlier let two copies of the suite plus a stray probe race on the shared fixture tree, which produced one spurious failure I then had to diagnose." Both facts are recorded in that task's issues.jsonl.

=== ROOT CAUSE, SPLIT BY OWNERSHIP ===

NOT OURS, AND NOT CHANGEABLE FROM THE AGENT SYSTEM: foreground `sleep` is blocked by the harness, and the harness's own stated alternative (`Monitor` with an until-loop) is not in a dispatched agent's toolset. Do not propose fixing either.

OURS: with both obvious primitives unavailable, a no-op spin loop is a reachable default.

=== REVISED 2026-10-07 -- ONE OF THE TWO REMEDIES THIS TASK ORIGINALLY NAMED IS NOW FORBIDDEN ===

The original text named two correct options: (a) run the long job in the FOREGROUND and let it block, since the Bash tool's own `timeout` parameter accommodates it up to its 600000ms ceiling; and (b) launch it with `run_in_background` and let the completion notification wake the agent.

OPTION (b) IS NO LONGER AVAILABLE FOR THIS TASK'S OWN INCIDENT SHAPE. `agents/general-implementation-agent.md` now carries a hard prohibition, verified in the source store at line 177: "MUST NOT use `Bash(run_in_background: true)` or arm a `Monitor` to watch a local verification, gate, build, or test process from within this dispatched subagent" -- the local-case sibling of the pre-existing CI/remote prohibition. Its stated reason is that the harness's asynchronous detach-then-await-notification path hands the dispatch back unfinished with nothing guaranteed to resume it. The measured incident recorded below was a certify TEST SUITE, i.e. precisely the forbidden shape, so (b) cannot be this task's remedy. Do not propose it, and do not treat the original "two correct options" framing as current.

THE REMEDIES NOW AVAILABLE ARE: (a) the plain foreground form `timeout N cmd`, which the same contract now states as the PREFERRED shape whenever the command plausibly fits the Bash tool's own ceiling; and (c) when it does not fit, `bounded-build-waiter.md`'s canonical idiom VERBATIM -- a captured `pid=$!`, a `kill -0 "$pid"` liveness loop, and an outer `timeout N`, all inside ONE Bash call that does not return control until the wait resolves. That idiom is load-bearing rather than stylistic precisely because it never surfaces a "wait for a notification" choice point, so there is no moment at which the turn could end mid-wait.

CONSEQUENCE FOR THIS TASK'S BINDING PROBLEM, WHICH IS THE WHOLE POINT OF THE TASK: the contract this task was filed to make bind has since been placed in the implementation-agent contract itself, with the local and CI cases named as explicit siblings, and `status-markers.md` separately records that a bounded-wait deadline reached with no result is not an admissible exclusion by itself. RE-CONFIRM WHAT REMAINS UNBOUND BEFORE PLANNING. The binding gap is likely narrower than when this task was filed, and the honest finding may be that the remaining work is the advisory hook and its fixture rather than any further contract text. The anti-proliferation clause above still governs: do not restate the prohibition a fourth time -- the MUST NOT quoted here is its home.

=== THE BINDING PROBLEM IS THE WHOLE TASK (READ BEFORE PLANNING) ===

Four facts, each verified in the source store during task creation. Together they mean the defect is NOT missing prose and NOT a missing hook. An implementer who sets out to write the contract from scratch, or to add a detector, has misread the task.

(1) context/patterns/external-process-wait.md ALREADY STATES THE RULE. Its "Required Rules" section 2 is titled "No no-op filler" and forbids `:`, `true`, `date`, `echo waiting`-style Bash calls by name. Its "The Defect" section already documents this exact four-step failure -- the blocked foreground `sleep`, an unbounded watch exceeding the 600s Bash ceiling and being auto-backgrounded, a chatty watcher waking the agent on every unchanged poll, and roughly 130 no-op calls (`:`, `true`, `date -u`, `echo waiting`) issued to keep a turn alive. It also already carries the bounded-wait idiom and the 540-versus-600 margin reasoning.

(2) context/patterns/bounded-build-waiter.md ALREADY STATES THE COMPANION RULE, and task 175's own plan phase 7 cited it VERBATIM: "background them with a captured PID, a hard timeout, and writer liveness via `kill -0`; one waiter per log; never `ps | grep` or `pgrep -f`".

(3) THE SPINNING AGENT HAD IT IN ITS OWN REFERENCE CHAIN. extensions/lean/agents/lean-implementation-agent.md cites bounded-build-waiter.md directly, and its always-load list includes context/project/lean4/operations/long-builds.md, which also cites it.

(4) AN ADVISORY HOOK ALREADY DETECTS THE EXACT STRING AND ALREADY FIRED. core/hooks/detect-noop-bash.sh is a PostToolUse hook (matcher "Bash") that classifies a pure-literal `echo` as trivial, counts CONSECUTIVE trivial calls per session, and from a threshold of 3 onward injects an `additionalContext` advisory pointing at external-process-wait.md, re-firing every 3 further consecutive trivial calls. `echo idle` is a pure-literal echo and classifies as trivial. The hook landed 2026-09-18 (commit 778109ec0, nineteen days before the incident), the hook file is deployed in the consumer repo at .claude/hooks/detect-noop-bash.sh, and it is registered in that repo's .claude/settings.json at line 108 as `bash .claude/hooks/detect-noop-bash.sh 2>/dev/null || echo '{}'`. Registration source is core/merge-sources/settings-hooks.json.

THE CONCLUSION TO TEST FIRST, BEFORE ANY DESIGN WORK: fact (4) means the advisory very probably fired many times during a streak of hundreds of `echo idle` calls and changed nothing. Confirm or refute that as the FIRST research step, because the two branches lead to different fixes and only one of them is about prose:

  BRANCH A -- it fired and was ignored. Then a PostToolUse `additionalContext` advisory does not bind a dispatched subagent, and neither does a pattern file in its reference chain. The fix is a mechanism with teeth (a blocking gate, or the contract injected into the dispatch prompt itself where anti-analysis-style contracts already go) and/or an honest amendment recording that the advisory layer is insufficient. ESTABLISH WHY the advisory failed -- whether `additionalContext` reaches a subagent's context at all is a verifiable question, not a matter of opinion, and it is the single highest-value finding this task can produce.

  BRANCH B -- it did not fire. Then find the mechanical reason (classification miss, hook not running for subagent tool calls, state-dir or session-id failure causing the documented fail-open, counter reset by an interleaved non-trivial call breaking every streak before 3). A streak broken by interleaved log-reading calls is a live candidate: the agent was alternating `echo idle` with `cat`/`grep` of the log, and the hook deletes the counter on ANY non-trivial command, so an alternating pattern never reaches the threshold. If this is the cause, the fix is in the hook's streak accounting, not in any document.

core/scripts/tests/test-detect-noop-bash.sh is the existing test harness and the place a classification or streak-accounting fixture belongs.

=== SCOPE TO SETTLE AND IMPLEMENT (rule on each; do not assume) ===

ITEM 1 -- ONE SHARED HOME, NOT A PER-AGENT DUPLICATE. The behavioral contract forbidding no-op wait loops (`echo idle`, bare `true`, repeated `cat`/`grep` of a log purely to test for completion) and naming the two sanctioned alternatives must live in ONE place. Candidate homes to evaluate, in the order of least new surface first: amend external-process-wait.md, which already owns this defect class and already forbids the filler (STRONGLY PREFERRED on the no-new-document ground); amend bounded-build-waiter.md; or state it in context/contracts/orchestrator-discipline.md. Note that orchestrator-discipline.md binds the ORCHESTRATOR ROLE explicitly and by its own first paragraph, not the agents it dispatches, so placing an agent-facing contract there requires either widening its stated audience or rejecting it as the home -- rule explicitly, do not place it there silently.

ITEM 2 -- REPEATED LOG-READING IS PART OF THE PROHIBITION. `cat`/`grep`/`tail` of a log issued solely to test whether a job finished is the same defect as `echo idle` wearing a disguise, and it additionally defeats detect-noop-bash.sh's streak counter (see Branch B). The existing "No no-op filler" rule names only the obviously-empty commands. Extend it, and say what to do instead.

ITEM 3 -- SINGLE-WRITER DISCIPLINE ON SHARED FIXTURE TREES (the contract must cover concurrency, not only waiting). The same dispatch raced two copies of the suite plus a stray probe on one shared fixture tree and produced one spurious failure that then had to be diagnosed -- wasted dispatch time attributable entirely to the concurrency, not to any real defect. bounded-build-waiter.md's "one waiter per log" is the nearest existing rule and is about waiters, not writers. Rule on: at most one writer per shared fixture tree per dispatch; how a second invocation is prevented or detected rather than merely discouraged; and whether this belongs in the same home as items 1-2 or alongside the existing one-waiter-per-log rule.

ITEM 4 -- THE 600000ms CEILING VERSUS A ~9.5-MINUTE SUITE. 9.5 min is 570s against a 600s foreground ceiling -- a 30s margin, and external-process-wait.md's own 540-versus-600 reasoning argues that margin is already too thin. This plausibly pushed the agent to background the job in the first place, which makes it a cause of the incident and not a footnote. Rule on whether a suite this close to the ceiling should be foregrounded at all, and what an agent facing a job of unknown duration near the ceiling should do. A recommendation to shard or shorten the suite is a CONSUMER-REPO recommendation and must be recorded as such, never implemented here.

=== BOUNDARY AGAINST THE ADJACENT IN-FLIGHT TASK (NON-NEGOTIABLE) ===

Task 343 ("Bound an implementation agent's wait on a backgrounded process, and give the orchestrator a way to detect a stranded dispatch", currently [researching]) owns the COMPLEMENTARY failure mode of the same wait, and this task carries a dependency edge on it for that reason. The split:

  343 OWNS THE PARKING FAILURE -- the agent backgrounds a job, waits on a completion notification that never arrives, and goes IDLE holding an unfinished dispatch. It also owns item (1) "whether an implementation agent may background a verification/gate process at all, or must run it in the foreground and accept the timeout", the bounded-wait fallback with a deadline, the COMPLETED-WITH-EXCLUSIONS-versus-PARTIAL ruling, and orchestrator-side stranded-dispatch detection.

  THIS TASK OWNS THE SPIN FAILURE -- the agent stays awake and manufactures no-op turns, plus the binding question of items (1)-(4) above, plus single-writer concurrency.

CONSEQUENCE FOR ITEM 4: 343's item (1) ruling on background-versus-foreground is UPSTREAM of this task's item 4. Do not re-litigate it. Take 343's ruling as settled and answer only the narrower near-the-ceiling question. If 343's ruling has not landed when this task is planned, say so and scope item 4 conditionally rather than deciding it twice. Two tasks independently ruling on whether an implementation agent may background a long job, and disagreeing, is the specific outcome the edge exists to prevent.

=== DECLARED FILE_SCOPE IS DELIBERATELY NARROW ===

file_scope declares only external-process-wait.md, bounded-build-waiter.md, detect-noop-bash.sh and its test. The agent definition files were CONSIDERED AND DELIBERATELY EXCLUDED: declaring core/agents/general-implementation-agent.md would have put this task in one territory-mandatory group with tasks 299, 336 and 343, and extensions/lean/agents/lean-implementation-agent.md adds 299 and 336 again, while detect-noop-bash.sh overlaps only task 170. If the item 1 ruling turns out to require an agent-prompt edit (the likely shape of a Branch A fix), ADD THE ENTRY AT THAT POINT via scripts/update-task-status.sh --file-scope-add and accept the resulting overlap and serializing edge. That is the sanctioned mid-run re-scope path, not a workaround.

=== EXPLICIT NON-GOALS ===

- Do not add a third or fourth pattern document stating the same rule. The task fails if its deliverable is new prose restating what external-process-wait.md section 2 already says.
- Do not propose changes to the harness: the blocked foreground `sleep` and `Monitor`'s absence from the dispatched-agent toolset are both out of our control.
- Do not fix the certify suite's runtime, shard it, or change the consumer repo. Record consumer-repo consequences as recommendations only.
- Do not weaken any existing rule in external-process-wait.md or bounded-build-waiter.md. This task strengthens and relocates; it does not relax.

=== ACCEPTANCE ===

- The Branch A / Branch B question is ANSWERED with evidence, not assumed: a stated, checkable finding on whether detect-noop-bash.sh fired during the incident and, if it did, why the advisory did not change behavior.
- The contract has exactly ONE home, named, with the rejected candidates and the reason each was rejected recorded -- including an explicit ruling on orchestrator-discipline.md's stated orchestrator-only audience.
- Repeated log-reading-to-test-completion is covered by the prohibition, with a stated alternative.
- Single-writer discipline on a shared fixture tree is stated, with a detection or prevention mechanism rather than only an exhortation.
- The near-the-ceiling ruling of item 4 is recorded and is consistent with task 343's background-versus-foreground ruling, or is explicitly scoped as conditional on it.
- If the hook changes at all, test-detect-noop-bash.sh carries a fixture proving the new classification or streak accounting, including the alternating-call case.
- Net document count does not increase. Shellcheck clean per context/standards/shell-strict-mode.md for any shell change. No task-number references in any deliverable outside specs/**.

---

### 344. Carry the batching-by-default doctrine to the point of use, and make a territory overlap produce a serializing edge rather than a separation
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 280, Task 311

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). No task-number references in any file landing under agent-system/** (rules/no-task-references-in-deliverables.md): cite by filename, command or concept.

GOAL. Make batching-by-default reachable at the moment an agent composes an /orchestrate invocation or writes a batch plan, and make shared file territory a reason to BATCH WITH A SERIALIZING EDGE rather than a reason to separate.

THE DOCTRINE ALREADY EXISTS -- DO NOT RE-AUTHOR IT. context/patterns/batch-orchestration-guardrails.md's "Batching Is the Default" section already states the dominance rule (shared file territory > topic cohesion > graph shape) and rule 1's unconditional mandate, including that territory wins "even when doing so collapses the batch to width 1 (full serialization) and gains nothing from parallel dispatch except collision visibility". The mechanism is sound too: wave dispatch serializes on any dependencies[] edge, and the per-cycle status/description/file_scope refresh in scripts/orchestrate-cycle-plan.sh lets a wave-N task re-scope a wave-N+1 task mid-run. THE GAP IS THAT NOTHING CARRIES THIS DOCTRINE TO THE POINT OF USE, and several surfaces actively teach its opposite. An implementer who sets out to write the doctrine from scratch has misread the task.

=== ITEM 1 -- STATE THE RULE AT THE ALWAYS-LOADED LAYER ===
merge-sources/claudemd.md already names the guardrails' "Batching Is the Default" section and already says "for which tasks to batch together" -- THE POINTER IS NOT MISSING. Verified independently twice. The defect is placement and framing: it sits directly under the "Multi-task syntax" label following the command table, with no heading of its own between it and the commands, so it reads as comma grammar and is never followed. Add one operative sentence stating the default posture and the overlap-to-edge move, keeping the pointer. JUSTIFY THE TOKEN COST IN WRITING: a posture must fire BEFORE any file read, and a posture discoverable only by reading a 1,795-line pattern file never fires. If research concludes the always-loaded layer should NOT state it, that conclusion must be argued on the same ground rather than assumed.

=== ITEM 2 -- NAME THE OVERLAP-TO-EDGE OPERATION AS THE DEFAULT MOVE ===
In the guardrails doc and context/patterns/multi-task-operations.md. Today the doctrine says territory-overlapping tasks are mandatory together but never says what to DO about an unordered overlapping pair. State serialize-by-edge as the default move on an overlap.

=== ITEM 3 -- RULE 1 HAS NO NARROWNESS QUALIFIER (FIRST-CLASS ITEM, NOT A FOOTNOTE) ===
Component 0 of docs/reference/standards/multi-task-creation-standard.md carries a narrowness qualifier ("a shared NARROW file_scope entry or one named acceptance gate -- not a broad, widely-edited infrastructure file or a directory-root scope"). The dominance rule's rule 1 carries NO such qualifier. Two MEASURED instances, both 2026-10-06, both to be re-measured at implementation time:

(i) GLOBAL REPO: declaring agent-system/extensions/core/manifest.json in a proposed file_scope made FIVE open tasks one "mandatory" group under rule 1, purely via a registration file. This task's own host-script ruling (Item 6) deliberately avoids manifest.json precisely to keep its mandatory group at 3 rather than 6 -- so that scoping choice is itself a worked instance of this finding and should be cited as one.

(ii) CONSUMER REPO (~/Projects/Logos/Verification): one rename task declares 135 paths and overlaps NINE open tasks; the resulting 8-task batch drains in SEVEN sequential waves, and is 8 tasks largely BECAUSE of that one task's footprint.

THE STRUCTURAL CONSEQUENCE: rule 1 taken literally can demand a group LARGER than MAX_TASKS=8, which the cap then silently trims -- so the doctrine as written can ask for what the mechanism refuses to deliver. A repository-root gate script, a manifest, a shared README or a CHANGELOG must not make every task that touches it one mandatory group. THE TASK MUST SAY WHAT RULE 1 DOES INSTEAD: a narrowness test on the overlapping path, a cap-aware fallback, or both. Whatever is chosen must stay consistent with the existing truncation-precedence rule (a cap-driven trim can never split a territory-mandatory group off the end).

=== ITEM 4 -- THE OWNER-BLOCKED CARVE-OUT (NON-NEGOTIABLE; THE RULING DEADLOCKS WITHOUT IT) ===
When the would-be predecessor cannot progress -- blocked on an owner action, PARTIAL behind something no task can unblock, or held -- SEPARATION IS CORRECT, and an edge would park a trivial task behind something permanently stalled. The batch plan must then STATE WHY rather than emit a bare exclusion. LIVE INSTANCE: two tasks in the consumer repo overlap on five components/framed_channel/certificate/*.txt files and were deliberately left unwired for exactly this reason. Without this carve-out the new doctrine produces a deadlock the old "never with" prose avoided.

=== ITEM 5 -- BATCH-PLAN RENDERING RULE ===
For an unordered territory overlap, a roadmap or batch plan picks an order and records the edge instead of emitting a "never with" note. EVIDENCE THAT THE CURRENT CONVENTION IS ACTIVELY WRONG, measured in the consumer repo with its own scripts/lib/file-scope-overlap.sh: three "never with" notes are genuinely territory-backed (components/framed_channel/books/; full-gate.sh; five certificate/*.txt), but a FOURTH is not backed by file_scope at all -- those two tasks are provably disjoint -- so the convention also manufactures FALSE exclusions. Where an edge is genuinely inadmissible, Item 4 governs.
BOUNDARY: the ROADMAP batch-block grammar and its declarative sentence belong to the roadmap-generation task and the batch-proposal-lint task. This task states the POSTURE they render; it must NOT edit context/formats/roadmap-format.md and must NOT author that lint.

=== ITEM 6 -- THE EDGE-BACKFILL OPERATION ===
There is no sanctioned operation today for "these two existing tasks overlap; add the edge that makes them a sequence". Component 4a auto-adds an overlap edge only for tasks created in the SAME batch, so two tasks created in separate sessions that overlap get no edge ever.

Add --depends-on-add to scripts/update-task-status.sh. HOST-SCRIPT RULING: that script is unowned by any non-terminal task, is already registered (so no manifest.json edit, cf. Item 3(i)), and already carries --file-scope-add, --research-questions and --hold-reason, each with the same JSON-array validation shape -- so --depends-on-add is a TRUE EXACT SIBLING, not a new surface.

MIRROR scripts/backfill-file-scope.sh's SHAPE -- idempotent, --dry-run printing the per-task diff and writing nothing, never overwriting what is already there -- but DO NOT MODIFY that script; consume its pattern only (it is a one-shot file_scope backfill, a different operation).

Three things the primitive must provide that nothing provides today:
(a) A DIRECTION CHOICE per pair, stated as a rule rather than left to the caller.
(b) A WRITE-TIME CYCLE REFUSAL. Cycle detection ALREADY EXISTS AND IS BLOCKING: validate-state.sh runs Kahn's algorithm over active_projects' dependency edges (archive entries excluded as terminal) and emits log_fail "Dependency cycle detected among project_number(s): ...". BUT IT IS A SEPARATE VALIDATOR, NOT A WRITE-TIME REFUSAL -- state-write.sh has no cycle check of its own, and validate-state.sh is reachable only by explicit invocation or at the next dispatch (via skill-base.sh, orchestrate-batch-admit.sh, orchestrate-predispatch-review.sh, verify-deploy.sh, commands/task.md). So WHETHER A BACKFILLED EDGE IS CYCLE-CHECKED DEPENDS ON WHETHER WHOEVER WROTE IT HAPPENED TO REMEMBER. That is the argument for a write-time refusal, and it does not depend on the writer having been careless. For a primitive whose entire job is adding edges, the check belongs at the point of write: refuse the edge, name the cycle, exit nonzero. THIS IS A REUSE REQUIREMENT, NOT A NEW ALGORITHM -- consume validate-state.sh's existing Kahn implementation; do not transcribe a second copy.
(c) A DRY-RUN CONFIRMATION that the resulting waves actually drain, via orchestrate-cycle-plan.sh --dry-run.

MOTIVATING INSTANCE (real, performed by hand): 20 edges across 13 tasks were added in the consumer repo via state-write.sh to make eight batches sequence correctly; the direction choice and the drain confirmation were each performed manually, and validate-state.sh was run manually afterwards and passed with 0 failures. The operation Item 6 specifies is exactly that, mechanized.

=== ITEM 7 -- RE-POINT THE NEXT-ADMISSIBLE-BATCH SUGGESTER'S SPEC ===
A specs/ state write via /revise or state-write.sh, NEVER a hand edit; no deliverable file is touched by this item. Task 274's acceptance criterion -- that a file_scope-colliding pair must not appear as a joint suggestion -- IS CORRECT AS WRITTEN AND MUST NOT BE WEAKENED: without an edge the pair would share a wave and write concurrently, so orchestrate-batch-admit.sh's refusal is right. The defect is narrower: THE SUGGESTER HAS NO EDGE-PROPOSING STEP, so it withholds exactly the pairs rule 1 makes mandatory instead of proposing the edge that would make them admissible as a sequence. Re-point it to "propose the serializing edge, then suggest the pair as a sequence". Do not weaken the disjointness check.

=== DECLARED BOUNDARIES -- DO NOT CROSS ===
- The stale "Batching is not yet supported. Running with first N tasks only." message at commands/orchestrate.md and docs/architecture/orchestrate-state-machine.md is owned by task 272 item (b). THIS TASK MUST NOT EDIT THAT STRING, and does not declare commands/orchestrate.md at all -- its existing pointer to the guardrails doc is already adequate.
- Component 4a's cross-batch blind spot is owned by task 312, which owns docs/reference/standards/multi-task-creation-standard.md. This task does NOT declare that file. It supplies the edge-writing primitive that 312's own overlaps-N-add-edge verdict has no way to call -- hence 312's edge on this task.
- DO NOT touch scripts/orchestrate-batch-admit.sh (owned by task 165) and DO NOT change the admission verdict schema.
- DO NOT WEAKEN ANY ADMISSION GATE. This task changes what the agent CHOOSES to batch and what the system TEACHES about batching, never what the runtime permits.

=== SCOPE-NOTE CONFLICT TO RULE ON ===
The guardrails doc's scope note "Territory is a human judgment, not a machine derivation" states that "file_scope declaration granularity, BACKFILL, and absent-scope admission posture are owned by the file-scope-lifecycle topic and are out of scope here". That disclaims file_scope backfill, not DEPENDENCY-EDGE backfill. Rule on the boundary explicitly and amend the note if it is widened -- do not silently widen it.

=== NON-GOAL ===
Not a parallelism or throughput change. Serialization inside one invocation is an acceptable and often preferred outcome; the property being defended is collision visibility and correct sequencing, not wall-clock.

=== DOGFOOD CONSTRAINT ===
This task declares territory overlap with task 280 (merge-sources/claudemd.md) and task 311 (context/patterns/batch-orchestration-guardrails.md) and carries serializing dependencies[] edges on both. Verified acyclic, and the batch {280, 311, this} drains in TWO waves: [280, 311] then [this]. IT IS MEANT TO BE RUN IN ONE /orchestrate INVOCATION TOGETHER WITH THEM, not alone. Tasks 274 and 312 cannot join that invocation (blocked behind 272/273/275/165 and 165/300/282 respectively) and instead take edges ON this task. Filing this work with an empty dependencies[] and a "run it by itself" note would have reproduced the exact defect it exists to fix.

=== ACCEPTANCE ===
- The always-loaded layer STATES the posture rather than only pointing at it, with the token cost justified in writing.
- Rule 1 carries a narrowness qualifier and/or a cap-aware fallback, consistent with the existing truncation-precedence rule; both measured instances in Item 3 are re-measured and cited.
- The owner-blocked carve-out of Item 4 is stated, with the five-file certificate pair as its worked instance.
- The batch-plan rendering rule of Item 5 is stated, including that a bare "never with" note is not an acceptable rendering and can itself be false.
- --depends-on-add exists with --dry-run, a stated direction rule, and a MANDATORY write-time cycle refusal that reuses validate-state.sh's existing Kahn check, with no second cycle detector anywhere in the new code.
- A fixture proves a cycle-creating edge is REFUSED AT WRITE TIME (nonzero exit, cycle named), and a second fixture proves an idempotent re-run adds nothing.
- The next-admissible-batch suggester's spec is re-pointed WITHOUT weakening its disjointness check.
- Shellcheck clean per context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

---

### 343. Bound an implementation agent's wait on a backgrounded process, and give the orchestrator a way to detect a stranded dispatch
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 337
- **Research**: [343_bound_agent_background_wait_stranded_dispatch/reports/01_background-wait-stranded-dispatch.md]
- **Plan**: [343_bound_agent_background_wait_stranded_dispatch/plans/01_bound-background-wait-stranded-dispatch.md]
- **Summary**: [343_bound_agent_background_wait_stranded_dispatch/summaries/01_bound-background-wait-stranded-dispatch-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/** (never .claude/**), per rules/source-store-deploy-boundary.md.

An implementation agent can park indefinitely on a backgrounded verification process and strand a dispatch mid-phase, with no bounded-wait fallback and no orchestrator-visible signal.

--- MEASURED LIVE (2026-10-05, nvim/, batch session sess_1791222088_1f4b0c, task 341 implement dispatch, dispatch_seq 9, general-implementation-agent) ---

At Phase 5 (the full gate sweep) the agent launched verify-deploy.sh as a detached background process (PID 74968) and entered a wait loop for a completion notification. The process exited while the agent was waiting; the notification never arrived. The agent reported "I'll pause here until that notification arrives rather than polling further" and went idle holding an UNFINISHED dispatch:

  - Phases 1-4: committed (4ca4aa3f1, e0fd139d6, aeff20082, 55e26aa05)
  - Phase 5: still [IN PROGRESS] in the plan file
  - summaries/: empty, no summary written
  - .return-meta.json and .orchestrator-handoff.json: still carrying the PRIOR (plan) dispatch's values — status "planned", dispatch_seq 8, not this dispatch's 9

--- WHY IT MATTERS ---

Nothing in the orchestrator detected this. The agent was idle, not failed; its Agent-tool call returned no error. Had postflight run at that moment it would have recorded a 4/5 [PARTIAL] and Phase 5's work would have been lost — despite the underlying gate having actually finished. Recovery required out-of-band human diagnosis (reading progress/*.json, the plan's phase markers, the dispatch_seq in the metadata, and `ps` on the recorded PID) followed by a hand-written resume message telling the agent to re-run the gate in the FOREGROUND and finish its metadata. The dispatch then completed 5/5 normally, which is the proof the work was recoverable and the stall was the only real failure.

--- THE DEFECT IS THE PARKING, NOT THE SLOW GATE ---

The gate's runtime belongs to tasks 170 and 328, which already own it and have both been revised with this batch's measurements. This task is about the failure mode being reachable at all: an agent that backgrounds ANY process and waits on a notification that never comes has no fallback. An instantaneous process that failed to notify would produce the identical stall. Do not let research or planning drift into the runtime question.

--- SCOPE TO SETTLE AND IMPLEMENT (rule on each; do not assume) ---

(1) Whether an implementation agent may background a verification/gate process at all during a dispatch, or must run it in the foreground and accept the timeout. If backgrounding stays permitted, it needs a bounded-wait fallback with a deadline after which the agent re-checks the process directly (its PID, its output file) instead of waiting on a notification that may never arrive.

(2) Whether the agent, on reaching such a deadline with no result, should close the phase as COMPLETED WITH EXCLUSIONS (which is what it eventually did, correctly, once resumed — with a full evidence-bearing Reasoned Exclusions table) or as PARTIAL. Record the ruling where the exclusion contract lives.

(3) Whether the orchestrator can detect a stranded dispatch at all. Today a dispatch whose agent goes idle without writing this dispatch's metadata is indistinguishable, from the orchestrator's side, from one still working. Candidate signals already on disk: the dispatch_seq in .return-meta.json (a RETURNED dispatch whose metadata still carries the PREVIOUS seq is by definition unfinished — this is the cheapest and most direct), the progress/*.json files, and the plan's own phase markers. Rule on whether a cheap post-return staleness check belongs in orchestrate-cycle-postflight.sh, bearing in mind two hard constraints it must respect: the Context Flatness Constraint (postflight must not read reports/plans/summaries) and the postflight boundary's prohibited-operations list.

--- EXPLICIT NON-GOAL ---

Do not resolve this by making the gate faster or by dropping the gate from the full tier. That is tasks 170/328's territory, and it would leave the parking failure mode intact for every other backgrounded process.

--- RELATED, NOT BLOCKING (state the relationship in the deliverable; do NOT create dependency edges) ---

Task 330 (per-dispatch cost and timing record) would make a stall visible after the fact but neither prevents nor detects one. Task 272 (honest session liveness for concurrent same-repo batches) addresses liveness BETWEEN batches, not within a single dispatch.

--- SITES (verify by grep rather than trusting this list) ---

agent-system/extensions/core/agents/general-implementation-agent.md and the other implementation agents that would carry the same guidance; agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh (where a post-return staleness check would go, and where the postflight boundary is enforced); agent-system/extensions/core/context/standards/postflight-tool-restrictions.md (the boundary ruling 3 must respect); agent-system/extensions/core/docs/architecture/handoff-schema.md (the dispatch-identity contract that makes the dispatch_seq signal meaningful).

DELIVERABLE RULE: no task-number references in any file written into the source store (rules/no-task-references-in-deliverables.md). The RELATED relationships above must be stated in deliverable prose by durable anchor — the cost/timing record, the cross-batch session-liveness work — never as "task 330" or "task 272". Task numbers are permitted in this description and elsewhere in specs/**.

--- DELIBERATELY UN-SEQUENCED FILE_SCOPE OVERLAP (read before co-scheduling) ---

All four declared file_scope entries are shared with other non-terminal tasks. No dependency edge
was created for any of them: this task is independent by decision, not by oversight, and the
overlap is recorded here instead of being serialized.

  - agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh — also declared by
    tasks 273, 284, 304, 335, 337
  - agent-system/extensions/core/docs/architecture/handoff-schema.md — also declared by
    tasks 185, 337
  - agent-system/extensions/core/context/standards/postflight-tool-restrictions.md — also
    declared by task 273
  - agent-system/extensions/core/agents/general-implementation-agent.md — also declared by
    tasks 299, 336

CONSEQUENCE THE NEXT READER MUST KNOW: scripts/orchestrate-batch-admit.sh scans every
non-terminal task in specs/state.json, so it WILL detect a cross_batch overlap on
orchestrate-cycle-postflight.sh and may defer this task if it is co-scheduled with that work.
Dispatch this task alone, or alongside tasks whose file_scope does not include the four files
above. If two land close together, the later one rebases; the edits sought here (a bounded-wait
contract and a post-return staleness check) occupy different regions from the handoff-field and
excursion-advisory work.

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
- **Dependencies**: None

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

### 336. Rule on the in-dispatch phase-commit staging surface: fifteen implementation agents commit with no file_scope check and no contended-path lease
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [336_phase_commit_staging_has_no_scope_check/reports/01_phase-commit-scope-check-ruling.md]
- **Plan**: [336_phase_commit_staging_has_no_scope_check/plans/01_phase-commit-containment-self-check.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/** (never .claude/**), per
rules/source-store-deploy-boundary.md.

Rule on the in-dispatch PHASE-COMMIT staging surface, which has no file_scope check and no
contended-path lease, and which is where the only observed out-of-scope commit actually happened.
Fifteen agent definitions share one commit recipe; none of them passes `--task`.

== THE SURFACE (enumerated, verified in the source store 2026-10-04) ==

An implementation agent commits incrementally at each phase boundary via git-commit-scoped.sh,
with a recipe of the shape:

    bash .claude/scripts/git-commit-scoped.sh \
      --message "task {N} phase {P}: {phase_name}" \
      --session "${session_id}" \
      -- <modified-files-for-this-phase>

No `--task`, so the V5 contended-path lease is never consulted. No file_scope comparison anywhere,
so nothing checks the staged list against the task's declared deliverables. The fifteen definitions
carrying this recipe, each verified to contain zero `--task` occurrences:

  agent-system/extensions/books/agents/books-implementation-agent.md
  agent-system/extensions/books/agents/books-implementation-hard-agent.md
  agent-system/extensions/core/agents/general-implementation-agent.md       (lines 297, 790)
  agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md
  agent-system/extensions/founder/agents/founder-implement-agent.md
  agent-system/extensions/latex/agents/latex-implementation-agent.md
  agent-system/extensions/lean/agents/lean-implementation-agent.md          (line 659)
  agent-system/extensions/lean/agents/lean-implementation-hard-agent.md
  agent-system/extensions/nix/agents/nix-implementation-agent.md
  agent-system/extensions/nvim/agents/neovim-implementation-agent.md
  agent-system/extensions/python/agents/python-implementation-agent.md
  agent-system/extensions/rust/agents/rust-implementation-agent.md
  agent-system/extensions/typst/agents/typst-implementation-agent.md
  agent-system/extensions/web/agents/web-implementation-agent.md
  agent-system/extensions/z3/agents/z3-implementation-agent.md

ONE DEFINITION WAS AUDITED AND DELIBERATELY EXCLUDED. agent-system/extensions/core/agents/
meta-builder-agent.md also invokes git-commit-scoped.sh without `--task`, but its site (line 1499)
commits `specs/TODO.md specs/state.json` for task CREATION -- it is not a phase commit, it stages
no deliverables, and it is already declared in the --task-wiring task's file_scope. Including it
here would create a footprint collision with that task for no gain.

Do NOT read that site as carrying a documented ruling on `--task`. The only documented omission
there concerns a DIFFERENT flag: that recipe states `--honest-index-rows` "is deliberately NOT
added here, mirroring commands/todo.md's identical documented omission: this commit creates N
tasks in one call, so there is no single owning task number for the flag to key on." That
rationale is about honest-index-rows, not about `--task`, and nothing anywhere documents the
`--task` omission at that site. So its `--task` gap is exactly as undocumented as the fifteen
below; the reason it is excluded here is ownership (the --task-wiring task declares that file)
plus the fact that it stages no deliverables, NOT that the omission has been ruled on. If a future reader counts
sixteen invokers, that is the sixteenth, and this is why it is absent.

== WHY THIS IS NOT COVERED BY THE --task-WIRING TASK ==

That task's audit of missing `--task` enumerates nine recipe sites -- skills/skill-git-workflow/
SKILL.md, commands/task.md, commands/todo.md, agents/meta-builder-agent.md, skills/skill-meta/
SKILL.md, epidemiology/commands/epi.md, present/commands/grant.md, present/commands/slides.md,
present/commands/timeline.md -- and omits every one of the fifteen above. Its declared file_scope
contains none of them either. So the subjects overlap (both concern `--task` at commit sites) while
the FILES do not overlap at all. Stated explicitly here so that a future reader does not merge
them: this task is not a subset of that one, and that one will not close this surface.

This task therefore declares NO dependencies. It is the surface with demonstrated harm, and it must
not be serialized out behind a dependency chain belonging to tasks that do not touch its files.

== EMPIRICAL BASIS: THIS IS A CASE THE FIX WOULD CATCH ==

Dated observation, 2026-10-04, in the Verification repository (~/Projects/Logos/Verification). The
commit whose subject is "task 187 phase 5: recertify the five books whose identity this work moves"
carried ten generated Typst files:
  typst/manual/generated/components/{channel,crc8,receiver,ring_buffer,seq_num,stuff,
  stuffed_channel,varint,vec_queue,zigzag}.typ
That task's declared file_scope names exactly ONE of them
(typst/manual/generated/components/crc8.typ). Nine were outside the declared scope. The five
components/framed_channel/books/*/book.cert.json paths in the same commit ARE all in file_scope.
Scoping held for every declared path and failed only for the undeclared ones.

That commit is a PHASE commit from this very surface -- verified structurally, not inferred: its
file list contains no state.json, no TODO.md and no task-directory entry other than the plan file,
whereas both postflight scripts unconditionally stage the task directory, TODO.md and state.json on
every call. Its message shape ("phase 5:") matches the recipe above. The neighbouring commit
"task 186: complete implementation" is what a postflight commit looks like by contrast.

THE CONTRAST WITH THE SIBLING TASK IS THE WHOLE REASON THERE ARE TWO TASKS, and both descriptions
state it. The sibling (gate_modified_files_excursion_at_staging) closes a verified disconnect
between an excursion advisory and a staging list inside scripts/orchestrate-cycle-postflight.sh;
that defect is real and worth closing, but a postflight-sited gate could not have prevented the
observed commit, because the observed commit never went through a postflight. This task owns the
surface that produced it.

== THE WORK ==

(1) Rule on the mechanism, and record the reason. The candidates are: pass `--task` (engaging the
V5 lease); add a file_scope check against the phase's staged list; both; or neither, with a
documented reason. They are not equivalent -- the lease only covers paths declared by some task,
so it does nothing for a path declared by none, which is exactly the observed shape. A ruling of
"`--task` alone" must therefore say what it does about the observed case or concede it does not
address it.

(2) THE ASYMMETRY IS THE HEART OF THE TASK: a phase commit happens mid-dispatch, with no postflight
in scope and no orchestrator engine running the call. Whatever mechanism is chosen cannot be a
postflight-sited one, and cannot assume a cycle manifest has been built. Rule on where the check
can actually live given that constraint -- inside the agent recipe as a documented step, inside
git-commit-scoped.sh behind a new opt-in flag, or nowhere -- and weigh the cost of a fifteen-file
prose edit against a single mechanical chokepoint. Prefer a mechanism that cannot be forgotten by
the sixteenth agent definition someone adds next.

(3) If the ruling touches scripts/git-commit-scoped.sh, that file is NOT in this task's file_scope
and that change is recorded as a constrained follow-up, coordinated with the out-of-repository-
pathspec task that owns that script's exit-code contract. Do not widen file_scope to reach it.

(4) Whatever lands must be uniform across all fifteen definitions, or the ruling must say why a
subset is correct. A per-extension divergence in commit discipline is itself a defect.

== OUT OF SCOPE ==

The postflight excursion gate (the sibling task, gate_modified_files_excursion_at_staging); the
own-task-directory filter false positive in the postflight advisory; the nine recipe sites owned by
the --task-wiring task; what file_scope means or how it is harvested; and any change to
git-commit-scoped.sh (item 3).

== KNOWN SERIALIZATION CONTENDER (no edge declared) ==

The in-place-plan-revision-detection task declares agent-system/extensions/core/agents/
general-implementation-agent.md and agent-system/extensions/lean/agents/lean-implementation-agent.md
in its file_scope -- two of this task's fifteen. Its subject is plan-revision detection during a
live implement dispatch, so the regions do not touch and either order merges cleanly. Recorded here
visibly rather than as a dependency edge, per the ruling that this task carries no dependencies.

== ACCEPTANCE ==

The mechanism question is RULED ON with reasons recorded, including an explicit answer on whether
the chosen mechanism addresses the observed undeclared-path case or only the contended-path case;
the mid-dispatch asymmetry in item (2) is addressed rather than assumed away; whatever lands is
uniform across all fifteen definitions or the subset is justified; the observed commit's shape is
exercised as a regression case that demonstrates the pre-fix behaviour; and any git-commit-scoped.sh
change is recorded as a follow-up rather than made here.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 335. Promote the modified_files-vs-file_scope excursion advisory into a staging-time gate, so the per-cycle commit stops carrying paths the advisory already named
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 284

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per
rules/source-store-deploy-boundary.md.

Make the postflight staging list consult the excursion verdict the same script already computes,
so a per-cycle commit stops carrying the paths that verdict has already named as outside the
task's declared file_scope.

== THE DEFECT, LOCATED PRECISELY (verified in the source store 2026-10-04) ==

Both halves live in ONE file: scripts/orchestrate-cycle-postflight.sh (1841 lines).

WORK (h), lines 1315-1331. Computes `excursions_json` as exactly the `.modified_files[]` entries
not matching any declared `file_scope` prefix, prints "ADVISORY: task N reported modified_files
outside its declared file_scope: [...]", and labels itself in the same line "(detection only --
no gate, no exit-code, no verdict effect)". The header's work-item list at line 50 says the same:
"detection only, never a gate."

WORK (i), lines 1563-1617. Roughly 240 lines later, independently re-reads the SAME
`.modified_files[]` from the SAME `${TASK_DIR}/.return-meta.json`, appends every entry to
`stage_paths`, and hands the lot to git-commit-scoped.sh. `excursions_json` is never consulted by
WORK (i). The gate is one conditional away from existing.

Note the line numbers: an earlier record of this file cites 1121-1132 for WORK (h). That is stale
drift, not a second site. There is exactly one excursion computation in the file.

== WHY THE CONTENDED-PATH LEASE CANNOT COVER THIS CASE ==

git-commit-scoped.sh's V5 contended-path lease fires only for paths listed in the cycle
contention manifest, which is derived from tasks' declared file_scope (orchestrate-cycle-plan.sh's
build_contended_manifest, lib/file-scope-overlap.sh, lib/territory-contention-lib.sh). A path in
NO task's file_scope is in no manifest, so the lease provably never fires for it. This is a
different gap from the one the --task-wiring work is closing, and the two must not be merged.
Note also that THIS call site already passes `--task`, so the lease is in fact consulted here --
it simply has nothing to say about an undeclared path.

== EMPIRICAL BASIS, AND PRECISELY WHAT IT DOES AND DOES NOT SHOW ==

Dated observation, 2026-10-04, in the Verification repository (~/Projects/Logos/Verification). The
commit whose subject is "task 187 phase 5: recertify the five books whose identity this work
moves" carried ten generated Typst files:
  typst/manual/generated/components/{channel,crc8,receiver,ring_buffer,seq_num,stuff,
  stuffed_channel,varint,vec_queue,zigzag}.typ
That task's declared file_scope names exactly ONE of them
(typst/manual/generated/components/crc8.typ). Nine were outside the declared scope. The five
components/framed_channel/books/*/book.cert.json paths in the same commit ARE all in file_scope.
So scoping held for every declared path and failed only for the undeclared ones -- the signature
of an unvalidated staging list, not a mis-declared scope.

READ THIS QUALIFIER BEFORE BUILDING ANY FIXTURE, AND DO NOT OVERSTATE THE EVIDENCE. That commit
was NOT produced by this script. Its subject is a PHASE commit, made mid-dispatch by the
implementation agent, and its file list contains no state.json, no TODO.md and no task-directory
entry other than the plan file -- whereas WORK (i) unconditionally stages `${TASK_DIR}/`, TODO.md
and STATE_FILE on every call. The neighbouring commit "task 186: complete implementation" is what
a real postflight commit looks like. The observed commit is therefore the EVIDENCE THAT THE
PREDICATE IS WORTH ENFORCING, not a case this gate catches. The regression fixture must be a
synthesised postflight-shaped case carrying that shape, and no claim may be made anywhere in the
artifacts that this gate would have prevented the observed commit. The surface where that commit
actually happened is a separate task, filed alongside this one (phase_commit_staging_has_
no_scope_check), and work item (7) below points at it.

== THE WORK ==

(1) Make WORK (i) consult WORK (h)'s result instead of recomputing the staging list independently.
One derivation of the staged set, one verdict on it.

(2) Rule on what an excursion DOES, and record the ruling with its reason in the script header.
The candidates are materially different: drop the excursion paths and commit the rest, which
matches context/standards/git-staging-scope.md's recorded "Under-stage, never over-stage" fail-safe
direction at that document's "Fail-Safe Direction" section; refuse the commit; or widen file_scope
and proceed. The drop-and-commit shape is the recommended starting hypothesis precisely because it
filters `stage_paths` upstream, inside this script, and needs no change to git-commit-scoped.sh's
exit-code contract at all. Follow the recorded advisory-first pattern from the completed
admission_posture_for_absent_file_scope task: if the honest outcome is to stay advisory, write down
the promotion criterion rather than asserting the status quo.

SCOPE NOTE ON THE EXIT-CODE CANDIDATE. git-commit-scoped.sh is deliberately NOT in this task's
file_scope. If research concludes the ruling genuinely requires a new git-commit-scoped.sh exit
code alongside 2/3/4, that specific change is recorded as a FOLLOW-UP, constrained by the
exit-code contract owned by the out-of-repository-pathspec task (see the interaction section
below), rather than made here. This mirrors how the --task-wiring task handles the identical
situation ("record it as a follow-up instead") -- it is the house pattern, not an improvisation.

(3) Decide whether the same gate belongs in scripts/orchestrator-postflight.sh Stage 9 (lines
518-547), which assembles its `stage_paths` the same way and has no excursion computation at all.
In that file file_scope appears only at lines 333-350, where it is WRITTEN (proposed_file_scope
forwarded for research; plan-file-scope-harvest.sh for plan), never read as a boundary. CONFIRM
FIRST THAT THE ORPHAN STATUS STILL HOLDS: scripts/skill-base.sh:991 states
"orchestrator-postflight.sh itself has no live callers" and :1185 calls it "the orphaned
orchestrator-postflight.sh". The stated default for the ruling is that a gate in dead code is not
worth the edit; overturning that default requires finding a live caller.

(4) Fail open where file_scope is absent. Most state.json rows carry none, and git-commit-scoped.sh's
own --task check fails open unconditionally on a missing or malformed manifest precisely so a
concurrency guard is never the reason an agent cannot commit. Match that posture; the completed
admission_posture_for_absent_file_scope task is the prior art.

(5) Preserve the two benign cases: the specs/ carve-out (TASK_DIR, TODO.md, state.json and the
plan path are legitimately outside any file_scope declaration -- file_scope names deliverables)
and the existing `modified_count -eq 0` branch, which already warns and commits nothing from
source. Neither may become a refusal.

(6) Tests in the repository's existing shell-test style; scripts/tests/test-lint-scoped-commit-
boundary.sh and scripts/tests/test-guard-destructive-git.sh are the nearest models, and
scripts/tests/test-orchestrate-cycle-postflight.sh is the file the cases land in. Cover the
synthesised excursion shape, the absent-file_scope fail-open, the specs/ carve-out, and the
zero-modified_files case.

(7) State explicitly, in the script header and the report, that this gate does not cover
in-dispatch phase commits, and point at the sibling task that owns that surface
(phase_commit_staging_has_no_scope_check). A phase commit happens mid-dispatch with no postflight
in scope, so no postflight-sited mechanism can reach it. Disclaiming coverage without naming the
owner is what let this gap persist.

== LOAD-BEARING INTERACTION TO CHECK AT RESEARCH TIME ==

The out-of-repository-pathspec task (out_of_repo_pathspec_aborts_whole_commit) names, as its own
candidate surface 2, verbatim: "The postflight consumer (orchestrate-cycle-postflight.sh:1252, and
orchestrator-postflight.sh, which also reads the field). Filter or partition modified_files before
it reaches the commit script." That is the same `modified_files` -> `stage_paths` region this task
rewrites -- a DIFFERENT predicate (repository containment vs file_scope membership) in the SAME
lines. It also owns git-commit-scoped.sh's exit-code contract and rules on whether callers branch
on exit 2/4.

No dependency edge is declared on it deliberately: the file_scope overlap (three shared entries --
orchestrate-cycle-postflight.sh, context/standards/git-staging-scope.md,
scripts/tests/test-orchestrate-cycle-postflight.sh) already forces serialization through the
admission gate, and an explicit edge would buy ordering determinism at the price of an eight-deep
dependency chain for a defect that is one conditional. But research MUST read that task before
designing: if it has landed, compose with its filter/partition step rather than duplicating it; if
it has not, do not pre-empt its predicate.

The excursion FILTER's own correctness -- exempting the dispatching task's own directory -- is
owned by the declared dependency and runs first, for the reason that task states itself: a gate
sitting on a known-false-positive predicate would block correct work.

== OUT OF SCOPE ==

What file_scope means; how it is harvested (plan-file-scope-harvest.sh, backfill-file-scope.sh);
the admission and contention machinery that consumes it. This task makes staging honour the
existing contract, it does not redefine it. Also out of scope: fixing the own-task-directory
filter false positive, which is the dependency's own work; the phase-commit staging surface, which
is the sibling task's; and any change to git-commit-scoped.sh, per the scope note in item (2).

== ADMISSION GATE ==

scripts/orchestrate-cycle-postflight.sh IS entry on context/reference/orchestrator-critical-paths.json,
so this task DOES trip the self-modification admission gate. Declared honestly rather than dodged
-- the gate is one conditional inside the commit path and cannot be reached from outside it. Note
that git-commit-scoped.sh is NOT on that registry (the twelve script entries are
orchestrate-batch-admit, orchestrate-build-dispatch, orchestrate-cycle-plan,
orchestrate-cycle-postflight, orchestrate-recover-outcome, orchestrate-triage-classify,
reconcile-task-status, skill-base, system-defect-record, task-lock, update-task-status,
verify-deploy), so it is not the source of the admission requirement here.

== ACCEPTANCE ==

WORK (i)'s staged set is derived once and checked against WORK (h)'s verdict; an excursion is
handled per the recorded ruling with the reason in the script header; a task with no file_scope
commits exactly as it does today; the specs/ carve-out and the zero-modified_files case are both
green; context/standards/git-staging-scope.md records the new behaviour alongside V2/V3/V5/V6 with
the dated observation as its empirical basis and with that observation's phase-commit provenance
stated accurately; the excursion shape is exercised as a synthesised postflight-shaped regression
fixture that fails before the change and passes after; and no artifact claims this gate would have
caught the observed commit. shellcheck clean per context/standards/shell-strict-mode.md.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 328. Systematic script and test corpus efficiency
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 170, Task 318, Task 322, Task 304, Task 303

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

### 319. Surface cross-task claim invalidation when a research dispatch refutes a filed premise
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 285

**Description**: SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/` (never `.claude/**`, a disposable deploy artifact -- see `rules/source-store-deploy-boundary.md`).

## Goal

When a research dispatch machine-checks a refutation, or closes a question by supersession, the OTHER open tasks whose filed premises that result falsifies must be surfaced for human triage. Today nothing does this, so a refutation's blast radius is found only if a human happens to read the report and hand-check sibling task descriptions.

## Motivating harm (observed live, not hypothetical)

During a five-task `/orchestrate 704,705,707,708,710 --lit --fable` run in `~/Projects/BimodalLogic` on 2026-10-02, a research dispatch machine-checked a refutation: the time-sliced certificate class is incomplete for full L-plus, and already for the CTL-like fragment. The probe is `specs/710_sliced_class_incompleteness_characterization/probes/NoFiniteWidthModel.lean` -- sorry-free, axioms `propext` / `Classical.choice` / `Quot.sound`.

That single result falsified filed claims in FIVE other tasks in the same repository (706, 707, 708, 709, 712). **Nothing in the system surfaced any of them.** They were found only because a human-directed pass read the report and hand-checked sibling task descriptions.

## Concrete cost of the gap

- Task 709's headline was "establish the finite model property for the CTL-like fragment against the sliced class" -- it targeted exactly the fragment that falls, with a recorded estimate of 60-100 hours of formalization. Without the manual pass it would have been dispatched to prove a theorem already machine-checked false.
- Task 707 was a context note whose entire stated purpose is "so the fact is never rediscovered a third time". It was about to enshrine a design rule (`Z x Fin n` with finite fibres) that the same refutation had just shown necessary but NOT sufficient. A task written to stop rediscovery was itself about to record the next stale assumption.

The downstream cost is therefore not a wasted hour; it is an entire dispatched programme aimed at a false target, and a durable context note recording a premise already known to be wrong.

## Reconciliation against the open backlog (verified in the source store, 2026-10-02)

- No existing script, context file, or postflight stage in `agent-system/extensions/core/` performs any refutation or supersession sweep. Greps for `refut` / `supersed` / `invalidat` across `scripts/` and `context/` return only unrelated matches (session reaping, predispatch review, census methodology). This gap has **zero** coverage in the backlog.
- There is **no structured field** for a refuted premise anywhere in the state schema. In the BimodalLogic repo the refutations of this run were recorded as free text inside `description` (29 occurrences of `refut`), which a mechanical sweep cannot key on reliably. Deciding the trigger surface is therefore part of this task, not a given.
- `decisions_made` exists in the orchestrator handoff schema (`docs/architecture/handoff-schema.md`) and is explicitly "informational/historical (settled questions a downstream agent should not re-investigate)" -- the closest existing surface, and a live candidate trigger. Its writer, however, is the subject of open task 285, which is why 285 is declared as a dependency here: if the ruling picks the decision-record route, 285 must land first.

## Scope to settle and implement

A **postflight surfacing step**. When a research artifact records a refutation or a closed-by-supersession decision, sweep the OTHER open task descriptions for the refuted claim and emit an advisory list for human triage.

Declaration names are the strongest key; the probe above is the worked example (a sweep keyed on `NoFiniteWidthModel`, or on the refuted declaration names it establishes, would have hit 706/707/708/709/712).

Research must RULE on, not assume:

1. **What triggers detection.** Three candidates, none yet chosen: (a) an explicit metadata field the research agent sets on `.return-meta.json`; (b) a convention in the report artifact body; (c) a `decisions_made` / `.decisions.json` decision-record line (see the task 285 dependency above).
2. **Where the sweep output lands.** It must reach a human, and it must survive the dispatch that produced it.
3. **Whether it blocks or is purely advisory.** Recommendation: **advisory**.

### Honest difficulty, to be stated in the deliverable rather than papered over

Detecting "this claim is the same claim" in general is hard. The tractable version keys on **declaration names and explicit supersession markers**, not on natural-language equivalence. The task must say so and record its false-negative posture explicitly, rather than over-promising a semantic claim-matcher it cannot deliver.

## Non-goals (hard constraints)

- **SURFACING ONLY.** It must never auto-edit a task description.
- It must never change a task's status. Both of those were human calls in the observed incident and must stay human calls.
- Do not attempt natural-language claim equivalence. See the difficulty note above.

## file_scope note

The trigger-surface path is deliberately NOT declared yet -- declaring one of `context/formats/return-metadata-file.md`, `rules/artifact-formats.md`, or the `.decisions.json` writer would prejudge design question 1 above. Add the chosen one via the research phase's `proposed_file_scope` mechanism once research rules (the same deliberate omission open task 312 uses).

The postflight call site is also NOT declared. `scripts/orchestrate-cycle-postflight.sh` is the obvious integration point but is already in the declared `file_scope` of eight open tasks (184, 263, 273, 279, 284, 285, 304, 315); declaring it here would add eight serializing edges for a file this task touches by one call line. Add it at wiring time.

## Acceptance

Replaying the observed incident -- the `NoFiniteWidthModel` refutation against the task descriptions of 706, 707, 708, 709 and 712 as they stood before the manual pass -- yields an advisory list naming all five, with no task description or status mutated by the sweep.


== ADDED SCOPE (amendment): THE POSITIVE DIRECTION -- PRIOR FINDINGS REACHING THE NEXT TASK ==

The sweep above surfaces the NEGATIVE direction: a result that FALSIFIES a filed premise in
another task. Extend the same sweep to the POSITIVE direction: a finding already RECORDED in one
task's artifacts must reach the later task that would otherwise rediscover it.

MOTIVATING MEASUREMENT (live, from a completed books task in the consumer repository, not
hypothetical). One implement dispatch spent 75 of 127 minutes in a single phase rediscovering six
integration collisions between the books convention and a component's pre-existing gate. THREE OF
THOSE SIX FACTS HAD ALREADY BEEN RECORDED IN EARLIER DISPATCHES' ARTIFACTS and were rediscovered
anyway, because a finding written into `specs/NNN_*/summaries/` is invisible to the next task.
Nothing reads it, nothing indexes it, and the memory extension's `memory-retrieve.sh` preflight
injection did not surface it either.

WHY THIS BELONGS HERE RATHER THAN IN ITS OWN TASK: it is the same mechanism in the other
direction over the same narrow edit target -- the artifact walk this task already builds, plus a
matching rule. Two directions of one matcher sharing one script is exactly the shared-edit-target
signal that Component 0 of `docs/reference/standards/multi-task-creation-standard.md` names as
calling for one task. A parallel cross-task artifact walker built alongside this one is the
duplication that the backlog-reconciliation work exists to prevent.

WHAT TO DECIDE AND IMPLEMENT (a decision is required; a restatement of the problem is not an
acceptable outcome). Weigh at least: (i) a harvest trigger, (ii) coverage through the memory
extension's existing `/distill --dream` surfacing path, and (iii) a dedicated per-domain finding
ledger. Record the verdict with its evidence. NOTE A BOUNDARY: `scripts/memory-harvest.sh` is
owned by the `/todo` consolidation work (titled *"consolidate the duplicated skill-todo
implementation, then wire roadmap pruning"*) -- if the chosen mechanism requires editing that
script, that is ADDED SCOPE TO SPAWN, NOT TO ABSORB.

PRECISION REQUIRED ON THE MATCHING RULE. The negative direction can key on refutation, which is a
sharp signal. The positive direction has no equivalently sharp signal, so an over-broad matcher
would surface every prior artifact for every task and be ignored. State the precision/recall
posture explicitly and pick a matcher whose false-positive rate is defensible.

ESCAPE HATCH, EXPLICIT: if research finds the two directions together exceed one agent dispatch
(the phase-sizing bound), the positive direction is SPAWNED AS ITS OWN TASK ORDERED BEHIND THIS
ONE -- added scope to spawn, not to absorb. Do not silently drop it and do not silently absorb it
past the sizing bound.

Cite durable anchors only in anything written into the source store -- never a task number
(`rules/no-task-references-in-deliverables.md`).

---

### 318. Wire lint-directory-pathspec-boundary.sh into verify-deploy.sh as a numbered gate
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 265

**Description**: Wire the directory-pathspec boundary lint into `verify-deploy.sh` as a numbered gate, so the rule it enforces cannot silently regress. The lint and its fixture test already exist and pass; only the gate wiring is missing, and it was deliberately deferred because the wiring target is an orchestrator-critical path.

== CURRENT STATE (verified) ==

`scripts/lint/lint-directory-pathspec-boundary.sh` exists, is registered in `agent-system/extensions/core/manifest.json`, is cross-referenced from `context/standards/git-staging-scope.md`, has a 14-case fixture test at `scripts/tests/test-lint-directory-pathspec-boundary.sh` (auto-discovered by `scripts/tests/run-all.sh`'s `test-*.sh` glob, so it needs no registration), and reports 0 violations across the whole source store.

What it lacks is a `verify-deploy.sh` gate. Its sibling `lint-scoped-commit-boundary.sh` IS wired, as gate 17. So the asymmetry is the defect: the newer rule is enforced only when someone runs the lint by hand, while the older sibling rule is enforced on every deploy.

== WHY IT WAS DEFERRED, AND WHAT THAT MEANS FOR THIS TASK ==

`scripts/verify-deploy.sh` is entry 12 on `context/reference/orchestrator-critical-paths.json` ("deploy verification gate"). The task that built the lint declared a scope note forbidding itself from touching any critical path, so it shipped the lint and recorded the wiring as a follow-up rather than widening its own scope. That was the correct call. This task exists to do the wiring under proper admission.

== THE WORK ==

Add the lint as a gate in `scripts/verify-deploy.sh`, following gate 17's existing shape for its sibling lint (same invocation convention, same `--verbose` handling, same PASS/FAIL line format, same placement relative to the other lint gates). Research must read gate 17 and match it rather than inventing a new gate idiom.

Rule on and record:

- **Gate number and placement.** The lint numbering is not arbitrary -- gates are referenced by number in operator-facing output and in docs. Determine whether this becomes a new trailing gate or is inserted next to gate 17 (its sibling), and what that does to every subsequent gate's number and to any doc that cites a gate by number. An insertion that silently renumbers gates 18-20 would invalidate existing references, including the gate-20 citations in the orchestrator context-budget work. Prefer a placement that does not renumber, or fix every citation.
- **Blocking vs. advisory tier.** Gate 17 is blocking. Confirm whether this lint should be too. It currently reports 0 violations, so wiring it as blocking is safe TODAY -- but verify that claim at implement time rather than trusting this sentence, since the source store changes underneath.

== HARD CONSTRAINT ==

Do not weaken the lint to make the gate green. If wiring reveals violations, the correct response is to fix the violating sites or to justify an allowlist entry in the lint's own allowlist layer -- never to broaden the classifier so the finding disappears.

== CLOSE BY ==

Run `bash .claude/scripts/verify-deploy.sh` and confirm the new gate appears, passes, and that the total gate count in the `[verify-deploy] PASS -- N check(s)` line increments correspondingly. Confirm `scripts/tests/test-lint-directory-pathspec-boundary.sh` still passes and that no other gate regressed.

All edits land under `agent-system/extensions/core/` per `.claude/rules/source-store-deploy-boundary.md`, never under `.claude/**`.

NOTE: `scripts/verify-deploy.sh` IS an orchestrator-critical path, so this task trips the self-modification admission gate by design. It also shares `verify-deploy.sh` with the Gate-8-parallelism task, hence the dependency edge -- do not run the two concurrently.

== BATCHING CONSTRAINT (added after a batchability review) ==

**Ordering dependency on the gate-20 trim task.** This task and the SKILL.md trim task both declare `scripts/tests/test-verify-deploy-context-budget.sh`. That is a genuine ordering dependency, not incidental file sharing: the trim task may re-derive gate 20's per-file ceiling, and this task may renumber the gates that same test refers to. A `dependencies[]` edge now records it -- do not remove it, and do not run the two concurrently.

**Shared file, distinct regions: `context/standards/git-staging-scope.md`.** Three live tasks declare this file and each owns a different region of it: the `--task` lease task owns the task-scoped pathspec carve-out ruling, the out-of-repository-pathspec task owns the exit-code table, and THIS task owns only the gate-number reference beside the existing `lint-directory-pathspec-boundary.sh` cross-reference (already present at the "complementary mechanical" bullet). No `dependencies[]` edge is declared between them, deliberately and on precedent: a live plan in this system already records the same posture for a file shared by eight tasks with no shared region, taking no edge and documenting the reasoning instead. A false serializing edge here would push this small gate-wiring task several waves later for no real conflict.

The consequence is a BATCHING rule, not a dependency: the admission gate matches `file_scope` at FILE granularity, not region granularity, so these three tasks WILL hard-defer each other if placed in the same `/orchestrate` batch. Run them in separate invocations. If a future change makes two of them genuinely contend for the same region, add the edge then.

== OBSERVATION (not a requirement of this task): THE LINT'S COVERAGE IS ONE-SIDED ==

Surfaced by the live regression now tracked as task 322, and recorded here because this task is the one wiring the lint as a gate.

`lint-directory-pathspec-boundary.sh` detects a pathspec that is too WIDE -- a bare shared-directory token regrowing at a call site. It cannot detect a pathspec that is too NARROW. Task 322's defect is exactly that second shape: `commands/todo.md`'s three directory-move sites pass an explicit list naming only each `mv`'s destination and omitting the vacated source, so the deletion half of every rename goes unstaged and the commit still exits 0. A missing pathspec token is an omission rather than a textual pattern, so the lint structurally cannot see it -- and neither can `git-commit-scoped.sh`'s V2/V6 gates, which only ever classify pathspecs they are given.

This does NOT change this task's scope, which remains the gate wiring, and it is NOT a licence to broaden the classifier (see the HARD CONSTRAINT above -- that prohibition still stands). It is recorded so that whoever wires the gate knows a green gate certifies "no over-wide pathspec", not "pathspecs are correct". Whether a complementary too-narrow check (e.g. flagging a `mv` whose source is absent from the nearby staging accumulator) is worth automating is an open question; if judged worthwhile it belongs in its own task, not bolted onto this wiring.

---

### 313. Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md phase blocks
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 306, Task 328, Task 344

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

### 311. Replace static build-heavy family membership with a measured co-scheduling signal, and record the isolation-posture findings
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: Two folded parts sharing one document. PART 1 -- MEASURED BUILD WEIGHT: BUILD_HEAVY_TASK_TYPES=("lean4" "cslib") at orchestrate-cycle-plan.sh line 1819 is a static task-type family list, so any two lean4 implement candidates are categorically refused co-scheduling regardless of real build weight -- a Mathlib-free lean4 package measured at 6 s wall / 17 jobs from an empty .lake/ is blocked exactly as a full Mathlib build is. This is the binding constraint on real parallelism for Lean-heavy batches, which is the primary intended application of concurrent batching here. Replace family membership with a measured or probed signal (recorded prior job count / wall-clock duration per task, or a cheap dry-run probe) and explicitly design the fallback behavior for a task with no measurement history yet. PART 2 -- ISOLATION POSTURE RECORD (folded in per the research report's own Context Extension Recommendation): append to batch-orchestration-guardrails.md's "Working-Tree and Build Isolation Posture" section (i) the two new hazard classes -- repo-scanning pollution from in-tree worktree provisioning, and mode 2's guard-bypass-via-bare-invocation recurrence, evidenced by a plan-sanctioned certify.sh bypassing lake-build-guard.sh via a bare `lake` call -- and (ii) the CoW/reflink/overlayfs/clone-nothing evaluation including the ext4 no-reflink blocker, cross-referencing specs/decisions/worktree-isolation-removal-reaffirmation.md so any future re-opening of the worktree question starts from a complete evidence base. WHY ONE TASK: that single doc carries both the build-heavy co-scheduling rule and the isolation posture in adjacent sections, and the build-weight change must edit it anyway; territory.md also carries build-heavy references. All edits land under agent-system/extensions/core/ per .claude/rules/source-store-deploy-boundary.md, never under .claude/**. Evidence base: specs/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md and specs/decisions/worktree-isolation-removal-reaffirmation.md. NON-GOALS: do NOT restore per-dispatch git worktree isolation (that verdict was re-opened, re-argued and CONFIRMED -- see the decision record); do NOT attempt a Lake/Mathlib shared-cache feasibility spike (named as a possible future spike, not requested). SELF-MODIFICATION: this task IS self-modifying (scripts/orchestrate-cycle-plan.sh is an orchestrator-critical path); expect the admission gate to defer it and re-invoke /orchestrate rather than passing --allow-self-modifying.

---

### 306. Make ROADMAP.md a generated artifact: extend the format into a generation contract and add regenerate and prune modes
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Turn specs/ROADMAP.md into a generated artifact with a standardized format, so its phase/batch structure is derived mechanically from state.json dependencies instead of being hand-maintained.

MOTIVATION (verified): specs/TODO.md's generated "Dependency Waves" table already contains exactly the same waves that a hand rewrite of ROADMAP.md derived by hand -- identical task sets, identical "Blocked by" and "Topics" columns. The roadmap was re-deriving by hand a table the system already computes. Hand-maintained roadmap prose also goes stale silently: the file carried a claim that the `hold` status was unsupported and would break generate-todo.sh and validate-state.sh, which had been false since the HOLD marker landed (validate-state.sh knows hold_reason, held_at and prior_status).

SCOPE:
1. Extend context/formats/roadmap-format.md from a 65-line parse spec into a generation contract. It currently specifies only phase headers, checkboxes, status tables and the completion annotation; it does NOT specify the **Status**, **Milestones**, **Blocked by**, **Topics** or **Run** lines the live file actually uses. The contract must cover these; must keep the per-phase structure with copy-pasteable /orchestrate Run blocks and task batches; and must drop the lengthy header, introduction and narrative description, which duplicate README.md and do not serve the user.
2. Add two modes to scripts/roadmap-integration.sh, which today has only parse-only and --annotate: a regenerate mode that rebuilds the phase/batch structure wholly from the wave data, and a prune mode that removes completed tasks and drops a whole batch or phase once every task in it is complete.
3. Specify which content is authored and which is generated. ONLY the short per-phase/per-batch description of what the phase accomplishes is authored; everything else is derived.

REUSE, DO NOT REBUILD. This is a wiring job, not a generator-building job:
- Wave derivation already exists: compute_waves (scripts/generate-task-order.sh line 393, Kahn's algorithm) and generate_wave_table (line 708), which already emit "Wave | Tasks | Blocked by | Topics". `generate-task-order.sh --print` emits that table read-only and was verified working. roadmap-integration.sh must CONSUME that output. Do NOT write a new wave or DAG implementation, and do NOT modify generate-task-order.sh: that file is in task 271's file_scope, and consuming rather than modifying is precisely what keeps this task free of any dependency on 271.
- Preserving authored prose across regeneration already exists: read_existing_goal (generate-task-order.sh line 905) reads the existing **Goal** line out of TODO.md and retains it unless overridden. Copy that mechanism for the authored per-phase descriptions.
- orchestrate-cycle-plan.sh and orchestrate-batch-admit.sh also compute eligibility and in-batch ordering from the same dependencies[] data. Check any new logic against them for duplication before writing it.

Research must settle the remaining details and is explicitly directed to AVOID NEEDLESS COMPLEXITY: prefer reusing and extending what exists over introducing new machinery. Open questions include where held and user-only tasks live in a generated structure (the hand-written roadmap had a Phase 0 of user-only owner decisions and a wholly-held phase, neither of which appears in the wave table), and whether the cut lines and risk table survive at all.

RESPONSIBILITY SPLIT, implemented by the two dependent tasks: /todo prunes; /review regenerates completely, including regenerating each phase's and batch's brief description of what it accomplishes.

---

### 304. Stop one out-of-repository pathspec entry from aborting staging for every valid path, and stop the callers sinking the script's nonzero exits, while the task still reports success
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 184, Task 263, Task 273, Task 284, Task 285, Task 302

**Description**: Make an out-of-repository path in a commit pathspec list non-fatal for the rest of the list, so one bad entry cannot abort staging for every valid path while the task still reports success. A narrow fix with a mechanically located cause; research rules on WHERE the fix belongs and on one genuinely open design question, it does not re-litigate whether the defect is real.

== PREMISE CORRECTION (verify before accepting any framing that says otherwise) ==

This task was filed on the hypothesis that `.return-meta.json`'s `modified_files` field "has no stated contract confining its entries to repository-relative paths." **That hypothesis is FALSE and must not be carried into the research.** `context/formats/return-metadata-file.md` already states the constraint emphatically and three times over:

- "**Path form**: entries are **repo-relative** paths, relative to the repository root. This is load-bearing and must not be left implied ... Absolute paths are not permitted."
- The producer-side procedure's step 1: "append that file's **repo-relative** path".
- The procedure's restated "Field constraints" block: "**Repo-relative**, never absolute."

The source-store copy and the deployed copy are byte-identical, so this is not deploy staleness. **Documenting the contract is therefore ALREADY DONE — do not re-do it.** The defect is not underspecification. It is that nothing anywhere ENFORCES the documented contract, and the consumer's failure mode on violation is maximally destructive.

== THE SIBLING-FIELD COMPARISON (narrowing evidence, with its inference corrected) ==

In the SAME dispatch, `.orchestrator-handoff.json`'s `artifacts[]` carried **only repo-relative paths** -- verified, two entries, both `specs/154_.../...`. Meanwhile all four absolute paths were confined to `modified_files`, and they appear nowhere else that is consumed as a pathspec. So the incident is narrow and field-specific, NOT general path carelessness by the agent: it put repo-relative paths in one field and absolute paths in another.

**This exonerates the producing agent and rules out a plausible wrong diagnosis.** Do not read the incident as an agent that was sloppy about paths and needs tighter instructions.

**But the natural inference from it is BACKWARDS, and the research must not repeat it.** The tempting reading is "the sibling schema'd field already has the correct repo-relative contract, so constraining `modified_files` is merely alignment with existing precedent." Verified against the schema, that is false:

- `context/schemas/orchestrator-handoff-schema.json`'s `artifacts[].path` is documented as "**Repo-relative or absolute** path to the artifact." It **permits** absolute. It is schema'd but LOOSE.
- `modified_files` has **no schema at all** (confirmed: nothing under `context/schemas/` covers `.return-meta.json`), but its prose contract is the STRICTEST path statement in the system -- "Absolute paths are not permitted."

So the asymmetry runs the opposite way from the framing above: the field that broke is the one with the STRICTER stated contract and NO schema and NO enforcement; the field that behaved is the one with the LOOSER stated contract, a schema, and no pathspec consumer to punish looseness. `artifacts[]` got repo-relative paths by practice (artifact paths are naturally built from the task directory), not because any contract demanded it.

**Consequence for the design, and this is the load-bearing conclusion:** there is NO in-system precedent of a path field being successfully constrained by documentation. The strictest prose contract in the system was violated anyway, by an agent that was never shown it. **That is a direct argument that candidate 1 is insufficient on its own** -- stronger than the generic version, because the counter-example is this very field. Enforcement (candidate 2, or a schema with validation) is required. If research wants to cite `artifacts[]` as precedent for anything, the honest citation is: a loose contract on a field with no pathspec consumer is harmless, which is why nobody noticed the asymmetry.

== THE DEFECT (precisely located) ==

`scripts/git-commit-scoped.sh:292`, the drop-pass predicate:

    if [ -e "$p" ] || git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      # Case 1 -- matched: present on disk, or already tracked.
      filtered_pathspecs+=("$p")
      add_pathspecs+=("$p")

`[ -e "$p" ]` is a bare filesystem existence test with **no repository-containment check**. An absolute path into a DIFFERENT repository exists on disk, so Case 1 matches it, and the path is admitted to `add_pathspecs`. The existing Case 3 drop (line 311) never sees it, because Case 1 already claimed it.

Staging is then a **single all-or-nothing invocation**, line 372:

    if ! git add "${add_pathspecs[@]}"; then
      echo "WARNING: git add failed for one or more staged paths (non-blocking); no commit was attempted." >&2

`git add` treats an out-of-repository path as **fatal**, not droppable, so that one entry aborts staging for every other entry in the same call. And the failure is deliberately **non-blocking**, so the caller proceeds and the task still transitions to `completed`.

**The authors already reasoned about this exact hazard class -- for a different case.** The Case 2 comment at lines 302-307 says, verbatim, that because `git add "${add_pathspecs[@]}"` "is a single all-or-nothing invocation, that one bad entry would abort staging for every other path in the same call -- silently converting today's 'deletion dropped' bug into a louder 'whole commit aborted' bug". They applied that reasoning to already-staged deletions and built Case 2 to avoid it. Out-of-repo absolute paths are the same hazard with no corresponding guard. **This is the strongest argument that the fix belongs in the drop pass: the drop pass already exists, already has the right instinct, and merely fails to classify this one input.**

== OBSERVED DAMAGE (verified, today) ==

During a live `/orchestrate 119,122,129,151,154,159` run in `~/Projects/Logos/Verification` (session `sess_1790826682_ca5834`), task 154's implement dispatch reported **30 entries** in `modified_files`. The first 26 were correct repo-relative paths. The last 4 were absolute paths into the agent-system source store at `/home/benjamin/.config/nvim/` -- a new lean-extension context page and its three registration sites, which the dispatch had legitimately edited and included for traceability.

    fatal: /home/benjamin/.config/nvim/agent-system/extensions/lean/context/project/lean4/domain/metadata-trust-surfaces.md: '...' is outside repository at '/home/benjamin/Projects/Logos/Verification'
    WARNING: git add failed for one or more staged paths (non-blocking); no commit was attempted.
    [orchestrate] WARNING: commit failed for task 154 (non-blocking) -- proceeding to lock release.

Task 154 then transitioned to `completed`. **No commit was attempted for ANY of the 26 valid paths.** Nothing was ultimately lost only because that dispatch happened to have committed its own source incrementally across ten commits, so the residue was just the plan marker and `.return-meta.json`, recovered by hand afterwards. **A dispatch that relied on the postflight commit instead would have reached `completed` with its work entirely uncommitted.** That is the severity argument: a false green over silent non-persistence, triggered by one entry out of thirty.

== SECOND VERIFIED FINDING: THE CONTRACT IS NOT PROPAGATED TO THE PRODUCERS (THIS IS THE ROOT CAUSE) ==

Of the 13 implementation agents under `agent-system/extensions/*/agents/`, only **4** mention `modified_files` at all (`general-implementation-agent.md`, and email/nix/nvim); all 4 of those do state the repo-relative constraint. The other **9 never mention the field** -- including `agent-system/extensions/lean/agents/lean-implementation-agent.md`, the exact agent that produced the 30-entry list above. They emit the field with no instruction about it, inheriting the contract only if they happen to load the format spec. There is also **no JSON schema** for `.return-meta.json` anywhere under `context/schemas/`, so no mechanical validation of the field exists at any point.

**This is the ROOT CAUSE of the observed incident, and it explains it completely.** The constraint existed; the agent that produced the offending 30-entry list was never told it. Nothing further is needed to account for the defect.

**Propagation to those 9 agents is OUT OF SCOPE here and should be a follow-up task** -- it is a 9-file producer-side surface, and excluding it is a scope judgment, NOT an overlap dodge (those 9 files carry no competing declarations found in this survey). **That follow-up is NOT a nice-to-have: it is the root-cause remediation, and this task is the containment.** Whoever triages it should treat it with the severity that implies, not as documentation tidying. Recorded here so it is filed against evidence rather than rediscovered.

It also reinforces why the consumer-side fix is needed REGARDLESS of propagation: until every producer is told the rule, the field will keep carrying violations, so the consumer must be robust to them.

**The producing agent's behaviour was reasonable against what it was actually given -- not against the contract.** State the distinction precisely, because the looser version invites the wrong fix: the agent DID violate a documented constraint, so this is not a case of defensible divergence from a rule it had seen. It is a case of an agent reasonably recording every file it touched, across both repositories, under a field name that suggests exactly that, having never been shown the rule its own definition omits. Do not frame any part of this as an agent error to be trained away, and do not frame it as the contract being wrong either.

== THE CENTRAL QUESTION: SILENT FILTERING VS LOUD REFUSAL ==

Filtering `modified_files` to entries under the repository root BEFORE staging would have let the observed commit succeed for its 26 valid entries instead of aborting all 30. **Candidate 2 is therefore demonstrably sufficient to close the observed incident** -- this is established, not open. What remains open, and is this task's central decision, is the behavior on a filtered entry:

- **Silent filtering** recovers the valid work but HIDES that an agent produced an out-of-contract entry. The contract violation goes unrecorded and the 9 unpropagated agents keep emitting them undetected.
- **Loud refusal** surfaces the violation but MUST NOT preserve the current behavior of reporting success while staging nothing. A refusal that leaves the task at `completed` with nothing committed is strictly worse than silent filtering.

**The status quo is the worst of both options: it neither commits the valid work nor reports failure.** Any ruling must beat that bar on both axes. The likely shape is filter-and-commit paired with a loud, non-suppressible report plus a non-terminal status or an explicit operator-visible record -- but research rules on it, and must say which axis it is trading if it does not get both.

== CANDIDATE SURFACES (research RULES between these; do not presuppose) ==

1. **`git-commit-scoped.sh`'s drop pass (recommended starting hypothesis).** Add a repository-containment classification ahead of Case 1, so an out-of-repo path is dropped with a loud WARN like any other unusable pathspec instead of poisoning the single `git add`. Closes the failure at the one chokepoint every commit site shares, and is robust to any misbehaving producer. Weigh `git rev-parse --show-toplevel` comparison against `git ls-files`-based containment, and handle symlinked and `..`-containing paths.
2. **The postflight consumer** (`orchestrate-cycle-postflight.sh:1252`, and `orchestrator-postflight.sh`, which also reads the field). Filter or partition `modified_files` before it reaches the commit script. Narrower blast radius but must be duplicated at each consumer, and leaves other commit sites exposed.
3. **A separate field for cross-repository edits.** The underlying need is REAL and currently unserved: a dispatch that legitimately edits the agent-system source store has nowhere to record it, and today those edits are simply left uncommitted for an operator to stumble on. Note the dispatch in question **correctly declined to commit them itself**, because that repo had concurrent in-flight work. Rule on whether to add such a field (and who consumes it) or to state explicitly in the format spec that cross-repo edits are out of `modified_files`'s remit and must be reported in prose.

**A design that does only the documentation half must be challenged** -- the contract is already documented (see PREMISE CORRECTION) and documentation alone demonstrably did not prevent this. At least one of (1) or (2) must land.

**Also rule on the non-blocking policy.** A commit that stages nothing, reports a WARNING, and lets the task reach `completed` is the "false green" direction of wrong. Research should decide whether a staging failure that results in ZERO files committed deserves to be blocking (or at minimum to force a non-terminal status), and must RECORD its reasoning rather than flip the policy silently. Changing the global non-blocking policy is a larger decision owned by other work on these files -- recommend rather than unilaterally impose, and if the ruling is "report only", say so explicitly.

== DISTINCTNESS FROM ALREADY-FILED TASKS (verified by reading their file_scope and titles) ==

- **Task 277** (`not_started`) -- "Make an unresolvable pathspec a hard error in git-commit-scoped.sh instead of a silent WARN-and-drop". **Closely adjacent, and the relationship is tighter than first assumed:** 277 changes the behavior of Case 3, the very drop pass this task must extend with a new classification. Not duplicate -- 277 is about an UNMATCHED path currently being dropped too quietly, this task is about an OUT-OF-REPO path not being dropped at all and killing the whole `git add`. But they edit the same block, and the orders interact: if 277 lands first and makes every drop a hard error, this task must decide whether an out-of-repo path is a hard error too (defensible) or the one case that stays a warn-and-drop (also defensible, since the operator may legitimately have cross-repo paths). **This dependency edge is load-bearing, not merely a serialization formality.**
- **Task 302** (`not_started`) -- bare `-- specs/` directory pathspec over-staging concurrent sessions' files. Different mechanism (over-broad pathspec vs. out-of-repo pathspec), different call sites (command/skill definitions vs. the commit script itself).
- **Task 303** (`not_started`) -- `validate-state.sh`'s CWD-relative state-file default. Unrelated beyond both being path-resolution bugs.

All three are distinct failures of the same subsystem. **Do not merge them.**

== DECLARED FILE_SCOPE OVERLAPS (declared honestly; nothing trimmed to dodge the check) ==

This task's `file_scope` collides with seven live tasks, enumerated so no reader has to re-derive them:

- `scripts/git-commit-scoped.sh` + `scripts/tests/test-git-commit-scoped.sh` -> **277** (load-bearing, see above).
- `context/formats/return-metadata-file.md` -> **263** (consent-gated git push).
- `scripts/orchestrate-cycle-postflight.sh` -> **184, 263, 273, 279, 284, 285**.
- `scripts/tests/test-orchestrate-cycle-postflight.sh` -> **184, 263, 273**.

Only the **277** edge is semantically load-bearing. The other six are pure serialization edges under `context/patterns/file-footprint-overlap.md` -- the regions do not touch, so any order merges cleanly. **An operator who wants this fix sooner should REORDER these edges, not drop a path from `file_scope`.** Both postflight scripts are retained in scope because candidate surface (2) cannot be evaluated without them; if research rules for surface (1) alone, the postflight entries simply go unused and that is the correct outcome, not a mis-declaration.

Six live tasks contending on `scripts/orchestrate-cycle-postflight.sh` is itself a signal worth an operator's attention.

== EXPLICITLY OUT OF SCOPE ==

- Re-documenting the repo-relative constraint in `return-metadata-file.md`. Already present, three times. (Correcting that section's reference to `orchestrator-postflight.sh` so it also names `orchestrate-cycle-postflight.sh`, the batch-engine consumer, IS in scope -- it is a one-line accuracy fix in a section this task already touches.)
- Propagating the constraint to the 9 silent implementation agents. Verified above; follow-up task.
- Adding a JSON schema for `.return-meta.json`. Verified absent; a larger piece of work.
- Flipping the global non-blocking-commit policy. Recommend with reasoning; do not impose.

== ACCEPTANCE ==

1. A pathspec list containing one absolute path outside the repository, mixed with N valid repo-relative paths, results in the N valid paths being **committed**, and the offending entry reported loudly by path. The whole-list abort is gone.
2. The behavior in (1) is covered by a case in `scripts/tests/test-git-commit-scoped.sh` constructed so it **cannot pass vacuously** -- it must fail against the pre-fix script. Assert on committed CONTENT (the N paths are in the resulting tree), not merely on exit code.
3. Existing `git-commit-scoped.sh` behavior is preserved for every other input class: `:(exclude)` entries, Case 2 already-staged deletions, Case 3 genuinely unmatched paths, and the V3 exclude-only refusal. Regression-test these -- Case 2 especially, since it shares the all-or-nothing `git add` reasoning and is the property most at risk from a careless fix.
4. A path inside the repository but given as an ABSOLUTE path continues to work (it is a legal `git add` argument today); the fix must distinguish "absolute" from "outside the repository" and not break the former. State the chosen predicate explicitly.
5. The cross-repository-edit question (surface 3) is RULED ON in the report: either a field/mechanism is specified, or the format spec states that such edits are outside `modified_files` and names what an agent should do instead.
6. The non-blocking-policy question is ruled on in the report with reasoning, whether or not code changes.
7. The silent-filtering-vs-loud-refusal decision is stated in the report, and the chosen behavior is shown to beat the status quo on BOTH axes (valid work committed AND the violation reported). If only one axis is achieved, the report says which was traded and why.
8. `bash scripts/tests/test-git-commit-scoped.sh` passes in full, and `scripts/verify-deploy.sh` passes.

== ADDED SCOPE: THE EXIT-CODE SINK AT EVERY CALLER (now a live, landed concern) ==

The hard-error refusal this task's sibling work introduced has LANDED: `git-commit-scoped.sh` now has a V6 gate that exits **4** when at least one pathspec was dropped AND the resulting commit would be empty, printing a loud `ERROR:` naming every dropped path. Verified in the source store, with regression cases T11/T12/T13 and a documented exit-code table (0-4) plus V2/V3/V5/V6 gate labels in `context/standards/git-staging-scope.md`.

That work deliberately did NOT change any caller, and recorded the reason as an explicit residual. This task inherits it, because the residual is precisely this task's own failure mode:

**Every caller wraps the script as `cmd || echo "WARN: ...(non-blocking)"`, which collapses ANY nonzero exit to 0 for the caller's control flow.** So a new exit code in the script alone is NECESSARY BUT NOT SUFFICIENT: V6 can fire, print its loud error, and the caller will still proceed and let the task transition to `completed`. That is the same "the task still reports success" shape named in this task's own title, reached by a second route.

Rule on, and record with reasons:

- **Which callers must branch on the exit code, and on which codes.** The live script callers are `scripts/orchestrate-cycle-postflight.sh` and `scripts/orchestrate-unwind-dispatch.sh` (`scripts/orchestrator-postflight.sh` is confirmed orphaned with no live callers -- confirm that still holds before either fixing or skipping it). Beyond those, roughly 50 documented bash snippets across core and extension skills/agents share the canonical call shape, so a blanket "every caller branches" ruling has a real cost that must be weighed rather than assumed.
- **Whether exit 4 and exit 2 deserve the same treatment.** Exit 2 (usage error / V3 degenerate-pathspec refusal / `git add` failed) is also currently sunk by `|| echo WARN`, and the `git add` failure is the exact mechanism in this task's OBSERVED DAMAGE section. Decide whether the fix is per-code or a single "any nonzero except 1 is fatal" rule. Exit 1 must remain non-fatal: it is the legitimate "nothing to commit" case and is indistinguishable from a benign no-op by design.
- **Where the branch belongs.** A `$?`-specific branch at ~50 call sites is a different change from a single branch inside the two live script callers plus a documented convention for the snippets. Prefer the narrow mechanical fix plus an enforcement lint over editing 50 prose snippets by hand, unless research shows the snippets are themselves executed rather than copied.

HARD CONSTRAINT: do not make a commit failure fatal in a way that can strand an orchestration mid-batch. The non-blocking posture exists so one task's commit problem does not abort its siblings. The fix must make the failure VISIBLE and ATTRIBUTABLE -- surfaced into the task's own outcome and status rather than swallowed -- not simply convert a silent success into a hard abort. If a task's commit genuinely failed, the honest outcome is a `[PARTIAL]` with a named blocker, never `[COMPLETED]`.

Read `context/standards/git-staging-scope.md`'s exit-code table before planning; it is the current contract and this task must extend it, not contradict it.

---

### 303. Make validate-state.sh resolve its omitted-argument state-file default against the repository being validated, not the current working directory
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 271

**Description**: Make `validate-state.sh`'s omitted-argument state-file default resolve against the repository being validated rather than the current working directory, and survey sibling scripts for the same latent pattern. A narrow, verified fix with a known mechanism — research confirms the resolution strategy and the survey, it does not re-litigate whether the defect is real.

== THE DEFECT (precisely located) ==

`scripts/validate-state.sh:241-243`:

    if [[ -z "$STATE_FILE" ]]; then
      STATE_FILE="specs/state.json"
    fi

A bare relative path, so the default resolves against the invoking shell's CWD. The script's own header documents this at line 41 ("STATE_FILE defaults to specs/state.json relative to the current working directory when omitted"). Invoking the validator from one repository while LOADING the script from another repository's deploy therefore silently validates the WRONG repository's state and reports findings belonging to a completely different repository.

**The deliberate design this fix must NOT break.** Header line 14 asserts the script is "Deliberately argument-relative, not PROJECT_ROOT-relative: this script takes a state-file path" — and the body honors that throughout: the sibling `TODO.md`, the sibling `archive/state.json`, and the `--fix` writer's `state-write.sh` candidate search are all located relative to `STATE_FILE`'s own directory (lines 274, 716, 326), not relative to `PROJECT_ROOT`. That argument-relative design is correct and intentional; it is what lets the script validate archive and vault targets. The defect is ONLY the DEFAULT applied when the argument is omitted. The fix is therefore scoped to that default — do not convert the script to PROJECT_ROOT-relative resolution throughout.

**Interface correction, verified:** `validate-state.sh` has NO `--state` flag. The override is a bare POSITIONAL `STATE_FILE` argument (argument parser default case, line 215). `--state` belongs to `generate-todo.sh`, which `validate-state.sh` invokes internally at line 725. Any report or acceptance criterion written against a `--state` flag on this script is wrong; do not add one without a reason beyond this task.

== CANDIDATE FIXES (research rules between them; all three are legitimate) ==

1. Resolve the default from the git toplevel of the CWD, so a repo-relative default still lands in the repo the caller is standing in.
2. Resolve the default from the script's own location via `lib/common.sh`'s `common_repo_root "$SCRIPT_DIR" 2` (already the documented idiom for `scripts/` callers; `SCRIPT_DIR` is computed at line 147 but is not used for the default today). This makes the default name the repo whose deploy the script came from — note this is NOT the same answer as (1) under cross-repo invocation, and choosing between them IS the design decision.
3. Refuse (exit 2) when the argument is omitted and the CWD-relative and script-relative candidates disagree, naming both. Fails loud rather than guessing.

Whichever is chosen, the resolved path MUST be echoed in the existing `Validating state file: $STATE_FILE` banner (line 408) as an ABSOLUTE path, so a false finding is self-diagnosing. In the incident below, printing the resolved path is exactly how the problem was found.

== OBSERVED DAMAGE (verified, today) ==

A dispatched agent with its shell CWD in `/home/benjamin/Projects/Logos/Verification` but loading the generator from the `/home/benjamin/.config/nvim` deploy reported a `TODO.md is OUT OF SYNC with specs/state.json` FAILURE (Check at line 729) against the nvim repo. No such failure existed. It was reading Verification's state — a repo legitimately mid-`/orchestrate` with drifted files. The agent caught it only by probing the validator to print its resolved paths, then re-ran with an absolute positional STATE_FILE and got 0 failures / 17 passed / 7 warnings.

**The failure mode is a false POSITIVE attributed to the wrong repository**, which is the dangerous direction: it invites someone to "fix" a repo that is not broken. This is the motivating severity argument — a false negative would merely be missed coverage.

== WHY A TASK AND NOT A NOTE ==

Cross-repo invocation is NORMAL in this architecture: one source store deploys into many consumer repos, and dispatched agents routinely run with CWD in one repo while a script resolves from another. Any script sharing this resolution pattern carries the same latent bug.

**Part (b) — survey, REPORT, do not necessarily fix.** A first pass over `scripts/*.sh` for a bare relative `specs/{state.json,TODO.md,errors.json,events.jsonl}` default already finds siblings:
- `scripts/command-gate-out.sh:63` — `state_file="specs/state.json"`, and `:87` — `task_dir="specs/${padded_num}_${project_name}"`
- `scripts/git-snapshot.sh:248, 332, 337` — bare `specs/state.json` in the task-inference and `file_scope`-read paths; note `:250` and `:333` already print `(cwd: $(pwd))` in their failure messages, which is the right instinct but does not prevent reading the wrong repo
- `scripts/command-gate-in.sh:65`, `scripts/orchestrate-build-dispatch.sh:213` — same literal, context to confirm
- `scripts/init-specs.sh:101-125` — CWD-relative BY DESIGN (it bootstraps `specs/` into the repo the caller is standing in). Confirm and exclude; do not "fix" it.

Report every sibling with a per-site verdict (same defect / by design / needs its own task). Remediate ONLY `validate-state.sh` here. Siblings live under directories declared wholesale by other tasks (270 declares `scripts/` and `scripts/lib/`), so fixing them inside this task would force avoidable serializing edges — recommend a follow-up task instead.

== DECLARED FILE_SCOPE OVERLAP WITH TASK 279 (declared honestly, not dodged) ==

Task 279 ("Reconcile state-schema.json with the live fields the orchestrator reads", `planned`) already declares BOTH `scripts/validate-state.sh` and `scripts/tests/test-validate-state.sh` in its file_scope — for a DIFFERENT change: adding `research_questions` to the hand-maintained `KNOWN_ENTRY_FIELDS` array (279's plan line 157), with a regression fixture (line 272) and a bidirectional schema/validator drift test (line 279). Grepping 279's plan for CWD or path-resolution language returns nothing, so 279 does NOT cover this defect and this is not duplicate work.

Task 271 ("Finish the parent_task edge", `not_started`) also declares both files, again for a `KNOWN_ENTRY_FIELDS`/schema change.

Both are genuine footprint collisions on the same two files. Declared as `dependencies: [271, 279]` rather than hidden, and `validate-state.sh` is deliberately NOT dropped from this task's file_scope to dodge them. Sequencing rationale: 271 and 279 both edit the `KNOWN_ENTRY_FIELDS` data array and the schema; this task edits the argument-resolution block (lines 241-243) and the banner (line 408). The regions do not touch, so either order merges cleanly — the edges exist to serialize the edits, not because the changes conflict semantically. **This task does NOT touch `KNOWN_ENTRY_FIELDS` or `context/schemas/state-schema.json`.**

== EXPLICITLY OUT OF SCOPE ==

The `research_questions` / `KNOWN_ENTRY_FIELDS` schema-validator drift. Task 279 owns it with an explicit checklist item, a regression fixture, and a bidirectional drift test. Verified — do not re-file or re-implement it.

== ACCEPTANCE ==

1. Invoking `validate-state.sh` with NO positional argument, from a CWD in a DIFFERENT repository than the one the script was loaded from, either validates the intended repository or refuses loudly naming both candidates. It never silently validates the other repo.
2. The `Validating state file:` banner prints an absolute resolved path.
3. An explicit positional `STATE_FILE` continues to behave exactly as today, including the argument-relative location of the sibling `TODO.md`, the sibling `archive/state.json`, and the `--fix` `state-write.sh` candidate search. Regression-test this — it is the property most at risk from a careless fix.
4. `scripts/tests/test-validate-state.sh` gains a case for the cross-repo omitted-argument invocation, constructed so it cannot pass vacuously (it must fail against the pre-fix script).
5. `bash scripts/tests/test-validate-state.sh` passes in full; `scripts/verify-deploy.sh` gate 10 (`--deep`, the only production `--deep` caller) still passes.
6. The sibling survey is recorded in the task report with a per-site verdict.
=== ADJACENT WORKED PRECEDENT (2026-10-04) ===

A defect of the same family was found and fixed in
`agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`: it resolved its
repository root by a fixed number of `..` hops, which is correct from the source store
(`agent-system/extensions/core/scripts/tests`) but overshoots to `$HOME` from the deployed tree
(`.claude/scripts/tests`) that `run-all.sh` actually invokes. The suite exited 2 on a path that
never exists, so the gate it guards went entirely unexercised and its failure was recorded in
`known-failures.txt` under a mis-diagnosed reason.

Two transferable conclusions for this task:

1. `scripts/lib/common.sh`'s `common_repo_root()` is NOT a fix for this family. It takes a caller-
   supplied hop count, so it is the same layout-dependent arithmetic behind a function call; a
   caller runnable from two layouts of different depths cannot pass one correct value.
2. The remedy that worked is UPWARD MARKER DISCOVERY: walk up from the script's own directory
   until a directory containing a known marker is found (there,
   `agent-system/extensions/core`), and fail loudly with the probed start directory if the walk
   reaches `/`. That is layout-independent and was verified to yield the same root from both the
   source-store and deployed locations.

Consider whether this task's own remedy should be the same discovery technique, and whether
`common_repo_root()` should gain a marker-based mode rather than every caller re-deriving one.

---

### 302. Pass --task at commit-staging sites to engage the contended-path lease, and rule on the task-scoped pathspec carve-out
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 300

**Description**: Pass `--task` at every commit-staging site so `git-commit-scoped.sh`'s contended-path lease is actually consulted, and rule on whether the sanctioned task-scoped directory pathspec carve-out should be narrowed. This task was originally two halves; HALF 1 IS NOW DONE and must not be re-done.

== SCOPE CORRECTION: HALF 1 IS COMPLETE (verify before planning anything) ==

The original task had two halves. Half 1 -- replacing the bare `-- specs/` DIRECTORY pathspec at commit-staging sites with explicit file lists -- has been implemented and landed. Verified directly in the source store:

- `grep -rn -E -- '--[[:space:]]+specs/([[:space:]]|$|\\)' agent-system/extensions/` now returns only the deliberate negative-case fixtures inside `scripts/tests/test-lint-directory-pathspec-boundary.sh`. Every real staging site is fixed.
- The fix covered 19 sites across 11 files (2 more than the 17/9 originally measured here; `context/standards/git-safety.md` and `memory/skills/skill-learn/SKILL.md` were found by the new lint's own full-tree run).
- `commands/todo.md`'s 7 sites -- flagged in the original description as "the genuinely interesting case" because an archival sweep touches a set not enumerable in advance -- were resolved with a `stage_paths` bash-array accumulator, which is the "enumerate from the archival manifest the command already computes" ruling the original description anticipated. That ruling is made and implemented; do not reopen it.
- A new lint, `scripts/lint/lint-directory-pathspec-boundary.sh`, now mechanically forbids regression, with a 14-case fixture test. (Wiring it as a `verify-deploy.sh` gate is a separate task.)

DO NOT re-audit the pathspec shape of those sites, and do not re-litigate the per-site rulings. If research finds a bare directory staging pathspec that the lint does not catch, that is a lint defect to report, not this task's work.

== WHAT REMAINS: HALF 2 -- THE LEASE WAS NEVER CONSULTED ==

`git-commit-scoped.sh` already implements the mechanism that prevents cross-session commit bleed: `--task <task_number>` (opt-in, empty-value-skips-flag, fails open unconditionally) consults the cycle-scoped contended-path manifest (`specs/.contention-manifest/*.json`) for each POSITIVE pathspec entry, claims each listed path via a first-claim lease (`specs/.contention-claims/<path>`), and REFUSES before any `git add` (exit 3) when another live task holds a path.

Verified current state: `--task` is passed only by the SCRIPTS (`orchestrate-cycle-postflight.sh`, `orchestrator-postflight.sh`, `git-commit-scoped.sh`'s own tests) and by `memory/skills/skill-learn/SKILL.md`. It is passed by NONE of the recipe sites -- `skills/skill-git-workflow/SKILL.md`, `commands/task.md`, `commands/todo.md`, `agents/meta-builder-agent.md`, `skills/skill-meta/SKILL.md`, `epidemiology/commands/epi.md`, `present/commands/grant.md`, `present/commands/slides.md`, `present/commands/timeline.md`.

So the mechanism did not fail; it was never consulted. This is the same systemic shape the worktree-isolation removal verdict already records about an absent `file_scope` ("The guard did not fail; it was never consulted"). That is the argument for auditing commit sites for the missing `--task`, and it survives Half 1's completion intact -- narrowing the pathspec reduced the blast radius of a collision but did nothing to make the lease run.

Rule per site, do not blanket-add: a recipe that commits only its own task's artifacts may have nothing contended to claim, in which case `--task` is harmless but inert, and the honest ruling may be "add it for uniformity" or "document why it is unnecessary here". Decide with reasons.

== ALSO IN SCOPE: THE SANCTIONED TASK-SCOPED CARVE-OUT ==

The new lint deliberately EXEMPTS a task-scoped directory token (one carrying a `${...}` interpolation or an `{N}`/`{NNN}` placeholder, e.g. `specs/{padded}_{slug}/`) while flagging a shared one (`specs/`). That carve-out is not arbitrary: `context/standards/git-staging-scope.md` explicitly sanctions `specs/{padded}_{slug}/ "${ephemeral_excludes[@]}"` as the canonical per-operation scope, and without the carve-out the lint would flag roughly 25 sanctioned sites and be un-greenable.

The open question, recorded as a follow-up when the lint shipped: should those ~25 task-scoped-directory sites be narrowed to explicit file lists too? Arguments to weigh, not assume:

- A task-scoped directory pathspec still over-stages WITHIN one task's own directory, which is exactly how a concurrent in-place plan revision or a sibling's artifact write could be swept in.
- But it is confined to one task's own territory, so the cross-session bleed that motivated Half 1 does not apply, and `git-commit-scoped.sh` already injects `:(exclude)` entries for the canonical ephemeral-runtime-file candidate set for exactly these directories.

Produce a ruling with reasons. "Leave the carve-out as-is, and record why" is a legitimate and possibly correct outcome -- but it must be argued from the exclude-injection behavior, not asserted.

== CLOSE BY ==

Demonstrate that a `--task`-engaged recipe site actually refuses on a contended path (exit 3) rather than merely accepting the flag, so the wiring is proven live and not just present in the text.

All edits land under `agent-system/extensions/` per `.claude/rules/source-store-deploy-boundary.md`, never under `.claude/**`.

SCOPE NOTE: none of the recipe files in `file_scope` is an orchestrator-critical path, so this task does NOT trip the self-modification admission gate -- keep it that way; do not widen `file_scope` to include `git-commit-scoped.sh` or any critical path. If the ruling requires a change to `git-commit-scoped.sh` itself, record it as a follow-up instead.

== HALF 1 INTRODUCED A REGRESSION, NOW TRACKED AS TASK 322 ==

Recorded here because this task's HALF 1 (declared complete above) is the confirmed cause, and because this task edits both files the fix touches.

Replacing the bare `-- specs/` directory pathspec with explicit file lists was correct for the cross-session-bleed reason documented above, but at a RENAME site a directory token had been covering both endpoints incidentally. The explicit lists only ever collected move DESTINATIONS, so the vacated source paths stopped being staged. In `commands/todo.md` this left all three directory-move sites (lines 665, 686, 752) committing the archive copy as a fresh `create mode` while the old tree's deletion stayed unstaged -- measured live at 173 unstaged ` D` entries after one 15-task archival run, plus a wrong `phantom_paths: 109` baked into `state.json`'s `repository_health`.

Task 322 owns that fix. It also lands a named rename rule in `context/standards/git-staging-scope.md` -- a file THIS task also declares -- so expect serialization there, and do not re-derive the rule independently.

GENERAL LESSON FOR THE REMAINING HALF 2 RULING: when ruling on whether the sanctioned task-scoped directory carve-out should be narrowed, treat renames as a first-class case. A directory pathspec covers both endpoints of a `mv` by construction; any explicit list replacing it must name both endpoints explicitly. Narrowing the carve-out without that rule in hand risks reproducing this same regression at whatever sites the ruling converts.

---

### 300. Resolve AskUserQuestion's unreachability in dispatched subagents: verify the mechanism, correct the frontmatter standard's tool-inheritance claim, and rehome every user-choice gate
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [300_askuserquestion_unreachable_in_subagents/reports/01_askuserquestion-subagent-reachability.md]
- **Plan**: [300_askuserquestion_unreachable_in_subagents/plans/01_rehome-askuserquestion-gates.md]

**Description**: Resolve the fact that `AskUserQuestion` is not reachable from a dispatched subagent on this harness: verify the mechanism by direct probe, correct `agent-frontmatter-standard.md`'s tool-inheritance claim to match measured behaviour, and rehome every user-choice gate that currently sits inside a dispatched agent. The same pass settles one further unmeasured row of that same standard's optional-field table -- `isolation` -- which is documented as supported while the prohibition that fenced it off is gone (MEASUREMENT 7).

== THE OBSERVED FAILURE ==

In a live `/meta` prompt-mode dispatch, the dispatched `meta-builder-agent` could not call `AskUserQuestion`. It therefore could not run `/meta`'s MANDATORY confirmation gate, and routed the gate to the parent session via `SendMessage`; the parent asked the user with `AskUserQuestion` and relayed the answer back. That workaround produced a correct outcome, but nothing in the agent file or the skill anticipates or documents it.

== MEASUREMENTS (taken directly; each states its probe) ==

All path counts below were measured over `~/.config/nvim/agent-system/extensions/` on 2026-09-30/10-01. Directory totals shift as extensions are added -- re-measure before relying on a count, and treat the file lists rather than the integers as the durable part.

MEASUREMENT 1 (tool reachability, direct probe, two independent observations).
Probe: inside a dispatched `meta-builder-agent` subagent, call `ToolSearch` with query `select:AskUserQuestion`.
Result: `No matching deferred tools found`. Additionally, the subagent's own deferred-tool system-reminder enumerated roughly 50 deferred tools (`ArtifactComments`, `ArtifactData`, `CronCreate`, `EnterWorktree`, `Monitor`, `NotebookEdit`, `SendMessage`, `TaskStop`, `WebFetch`, `WebSearch`, plus the MCP tool families) and `AskUserQuestion` was absent from that list.
Note a CORRECTION to the first report of this failure: that report characterised `ToolSearch` as returning "only SendMessage". That phrasing is imprecise. The measured behaviour is that a large deferred-tool set IS available and `AskUserQuestion` specifically is not in it. The distinction matters, because it rules out "the subagent has almost no tools" and points at per-tool withholding instead.
STILL UNVERIFIED, and the task's FIRST obligation: whether the withholding is categorical for every dispatched subagent regardless of frontmatter. Both observations so far are of ONE agent (`meta-builder-agent`) with NO `tools:` line. Do not let research or the plan inherit this description's reading of the cause. Establish by direct test: (a) does a `tools:` allowlist that names `AskUserQuestion` expose it (the `literature-agent` form below is the natural probe subject); (b) does `disallowedTools:` omission behave differently from `tools:` omission; (c) does a `subagent_type` registered with "All tools" differ from a restricted one; (d) does it differ between a fork (`context: fork`) and a plain `Agent` dispatch. Record the measured answer with the exact probe used, and let the remediation follow from it.
THE SCOPE OF THIS OBLIGATION IS THE FULL OPTIONAL-FIELD TABLE, NOT ONLY `tools:`/`disallowedTools:`. The probe matrix this task must build is the natural -- and only cheap -- place to settle every row of `agent-frontmatter-standard.md`'s Supported Fields table that asserts harness behaviour nobody has measured. Probe: `awk '/^## Supported Fields/,/^## Optional Fields/' agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md | grep '^| `' | awk -F'|' '$4 ~ /No/' | wc -l`. Result: 14 optional (Required=No) rows as currently written -- `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `effort`, `isolation`, `color`, `initialPrompt`. (An earlier statement of this fold-in put the count at 13; 14 is the figure measured here by the probe above. Re-measure rather than citing either -- the row NAMES, not the integer, are the durable part.) Of these rows, `isolation` is MANDATORY to resolve, for the reason MEASUREMENT 7 records. The specific question to answer for it: does the harness honour `isolation` from an agent-definition frontmatter block AT ALL, as opposed to only as an `Agent` tool-call parameter? Record the exact probe used, and mark the answer unverified if the probe cannot settle it. The remaining rows are OPPORTUNISTIC: settle whatever the matrix settles for free, explicitly mark the rest unverified, and do NOT let them expand the task.

MEASUREMENT 2 (frontmatter census).
Probe: `find . -path '*/agents/*.md' -type f | wc -l`, and an awk scan of each file's YAML frontmatter block for a `tools:` key.
Result: 76 agent files in the source store. Exactly TWO declare a `tools:` line at all: `core/agents/spawn-agent.md` (`tools: Read, Write, Glob, Grep, Bash(jq:*)`) and `literature/agents/literature-agent.md` (`tools: Bash, Read, Write, Edit, AskUserQuestion`).
(The first report of this gap said 74 files; 76 is the figure measured here. Re-measure rather than citing either.)

MEASUREMENT 3 (which agents promise the tool).
Probe: `grep -rl 'AskUserQuestion' --include='*.md' . | grep '/agents/'`.
Result: 24 agent files reference `AskUserQuestion` in their bodies. 23 of them declare NO `tools:` line:
  core/agents/meta-builder-agent.md
  cslib/agents/cslib-vet-agent.md
  epidemiology/agents/epi-implement-agent.md
  epidemiology/agents/epi-research-agent.md
  founder/agents/analyze-agent.md
  founder/agents/deck-planner-agent.md
  founder/agents/deck-research-agent.md
  founder/agents/finance-agent.md
  founder/agents/financial-analysis-agent.md
  founder/agents/founder-spreadsheet-agent.md
  founder/agents/legal-analysis-agent.md
  founder/agents/legal-council-agent.md
  founder/agents/market-agent.md
  founder/agents/meeting-agent.md
  founder/agents/project-agent.md
  founder/agents/strategy-agent.md
  present/agents/budget-agent.md
  present/agents/funds-agent.md
  present/agents/pptx-assembly-agent.md
  present/agents/slide-critic-agent.md
  present/agents/slides-research-agent.md
  present/agents/slidev-assembly-agent.md
  present/agents/timeline-agent.md
The single exception is `literature/agents/literature-agent.md`, whose allowlist names the tool. If verification shows the harness never exposes it to a subagent, that declaration is inert AND it additionally narrows that agent to an allowlist it cannot fully use -- a second, separate defect to fix in the same pass. (Note `literature-agent.md`'s own body describes `/literature` as a DIRECT-EXECUTION architecture, so whether that file is ever dispatched as a subagent at all is itself worth establishing before deciding what its allowlist should say.)

MEASUREMENT 4 (the standard's claim).
Probe: `grep -n 'inherit the full tool set' core/docs/reference/standards/agent-frontmatter-standard.md`.
Result: the claim appears twice -- in the field table at line 39 ("Omit to inherit the full tool set.") and in the "`tools:`, `disallowedTools:`, and `mcpServers:` Semantics" section at lines 71-72 ("Omitting the field means the agent inherits the full available tool set.").
`meta-builder-agent.md`'s frontmatter is exactly `name`, `description`, `model: opus` -- it omits `tools:`, so by the standard's own rule it inherits everything, `AskUserQuestion` included. It did not. EITHER the standard's claim needs a stated exception for tools the harness withholds from subagents, OR the inheritance is being broken somewhere the standard does not describe. Whichever verification establishes, the standard must end up stating it explicitly, because all 23 files in Measurement 3 are written on the strength of that sentence.
This measurement's ownership of the file is what makes MEASUREMENT 7's `isolation` row this task's business rather than a new task's: same file, same defect class.

MEASUREMENT 5 (blast radius is NARROWER than a raw grep suggests -- the task must say so explicitly).
Probe: `grep -rl 'AskUserQuestion' --include='SKILL.md' .`, then for each hit `grep -m1 -E '^agent:'` and `grep -m1 -E '^context:'`.
Result: 28 SKILL.md files mention the tool, but only THREE declare an `agent:` line, i.e. fork to a subagent:
  core/skills/skill-meta/SKILL.md            -> agent: meta-builder-agent
  present/skills/skill-slide-critic/SKILL.md -> agent: slide-critic-agent   (context: fork)
  present/skills/skill-slide-planning/SKILL.md -> agent: slide-planner-agent (context: fork)
The other 25 are direct-execution skills running in the primary session, where the tool works fine. They are NOT affected and MUST NOT be churned. Scoping the fix to every file that merely greps positive would be wrong.
Two nuances inside that set of three:
  - `slide-planner-agent.md` does NOT itself reference `AskUserQuestion` (it is absent from Measurement 3's list), yet its skill does. Determine where that skill expects the asking to happen before changing either file.
  - `core/skills/skill-spawn/SKILL.md` and `core/skills/skill-fix-it/SKILL.md` mention the tool with no `agent:` line. Research should check whether they interact with a dispatched agent in practice before classing them as unaffected.

MEASUREMENT 6 (a constraint that bites remediation option 1 directly -- not in the original report).
Probe: `sed -n '1,6p' core/skills/skill-meta/SKILL.md`.
Result: `skill-meta`'s frontmatter reads `allowed-tools: Agent, Bash, Edit, Read, Write`. `AskUserQuestion` is NOT in skill-meta's own allowlist either. So "move the interview into the skill" is not a pure relocation: `skill-meta`'s `allowed-tools` must gain `AskUserQuestion` for the rehomed gate to work. Any plan choosing option 1 must include that edit, and should check the sibling skills' `allowed-tools` for the same omission.

MEASUREMENT 7 (the `isolation` frontmatter row: documented as supported, declared by nothing, fenced by nothing -- three probes, taken 2026-10-01).
Probe A: `grep -n -i worktree agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`.
Result: exactly one hit, line 50, in the Supported Fields table: `| `isolation` | string | No | Isolation mode (e.g., `worktree`) |`. The standard therefore documents a per-agent frontmatter field whose documented example value requests a git-worktree-isolated dispatch.
Probe B: `grep -rn '^isolation:' agent-system/extensions/*/agents/`.
Result: no match (exit 1). NO agent file in the source store declares the field. The row is exercised by nothing today.
Probe C: `grep -n -i isolation agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`.
Result: no match (exit 1). The Move 2 `MUST NOT` that formerly forbade forwarding `isolation`/`worktree_path` to the `Agent` tool is gone from that file. That removal was DELIBERATE, not accidental: `agent-system/extensions/core/context/config/orchestrator-context-budget.json` records dropping "the isolation/worktree_path forwarding-prohibition paragraph, now moot since no dispatch row carries those fields" as part of a 992 B reclamation against that file's byte ceiling (verified by `grep -n -i 'isolation\|worktree_path'` on that JSON, which returns the derivation string quoted here).

THE GAP THOSE THREE PROBES DESCRIBE. Per-dispatch `git worktree` isolation is removed -- `specs/decisions/worktree-isolation-removal-verdict.md` (present, verified by `ls`), reaffirmed and NOT re-openable. The removal is clean at the code level: probe `grep -rln 'dispatch-worktree.sh\|task_selected_for_worktree_isolation' agent-system/` returns nothing, so `dispatch-worktree.sh`, its two test files, and `task_selected_for_worktree_isolation()` are absent from every live file. But the frontmatter row that could re-introduce a per-dispatch worktree THROUGH THE HARNESS is still documented as supported, while the prohibition that fenced it off is gone. Two of the three defects that layer induced remain OPEN, so a re-entry would re-arm them:
  - `agent-system/extensions/core/scripts/git-commit-scoped.sh` reports false success inside a worktree: its `PROJECT_ROOT` is derived from `BASH_SOURCE[0]`, every pathspec falls through WARN-and-drop, nothing stages, exit 0. Separately tracked (task 277, narrowed to the hard-error part); cite by path and defect in anything written into the source store.
  - `agent-system/extensions/core/scripts/lake-build-guard.sh` replays records across trees. Separately tracked (task 268, [implementing]); cite by path and defect in anything written into the source store.
STILL UNVERIFIED, and this is the entire reason for folding it in here: whether the harness honours `isolation` from an agent-definition frontmatter block at all. Probe B establishes only that no agent file DECLARES it; it says NOTHING about whether a declaration would take effect. Do NOT round Probe B up to "the field is inert" -- that is exactly the unverified-reading-promoted-to-finding error MEASUREMENT 1 warns against. MEASUREMENT 1's widened obligation owns answering it.

WHY THIS TASK IS THE RIGHT HOME, NOT A NEW ONE. MEASUREMENT 4 already owns correcting `agent-frontmatter-standard.md`'s unverified claims about what the harness reads from agent frontmatter, and that file is already in this task's `file_scope`. `isolation` is the same defect class -- a table row asserting harness behaviour nobody has measured. Folding it in costs ONE additional probe subject in a probe matrix this task already has to build; a separate task would duplicate the file ownership for no gain.

== WHY IT MATTERS MOST FOR /meta ==

`core/agents/meta-builder-agent.md` does not merely use the tool, it MANDATES it and forbids the fallback:
  - "ALL user choices MUST use AskUserQuestion with the `options` parameter to render interactive checkboxes/radio buttons."
  - "Use AskUserQuestion with `options` array for EVERY user choice point (single-select or multiSelect). Never fall back to text-based option presentation."
  - "**NEVER** present choices as plain text (A/B/C or numbered lists). Always use AskUserQuestion with `options` for interactive selection."
  - It lists "AskUserQuestion - Multi-turn interview for interactive mode" among its own tools.
Its 7-stage interview is built on the tool throughout: Questions 1, 2, 3, 5, 5b and 6 are each specified "via AskUserQuestion", Stage 5 ReviewAndConfirm is the mandatory confirmation gate, Stage 4.5's topic picker has no Skip option, and dependency-validation failures are specified to re-prompt through it.

CONSEQUENCE: `/meta`'s interactive mode -- the no-argument invocation, its primary documented entry point -- cannot run as specified at all. The interview has no way to ask anything, and the agent's own instructions forbid the text fallback that would otherwise rescue it. Prompt mode survives only via the undocumented `SendMessage` relay described above.

`core/skills/skill-meta/SKILL.md` compounds it twice: line 141 specifies "**Interactive**: Run 7-stage interview with AskUserQuestion" as agent work, and line 267 lists `AskUserQuestion` under the skill's postflight MUST NOT as "User interaction is agent work" -- placing the interaction squarely on the side of the boundary where it does not work.

== RESOLUTIONS TO WEIGH, NOT PRE-DECIDE ==

Research chooses with measured evidence; this description deliberately fixes none of them.

1. REHOME THE GATES. Move every user-choice point out of the dispatched agent and into the parent session -- the skill asks before dispatch, or after dispatch on a returned proposal -- and amend the agent files to stop promising a tool they cannot call. For `/meta` interactive mode this likely means the interview runs in `skill-meta` (direct execution) with only task-writing delegated. Requires the Measurement 6 `allowed-tools` edit.
2. SANCTION THE RELAY. Make the `SendMessage`-to-parent round trip a documented pattern with its own context file, since it is already proven to work. Record its real costs honestly: it depends on a parent that is listening, and a relayed answer is one more hop at which a decision can be garbled or a peer agent's message mistaken for user approval. (The agent-teammate contract already warns that no agent message is ever user consent -- a sanctioned relay runs straight at that warning and must address it.)
3. FIX THE FRONTMATTER, if and only if verification finds a form that genuinely exposes the tool -- in which case the 23 files get the declaration and the standard documents the requirement.
4. CORRECT THE STANDARD either way. Both occurrences (field table line 39 and the Semantics section) must state whatever exception verification establishes. This is NOT optional and does not depend on which of 1-3 is chosen.
5. SETTLE THE `isolation` ROW, likewise following the measurement rather than pre-deciding it. IF verification finds the harness DOES honour `isolation` from an agent-definition frontmatter block, then the forwarding prohibition that MEASUREMENT 7's Probe C shows is gone must be re-stated in a durable NON-EAGER home. It must NOT simply go back where it was: `core/skills/skill-orchestrate/SKILL.md`'s byte ceiling is precisely why it left, and `context/config/orchestrator-context-budget.json` records that reclamation, so restoring it there would re-open a closed budget. The candidates are `agent-system/extensions/core/context/contracts/territory.md` (whose lines 136-140 already carry the working-tree-and-build isolation posture and point at the decision record) and `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture" section (line 1392). BOTH candidates are already another open task's declared edit target -- probe: `jq -r '.active_projects[] | select((.file_scope//[])[] | test("batch-orchestration-guardrails"))' specs/state.json` and the same test for `territory.md`, which return task 311 (`measured_co_scheduling_signal_and_isolation_posture`, [not_started]) whose `file_scope` names both files. The plan MUST declare that overlap explicitly rather than collide with it. IF verification finds the harness does NOT honour `isolation` from frontmatter, DROP the row from the Supported Fields table and say so with the probe that established it. Either way, the row and whatever verification establishes must end up consistent -- on exactly the same footing item 4 demands for the two "inherit the full tool set" occurrences.

PREFERENCE: prefer the option that removes the dependence over the one that documents a workaround, unless the measurement says otherwise.

== NON-GOALS FOR THE `isolation` FOLD-IN (load-bearing -- state these in the plan too) ==

- Do NOT re-open the worktree isolation verdict. It was re-opened once under new evidence and formally CONFIRMED; `specs/decisions/worktree-isolation-removal-verdict.md` is authoritative and the removal is not re-openable. Nothing in MEASUREMENT 7 or resolution 5 is licence to revisit it: the fold-in concerns a DOCUMENTATION row and a missing fence, never the decision itself.
- Do NOT restore any part of the removal layer. `dispatch-worktree.sh`, its two test files, and `task_selected_for_worktree_isolation()` stay absent, and the probe in MEASUREMENT 7 that shows them absent is an acceptance check, not a to-do.
- Do NOT widen into the two open defect tasks -- the `git-commit-scoped.sh` hard-error change and the `lake-build-guard.sh` cross-tree record replay fix. They are separately tracked and MUST NOT be edited by this task. MEASUREMENT 7 cites them only as the reason the re-entry path matters at all. Per `rules/no-task-references-in-deliverables.md`, cite them by FILE PATH AND DEFECT, never by task number, in anything written into the source store; task numbers are permitted only inside this `specs/**` description.
- Do NOT add `territory.md` or `batch-orchestration-guardrails.md` to `file_scope` now. Both are conditional on a verification outcome that has not been taken, and they belong in the plan-time narrowing -- added only if resolution 5's first branch is reached, and then with the overlap against the other open task declared.

== CONSTRAINTS ==

- SOURCE STORE ONLY. Implementation edits `~/.config/nvim/agent-system/extensions/**`; every consuming repo regenerates its own `.claude/` through the loader picker. Nothing hand-authored under `.claude/**` -- the next redeploy wipes it (`rules/source-store-deploy-boundary.md`).
- No task-number references in anything written into the source store (`rules/no-task-references-in-deliverables.md`). Cite file paths, standard section names and script names.
- Any behavioural claim about the harness in the final record must be MEASURED on this harness and state its probe, never asserted from this description. Where a claim stays unverified, mark it unverified rather than rounding it up. The "STILL UNVERIFIED" clauses under Measurement 1 and Measurement 7 are the ones that matter most.
- FILE SCOPE -- DO NOT WIDEN; NARROW IT AT PLAN TIME. This task carries the backlog's coarsest `file_scope` entry. Probe: `bash .claude/scripts/validate-state.sh --deep`. Result: `WARN Coarse file_scope declaration: project_number 300, entry 'agent-system/extensions/core/scripts/tests/' overlaps 19 distinct non-terminal task(s): 165,184,217,250,251,263,265,268,270,271,273,274,277,279,281,282,303,304,313`. That bare-directory entry MUST be replaced at plan time by the explicit test files this task will add or touch; the standing warning clearing is the signal it was done. (Counts are re-measurable; the overlap and the file list, not the integer, are the durable part.) The `isolation` fold-in adds NO net widening: its only file is `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`, which MEASUREMENT 4 already required and which is already declared in `file_scope`.
- DELIVERABLE: a fixture or probe that demonstrates the chosen remediation actually lets a user choice reach the user, in the style of the lean and typst extensions' own test suites. Landing site for a shell-level probe: `agent-system/extensions/core/scripts/tests/` (see `run-all.sh` and the existing `test-*.sh` siblings for the harness conventions).

== ACCEPTANCE DIRECTION ==

- `/meta` with no arguments completes a real interview and creates a task.
- The reachability mechanism is recorded with its exact probe, and anything unresolved is marked unverified rather than asserted.
- Both "inherit the full tool set" occurrences in `agent-frontmatter-standard.md` match measured behaviour.
- No agent file instructs an agent to call a tool it cannot call.
- `literature-agent.md`'s allowlist is correct for whatever verification establishes (including the prior question of whether it is ever dispatched as a subagent at all).
- The three fork-to-agent skills' contracts agree with where the asking now happens, and the 25 direct-execution skills are left untouched.
- A probe/fixture under `core/scripts/tests/` demonstrates a user choice actually reaching the user.
- The `isolation` row of `agent-frontmatter-standard.md`'s Supported Fields table is SETTLED BY MEASUREMENT, on one of exactly two branches: either the harness honours the field from frontmatter and the forwarding prohibition is re-stated in a NAMED non-eager home (never `skill-orchestrate/SKILL.md`) with the `file_scope` overlap against the other open isolation-posture task declared; or the row is dropped and the probe that justified dropping it is recorded. An `isolation` row left standing with no measurement behind it is a FAILURE of this task, not a deferral.
- Every optional row of the Supported Fields table is either measured or explicitly marked unverified in the standard -- no row silently retains an unmeasured behavioural claim, and the row list is re-measured at implementation time rather than taken from this description's count.
- The worktree isolation verdict is untouched; the removal layer is not partially restored (`grep -rln 'dispatch-worktree.sh\|task_selected_for_worktree_isolation' agent-system/` still returns nothing); and neither separately-tracked defect script -- `git-commit-scoped.sh`, `lake-build-guard.sh` -- is edited by this task.
- `file_scope`'s `agent-system/extensions/core/scripts/tests/` entry is narrowed to explicit files, and `validate-state.sh --deep` no longer reports a coarse-scope warning for this task.

---

### 299. Guarantee detection of in-place plan revision concurrent with a live implement dispatch
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: Guarantee that an in-place plan revision landing concurrently with a live implement dispatch is DETECTED, by adopting two complementary remedies together.

THE DEFECT. scripts/orchestrate-cycle-plan.sh can emit a `plan-revision` aux row for the same task and the same cycle as that task's implement dispatch: mutual exclusion is asserted between aux KINDS (drift-inspection vs divergence-audit), never between an aux row and the implement row. See the AUX DECISION comment at orchestrate-cycle-plan.sh:1241-1247 ("Mutual exclusion between `drift-inspection` (base mode) and `divergence-audit` (hard mode) is asserted defensively...") and the `aux_emit_kind` declaration at :1250. skills/skill-orchestrate/SKILL.md's Move 2 then requires every `dispatch[]` AND `aux_dispatch[]` row be issued in ONE message (SKILL.md:131-133, "Issue every Agent call named by `dispatch[]` AND `aux_dispatch[]` in **one message**"). So reviser-agent (the fixed agent for `plan-revision`, orchestrate-cycle-plan.sh:1359) edits plans/*.md IN PLACE while the implement agent is reading that same file. Nothing in any contract makes the implement agent aware the file changed underneath it.

OBSERVED COST (real production run: BimodalLogic, task 703, cycle 5). The implement dispatch excerpted one phase from the post-revision file and another from the pre-revision file, noticing only because line numbers shifted between two reads. It reported a plan bullet as uncorrected when the revision had already corrected it, propagated that false claim into the phase handoff and the round summary, and required a retraction plus two further plan revisions to unwind. It was caught ONLY because reviser-agent chose, on its own initiative, to message the live implement dispatch when its revision landed. Confirmed: agents/reviser-agent.md contains no notification machinery whatsoever (no SendMessage, notify, or concurrent-dispatch obligation anywhere in the file). That load-bearing behavior is entirely discretionary today.

REMEDY 1 - make the landed-revision notification routine rather than discretionary. The aux plan-revision dispatch file must instruct reviser-agent to message the live implement dispatch when its revision lands. Landing site: scripts/orchestrate-build-aux-dispatch.sh - the `plan-revision` arm of the prompt case statement at :189-195, and/or the dispatch-file emit block beginning at :201. This is precisely the mechanism that already worked; the change makes it contractual.

OPEN DECISION (settle during research/plan; do not assume it is free). Remedy 1 stated conditionally - "whenever a plan-revision aux row is co-dispatched with that same task's implement row" - is NOT directly expressible at the point the aux dispatch file is built, for two independently verified reasons. (a) orchestrate-build-aux-dispatch.sh's argument interface (usage block at :59-66) has no parameter carrying any knowledge of a sibling implement row. (b) More fundamentally, the AUX DECISION and AUX EMISSION blocks run at orchestrate-cycle-plan.sh:1241 and :1343, which is BEFORE the all-terminal check (:1500), eligibility (:1517), classification (:1635), force-phase consumption (:1676), admission (:1714), and dispatch-candidate bucketing (:1829). At aux-emission time the cycle does not yet know which tasks receive an implement row this cycle. Three resolutions, in recommended order:
  (c) RECOMMENDED - emit the notification instruction UNCONDITIONALLY in every `plan-revision` aux dispatch file. Requires no reordering and no new flag; the instruction is inert when no implement dispatch is live. Cheapest correct option.
  (b) Defer only the dispatch-file WRITE for plan-revision rows until after bucketing, then pass a new flag. More precise, but splits the aux emission block and must preserve its live-only-side-effect ordering (aux_pending consumption, marker-file consumption, escalation counters) and the shared-decision-section mandate that --dry-run and live render identical choices.
  (a) NOT RECOMMENDED - reorder the aux decision after bucketing. Most invasive; touches the script's documented decision-section structure.

REMEDY 2 - add an implement-side obligation to re-read every excerpted plan phase before writing. This catches a tear that lands between two reads before any message arrives, which is the failure mode remedy 1 alone misses. Landing sites: scripts/orchestrate-build-dispatch.sh's implement-phase "## Plan" block at :435-439 (currently emits only `plan_path`), and/or agents/general-implementation-agent.md (plus extensions/lean/agents/lean-implementation-agent.md for parity).

REMEDY 2 IS GENUINELY NEW - do not mistake it for existing coverage. Two adjacent mechanisms look like they already cover it and do not: (i) the `--territory` payload's "generic re-read-before-editing" note (orchestrate-build-dispatch.sh:67-69) governs re-reading the TARGET files an agent is about to edit, not the plan that instructs it; (ii) context/contracts/pre-edit-gate.md treats "a planning-time list as a hypothesis about the codebase" - it validates plan CLAIMS against the tree, not the plan FILE against its own later revision. Remedy 2's subject is the instruction source itself.

TENSION TO RECONCILE EXPLICITLY. agents/general-implementation-agent.md:59 currently reads "Do NOT re-read the full plan unless necessary (the handoff References section points to deeper context if needed)". It sits under **Successor Behavior** (:55-60), so it is scoped to handoff resumption rather than the primary read path - but a successor dispatch is exactly the case where the plan is most likely to have been revised since the prior read. Remedy 2 must reconcile with this line rather than silently contradict it, and the reconciliation should keep the obligation narrow: re-read the specific excerpted phase before writing, not the full plan.

BYTE-BUDGET INTERACTION (affects the design, not just the ordering). skills/skill-orchestrate/SKILL.md is already 325 B over its 20,000 B ceiling, and a concurrent task promotes ORCHESTRATOR_BUDGET_GATE_MODE from warn to hard (see task #289, which owns agent-system/extensions/core/context/config/orchestrator-context-budget.json and the same SKILL.md). Therefore: prefer putting the actual contract text in a context/ file and emitting only a short pointer into SKILL.md and the dispatch files, rather than adding prose to SKILL.md. No blocking dependency is declared on #289 in either direction - whichever lands second re-measures the budget - but a byte-heavy SKILL.md edit here would re-breach a gate that is becoming hard.

REJECTED ALTERNATIVE (recorded as rejected, NOT as a future phase). Remedy 3: never co-dispatch a plan-revision aux row with the same task's implement row, deferring the revision one cycle. It is the only option that REMOVES the race rather than detecting it. Rejected because it costs a full cycle and contradicts the current one-message dispatch rule at SKILL.md:131. Do not re-scope it into this task or a successor.

DEFERRED OBSERVATION (record only; explicitly OUT OF SCOPE). The same incident surfaced a second finding: a header-only correction label in a long plan does not survive a line-range excerpt, because a reader excerpting from below the labelled block drops the label silently. That was fixed in the affected plan directly. It is a documentation-form finding about plan authoring, not an orchestrator defect, and must not be scoped into this task.

SOURCE-STORE BOUNDARY. All edits land under agent-system/extensions/core/** (and extensions/lean/** for the lean agent). Never edit a deployed .claude/** copy - the next redeploy wipes it (.claude/rules/source-store-deploy-boundary.md). Script behavior changes should carry coverage in agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh and the aux/cycle-plan test siblings.

SHARED-FILE CONTENTION (for batch admission awareness, not dependencies). Other active tasks declare overlapping file_scope: #289, #273, #274, #275, #285 and #263 touch skill-orchestrate/SKILL.md; #250, #165, #272, #265 and #293 touch orchestrate-cycle-plan.sh; #263 touches orchestrate-build-dispatch.sh. Do not batch this task concurrently with those.

---

### 296. Repo hygiene: remove stale init.lua.backup, regenerate project-overview.md, fix README.md link
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: neovim
- **Dependencies**: None

**Description**: Review issues from all review on 2026-10-01 (grouped -- 3 independent small fixes, no shared file):

1. [medium] `init.lua.backup` - stale, tracked, byte-identical duplicate of `init.lua` (present since old task 516/518, pre-vault numbering).
   Impact: dead weight inviting confusion about which file is authoritative; silent drift risk if init.lua changes without the backup.
   Fix: delete init.lua.backup (git history already preserves prior states of init.lua), or move the backup convention to .gitignore if intentional.

2. [medium] `.claude/context/repo/project-overview.md` - still carries the `<!-- GENERIC TEMPLATE -->` notice despite 200+ archived tasks of repo history.
   Impact: any command/agent reading this file for repo orientation gets generic boilerplate instead of a real description.
   Fix: run /project-overview to generate a repo-specific version, then add context/repo/project-overview.md to .syncprotect per the file's own header instruction. Note: this file lives under .claude/context/repo/ -- confirm via .claude-extensions.json's source_dir whether it should be authored in a source store instead of hand-edited under .claude/** directly (source-store-deploy-boundary.md).

3. [low] `README.md:185` - links to a non-existent `.claude/README.md` ("For details on the agent system architecture... see [.claude/README.md](.claude/README.md)"). Only `.claude/CLAUDE.md` exists there, and it is itself marked "generated automatically... do not edit directly" rather than written as a navigable README.
   Impact: minor broken link for a reader following the architecture pointer from root README.
   Fix: point the link at `.claude/docs/docs-README.md` (the actual architecture entry point per .claude/CLAUDE.md's own Quick Reference) or at `.claude/CLAUDE.md` directly.

Related files: init.lua.backup, .claude/context/repo/project-overview.md, README.md

---

### 295. Add desc field to 44 keymap.set calls missing documentation
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: neovim
- **Dependencies**: None

**Description**: Review issue from all review on 2026-10-01:

**File**: `lua/neotex/util/notifications.lua`, `lua/neotex/util/url.lua`, `lua/neotex/config/notifications.lua`, `lua/neotex/config/autocmds.lua`, `lua/neotex/config/keymaps.lua`, `lua/neotex/plugins/tools/luasnip.lua`, `lua/neotex/plugins/tools/autopairs.lua`, `lua/neotex/plugins/tools/mail.lua`, `lua/neotex/plugins/tools/himalaya/data/templates.lua`, `lua/neotex/plugins/tools/himalaya/data/search.lua`, `lua/neotex/plugins/tools/himalaya/ui/features.lua`, `lua/neotex/plugins/ui/neo-tree.lua`, `lua/neotex/plugins/ai/shared/extensions/picker.lua`
**Severity**: medium
**Description**: Of 88 `vim.keymap.set(...)` calls in active (non-deprecated) code, 44 (50%) have no `desc` field, violating CLAUDE.md's own Lua Code Style standard ("Keymaps: ... use vim.keymap.set with descriptive options") and the Neovim extension's Common Operations note ("Use vim.keymap.set with description for all keymaps"). Concentration: himalaya/ui/features.lua (10), plugins/ui/neo-tree.lua (8), himalaya/data/templates.lua (4), util/notifications.lua (4), himalaya/data/search.lua (2), config/notifications.lua (2), plugins/tools/luasnip.lua (2), plugins/ai/shared/extensions/picker.lua (2), and one each in util/url.lua, config/autocmds.lua, config/keymaps.lua, plugins/tools/autopairs.lua, plugins/tools/mail.lua.
**Impact**: Reduces discoverability via which-key/:map introspection; conflicts with the project's own documented standard.
**Recommended Fix**: Add a concise `desc` string to each flagged `vim.keymap.set` call, describing what the mapping does. Start with himalaya/ui/features.lua and plugins/ui/neo-tree.lua (18 of the 44 between them).

---

### 284. Exempt a task’s own directory from the postflight file_scope excursion advisory, so the aggregator signal it was built for is visible
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**), per
rules/source-store-deploy-boundary.md.

Make the postflight modified_files-vs-file_scope excursion advisory carry signal, by exempting
the dispatching task's own task directory -- which the lifecycle REQUIRES it to write.

DEFECT (observed live 2026-09-30, ~/Projects/Logos/Verification, session sess_1790791567_96a2e0,
an ordinary single-task /orchestrate run). The advisory fired on EVERY phase, each time naming
only the artifact that phase had been dispatched to produce:
  - research postflight: ["specs/160_.../reports/01_recentre-task-graph-three-layer-aim.md"]
  - plan postflight:     ["specs/160_.../plans/01_recentre-task-graph-three-layer-aim.md"]
Both are the canonical artifact paths mandated by CLAUDE.md's "Artifact Paths" section and
rules/artifact-formats.md. A task cannot close a phase WITHOUT writing them, so no task can ever
avoid the advisory: it is unconditional, and therefore carries zero information while training
the reader to ignore the channel.

SITE. scripts/orchestrate-cycle-postflight.sh:1121-1132. The excursion predicate at lines
1128-1129 compares reported modified_files against the declared file_scope alone; there is no
implicit member for the dispatching task's own specs/{NNN}_{slug}/ tree.

READ THE PROVENANCE BEFORE DESIGNING -- THIS IS NOT COSMETIC. This advisory is direction (a) of
task 100 (close_aggregator_file_scope_blind_spot), now ABANDONED and held in
specs/archive/state.json. Its purpose was specific and narrow: make an AGGREGATOR edit outside a
declared scope visible, after two lean4 tasks were each found editing a module aggregator that
appeared nowhere in their file_scope (one adding `import` plus a docstring index entry to
Metalogic/BXCanonical.lean, the other to Semantics.lean), where the omitted edit was
structurally required for the new module to be reachable from the build. Its acceptance read:
"an aggregator edit made outside a task's declared file_scope is no longer silent -- at minimum
it is reported against that task." As shipped, that genuine aggregator signal arrives in the
same channel as, and is outnumbered by, every task's own required artifacts on every phase. The
detection direction the abandoned task chose was sound; the filter is what defeats it.

ALSO REPAIR A DANGLING CROSS-REFERENCE. Task 270's "RELATED, DELIBERATELY NOT MERGED" paragraph
states that this excursion check's advisory-vs-blocking question "was recorded separately". The
separate record is abandoned task 100, so the follow-on is not live and the pointer misleads a
reader into believing it is. Repoint 270 at this task, or restate the status there.

DELIBERATELY NOT BUNDLED INTO 270. Task 270 owns the same file and says explicitly "Touching the
same file is not a reason to bundle it." Its subject is null/type-safety in jq guards; this is
filter correctness and signal quality. Honour that boundary in both directions: if 270's audit
finds null-safety problems INSIDE lines 1121-1132 it fixes those and leaves this filter alone.

DELIVERABLE. Exempt the dispatching task's own task directory from the excursion comparison. The
natural form is to add the resolved specs/{NNN}_{slug}/ prefix as an implicit file_scope member
for the duration of the check, so that no task ever has to declare its own artifact home. Decide
and RECORD whether the exemption covers the whole task directory or only the sanctioned artifact
subdirectories plus runtime dotfiles (reports/, plans/, summaries/, .dispatch/,
.return-meta.json, .orchestrator-handoff.json, .decisions.json); prefer the whole directory
unless there is a concrete reason that a task writing elsewhere beneath its own tree is worth
surfacing. Note that an archived task's directory moves to specs/archive/{NNN}_{slug}/ -- a
forced round dispatched against an archived task writes there, so resolve the exemption from the
task directory the dispatch actually used rather than assuming the active path.

SECOND, SEPARABLE QUESTION -- ANSWER IT OR DEFER IT EXPLICITLY. Once the channel is quiet, is
advisory still the right enforcement level, or should a genuine excursion gate? Task 165's
recorded prior art is the pattern: advisory-first, write down the promotion criterion, promote
only once coverage is complete. Deciding to STAY advisory and recording the threshold is a
defensible outcome and a real decision -- but it goes in the script header either way. Do NOT
promote to blocking in the same change that fixes the filter: a gate sitting on a
known-false-positive predicate would block correct work.

ACCEPTANCE. A single-task /orchestrate run through research, plan and implement produces ZERO
excursion advisories when every modified file is either inside the declared file_scope or inside
the task's own directory. A task that genuinely edits an undeclared file outside its own tree --
the aggregator case -- still produces exactly one advisory naming that file, demonstrated with a
concrete case rather than argued. The enforcement-level ruling and its reasoning sit in the
script header alongside the existing documentation. shellcheck clean per
context/standards/shell-strict-mode.md.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 282. Write-time PreToolUse hook blocking record-versioning language, registered bare so exit 2 survives
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 280, Task 281

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

### 281. Repo-wide record-versioning lint with a blocking/advisory tier split, driven by the shared pattern library
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 280

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Build the repo-wide lint consumer for the record-versioning rule: a script that scans every
git-tracked file outside specs/** for unexempted record-version language, driven ENTIRELY by the
shared pattern library, plus its fixture test.

DELIVERABLES:
(1) scripts/check-record-versioning.sh -- modeled line-for-line on scripts/check-task-references.sh,
    which is the established shape for this class of lint and already solves several problems worth
    inheriting rather than rediscovering:
      - scans via `git ls-files`, so gitignored/vendored/generated paths are excluded by
        construction (this is what keeps .claude/** out of scope automatically)
      - three exit codes with distinct meanings: 0 clean, 1 findings, 2 environment/usage error, so
        a broken invocation is never mistaken for a clean tree
      - `--quiet` summary mode and an optional positional PATH_SCOPE argument scoping the scan to a
        subtree or single file, where a nonexistent PATH_SCOPE prints [SKIP] and exits 0
      - a `REPO_ROOT=$(pwd)` source-store invocation override, required because
        .claude/scripts/... does not exist until a deploy runs
      - NO hard-coded directory list: the sibling's own header records "Default to Repo-Wide Scope,
        Never a Hard-Coded Directory List" as a design principle, so a consumer repo with any layout
        is scanned in full rather than scanning nothing.
(2) scripts/tests/test-check-record-versioning.sh -- fixture test modeled on
    scripts/tests/test-check-task-references.sh.

=== BLOCKING VS ADVISORY -- THE ONE GENUINELY NEW DESIGN SURFACE ===
The sibling lint has a single severity. This one does not: the tiering decided in the taxonomy means
findings split into BLOCKING (affect the exit code) and ADVISORY (reported, never affect the exit
code). Implement the tier split by consuming the library's per-category tier rather than
re-classifying here, and make the reporting format state the tier per finding. The precedent for
exactly this two-tier reporting contract already exists in this repo -- see
scripts/chapter-quality-check.sh and scripts/typst-element-lint.sh, both of which report advisory
findings without affecting the exit code -- so follow that established convention rather than
inventing a third.

=== DEPENDENCY NOTE ===
Edge on the rule/taxonomy/library task is SUBSTANTIVE, not merely footprint: this script defines
none of its own patterns, exemptions, or tiers, so there is nothing to consume until the library
exists and the taxonomy has fixed the per-category tiers. file_scope also overlaps on manifest.json
and on the library itself (tier refinement driven by what the real scan finds), and the edge
serializes that overlap rather than leaving it to chance.

=== WIRING ===
  - manifest.json: add the script to provides.scripts and the test to the tests list (the sibling's
    entries are the `check-task-references.sh` and `tests/test-check-task-references.sh` lines).
  - docs/reference/utility-scripts-inventory.md: catalogue the new lint there -- that file is the
    documented home for standalone repo-health/doc-lint scripts not invoked in the normal
    research/plan/implement lifecycle, per the CLAUDE.md "Utility Scripts" pointer.

ACCEPTANCE. Script shellcheck clean per context/standards/shell-strict-mode.md. All four sibling
behaviors present and exercised by the fixture test: clean tree, blocking finding, advisory finding
that does NOT change the exit code, and marker-exempted content. Running the lint with no arguments
against the Verification repo returns exit 0 (the de-versioning sweep is committed; a nonzero exit
means either a real miss in the sweep or a discriminator bug -- resolve which, do not relax the
pattern to make it green). Running it against docs/ci.md, docs/consuming.md,
docs/stability-and-versioning-policy.md and docs/setup-without-nix.md individually produces zero
BLOCKING findings, since those carry only durable-axis version language. No task-number references
in deliverables outside specs/**.

---

### 280. Forbid record-versioning language in deliverables: the rule, its exemption taxonomy, and the shared pattern library that discriminates draft history from durable version axes
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. State the policy that deliverables outside specs/ describe the CURRENT DESIGN ONLY and never
narrate their own draft history, and build the single mechanical source of truth that this rule's
two enforcement consumers (repo-wide lint, write-time hook) will both consume. This task produces
policy plus mechanism; the consumers are separate tasks and deliberately come later.

DELIVERABLES (three files plus wiring):
(1) rules/no-record-versioning-in-deliverables.md -- the rule, shaped EXACTLY like its sibling
    rules/no-task-references-in-deliverables.md: a "## Path Pattern" section, a "## Principle"
    section, an explicit exceptions list, and a closing pointer to the fuller taxonomy under
    context/standards/. Carry the sibling's deliberate no-`paths:`-frontmatter HTML comment
    rationale if the same universal-scope reasoning applies (it does: any deliverable in any
    location could receive version language).
(2) context/standards/record-version-exemptions.md -- the full taxonomy and enforcement narrative,
    the lazy companion the rule points at.
(3) scripts/lib/record-version-patterns.sh -- the ONLY place detection patterns, axis
    discrimination, and exemption logic are defined. Both later consumers source it and neither
    defines any of that locally. Model its header, its exported-variable shape, its
    `is_exempt_path`, and its `strip_exempt_regions` stdin/stdout filter on
    scripts/lib/task-reference-patterns.sh.

=== SUBSTANCE OF THE RULE -- RULED, DO NOT RE-OPEN ===
Deliverable files (docs/**, README.md, code, and other work product) must state the current design
only and must never narrate their own draft history. Specifically FORBIDDEN in deliverables:
  - page-level version labels in titles or status lines: "The X convention (v2)";
    "**Status**: v2, accepted <date>; supersedes v1"
  - "this is the second version" / "supersedes v1" framing
  - supersession or disposition tables mapping an earlier draft's decisions onto the current ones
  - "(v1 Decision N)" attributions attached to rejected alternatives
  - phrasing relative to an unstated past: "no longer", "previously", "formerly", "used to",
    "carried forward from v1", "withdrawn", "every v1 field removed"

Rejected alternatives are KEPT -- they are the point of a decision record -- but stated on their own
merits rather than attributed to an earlier draft of the same document.

=== EXEMPT ZONES -- RULED, VERSION LANGUAGE IS PERMITTED, NO MARKER NEEDED ===
1. Everything under specs/** -- task descriptions, plans, reports, summaries, `completion_summary`
   fields, TODO.md, state.json, ROADMAP.md. THIS IS THE PRIMARY EXEMPTION and was confirmed
   explicitly by the owner.
2. Git commit messages; PR/branch metadata.
3. Three DURABLE NON-RECORD version axes that are not draft history:
   (a) software/toolchain versions -- `Lean v4.31.0`, `actions/checkout@v4`, `schema = 2` semantics
   (b) file-format and schema versions -- `book.toml` `schema = 2`, `books/schema/book-toml-v2.md`,
       `book-cert-v2.md`
   (c) CI cache-key epoch segments -- `pnpm-v1-`, `lake-recheck-v3-` in docs/ci.md
4. An explicit, DATED cross-document amendment note in a decision record, recording that a decision
   the record OWNS was amended -- docs/architecture-decisions.md's "**Amended by** <doc>, <date>:"
   house style. This records a real change to an accepted decision, not a draft lineage, and MUST
   stay permitted. (Verified present: docs/architecture-decisions.md carries exactly one such note.)

Beyond these four, an exception requires EXPLICIT USER PERMISSION. Provide a marker convention for a
user-permitted exception mirroring the sibling's `task-ref-ok` marker: a block form
(`version-ok:begin` ... `version-ok:end`, matched as plain substrings so comment syntax is
irrelevant) and an inline form, both requiring a trailing reason naming a taxonomy category. Name
the marker in the taxonomy and implement its stripping in the shared library, not in either
consumer.

=== THE HARD DESIGN PROBLEM -- THIS IS WHAT THE TASK IS ACTUALLY ABOUT ===
The forbidden vocabulary OVERLAPS HEAVILY with the legitimate uses in exempt zone 3: `v1`/`v2`
appear in toolchain pins, CI cache keys and schema filenames, so a naive regex is noisy. The shared
library must DISCRIMINATE the record-version axis from the three durable axes. Verified footprint in
the Verification repo at the time of writing: eight files under docs/ plus README.md match a bare
`\bv[0-9]\b`, and docs/book-convention.md still legitimately carries 4 such mentions AFTER the sweep
-- so the discriminator's job is to return zero findings on that already-clean tree while still
catching the patterns in the FORBIDDEN list above. It is ACCEPTABLE for some categories to be
ADVISORY rather than BLOCKING; decide the tier per category in the taxonomy and encode the tiering
in the library so both consumers inherit it rather than each choosing. The bare-past-tense
vocabulary ("no longer", "previously", "formerly", "used to", "withdrawn") is the most
false-positive-prone category and is the leading advisory candidate.

=== RATIONALE TO RECORD IN THE RULE (cite durable anchors, no task numbers) ===
docs/book-convention.md shipped carrying 68 v1/v2 mentions across 1,705 lines, a 22-line "How this
record relates to v1" supersession table with 15 disposition rows, eight "(v1 Decision N)"-attributed
rejected alternatives, and an "Every v1 field removed" migration table -- while BOTH "versions" were
dated the same day and nothing in the repository had ever been built against v1 (no `book.toml`
existed anywhere). The file documented its own authoring process rather than its design, and the
label leaked outward into docs/architecture-decisions.md (5 references), docs/README.md,
specs/ROADMAP.md and eight open task descriptions in state.json. It was also off house style: every
other decision record in docs/architecture-decisions.md carries a bare "**Status**: accepted, <date>"
with no page version. The de-versioning sweep is already committed -- see the commit titled "docs:
state the book convention without version history" -- and this rule is the durable guard against
recurrence.

=== WIRING (do not skip; the sibling occupies all of these surfaces) ===
  - manifest.json: add the rule to provides.rules, the standard to provides.context, and the library
    to provides.scripts (the sibling's entries are at the `no-task-references-in-deliverables.md`,
    `standards/task-reference-exemptions.md` and `lib/task-reference-patterns.sh` lines -- follow
    their exact shape).
  - index-entries.json: add a discovery entry for the standard, modeled on the existing
    `standards/task-reference-exemptions.md` entry (path, summary, keywords).
  - merge-sources/claudemd.md: add the rule to the "Rules References" core-rules list beside the
    `no-task-references-in-deliverables.md` line, so the deployed CLAUDE.md advertises it.

ACCEPTANCE. Rule file structurally parallel to its sibling (same four sections, same pointer
discipline). Taxonomy standard enumerates every category with its blocking/advisory tier and
documents the marker convention. Shared library is shellcheck clean per
context/standards/shell-strict-mode.md, exports its patterns and both exemption helpers, and is
sourceable standalone. All three manifest/index/claudemd surfaces wired. A one-off manual run of the
library's discriminator over the Verification repo's docs/ and README.md returns zero BLOCKING
findings (the sweep is committed, so a green tree is the expected baseline and any finding is either
a real miss in the sweep or a discriminator bug -- resolve which before closing). No task-number
references in deliverables outside specs/**.

---

### 275. Per-repo orchestration queue: registered, live, archived on finish, and consumed by admission
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 272

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

---

### 273. Three-channel orchestration conclusion stage with per-channel approval, as a distinct post-postflight stage
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: Task 271, Task 184, Task 329

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Every orchestration concludes by proposing three channels of follow-on work, each fired ONLY
on that channel's own separate explicit user approval:
  (a) DIRECT FIXES to make now, executed by a final cleanup agent;
  (b) AGENT-SYSTEM CHANGES, routed to meta-builder-agent;
  (c) FOLLOW-UP TASKS to create, routed to a task agent, recorded as CHILDREN of the originating
      task via the `parent_task` edge.
No channel may fire on another channel's approval, and none may fire without one.

ANTI-BYPASS CONSTRAINT ON CHANNEL (b) -- NOT RELAXED BY THIS FEATURE. meta-builder-agent must keep
CREATING TASKS rather than editing .claude/ or the source store directly. The constraint in
commands/meta.md and skills/skill-meta/SKILL.md stands unchanged: the conclusion stage may hand it
a change request, but it still produces tasks in specs/, never implementation.

THIS MUST BE A DISTINCT POST-POSTFLIGHT STAGE WITH ITS OWN BOUNDARY CONTRACT -- NOT SMUGGLED INTO
POSTFLIGHT. context/standards/postflight-tool-restrictions.md today prohibits Edit on *.md outside
specs/ and on .claude/** non-specs, and confines postflight Bash to state-write.sh, git add/commit,
and two `rm -f` marker deletions; AskUserQuestion is likewise outside that contract.
skills/skill-orchestrate/SKILL.md:287 carries a `## MUST NOT (Postflight Boundary)` section.
Channels (a) and (b) would violate both if folded into postflight. The new stage therefore needs
its own explicitly written allowed/prohibited table in that standard, stating that it runs AFTER
postflight has closed state and committed.

=== OPEN QUESTION FOR THE RESEARCH PHASE: RECONCILE WITH TASK 184'S RULING ===
THIS MUST BE SETTLED WITH A WRITTEN VERDICT BEFORE PLANNING. The contradiction may NOT be left
standing in both task descriptions.

Task 184's ruling of 2026-09-22 states verbatim:
    "do NOT auto-create tasks: the report is the handoff and the user files them with /task"
Channel (c) as requested REVERSES that operative clause. Both candidate resolutions are live:

  RESOLUTION A -- NARROW OVERTURN. The ruling's implicit premise was that auto-creation is
  UNAPPROVED creation. Per-channel explicit approval removes that premise: user-approved creation
  is not auto-creation. On this reading 184 was right for a report-only postflight (where
  AskUserQuestion is outside the boundary contract anyway) and wrong for an interactively-gated
  post-postflight stage. 184's scope would be rewritten to match rather than left contradictory.

  RESOLUTION B -- SCOPE-LIMITED COEXISTENCE. Task 184 governs one specific payload (skeleton-plan
  sorry_inventory[].follow_up_task entries surfaced from orchestrate-cycle-postflight.sh, reported
  plus recorded in an append-only state.json field), while this task governs conclusion-stage
  follow-ups generally. The two stay distinct. Cost: two adjacent mechanisms produce follow-ups by
  two different routes, and someone reconciles them later regardless.

PRIOR ANALYSIS, RECORDED AS A RECOMMENDATION AND NOT AS THE DECISION: the /meta prompt-mode
analysis that filed this task recommended Resolution A ("overturns, narrowly"), on the grounds
stated above, and judged that the reversal should be named plainly as a reversal rather than
presented as an extension. The research phase is not bound by that recommendation and must reach
its own verdict.

DEPENDENCY NOTE. The edge on task 184 is a HARD dependency: shared footprint on
scripts/orchestrate-cycle-postflight.sh and context/standards/status-markers.md, plus the
substantive ruling conflict above. Its own dependency chain was verified CLEAR at filing time --
242, 243, 258 and 259 are all in specs/archive/ (directories
242_orchestrate_partial_with_blocker_stops_redispatch,
243_reconcile_research_handoff_writer_contract,
258_fix_postflight_recovery_decline_attribution,
259_allow_completion_on_a_gate_skipped_plan_branch), each carrying an implementation summary rather
than an abandonment note, and 266 is completed -- so nothing unresolved is inherited. Per the
standing convention, DROP THE EDGE rather than hold this task if 184 stalls.

The edge on task 271 is also hard and is NOT droppable: channel (c) creates tasks AS CHILDREN, which
is structurally impossible before the `parent_task` edge is declared, validated and rendered.
Without 271 this stage would write a field nothing reads.

ACCEPTANCE. A written verdict on the 184 reconciliation before planning begins, with the losing
resolution's rationale recorded. The stage's own allowed/prohibited table lands in
postflight-tool-restrictions.md to the same standard as the existing postflight table. Each of the
three channels demonstrably cannot fire without its own approval, covered by a test. The
meta-builder-agent anti-bypass constraint is shown still to hold for channel (b). Documented in
docs/architecture/orchestrate-state-machine.md. Shellcheck clean per
context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

=== AMENDMENT 2026-10-03: THE THREE CHANNELS ARE DERIVED FROM THE PER-TASK ISSUE LOGS ===

Nothing above is withdrawn or rewritten. This amendment supplies the EVIDENCE BASE the conclusion
stage's proposals are built from, which was unspecified when this task was filed.

A new dependency has been added: the per-task issue log task (task 329), which introduces an
append-only `specs/{NNN}_{SLUG}/issues.jsonl` written by `scripts/issue-record.sh` from both
dispatched agents and the orchestrator, surviving the per-dispatch overwrites of
`.return-meta.json` and `.orchestrator-handoff.json`. That task is CAPTURE ONLY by design: it
surfaces nothing to the user mid-run and acts on nothing. Review is THIS stage's job and only this
stage's job.

THE DERIVATION. This stage's three channels are not composed from the orchestrator's recollection
of the run. They are DERIVED FROM THE PER-TASK ISSUE LOGS OF THE TASKS THE RUN TOUCHED:

  - Every entry whose `resolution` is `open` or `worked_around` is classified into EXACTLY ONE of
    the three channels -- (a) what can be fixed now directly; (b) what follow-up tasks are called
    for in the local repository; (c) what agent-system upgrades are needed, routed via /meta.
    Exactly one: an entry may not appear in two channels.
  - The entry's own `suggested_channel` field is a HINT. The ORCHESTRATOR'S JUDGMENT IS THE
    DECISION. A hint that is overridden should be overridden visibly, not silently.
  - RECURRING CLASSES ACROSS TASKS ARE GROUPED INTO ONE PROPOSAL. Three tasks hitting the same
    class is one proposal citing three entries, never three proposals. This is the main reason the
    derivation is worth doing at all: the recurrence is invisible from any single task.
  - Entries with `kind: "win"` ARE SUMMARISED, NEVER ACTIONED. Positive signals belong in the
    report so the user can see what the convention bought; they generate no channel item.
  - REVIEW HAPPENS ONLY AT THIS STAGE, NEVER MID-RUN. This is the complement of the issue log's
    capture-only contract, and the two must not drift: if a mid-run surface is ever added, it is
    added here by amendment, not improvised in the writer.
  - EACH PROPOSAL CITES ITS ISSUE-LOG ENTRIES -- task number plus entry identifier -- so the user
    can audit the proposal against its evidence before approving that channel. A proposal with no
    citation is not presentable.

The per-channel explicit-approval contract above is unchanged by this amendment: deriving a
proposal from evidence is not approval to fire it.

---

### 272. Honest session liveness for concurrent same-repo batches: diagnose why the wired heartbeat never fires, add a live-but-stale lock state, re-derive registry scope, and give each orchestration its own identity
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

GOAL. Let different batches of tasks be orchestrated CONCURRENTLY in different sessions of the same
repo when there is no file_scope collision and no dependency edge between them, with each
orchestration keeping distinct metadata rather than sharing one in-flight record.

THE DECISION LAYER IS ALREADY SOUND -- DO NOT REWORK IT. Measured live in ~/Projects/BimodalLogic:
scripts/orchestrate-batch-admit.sh returned a correct v5 verdict for a real candidate,
  {"decision":"defer","defer_reason":"file_scope_collision", plus colliding_task_number,
   colliding_task_status, overlapping_path, "collision_scope":"cross_batch",
   "corroborated_by":["non_terminal_status","session_registry"]}
alongside an `idle_overlap_advisory` for an idle overlapping task. The gap is the layer BENEATH
this verdict. MUST NOT modify scripts/orchestrate-batch-admit.sh -- that surface belongs to
task 165, which is already scoped to it.

=== PIECE 1 (SCOPE-DETERMINING, DO THIS FIRST): IS THE HEARTBEAT SILENCE A ROUTING REGRESSION OR A DESIGN GAP? ===

THE MECHANISM ALREADY EXISTS AND IS WIRED. DO NOT BUILD A SECOND ONE. The per-task heartbeat is
called at scripts/update-phase-status.sh:223:
    hb_out=$(bash "$tl_path" heartbeat "$task_number" "$hb_sid" 2>&1) || hb_rc=$?
seventeen lines above the `session-heartbeat` call at line 240, in the same function, with its own
`_hb_trace "heartbeat" "$hb_verdict"` verdict line and its own no-op classifier (`no-lock`,
`session-mismatch`, `unknown`). It is invisible to a naive grep only because the script path is
held in the variable "$tl_path". An implementer who believes the mechanism is missing will build a
redundant second one alongside it.

MEASURED EVIDENCE (the function writes ${repo_root}/.agent-logs/heartbeat-trace.log):
  ~/Projects/BimodalLogic: 580 trace lines, 580 of them `heartbeat ok`, covering 26 task numbers
      -- ALL from EARLIER sessions.
  ~/.config/nvim:          2740 trace lines, 2723 `ok`, 15 `noop:no-entry`, 2 `noop:no-holder`.
  BUT: ZERO trace lines for EITHER in-flight task of the currently-running BimodalLogic session --
      neither the modal-substrate task (lock acquired 2026-09-29T14:57:11Z) nor the Typst
      lean-code-environment task in that same session produced a single line, despite eleven
      phase-completion commits having landed for the former.
  AND: its .lock/holder.json shows acquired_at == heartbeat_at == 2026-09-29T14:57:11Z exactly, so
      `never_heartbeated=true` is literal, not approximate.
  AND: the `noop:session-mismatch` verdict exists in the classifier but appears ZERO times in
      either repo's log -- so the no-op paths are NOT absorbing these calls. The function is not
      being ENTERED at all.

WHY THIS ORDERING MATTERS. The silence is SESSION- or DISPATCH-PATH-scoped, not task-scoped: two
in-flight tasks in one session both traced zero while every earlier session traced cleanly. Cadence
therefore cannot explain it for either task. A routing regression in the currently-running
orchestrate loop is a SMALL fix; a design gap is not. ESTABLISH WHICH BEFORE SCOPING THE REST OF
THIS PIECE. Secondary and genuinely real regardless of that answer: the heartbeat is reachable only
via a phase-status change, so a task sitting in one long phase emits nothing between transitions --
close that with a time-based or dispatch-boundary trigger. Also consider consuming the `_hb_trace`
verdicts, which are written today and read by nothing.

=== PIECE 2: A THIRD LOCK STATE FOR STALE-HEARTBEAT-BUT-PID-ALIVE ===
Observed live: `task-lock.sh check <N>` reported `held-stale session=... heartbeat_age_min=33
threshold_min=30 never_heartbeated=true` while `session-list` reported that SAME session
`live:true, liveness_reason:"pid-alive"` (pid 1015099). cmd_acquire's held-lock overlap pass
degrades to WARN-and-proceed on a stale lock, so a lock belonging to a demonstrably LIVE session
became advisory purely because its heartbeat drifted. Decide whether stale-but-pid-alive should be
a THIRD state distinct from both `held` and `held-stale`, and implement the ruling.

PRECEDENT TO REUSE, NOT TO INVENT AROUND. The distinction piece 2 needs ALREADY EXISTS one level
up: `session_liveness()` computes six reasons -- `corrupt`, `dead-pid`, `dead-pid-within-grace`,
`stale-heartbeat`, `pid-alive`, `undeterminable` -- governed by two thresholds
(SESSION_REGISTRY_DEAD_PID_MIN, SESSION_REGISTRY_REAP_MIN) in a documented evaluation order, and
its own header records that it was factored out so cmd_session_list and session_contention()
consume the IDENTICAL verdict rather than a second transcription. THE GAP IS THAT THE PER-TASK
LOCK HAS NO SUCH DISTINCTION: cmd_check emits only `held-fresh` (line 1033) and `held-stale`
(line 1036), each carrying heartbeat_age_min, threshold_min and never_heartbeated but NO
pid-liveness dimension at all. So piece 2 is bringing an existing, tested session-level vocabulary
down to the per-task lock -- a smaller and better-shaped change than inventing a third state from
scratch. Consume `session_liveness()`'s verdict; do not transcribe it.

CRITICAL CONSTRAINT -- KEY ON session_id, NEVER ON pid. Task 165's absorbed text records that both
sessions in its incident reported the SAME pid with pid_source `ancestor-claude`, because two
/orchestrate runs inside one Claude Code process share an ancestor. The failing task's own
holder.json likewise shows pid_source `ancestor-claude`. A self-exclusion keyed on pid would treat
a foreign session as self and silently disable cross-session detection for the most common case.

=== PIECE 3: RE-DERIVE THE REGISTRY'S file_scope ON HEARTBEAT ===
scripts/command-gate-in.sh:106 registers the session with a task-number CSV, and the union
file_scope is computed AT REGISTER TIME ONLY; `session-heartbeat` refreshes heartbeat_at and
nothing else. So widening a task's file_scope after registration leaves the registry snapshot
permanently narrow. Observed live: the registered scope lacked
FormalSystem/Metalogic/Decidability/PlusWitnessFamily/Incompleteness.lean, which that task's
state.json file_scope does declare. Decide whether the registry should re-derive on heartbeat and
implement it.

=== PIECE 4 HAS MOVED OUT OF THIS TASK ===
Per-orchestration identity (an orchestration-id distinct from session_id, with per-orchestration
metadata/artifacts/return-meta rather than one shared in-flight record) was originally piece 4 of
this task. It now lives IN FULL in task 275, the per-repo orchestration queue, which DEPENDS on
this task. Do not implement it here. This task is pieces 1-3 only: diagnose the unreachable
heartbeat, add the live-but-stale lock state, re-derive registry scope on heartbeat.

DEPENDENCY NOTE. The edge on task 51 is substantive, not merely footprint serialization: 51
relocates the per-session orchestration runtime files (specs/.orchestrator-multi-state-*.json,
specs/.return-meta-multi-*.json) that Piece 4's per-orchestration metadata extends, and it owns the
same two files this task edits (scripts/task-lock.sh,
context/standards/orchestrator-runtime-files.md). Building Piece 4 before 51 lands risks creating
exactly the fourth orphaned naming generation that 51's own text warns against.

ACCEPTANCE. Piece 1's routing-regression-versus-design-gap question answered in writing before any
fix lands, with the answer visible in the trace log or an equivalent probe. A fixture test
reproduces the two-live-sessions overlap case and the stale-but-pid-alive case, and fails against
the current scripts. No change to orchestrate-batch-admit.sh. Existing consumers of task-lock.sh's
output lines (which read them as prefixes/substrings) keep working. Shellcheck clean per
context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

## ABSORBED AT CREATION-TIME RECONCILIATION (two defects, with evidence)

These two items were drafted as a separate task and folded in here instead, because this task already states the same goal and owns the session-registry trust question. Both are newly verified live; neither was stated by this task before.

(a) CLASS E CONTENTION REVIEW IS DEAD ON ARRIVAL. `commands/orchestrate.md` mints `batch_session_id` AFTER it calls `orchestrate-predispatch-review.sh`, so `--session-id` is never passed and that script's Class E (session-registry contention) section prints `SKIPPED (no --session-id supplied to this script; orchestrate-batch-admit.sh's session-registry input was itself skipped via its own D6 degradation)` on EVERY run. Reproduced live. This is the only surface designed to warn an operator, before dispatch, that another live batch already covers the candidate files -- precisely the capability this task's GOAL section describes. Remedy: mint the session earlier in `commands/orchestrate.md` and pass `--session-id` through. Note the ordering subtlety: the review runs BEFORE `session-register`, so self-exclusion is a no-op on the caller's own not-yet-registered id, which is harmless and still surfaces OTHER live sessions correctly.

(b) STALE, SELF-CONTRADICTING BATCH MESSAGE. The MAX_TASKS guard prints "Batching is not yet supported. Running with first $MAX_TASKS tasks only." at `commands/orchestrate.md` line 235 and `docs/architecture/orchestrate-state-machine.md` line 714. Batching is the DEFAULT -- `context/patterns/batch-orchestration-guardrails.md` opens with a "Batching Is the Default" section. This is the message an operator sees exactly when pushing batch size, so it misleads at the worst moment. Text-only fix.

ALSO OBSERVED (bears on this task's heartbeat diagnosis): `specs/.sessions/` currently holds five dead registry entries dating to 2026-09-08, all reading `live:false / liveness_reason:dead-pid`, never reaped, plus a leftover `specs/.contention-manifest/` directory. `session-reap` is explicit-invocation-only by deliberate design (`task-lock.sh` line 184) and no lifecycle site calls it. They are correctly EXCLUDED today because their PIDs are dead, so this is not presently a false-defer -- but PID recycling would make a leaked entry read as live and false-defer a candidate indefinitely. Argue the reap-policy choice (opportunistic on `session-register` vs. wired into `/refresh`'s documented sweep) rather than assuming either; the current restriction is intentional.

FILE_SCOPE WIDENED by this absorption: `commands/orchestrate.md`, `scripts/orchestrate-predispatch-review.sh`, `docs/architecture/orchestrate-state-machine.md`. The first and third overlap open tasks #273 and #265, so the admission gate will serialize against them -- expected and correct, not a defect.

---

### 271. Finish the parent_task edge: declare it in the schema, validate it, render it in TODO, and make it survive renumbering
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: orchestrator
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact regenerated by the loader -- see rules/source-store-deploy-boundary.md).

GOAL. Finish the `parent_task` edge so that follow-up and spawned tasks can be recorded as CHILDREN of their originating task, as a parent/child relation DISTINCT from the existing `dependencies[]` array.

THIS IS NOT GREENFIELD -- IT IS A HALF-BUILT FIELD WITH TWO PRODUCERS AND ZERO CONSUMERS. Verified in the source store:
  PRODUCERS (already write it):
    - skills/skill-spawn/SKILL.md:380  ("parent_task": $parent)
    - commands/task.md:833             (/task --review follow-up creation)
    plus declared intent in commands/spawn.md:117, agents/spawn-agent.md:176,195
      (as `parent_task_number`), context/orchestration/delegation.md:657,673
  CONSUMERS (all absent -- measured, 0 occurrences each):
    - context/schemas/state-schema.json          0  (field is written but UNDECLARED)
    - scripts/validate-state.sh                  0  (no orphan/cycle checking)
    - scripts/generate-todo.sh                   0  (invisible in TODO.md)
    - context/reference/state-management-schema.md 0 (undocumented)
  NOT A CONSUMER DESPITE APPEARANCES: scripts/generate-task-order.sh has 10 "parent" hits, but
  they are union-find / graph-parent identifiers (lines 459, 464-468, 479, 486) plus two display
  strings ("indented = depends on parent", lines 513 and 881). None reads `parent_task`.

NO MIGRATION BURDEN. Live count of entries carrying `parent_task` in this repo: 0, across both
`active_projects` and `completed_projects`. There is no legacy population to backfill, which makes
this a clean moment to declare the field properly rather than after it has accumulated data.

PREMISE CORRECTION (added after the paragraph above; that paragraph is REPO-LOCAL and does not
generalize). The "live count 0 / no legacy population to backfill" finding holds for THIS
repository only. In the BimodalLogic consumer repo, SIX active entries carry `parent_task: 165`
-- 410, 411, 412, 428, 429 and 430 -- recording real expansion lineage (which task each was split
from). So a deployed consumer repo DOES have a population, and two consequences follow for the
work items above:
  - Work item (2)'s orphaned-parent and cyclic-parentage checks must be designed against a real
    population, not a greenfield one. Note in particular that `parent_task: 165` points at a task
    that is itself still active in that repo, and that four of the six children are `not_started`
    while 428 is `blocked` -- so the checks will encounter live, mid-lifecycle parentage, not just
    settled history.
  - The "clean moment to declare the field properly rather than after it has accumulated data"
    framing no longer applies globally: the data has already accumulated somewhere the loader
    deploys to. Decide whether declaring the field needs an accompanying consumer-side backfill or
    validation pass, and whether an entry whose `parent_task` points at an ARCHIVED or renumbered
    task is an error, a warning, or expected.
Evidence gathered read-only from that repo; it is a separate repository with its own task system
and is not an edit target for this task.

RELATED, SEPARATELY TRACKED. `parent_task` is one of NINE state-schema.json validation failures in
that same consumer repo (`validate-state.sh`: 8 passed, 13 warnings, 9 failed). The other eight
fields -- top-level `active_goal`, `artifacts`, `last_updated`, `metadata`, and entry-level
`blockers`, `previous_status`, `researched`, `resume_phase` -- are ruled on by their own task,
which deliberately EXCLUDES `parent_task` because this task already owns it. That task sets a
per-field widen/migrate/retire policy and a hard constraint that no non-null value may be deleted
without recording where the information went; this task's work item (1) should follow that policy
rather than deciding independently. The two tasks share state-schema.json and validate-state.sh in
their file_scope, so whichever lands second must re-read both files.

WORK ITEMS.
(1) Declare `parent_task` in context/schemas/state-schema.json and document it in
    context/reference/state-management-schema.md, stating explicitly that it is NOT a dependency
    edge: a parent may complete before its children, and parentage must never affect dispatch
    eligibility or the Kahn-algorithm dependency waves.
(2) Add orphaned-parent and cyclic-parentage checks to scripts/validate-state.sh. Follow the
    ADVISORY-FIRST precedent recorded at plan-format.md:259-266 (the Verification Tier rollout):
    a missing or dangling value emits a warning rather than an error, `--strict` enforces, and the
    PROMOTION CRITERION is written down at the same time as the check.
(3) Decide what scripts/generate-task-order.sh and scripts/generate-todo.sh render for parentage.
    CONSTRAINT: generate-task-order.sh's existing indentation already means "depends on parent" in
    the DEPENDENCY sense (its own display strings say so). Parentage rendering must not collide
    with or be mistaken for that. Consider whether parentage belongs in the Task Order tree at all
    versus the per-task TODO.md entry.
(4) Settle renumber survival. scripts/deprecated/vault-operation.sh step 5 renumbers active tasks
    by subtracting 1000 and rewrites `dependencies`, but nothing anywhere handles `parent_task`, so
    a renumber would silently dangle every parentage edge. PRIOR QUESTION TO ANSWER FIRST: that
    script lives under scripts/deprecated/, so establish whether renumbering is a live path at all
    before writing code for it. If it is dead, say so and record that parentage stability rests on
    numbers never being rewritten; if it is live, fix it.

DEPENDENCY NOTE. The edge on task 269 is a FOOTPRINT-SERIALIZATION edge only, on
scripts/validate-state.sh, not a substantive dependency: 269 is a one-line null-safety fix
(presence test -> type test) in that same file. Per the standing convention, DROP THE EDGE rather
than hold this task if 269 stalls.

ACCEPTANCE. The field is declared in the schema and documented; validate-state.sh detects an
orphaned parent and a parentage cycle, advisory-first with a written promotion criterion; the TODO
rendering decision is recorded with its rationale (including a decision NOT to render, if that is
the ruling); the renumber question is answered either way in writing; shellcheck clean per
context/standards/shell-strict-mode.md. No task-number references in deliverables outside specs/**.

RENDERER QUIRK TO FOLD IN (observed 2026-09-29, not a separate task). The Task Order tree
already renders the string "parenttask" -- the underscore stripped by generate-task-order.sh's own
truncation path -- while state.json and the TODO.md task heading both hold "parent_task" correctly.
This is a pre-existing defect in the very script this task is scoped to touch, so fix it as part of
the rendering work item rather than filing it separately.

---

### 251. Context-corpus reachability probe (filename, directory, index.json), then act on dead and overlapping files
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 127

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

MOTIVATION. Same structural gap as the script-corpus task: defect-driven intake surfaces only
what breaks, and an unreachable or redundant context file breaks nothing -- it just costs bytes,
deploy time and reader attention. Existing tasks slim SPECIFIC oversized files (commands/task.md,
the literature and distill skills) or collapse ONE mechanism (the routing ladder). Nothing
reviews the corpus, and -- the sharper problem -- nothing in the repo can currently ANSWER what
is reachable.

MEASURED 2026-09-22 (re-measure before acting; standing rule 3).
  - 523 .md files under agent-system/extensions/**/context/**, 3,583,550 B (~3.6 MB) total.
  - A naive basename-grep reachability check over the whole source store returned: 39 files not
    referenced from outside context/, of which 16 were referenced NOWHERE at all.
  - ALL 16 WERE FALSE POSITIVES. Every one is a present-extension slide template under
    context/project/present/talk/contents/**, referenced by DIRECTORY from the present agents
    (`talk/contents/title/`, `talk/contents/methods/`, ...) rather than by filename.
  - CONCLUSION, STATED PLAINLY SO NOBODY RE-DERIVES IT: there are ZERO confirmed dead context
    files today. The finding is not "delete 16 files" -- it is that the naive check is INADEQUATE
    and no adequate one exists. Do not open this task by deleting anything.

THREE REFERENCE STYLES THE PROBE MUST UNDERSTAND (the naive check saw only the first):
  1. by filename -- a backticked or plain path naming the file;
  2. by directory -- a reference to the containing directory, which reaches every file under it
     (the present templates; treat a directory reference as covering its whole subtree);
  3. via index.json -- context indices that enumerate entries the loader resolves at runtime.
A probe that misses any of these produces false orphans, and acting on false orphans deletes live
content. Prove the probe against the present-templates cluster as a REGRESSION FIXTURE: a correct
probe reports all 16 reachable.

PHASE 1 -- THE PROBE (mechanical, becomes permanent).
Add a standing reachability/inventory probe following the EXISTING convention of
scripts/assess-repo-health.sh and scripts/measure-eager-context.sh (JSON to stdout, --check mode,
no side effects, reads the SOURCE STORE not .claude/**). Per context file report:
  - bytes; owning extension; reachable yes/no and by WHICH of the three styles;
  - eager vs lazy -- whether it loads on every session (the eager channels measure-eager-context.sh
    already models: parent chain, assembled CLAUDE.md, @-imports, path-matched rules) or only on
    demand. Reuse that script's channel model; do not build a second, divergent one.
  - inbound reference count, so single-referrer files that could be inlined are visible.
Register it in docs/reference/utility-scripts-inventory.md alongside the other probes.

PHASE 2 -- THE STRONGER EVIDENCE: TELEMETRY, NOT ONLY STATIC ANALYSIS.
Static reachability answers "could this be loaded". The better question is "has any dispatch
ACTUALLY loaded it". The repo already carries the data: specs/events.jsonl, the memory
extension's history.jsonl, and the telemetry tiers the distill review mode queries. Determine
whether load events are recorded at context-file granularity; if they are, cross the probe's
static verdict against observed loads and report files that are statically reachable but never
actually loaded. If they are NOT recorded at that granularity, say so explicitly in the summary
and state what instrumentation would be needed -- that is a legitimate finding, not a failure.

PHASE 3 -- ACT ON THE RANKING.
Only after Phases 1-2 produce evidence: remove confirmed-dead files; merge pairs whose content
substantially overlaps; and for files that are live but oversized, apply the established
rule-or-command -> lazy-narrative split (rules/git-workflow.md -> context/standards/
git-workflow-narrative.md is the worked example). Every removal cites the probe's verdict AND
the telemetry verdict where available. A file that is reachable by any of the three styles is NOT
dead, however unloved it looks.

SCOPE DISCIPLINE -- READ BEFORE DECLARING file_scope.
This task's INITIAL file_scope is the new probe, its test, and the inventory doc ONLY. Do NOT
declare `context/` or any whole-directory or glob entry: coarse entries draw validate-state.sh
warnings and defer unrelated tasks in the dry run -- a mistake already corrected once in this
backlog by narrowing a task that had three whole-directory entries. Phase 3's actual edit targets
MUST be named individually and ADDED to file_scope at plan time, after Phase 1 has ranked them.

ACCEPTANCE.
  1. The probe runs clean, is registered, and reports all 16 present-extension templates as
     REACHABLE (the regression fixture above).
  2. Its output is reproducible across two runs and does not read .claude/**.
  3. The eager/lazy classification agrees with measure-eager-context.sh's totals -- two probes
     must not disagree about what is eager.
  4. Every file removed in Phase 3 has a recorded probe verdict and a stated reference-style check
     against all three styles.
  5. run-all.sh green -- read the summary line AND the exit code, and do NOT pipe it through
     tail/head.
  6. verify-deploy.sh --skip-slow no worse than at task start.

DEPENDENCIES AND WHY.
  - The eager-context budget task performs exactly the rule -> lazy-narrative split this task's
    Phase 3 generalizes, and CREATES a new context/standards file. Measuring the corpus before it
    lands measures a state about to change, and its split is the worked exemplar to follow.
  - The task.md slimming task moves reference material into six new lazily loaded context/patterns
    files. A corpus inventory taken before those exist is stale on arrival.
  - The routing-ladder collapse removes a routing mechanism and may orphan its context; measuring
    before it lands would miss exactly the kind of dead content this task exists to find.

DELIVERABLE RULE: no task numbers in deliverables outside specs/** (no-task-references-in-deliverables.md).

---

### 170. Audit and isolate shell test suites from ambient host state (memory and timing axes), and record the convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 206, Task 215, Task 250, Task 251

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
