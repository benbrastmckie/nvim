---
next_project_number: 153
---

# TODO

## Task Order

*Updated 2026-09-04. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,29,39,43,44,45,51,89,127,136,137,139,148,151,152 | -- | core-agent-system, extensions, literature, ... |
| 2 | 30,74,88,140 | 29,139,148 | core-agent-system, extensions |
| 3 | 14,75,76,129,142,150 | 74,88,139 | core-agent-system, extensions |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

44 [PLANNED] — LOWER PRIORITY (per-invocation cost, not per-session). `commands/
51 [NOT STARTED] — Stop session-scoped orchestration runtime files from accumulating
89 [NOT STARTED] — Apply the mode-gated section convention to the two remaining larg
127 [NOT STARTED] — === REVISED 2026-09-01 (backlog streamline: absorbs the present-r
136 [NOT STARTED] — PRODUCER-SIDE root cause of the malformed plan-level Status line 
137 [IMPLEMENTING] — The lean extension's research and implementation agents have no a
139 [NOT STARTED] — Bare git history rewrites (`git commit --amend`, `git reset` with
  └─ 14 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) ===
  └─ 140 [NOT STARTED] — Give agent-system/extensions/core/hooks/guard-destructive-git.sh 
148 [PLANNED] — Port team fan-out, hard-mode counters, loop guard, and the auxili
  └─ 88 [NOT STARTED] — === ADDENDUM 2026-09-02 (team mode deleted; dry-run report retire
    └─ 14 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) === (see above)
    └─ 129 [NOT STARTED] — Audit every `\b` word-boundary construct used in a grep pattern a
    └─ 142 [NOT STARTED] — === REVISED 2026-09-02 (thin-lead path: narrowed to measure-and-l
    └─ 150 [NOT STARTED] — Research on demand: let the planner decide whether a research pha
151 [NOT STARTED] — Two verify-deploy.sh gate failures are live in this repo today, b
152 [NOT STARTED] — An unrelated multi-task /orchestrate batch was fully blocked by t

### Extensions

29 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core
  └─ 30 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core
43 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core
74 [NOT STARTED] — Build a shared, task-type-agnostic guard script that detects a us
  └─ 75 [NOT STARTED] — Wire the shared LaTeX build guard into the latex extension's life
  └─ 76 [NOT STARTED] — Close the coverage gap that the latex-extension wiring cannot rea

### Literature

39 [PLANNED] — Upgrade the literature extension's Zotero integration beyond bare

### Neovim

45 [NOT STARTED] — TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carr

### Opencode

22 [RESEARCHING] — === REVISED 2026-09-01 (backlog streamline: .opencode declared FR

## Tasks

### 152. Stop hand-maintained line_count drift and unrelated red gates from blocking task completion and whole batches
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: An unrelated multi-task /orchestrate batch was fully blocked by three stale line_count integers. This entry addresses the CLASS of defect, not the instances (a sibling task fixes the two live remaining gate failures).

WHAT HAPPENED, verified.
index-entries.json declares a line_count per context entry, hand-maintained, and check-extension-docs.sh Rule R fails when a declaration drifts from the file's actual line count. Three entries had drifted:
  core/index-entries.json  patterns/postflight-control.md   declared 318, actual 405
  core/index-entries.json  schemas/state-schema.json        declared 267, actual 271
  literature/index-entries.json  project/literature/patterns/zotero-item-creation.md  declared 208, actual 234
In every case the FILE was unchanged (byte-identical across many commits) and only the DECLARATION was stale; the last commits touching those files belonged to unrelated earlier tasks. The failing declarations had nothing to do with the work in flight.

THE COUPLING THAT TURNED THREE INTEGERS INTO A FULL BATCH STALL.
  1. check-extension-docs.sh Rule R fails on the drift.
  2. verify-deploy.sh gate 3 (doc-lint) therefore fails.
  3. deploy-headless.sh runs verify-deploy.sh after deploying and exits non-zero on ANY gate failure.
  4. skill-orchestrate's inter-cycle redeploy checkpoint (scripts/orchestrate-cycle-plan.sh, the `if bash deploy-headless.sh; then ... else` branch) treats a non-zero deploy-headless exit as a deploy FAILURE and moves EVERY remaining task into deferred_deploy_checkpoint, stopping the batch.
Note the asymmetry that makes this worse than it needs to be: that checkpoint ALREADY has a pre-existing-baseline branch (compare pre- and post-redeploy findings; proceed when 0 are newly introduced, recording a verify_deploy_baseline_notices entry). But that branch lives INSIDE the deploy-succeeded arm, so it is unreachable whenever deploy-headless.sh itself exits non-zero -- which is exactly what a pre-existing verify failure causes. The tolerance mechanism that was built for this situation cannot fire in this situation.
Independently confirmed: the completion-deploy gate (update-task-status.sh exit 6) checks only per-task deploy FRESHNESS, not whole-repo verify health -- after a successful resync it passed and both blocked tasks completed, even with two unrelated gates still failing. So the batch-level stall was strictly harsher than the per-task gate required.

WORK -- two independent axes; both are in scope, and each should be justified separately.

(a) STOP HAND-MAINTAINING line_count. A declared integer that must be manually kept in sync with a file's length is a drift generator: it carries no information a reader needs that `wc -l` cannot produce on demand, and every edit to any indexed file is a chance to forget it. Evaluate, and pick with stated reasoning: (i) derive line_count at deploy/index-generation time instead of declaring it, (ii) keep the declaration but auto-repair it (the codebase already has a --fix idiom in validate-artifact.sh; note that the auto-repair-reporting task decided in-place repair must be REPORTED, never silent -- honor that precedent), or (iii) drop line_count entirely if nothing consumes it for more than display. DETERMINE WHAT ACTUALLY READS line_count before choosing (iii); do not assume it is unused.

(b) DECOUPLE unrelated gate health from task completion and batch progress. A pre-existing failure in a gate that has nothing to do with the changed files should not deny an unrelated task its completion transition, nor defer an entire batch. Evaluate, with reasoning: extending the checkpoint's existing pre-existing-baseline tolerance to cover a non-zero deploy-headless exit (so the baseline comparison decides, rather than being skipped); and/or having deploy-headless.sh distinguish "the deploy itself failed" from "the deploy succeeded but a pre-existing, unrelated gate is red", which are today the same exit code. A THIRD, ALREADY-OBSERVED confound belongs in this analysis: deploy-headless.sh also exits 3 merely because OTHER consumer repos are stale, a condition it explicitly refuses to act on ("this script never redeploys into a consumer") and which says nothing about this repo's deploy health.

CONSTRAINTS.
  - All edits target agent-system/extensions/**, never .claude/**.
  - Do NOT make gates non-blocking wholesale. The goal is that a failure blocks what it is actually evidence about, not everything. A genuinely broken deploy must still stop the batch.
  - scripts/orchestrate-cycle-plan.sh and update-task-status.sh are orchestrator-critical paths; expect the self-modification ordering gate to apply.

ACCEPTANCE.
  - A line_count drift can no longer occur silently, by whichever mechanism (a) selects; demonstrated by editing an indexed file and showing the gate stays green without a manual declaration edit.
  - A pre-existing, unrelated red gate no longer defers an entire /orchestrate batch; demonstrated against a deliberately-introduced pre-existing failure, showing the baseline branch fires and the batch proceeds with a recorded notice.
  - A genuinely NEW failure introduced by the batch's own changes still stops it; demonstrated, so the tolerance is proven narrow rather than assumed narrow.
  - The three confounded exit-3 causes (deploy failed / pre-existing red gate / stale consumer repos) are distinguishable by a caller.

---

### 151. Fix the two pre-existing verify-deploy gate failures (state-writer boundary, whole-tree orphan)
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Two verify-deploy.sh gate failures are live in this repo today, both PRE-EXISTING and unrelated to whatever task happens to be running when they surface. They were observed blocking an unrelated multi-task /orchestrate batch: verify-deploy.sh reported "FAIL -- 3 of 29 check(s) failed", deploy-headless.sh therefore exited 3, and the orchestrator's inter-cycle redeploy checkpoint deferred EVERY task in the batch. One of the three (doc-lint, stale index-entries.json line_count declarations) was fixed at that time; these two remain.

FAILURE 1 -- STATE-WRITER BOUNDARY LINT (gate 12).
scripts/lint/lint-state-writer-boundary.sh reports "Found 4 hand-rolled state.json write(s)", all four in ONE file:
  agent-system/extensions/core/scripts/tests/test-force-phases.sh:261
    jq '.active_projects[0].status = "planned"' specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json
  agent-system/extensions/core/scripts/tests/test-force-phases.sh:307
    jq '.active_projects[0].next_artifact_number = 2' "$WORKDIR/specs/state.json" > "$WORKDIR/specs/state.json.tmp" && mv ...
  agent-system/extensions/core/scripts/tests/test-force-phases.sh:317  (same shape as :307, .status = "planned")
  agent-system/extensions/core/scripts/tests/test-force-phases.sh:327  (same shape as :307, .status = "planned")
Last commit touching that file is an earlier, unrelated task's phase-7 work; the file appears in NO recent task's modified_files. These are test-fixture writes against a scratch $WORKDIR, not production state mutations -- which is precisely the judgment call this task must make explicitly rather than reflexively rewriting them.

DECIDE, do not assume: is the correct remedy (a) route these through state-write.sh like production callers, (b) add a scoped allowlist entry for test-fixture writes against a scratch WORKDIR (the lint already has a file-level allowlist mechanism, used by task.md, todo.md, validation.md, jq-escaping-workarounds.md, vault-operation.sh and the lint's own header), or (c) narrow the lint's own detection so a non-specs/ scratch path is not matched? Note that :261 writes the REAL specs/state.json path, while :307/:317/:327 write "$WORKDIR/specs/state.json" -- these two shapes may not deserve the same answer. State the choice and its reasoning; do not silently weaken a boundary lint that exists to protect the single-writer invariant.

FAILURE 2 -- WHOLE-TREE ORPHAN DETECTION (gate 13).
verify-deploy.sh reports "whole-tree orphan detection reported 1 finding(s)" (find_orphans: deployed-but-undeclared files, ghost index rows). The specific finding was NOT captured at observation time -- the detail run exceeds a 120s timeout because the gate suite runs the full shell test suite. RESEARCH MUST establish what the single finding actually is before planning a fix; do not assume it is the same class as FAILURE 1. Remedy pointer named by the gate output itself: context/patterns/deploy-orphan-detection.md. Re-run detail with: bash agent-system/extensions/core/scripts/verify-deploy.sh (without --quiet), allowing several minutes.

CONSTRAINTS.
  - All edits target agent-system/extensions/**, never .claude/** (deploy artifact).
  - Do not weaken a gate merely to make it pass. If a finding is a genuine false positive, fix the DETECTION and say so; if it is a real violation, fix the violation.
  - Redeploy and confirm verify-deploy.sh reports 0 failures afterwards.

ACCEPTANCE.
  - lint-state-writer-boundary.sh --verbose reports 0 violations, with the chosen remedy and its reasoning recorded in the summary.
  - Whole-tree orphan detection reports 0 findings, with the finding's actual identity documented (not merely made to disappear).
  - bash verify-deploy.sh completes with all gates passing.
  - A regression note explains why each fix will not silently re-break.

RELATED, not a dependency: the sibling task on line_count/gate-coupling brittleness addresses the CLASS of problem (why an unrelated pre-existing lint failure can gate every task's completion). This task fixes the two live instances; that one changes the coupling. Either can land first.

---

### 150. Research on demand: planner-first lifecycle with research only when the planner asks or --research forces it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88

**Description**: Research on demand: let the planner decide whether a research phase is needed, and run one only when it asks for it or when --research forces it. Decided 2026-09-02 (specs/PATH.md, Decisions). Stage A.8 of specs/PATH.md. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

WHY. Every task runs research -> plan -> implement today, yet most filings in this system are already specifications: they carry the defect, the measured evidence, the work list and the acceptance bar. A research dispatch on such a task re-derives what the description states and costs a full agent run plus a cycle. The decision whether research is needed belongs to an agent, not to the orchestrator and not to a keyword heuristic.

DESIGN (binding; the planner of this task refines mechanics, not the shape).
(a) Default lifecycle becomes plan -> implement. A task at [NOT STARTED] with no report is dispatched to the PLANNER first. The planner's contract gains an opening step: assess whether the description plus what it can read in the codebase suffices to write a plan that meets plan-format.md. If yes, plan as today; status advances to [PLANNED] (the [RESEARCHED] state is simply not visited). If no, it writes no plan and returns verdict `needs_research` in its return metadata with a focused list of the questions research must answer; it does not attempt partial planning.
(b) orchestrate-cycle-plan.sh / orchestrate-triage-classify.sh: a `needs_research` verdict recorded by the postflight script routes the task to the research phase on the next cycle, with the planner's questions carried into the dispatch file as the research focus; after research, the task returns to plan as today. `--research` (the phase-forcing flag) forces the research phase first exactly as it does now and bypasses the planner's assessment. A task that already has a report is never asked again.
(c) orchestrate-cycle-postflight.sh: relay `needs_research` as a verdict (no status regression; the task stays [NOT STARTED] or [RESEARCHING]-equivalent by the existing vocabulary -- decide and record which); record nothing as a defect.
(d) Contracts and docs: planner-agent.md (and extension planner agents, swept with negatives) gain the assessment step and the bar for asking -- research is requested only when the plan would otherwise rest on guesses about facts an agent can establish (external APIs, unfamiliar code paths, literature), never as a default; the research-agent contract is unchanged except that the dispatch file may now carry the planner's question list; status-markers.md and the state-machine doc describe the two-phase default with research on demand; the return-metadata format gains the verdict field.
(e) Memory retrieval and --lit still run at every dispatch through the dispatch builder, so a planner dispatched first receives the same context a research dispatch would.

MUST NOT: skip research when `--research` is passed; let the orchestrator decide (the classifier only routes on the recorded verdict); weaken plan-format.md's requirements to make planning-without-research easier.

ACCEPTANCE: a specification-shaped task goes [NOT STARTED] -> [PLANNED] -> [COMPLETED] in two dispatches with a plan that passes validate-artifact.sh; a task whose planner returns `needs_research` is shown routing to research with the question list in its dispatch file and then back to plan; `--research` on a fresh task runs research first; fixture tests for both routes; full gate run green.

DELIVERABLE RULE: no task-number references in deliverables outside specs/**.
REFERENCE: specs/PATH.md, "Decisions".

---

### 148. Port hard-mode counters, loop guard and auxiliary dispatches into the batch engine as per-dispatch options
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 143
- **Research**: [148_port_single_task_features_to_batch_engine/reports/01_port-single-task-features.md]
- **Plan**: [148_port_single_task_features_to_batch_engine/plans/01_port-single-task-features.md]

**Description**: Port team fan-out, hard-mode counters, loop guard, and the auxiliary dispatches into the multi-task engine as per-dispatch options, so that a single task number runs as a batch of one. Stage A.5 of specs/PATH.md (thin-lead path); the precondition for deleting the single-task engine. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DECIDED DESIGN (do not re-litigate). Single-task mode is deleted by the successor task; /orchestrate N becomes a batch whose wave table has one row. Every capability that exists only in single-task Stages 1-8 today must exist as a per-row option or a script in the batch engine first.

WORK.
(1) TEAM. Stage 3.6 / 3.6a (19,414 B) becomes scripts/orchestrate-team-fanout.sh: teammate-plan construction, per-teammate dispatch files via orchestrate-build-dispatch.sh, {NN}_{letter}-findings.md naming, territory contracts, and the synthesis dispatch (synthesis-agent unchanged). A cycle-plan row with team=true is dispatched through it; the graceful degradation when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is unset lives in the script. `--team` in multi-task mode applies per row (remove the accepted-and-ignored notice); the planner of this task decides and records any cap on total concurrent teammates across a wave.
(2) HARD. The Stage 2 loop-guard/churn-state initialization, Stage 5b churn detection and three-strikes, and the Stage 3c burnout circuit-breaker move into scripts/orchestrate-churn.sh, called from the cycle-postflight script when hard_mode; the H1 single-blocking-phase-per-cycle limiter moves into orchestrate-cycle-plan.sh. Contract injection is already script-side (build-dispatch) and needs no change.
(3) LOOP GUARD. Single-task Stage 2/7's budget and orchestrate-loop-guard-init.sh reconcile with MAX_CYCLES_MT into ONE counter in the multi-state file, --continue-budget honored in one place.
(4) AUXILIARY DISPATCHES. Stage 5a drift inspection and Stage 6 blocker escalation become rows the cycle-plan script emits on the next cycle when a postflight verdict is `blocked` or a drift signal fires; they keep their frontmatter models and never call build-dispatch's memory/lit path (as today).
(5) Route a single task number through the batch path behind a feature flag (or an environment variable) and run the retargeted hard-mode/team test set against it. Leave Stages 1-8 on disk, unreachable, for the successor deletion task.

MUST NOT: drop any row of specs/PATH.md's capability table; change any decision the existing scripts make; touch user-prompting (the orchestrator never asks on its own).

ACCEPTANCE: each of the five items demonstrated on a live invocation carrying ONE task number routed through the batch engine (a --team run, a --hard run with the churn script firing on a fixture, a budget-exhaustion stop, a blocker-escalation row); hard-mode and team tests green; full gate run green.

DELIVERABLE RULE: no task-number references in deliverables outside specs/**.
REFERENCE: specs/PATH.md, "One engine, batch of one".
=== ADDENDUM 2026-09-02 (team mode deleted; hard mode kept in full) ===
Item (1) TEAM is withdrawn: team mode is deleted by its own predecessor task, so there is no fan-out to port and no orchestrate-team-fanout.sh to build; the `team` field on cycle-plan rows is dropped. Item (2) HARD stands as written and in full -- the decision is to KEEP the stateful half (churn / three-strikes counters and the burnout breaker) alongside contract injection, so orchestrate-churn.sh is built as specified. Items (3), (4) and (5) stand. The --team acceptance case is withdrawn; the remaining acceptance cases stand.

---

### 143. Build orchestrate-cycle-postflight.sh: per-task postflight as one script (absorbs the MT handoff gates)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 147
- **Research**: [143_mt_handoff_staleness_and_dispatch_seq_gates/reports/01_cycle-postflight-consolidation.md]
- **Plan**: [143_mt_handoff_staleness_and_dispatch_seq_gates/plans/01_cycle-postflight-script.md]
- **Summary**: [143_mt_handoff_staleness_and_dispatch_seq_gates/summaries/01_cycle-postflight-script-summary.md]

**Description**: === REVISED 2026-09-02 (thin-lead path: widened into the per-task postflight script) ===
SUPERSEDING SCOPE. The two gates below are the seed of scripts/orchestrate-cycle-postflight.sh, Stage A.4 of specs/PATH.md: ONE script that performs everything the lead does after an agent returns, for both engines, returning one JSON line. This absorbs three sibling tasks whose work is the same script (each abandoned with a pointer here): the expected-handoff-absence recording-order defect, the multi-task artifact-round advance, and the aggregator file_scope excursion advisory.

WORK. Script scripts/orchestrate-cycle-postflight.sh <task_number> --session SID --state-file F performing, in order:
(a) Handoff read guarded by the mtime staleness gate (fail-closed 9999999999 default) and the dispatch_seq identity gate -- the original defect below, now on both paths by construction.
(b) Return-meta recovery via orchestrate-recover-outcome.sh, which must gain the same dispatch_seq identity check it lacks today (its fallback is mtime-windowed only; the git-restored-predecessor incident recorded under the absorbed recording-order task shows mtime alone is inert against that shape).
(c) Phase-count corroboration via skill_corroborate_phase_counts (count-only greps, unchanged bounds).
(d) Writer-contract-aware recording: BEFORE recording HANDOFF_STALE_OR_ABSENT, consult whether the dispatched writer is a contractual non-writer for this phase, keyed on dispatch identity (dispatch_seq) and not on phase alone. A contractual non-writer leaving no fresh handoff records no defect; a seq-mismatched late write from a live or resurrected predecessor still does. Both live incidents recorded under the absorbed task (evt_1787614360544_SgKpRP, evt_1788246742189_Fodegl) become fixtures.
(e) user_decision relay: when .return-meta.json or the handoff carries `user_decision`, emit verdict `ask_user` with the payload and leave status exactly as the agent left it; the lead asks, writes the answer to specs/{NNN}_{slug}/.decisions.json, and the next dispatch file carries it. The script never asks and never decides.
(f) Status transition via update-task-status.sh with the monotonic-max clamp for forced phases.
(g) Artifact link (same-type supersession, append-only otherwise) and the artifact-round advance on research and on a forced plan/implement -- closing the multi-task advance gap (verify the call graph: the single-task advance lives in orchestrate-stage5-postflight.sh, not orchestrator-postflight.sh, which /orchestrate never calls).
(h) modified_files vs file_scope excursion advisory: compare the agent's reported modified_files against the task's declared file_scope and log any path outside it (detection only; no gate change).
(i) Per-task scoped commit via git-commit-scoped.sh (never a batch commit).
(j) Multi-state update and task-lock release.
Output: ONE JSON line {task, phase, status, phases_completed, phases_total, verdict: ok|defer|blocked|failed|ask_user, user_decision?, note}. Both engines call it (single-task Stage 5/8 and MT-4/MT-5) until the single-task engine is deleted; the relocated prose goes to docs/architecture/, which the lead never loads.

MUST NOT: read report, plan, summary or handoff prose; batch commits; weaken either gate; ask the user; move state.json except through update-task-status.sh / state-write.sh.

ACCEPTANCE: fixture regression tests proving (1) a handoff with mtime predating the dispatch window and (2) a dispatch_seq mismatch each route to recovery rather than being trusted; (3) git-restored predecessor files are rejected by recovery too; (4) a contractual non-writer with no handoff records no defect while a genuine late write still does; (5) a user_decision payload is relayed intact; a live multi-task cycle run through the script; bytes removed from SKILL.md reported; full gate run green.

REFERENCE: specs/PATH.md, "The four moves per cycle".
=== ORIGINAL DESCRIPTION FOLLOWS ===Port the handoff staleness gate and the dispatch_seq identity gate to the multi-task postflight path in skill-orchestrate/SKILL.md. Both gates exist in single-task Stage 5 and neither exists in Stage MT-4; the multi-task path therefore trusts any handoff file that happens to sit at the expected path.

DEFECT. Single-task Stage 5 applies two checks before trusting .orchestrator-handoff.json: (a) an mtime staleness gate comparing the handoff's mtime against this dispatch's own dispatch_start_ts, fail-closed via a 9999999999 default so a dispatch site that forgot to set its window marks the handoff stale rather than trusting it; and (b) a dispatch_seq identity gate comparing the handoff's echoed dispatch_seq against the value the orchestrator minted for this cycle, which is the only check that can discriminate a woken predecessor's late write (such a write always carries a NEWER mtime and so passes the mtime check looking exactly like an on-time report). Either failing sets handoff_stale=true, routes to .return-meta.json recovery, and records a HANDOFF_STALE_OR_ABSENT system defect. Stage MT-4 step 1 has neither gate: it reads the handoff whenever the file exists and only attempts recovery when the file is absent.

OBSERVED. During a live multi-task run, a task directory carried a handoff left by an earlier interrupted session, with mtime predating the dispatch window and dispatch_seq=4 against the cycle's minted 1, reporting status "planned" and phases_completed 0 -- while the dispatch that had just returned actually completed 6 of 6 phases. Stage MT-4 step 1 as written would have consumed that stale file and reported a completed task as planned with zero phases done, regressing real work. The correct outcome was only reached by checking mtime and dispatch_seq by hand and routing to the return-meta recovery path instead.

WHY THIS IS CHEAP. Multi-task mode already records both inputs the gates need: Stage MT-4's own dispatch-time mint snippet writes dispatch_start_ts[task_num] and dispatch_seq[task_num] into the multi-state file in one atomic read-modify-write. Nothing new needs to be captured -- only the comparison is missing.

WORK. Add both gates to Stage MT-4 step 1, ahead of its existing "if present, continue to step 2" branch, mirroring single-task Stage 5's shape and semantics rather than inventing a second convention. A stale or seq-mismatched handoff must route into the EXISTING return-meta recovery path, not a new branch. Record the detection through the existing append_detected_defect_mt idiom with defect_class HANDOFF_STALE_OR_ABSENT. While there, evaluate whether the stray-handoff sweep that single-task mode gets from orchestrate-stage5-gates.sh should also serve the multi-task path, or whether a narrower fix is correct -- decide and record the reasoning either way.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/skills/skill-orchestrate/SKILL.md (never .claude/**).

ACCEPTANCE. A fixture-driven regression test proving that (1) a handoff with mtime predating the dispatch window and (2) a handoff whose dispatch_seq does not match the minted value each route to return-meta recovery rather than being trusted; both engines visibly agree on the gate semantics; full gate run green.

---

### 142. Orchestrator context budget: measure and lock
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88

**Description**: === REVISED 2026-09-02 (thin-lead path: narrowed to measure-and-lock; absorbs the context-budget gate) ===
SUPERSEDING SCOPE. The sweep described below is now the Stage A chain in specs/PATH.md (slim command, dispatch builder, cycle-plan, cycle-postflight, feature port, engine deletion). This task is the measurement and the lock, and it absorbs the warning-first context-budget gate from the abandoned verify-deploy context-gates task (its broken-@-ref half already holds and needs no work).

BASELINE (measured 2026-09-02; record in this task's report before anything else): skills/skill-orchestrate/SKILL.md 293,977 B; commands/orchestrate.md 46,874 B; eager session load 63,973 B / ~16k tokens (measure-eager-context.sh); eager load before the first /orchestrate dispatch ~405 KB / ~100k tokens; lead-authored prompt text per 5-task cycle 25-60 KB (task descriptions average 4,612 B, max 11,598 B, interpolated inline).

WORK.
(1) Re-measure the four figures after each Stage A task lands; final before/after table in the summary.
(2) Extend verify-deploy.sh with a warning-first context-budget gate: the eager-load ceiling from measure-eager-context.sh (fail above the recorded baseline, print the number on every run so drift direction is visible), plus per-file ceilings for skills/skill-orchestrate/SKILL.md (20,000 B) and commands/orchestrate.md (8,000 B) read from a small config file in the source store. Warn tier first; promote to hard failure once the warning has been stable across a stated number of deploys. Volatile files in the eager set remain an unconditional failure.
(3) A per-cycle growth probe: a test or a documented procedure that measures the lead's context growth on a 3-task batch (bytes of cycle-plan JSON + pointer prompts + postflight JSON) and records it, so the "~1 KB per task per cycle" target is a number, not a claim.
(4) Correct the Context Flatness prose wherever it survives (state-machine doc) to state the measured figure.

MUST NOT DAMAGE (unchanged from the original): the four admission gates and their defer-not-fail semantics; the handoff staleness and dispatch_seq identity gates; per-task scoped commits; the inter-cycle redeploy checkpoint; task-lock acquire/heartbeat/release.

ACCEPTANCE: the before/after table; both gates wired, exercised on a fixture that exceeds each ceiling, and green on the real tree; Gate 19 green; full gate run green.

REFERENCE: specs/PATH.md, "Budgets".
=== ORIGINAL DESCRIPTION FOLLOWS ===Reduce the orchestrator's own token consumption so that multi-task /orchestrate runs can proceed much further before exhausting context. Review-and-optimize task: identify every optimization available WITHOUT damaging functionality, quantify each, and land the safe ones.

PROBLEM. The orchestrator lead is the context bottleneck in multi-task runs. Its eager load is dominated by two runtime-loaded .md files read IN FULL on every invocation: commands/orchestrate.md and skills/skill-orchestrate/SKILL.md (the latter alone is ~190k characters as deployed). The lead then accumulates further context per cycle from admission verdicts, classifier NDJSON, handoff/return-meta reads, and its own warning text. Observed in practice: a 5-task batch consumed a large fraction of available context before the second dispatch completed.

RELATIONSHIP TO EXISTING WORK (do not duplicate). Task 87 landed the mode-gated section loading convention plus a lint (verify-deploy Gate 19) for exactly this defect class. Task 88 already owns the single largest instance -- extracting skill-orchestrate/SKILL.md's `## Multi-Task Mode` section (103,462 B, 55% of the file). This task is the BROADER sweep that those two do not cover; it must build on the convention rather than re-deciding it, and must not re-do task 88's extraction.

