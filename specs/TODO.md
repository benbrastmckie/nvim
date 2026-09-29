---
next_project_number: 269
---

# TODO

## Task Order

*Updated 2026-09-29. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,39,43,44,51,89,127,139,162,163,167,184,199,207,217,223,241,244,255,265,268 | -- | core-agent-system, extensions, literature, ... |
| 2 | 29,136,165,185,250,251,263 | 22,44,127,139,162,163,184,199,241,265 | core-agent-system, extensions, file-scope-lifecycle |
| 3 | 170 | 51,250,251 | core-agent-system |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

44 [PLANNED] — Slim commands/task.md, the largest per-invocation context...
  └─ 251 [NOT STARTED] — Context-corpus reachability probe (filename, directory,...
    └─ 170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state...
51 [NOT STARTED] — Move session runtime files out of the specs root and make the...
  └─ 170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state... (see above)
89 [NOT STARTED] — Apply the mode-gated section convention to the two remaining...
127 [NOT STARTED] — === REVISED 2026-09-01 (backlog streamline: absorbs the...
  └─ 251 [NOT STARTED] — Context-corpus reachability probe (filename, directory,... (see above)
139 [RESEARCHED] — Forbid concurrent-writer history rewrites: rules and agent...
  └─ 136 [NOT STARTED] — Implementation-agent contract corrections: plan-level Status...
  └─ 263 [NOT STARTED] — Consent-gated git push: grant semantics and enforcement mechanism
184 [NOT STARTED] — Surface skeleton-plan follow-ups at completion under the...
  └─ 185 [NOT STARTED] — Retarget the remaining historical "Stage N" and "Stage MT-N"...
199 [RESEARCHING] — Decide and implement the working-tree and build isolation...
  └─ 185 [NOT STARTED] — Retarget the remaining historical "Stage N" and "Stage MT-N"... (see above)
  └─ 250 [NOT STARTED] — Script-corpus inventory probe, then cut tests/run-all.sh...
    └─ 170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state... (see above)
217 [NOT STARTED] — Cost-aware idle Lean tree reclamation in /refresh: PSS...
244 [RESEARCHING] — check-task-references.sh: scan repo-appropriate roots instead...
265 [NOT STARTED] — Run Gate 8 in parallel inside verify-deploy.sh via run-all.sh...
  └─ 250 [NOT STARTED] — Script-corpus inventory probe, then cut tests/run-all.sh... (see above)
268 [NOT STARTED] — SOURCE STORE IS THE EDIT TARGET:...

### Extensions

43 [RESEARCHING] — Decide and implement how email safety context actually...
167 [RESEARCHING] — Guard LaTeX builds against the vimtex watcher: always-on rule...
241 [NOT STARTED] — Reconcile MCP registration surfaces: redundant playwright...
  └─ 29 [NOT STARTED] — Generate .mcp.json from extension manifests, then register...
255 [NOT STARTED] — Reconcile typst extension scope ownership and fix...

### Literature

39 [PLANNED] — Upgrade Zotero metadata resolution and plan the Zotero 10...
207 [RESEARCHING] — Fix zotero-generate-export.sh Path 1: accumulator truncation...

### Neovim

22 [NOT STARTED] — Freeze .opencode: silence fragment validation spam and record...

### File Scope Lifecycle

162 [PLANNING] — Formalize Files to modify, harvest it into filescope at every...
  └─ 165 [NOT STARTED] — Admission gates in orchestrate-batch-admit.sh: posture for an...
163 [RESEARCHING] — Surface missing and empty filescope in validate-state.sh and...
  └─ 165 [NOT STARTED] — Admission gates in orchestrate-batch-admit.sh: posture for an... (see above)

### Lean Extension

223 [RESEARCHED] — Record the Comparator-on-NixOS fixes in the lean extension

## Tasks

### 268. Lake build guard false green scope key
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/scripts/lake-build-guard.sh (never .claude/**).

REPORTED DEFECT. During a multi-task /orchestrate run in the BimodalLogic repository, a Lean implementation agent observed lake-build-guard.sh replay a stale result across a differently-scoped build: it reported 'Build completed successfully (1200 jobs)' while writing no .olean for the module actually requested. The agent worked around it by passing --no-share on every subsequent build, and all of its later builds were genuine. A false green is the dangerous direction of wrong for this guard: it would let a broken module pass a gate that believes it built.

DO NOT ASSUME THE DEFECT IS REAL -- REPRODUCE FIRST. The scope_key result-sharing condition that would prevent exactly this replay is ALREADY IMPLEMENTED in the guard and predates the observation. See decide_sharing(), whose scope condition is labelled 'Defect B' and reads: a missing or empty recorded scope_key is treated as NOT shareable (fail closed); and compute_scope_key(), which hashes the invocation's lake argument vector with a NUL-separated sha256. The STALENESS POLICY header block states the five sharing conditions, of which scope_key is condition 3. So this is not simply the known defect recurring.

DETERMINE WHICH OF THESE HOLDS:
(a) compute_scope_key has a residual normalization gap that lets a scoped build (lake build Foo.Bar) and a full build (lake build) hash to the same key -- e.g. argument-vector construction differing between the two call paths before hashing, so the guard believes the scopes match when they do not;
(b) the observed replay came from a record written before scope_key existed, and the documented fail-closed branch did not actually fire -- i.e. get_record_field returning something non-empty for an absent key, or the record being read by a path that bypasses decide_sharing;
(c) the report was a misdiagnosis and some other mechanism produced the appearance of a successful build with no .olean written.

If (a) or (b), fix at source and add a regression test under agent-system/extensions/core/scripts/tests/ covering the scoped-vs-full collision directly. If (c), record the real cause; a false-green report against this guard should not be left unexplained.

REPRODUCTION ENVIRONMENT. This repository contains no Lean project (no lakefile.toml anywhere under it), so the guard cannot be exercised end to end here. Reproduction needs a real Lean project with a lake build; ~/Projects/BimodalLogic is where the observation occurred and is the natural harness. Treat that checkout as read-only test fixture: land no change there, and note it is a separate repository with its own task system.

Note the guard is deployed into consumer repositories at .claude/scripts/lake-build-guard.sh. Never hand-patch a deployed copy -- fix the source above and redeploy, per the source-store/deploy-boundary rule.

---

### 266. Deploy-pending completion refusal collides with the identical-dispatch convergence guard
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [266_deploy_pending_vs_identical_dispatch_guard/reports/01_deploy_pending_vs_identical_dispatch_guard.md]
- **Plan**: [266_deploy_pending_vs_identical_dispatch_guard/plans/01_deploy-pending-guard-composition-fix.md]
- **Summary**: [266_deploy_pending_vs_identical_dispatch_guard/summaries/01_deploy-pending-guard-composition-fix-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

=== THE DEFECT, OBSERVED TWICE IN ONE REAL RUN ===
During a single live /orchestrate run over a three-task batch, two different tasks independently
hit the same interaction. A task whose modified_files touch agent-system/** cannot converge to
`completed` inside the run that finished it, and then gets halted by the churn guard for being
finished.

Sequence, as observed:

1. The implement dispatch finishes CORRECTLY and writes a valid handoff (all phases done, status
   `implemented`).
2. scripts/orchestrate-cycle-postflight.sh's completion-deploy gate REFUSES the completion write
   with exit 6: "refusing postflight implement for task N: extension 'core' is stale relative to
   its source store (touched path: agent-system/extensions)". No state.json write, no plan-file
   status stamp. The task stays at `implementing` and is marked deploy-pending. The emitted
   message asserts that convergence "is deferred to the next cycle's Inter-Cycle Redeploy
   Checkpoint -- no manual action needed."
3. The next cycle's checkpoint DID fire and DID deploy. But because the task's status was still
   `implementing` with a complete plan on disk, scripts/orchestrate-cycle-plan.sh re-derived an
   implement dispatch whose content was BYTE-IDENTICAL to the previous cycle's. That tripped the
   identical-dispatch convergence guard (orchestrate-cycle-plan.sh:2296-2345): "dispatch content
   matched the previous dispatch 2 times in a row; halted for the rest of this run". The task was
   excluded via a blocked[] row and the run ended with the task still at `implementing`, despite
   its work being complete and committed.
4. Both tasks ultimately required OUT-OF-BAND OPERATOR ACTION to converge: run the deploy, then
   scripts/reconcile-task-status.sh N <session_id>, which correctly promoted each to `completed`
   ("[deploy-check] Task N: touched extension(s) verified fresh -- proceeding").

=== CHARACTERIZE IT THIS WAY ===
The deploy-pending defer and the identical-dispatch guard interact badly. A deploy-blocked task
NECESSARILY re-derives an identical dispatch, because nothing about its inputs changed -- that is
the definition of its situation, not evidence of churn. So the guard reads a deploy-gating
condition as dispatch churn and halts a task that was actually finished. Both mechanisms are
individually correct; the defect is in their composition. The "no manual action needed" assurance
did not hold in either observed case, which makes the emitted message actively misleading.

=== POINTS TO SETTLE IN RESEARCH/PLANNING -- DO NOT PRE-DECIDE ANY OF THESE ===
- Should the identical-dispatch guard be SUPPRESSED when the task carries a deploy_pending
  marker, or should its streak counter merely NOT BE INCREMENTED? These are different: the first
  disables a real safety net, the second preserves it for genuine churn while refusing to charge
  a deploy-gated re-derivation against it. Argue for one.
- Should a deploy-pending task be RE-POSTFLIGHTED directly after the checkpoint's deploy lands,
  rather than re-dispatched at all? The work is already done and committed; a re-dispatch is pure
  waste even on the runs where it is not halted. This may be the better fix and may make the
  guard question moot.
- Should the checkpoint's deploy be followed by an AUTOMATIC reconcile pass over the tasks it
  just unblocked, making the "no manual action needed" claim true rather than aspirational?
  reconcile-task-status.sh already performs exactly the right check and got the right answer both
  times, so the question is wiring and idempotency, not new logic.
- ORDERING: the checkpoint currently deploys during Move 1 of the NEXT cycle, i.e. after the
  refusal has already happened. Is there a cheaper ordering -- deploy BEFORE the completion write
  is attempted, in the cases where modified_files are already known to overlap agent-system/** --
  and what does that cost on runs where it turns out not to be needed?
- Whether the emitted "no manual action needed" text should be CORRECTED (or downgraded to a
  conditional) until the behavior actually matches it. Shipping a true message is a valid partial
  fix and should not be held hostage to the larger one.

=== CONSTRAINTS ===
- Do NOT weaken the completion-deploy gate itself. Refusing to mark a task `completed` while its
  extension is stale relative to the source store is correct and is what keeps .claude/ from
  being certified against un-deployed sources.
- Do NOT weaken the identical-dispatch guard for the general case. It exists to stop genuine
  non-convergence loops and has done so.
- Do not modify tasks 260-264 or anything under their task directories. They are the evidence
  record for this defect, not work to be revised.

=== VERIFICATION ===
1. Reproduce the interaction in a test: a task with a complete plan and a deploy_pending marker
   must not be halted by the identical-dispatch guard, and must converge to `completed` within a
   single run once the checkpoint's deploy lands.
2. A task with a complete plan and NO deploy_pending marker that genuinely re-derives an
   identical dispatch twice IS still halted. The guard must remain live for real churn.
3. The completion-deploy gate still refuses exit 6 when the extension is genuinely stale and no
   deploy has run.
4. Whatever message the refusal emits is TRUE of the resulting behavior. Quote the before and
   after text in the summary.
5. scripts/tests/ passes, including test-orchestrate-cycle-postflight.sh and
   test-orchestrate-cycle-plan.sh. No test may be weakened or deleted to make the change pass.

---

### 265. Run Gate 8 in parallel inside verify-deploy.sh via run-all.sh --jobs
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 266

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

=== WHAT TO CHANGE ===
scripts/verify-deploy.sh line 558 (gate8) currently invokes the shell test suite with no --jobs:

  run_all_output=$(cd "$TARGET" && bash "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh" --quiet 2>&1)

so it inherits run-all.sh's JOBS=1 default and runs fully sequentially. Make Gate 8 use the
opt-in parallelism that already exists in run-all.sh.

=== MEASURED FACTS (already committed, do not re-measure from scratch) ===
- Gate 8 alone costs ~9m21s of an ~11m03s full verify-deploy.sh run (~86% of the run).
- The shell-test-suite parallelism task added opt-in `--jobs N|auto` to run-all.sh, with a
  JOBS_CAP (4), longest-first scheduling, deterministic output ordering, and a nested-invocation
  guard that forces JOBS=1 when run-all.sh is reached from inside a suite that itself calls
  verify-deploy.sh (see run-all.sh header lines 34-140). Measured 449s -> 187s at --jobs 4 (58%
  reduction) with an identical pass/fail set to --jobs 1.

=== WHY THIS MECHANISM AND NOT THE OTHER ONE (record this reasoning) ===
The sibling redundant-verify-passes task attacked the same cost differently: capture Gate 8 ONCE
per redeploy checkpoint and share the snapshot across the pre/post/confirm passes. That was
REJECTED in its Phase 1 precondition audit because Gate 8 is NOT invariant across a
deploy-headless.sh call -- 41 of 73 files under scripts/tests/ prefer the DEPLOYED copy of their
subject-under-test over the source-store copy, so a pre-deploy snapshot and a post-deploy
snapshot are legitimately measuring different things. The rejected design and its evidence are
recorded in context/patterns/batch-orchestration-guardrails.md; read it before proposing
anything snapshot-shaped here.

Making each Gate 8 run FASTER requires no invariance premise at all, so it sidesteps the exact
reason the sharing design failed. That is the justification for this task existing, and it
should survive into the plan's rationale section.

=== CRITICAL DEPENDENCY TO RESOLVE, NOT ASSUME ===
Parallel-run safety is NOT yet empirically established. The parallelism task's Phase 6 was the
flakiness decision gate -- 3 repeated full-suite runs at --jobs 4, checked against Phase 1's
recorded baseline pass/fail set and against a named set of load-sensitive suites -- and it did
NOT complete: it was interrupted by genuine system-wide memory pressure. That task remains
PARTIAL with Phases 6 and 7 outstanding, and the user has chosen NOT to resume it for now.

Therefore this task must choose ONE of:
  (a) carry that 3-run validation itself, as an explicit EARLY phase that gates every later
      phase, before line 558 is touched at all; or
  (b) declare a hard dependency on the parallelism task's Phase 6 completing.

DECIDE THIS IN RESEARCH/PLANNING. Do not pre-decide it, and under no circumstances change
line 558 on unvalidated parallel safety. No dependency edge is recorded on this task's
`dependencies` field precisely because recording one would pre-decide option (b).

=== ALSO SETTLE ===
- What job count Gate 8 should request: a fixed N, `auto`, or inherit from an env var. Note that
  `auto` resolves to nproc capped at JOBS_CAP=4 (run-all.sh:121-130).
- Whether an environment override is needed for CI or low-memory hosts, and if so its name,
  precedence, and documented default.
- The load-sensitive suites named by the parallelism task's Phase 4 audit -- carry that list
  forward rather than rediscovering it.
- That test-run-all-parallel.sh's own timing assertions were ALREADY redesigned from absolute
  thresholds to load-tolerant relative ratios after flaking under ambient host load. Do not
  regress them to absolute timings, and do not read a ratio-based assertion as a weakened one.
- Interaction with run-all.sh's nested-invocation guard: verify-deploy.sh IS reached from inside
  some suites, so confirm the guard still forces JOBS=1 on those paths and that the new call site
  does not defeat it.

=== VERIFICATION ===
1. The pass/fail set under the new invocation is IDENTICAL to the sequential baseline set. Report
   both sets, not just a count.
2. Report before/after wall times for a full verify-deploy.sh run (no --skip-slow), measured on
   the same host.
3. --skip-slow still skips Gate 8 entirely (verify-deploy.sh:551) -- unchanged.
4. The deploy-consumer and missing-run-all.sh branches (verify-deploy.sh:553-556) are unchanged.
5. scripts/tests/ passes, including test-deploy-verify-wiring.sh,
   test-verify-deploy-gate-selection.sh, and test-run-all-parallel.sh. No test may be weakened,
   skipped, or deleted to make the change pass.


=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 267 (suppress_inline_verify_in_deploy_headless); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

=== THE REDUNDANCY ===
scripts/deploy-headless.sh runs its OWN inline verification after deploying ("Verifying deploy
(fast gates; shell test suite deferred)") -- a `verify-deploy.sh --skip-slow` pass, measured at
~1m35s (deploy-headless.sh:402 `local -a VERIFY_ARGS=(--skip-slow)`, invoked at :406).

When deploy-headless.sh is called from scripts/orchestrate-cycle-plan.sh's Inter-Cycle Redeploy
Checkpoint, the checkpoint then runs its OWN pre/post/confirm verify-deploy.sh passes. The inline
pass is duplicated work on that path.

=== THIS WAS ALREADY EVALUATED AND DEFERRED -- CONFRONT THE REASONS, DO NOT REPEAT THEM ===
The redundant-verify-passes task explicitly considered this and ruled it OUT OF SCOPE for two
stated reasons. Both are real and both must be answered here, not rediscovered:

1. deploy-headless.sh was not in that task's declared file_scope. (Procedural only -- it IS in
   this task's file_scope.)
2. Its exit-3 contract has many callers that depend on it. Exit 3 means RESULT=landed_verify_red:
   the deploy LANDED but the resulting tree FAILS verification (deploy-headless.sh:96, :108,
   :160, :454). That exit code is derived from precisely the inline run being discussed, so the
   inline verify cannot simply be deleted. The checkpoint's own branch contract consumes exit 3.

=== POINTS TO SETTLE -- DO NOT PRE-DECIDE ===
- Whether to add an OPT-IN `--no-verify` / `--skip-verify` flag that ONLY the redeploy checkpoint
  passes, leaving every other caller's exit-3 contract byte-identical. Opt-in (rather than
  opt-out) is the shape that makes "no other caller changes" a structural guarantee instead of a
  claim, but argue it rather than assuming it.
- What EXIT CODE a deploy-with-verification-suppressed should return, such that no caller can
  silently misread it as verified-green. A suppressed verify is not a passed verify, and 0 may be
  the wrong answer. Consider a distinct RESULT= token alongside whatever code is chosen, matching
  the existing RESULT= convention at :108.
- ENUMERATE EVERY CALLER of deploy-headless.sh and state what each does with exit 3. The known
  set of source files referencing it includes: verify-deploy.sh, orchestrate-cycle-plan.sh,
  orchestrate-build-dispatch.sh, orchestrate-batch-admit.sh, command-gate-out.sh, skill-base.sh,
  deploy-root-guard.sh, check-deploy-freshness.sh, check-consumer-freshness.sh,
  check-extension-docs.sh, validate-state.sh, git-snapshot.sh, task-lock.sh,
  measure-eager-context.sh, system-defect-record.sh, lib/deploy-baseline-lib.sh, plus tests
  (test-deploy-verify-wiring.sh, test-postflight-deploy-gate.sh, test-deploy-propagation.sh,
  test-deploy-orphans.sh, test-deploy-freshness.sh, test-lint-deploy-caller-wrap.sh,
  test-double-loading-check.sh, test-orchestrate-build-dispatch.sh, test-orchestrate-cycle-plan.sh,
  test-validate-state.sh) and docs (architecture/extension-system.md,
  architecture/orchestrate-state-machine.md, reference/utility-scripts-inventory.md). Verify that
  list rather than trusting it -- some references are mentions, not invocations, and the
  distinction matters.
- Whether run-all.sh's new `--only-gate` flag makes a CHEAPER TARGETED inline verify a better
  answer than suppression outright. A narrowed inline verify keeps the exit-3 contract meaningful
  while removing most of the duplicated cost, which may dominate suppression on every axis. Weigh
  it explicitly and record the comparison either way.
- Note that test-lint-deploy-caller-wrap.sh exists specifically to police how callers wrap
  deploy-headless.sh; any new flag or exit code must satisfy it, or the lint must be extended
  deliberately and with reasoning, never relaxed.

=== VERIFICATION ===
1. Every caller NOT passing the new flag observes byte-identical behavior and exit codes,
   including exit 3. Demonstrate this, do not assert it.
2. The redeploy checkpoint's total wall time is measured before and after, on a checkpoint that
   actually fires (cycle_modified_files touching agent-system/**). Report both numbers.
3. A deploy whose tree genuinely fails verification is still detectable by the checkpoint --
   suppression must not create a path where a red tree is treated as green.
4. The suppressed-verify exit code / RESULT token is distinguishable from verified-green in a
   test.
5. scripts/tests/ passes, including test-deploy-verify-wiring.sh,
   test-lint-deploy-caller-wrap.sh, and test-orchestrate-cycle-plan.sh. No test may be weakened
   or deleted to make the change pass.

=== FILE-FOOTPRINT DEPENDENCIES (auto-added, overlap-derived) ===
This task's file_scope overlaps both sibling tasks: scripts/tests/test-deploy-verify-wiring.sh is
shared with the Gate 8 parallelization task, and scripts/orchestrate-cycle-plan.sh plus
scripts/tests/test-orchestrate-cycle-plan.sh are shared with the deploy-pending/dispatch-guard
task. Both edges are serialization-only, not semantic -- rebase on whatever they land.

=== PATH REVIEW 2026-09-28 (fifth pass): premise update and ordering ===
The parallelism task this text calls PARTIAL is COMPLETED (2026-09-26): its Phase 6 flakiness gate ran three repeated --jobs 4 full-suite runs, found two load-sensitive suites unreliable only under sustained heavy contention (five concurrent agent sessions), and closed COMPLETED WITH EXCLUSIONS without flipping the serial default. Option (b) above is therefore already satisfied; do not re-run a 3-run gate from scratch -- cite that task's recorded pass/fail sets and carry its named load-sensitive suites forward.
WHY THIS IS HIGH LEVERAGE (measured 2026-09-28): the Inter-Cycle Redeploy Checkpoint in orchestrate-cycle-plan.sh takes its pre/post (and confirm) findings snapshots at FULL depth -- never --skip-slow -- so Gate 8 (~9 min of an ~11 min run) is paid two to three times per checkpoint fire, on top of deploy-headless.sh's own inline --skip-slow pass (~1.5 min). Every self-modifying task in this repo fires that checkpoint. The checkpoint runs at the one boundary with no dispatch in flight, so ambient agent load there is minimal -- the condition under which --jobs 4 reproduced the sequential pass/fail set exactly.
PHASES: (A) Gate 8 --jobs (choose a conservative default plus an env override; document; verify --skip-slow and nested-guard paths unchanged); (B) the absorbed inline-verify question in deploy-headless.sh (opt-in flag vs. --only-gate-narrowed inline verify; exit-code contract preserved for every other caller). Serialized behind the deploy-pending/identical-dispatch fix because both touch orchestrate-cycle-plan.sh's checkpoint.

---

### 263. Consent-gated git push: grant semantics and enforcement mechanism
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 139

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

=== GOAL ===
Make `git push` permissible by an agent ONLY after the user answers an interactive
AskUserQuestion gate granting permission for that specific push. The prohibition stays the
DEFAULT. Permission must never be inferred from a task description, from a prior approval in
another context, or from a user message that merely sounds permissive.

=== CURRENT STATE (verified 2026-09-25, source store) ===
rules/pr-prohibition.md has frontmatter `paths: "**/*"` (with a why-eager comment explaining the
universal glob is deliberate), so it applies repo-wide. It bans three classes:
  1. PR/MR creation (`gh pr create`, `glab mr create`, any API/wrapper equivalent)
  2. `git push` in ALL forms, explicitly including `--force`, `--set-upstream`, `-u`
  3. autonomous `/merge` invocation
Its "Required Behavior" section says agents MUST stop at `[PR READY]`, report readiness, and wait
for the user to invoke `/merge`, and states verbatim: "Never push branches or create PRs even if
asked to in task descriptions or user messages." That sentence is the one this change must
narrow -- carefully, because it is also the sentence that currently makes the rule
un-social-engineerable.

Other places the prohibition is asserted, all of which must stay consistent:
  - rules/git-workflow.md "Git Safety > Never Run" bullet: "`git push --force` to main/master"
  - merge-sources/claudemd.md: `/merge` and `/tag` marked "(user-only)" in the command table
    (lines ~111, ~114), `skill-tag | (user-only)` in the skill table (~153), and the
    "User-Only Skills" note (~165)
  - context/standards/git-integration.md and git-safety.md contain NO push references (checked) --
    so the rule surface is narrower than it might appear; do not assume otherwise without
    re-checking.

=== MECHANISMS THAT ALREADY EXIST AND SHOULD BE EXTENDED, NOT REINVENTED ===
  - scripts/git-commit-scoped.sh -- the single sanctioned path-scoped, mutex-serialized committer.
    This is the structural model for a push wrapper: one sanctioned entry point, everything else
    blocked.
  - hooks/guard-destructive-git.sh -- an existing PreToolUse Bash hook that already blocks two
    command classes (destructive-on-dirty-tree, and over-staging). Read its header in full: it
    documents that it blocks via `exit 2` + stderr, NOT `permissionDecision: deny`, because the
    latter is documented-buggy for allow-listed `Bash(git:*)` commands (GH #4669, #13214, #18312).
    Any new push guard must use the same blocking mechanism for the same reason.
    It also documents a critical asymmetry to respect: the snapshot-marker exemption applies to
    the destructive class but is FORBIDDEN from exempting the over-staging class, because a
    snapshot makes data loss recoverable while over-staging is a scope problem a snapshot does
    not make acceptable. Decide deliberately which side a push grant resembles.
  - scripts/git-snapshot.sh -- its marker-file contract is a working precedent for a ONE-SHOT
    authorization token: a fresh marker (<=120s) authorizes exactly one destructive command and is
    CONSUMED (deleted) on use. Evaluate this as the grant-token shape before designing a new one.
    Note its known observation boundary, documented in guard-destructive-git.sh: a hook only ever
    sees the top-level `tool_input.command` string, so a `git push` run as a subprocess inside a
    wrapper script is structurally invisible to the hook. That is what makes the
    wrapper-plus-hook pair work, and it is also the bypass to reason about.
  - context/standards/interactive-selection.md -- the AskUserQuestion schema and option-
    construction standard the gate must conform to.

=== DESIGN QUESTIONS TO SETTLE (these are the research/plan work; they are deliberately NOT
pre-decided) ===
  1. GRANT SCOPE: one push only, or session-scoped, or task-scoped? What INVALIDATES an existing
     grant -- new commits after the grant, a different branch, a different remote, a change from
     non-force to force? State the invalidation predicate precisely enough to implement.
  2. WHETHER PR/MR CREATION AND `/merge` FOLLOW THE SAME GATE OR STAY FULLY USER-ONLY. Working
     assumption to ARGUE FOR OR AGAINST, not to assume: push is the narrow case being opened;
     PR creation and `/merge` stay prohibited. Whichever way this lands, say why.
  3. CATEGORICAL EXCLUSIONS: are `--force` and `--force-with-lease`, and pushes to the default
     branch (master), outside what ANY grant can cover? Note the repo's default branch is master
     and rules/git-workflow.md already singles out force-push-to-master as a "Never Run".
  4. WHERE THE GATE LIVES SO IT CANNOT BE BYPASSED. A rule edit alone is documentation, not
     enforcement -- this is the central requirement. Design the enforcement pair: a wrapper/guard
     script analogous to git-commit-scoped.sh, plus a PreToolUse hook blocking bare `git push`
     call sites the way guard-destructive-git.sh already blocks its two classes. Confirm the hook
     registration shape in manifest.json against the existing registered hooks.
  5. DURABLE AUDIT RECORD: how the grant request and the user's actual answer are recorded so the
     consent is auditable after the fact. Candidates: a `.decisions.json` entry per the handoff
     schema's Decisions File Schema, and/or a specs/events.jsonl record. Record enough to
     reconstruct WHAT was authorized (remote, branch, commit sha, force-or-not) and WHEN, not
     merely that someone said yes.

=== EXPLICIT NON-GOALS ===
Do not implement the orchestrator-dispatch path here -- a dispatched subagent cannot call
AskUserQuestion, and routing that request is the companion task's scope. This task must, however,
define the grant semantics and guard interface that companion task consumes, and should state
that interface explicitly rather than leaving it implicit.

=== VERIFICATION ===
1. A bare `git push` from an agent is BLOCKED by the hook, with a stderr message naming the
   sanctioned path. Demonstrate the block, do not merely assert it.
2. A push attempted with NO grant present is blocked.
3. A push attempted with an INVALID grant (per whichever invalidation predicate is chosen --
   e.g. stale, wrong branch, wrong remote, commits added since) is blocked. Test each
   invalidation condition the design defines.
4. A categorically excluded push (force, and/or default-branch, per decision 3) is blocked EVEN
   WITH an otherwise-valid grant.
5. A push with a valid, in-scope grant succeeds through the sanctioned wrapper.
6. The audit record is written and contains enough to reconstruct what was authorized.
7. The fail-safe direction is BLOCK: an unreadable, absent, malformed, or unverifiable grant
   must block, never permit. Test the malformed case explicitly.
8. `git push` remains prohibited by default with no grant mechanism invoked -- i.e. existing
   agent behavior is unchanged unless a user actively grants.
9. Re-run the shell test suite under scripts/tests/. No existing test may be weakened or deleted
   to make this pass; a test that asserts the OLD blanket prohibition must be updated
   deliberately, with its new assertion stated in the summary.

=== VERIFIED MECHANISM MAP (surveyed 2026-09-25; use these, do not re-derive) ===
THE PROHIBITION IS CURRENTLY RULE TEXT ONLY -- THERE IS NO MECHANICAL ENFORCEMENT AT ALL.
This is the single most important finding and it reframes the work. Verified:
  - `grep -rln "git push|gh pr create|glab mr create" hooks/ scripts/` over the source store
    returns EMPTY. No hook, script, or lint blocks any of the three prohibited classes.
  - No test under scripts/tests/ (76 files) invokes `git push` or `gh pr create` against a hook to
    assert blocking. Matches for "push" there are incidental (`git stash push`; "push bytes past a
    ceiling"; an unrelated "hand-patch prohibition" string in test-orchestrate-build-dispatch.sh).
  - scripts/check-extension-docs.sh Rule H `check_undeclared_rules()` (~line 508-524) asserts only
    STRUCTURAL registration -- that rules/pr-prohibition.md is declared in manifest.json's
    `provides.rules` so it propagates to consumers. Its motivating comment records that the rule
    once existed on disk while absent from provides.rules, so it "never propagated downstream".
    That is a propagation check, not a behavioral one.
  So the guard being added here is NET-NEW enforcement, not a modification of existing
  enforcement. Consequence worth stating plainly in the plan: this change can leave the system
  STRICTER than it found it (a real hook where there was only text), even while narrowing the
  rule's stated scope. Design for that outcome deliberately.

HOOK REGISTRATION -- the wiring is NOT where you would first look:
  - manifest.json `provides.hooks` (~line 260-280) is a FLAT FILENAME LIST only
    ("guard-destructive-git.sh" among ~19 others). It carries no PreToolUse wiring.
  - merge-sources/settings-hooks.json (the deep-merge fragment applied into a consumer repo's
    .claude/settings.json) registers only `matcher: "Write|Edit"` ->
    validate-no-task-references.sh. It carries NO Bash-matcher entry.
  - root-files/settings.json is the template that actually carries the Bash-matcher registration
    for guard-destructive-git.sh (~line 44-52), shaped as a PreToolUse array entry with
    `matcher: "Bash"` and one `{"type":"command","command":"bash .claude/hooks/<script>.sh"}`.
  A new push guard must be added in BOTH manifest.json `provides.hooks` (so it deploys) AND the
  correct settings template (so it is wired). Missing either yields a silently inert hook -- which
  is precisely the failure mode Rule H exists to catch for rules.

ONE-SHOT MARKER CONTRACT (the reusable grant-token precedent), verified in
scripts/git-snapshot.sh + hooks/guard-destructive-git.sh:
  - Path: `specs/{NNN}_{SLUG}/.git-snapshot-marker`, task-scoped, gitignored via
    `**/.git-snapshot-marker`.
  - Format: line-oriented KEY=VALUE, minimally `TIMESTAMP=<epoch seconds>`, plus tool-specific
    payload fields (HEAD_SHA, PATCH_PATH, STASH_REF, BRANCH_NAME, UNTRACKED_BACKUP).
  - Freshness: `FRESHNESS_WINDOW=120` seconds. The consuming hook does
    `find specs -maxdepth 3 -name ".git-snapshot-marker" -type f`, picks newest by TIMESTAMP, and
    honors it only if `0 <= (NOW - TIMESTAMP) <= 120`.
  - Consumption: `rm -f "$BEST_MARKER"; exit 0` (guard-destructive-git.sh ~line 287-292) -- delete
    on use, so one marker authorizes exactly one gated command.
  A push grant token needs MORE payload than this marker does (remote, branch, sha, force-or-not)
  precisely so it cannot be replayed against a different push. A bare TIMESTAMP-only token would
  be a blank cheque for any push within the window -- do not reuse the shape uncritically.

scripts/git-commit-scoped.sh interface, for the wrapper to be modeled on:
  - `git-commit-scoped.sh --message <msg> --session <sid> [--honest-index-rows <task_number>]
    -- <pathspec>...`
  - PROJECT_ROOT: `SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, source lib/common.sh,
    `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"`, then `. deploy-root-guard.sh`.
  - Mutex: serializes via `specs/.commit-lock/` through `task-lock.sh commit-acquire/commit-release`,
    released in an EXIT trap; `COMMIT_MUTEX_HELD` lets a nested caller reuse the lock as a guest.
  - IMPORTANT DIVERGENCE: it fails OPEN on mutex-acquire failure (proceeds unserialized with a loud
    WARNING), reasoning the worst residual case is a safe index.lock race, not misattribution. A
    PUSH guard must fail CLOSED -- an unavailable lock or unverifiable grant must refuse the push.
    Do not inherit the fail-open direction; state this divergence explicitly in the code comments.
  - Shape to mirror: usage/flag parsing -> PROJECT_ROOT resolution -> mutex acquire/release via
    task-lock.sh verbs -> guarded git operation -> bounded retry on index.lock. Safety gates
    V2/V3/V4 (unmatched-path classification, exclude-only-pathspec refusal, nothing-to-commit
    exit 1) are the precedent for refusing ambiguous input rather than guessing.

AUDIT WRITER: scripts/events-append.sh is the sanctioned specs/events.jsonl writer (analogous to
state-write.sh): builds the line via `jq -c -n`, appends under `flock` on specs/.events.lock.
Required flags `--event-type --category --session --message`; optional `--task --checkpoint
--duration --detail-json --error-ref --cwd --cc-session-id`. `--category` is an enum:
deviation|blocker|milestone|success -- pick the fitting one and justify it. Record fields and the
draft-07 schema live in context/formats/events-format.md and context/schemas/events-schema.json,
which MUST stay in sync with each other. Never hand-append to events.jsonl.

DANGLING REFERENCE TO RESOLVE (small, real, in scope): hooks/guard-destructive-git.sh line 6 says
it is "Modeled line-for-line on .claude/hooks/block-pr-submission.sh", but NO file named
block-pr-submission.sh exists anywhere in the source store, and manifest.json has no
provides.hooks entry for it. It is a deploy-side-only artifact, i.e. either an orphan that
source-store regeneration will wipe or a stale reference to something already gone. Determine
which and fix the reference. Do not leave a header comment pointing at a file the source store
does not contain.


=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 224 (please_grant_integrity_and_git_guards); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Add a tamper-resistant single-use /please grant mechanism, a new git push guard, and grant checks in the destructive-git guard. Only agent-system/extensions/core/ is edited (hooks/, scripts/tests/, root-files/settings.json and/or merge-sources/settings-hooks.json, context/standards/git-safety.md), never .claude/.

(1) GRANT HOOK. A UserPromptSubmit hook that, when the literal user prompt starts with "/please", writes one grant (request text, timestamp, 10-minute expiry). Research must first verify what the hook payload actually contains (raw "/please ..." text or the expanded command body) and that subagent- or model-generated prompts can never trigger UserPromptSubmit.

(2) INTEGRITY, TO BE SETTLED IN RESEARCH. "The model must not be able to create grants" and "forged grant file rejected" require a real integrity mechanism: a gitignored file the model can Write to is forgeable. Starting point: an HMAC over each grant using a secret key stored outside the model-reachable/writable paths (or readable only by the hook), plus a PreToolUse guard blocking Write/Edit/Bash writes to the grant file and the key path. State the threat model honestly: a same-user shell process can in principle read any file the hook can read, so this raises the bar rather than proving user intent; name the residual risk. Decide whether the grant belongs outside the repo (e.g. $XDG_STATE_HOME) or in a gitignored in-repo path (the repo .gitignore currently ignores /.claude/ and /specs/tmp; root-files/.gitignore only covers .claude/).

(3) MATCHING RULE, TO BE SETTLED IN RESEARCH. Define how the free-text request is matched to the concrete command, e.g. action class (force-push, reset --hard, clean -fd, ...) plus remote/branch extracted from both. Ambiguous or partial matches are refused; one grant covers one action class and one target.

(4) PUSH GUARD. No push guard exists today (rules/pr-prohibition.md is advisory only; root-files/settings.json allow-lists Bash(git:*)). Create a new PreToolUse Bash hook (e.g. hooks/guard-git-push.sh) that blocks git push without a matching unexpired grant, via exit 2 + stderr like guard-destructive-git.sh (permissionDecision: deny is documented-buggy for allow-listed git commands). Research decides whether it also covers gh pr create / glab mr create and how /merge own push stays working.

(5) DESTRUCTIVE-GIT GUARD. hooks/guard-destructive-git.sh allows a matched action only with a matching unexpired grant, consuming it on use (mirror the existing .git-snapshot-marker consume-on-use pattern). Without a grant, behavior is unchanged. Preserve the clean-tree early exit and the COMMAND_SCAN quote/comment-stripping; a grant must never exempt the over-staging detectors. Decide where the grant check sits relative to the clean-tree early exit.

(6) REGISTRATION. Register the new hooks in the source-store settings file(s) research identifies (PreToolUse Bash hooks currently live in root-files/settings.json; UserPromptSubmit hooks in merge-sources/settings-hooks.json).

(7) TESTS in scripts/tests/ following context/standards/shell-script-testing.md and the fixture style of test-guard-destructive-git.sh (hook run as a subprocess against a synthetic dirty repo, asserting exit codes): forged grant rejected, expired grant rejected, grant consumed after one use, mismatched action/target rejected, no-grant behavior unchanged for both guards, writes to grant file and key path blocked.

OVERLAP NOTE (no dependency edge, by user decision): the pending history-rewrite predicate work on guard-destructive-git.sh also edits hooks/guard-destructive-git.sh, rules/git-workflow.md and context/standards/git-safety.md. Structure predicate ordering so the two additions compose; the file-footprint admission gate serializes them if run concurrently.

Redeploy afterwards and confirm the hooks fire from the deployed copies.

=== ABSORBED 2026-09-17 from former task 225 (/please command, never-list, pr-prohibition exception, docs); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
Add the user-only /please command, its never-list, the pr-prohibition exception, and the CLAUDE.md command-reference entry. Only agent-system/extensions/core/ is edited (commands/please.md, commands/README.md, rules/pr-prohibition.md, merge-sources/claudemd.md), never .claude/. Builds on the grant mechanism and guards from the predecessor task (dependency).

(1) commands/please.md, user-only, modeled on commands/merge.md and commands/tag.md: authorizes one otherwise-blocked action per invocation (e.g. "/please force-push main to origin"). Parse the requested action; show the exact command and its effect (for pushes: local vs remote SHAs); confirm with AskUserQuestion before any irreversible step; prefer safe forms (--force-with-lease=<ref>:<observed remote SHA> over --force); do only the literal request; log the action to specs/events.jsonl via scripts/events-append.sh. Caveat to state in the command: the grant proves the user typed /please, not that the command the agent then runs is the one meant, so the confirmation step is mandatory for anything irreversible.

(2) NEVER-LIST, refused regardless of wording and enforced in the command: credential/secret access, deletion outside the repo, .git internals, disabling/editing/removing hooks or hook settings.

(3) rules/pr-prohibition.md: add a /please exception scoped to the single action of that one invocation, reconciled explicitly with the existing "never push even if asked in user messages" language.

(4) merge-sources/claudemd.md: add a /please row to the Command Reference table beside /tag and /merge, marked user-only; add a row to commands/README.md.

Redeploy and confirm the generated .claude/CLAUDE.md shows the new row.

=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 264 (relay_push_consent_through_user_decision); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable
deploy artifact -- see rules/source-store-deploy-boundary.md).

DEPENDS ON the consent-gated-push design task, for two independent reasons: (1) semantic -- this
task routes a push REQUEST through the orchestrator and mints the grant its guard consumes, which
is impossible until that task settles the grant semantics, the invalidation predicate, and the
wrapper's interface; (2) file-footprint overlap -- both touch rules/pr-prohibition.md and
manifest.json. Rebase on whatever that task lands.

=== GOAL ===
Two things: (a) define how an agent running in a fire-and-forget dispatch REQUESTS a push, since it
cannot call AskUserQuestion itself, and how the user's answer becomes a grant the guard honors;
(b) sweep the codebase so nothing still asserts the blanket prohibition the companion task
narrowed.

=== (a) THE DISPATCH PATH -- EXTEND THE EXISTING CHANNEL, DO NOT INVENT ONE ===
A dispatched subagent cannot call AskUserQuestion. Verified concretely: while these tasks were
being created, the dispatched agent doing so had NO AskUserQuestion tool available -- a
ToolSearch for it returned "No matching deferred tools found". So the request must be relayed.

The channel exists and this case is already inside its stated remit.
context/standards/user-decision-contract.md defines an agent-authored `user_decision`, and
context/formats/return-metadata-file.md (~line 507, "### user_decision (optional)") gives its
shape: a TOP-LEVEL object on `.return-meta.json`, producer-owned by the agent that sets it,
`{question, options: [...], recommended, blocking: true|false}`, mirrored onto
`.orchestrator-handoff.json` when that dispatch also writes one. Later writers must merge without
touching it. The contract's enumerated qualifying shape 2 is, verbatim: "An external cost or risk
the user must accept -- spending money, granting a credential, deleting data, or taking an action
outside this repository that the agent cannot verify is already sanctioned." A push to a remote is
squarely an action outside this repository. Treat that as the designed home for this request.

VERIFIED RELAY PATH (use these call sites; do not re-derive):
  - scripts/orchestrate-cycle-postflight.sh, "WORK (e): user_decision relay" (~lines 1073-1096):
    reads `.orchestrator-handoff.json` first when fresh (`handoff_stale != true`), else
    `.return-meta.json`; a non-null value sets `verdict="ask_user"`, which "takes precedence over
    every other signal". The script relays and NEVER resolves (its line-68 comment:
    "user_decision is RELAYED, never resolved") and explicitly never writes .decisions.json
    (~line 1088).
  - skills/skill-orchestrate/SKILL.md Move 3 "Postflight" (~lines 208-213) ACCUMULATES rather than
    asking per task: `.pending_ask_user = ((.pending_ask_user // []) + [{"task": $tn,
    "decision": $q}])`.
  - Move 4 "Branch" batched relay (~lines 256-263): if `pending_ask_user[]` is non-empty, call
    AskUserQuestion once per entry (question/options/recommended from `.decision`), all batched at
    the single Move-4 boundary -- "never mid-cycle, never one call per task". Non-blocking
    decisions proceed on the agent's recommendation and are only surfaced in output.
  - Move 4 then appends each answer to `specs/{padded}_{project}/.decisions.json` and clears that
    task's `pending_ask_user`.

*** CRITICAL DESIGN HAZARD -- THE EXISTING REPLAY CHANNEL ***
`.decisions.json` is not inert. Schema in docs/architecture/handoff-schema.md (~lines 951-991):
a JSON array of `{question, answer, cycle, timestamp}` at
`specs/{NNN}_{slug}/.decisions.json`, absent until the first decision is answered, additive only.
scripts/orchestrate-build-dispatch.sh (~lines 38-42, 367-377, 511-518) READS it when building the
NEXT dispatch for the same task and emits a `## Prior Decisions` section so the answer is not
re-asked. That mechanism is desirable for ordinary design decisions and DANGEROUS here: a recorded
"yes, push" would be replayed into every subsequent dispatch for that task as standing prior
approval -- which is exactly the failure the requirement forbids ("permission must never be
inferred from a prior approval in another context"). Resolve this explicitly. Either exclude push
grants from the `## Prior Decisions` injection, or record them in a form that is self-evidently
non-reusable (bound to a specific sha/branch/remote that a later cycle cannot satisfy), or both.
Do NOT leave the default replay behavior in place for this decision class. Whatever is chosen,
verify it with a test that runs two cycles and confirms the second does not inherit the grant.

Also establish:
  - How the push request is expressed in the `user_decision` payload with enough specificity that
    the answer authorizes ONE identifiable push (remote, branch, commit sha, force-or-not). A
    vague "may I push?" the guard then interprets broadly would defeat the design. The payload's
    `options`/`recommended` fields must make the exact target legible to the user at the moment
    they answer -- consent to an unspecified push is not consent.
  - Whether such a request may ever be `blocking: false`. It almost certainly must always be
    `blocking: true`, since the non-blocking path proceeds on the AGENT's recommendation without
    asking -- which would be an agent authorizing its own push. Confirm and enforce this.
  - The RETURN LEG, which has no existing precedent: the relay today surfaces decisions to the
    user; it does not mint an authorization token a later subprocess consumes. Design how a YES
    becomes a grant the guard script honors, and where that token lives.
  - What happens when the request is relayed but the run ENDS before an answer, and when the user
    answers NO. Both must leave the task clean with no push performed.
  - Whether a granted push may carry across a later cycle in the same run, or dies with the
    dispatch that requested it. Must be answered consistently with the companion task's
    grant-scope decision.

Constraint to preserve: the contract's core invariant is that the orchestrator never asks on its
own and never decides on the user's behalf, and that agents decide everything else themselves. A
push request must not become a prompt agents raise reflexively; it qualifies only when a push is
genuinely the task's sanctioned endpoint.

=== (b) CONSISTENCY SWEEP ===
Note up front, verified: there is NO existing lint or test asserting behavioral push/PR blocking,
so this sweep is about DOCUMENT consistency plus ADDING the missing tests, not about repairing
broken assertions. The only structural check is scripts/check-extension-docs.sh Rule H
`check_undeclared_rules()`, which asserts rules/pr-prohibition.md is declared in manifest.json's
`provides.rules`; keep that satisfied.

Files to reconcile:
  - rules/pr-prohibition.md -- the narrowing lands in the companion task; verify no stale absolute
    language survives, especially "Never push branches or create PRs even if asked to in task
    descriptions or user messages", which must still hold verbatim for everything the new gate
    does NOT cover. Its `paths: "**/*"` frontmatter and why-eager comment stay.
  - rules/git-workflow.md -- the "Git Safety > Never Run" bullet on `git push --force` to
    main/master, and the "Enforced by guard-destructive-git.sh" note if a new guard joins it.
  - merge-sources/claudemd.md -- this is the GENERATED-FROM source for the deployed
    .claude/CLAUDE.md; edit here, never the deployed file. Reconcile the `/merge` and `/tag`
    "(user-only)" command-table markings (~lines 111, 114), `skill-tag | (user-only)` in the skill
    table (~153), and the "User-Only Skills" note (~165). If the companion task decided PR
    creation and `/merge` stay prohibited, these stay and should be reinforced, not loosened.
  - commands/merge.md and skills/skill-tag/SKILL.md -- both reference the prohibition; check both.
  - context/standards/status-markers.md -- confirm whether a consented push changes when a task
    reaches `[PR READY]`. Most likely it does not; say so explicitly rather than leaving it
    unexamined.
  - If a new audit event type is introduced, context/formats/events-format.md and
    context/schemas/events-schema.json must stay in sync with each other.

=== VERIFICATION ===
1. A dispatched subagent needing a push emits a well-formed top-level `user_decision` with
   `blocking: true` and does NOT push.
2. postflight sets `verdict="ask_user"`; Move 3 accumulates it into `pending_ask_user`; Move 4
   relays it in the batch with the specific push identified (remote, branch, sha, force-or-not).
3. A NO answer results in no push and a clean task state.
4. A run ending before an answer results in no push and a clean task state.
5. A YES produces a grant the guard honors for exactly that push and no other: verify a replay
   against a different branch, a different remote, and a later commit is each refused.
6. TWO-CYCLE TEST for the hazard above: after a granted push in cycle N, cycle N+1's dispatch does
   NOT inherit standing permission via `## Prior Decisions`.
7. `grep` the source store for remaining blanket-prohibition language; list every file changed and
   every file deliberately left unchanged, with reasons.
8. Re-run scripts/tests/ plus the check-*.sh lints, including check-extension-docs.sh Rule H. No
   test weakened or deleted; any test whose assertion changed is named in the summary with its old
   and new assertion. New tests must cover items 1-6.

=== PATH REVIEW RULING 2026-09-28 (fifth pass) -- ONE grant mechanism, not three ===
Three tasks (this one, the absorbed /please task, and the absorbed user_decision relay task) each designed a git-push grant. They are now one task with three phases, and the following is settled rather than re-litigated:
  1. INTEGRITY DECIDES THE MINT PATH. A grant file the model can Write after reading an AskUserQuestion answer is forgeable by construction -- exactly the artifact the absorbed /please text rejects. So the tamper-resistant mint path is the /please UserPromptSubmit hook (the harness fires it only on a literal user prompt; research item (1) of the absorbed text must still VERIFY the payload shape and that model- or subagent-generated prompts never trigger it). AskUserQuestion is the confirmation surface, never the mint.
  2. THE TOKEN CARRIES THE TARGET. Whatever the /please grant records, it must bind action class + remote + branch + commit sha + force-or-not (this task's design questions 1 and 3), single-use, short expiry, fail-CLOSED on any unreadable/malformed/mismatched grant. The bare TIMESTAMP-only snapshot-marker shape is explicitly insufficient.
  3. THE DISPATCH PATH ONLY RELAYS. A dispatched agent emits a blocking user_decision whose options make the exact push legible; Move 4 relays it once at cycle end (settled decision: the orchestrator never asks on its own and never decides). A YES does NOT mint anything -- the relayed text tells the user the exact /please line to type, and the guard consumes that grant. This closes the .decisions.json replay hazard for free: nothing replayable is ever recorded, but the two-cycle test in the absorbed text still ships to prove it.
  4. PR/MR creation and /merge stay user-only. Force-push and pushes to master are outside any grant unless the /please never-list explicitly admits a --force-with-lease form; decide and record.
  5. skills/skill-orchestrate/SKILL.md sits at 17 B under its 20,000 B ceiling (measured 2026-09-28). Any relay text added there must be offset byte-for-byte (mode-gate it or move it to a context file) -- verify-deploy Gate 20 will otherwise refuse the redeploy.
PHASES: (A) grant token + /please hook + integrity + push guard + destructive-git grant check + tests; (B) /please command, never-list, rule exception, docs sweep (the absorbed consistency sweep); (C) dispatch relay + two-cycle test. Depends on the history-rewrite task (guard-destructive-git.sh, git-safety.md, git-workflow.md are shared; its predicate ordering must compose with the grant check).

---

### 255. Reconcile typst extension scope ownership and fix chapter-quality-check.sh Rule 1.3 bib resolution
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Reconcile the typst extension's declared scope with what it actually owns, and fix chapter-quality-check.sh silently skipping BLOCKING Rule 1.3

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/typst/ (never .claude/**). This extension deploys to at least 5 repos (Logos/Verification, Logos/ModelChecker, BimodalLogic, SPSDemo, plus the source store), so every edit must land in the source store and reach deployed trees only by regeneration.

WHY THESE TWO DEFECTS ARE ONE TASK. Both make the extension's chapter-quality machinery fail to engage, at two consecutive points in the same pipeline. Defect 1 stops the right agents from being dispatched at all: chapter-content work self-detects as `general`, so general-research-agent/general-implementation-agent run instead of the typst agents, and those agents never execute the chapter-quality gates. Defect 2 stops a BLOCKING rule from being evaluated even once the typst agents DO run. Fixing only one leaves the machinery half-connected: fix routing alone and the gate still under-enforces; fix the gate alone and most chapter work never reaches it. The two halves have disjoint file scopes and should be separate implementation phases, but they share a single acceptance question -- does chapter-quality enforcement actually fire end to end?

=== PART 1: SCOPE NOTE AND keyword_overrides CONTRADICT THE EXTENSION'S OWN STANDARD ===

EXTENSION.md lines 5-9 ("### Scope") currently state: "This extension covers formatting, compilation, styling, and structural concerns for existing document content. Content-creation work (proofs, theorems, chapters, textbook prose) routes to `lean4`, `formal`, or `general` as appropriate, not to `typst`."

This is contradicted by what the extension actually ships.

THE CONTRADICTION IS BROADER THAN chapter-quality.md ALONE -- verified by direct inspection of the source store, and the single most important finding to carry forward. Beyond context/project/typst/standards/chapter-quality.md (which is entirely about chapter CONTENT quality across four dimensions: SOURCE GROUNDING, ANTI-FLUFF DENSITY, PRESENTATION CLARITY, OPEN-QUESTION HONESTY), the extension also ships:
  - context/project/typst/standards/textbook-standards.md
  - context/project/typst/standards/type-theory-foundations.md
  - context/project/typst/patterns/theorem-environments.md
  - context/project/typst/templates/chapter-template.md
So the phrase "Content-creation work (proofs, theorems, chapters, textbook prose) ... not to `typst`" contradicts roughly a third of the extension's own context corpus, naming four categories (proofs, theorems, chapters, textbook prose) of which at least three have dedicated context files INSIDE this extension. Do not scope the reconciliation to chapter-quality.md alone; audit the full context/project/typst/ tree and state a boundary that matches it.

The contradiction is also enforced in code, not merely documented: scripts/chapter-quality-check.sh is executed as a gate by agents/typst-implementation-agent.md at Stage 4C and Stage 5 (MUST DO items 7-8), and agents/typst-research-agent.md loads chapter-quality.md as calibration context.

OBSERVED CONSEQUENCE (live, not hypothetical): a task to review and condense typst manual chapters was detected as task_type `general` and had to be re-routed to `typst` by hand.

manifest.json keyword_overrides.typst.keywords currently holds 8 phrases, every one formatting/compilation-shaped:
  "typst formatting", "typst compile", "typst compilation", "typst package",
  "typst template", "typst style", "typst layout", "fletcher diagram"
Nothing matches "typst chapter", "typst manual", "chapter quality", or "chapter prose", which is why detect_task_type() falls through to `general`.

REQUIRED:
  1. Decide and state the REAL boundary between `typst` and `lean4`/`formal`/`general`. Chapter-quality and chapter-prose work IS in scope for this extension -- the question to answer is where proofs and theorems sit, given that theorem-environments.md and type-theory-foundations.md ship here. A defensible split is likely "typst owns presentation and quality of prose/chapters including their theorem PRESENTATION; lean4/formal own mathematical CONTENT and correctness" -- but argue it, do not assume it.
  2. Rewrite EXTENSION.md's Scope section to match. NOTE THE DEPLOY PATH: EXTENSION.md is the claudemd merge source (manifest.json merge_targets.claudemd -> .claude/CLAUDE.md, section_id `extension_typst`), so the deployed CLAUDE.md section regenerates from it. Edit EXTENSION.md, never the deployed section.
  3. Extend manifest.json keyword_overrides.typst.keywords so chapter/manual-quality work self-detects as `typst`.

KEYWORD SAFETY CONSTRAINT: check every added keyword against scripts/lib/task-type-detect.sh's resolution ladder. Extension keyword_overrides are step 2; the FIRST whole-word match in alphabetical directory order wins and is FINAL. An over-broad keyword (e.g. a bare "chapter" or bare "manual") could hijack tasks meant for other extensions, since `typst` sorts early alphabetically. Prefer qualified multi-word phrases ("typst chapter", "chapter quality", "typst manual") over bare nouns, and verify no collision with other loaded extensions' keyword sets.

=== PART 2: chapter-quality-check.sh SILENTLY DISABLES BLOCKING RULE 1.3 ===

Rule 1.3 (citation keys resolve in the .bib) is BLOCKING, but is routinely never evaluated.

Location: scripts/chapter-quality-check.sh -- resolve_bibliography() at lines 347-370, call site at lines 634-640, documented contract in the header at lines 99-101.

Current logic: (a) grep `#bibliography("...")` in the CHECKED FILE; else (b) accept the single *.bib found by `find "$root" -type f -name '*.bib'`. Zero or multiple candidates => Rule 1.3 NOT EVALUATED.

BUG 2a -- MULTI-FILE MANUALS CAN NEVER MATCH BRANCH (a). In any multi-file manual, chapters are `#include`d into a root document that owns the `#bibliography(...)` declaration. The chapter file itself never carries the declaration, so branch (a) can never match for a chapter file -- exactly the file type this checker exists to check. Needs resolution via the including/root document, or a nearest-ancestor search.

BUG 2b -- BRANCH (b) COUNTS VENDORED .bib FILES. The find has no exclusion for vendored or build directories. Reproduced in Logos/Verification: typst/manual/bibliography.bib plus a vendored framed_channel/aeneas/.lake/packages/mathlib/docs/references.bib makes the candidate count 2, so the single-candidate test fails and the rule is skipped. ANY repo with a vendored dependency carrying a .bib hits this. Exclusions likely needed for at least .lake/, .git/, node_modules/, target/, build/.

NARROWING FINDING -- resolve_bibliography() ALREADY HANDLES DECLARED PATHS. Lines 355-358 already contain a `filedir` fallback: when a `#bibliography("...")` declaration IS present but the path does not resolve against the repo root, it retries against the checked file's own directory. That branch is sound and needs no work. ONLY the undeclared and multi-candidate branches need fixing. Do not rewrite the declared-path branch.

VERIFIED REPRODUCTION, from /home/benjamin/Projects/Logos/Verification:
  bash .claude/scripts/chapter-quality-check.sh --verbose typst/manual/chapters/01-introduction.typ
Emits:
  [INFO] Rule 1.3 NOT EVALUATED: no resolvable .bib file (no #bibliography(...) declaration and zero or multiple *.bib candidates under /home/benjamin/Projects/Logos/Verification)
  SCORE ...: MECHANICAL 4/6 | BLOCKING 0 | ADVISORY 4 | JUDGED 12 prompts pending
  CHAPTER QUALITY CHECK PASSED
...and exits 0.

SEVERITY AND THE SURFACING QUESTION: a BLOCKING rule becomes unenforced while the script still prints "CHAPTER QUALITY CHECK PASSED". It is quiet rather than fully silent -- it does emit an [INFO] NOT EVALUATED line and drops the score to MECHANICAL 4/6 -- but the PASSED banner is misleading to anyone reading only the last line, which is the common case in agent gate output. Part of this task is to DECIDE whether an unevaluated BLOCKING rule warrants louder surfacing than [INFO] (e.g. a [WARN] tier, or qualifying the PASSED banner when any BLOCKING rule was skipped). Note this is a judgement call with a real tradeoff: the current [INFO]/never-fail posture is deliberate per the header contract, so any change to it must be argued and the header updated to match.

=== TESTS ===

scripts/tests/test-chapter-quality-check.sh (317 lines) needs cases for both 2a and 2b.

CRITICAL -- AN EXISTING TEST ASSERTS THE BUGGY BEHAVIOR. Case-f at lines 168-181 ("unresolvable bibliography") currently ASSERTS exit 0 plus "NOT EVALUATED" for a file with no declaration and no .bib. That assertion must be REVISITED, not merely supplemented with new cases. A researcher or implementer who only adds new cases will leave a test actively contradicting the fix, and the suite will either fail or silently pin the old behavior. Decide whether case-f remains valid (a genuinely bib-less repo arguably should still be NOT EVALUATED) or must be re-scoped so it no longer covers the multi-candidate/include-root paths the fix now resolves.

Related existing fixtures to check for interaction: case-a (lines 65-81, compliant fixture with declared refs.bib), case-e (lines 144-165, Rule 1.3 violation with a declared bib), and the dirscan fixture at line 304 which copies refs.bib into a second directory -- that last one may already be sensitive to candidate-counting changes.

HEADER CONTRACT MUST BE UPDATED IN THE SAME COMMIT. Header lines 99-101 document the current (a)/(b) resolution contract verbatim. The script header states the rule inventory must never drift from the standard, so any behavior change here requires the header updated in the same commit as the code.

=== ACCEPTANCE ===
  1. EXTENSION.md's Scope section is consistent with every file under context/project/typst/ -- no category is disclaimed that the extension actually ships context for.
  2. A task phrased like "review and condense the typst manual chapters" self-detects as task_type `typst` via detect_task_type(), demonstrated by running the detection, not asserted.
  3. No added keyword hijacks a task belonging to another extension; verified against the alphabetical-first-match ladder in scripts/lib/task-type-detect.sh.
  4. Rule 1.3 evaluates for a chapter file that is `#include`d into a root document carrying the `#bibliography(...)` declaration.
  5. Rule 1.3 evaluates in a repo containing a vendored .bib under .lake/ (or equivalent) alongside the real bibliography -- demonstrated against the Logos/Verification reproduction above.
  6. scripts/tests/test-chapter-quality-check.sh green, with case-f explicitly re-examined and its disposition recorded.
  7. Header lines 99-101 match the implemented resolution contract.
  8. No test weakened or deleted to make the change pass.

=== SCOPE DISCIPLINE ===
  - Edits land ONLY in agent-system/extensions/typst/. Do not edit any deployed .claude/ tree, in this repo or any of the 5 consumer repos.
  - Do not touch scripts/typst-element-lint.sh or its tests; it is a separate gate with its own contract.
  - Part 1 and Part 2 have disjoint file scopes (EXTENSION.md + manifest.json vs. scripts/chapter-quality-check.sh + its test). Keep them as separate phases so each can be committed green independently.

---

### 251. Context-corpus reachability probe (filename, directory, index.json), then act on dead and overlapping files
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 249, Task 44, Task 127

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

### 250. Script-corpus inventory probe, then cut tests/run-all.sh runtime and decompose orchestrate-cycle-plan.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 199, Task 245, Task 249, Task 259, Task 265, Task 266

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

MOTIVATION -- A GAP IN THE INTAKE MECHANISM, NOT A SINGLE DEFECT. Tasks in this repo are filed by hand from defects hit live during /orchestrate runs. That intake only ever surfaces what BROKE. Needless complexity, duplicated logic and poor division of labor never break anything -- they only cost -- so they are invisible to the filing process by construction and will not self-correct. Every existing script-touching task is a point fix on one file. Nothing reviews the corpus. This task closes that gap with a standing probe, not a one-off reading pass.

MEASURED 2026-09-22 (re-measure before acting; standing rule 3).
  - 182 non-test .sh files under agent-system/extensions/**, 63,740 lines total.
  - The orchestrate engine alone: 8,207 lines across 14 orchestrate-*.sh scripts.
  - orchestrate-cycle-plan.sh: 2,279 lines -- 27.8% of the engine in ONE file, and 6.5x the
    351-line median of its own 14-script family (next largest: cycle-postflight at 1,256).
  - scripts/lib/ already holds 14 extracted libraries totalling 2,564 lines (common.sh,
    file-scope-overlap.sh, manifest-routing-lib.sh, task-lookup-lib.sh, ...). The extraction
    pattern is ESTABLISHED and working; it simply has never been applied to the largest file.

ANTI-ANALYSIS CONSTRAINT -- READ THIS BEFORE PLANNING. A "review all 182 scripts" pass that
emits a report and no diff is the failure mode this repo's own hard-mode contract names (H2:
forbidden analysis-only outputs, analysis-paralysis signal). This task is therefore explicitly
two-part: build a MECHANICAL probe, then act on its RANKED output. Any phase whose only artifact
is prose is out of contract. The probe is the deliverable that outlives the task.

PHASE 1 -- THE PROBE (mechanical, becomes permanent).
Add a standing inventory probe following the EXISTING convention of scripts/assess-repo-health.sh
and scripts/measure-eager-context.sh (JSON to stdout, --check mode, no side effects, reads the
SOURCE STORE not .claude/**). Per non-test script it must report at minimum:
  - line count and byte count;
  - inbound caller count (how many skills, agents, commands, manifests, hooks and other scripts
    reference it) -- a script with zero callers is a finding in itself;
  - whether a test suite covers it (pair against scripts/tests/ and flat scripts/test-*.sh);
  - duplicated-block detection ACROSS scripts, so copy-paste that belongs in lib/ is visible;
  - whether it is registered in the owning manifest's provides.scripts (the same class of drift
    check-extension-docs.sh already performs -- reuse, do not reimplement).
Register it in docs/reference/utility-scripts-inventory.md alongside the other repo-health probes.
Emit a stable ranked ordering so Phase 2+ targets are chosen by evidence, not by preference.

PHASE 2+ -- ACT ON THE RANKING, HIGHEST FIRST.
Decompose orchestrate-cycle-plan.sh into lib/ extractions, following the shape the 14 existing
libs already demonstrate. This is a BEHAVIOR-PRESERVING refactor:
  - the --dry-run JSON payload and the human table must be byte-identical before and after for a
    representative multi-task invocation (capture the baseline FIRST, diff at the end);
  - md5sum specs/state.json unchanged across a --dry-run call, as today;
  - scripts/tests/test-orchestrate-cycle-plan.sh green throughout, and green after each extraction
    rather than only at the end (commit-per-green-substep, per rules/git-workflow.md).
Size each extraction to one agent run. Do NOT attempt the whole 2,279 lines in a single phase.

SCOPE DISCIPLINE.
  - Phase 2 targets orchestrate-cycle-plan.sh ONLY among the engine scripts. Do NOT edit
    orchestrate-batch-admit.sh (owned by the admission tasks), orchestrate-predispatch-review.sh,
    or orchestrate-cycle-postflight.sh in this task -- each is another open task's declared scope,
    and editing them here reintroduces exactly the undeclared-overlap deferral the batch engine
    exists to prevent.
  - If Phase 1's ranking names further scripts worth decomposing, ADD them to file_scope at plan
    time (the convention already used elsewhere in this backlog) or file them as separate tasks.
    Do NOT declare a whole-directory or glob file_scope entry: coarse entries draw
    validate-state.sh warnings and defer unrelated tasks in the dry run.
  - Never weaken or delete a test to make a refactor pass.

ACCEPTANCE.
  1. The probe runs clean, is registered, and its output is reproducible across two runs.
  2. Every script with zero inbound callers is either removed or justified in the summary.
  3. orchestrate-cycle-plan.sh is materially smaller, with the extracted logic in lib/ and each
     extraction covered by the existing suite.
  4. Byte-identical --dry-run output vs. the captured pre-refactor baseline.
  5. run-all.sh green -- read the summary line AND the exit code, and do NOT pipe it through
     tail/head (that masks both; it is how a red run read as green on 2026-09-22).
  6. verify-deploy.sh --skip-slow no worse than at task start.

DEPENDENCIES AND WHY.
  - 199 declares orchestrate-cycle-plan.sh in its own file_scope and decides the working-tree /
    build isolation posture. Decomposing the file while another task is changing its behavior is
    a guaranteed conflict; 199 lands first.
  - The in-flight admission task rewrites orchestrate-batch-admit.sh, which cycle-plan calls.
    Refactoring the caller across a changing callee contract is the same hazard.

DELIVERABLE RULE: no task numbers in deliverables outside specs/** (no-task-references-in-deliverables.md).

=== WORKED EXAMPLE ADDED 2026-09-22: tests/run-all.sh IS THE FIRST PHASE-2 TARGET ===

Reported by the user as "runs very slow", then profiled. This is the concrete exemplar for what
Phase 1's probe should surface and what Phase 2 should do about it. Every number below was
measured on 2026-09-22 by timing each suite individually; re-measure before acting (standing
rule 3).

MEASUREMENT: 92 suites, 557.1 s (9.3 min) end to end, strictly serial.

  329,016 ms  test-verify-deploy-context-budget.sh   <- 59.1% OF THE ENTIRE RUN, and it is the
   39,778 ms  test-orchestrate-cycle-plan.sh             one suite currently FAILING
   21,828 ms  test-literature-convert.sh
   19,160 ms  test-git-commit-scoped.sh
   13,835 ms  test-roadmap-argv-ceiling.sh
   11,728 ms  test-orchestrate-cycle-postflight.sh
   11,086 ms  test-state-write-concurrency.sh

  Top 5 = 76.0% of total. Top 10 = 83.7%. 56 of the 92 suites finish in under 1 second.

This is an extreme long-tail profile, and it dictates the ORDER of the work.

FINDING 1 -- THE LONG POLE, AND WHY IT COSTS 329 s.
test-verify-deploy-context-budget.sh builds its fixture by rsync-ing the ENTIRE
agent-system/extensions/ tree (17 MB) into a mktemp mirror (its line 74). It does this because a
minimal fixture makes verify-deploy.sh's gates 3-13 SKIP, which would make the suite vacuous --
that is a deliberate, correct design decision, documented in the suite's own header, and it must
NOT be "fixed" by shrinking the fixture back into vacuity. It then runs verify-deploy.sh over
that full-size mirror several times; verify-deploy's own header measures a --skip-slow run at
roughly 50-70 s, and N x ~55 s accounts for the observed 329 s almost exactly. The suite already
uses --skip-slow correctly (its header notes gate 8 "would otherwise recurse"), and it has
already been hand-optimized once (three fixture mutations combined into a single invocation).
The remaining cost is structural, not sloppiness.

FINDING 2 -- THE HIGHEST-LEVERAGE FIX: verify-deploy.sh HAS NO GATE SELECTOR.
verify-deploy.sh accepts [--quiet] [--findings] [--skip-slow] [--minimal-init DIR] [TARGET_REPO]
and nothing else -- there is no --only-gate / --gate / GATE_FILTER. This suite exercises GATE 20
(the orchestrator context budget) and needs the other ~19 gates only so they do not SKIP the
fixture into vacuity. Adding a gate selector to verify-deploy.sh, and having this suite request
only the gate it asserts on, is the single largest available win in the whole harness: it should
take the suite from ~329 s toward tens of seconds, and run-all.sh from ~557 s to roughly ~250 s
on its own. Confirm by measurement, not by assumption, and confirm the suite stays non-vacuous
(the selector must not become a way to skip the gates that give the fixture its realism).

FINDING 3 -- SERIAL BY CONSTRUCTION, WITH ONE STRUCTURAL BLOCKER.
The runner loop (run-all.sh:148) executes `bash "$suite"` one suite at a time: no `&`, no `wait`,
no `xargs -P`, no job control anywhere in the file. The blocker to changing that is concrete: a
SINGLE shared `SUITE_OUT="$(mktemp)"` (line 145) is written by every suite (line 157) and
truncated between them (line 169). Per-suite output files are the prerequisite for any
parallelism. The runner also accepts only `--quiet` -- there is no `--jobs`, no `--filter`, no
`--changed`, so a developer touching one script cannot run only its suite and must pay the full
9.3 minutes.

ORDERING IS LOAD-BEARING -- DO NOT PARALLELIZE FIRST. Parallelism cannot reduce total wall time
below the longest single suite. While the long pole is 329 s, even infinite parallelism leaves
run-all.sh at 329 s -- a 41% improvement at best. Fix the long pole FIRST (Finding 2): that takes
the serial total to ~228 s, after which parallelism has a ~40 s floor (the next-longest suite)
and becomes worth doing. Sequence: gate selector -> re-measure -> per-suite output files ->
parallelism -> selective execution.

PARALLELISM MUST SHIP OPT-IN, SERIAL BY DEFAULT. The shell-test-isolation task in this backlog
already documents, with live evidence, that some suites pass in isolation and fail in a full run
because their assertions are coupled to ambient host state on the TIMING axis (a wall-clock
window that holds on an idle machine and breaks under load). Parallel execution increases
exactly that contention. That task DEPENDS on this one, so this task lands first -- therefore
ship `--jobs` defaulting to 1 (serial, today's behavior byte for byte) and leave flipping the
default to the isolation work. Do NOT make parallel the default here; doing so converts a slow
but honest gate into a fast flaky one, which the isolation task's own description argues is
strictly worse.

WHY THIS MATTERS BEYOND DEVELOPER PATIENCE. run-all.sh is verify-deploy.sh's gate 8. A slow or
flaky gate 8 slows verify-deploy, which gates deploy-headless.sh, which makes the orchestrator's
inter-cycle redeploy checkpoint defer an entire batch. Test-harness latency is on the critical
path for throughput, not merely on developer comfort.

METHOD WARNING -- THREE PLAUSIBLE-LOOKING LEADS THAT ARE FALSE. All three were checked and
refuted on 2026-09-22. Do not re-derive them, and do not let the probe in Phase 1 emit them:
  1. "~225 s of hard-coded sleeps across 32 call sites." FALSE. Those are fixture STRING LITERALS
     -- test-claude-refresh-matcher.sh synthesizes fake `ps` output containing `sleep 10`, and
     test-detect-noop-bash.sh passes "sleep 30" as a CLASSIFIER INPUT. The suite with the largest
     apparent sleep total (158 s) measures 6.9 s. A static `grep sleep` sum is meaningless here.
  2. "43 verify-deploy invocations across the suites." FALSE. That counted every textual mention
     including comments. Real executable invocations are single digits, roughly half already pass
     --skip-slow, and all target fixtures rather than the real source store -- so gate 8 never
     re-enters and there is no recursion bug to find.
  3. "Gate 8 is 43-83% of verify-deploy's runtime." FALSE. That comment in
     test-claude-refresh-matcher.sh states the FAILURE RATE of a flaky reap mechanism, not a
     runtime share.
  The general lesson, which Phase 1's probe must honor: counting occurrences of a token in shell
  source over-reports, because comments, heredocs and fixture literals are indistinguishable from
  code to grep. Where the probe reports a cost, it must measure it.

ACCEPTANCE ADDITIONS FOR THIS EXAMPLE.
  a. run-all.sh total wall time is re-measured before and after, with the per-suite breakdown
     recorded, and the improvement stated as a measured ratio rather than an estimate.
  b. Suite PASS/FAIL outcomes are identical before and after for all 92 suites -- a speedup that
     changes an outcome is a regression, not an optimization.
  c. `--jobs` (if added) defaults to 1 and serial output is byte-identical to today's.
  d. The long-pole suite remains non-vacuous: it must still fail when the eager budget is
     breached and pass when it is not. Demonstrate both directions explicitly.
  e. run-all.sh's exit code still propagates failure (it correctly exits 1 today; a parallel
     rewrite must not lose that through a pipeline or a subshell).

=== EVIDENCE ADDENDUM (2026-09-22, measured live) ===

RUN-ALL.SH WALL-CLOCK, MEASURED: ~40 minutes for a single full `run-all.sh --quiet` over the
source-store copy, with concurrent agent activity on the machine. Observed during an
/orchestrate implement dispatch, where the dispatched agent backgrounded the run and then
stopped and resumed THREE times waiting on it (cumulative agent durations 384s / 1077s / 2287s
across the stop/resume rounds) before the suite exited.

WHY THIS MATTERS BEYOND COST. The runtime is not merely expensive, it is behaviour-changing:
  - It pushed the dispatched agent into a repeated stop/park/resume cycle, which is a
    reliability problem for autonomous orchestration, not just a slow gate.
  - The load the long run generates is itself implicated in ambient-state test failures --
    `test-lake-build-guard.sh` failed inside this run and then passed 47/47 in isolation
    immediately afterwards (recorded in the shell-test-isolation task's own evidence addendum).
    So run-all.sh's runtime and its concurrency are jointly producing false reds.

SUGGESTED MEASUREMENT FOR PHASE 1'S PROBE: capture per-suite wall-clock in the inventory probe
output, not just line/byte/caller counts. The ranking for "what to speed up" needs per-suite
timing, and that data is currently collected nowhere.

=== PATH REVIEW 2026-09-28 (fifth pass): the run-all.sh worked example is CLOSED -- do not redo it ===
The test-suite runtime task completed on 2026-09-26 and delivered exactly the sequence the worked example above prescribes: verify-deploy.sh gained --only-gate; test-verify-deploy-context-budget.sh collapsed to one full battery (391 s -> ~103 s); run-all.sh gained opt-in --jobs N|auto (serial default, JOBS_CAP 4, longest-first, deterministic output, nested-invocation guard) and a durable per-suite timing baseline in that task's report. run-all.sh, test-verify-deploy-context-budget.sh and verify-deploy.sh were removed from this task's file_scope accordingly (verify-deploy.sh now belongs to the Gate 8 parallelism task).
WHAT REMAINS: Phase 1 (the standing script-inventory probe, which must reuse that task's timing baseline as its per-suite wall-clock input rather than re-measuring) and Phase 2 (the behaviour-preserving decomposition of orchestrate-cycle-plan.sh into lib/). Ordered behind the isolation-posture decision, the deploy-pending/identical-dispatch fix and the checkpoint-cost task, so the file is quiet when it is decomposed. Re-measure the 2,279-line figure first.

---

### 244. check-task-references.sh: scan repo-appropriate roots instead of a hard-coded nvim-repo TREE_ROOTS list
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

EVIDENCE SOURCE. Observed live on 2026-09-21 in ~/Projects/Logos/Verification during `/orchestrate 66,70,72,76,77,81,84,85` (session sess_1790009936_0a5e95).

DEFECT. scripts/check-task-references.sh only scans a hard-coded TREE_ROOTS=(agent-system/extensions .opencode lua .memory) (~line 102) -- the nvim repo's own layout. In a consumer repo (e.g. Verification: docs/, README.md, framed_channel/, nix/, .github/) the rule no-task-references-in-deliverables.md applies repo-wide except specs/**, but the lint scans nothing relevant; an implementer had to hand-run the pattern library against docs/ manually. Additionally, a PATH_SCOPE argument outside TREE_ROOTS exits 2 instead of scanning it.

DELIVERABLE. Make the scanned roots repo-appropriate: e.g. default to the whole repository minus specs/, .git, .claude and generated/vendored dirs (respecting .gitignore via `git ls-files` is one option), or a per-repo config file, or detection of the nvim source-store layout -- decide in research. Requirements: (1) the nvim repo's scan result is equivalent to today's (same files flagged); (2) a consumer repo like Verification gets its docs/, README.md and source dirs scanned; (3) an explicit PATH_SCOPE anywhere in the repo (outside the exempt trees) is scanned rather than exiting 2; (4) exemption logic stays sourced from scripts/lib/task-reference-patterns.sh; (5) update context/standards/task-reference-exemptions.md if the enforcement narrative describes the roots; (6) add or extend a test covering a consumer-repo-shaped fixture.

DELIVERABLE RULE: no task numbers in deliverables outside specs/** (no-task-references-in-deliverables.md).

=== CORROBORATED 2026-09-25 from a SECOND consumer repo, ModelChecker (session sess_1790352661_77259f) ===
The first evidence source was Verification (2026-09-21); this is an independent reproduction.
In ~/Projects/Logos/ModelChecker the primary source tree is code/, which TREE_ROOTS matches
nowhere, so the lint scans nothing that repo actually ships. Measured: a manual grep of ONE
subtheory found ~35 violations, ~20 of them in a single operators.py, plus a literal
specs/{NNN}_{slug}/reports/ path citation -- every one of them invisible to the lint today.
Two consumers failing the same way confirms the hard-coded list encodes the nvim repo's own
layout and generalizes to nothing.

TWO ADDITIONAL REQUIREMENTS beyond the original (1)-(6):

(7) DECIDE BETWEEN COVERAGE AND HONEST SCOPE -- do not assume option (a). The original
    deliverable presumes the roots get fixed. Research must also weigh the alternative: an
    explicit, documented carve-out in rules/no-task-references-in-deliverables.md and
    context/standards/task-reference-exemptions.md declaring consumer source trees out of
    scope. Option (b) is a legitimate outcome if (a) proves unworkable. The defect being fixed
    is that the rule's text asserts repo-wide reach ("the entire repository EXCEPT specs/**,
    commit messages, and PR/branch metadata") that the lint does not deliver. Either close the
    gap or stop claiming it -- but the claim must not survive unbacked. Whichever is chosen,
    the rule file itself is a deliverable, which is why it is now in file_scope.

(8) THE TWO PATTERN-LIBRARY CONSUMERS MUST NOT DRIFT. scripts/lib/task-reference-patterns.sh is
    shared by check-task-references.sh (batch lint) and hooks/validate-no-task-references.sh
    (blocking write-time gate). Original requirement (4) keeps exemption logic sourced from the
    shared lib but never names the hook as the second consumer. Any change to scanned scope or
    exemption semantics must land identically in both: a repo-wide lint paired with a gate that
    admits or blocks a different set is a new defect, not a fix. The hook is now in file_scope
    for this reason, and a test should cover lint/hook agreement on a consumer-repo-shaped
    fixture.


=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 256 (validate_wiring_skip_missing_tree_root); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

=== PREMISE RESOLVED 2026-09-25 -- SCOPE NARROWED, DO NOT RE-BROADEN ===
This task originally proposed auditing ~32 .opencode references across core scripts on the
premise that "OpenCode is retired". The user has now settled that premise directly: .opencode/
in the nvim agent-system repo STAYS FROZEN, exactly as the standing frozen-mirror policy
records -- not maintained, not generated, not deleted. The blanket reference audit is therefore
CANCELLED: those references are correct and must stay. Removing the .opencode arm from
deploy-root-guard.sh or validate-state.sh in particular would narrow a deliberately general
"this must be a deploy tree, whichever kind" guard into a single-system one -- a regression
dressed as a cleanup, and the specific outcome this note exists to prevent.

What separately DID happen: the ModelChecker consumer repo deleted its own stale .opencode/
DEPLOY (351 files, 2.9M, context files already drifted) plus its root opencode.json. That is a
consumer-local deploy deletion, orthogonal to the frozen mirror, and it is already done.

=== THE ONE REAL REMAINING DEFECT ===
That deletion exposed a genuine, narrow bug, which is now this task entire:

scripts/validate-wiring.sh does not gracefully skip a MISSING .opencode tree. Its `all` arm
unconditionally calls validate_core_system/validate_extensions_loaded against
"$PROJECT_ROOT/.opencode" and reports hard [FAIL] rows ("index.json not found", "Agent
missing: ...", "Rule missing: ...") when that directory simply is not deployed in this
consumer. Measured in ModelChecker on 2026-09-25, immediately after the deletion:
`validate-wiring.sh all` -> exit 1, 15 failures, every one attributable to the absent
.opencode arm; `validate-wiring.sh --claude` -> exit 0, 20 passed, 0 failed.

A consumer repo that never deploys OpenCode is a NORMAL, supported configuration, not an
error. The script should treat an absent tree root the way check-task-references.sh already
does -- skip it with an informational line (its existing "[SKIP] lua does not exist under
..." output is the exact precedent to mirror) -- rather than emitting failures that mask the
real .claude-side result. Note this masking was severe before the deletion: ModelChecker
`validate-wiring.sh all` reported 89 failures, ALL from the stale .opencode arm, while the
.claude side was in fact completely clean.

Scope: (1) make validate-wiring.sh skip a non-existent tree root for BOTH the .claude and
.opencode arms, emitting a SKIP line rather than failures, so the exit status reflects only
trees actually present; (2) confirm the same missing-tree-root assumption does not bite the
other scripts that reference .opencode -- deploy-root-guard.sh and validate-state.sh were
checked on 2026-09-25 and are SAFE (both match the running script own path against
*/.claude/scripts/ or */.opencode/scripts/, so an absent sibling tree is irrelevant), and
hooks/validate-handoff-location.sh is SAFE (its OC_ regex concerns specs/ path shapes, not the
tree); re-verify rather than trusting this note; (3) add a regression test covering a
consumer layout with .claude present and .opencode absent.

Explicitly OUT of scope now: removing any .opencode reference, editing the frozen-mirror
policy, and check-task-references.sh TREE_ROOTS (owned wholesale by the dependency task).

---

### 241. Reconcile MCP registration surfaces: redundant playwright grants, dead manifest mcp_servers fields, ownership doc and nix README
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

**Description**: Reconcile the MCP registration/permission documentation and dead declaration surfaces in the agent-system source store. Four items, one coherent change: three follow-ups that agent-system/extensions/core/context/patterns/mcp-server-ownership.md records but never corrects, plus a fourth stale surface found during task research.

SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. Do NOT edit the ~/.dotfiles repository; its own separate task owns the machine-scope grants, the home-manager activation block, and the nixos registration. Do NOT touch per-project lean-lsp registrations.

ITEM 1 -- REMOVE THE REDUNDANT PLAYWRIGHT ENUMERATIONS.
agent-system/extensions/web/settings-fragment.json and agent-system/extensions/present/settings-fragment.json each carry an identical 9-entry safe-tier playwright grant list (browser_navigate, browser_snapshot, browser_take_screenshot, browser_console_messages, browser_network_requests, browser_click, browser_type, browser_find, browser_wait_for; verified byte-identical between the two). The playwright MCP server is registered at USER scope by a home-manager activation block in the separate ~/.dotfiles repository, so per this system's own governing rule -- grant permissions at the same scope where the server is registered -- the grant belongs at user scope only. Machine-scope grants for exactly these nine tools are already written into ~/.dotfiles/config/claude/settings.json and are live. Removing the two extension copies leaves one list instead of three, eliminating the drift hazard the ownership doc's "Wildcard over enumeration" section warns about: a newly added safe tool currently requires three synchronized edits, and a missed one silently reintroduces prompting with no error.

HARD PRECONDITION, RE-VERIFY AT IMPLEMENTATION TIME (not merely at task creation): the user-scope grants must be LIVE, not just committed to the dotfiles source. Run:
  jq '[.permissions.allow[]? | select(test("playwright"))] | length' ~/.claude/settings.json
The result MUST be 9 before performing any item 1 deletion. At task-creation time this returned 9 and ~/.claude.json showed playwright registered at user scope, but a home-manager rebuild between creation and implementation could regress it. If the count is not 9, DO NOT perform item 1: report it as a blocked item, leave both fragments untouched, and complete items 2-4, which have no such dependency. Removing the extension grants while user scope is empty would make every playwright call prompt in web/present projects and DENY outright in headless runs.

NO WILDCARD REPLACEMENT (binding): do NOT replace the removed enumerations with an mcp__playwright__* wildcard anywhere. The enumeration exists specifically to withhold browser_evaluate, browser_run_code_unsafe and browser_file_upload, which execute arbitrary code or read arbitrary local files onto a page and MUST keep prompting. This is the documented safe/unsafe carve-out to the wildcard preference, not an oversight to simplify.

ITEM 2 -- DELETE THE FIVE DEAD manifest.json mcp_servers FIELDS.
agent-system/extensions/{filetypes,founder,lean,memory,nix}/manifest.json each carry an mcp_servers field. Nothing in the loader reads it to write ~/.claude.json, so it registers nothing; it is inert dead weight that reads as working configuration to a future maintainer. Verified present in exactly these five and no others. This is a pure removal: no grant changes accompany it.

Task research already confirmed there is NO dangling reader: a sweep of every .sh/.py/.lua/.json/.md in the source store found no loader, lint, or verify-deploy script reading the field. The only references are documentation that already describes it as inert (core/docs/architecture/extension-system.md lines 227 and 498, core/docs/guides/creating-extensions.md lines 103 and 120, core/docs/guides/adding-domains.md line 115, core/templates/extension-readme-template.md line 68); those stay correct after deletion and need no follow-on edits. Re-confirm this sweep before deleting, and if a reader has appeared since, update it in the same task rather than leaving it dangling.

Two specifics worth preserving: nix's block declares the server under the trap name mcp-nixos, which would produce mcp__mcp-nixos__* tools and break the existing mcp__nixos__nix / mcp__nixos__nix_versions grants and every doc cross-reference -- deleting it removes a live footgun, and the correct registration under the name nixos now lives in the dotfiles activation block. lean's block is likewise inert: lean-lsp is registered per-project in LOCAL scope by a SessionStart hook, not by any manifest.

OUT OF SCOPE, DO NOT CONFLATE: agent-system/extensions/memory/settings-fragment.json's mcpServers block is a DIFFERENT file and a DIFFERENT mechanism from the manifest.json mcp_servers fields. It is owned by existing task 30 (register obsidian memory mcp server). Leave it exactly as it is -- it is the only remaining mcpServers block anywhere in the source store. Item 2 removes memory's manifest.json mcp_servers field only.

COMPLEMENTARY, NOT CONFLICTING: existing task 29 (generate mcp json from extension manifests) introduces a NEW merge_targets.mcp key with a per-extension source file, and explicitly routes away from both dead surfaces. Deleting mcp_servers now does not conflict with it and creates no dependency in either direction. Recorded here so a future reader does not re-litigate it.

ITEM 3 -- CORRECT THE OWNERSHIP DOC, WHICH IS NOW STALE.
agent-system/extensions/core/context/patterns/mcp-server-ownership.md is the SOURCE. (~/.dotfiles/.claude/context/patterns/mcp-server-ownership.md is a deploy copy that regenerates and must NOT be hand-edited.) Four passages:

(a) Its "Grant permissions at the same scope where the server is registered" section calls playwright "the live counter-example -- registered in user scope, but its 9-tool safe-tier enumeration appears only inside the web and present extensions' settings-fragment.json files, with zero mcp__playwright__* entries in ~/.claude/settings.json itself", and says fixing the asymmetry is "a separate follow-up, not performed here -- it is recorded, not corrected, by this document". Once the dotfiles grants are live and item 1 lands, this is resolved. Rewrite to describe the corrected end state, KEEPING playwright as a worked example of correct user-scope grant placement rather than deleting the passage -- the reasoning is still instructive. If item 1 was blocked by its precondition, leave passage (a) unchanged and say so explicitly in the summary.

(b) Its "Known gaps" section says five extensions "additionally carry the identical dead declaration in their manifest.json mcp_servers field" and calls correcting it "a recorded follow-up, not performed by this document's own edits". Item 2 performs it; update accordingly.

(c) Its "Wildcard over enumeration" section describes the lean-lsp triple duplication (a wildcard in core's root-files/settings.json, a 21-entry enumeration in lean's settings-fragment.json, and a dead mcpServers block) and states "The correct end state is one wildcard in lean's own fragment and nothing in core." That end state has ALREADY been reached -- verified live during task research: core's root-files/settings.json has 0 lean entries, lean's settings-fragment.json has exactly one (the mcp__lean-lsp__* wildcard), and the dead mcpServers block is gone. The doc still describes it in the present tense as an outstanding defect. Rewrite to record it as a completed worked example rather than a pending one.

(d) Its "Known gaps" section lists memory (obsidian-memory) carrying a dead mcpServers block in its settings-fragment.json as "a genuine, still-open gap". That block IS still present and existing task 30 covers registering that server properly, so this entry STAYS OPEN. Do NOT mark it resolved.

ITEM 4 -- CORRECT THE NIX README REGISTRATION PASSAGE.
agent-system/extensions/nix/README.md lines 26-34 assert that mcp-nixos is "not currently registered by anything in this repository", that "no such mechanism exists yet for this server", and that "Registering this server in user scope is a pending follow-up". All three are now false: ~/.claude.json registers nixos at user scope via the home-manager activation block in ~/.dotfiles -- precisely the mechanism the passage names as hypothetical. The same passage also refers to "The mcpServers block that may appear in this extension's settings-fragment.json"; nix's settings-fragment.json contains no such block (memory's is the only one left in the source store), so that sentence is a dangling reference and should simply be dropped rather than rewritten. Net effect today: a reader of this README is told to expect the WebSearch/CLI degradation path as the normal case when the MCP path is in fact live.

Rewrite the passage to record user-scope registration under the name nixos, and to reinforce why the trap name mcp-nixos is being deleted from the manifest in item 2.

DO NOT BLANKET-RENAME (binding): only the registration passage at lines 26-34 changes. The other six occurrences of mcp-nixos in this README (lines 3, 18, 23, 92, 101, 195) are the upstream project/package name -- the uvx mcp-nixos invocation, the tools column, and the GitHub project URL -- and are all correct as-is. Only the SERVER REGISTRATION NAME is nixos. Conflating the two would reintroduce the same class of confusion item 2's deletion removes. The README's conditional "when MCP is unavailable" degradation framing also stays as-is.

DO NOT EDIT: agent-system/extensions/nix/context/project/nix/tools/mcp-nixos-integration.md was read in full during task research and needs NO correction. It is written conditionally throughout ("When configured, it lets agents verify...", "Agents gracefully degrade to WebSearch and CLI commands when MCP is unavailable"), and already uses the correct tool names mcp__nixos__nix and mcp__nixos__nix_versions, never the trap name. It is properly future-proofed and now simply describes the live state.

FILE SCOPE (nine files, all under agent-system/extensions/):
- web/settings-fragment.json, present/settings-fragment.json  (item 1)
- filetypes/manifest.json, founder/manifest.json, lean/manifest.json, memory/manifest.json, nix/manifest.json  (item 2)
- core/context/patterns/mcp-server-ownership.md  (item 3)
- nix/README.md  (item 4)

VERIFICATION: jq empty on all seven edited JSON files; confirm zero mcp__playwright__* entries remain in the web and present fragments and that no wildcard was introduced in their place; confirm zero mcp_servers fields remain in any agent-system/extensions/*/manifest.json; confirm memory/settings-fragment.json's mcpServers block is byte-identical to its pre-change state; confirm ownership doc Known-gap (d) still reads as open; doc-lint passes for core, nix, web and present; run bash .claude/scripts/deploy-headless.sh and confirm it lands green.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 223. Record the Comparator-on-NixOS fixes in the lean extension
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: None
- **Research**: [223_record_comparator_nixos_fixes_in_lean_extension/reports/01_comparator-nixos-fixes.md]

**Description**: Record the Comparator-on-NixOS fixes in the lean extension source store (~/.config/nvim/agent-system/extensions/lean, not .claude/): update context/project/lean4/domain/comparator-integration.md, context/project/lean4/tools/comparator-guide.md and scripts/lean-comparator-run.sh (with scripts/tests/test-lean-comparator-run.sh) so a Comparator run works on this host. Fixes found while certifying framed_channel: (1) put the pinned toolchain bin/ before the elan shim on PATH, since landrun cannot execute the shim (the `lake: Permission denied` failure the design record notes but never explains); (2) invoke as `lake env comparator config.json`; (3) point TMPDIR inside the writable .lake directory because bv_decide writes SAT files to /tmp, which the sandbox makes read-only; (4) grant --rox on git's nix store libraries, otherwise Lake decides the package URL changed and deletes .lake/packages/<dep>. Also document: lean4export panics when permitted_axioms names an axiom absent from the Challenge (handle a flagged bv_decide row by permitting only the trusted axioms and requiring the exact Illegal axiom rejection, which still proves the statement matches); `lake update` in a tool-pinning package silently rewrites lean-toolchain unless --keep-toolchain; batched Lean4Lean runs can exceed 19 GB and trigger earlyoom, so run one module per process; an outer landrun around lake env and Comparator itself. Reference implementation: framed_channel/recheck-comparator.sh, recheck-revs.sh and comparator-configs.sh in this repository, and the task 32 report and summary. Redeploy .claude/ afterwards.

ORIGIN: moved from the ~/Projects/Logos/Verification task list, where it was researched; the research report was copied here as reports/01_comparator-nixos-fixes.md. The reference implementation it transcribes lives in ~/Projects/Logos/Verification/framed_channel/ (recheck-comparator.sh, recheck-revs.sh, comparator-configs.sh). Task numbers inside the report refer to that repository's task list.

=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 177 (lean4_dependency_tracing_recipe); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Add a dependency-tracing recipe to the lean4 extension context: how to mechanically answer "does X depend on Y?" in a Lean 4 environment, and why `#print axioms` cannot answer it.

WHY THIS EXISTS. A trace task in ~/Projects/BimodalLogic had to answer whether a decision procedure depended on a set of theorems whose hypotheses had been refuted. The task's own description demanded a MECHANICAL trace ("a prose argument that it probably doesn't is not the deliverable"), and no recipe existed -- the probes were invented from scratch. They worked, are re-runnable, and generalize. The finished probes and their verbatim output live at `~/Projects/BimodalLogic/specs/549_trace_decide_dependency_on_vacuous_run_theorems/probes/` (`DepTrace.lean`, `DepTrace2.lean`, `RevDep.lean`, `Widen.lean`, `Ax.lean`, `Exists.lean`, plus `probe-evidence.md`). Harvest them from there; do not re-derive.

THE LOAD-BEARING CAVEAT, and the reason this is worth writing down at all. `#print axioms` is NOT a dependency tracer. In the observed case the decision procedure, its soundness theorem, AND the vacuous theorem under suspicion all reported the same `[propext, Classical.choice, Quot.sound]`. An axiom check answers "is this sound?", never "what does this rest on?" -- yet it is the first probe most people reach for, and it would have returned a confidently useless answer. State this explicitly and early in the recipe.

FOUR PROBE SHAPES TO DOCUMENT AS REUSABLE TEMPLATES:
1. Forward transitive closure over the environment -- `Expr.getUsedConstants` over both type and value, iterated to a fixed point from a named entry point, then intersected with a suspect set. This is the primary tool.
2. The module-index variant -- resolve which module each reached constant came from, and count the hits attributable to a target module. Answers "how much of module M does X touch?" in one number.
3. Whole-environment reverse-dependency scan -- iterate every declaration in the environment and report those whose closure contains a suspect. Answers "what would break if I deleted this?", which is the question a retirement decision actually needs.
4. Import-closure check -- whether the target's module is even reachable via transitive imports. Distinguishes "unused" from "unavailable", a meaningfully stronger result.

ALSO WORTH RECORDING: run probes with `lake env lean` against existing oleans rather than a full `lake build` -- the observed trace needed no rebuild at all. And note the failure mode that bit the source task: line numbers cited in a research report go stale quickly in a large file, so probes should resolve declarations by name.

SCOPE. Create `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md` in the SOURCE STORE (never `.claude/**`, which is a regenerated deploy artifact -- see rules/source-store-deploy-boundary.md). Wire it into the lean4 context index the way sibling pattern files are wired; follow the existing single-statement-plus-pointer convention rather than restating the model at the pointer site.

PRIORITY: low, and genuinely optional. This is a recipe harvested from one successful use, not a defect fix -- nothing is broken without it. Its value is that the next such trace does not start from zero, and that the `#print axioms` trap is documented before someone falls into it.

ACCEPTANCE. The four probe shapes are reproduced as templates a reader can adapt without access to the originating repository. The `#print axioms` caveat is stated explicitly, with the concrete observation that three declarations at different dependency depths all reported identical axioms.

---

### 217. Cost-aware idle Lean tree reclamation in /refresh: PSS accounting, CPU-delta idleness, notify-before-kill
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 174

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

DEFECT. run_claude_pass and run_lean_pass in scripts/claude-refresh.sh both sum per-process RSS + VmSwap (get_vmswap_kb). Lean workers share mmapped Mathlib .olean files (5.6 GB lib), so shared pages are counted once per worker, and file-backed pages are evictable page cache anyway.

WORK.
(a) Add one shared memory helper used by BOTH passes: read $PROC_ROOT/PID/smaps_rollup; reclaimable = Pss_Anon + SwapPss. Report Pss_File separately as "shared cache (not counted)". When smaps_rollup is unreadable, fall back to RSS + VmSwap and label the figure approximate. Read only for candidates (not every process).
(b) Update both passes' report format to show reclaimable (and approximate marker) plus shared cache.
(c) Correct the in-script pcpu comment: procps-ng ps pcpu is lifetime cputime/elapsed, NOT a decaying average. (The idle gate itself is replaced by a follow-on task; only fix the comment here.)
(d) Tests in scripts/tests/test-claude-refresh-matcher.sh: fixture-based /proc via PROC_ROOT covering smaps_rollup parsing (Pss_Anon, SwapPss, Pss_File), shared-page de-duplication across multiple workers, and the unreadable fallback label.

MUST NOT. Change UID/system-slice safety predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Fixture of N workers sharing a large Pss_File reports reclaimable = sum(Pss_Anon+SwapPss) and shared cache separately; fallback path labeled approximate; test suite passes; shellcheck clean; redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-17 from former task 218 (CPU-delta idleness and the memory-floor cost gate); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

DEFECT. lean_row_is_idle uses ps etimes (process AGE) plus ps pcpu, which in procps-ng is lifetime cputime/elapsed. Any long-lived tree reads <1%, so an actively used 5h-old tree counts as "idle".

WORK (consumes the reclaimable figure from the PSS memory helper, hence the dependency).
(a) CPU-delta idle tracking: per-tree state in ~/.local/state/claude-refresh/lean-trees.json keyed by root pid + process starttime (/proc/PID/stat field 22). Each run, store the summed utime+stime of all tree members; if it increased since the last run, reset last_active; idle_for = now - last_active. Replace the pcpu/etimes gate entirely. Hourly run granularity is acceptable. Prune entries for trees that no longer exist.
(b) State file writes atomic (tmp + mv). Tolerate a missing or corrupt file: treat as first sighting, NEVER as idle.
(c) Cost gate: a tree is prompt-eligible only when idle_for >= LEAN_LSP_IDLE_THRESHOLD_MIN (default 240) AND reclaimable >= LEAN_LSP_MEM_FLOOR_MB (default 1024). Otherwise report it as "idle, cheap, kept" (or active). Interactive /refresh uses this same gate and the same numbers for its existing AskUserQuestion prompt.
(d) Tests (fixture /proc via PROC_ROOT, fixture state dir): CPU-delta idle state machine (first sighting not idle; unchanged cputime accrues idle_for; increased cputime resets), pid reuse with different starttime treated as a new tree, corrupt/missing state file, floor gate both sides of the threshold.
(e) Update Pass Inventory rows in commands/refresh.md and skills/skill-refresh/SKILL.md for the new idle definition and cost gate.

MUST NOT. Kill anything silently. Change UID/system-slice predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Active 5h-old tree whose cputime grows is never idle; a tree idle >=240 min with <1 GB reclaimable is reported kept; tests pass; shellcheck clean; redeploy and confirm.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== ABSORBED 2026-09-17 from former task 219 (notify-before-kill prompt path with snooze); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy artifact).

OBSERVED LIVE (2026-09-15): a Lean LSP tree was reported as "15.1 GB" reclaimable while earlyoom showed 14-16.6 GB available throughout; real reclaim was ~2.3 GB swap plus a little anon. User policy: idle trees that cost nothing may stay; trees that cost memory get a prompt (never a silent kill) after being idle a while. Memory floor 1 GB approved.

WORK (builds on the cost gate and per-tree state file).
(a) Prompt path: when the headless hourly run (--dry-run) finds an eligible tree that is not snoozed or already prompted, launch a detached `systemd-run --user --unit=claude-refresh-prompt-<rootpid>-<starttime>` (the unit name must NOT match claude-*.scope, which the user's claude-session-reaper stops) running `notify-send -a claude-refresh -u critical -t 0 -A default=Kill --wait "Idle Lean tree (<project>)" "idle Xh, N GB reclaimable -- click to kill, dismiss to keep 4h"` (or equivalent that blocks on the chosen action). Project = lake serve cwd (/proc/PID/cwd).
    DESIGN REFINEMENT (notification daemon): the user runs mako with no dmenu-style action launcher, so named notify-send actions cannot be selected by clicking. Therefore use a single `-A default=Kill` action (mako left-click invokes the default action) and treat dismiss / right-click / expiry / no action returned as "Keep" (snooze). Pass `-t 0` so the notification does not auto-expire. The complementary mako rule ([app-name=claude-refresh] default-timeout=0) and the NixOS home-manager install of the timer/service with a correct PATH are handled by a separate ~/.dotfiles task (external, not in this repo).
(b) On the default action ("Kill", i.e. left-click): run `claude-refresh.sh --lean-tree <pid>:<starttime> --force`. The new --lean-tree mode re-verifies starttime identity, still idle, and still over the floor before the existing ordered workers -> server -> root termination; if anything changed, skip and log.
(c) On dismiss / right-click / expiry / any non-default outcome (treated as "Keep"): record snooze_until = now + LEAN_LSP_SNOOZE_MIN (default 240) in the state file. Dedupe so a tree is prompted at most once per snooze window (record prompted state before launching).
(d) Degrade gracefully when notify-send, systemd-run, or a DBus session bus is absent: log only, never kill.
(e) The hourly unit (systemd/claude-refresh.service) ExecStart stays --dry-run; prompting happens only in the separate transient unit. Keep generic units portable, but document that Environment=PATH=/usr/bin:/bin is broken on NixOS and that NixOS installs these units via home-manager (the dotfiles change is a separate task).
(f) Interactive /refresh keeps its AskUserQuestion prompt with the shared gate and numbers.
(g) Tests (fixture /proc via PROC_ROOT, stubbed notify-send/systemd-run on PATH): stubbed notify-send printing "default" -> kill path, printing nothing/other -> snooze path, starttime re-verification refusal (pid reused), still-idle/still-over-floor re-check refusal, snooze dedupe (no second prompt inside window, prompt again after expiry), missing notify-send/systemd-run/DBus degrades to log-only, unit name never matches claude-*.scope.
(h) Docs: commands/refresh.md and skills/skill-refresh/SKILL.md (Pass Inventory rows, --lean-tree flag, env vars LEAN_LSP_IDLE_THRESHOLD_MIN / LEAN_LSP_MEM_FLOOR_MB / LEAN_LSP_SNOOZE_MIN, prompt flow, NixOS note).

MUST NOT. Kill without explicit user action. Change UID/system-slice predicates or termination ordering. Edit .claude/**.

ACCEPTANCE. Tests pass; shellcheck clean; redeploy and confirm; a manual end-to-end check shows one notification per snooze window and a left-click Kill that refuses when the tree became active, and a dismiss that records a 4h snooze.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 207. Fix zotero-generate-export.sh Path 1: accumulator truncation and shrink guard, then the pagination shortfall or path-preference order
- **Effort**: 2-3 hours
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Fix the silent-truncation data-loss defect in zotero-generate-export.sh's Path 1 (Zotero 7 local API pull), and add a shrink guard so a truncated pull can never again overwrite a complete export.

=== VERIFIED DEFECT (diagnosed empirically with an instrumented trace, not hypothesized) ===

fetch_path1()'s accumulator passes the entire growing JSON array as a single jq argv string:

    all_items="$(jq -n --argjson a "$all_items" --argjson b "$filtered" '$a + $b' 2>/dev/null || echo "$all_items")"

At ~200 accumulated items the string reaches 152KB and jq dies with "Argument list too long". The cause is Linux MAX_ARG_STRLEN: a SINGLE argument is capped at 128KiB (32 x 4KiB pages), independent of ARG_MAX (2MB on this machine). The trailing `2>/dev/null || echo "$all_items"` then swallows the error and yields the prior value, so the loop keeps fetching pages 3..41 and silently discards every one, then exits 0 printing a success message ("wrote 200 entries").

Instrumented trace output:

    start=0   page_len=100 filtered_len=100   accum: 0 -> 100
    start=100 page_len=100 filtered_len=100   accum: 100 -> 200
    start=200 page_len=100 filtered_len=100   accum: 200 -> 200   !!! ACCUMULATION FAILED
    start=300 page_len=100 filtered_len=100   accum: 200 -> 200   !!! ACCUMULATION FAILED

Deterministic; reproduced twice. Affects any library past ~200 items -- not user- or data-specific.

REAL-WORLD IMPACT (already occurred, actual data loss): a regeneration run with Zotero open overwrote a good 4046-item export with a 200-item one and reported success. Recovered only because the pre-state item count had been captured beforehand; the export is not git-tracked and had no backup. Which path runs decides the outcome: Zotero closed -> Path 3 sqlite reconstruction (correct); Zotero open -> Path 1 (truncates to 200). The failure is invisible in the common case and catastrophic in the other.

=== WORK ITEMS ===

1. TEMP-FILE ACCUMULATOR. Write each fetched page to $tmpdir/page_N.json and combine once at the end with `jq -s 'add'`, so neither a page nor the accumulator ever transits argv. Retain the existing attachment/note CSL-type filter (currently applied per-page at the `filtered` step). Clean up $tmpdir on all exit paths.

2. MAKE FAILURE LOUD. A failed fetch OR a failed accumulation must abort with a non-zero return and NO write, rather than `break` into a partial that looks complete. Remove the error-swallowing `2>/dev/null || echo "$all_items"` fallback entirely -- it discards the only evidence anything went wrong, and today the break path is indistinguishable from normal pagination completion. Distinguish the three terminal conditions explicitly: genuine end-of-pagination (short page), max_pages guard hit, and error.

3. SHRINK GUARD. Refuse to overwrite an existing export with one containing dramatically fewer items unless explicitly forced. This alone would have prevented the data loss. `--force` is ALREADY TAKEN for the staleness/exists override (see the existing arg parser and exit code 3), so the guard needs its own opt-out flag or a distinct threshold semantic -- resolve which during planning and state the rationale.

   SHRINK-GUARD SPEC NOTE (verified live state, do not re-derive): the export currently on disk is
   /home/benjamin/Projects/Literature/zotero-library.json -- 2099350 bytes, 4049 items, source
   "sqlite-reconstruction" per its .zotero-library.meta.json stamp. $LITERATURE_DIR is
   /home/benjamin/Projects/Literature, which is OUTSIDE this repo; the export is never in the repo,
   and resolve_library_path() resolves it (tier 1 $ZOTERO_LIBRARY, then $LITERATURE_DIR). So the
   guard has a real, complete 4049-item file to protect on the very next run -- its primary and
   immediately-live scenario is exactly the one that already caused loss. Design a no-existing-export
   branch too (a legitimate case), but do NOT frame the guard as "first regeneration is unguarded by
   construction" -- that is only true of a genuinely absent export, which is not the state here.
   The prior truncated 200-item file is NOT on disk (it was overwritten by the successful Path 3
   regeneration); generate a truncated fixture rather than expecting to find one.

4. REGRESSION COVERAGE for the >128KiB accumulator boundary specifically, since that exact threshold is what made this invisible. Also cover the shrink guard blocking a catastrophic overwrite.

   SPECIFIED TEST MECHANISM (verified feasible offline -- do NOT conclude a live API is needed and
   skip the test): scripts/tests/curl-stub.sh is already a PATH-shadowing curl stub, and
   zotero-generate-export.sh calls bare `curl` (never an absolute path, never `command curl`), so a
   PATH-shadowing stub genuinely intercepts it. Extend the stub to dispatch on localhost:23119 and
   serve synthetic paged csljson bodies large enough to cross the 128KiB single-arg boundary. This
   needs no live API and no running Zotero.

5. DOC UPDATE for the changed contract, using these VERIFIED touchpoints.

   CORRECTED DOC TARGETS (verified by grep -- use these, not zotero-integration.md or
   tools/zotero-scripts.md, NEITHER of which mentions zotero-generate-export.sh at all: zero hits):
     context/project/literature/patterns/zotero-pdf-resolution.md
     context/project/literature/domain/literature-index.md
     context/project/literature/domain/corpus-directory-conventions.md
     commands/literature.md
   Deliberately avoiding zotero-integration.md also keeps this task at ZERO file overlap with the
   active zotero-metadata-resolution task (see SCOPE BOUNDARIES below).

=== ALREADY-VERIFIED NEGATIVE RESULT -- DO NOT RE-RUN THIS SWEEP ===

The sibling-script sweep for the same MAX_ARG_STRLEN bug is COMPLETE. Every script under the
literature extension was grepped for `--argjson` accumulation in a loop. RESULT: line 258 of
zotero-generate-export.sh is the ONLY genuine argv-accumulation instance in the extension. Every
other accumulator pipes the GROWING value through stdin and passes only the single new item via
argv, so MAX_ARG_STRLEN does not apply to any of them:
    cite-extract.sh:259, zotero-search.sh:422, literature-discover.sh:280,
    zotero-generate-export.sh:484
This negative result is recorded so a later reader does not re-fund the sweep as a research phase.

=== ADJACENT-CODE WARNING (do not misfire here) ===

Line 484 in synthesize_citekeys:

    result="$(echo "$result" | jq --argjson e "$entry" '. + [$e]' 2>/dev/null || echo "$result")"

This is NOT an instance of the same bug and is NOT a data-loss path. It pipes the growing
accumulator via stdin; only the single small `$entry` crosses argv. It runs on EVERY path including
Path 3, which is consistent with Path 3 having correctly produced the complete 4049-item export. It
is O(n^2) and it does swallow errors, but fixing it is OUT OF SCOPE for this task. Do not rewrite it
as though it shared the MAX_ARG_STRLEN cause -- that is exactly the adjacent-code misfire an
implementer makes when handed a MAX_ARG_STRLEN brief.

=== ACCEPTANCE CRITERIA ===

1. A >200-item library exports completely via Path 1, or fails loudly with a non-zero exit and NO write.
2. No silent-truncation path remains in fetch_path1 -- specifically, no error-swallowing
   `2>/dev/null ||` fallback that can return a short result as success.
3. The shrink guard blocks a catastrophic overwrite of the existing complete export and is exercised
   by a test; its opt-out mechanism is distinct from the existing --force staleness override, with a
   documented rationale for the chosen semantic.
4. Regression coverage exists for the >128KiB accumulator boundary specifically, implemented offline
   via the PATH-shadowing curl stub.
5. The changed contract is reflected in the four verified doc touchpoints.

=== SCOPE BOUNDARIES ===

No dependency on the active zotero-metadata-resolution task: its file_scope covers the WRITE /
metadata-resolution path (literature-ingest-online.sh, literature-discover.sh, zotero-item-creation.md,
zotero-integration.md, README.md) and excludes zotero-generate-export.sh entirely -- a different
concern from this export READ path. Keeping doc edits off zotero-integration.md leaves zero file
overlap, deliberately so this urgent data-loss fix is not serialized behind that task's larger scope.

Standing operational rule until this task lands: any regeneration must be done with Zotero CLOSED,
so Path 3 sqlite reconstruction runs instead of the truncating Path 1.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed
.claude/** tree -- it is a gitignored, disposable deploy artifact wiped by the next regeneration.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.


=== ABSORBED 2026-09-22 from former task 208 (Explain Path 1 pagination shortfall or revisit Zotero export path-preference order); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Explain the Path 1 pagination shortfall in zotero-generate-export.sh -- or, if Path 1 cannot reach parity with sqlite reconstruction, change the path-preference order with a documented rationale.

=== THE OPEN QUESTION (flagged as unknown, NOT guessed -- do not assume a cause) ===

Even with the accumulator truncation fixed, Path 1 pagination terminates at 481 items: at start=400
the API returns 81 items, which is < limit, so the loop treats it as end-of-pagination. But the same
local API's own Total-Results header reports 4042 for the same library. Those two numbers disagree
and the reason is UNKNOWN.

Candidate directions to investigate (none verified, none preferred):
  - csljson format filtering interacting with limit/start applied PRE-filter, so each page is
    silently thinned after the window is computed;
  - a local-API pagination quirk specific to the csljson format or to Zotero 7's local endpoint;
  - attachment/note items inflating Total-Results (the library has 1473 PDF attachments and 62 notes,
    while the bibliographic item count is 4049).

Verify empirically against the live API. Do NOT settle this from reasoning alone, and do not treat
any of the three candidates as the answer before measuring.

=== PRECONDITION: REQUIRES ZOTERO RUNNING ===

Path 1 exists only while Zotero is open -- the local API at localhost:23119 is served by the running
application. A probe during task creation returned HTTP 000 (unreachable) because Zotero was
deliberately quit so Path 3 could produce the complete export. WHOEVER PICKS THIS UP MUST OPEN ZOTERO
FIRST, then confirm the API is reachable before starting. This is a setup step, not a blocker.

=== REFERENCE POINT ===

Path 3 (direct sqlite reconstruction, Zotero closed) produced a complete, verified 4049-item export
matching `select count(*) from items` exactly. That export is the ground truth to compare Path 1
against: /home/benjamin/Projects/Literature/zotero-library.json, 4049 items, source
"sqlite-reconstruction" per its .zotero-library.meta.json stamp. Note $LITERATURE_DIR
(/home/benjamin/Projects/Literature) is OUTSIDE this repo -- the export is never in the repo, and
resolve_library_path() resolves it (tier 1 $ZOTERO_LIBRARY, then $LITERATURE_DIR).

=== WORK ITEMS ===

1. Measure the actual relationship between Total-Results, the csljson page contents, and the
   bibliographic item count against the live API. Determine whether limit/start are applied before
   or after format filtering, and whether attachments/notes are counted in Total-Results.

2. Either (a) explain the 481-vs-4042 discrepancy and fix Path 1 so it reaches parity with Path 3,
   or (b) if Path 1 provably cannot reach parity, change the Path 1 > Path 3 preference order in the
   generation control flow and document why. Option (b) is a legitimate outcome, not a failure --
   the current preference order was chosen on the assumption that a live API pull is more current
   than a sqlite read, and that assumption is what this task tests.

3. If the preference order changes, update the affected docs and the script's own header rationale
   comments so the ordering and its justification stay discoverable. Verified doc touchpoints
   (zotero-integration.md and tools/zotero-scripts.md do NOT mention this script -- zero grep hits):
     context/project/literature/patterns/zotero-pdf-resolution.md
     context/project/literature/domain/literature-index.md
     context/project/literature/domain/corpus-directory-conventions.md
     commands/literature.md

=== ACCEPTANCE CRITERIA ===

1. The 481-vs-4042 discrepancy is either explained with empirical evidence, or the path-preference
   order is changed with a documented rationale.
2. If Path 1 is fixed, a full export via Path 1 matches the sqlite-reconstruction item count.
3. Whichever outcome, the resulting path-selection behavior is documented where a future reader will
   find it, including the reason.

=== DEPENDENCY RATIONALE ===

Depends on the Path 1 accumulator fix. This is substantive, not bookkeeping: (a) both tasks modify
fetch_path1 in the same file, and (b) pagination termination cannot be observed cleanly while the
accumulator is still silently discarding pages and the error-swallowing fallback is masking failures.
Measure only after the truncation fix is in place.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed
.claude/** tree -- it is a gitignored, disposable deploy artifact wiped by the next regeneration.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 199. Decide and implement the working-tree and build isolation posture for concurrent same-repo dispatches
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 191, Task 192, Task 193, Task 213, Task 242, Task 243, Task 259, Task 266

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ and agent-system/extensions/lean/ (never .claude/**).

DECIDE, THEN IMPLEMENT: should concurrent same-repo /orchestrate dispatches keep sharing one working tree and one build directory, or should each dispatch get an isolated one? Weigh the options against the accumulated evidence; do not presuppose either.

=== THE ROOT CAUSE PRODUCES THREE DISTINCT FAILURE MODES ===

All three were observed live on 2026-09-09 in ~/Projects/BimodalLogic, tasks 574 and 575 dispatched concurrently as lean-implementation-agent into ONE shared working tree. They share a single root cause -- concurrent dispatch onto shared mutable resources -- but each has its own mechanism, and no single per-mechanism patch addresses more than one of them. This taxonomy is the core input to the decision.

  MODE 1a -- WORKING-TREE REVERT. The 575 dispatch ran `git-snapshot.sh 575` in DEFAULT mode while 574 was editing the same tree. Default mode runs `git stash push -u` repo-globally with NO pathspec, stashing away the sibling's uncommitted work (574's `.return-meta.json`, `.claude-extensions.json`, 7 lines of `specs/events.jsonl`). Detected and restored from `stash@{0}` by the agent noticing -- nothing at any layer would have caught it otherwise. Corroboration that this recurs: `git stash list` holds 44 entries, 32 named `git-snapshot-*`.
    Fixed by: auto/mandated `--no-revert`. Does NOT fix 1b or 2.

  MODE 1b -- CROSS-TASK COMMIT BLEED. VERIFIED DIRECTLY. Commit 08936bfbb ("task 574 phase 5: TM-star ledger rows and declaration-site Paper: lines") carries THREE task-575 rows in docs/theorem-index.md -- `isPlusStateLocal_of_stateLocal`, `plusStateLocal_plusValid_iff_stab`, `stateLocal_ofPlus_iff` -- plus a table header. Reproduce with `git show 08936bfbb -- docs/theorem-index.md`. Self-reported by the 574 dispatch and confirmed by the 575 dispatch. Both agreed nothing should be reverted, because reverting would delete 575's legitimate rows from HEAD. Recorded as cross-task bleed, NOT misattributed authorship.
    Fixed by: nothing currently filed. See the next section -- this is the mode that breaks the existing mitigation.

  MODE 2 -- BUILD CONTENTION. The 575 dispatch lost two builds to concurrent `lake` processes sharing one `.lake` directory. One was self-inflicted: it ran `scripts/check-module-invariants.sh` alongside a guarded build.
    Fixed by: a build mutex. Does NOT fix 1a or 1b.

=== WHY MODE 1b IS THE DECISIVE EVIDENCE: IT DEFEATS THE EXISTING MITIGATION ===

core/rules/git-workflow.md forbids `git add -A` and `git commit -am` for exactly this hazard -- pulling in "concurrent-session or unrelated stray edits" -- and prescribes targeted explicit-path staging as the remedy. The 574 dispatch FOLLOWED that prescription. It staged docs/theorem-index.md by explicit whole path, correctly, and bled anyway.

The reason is structural and cannot be patched at the staging layer as currently designed: EXPLICIT-PATH STAGING CANNOT SPLIT A FILE. Path granularity is the file. Two dispatches touching one shared file bleed into each other's commits no matter how carefully each one stages. In this repo several files are shared by construction -- docs/theorem-index.md, README.md, scripts/check-module-invariants.sh -- so the collision surface is not incidental.

INTERACTION WITH THE OVER-STAGING WORK (task 192) -- IMPORTANT, READ IT. That task widens the over-staging predicate to catch directory pathspecs, and its MUST NOT correctly protects "an explicit list of named file paths" as the sanctioned form that agents are told to use. Nothing here contradicts that: the explicit list must indeed remain permitted, because blocking it would leave agents with no compliant way to commit at all. What mode 1b establishes is narrower and does not overturn task 192: the sanctioned form is SUFFICIENT against over-broad staging and INSUFFICIENT against concurrent same-file dispatch. These are different hazards. Do not re-decide task 192's predicate here; do record this qualification so the rules stop implying that explicit-path staging is a complete answer under concurrency.

=== THE OPTIONS TO WEIGH ===

Produce an explicit recommendation with reasoning; the deciding artifact is as much the deliverable as the code. Score each option against ALL THREE failure modes above -- an option that fixes one mode and leaves two open should be scored as such.

  OPTION 1 -- KEEP THE SHARED TREE, PATCH PER MECHANISM. Continue dispatching siblings into one working tree and one `.lake`, closing holes individually. Already filed on this branch: task 191 (git-snapshot revert, mode 1a), task 192 (directory-pathspec over-staging), task 193 (territory in briefs). This task's contribution would be hardening mutex participation for mode 2.
    Score honestly: this branch has no answer to mode 1b at all. It is also the fourth-plus patch against one root cause, each closing an enumerated hole -- note the pattern already recorded in task 192, where a refusal that enumerated forms simply taught the enumeration and the agent reached for the nearest unnamed form.

  OPTION 2 -- PER-DISPATCH GIT WORKTREE ISOLATION. Give each concurrent implement dispatch its own `git worktree` (and therefore its own `.lake`), merging results back at commit time.
    Weigh honestly: it is the only option that addresses all three modes at once -- no shared tree means no sibling revert (1a) and no shared working copy to bleed from (1b); no shared `.lake` means no build contention (2) -- and it does so WITHOUT reducing concurrency. Against that: each worktree pays a full cold build, potentially very expensive for this repo (MEASURE IT, do not assume); merge-back at commit time is new machinery and does not make same-file conflicts vanish, it converts them from silent bleed into an explicit merge that someone or something must resolve -- cost that honestly, it is the main weakness of this option; the harness already exposes a worktree isolation mode for subagents, so check what is reusable before building. Prior art exists in the source store under the lean and cslib extensions (comparator runs, lint-fix wave assignment) -- read it before designing.

  OPTION 3 -- NARROWER STAGING-LAYER ALTERNATIVE, WORTH COSTING BEFORE COMMITTING TO 2. Either (i) teach `core/scripts/git-commit-scoped.sh` to stage by HUNK rather than by path, so a dispatch commits only its own edits within a shared file; or (ii) have it REFUSE a shared file while a sibling dispatch holds uncommitted edits in it, forcing explicit sequencing. This targets mode 1b directly and is far cheaper than worktrees.
    Weigh honestly: (i) needs a reliable way to attribute a hunk to a dispatch, which the system may not have -- establish whether it does before recommending it. (ii) needs live sibling-edit knowledge at commit time, which relates to what task 193 makes available; say so and do not duplicate that work. Neither variant addresses modes 1a or 2.

  A SPLIT VERDICT IS AN ACCEPTABLE OUTCOME -- e.g. worktree isolation for lean4/cslib implement dispatches where builds are expensive and collisions frequent, shared tree plus option 3 for cheap doc/meta dispatches. If that is the recommendation, define the predicate that selects between them.

=== NOT A CONTRADICTION OF TASK 193 ===

That task's MUST NOT says "do not serialize all multi-task dispatch as the fix; concurrency is the design". No option here proposes running the batch sequentially: worktree isolation preserves full concurrency and removes the shared resource instead. Coordinate rather than re-decide -- task 193 decides what a dispatch is TOLD, this decides what a dispatch RUNS IN. Note also that informing agents is demonstrably insufficient on its own for mode 1b: both dispatches here ended up fully aware of each other and the bleed still landed in history.

=== CORRECTION TO THE ORIGINAL MODE-2 DIAGNOSIS: THE BUILD MUTEX ALREADY EXISTS ===

Mode 2 was initially reported as "needs a build mutex in lake-build-guard.sh". Verified against the source: agent-system/extensions/core/scripts/lake-build-guard.sh ALREADY implements a `flock`-based mutex on `$GUARD_LAKE_DIR/build-guard.lock`, with lock-wait timeout (exit 75), abandoned-lock recovery via flock's automatic release on process exit, and result sharing between waiter and holder. It degrades audibly when `flock` is absent rather than silently running unserialized. The mutex is not missing.

WHAT IS MISSING IS THAT IT IS OPT-IN. The guard's header states it: "any other consumer must opt in explicitly by invoking `lake-build-guard.sh build ...`". Any process running bare `lake` bypasses the lock. The self-inflicted collision is exactly this -- /home/benjamin/Projects/BimodalLogic/scripts/check-module-invariants.sh calls bare `lake build` and `lake build BimodalTest` (around lines 638/644) with no guard. The failure mode is BYPASS, not absence. Note that this same script is itself one of the shared-by-construction files implicated in mode 1b (it was modified in commit 08936bfbb).
  OWNERSHIP: check-module-invariants.sh is a BimodalLogic project-local script, NOT an agent-system file. Fixing that call site is OUT OF SCOPE. In scope is the general question it exposes: how does the agent system get unguarded lake-invoking callers to participate in the mutex, given that it cannot edit every consumer repo's scripts?

=== WORK ===

  (a) Measure before deciding: cold-build cost for this repo under a fresh worktree; observed frequency of guard-lock contention versus outright bypass; whether per-dispatch hunk attribution is even available (gates option 3(i)).
  (b) Produce the written recommendation scoring every option against all three failure modes, recorded in the task summary and in core/context/patterns/batch-orchestration-guardrails.md.
  (c) Implement the chosen option.
  (d) Whichever option wins, document (i) the mutex's opt-in nature and the bypass hazard, in lean/rules/lean4.md's build section and the guard's header if the participation contract changes; and (ii) the mode-1b qualification -- that explicit-path staging does not protect against concurrent same-file dispatch -- wherever the rules currently present targeted staging as the concurrency remedy.

=== MUST NOT ===

Do not edit core/scripts/git-snapshot.sh, core/rules/git-workflow.md or the plan format (task 191 owns those; the mode-1b rules qualification in (d)(ii) must be coordinated with that task rather than written directly into git-workflow.md here). Do not edit hooks/guard-destructive-git.sh or re-decide the over-staging predicate (task 192). Do not block explicit multi-file path staging -- it must remain the sanctioned form. Do not implement the territory payload (task 193). Do not edit any BimodalLogic project-local script. Do not remove or weaken the existing flock mutex under any option. Do not attempt retroactive repair of commit 08936bfbb -- both dispatches deliberately agreed against reverting, because the bled rows are legitimate content.

=== FOOTPRINT NOTE ===

file_scope overlaps tasks 182, 193 and 197 on orchestrate-cycle-plan.sh, and task 191 conceptually on the staging rules; the file-footprint admission gate will serialize the overlapping ones. Whichever lands last reconciles the header contracts.

=== ACCEPTANCE ===

A written, evidence-backed recommendation exists naming the chosen posture, scoring every option against modes 1a, 1b and 2 explicitly, with the cold-build measurement and the hunk-attribution feasibility finding that informed it. The chosen option is implemented. A fixture reproduces the observed batch shape -- two concurrent lean4 implement dispatches in one repo, both editing one shared markdown file, one of them invoking an unguarded `lake` -- and demonstrates that cross-task bleed into a commit no longer occurs (or, if option 1 was chosen, documents plainly that it still can and why that was accepted). The opt-in nature of the build mutex is documented where an agent will read it. shellcheck clean per context/standards/shell-strict-mode.md for any shell touched. Redeploy and confirm the change is live in a consumer repo.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


=== ADDITIONAL EVIDENCE (2026-09-17, ~/Projects/BimodalLogic) ===
THE SHARED-TREE POSTURE PRODUCED CROSS-TASK COMMIT MISATTRIBUTION, not merely a build collision.
A four-task base-mode batch was admitted for concurrent implementation despite overlapping edit
sets (docs/, typst/, CI_CD_PROCESS.md, sync-check-whitelist.txt). Three of the four dispatches
committed files that still held a fourth dispatch's UNCOMMITTED rename edits, so git history now
credits those changes to the wrong tasks. Unlike the earlier incident recorded against the
base-mode territory task, nothing here was reverted and no build was mis-attributed -- the damage
is permanent and silent, in the history itself.

WHY THIS SHARPENS THE DECISION THIS TASK OWNS. Informing agents of each other (the territory
work) would not have prevented this on its own: the colliding writes were correctly inside each
task's own declared intent, and the misattribution happened at COMMIT time, when a path-scoped
commit swept up a sibling's in-flight edits to the same path. That is a property of sharing one
index and one working tree, which is precisely the posture this task is chartered to decide. Weigh
it as evidence for the isolation option -- per-dispatch worktrees make the failure structurally
impossible -- against the cost of N build directories, but do not treat it as decisive on its own.

THIRD OPTION TO PRICE ALONGSIDE THE TWO ALREADY NAMED: pre-commit hunk-level ownership checks,
i.e. keep the shared tree but refuse to commit a hunk in a path the committing task does not own.
Cheaper than worktree isolation and it attacks the observed failure directly, but it needs a
per-task ownership map finer than the current file_scope, which was too coarse for the collision
gate to catch this batch at all. Coordinate with the file-scope-lifecycle tasks rather than
re-deciding declaration granularity here.

---

### 185. Retarget stage citations to move vocabulary
- **Status**: [NOT STARTED]
- **Task Type**: markdown
- **Topic**: core-agent-system
- **Dependencies**: Task 266, Task 199, Task 184

**Description**: Retarget the remaining historical "Stage N" and "Stage MT-N" citations to the four-move loop vocabulary.

CONTEXT. skill-orchestrate/SKILL.md was rewritten from a two-engine, Stage-numbered state machine (single-task Stages 0-8; multi-task Stages MT-1 through MT-5) into a single four-move loop whose sections are named Move 1 through Move 4. Roughly 120 citations of the old vocabulary remain across 9 context/ and docs/ files. They now point at section names that no longer exist in the file they cite.

KNOWN SITES (from the rewrite's own survey; re-verify by grep rather than trusting this list):
  context/patterns/batch-orchestration-guardrails.md  -- 34 occurrences, the largest single concentration
  docs/architecture/handoff-schema.md
  docs/architecture/orchestrate-cycle-postflight.md
  docs/architecture/batch-admit-schema.md
  context/patterns/orchestrate-batch-results-template.md
  plus four further context/ and docs/ files

WHY IT WAS DEFERRED. The rewrite judged a ~120-citation mechanical sweep disproportionate to its core scope and recorded it as a follow-up rather than attempting it inline.

SCOPE AND CARE. This is a mechanical retarget, not a rewrite of the surrounding prose. Two hazards to respect: (1) some citations are historical-by-intent -- they describe what a now-deleted engine did, in a decision record or incident narrative, and must keep naming the old stage rather than being rewritten to a Move that never had that behavior; distinguish "cites a live section" from "narrates history" before editing. (2) Edit the source store under agent-system/extensions/** and never the deployed .claude/ tree (see rules/source-store-deploy-boundary.md).

ACCEPTANCE: every citation that refers to a LIVE section names the correct Move; every historical citation is either left intact or explicitly marked as historical; a grep for "Stage MT-" and for single-task "Stage [0-8]" returns only intentional historical references; deploy and the full gate run stay green.

=== PATH REVIEW 2026-09-28: scope and ordering ===
file_scope now names the five known sites; research MUST add the remaining files (a grep for 'Stage MT-' and single-task 'Stage [0-8]' matched 72 files under core/context, docs, skills and commands on 2026-09-28, most of them historical-by-intent) to file_scope before the implement dispatch. Ordered behind the three engine tasks that are actively editing batch-orchestration-guardrails.md and handoff-schema.md, so the mechanical sweep runs over settled text.

---

### 184. Surface skeleton-plan follow-ups at completion under the batch engine (ruled: port the sorry_inventory follow-up report, not pr_ready routing)
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 242, Task 243, Task 258, Task 259, Task 266

**Description**: === RULED 2026-09-22 (eighth-pass phase 0) ===
Disposition: option (a), narrowed to what was actually lost. The single-task engine's skeleton-exhaustion branch did three things: (1) routed the task to completion via the pr_ready target, (2) propagated a completion summary, (3) derived and reported follow-up tasks from sorry_inventory[].follow_up_task. Under the batch engine (1) is moot: pr_ready is a type=pr-only terminus, and every other task completes through orchestrate-cycle-postflight.sh's completion-claim gate, which a skeleton plan with all phases complete already reaches (orchestrate-cycle-plan.sh's 'no OPEN heading' fallthrough, ~line 2003, and the porting note at ~line 1921). (2) is owned by postflight generally. Only (3) is lost: a skeleton plan completes with its sorry_inventory silently dropped, so the strategic sorries never become tasks.

SCOPE (now concrete; no further decision phase). In orchestrate-cycle-postflight.sh, when the final implement handoff carries skeleton=true and a non-empty sorry_inventory[]: (i) print the follow_up_task entries in the cycle's stderr report and include them in the task's completion summary section; (ii) record them on the state.json entry in an append-only field (research picks the field -- a skeleton_follow_ups array or reuse of the memory_candidates shape -- and state-management-schema.md documents it); (iii) do NOT auto-create tasks: the report is the handoff and the user files them with /task. Document in status-markers.md and handoff-schema.md how a skeleton plan terminates now (through the completion-claim gate, follow-ups reported). Regression test in scripts/tests/test-orchestrate-cycle-postflight.sh with a skeleton=true fixture whose sorry_inventory has two entries. Options (b) and (c) of the original text are closed by this ruling. ORDERING: after 242 (same postflight script and test) and 243 (handoff-schema.md), recorded as dependency edges. The original decision text follows for the record.

Decide the disposition of the Lean/formal skeleton-plan completion routing lost with the single-task engine.

CONTEXT. The deleted single-task /orchestrate engine carried a skeleton-exhaustion completion branch: when no incomplete phase heading remained AND the last handoff declared skeleton=true, it derived a follow-up task list from the handoff's sorry_inventory[].follow_up_task entries, routed the task to completion via update-task-status.sh postflight with the pr_ready target and --allow-pr-ready, and reported the pending follow-ups. The surviving batch engine has no equivalent branch.

WHY THIS ONE NEEDS A DECISION AND HAS NOT HAD ONE. The rewrite recorded TWO capability losses. The loop-guard staleness detector got an explicit recommended follow-up. This one was recorded as a permanent loss with NO follow-up named at all -- it is the only deviation in that summary left without a next step. Lean and formal work is live in this repository, so silent acceptance should be a deliberate choice rather than an oversight.

SCOPE. Determine whether strategic-sorry skeleton plans can still reach a correct terminal status under the batch engine, and if not, what should happen. Evaluate at least: (a) port the skeleton-exhaustion branch into orchestrate-cycle-plan.sh or orchestrate-cycle-postflight.sh; (b) require skeleton plans to close through a different, already-supported path; (c) accept the loss explicitly and document how a skeleton plan is expected to terminate now. Do not pre-commit to an option.

EVIDENCE. The assertions covering this mechanism (.skeleton / last_skeleton and .sorry_inventory / follow_up_tasks) were removed from scripts/tests/test-handoff-reader-parity.sh. Recorded under "Plan Deviations" in specs/088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_four-move-loop-rewrite-summary.md. Related policy: the strategic-sorry skeleton allowance in context/contracts/recovery.md.

ACCEPTANCE: a recorded decision with rationale; if a gap is confirmed, either a working path to terminal status for skeleton plans with test coverage, or documentation naming the expected terminus.

---

### 170. Audit and isolate shell test suites from ambient host state (memory and timing axes), and record the convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 51, Task 129, Task 151, Task 169, Task 206, Task 215, Task 250, Task 251

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

---

### 167. Guard LaTeX builds against the vimtex watcher: always-on rule first; shared guard script and lifecycle wiring only if the rule proves insufficient
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 257, Task 259

**Description**: Make continuous-build (vimtex `latexmk -pvc`) safety guidance always-in-effect for every agent and command, not only latex-typed dispatches, by extending the latex extension's EXISTING deployed rule file rather than adding a new mechanism.

=== MOTIVATING INCIDENT (2026-09-07, PossibleWorlds paper repo, JPL/ subdirectory) ===

Command-line `latexmk -pdf` runs issued during an ordinary editing conversation (NOT a latex-typed task) raced a running vimtex `latexmk -pvc` watcher on the same shared build/ directory.

Symptoms: empty .aux file; deleted PDF; spurious "Build failed" entries appended to build/compile.log by the .latexmkrc $failure_cmd; bibtex reporting "I found no \citation commands"; latexmk exit code 12 despite ZERO LaTeX errors in the log. The exit-12-with-clean-log signature was misread as a LaTeX error, prompting repeated rebuilds that compounded the race.

Verified during diagnosis:
  - `pgrep -af 'latexmk'` showed the vimtex process with flags:
      -pvc -pvctimeout- -view=none -outdir=build -emulate-aux-dir -auxdir=build
  - An isolated build succeeded cleanly and was the correct verification path:
      latexmk -pdf -outdir=$SCRATCH -auxdir=$SCRATCH -r /dev/null file.tex
  - A direct `pdflatex -output-directory=build` also exited 0, confirming the source was fine
    and the failure was latexmk-level contention, not a LaTeX error.

=== ROOT-CAUSE FINDING (drives the recommendation) ===

The rule `agent-system/extensions/latex/rules/latex.md` ALREADY exists, ALREADY declares
`paths: "**/*.tex"`, and is ALREADY deployed to the paper repo as `.claude/rules/latex.md`
(confirmed present). Because the incident conversation was editing `JPL/possible_worlds.tex`,
that rule was almost certainly auto-loaded at the time.

The rule was therefore not silent -- it was the proximate source of the harmful advice. Its
"Build Commands" section currently prescribes, with no watcher guard whatsoever:

    latexmk -pdf document.tex
    latexmk -c

These are exactly the two commands that must NOT be run against a shared -outdir while a
`-pvc` watcher owns it. Separately, `context/project/latex/tools/compilation-guide.md:215`
documents `latexmk -pdf -pvc` as something to run, with no note that an agent must never
start, kill, or race one.

So the lowest-impact fix is not to add a mechanism. It is to correct an existing file that
already fires on the right trigger and currently says the wrong thing.

=== RECOMMENDED MECHANISM (minimal pair -- option (a) primary + option (b) one-pointer) ===

PRIMARY (option a) -- edit `agent-system/extensions/latex/rules/latex.md`:
  1. Widen the frontmatter glob from `paths: "**/*.tex"` to also cover build/aux surfaces that
     a bare compile command references without touching a .tex file, e.g.
     `**/*.tex`, `**/*.latexmkrc`, `**/build/**`, `**/*.bib`.
     (Confirm the deployer's supported frontmatter syntax for multiple globs before writing --
     every current rule in the source store uses a single-string `paths:` value, so a list form
     must be validated against the loader, not assumed.)
  2. Insert a "Continuous Build Safety" section ABOVE the existing "Build Commands" section, so
     the guard is read before the commands it constrains.
  3. Repair the existing "Build Commands" and "Validation Checklist" blocks so they no longer
     present bare `latexmk -pdf` / `latexmk -c` / "Builds successfully with pdflatex" as
     unconditional instructions.

COMPLEMENT (option b) -- add 3-4 lines to `agent-system/extensions/latex/EXTENSION.md`, the merge
source for the CLAUDE.md "LaTeX Extension" section (merge_targets.claudemd, section_id
`extension_latex`). This is a POINTER ONLY, not a copy of the rule. Rationale: it closes the one
residual gap where an agent issues a bare `latexmk` Bash call having never touched or referenced
any .tex/build path in the session, so no paths-glob match ever fires. Keep it to a few lines --
this text lands in the eager session prefix, which the system explicitly budgets (see
`measure-eager-context.sh` / `measure-eager-surface.sh`).

Also update `context/project/latex/tools/compilation-guide.md` (around the `-pvc` line, ~215) with
a one-line cross-reference to the new rule section, so the lazily-loaded guide does not contradict
the eagerly-loaded rule.

=== ACCEPTANCE CRITERIA (the five behavioral points; the rule text must make each actionable) ===

AC1. DETECT BEFORE COMPILING. Before any latexmk/pdflatex/xelatex/lualatex invocation, check for a
     running continuous watcher on the same source:
         pgrep -af 'latexmk.*-pvc'
     and/or any latexmk/pdflatex process whose arguments name the same .tex file or the same
     -outdir. The rule must give the literal command, not a paraphrase.

AC2. IF A WATCHER IS RUNNING, DO NOT CONTEND. Never run latexmk/pdflatex into the shared build/
     (or whatever -outdir the watcher uses). Never kill, stop, or restart the watcher. Never run
     `latexmk -C` or `latexmk -c` against the shared directory.

AC3. USE A NON-CONTENDING PATH INSTEAD. Either (i) make the edit and let vimtex rebuild -- it is
     already watching the file -- or (ii) verify compilation with an isolated build into the
     session scratchpad and inspect the log there:
         latexmk -pdf -outdir="$SCRATCH" -auxdir="$SCRATCH" -r /dev/null file.tex
     `-r /dev/null` bypasses the project .latexmkrc (which is what appends the spurious
     "Build failed" entries via $failure_cmd).

AC4. REPORT, DO NOT REPAIR. Report the isolated build's result. If the shared build directory
     looks broken (missing PDF, empty .aux, "Build failed" entries in build/compile.log), tell the
     user to run `:VimtexClean` then `:VimtexCompile`. Do not attempt repairs against the shared
     directory.

AC5. CLASSIFY THE FAILURE BEFORE RERUNNING. When diagnosing a nonzero latexmk exit code,
     distinguish latexmk-level failure (exit 12, bibtex/aux complaints such as "I found no
     \citation commands") from an actual LaTeX error (a `^!` line, or a file-line-error
     `file.tex:N:` line) BEFORE rerunning anything. A clean log with a nonzero exit code is a
     contention signal, not a source error.

AC6. NO DUPLICATION. The guidance lives in exactly one authoritative place (the rule). EXTENSION.md
     and compilation-guide.md carry pointers, not restatements.

AC7. VERIFY THE TRIGGER, DO NOT ASSUME IT. Before closing, empirically confirm whether the widened
     paths glob actually fires for a Bash tool call that merely names a .tex path in its command
     string, versus only for Read/Edit/Write on that path. This determines whether the option (b)
     pointer is load-bearing or merely belt-and-braces, and the finding must be recorded in the
     task report either way.

=== OPTION ANALYSIS (rationale for rejecting the alternatives) ===

(a) RULE FILE via provides.rules with a paths glob -- CHOSEN.
    Already exists, already deployed, already fires on .tex touches, already declared in
    manifest.json provides.rules (["latex.md"]). No manifest change, no new file, no deploy
    topology change. Precedent for the pattern: lean's rules/lean4.md with `paths: "**/*.lean"`.
    Fires regardless of task type -- the harness paths-glob mechanism is independent of task
    routing, of index.json, and of any @-import list (see
    `context/patterns/context-discovery.md`, "Rule Loading: Two Independent Paths").
    Residual gap: a bare Bash `latexmk` that references no matching path -- covered by (b).

(b) MERGE-SOURCE ADDITION to EXTENSION.md -> CLAUDE.md -- CHOSEN AS MINIMAL COMPLEMENT, pointer only.
    Always in the eager session prefix whenever the latex extension is loaded, so it is
    unconditionally task-type-independent and has no trigger dependency at all. Cost: eager
    context bytes, which the system budgets. Hence a pointer, not a copy.

(c) PREFLIGHT LIFECYCLE HOOK in the manifest `hooks` object -- REJECTED. CONFIRMED to fail the
    requirement. Lifecycle hooks run only at skill lifecycle stages via skill-base.sh
    (preflight/context_injection/verification/postflight), so they fire only inside a dispatched
    skill. The motivating incident occurred in an ordinary editing conversation with no skill
    lifecycle active -- exactly the case a lifecycle hook cannot reach. The latex manifest
    currently has `provides.hooks: []` and no top-level `hooks` object.

(d) CONTEXT FILE under context/project/latex/ -- REJECTED. CONFIRMED to fail the requirement.
    Every latex entry in `index-entries.json` is gated on `load_when.task_types: ["latex"]` and
    on the latex agents, making it lazily loaded and task-typed -- precisely the two properties
    the requirement excludes. compilation-guide.md, which already contains the only `-pvc` mention
    in the extension, was NOT loaded during the incident for exactly this reason.

(e) PreToolUse Bash-matcher HOOK via settings-fragment.json -- CONSIDERED AND REJECTED as
    disproportionate, though it is the only mechanism that fires with certainty on a bare
    `latexmk` Bash call carrying no path reference. Precedent exists: the email extension
    registers `mail-guard.sh` as a PreToolUse "Bash" matcher through its settings-fragment.json
    plus `provides.hooks`. Rejected because it requires a new script, a new settings-fragment.json
    for an extension that has none, a manifest provides.hooks change, and it imposes a hook
    invocation on EVERY Bash call system-wide to guard one narrow case. Record this as the
    documented escalation path if AC7 shows the paths glob does not fire for Bash-only references
    and the (b) pointer proves insufficient in practice.

COMPLEMENT, OUT OF SCOPE FOR THIS TASK: the PossibleWorlds paper repo's own CLAUDE.md already has
a "Build Workflow: Preventing Aux File Corruption" section documenting this exact race from the
latexmk side. A short pointer there is warranted, but that file belongs to the paper repo, not to
this source store, and is user-owned. Note it in the report as a follow-up suggestion; do not edit
it from this task.

=== SCOPE BOUNDARY ===

All edits target the SOURCE STORE at `agent-system/extensions/latex/**`. Never hand-author
anything under `.claude/**` -- that tree is a disposable deploy artifact regenerated from source
(see `.claude/rules/source-store-deploy-boundary.md`). Verify the change by redeploying and
confirming the regenerated `.claude/rules/latex.md` and the CLAUDE.md `extension_latex` section
carry the new text.


=== ABSORBED 2026-09-22 from former task 74 (Add shared LaTeX build-conflict guard script (detect competing vimtex latexmk -pvc)); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Build a shared, task-type-agnostic guard script that detects a user-owned LaTeX continuous-build watcher (`latexmk -pvc`, typically driven by nvim's vimtex plugin) competing for the same .tex target an agent is about to build, and that can report, stop, and restore it. This task delivers the MECHANISM only; wiring it into lifecycle stages is handled by the two dependent tasks.

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


=== ABSORBED 2026-09-22 from former task 75 (Wire build guard into latex extension preflight hook and agent contracts); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Wire the shared LaTeX build guard into the latex extension's lifecycle and contracts, so that `latex`-typed research and implementation dispatches detect (and, per the chosen mechanism, stop) a competing vimtex continuous build before the agent runs its own.

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


=== ABSORBED 2026-09-22 from former task 76 (Close task-type-keyed hook gap for non-latex agents that compile .tex); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Close the coverage gap that the latex-extension wiring cannot reach: agents that compile .tex files under a task type OTHER than `latex` currently get no build-guard protection at all, because the extension hook mechanism is keyed on task_type.

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


=== PATH REVIEW 2026-09-28 (fifth pass): rule first, scope trimmed ===
Settled decision 8 stands: the rule edit (primary + pointer + guide cross-reference, AC1-AC7) is the deliverable. The three absorbed mechanism tasks above (core guard script, latex preflight wiring, task-type-independent core path) are CONDITIONAL later phases, admitted only if AC7 shows the widened paths glob does not fire for Bash-only references AND the EXTENSION.md pointer proves insufficient in practice. Their core-side targets (scripts/latex-build-guard.sh, scripts/skill-base.sh, core/manifest.json, agents/general-implementation-agent.md) were REMOVED from file_scope: they classified this task as self-modifying and collided with three unrelated engine tasks. Add them back at plan time only if the conditional phases are actually admitted.

---

### 165. Admission gates in orchestrate-batch-admit.sh: posture for an absent file_scope, then cross-session visibility for self-modifying candidates
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 162, Task 163, Task 245

**Description**: Settle whether an ABSENT `file_scope` should be admission-relevant in agent-system/extensions/core/scripts/orchestrate-batch-admit.sh, or remain purely advisory -- and implement the ruling.

THE MOTIVATING HARM (observed live in ~/Projects/BimodalLogic, not hypothetical):
- `/orchestrate 530,531` correctly deferred one task cross-batch for overlapping a live task at README.md -- the collision guard working exactly as designed.
- `/orchestrate 544,545` dispatched BOTH with ZERO collision-guard coverage, purely because neither declares a file_scope at all. A live concurrent task held a broad scope (FormalSystem/, Tests/, docs/, typst/, README.md) and one of the dispatched pair worked the same naming domain that live task was mid-rename on. Nothing would have caught a conflicting concurrent edit.
The guard did not fail. It was never consulted, because the predicate has nothing to compare. An undeclared scope is currently indistinguishable from a scope that provably collides with nothing.

THE TRADEOFF (this is the decision, state it explicitly): treating absence as a defer reason closes the silent-passage hole but risks blocking legitimate work on legacy tasks that predate any file_scope discipline. That risk is what the sequencing mitigates -- this task is gated behind both the detection work and the backfill precisely so the legacy population is already covered before absence can block anything. Verify that mitigation actually landed before tightening; if backfill coverage is incomplete, prefer the softer posture and say why.

EXISTING MECHANICS TO WORK WITHIN (the script's own documented contract): `defer_reason` currently admits "self_modifying", "file_scope_collision", and "session_active". A `file_scope_collision` defer carries `colliding_task_number`, `colliding_task_status`, `overlapping_path`, `collision_scope`, and `corroborated_by`. An absent-scope defer has NO colliding task and NO overlapping path, so it does not fit that payload shape -- it is a different kind of fact (missing information, not detected conflict). If a defer is chosen, it likely needs its OWN reason value rather than being forced into file_scope_collision, whose fields would all be empty. Note also the documented override asymmetry: file_scope_collision and session_active have specific override semantics -- decide where a new reason sits in that hierarchy.

ENFORCEMENT LEVEL -- PRIOR ART, FOLLOW IT: plan-format.md:259-266 records the Verification Tier rollout as the in-repo precedent. Quoted: enforcement is "advisory-first: a missing field emits a warning, not an error, so default-mode validation of plans authored before this vocabulary existed continues to pass. `--strict` mode enforces it today. Promotion criterion: promote the warning to an error once no non-terminal plan under specs/ lacks the field." The same three-part pattern applies: start advisory, WRITE DOWN the promotion criterion, promote only once coverage is complete. A defensible outcome for this task is explicitly deciding NOT to make absence blocking yet, and recording the coverage threshold at which it should become blocking -- that is a real decision, not a deferral, and it must be written into the script header either way.

OPTIONS TO WEIGH: (a) advisory only -- surface in the review, never affect admission; (b) a new non-blocking `defer_reason` visible in output but overridable; (c) a genuine defer gated on a coverage precondition; (d) blocking only when a live task holds a broad scope, i.e. treat absence as risky only in the presence of an actual concurrent hazard, which directly matches the observed harm and is the narrowest fix.

ACCEPTANCE: the ruling and its reasoning are recorded in the script's header contract alongside the existing defer_reason documentation; if a new reason value is added, its payload fields and override semantics are documented to the same standard as the existing three; the observed harm scenario is reproduced as a test case and the chosen posture demonstrably changes its outcome (or is documented as deliberately unchanged); shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


=== ADDITIONAL EVIDENCE (2026-09-21, ~/Projects/Logos/Verification, session sess_1790009936_0a5e95) ===
A SECOND, LARGER INSTANCE OF THE MOTIVATING HARM -- IN-BATCH, NOT CROSS-SESSION. `/orchestrate
66,70,72,76,77,81,84,85` (8 tasks, all task_type general, all created without file_scope) reached
the implement phase with every task planned. `orchestrate-cycle-plan.sh --dry-run` reported:
Dispatch = all 8, Deferred = 0, Blocked = 0 -- i.e. it would have run 8 implementers concurrently
in ONE working tree. The plans themselves showed heavy real overlap, found only by an operator
reading them:
  - framed_channel/check.sh edited by 3 tasks (one a 9-phase refactor of it);
  - .github/workflows/verify.yml: one task edited the comparator-arm job while another DELETED it;
  - docs/ci.md edited by 4 tasks;
  - 4 tasks ran the full local verification gate, which regenerates the committed certificate --
    concurrent gate runs over a tree other agents are mid-edit would have produced wrong results.
The collision guard did not fail; as in the BimodalLogic case it was never consulted, because
every candidate's file_scope was absent.

OPERATOR REMEDY THAT WORKED (and what it implies for the ruling): the operator hand-populated
file_scope for all 8 tasks from each plan's "Files to modify" lists and re-ran the dry-run. The
existing in_batch predicate then serialized correctly (cycle 3: 2 admitted, 6 deferred with
accurate overlap reasons), and the batch completed across 6 implement cycles with zero
cross-task clobbers, all eight committing cleanly. Two implications:
  1. The information needed was already on disk at plan time (every plan listed its files) --
     direct support for harvesting file_scope from plans (the formalize/harvest task) as the
     primary fix, with this task's posture as the backstop.
  2. For the in_batch case specifically, the "defer on absence" posture is cheap: an absent-scope
     task in a multi-task batch has no evidence it is disjoint from its siblings, and the cost of
     wrongly serializing is extra cycles, while the cost of wrongly parallelizing was (here)
     concurrent edits to the same gate script and concurrent certificate-regenerating gate runs.
     Consider ruling separately for in_batch (strict: absent scope => serialize against every
     sibling, or refuse admission until scope is declared) vs cross_batch (the tradeoff already
     stated above).


=== ABSORBED 2026-09-22 from former task 190 (Fix cross-session admission blindness for self-modifying candidates); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. Two SELF-MODIFYING tasks running in SEPARATE concurrent /orchestrate sessions are mutually invisible to every admission gate. Each is admitted solo; neither sees the other; they proceed to edit the same orchestrator-critical file concurrently.

OBSERVED LIVE (2026-09-08, this repository, not hypothetical). Two /orchestrate sessions ran concurrently under the same ancestor pid:
  sess_1788883218_cb46bc  /orchestrate 180,181,182
  sess_1788889066_9309df  /orchestrate 189
Both batches claimed agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh. Three commits landed on that file from the 189 session while the other session was in cycle-6 planning for 182. No gate fired. The collision was caught only by a human reading a task notification. 182 had not yet dispatched, so no clobber occurred -- this was luck, not a gate.

MEASURED EVIDENCE (direct probe, reproducible):
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <A> 182
    -> {"decision":"admit","self_modifying":true}
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <B> 189
    -> {"decision":"admit","self_modifying":true}
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <B> 182 189   # SAME batch
    -> 182 admit; 189 DEFER, defer_reason self_modifying, full critical_path + ordering reason
  bash .claude/scripts/orchestrate-batch-admit.sh --session-id <A> 157       # NOT self-modifying
    -> admit + idle_overlap_advisory naming out-of-batch task 170, collision_scope cross_batch

WHAT THIS ISOLATES. The in-batch tie-breaker works correctly. The cross-batch file_scope scan also works -- it fired for the NON-self-modifying candidate (157) against an out-of-batch task. But for a SELF-MODIFYING candidate dispatched solo, the verdict carries no cross-batch collision result and no session-registry result at all. The self-modification branch appears to admit early and short-circuit the file_scope_collision and session_active passes that would have caught the overlap. Confirm that reading against the script's own documented pass ordering (self-mod, then file_scope_collision, then session_active, the last two reached only when the prior finds no hit) before changing anything.

CONTRIBUTING FACTOR, ALREADY REMEDIED, DO NOT RE-FILE. Task 189 carried no file_scope at all, so its session registered an empty covered scope. That was repaired by hand during the incident and is not the root cause: with all 11 paths populated AND the session registry re-registered to match, the solo verdicts above STILL admit. Absent metadata made it worse; it did not cause it.

MUST NOT. Do not make the solo self-modifying candidate DEFER -- that would mean zero dispatch on every solo run of a self-modifying task, which is the exact regression the pre-existing tie-breaker design avoids. The admission DECISION is defensible; what is missing is that the verdict does not carry, and the caller cannot see, a live cross-session collision. Do not change the collision predicate or the verdict schema's existing fields in ways that break orchestrate-predispatch-review.sh, which is a consumer.

ACCEPTANCE. With two live registered sessions whose covered scopes overlap on at least one path, a solo self-modifying candidate in one of them produces a verdict that names the overlap (defer, or admit carrying an explicit cross-session hazard field that orchestrate-predispatch-review.sh renders). A fixture test reproduces the two-session case above and fails against the current script.

NOTE ON LIVENESS DETECTION. Both sessions in the incident reported the SAME pid with pid_source ancestor-claude, because two /orchestrate runs inside one Claude Code process share an ancestor. Any self-exclusion keyed on pid rather than session_id would treat a foreign session as self and silently disable cross-session detection for the most common case. Verify which key the exclusion actually uses; if it is pid, that alone may be the whole defect.

---

### 163. Surface missing and empty file_scope in validate-state.sh and orchestrate-predispatch-review.sh
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 188

**Description**: Make an ABSENT or EMPTY `file_scope` visible. Today it is invisible everywhere, by construction.

VERIFIED GAP -- both existing checks skip exactly the entries that lack the field:
1. agent-system/extensions/core/scripts/validate-state.sh Check 8 (coarse whole-directory-root declarations, ~line 460) and Check 9 (duplicate entries within one task's array, ~line 501) are BOTH WARN-only AND both guard with `select(has("file_scope"))`. An entry with no file_scope key is silently skipped by both. There is no missing/empty check anywhere in the script.
2. agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh Class B (~line 236) iterates `["dependencies", "file_scope", "title", "topic"]` and matches with `select(($entry | has($field)) and ($entry[$field] == null))`. Its own comment states the intent verbatim: "A genuinely absent key is NOT flagged -- only a present-but-literal-null value is the anomaly this class exists to surface." So absence is skipped BY DESIGN, not by oversight.

These two are consolidated into one task deliberately: both are WARN-shaped detection edits in the same layer, and splitting them would force two tasks to independently re-derive the same WARN-vs-block conclusion.

WORK: add a missing/empty file_scope check to validate-state.sh; extend predispatch-review to surface an absent file_scope. For the latter, DECIDE whether to widen Class B or add a NEW class -- widening Class B changes the documented meaning of an established class (its comment explicitly scopes it to literal-null) and Class B feeds `--repair`, which normalizes null to []. Note that an absent key and a literal-null value are NOT equivalent for repair purposes: normalizing an absent key to `[]` would manufacture an empty declaration that then looks deliberate, which is arguably worse than absence. A new class avoids both hazards. Record the ruling either way.

ENFORCEMENT LEVEL -- PRIOR ART, FOLLOW IT: plan-format.md:259-266 records the Verification Tier rollout as the in-repo precedent for exactly this decision. Quoted: per-phase tier enforcement in validate-artifact.sh is "advisory-first: a missing `**Verification Tier**:` field emits a warning, not an error, so default-mode validation of plans authored before this vocabulary existed continues to pass. `--strict` mode enforces it today. Promotion criterion: promote the warning to an error once no non-terminal plan under specs/ lacks the field. This is recorded here for a future task to execute; it is not done by the task that introduced this vocabulary."

Apply that same three-part pattern here: (a) start WARN in default mode; (b) WRITE DOWN an explicit promotion criterion in the script's own header comment; (c) do NOT promote in this task. Consider whether `--strict` should enforce it immediately, as validate-artifact.sh does. Do not invent a different enforcement philosophy -- this precedent exists and is load-bearing.

EMPTY vs ABSENT: treat `file_scope: []` and a missing key as distinct states and decide whether both warn. An explicit empty array may be a deliberate "this task touches nothing" assertion; a missing key is an omission. Record the distinction.

MEASUREMENT VALUE: this task is what makes the problem measurable. Local coverage is 37/38 active tasks with a non-empty file_scope; ~/Projects/BimodalLogic is 27/49, with 22 lacking a usable value (17 missing the key, 5 literal null) spanning 2026-05-11 through 2026-08-26 -- longstanding, not a recent regression. The check must reproduce those counts.

ACCEPTANCE: validate-state.sh reports the missing/empty count and exits 0 in default mode; the promotion criterion is written into the script header; predispatch-review surfaces absent file_scope with the class decision documented; `--repair` does not manufacture `[]` on absent keys; both scripts shellcheck clean per context/standards/shell-strict-mode.md; running against this repo's specs/state.json yields the expected 1-of-38 figure.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


=== ADDENDUM 2026-09-22 (eighth-pass phase 0) ===
Also reject GLOB entries in file_scope at both check sites. Observed 2026-09-14: a `*/agents/**` entry was admitted alongside three tasks editing agent files because lib/file-scope-overlap.sh does not expand globs, so a glob collides with nothing. Neither task creation nor validate-state.sh rejects the shape today (0 glob entries exist in the live file, so the class is latent, not fixed). Treat a glob entry as invisible-by-construction, the same family as an absent or empty field: WARN in validate-state.sh naming the entry, and surface it in orchestrate-predispatch-review.sh Class C.

---

### 162. Formalize Files to modify, harvest it into file_scope at every plan postflight site, and backfill existing tasks
- **Status**: [PLANNING]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 197, Task 213
- **Research**: [162_formalize_files_to_modify_and_harvest_file_scope/reports/01_files-to-modify-harvest.md]

**Description**: Populate `file_scope` at PLAN time by formalizing an existing, universally-followed convention and making it reliably machine-harvestable.

FRAMING -- THIS IS NOT A GREENFIELD FIELD. `**Files to modify**:` is already a de facto universal convention. Verified: present in 10/10 plan files under specs/*/plans/ in this repo (11/12 in ~/Projects/BimodalLogic); already EMITTED by the planner's own phase template at agent-system/extensions/core/agents/planner-agent.md:259 (`**Files to modify**:` followed by `- `path/to/file` - {what changes}`). What is missing is only its FORMALIZATION: context/formats/plan-format.md's per-phase field list (lines 76-95: Goal, Tasks, Timing, Depends on, Verification Tier, Commit Mode, Scope Hypothesis, Owner) does not enumerate it. The task is to formalize the convention and pin a stable grammar, NOT to invent a carrier.

CONSEQUENCE: the harvest has near-total existing coverage to work against immediately, making this substantially lower-risk than a greenfield field would be. Do not design for a sparse-adoption rollout; design for a convention already in place.

COMPATIBILITY CONSTRAINTS (binding -- three existing consumers reference this by name; any grammar settled on MUST keep all three working):
1. agent-system/extensions/core/agents/general-implementation-agent.md:65 -- reads "Files to modify/create per phase" when extracting from the plan.
2. agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:1274,1280 -- the H1 territory block sets `"owned_files": "derive from plan_path's Phase N \"Files to modify\" list"`.
3. agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1335 -- the same territory derivation, ported verbatim.

IMPORTANT NUANCE about consumers 2 and 3: neither parses the list itself. Per the comment at SKILL.md:1274, "The orchestrator does not parse the plan's 'Files to modify' list itself -- it points the agent at the plan/phase location" and the agent derives owned_files from the phase section. So the constraint these two impose is HEADING-NAME STABILITY (the literal string is embedded in a prompt directive handed to an agent), not parser grammar. Changing the heading text would silently break the directive with no parse error. Treat the name as frozen.

GRAMMAR: two punctuation variants exist in practice -- `**Files to modify**:` (64 occurrences) and `**Files to modify:**` (6). This matches plan-format.md's already-documented "Field-punctuation tolerance" rule for per-phase field labels, which states both forms are accepted; the harvester MUST accept both. Settle the list-item grammar against the planner template's emitted shape (`- `path/to/file` - {what changes}`), tolerating the backtick-quoted path and the trailing ` - {description}`.

SCOPE-HYPOTHESIS ALIGNMENT: plan-format.md:251 defines any plan-asserted file list as "a hypothesis requiring implementation-time confirmation, never a fact". The state schema (context/schemas/state-schema.json:227) independently describes file_scope as "prospective, not filesystem-validated". These align: harvesting a plan-time hypothesis into a prospective field is coherent, and the harvest MUST NOT filesystem-validate the paths or drop ones that do not yet exist (new files are exactly what a plan creates). Where a phase carries a `**Scope Hypothesis:**` line, decide whether it informs the harvest or is ignored, and record the ruling.

WORK: (1) add `**Files to modify**:` to plan-format.md's per-phase field list with its grammar, marking it required-or-advisory deliberately; (2) record the three consumers above in plan-format.md as compatibility constraints so a future format change accounts for them, mirroring how that file already lists the three consumers of the phase-heading contract; (3) build the harvester (anticipated: agent-system/extensions/core/scripts/plan-file-scope-harvest.sh) that unions every phase's list into a deduplicated file_scope; (4) wire it into plan postflight, writing via state-write.sh (the single mutex-guarded writer -- do not hand-roll a jq read-modify-write).

DECIDE, DO NOT ASSUME: whether harvest OVERWRITES an existing file_scope or unions into it; whether a plan revision (/revise, a new MM_ plan round) re-harvests; whether a harvest failure is fatal to postflight or a warning (note update-task-status.sh's and state-write.sh --regen-todo's existing posture is a loud warning, not a hard failure).

ACCEPTANCE: plan-format.md enumerates the field with its grammar and its three named consumers; the harvester extracts the correct union from all 10 local plan files under specs/*/plans/ and accepts both punctuation variants; a plan postflight on a task with a plan populates a non-empty file_scope; the three existing consumers are demonstrably unbroken (the heading string is unchanged); shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


=== ABSORBED 2026-09-17 from former task 164 (backfill file_scope for existing tasks); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
One-shot backfill of `file_scope` for existing tasks that lack a usable one, plus an explicit ruling on the tasks the backfill CANNOT reach.

WHY THIS IS REACHABLE: because `**Files to modify**:` is an already-universal convention (10/10 plan files locally, 11/12 in ~/Projects/BimodalLogic, emitted by the planner template at agents/planner-agent.md:259), any task that HAS a plan can be backfilled by reusing the harvester built alongside plan-format formalization. This is not a from-scratch inference problem for that population.

REUSE, DO NOT DUPLICATE: the derivation logic belongs to the harvester script (anticipated agent-system/extensions/core/scripts/plan-file-scope-harvest.sh). The backfill script must call or source it, never re-implement path extraction -- two divergent parsers for one convention is precisely the defect this chain exists to remove.

THE HARD PART -- PLAN-LESS TASKS (decide and record, do not silently leave uncovered): a task with NO plan yet has no "Files to modify" list to harvest, so the plan-based route cannot reach it. In BimodalLogic this is the MAJORITY of the 22 affected tasks -- most are status `not_started` and will never have had a plan. Options to weigh explicitly:
  (a) leave them absent and let plan-time population (the formalized harvest) cover them naturally when they are eventually planned -- zero risk, but leaves the gap open for however long they sit unplanned;
  (b) infer a provisional file_scope from the task description/title, accepting that it is a guess -- note the schema already frames file_scope as "prospective, not filesystem-validated", so a provisional value is not a category error, but a WRONG one is worse than absence because it produces false confidence in the collision guard;
  (c) write an explicit sentinel (e.g. `[]`) to distinguish "deliberately unknown" from "never considered" -- but see the empty-vs-absent distinction, since an empty array may read as "touches nothing" and would suppress the very warning that should stay lit.
RECORD THE CHOSEN DISPOSITION AND ITS REASONING. Leaving this population undiscussed is the failure mode this paragraph exists to prevent.

SAFETY: the backfill mutates specs/state.json across repos. It MUST write via state-write.sh (the single mutex-guarded writer; hand-rolled `jq ... > tmp && mv` sequences are exactly what that script was built to eliminate). It MUST offer a dry-run that prints the proposed per-task diff without writing, and MUST be idempotent -- a second run over an already-backfilled state changes nothing. It must never overwrite a task that already has a non-empty file_scope.

CROSS-REPO SCOPE: decide whether the script targets only the invoking repo or accepts a `--state-file` / repo argument. The measured need is largely in ~/Projects/BimodalLogic, not here, so a repo-local-only tool would not address the motivating case. Note state-write.sh already supports `--state-file` for non-default targets.

ORDERING: this task is a prerequisite for making an absent file_scope admission-relevant. Backfilling before any enforcement tightens is the mitigation that keeps legacy tasks from being blocked.

ACCEPTANCE: dry-run prints an accurate per-task diff and writes nothing; a real run raises this repo's coverage to 38/38 and BimodalLogic's toward 49/49 for the plan-bearing population; re-running is a no-op; tasks with an existing non-empty file_scope are untouched; the plan-less disposition is implemented and its reasoning recorded; shellcheck clean per context/standards/shell-strict-mode.md.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader, so edits there are silently wiped. Backfilled DATA under specs/** is exempt from this rule -- specs/** is the legitimate write target for task-management artifacts. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 139. Forbid concurrent-writer history rewrites: rules and agent contracts, then a concurrency-gated predicate in guard-destructive-git.sh
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 129
- **Research**: [139_forbid_concurrent_writer_history_rewrites/reports/01_forbid-concurrent-writer-rewrites.md]

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


=== ABSORBED 2026-09-22 from former task 140 (Add a concurrency-gated history-rewrite predicate to guard-destructive-git.sh); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

Give agent-system/extensions/core/hooks/guard-destructive-git.sh a SECOND, INDEPENDENT predicate that blocks or loudly warns on history rewrites (`git commit --amend`, `git reset` without `--hard`) when evidence of a concurrent writer exists. This is the enforcement half of the policy its predecessor task establishes in the rules and agent contracts.

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

### 136. Implementation-agent contract corrections: plan-level Status ownership, no fan-out, marker/commit sync, validator catch
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 139

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

=== ABSORBED 2026-09-17 from former task 14 (no fan-out, terminal status, marker/commit sync in implementation agents); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===
=== REVISED 2026-08-24 (refactor survey) ===
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


=== ABSORBED 2026-09-28 (path review, fifth pass) from former task 166 (enforce_required_section_heading_conformance); that task is abandoned into this one. Its text follows verbatim; where it names "the dependency task" or "the sibling task", read this task's other sections. ===

DEFECT: a produced research report used section headings that are semantically correct but lexically non-conforming, so validate-artifact.sh's required-section check failed on an artifact whose authoring agent ALREADY carries a conforming skeleton. This is NOT the "agent has no skeleton at all" class addressed by the lean/formal skeleton work -- here the skeleton is present and correct, and the produced artifact drifted from it.

VERIFIED EVIDENCE.
1. THE CHECK. agent-system/extensions/core/scripts/validate-artifact.sh:20 declares
     REPORT_SECTIONS=("Executive Summary" "Context & Scope" "Findings" "Decisions" "Recommendations")
   and :170-173 matches each with `grep -qE "^##+ ${section}"` -- an any-depth heading PREFIX match, unanchored at the end.
2. THE ARTIFACT. ~/Projects/BimodalLogic specs/461_acquire_goldblatt_1989_varieties_of_complex_algebras/reports/01_acquisition-verified-corpus-status.md, authored 2026-09-07 12:39 -- AFTER that repo's agent reload at 11:13, so by the current deployed agent. task_type=general, therefore written by general-research-agent. `validate-artifact.sh <path> report` without --fix: FAIL, 1 error, "Missing required section: ## Recommendations".
3. WHY IT FAILED. The report does address recommendations, under two headings:
     :331  ## Context Extension Recommendations
     :337  ## Recommended Next Steps (for the plan phase)
   Neither matches `^##+ Recommendations`: the first because the text after "## " begins "Context", the second because "Recommended" is not "Recommendations". Both directions verified by running the validator's exact regex against both literal strings.
4. THE SKELETON IS NOT THE DEFECT. agent-system/extensions/core/agents/general-research-agent.md:277 carries a report skeleton that DOES include a conforming `### Recommendations`, which satisfies `^##+ Recommendations`. The agent departed from its own template when writing a real report.

TWO CONTRIBUTING FACTORS TO EVALUATE (do not assume either is the cause).
(a) BURIAL. In the skeleton, `### Recommendations` is a third-level subsection of `## Findings`, sitting alongside `### Codebase Patterns` and `### External Resources`. Every other required section is top-level. An agent restructuring Findings for a real report gets no signal that this one subsection is load-bearing for validation.
(b) NEAR-MISS TRAP. The same skeleton separately contains `## Context Extension Recommendations`. An agent writing that heading may reasonably believe the Recommendations requirement is met. The observed artifact contains exactly that heading.

DECIDE, do not assume. Candidate remedies, each with a real cost:
  (i)   AGENT-SIDE: state the five required heading strings verbatim in the agent contract and mark them non-paraphrasable. Cheapest; relies on instruction-following, which is precisely what failed here.
  (ii)  SKELETON-SIDE: promote `### Recommendations` to a top-level `## Recommendations`. Structurally removes factor (a); changes the report shape.
  (iii) VALIDATOR-SIDE: relax matching. DANGEROUS -- a substring match would let `## Context Extension Recommendations` satisfy `Recommendations`, converting a true failure into a false pass. Do not weaken a check to make it green.
State the ruling and its reasoning. Combining (i) and (ii) is permitted; (iii) requires an explicit argument that it creates no false passes.

SCOPE. Determine whether this is general-research-agent alone or a shared shape. Enumerate every core agent carrying a report or summary skeleton and machine-check each skeleton's headings against REPORT_SECTIONS/SUMMARY_SECTIONS using the validator's own regex -- not by eye.

NOT IN SCOPE: pre-existing non-conforming artifacts authored before their agent gained a conforming skeleton. Those fail for a different reason and are a separate backfill question.

ACCEPTANCE.
  - The exact failure is reproduced in a fixture (a report carrying `## Recommended Next Steps` and `## Context Extension Recommendations` but no `## Recommendations`) and shown to pass after the chosen remedy.
  - The chosen remedy is recorded with reasoning, including why the validator was or was not changed.
  - If the validator is touched, a fixture proves `## Context Extension Recommendations` ALONE still fails.
  - An enumeration of all core report/summary-writing agent skeletons, machine-checked against the validator's own regex, with any further gaps listed.
  - A real general-type research dispatch produces a report validating with 0 errors and 0 auto-repairs.

CANONICAL SOURCE CONSTRAINT (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/core/. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store by the loader. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== PATH REVIEW 2026-09-28: why the research-report heading task was folded in ===
Both halves are 'an agent skeleton/contract drifts from what validate-artifact.sh enforces': the implementation side (plan-level Status grammar, fan-out, marker/commit sync) and the research side (required-section headings). They serialize on validate-artifact.sh and share one remedy shape (fix the contract text AND make the validator reject the drift), so they are one task with two phases -- research phase first (independent of the git-safety task), implementation-agent phase after the history-rewrite task lands on general-implementation-agent.md.

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

### 51. Move session runtime files out of the specs root and make the reap path run
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 143, Task 209

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

=== EVIDENCE REFRESHED 2026-09-22 (post-/todo measurement) ===
The stranded-file count in THIS repo alone is now 48 (.orchestrator-multi-state-*.json and .return-meta-multi-*.json at the specs/ root), up from 25 measured on 2026-09-08 -- nearly doubled in two weeks, with the oldest surviving entries still present. No reaper ran in between, which is precisely the point: part (3) above is the load-bearing half of this task. Relocation (part 1) and glob widening (part 2) both leave the growth rate untouched; only wiring the reaper into /todo changes it. Treat part (3) as the acceptance-critical deliverable, not as the third of three equals.

=== EVIDENCE REFRESHED 2026-09-28 ===
67 stranded session files at this repo's specs/ root (48 on 2026-09-22, 25 on 2026-09-08), including one .meta-return-sess_*.json written by the superseded convention this task already names as orphaned. Twelve completed tasks await /todo, which is the housekeeping command part (3) wires the reaper into.

---

### 44. Slim commands/task.md, the largest per-invocation context contributor
- **Effort**: 2-4 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87, Task 149, Task 210
- **Research**: [044_slim_task_command_body/reports/01_command-body-extraction-approach.md]
- **Plan**: [044_slim_task_command_body/plans/01_task-command-mode-extraction.md]

**Description**: LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k tokens of imports it pulls in — the largest single per-invocation context contributor found by the context-loading audit. Slim the command body by moving reference material (long option tables, worked examples, edge-case narratives) into lazily-loaded context files under the core extension's context tree, keeping the command body to the decision logic and dispatch instructions an invocation actually needs. Preserve behavior: every mode (--recover, --expand, --sync, --abandon, multi-task creation) must remain fully specified — either inline or via an explicit pointer the executing agent is instructed to follow. Measure before/after bytes and record them in the implementation summary. CONSTRAINTS: all edits target agent-system/extensions/core/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**; do not change command behavior, only where its prose lives.

---

### 43. Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Effort**: 1-3 hours
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 194, Task 257

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

### 29. Generate .mcp.json from extension manifests, then register obsidian-memory through it
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 210, Task 22, Task 241

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
