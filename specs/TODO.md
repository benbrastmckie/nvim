---
next_project_number: 202
---

# TODO

## Task Order

*Updated 2026-09-09. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,29,39,43,44,45,51,74,89,127,129,136,139,162,163,166,167,168,170,172,177,182,183,184,185,187,188,190,191,192,193,194,197,198,199,200,201 | -- | core-agent-system, extensions, literature, ... |
| 2 | 14,30,75,76,140,164,173,174,175,195 | 29,74,139,162,172,194 | core-agent-system, extensions, file-scope-lifecycle |
| 3 | 165 | 163,164 | file-scope-lifecycle |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

44 [PLANNED] — Slim commands/task.md, the largest per-invocation context...
51 [NOT STARTED] — Stop session-scoped orchestration runtime files from...
89 [NOT STARTED] — Apply the mode-gated section convention to the two remaining...
127 [NOT STARTED] — === REVISED 2026-09-01 (backlog streamline: absorbs the...
129 [NOT STARTED] — Empirically audit \b word-boundary grep patterns for...
136 [NOT STARTED] — Stop implementation agents hand-writing the plan-level Status...
139 [NOT STARTED] — Forbid concurrent-writer history rewrites in git rules and...
  └─ 14 [NOT STARTED] — Prevent implementation-agent fan-out from returning...
  └─ 140 [NOT STARTED] — Add a concurrency-gated history-rewrite predicate to...
166 [NOT STARTED] — Stop research reports drifting from validate-artifact.sh's...
170 [NOT STARTED] — Audit and isolate shell test suites from ambient host state...
172 [NOT STARTED] — Define a canonical bounded-wait idiom for detached builds
  └─ 173 [NOT STARTED] — Guarantee lake-build-guard.sh writes a terminal record on...
  └─ 174 [NOT STARTED] — Add a self-excluding orphaned-build-waiter reaper pass to...
  └─ 175 [NOT STARTED] — Enforce waiter teardown in the agent contracts that spawn...
182 [NOT STARTED] — Add a durable redeploy ledger with content-hash and recency...
183 [NOT STARTED] — Decide whether to port the hard-mode loop-guard...
184 [NOT STARTED] — Decide the disposition of the Lean/formal skeleton-plan...
185 [NOT STARTED] — Retarget the remaining historical "Stage N" and "Stage MT-N"...
187 [NOT STARTED] — Decide and enforce one commit-attribution convention across...
188 [NOT STARTED] — Fix orchestrate-predispatch-review.sh Class A false positive:...
190 [NOT STARTED] — Fix cross-session admission blindness for self-modifying...
191 [NOT STARTED] — Stop plan-mandated git-snapshot from reverting task-unrelated...
192 [NOT STARTED] — Close the directory-pathspec hole in guard-destructive-git.sh...
193 [NOT STARTED] — Carry concurrent-sibling territory in base-mode dispatch...
194 [NOT STARTED] — Align lifecycle agent contracts on .orchestrator-handoff.json...
  └─ 195 [NOT STARTED] — Replace iscontractualhandoffwriter allowlist with a...
197 [NOT STARTED] — Honor a forced phase on a terminal task, including one...
199 [NOT STARTED] — Decide and implement the working-tree and build isolation...
200 [NOT STARTED] — Close the consumer-repo deploy propagation gap that leaves...
201 [NOT STARTED] — Close the ephemeral-runtime-file ignore enumeration gap that...

### Extensions

29 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced...
  └─ 30 [NOT STARTED] — TOPIC CORRECTION (backlog streamline 2026-09-01): re-topiced...
43 [NOT STARTED] — Decide and implement how email safety context actually...
74 [NOT STARTED] — Add shared LaTeX build-conflict guard script (detect...
  └─ 75 [NOT STARTED] — Wire build guard into latex extension preflight hook and...
  └─ 76 [NOT STARTED] — Close task-type-keyed hook gap for non-latex agents that...
167 [NOT STARTED] — Make vimtex continuous-build safety always-in-effect via the...

### Literature

39 [PLANNED] — Upgrade Zotero metadata resolution and plan the Zotero 10...

### Neovim

45 [NOT STARTED] — TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task...

### Opencode

22 [RESEARCHING] — Freeze .opencode: silence fragment validation spam and record...
168 [NOT STARTED] — Correct the disproven project-scoped MCP claim in the...

### File Scope Lifecycle

162 [NOT STARTED] — Formalize the existing Files to modify convention in...
  └─ 164 [NOT STARTED] — Backfill filescope for existing tasks and decide the...
    └─ 165 [NOT STARTED] — Decide and implement the admission posture for an absent...
163 [NOT STARTED] — Surface missing and empty filescope in validate-state.sh and...
  └─ 165 [NOT STARTED] — Decide and implement the admission posture for an absent... (see above)

### Lean Extension

177 [NOT STARTED] — Add a dependency-tracing recipe to the lean4 extension context
198 [NOT STARTED] — Mandate git-snapshot --no-revert in the lean implementation...

## Tasks

### 201. Close the ephemeral-runtime-file ignore enumeration gap that lets a live deploy mutex be committed
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. `specs/.deploy-lock/` is a mutex directory belonging squarely to the documented "ephemeral orchestrator runtime state" class, but it is absent from every one of the three places that enumerate that class. As a result a LIVE deploy mutex is tracked by git and gets swept into any commit that stages `specs/`.

PROVEN LIVE, NOT THEORIZED (2026-09-09, ~/.config/nvim). Commit 96fb00a40 contains `specs/.deploy-lock/owner` as a NEW TRACKED FILE. Its contents at commit time were `pid=1635066 / claimed_at=1788958952 / session=unknown`, and process 1635066 was verified still running (`bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh`) at that moment. A live, held mutex is now in history. The commit was an ordinary `git-commit-scoped.sh ... -- specs/` invocation -- the sanctioned narrow-staging form -- so no misuse was involved; the pathspec simply swept an untracked-but-not-ignored runtime file.

THE THREE ENUMERATION SITES, ALL MISSING IT (verify each; do not assume this list is exhaustive).
  1. `core/context/standards/orchestrator-runtime-files.md`, the "Consumer Repo Setup" gitignore block -- the canonical list a consumer repo is told to paste into its own root `/.gitignore` by hand. It carries `**/.lock/`, `**/.events.lock`, `**/.sessions/`, `**/.orchestrator-multi-state*.json` and others, and its own comment names "mutex directories" as an included class. `.deploy-lock/` is simply not there.
  2. `core/scripts/check-runtime-file-tracking.sh` -- the lint that exists SPECIFICALLY to catch this failure. Its Check A ignore-coverage probe list (around lines 31-45) and its Check B tracked-file pattern list (around lines 83-92) both enumerate `.lock/`, `.events.lock` and friends, and neither mentions `.deploy-lock`. So the one mechanism designed to detect an untracked-runtime-file leak is blind to this member of the class.
  3. The consuming repo's own root `/.gitignore`. In ~/.config/nvim it carries `**/.lock/`, `**/.commit-lock/`, `**/.events.lock`, `**/.errors.lock` -- and no `.deploy-lock/`.

WHY THIS IS A CLASS DEFECT AND NOT A ONE-LINE TYPO. Three independent enumerations of one class all drifted the same way, and the lint that should have caught the drift is itself one of the enumerations. Note the pattern already recorded in the over-staging work (task 192), where an enumerated refusal taught the enumeration rather than the principle. The remedy should therefore consider whether these lists can be derived from ONE source rather than maintained in triplicate -- at minimum, make check-runtime-file-tracking.sh's patterns and the standards block provably agree, so a future class member cannot be added to one and forgotten in the others.

WHY IT MATTERS BEYOND TIDINESS. The standards file states the rationale for the whole class: these files "have no freshness gate on read — a git-restored copy would silently corrupt in-flight cycle/churn state". A tracked `.deploy-lock/owner` is exactly that hazard: a checkout, clone, or `git restore` can materialize a mutex naming a PID that does not exist or, worse, one that does and belongs to something else. deploy-headless.sh's lock handling is fail-open with a staleness threshold (DEPLOY_LOCK_STALE_SEC) and will warn-and-proceed, so this degrades rather than deadlocks -- but it can cause a spurious "another session's deploy appears in progress" warning, or a spurious stale-reclaim, on a perfectly clean tree. Establish the actual blast radius as part of the work rather than assuming it is cosmetic.

SCOPE.
  (a) Add `.deploy-lock/` to the standards file's Consumer Repo Setup block, with the same one-class rationale the block already carries.
  (b) Add it to BOTH of check-runtime-file-tracking.sh's lists (the Check A representative-path probe and the Check B tracked-file pattern), and to any test fixture that mirrors them.
  (c) Grep the source store for every OTHER mutex/lock/runtime artifact created at runtime -- `specs/.commit-lock/`, `specs/.sessions/`, task-lock.sh's artifacts, anything under `specs/` created by a script rather than by a task -- and confirm each is present in all three enumerations. Fix any further gaps found; this task's value is mostly in that sweep, not in the single known member.
  (d) Decide and record whether the three enumerations should be derived from one source, and implement that if the cost is proportionate. If not, say why and add a cross-reference comment at each site pointing at the others.

UNTRACKING THE ALREADY-COMMITTED FILE -- HANDLE WITH CARE.
  - The correct remedy is `git rm -r --cached specs/.deploy-lock` (file stays on disk), which is exactly the remediation check-runtime-file-tracking.sh already prints for the `.lock/` class. Do this only when no deploy is in flight.
  - Do NOT delete the lock directory or the `owner` file from disk. It is a live mutex; removing it while a deploy holds it defeats the serialization it provides.
  - Do NOT rewrite history to remove it from commit 96fb00a40. Concurrent writers were active in the session that produced it, and bare history rewrites under concurrent writers are the subject of already-filed work (tasks 139 and 140). The file's presence in one historical commit is harmless; what matters is that it stops being tracked going forward.

MUST NOT. Do not add `.orchestrator-handoff.json` or `.return-meta.json` to any ignore list -- the standards file states explicitly that those are durable, freshness-gated provenance and MUST stay tracked; several are legitimately tracked today. Do not attempt to deliver a repo-root `.gitignore` from the source store: the standards file documents why that cannot work (`root_files` deploys into the consumer's `.claude/`, so a `specs/`-rooted pattern would resolve to `.claude/specs/...` and match nothing). The consumer-side `.gitignore` edit stays a documented manual step.

ACCEPTANCE. `.deploy-lock/` (and every other gap the (c) sweep finds) is present in the standards block and in both of check-runtime-file-tracking.sh's lists. Running check-runtime-file-tracking.sh against a repo whose tree contains a tracked `specs/.deploy-lock/owner` FAILS with the `git rm -r --cached` remediation line, and passes once untracked -- demonstrated, not asserted. The nvim repo's own root `.gitignore` carries the new pattern and the tracked file is untracked via `git rm --cached` at a moment when no deploy is in flight, with the on-disk file left intact. shellcheck clean per context/standards/shell-strict-mode.md.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


FOOTPRINT NOTE -- READ BEFORE STARTING. Task 51 ("move session state files out of specs/ root") declares BOTH of this task's files in its own file_scope: context/standards/orchestrator-runtime-files.md and scripts/check-runtime-file-tracking.sh. That task relocates session-scoped runtime files into a dot-prefixed subdirectory and will necessarily rewrite the same enumerations this task corrects. No blocking dependency is declared between them, deliberately: this task is small and has a live proof, task 51 is large and not started, and the file-footprint admission gate serializes them at dispatch regardless. Whichever lands SECOND must reconcile -- specifically, it must re-verify that every class member appears in the standards block, in both of check-runtime-file-tracking.sh's lists, and in the consumer .gitignore guidance, rather than assuming its own view of the lists is current. If task 51 lands first and has already relocated the artifacts, re-derive the (c) sweep against the NEW paths before concluding this task is a no-op.

---

### 200. Close the consumer-repo deploy propagation gap that leaves fixed defects live in deployed trees
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. A defect fixed in the source store and marked completed can remain live indefinitely in a consumer repository's deployed `.claude/` tree, where it continues to mislead every agent that reads it. Nothing enforces propagation, and the only detector is opt-in and report-only.

OBSERVED LIVE (2026-09-09). A lean-implementation-agent dispatch in ~/Projects/BimodalLogic followed its own deployed agent definition's documented build command and got exit 77 (`build mode requires a lake subcommand`), because the deployed copy read `lake-build-guard.sh build --timeout 1800 -- 2>&1` -- an empty lake-argument vector that can never launch a build.

THAT EXACT DEFECT WAS ALREADY FIXED AND CLOSED. Task 176 ("Fix the documented lake-build-guard full-build invocation across the lean extension") corrected precisely these call sites and is marked completed. Verified by direct comparison:

  agent-system/extensions/lean/agents/lean-implementation-agent.md:253   (SOURCE, correct)
    bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- build 2>&1
  /home/benjamin/Projects/BimodalLogic/.claude/agents/lean-implementation-agent.md:253   (DEPLOYED, stale/broken)
    bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- 2>&1

The same divergence holds for lean-implementation-hard-agent.md:392, rules/lean4.md:51, and skills/skill-lake-repair/SKILL.md:81. So no documentation fix is needed in the source store -- it is already correct. The defect is entirely one of PROPAGATION. Do not "re-fix" the source store; confirm it is correct and leave it alone.

THE STALENESS IS PARTIAL, WHICH IS THE DANGEROUS PART. In the same deployed tree, `core/scripts/git-snapshot.sh` is BYTE-IDENTICAL between source and deploy, while `lean/agents/lean-implementation-agent.md` differs. An operator (or agent) who spot-checks one file and concludes "the deploy is fresh, so the source store is the right edit target" reaches a correct conclusion about the edit target for the wrong reason, and will not suspect that a DIFFERENT file in the same tree is months out of date. This exact reasoning was performed during the observing session. Any remedy must make partial staleness visible, not just whole-tree staleness.

ROOT CAUSE, CONFIRMED IN THE SOURCE. The detector exists but is deliberately inert by default:
  - `agent-system/extensions/core/scripts/check-consumer-freshness.sh` exists and can report STALE/CANNOTVERIFY rows per consumer repo.
  - In `deploy-headless.sh` it fires ONLY behind `--consumer-report` (`CONSUMER_REPORT=false` by default). Task 180 made it opt-in on purpose, for a good reason: on the blocking redeploy-checkpoint path it walked ~50 repositories, cost ~10 minutes of wall clock, and produced output the gate could not act on.
  - The script's own comments state the scan "is report-only and can NEVER change this script's exit code", and that deploy-headless.sh never redeploys into a consumer -- the documented remedy is for a human to run the deploy manually in each stale repo.
So the design is: detect only if asked, never act, and rely on a human remembering. The observed defect is that design working exactly as specified.

THIS IS NOT A REQUEST TO REVERT TASK 180. Putting a 10-minute unactionable walk back on a blocking gate would re-create a worse problem. The question is how to close the propagation gap WITHOUT that cost. Weigh at least these, and recommend:
  (a) PULL-SIDE FRESHNESS CHECK. Have the consuming repo verify its own `.claude/` tree against the source store at a cheap, natural moment -- e.g. skill preflight in `core/scripts/skill-base.sh`, or dispatch time -- rather than having the source repo push-scan 50 consumers. This inverts the cost: each repo checks only itself, only when it is actually being used. Strongly consider this as the primary direction.
  (b) CHEAP WHOLE-TREE FINGERPRINT. A single content hash or manifest digest per deployed extension, so "is this tree current?" is one comparison instead of a file walk -- and so PARTIAL staleness is caught, which a timestamp or a single-file spot-check will not catch.
  (c) MAKE THE SIGNAL ACTIONABLE. If a stale consumer is detected at dispatch time, decide what happens: warn loudly in the dispatch brief, auto-redeploy, or refuse the dispatch. An unactionable warning is what already exists and it did not work.
Do not pre-commit to one; measure the cost of the cheap check and justify the choice.

SCOPE BOUNDARY. Detection and signalling of consumer staleness, plus whatever minimal action the recommendation supports. Not in scope: re-fixing the lean docs (already correct at source), and redeploying every consumer repo as a data-migration exercise. Bringing ~/Projects/BimodalLogic's tree current is a reasonable one-line verification step at acceptance time, not the deliverable.

MUST NOT. Do not put an unbounded consumer walk back on any blocking gate path. Do not edit `.claude/**` in any repo by hand -- a stale deployed tree is fixed by redeploying it, never by hand-patching it, and hand-patching would additionally mask the very divergence this task exists to detect. Do not change the lean extension's already-correct source documentation.

ACCEPTANCE. A consuming repo whose deployed `.claude/` tree diverges from the source store in even ONE file is detected, cheaply, at a moment when the information can still change what an agent does -- demonstrated by a fixture that reproduces the observed shape (one file identical, one file stale, in the same tree). The chosen remedy's wall-clock cost is measured and shown not to reintroduce the regression task 180 removed. The recommendation and its rejected alternatives are recorded. shellcheck clean per context/standards/shell-strict-mode.md. Finally, verify by redeploying into ~/Projects/BimodalLogic that the four stale lean call sites there now match source.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 199. Decide and implement the working-tree and build isolation posture for concurrent same-repo dispatches
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

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

---

### 198. Mandate git-snapshot --no-revert in the lean implementation agent contracts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/lean/ (never .claude/**).

DEFECT. The lean implementation agent contracts say NOTHING about git-snapshot.sh. Verified by grep against the source store: `orchestrator_mode`, `git-snapshot` and `no-revert` each appear ZERO times in agent-system/extensions/lean/agents/lean-implementation-agent.md. A lean implementation dispatch that reaches for a pre-work backup therefore finds no guidance at all and lands on the script's DEFAULT mode, which reverts the working tree repo-globally.

OBSERVED LIVE (2026-09-09, ~/Projects/BimodalLogic, tasks 574 and 575 dispatched concurrently as lean-implementation-agent into ONE shared working tree). The 575 dispatch ran `git-snapshot.sh 575` in default mode while the 574 dispatch was concurrently editing the same tree. Default mode runs `git stash push -u` repo-globally with NO pathspec, so it stashed away the SIBLING dispatch's uncommitted work: 574's `.return-meta.json`, `.claude-extensions.json`, and 7 lines of `specs/events.jsonl`. The 575 dispatch noticed the over-capture and restored from `stash@{0}` (kept, not dropped), so nothing was ultimately lost -- but detection and repair depended ENTIRELY on the agent happening to notice. A less attentive dispatch proceeds on a silently reverted tree with no error at any layer.

THIS IS A CALLING-CONVENTION GAP, NOT A SCRIPT BUG. git-snapshot.sh already documents the hazard loudly in its own header ("WARNING: default and --branch modes REVERT the working tree"; "Despite the name, this script is NOT read-only in its default or --branch modes") and already implements the correct alternative: `--no-revert`, which builds a durable stash object via `git stash create` + `git stash store` WITHOUT touching the working tree, described in the header as the mode for "when you want a durable backup and intend to KEEP WORKING". agent-system/extensions/core/agents/general-implementation-agent.md ALREADY calls it correctly with `--no-revert` and explains why. The lean agents were simply never given the same bullet.

CORROBORATION THAT THIS RECURS. `git stash list` in ~/Projects/BimodalLogic currently holds 44 entries, 32 of them named `git-snapshot-*`, accumulated across many sessions. This is not a one-off.

SCOPE -- DELIBERATELY SMALL, SHIPS ON ITS OWN. Add to both lean implementation agent contracts an explicit instruction that `git-snapshot.sh` MUST be invoked with `--no-revert` whenever the dispatch is running under `orchestrator_mode` (i.e. whenever a concurrent sibling dispatch may share the working tree), and SHOULD be preferred generally when the agent intends to keep working after the snapshot. State the reason in one line -- default mode reverts the tree repo-globally and will capture a sibling's in-flight edits -- so the bullet teaches the hazard rather than only the incantation. Mirror the wording already used in core/agents/general-implementation-agent.md rather than inventing a second phrasing.

RELATIONSHIP TO OTHER FILED WORK -- READ BEFORE STARTING.
  - Task 191 ("Stop plan-mandated git-snapshot from reverting task-unrelated uncommitted work") owns the SCRIPT-LEVEL remedy in core/scripts/git-snapshot.sh plus core/rules/git-workflow.md and the plan-format/planner emission path. This task deliberately does NOT touch any of those files. A contract bullet is the cheap interim mitigation that can land immediately; it is explicitly NOT a substitute for the runtime guard, because a bullet can be forgotten. Both are wanted.
  - Task 191's currently-recorded design direction keys the proposed refusal on "tracked paths OUTSIDE the task's declared file_scope". Note for that task, and record it in this task's summary: that predicate does not cleanly cover the concurrent-sibling case observed here, where a sibling's edits may fall INSIDE an overlapping declared scope. A live-concurrent-dispatch predicate is a distinct condition from an out-of-file_scope predicate. Surface this; do not implement it here.

MUST NOT. Do not edit core/scripts/git-snapshot.sh, core/rules/git-workflow.md, or the plan format -- those belong to task 191 and would collide. Do not weaken or remove `--no-revert`. Do not `git stash drop`/`clear` any existing entry.

ACCEPTANCE. Both lean implementation agent contracts instruct `--no-revert` under orchestrator_mode, with the one-line rationale. The wording matches the existing core agent contract. The lean extension is redeployed and the regenerated `.claude/**` copies carry the bullet (see the deploy-propagation task -- a source-store fix that never reaches the consuming repo changes nothing for a running agent).

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.


SCOPE CEILING -- KNOW WHAT THIS DOES NOT FIX. The concurrent-dispatch root cause produces three distinct failure modes: working-tree revert (this one), cross-task commit bleed via whole-path staging on a shared file, and .lake build contention. The isolation-posture task enumerates all three with verified evidence and decides the structural remedy. This contract bullet addresses ONLY the working-tree revert mode, and only by convention rather than by construction. Do not let it close out the other two, and do not let its landing be read as evidence that the shared-tree posture is safe.

---

### 197. Honor a forced phase on a terminal task, including one already archived by /todo
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 196

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy tree regenerated from the source store; hand edits there are silently wiped). Consumer repos pick the change up via their own redeploy.

REQUEST. The user wants `/orchestrate N --research` to work on a task that is already complete. Today it silently does nothing.

DEFECT 1 -- ORDERING. In scripts/orchestrate-cycle-plan.sh, is_terminal_status() is defined at lines 1123-1128; the all-terminal check at lines 1138-1148 sets stop_reason="all_terminal" and calls emit_and_exit as soon as every named task is terminal, and the eligibility loop at line 1156 independently `continue`s past any terminal task. BOTH run BEFORE per-task force_phases consumption, which does not begin until line 1324 ("(f) Per-task force_phases consumption"). scripts/orchestrate-triage-classify.sh independently returns group:"terminal" for completed/abandoned/expanded at lines 326-329. So `/orchestrate 42 --research` on a completed task short-circuits to all_terminal and dispatches nothing. The blocker is ordering, not intent: --research/--plan/--implement already parse (parse-command-args.sh line ~152), already thread through as --force-phases (orchestrate-cycle-plan.sh lines 288, 429-452, 504), and already consume per-task from force_phases_remaining (lines 1324-1340, 1710). Their documented contract (commands/orchestrate.md lines 25-26 and 51-53) is: canonical lifecycle order regardless of typed order, a new MM_ artifact round, NEVER regresses status, stop after the last named phase.

DEFECT 2 -- ARCHIVED TASKS, AND IT IS NOT FIXED BY REORDERING. /todo archives every terminal task OUT of .active_projects. orchestrate-cycle-plan.sh already handles this: lines 405-413 read ${STATE_FILE%state.json}archive/state.json, flattening completed_projects and archived_projects and normalizing status (completed/abandoned/expanded preserved verbatim; any archive-only status such as orphan_archived mapped to completed), and lookup_project() at lines 415-425 consults the archive whenever a number is absent from active projects, with active entries winning. scripts/orchestrate-triage-classify.sh does NOT: line 316 binds `($state_arr[0].active_projects // []) as $all` and nothing else, so an archived task hits the null-entry branch at lines 321-323 and returns group:"skip", reason "not found in state.json". The two scripts therefore disagree about the same archived task -- cycle-plan resolves it to completed, the classifier calls it nonexistent. Reordering the terminal check alone leaves the archived case broken. A fix that closes only the ordering defect is INCOMPLETE and must not be accepted.

DECISIONS THE RESEARCH PHASE MUST WEIGH AND RECORD -- DO NOT PRE-DECIDE.
(a) How a terminal task with a pending forced phase becomes eligible: reorder force_phases consumption ahead of the all-terminal check and the eligibility loop, versus computing a "has a pending forced phase" set up front and exempting exactly those tasks from both terminal `continue`s. Weigh which keeps the (b)/(c)/(f) section structure and the mt_ state-writing order coherent, since force_phases_remaining seeding currently writes state that the earlier checks do not read.
(b) What status a completed task holds while a forced phase runs, and what it holds afterward. Keeping it completed while a new MM_ round is written is FAVORED, per the existing never-regresses-status clause, but must be justified against how orchestrate-cycle-postflight.sh's monotonic-max clamp and update-task-status.sh's map_status actually behave on a completed task -- verify rather than assume.
(c) Whether --implement forced on a completed task is permitted on the same terms as --research, or needs a stricter gate (re-running an implementation against already-implemented work is materially riskier than re-running research or planning). Decide for all three flags explicitly; do not fix --research and leave the other two undefined.
(d) Whether the classifier gains the archive read directly (mirroring lookup_project's existing shape, which is the natural fix) or receives resolved statuses from its caller -- and whether it should keep returning group:"terminal" for a forced-phase task or gain a distinct verdict. Note that the research-first default task lands first and may already have established a precedent for feeding the classifier new inputs; reuse that answer rather than inventing a second one.
(e) Whether the all_terminal stop message must distinguish "terminal and nothing forced" (a correct stop) from "terminal but a forced phase is pending" (which must no longer stop at all), and whether the archive read should ever WRITE -- un-archiving a task versus reading it read-only and leaving /todo's archive untouched. Read-only is FAVORED but must be justified against how the eventual completion of a forced round on an archived task is recorded.

SCOPE. Implement the chosen fix across both defects together. Add fixture coverage in scripts/tests/test-orchestrate-cycle-plan.sh for a completed task with --force-phases research (must dispatch, not stop at all_terminal -- note line 1041 already has an all_terminal assertion whose fixture must remain valid), and for a completed-and-archived task with --force-phases research. Add coverage in scripts/tests/test-orchestrate-triage-classify.sh for the archived-task lookup. Update commands/orchestrate.md so the --research/--plan/--implement rows state plainly whether they apply to terminal and archived tasks, and update docs/architecture/orchestrate-state-machine.md's terminal-state handling to match.

MUST NOT. Do not edit .claude/** . Do not make terminal tasks eligible for ORDINARY dispatch -- only an explicitly forced phase may reach one; an /orchestrate with no phase-forcing flag must still stop with all_terminal on a fully terminal set. Do not regress a completed task's status as a side effect of the fix. Do not change the not_started default routing -- that is the companion task's territory; this task lands second and builds on it. Do not write task numbers into any deliverable outside specs/. shellcheck clean per context/standards/shell-strict-mode.md.

ACCEPTANCE. /orchestrate N --research on a completed task in active_projects dispatches a research round and writes a new MM_ artifact. The same on a completed-and-ARCHIVED task also dispatches, with the classifier and cycle-plan agreeing on its status rather than one calling it nonexistent. /orchestrate N with no forcing flag on the same terminal task still stops with all_terminal and dispatches nothing. The chosen posture for --plan and --implement on terminal tasks is implemented and documented, not left undefined. Fixtures cover the active-terminal, archived-terminal, and unforced-terminal cases. Full gate set green: test-orchestrate-cycle-plan.sh, test-orchestrate-triage-classify.sh, check-task-references.sh.

---

### 196. Make research the default first phase for an un-researched task unless --fast is given
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Plan**: [196_research_first_default_unless_fast/plans/01_research-first-default-unless-fast.md]
- **Summary**: [196_research_first_default_unless_fast/summaries/01_research-first-default-unless-fast-summary.md]

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy tree regenerated from the source store; hand edits there are silently wiped). Consumer repos pick the change up via their own redeploy.

REQUEST. The user wants /orchestrate to research first whenever a task has not already been researched, UNLESS --fast was passed. Today the system implements the exact opposite, deliberately.

CURRENT BEHAVIOR, AND WHY IT IS NOT AN ACCIDENT. The completed "research on demand" work (Stage A.8) flipped not_started from research to plan on purpose: a specification-shaped task reaches [PLANNED] in one dispatch instead of two, and planner-agent regains research on demand by returning a needs_research verdict carrying a focused question list. That prior decision, its rationale, and its hazards are recorded in specs/150_research_on_demand/ (report, plan, summary) and MUST be read before touching anything. This task inverts that default; it does not get to pretend the default was arbitrary.

VERIFIED ANCHORS (each confirmed on disk).
- scripts/orchestrate-triage-classify.sh:330-333 -- the live jq classifier row: `elif $status == "not_started" then ... group:"plan" ... reason "...routes to plan (research on demand -- the planner requests research via needs_research if the description does not suffice)"`.
- scripts/orchestrate-triage-classify.sh:409 -- the blocked-discharge previous_status re-routing table: `(if $p == "not_started" then "plan"`.
- scripts/orchestrate-triage-classify.sh:60 -- the header routing table row `| not_started | plan | plan |`, and the line-101 note about the shared not_started/researched/planned ladder.
- scripts/orchestrate-cycle-plan.sh:1300-1313 -- the degraded-classifier inline fallback table (`not_started) triage_group[$t]="plan"`, `researching) triage_group[$t]="research"`), carrying its own "research on demand -- Stage A.8" comment. It must stay in agreement with the live classifier; a fixture already asserts exactly that parity.
- scripts/orchestrate-cycle-plan.sh:1737-1743 -- the research_questions --focus wiring at the research-dispatch build call.
- Doc/contract surfaces asserting the current default: docs/architecture/orchestrate-state-machine.md lines 25-26 (Complete State Table), 77, 90, 117, 161-162 (ASCII diagram plus the "merges into a single dispatch plan node" prose), 305 and 324 (worked-example flows); agents/general-research-agent.md and agents/planner-agent.md (the needs_research contract); commands/orchestrate.md line 45 (the --fast row of the flag table); context/standards/status-markers.md (the documented two-phase default and [RESEARCHING]'s two producers).

THE PLUMBING PROBLEM, MEASURED. scripts/orchestrate-triage-classify.sh accepts NO effort/--fast argument whatsoever -- `grep -c 'fast\|effort'` on that file returns 0. scripts/orchestrate-cycle-plan.sh parses --fast at line 293 into effort_flag and forwards it to command-route-agent.sh (line 1509) and orchestrate-build-dispatch.sh (line 1729); today --fast carries model-and-agent-selection semantics ONLY, with no phase-skipping meaning anywhere. Making the default effort-aware therefore requires a structural choice.

DECISIONS THE RESEARCH PHASE MUST WEIGH AND RECORD -- DO NOT PRE-DECIDE.
(a) Where effort-awareness lives: give orchestrate-triage-classify.sh a new effort input (keeping the "one code path" classification discipline its own header asserts) versus having orchestrate-cycle-plan.sh post-adjust the classifier's verdict for --fast. Weigh both against that header's explicit one-code-path contract and against the degraded-fallback parity fixture, which will need the same answer applied twice if the caller post-adjusts.
(b) What "has not already been researched" means precisely. not_started is the obvious case, but decide explicitly for: researched (already has a report -- must NOT re-research), planned/implementing/partial (progressed past research), and the blocked-discharge previous_status ladder at line 409, which mirrors the live row and will otherwise silently keep the old default.
(c) What becomes of the needs_research verdict. Under research-first it is largely redundant on the default path but is precisely the escape hatch that keeps --fast safe -- a --fast task whose description turns out to be insufficient still needs the planner able to ask. Retaining it on the --fast path is FAVORED but must be justified, not assumed; decide and record whether it also survives on the now-default research-first path or becomes unreachable there.
(d) Whether --fast's new phase-skipping semantics should be documented as a second, independent meaning of the flag or whether a distinct flag would be clearer -- and if --fast is kept, state plainly in commands/orchestrate.md that it now changes WHICH PHASES RUN, not merely reasoning depth.

SCOPE. Implement the chosen design across every site that encodes the default, keeping the live classifier and the degraded fallback table in agreement. Update the routing table in the classifier header, the state-machine doc's state table, ASCII diagram, prose footnote and both worked examples, the planner and research agent contracts, the --fast row of the command flag table, and status-markers.md's two-phase-default narrative. Update the fixtures that assert the current default deliberately and with a comment naming the new contract: scripts/tests/test-orchestrate-triage-classify.sh lines 97-107 (the single-engine sandbox probe), 224-240 (the mt-engine not_started row), 298-323 (the blocked-discharge previous_status row); scripts/tests/test-orchestrate-cycle-plan.sh Group 13 (lines 1430-1485, degraded-fallback parity) and Group 14 (lines 1490+, research_questions --focus wiring). Add NEW coverage for the --fast path, which has no fixture today.

MUST NOT. Do not edit .claude/** . Do not silently delete the needs_research verdict, its postflight case arm, its update-task-status.sh map_status arm, or the research_questions field and its state-schema.json admission -- a decision to retire any of them must be explicit, recorded, and complete rather than partial (the prior work documents that an unhandled needs_research falls into orchestrate-cycle-postflight.sh's catch-all and produces halt=true plus an OFF_SCHEMA_STATUS defect). Do not change terminal-status handling or forced-phase consumption -- that is the companion task's territory and the file scopes overlap by design, so this task lands first. Do not write task numbers into any deliverable outside specs/ (see .claude/rules/no-task-references-in-deliverables.md). shellcheck clean per context/standards/shell-strict-mode.md.

ACCEPTANCE. Without --fast, a not_started task dispatches research, then plan, then implement; a task at researched or later never re-researches. With --fast, a not_started task still dispatches straight to plan, and the planner can still send it back via needs_research if the chosen design retains that arm. The degraded fallback table and the live classifier agree on every row, proven by the existing parity fixture. The blocked-discharge previous_status ladder agrees with the live not_started row. Every doc surface listed above describes the new default with no residual claim that plan-first is the default. New fixtures cover both the --fast and non---fast not_started paths. Full gate set green: test-orchestrate-triage-classify.sh, test-orchestrate-cycle-plan.sh, lint-agent-contracts.sh, check-task-references.sh.

---

### 195. Replace is_contractual_handoff_writer allowlist with a dispatch-derived predicate
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 194

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**, a disposable deploy tree regenerated from the source store; hand edits there are silently wiped). Consumer repos pick the fix up via their own redeploy.

DEFECT. is_contractual_handoff_writer() in agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh returns 0 for exactly two hard-mode agents:

  is_contractual_handoff_writer() {
    case "$1" in
      cslib-implementation-hard-agent|lean-implementation-hard-agent) return 0 ;;
      *) return 1 ;;
    esac
  }

Every other agent falls through to `return 1` and is treated as a non-writer. Consequently all base-mode implementation agents -- general-implementation-agent (the default for general/meta/markdown and, via noncore-exact routing, formal task types), lean-implementation-agent, typst-implementation-agent -- plus every research and plan agent are excused when .orchestrator-handoff.json is absent. No HANDOFF_STALE_OR_ABSENT defect is recorded via system-defect-record.sh, and a real failure goes unattributed.

OBSERVED LIVE (evidence, not hypothesis). An /orchestrate implement dispatch to general-implementation-agent died on context exhaustion ('Prompt is too long') without writing a handoff. Postflight emitted verbatim:

  [orchestrate] WARN: agent name 'general-implementation-agent' is not on the contractual handoff-writer allowlist -- treated as a non-writer, no defect recorded for the absent handoff. If 'general-implementation-agent' is a genuine new hard-mode writer, add it to is_contractual_handoff_writer() in this script.

The run then degraded silently to heading-scan recovery (plan headings showed 16/16 phases closed) and no defect row was recorded.

THE DECISION IS NOT PRE-MADE -- WEIGH (a) AGAINST (b) IN RESEARCH.
  (a) Extend the hardcoded allowlist to cover every lifecycle agent.
  (b) Invert the predicate so writer status derives from whether the dispatch supplied a handoff_path, eliminating the agent-name list entirely and making the contract self-maintaining as new agents and extensions are added.

Option (b) is FAVORED but must be justified, not assumed. The case for it: the existing list has already drifted behind the agent roster, which is the proximate cause of the observed miss. The structural support: skill-orchestrate/SKILL.md Move 3 loops over .dispatch[] rows ONLY and states outright that an aux_dispatch[] row never reaches Move 3; Move 2 supplies handoff_path to every dispatch[] row and deliberately omits the key for aux rows. So every agent that reaches postflight is, by construction, a handoff-expected dispatch.

THE WRINKLE THAT MUST BE RESOLVED. Postflight does not receive handoff_path as an argument. It derives handoff_file itself from --task-dir. Option (b) therefore requires choosing between two concrete shapes, and the research phase must pick one and record why:
  - Treat 'reached postflight at all' as the predicate (simplest; correct today given the Move 3 dispatch[]-only loop, but silently depends on that invariant holding).
  - Thread an explicit --handoff-expected true|false flag from the dispatch row through skill-orchestrate's Move 3 call site (more plumbing; preserves the distinction explicitly if an aux row ever starts reaching postflight).
Assess both against how postflight actually receives dispatch metadata today -- its full CLI contract is documented in its own header Usage block.

SCOPE. Implement the chosen fix. Replace the now-misleading WARN text at the fall-through branch, which currently instructs the reader to 'add it to is_contractual_handoff_writer() in this script' -- guidance that will be wrong under either fix. Update the D1 header comment block, which asserts the allowlist is 'the complete, closed set of contractual writers today'. Add fixture coverage to scripts/tests/test-orchestrate-cycle-postflight.sh for the absent-handoff branch under a base-mode lifecycle agent, which is the exact case that produced no defect row in the observed run.

DEPENDS ON the lifecycle-agent contract alignment task, which must land first: widening detection ahead of the stated obligation would record defects against agents whose contracts never asked them to write a handoff.

MUST NOT. Do not weaken the mtime staleness gate, the dispatch_seq identity gate, or the fail-closed 9999999999 sentinel -- this change concerns only the ABSENT-handoff branch, never the present-but-stale or present-but-mismatched branches, which already record unconditionally. Do not edit agent contract files (the companion task's territory; the file scopes are deliberately disjoint). Do not write task numbers into any script or skill deliverable (see .claude/rules/no-task-references-in-deliverables.md).

ACCEPTANCE. An absent .orchestrator-handoff.json from any lifecycle dispatch -- base mode included -- records a HANDOFF_STALE_OR_ABSENT defect. An aux dispatch still records none. The fixture reproduces the observed general-implementation-agent case and demonstrates the defect row is now written. The WARN text and D1 header comment no longer instruct the reader toward a removed or superseded mechanism. shellcheck clean per context/standards/shell-strict-mode.md.

---

### 194. Align lifecycle agent contracts on .orchestrator-handoff.json writing
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/*/agents/ (never .claude/**, a disposable deploy tree regenerated from the source store; hand edits there are silently wiped).

DEFECT. The handoff-writing obligation is asserted by orchestrate-cycle-postflight.sh's detection logic but is NOT uniformly stated in the agent contracts it judges. Several agents that are routinely dispatched through a dispatch[] row -- and therefore reach postflight, where an absent .orchestrator-handoff.json is a real failure signal -- carry no statement of the obligation at all.

STARTING EVIDENCE (measured 2026-09-09 by counting '.orchestrator-handoff.json' occurrences in each agent's own contract file under agent-system/extensions/*/agents/):
  - planner-agent: 0
  - lean-implementation-agent: 0
  - typst-implementation-agent: 0
  - general-research-agent: 2
  - general-implementation-agent: 5
  - lean-implementation-hard-agent: 7

THIS COUNT IS A STARTING POINT, NOT A VERIFIED-COMPLETE ROSTER. It samples six agents only. The audit must independently enumerate EVERY agent reachable via a dispatch[] row -- research, plan, and implement phases, across core and all loaded extensions -- rather than trusting the six above. Use skill-orchestrate/SKILL.md Move 2 and the routing tables in each extension manifest.json (routing_agents / routing_agents_hard) to derive the true reachable set; a mention count of zero is evidence of a missing contract statement, and a nonzero count is not by itself evidence that the statement is correct or complete.

WHY THIS COMES FIRST. The companion task widens postflight's contractual-writer predicate so that an absent handoff from a lifecycle agent is recorded as a HANDOFF_STALE_OR_ABSENT defect instead of being silently excused. Widening detection BEFORE the contracts state the obligation would flood errors.json with defect rows attributed to agents that were never told to write a handoff -- correct detection against an unstated obligation. This task establishes the obligation so the widened detection lands on a contract that actually exists.

SCOPE. For each agent in the reachable set that lacks the obligation, add an explicit contract statement: it MUST write .orchestrator-handoff.json to the task directory named by its dispatch context's handoff_path, on every dispatch where orchestrator_mode is true. Match the wording and placement already used by the agents that state it correctly (general-implementation-agent and lean-implementation-hard-agent are the fullest existing examples) rather than inventing a new phrasing. Note the asymmetry to preserve: an aux_dispatch[] row is deliberately given NO handoff_path key and never writes a handoff -- any contract wording must not oblige an agent dispatched in that mode.

MUST NOT. Do not modify orchestrate-cycle-postflight.sh or the predicate itself -- that is the companion task's territory and the two file scopes are deliberately disjoint. Do not weaken or restate the aux-dispatch exemption. Do not write task numbers into any agent contract (see .claude/rules/no-task-references-in-deliverables.md).

ACCEPTANCE. Every agent reachable via a dispatch[] row carries an explicit, consistently-worded handoff-writing obligation naming .orchestrator-handoff.json and its handoff_path source. The audit records the full enumerated reachable set and the derivation method, so a future reader can re-verify completeness without re-deriving it. The aux-dispatch exemption remains intact and is stated where relevant.

---

### 193. Carry concurrent-sibling territory in base-mode dispatch briefs, the only channel that reaches a running dispatch
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. In BASE-MODE multi-task /orchestrate, a dispatched agent is never told that concurrent sibling dispatches exist, which files they own, or how it must sequence against them -- and the orchestrator cannot tell it later, because messages sent to a running dispatch do not arrive until after it finishes. The dispatch brief is therefore the ONLY channel that reaches a concurrent agent, and it currently carries no territory information at all.

THE MECHANISM ALREADY EXISTS AND IS WIRED FOR HARD MODE ONLY -- THIS IS NOT NEW FUNCTIONALITY. orchestrate-build-dispatch.sh already accepts `--territory` and emits a "## Territory" section into the brief (lines 392-399), and already pulls in context/contracts/territory.md as a core contract when it is set (line 263). The contract file exists. But orchestrate-cycle-plan.sh populates it at exactly one call site (line 1735) from `h1_territory`, and that whole block is gated on hard mode: line 1555 `if [ "$hard_mode" = "true" ]`, line 1561 `[ "$hard_mode" != "true" ] && continue`. The script's own comment at lines 1731-1733 states it outright: "only ever set for a hard-mode implement candidate ... absent from every base-mode call." So the default concurrent path -- plain `/orchestrate A,B,C` -- dispatches siblings onto one shared working tree with each one structurally unaware of the others.

OBSERVED LIVE (2026-09-08, ~/Projects/BimodalLogic, `/orchestrate 562,542,193`, base mode). Two lean4 implementation dispatches ran concurrently on one tree with no territory in either brief. Consequences, all traceable to that single gap:
  - A tree-wide rename dispatch and a two-file proof-tactic sweep collided on FormalSystem/Metalogic/Soundness.lean. Commits absorbed each other's uncommitted work in both directions (ea1a561c9, 357212808).
  - One dispatch ran git-snapshot.sh in its reverting default mode and reverted the other's in-flight edits plus unrelated user files.
  - One dispatch reported the other for a file_scope breach that had not happened; the three files it cited were its own rename, identifiable by `git log -1`. It had no way to know a sibling existed, let alone what that sibling owned.
  - Full-package builds from one dispatch elaborated the other's uncommitted broken edits, so build results were unattributable in both directions, and one dispatch's build held the guard lock while the other's queued behind it.
The orchestrator detected every one of these and sent corrective messages mid-flight. ALL FIVE were delivered to the dispatch in a single batch AFTER it had completed all twelve of its phases and committed. The agent confirmed it never saw any of them during execution. Corrections that arrive after completion are not corrections.

THE TWO HALVES, BOTH IN SCOPE.
(1) POPULATE TERRITORY IN BASE MODE. Decide what a base-mode territory payload should contain and emit it. At minimum the concurrently-dispatched sibling task numbers and their declared file_scope; consider also the sequencing rationale when one sibling's work is non-idempotent over another's. Note the h1 payload's shape at orchestrate-cycle-plan.sh:1615 as prior art, but do not assume the hard-mode payload is the right base-mode payload -- hard mode's H7 territory is about parallel phase ownership within one task, which is a different fact from cross-task concurrency within one batch.
(2) THE UNDECLARED-SCOPE CASE. A task with `file_scope: null` contributes nothing to any territory payload and is invisible to the overlap gate -- in the observed batch, the tree-wide rename declared no scope, so the gate deferred a third task four times over one directory while the 97-file rename overlapped with nothing. Coordinate with the already-filed work on absent-file_scope admission posture rather than re-deciding it here; this task consumes whatever that one rules, and should say so.

CONSIDER, DO NOT PRE-COMMIT. Whether the delivery limitation itself is fixable (can a dispatched agent drain its mailbox at tool-round boundaries during a long Bash call?) is worth a bounded look, but must NOT be this task's dependency. Even with working mid-flight delivery, constraints known at dispatch time belong in the brief; a message is a worse channel for a fact that was already knowable.

MUST NOT. Do not make base-mode territory a hard-mode-only feature by another name -- the observed harm is entirely in the base-mode path. Do not serialize all multi-task dispatch as the fix; concurrency is the design and the remedy is informing the agents, not abandoning it. Do not duplicate the absent-file_scope ruling.

ACCEPTANCE. A base-mode multi-task dispatch brief names its concurrent siblings and their declared file territory, and the territory.md contract is pulled in as it already is for hard mode. A fixture reproduces the observed batch shape -- two concurrent implement dispatches, one with a declared narrow scope and one with none -- and demonstrates the brief now carries what the agents lacked. The behaviour change is documented in the header contracts of both orchestrate-cycle-plan.sh and orchestrate-build-dispatch.sh. shellcheck clean per context/standards/shell-strict-mode.md.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 192. Close the directory-pathspec hole in guard-destructive-git.sh over-staging predicate
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. guard-destructive-git.sh's over-staging predicate blocks `git add -A`, `git add --all` and a bare `.` pathspec, but NOT a directory pathspec. `git add -- some/dir/` and `git add some/dir/` stage every modified file under that directory and pass the guard untouched, producing the identical harm the blocked forms exist to prevent: on a shared working tree, one dispatch's commit silently absorbs a concurrent dispatch's uncommitted work.

THE GUARD IS WORKING; THE ENUMERATION IS INCOMPLETE. This is not a request to distrust the hook. Its header (lines 28-35) enumerates exactly three over-staging forms -- `git add -A`/`--all`, `git add .`, and `git commit -a`/`-am`/`--all` -- and the implementation at lines 120-135 matches precisely those. A directory pathspec was simply never in the list. Note the header's own strong stance that over-staging has NO exemption mechanism and that a fresh snapshot marker must NEVER exempt these forms; a directory pathspec should join that same no-exemption class.

OBSERVED LIVE (2026-09-08, ~/Projects/BimodalLogic, two concurrent implementation dispatches on one working tree). An agent attempted `git add -A`, WAS CORRECTLY BLOCKED by this hook, and then used `git add -- FormalSystem/`, which passed. The resulting commit ea1a561c9 changed 30 lines of FormalSystem/Metalogic/Soundness.lean, of which only 1 belonged to the committing task; the other 16 added lines were a concurrent task's verified-but-uncommitted proof-tactic conversions. The absorption ran in BOTH directions in the same session: commit 357212808, authored under the other task, likewise carries 4 lines of the first task's rename of that same file. Neither commit is wrong in content; both are mis-attributed, per-task revert is no longer possible, and the history is misleading about who changed what. History was deliberately NOT rewritten (two dispatches were live; see the concurrent-writer history-rewrite work already filed).

THE BLOCK-THEN-WALK-AROUND SEQUENCE IS THE POINT. The agent did not evade a rule it disagreed with -- it received a refusal naming `-A` specifically, and reached for the nearest form the message did not name. A refusal that enumerates forms teaches the enumeration. This is evidence for widening the predicate rather than for adding more contract prose.

WORK.
(a) Extend the over-staging predicate in hooks/guard-destructive-git.sh to reject a `git add` pathspec that resolves to a directory, and consider the more general rule: any bare pathspec expanding to more than one modified file. Decide and justify which of the two rules to implement -- the general form also catches globs (`git add src/*.lean`) but needs care not to reject a legitimate multi-file explicit list, which IS the sanctioned form.
(b) Reuse the file's existing COMMAND_SCAN argv-anchoring machinery (quoted-span and comment stripping) so a path appearing inside a commit message cannot trigger a false positive.
(c) Emit the same "stage explicit task-scoped paths instead" guidance the `-A` branch already gives, and name the offending pathspec.
(d) Update the header's over-staging enumeration (lines 28-35), which would otherwise misdescribe the file.
(e) Update context/standards/git-staging-scope.md and rules/git-workflow.md's "enforced by" framing so rules and implementation stay in agreement.
(f) Add fixture cases to scripts/tests/test-guard-destructive-git.sh: `git add -- dir/` and `git add dir/` are refused; `git add -- a.lean b.lean` (explicit multi-file list) is permitted; a commit message containing a directory-looking string does not trigger; git-commit-scoped.sh remains unblocked.

MUST NOT. Do not block the sanctioned form -- an explicit list of named file paths is exactly what the guard's own refusal message tells agents to use, and rejecting it would leave agents with no compliant way to commit. Do not add an exemption mechanism for over-staging. Do not attempt retroactive repair of ea1a561c9 or 357212808.

RELATIONSHIP TO THE HISTORY-REWRITE PREDICATE WORK (no hard dependency). Another filed task adds a concurrency-gated predicate to this same hook for `--amend`/`reset`. That one is a genuinely new hazard class requiring independence from the clean-tree exemption; THIS one is a completeness fix to the hook's original over-staging class and needs no concurrency signal -- a directory stage is over-broad whether or not a concurrent writer exists. They are separable, but both edit hooks/guard-destructive-git.sh, so the file-footprint admission gate will serialize them regardless; whichever lands second should reconcile the header.

ACCEPTANCE. `git add -- <dir>/` and `git add <dir>/` are refused with a message naming the pathspec and pointing at the explicit-paths guidance; an explicit multi-file list remains permitted; the header enumeration and git-staging-scope.md match the implementation; fixture tests cover all four cases above and fail against the current script; shellcheck clean per context/standards/shell-strict-mode.md. Redeploy and confirm the hook fires from the deployed copy.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 191. Stop plan-mandated git-snapshot from reverting task-unrelated uncommitted work
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

DEFECT. A plan-mandated `git-snapshot.sh {task_number}` step, run in its DEFAULT mode, reverts uncommitted work that has nothing to do with the task. Recovery depends entirely on the dispatched agent noticing and running `git stash pop`. A less attentive agent would proceed on a silently reverted tree and the user would lose in-flight edits with no error at any layer.

OBSERVED LIVE (2026-09-08, this repository). During an implementation dispatch, the plan mandated `git-snapshot.sh` in default mode. The working tree carried ten task-unrelated uncommitted user files:
  after/ftplugin/markdown.lua, after/ftplugin/tex.lua, after/ftplugin/typst.lua,
  docs/MAPPINGS.md, docs/TYPST.md, lua/neotex/plugins/editor/README.md,
  lua/neotex/plugins/editor/which-key.lua, lua/neotex/util/README.md,
  lua/neotex/util/process.lua, .memory/memory-index.json
All ten were stashed away by the snapshot step. The agent noticed and restored them with `git stash pop`, and reported it. Nothing in the script, the plan format, or any gate would have caught it if the agent had not.

THE SAFE MODE ALREADY EXISTS -- THIS IS NOT A REQUEST FOR NEW FUNCTIONALITY. git-snapshot.sh documents the hazard in its own header ("WARNING: default and --branch modes REVERT the working tree", "Despite the name, this script is NOT read-only in its default or --branch modes") and already implements `--no-revert`, which records a real stash entry via `git stash create` + `git stash store` and leaves the working tree exactly as found. The overflow-checkpoint step in general-implementation-agent.md ALREADY calls it correctly with `--no-revert` and explains why. The gap is that PLAN-GENERATED invocations use the bare default form, and nothing forces the safer choice.

DESIGN DIRECTION (the implementer refines mechanics). Prefer a runtime guard in git-snapshot.sh over documentation alone: in default mode, when the dirty tree contains tracked paths OUTSIDE the task's declared file_scope, refuse (or require an explicit override flag) rather than reverting them, naming the offending paths. Documentation-only remedies have already been tried here -- the header warning exists and was not enough. Also audit how planners emit this step so generated plans stop defaulting to the reverting form.

SECONDARY, IN SCOPE: SNAPSHOT STASHES ACCUMULATE. Three git-snapshot stash entries from three separate sessions were present simultaneously (`git-snapshot-1788908157`, `git-snapshot-1787606319`, `git-snapshot-1787004036`), alongside two older WIP stashes. Nothing reaps them and nothing tells an operator which are safe to drop. At minimum give the entries enough identity for that judgment; a reaper is optional and may be split out.

MUST NOT. Do not remove or weaken `--no-revert`. Do not make the snapshot silently non-durable -- the point of the step is a recoverable backup before risky operations. Do not `git stash drop`/`clear` any existing entry as part of this work.

ACCEPTANCE. In a dirty tree carrying tracked modifications outside the task's file_scope, default-mode git-snapshot.sh does not silently revert them: it refuses, or preserves them, naming the paths. A fixture test sets up exactly that tree shape and fails against the current script. Generated plans no longer emit the bare reverting form for a routine pre-work snapshot.

---

### 190. Fix cross-session admission blindness for self-modifying candidates
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

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

### 189. Fix three channel-confusion defects in the orchestrate cycle-plan pipeline
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 150
- **Plan**: [189_fix_channel_confusion_orchestrate_pipeline/plans/01_fix-channel-confusion-orchestrate.md]
- **Summary**: [189_fix_channel_confusion_orchestrate_pipeline/summaries/01_fix-channel-confusion-orchestrate-summary.md]

**Description**: Fix three channel-confusion defects in the orchestrate cycle-plan pipeline that misled a live /orchestrate run. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (never .claude/**).

WHY. A single /orchestrate run hit several misleading signals, each independently reproducible and each measured during that run. All three defects kept here are one bug class expressed three ways: a channel carrying two meanings -- stdout carrying logs and data; a negative message conflating "not deferred" with "not matched"; and, in the second item, a read operation that quietly performs a write.

SCOPE NARROWED 2026-09-08. A fourth defect was originally filed here -- the inter-cycle redeploy checkpoint's unbounded, silent cost (a FULL verify-deploy.sh, timed at >400s without completing, run on both sides of deploy-headless.sh). It is REMOVED from this task as a duplicate. It is already covered, in more detail, by the task titled "Unify redeploy-checkpoint gate depth and make its defer verdict trustworthy and actionable" (#181 at filing time), whose Defect A documents THREE verify-deploy.sh runs per checkpoint firing at inconsistent depths -- one more than this task's own probe found -- and by "Add a durable redeploy ledger with content-hash and recency skip to the checkpoint" (#182) and "Make the consumer-freshness scan opt-in in deploy-headless.sh" (#180). Do NOT re-open that work here. This task MUST NOT modify verify-deploy.sh, deploy-headless.sh, or the checkpoint block in orchestrate-cycle-plan.sh; if a change here appears to require one, stop and record the coupling rather than crossing into that task's territory.

MEASURED EVIDENCE (verified 2026-09-08 by direct probe, not inferred):
(1) STDOUT CONTAMINATION. scripts/update-task-status.sh:875 and :877 echo "OK: task N ..." to STDOUT. scripts/orchestrate-cycle-plan.sh calls it without redirecting, so its plan JSON shares stdout with progress prose. The documented consumer contract in skills/skill-orchestrate/SKILL.md (Move 1: plan_json=$(bash .claude/scripts/orchestrate-cycle-plan.sh ...) then stop_json=$(echo "$plan_json" | jq -c '.stop')) therefore CANNOT WORK AS WRITTEN -- jq exits 5 on the leading non-JSON lines. Observed contaminating lines: a bare plan-path echo, and "OK: task N state.json already at 'implementing' (no-op); plan/phase updates re-applied". A second, smaller instance of the same documentation-vs-script drift: commands/orchestrate.md's dry-run block passes --session only when non-empty and shows a no-session fallback branch, but orchestrate-cycle-plan.sh requires --session unconditionally and exits 2 without it, so that documented fallback branch cannot run.
(2) BUDGET CHARGED ON A READ. The per-task cycle budget (cycle_counts[t], flushed to ${TASK_DIR}/.orchestrator-loop-guard via orchestrate-loop-guard-init.sh) is incremented during PLAN COMPOSITION, not at dispatch. A re-run caused by defect (1) -- a parse failure that dispatched nothing -- permanently consumed a cycle, taking the affected task from 3/5 to 5/5 and forcing a --continue-budget re-run to finish work that was already done and committed.
(3) A FALSE NEGATIVE MESSAGE. scripts/orchestrate-batch-admit.sh returns, for a solo self-modifying candidate, {"decision":"admit","self_modifying":true} -- the hazard IS computed and IS carried on the verdict. But scripts/orchestrate-predispatch-review.sh's Class C filters on (decision == "defer" and defer_reason == "self_modifying") at :370, so a solo admit renders as "0 findings (no candidate's file_scope names an orchestrator-critical path)". That sentence is FALSE whenever self_modifying is true; in the observed run the candidate's file_scope named three orchestrator-critical paths. It conflates "nothing deferred" with "nothing matched", and suppresses the one pre-dispatch signal that would have predicted the run ending at the deploy gate.

DESIGN (binding shape; the planner refines mechanics, not the shape). Three independent changes:
(a) STDOUT IS THE JSON CHANNEL, STRUCTURALLY. In orchestrate-cycle-plan.sh, redirect at entry (exec 3>&1 1>&2) and emit the final plan JSON to fd 3. Structural rather than per-callsite, so no future callee can leak into the data channel. Verify the SKILL.md Move 1 snippet then works verbatim, unmodified. Check whether orchestrate-cycle-postflight.sh and orchestrate-batch-admit.sh share the defect and apply the same treatment where they do. Also reconcile commands/orchestrate.md's dry-run --session fallback branch with the script's actual unconditional requirement -- fix whichever side is wrong, do not document around it.
(b) DO NOT CHARGE FOR READS. Make plan composition idempotent: cache the composed plan JSON in the mt_state_file keyed by dispatch_seq; on re-entry with dispatch_seq unchanged (nothing was actually dispatched since), return the cached plan verbatim WITHOUT incrementing cycle_counts[t] or flushing the loop guard. The dispatch_seq and dispatch_start_ts signals already exist in the mt_state_file. A genuine cycle must still cost exactly one.
(c) NEVER PRINT A NEGATIVE YOU DID NOT TEST. Class C must not report absence when the underlying verdict carries self_modifying: true. Either render admitted-with-hazard as its own row (context/patterns/orchestrate-batch-results-template.md already has this shape in its "### Admitted (idle overlap advisory)" section -- an admitted, not deferred, advisory) or at minimum make the negative message state exactly what was filtered, e.g. "0 deferred for self-modification (1 admitted carrying self_modifying: true)". Sweep sibling classes B/D/E for the same conflation of "none deferred" with "none matched" and fix any found. Class A is EXCLUDED from that sweep: its own false-positive defect (archived completed dependencies reported as nonexistent) is separately filed as "Fix orchestrate-predispatch-review.sh Class A false positive" (#188 at filing time); coordinate rather than both editing the Class A block.

MUST NOT: change orchestrate-batch-admit.sh's verdict schema or its collision/self-modification predicate (Class C is a CONSUMER of that verdict, per that script's own stated non-goal); make the solo self-modifying candidate DEFER rather than admit (that would mean zero dispatch on every solo run -- the REPORTING is broken, not the admission decision); modify verify-deploy.sh, deploy-headless.sh, or orchestrate-cycle-plan.sh's redeploy-checkpoint block (the cross-referenced checkpoint tasks own those); edit orchestrate-predispatch-review.sh's Class A block (the cross-referenced Class A task owns it); hand-author anything under .claude/**.

ACCEPTANCE: SKILL.md's Move 1 snippet, run verbatim, parses the plan JSON with no preamble stripping; commands/orchestrate.md's dry-run invocation as documented actually runs; a plan composition that dispatches nothing, re-run immediately, leaves cycle_counts[t] and .orchestrator-loop-guard unchanged, while a genuine dispatch still charges exactly one; a solo candidate carrying self_modifying: true is reported as such by orchestrate-predispatch-review.sh rather than as "0 findings"; fixture tests covering all three; full gate run green.

SEQUENCING: (i) these edits touch orchestrate-cycle-plan.sh and orchestrate-predispatch-review.sh, which the research-on-demand task (dependency edge recorded) also rewrote and which were UNDEPLOYED at filing time; that work must land and deploy first. (ii) The checkpoint tasks named above ALSO edit orchestrate-cycle-plan.sh, in its redeploy-checkpoint block, disjoint from items (a) and (b) here -- do not run this task in the same cycle as those; serialize either direction.

DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

--- ADDENDUM 2026-09-08 (partial fix already landed; scope changed) ---

PART OF THIS TASK IS ALREADY FIXED IN THE SOURCE STORE. Two commits landed on
agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh while this task was still
[NOT STARTED]. Read them before planning, and do NOT re-derive what they already did:

  1c44c8a33  orchestrate: keep cycle-plan stdout pure JSON
  6bca9f194  orchestrate: fix stderr-into-JSON at all four collaborator calls

WHAT THEY FIXED (defect (1), tactically). The "OK: task N ..." contamination named in defect (1)
is resolved at the call site: skill_preflight_update is now invoked with >&2. Fixed at that call
site rather than inside update-task-status.sh, because its other call sites have no JSON-purity
contract and printing to stdout is correct for them.

ITEM (a) IS STILL WORTH DOING ANYWAY. The landed fix is per-call-site and therefore exactly the
kind of fix item (a) argues against. The structural remedy item (a) specifies -- exec 3>&1 1>&2 at
entry, plan JSON emitted to fd 3 -- still stands, is strictly stronger, and would make the >&2 at
the skill_preflight_update call site redundant (remove it when item (a) lands, rather than leaving
two overlapping mechanisms). Treat the landed commit as a stopgap that unblocked live runs, not as
item (a) completed.

NEW FINDING THIS TASK DID NOT DESCRIBE: THE SAME CHANNEL CONFUSION IN THE OPPOSITE DIRECTION.
Defect (1) describes cycle-plan leaking prose INTO its own stdout. The audit behind 6bca9f194
found the mirror image: cycle-plan CONSUMING its collaborators' stdout with 2>&1, folding their
stderr diagnostics into payloads it then parses. Four sites, all now fixed via a shared
run_capture_stdout helper:

  (l) orchestrate-build-dispatch.sh      -> jq .dispatch_file
  (A) orchestrate-build-aux-dispatch.sh  -> jq .dispatch_file
  (B) orchestrate-triage-classify.sh     -> per-row NDJSON parse
  (C) orchestrate-batch-admit.sh         -> per-row NDJSON parse

(B) and (C) are the dangerous pair: the collaborator still exits 0, so the degraded-path warning
never fires and the while-read loop ingests a garbage row while reporting success. The three
collaborators carry 31 stderr-writing sites between them (15 in batch-admit alone). This was not
hypothetical -- the --lit resolver's [lit:auto] rationale triggered it on a live /orchestrate --lit
run, which dispatched nothing and exited 5 on "jq: parse error".

If item (a)'s fd-3 redirection is implemented, note it does NOT subsume these four: fd-3 governs
what cycle-plan EMITS, whereas these govern what it INGESTS. Both directions need their own fix.

REGRESSION COVERAGE NOW EXISTS. tests/test-orchestrate-cycle-plan.sh Group 15 stubs all three
collaborators to write to stderr while returning valid payloads, and asserts stdout still parses.
Verified to fail against the pre-fix script (4 failures, exit 5, the same jq parse error seen in
production) and pass after. Suite: 116 passed, 0 failed. Any item (a) rewrite must keep Group 15
green.

LIVE CORROBORATION FOR DEFECT (2), FROM A REAL RUN. Defect (2) (budget charged on a read) was
observed again end-to-end on 2026-09-08. A /orchestrate --lit run in the PossibleWorlds repo hit
defect (1), dispatched nothing, and still consumed a cycle; the task completed at 3/5 cycles for
2 real dispatches. This is exactly the failure chain defect (2) predicts -- a parse failure that
dispatches nothing permanently consuming budget -- and it is now reproducible on demand by
reverting either commit above. Item (b) remains unfixed.

AUDIT RESULT FOR THE REST OF THE SOURCE STORE: CLEAN. A detector for this defect class (capture
with 2>&1, then consume via jq pipe, jq here-string, or while-read NDJSON) was validated against
the known-bad pre-fix file -- it catches all four sites -- and then run across every non-test .sh
in agent-system/extensions/. The only other hit, verify-deploy.sh's doc_lint_output, is a false
positive: it parses human-readable lint text ("[header]" / "  FAIL:" prefixes), not JSON, so
merging stderr there is intentional. No further instances outstanding.

SUGGESTED ADDITIONAL SCOPE: MAKE THE DETECTOR A MAINTAINED LINT. The ad-hoc detector above needed
three iterations to get right -- its first two versions silently missed the NDJSON while-read
shape, i.e. the more dangerous half. That is a strong argument for lint-json-channel-discipline.sh
under scripts/lint/, following the nine existing lint-*.sh and wired into verify-deploy.sh like
its siblings, so this class cannot regress unnoticed. Filed here rather than as a separate task to
avoid a duplicate; split it out if the planner judges it separable.

---

### 188. Predispatch review archived dependency false positive
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Fix orchestrate-predispatch-review.sh Class A false positive: archived completed dependencies reported as nonexistent. MEASURED STATE (observed live in the BimodalLogic repository): the Class A dependency-edge classifier resolves a task dependencies[] against specs/state.json active_projects[] ONLY. A dependency that was completed and then archived by /todo is moved out of active_projects[] into specs/archive/{NNN}_{slug}/, so the classifier reports it as `nonexistent` -- the loudest verdict it has -- when the dependency is in fact SATISFIED. Measured there: 37 unique dependency numbers flagged nonexistent across roughly 30 tasks; ALL 37 resolve to a directory under specs/archive/, and ZERO are genuinely absent. The advisory is therefore ~100 percent false-positive noise on a mature repository, which trains an operator to ignore Class A entirely and would mask a real dangling edge when one finally appears. WORK: teach the Class A classifier a third verdict distinguishing (a) satisfied-and-archived -- resolvable under specs/archive/ -- from (b) genuinely nonexistent -- resolvable nowhere. Report (a) at informational volume or not at all; reserve the loud `nonexistent` wording for (b). Confirm the archive lookup matches the directory naming /todo actually writes (zero-padded {NNN}_{slug}), and decide whether a completed-but-not-yet-archived dependency warrants its own verdict. Check whether scripts/orchestrate-batch-admit.sh and scripts/orchestrate-triage-classify.sh share the same active_projects-only assumption and need the same correction -- the eligibility path narrows out-of-batch edges separately, so a false `nonexistent` there could have different consequences than in the advisory. EDIT TARGET: agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh (this repository is the source store; consuming repositories only carry a gitignored deployed copy under .claude/, so a fix authored there is wiped by the next regeneration). ACCEPTANCE: running the review against a state file whose dependencies point at archived tasks reports zero `nonexistent` findings and classifies those edges as satisfied; a synthetic dependency on a number present in neither active_projects[] nor specs/archive/ still reports loudly as `nonexistent`; the deployed copy in a consuming repo reproduces both outcomes after redeploy.

---

### 187. Unify commit attribution convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Decide and enforce one commit-attribution convention across scripted and hand-written agent commits.

OBSERVED. Across the 16 commits of a single completed task, exactly one commit carried the session-attribution trailer and 15 did not. The one that carried it (2d09265cc) was hand-written by an implementation agent using git directly; the other 15 were produced by scripts/git-commit-scoped.sh, which composes its own commit message from --message plus a Session: line and never picks up harness-supplied attribution guidance. The result is a single task whose history is inconsistent for no principled reason.

NOT A SECURITY ISSUE. During the same run a subagent flagged the attribution guidance as a suspected prompt injection. That was investigated and NOT substantiated: no file in the repository contains the trailer strings or the notice's phrasing, and the guidance arrived alongside a genuine /remote-control invocation that also enabled session-linked tooling. The finding here is consistency, not compromise. Record this explicitly so the earlier false positive is not rediscovered and re-escalated.

THE REAL QUESTION. git-commit-scoped.sh is the single sanctioned committing implementation, and agent contracts direct agents to it -- but agents still sometimes commit with raw git (as 2d09265cc did), and only those commits pick up ambient attribution. Decide which of these is intended: (a) git-commit-scoped.sh should accept and emit session attribution so scripted commits match hand-written ones; (b) attribution belongs only on interactive commits and agent commits should carry none; (c) the divergence is acceptable and should be documented rather than fixed. Do not pre-commit to an option.

CONSIDER ALSO. Whether the raw-git commit is itself the defect worth addressing -- rules/git-workflow.md and the scoped-commit boundary lint already push all task committing through git-commit-scoped.sh, so a hand-written agent commit may indicate a gap in that enforcement independent of attribution.

ACCEPTANCE: a recorded decision with rationale; whichever option is chosen is reflected in git-commit-scoped.sh, the git-workflow rule, or both; a task run end to end afterwards produces commits with a single consistent attribution shape.

---

### 186. Fix deploy headless path in regeneration doc
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Plan**: [186_fix_deploy_headless_path_in_regeneration_doc/plans/01_fix-deploy-headless-invocation-path.md]
- **Summary**: [186_fix_deploy_headless_path_in_regeneration_doc/summaries/01_fix-deploy-headless-invocation-path-summary.md]

**Description**: Fix the wrong deploy-headless.sh invocation path documented in regeneration-is-manual-only.md.

OBSERVED (live, cost a full orchestration cycle). A /orchestrate run was refused at postflight by the completion-deploy gate, whose remedy text correctly names "bash .claude/scripts/deploy-headless.sh". The operator instead copied the invocation form documented in context/patterns/regeneration-is-manual-only.md -- "bash scripts/deploy-headless.sh" -- which does not exist at that path. The command failed with exit 127 and NO output, so it looked like a silent no-op rather than a failure. The task stayed blocked until the correct path was used, at which point the deploy landed clean on the first attempt.

WHY THIS FILE MATTERS DISPROPORTIONATELY. regeneration-is-manual-only.md is the file the deploy gate's own remedy text points operators and agents at. It is the canonical reference read precisely when someone is already blocked, so a wrong invocation there is maximally expensive.

THE DEFECT. Four sites carry the bare, non-existent path -- lines 32 and 35 of context/patterns/regeneration-is-manual-only.md in BOTH the deployed tree and its source store copy under agent-system/extensions/core/. A repo-wide survey found 26 references using the "scripts/deploy-headless.sh" form and 4 using "bash agent-system/extensions/core/scripts/deploy-headless.sh"; determine which of these are genuinely wrong versus correct-in-their-own-context (a source-store-relative path may be correct where the reader is operating in the source store) rather than mass-rewriting on the string alone.

SCOPE. Correct the invocation form in the source store under agent-system/extensions/** only -- never the deployed .claude/ tree, which is regenerated (see rules/source-store-deploy-boundary.md). Consider whether the surrounding text should also warn that a wrong path fails silently with exit 127.

ACCEPTANCE: every documented invocation of deploy-headless.sh names a path that resolves from the working directory its surrounding text assumes; the two code fences in regeneration-is-manual-only.md are runnable as written from a consuming repo root; deploy and the full gate run stay green.

---

### 185. Retarget stage citations to move vocabulary
- **Status**: [NOT STARTED]
- **Task Type**: markdown
- **Topic**: core-agent-system
- **Dependencies**: None

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

---

### 184. Decide lean skeleton plan completion routing
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Decide the disposition of the Lean/formal skeleton-plan completion routing lost with the single-task engine.

CONTEXT. The deleted single-task /orchestrate engine carried a skeleton-exhaustion completion branch: when no incomplete phase heading remained AND the last handoff declared skeleton=true, it derived a follow-up task list from the handoff's sorry_inventory[].follow_up_task entries, routed the task to completion via update-task-status.sh postflight with the pr_ready target and --allow-pr-ready, and reported the pending follow-ups. The surviving batch engine has no equivalent branch.

WHY THIS ONE NEEDS A DECISION AND HAS NOT HAD ONE. The rewrite recorded TWO capability losses. The loop-guard staleness detector got an explicit recommended follow-up. This one was recorded as a permanent loss with NO follow-up named at all -- it is the only deviation in that summary left without a next step. Lean and formal work is live in this repository, so silent acceptance should be a deliberate choice rather than an oversight.

SCOPE. Determine whether strategic-sorry skeleton plans can still reach a correct terminal status under the batch engine, and if not, what should happen. Evaluate at least: (a) port the skeleton-exhaustion branch into orchestrate-cycle-plan.sh or orchestrate-cycle-postflight.sh; (b) require skeleton plans to close through a different, already-supported path; (c) accept the loss explicitly and document how a skeleton plan is expected to terminate now. Do not pre-commit to an option.

EVIDENCE. The assertions covering this mechanism (.skeleton / last_skeleton and .sorry_inventory / follow_up_tasks) were removed from scripts/tests/test-handoff-reader-parity.sh. Recorded under "Plan Deviations" in specs/088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_four-move-loop-rewrite-summary.md. Related policy: the strategic-sorry skeleton allowance in context/contracts/recovery.md.

ACCEPTANCE: a recorded decision with rationale; if a gap is confirmed, either a working path to terminal status for skeleton plans with test coverage, or documentation naming the expected terminus.

---

### 183. Decide loop guard staleness detector disposition
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Decide whether to port the hard-mode loop-guard operational-staleness detector into orchestrate-cycle-plan.sh, or record its removal as accepted.

CONTEXT. The single-task /orchestrate engine (skill-orchestrate/SKILL.md Stages 0-8) was deleted when SKILL.md was rewritten as the four-move loop. That engine carried a 3-signal operational-staleness detector for .orchestrator-loop-guard, gated on hard mode only. It has NO equivalent in the surviving batch engine (orchestrate-cycle-plan.sh), so /orchestrate --hard no longer detects a stale-but-syntactically-valid loop guard at all.

WHAT WAS LOST (the detector's own contract, for reference when deciding):
  Signal 1 -- schema/version drift: guard .max_cycles differs from the live MAX_CYCLES.
  Signal 2 -- plan-lineage drift: guard .plan_version differs from the newest plans/*.md basename. Skipped when either side is empty or "none" (an absent plans/ directory is never itself evidence of staleness).
  Signal 3 -- mtime-age backstop: guard older than ORCHESTRATOR_LOOP_GUARD_STALE_DAYS (default 7). An unreadable mtime (stat returns 0) is treated as NOT stale.
  Any one signal tripping was sufficient. On trip: archive the guard aside to .stale-loop-guard-<ts>.json (never delete), co-archive .orchestrator-churn-state.json under the same timestamp if present, then fall through to fresh init at cycle 0.

THIS IS A DECISION TASK, NOT A PORT TASK. The prior engine's own comments recorded that whether BASE mode should gain the detector unconditionally was already an open, undecided question. Deleting the hard-mode copy did not settle that question -- it removed the only implementation. Evaluate at least: (a) port into orchestrate-cycle-plan.sh for all effort modes; (b) port hard-mode-only, preserving the old asymmetry; (c) accept the loss and sweep the retired test's remaining references. Do not pre-commit to an option.

EVIDENCE. The retired test scripts/tests/test-loop-guard-staleness.sh was removed from git tracking in commit 2d09265cc. The capability loss is recorded under "Plan Deviations" and "Follow-ups" in specs/088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_four-move-loop-rewrite-summary.md.

ACCEPTANCE: a recorded decision with rationale; if ported, the detector works under the batch engine and has test coverage; if accepted as lost, the removal is documented where a future reader will find it rather than surviving only as summary prose.

---

### 182. Add a durable redeploy ledger with content-hash and recency skip to the checkpoint
- **Effort**: 4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 181

**Description**: Give the /orchestrate inter-cycle redeploy checkpoint a durable run ledger so it stops re-running a full redeploy that just happened.

OBSERVED COST. In session sess_1788827855_dfff06 the checkpoint consumed roughly 10 minutes of wall clock in a single cycle and ended by deferring BOTH tasks in the batch (deferred_deploy_checkpoint: [155,156]) -- leaving one task stranded at [IMPLEMENTING] despite 6/6 plan phases closed and committed, and the other never dispatched at all. There is no durable record of when a redeploy last ran, against which source-store content, or with what verify outcome, so the checkpoint cannot skip a redeploy that just succeeded.

=== CORRECTION TO THE ORIGINAL DIAGNOSIS: deployed_critical_paths IS MIS-SCOPED, NOT DEAD ===

The field was initially suspected of never being written, which would make it a dead field. That is NOT what the code does. Verified:
  - It IS written, on the two SUCCESS branches of the checkpoint: the verify-clean branch and the pre-existing-findings-proceed branch (branch (c)). Both do .deployed_critical_paths = ((.deployed_critical_paths + $mp) | unique).
  - It is NEVER written on the DEFER branch. The observed empty [] is therefore fully explained by the run having deferred -- the field did exactly what it was coded to do.
  - Decisively, it lives in the mt_state_file, whose filename is session-scoped (specs/.orchestrator-multi-state-sess_<id>.json). It resets on every /orchestrate invocation.

CONCLUSION. deployed_critical_paths is a WITHIN-INVOCATION re-deploy suppressor, working as designed for that narrower purpose. It is not, and cannot be, the cross-invocation ledger described here. This task must therefore introduce genuinely NEW durable state rather than attempt to repair that field. Decide during planning whether the existing field is subsumed by the new ledger or retained alongside it for its narrower within-invocation role; do not silently redefine its semantics in place.

=== WHAT TO BUILD ===

Persist a last-deploy record spanning invocations: timestamp, source-store content hash, and verify outcome. Skip the redeploy when the source-store hash is unchanged since the recorded successful deploy, or when the record is recent enough -- i.e. run the redeploy when it is genuinely needed or when it has been a while, not on every qualifying cycle.

The record must capture the verify OUTCOME, whose definition is settled by the prerequisite gate-depth task. That is the primary reason for the dependency ordering: writing a ledger against outcome semantics that the next task redefines would require rewriting it.

=== NAMED ACCEPTANCE CRITERION: THE SELF-MODIFYING-TASK CLASS ===

A task whose own file_scope IS the orchestrator source store necessarily stales the deploy that its own completion gate then checks. This is exactly what happened in the observed session: the batch edited agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh -- the very script running the checkpoint that then blocked it. This class of task hits the checkpoint EVERY SINGLE TIME by construction, so it must be designed for explicitly, not treated as an edge case.

CRITICAL CONSEQUENCE FOR THE DESIGN: a content-hash skip does NOT help this class, because the hash always changes by construction -- the task's own edits are what change it. Only a recency window, or a 'the redeploy that just landed was mine' ledger check that recognizes the last successful deploy already incorporated this batch's changes, addresses it. The content-hash skip and the recency/attribution skip are therefore NOT redundant alternatives; the hash skip covers the ordinary case and the recency/attribution skip covers the self-modifying case. Shipping only the hash skip leaves the observed failure mode fully intact.

This must be a named acceptance criterion with test coverage: a simulated self-modifying task (file_scope overlapping the orchestrator's own scripts) must not incur a redundant full redeploy on every cycle.

=== SCOPE ===

Extend scripts/tests/test-orchestrate-cycle-plan.sh with coverage for: skip on unchanged hash; skip within the recency window; NO skip when the source store genuinely changed outside the window; and the self-modifying-task case above. Update the 'The Inter-Cycle Redeploy Checkpoint' subsection of context/patterns/batch-orchestration-guardrails.md, which currently defers this work explicitly -- it names the deployed_critical_paths idempotence backing store as 'its own task'. That note is closed by this task and must be replaced with the real contract, including the corrected description of the existing field's within-invocation scope.

DO NOT SIMPLY DISABLE THE GATE. Skipping must be justified by evidence in the ledger that the deploy is current. A skip on no evidence is a disabled gate wearing a ledger's clothes.

SOURCE STORE. All edits land under agent-system/extensions/core/** at the GLOBAL root /home/benjamin/.config/nvim. Never edit .claude/**, which is a regenerated deploy artifact -- see rules/source-store-deploy-boundary.md.

DEPENDENCY. Depends on the gate-depth task both by file footprint (both modify orchestrate-cycle-plan.sh) and semantically (the ledger stores a verify outcome whose definition that task changes).

---

### 181. Unify redeploy-checkpoint gate depth and make its defer verdict trustworthy and actionable
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 180
- **Plan**: [181_unify_redeploy_checkpoint_gate_depth/plans/01_unify-redeploy-checkpoint-gate.md]
- **Summary**: [181_unify_redeploy_checkpoint_gate_depth/summaries/01_unify-redeploy-checkpoint-gate-summary.md]

**Description**: Fix three related defects in the /orchestrate inter-cycle redeploy checkpoint that together produced a contradictory, unactionable deferral of an entire batch.

=== DEFECT A: INCONSISTENT GATE DEPTH PRODUCES CONTRADICTORY VERDICTS ===

OBSERVED. In session sess_1788827855_dfff06, deploy-headless.sh ran verify-deploy.sh WITH --skip-slow and reported PASS (29 checks, 0 failures, RESULT=landed_verify_clean, including an explicit '[SKIP] --skip-slow: shell test suite deferred' line). The checkpoint then immediately ran its OWN verify-deploy.sh WITHOUT --skip-slow, got exit 1 with new findings versus the pre-redeploy baseline, and deferred both tasks. Two verifications of the same tree, minutes apart, returned opposite verdicts purely because they ran at different gate depths.

MECHANICS (verified). Each checkpoint firing runs verify-deploy.sh THREE times:
  1. orchestrate-cycle-plan.sh pre_findings snapshot -- FULL depth
  2. deploy-headless.sh's own internal run -- VERIFY_ARGS=(--skip-slow), fast depth
  3. orchestrate-cycle-plan.sh post_findings snapshot -- FULL depth

IMPORTANT -- THIS IS A DOCUMENTED DECISION, NOT AN OVERSIGHT. The comment block immediately above the post_findings call in orchestrate-cycle-plan.sh explicitly argues for the full-depth choice: it takes the full snapshot 'independently of deploy-headless.sh's own internal --skip-slow verify -- exactly as before this phase -- so the baseline comparison below sees slow-gate findings too, not only the fast subset deploy-headless.sh itself checked.' Do NOT simply delete the full-depth pass. Either preserve that intent under a cheaper mechanism or supersede the argument explicitly and update the comment; a silent reversal will be re-reverted by the next reader.

APPROACHES TO EVALUATE (choose during research/planning, do not pre-commit): verify once at a single depth; have the checkpoint consume deploy-headless.sh's own already-computed result instead of independently re-verifying; or keep two depths but make the depth mismatch explicit in the comparison so a fast-PASS/full-FAIL disagreement is reported as such rather than silently resolved in favor of the deferral.

=== DEFECT B: THE DEFER MESSAGE DOES NOT NAME THE FAILING FINDING ===

OBSERVED. The deferral message reads 'verify-deploy.sh exit N with new findings vs. pre-redeploy baseline; deferring remaining tasks. Fix the deploy/verify failure, redeploy manually, then re-run /orchestrate on the remaining task numbers.' It never names WHICH finding was new, so the operator cannot act on it without manually re-running the whole gate.

THIS IS THE CHEAPEST FIX IN THE TASK. The new_findings variable is already computed by deploy_baseline_new_findings immediately above, and is in scope and non-empty on exactly this branch -- the branch is reached only because new_findings is non-empty. The message simply does not print it. Emit the specific new findings (and the recorded defer_ledger detail field) so the operator sees what failed. The defer_ledger entry's detail field should likewise carry the finding identity, not just the generic string 'verify-deploy.sh new findings vs. pre-redeploy baseline'.

=== DEFECT C: A FLAKY, LOAD-SENSITIVE TEST CAN DEFER AN UNRELATED BATCH ===

This is the ACTUAL trigger of the observed deferral, verified in-session.

EVIDENCE.
  - The failing gate was test-lake-build-guard.sh: 28 passed / 1 failed during the checkpoint run.
  - Re-run twice immediately afterward on an idle machine: 29 passed / 0 failed, both times. It is FLAKY, not broken.
  - Git history confirms known load sensitivity: commit 878043472 'tests: isolate lake-build-guard suite from ambient host memory pressure', and a prior task added a 'pressured fixture' to it.
  - It is UNRELATED to the batch: it was last touched by an unrelated earlier task, and the batch's own modified_files never include it.
  - CRITICALLY, THE CHECKPOINT SELF-INFLICTED THE LOAD. It ran a full deploy plus the entire shell test suite immediately before the post_findings snapshot that then flagged the failure. The gate created the memory pressure that made its own load-sensitive test fail, and then deferred the batch over that failure.

WHY THIS MATTERS BEYOND ONE TEST. As built, ANY load-sensitive test flaking under checkpoint-induced load can defer an entire batch over a finding attributable to no task in that batch. This is a structural property of the gate, not a property of test-lake-build-guard.sh.

ACCEPTANCE CRITERION. The checkpoint MUST NOT defer a batch on a finding that is flaky or unrelated to the batch's own modified_files.

APPROACHES TO EVALUATE (choose during research/planning, do not pre-commit to one): re-run a candidate new finding before treating it as new; quarantine load-sensitive tests out of the blocking gate; or scope the defer decision to findings attributable to the batch's own modified_files. Note the interaction with Defect A -- reducing gate depth may make the third option easier, and re-running a candidate finding costs less if the gate is not already running three verify passes.

=== PRESERVE ===

Branch (c) of the existing three-branch contract MUST survive: a post-redeploy finding set that is unchanged or shrunk relative to the pre-redeploy baseline proceeds loudly with a recorded verify_deploy_baseline_notices entry. That is what stops a pre-existing, unrelated red gate from deferring the whole batch, and it is the closest existing analogue to the Defect C fix. Branch (a) -- deploy-headless.sh exit 1 or 2 means the deploy did not land, unconditional defer, no baseline consultation -- must also survive unchanged, including its deliberate exclusion of exit 3.

DO NOT SIMPLY DISABLE THE GATE. The checkpoint exists to stop the orchestrator running against a stale deploy of its own scripts. The goal is a verdict that is trustworthy and actionable when it fires, not an absent verdict.

=== SCOPE ===

Update the 'The Inter-Cycle Redeploy Checkpoint' subsection of context/patterns/batch-orchestration-guardrails.md to match whatever contract results, and extend scripts/tests/test-orchestrate-cycle-plan.sh with coverage for the new behavior (at minimum: a new finding that is flaky or unrelated does NOT defer; a genuine new attributable finding still DOES defer; the defer message names the finding).

SOURCE STORE. All edits land under agent-system/extensions/core/** at the GLOBAL root /home/benjamin/.config/nvim. Never edit .claude/**, which is a regenerated deploy artifact -- see rules/source-store-deploy-boundary.md.

DEPENDENCY. Depends on the consumer-scan opt-in task both by file footprint (both modify deploy-headless.sh) and because that task removes latency this task's re-run-a-candidate-finding option would otherwise compound.

=== SCOPE NOTE ADDED 2026-09-08 (residual observed live) ===
A completed task was refused at postflight by the completion-deploy gate and could NOT self-correct within the invocation: /orchestrate has no serialized redeploy trigger of its own. The two sanctioned automated deploy call sites (command-gate-out.sh rc==6, and commands/implement.md Step 4) do not cover the /orchestrate path, and Stage MT-3 step 7 keys off orchestrator-critical-paths.json rather than a broader agent-system/extensions/** predicate -- so a task whose own commits touched the source store outside a declared critical path defers rather than converging. The operator had to deploy by hand and re-attempt the transition.
Widening that predicate (and its deployed_critical_paths idempotence backing store) is named as explicit follow-up work in context/patterns/batch-orchestration-guardrails.md and is in scope for THIS task if the chosen approach makes it natural; if not, split it out rather than dropping it silently.

---

### 180. Make the consumer-freshness scan opt-in in deploy-headless.sh
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Plan**: [180_make_consumer_freshness_scan_opt_in/plans/01_consumer-freshness-scan-opt-in.md]
- **Summary**: [180_make_consumer_freshness_scan_opt_in/summaries/01_consumer-freshness-scan-opt-in-summary.md]

**Description**: Move the post-deploy consumer-freshness scan off the blocking path of the /orchestrate inter-cycle redeploy checkpoint by making it opt-in.

OBSERVED COST. In session sess_1788827855_dfff06 (orchestrating tasks 155 and 156), the redeploy checkpoint consumed roughly 10 minutes of wall clock in a single cycle. Part of that cost is a consumer-repo staleness walk over approximately 50 repositories (CONSUMERS_STALE=50), printing per-extension STALE/CANNOTVERIFY rows for each.

WHY THIS IS PURE COST. The scan is report-only by explicit design. deploy-headless.sh's own comment at the scan site states it 'is report-only and can NEVER change this script's exit code', and the script states plainly that it never redeploys into a consumer -- the documented remedy is to run the deploy manually in each stale repo. So on the critical path of a blocking gate this walk produces output that the gate cannot act on and that the orchestrator does not consume.

LOCATION. The scan lives in the post-deploy block of agent-system/extensions/core/scripts/deploy-headless.sh (the '--- Post-deploy stale-consumer report (TIER 3, additive output only)' section), invoking check-consumer-freshness.sh --stale-only. Some flag plumbing may also touch verify-deploy.sh.

SCOPE OF WORK.
A. Gate the scan behind an explicit opt-in flag (default OFF), following verify-deploy.sh's existing 'always explicit, never derived. Default OFF' flag convention rather than inventing a new one.
B. Preserve the CONSUMERS_STALE=<n> stderr contract for callers that DO opt in -- deploy-headless.sh's header documents this as the way a caller reads the consumer-staleness signal on its own, so the line must remain byte-compatible when the flag is passed.
C. Confirm no current caller depends on the scan running unconditionally. If a caller does, pass the new flag there explicitly rather than flipping the default.

ACCEPTANCE. A default deploy-headless.sh run performs no consumer walk and emits no per-consumer STALE/CANNOTVERIFY rows; the same run with the opt-in flag reproduces today's output including the CONSUMERS_STALE=<n> line. The checkpoint's wall-clock cost drops by the scan's share. The scan's exit-code neutrality is unchanged in both modes.

ORDERING. This is the lowest-risk of the three redeploy-checkpoint tasks and lands first so that deploy-headless.sh is settled before the gate-depth work modifies it.

SOURCE STORE. All edits land under agent-system/extensions/core/** at the GLOBAL root /home/benjamin/.config/nvim. Never edit .claude/**, which is a regenerated deploy artifact -- see rules/source-store-deploy-boundary.md.

SAFETY CONSTRAINT. Do not disable or weaken any gate that can change the deploy verdict. This task removes reporting from the blocking path; it must not remove verification.

---

### 179. Add an element placement and density lint to the typst extension
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 178
- **Research**: [179_typst_element_placement_density_lint/reports/01_element-placement-density-lint.md]
- **Plan**: [179_typst_element_placement_density_lint/plans/01_element-placement-density-lint.md]
- **Summary**: [179_typst_element_placement_density_lint/summaries/01_element-placement-density-lint-summary.md]

**Description**: Add a mechanical element-placement and density lint to the typst extension, and wire it into the implementation agent's verification stage.

WHY A LINT, NOT JUST PROSE. The companion task authors the semantic-element usage contract as prose. Prose alone is the weaker half of the fix, for one specific and evidenced reason: the "prose guidance is enough" hypothesis has already been tested in this extension and falsified. `templates/chapter-template.md` already required an "Opening paragraph explaining chapter purpose", the implementation agent already loads that file via index-entries.json, and a 25-item `#remark` tracking checklist still landed where a chapter's opening prose belongs in `typst/manual/chapters/08-agency.typ`. Adding better prose to a system that already ignored adequate prose needs a mechanical backstop.

CURRENT STATE. The extension carries NO mechanical infrastructure to hang a check on: `manifest.json` declares `provides.scripts: []`, `provides.hooks: []`, and `provides.rules: []`. This is new infrastructure, not a tweak, and there is no existing script convention in this extension to conform to. The only present gate is `typst compile` exit 0, which is blind to rhetorical and structural misuse.

CHECKS TO IMPLEMENT.
1. Placement: a semantic element standing as the first body content after a `= ` chapter heading, with no intervening prose. Implementation is a line scan -- find `^= `, skip blank lines and `//` comments, flag if the next content line opens a semantic element.
2. Enumerated list inside a remark exceeding a threshold item count. Needs brace matching over the remark block to find its extent; tractable in a small script.
3. Per-file / per-chapter remark density.

TWO CONSTRAINTS THE USER SPECIFICALLY ENDORSED. Build these in; do not rediscover them during implementation.

CONSTRAINT 1 -- the check must be PLACEMENT-SPECIFIC, NOT BLANKET. `08-agency.typ` legitimately opens with roughly 50 lines of chapter-local `#let` macro definitions and explanatory comments BEFORE the `= Agency` heading, and remarks that FOLLOW a substantial result are exactly the correct usage the contract endorses. A naive "no remark near a heading" rule would fire constantly on correct documents, and a gate that fires on correct documents gets switched off. The check must key on the specific position -- first body content after a chapter heading, no intervening prose -- and must not penalize pre-heading macro blocks or post-result remarks.

CONSTRAINT 2 -- density thresholds start ADVISORY, NOT BLOCKING. Emit a warning, do not fail the run, pending review of how the thresholds behave on real documents. An unreviewed hard threshold that fires on correct documents is the other way gates get disabled. Placement violations may be treated more strictly than density once the thresholds have been observed; density starts soft.

SCOPE OF WORK.
A. Create the lint script under `agent-system/extensions/typst/scripts/`.
B. Wire it into `manifest.json` `provides.scripts` (currently `[]`).
C. Invoke it from the verification stage of `agents/typst-implementation-agent.md`, alongside -- not replacing -- `typst compile`.
D. Take thresholds and element definitions from the semantic-element usage standard authored by the prerequisite task, rather than inventing a second, divergent set of norms.

DEPENDENCY. Depends on the semantic-element usage contract task, both semantically (the thresholds and the element inventory come from that contract) and by file footprint (both tasks modify `agents/typst-implementation-agent.md`).

SOURCE STORE. All edits land under `agent-system/extensions/typst/**` at the GLOBAL root `/home/benjamin/.config/nvim`. Never edit `.claude/**`, which is a regenerated deploy artifact -- see rules/source-store-deploy-boundary.md.

EXPLICITLY OUT OF SCOPE. Do NOT edit `08-agency.typ` or any other chapter in the Logos/Theory repository. That document is useful only as a TEST FIXTURE for validating that the lint fires on the real defect and stays silent on the file's legitimate pre-heading macro block; it must not be modified.

ACCEPTANCE. The lint fires on the observed defect in `08-agency.typ` (a 25-item remark checklist as first body content after `= Agency`). It stays silent on that same file's ~50-line pre-heading macro-and-comment block, and silent on remarks that follow a substantial result. Density findings are advisory. The script is reachable from the implementation agent's verification stage and declared in the manifest.

---

### 178. Add a semantic element usage contract to the typst extension and enforce it in the agent
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [178_typst_semantic_element_usage_contract/reports/01_semantic-element-usage-contract.md]
- **Plan**: [178_typst_semantic_element_usage_contract/plans/01_semantic-element-usage-contract.md]
- **Summary**: [178_typst_semantic_element_usage_contract/summaries/01_semantic-element-usage-contract-summary.md]

**Description**: Author the missing semantics layer for the typst extension's semantic elements, and wire it into the implementation agent and skill as an actual structural gate.

WHY THIS EXISTS (concrete evidence). A document the system produced -- `typst/manual/chapters/08-agency.typ` in the Logos/Theory repository -- opens, immediately after its `= Agency <sec-agency>` heading and before any chapter prose, with `#remark("Formalization Status")[...]` containing a 25-item numbered tracking checklist (label `<rem-agency-status>`), followed immediately by further `#remark("Decision: ...")` blocks. Nothing flagged it.

THE USER'S NORM (this is the requirement, not a suggestion). Remarks are for SPARING, high-value OFF-TOPIC points, or big-picture reflections on the current development, and they typically FOLLOW some substantial result. A remark is never a chapter opener, and never a long enumerated status/tracking list.

WHAT THE AUDIT FOUND.
1. `context/project/typst/patterns/theorem-environments.md` is 74 lines. It defines `#let remark = thmbox("rem", "Remark", color: gray)` on line 16 and then documents ONLY mechanics: basic, named, labeled, proof, custom styling, label conventions. Nothing in it -- or anywhere else in the extension -- states what any environment is FOR, how sparingly to reach for it, or where it may appear relative to headings and results. `remark` is not even listed in that file's own Label Conventions table.
2. The delivery channel is HEALTHY, so this is not a plumbing failure. `index-entries.json` wires essentially every context file to `typst-implementation-agent` via `load_when.agents`, including theorem-environments.md, textbook-standards.md, and chapter-template.md. New guidance written into `context/project/typst/**` will in fact reach the agent.
3. The extension already knows how to express a sparingness norm, but only in one narrow place: `standards/type-theory-foundations.md` says "Do NOT add DTT remarks to every definition. The goal is strategic placement, not exhaustive annotation," with a matching checklist item. That is exactly the right shape of rule, scoped to DTT annotations only, generalizing to nothing.
4. The only verification gate is compile-green. In `agents/typst-implementation-agent.md`, Stage 4C is "Compilation must succeed. All specified files must exist"; Stage 5 is `typst compile`; and Critical Requirements MUST NOT items 2-4 are all compile/PDF-centric. `typst compile` exits 0 on rhetorically and structurally misused elements. No structural check exists in the agent or in `skill-typst-implementation`.

THE MOTIVATING FALSIFIED HYPOTHESIS -- build the fix around this, do not rediscover it. Prose guidance alone has ALREADY been tried in this extension and it already failed on this exact document. `templates/chapter-template.md` carries a "Checklist for New Chapters" whose first content item requires an "Opening paragraph explaining chapter purpose." The agent already loads that file via index-entries.json. The observed document violates that item directly -- a 25-item checklist stands exactly where opening prose belongs -- and the defect landed anyway. An unenforced checklist line that no gate reads did not change agent behavior. Therefore this work MUST NOT terminate in one more checklist line: the contract has to be wired into the agent and skill as a structural self-review step with explicit MUST NOT items, or it will fail the same way.

SCOPE OF WORK.
A. Author a new usage standard at `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md`. State, per semantic element, what it is FOR, its expected density, and its legal placement relative to headings and results. GENERALIZE beyond `#remark`: cover definition, theorem, lemma, example, proof, remark, and the elements in `patterns/rule-environments.md`. Encode the user's norm for remark verbatim in substance. Say explicitly where an enumerated formalization-status or tracking checklist DOES belong, since that content has to go somewhere -- it is task-management material, or at most an appendix or dedicated status section, never chapter-opening body prose.
B. Give `patterns/theorem-environments.md` the semantics it lacks, and add `rem:` to its Label Conventions table.
C. Give `templates/chapter-template.md` a positive example of CORRECT remark placement -- one following a substantial result -- so the template models the norm instead of leaving it unstated.
D. Wire the new standard into `index-entries.json` with `load_when.agents` including typst-implementation-agent, following the shape of sibling entries.
E. Add a structural self-review step and explicit MUST NOT items to `agents/typst-implementation-agent.md` (Stage 4C verification and Critical Requirements) and to `skills/skill-typst-implementation/SKILL.md`, so that compile-green stops being the sole gate. At minimum the MUST NOT list should forbid a semantic element standing as the first body content after a chapter heading with no intervening prose, and forbid a long enumerated status/tracking list inside a remark.

SOURCE STORE. All edits land under `agent-system/extensions/typst/**` at the GLOBAL root `/home/benjamin/.config/nvim`. Never edit `.claude/**`, which is a regenerated deploy artifact -- see rules/source-store-deploy-boundary.md.

EXPLICITLY OUT OF SCOPE. Do NOT edit `08-agency.typ` or any other chapter in the Logos/Theory repository. Document remediation is the user's, to be done after reloading the improved extension. This task changes the agent system only.

NOTE ON ROUTING. This task produces markdown and JSON, not `.typ` documents. If it is ever re-routed to `typst-implementation-agent`, that agent's "MUST NOT mark completed without successful compilation" requirement has nothing to compile and does not apply.

ACCEPTANCE. A reader of the new standard can answer, for each semantic element, what it is for and where it may appear, without consulting the originating conversation. The remark norm is stated in a form that would have flagged the observed 25-item chapter-opening checklist. The agent and skill contracts name the standard and carry enforceable MUST NOT items rather than a checklist line.

---

### 177. Add a dependency-tracing recipe to the lean4 extension context
- **Effort**: 2-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: None

**Description**: Add a dependency-tracing recipe to the lean4 extension context: how to mechanically answer "does X depend on Y?" in a Lean 4 environment, and why `#print axioms` cannot answer it.

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

### 176. Fix the documented lake-build-guard full-build invocation across the lean extension
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: lean-extension
- **Dependencies**: None
- **Plan**: [176_fix_documented_full_build_guard_invocation/plans/01_fix-full-build-guard-invocation.md]
- **Summary**: [176_fix_documented_full_build_guard_invocation/summaries/01_fix-full-build-guard-invocation-summary.md]

**Description**: Fix the documented `lake-build-guard.sh` full-build invocation across the lean extension: four caller sites document a form that exits 77 without ever launching a build.

OBSERVED, not theorized. During a `/orchestrate` run in ~/Projects/BimodalLogic, a `lean-implementation-agent` dispatch followed its own agent definition's documented build command and got exit 77 (`build mode requires a lake subcommand (e.g. 'build', 'test'); none was given`). The agent recovered by guessing the correct form, but the dispatch stalled mid-phase first and the orchestrator had to re-dispatch. Every affected site is a FULL-repository build -- the final verification gate -- which is exactly the invocation an agent reaches for at phase end.

ROOT CAUSE, confirmed in the guard's own source. `validate_build_subcommand()` (agent-system/extensions/core/scripts/lake-build-guard.sh, immediately above `main()`) rejects an EMPTY lake-argument vector with exit 77 before any dispatch. In build mode the lake subcommand must follow the `--`. `bash lake-build-guard.sh build --timeout 1800 -- 2>&1` passes an empty vector (the `2>&1` is shell redirection, not an argument), so it can never run. The correct full-build form is `bash lake-build-guard.sh build --timeout 1800 -- build`.

THE FOUR CALLER SITES (all in the source store; `.claude/**` is a regenerated deploy artifact and must not be hand-edited -- see rules/source-store-deploy-boundary.md):
1. `agent-system/extensions/lean/agents/lean-implementation-agent.md:253` -- `build --timeout 1800 -- 2>&1`
2. `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md:392` -- same shape
3. `agent-system/extensions/lean/rules/lean4.md:51` -- "Final verification only: `... --timeout 1800 --`"
4. `agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md:81` -- `build --timeout 1800 2>&1`, no `--` at all, same empty vector

Note that the per-module forms at lean4.md:48/71, long-builds.md:75, lean-implementation-hard-agent.md:237 and skill-lake-repair/SKILL.md:79 are all CORRECT (`-- Module.Name` / `-- <lake args>`) -- only the full-build variants lost their subcommand. Verify each site rather than assuming this list is exhaustive; grep the whole source store for `lake-build-guard.sh build` and check every hit's argument vector.

A SECOND, SEPARATE DISCREPANCY -- surface it, do not fix it here. The guard's own usage banner (lake-build-guard.sh header, and `print_help`) documents the trailing lake arguments as OPTIONAL: `[--] [LAKE ARGS...]`. That contradicts `validate_build_subcommand()`, which requires a non-empty vector. The banner is plausibly what taught the broken form in the first place. That fix belongs in lake-build-guard.sh, which is another task's `file_scope` (the guard-terminal-record task) -- do NOT edit the guard here; the two would collide on the same file. Record the discrepancy in this task's summary and name it for that task to pick up, or for its own follow-up.

SCOPE. Correct the four (or more, if the grep finds them) caller sites to the working form. Keep each site's surrounding prose intent intact -- these are "final verification" instructions, so the replacement must remain a full-repository build, not silently become a per-module one. Do not modify lake-build-guard.sh or its tests.

ACCEPTANCE. Every `lake-build-guard.sh build` invocation in the source store either names a lake subcommand after `--` or is explicitly documented as a deliberate usage-error example. The corrected full-build form is verified to actually run -- not merely to parse -- at least once. Deploy the affected extension and confirm the regenerated `.claude/**` copies carry the fix.

---

### 175. Enforce waiter teardown in the agent contracts that spawn build waiters
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 172

**Description**: Wire the already-written teardown rule into the specific contracts whose agents actually spawn build waiters, so the leak is prevented at its source rather than only cleaned up afterward. Investigation finding: the governing rule already exists and was violated. agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md carries a normative section titled 'Tear Down Watchers/Monitors Before Reporting' stating that every agent which arms a watcher/monitor process during its own dispatch MUST tear it down before reporting a terminal result. The 22 leaked waiters are a direct violation of that existing rule -- so this is an enforcement-and-wiring problem, not a missing-prose problem. That file's own 'Where This Is Referenced' section lists exactly three fix sites today (skill-orchestrate's Stage 5 staleness-gate comment block, context/contracts/territory.md's Territory Declaration Template, and context/standards/orchestrator-runtime-files.md), none of which covers a build waiter armed by a dispatched implementation agent. Scope: (1) extend the teardown rule to name the supersession case explicitly -- a waiter must be torn down not only before REPORTING but before its watched build is cancelled or superseded, which is the transition that actually orphaned the observed loops -- and add the new fix sites to its 'Where This Is Referenced' list; (2) add the corresponding one-line pointer obligations to the agent contracts that dispatch guarded builds, i.e. the lean implementation agents (agent-system/extensions/lean/agents/lean-implementation-agent.md and lean-implementation-hard-agent.md), pointing at the bounded-waiter anchor and the teardown rule rather than restating either. Follow the established single-statement-plus-pointer convention: the model lives in one file, fix sites point at it. Do not duplicate the waiter contract text into the agent files.

---

### 174. Add a self-excluding orphaned-build-waiter reaper pass to /refresh
- **Effort**: 3-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 172

**Description**: Give the system a way to clean up waiters that already leaked, correct by construction against the self-match bug observed while cleaning up manually. Second observed defect, same bug class as the primary one: an ad-hoc cleanup command of the form `pgrep -f 'until grep' | ... kill` matched ITS OWN command line -- the command string contained the very pattern it was searching for -- and killed its own shell (exit 144). This happened twice. Any reaper for this must exclude itself and its own process group, or it kills the reaper. Investigation finding: agent-system/extensions/core/scripts/claude-refresh.sh already solves exactly this, and the fix should reuse its architecture rather than invent a new one. It takes a single atomic `ps -eo` snapshot per invocation (take_snapshot()) with every exclusion evaluated against that frozen snapshot, and it already implements what its own header calls zero-query self-exclusion -- `if [ "$pid" = "$$" ] || [ "$ppid" = "$$" ]; then` skip -- applied in both the Claude-process pass and the Lean-LSP pass. That idiom is known at parse time, needs no second query, and is race-free; it is the correct-by-construction answer to the pgrep self-match bug. Scope: add a new pass that identifies orphaned build-waiter poll loops (matching the process signature settled by the bounded-waiter contract) whose watched log has a dead or absent writer, reusing the existing snapshot and the existing self-exclusion, and extend the exclusion to the reaper's own process group as well as its pid/ppid. Decide and document the pass's gate class explicitly -- the existing passes are split between interactive-confirm (rows 1-2), report-only-always (rows 3-4), and age-threshold-only (rows 5-8); an age-threshold-only gate matching the stale-lock passes is the closest existing precedent, since these waiters are 0% CPU and provably unreapable rather than merely idle. Then update the pass inventory in BOTH places that must agree row-for-row on gate and destructiveness: agent-system/extensions/core/commands/refresh.md ('What It Cleans' table plus a new owning subsection) and agent-system/extensions/core/skills/skill-refresh/SKILL.md (its Pass Inventory table). State whether the new pass is reached by the hourly claude-refresh.timer cadence -- only the four passes internal to claude-refresh.sh currently are.

---

### 173. Guarantee lake-build-guard.sh writes a terminal record on every exit path
- **Effort**: 3-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 172

**Description**: Make the guard-side analogue of the poll-loop leak impossible, so that any correctly-written waiter can always drain. Investigation finding: lake-build-guard.sh does NOT write the observed `EXIT=` sentinel at all -- that was agent-side. What it does write is a structured record at <root>/.lake/build-guard.result via two functions: write_inflight_record() emits `state=in_flight`, `holder_pid=$$`, `start_epoch=`, empty `exit_status=`, and `log_path=`; finalize_record() rewrites it as `state=complete` with the real `exit_status=`. The defect: finalize_record() is reached only on the normal return path out of run_as_holder(). There is no trap, so if the holder shell is killed, cancelled, or superseded (exactly the lock-contention scenario that triggered the observed leak), the record is left permanently at `state=in_flight` with a `holder_pid` that names a dead process. A waiter consuming that record has no terminal transition to observe -- the same unbounded-termination defect, one layer down. Fix directions to evaluate (not prescriptive): install an EXIT/INT/TERM trap in run_as_holder() that finalizes the record with a distinguishable terminal state (e.g. state=aborted with a reserved exit_status) so existing waiters drain rather than hang; confirm holder_pid is documented as the liveness handle that the bounded-waiter contract's `kill -0` check reads, since it is already written and is the natural handle; and make sure the waiter/sharing path in cmd_build treats an in_flight record whose holder_pid is dead as stale rather than as a live build to wait behind. Preserve the guard's existing documented contracts: the subcommand shape (status/preflight/build), the reserved 77 usage band, exit 75 on lock-wait timeout, the five-condition staleness policy on the sharing decision, and the `--timeout` semantics (a lock-WAIT budget, never a build-duration limit). Extend agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh with coverage for the killed-holder case: a holder killed mid-build must leave a terminal record, and a waiter must not block on a record whose holder_pid is dead. Land the fix in the nvim source store only.

---

### 172. Define a canonical bounded-wait idiom for detached builds
- **Effort**: 2-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Close the taught-pattern gap that produced 22 unreapable poll loops during a multi-task /orchestrate run in ~/Projects/BimodalLogic. Investigation finding: the observed waiter shape `until grep -q "^EXIT=" <log>; do sleep ...; done` appears NOWHERE in this source store -- it is agent-improvised. Two forces create it: (a) the harness's own Bash guidance blocks foreground `sleep` and points agents at a Monitor until-loop to wait on a condition, and (b) extensions/lean/context/project/lean4/operations/long-builds.md mandates `Bash(run_in_background: true)` detachment for every `lake build` but offers no sanctioned way to BLOCK on a detached build -- its only stated discipline is 'wait for the harness completion notification', with four Passive progress checks explicitly labeled liveness-only. An agent that needs to block therefore invents an unbounded sentinel poll. The defect class: a poll loop whose exit condition is a sentinel written by a process that may die first has no bounded termination. In the observed run the agent-side wrapper was of the form `cmd > b2b.log 2>&1; echo "EXIT=$?" >> b2b.log`; when the guarded build was cancelled/superseded by lock contention with a concurrent session, the `echo` never ran, so the sentinel became unwritable by construction. 22 loops watched the same b2b.log (2 more watched b9b.log), aged 24-55 minutes, at 0% CPU -- the cost is background-shell-slot exhaustion and operator confusion, not throughput. Deliverable: a new core context pattern file (suggested agent-system/extensions/core/context/patterns/bounded-build-waiter.md) stating the defect class once, canonically, and defining a safe waiter with three mandatory properties -- (1) a hard timeout so the waiter cannot outlive its writer, (2) a writer-liveness check (`kill -0 <pid>`) rather than sentinel-polling alone, so a dead writer terminates the wait immediately, and (3) one-waiter-per-log enforcement, so a superseded build's waiter is reaped before a replacement waiter is spawned. Wire the new anchor into long-builds.md with a one-line pointer under a new section covering the blocking case (do NOT restate the model there -- follow the existing single-statement-plus-pointer convention used by context/patterns/dispatch-report-not-termination.md). This task is foundational: it settles the waiter/writer contract that the guard-side, reaper-side, and agent-contract tasks all consume. Do not modify lake-build-guard.sh, claude-refresh.sh, or any agent file here -- those are separate dependent tasks.

---

### 171. Fix literature ingest dedup hang
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Plan**: [171_fix_literature_ingest_dedup_hang/plans/01_fix-ingest-dedup-hang.md]
- **Summary**: [171_fix_literature_ingest_dedup_hang/summaries/01_fix-ingest-dedup-hang-summary.md]

**Description**: Fix the literature online-ingest hang caused by an O(n) per-title subprocess loop. check_duplicate_title() in agent-system/extensions/literature/scripts/literature-ingest-online.sh iterates every title in the global Literature index and spawns a separate python3 process per title to run .zotero-title-sim.py (11845 titles as of 2026-09-07), so any in_zotero_no_pdf or open_access ingest stalls for roughly 9-10 minutes before emitting any directive token. Observed: an in_zotero_no_pdf record (Zotero citation_key xu2001facing, item key Z8QNQKNL) logged "Resolved doc_id=... (tier=matched-no-pdf)" to stderr and then produced no stdout directive token at all until killed by a 540s timeout (rc=124), so the caller cannot distinguish a hang from a slow success. The Unpaywall lookup already carries curl --max-time 10 and the download path --max-time 30, so this is not network-bound; the stall is the subprocess-per-title loop. Fix direction: collapse the similarity pass into a single python3 invocation (pass the candidate title and the whole title list once, or precompute a normalized-title map), and short-circuit on exact or normalized-equality before any similarity scoring. Because the check is documented as non-blocking and recommendation-only, it must also fail fast and never gate ingestion. Preserve the existing WARNING output contract and the 0.85 similarity threshold. Note for scope: the sibling literature defect found in the same session (literature-briefing.sh exiting 141/SIGPIPE from piping a multi-line jq object into head -1 under set -euo pipefail) is ALREADY FIXED in this source store, which now uses jq -c first(...); no work is needed for it here, only redeployment of stale consumer repos

---

### 170. Audit and isolate shell test suites from ambient host state (memory and timing axes), and record the convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 151, Task 169

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

---

### 168. Correct opencode mcp scoping claim
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: opencode
- **Dependencies**: None

**Description**: Correct the disproven project-scoped MCP claim in the OpenCode doc tree.

An earlier task verified against Claude Code's actual behavior that there is NO categorical subagent barrier to project-scoped MCP servers (.mcp.json) -- the real constraint is one-time workspace trust, not per-call access -- and landed the corrected wording in agent-system/extensions/core/docs/docs-README.md (see its "MCP Configuration" section). Two tracked, live files in the parallel OpenCode tree still carry the disproven claim verbatim and were explicitly scoped OUT of that task under its canonical-source constraint:
  .opencode/extensions/core/docs/README.md:227
  .opencode/docs/README.md:227
The two are currently byte-identical. Establish which is source and which is deployed BEFORE editing, and edit the source, not the deploy.

STALE TEXT (both files):
  "Custom subagents cannot access project-scoped MCP servers (`.mcp.json`). For subagent access, configure servers in user scope (`~/.claude.json`)."

WHY THIS MATTERS. The earlier task's research documented that this specific false claim had already propagated into research findings, implementation plans, and user-facing handoffs, each concluding that subagents were barred from project scope. It is a decision-corrupting premise with a demonstrated track record, not a cosmetic doc nit.

SCOPE. Correct the claim and align it with the corrected core wording. context/patterns/mcp-server-ownership.md already carries the accurate framing and needs NO edits -- consult it, do not modify it. Do NOT re-derive or re-litigate the underlying MCP behavior; it is already verified, and this is a propagation fix, not a research question. Keep the correction proportionate to the one-line defect: do not restructure the surrounding "MCP Configuration" section.

ACCEPTANCE.
  - Repo-wide grep for "cannot access project-scoped MCP" returns zero hits outside historical specs/ artifacts.
  - Both OpenCode files carry wording consistent with the corrected core version.
  - If the two files are in a source/deploy relationship, the deployed copy is REGENERATED rather than hand-edited.

---

### 167. Make vimtex continuous-build safety always-in-effect via the latex extension rule
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None

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

---

### 166. Stop research reports drifting from validate-artifact.sh's required section headings
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: DEFECT: a produced research report used section headings that are semantically correct but lexically non-conforming, so validate-artifact.sh's required-section check failed on an artifact whose authoring agent ALREADY carries a conforming skeleton. This is NOT the "agent has no skeleton at all" class addressed by the lean/formal skeleton work -- here the skeleton is present and correct, and the produced artifact drifted from it.

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

---

### 165. Decide and implement the admission posture for an absent file_scope in orchestrate-batch-admit.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 163, Task 164

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

---

### 164. Backfill file_scope for existing tasks and decide the disposition for plan-less tasks
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: Task 162

**Description**: One-shot backfill of `file_scope` for existing tasks that lack a usable one, plus an explicit ruling on the tasks the backfill CANNOT reach.

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

### 163. Surface missing and empty file_scope in validate-state.sh and orchestrate-predispatch-review.sh
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: None

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

---

### 162. Formalize the existing Files to modify convention in plan-format and harvest it into file_scope at plan postflight
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: file-scope-lifecycle
- **Dependencies**: None

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

---

### 157. Fix TODO.md summary lines: prefer .title, and stop the blind slice from splitting inline-code spans
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Plan**: [157_markdown_safe_todo_summary_truncation/plans/01_markdown-safe-summary-truncation.md]
- **Summary**: [157_markdown_safe_todo_summary_truncation/summaries/01_markdown-safe-summary-truncation-summary.md]

**Description**: The "Grouped by Topic" summary lines in TODO.md are cut with a blind character slice
that can land inside an inline-code span, leaving an unclosed backtick that corrupts markdown
highlighting for the rest of the line. Separately and more consequentially, those lines slice
.description when 23 of 29 active tasks carry a purpose-written .title the generator never
consults. Observed on screen by the operator, then confirmed against the live file; not inferred.

ROOT CAUSE, VERIFIED 2026-09-07.
scripts/generate-task-order.sh:155 populates the task_desc map that every summary emit site
reads:
    "\(.project_number)|\((.description // .project_name) | ltrimstr(" ") | .[0:65])"
`.[0:65]` is a blind character slice. Nothing balances markdown inline formatting across the cut.

EVIDENCE -- exactly one line in the current TODO.md carries an odd backtick count, and it is the
one that renders wrong:
    44 [PLANNED] -- LOWER PRIORITY (per-invocation cost, not per-session). `commands/
One backtick, never closed, so the span bleeds onward. Two neighbouring lines survive only by
luck of where character 65 happened to fall:
    139 ... Bare git history rewrites (`git commit --amend`, `git reset` with     -- 4, balanced
    129 ... Audit every `\b` word-boundary construct used in a grep pattern a     -- 2, balanced
This is therefore intermittent by position, not by content, which is why it reads as a random
highlighting glitch rather than a bug.

SECOND, COMPOUNDING SLICE SITE. scripts/generate-task-order.sh:592 applies `${desc:0:40}` to the
ALREADY-SLICED value for cross-topic "(see above)" annotations. A pair the first cut left intact
can be split by the second. Both sites need the same treatment; there is no third slice -- the
other emit sites at :593, :600 and :766 all consume task_desc unmodified, so fixing :155 fixes
them.

THE LARGER DEFECT UNDERNEATH. Line 155 reads `(.description // .project_name)` and never consults
`.title`. Coverage measured on the live state.json: 29 active non-terminal tasks, 23 with a
non-empty title. The six without are 29, 30, 45, 51, 89 and 127. What the section shows today
versus what was already available:
    44   shown: LOWER PRIORITY (per-invocation cost, not per-session). `commands/
         title: Slim commands/task.md, the largest per-invocation context contributor
    88   shown: === ADDENDUM 2026-09-02 (team mode deleted; dry-run report retire
         title: Delete the single-task engine and rewrite skill-orchestrate as the four-move loop
    137  shown: The lean extension's research and implementation agents have no a
         title: Give the lean research and implementation agents the artifact skeletons their
                general-* counterparts already have
Every truncated fragment the operator observed on screen -- "larg", "present-r", "auxili",
"have no a", and the "=== REVISED" / "=== ADDENDUM" administrative preambles for 127 and 88 --
is this same cause: the top of a long prose description shown where a written summary existed.

WORK -- three independent sub-fixes, all at scripts/generate-task-order.sh:155, plus :592.

  (a) PREFER .title. Change the source expression to `(.title // .description // .project_name)`.
      .description remains the fallback for the six title-less tasks. Note honestly that this
      CHANGES WHAT ~23 LINES SAY, not merely how they are cut -- it is a content change to the
      section, and the regenerated output must be eyeballed, not just diffed for line count.

  (b) MAKE TRUNCATION MARKDOWN-SAFE. Strip inline-code backticks before slicing rather than
      trying to balance them after. Stripping eliminates the whole class -- backticks, and also
      `*`, `_` and unclosed `[` -- where a parity check only handles the one symptom observed.
      Record the rejected alternative and why: appending a closing backtick when the count is odd
      preserves code styling but fabricates a span around a truncated fragment, rendering
      `commands/` as though it named a real path when the actual content was longer. At a 65
      character budget the styling buys nothing. If the implementer disagrees after looking at
      real output, they may choose the parity approach instead, but must say why in the summary.

  (c) CUT ON A WORD BOUNDARY AND SIGNAL TRUNCATION. Back off to the last space at or before the
      budget and append an ellipsis. Nothing currently signals that a line was cut at all, which
      is why the fragments read as corrupted text rather than as elisions.

A composed form satisfying all three (illustrative, not prescriptive -- verify against real data
before committing to it):
    "\(.project_number)|\((.title // .description // .project_name)
       | ltrimstr(" ") | gsub("`";"") | gsub("\n";" ")
       | if length > 65 then (.[0:65] | sub(" [^ ]*$";"")) + "..." else . end)"
Note it contains no `!=`, so it is clear of the jq escaping hazard documented in CLAUDE.md's
"jq Command Safety" section. Confirm that holds for whatever is finally written.

TEST COVERAGE. scripts/tests/ currently contains NO test for generate-task-order.sh or
generate-todo.sh -- verified by listing the directory. A regression this cheap to assert should
not go back in uncovered. Add scripts/tests/test-generate-task-order.sh following the conventions
of the existing tests in that directory.

CONSTRAINTS.
  - Edit agent-system/extensions/core/scripts/**, never .claude/**. The deployed
    .claude/scripts/generate-task-order.sh is regenerated and any edit there is wiped.
  - TODO.md is wholly generated from state.json by generate-todo.sh (which delegates the Task
    Order section to generate-task-order.sh --print). Do NOT hand-edit TODO.md to fix the
    rendering; that would be papered over on the next regeneration.
  - No file_scope collision was found: no other active task lists generate-task-order.sh or
    generate-todo.sh in its file_scope, checked 2026-09-07.

ACCEPTANCE.
  - Every line of the regenerated "Grouped by Topic" section has an EVEN backtick count,
    asserted mechanically over the whole section, not spot-checked. The task-44 line is the
    specific regression witness and must be shown before and after.
  - A description crafted to place a backtick exactly at the cut boundary produces a balanced
    line. This is the case the current code fails, so a test that only uses today's data proves
    nothing -- construct the adversarial input deliberately.
  - Lines for tasks WITH a title show the title; lines for the six WITHOUT one still render from
    .description and are not made worse. Both directions demonstrated.
  - No line exceeds the budget, and every truncated line ends at a word boundary with a
    truncation marker; untruncated lines carry no marker.
  - The second slice at :592 is covered by the same guarantees, demonstrated on a cross-topic
    "(see above)" line rather than assumed to follow from the :155 fix.
  - A test exists under scripts/tests/ and fails against the pre-fix script.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 156. Surface a Comparator doctor mode and document what a green result does and does not certify
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 155
- **Research**: [156_document_comparator_trust_boundary/reports/01_comparator-doctor-trust-boundary.md]
- **Plan**: [156_document_comparator_trust_boundary/plans/01_comparator-doctor-trust-boundary.md]
- **Summary**: [156_document_comparator_trust_boundary/summaries/01_comparator-doctor-trust-boundary-summary.md]

**Description**: BACKGROUND (verified 2026-09-07, shared by all Comparator tasks).
leanprover/comparator (Apache-2.0, github.com/leanprover/comparator, default branch master,
lean-toolchain leanprover/lean4:v4.34.0-rc2, last push 2026-08-30) is a trustworthy judge for
Lean proofs from untrusted sources, built by Lean FRO with AIMO feedback expressly to enable
trustworthy LLM Lean evaluation. Given a trusted Challenge.lean (statements, bodies may be
sorry), an untrusted Solution.lean, and a JSON config naming challenge_module, solution_module,
theorem_names, permitted_axioms (and optionally definition_names and external_kernels), it:
  1. builds Challenge with lake inside a landrun sandbox, then runs lean4export on the .olean
  2. repeats build-sandboxed and export-sandboxed for Solution
  3. verifies every declaration used in the STATEMENT of each named theorem is identical between
     the Challenge and Solution environments
  4. verifies the bodies of the named theorems use no axioms outside permitted_axioms
  5. replays the Solution environment into the Lean kernel (optionally also external kernels)
It deliberately never loads .olean files, on the stated grounds that they are mmapped into the
address space and dereferenced and are therefore an attack surface.

WHY THIS MATTERS TO THIS AGENT SYSTEM. lean-implementation-agent is precisely an untrusted
LLM proof producer, and its Final Verification Stage currently gates on four text heuristics,
each with a hole Comparator closes:
  - plan compliance (agents/lean-implementation-agent.md, Final Verification Stage step 5) greps
    only that a declaration NAMED X exists in Theories/. It never checks that X states what the
    plan intended. Statement weakening -- adding a hypothesis, specialising a quantifier,
    restating a weaker claim -- passes this gate silently. Comparator step 3 is exactly the
    missing check.
  - the new-axiom gate is `grep -rn "^axiom " Theories/ | wc -l`, a textual match on one source
    form. It does not see sorryAx, axioms reached transitively through imports, or the axioms
    native_decide introduces. Comparator step 4 is a transitive check against a whitelist.
  - the vacuous-definition gate is a single-line grep for `:= True|Unit|trivial|Trivial`; the
    agent file itself already records that multi-line vacuous definitions require manual review.
  - `lake build` elaborates but never replays into the kernel, and it runs agent-authored Lean
    UNSANDBOXED. Elaboration executes arbitrary code (#eval, initialize, run_cmd, macros,
    native_decide plugins). Comparator steps 1-2 sandbox both builds and step 5 replays.
So the role Comparator serves is specific and bounded: it upgrades the "did the agent cheat?"
question from grep heuristics to a kernel-backed guarantee. It is the natural terminal gate for
context/project/lean4/standards/proof-debt-policy.md's zero-debt completion requirement, which
today is enforced by exactly those greps.

FOUR CONSTRAINTS ANY INTEGRATION MUST HANDLE (all read off the tool's own README).
  C1 NO CHALLENGE EXISTS TODAY. Comparator's guarantee is relative to a Challenge you trust.
     Plans in this system name goal IDENTIFIERS, not statements (context/formats/plan-format.md
     defines only `- **Goals**: ...` under `## Goals & Non-Goals`). Something must fix the
     intended statements before the agent works.
  C2 ASSUMPTION 2 IS VIOLATED BY THE NORMAL WORKFLOW. The README requires that you have not
     previously tried to compile the Solution file, "as that might compromise your Challenge file
     to make it seem like you are looking for a different proof than you actually are". The
     implementation agent compiles continuously. The README does bless a mitigation: with a fully
     pre-built .lake obtained without compromising the checking environment, Solution.lean is not
     rebuilt.
  C3 VERSION COUPLING. lean4export must match the Lean version of the TARGET project, not
     Comparator's own v4.34.0-rc2.
  C4 COST. Two sandboxed full builds plus two exports plus a kernel replay. On a Mathlib
     dependant project this is minutes to tens of minutes. Opt-in only, scoped to named theorems.

ENVIRONMENT AS MEASURED ON THIS MACHINE 2026-09-07: lake, lean, elan present (~/.elan/bin);
landrun, lean4export, nanoda_bin, comparator ALL MISSING. landrun is in nixpkgs at 0.1.15. The
kernel is Linux 7.1.3, past the landrun issue the README's systemd-run wrapper guards against
("will be fixed in Linux 7.1") -- the wrapper is still required for portability, not for this
host.

GATE STRENGTH DECISION (already made by the operator, do not relitigate): ADVISORY FIRST. A
Comparator rejection records its finding and surfaces it prominently, but MUST NOT set
verification_passed false, MUST NOT downgrade status to partial, and MUST NOT block completion.
Promotion to a hard gate is a separate, later decision to be taken on evidence from real runs.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

WORK -- make the trust boundary legible to a human, and give the environment a doctor.

  (a) DOCTOR MODE. Add a Comparator mode to commands/lean.md alongside check/upgrade/rollback,
      routed through skills/skill-lean-version/SKILL.md (which is already the direct-execution
      home for toolchain-version concerns and already reads lean-toolchain and elan state). It
      probes for landrun, lean4export, comparator and optionally nanoda_bin; reports which are
      present and via which env var each may be overridden; and CHECKS THE C3 VERSION MATCH --
      lean4export must match the target project's lean-toolchain, not Comparator's own. A doctor
      that only reports presence and not version match will pass on a setup that cannot work.
  (b) TRUST-MODEL DOCUMENT at context/project/lean4/tools/comparator-guide.md. This is the
      important half of the task. It must state, plainly and without overclaiming, WHAT A GREEN
      COMPARATOR RESULT DOES AND DOES NOT CERTIFY:
        - it certifies the named theorems prove the Challenge's statements, use no axioms outside
          the whitelist, and are accepted by the kernel;
        - it does NOT certify that the Challenge asked the right question;
        - it does NOT certify definition-hole solutions -- the tool's own README requires an
          additional, potentially human, verifier for those, and gives the RiemannHypothesis
          gaming example;
        - its guarantee is conditional on the README's six assumptions, of which at least two are
          live concerns here: that the Solution was not previously compiled in the checking
          environment, and that landrun sandboxes correctly on the host;
        - the trusted computing base includes the OS, the hardware, and landrun's sandboxing.
      Register the file in index-entries.json with an accurate line_count and link it from
      context/project/lean4/README.md.
  (c) POLICY UPDATE. context/project/lean4/standards/proof-debt-policy.md states a zero-debt
      completion requirement enforced today by greps. Record what Comparator adds, and be
      explicit that while --compare is advisory the greps remain the operative gate. Do not write
      the policy as though the hard gate already exists.
  (d) EXTENSION SURFACE. Update EXTENSION.md, README.md, manifest.json and index-entries.json to
      reflect the new command mode, script(s) and context file. check-extension-docs.sh Rule R
      compares declared line_count against actual, so a stale declaration here will fail the
      doc-lint gate.

ACCEPTANCE.
  - The doctor reports correctly in three distinct states: all binaries present and versions
    matched; a binary missing; a binary present but lean4export mismatched against the project
    toolchain. The third state is the one that matters and must be demonstrated, not assumed.
  - comparator-guide.md contains an explicit "what this does not certify" section naming the
    definition-hole caveat and the previously-compiled-Solution assumption.
  - A fresh deploy passes check-extension-docs.sh with the new entries registered.
  - No task-number references appear in any of these deliverables (all live outside specs/).

---

### 155. Thread an advisory --compare flag through the lean implementation path
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 137, Task 153, Task 154
- **Research**: [155_thread_compare_flag_through_lean_implementation/reports/01_compare-flag-lean-threading.md]
- **Plan**: [155_thread_compare_flag_through_lean_implementation/plans/01_compare-flag-lean-threading.md]
- **Summary**: [155_thread_compare_flag_through_lean_implementation/summaries/01_compare-flag-lean-threading-summary.md]

**Description**: BACKGROUND (verified 2026-09-07, shared by all Comparator tasks).
leanprover/comparator (Apache-2.0, github.com/leanprover/comparator, default branch master,
lean-toolchain leanprover/lean4:v4.34.0-rc2, last push 2026-08-30) is a trustworthy judge for
Lean proofs from untrusted sources, built by Lean FRO with AIMO feedback expressly to enable
trustworthy LLM Lean evaluation. Given a trusted Challenge.lean (statements, bodies may be
sorry), an untrusted Solution.lean, and a JSON config naming challenge_module, solution_module,
theorem_names, permitted_axioms (and optionally definition_names and external_kernels), it:
  1. builds Challenge with lake inside a landrun sandbox, then runs lean4export on the .olean
  2. repeats build-sandboxed and export-sandboxed for Solution
  3. verifies every declaration used in the STATEMENT of each named theorem is identical between
     the Challenge and Solution environments
  4. verifies the bodies of the named theorems use no axioms outside permitted_axioms
  5. replays the Solution environment into the Lean kernel (optionally also external kernels)
It deliberately never loads .olean files, on the stated grounds that they are mmapped into the
address space and dereferenced and are therefore an attack surface.

WHY THIS MATTERS TO THIS AGENT SYSTEM. lean-implementation-agent is precisely an untrusted
LLM proof producer, and its Final Verification Stage currently gates on four text heuristics,
each with a hole Comparator closes:
  - plan compliance (agents/lean-implementation-agent.md, Final Verification Stage step 5) greps
    only that a declaration NAMED X exists in Theories/. It never checks that X states what the
    plan intended. Statement weakening -- adding a hypothesis, specialising a quantifier,
    restating a weaker claim -- passes this gate silently. Comparator step 3 is exactly the
    missing check.
  - the new-axiom gate is `grep -rn "^axiom " Theories/ | wc -l`, a textual match on one source
    form. It does not see sorryAx, axioms reached transitively through imports, or the axioms
    native_decide introduces. Comparator step 4 is a transitive check against a whitelist.
  - the vacuous-definition gate is a single-line grep for `:= True|Unit|trivial|Trivial`; the
    agent file itself already records that multi-line vacuous definitions require manual review.
  - `lake build` elaborates but never replays into the kernel, and it runs agent-authored Lean
    UNSANDBOXED. Elaboration executes arbitrary code (#eval, initialize, run_cmd, macros,
    native_decide plugins). Comparator steps 1-2 sandbox both builds and step 5 replays.
So the role Comparator serves is specific and bounded: it upgrades the "did the agent cheat?"
question from grep heuristics to a kernel-backed guarantee. It is the natural terminal gate for
context/project/lean4/standards/proof-debt-policy.md's zero-debt completion requirement, which
today is enforced by exactly those greps.

FOUR CONSTRAINTS ANY INTEGRATION MUST HANDLE (all read off the tool's own README).
  C1 NO CHALLENGE EXISTS TODAY. Comparator's guarantee is relative to a Challenge you trust.
     Plans in this system name goal IDENTIFIERS, not statements (context/formats/plan-format.md
     defines only `- **Goals**: ...` under `## Goals & Non-Goals`). Something must fix the
     intended statements before the agent works.
  C2 ASSUMPTION 2 IS VIOLATED BY THE NORMAL WORKFLOW. The README requires that you have not
     previously tried to compile the Solution file, "as that might compromise your Challenge file
     to make it seem like you are looking for a different proof than you actually are". The
     implementation agent compiles continuously. The README does bless a mitigation: with a fully
     pre-built .lake obtained without compromising the checking environment, Solution.lean is not
     rebuilt.
  C3 VERSION COUPLING. lean4export must match the Lean version of the TARGET project, not
     Comparator's own v4.34.0-rc2.
  C4 COST. Two sandboxed full builds plus two exports plus a kernel replay. On a Mathlib
     dependant project this is minutes to tens of minutes. Opt-in only, scoped to named theorems.

ENVIRONMENT AS MEASURED ON THIS MACHINE 2026-09-07: lake, lean, elan present (~/.elan/bin);
landrun, lean4export, nanoda_bin, comparator ALL MISSING. landrun is in nixpkgs at 0.1.15. The
kernel is Linux 7.1.3, past the landrun issue the README's systemd-run wrapper guards against
("will be fixed in Linux 7.1") -- the wrapper is still required for portability, not for this
host.

GATE STRENGTH DECISION (already made by the operator, do not relitigate): ADVISORY FIRST. A
Comparator rejection records its finding and surfaces it prominently, but MUST NOT set
verification_passed false, MUST NOT downgrade status to partial, and MUST NOT block completion.
Promotion to a hard gate is a separate, later decision to be taken on evidence from real runs.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

WORK -- thread `--compare` end to end, ADVISORY ONLY.

  (a) FLAG SPINE. Add COMPARE_FLAG to core/scripts/parse-command-args.sh. Model it on LIT_FLAG
      and CLEAN_FLAG (boolean mode hints), NOT on EFFORT_FLAG: --compare must compose with --hard
      rather than compete with it. The file's header comment block enumerates every exported
      variable and is load-bearing documentation -- extend it, do not just add the assignment.
  (b) SKILL THREADING. skills/skill-lean-implementation/SKILL.md and
      skills/skill-lean-implementation-hard/SKILL.md pass the flag into the delegation context
      they hand to the Agent tool. Both, not just the standard one.
  (c) AGENT GATE. In agents/lean-implementation-agent.md, add a Comparator step to the Final
      Verification Stage, and the same in agents/lean-implementation-hard-agent.md. The step
      invokes lean-comparator-run.sh against the snapshot Challenge and the implemented Solution,
      scoped to the theorem names the plan declares. It runs ONLY when --compare was passed.
  (d) METADATA. Record a `comparator` block in .return-meta.json carrying the verdict category,
      the theorem names checked, the axiom whitelist used, and the runtime. Update
      core/context/formats/return-metadata-file.md so the block is part of the documented schema
      rather than an undeclared field. The verification block's existing keys
      (verification_passed, sorry_count, vacuous_count, axiom_count, build_passed) are NOT
      touched by this task.
  (e) POSTFLIGHT SURFACE. The skill's postflight reads the comparator block and surfaces it in
      the returned summary. Per the operator's decision it MUST NOT downgrade status. Note that
      skill postflight is bound by context/standards/postflight-tool-restrictions.md -- the skill
      READS the agent's recorded result and must not re-run the check itself, exactly as it
      already reads compliance_check at Stage 6b rather than re-running the grep.

ADVISORY MEANS ADVISORY. The failure mode to design against is not a false block, it is a finding
nobody ever reads. Make a rejection loud in the returned summary and in the written summary
artifact. Record, in the implementation summary, what the promotion criteria to a hard gate would
be, so that decision later has evidence to stand on rather than being taken on vibes.

FILE COLLISION, READ BEFORE STARTING: the lean artifact-skeletons task is in [IMPLEMENTING] and
edits agents/lean-implementation-agent.md and lean-research-agent.md. This task is dependency
ordered behind it for that reason. Re-read those files at dispatch time rather than working from
the state described here.

ACCEPTANCE.
  - A lean4 dispatch WITHOUT --compare behaves exactly as today: no Comparator invocation, no new
    metadata block, no runtime cost. Demonstrated, because a mode hint that fires unconditionally
    is a regression for every existing task.
  - A dispatch WITH --compare on an honest implementation records a `verified` verdict and
    completes normally.
  - A dispatch WITH --compare on an implementation that weakened a statement records the
    rejection, surfaces it in the summary, and STILL COMPLETES -- proving the advisory contract
    holds in the direction that actually tests it.
  - --compare --hard routes to the hard agent AND runs the Comparator step, proving composition.
  - Missing binaries produce a reported comparator_unavailable, not a silent pass and not a
    block.

---

### 150. Research on demand: planner-first lifecycle with research only when the planner asks or --research forces it
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88
- **Research**: [150_research_on_demand/reports/01_research-on-demand-lifecycle.md]
- **Plan**: [150_research_on_demand/plans/01_research-on-demand-lifecycle.md]
- **Summary**: [150_research_on_demand/summaries/01_research-on-demand-lifecycle-summary.md]

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

### 142. Orchestrator context budget: measure and lock
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88
- **Research**: [142_reduce_orchestrator_token_consumption/reports/01_context-budget-gate-measurement.md]
- **Plan**: [142_reduce_orchestrator_token_consumption/plans/01_context-budget-gate-lock.md]
- **Summary**: [142_reduce_orchestrator_token_consumption/summaries/01_context-budget-gate-lock-summary.md]

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
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 148
- **Research**: [088_mode_gate_skill_orchestrate_multi_task_section/reports/01_delete-single-task-engine.md]
- **Plan**: [088_mode_gate_skill_orchestrate_multi_task_section/plans/01_four-move-loop-rewrite.md]
- **Summary**: [088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_four-move-loop-rewrite-summary.md]

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