SCOPE TO INVESTIGATE.
1. Remaining mutually-exclusive branch sections in skill-orchestrate/SKILL.md beyond the multi-task one: the Stage 3.6/3.6a team fan-out (fires only under --team), Stage 5a vs Stage 5b (mutually exclusive on hard_mode by construction), and any hard-mode-gated regions that survive the hard-mode deletion work.
2. Procedural bash currently inline in SKILL.md. The convention notes that moving procedural bash to scripts/ removes it from context ENTIRELY, whereas moving prose to context/ saves only on invocations that do not need it -- so bash extraction is the strictly stronger lever and should be enumerated first.
3. commands/orchestrate.md itself, which carries large bash blocks its own text explicitly labels illustrative-not-executed (the runtime wave-split check, the consolidated-output template). These cost tokens on every invocation and execute never.
4. Per-cycle growth: measure actual per-cycle context cost against the ~450 tokens/cycle the Context Flatness Constraint claims, and identify what exceeds it (verdict JSON, classifier output, repeated warning prose, re-read state).
5. Further delegation of lead work to scripts that return compact decision JSON -- the pattern orchestrate-stage5-gates.sh and orchestrate-stage5-postflight.sh already establish. Enumerate what remains inline in the lead that could follow the same shape.

METHOD. Establish a measured baseline first (scripts/measure-eager-context.sh exists), quantify each candidate in bytes/tokens, and rank by saving-per-unit-risk. Report measured numbers, not estimates.

MUST NOT DAMAGE. These are load-bearing safety mechanisms and must survive unchanged in behavior: the four admission gates and their defer-not-fail semantics; the handoff staleness and dispatch_seq identity gates; per-task scoped commits (never a batch commit); the inter-cycle redeploy checkpoint; task-lock acquire/heartbeat/release. An optimization that weakens any of these is out of scope regardless of its saving.

ACCEPTANCE. Measured before/after numbers for the orchestrator's eager load, the safe optimizations landed, Gate 19 green, and full gate run green.

---

### 140. Add a concurrency-gated history-rewrite predicate to guard-destructive-git.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 139

**Description**: Give agent-system/extensions/core/hooks/guard-destructive-git.sh a SECOND, INDEPENDENT predicate that blocks or loudly warns on history rewrites (`git commit --amend`, `git reset` without `--hard`) when evidence of a concurrent writer exists. This is the enforcement half of the policy its predecessor task establishes in the rules and agent contracts.

WHY A SECOND PREDICATE AND NOT AN EXTENSION OF THE FIRST. The hook's entire existing design is built around ONE hazard: discarding UNCOMMITTED working-tree changes. Its header states the premise directly -- "block destructive git commands when the working tree is dirty" (lines 3-5) -- and its first live check is the clean-tree exemption, "working tree is already clean (git status --porcelain is empty)" / "Clean tree -> nothing to lose" (lines 19-23, check at lines 61-64). The hazard this task addresses is a different class: rewriting ALREADY-COMMITTED history owned by a concurrent writer. Both commands involved are non-destructive to the working tree, so the clean-tree exemption would have ACTIVELY WAVED THEM THROUGH. Merely adding `--amend` to the existing dirty-tree predicate would still not fire. The new predicate must therefore not consult tree dirtiness at all. Verified: the file matches `amend` 0 times and `mixed` 0 times today.

MOTIVATING INCIDENT (real, observed 2026-09-02, multi-task /orchestrate run, five concurrent implementation agents committing to master). An agent ran bare `git commit --amend` intending its own commit; a sibling agent's commit had landed on top in the interim, so the amend rewrote the sibling's commit, preserving its file content but overwriting its message. A follow-up `git reset --mixed <own-sha>` rewound HEAD past three further legitimate commits and intermingled their changes in the working tree. Recovered via reflog: trees identical, zero content lost, residual damage exactly one mislabeled commit message. Reconstructible evidence: 539561c39 (correct), 9c5b790b6 (orphaned original), fd50fabfd (tree-identical to 9c5b790b6, wrong message).

THE DESIGN TENSION TO RESOLVE, NOT PAPER OVER. The hook observes only the literal top-level tool_input.command string. It cannot see intent. An over-broad rule blocks legitimate solo interactive `--amend`, which is explicitly permitted. Research must select and justify a concurrency signal, weighing false-positive and false-negative cost. Candidate signals, none pre-committed:
  - a live entry in specs/.task-locks/ held by a session other than the caller's;
  - an in-flight session-registry entry belonging to a different session;
  - HEAD having moved since the calling agent's own last commit (directly diagnostic of the incident, but requires per-session commit-sha state the hook does not currently keep).
Also decide the response: hard refusal (exit 2 + stderr, matching the existing block mechanism -- note the header's warning that `permissionDecision: deny` is documented-buggy for allow-listed Bash(git:*) commands, GH #4669/#13214/#18312) versus a loud non-blocking warning. These may differ per signal strength.

DESIGN CONSTRAINTS.
  - The new predicate must be structurally independent of the clean-tree exemption; that exemption currently returns exit 0 before any detector runs, so predicate ordering is load-bearing.
  - `git-commit-scoped.sh` must remain unblocked. Note the existing header's observation-boundary argument (lines 41-47): a git command run as a subprocess inside a wrapper script never appears in tool_input.command, so wrapper-internal git is structurally invisible to this hook. Follow that established pattern rather than special-casing.
  - Reuse the file's existing argv-anchoring scan-string machinery (COMMAND_SCAN, quoted-span and comment stripping, lines 67+) so a commit message containing the text "--amend" cannot trigger a false positive.
  - The refusal message must point at the rule section its predecessor task adds, so a blocked agent can read the rationale.

WORK.
(a) Implement the concurrency-gated history-rewrite predicate in hooks/guard-destructive-git.sh.
(b) Update the hook's header comment block, which currently documents a single-hazard design and would otherwise misdescribe the file.
(c) Update context/standards/git-safety.md for the new hazard class and the chosen signal.
(d) Update rules/git-workflow.md's enumeration of what the hook enforces (its "enforced by" framing) so rules and implementation stay in agreement.
(e) Verify with concrete cases: a bare `--amend` under a foreign task lock is refused; the same command with no concurrent writer is permitted; a git-commit-scoped.sh invocation is permitted; a commit message containing the literal string "--amend" does not trigger.

NON-GOALS (explicit).
  - Do NOT forbid `--amend` unconditionally for single-session interactive use.
  - Do NOT attempt retroactive repair of the mislabeled commit fd50fabfd.

ACCEPTANCE. A bare `git commit --amend` or `git reset` issued by a dispatched agent while another session holds a task lock is refused or loudly warned; the rationale is reachable from the message; compliant git-commit-scoped.sh use remains unblocked; solo use is unaffected.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/. Never edit .claude/ directly. Redeploy and confirm the hook survives regeneration and actually fires from the deployed copy.

DEPENDENCY RATIONALE. Depends on its predecessor task on two grounds: that task settles the policy this one mechanizes and supplies the rationale text this hook's refusal message points at; and both tasks touch rules/git-workflow.md, so the file-footprint admission gate serializes them regardless.

---

### 139. Forbid concurrent-writer history rewrites in git rules and agent contracts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 146

**Description**: Bare git history rewrites (`git commit --amend`, `git reset` without `--hard`) are forbidden nowhere in the agent system, and the one place that looks like a prohibition is scoped so that it structurally cannot fire on the hazard that actually occurred. Add the prohibition to the rules and to the agent contracts, and correct the existing mis-scoped bullet rather than merely adding alongside it.

MOTIVATING INCIDENT (real, observed 2026-09-02 during a multi-task /orchestrate run with five concurrent implementation agents committing to master). An agent ran bare `git commit --amend` to add an attribution trailer to what it believed was its own commit. Between its commit and the amend, a DIFFERENT agent's commit landed on top, so the amend rewrote the sibling's commit instead -- preserving that sibling's file content but overwriting its message. The agent then ran `git reset --mixed <own-sha>` to undo, which rewound HEAD past three further legitimate commits and dumped their changes into the working tree intermingled. It caught this and restored HEAD via reflog. Verified afterward: trees identical, zero content lost; residual damage is exactly one mislabeled commit message still in history. Reconstructible reflog evidence: commits 539561c39 (correct), 9c5b790b6 (orphaned original), fd50fabfd (tree-identical to 9c5b790b6, wrong message).

WHY THIS IS A NEW PREDICATE, NOT A WIDENED OLD ONE -- the load-bearing finding. ALL THREE layers of the existing mechanism share one identical blind spot: each is scoped by dirtiness-of-tree, and the incident's hazard is concurrency-of-writers. Both commands involved are non-destructive to the working tree, so every existing guard would have actively waved them through.

  1. HOOK. agent-system/extensions/core/hooks/guard-destructive-git.sh states its own premise in its header: "PreToolUse Bash hook: block destructive git commands when the working tree is dirty" (lines 3-5), with the exemption "working tree is already clean (git status --porcelain is empty)" -- annotated in the file as "Clean tree -> nothing to lose" (lines 19-23, and the live check at lines 61-64). Verified: the file matches `amend` 0 times and `mixed` 0 times. It blocks only `reset --hard`, `checkout -- <path>`, `restore <path>`, `clean -f -d`, `stash drop`/`clear`, and forced `checkout`/`switch`.
  2. RULES. agent-system/extensions/core/rules/git-workflow.md's "Never Run" list (line 77) covers `push --force`, `reset --hard` on uncommitted work, `rebase -i`, `add -A`, `commit -am` -- but NOT `commit --amend` and NOT non-hard `reset`. Its sibling section at line 89 is titled "No Destructive Git on Uncommitted Work"; that title and framing structurally exclude already-committed history.
  3. AGENT CONTRACTS. agent-system/extensions/core/agents/general-implementation-agent.md carries no prohibition at all. Its `-hard` sibling (general-implementation-hard-agent.md, ~line 63, Recovery Ladder) says "Never `git reset`/`git checkout -- <path>`/`git restore` WHILE UNCOMMITTED CHANGES EXIST" -- the prohibition is itself gated on the dirty-tree predicate, so it too would have permitted this. This phrasing must be CORRECTED, not merely supplemented.

Verified across agent-system/extensions/core/{rules,context,agents}/: `--amend` has ZERO occurrences. It is forbidden nowhere.

WORK (contract and documentation layer only; the hook predicate is a separate task).
(a) rules/git-workflow.md: add `git commit --amend` and non-hard `git reset` to the "Never Run" list.
(b) rules/git-workflow.md: add a SIBLING section to "No Destructive Git on Uncommitted Work" covering rewrites of already-committed history under concurrent writers. Place it so a reader arriving at the uncommitted-work rule finds it -- the current title is precisely what makes this case invisible. Include the incident rationale and the concurrency-vs-dirtiness distinction.
(c) agents/general-implementation-agent.md: add a MUST NOT bullet against bare history rewrites, directing all commits through scripts/git-commit-scoped.sh, which serializes on the commit mutex and path-scopes staging. Empirical support: in the motivating run, four of five agents used git-commit-scoped.sh exclusively and had zero incidents; the one that did not caused the entire incident.
(d) agents/general-implementation-hard-agent.md: correct the Recovery Ladder bullet's "while uncommitted changes exist" scoping so the prohibition also covers committed-history rewrites under concurrent writers.

NON-GOALS (explicit).
  - Do NOT forbid `--amend` unconditionally for single-session interactive use. The discriminating variable is a concurrent writer, not the command itself.
  - Do NOT attempt retroactive repair of the mislabeled commit fd50fabfd. That is a separate operator decision to be made when the branch is quiet.

ACCEPTANCE.
  - `git commit --amend` and non-hard `git reset` appear in the "Never Run" list with the concurrency qualifier.
  - The rationale is documented where a reader looking at the uncommitted-work rule will find it.
  - general-implementation-agent.md carries an explicit git-commit-scoped.sh mandate.
  - general-implementation-hard-agent.md no longer scopes its git prohibition solely by tree dirtiness.
  - Compliant git-commit-scoped.sh use remains unrestricted.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/. Never edit .claude/ directly (it is a regenerated deploy artifact). Redeploy and confirm the change survives regeneration.

RELATED, NOT DUPLICATE. Task 72 covers teammate .return-meta.json ownership and marker correlation -- a different concern entirely.

---

### 137. Give the lean research and implementation agents the artifact skeletons their general-* counterparts already have
- **Status**: [IMPLEMENTING]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [137_lean_agent_artifact_skeletons/reports/01_lean-agent-artifact-skeletons.md]
- **Plan**: [137_lean_agent_artifact_skeletons/plans/01_lean-agent-artifact-skeletons.md]
- **Summary**: [137_lean_agent_artifact_skeletons/summaries/01_lean-agent-artifact-skeletons-summary.md]

**Description**: The lean extension's research and implementation agents have no artifact skeletons, so the artifacts they author fail validate-artifact.sh on required sections that their general-* counterparts get right by construction. Observed on a real completed task, not inferred.

OBSERVED FAILURES (BimodalLogic task 507, gate-out validation output, 2026-09-01):
  summaries/01_frame-level-validity-indexing-summary.md -> [FAIL] 6 error(s)
      Missing required section: ## Overview, ## What Changed, ## Decisions, ## Impacts, ## Follow-ups, ## References
      (4 metadata fields -- Started, Completed, Artifacts, Standards -- were auto-repaired to "TBD" placeholders)
  reports/01_frameclass-indexed-validity.md -> [FAIL] 13 error(s), 1 warning
      [WARN] Cannot auto-fix: no existing metadata lines found to anchor insertion
The report case is the worse of the two: with zero conforming metadata lines present, validate-artifact.sh's --fix path has no anchor to insert against and gives up entirely. The artifact is left non-conforming with no repair path.

ROOT CAUSE -- MISSING TEMPLATES, NOT MISBEHAVING AGENTS.
extensions/core/agents/general-implementation-agent.md carries a full inline summary skeleton (around :468-482): the metadata block, the bracketed Status vocabulary spelled out ("Use `**Status**: [COMPLETED]` when every plan phase is done, `**Status**: [IN PROGRESS]` on a partial run, `**Status**: [BLOCKED]` when blocked, matching summary-format.md's declared vocabulary"), and the required sections. An agent handed that template produces a conforming artifact without needing to consult the format spec.
The lean agents carry no such thing:
  extensions/lean/agents/lean-implementation-agent.md  -- grep for summary-format / ## What Changed / ## Decisions / ## Impacts / ## Follow-ups / ## References returns ZERO hits (its own `## Overview` at :9 is the agent file's own document heading, not a template)
  extensions/lean/agents/lean-research-agent.md        -- grep for report-format / ## Findings / ## Executive Summary / `**Task**:` returns ZERO hits
The agents are behaving reasonably given what they were handed. The defect is the missing contract.

AUTHORITATIVE REQUIREMENTS (from extensions/core/scripts/validate-artifact.sh, lines 19-44 -- transcribe from the script, do not retype from this description):
  REPORT_METADATA   = Task, Started, Completed, Effort, Dependencies, Sources/Inputs, Artifacts, Standards
  REPORT_SECTIONS   = Executive Summary, Context & Scope, Findings, Decisions, Recommendations
  SUMMARY_METADATA  = Task, Status, Started, Completed, Artifacts, Standards
  SUMMARY_SECTIONS  = Overview, What Changed, Decisions, Impacts, Follow-ups, References
  SUMMARY_SECTIONS_OPTIONAL = Plan Deviations
  Note the script's own comment: SUMMARY_SECTIONS is a required MINIMUM, not an exhaustive whitelist.
The prose specs are extensions/core/context/formats/summary-format.md (its Example Skeleton section) and the report-format equivalent.

WORK.
(a) Add an inline summary skeleton to extensions/lean/agents/lean-implementation-agent.md, modelled on general-implementation-agent.md's, including the explicit bracketed-Status vocabulary sentence -- that sentence is why the general agent's summaries carry a well-formed Status line, and its absence is directly implicated in the sibling defect this task's peer covers.
(b) Add an inline report skeleton to extensions/lean/agents/lean-research-agent.md covering REPORT_METADATA and REPORT_SECTIONS.
(c) SWEEP the other extensions' agents for the same gap rather than assuming lean is the only one. Known candidates to CHECK (not assume defective): extensions/lean/agents/lean-implementation-hard-agent.md, lean-research-hard-agent.md, and the formal extension's research agents. Report what was checked and what was found, including negatives.
(d) Where a skeleton already exists but is incomplete, prefer amending it over replacing it.

EXPLICIT NON-GOAL. Do not weaken validate-artifact.sh's required-section lists to make existing non-conforming artifacts pass. The artifacts are wrong, not the validator. Task 136 is separately TIGHTENING that validator; a loosening here would fight it directly.

ACCEPTANCE.
  - A lean-language task run end to end produces a summary and a report that both pass validate-artifact.sh with zero errors and zero auto-repairs -- demonstrated on a real dispatch, not on a hand-written fixture.
  - The sweep in (c) is reported with explicit negatives ("checked X, already conforming") so a later reader knows the search happened.
  - Redeploy and confirm the fix survives regeneration (.claude/ is a deploy artifact; the edit target is agent-system/extensions/lean/).

RELATED, NOT DUPLICATE. Task 13 (instrument_gate_out_auto_repair_reporting) covers REPORTING of auto-repair counts through command-gate-out.sh and skill-base.sh, and flags the silent-in-place-mutation hazard. It does not add any missing agent template. This task removes the need for those repairs at the source; 13 makes the repairs visible when they still happen. Both are worth having.

PROVENANCE. Surfaced 2026-09-01 by gate-out validation during an /orchestrate 507 run in the BimodalLogic repo. The validation warnings are non-blocking, which is why this had gone unnoticed: the task completed successfully with two non-conforming artifacts on disk.

---

### 136. Stop implementation agents hand-writing the plan-level Status field, and make the validator catch it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 91, Task 146

**Description**: PRODUCER-SIDE root cause of the malformed plan-level Status line that task 91 handles from the consumer side. Task 91 makes update-plan-status.sh diagnose the malformed line loudly; this task stops the line being written in the first place, and makes the validator catch it if it ever is.

EVIDENCE (git history of a real plan file, BimodalLogic repo, specs/507_parameterize_validity_by_frameclass/plans/02_frame-level-validity-indexing.md):
  bd68091cb  - **Status**: [NOT STARTED]     planner-agent, conforming
  b35d5c043  - **Status**: [IMPLEMENTING]    lifecycle transition, conforming
  463b00103  - **Status**: [IMPLEMENTING]    still conforming after phase 8
  3d50e2583  - **Status**: COMPLETED         <-- lean-implementation-agent hand-edit, BRACKETS LOST
  b7ccf6702  - **Status**: [COMPLETED]       manual orchestrator repair
The malformed line is authored by an IMPLEMENTATION AGENT, not by any script and not by the planner. update-plan-status.sh cannot produce an unbracketed line (its sed both requires and writes brackets), and plan-format.md is correct and unambiguous (bracketed form specified at lines 6, 16, 372). The plan format file is NOT the defect.

DEFECT 1 -- NO OWNERSHIP BOUNDARY IN AGENT CONTRACTS.
Implementation agents are told, emphatically, to Edit PHASE HEADING markers in the plan file:
  extensions/lean/agents/lean-implementation-agent.md:80   "**CRITICAL**: You MUST update phase status markers in the plan file at phase boundaries."
  extensions/lean/agents/lean-implementation-agent.md:99   new_string: "### Phase {P}: {exact_phase_name} [COMPLETED]"
  extensions/lean/agents/lean-implementation-agent.md:437  "**ALWAYS update plan file phase markers with Edit tool**"
  extensions/lean/agents/lean-implementation-agent.md:450  (forbids) "Leave plan file with stale status markers"
NOWHERE does any implementation-agent contract state that the plan-level metadata field `- **Status**:` is a DIFFERENT field with a DIFFERENT owner (update-plan-status.sh, driven by postflight via update-task-status.sh). An agent told "ALWAYS update plan file status markers" and "never leave stale status markers" generalizes from the phase headings to the metadata field -- which is exactly what happened -- and hand-typing loses the brackets.
Verified absent by grep for `update-plan-status|plan-level status|metadata Status` across:
  extensions/lean/agents/lean-implementation-agent.md          (zero hits)
  extensions/lean/agents/lean-implementation-hard-agent.md     (zero hits)
  extensions/core/agents/general-implementation-agent.md       (zero hits; its only `- **Status**: [COMPLETED]` at :476 is inside the SUMMARY template, a field the agent legitimately owns)
Note the asymmetry worth preserving: the general agent's summary template DOES spell out the bracketed vocabulary inline ("Use `**Status**: [COMPLETED]` when every plan phase is done..."). The plan-level field has no equivalent statement anywhere.

DEFECT 2 -- VALIDATOR CHECKS PRESENCE, NOT GRAMMAR.
extensions/core/scripts/validate-artifact.sh:120-124 is the entire metadata check:
  for field in "${metadata_fields[@]}"; do
    if ! grep -qF "**${field}**:" "$artifact_path"; then ... log_error "Missing metadata field" ...
It tests only that the substring `**Status**:` EXISTS. The bracketed-value grammar is never checked, for plans, reports, or summaries. Consequence, observed: the task-507 plan carrying `- **Status**: COMPLETED` validated as `[PASS] plan artifact is valid (0 warning(s))` while being unstampable by update-plan-status.sh. The validator is the layer that should have caught this before postflight did.

WORK.
(a) Add an explicit ownership boundary to every implementation-agent contract that instructs phase-marker editing. State that `- **Status**:` in the plan METADATA block is owned by update-plan-status.sh (invoked from update-task-status.sh postflight) and MUST NOT be hand-edited, and that the agent's plan-file write authority is limited to `### Phase N: ... [MARKER]` headings and checklist items. Apply to at minimum: extensions/lean/agents/lean-implementation-agent.md, extensions/lean/agents/lean-implementation-hard-agent.md, extensions/core/agents/general-implementation-agent.md, extensions/core/agents/general-implementation-hard-agent.md. SWEEP for other agents carrying phase-marker instructions (cslib-implementation-agent.md is a known candidate) rather than assuming the list above is complete.
(b) Add a Status-line GRAMMAR check to validate-artifact.sh, so a non-conforming value is an error, not a pass. Must cover the three malformed shapes task 91 enumerates: missing brackets, trailing text after the closing bracket, missing `- ` prefix.
(c) Decide whether the grammar check participates in --fix (in-place repair) or reports only. NOTE THE INTERACTION: task 13 (instrument_gate_out_auto_repair_reporting) is separately deciding whether --fix should remain in-place-mutating on the gate-out path at all. Do not silently add a new in-place mutation while that decision is open -- state the choice and its reasoning explicitly.

DEPENDENCY ON 91 -- LOAD-BEARING, NOT ADMINISTRATIVE. Task 91's deliverable (b) decides the tolerance policy for trailing text after the closing bracket: either accept `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)` by rewriting only the bracketed token, or reject it as malformed. The validator grammar in (b) above must ENFORCE whatever 91 decides. Implementing this task first would hardcode a guess and then need reworking. Sequence behind 91.

SCOPE BOUNDARY. This task does NOT touch update-plan-status.sh, update-task-status.sh, or context/formats/plan-format.md -- all three belong to task 91's file_scope. If documenting the ownership boundary in plan-format.md proves necessary, hand that edit to 91 rather than widening this task's scope into a file_scope collision.

ACCEPTANCE.
  - Every implementation agent carrying phase-marker instructions also carries the plan-level-Status ownership boundary; verified by grep, not by assumption.
  - validate-artifact.sh rejects all three malformed Status shapes on a plan artifact and passes the conforming shape, consistent with 91's trailing-text policy.
  - The --fix participation decision is stated in the summary with its reasoning, and is consistent with whatever task 13 concluded (or explicitly notes 13 as still open).
  - Redeploy and confirm the fix survives regeneration (.claude/ is a deploy artifact; the edit target is agent-system/extensions/).

PROVENANCE. Root-caused 2026-09-01 during an /orchestrate 507 run in the BimodalLogic repo, where the postflight status transition failed with "Failed to update status in .../plans/02_frame-level-validity-indexing.md" and the orchestrator repaired the line by hand. Consumer-side handling is task 91; this entry covers the producer and validator ends, which 91's file_scope excludes.

---

### 134. Close the tag-reachability gap so /tag never pushes a tag pointing at unpushed commits
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [134_tag_branch_reachability_gate/reports/01_tag-branch-reachability-gate.md]
- **Plan**: [134_tag_branch_reachability_gate/plans/01_tag-branch-reachability-gate.md]
- **Summary**: [134_tag_branch_reachability_gate/summaries/01_tag-branch-reachability-gate-summary.md]

**Description**: Close the third and last uncovered gate in the /tag release preflight: a tag created from a branch with unpushed commits points at a commit absent from origin/<branch>, so a consuming repo's release.yml preflight rejects it -- AFTER the tag has already been pushed, requiring a delete-and-re-push to recover.

CANONICAL SOURCE. Edit `agent-system/extensions/core/skills/skill-tag/SKILL.md` and, if the user-facing contract changes, `agent-system/extensions/core/commands/tag.md`. Do NOT edit any repo's deployed `.claude/skills/skill-tag/SKILL.md` -- it is a disposable artifact regenerated from this source store (see `.claude/rules/source-store-deploy-boundary.md`).

THE DEFECT, observed live during a real v1.3.9 release in a consuming repo:
- Step 2 ("Validate Git State") fetches `origin/$current_branch`, then computes ONLY `behind=$(git rev-list --count "HEAD..origin/$current_branch")` and errors solely when `behind > 0`. It never computes or acts on the symmetric `ahead`.
- Step 6 runs `git push origin "$new_version"` alone, with no corresponding branch push.
- The release only succeeded because the operator manually pushed the branch before tagging. Following the skill literally, from a branch 36 commits ahead, would have produced a pushed tag pointing at a commit absent from the remote.

PRIOR ART -- BUILD ON, DO NOT RE-DERIVE. This is the follow-up that the completed annotated-tag/changelog work explicitly filed rather than folded in. Read both before starting:
- `specs/131_tag_annotated_and_changelog_preflight/reports/01_tag-annotated-and-changelog-preflight.md` -- see its "Decisions" section, finding (4).
- `specs/131_tag_annotated_and_changelog_preflight/summaries/01_tag-annotated-changelog-preflight-summary.md` -- see its "Follow-ups" section, which quotes finding (4) verbatim precisely so this task need not rediscover it.

Quoting that recorded finding: "the fix is cheap and reuses data Step 2 already fetches. Step 2 already does `git fetch origin \"$current_branch\"` and computes `behind=$(git rev-list --count \"HEAD..origin/$current_branch\")`; the symmetric 'ahead' check is `git rev-list --count \"origin/$current_branch..HEAD\"` -- if nonzero, local `HEAD` has commits not yet on the remote, which is exactly the condition that will make a tag created against it unreachable from `origin/<branch>` and fail the reference preflight's third assertion. A follow-up task should point directly at `SKILL.md`'s Step 2 (not Step 3.5/3.6) and can almost certainly reuse the `remote_sha`/`behind` variables already computed there."

REFERENCE GATE, to verify the fix against a real assertion rather than an imagined one. The reference preflight (ModelChecker `.github/workflows/release.yml`) asserts, after fetching the tag ref:
    TAG_TYPE=$(git cat-file -t "refs/tags/${GITHUB_REF_NAME}")     # already satisfied
    git merge-base --is-ancestor "${GITHUB_REF_NAME}" origin/master  # NOT satisfied
The first half is closed by the annotated-tag work. The second half -- ancestry of the TAGGED COMMIT from `origin/<branch>` -- is what this task closes.

DESIGN QUESTIONS TO RESOLVE DELIBERATELY, NOT BY REFLEX. Each must be decided and the judgment recorded in the research report, in the same way the annotated-tag message source and the `-a` vs `-s` choice were recorded rather than defaulted into:

1. REFUSE vs. AUTO-PUSH. Either refuse when the branch is not fully pushed, with actionable resolution text ("Push the branch with `git push origin $current_branch` before tagging"), or push the branch automatically ahead of the tag push in Step 6. Default to REFUSE unless auto-push is affirmatively justified: pushing a branch is an outward-facing action with materially different risk than pushing a tag, and /tag is user-only precisely because deployment timing is a human decision. An auto-push silently publishes work the operator may not have intended to publish yet. If auto-push is chosen anyway, it must be explicit, previewed by --dry-run, and confirmed in the Step 5 interactive prompt -- never a silent side effect.

2. PLACEMENT. Step 2 ("Validate Git State", which already holds the `behind` check and the fetch this needs) versus a new step adjacent to Step 3.6. Step 2 is the natural home per the recorded finding above, but note the ordering consequence: the tag ref does not exist yet at Step 2, so a Step 2-placed check can only test HEAD, not the tag. Reconcile that against design question 3 before deciding.

3. EXACT PREDICATE, not a proxy. `ahead == 0` on HEAD is a PROXY for the CI gate; the CI gate's actual predicate is that the TAGGED COMMIT is an ancestor of `origin/<branch>`. These diverge whenever the tag is not created at HEAD. Determine whether /tag can ever tag a non-HEAD commit as currently written (Step 4 reports `git rev-parse HEAD` and Step 6 tags with no commit-ish argument, i.e. HEAD) and decide whether to mirror the CI predicate exactly via `git merge-base --is-ancestor` against the fetched remote ref, or to accept the `ahead` proxy with the equivalence explicitly recorded as a documented assumption. Do not leave the divergence unexamined.

4. --dry-run TRUTHFULNESS. The annotated-tag work established that the --dry-run preview must not misrepresent what a real run does (the preview line and the real command were required to change in step). Apply the same standard here: the new check must run before Step 5's `--dry-run` early exit (as Steps 3.5 and 3.6 already do), and if auto-push is chosen, the dry-run "Would execute:" block must list the branch push alongside the tag push.

5. OVERRIDE FLAG. Decide whether an escape hatch is warranted at all. If yes, follow the established `--skip-version-check` / `--skip-changelog-check` convention exactly: the flag suppresses the BLOCK, not the DISCLOSURE -- print the full failure detail first, then the override warning, so the transcript records what was overridden. If no flag is warranted, record why (this gate, unlike a version or changelog mismatch, has a trivially safe remedy: push the branch).

ALSO UPDATE. `agent-system/extensions/core/commands/tag.md` documents the flag table, workflow, and Requirements; keep it in sync with whatever is decided, or the command doc silently contradicts the skill. Also update the "Behind Remote" entry in SKILL.md's own Error Handling section neighborhood with the corresponding not-fully-pushed example output.

NON-GOALS. Do not change /tag's user-only status or its agent prohibition. Do not add a check for the reference workflow's fourth assertion (tagged release.yml matching origin's copy) -- it is workflow-file-content-specific and out of scope for a repo-agnostic skill, as already recorded. Do not couple the skill to any single repository's branch name; `origin/master` appears in the reference gate but the skill must use `$current_branch`.

VERIFICATION. At minimum: `bash -n` on extracted blocks; a behavioral smoke test covering (a) branch fully pushed, (b) branch ahead, (c) branch behind, (d) --dry-run under each; and a literal check that the resulting tag satisfies `git merge-base --is-ancestor "$new_version" "origin/$current_branch"`.

---

### 129. Empirically audit \b word-boundary grep patterns for compositional failure under the deployed grep
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88, Task 128

**Description**: Audit every `\b` word-boundary construct used in a grep pattern across the source store, empirically, against the grep actually deployed, and record portable-construct guidance so the class does not recur. Surfaced by the adversarial-verification gate failure (evt_1788245094839_eybEyC); that gate is fixed separately and is NOT in this task's scope.

THE DEFECT IS COMPOSITIONAL, NOT A MISSING FEATURE. State this precisely; the imprecise version of this finding is what would sink the audit itself. The deployed grep is ugrep 7.8.4 (built with PCRE2 available: `-P:pcre2jit`). Its POSIX/DFA `-E` engine does NOT simply ignore `\b`. Every fragment of the failing pattern matches in isolation against the literal header line `| Claim | Source / counterexample | Verification method | Confidence |`:

  PATTERN                                                          RESULT
  \bclaim\b                                                        MATCH
  claim                                                            MATCH
  \|[^|]*\bclaim\b[^|]*\|                                          MATCH
  [^|]*\bclaim\b                                                   MATCH
  \bclaim\b[^|]*                                                   MATCH
  \bsource\b[^|]*\bcounterexample\b                                MATCH
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b                           MATCH

The full composed pattern nevertheless fails, and bisection localizes it:

  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|   NOMATCH   (production form)
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b          NOMATCH
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*counterexample              MATCH     (dropped \b around counterexample)
  \|[^|]*\bclaim\b[^|]*\|[^|]*source[^|]*\bcounterexample\b              NOMATCH   (dropped \b around source)
  \|[^|]*claim[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b              NOMATCH   (dropped \b around claim)

and the unmodified production pattern under `-P` (PCRE2) returns MATCH.

So the engine mis-evaluates a `\b` that appears DOWNSTREAM of an earlier `\b`-anchored subexpression separated by a `[^|]*` run. Whether a given `\b` works depends on what else is in the pattern.

BINDING CONSTRAINT ON HOW THIS AUDIT IS PERFORMED. Because the failure is compositional, spot-testing a fragment in isolation does NOT prove the production pattern works in situ. Every site must be executed as its full, unmodified production pattern against a real positive input under the deployed grep, and the observed result recorded. Reasoning about whether a construct "should" work, testing a simplified stand-in, or generalizing from one site's result to another's are all forbidden -- they are precisely the trap this defect sets.

FOR THE SAME REASON, THIS IS NOT A MECHANICAL FIND-AND-REPLACE. A blanket `\b` removal would be wrong: `\b` carries real semantics, and several high-stakes sites were spot-verified as CURRENTLY WORKING under the deployed grep -- guard-destructive-git.sh's `--hard\b` and `(drop|clear)\b` both match (that guard is live, not silently dead), the sorry census's `\bsorry\b` matches, and literature-audit.sh's `\b(Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example)\s+[0-9]+(\.[0-9]+)*\b` matches. Rewriting working patterns risks introducing false positives in a destructive-git guard, which is a worse outcome than the defect being audited.

SCOPE. Roughly 26 grep-adjacent `\b` sites across the source store, spanning literature scripts, lean scripts, core scripts, lint scripts, test harnesses, and hooks. For each: run the production pattern against a real positive input under the deployed grep; classify as WORKING or BROKEN on the evidence; repair only the broken ones, choosing per-site between dropping `\b` where surrounding delimiters already provide the boundary and switching that invocation to `-P`; and leave working sites alone with a one-line note recording that they were tested rather than assumed.

DELIVERABLE BEYOND THE REPAIRS. A short portability guidance note under the core standards context directory covering: that the deployed grep may be ugrep rather than GNU grep; that `\b` under `-E` is compositionally unreliable there while `-P` is reliable; that delimiter-anchored alternatives are preferred where the surrounding pattern already bounds the token; and that any new `\b` pattern must be executed against a real input before being committed. Without this note the class recurs the next time someone writes a plausible-looking boundary pattern.

SEQUENCING. Depends on the adversarial-gate fix purely to avoid a file-footprint collision: skill-orchestrate/SKILL.md is itself one of the sites, and that task owns the gate's pattern. This task covers every other site and must not touch the gate.

ACCEPTANCE: every site is accompanied by a recorded empirical result under the deployed grep; no working pattern is rewritten; each repaired pattern is demonstrated to match a real positive input AND to reject a real negative input; and the guidance note exists.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 127. Collapse routing ladder to routing agents
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 121, Task 124, Task 125

**Description**: === REVISED 2026-09-01 (backlog streamline: absorbs the present-routing residue) ===
ADDITIONAL WORK ITEMS, absorbed from the abandoned present-extension routing task: (5) while rewriting the manifests, resolve present/manifest.json's colon-suffixed compound values -- its routing.implement block ("present:grant" -> "skill-grant:assemble" style) disappears with the collapse, mooting the skill-name half of the original defect, but audit routing_agents for any analogous colon-suffixed AGENT value encoding workflow_type into a name no consumer splits, and settle the encoding (drop the suffix and carry workflow_type another way, or make the resolver split and expose it as a sub-mode variable). (6) extend lint-routing-wiring.sh so any routing_agents value naming a nonexistent agent file fails verify-deploy -- the original defect (a manifest naming a nonexistent dispatch target, shipped silently) must be impossible to reintroduce under the collapsed model.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Collapse the routing ladder to routing_agents-only across all 19 extension manifests; retire command-route-skill.sh.

CONTEXT. Every extension manifest may declare up to four routing blocks today (routing, routing_hard, routing_agents, routing_agents_hard), resolved by the shared five-step ladder in scripts/lib/manifest-routing-lib.sh. Once /research, /plan, /implement are deleted (no skill layer left to route to) and the hard-mode collapse lands (no separate hard-routing table needed -- hard mode becomes a dispatch-prep injection, not a different resolved agent file), only routing_agents remains meaningful.

WORK. (1) Remove the routing and routing_hard blocks from every extension manifest that declares them, retaining only routing_agents (plus any extension-specific op like present's critique). (2) Retire command-route-skill.sh -- confirm no remaining caller (only the now-deleted /research, /plan, /implement, /revise-adjacent paths called it; /revise itself does not use this resolver and is unaffected). (3) Update context/guides/manifest-routing-schema.md to document the collapsed two-block model (down from four), including the completeness-lint contract re-scoped to check only routing_agents completeness against itself. (4) Re-scope lint-routing-wiring.sh's Checks A/C accordingly.

DEPENDS ON both the command deletions (routing/skill-dispatch has no remaining caller) and the hard-mode file deletions (routing_hard/routing_agents_hard has no remaining caller) having already landed.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/*/manifest.json (all 19), agent-system/extensions/core/scripts/command-route-skill.sh, agent-system/extensions/core/context/guides/manifest-routing-schema.md, agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A3).

---

### 91. Make update-plan-status.sh diagnose non-conforming Status lines, and settle the trailing-text tolerance policy
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [091_fail_loudly_on_nonconforming_plan_status_line/reports/01_diagnostic-opacity-and-anchor-fix.md]
- **Plan**: [091_fail_loudly_on_nonconforming_plan_status_line/plans/01_status-line-diagnostics-and-tolerance.md]
- **Summary**: [091_fail_loudly_on_nonconforming_plan_status_line/summaries/01_status-line-diagnostics-and-tolerance-summary.md]

**Description**: update-plan-status.sh reports every non-conforming plan Status line with one generic, undiagnosable message, and hard-fails /orchestrate postflight on a plan shape that a legitimate resume workflow produces. Reported independently by a peer session reviewing a consuming repo (BimodalLogic) and re-derived by execution against the source store on 2026-08-24.

CORRECTION TO THE ORIGINAL FILING. This task previously led with a claim that lines 62/72 compare two EMPTY strings and yield a silent SUCCESS. That is false, and it was verified false by running the script against fixtures for all three malformed shapes. Do not go looking for that path.
  - Line 62's `grep -m1 "^- \*\*Status\*\*:" | sed 's/.*\[\([^]]*\)\].*/\1/'` does NOT return empty on a bracket-less line. grep matches (the `- **Status**:` prefix is present), so `|| echo ""` never fires, and sed's substitution simply does not apply -- so the whole line comes back verbatim as `current_status`. It is non-empty, and it never equals a bare status token, so the equality check cannot pass.
  - Measured outcomes: trailing-text shape -> rc=1; no-brackets shape (target PARTIAL and target COMPLETED alike) -> rc=1; missing-`- `-prefix shape -> rc=1; well-formed change -> rc=0 and correctly stamped. There is no false-success input.
  - Consequently the old acceptance criterion "no input produces an empty-equals-empty pass" was already vacuously satisfied and has been dropped.

WHAT IS ACTUALLY WRONG. Four distinct defects, all confirmed:

1. DIAGNOSTIC OPACITY (the core defect). All three malformed shapes exit 1 with the byte-identical message `Failed to update status in <file>`. It names no line number, quotes no line content, and states no reason. The operator must reverse-engineer which of three different problems occurred.

2. `$`-ANCHOR INTOLERANCE OF TRAILING ANNOTATIONS. Line 69's replacement pattern `s/^- \*\*Status\*\*: \[.*\]$/.../` requires the line to END at the closing bracket. A plan carrying `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)` can therefore NEVER be stamped -- the sed is a permanent no-op and every transition on that plan fails. This shape arose from a legitimate resume workflow, which is the argument for tolerating it rather than rejecting it.

3. PREFLIGHT MASKS THE LEADING INDICATOR. update-task-status.sh:515-525 branches fatal-vs-warn on operation. Preflight prints only `Warning: plan file update failed (non-fatal)`, so a malformed Status line survives an entire task and only bites at POSTFLIGHT, where the same failure is `exit 3`. Note carefully: postflight does NOT silently diverge. It fails loudly and calls itself retryable. The "state.json says completed while the plan still reads [IMPLEMENTING], and generate-todo.sh reads only state.json" sentence in the original filing is the code comment's RATIONALE for making postflight fatal, not a description of an undetected outcome. The real cost is a late, expensive failure that a preflight warning already knew about.

4. stdout/rc CONTRACT AMBIGUITY. The script header promises "Outputs: Updated plan file path on success, empty on failure/no-op". The idempotency early-exit (lines 62-66, already-at-target) returns rc=0 with EMPTY stdout -- so stdout alone cannot distinguish success from failure. The sole current caller branches on rc and is unaffected, but commands/implement.md:353 documents a defensive call site, and any future stdout-consuming caller would be misled.

REQUIRED FIX.
(a) Diagnose loudly. On no-match, print the offending line VERBATIM with its line number and state WHICH condition failed: missing `- **Status**:` prefix, missing brackets, or trailing text after the closing bracket. Replace the single generic message with these three distinct ones.
(b) Decide and implement a tolerance policy for trailing text after `]`. Either accept it -- rewriting only the bracketed token and preserving the remainder, which defect 2 argues for -- or reject it explicitly as malformed. Apply the choice consistently and document it in context/formats/plan-format.md, which is where plan format is specified (see its existing line 99 discussion of the three status-mutating scripts).
(c) PRESERVE the deliberate preflight/postflight asymmetry. update-task-status.sh's error text acknowledges it on purpose. The fix is diagnosability, not flipping fatality.

ALSO EVALUATE (evaluate, do not assume).
  - Whether the preflight non-fatal path should emit a one-line operator-visible WARNING naming the malformed line, given that a preflight no-op is the leading indicator of the fatal postflight failure.
  - Whether a plan-format lint should validate the Status line at plan-creation time, so a malformed line never reaches a dispatch.
  - Whether the idempotent-no-op path (defect 4) should echo the plan path rather than empty, making stdout a reliable success signal.

ACCEPTANCE.
  - Each of the three malformed shapes (trailing text, no brackets, missing prefix) produces a DISTINCT, line-numbered diagnostic quoting the offending line.
  - A well-formed plan still stamps correctly, and the already-at-target path stays a no-op.
  - The chosen trailing-text policy is implemented and documented in plan-format.md.
  - Redeploy and confirm the fix survives regeneration (.claude/ is a deploy artifact; the edit target is agent-system/extensions/core/).

PROVENANCE. Originally filed in the BimodalLogic repo and abandoned there on 2026-08-24 because its entire work product lands in this repo -- BimodalLogic's .claude/ is a gitignored deploy artifact wiped on every reload, so the fix was not executable from there. That repo's specs/archive/state.json retains the original description and its specs/PATH.md records the handoff. This entry closes that handoff and supersedes the peer session's request to file a second task.

---

### 89. Mode gate literature and distill skills
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87

**Description**: Apply the mode-gated section convention to the two remaining large instances, after the pilot proves it.

skill-literature/SKILL.md, 84,265 B total, 64.5% fenced bash. Seven mutually exclusive mode sections of which exactly ONE fires per invocation: Mode: Rebuild 20,170 | Mode: Convert 17,534 | Mode: Search 10,043 | Mode: Validate 5,989 | Mode: Import Pipeline 5,785 | Mode: Index 5,234 | Mode: Ingest 1,917 = ~65,772 B, 78% of the file. Cleanly '## Mode:'-delimited, so the split is mechanical. Estimated ~14,000 tokens per /literature invocation, taking it from ~46.2k toward ~32k.

skill-distill/SKILL.md, 93,044 B total, only 1.9% bash -- essentially pure prose. `## Auto Distill Complete` is 43,254 B, 46% of the file, and is an OUTPUT TEMPLATE used by --auto alone. It belongs in context/formats/, not in a skill body loaded on every /distill invocation. Estimated ~10,800 tokens per non---auto /distill, taking it from ~42.4k toward ~32k.

Combined estimated saving ~24,800 tokens across the two commands' invocations.

Both carry the same fence-interior heading hazard as the orchestrate application -- '## Mode:' and '## Auto' strings can appear inside fenced examples. Split bottom-up and verify each extracted section round-trips.

ACCEPTANCE: each mode section loads only when its mode is selected; all seven literature modes and both distill paths verified working; measured reductions reported against the 46.2k and 42.4k baselines.

---

### 88. Delete the single-task engine and rewrite skill-orchestrate as the four-move loop
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 148

**Description**: === ADDENDUM 2026-09-02 (team mode deleted; dry-run report retired) ===
Team rows no longer exist (team mode is deleted by an earlier Stage A task); item (6)'s `--team` notice removal is already done by that deletion. The loop's dry-run path is `orchestrate-cycle-plan.sh --dry-run` (the standalone report is retired by the cycle-plan task). Research on demand (a later task) changes only the phase the planner is dispatched in; this rewrite must not hardcode research-first anywhere -- the loop dispatches whatever phase the cycle plan names.
=== REVISED 2026-09-02 (thin-lead path: engine deletion replaces mode-gating) ===
SUPERSEDING SCOPE. The premise below -- that single-task /orchestrate is the hot path and should stop loading the multi-task section -- is the inverse of how the system is used: the default is many tasks at once, and "batch of one" is the decided design (specs/PATH.md). Mode-gating would keep both engines on disk and the parity-drift defect class alive. This task instead deletes the single-task engine and rewrites the skill as the four-move loop. Stage A.6 of specs/PATH.md. The file has grown to 293,977 B since the figures below were taken.

WORK.
(1) Delete single-task Stages 1-8 (~183,000 B) outright; the feature-port predecessor has already made them unreachable.
(2) Rewrite skills/skill-orchestrate/SKILL.md as the loop: call orchestrate-cycle-plan.sh -> issue every dispatch row as a pointer-prompt Agent call in ONE message (team rows via orchestrate-team-fanout.sh) -> call orchestrate-cycle-postflight.sh per returned task -> branch: continue; on any `ask_user` verdict, AskUserQuestion once per question, batched at the end of the cycle after every other task's postflight has run, writing answers to specs/{NNN}_{slug}/.decisions.json for the next dispatch file; on `stop`, print the consolidated output and exit. Nothing else. The orchestrator never asks except to relay an agent-surfaced decision, and never reads a description, report, plan, summary, handoff prose, or context file during the loop.
(3) Move narration, incident history, and exception taxonomies to docs/architecture/orchestrate-state-machine.md and handoff-schema.md. The `## MUST NOT` sections become a list of at most ~1,500 B.
(4) Target: SKILL.md <= 20,000 B. Its Context References cite only the three cycle scripts, the fan-out script, and the state-machine doc.
(5) Update context/reference/orchestrator-critical-paths.json labels, docs/architecture/orchestrate-state-machine.md, and every test that greps SKILL.md structure (enumerate by grep for skill-orchestrate/SKILL.md under scripts/tests and scripts/lint).
(6) Retire the accepted-and-ignored notices for `--team` and phase-forcing flags in multi-task mode; both are per-row now.

MUST NOT: change any decision the scripts make; reintroduce any inline jq beyond the loop; keep a second engine.

ACCEPTANCE: measured SKILL.md bytes before/after; a live 5-task batch completes end to end with the lead's per-cycle context growth measured (cycle-plan JSON + pointer prompts + postflight JSON; target on the order of 1 KB per task per cycle); a single-task-number invocation completes through the same path; an agent-surfaced user_decision is shown reaching AskUserQuestion and its answer reaching the next dispatch file; all orchestrate tests green; full gate run green.

DELIVERABLE RULE: no task-number references in deliverables outside specs/**.
REFERENCE: specs/PATH.md, "Target design: the thin lead".
=== ORIGINAL DESCRIPTION FOLLOWS ===Apply the mode-gated section convention to the largest single instance in the system. skill-orchestrate/SKILL.md is 188,284 B; its `## Multi-Task Mode` section measures 103,462 B -- 55% of the file -- and is entered ONLY when multi_task_mode=true. Stage 0 states it explicitly: 'If multi_task_mode is true: skip Stages 1-8 entirely and proceed to Stage MT-1.' Every single-task /orchestrate N therefore loads ~26k tokens of text it will never execute, on the command intended for the longest, most context-hungry runs.

Section breakdown of the file: ## Multi-Task Mode 103,462 (only ~11% bash) | ## Execution Flow 71,570 | ## MUST NOT (Context Flatness) 8,932 | remainder ~2,500.

ESTIMATED SAVING: ~26,000 tokens per single-task /orchestrate invocation, taking its budget from ~83.5k toward ~57k. This is the single largest measured token item in the system and it is a pure move -- the section is self-contained and the branch is already explicit, so no prose rewriting is required.

Secondary, separable lever recorded here so it is not lost: this file carries 5 bash blocks of >=20 lines totalling 39,275 B, and skill-orchestrate-hard carries 9 such blocks totalling 63,892 B. Bash moved into a standalone script costs ZERO context because the script source is never loaded. That is a bigger per-token win than prose extraction and is already the established pattern here (~20 orchestrate-*.sh scripts exist). Do it in a follow-up rather than widening this work.

BEWARE the fence-interior heading trap: naive '^## ' section splitting can match headings inside fenced code blocks and silently truncate. The slim-task-command plan documents this exact hazard and mandates bottom-up extraction so earlier line numbers do not drift. Reuse that approach.

ACCEPTANCE: single-task /orchestrate no longer loads the multi-task section; multi-task /orchestrate still works end to end; measured budget reduction reported against the 83.5k baseline.

---

### 76. Close task-type-keyed hook gap for non-latex agents that compile .tex
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74, Task 146

**Description**: Close the coverage gap that the latex-extension wiring cannot reach: agents that compile .tex files under a task type OTHER than `latex` currently get no build-guard protection at all, because the extension hook mechanism is keyed on task_type.

DEPENDS ON the core guard script task. This task is NOT redundant with the latex-extension wiring task -- it covers a disjoint set of dispatches, and skipping it would leave the exact incident that prompted this work uncovered.

THE GAP, VERIFIED PRECISELY. `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` resolves which extension's hooks to run by calling `skill_get_extension_dir "$task_type"`, which maps a task type to `.claude/extensions/<ext_name>`. It then reads `.hooks[<stage>]` from THAT extension's manifest. Consequence: a preflight hook declared in the latex manifest fires if and only if `task_type == "latex"`. It never fires for any other task type. Additionally, when no extension matches the task type, `skill_get_extension_dir` returns empty and the function returns 0 immediately -- so core-typed tasks (`general`, `meta`, `markdown`) run NO lifecycle hooks whatsoever, from any extension.

WHY THIS MATTERS CONCRETELY. `agent-system/extensions/formal/manifest.json` routes ALL of `formal`, `formal:logic`, `formal:math`, and `formal:physics` implement operations to `skill-implementer` / `general-implementation-agent`. Philosophy and logic paper repositories are precisely where .tex files live, and `formal`-typed paper tasks are a normal, expected shape. The formal manifest declares NO top-level `hooks` object at all (verified: `.hooks` is null, `provides.scripts` is an empty array). So a `formal`-typed task that builds a .tex file receives zero protection from a latex-extension-only fix. The user flagged this explicitly: a latex-extension-only fix would not have covered the live incident that prompted this work. The same reasoning applies to `general`-typed tasks that happen to touch LaTeX.

DECISION TO MAKE -- WHERE THE UNCONDITIONAL PATH LIVES. Two structurally different options; choose one and record why:

  (i) AGENT-CONTRACT MANDATE. Add the guard obligation to `agent-system/extensions/core/agents/general-implementation-agent.md` and its twin `general-implementation-hard-agent.md`: before running any `pdflatex`/`latexmk` invocation, run the shared guard. Cheap, no harness change, and it composes with the "detect and refuse" mechanism (a contract can refuse; a non-blocking hook cannot). Weakness: it is instruction text an agent may skip, and it must be duplicated across the two twins.

  (ii) CORE-LEVEL UNCONDITIONAL CHECK. Add a task-type-independent guard invocation into `skill-base.sh` itself, running regardless of extension. Strongest coverage, and it survives agents ignoring instructions. Weaknesses: it touches the shared lifecycle spine that every skill in every repository depends on; it would run for every task type including ones that never touch LaTeX (mitigated if the guard is cheap and silent when no .tex conflict exists -- an explicit acceptance requirement of the core guard task); and, because hook/preflight failures are deliberately non-blocking, it still cannot ENFORCE a refusal on its own.

  A defensible outcome is BOTH: (ii) for detection and reporting, (i) for the refusal obligation. The user's framing invites exactly this ("the latex extension, a shared preflight hook, or both"). Do not silently pick the cheaper option without recording the tradeoff.

  A third possibility worth evaluating and rejecting explicitly: giving the formal extension its own preflight hook that delegates to the shared guard. This closes the `formal` case specifically but leaves `general`/`meta`/`markdown` uncovered and does not generalize -- it invites one hook per extension forever.

TWIN-FILE DISCIPLINE (binding). If option (i) is chosen, `general-implementation-agent.md` and `general-implementation-hard-agent.md` MUST be edited together in this task. A one-sided edit between engine twins is a known recurring defect class in this system. Do not assume the two files are line-symmetric; locate each site by content.

BLAST-RADIUS WARNING. If option (ii) is chosen, `skill-base.sh` is the shared lifecycle spine sourced by essentially every skill and deployed to roughly ten repositories. Changes there must be additive, must not alter existing hook ordering or the existing non-blocking semantics, and must be exercised against `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`, which already covers the hook-invocation contract.

FILE-SCOPE NOTE. This task's scope includes `agent-system/extensions/core/scripts/skill-base.sh`, which falls under the `agent-system/extensions/core/scripts/**` scope of the prerequisite core-guard task. That overlap is already serialized by the declared dependency, so no additional ordering constraint is needed -- but the two tasks must not be run concurrently.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**` (and `agent-system/extensions/formal/**` only if the rejected third option is nonetheless adopted). Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a task-type-independent path exists by which an agent about to compile a .tex file consults the shared guard, demonstrably covering `formal`-typed and `general`-typed tasks; the (i)/(ii)/both decision is recorded with reasons, and the rejected per-extension-hook option is explicitly rejected in writing; if agent contracts were edited, both twins carry equivalent obligations; if `skill-base.sh` was edited, the change is additive, preserves existing hook ordering and non-blocking semantics, and the lifecycle test suite passes; no `.claude/**` file is modified.

---

### 75. Wire build guard into latex extension preflight hook and agent contracts
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74

**Description**: Wire the shared LaTeX build guard into the latex extension's lifecycle and contracts, so that `latex`-typed research and implementation dispatches detect (and, per the chosen mechanism, stop) a competing vimtex continuous build before the agent runs its own.

DEPENDS ON the core guard script task: this task consumes the script and its chosen mechanism, and must not re-litigate the mechanism decision.

HOOK MECHANISM (verified). `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` (lines ~89-126) dispatches four lifecycle stages -- preflight, context_injection, verification, postflight -- to a script named in the extension's manifest under a TOP-LEVEL `hooks` object. This is distinct from `provides.hooks`, which is a file-copy target list; do not confuse the two. The preflight hook is invoked from `skill_preflight_update()` (line ~225) AFTER the status update. Hooks are non-blocking by design: a non-zero exit is caught and downgraded to a `[skill-base] WARNING` line, and execution continues. THIS IS A REAL CONSTRAINT ON THIS TASK -- if the chosen mechanism is "detect and refuse", a preflight hook CANNOT enforce the refusal on its own, because the harness ignores its exit code. In that case the refusal must additionally be carried in the agent contract text (the agent declines to build), with the hook serving as the detector and reporter. Resolve this explicitly rather than assuming a non-zero exit will stop anything.

REFERENCE IMPLEMENTATION. `agent-system/extensions/nix/scripts/nix-preflight.sh` is the only existing preflight hook in the source store and shows the exact contract: five positional args (`task_number`, `task_type`, `task_dir`, `session_id`, `operation`), `set -euo pipefail`, warnings to stderr, and `exit 0` even when warnings fired. The nix manifest declares it as `"hooks": {"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}`. Only two extensions (nix, nvim) declare top-level hooks today, so this is a lightly-trodden path -- read both before writing.

DELIVERABLES.
  1. A new `agent-system/extensions/latex/scripts/` directory (it does NOT exist yet -- latex's `provides.scripts` is currently an empty array) containing a preflight hook that calls the shared core guard. The hook should be a thin adapter, not a reimplementation.
  2. `agent-system/extensions/latex/manifest.json`: add the top-level `hooks` object (preflight, and postflight if the restore/report decision requires it), and add the new script(s) to `provides.scripts`. Note the manifest currently has `"hooks": []` nested inside `provides` -- the new object is a SIBLING of `provides`, not a replacement for that field.
  3. `agent-system/extensions/latex/agents/latex-implementation-agent.md`: the build guidance is concentrated at lines ~38-62 ("Build Tools (via Bash)", listing `pdflatex`, `latexmk -pdf`, `latexmk -c`, with worked multi-pass examples) and recurs at lines ~97, ~134, and ~175 as bare build instructions. Line numbers verified at task-creation time and may drift; locate by content. Add the guard obligation, and add a MUST NOT item against running a build without first invoking the guard -- MUST NOT is the strongest lever these contracts have, and advisory prose buried mid-file is what gets skipped.
  4. `agent-system/extensions/latex/rules/latex.md`: the build-command block at lines ~74-93 presents `pdflatex`/`latexmk -pdf` with no concurrency caveat. Point it at the guard.
  5. `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md`: add a build-coordination section. This file already has "Automated Build", "Using latexmk", and ".latexmkrc Configuration" sections (lines ~46-60) that discuss latexmk without mentioning the watcher conflict, so it is the natural anchor. Per this extension's convention, put the explanatory prose HERE ONCE and have the agent/rules files reference it by path rather than restating it.

NO -HARD TWIN. Unlike the lean extension, latex declares no `routing_hard`/`routing_agents_hard` block and has no `-hard` agent variants, so there is no twin-file discipline burden here. `latex-research-agent.md` is a lighter touch -- research dispatches rarely build, but should not be silently exempt if the hook is manifest-level (the hook fires for ALL latex-typed operations, research included, since `operation` is only passed as an argument, not filtered on). Decide whether the hook self-filters on the `operation` argument.

SCOPE BOUNDARY. This task covers `latex`-TYPED tasks only. Coverage for agents that build .tex files under other task types is a separate task and must not be absorbed here.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/latex/**`. Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a latex preflight hook exists, is executable, is declared in the manifest's top-level `hooks` object, and is listed in `provides.scripts`; it delegates to the shared core guard rather than duplicating detection logic; the agent, rules, and compilation-guide files carry the obligation with prose stated once in compilation-guide.md and referenced elsewhere; the non-blocking-hook constraint is explicitly resolved (either the mechanism does not need enforcement, or the enforcement is carried in contract text); the operation-filtering decision is recorded; no `.claude/**` file is modified.

---

### 74. Add shared LaTeX build-conflict guard script (detect competing vimtex latexmk -pvc)
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 130, Task 148

**Description**: Build a shared, task-type-agnostic guard script that detects a user-owned LaTeX continuous-build watcher (`latexmk -pvc`, typically driven by nvim's vimtex plugin) competing for the same .tex target an agent is about to build, and that can report, stop, and restore it. This task delivers the MECHANISM only; wiring it into lifecycle stages is handled by the two dependent tasks.

PROBLEM (observed live, not hypothetical). An agent ran `latexmk -pdf possible_worlds.tex` in a paper repo while the user's nvim vimtex continuous-mode compile was watching the same file. The two builds raced and corrupted aux files (null bytes, `^^@`). The failure mode is already documented in that repo's own CLAUDE.md under "Build Workflow: Preventing Aux File Corruption" -- but that documentation instructs a HUMAN to run `:VimtexStop` by hand. Nothing in the agent system detects, prevents, or even warns about it, so the user must notice and intervene manually every time an agent begins LaTeX work.

WHY THE EXISTING DEBOUNCE DOES NOT COVER THIS. The paper repo carries a `.latexmkrc` with `$sleep_time = 5` and a `$compiling_cmd` that pre-scans `build/*.aux` for null bytes and unlinks corrupted files. NOTE TWO CORRECTIONS TO THE ORIGINATING PROMPT, both verified at task-creation time: the file is at `JPL/.latexmkrc`, NOT the repo root; and the value is `$sleep_time = 5`, NOT the `2` that repo's CLAUDE.md claims (that CLAUDE.md is stale on this point -- do not propagate the wrong number). More importantly, `$sleep_time` debounces the file watcher WITHIN a single latexmk instance. It provides no coordination whatsoever between two SEPARATE latexmk processes, which is precisely the race here. The `$compiling_cmd` null-byte sweep is a post-hoc corruption cleanup, not prevention. Neither existing mechanism can solve this; a new one is required.

MECHANISM DECISION -- THIS IS THE CORE RESEARCH QUESTION. An agent cannot invoke a Vim command directly, so the shutdown path is non-obvious. Three candidates, to be evaluated and one (or a documented layering) chosen:

  (a) PROCESS TERMINATION. Detect a running `latexmk -pvc` whose target resolves to the .tex file about to be built, and SIGTERM it. Most reliable, most destructive -- it kills a process the user owns, and vimtex's own state will not know its child died, potentially leaving the plugin's status display stale or its callback machinery confused.

  (b) EDITOR REMOTE CONTROL. Use `nvim --server <socket> --remote-expr` (or `--remote-send`) against the live nvim instance to invoke VimtexStop. VERIFIED FEASIBLE IN THIS ENVIRONMENT: four live sockets were present at task-creation time under `/run/user/1000/` in the form `nvim.<PID>.0` (XDG_RUNTIME_DIR). This is the only option that leaves vimtex's internal state consistent, because vimtex itself performs the stop. Costs: it requires mapping socket -> the nvim instance that actually owns the target buffer (a socket exists per nvim instance, and most of them will be unrelated); `--remote-expr` executes arbitrary expressions in the user's editor, which is a real side effect deserving explicit justification; and it depends on vimtex being loaded in that instance.

  (c) DETECT AND REFUSE. Detect the conflict and emit a clear, actionable message -- naming the PID, the target file, and the exact `:VimtexStop` remedy -- then either warn-and-continue or refuse to build. Zero side effects on user-owned processes and zero remote editor control. The user's explicit steer is to PREFER THE LEAST DESTRUCTIVE OPTION THAT RELIABLY PREVENTS THE RACE, and to weigh killing a user process or driving their editor remotely against simply refusing with a clear message. Research should take that steer seriously rather than defaulting to (a) because it is easiest to implement. A defensible outcome is (b) with (c) as fallback when no owning socket can be identified, or (c) alone.

RESTORE-VS-REPORT DECISION. Also decide whether the agent restores continuous mode on exit or merely reports that it stopped it. The user's stated position: an agent that silently leaves the user's watch mode off is its own (smaller) annoyance. At minimum, whatever is stopped must be REPORTED. Restoration is materially easier under mechanism (b) (re-invoke VimtexCompile over the same socket) than under (a) (the script would have to reconstruct and relaunch a latexmk invocation it did not create -- generally a bad idea). Note that this decision is coupled to the mechanism decision and should not be made independently of it.

REUSABLE PATTERN -- `agent-system/extensions/core/scripts/claude-refresh.sh`. That script already solves the hard parts of safe process handling and should be read before writing anything new. It takes a single atomic `ps -eo` snapshot per invocation rather than re-querying live; it applies exclusion regexes so the script can never target itself or its own ancestry; it gates destructive action behind an explicit `--force` (the calling skill handles confirmation separately); and it escalates SIGTERM (`kill -15`) -> liveness recheck (`kill -0`) -> SIGKILL (`kill -9`) rather than killing outright.

SELF-MATCH HAZARD (verified concretely, do not skip). During task creation, a plain `pgrep -af latexmk` returned exactly one "match" -- the task-creating agent's OWN bash wrapper command, whose argv merely CONTAINED the string `latexmk`. A naive detector would therefore report a phantom conflict, and under mechanism (a) would attempt to kill the agent's own shell. Detection must match on the actual executable and its `-pvc` flag, resolve the build target, and exclude self/ancestry, exactly as claude-refresh.sh does. This is not a theoretical edge case; it fired on the first probe.

DELIVERABLE. A new executable script under `agent-system/extensions/core/scripts/` (suggested name `latex-build-guard.sh`; final name to be fixed during planning). Placement in CORE, not in the latex extension, is DELIBERATE and load-bearing: the two dependent tasks show that non-latex-typed tasks also run LaTeX builds, so the mechanism cannot live behind the latex extension's task-type gate. Suggested subcommand shape (refine during planning): a `detect` mode that reports conflicts and exits non-zero, a `stop` mode implementing the chosen mechanism, and a `restore`/`report` mode for the exit path. Modes should be separable so callers can adopt detect-only first.

The script must be registered in `agent-system/extensions/core/manifest.json` under `provides.scripts` alongside the ~124 existing entries so it is deployed.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**`. Never edit a deployed `.claude/**` tree -- those are disposable artifacts regenerated on reload, so such an edit silently vanishes.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: the script exists, is executable, and is registered in core's `provides.scripts`; the chosen mechanism is implemented and the rejected candidates are recorded WITH REASONS in the task's artifacts; detection correctly distinguishes a real `latexmk -pvc` on the target .tex from a process whose argv merely contains the string, and never matches itself or its own ancestry; the restore-vs-report decision is recorded and implemented; whatever the script stops is always reported to the user; the script is safe and silent (exit 0, no output) when no conflict exists, since it will run on every applicable build.

---

### 51. Move session state files out of specs root
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 143

**Description**: Stop session-scoped orchestration runtime files from accumulating at the specs/ root, and make the existing reap path actually run. Originally scoped as "move the files into a dot-prefixed directory"; widened after a manual cleanup swept 79 stranded files across 5 repos (oldest dated 2026-07-11), because relocation alone hides the clutter without stopping the growth.

Three parts:

(1) Relocation (original scope). Move .orchestrator-multi-state-{sid}.json and .return-meta-multi-{sid}.json out of the specs/ root into a dot-prefixed subdirectory (e.g. specs/.orchestration/), or handle otherwise as most appropriate. Must update every writer/reader, the reaper's glob roots, .gitignore patterns, check-runtime-file-tracking.sh's probe paths, and context/standards/orchestrator-runtime-files.md's Class Table.

(2) Reaper glob coverage gap. scripts/reap-session-runtime-files.sh sweeps ONLY the current hyphen-separated shapes (specs/.orchestrator-multi-state-*.json, specs/.return-meta-multi-*.json). Three superseded naming generations are therefore permanently unreapable and had to be deleted by hand:
  - un-suffixed:     .orchestrator-multi-state.json / .return-meta-multi.json
  - dot-separator:   .orchestrator-multi-state.sess_{sid}.json
  - .prev- variant:  .orchestrator-multi-state.prev-sess_{sid}.json
Additionally .return-meta-meta.json, .return-meta-meta-sess_{sid}.json, and .meta-return.json have NO writer or reader anywhere in agent-system/ or .claude/ (orphans of a superseded convention; .meta-return.json was also tracked in git and has since been removed). Decide per shape whether to widen the reaper's globs or to add a one-shot legacy-name migration, and ensure any relocation in part (1) does not create a fourth orphaned generation.

(3) Automatic invocation (root cause). The reaper is correct and works -- it cleared 41 of 41 files on first run -- but its ONLY trigger is a manual /refresh, so litter grows unbounded between refreshes. Wire reap into /todo, which is run far more often and is already the repo's housekeeping command. Call both scripts/reap-session-runtime-files.sh and task-lock.sh session-reap (stale .sessions/ registry entries accumulate identically -- 9 dead-pid entries were swept in nvim alone). Suggested hook point: a new stage between skill-todo's stage 10 ArchiveTasks and stage 15 GitCommit, so reaped paths land in the same commit; alternatively fold the reporting half into stage 3 DetectOrphans. Must stay non-blocking and honor the existing ORCHESTRATOR_SESSION_REAP_MIN threshold (default 240min) so in-flight batch runs are never reaped; echo the reaper's own output verbatim the way skill-refresh already does. Keep /refresh's invocation working unchanged.

Affected repos observed: nvim, BimodalLogic, cslib, ModelChecker, PersonalWebsite -- so the fix belongs in the core extension source store, not any single repo's deploy.

---

### 45. Global update extension repo registry
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: neovim
- **Dependencies**: None

**Description**: TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carried topic core-agent-system, but its real scope (the <leader>al extension picker's 'Global Update' action) is nvim-config Lua UI code at lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**, NOT agent-system/extensions/** -- it is unrelated to the orchestrate-engine collapse. Re-topiced to neovim; file_scope backfilled from description evidence (was previously empty). Original description follows.\n\nImplement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded extensions in this nvim repo; add a 'Global Update' entry (similar to 'Reload All') that reloads all extensions already loaded in each registered repo, reporting any failures in a message and otherwise success as a count of the total

---

### 44. Slim commands/task.md, the largest per-invocation context contributor
- **Effort**: 2-4 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87, Task 149
- **Research**: [044_slim_task_command_body/reports/01_command-body-extraction-approach.md]
- **Plan**: [044_slim_task_command_body/plans/01_task-command-mode-extraction.md]

**Description**: LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k tokens of imports it pulls in — the largest single per-invocation context contributor found by the context-loading audit. Slim the command body by moving reference material (long option tables, worked examples, edge-case narratives) into lazily-loaded context files under the core extension's context tree, keeping the command body to the decision logic and dispatch instructions an invocation actually needs. Preserve behavior: every mode (--recover, --expand, --sync, --abandon, multi-task creation) must remain fully specified — either inline or via an explicit pointer the executing agent is instructed to follow. Measure before/after bytes and record them in the implementation summary. CONSTRAINTS: all edits target agent-system/extensions/core/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**; do not change command behavior, only where its prose lives.

---

### 43. Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions. This is email-extension-internal context-loading work, classified extension-internal by the consolidation audit, and is unrelated to the orchestrate-engine collapse. Original description follows.LIVE DEFECT, not an efficiency item: the email extension's five 'non-negotiable' safety context pointers (safety-invariants.md, wrapper-contracts.md, index-architecture.md, staleness-detection.md, archive-mode-risk.md) were written as `@.claude/context/...` imports in the merge-source era — a form that resolves to a nonexistent path and silently loads NOTHING. They have since been normalized to plain backticked paths (still non-loading by design), so the question the audit deferred is now unavoidable: how does safety-invariants.md actually reach an agent before it mutates a mailbox? Decide deliberately between: (a) making the safety pointers genuinely eager in the email extension's CLAUDE.md contribution, accepting roughly 13k tokens of every-session cost in deploys where email is loaded; (b) establishing that the wrapper contracts (five nix-built wrapper binaries as the only mutation path) plus the email skills'/agent's own explicit context-loading instructions already carry the enforcement, and recording that as the documented decision; or (c) a middle path such as eager-loading ONLY safety-invariants.md (the smallest, most critical file) while the rest stay lazy. Verify empirically what skill-email-cleanup, skill-email-sync, and email-implementation-agent load today before choosing. Whatever the choice, record it in the email extension's docs so the next audit does not re-litigate. CONSTRAINTS: all edits target agent-system/extensions/** (source store); no volatile files in any eager prefix; no task-number references in deliverables outside specs/**.

---

### 39. Upgrade Zotero metadata resolution and plan the Zotero 10 backend swap
- **Effort**: 3-6 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [039_zotero_metadata_resolution_upgrade/reports/02_zotero-metadata-resolution-design.md]
- **Plan**: [039_zotero_metadata_resolution_upgrade/plans/02_zotero-metadata-resolution.md]

**Description**: Upgrade the literature extension's Zotero integration beyond bare write-path activation: add a real metadata-resolution step for web-discovered sources, decide the MCP question, gate auto-attach on storage quota, and record the Zotero 10 backend-swap plan. Grounded in verified Aug-2026 tooling research — see the seed report before re-deriving any landscape claim.

=== WORK ITEMS ===

1. TRANSLATION-SERVER INTEGRATION (the pipeline's thinnest point today). The online ingest bridge currently relies on `zot add --pdf`'s DOI-from-PDF extraction for metadata, which fails on books, preprints without embedded DOIs, and scans. Integrate the official `zotero/translation-server` (HTTP, port 1969; service provisioning is the ~/.dotfiles repo's job — its task 129): call `POST /search` (DOI/ISBN/arXiv ID, preferred when Tier-3 discovery already has an identifier) or `POST /web` (URL fallback) to resolve full Zotero JSON BEFORE item creation, and pass that metadata through the create path. Degrade gracefully (current behavior) when the service is down, and surface which resolution path produced the record.

2. ZOTERO-MCP ADOPTION DECISION. Evaluate adding 54yyyu/zotero-mcp (de-facto standard, ~4.6k stars, hybrid mode = local-API reads + Web-API writes, add-by-DOI/URL/ISBN, OA-PDF cascade) as an INTERACTIVE complement for `/research --lit` sessions. The deterministic scripts remain the pipeline of record — community practice in 2026 is exactly this split. Deliverable is a recorded decision (adopt/defer with reasons); if adopted, registration scope and permission grants follow the grant-at-registration-scope principle already established for MCP servers in the ~/.dotfiles Claude configuration, and the registration itself lands there, not here.

3. STORAGE-QUOTA GATE. Stored-file uploads via the Web API count against the zotero.org 300 MB free tier (948 attachments already exist locally; the account's plan/usage is unverified). Verify quota state and encode an explicit auto-attach policy in the ingest bridge rather than discovering the ceiling by failure. Note the upload flow's `{"exists": 1}` content-hash dedup for PDF bytes.

4. ZOTERO 10 BACKEND-SWAP PLAN (plan, do NOT implement while 10 is beta). Zotero 10 ships native local writes (items + file upload) at `localhost:23119/api/` with consent-based local API keys via `POST /api/local/authorize` — eliminating cloud round-trips and the storage quota for attached files. Record the swap plan against the single write choke-point (`zotero-write.sh`) so callers never change; explicitly reject `/connector/saveItems` as a write contract (undocumented internal protocol).

=== ACCEPTANCE CRITERIA ===

1. Web-discovered sources get translation-server-resolved metadata when an identifier or URL is available, with honest surfacing of which resolution path was used and graceful degradation when the service is unreachable.
2. The MCP decision is recorded with reasons; no MCP registration or grants are hand-edited in this repo either way.
3. Auto-attach policy is explicit and quota-aware; no silent quota-exhaustion failure mode remains.
4. The Zotero 10 swap plan exists in the extension's context docs, names the choke-point, and states what stays constant for callers.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 30. Register obsidian memory mcp server
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 29

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions, alongside its prerequisite (the .mcp.json generation mechanism). Unrelated to the orchestrate-engine collapse. Original description follows.Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope.

CURRENT STATE: memory/settings-fragment.json carries a dead `mcpServers` block declaring obsidian-memory (npx -y @anthropic-ai/obsidian-claude-code-mcp@latest, with env OBSIDIAN_WS_PORT). It registers nothing, because settings files are not a registration surface. The memory extension IS loaded in this repository, so unlike the five retired servers this one is wanted and should be made to work.

WORK: move the declaration to the new merge target so it lands in .mcp.json, with an explicit "type": "stdio". Then determine the server's ACTUAL tool names and add matching permission grants to the fragment, applying the grant-at-registration-scope rule. Do NOT guess the tool names and do NOT copy them from any existing documentation: enumerate them empirically by starting the server and issuing a tools/list request. This system has already shipped documentation instructing agents to call MCP tools that never existed, and a naming mismatch between a declared server name and its granted mcp__<name>__* prefix has already been found in another extension -- verify both the server name and every tool name against the running server.

RUNTIME PREREQUISITE, DO NOT PAPER OVER: this server needs OBSIDIAN_WS_PORT set and a running Obsidian instance with the companion plugin. If that prerequisite cannot be satisfied in this environment, wire the declaration correctly, document the prerequisite plainly in the memory extension README, and report the tool-name enumeration as NOT VERIFIED rather than inventing plausible names. A truthful 'could not verify' is the correct outcome here; a fabricated tool list is not.

VERIFICATION: .mcp.json contains the entry after a fixture deploy; `jq empty` on both edited files; doc-lint passes for the memory extension; every granted mcp__ tool name either matches a name observed from the running server or is explicitly marked unverified with the reason. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 29. Generate mcp json from extension manifests
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced core-agent-system -> extensions. This is deploy-engine (lua merge-path) and manifest-surface work for extension MCP registration, unrelated to the orchestrate-engine collapse; the consolidation audit confirmed no overlap with the routing ladder it carries forward. Original description follows.Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Freeze .opencode: silence fragment validation spam and record the frozen-mirror policy
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: opencode
- **Dependencies**: None

**Description**: === REVISED 2026-09-01 (backlog streamline: .opencode declared FROZEN) ===
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

---

### 14. Prevent implementation-agent fan-out from returning non-terminal status and stale plan markers
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88, Task 139

**Description**: === REVISED 2026-08-24 (refactor survey) ===
NARROWED: roughly half of this task already landed with the handoff-identity work and must not be redone. skill-orchestrate/SKILL.md:2374,2384 now treats in_progress (and null/empty) as OFF-SCHEMA rather than routing it toward failed_tasks, and orchestrate-recover-outcome.sh:233 emits a clean STATUS_IN_PROGRESS verdict. Verified in the source store today.
WHAT REMAINS is the AGENT-CONTRACT side only, and it is untouched: general-implementation-agent.md contains NO fan-out prohibition, and NO requirement that a sub-agent which commits a phase must update that phase's marker in the same commit. Both gaps are what produced the original symptom -- dispatches fanning out to phase sub-agents and terminating before writing a terminal status, leaving plan markers reading [NOT STARTED] against landed commits.
Rescope to those two contract additions. Do not re-litigate the status-vocabulary half.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Two dispatches in a single batch fanned out to phase sub-agents and terminated before writing a terminal status, costing a recovery cycle each. Recorded as err_1786344051474_RcIhk6.

OBSERVED FAILURE MODE: a dispatched implementation agent spawned per-phase sub-agents, returned while they were still running, and left .return-meta.json at status=in_progress. Per context/formats/return-metadata-file.md that value is early-metadata-only and never a legal terminal dispatch outcome, so orchestrate-recover-outcome.sh correctly declines it (reason STATUS_IN_PROGRESS). The orchestrator contract for an unresolvable dispatch is failed_tasks - which would have been WRONG here, since 6 of 10 phases had in fact been committed. Correct handling came from rules/error-handling.md Delegation Interrupted Recovery (keep status, resume), not from the orchestrator stage contract.

COMPOUNDING DEFECT - STALE PLAN MARKERS: the sub-agents committed phases 3, 4, 5 and 7 but left every one of those phase markers reading [NOT STARTED]. Because the orchestrator phase-marker recovery grep reads exactly those markers, it would have reported 2/10 against a true 6/10. A resume driven by markers alone would have redone committed work. Recovery only succeeded because the actual state was reconstructed from git log and diffs instead.

TWO INDEPENDENT QUESTIONS, BOTH IN SCOPE:
  1. Should a dispatched implementation agent fan out to sub-agents at all? If yes, it must still write a terminal status covering its childrens work; if no, the prohibition belongs in the agent contract, not in per-dispatch prompt text (the workaround used during the incident).
  2. Should a sub-agent that commits a phase be required to update that phases marker in the same commit? Markers and commits diverging silently is the deeper defect - it degrades the recovery path for every future interrupted dispatch, not just fan-out ones.

CONSIDER ALSO: whether the orchestrator should treat status=in_progress plus evidence of committed phase work as PARTIAL/resume rather than routing it toward failed_tasks, so correct handling does not depend on an operator noticing.

ACCEPTANCE: an interrupted fan-out dispatch is either impossible by contract, or leaves markers and terminal status accurate enough that resume needs no manual git archaeology.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== REVISED 2026-08-24 (second live occurrence, extension-agent gap) ===
RECURRED, AND THE CONTRACT GAP IS WIDER THAN THIS TASK'S CURRENT SCOPE. A seven-task lean4 batch
orchestrated in a separate consumer repo reproduced this exact failure mode TWICE in one
implementation cycle: two of seven dispatches performed real work, committed it, and then
terminated WITHOUT writing a terminal handoff, leaving .return-meta.json at status=in_progress.
orchestrate-recover-outcome.sh correctly declined both (STATUS_IN_PROGRESS); both needed a
re-dispatch cycle to resolve, exactly as the original incident did.

SCOPE CORRECTION (the actionable part). Both offending dispatches ran
extensions/lean/agents/lean-implementation-agent.md, NOT
extensions/core/agents/general-implementation-agent.md -- the only agent contract this task's
file_scope currently names. The terminal-status requirement is therefore missing from the
EXTENSION implementation agents as well as the core one, and fixing only the core file would
leave the reproducing path untouched. file_scope is extended accordingly to the lean pair. Treat
the core agent as the normative contract and the extension agents as required conformers; if a
shared include or a single normative statement referenced by all implementation agents is the
better mechanism, prefer that over copying the same paragraph into four files.

MARKER DIVERGENCE RECURRED IN THE OPPOSITE DIRECTION -- fold into question 2, do not treat as a
separate concern. The original incident recorded markers UNDER-claiming (phases committed, markers
still [NOT STARTED]). This batch recorded the inverse: one task's plan carried five of seven
phases marked [COMPLETED] while its sole declared file_scope target was UNMODIFIED against HEAD --
markers OVER-claiming against work that had not landed. A resume driven by those markers would
have skipped real work rather than redone it. Both signs share one root cause, which question 2
already names: markers and committed reality are allowed to diverge silently. Any fix must be
bidirectional -- a marker must not be promotable without the corresponding work being verifiable,
and committed work must not leave its marker unpromoted. The over-claim direction was only caught
because the orchestrator cross-checked the marker count against the working tree; a fix that
merely tightens promotion-on-commit would not have caught it.

WHAT IS ALREADY GOOD AND MUST NOT BE UNDONE. The re-dispatch path worked: both tasks resumed from
their real state and completed, and the resumed dispatches -- when explicitly instructed to write
the handoff FIRST and to re-verify prior phase markers with a real build rather than trust them --
both reported correctly and downgraded nothing falsely. That per-dispatch prompt text is the
workaround this task exists to retire; it is evidence the contract wording works, not a substitute
for putting it in the contract.

ACCEPTANCE (extends, does not replace, the original): the terminal-status requirement and the
fan-out resolution apply to extension implementation agents as well as the core one, demonstrated
against a lean4 dispatch; and marker/reality divergence is caught in BOTH directions.

---

### 13. Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [013_instrument_gate_out_auto_repair_reporting/reports/01_gate-out-repair-reporting.md]
- **Plan**: [013_instrument_gate_out_auto_repair_reporting/plans/01_gate-out-repair-reporting.md]
- **Summary**: [013_instrument_gate_out_auto_repair_reporting/summaries/01_gate-out-repair-reporting-summary.md]

**Description**: The acceptance criterion "gate-out reports zero format errors and zero auto-repaired fields" is unverifiable as written, because no reporting surface exists. Recorded as err_1786350581339_Q4VnFy.

TRACED PATH: command-gate-out.sh (134 lines) has no counter, aggregate, or exit-code surface for auto-repairs; its only related line is a comment. The real repair path is
    command-gate-out.sh -> skill_validate_task_artifacts (skill-base.sh) -> validate-artifact.sh "$f" "$type" --fix 2>/dev/null
validate-artifact.sh DOES emit a terminal line of the form "[FIXED] N field(s) auto-repaired, E error(s), W warning(s) remaining" and exits 2. But skill_validate_task_artifacts discards stderr, collapses every non-zero exit into a single generic non-blocking WARNING carrying no numeric detail, and always returns 0. command-gate-out.sh therefore receives no signal at all.

PRIMARY HAZARD (the reason this is not merely cosmetic): --fix MUTATES THE ARTIFACT IN PLACE. A repair both happens and goes uncounted, so an artifact can be silently rewritten with nothing anywhere recording that it was. The instrumentation gap and the silent-mutation hazard are the same defect seen from two ends.

WORK:
  1. Propagate validate-artifact.sh fix/error/warning counts through skill_validate_task_artifacts instead of discarding them.
  2. Give command-gate-out.sh a reportable surface for those counts.
  3. Decide explicitly whether --fix should remain in-place-mutating on the gate-out path, or whether a repair should be reported and left for a human. State the decision and its reasoning.

ACCEPTANCE: a task whose artifact required auto-repair produces a gate-out report naming a nonzero repaired-field count, and a task needing none reports zero. Both directions must be demonstrated - a report that can only ever say zero is not instrumentation.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.
